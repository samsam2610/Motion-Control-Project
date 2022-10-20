classdef AnalogTriggerApp_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        AnalogTriggerAppExampleUIFigure  matlab.ui.Figure
        GridLayout                      matlab.ui.container.GridLayout
        LeftPanel                       matlab.ui.container.Panel
        LeftPanelLabel                  matlab.ui.control.Label
        StopButton                      matlab.ui.control.Button
        StartButton                     matlab.ui.control.Button
        RateSlider                      matlab.ui.control.Slider
        RateEdit                        matlab.ui.control.NumericEditField
        RatescanssLabel                 matlab.ui.control.Label
        ExcitationSourceDropDown        matlab.ui.control.DropDown
        ExcitationSourceLabel           matlab.ui.control.Label
        TerminalConfigDropDown          matlab.ui.control.DropDown
        TerminalConfigLabel             matlab.ui.control.Label
        CouplingDropDown                matlab.ui.control.DropDown
        CouplingLabel                   matlab.ui.control.Label
        RangeDropDown                   matlab.ui.control.DropDown
        RangeLabel                      matlab.ui.control.Label
        MeasurementTypeDropDown         matlab.ui.control.DropDown
        MeasurementTypeLabel            matlab.ui.control.Label
        ChannelDropDown                 matlab.ui.control.DropDown
        ChannelLabel                    matlab.ui.control.Label
        DeviceDropDown                  matlab.ui.control.DropDown
        DeviceLabel                     matlab.ui.control.Label
        CenterPanel                     matlab.ui.container.Panel
        CenterPanelLabel                matlab.ui.control.Label
        TimeWindowEditField             matlab.ui.control.NumericEditField
        TimeWindowsEditFieldLabel       matlab.ui.control.Label
        AutoscaleYSwitch                matlab.ui.control.Switch
        AutoscaleYSwitchLabel           matlab.ui.control.Label
        CaptureDataAxes                 matlab.ui.control.UIAxes
        LiveDataAxes                    matlab.ui.control.UIAxes
        RightPanel                      matlab.ui.container.Panel
        RightPanelLabel                 matlab.ui.control.Label
        CaptureDurationEditField        matlab.ui.control.NumericEditField
        CaptureDurationsEditFieldLabel  matlab.ui.control.Label
        TriggerDelayEditField           matlab.ui.control.NumericEditField
        TriggerDelaysEditFieldLabel     matlab.ui.control.Label
        TriggerLevelEditField           matlab.ui.control.NumericEditField
        TriggerLevelEditFieldLabel      matlab.ui.control.Label
        StatusText                      matlab.ui.control.Label
        CaptureButton                   matlab.ui.control.StateButton
        VariableNameEditField           matlab.ui.control.EditField
        VariableNameEditFieldLabel      matlab.ui.control.Label
        TriggerConditionDropDown        matlab.ui.control.DropDown
        TriggerConditionDropDownLabel   matlab.ui.control.Label
    end

    % Properties that correspond to apps with auto-reflow
    properties (Access = private)
        onePanelWidth = 576;
        twoPanelWidth = 768;
    end

    % Analog Trigger App example
    % 2019/01/11 version 1.0 Andrei Ursache
    % 2019/12/21 version 1.1, AU, updated DAQ code from Session to DataAcquisition interface
    
    % Copyright 2019-2020 The MathWorks, Inc.
        
    properties (Access = private)
        DAQ                      % Handle to DAQ object
        DevicesInfo              % Array of devices that provide analog input voltage or audio input measurements
        TimestampsFIFOBuffer     % Timestamps FIFO buffer used for live plot of latest "N" seconds of acquired data
        DataFIFOBuffer           % Data FIFO buffer used for live plot of latest "N" seconds of acquired data
        FIFOMaxSize = 1E+7;      % Maximum allowed FIFO buffer size for DataFIFOBuffer and TimestampsFIFOBuffer
        LivePlotLine             % Handle to line plot of acquired data
        DAQMeasurementTypes = {'Voltage','IEPE','Audio'};  % DAQ input measurement types supported by the app
        DAQSubsystemTypes = {'AnalogInput','AudioInput'};  % DAQ subsystem types supported by the app
        CapturePlotLine          % Handle to line plot of capture data
        TrigActive = false;      % Trigger detected flag
        TrigMoment = [];         % Relative timestamp (s) of detected trigger event
        CaptureTimestamps        % Captured data timestamps (s)
        CaptureData              % Captured data
        Timestamps = [];         % Latest timestamps values used for trigger detection
        Data = [];               % Latest data values used for trigger detection       
        CallbackTimeSpan         % Timespan of data read in ScansAvailable callback
        TriggerDelay             % Trigger delay (s)
        CaptureDuration          % Capture duration (s)
        ViewTimeWindow           % Live view timespan (s)
        CaptureStartMoment       % Relative timestamp of capture start moment (s)
        BufferSize               % Size of the data FIFO buffer
        TriggerDelayMax = 3600;  % Upper limit for trigger delay (s)
        CurrentState = '';       % App current state       
    end
    
    methods (Access = private)
        
        function scansAvailable_Callback(app, src, ~)
        %scansAvailable_Callback Executes on DAQ ScansAvailable event
        %  This callback function gets executed periodically as more data is acquired.
        %  For a smooth live plot update, it stores the latest N seconds
        %  (specified time window) of acquired data and relative timestamps in FIFO
        %  buffers. A live plot is updated with the data in the FIFO buffer.
        
            if ~isvalid(app)
                return
            end
            
            
            % Continuous acquisition data and timestamps are stored in FIFO data buffers
            % Calculate required buffer size -- this should be large enough to accomodate the
            % the data required for the live view time window and the data for the requested
            % capture duration.
            app.ViewTimeWindow = app.TimeWindowEditField.Value;
            app.TriggerDelay = app.TriggerDelayEditField.Value;
            app.CaptureDuration = app.CaptureDurationEditField.Value;
            
            [data,timestamps] = read(src, src.ScansAvailableFcnCount, 'OutputFormat','Matrix');
            
            % Store continuous acquisition data in FIFO data buffers
            app.TimestampsFIFOBuffer = storeDataInFIFO(app, app.TimestampsFIFOBuffer, app.BufferSize, timestamps);
            app.DataFIFOBuffer = storeDataInFIFO(app, app.DataFIFOBuffer, app.BufferSize, data(:,1));
            
            % Update live plot data
            samplesToPlot = min([round(app.ViewTimeWindow * src.Rate), size(app.DataFIFOBuffer,1)]);
            firstPoint = size(app.DataFIFOBuffer, 1) - samplesToPlot + 1;
            if samplesToPlot > 1
                xlim(app.LiveDataAxes, [app.TimestampsFIFOBuffer(firstPoint), app.TimestampsFIFOBuffer(end)])
            end
            set(app.LivePlotLine, 'XData', app.TimestampsFIFOBuffer(firstPoint:end), ...
                'YData', app.DataFIFOBuffer(firstPoint:end));
            
            
            % If capture is requested, analyze latest acquired data until a trigger
            % condition is met. After enough data is acquired for a complete capture,
            % as specified by the capture duration, extract the capture data from the
            % data buffer and save it to a base workspace variable.
            
            % For trigger detection, store previous and current ScansAvailable callback data and timestamps
            if isempty(app.Timestamps)
                app.Data = data(:,1);
                app.Timestamps = timestamps;
            else
                app.Data = [app.Data(end,1); data(:,1)];
                app.Timestamps = [app.Timestamps(end); timestamps];
            end
            
            % App state control logic 
            switch app.CurrentState
                case 'Acquisition.Buffering'
                   % Buffering pre-trigger data
                    if isEnoughDataBuffered(app)
                        app.CurrentState = 'Acquisition.ReadyForCapture';
                        setAppViewState(app, app.CurrentState)
                    end
                case 'Acquisition.ReadyForCapture'
                    % Ready for capture
                    if app.CaptureButton.Value
                        app.CurrentState = 'Capture.LookingForTrigger';
                        setAppViewState(app, app.CurrentState)
                    end
                case 'Capture.LookingForTrigger'
                    % Looking for trigger event in the latest data
                    detectTrigger(app)
                    if app.TrigActive
                        app.CurrentState = 'Capture.CapturingData';
                        setAppViewState(app, app.CurrentState)
                    end
                case 'Capture.CapturingData'
                    % Capturing data
                    % Not enough acquired data to cover capture timespan during this ScansAvailable callback execution
                    if isEnoughDataCaptured(app)
                        app.CurrentState = 'Capture.CaptureComplete';
                        setAppViewState(app, app.CurrentState)
                    end
                case 'Capture.CaptureComplete'
                    % Acquired enough data to complete capture of specified duration
                    completeCapture(app)
                    app.CurrentState = 'Acquisition.ReadyForCapture';
                    setAppViewState(app, app.CurrentState)
            end
        end
        
        function data = storeDataInFIFO(~, data, buffersize, datablock)
        %storeDataInFIFO Store continuous acquisition data in a FIFO data buffer
        %  Storing data in a finite-size FIFO buffer is used to plot the latest "N" seconds of acquired data for
        %  a smooth live plot update and without continuously increasing memory use.
        %  The most recently acquired data (datablock) is added to the buffer and if the amount of data in the
        %  buffer exceeds the specified buffer size (buffersize) the oldest data is discarded to cap the size of
        %  the data in the buffer to buffersize.
        %  input data is the existing data buffer (column vector Nx1).
        %  buffersize is the desired buffer size (maximum number of rows in data buffer) and can be changed.
        %  datablock is a new data block to be added to the buffer (column vector Kx1).
        %  output data is the updated data buffer (column vector Mx1).
        
            % If the data size is greater than the buffer size, keep only the
            % the latest "buffer size" worth of data
            % This can occur if the buffer size is changed to a lower value during acquisition
            if size(data,1) > buffersize
                data = data(end-buffersize+1:end,:);
            end
            
            if size(datablock,1) < buffersize
                % Data block size (number of rows) is smaller than the buffer size
                if size(data,1) == buffersize
                    % Current data size is already equal to buffer size.
                    % Discard older data and append new data block,
                    % and keep data size equal to buffer size.
                    shiftPosition = size(datablock,1);
                    data = circshift(data,-shiftPosition);
                    data(end-shiftPosition+1:end,:) = datablock;
                elseif (size(data,1) < buffersize) && (size(data,1)+size(datablock,1) > buffersize)
                    % Current data size is less than buffer size and appending the new
                    % data block results in a size greater than the buffer size.
                    data = [data; datablock];
                    shiftPosition = size(data,1) - buffersize;
                    data = circshift(data,-shiftPosition);
                    data(buffersize+1:end, :) = [];
                else
                    % Current data size is less than buffer size and appending the new
                    % data block results in a size smaller than or equal to the buffer size.
                    % (if (size(data,1) < buffersize) && (size(data,1)+size(datablock,1) <= buffersize))
                    data = [data; datablock];
                end
            else
                % Data block size (number of rows) is larger than or equal to buffer size
                data = datablock(end-buffersize+1:end,:);
            end
            
        end
        
        function [items, itemsData] = getChannelPropertyOptions(~, subsystem, propertyName)
        %getChannelPropertyOptions Get options available for a DAQ channel property
        %  Returns items and itemsData for displaying options in a dropdown component.
        %   subsystem is the DAQ subsystem handle corresponding to the DAQ channel.
        %   propertyName is a channel property name as a character array, and can be
        %    'TerminalConfig', 'Coupling', or 'Range'.
        %   items is a cell array of possible property values, for example {'DC', 'AC'}.
        %   itemsData is [] (empty) for 'TerminalConfig' and 'Coupling', and is a cell array of
        %     available ranges for 'Range', for example {[-10 10], [-1 1]}.
            
            switch propertyName
                case 'TerminalConfig'
                    items = cellstr(string(subsystem.TerminalConfigsAvailable));
                    itemsData = [];
                case 'Coupling'
                    items = cellstr(string(subsystem.CouplingsAvailable));
                    itemsData = [];
                case 'Range'
                    numRanges = numel(subsystem.RangesAvailable);
                    items = strings(numRanges,1);
                    itemsData = cell(numRanges,1);
                    for ii = 1:numRanges
                        range = subsystem.RangesAvailable(ii);
                        items(ii) = sprintf('%.2f to %.2f', range.Min, range.Max);
                        itemsData{ii} = [range.Min range.Max];
                    end
                    items = cellstr(items);                    
                case 'ExcitationSource'
                    items = {'Internal','External','None'};
                    itemsData = [];
            end
        end
        
        
        function setAppViewState(app, state)
        %setAppViewState Sets the app in a new state and enables/disables corresponding components
        %  state can be 'DevicesSlection', 'Configuration', 'Acquisition.Buffering', 
        %   'Acquisition.ReadyForCapture', 'Capture.LookingForTrigger', 
        %   'Capture.CapturingData', or 'Capture.CaptureComplete'.
        
            switch state                
                case 'DeviceSelection'
                    app.RateEdit.Enable = 'off';
                    app.RateSlider.Enable = 'off';
                    app.DeviceDropDown.Enable = 'on';
                    app.ChannelDropDown.Enable = 'off';
                    app.MeasurementTypeDropDown.Enable = 'off';
                    app.RangeDropDown.Enable = 'off';
                    app.TerminalConfigDropDown.Enable = 'off';
                    app.CouplingDropDown.Enable = 'off';
                    app.StartButton.Enable = 'off';
                    app.ExcitationSourceDropDown.Enable = 'off';
                    app.StopButton.Enable = 'off';
                    app.TimeWindowEditField.Enable = 'off';
                    app.CaptureButton.Enable = 'off';
                    app.AutoscaleYSwitch.Enable = 'off';
                    app.TriggerDelayEditField.Enable = 'off';
                    app.CaptureDurationEditField.Enable = 'off';
                    
                case 'Configuration'
                    app.RateEdit.Enable = 'on';
                    app.RateSlider.Enable = 'on';
                    app.DeviceDropDown.Enable = 'on';
                    app.ChannelDropDown.Enable = 'on';
                    app.MeasurementTypeDropDown.Enable = 'on';
                    app.RangeDropDown.Enable = 'on';
                    app.StartButton.Enable = 'on';
                    app.StopButton.Enable = 'off';
                    app.TimeWindowEditField.Enable = 'on';
                    app.CaptureButton.Enable = 'off';
                    app.CaptureButton.Value = 0;
                    app.StatusText.Text = '';
                    app.CaptureButton.Text = 'Capture';
                    app.AutoscaleYSwitch.Enable = 'on';
                    app.TriggerDelayEditField.Enable = 'off';
                    app.CaptureDurationEditField.Enable = 'off';

                    switch app.MeasurementTypeDropDown.Value
                        case 'Voltage'
                            % Voltage channels do not have ExcitationSource
                            % property, so disable the corresponding UI controls
                            app.TerminalConfigDropDown.Enable = 'on';
                            app.CouplingDropDown.Enable = 'on';
                            app.ExcitationSourceDropDown.Enable = 'off';
                        case 'Audio'
                            % Audio channels do not have TerminalConfig, Coupling, and ExcitationSource
                            % properties, so disable the corresponding UI controls
                            app.TerminalConfigDropDown.Enable = 'off';
                            app.CouplingDropDown.Enable = 'off';
                            app.ExcitationSourceDropDown.Enable = 'off';
                        case 'IEPE'
                            app.TerminalConfigDropDown.Enable = 'on';
                            app.CouplingDropDown.Enable = 'on';
                            app.ExcitationSourceDropDown.Enable = 'on';
                    end

                case 'Acquisition.Buffering'
                    app.RateEdit.Enable = 'off';
                    app.RateSlider.Enable = 'off';
                    app.DeviceDropDown.Enable = 'off';
                    app.ChannelDropDown.Enable = 'off';
                    app.MeasurementTypeDropDown.Enable = 'off';
                    app.RangeDropDown.Enable = 'off';
                    app.TerminalConfigDropDown.Enable = 'off';
                    app.CouplingDropDown.Enable = 'off';
                    app.ExcitationSourceDropDown.Enable = 'off';
                    app.StartButton.Enable = 'off';
                    app.StopButton.Enable = 'on';
                    app.TimeWindowEditField.Enable = 'on';
                    app.CaptureButton.Enable = 'off';
                    app.TriggerDelayEditField.Enable = 'on';
                    app.CaptureDurationEditField.Enable = 'on';
                    app.StatusText.Text = 'Buffering pre-trigger data...';
                    
                case 'Acquisition.ReadyForCapture'
                    app.CaptureButton.Enable = 'on';
                    app.TriggerDelayEditField.Enable = 'on';
                    app.CaptureDurationEditField.Enable = 'on';
                    app.StatusText.Text = 'Ready for capture';
                    app.TrigActive = 0;
                    app.CaptureButton.Text = 'Capture';
                    app.CaptureButton.Value = 0;
                    
                case 'Capture.LookingForTrigger'
                    app.StatusText.Text = 'Waiting for trigger';
                    app.TriggerDelayEditField.Enable = 'off';
                    app.CaptureDurationEditField.Enable = 'off';
                    app.CaptureButton.Text = 'Cancel capture';
                    
                case 'Capture.CapturingData'
                    app.StatusText.Text = 'Trigger detected. Capturing';

                case 'Capture.CaptureComplete'
                    app.StatusText.Text = 'Capture completed';
                    
            end
        end
        
        function deviceinfo = daqListSupportedDevices(app, subsystemTypes, measurementTypes)
        %daqListSupportedDevices Get connected devices that support the specified subsystem and measurement types      
            
            % Detect all connected devices
            devices = daqlist;
            deviceinfo = devices.DeviceInfo;
            
            % Keep a subset of devices which have the specified subystem and measurement types
            deviceinfo = daqFilterDevicesBySubsystem(app, deviceinfo, subsystemTypes);
            deviceinfo = daqFilterDevicesByMeasurement(app, deviceinfo, measurementTypes);
            
        end
                
        function filteredDevices = daqFilterDevicesBySubsystem(~, devices, subsystemTypes)
        %daqFilterDevicesBySubsystem Filter DAQ device array by subsystem type
        %  devices is a DAQ device info array
        %  subsystemTypes is a cell array of DAQ subsystem types, for example {'AnalogInput, 'AnalogOutput'}
        %  filteredDevices is the filtered DAQ device info array
            
            % Logical array indicating if device has any of the subsystem types provided
            hasSubsystemArray = false(numel(devices), 1);
            
            % Go through each device and see if it has any of the subsystem types provided
            for ii = 1:numel(devices)
                hasSubsystem = false;
                for jj = 1:numel(subsystemTypes)
                    hasSubsystem = hasSubsystem || ...
                        any(strcmp({devices(ii).Subsystems.SubsystemType}, subsystemTypes{jj}));
                end
                hasSubsystemArray(ii) = hasSubsystem;
            end
            filteredDevices = devices(hasSubsystemArray);
        end
        
        
        function filteredDevices = daqFilterDevicesByMeasurement(~, devices, measurementTypes)
        %daqFilterDevicesByMeasurement Filter DAQ device array by measurement type
        %  devices is a DAQ device info array
        %  measurementTypes is a cell array of measurement types, for example {'Voltage, 'Current'}
        %  filteredDevices is the filtered DAQ device info array
            
            % Logical array indicating if device has any of the measurement types provided
            hasMeasurementArray = false(numel(devices), 1);
            
            % Go through each device and subsystem and see if it has any of the measurement types provided
            for ii = 1:numel(devices)
                % Get array of available subsystems for the current device
                subsystems = [devices(ii).Subsystems];
                hasMeasurement = false;
                for jj = 1:numel(subsystems)
                    % Get cell array of available measurement types for the current subsystem
                    measurements = subsystems(jj).MeasurementTypesAvailable;
                    for kk = 1:numel(measurementTypes)
                        hasMeasurement = hasMeasurement || ...
                            any(strcmp(measurements, measurementTypes{kk}));
                    end
                end
                hasMeasurementArray(ii) = hasMeasurement;
            end
            filteredDevices = devices(hasMeasurementArray);
        end
        
        
        function updateRateUIComponents(app)
        %updateRateUIComponents Updates UI with current rate and time window limits
            
            % Update UI to show the actual DAQ rate and limits
            value = app.DAQ.Rate;
            app.RateEdit.Limits = app.DAQ.RateLimit;
            app.RateSlider.Limits = app.DAQ.RateLimit;
            app.RateSlider.MajorTicks = [app.DAQ.RateLimit(1) app.DAQ.RateLimit(2)];
            app.RateSlider.MinorTicks = [];
            app.RateEdit.Value = value;
            app.RateSlider.Value = value;
            
            % Update time window limits
            % Minimum time window shows 2 samples
            % Maximum time window corresponds to the maximum specified FIFO buffer size
            minTimeWindow = 1/value;
            maxTimeWindow = app.FIFOMaxSize / value;
            app.TimeWindowEditField.Limits = [minTimeWindow, maxTimeWindow];
            
            app.CallbackTimeSpan = double(app.DAQ.ScansAvailableFcnCount)/app.DAQ.Rate;
            
            % Set limits for entry fields
            app.CaptureDurationEditField.Limits = [minTimeWindow, maxTimeWindow];
            app.TriggerDelayEditField.Limits = [-maxTimeWindow, app.TriggerDelayMax];
            
            % Calculate required FIFO data buffer size
            app.BufferSize = calculateBufferSize(app, app.CallbackTimeSpan, ...
                app.TimeWindowEditField.Value, app.TriggerDelayEditField.Value, ...
                app.CaptureDurationEditField.Value, app.DAQ.Rate);
            
        end
        
        
        function closeApp_Callback(app, ~, event, isAcquiring)
        %closeApp_Callback Clean-up after "Close Confirm" dialog window
        %  "Close Confirm" dialog window is called from CloseRequestFcn
        %  of the app UIFigure.
        %   event is the event data of the UIFigure CloseRequestFcn callback.
        %   isAcquiring is a logical flag (true/false) corresponding to DAQ
        %   running state.
        
            switch event.SelectedOption
                case 'OK'
                    if isAcquiring
                        % Acquisition is currently on
                        stop(app.DAQ)
                        delete(app.DAQ)
                    else
                        % Acquisition is stopped
                    end

                    delete(app)
                case 'Cancel'
                    % Continue
            end
        end
        
        function [trigDetected, trigMoment] = trigDetect(~, timestamps, data, trigConfig)
        %trigDetect Detect if trigger event condition is met in acquired data
        %   [trigDetected, trigMoment] = trigDetect(app, data, trigConfig)
        %   Returns a detection flag (trigDetected) and the corresponding data point index
        %   (trigMoment) of the first data point which meets the trigger condition
        %   based on signal level and condition specified by the trigger parameters
        %   structure (trigConfig).
        %   The input data (data) is an M x N matrix corresponding to M acquired
        %   data scans from N channels.
        %   trigConfig.Channel = index of trigger channel in DAQ channels
        %   trigConfig.Level   = signal trigger level
        %   trigConfig.Condition = trigger condition ('Rising' or 'Falling')
            
            switch trigConfig.Condition
                case 'Rising'
                    % Logical array condition for signal trigger level
                    trigConditionMet = data(:, trigConfig.Channel) > trigConfig.Level;
                case 'Falling'
                    % Logical array condition for signal trigger level
                    trigConditionMet = data(:, trigConfig.Channel) < trigConfig.Level;
            end
            
            trigDetected = any(trigConditionMet) & ~all(trigConditionMet);
            trigMoment = [];
            if trigDetected
                % Find time moment when trigger condition has been met
                trigMomentIndex = 1 + find(diff(trigConditionMet)==1, 1, 'first');
                trigMoment = timestamps(trigMomentIndex);
            end
        end
    
        function completeCapture(app)
        %completeCapture Saves captured data to workspace variable and plots it
            
            % Find index of first sample in data buffer to be captured
            firstSampleIndex = find(app.TimestampsFIFOBuffer >= app.CaptureStartMoment, 1, 'first');
            
            % Find index of last sample in data buffer that complete the capture
            lastSampleIndex = firstSampleIndex + round(app.CaptureDurationEditField.Value * app.DAQ.Rate);
            if isempty(firstSampleIndex) || isempty(lastSampleIndex) || lastSampleIndex > size(app.TimestampsFIFOBuffer, 1)
                % Something went wrong
                % Abort capture
                app.StatusText.Text = 'Capture error';
                app.CaptureButton.Value = 0;
                uialert(app.AnalogTriggerAppExampleUIFigure, 'Could not complete capture.', 'Capture error');
                return
            end
            
            % Extract capture data and shift timestamps so that 0 corresponds to the trigger moment
            app.CaptureData = app.DataFIFOBuffer(firstSampleIndex:lastSampleIndex);
            app.CaptureTimestamps = app.TimestampsFIFOBuffer(firstSampleIndex:lastSampleIndex, :) - app.TrigMoment;
            
            % Update captured data plot (one line for each acquisition channel)
            set(app.CapturePlotLine, 'XData', app.CaptureTimestamps, 'YData', app.CaptureData);
            app.CaptureDataAxes.XLim = [min(app.CaptureTimestamps), max(app.CaptureTimestamps)];
            
            % Save captured data to a base workspace variable
            % For simplicity, validation of user input and checking whether a variable
            % with the same name already exists are not addressed in this example.
            % Get the variable name from UI text input
            varName = genvarname(app.VariableNameEditField.Value);
            captureData = timetable(seconds(app.CaptureTimestamps), app.CaptureData, 'VariableNames', {varName});
            
            % Use assignin function to save the captured data in a base workspace variable
            assignin('base', varName, captureData);
            
        end
        
        function [buffersize, bufferTimeSpan] = calculateBufferSize(~, callbackTimeSpan, liveViewTimeSpan, triggerDelay, captureDuration, rate)
        %calculateBufferSize Calculates the required FIFO data buffer size 
        %  callbackTimeSpan is the wall-clock timespan (seconds) of the data read in the DAQ ScansAvailable callback function.
        %  liveViewTimeSpan is the wall-clock timespan (seconds) of the DAQ data in the live view plot.
        %  triggerDelay is the trigger delay (seconds).
        %  captureDuration is the total capture duration (seconds).
        %  rate is the DAQ acquisition rate (scans/second).
        %  buffersize is the calculated buffer size (number of scans).
        %  bufferTimeSpan is the wall-clock timespan (seconds) corresponding to <buffersize> scans.       
        
            if triggerDelay < 0
                bufferTimeSpan = max([abs(triggerDelay), captureDuration, liveViewTimeSpan]);
            else
                bufferTimeSpan = max([captureDuration, liveViewTimeSpan]);
            end
            bufferTimeSpan = bufferTimeSpan + 2*callbackTimeSpan;
            buffersize = ceil(rate * bufferTimeSpan) + 1;
        end
        

        function results = isEnoughDataBuffered(app)
        %isEnoughDataBuffered Checks whether buffering pre-trigger data is complete    
       
            % If specified trigger delay is less than 0, need to check
            % whether enough pre-trigger data is buffered so that a
            % triggered capture can be requested
            results = (app.TriggerDelay >= 0) || ...
                (size(app.TimestampsFIFOBuffer,1) > ceil(abs(app.TriggerDelay)*app.DAQ.Rate));
            
        end
        
        function detectTrigger(app)
        %detectTrigger Detects trigger condition and updates relevant app properties
        % Updates TrigActive, TrigMoment, and CaptureStartMoment app properties
            
            trigConfig.Channel = 1;
            trigConfig.Level = app.TriggerLevelEditField.Value;
            trigConfig.Condition = app.TriggerConditionDropDown.Value;
            [app.TrigActive, app.TrigMoment] = ...
                trigDetect(app, app.Timestamps, app.Data, trigConfig);
            app.CaptureStartMoment = app.TrigMoment + app.TriggerDelay;
        end
        
        function results = isEnoughDataCaptured(app)
        %isEnoughDataCaptured Check whether captured-data duration exceeds specified capture duration

            results = (app.TimestampsFIFOBuffer(end,1)-app.CaptureStartMoment) > app.CaptureDuration;
        end
        
        function results = doesTriggerDelayChangeRequireBuffering(app)
        
            value = app.TriggerDelayEditField.Value;
            if value < 0 && size(app.TimestampsFIFOBuffer,1) < ceil(abs(value)*app.DAQ.Rate)
                results = true;
            else
                results = false;
            end            
        end
        
        function updateChannelMeasurementComponents(app)
        %updateChannelMeasurementComponents Updates channel properties and measurement UI components
            measurementType = app.MeasurementTypeDropDown.Value;

            % Get selected DAQ device index (to be used with DaqDevicesInfo list)
            deviceIndex = app.DeviceDropDown.Value - 1;
            deviceID = app.DevicesInfo(deviceIndex).ID;
            vendor = app.DevicesInfo(deviceIndex).Vendor.ID;
                        
            % Get DAQ subsystem information (analog input or audio input)
            % Analog input or analog output subsystems are the first subsystem of the device
            subsystem = app.DevicesInfo(deviceIndex).Subsystems(1);
            
            % Delete existing DAQ object
            delete(app.DAQ);
            app.DAQ = [];
            
            % Create a new data acquisition object
            d = daq(vendor);
            addinput(d, deviceID, app.ChannelDropDown.Value, measurementType);
            
            % Configure DAQ ScansAvailableFcn callback function
            d.ScansAvailableFcn = @(src,event) scansAvailable_Callback(app, src, event);
            
            % Store DAQ object handle in an app property
            app.DAQ = d;

            % Depending on what device and measurement are selected, populate the UI channel properties
            switch subsystem.SubsystemType
                case 'AnalogInput'
                                        
                    % Populate dropdown with available channel 'TerminalConfig' options
                    app.TerminalConfigDropDown.Items = getChannelPropertyOptions(app, subsystem, 'TerminalConfig');
                    % Update UI with the actual channel property value
                    % (default value is not necessarily first in the list)
                    % DropDown Value must be set as a character array in MATLAB R2017b
                    app.TerminalConfigDropDown.Value = d.Channels(1).TerminalConfig;
                    app.TerminalConfigDropDown.Tag = 'TerminalConfig';
                    
                    % Populate dropdown with available channel 'Coupling' options
                    app.CouplingDropDown.Items =  getChannelPropertyOptions(app, subsystem, 'Coupling');
                    % Update UI with the actual channel property value
                    app.CouplingDropDown.Value = d.Channels(1).Coupling;
                    app.CouplingDropDown.Tag = 'Coupling';
                                        
                    switch measurementType
                        case 'IEPE'
                            % Populate dropdown with available channel 'ExcitationSource' options
                            app.ExcitationSourceDropDown.Items = getChannelPropertyOptions(app, subsystem, 'ExcitationSource');
                            app.ExcitationSourceDropDown.Value = d.Channels(1).ExcitationSource;
                            app.ExcitationSourceDropDown.Tag = 'ExcitationSource';
                        case 'Voltage'
                            app.ExcitationSourceDropDown.Items = {''};
                    end
                    
                    ylabel(app.LiveDataAxes, 'Voltage (V)')
                    ylabel(app.CaptureDataAxes, 'Voltage (V)')
                                        
                case 'AudioInput'
                    ylabel(app.LiveDataAxes, 'Normalized amplitude')
                    ylabel(app.CaptureDataAxes, 'Normalized amplitude')
            end
            
            % Update UI with current rate and time window limits
            updateRateUIComponents(app)
                    
            % Populate dropdown with available 'Range' options
            [rangeItems, rangeItemsData] = getChannelPropertyOptions(app, subsystem, 'Range');
            app.RangeDropDown.Items = rangeItems;
            app.RangeDropDown.ItemsData = rangeItemsData;
            
            % Update UI with current channel 'Range'
            currentRange = d.Channels(1).Range;
            app.RangeDropDown.Value = [currentRange.Min currentRange.Max];
            app.RangeDropDown.Tag = 'Range';

            app.DeviceDropDown.Items{1} = 'Deselect device';
                        
            % Configure the app view for device configuration state
            app.CurrentState = 'Configuration';
            setAppViewState(app, app.CurrentState);    
        end
        
        function updateAutoscaleYSwitchComponents(app)
        %updateAutoscaleYSwitchComponents Updates UI components related to y-axis autoscale
        
            value = app.AutoscaleYSwitch.Value;
            switch value
                case 'On'
                    app.LiveDataAxes.YLimMode = 'auto';
                case 'Off'
                    app.LiveDataAxes.YLim = app.RangeDropDown.Value * 1.2;
            end
        end
        

    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)

            % Configure the app view for device selection state
            app.CurrentState = 'DeviceSelection';
            setAppViewState(app, app.CurrentState);
            
            % Get connected devices that have the supported subsystem and measurement types
            deviceinfo = daqListSupportedDevices(app, app.DAQSubsystemTypes, app.DAQMeasurementTypes);
            
            % Store DAQ device information (filtered list) into DaqDevicesInfo app property
            % This is used by other functions in the app
            app.DevicesInfo = deviceinfo;
            
            % Populate the device drop down list with cell array of composite device names (ID + model)
            % First element is "Select a device"
            deviceDescriptions = cellstr(string({deviceinfo.ID}') + " [" + string({deviceinfo.Model}') + "]");
            app.DeviceDropDown.Items = ['Select a device'; deviceDescriptions];
            
            % Assign dropdown ItemsData to correspond to device index + 1
            % (first item is not a device)
            app.DeviceDropDown.ItemsData = 1:numel(deviceinfo)+1;           
            
            % Create a line plot and store its handle in LivePlot app property
            % This is used for updating the live plot from scansAvailable_Callback function
            app.LivePlotLine = plot(app.LiveDataAxes, NaN, NaN);

            app.CapturePlotLine = plot(app.CaptureDataAxes, NaN, NaN);

            % Turn off axes toolbar and data tips for live plot axes
            app.LiveDataAxes.Toolbar.Visible = 'off';
            disableDefaultInteractivity(app.LiveDataAxes);
            
            
        end

        % Changes arrangement of the app based on UIFigure width
        function updateAppLayout(app, event)
            currentFigureWidth = app.AnalogTriggerAppExampleUIFigure.Position(3);
            if(currentFigureWidth <= app.onePanelWidth)
                % Change to a 3x1 grid
                app.GridLayout.RowHeight = {552, 552, 552};
                app.GridLayout.ColumnWidth = {'1x'};
                app.CenterPanel.Layout.Row = 1;
                app.CenterPanel.Layout.Column = 1;
                app.LeftPanel.Layout.Row = 2;
                app.LeftPanel.Layout.Column = 1;
                app.RightPanel.Layout.Row = 3;
                app.RightPanel.Layout.Column = 1;
            elseif (currentFigureWidth > app.onePanelWidth && currentFigureWidth <= app.twoPanelWidth)
                % Change to a 2x2 grid
                app.GridLayout.RowHeight = {552, 552};
                app.GridLayout.ColumnWidth = {'1x', '1x'};
                app.CenterPanel.Layout.Row = 1;
                app.CenterPanel.Layout.Column = [1,2];
                app.LeftPanel.Layout.Row = 2;
                app.LeftPanel.Layout.Column = 1;
                app.RightPanel.Layout.Row = 2;
                app.RightPanel.Layout.Column = 2;
            else
                % Change to a 1x3 grid
                app.GridLayout.RowHeight = {'1x'};
                app.GridLayout.ColumnWidth = {269, '1x', 243};
                app.LeftPanel.Layout.Row = 1;
                app.LeftPanel.Layout.Column = 1;
                app.CenterPanel.Layout.Row = 1;
                app.CenterPanel.Layout.Column = 2;
                app.RightPanel.Layout.Row = 1;
                app.RightPanel.Layout.Column = 3;
            end
        end

        % Button pushed function: StartButton
        function StartButtonPushed(app, event)
                           
           
            % Reset FIFO buffer data
            app.DataFIFOBuffer = [];
            app.TimestampsFIFOBuffer = [];

            % Reset Data and Timestamps
            app.Data = [];
            app.Timestamps = [];

            try
                start(app.DAQ,'continuous');
                
                % Configure the app for Acquisition state
                app.CurrentState = 'Acquisition.Buffering';
                setAppViewState(app, app.CurrentState);
                                
                updateAutoscaleYSwitchComponents(app)                
            catch exception
                uialert(app.AnalogTriggerAppExampleUIFigure, exception.message, 'Start error');   
            end
        end

        % Button pushed function: StopButton
        function StopButtonPushed(app, event)
            
            stop(app.DAQ);
            
            % Configure the app for device configuration state
            app.CurrentState = 'Configuration';
            setAppViewState(app, app.CurrentState);
        end

        % Value changed function: DeviceDropDown
        function DeviceDropDownValueChanged(app, event)
            value = app.DeviceDropDown.Value;
            
            if ~isempty(value)
                % Device index is offset by 1 because first element in device dropdown
                % is "Select a device" (not a device).
                deviceIndex = value-1 ;
                
                % Reset channel property options
                app.ChannelDropDown.Items = {''};
                app.MeasurementTypeDropDown.Items = {''};
                app.RangeDropDown.Items = {''};
                app.TerminalConfigDropDown.Items = {''};
                app.CouplingDropDown.Items = {''};
                app.ExcitationSourceDropDown.Items = {''};
                setAppViewState(app, 'DeviceSelection');

                
                % Delete DAQ object, as a new one will be created for the newly selected device
                delete(app.DAQ);
                app.DAQ = [];
                
                if deviceIndex > 0
                    % If a device is selected
                    
                    % Get subsystem information to update channel dropdown list and channel property options
                    % For devices that have an analog input or an audio input subsystem, this is the first subsystem
                    subsystem = app.DevicesInfo(deviceIndex).Subsystems(1);
                    app.ChannelDropDown.Items = cellstr(string(subsystem.ChannelNames));
                    
                    % Populate available measurement types for the selected device
                    app.MeasurementTypeDropDown.Items = intersect(app.DAQMeasurementTypes,...
                                subsystem.MeasurementTypesAvailable, 'stable');

                    % Update channel and channel property options
                    updateChannelMeasurementComponents(app)

                else
                    % If no device is selected

                    % Delete existing DAQ object
                    delete(app.DAQ);
                    app.DAQ = [];
                    
                    app.DeviceDropDown.Items{1} = 'Select a device';
                    
                    % Configure the app view for device selection state
                    app.CurrentState = 'DeviceSelection';
                    setAppViewState(app, app.CurrentState);
                end
            end            
        end

        % Value changed function: ChannelDropDown
        function ChannelDropDownValueChanged(app, event)
            
            updateChannelMeasurementComponents(app)
        end

        % Value changed function: MeasurementTypeDropDown
        function MeasurementTypeDropDownValueChanged(app, event)

            updateChannelMeasurementComponents(app)
        end

        % Value changed function: RateEdit, RateSlider
        function RateSliderValueChanged(app, event)
        % Shared callback for RateSlider and RateEdit
            
            value = event.Source.Value;
            app.DAQ.Rate = value;
            
            % Update UI with current rate and time window limits
            updateRateUIComponents(app)
        end

        % Value changing function: RateSlider
        function RateSliderValueChanging(app, event)
            changingValue = event.Value;
            app.RateEdit.Value = changingValue;            
        end

        % Value changed function: AutoscaleYSwitch
        function AutoscaleYSwitchValueChanged(app, event)
            updateAutoscaleYSwitchComponents(app)
        end

        % Value changed function: CouplingDropDown, 
        % ExcitationSourceDropDown, RangeDropDown, TerminalConfigDropDown
        function ChannelPropertyValueChanged(app, event)

            % Shared callback for RangeDropDown, TerminalConfigDropDown, CouplingDropDown, and ExcitationSourceDropDown.
            % This executes only for 'Voltage' measurement type, since for 'Audio' measurement
            % type Range never changes, and TerminalConfig and Coupling are disabled.
            
            value = event.Source.Value;
            
            % Set channel property to selected value
            % The channel property name was previously stored in the UI component Tag
            propertyName = event.Source.Tag;
            try
                set(app.DAQ.Channels(1), propertyName, value);
            catch exception
                % In case of error show it and revert the change
                uialert(app.AnalogTriggerAppExampleUIFigure, exception.message, 'Channel property error');
                event.Source.Value = event.PreviousValue;
            end
            
            % Make sure shown channel property values are not stale, as some property update can trigger changes in other properties
            % Update UI with current channel property values from DAQ 
            currentRange = app.DAQ.Channels(1).Range;
            app.RangeDropDown.Value = [currentRange.Min currentRange.Max];
            app.TerminalConfigDropDown.Value = app.DAQ.Channels(1).TerminalConfig;
            app.CouplingDropDown.Value = app.DAQ.Channels(1).Coupling;            
        end

        % Value changed function: CaptureDurationEditField, 
        % TimeWindowEditField, TriggerDelayEditField
        function TriggerDelayEditFieldValueChanged(app, event)
            
            % Recalculate the FIFO data buffer size
            app.BufferSize = calculateBufferSize(app, app.CallbackTimeSpan, ...
                app.TimeWindowEditField.Value, app.TriggerDelayEditField.Value, ...
                app.CaptureDurationEditField.Value, app.DAQ.Rate);
                
            % Check whether this callback execution is for TriggerDelayEditField
            if event.Source == app.TriggerDelayEditField
                value = event.Source.Value;
                if value < 0 && size(app.TimestampsFIFOBuffer,1) < ceil(abs(value)*app.DAQ.Rate)
                    app.CurrentState = 'Acquisition.Buffering';
                    setAppViewState(app, app.CurrentState);
                end
            end
        end

        % Close request function: AnalogTriggerAppExampleUIFigure
        function AnalogTriggerAppExampleUIFigureCloseRequest(app, event)
            
            isAcquiring = app.TrigActive;
            if app.TrigActive
                question = 'Abort capture and close app?';
            else
                % Capture is not active
                question = 'Close app?';
            end
            
            uiconfirm(app.AnalogTriggerAppExampleUIFigure,question,'Confirm Close',...
                'CloseFcn',@(src,event) closeApp_Callback(app,src,event,isAcquiring));
        end

        % Value changed function: CaptureButton
        function CaptureButtonValueChanged(app, event)
            value = app.CaptureButton.Value;
            if ~value
                % Capture cancelled
                app.CurrentState = 'Acquisition.ReadyForCapture';
                setAppViewState(app, app.CurrentState);
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create AnalogTriggerAppExampleUIFigure and hide until all components are created
            app.AnalogTriggerAppExampleUIFigure = uifigure('Visible', 'off');
            app.AnalogTriggerAppExampleUIFigure.AutoResizeChildren = 'off';
            app.AnalogTriggerAppExampleUIFigure.Position = [100 100 1002 552];
            app.AnalogTriggerAppExampleUIFigure.Name = 'Analog Trigger App Example';
            app.AnalogTriggerAppExampleUIFigure.CloseRequestFcn = createCallbackFcn(app, @AnalogTriggerAppExampleUIFigureCloseRequest, true);
            app.AnalogTriggerAppExampleUIFigure.SizeChangedFcn = createCallbackFcn(app, @updateAppLayout, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.AnalogTriggerAppExampleUIFigure);
            app.GridLayout.ColumnWidth = {269, '1x', 243};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Scrollable = 'on';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create DeviceLabel
            app.DeviceLabel = uilabel(app.LeftPanel);
            app.DeviceLabel.HorizontalAlignment = 'right';
            app.DeviceLabel.Position = [14 418 42 22];
            app.DeviceLabel.Text = 'Device';

            % Create DeviceDropDown
            app.DeviceDropDown = uidropdown(app.LeftPanel);
            app.DeviceDropDown.Items = {'Detecting devices...'};
            app.DeviceDropDown.ValueChangedFcn = createCallbackFcn(app, @DeviceDropDownValueChanged, true);
            app.DeviceDropDown.Position = [71 418 175 22];
            app.DeviceDropDown.Value = 'Detecting devices...';

            % Create ChannelLabel
            app.ChannelLabel = uilabel(app.LeftPanel);
            app.ChannelLabel.HorizontalAlignment = 'right';
            app.ChannelLabel.Position = [81 378 50 22];
            app.ChannelLabel.Text = 'Channel';

            % Create ChannelDropDown
            app.ChannelDropDown = uidropdown(app.LeftPanel);
            app.ChannelDropDown.Items = {};
            app.ChannelDropDown.ValueChangedFcn = createCallbackFcn(app, @ChannelDropDownValueChanged, true);
            app.ChannelDropDown.Position = [146 378 100 22];
            app.ChannelDropDown.Value = {};

            % Create MeasurementTypeLabel
            app.MeasurementTypeLabel = uilabel(app.LeftPanel);
            app.MeasurementTypeLabel.HorizontalAlignment = 'right';
            app.MeasurementTypeLabel.Position = [23 338 108 22];
            app.MeasurementTypeLabel.Text = 'Measurement Type';

            % Create MeasurementTypeDropDown
            app.MeasurementTypeDropDown = uidropdown(app.LeftPanel);
            app.MeasurementTypeDropDown.Items = {};
            app.MeasurementTypeDropDown.ValueChangedFcn = createCallbackFcn(app, @MeasurementTypeDropDownValueChanged, true);
            app.MeasurementTypeDropDown.Position = [146 338 100 22];
            app.MeasurementTypeDropDown.Value = {};

            % Create RangeLabel
            app.RangeLabel = uilabel(app.LeftPanel);
            app.RangeLabel.HorizontalAlignment = 'right';
            app.RangeLabel.Position = [90 298 41 22];
            app.RangeLabel.Text = 'Range';

            % Create RangeDropDown
            app.RangeDropDown = uidropdown(app.LeftPanel);
            app.RangeDropDown.Items = {};
            app.RangeDropDown.ValueChangedFcn = createCallbackFcn(app, @ChannelPropertyValueChanged, true);
            app.RangeDropDown.Position = [146 298 100 22];
            app.RangeDropDown.Value = {};

            % Create CouplingLabel
            app.CouplingLabel = uilabel(app.LeftPanel);
            app.CouplingLabel.HorizontalAlignment = 'right';
            app.CouplingLabel.Position = [78 258 53 22];
            app.CouplingLabel.Text = 'Coupling';

            % Create CouplingDropDown
            app.CouplingDropDown = uidropdown(app.LeftPanel);
            app.CouplingDropDown.Items = {};
            app.CouplingDropDown.ValueChangedFcn = createCallbackFcn(app, @ChannelPropertyValueChanged, true);
            app.CouplingDropDown.Position = [146 258 100 22];
            app.CouplingDropDown.Value = {};

            % Create TerminalConfigLabel
            app.TerminalConfigLabel = uilabel(app.LeftPanel);
            app.TerminalConfigLabel.HorizontalAlignment = 'right';
            app.TerminalConfigLabel.Position = [39 218 92 22];
            app.TerminalConfigLabel.Text = 'Terminal Config.';

            % Create TerminalConfigDropDown
            app.TerminalConfigDropDown = uidropdown(app.LeftPanel);
            app.TerminalConfigDropDown.Items = {};
            app.TerminalConfigDropDown.ValueChangedFcn = createCallbackFcn(app, @ChannelPropertyValueChanged, true);
            app.TerminalConfigDropDown.Position = [146 218 100 22];
            app.TerminalConfigDropDown.Value = {};

            % Create ExcitationSourceLabel
            app.ExcitationSourceLabel = uilabel(app.LeftPanel);
            app.ExcitationSourceLabel.HorizontalAlignment = 'right';
            app.ExcitationSourceLabel.Position = [32 178 99 22];
            app.ExcitationSourceLabel.Text = 'Excitation Source';

            % Create ExcitationSourceDropDown
            app.ExcitationSourceDropDown = uidropdown(app.LeftPanel);
            app.ExcitationSourceDropDown.Items = {};
            app.ExcitationSourceDropDown.ValueChangedFcn = createCallbackFcn(app, @ChannelPropertyValueChanged, true);
            app.ExcitationSourceDropDown.Position = [146 178 100 22];
            app.ExcitationSourceDropDown.Value = {};

            % Create RatescanssLabel
            app.RatescanssLabel = uilabel(app.LeftPanel);
            app.RatescanssLabel.HorizontalAlignment = 'right';
            app.RatescanssLabel.Position = [48 117 83 22];
            app.RatescanssLabel.Text = 'Rate (scans/s)';

            % Create RateEdit
            app.RateEdit = uieditfield(app.LeftPanel, 'numeric');
            app.RateEdit.ValueDisplayFormat = '%.1f';
            app.RateEdit.ValueChangedFcn = createCallbackFcn(app, @RateSliderValueChanged, true);
            app.RateEdit.Position = [146 117 100 22];

            % Create RateSlider
            app.RateSlider = uislider(app.LeftPanel);
            app.RateSlider.ValueChangedFcn = createCallbackFcn(app, @RateSliderValueChanged, true);
            app.RateSlider.ValueChangingFcn = createCallbackFcn(app, @RateSliderValueChanging, true);
            app.RateSlider.Position = [68 105 166 3];

            % Create StartButton
            app.StartButton = uibutton(app.LeftPanel, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.BackgroundColor = [0.9608 0.9608 0.9608];
            app.StartButton.Position = [21 477 108 22];
            app.StartButton.Text = 'Start';

            % Create StopButton
            app.StopButton = uibutton(app.LeftPanel, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            app.StopButton.BackgroundColor = [0.9608 0.9608 0.9608];
            app.StopButton.Position = [138 477 108 22];
            app.StopButton.Text = 'Stop';

            % Create LeftPanelLabel
            app.LeftPanelLabel = uilabel(app.LeftPanel);
            app.LeftPanelLabel.FontAngle = 'italic';
            app.LeftPanelLabel.Position = [9 529 42 22];
            app.LeftPanelLabel.Text = 'Device';

            % Create CenterPanel
            app.CenterPanel = uipanel(app.GridLayout);
            app.CenterPanel.Layout.Row = 1;
            app.CenterPanel.Layout.Column = 2;

            % Create LiveDataAxes
            app.LiveDataAxes = uiaxes(app.CenterPanel);
            title(app.LiveDataAxes, 'Live Data')
            xlabel(app.LiveDataAxes, 'Time (s)')
            ylabel(app.LiveDataAxes, 'Y')
            app.LiveDataAxes.Position = [6 239 478 230];

            % Create CaptureDataAxes
            app.CaptureDataAxes = uiaxes(app.CenterPanel);
            title(app.CaptureDataAxes, 'Captured Data')
            xlabel(app.CaptureDataAxes, 'Time (s)')
            ylabel(app.CaptureDataAxes, 'Y')
            app.CaptureDataAxes.Position = [6 6 478 230];

            % Create AutoscaleYSwitchLabel
            app.AutoscaleYSwitchLabel = uilabel(app.CenterPanel);
            app.AutoscaleYSwitchLabel.HorizontalAlignment = 'center';
            app.AutoscaleYSwitchLabel.Position = [21 478 70 22];
            app.AutoscaleYSwitchLabel.Text = 'Autoscale Y';

            % Create AutoscaleYSwitch
            app.AutoscaleYSwitch = uiswitch(app.CenterPanel, 'slider');
            app.AutoscaleYSwitch.ValueChangedFcn = createCallbackFcn(app, @AutoscaleYSwitchValueChanged, true);
            app.AutoscaleYSwitch.Position = [121 479 45 20];
            app.AutoscaleYSwitch.Value = 'On';

            % Create TimeWindowsEditFieldLabel
            app.TimeWindowsEditFieldLabel = uilabel(app.CenterPanel);
            app.TimeWindowsEditFieldLabel.HorizontalAlignment = 'right';
            app.TimeWindowsEditFieldLabel.Position = [318 478 95 22];
            app.TimeWindowsEditFieldLabel.Text = 'Time Window (s)';

            % Create TimeWindowEditField
            app.TimeWindowEditField = uieditfield(app.CenterPanel, 'numeric');
            app.TimeWindowEditField.ValueChangedFcn = createCallbackFcn(app, @TriggerDelayEditFieldValueChanged, true);
            app.TimeWindowEditField.Position = [420 478 51 22];
            app.TimeWindowEditField.Value = 1;

            % Create CenterPanelLabel
            app.CenterPanelLabel = uilabel(app.CenterPanel);
            app.CenterPanelLabel.FontAngle = 'italic';
            app.CenterPanelLabel.Position = [7 529 31 22];
            app.CenterPanelLabel.Text = 'Data';

            % Create RightPanel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 3;

            % Create TriggerConditionDropDownLabel
            app.TriggerConditionDropDownLabel = uilabel(app.RightPanel);
            app.TriggerConditionDropDownLabel.HorizontalAlignment = 'right';
            app.TriggerConditionDropDownLabel.Position = [30 359 97 22];
            app.TriggerConditionDropDownLabel.Text = 'Trigger Condition';

            % Create TriggerConditionDropDown
            app.TriggerConditionDropDown = uidropdown(app.RightPanel);
            app.TriggerConditionDropDown.Items = {'Rising', 'Falling'};
            app.TriggerConditionDropDown.Position = [142 359 70 22];
            app.TriggerConditionDropDown.Value = 'Rising';

            % Create VariableNameEditFieldLabel
            app.VariableNameEditFieldLabel = uilabel(app.RightPanel);
            app.VariableNameEditFieldLabel.HorizontalAlignment = 'right';
            app.VariableNameEditFieldLabel.Position = [43 427 84 22];
            app.VariableNameEditFieldLabel.Text = 'Variable Name';

            % Create VariableNameEditField
            app.VariableNameEditField = uieditfield(app.RightPanel, 'text');
            app.VariableNameEditField.Position = [142 427 70 22];
            app.VariableNameEditField.Value = 'mydata';

            % Create CaptureButton
            app.CaptureButton = uibutton(app.RightPanel, 'state');
            app.CaptureButton.ValueChangedFcn = createCallbackFcn(app, @CaptureButtonValueChanged, true);
            app.CaptureButton.Text = 'Capture';
            app.CaptureButton.BackgroundColor = [0.9608 0.9608 0.9608];
            app.CaptureButton.Position = [112 477 100 22];

            % Create StatusText
            app.StatusText = uilabel(app.RightPanel);
            app.StatusText.HorizontalAlignment = 'right';
            app.StatusText.Position = [44 452 168 22];
            app.StatusText.Text = '';

            % Create TriggerLevelEditFieldLabel
            app.TriggerLevelEditFieldLabel = uilabel(app.RightPanel);
            app.TriggerLevelEditFieldLabel.HorizontalAlignment = 'right';
            app.TriggerLevelEditFieldLabel.Position = [52 319 75 22];
            app.TriggerLevelEditFieldLabel.Text = 'Trigger Level';

            % Create TriggerLevelEditField
            app.TriggerLevelEditField = uieditfield(app.RightPanel, 'numeric');
            app.TriggerLevelEditField.Position = [142 319 70 22];
            app.TriggerLevelEditField.Value = 0.1;

            % Create TriggerDelaysEditFieldLabel
            app.TriggerDelaysEditFieldLabel = uilabel(app.RightPanel);
            app.TriggerDelaysEditFieldLabel.HorizontalAlignment = 'right';
            app.TriggerDelaysEditFieldLabel.Position = [33 279 94 22];
            app.TriggerDelaysEditFieldLabel.Text = 'Trigger Delay (s)';

            % Create TriggerDelayEditField
            app.TriggerDelayEditField = uieditfield(app.RightPanel, 'numeric');
            app.TriggerDelayEditField.ValueChangedFcn = createCallbackFcn(app, @TriggerDelayEditFieldValueChanged, true);
            app.TriggerDelayEditField.Position = [142 279 70 22];
            app.TriggerDelayEditField.Value = -0.5;

            % Create CaptureDurationsEditFieldLabel
            app.CaptureDurationsEditFieldLabel = uilabel(app.RightPanel);
            app.CaptureDurationsEditFieldLabel.HorizontalAlignment = 'right';
            app.CaptureDurationsEditFieldLabel.Position = [13 239 114 22];
            app.CaptureDurationsEditFieldLabel.Text = 'Capture Duration (s)';

            % Create CaptureDurationEditField
            app.CaptureDurationEditField = uieditfield(app.RightPanel, 'numeric');
            app.CaptureDurationEditField.ValueChangedFcn = createCallbackFcn(app, @TriggerDelayEditFieldValueChanged, true);
            app.CaptureDurationEditField.Position = [142 239 70 22];
            app.CaptureDurationEditField.Value = 2;

            % Create RightPanelLabel
            app.RightPanelLabel = uilabel(app.RightPanel);
            app.RightPanelLabel.FontAngle = 'italic';
            app.RightPanelLabel.Position = [9 529 43 22];
            app.RightPanelLabel.Text = 'Trigger';

            % Show the figure after all components are created
            app.AnalogTriggerAppExampleUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = AnalogTriggerApp_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.AnalogTriggerAppExampleUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.AnalogTriggerAppExampleUIFigure)
        end
    end
end