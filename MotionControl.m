classdef MotionControl < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        ExportmatStatus                 matlab.ui.control.Label
        ExportcsvStatus                 matlab.ui.control.Label
        PlotChosenChannel               matlab.ui.control.Button
        ChannelplotselectDropDown       matlab.ui.control.DropDown
        ChannelplotselectDropDownLabel  matlab.ui.control.Label
        TrialNumberField                matlab.ui.control.Spinner
        TrialLabel                      matlab.ui.control.Label
        SubjectNameEditField            matlab.ui.control.EditField
        SubjectnameLabel                matlab.ui.control.Label
        BiasTick                        matlab.ui.control.CheckBox
        CalibrationTick                 matlab.ui.control.CheckBox
        SavingdirEditField              matlab.ui.control.EditField
        SavingdirEditFieldLabel         matlab.ui.control.Label
        OffsetSwitch                    matlab.ui.control.ToggleSwitch
        OffsetSwitchLabel               matlab.ui.control.Label
        TabGroup                        matlab.ui.container.TabGroup
        SubplotView                     matlab.ui.container.Tab
        SubplotAxesPanel                matlab.ui.container.Panel
        CombinedPlotView                matlab.ui.container.Tab
        LiveDataAxes                    matlab.ui.control.UIAxes
        VectorViewTab                   matlab.ui.container.Tab
        VectorAxesPanel                 matlab.ui.container.Panel
        ExporttomatButton               matlab.ui.control.Button
        ApplycalibrationButton          matlab.ui.control.Button
        ExporttocsvButton               matlab.ui.control.Button
        RunningstatPanel                matlab.ui.container.Panel
        CapturetimerLabelValue          matlab.ui.control.Label
        CapturetimerLabel               matlab.ui.control.Label
        TriggerChannelLabelValue        matlab.ui.control.Label
        TriggerchannelLabel             matlab.ui.control.Label
        FIFOCountValue                  matlab.ui.control.Label
        FIFOcountLabel                  matlab.ui.control.Label
        BufferSizeValue                 matlab.ui.control.Label
        BuffersizeLabel                 matlab.ui.control.Label
        PlotButton                      matlab.ui.control.Button
        DataPlotPanel                   matlab.ui.container.Panel
        CaptureButton                   matlab.ui.control.StateButton
        MinMaxYTable                    matlab.ui.control.Table
        StatusText                      matlab.ui.control.Label
        StatusLabel                     matlab.ui.control.Label
        OffsetDurationField             matlab.ui.control.NumericEditField
        TriggerDelaysLabel              matlab.ui.control.Label
        TriggerCondition                matlab.ui.control.DropDown
        TriggerConditionDropDownLabel   matlab.ui.control.Label
        PlotColumnCount                 matlab.ui.control.NumericEditField
        PlotcolumnsEditFieldLabel       matlab.ui.control.Label
        Rate                            matlab.ui.control.NumericEditField
        DurationsEditField_2Label_2     matlab.ui.control.Label
        ArmButton                       matlab.ui.control.Button
        ArmedLamp                       matlab.ui.control.Lamp
        ArmedLampLabel                  matlab.ui.control.Label
        AcquireSwitch                   matlab.ui.control.Switch
        AcquireSwitchLabel              matlab.ui.control.Label
        DeviceName                      matlab.ui.control.EditField
        DeviceEditFieldLabel            matlab.ui.control.Label
        ChannelsList                    matlab.ui.control.EditField
        ChannelslistEditFieldLabel      matlab.ui.control.Label
        LivePlotLengthField             matlab.ui.control.NumericEditField
        PlottingtimesEditFieldLabel     matlab.ui.control.Label
        CaptureLengthField              matlab.ui.control.NumericEditField
        DurationsEditField_2Label       matlab.ui.control.Label
        VariableNameEditField           matlab.ui.control.EditField
        VariablenameEditFieldLabel      matlab.ui.control.Label
        AcquisitionparametersLabel      matlab.ui.control.Label
        TriggerandcaptureparametersLabel  matlab.ui.control.Label
        TriggerVoltage                  matlab.ui.control.NumericEditField
        TriggerLevelVLabel              matlab.ui.control.Label
        TriggerChannel                  matlab.ui.control.NumericEditField
        TriggerChannelLabel             matlab.ui.control.Label
        CaptureDataAxes                 matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        DAQ                      % Handle to DAQ object
        DevicesInfo              % Array of devices that provide analog input voltage or audio input measurements
        TimestampsFIFOBuffer     % Timestamps FIFO buffer used for live plot of latest "N" seconds of acquired data
        DataFIFOBuffer           % Data FIFO buffer used for live plot of latest "N" seconds of acquired data
        FIFOMaxSize = 1E+7;      % Maximum allowed FIFO buffer size for DataFIFOBuffer and TimestampsFIFOBuffer
        LivePlotsLineSubplot     % Handle to line plot of acquired data
        LivePlotsLineCombined    % Handle to line plot of single plot of acquired data
        LiveVectorPointSubplot    % List of scatter point in vector view
        CapturePlotLine          % Handle to line plot of capture data
        DataPlotsLine             % Handle to line plot of captured data
        TrigActive = false;      % Trigger detected flag
        TrigMoment = [];         % Relative timestamp (s) of detected trigger event
        CaptureTimestamps        % Captured data timestamps (s)
        CaptureData              % Captured data
        CaptureDataCalibrate     % Calibrated captured data
        Timestamps = [];         % Latest timestamps values used for trigger detection
        Data = [];               % Latest data values used for trigger detection       
        CallbackTimeSpan         % Timespan of data read in ScansAvailable callback
        TriggerDelay = 0         % Trigger delay (s)
        CaptureDuration          % Capture duration (s)
        ViewTimeWindow           % Live view timespan (s)
        CaptureStartMoment       % Relative timestamp of capture start moment (s)
        TimerValue               % Time value
        BufferSize               % Size of the data FIFO buffer
        TriggerDelayMax = 3600;  % Upper limit for trigger delay (s)
        CurrentState = '';       % App current state       
        ChannelNumbers = [];     % List of channels in array
        LiveAxesList             % List of live channels' plots
        DataAxesList             % List of captured data's plots
        CaptureAxesList = [];    % List of captured channels' plots
        ChannelCount             % Number of recording channels
        ChannelIndexLU           % Channel lookup table
        OffsetData               % Offset data
        OffsetDataRaw            % Offset data raw
        OffsetStartMoment        % Offset starting moment
        OffsetDuration           % Offset duration
        CalibratedMatrix         % Calibrated matrix
        SGChannelList            % List of strain gage from channel list
        LiveVectorAxesList       % List of subplot axes in vector view
        SGChannelCheck           % Check if channels 16-18 presented
        CaptureDataRaw           % Capture data raw
        NameForceList            % List of force components name
        CurrentPlottingData      % Contain currently plotted data
    end
    
    methods (Access = private)
        
        function setAppViewState(app, state)
            switch state                
                    
                case 'Unarm'
                    app.DeviceName.Enable = 'on';
                    app.AcquireSwitch.Enable = 'off';
                    app.ChannelsList.Enable = 'on';
                    app.Rate.Enable = 'on';
                    app.CaptureLengthField.Enable = 'on';
                    app.LivePlotLengthField.Enable = 'on';
                    app.SubjectNameEditField.Enable = 'on';
                    app.VariableNameEditField.Enable = 'on';
                    app.ExporttomatButton.Enable = 'on';
                    app.ExporttocsvButton.Enable = 'on';                    
                    app.ExportcsvStatus.Text = 'Do not export without capturing data';
                    app.ExportmatStatus.Text = 'Do not export without capturing data';

                    app.CaptureButton.Enable = 'off';
                    app.StatusText.Text = 'Configurating...';
                    app.CaptureButton.Text = 'Capture';
                    app.CaptureButton.Value = 0;

                    app.OffsetDurationField.Enable = 'off';
                    app.ArmedLamp.Color = 'red';
                    app.ArmButton.Enable = 'on';
                    app.PlotButton.Enable = 'off';
                    app.PlotChosenChannel.Enable = 'off';
                    app.ChannelplotselectDropDown.Enable = 'off';
                    app.ApplycalibrationButton.Enable = 'on';
                    app.BiasTick.Enable = 'on';

                case 'Arming'
                    app.DeviceName.Enable = 'off';
                    app.ChannelsList.Enable = 'off';
                    app.Rate.Enable = 'off';
                    app.CaptureLengthField.Enable = 'off';
                    app.LivePlotLengthField.Enable = 'on';
                    app.SubjectNameEditField.Enable = 'on';
                    app.VariableNameEditField.Enable = 'on';
                    app.ExporttomatButton.Enable = 'on';
                    app.ExporttocsvButton.Enable = 'on';
                    app.ExportcsvStatus.Text = 'Do not export without capturing data';
                    app.ExportmatStatus.Text = 'Do not export without capturing data';
                    app.CaptureButton.Enable = 'off';

                    app.OffsetDurationField.Enable = 'on';
                    app.CaptureLengthField.Enable = 'on';
                    app.StatusText.Text = 'Arming ...';
                    app.ArmedLamp.Color = 'yellow';
                    app.ArmButton.Enable = 'off';
                    app.PlotButton.Enable = 'off';
                    app.PlotChosenChannel.Enable = 'off';
                    app.ChannelplotselectDropDown.Enable = 'off';
                    app.ApplycalibrationButton.Enable = 'off';
                    app.BiasTick.Enable = 'off';


                case 'Armed'
                    app.DeviceName.Enable = 'on';
                    app.AcquireSwitch.Enable = 'on';
                    app.AcquireSwitch.Value = 'Stop';
                    app.ChannelsList.Enable = 'on';
                    app.Rate.Enable = 'on';
                    app.CaptureLengthField.Enable = 'on';
                    app.LivePlotLengthField.Enable = 'on';
                    app.SubjectNameEditField.Enable = 'on';
                    app.VariableNameEditField.Enable = 'on';
                    app.ExporttomatButton.Enable = 'on';
                    app.ExporttocsvButton.Enable = 'on';
                    app.ExportcsvStatus.Text = 'Do not export without capturing data';
                    app.ExportmatStatus.Text = 'Do not export without capturing data';

                    app.CaptureButton.Enable = 'off';
                    app.StatusText.Text = 'Armed. Ready for capture!';
                    
                    app.OffsetDurationField.Enable = 'on';
                    app.ArmedLamp.Color = 'green';
                    app.ArmButton.Enable = 'on';
                    app.BiasTick.Enable = 'on';

                case 'Acquisition.Buffering'
                    app.DeviceName.Enable = 'off';
                    app.ChannelsList.Enable = 'off';
                    app.Rate.Enable = 'off';
                    app.CaptureLengthField.Enable = 'off';
                    app.LivePlotLengthField.Enable = 'on';
                    app.SubjectNameEditField.Enable = 'on';
                    app.VariableNameEditField.Enable = 'on';
                    app.CaptureButton.Enable = 'off';
                    app.ArmButton.Enable = 'off';
                    app.PlotButton.Enable = 'off';
                    app.PlotChosenChannel.Enable = 'off';
                    app.ChannelplotselectDropDown.Enable = 'off';
                    app.ApplycalibrationButton.Enable = 'off';
                    app.BiasTick.Enable = 'on';

                    app.OffsetDurationField.Enable = 'on';
                    app.CaptureLengthField.Enable = 'on';
                    app.ExporttomatButton.Enable = 'off';
                    app.ExporttocsvButton.Enable = 'off';
                    app.ExportcsvStatus.Text = 'Not available';
                    app.ExportmatStatus.Text = 'Not available';
                    app.StatusText.Text = 'Buffering pre-trigger data...';
                
                case 'Acquisition.CollectingOffset'
                    app.DeviceName.Enable = 'off';
                    app.ChannelsList.Enable = 'off';
                    app.Rate.Enable = 'off';
                    app.CaptureLengthField.Enable = 'off';
                    app.LivePlotLengthField.Enable = 'on';
                    app.SubjectNameEditField.Enable = 'on';
                    app.VariableNameEditField.Enable = 'on';
                    app.CaptureButton.Enable = 'off';
                    app.ArmButton.Enable = 'off';
                    app.PlotButton.Enable = 'off';
                    app.PlotChosenChannel.Enable = 'off';
                    app.ChannelplotselectDropDown.Enable = 'off';
                    app.ApplycalibrationButton.Enable = 'off';
                    app.BiasTick.Enable = 'off';

                    app.OffsetDurationField.Enable = 'on';
                    app.CaptureLengthField.Enable = 'on';
                    app.ExporttomatButton.Enable = 'off';
                    app.ExporttocsvButton.Enable = 'off';
                    app.ExportcsvStatus.Text = 'Not available';
                    app.ExportmatStatus.Text = 'Not available';
                    app.StatusText.Text = 'Buffering pre-trigger data...';

                case 'Acquisition.ReadyForCapture'
                    app.CaptureButton.Enable = 'on';
                    app.OffsetDurationField.Enable = 'on';
                    app.ArmButton.Enable = 'on';
                    app.CaptureLengthField.Enable = 'on';
                    app.StatusText.Text = 'Ready for capture';
                    app.TrigActive = 0;
                    app.CaptureButton.Text = 'Capture';
                    app.CaptureButton.Enable = 'on';
                    app.PlotButton.Enable = 'on';
                    app.PlotChosenChannel.Enable = 'on';
                    app.ChannelplotselectDropDown.Enable = 'on';
                    app.ApplycalibrationButton.Enable = 'on';
                    app.CaptureButton.Value = 0;
                    app.SubjectNameEditField.Enable = 'on';
                    app.VariableNameEditField.Enable = 'on';
                    app.ExporttomatButton.Enable = 'on';
                    app.ExporttocsvButton.Enable = 'on';
                    app.ExportcsvStatus.Text = 'Do not export without capturing data';
                    app.ExportmatStatus.Text = 'Do not export without capturing data';
                    app.BiasTick.Enable = 'on';

                case 'Capture.CollectingOffset'
                    app.StatusText.Text = 'Collecting offset...';
                    app.OffsetDurationField.Enable = 'off';
                    app.CaptureLengthField.Enable = 'off';
                    app.ArmButton.Enable = 'off';
                    app.CaptureButton.Text = 'Cancel capture';
                    app.PlotButton.Enable = 'off';
                    app.PlotChosenChannel.Enable = 'off';
                    app.ChannelplotselectDropDown.Enable = 'off';
                    app.ApplycalibrationButton.Enable = 'off';
                    app.SubjectNameEditField.Enable = 'off';
                    app.VariableNameEditField.Enable = 'off';
                    app.ExporttomatButton.Enable = 'off';
                    app.ExporttocsvButton.Enable = 'off';
                    app.ExportcsvStatus.Text = 'Not available';
                    app.ExportmatStatus.Text = 'Not available';

                case 'Capture.LookingForTrigger'
                    app.StatusText.Text = 'Waiting for trigger...';
                    app.OffsetDurationField.Enable = 'off';
                    app.CaptureLengthField.Enable = 'off';
                    app.ArmButton.Enable = 'off';
                    app.CaptureButton.Text = 'Cancel capture';
                    app.PlotButton.Enable = 'off';
                    app.PlotChosenChannel.Enable = 'off';
                    app.ChannelplotselectDropDown.Enable = 'off';
                    app.ApplycalibrationButton.Enable = 'off';
                    app.SubjectNameEditField.Enable = 'off';
                    app.VariableNameEditField.Enable = 'off';
                    app.ExporttomatButton.Enable = 'off';
                    app.ExporttocsvButton.Enable = 'off';
                    app.ExportcsvStatus.Text = 'Not available';
                    app.ExportmatStatus.Text = 'Not available';
                    
                case 'Capture.CapturingData'
                    app.StatusText.Text = 'Trigger detected. Capturing';
                    app.ArmButton.Enable = 'off';
                    app.PlotButton.Enable = 'off';
                    app.PlotChosenChannel.Enable = 'off';
                    app.ChannelplotselectDropDown.Enable = 'off';
                    app.ApplycalibrationButton.Enable = 'off';
                    app.CapturetimerLabelValue.Text = num2str(app.TimerValue);
                    app.SubjectNameEditField.Enable = 'off';
                    app.VariableNameEditField.Enable = 'off';
                    app.ExporttomatButton.Enable = 'off';
                    app.ExporttocsvButton.Enable = 'off';
                    app.ExportcsvStatus.Text = 'Not available';
                    app.ExportmatStatus.Text = 'Not available';

                case 'Capture.CaptureComplete'
                    app.StatusText.Text = 'Capture completed';
                    app.ArmButton.Enable = 'on';
                    app.PlotButton.Enable = 'on';
                    app.PlotChosenChannel.Enable = 'on';
                    app.ChannelplotselectDropDown.Enable = 'on';
                    app.ApplycalibrationButton.Enable = 'on';
                    app.CapturetimerLabelValue.Text = '0';
                    app.SubjectNameEditField.Enable = 'on';
                    app.VariableNameEditField.Enable = 'on';
                    app.ExporttomatButton.Enable = 'on';
                    app.ExporttocsvButton.Enable = 'on';
                    app.ExportcsvStatus.Text = 'Ready to export';
                    app.ExportmatStatus.Text = 'Ready to export';
                
                case 'DataPlot.NotAvailable'
                    

                case 'DataPlot.Available'
                    
                    
            end
            
        end
        
        function setDeviceParameters(app)
            delete(app.DAQ);
            app.DAQ = daq('ni');
            app.DAQ.Rate = app.Rate.Value;
            app.ChannelNumbers = str2num(app.ChannelsList.Value); %#ok<ST2NM> 
            app.ChannelCount = length(app.ChannelNumbers);
            app.OffsetData = zeros(1, app.ChannelCount);
            unitName = "Voltage";

            app.ChannelIndexLU = zeros(35, 1);
            indexLU = 1;
            for indexChannel = 1:length(app.ChannelNumbers)
                channelNumber = app.ChannelNumbers(indexChannel);
                if channelNumber < 16
                    channel = addinput(app.DAQ, app.DeviceName.Value, "ai" + num2str(channelNumber), unitName);
                    channel.TerminalConfig = 'SingleEnded';
                    app.ChannelIndexLU(channelNumber+1) = indexLU; 
                    indexLU = indexLU + 1;
                else
                    channel = addinput(app.DAQ, app.DeviceName.Value, "ai" + num2str(channelNumber), unitName);
                    app.ChannelIndexLU(channelNumber+1) = indexLU; 
                    indexLU = indexLU + 1;
                    channelRef = addinput(app.DAQ, app.DeviceName.Value, "ai" + num2str(channelNumber + 8), unitName);
                    app.ChannelIndexLU(channelNumber+1 + 8) = indexLU; 
                    indexLU = indexLU + 1;
                end
            end
            % Configure DAQ ScansAvailableFcn callback function
            app.DAQ.ScansAvailableFcn = @(src,event) scansAvailable_Callback(app, src, event);
            app.CallbackTimeSpan = double(app.DAQ.ScansAvailableFcnCount)/app.DAQ.Rate;

            % Calculate required FIFO data buffer size
            app.BufferSize = calculateBufferSize(app, app.CallbackTimeSpan, ...
                                                      app.LivePlotLengthField.Value, ...
                                                      app.OffsetDurationField.Value, ...
                                                      app.CaptureLengthField.Value, ...
                                                      app.DAQ.Rate);
            app.BufferSizeValue.Text = num2str(app.BufferSize);

        end
        
        function updateSubplotPanel(app)
            numberOfColumns = app.PlotColumnCount.Value;
            channelList = str2num(app.ChannelsList.Value); %#ok<ST2NM> 
            if mod(app.ChannelCount, numberOfColumns) > 0
                addRow = 1;
            else
                addRow = 0;
            end
            numberOfRows = floor(app.ChannelCount/numberOfColumns) + addRow;

            for indexPlot = 1:app.ChannelCount
                app.LiveAxesList{indexPlot} = subplot(numberOfRows, numberOfColumns, indexPlot, 'Parent', app.SubplotAxesPanel);
                app.LivePlotsLineSubplot{indexPlot} = plot(app.LiveAxesList{indexPlot}, NaN, NaN);

                % Setting subplot title
                channelNumber = channelList(indexPlot);
                channelName = "Channel " + num2str(channelNumber);
                title(app.LiveAxesList{indexPlot}, channelName)

                % Setting capture plot line - After capturing
                app.CapturePlotLine{indexPlot} = plot(app.CaptureDataAxes, NaN, NaN, 'DisplayName', channelName);
                hold(app.CaptureDataAxes, 'on');

                % Setting combined live plot line
                app.LivePlotsLineCombined{indexPlot} = plot(app.LiveDataAxes, NaN, NaN, 'DisplayName', channelName);
                hold(app.LiveDataAxes, 'on');
            end
            setYLimAxes(app)
            legend(app.CaptureDataAxes, 'Location', 'northeastoutside')
            
        end

        function updateVectorPlotPanel(app)
            app.SGChannelCheck = true;
            for indexSG = 16:18
                if ~any(app.ChannelNumbers(:)==indexSG)
                    app.SGChannelCheck = false;
                    return
                end
            end
            samplesToPlot = round(app.LivePlotLengthField.Value * app.Rate.Value);
            dummyData = zeros(samplesToPlot, 1);
            titleVector = ["XY"; "XZ"; "YZ"];
            for indexPlot = 2:4 % isometric view, xy view, xz view, yz view
                app.LiveVectorAxesList{indexPlot} = subplot(2, 2, indexPlot, 'Parent', app.VectorAxesPanel);
                c = linspace(1, 10, samplesToPlot);
                app.LiveVectorPointSubplot{indexPlot} = scatter(app.LiveVectorAxesList{indexPlot}, dummyData, dummyData, 10, c, "filled");
                colormap(app.LiveVectorAxesList{indexPlot}, 'jet');
                title(app.LiveVectorAxesList{indexPlot}, titleVector(indexPlot - 1));
                app.LiveVectorAxesList{indexPlot}.YLim = [-10 35];
                app.LiveVectorAxesList{indexPlot}.XLim = [-10 35];
            end
            
        end
        
        function plotParams = generatePlotParams(app)
            plotParams = struct;
            plotParams.ylabel = 'Voltage (V)';
            plotParams.ylim = [-10 10];
        end

        function updateDataPlotPanel(app, plotParams)
            numberOfColumns = app.PlotColumnCount.Value;
            channelList = str2num(app.ChannelsList.Value); %#ok<ST2NM> 
            if mod(app.ChannelCount, numberOfColumns) > 0
                addRow = 1;
            else
                addRow = 0;
            end
            numberOfRows = floor(app.ChannelCount/numberOfColumns) + addRow;
            for indexPlot = 1:app.ChannelCount
                app.DataAxesList{indexPlot} = subplot(numberOfRows, numberOfColumns, indexPlot, 'Parent', app.DataPlotPanel);
                app.DataPlotsLine{indexPlot} = plot(app.DataAxesList{indexPlot}, NaN, NaN);
                xlabel(app.DataAxesList{indexPlot}, "Time (s)");
                
                % Setting subplot title
                channelNumber = channelList(indexPlot);
                channelName = "Channel " + num2str(channelNumber) + ...
                              " - " + num2str(app.OffsetData(indexPlot), '%.4f') + " V";
                if channelNumber > 15
                    ylabel(app.DataAxesList{indexPlot}, plotParams.ylabel);
                    ylim(app.DataAxesList{indexPlot}, plotParams.ylim);
                else
                    ylabel(app.DataAxesList{indexPlot}, 'Voltage (V)');
                    ylim(app.DataAxesList{indexPlot}, [-10 10]);
                end
                title(app.DataAxesList{indexPlot}, channelName);
            end
        end


        function updateCapturePlotPanel(app)
            cla(app.CaptureDataAxes, 'reset')
            channelList = str2num(app.ChannelsList.Value); %#ok<ST2NM> 
            
            for indexPlot = 1:app.ChannelCount
                channelNumber = channelList(indexPlot);
                channelName = "Channel " + num2str(channelNumber);
                app.CapturePlotLine{indexPlot} = plot(app.CaptureDataAxes, NaN, NaN, 'DisplayName', channelName);
                hold(app.CaptureDataAxes, 'on');
            end
            legend(app.CaptureDataAxes, 'Location', 'northeastoutside')
        end


        function scansAvailable_Callback(app, src, ~)
            if ~isvalid(app)
                return
            end
            

            % Continuous acquisition data and timestamps are stored in FIFO data buffers
            % Calculate required buffer size -- this should be large enough to accomodate the
            % the data required for the live view time window and the data for the requested
            % capture duration.
            app.ViewTimeWindow = app.LivePlotLengthField.Value;
            app.OffsetDuration = app.OffsetDurationField.Value;
            app.CaptureDuration = app.CaptureLengthField.Value;
            
            [data,timestamps] = read(src, src.ScansAvailableFcnCount, 'OutputFormat','Matrix');

            % Offset straingage
            SGRawIndexList = app.ChannelIndexLU(app.SGChannelList + 1);
            SGRefIndexList = app.ChannelIndexLU(app.SGChannelList + 1 + 8);
            data(:, SGRawIndexList) = data(:, SGRawIndexList) - data(:, SGRefIndexList);

            % Store continuous acquisition data in FIFO data buffers
            app.TimestampsFIFOBuffer = storeDataInFIFO(app, app.TimestampsFIFOBuffer, app.BufferSize, timestamps);
            app.DataFIFOBuffer = storeDataInFIFO(app, app.DataFIFOBuffer, app.BufferSize, data);
            
            app.FIFOCountValue.Text = num2str(size(app.TimestampsFIFOBuffer, 1));


            % Update live plot data
            samplesToPlot = min([round(app.ViewTimeWindow * src.Rate), size(app.DataFIFOBuffer,1)]);
            firstPoint = size(app.DataFIFOBuffer, 1) - samplesToPlot + 1;
            
            dataPlot = app.DataFIFOBuffer;
            if app.BiasTick.Value && app.CurrentState == "Acquisition.ReadyForCapture"  
                dataIndex = app.ChannelIndexLU(app.ChannelNumbers+1);
                dataPlot(:, dataIndex) = dataPlot(:, dataIndex) - app.OffsetDataRaw(:, dataIndex);
            end

            if app.CalibrationTick.Value == 1
                dataPlot(:, SGRawIndexList) = (app.CalibratedMatrix*dataPlot(:, SGRawIndexList)')';
            end


            for indexChannel = 1:app.ChannelCount
                channelNumber = app.ChannelNumbers(indexChannel);
                dataIndex = app.ChannelIndexLU(channelNumber+1);
                if samplesToPlot > 1
                    xlim(app.LiveAxesList{indexChannel}, [app.TimestampsFIFOBuffer(firstPoint), app.TimestampsFIFOBuffer(end)])
                    xlim(app.LiveDataAxes, [app.TimestampsFIFOBuffer(firstPoint), app.TimestampsFIFOBuffer(end)])
                end
              
                switch  app.TabGroup.SelectedTab.Title
                    case "Subplot View"
                        plotVectorBool = false;
                        set(app.LivePlotsLineSubplot{indexChannel}, 'XData', app.TimestampsFIFOBuffer(firstPoint:end), ...
                                                            'YData', dataPlot(firstPoint:end, dataIndex));

                        channelName = "Channel " + num2str(channelNumber) + " - " + num2str(mean(dataPlot(end-10:end, dataIndex)));
                        title(app.LiveAxesList{indexChannel}, channelName)
                    case "Combined Plot View"
                        plotVectorBool = false;
                        set(app.LivePlotsLineCombined{indexChannel}, 'XData', app.TimestampsFIFOBuffer(firstPoint:end), ...
                                                            'YData', dataPlot(firstPoint:end, dataIndex));
                    case "Vector View"
                        plotVectorBool = true;
                        break
                end
            end

            if plotVectorBool && app.SGChannelCheck && (size(dataPlot, 1) > app.ViewTimeWindow * src.Rate)
                channelPair = [16 17; 16 18; 17 18];
                for indexPair = 1:3
                    dataIndex = app.ChannelIndexLU(channelPair(indexPair, :)+1);
                    set(app.LiveVectorPointSubplot{indexPair+1}, 'XData', dataPlot(firstPoint:end, dataIndex(1)), ...
                                                                 'YData', dataPlot(firstPoint:end, dataIndex(2)));
                end
                
            end
         
            % If capture is requested, analyze latest acquired data until a trigger
            % condition is met. After enough data is acquired for a complete capture,
            % as specified by the capture duration, extract the capture data from the
            % data buffer and save it to a base workspace variable.
            
            % For trigger detection, store previous and current ScansAvailable callback data and timestamps
            if isempty(app.Timestamps)
                app.Data = data;
                app.Timestamps = timestamps;
            else
                app.Data = [app.Data(end, :); data];
                app.Timestamps = [app.Timestamps(end); timestamps];
            end

            % App state control logic 
            switch app.CurrentState
                case 'Acquisition.Buffering'
                   % Buffering pre-trigger data
                    if isEnoughDataBuffered(app)
                        app.CurrentState = 'Acquisition.CollectingOffset';
                        setAppViewState(app, app.CurrentState)

                        app.OffsetStartMoment = app.Timestamps(end);
                        app.OffsetDataRaw = app.Data;
                    end
                
                case 'Acquisition.CollectingOffset'
                    if isEnoughDataOffset(app)
                        app.OffsetDataRaw = mean(app.OffsetDataRaw, 1);
                        app.CurrentState = 'Acquisition.ReadyForCapture';
                        setAppViewState(app, app.CurrentState)
                    end
                case 'Acquisition.ReadyForCapture'
                    % Ready for capture
                    if app.CaptureButton.Value
                        app.CurrentState = 'Capture.CollectingOffset';
                        setAppViewState(app, app.CurrentState)

                        app.OffsetStartMoment = app.Timestamps(end);
                        app.OffsetDataRaw = app.Data;
                    end
                case 'Capture.CollectingOffset'
                    if isEnoughDataOffset(app)
                        app.OffsetDataRaw = mean(app.OffsetDataRaw, 1);
                        app.CurrentState = 'Capture.LookingForTrigger';
                        setAppViewState(app, app.CurrentState)
                    end
                case 'Capture.LookingForTrigger'
                    % Looking for trigger event in the latest data
                    detectTrigger(app)
                    if app.TrigActive
                        tic;
                        app.CurrentState = 'Capture.CapturingData';
                        setAppViewState(app, app.CurrentState)
                    end
                case 'Capture.CapturingData'
                    % Capturing data
                    % Not enough acquired data to cover capture timespan during this ScansAvailable callback execution
                    app.CapturetimerLabelValue.Text = num2str(toc);
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

        function  detectTrigger(app)
            %detectTrigger Detects trigger condition and updates relevant app properties
            % Updates TrigActive, TrigMoment, and CaptureStartMoment app properties
            
            trigConfig.Channel = find(app.ChannelNumbers==app.TriggerChannel.Value);
            trigConfig.Level = app.TriggerVoltage.Value;
            trigConfig.Condition = app.TriggerCondition.Value;
            [app.TrigActive, app.TrigMoment] = ...
                trigDetect(app, app.Timestamps, app.Data, trigConfig);
            app.CaptureStartMoment = app.TrigMoment + app.TriggerDelay;
            
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
            lastSampleIndex = firstSampleIndex + round(app.CaptureLengthField.Value * app.DAQ.Rate);
            if isempty(firstSampleIndex) || isempty(lastSampleIndex) || lastSampleIndex > size(app.TimestampsFIFOBuffer, 1)
                % Something went wrong
                % Abort capture
                app.StatusText.Text = 'Capture error';
                app.CaptureButton.Value = 0;
                uialert(app.UIFigure, 'Could not complete capture.', 'Capture error');
                return
            end
            
            % Extract capture data and shift timestamps so that 0 corresponds to the trigger moment
            app.CaptureDataRaw = app.DataFIFOBuffer(firstSampleIndex:lastSampleIndex, :);
            app.CaptureTimestamps = app.TimestampsFIFOBuffer(firstSampleIndex:lastSampleIndex, :) - app.TrigMoment;
            
         
            app.CaptureData = zeros(size(app.CaptureDataRaw, 1), app.ChannelCount);
            
            % Remove ref channels from raw captured data and offset data
            for indexChannel = 1:app.ChannelCount
                channelNumber = app.ChannelNumbers(indexChannel);
                dataIndex = app.ChannelIndexLU(channelNumber+1);
                app.CaptureData(:, indexChannel) = app.CaptureDataRaw(:, dataIndex);
                if isempty(app.OffsetDataRaw)
                    app.OffsetData(1, indexChannel) = app.CaptureDataRaw(1, dataIndex);
                else
                    app.OffsetData(1, indexChannel) = app.OffsetDataRaw(:, dataIndex);
                end
            end

            % Update captured data plot (one line for each acquisition channel)
            for indexChannel = 1:app.ChannelCount
                set(app.CapturePlotLine{indexChannel}, 'XData', app.CaptureTimestamps, ...
                                                       'YData', app.CaptureData(:, indexChannel));
            end

            app.CaptureDataAxes.XLim = [min(app.CaptureTimestamps), max(app.CaptureTimestamps)];
            
            % Save capture data
            varCaptureName = app.VariableNameEditField.Value;
            saveCaptureData(app, app.CaptureData, varCaptureName);

            % Save offset data
            varOffsetName = 'OffsetData';
            assignin('base', varOffsetName, app.OffsetData);
            
        end

        function plotCaptureData(app, data)
            if isempty(app.CaptureData) || isempty(app.CaptureTimestamps)
                return
            end
            app.CurrentPlottingData = data;
            
            dataYLim = app.MinMaxYTable.Data;
            for indexChannel = 1:app.ChannelCount
                
                xlim(app.DataAxesList{indexChannel}, [app.CaptureTimestamps(1), app.CaptureTimestamps(end)]);
                ylim(app.DataAxesList{indexChannel}, [dataYLim(indexChannel, 1), dataYLim(indexChannel, 2)]);
                set(app.DataPlotsLine{indexChannel}, 'XData', app.CaptureTimestamps(:), ...
                                                     'YData', data(:, indexChannel));
            end
        end
        
        function data = applyOffset(app, data)
            if isempty(app.CaptureData) || isempty(app.CaptureTimestamps)
                return
            end
            if app.OffsetSwitch.Value == "Off"
                offsetDataSelect = zeros(size(app.OffsetData));
            else
                offsetDataSelect = app.OffsetData;
            end
            for indexChannel = 1:app.ChannelCount
                data(:, indexChannel) = data(:, indexChannel) - offsetDataSelect(:, indexChannel);
            end
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

        function results = isEnoughDataCaptured(app)
        %isEnoughDataCaptured Check whether captured-data duration exceeds specified capture duration

            results = (app.TimestampsFIFOBuffer(end,1)-app.CaptureStartMoment) > app.CaptureDuration;
        end

        function results = isEnoughDataOffset(app)
            app.OffsetDataRaw = [app.OffsetDataRaw; app.Data];
            results = (app.TimestampsFIFOBuffer(end,1)-app.OffsetStartMoment) > app.OffsetDuration;
        end

        function results = doesTriggerDelayChangeRequireBuffering(app)
        
            value = app.TriggerDelayEditField.Value;
            if value < 0 && size(app.TimestampsFIFOBuffer,1) < ceil(abs(value)*app.DAQ.Rate)
                results = true;
            else
                results = false;
            end            
        end

        function setMinMaxYTableDefault(app, minY, maxY)
            RowName = {};
            app.MinMaxYTable.ColumnEditable = [true, true, true];
            channelList = str2num(app.ChannelsList.Value); %#ok<ST2NM> 
            for indexChannel = 1:app.ChannelCount
                channelNumber = channelList(indexChannel);
                RowName{indexChannel} = "Channel " + num2str(channelNumber);
                
                app.MinMaxYTable.Data(indexChannel, 1) = minY;
                app.MinMaxYTable.Data(indexChannel, 2) = maxY;
                if channelNumber > 15
                    app.MinMaxYTable.Data(indexChannel, 3) = "Strain gauge " + num2str(channelNumber - 15);
                else
                    app.MinMaxYTable.Data(indexChannel, 3) = RowName{indexChannel};
                end
             
            end
            app.MinMaxYTable.RowName = RowName;

        end

        function setYLimAxes(app)
            data = app.MinMaxYTable.Data;
            for indexChannel = 1:app.ChannelCount
                app.LiveAxesList{indexChannel}.YLim = [data(indexChannel, 1), data(indexChannel, 2)];
                app.DataAxesList{indexChannel}.YLim = [data(indexChannel, 1), data(indexChannel, 2)];
            end
        end

        function flipAcquire(app, value)
            if value == "Start"
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
               
                    setYLimAxes(app)               
                catch exception
                    uialert(app.UIFigure, exception.message, 'Start error');   
                end
            elseif value == "Stop"
                stop(app.DAQ);

                app.DataFIFOBuffer = [];
                app.TimestampsFIFOBuffer = [];
                % Configure the app for device configuration state
                app.CurrentState = 'Armed';
                setAppViewState(app, app.CurrentState);
            end

        end
        
        function calculateCalibratedMatrix(app)
            calibrationMatrix = load('calibrationMatrixATI.mat');
            toolMatrix = load('toolTransMatrix.mat');
            app.CalibratedMatrix = toolMatrix.toolTransMatrix*calibrationMatrix.calibrationMatrixATI;
            assignin('base', 'calibratedMatrix', app.CalibratedMatrix);
        end

        function applyCalibration(app, data)
            indexSG = find(app.ChannelNumbers>15);
            countSG = size(indexSG, 2);
            captureSG= zeros(size(data, 1), countSG);
            indexCurrentSG = 1;
            for indexChannel = 1:app.ChannelCount
                channelNumber = app.ChannelNumbers(indexChannel);
                if channelNumber >= 16
                    captureSG(:, indexCurrentSG) = data(:, indexChannel);
                    indexCurrentSG = indexCurrentSG + 1;
                end
            end
            calibratedSG = app.CalibratedMatrix*captureSG';
            app.CaptureDataCalibrate = data;
            app.CaptureDataCalibrate(:, indexSG) = calibratedSG';

            varCaptureName = char(string(app.VariableNameEditField.Value) + "_force");
            saveCaptureData(app, app.CaptureDataCalibrate, varCaptureName);

        end
        
        function captureData = saveCaptureData(app, data, varnameInput, options)
            % Save captured data to a base workspace variable
            % For simplicity, validation of user input and checking whether a variable
            % with the same name already exists are not addressed in this example.
            % Get the variable name from UI text input
            arguments
                app
                data
                varnameInput
                options.force (1, 1) {mustBeNumericOrLogical} = false
                options.toWorkspace (1, 1) {mustBeNumericOrLogical} = true
                options.timetable (1, 1) {mustBeNumericOrLogical} = true
            end
            columnNames = {};
            channelList = str2num(app.ChannelsList.Value); %#ok<ST2NM> 
            for indexChannel = 1:app.ChannelCount
                channelNumber = channelList(indexChannel);
                if channelNumber >= 16 && options.force
                    columnNames{indexChannel} = char(app.NameForceList{channelNumber-15});
                else
                    columnNames{indexChannel} = char("Channel " + num2str(channelNumber));
                end
            end
            if app.OffsetSwitch.Value == "Off"
                varName = genvarname(char(string(varnameInput) + "_woOffset"));
            else
                varName = genvarname(char(string(varnameInput) + "_wOffset"));
            end
            if options.timetable
                captureData = timetable(seconds(app.CaptureTimestamps), data, 'VariableNames', {varName});
            else
                columnName = [{'Timestamps'}, varName];
                captureData = table(app.CaptureTimestamps, data, 'VariableNames', columnName);
            end
            captureData = splitvars(captureData, varName, 'NewVariableNames', columnNames);
            
            % Use assignin function to save the captured data in a base workspace variable
            if options.toWorkspace
                assignin('base', varName, captureData);
            end
            
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.ChannelNumbers = str2num(app.ChannelsList.Value); %#ok<ST2NM> 
            app.ChannelCount = length(app.ChannelNumbers);
            app.SGChannelList = app.ChannelNumbers(find(app.ChannelNumbers>=16));
            app.NameForceList = {"Fx", "Fy", "Fz", "Tx", "Ty", "Tz"};

            app.OffsetData = zeros(1, app.ChannelCount);
            
            calculateCalibratedMatrix(app)
            setMinMaxYTableDefault(app, -10, 10)
            plotParams = generatePlotParams(app);
            updateSubplotPanel(app)
            updateVectorPlotPanel(app)
            updateDataPlotPanel(app, plotParams)
            setYLimAxes(app)

            % Populate the plot selected channel list
            if isrow(app.ChannelNumbers)
                channelListCell = cellstr(num2str(app.ChannelNumbers'));
            else
                channelListCell = cellstr(num2str(app.ChannelNumbers));
            end

            app.ChannelplotselectDropDown.Items = channelListCell;
            app.ChannelplotselectDropDown.Value = channelListCell{1};

            app.CurrentState = 'Unarm';
            setAppViewState (app, app.CurrentState)
            
            
        end

        % Button pushed function: ArmButton
        function ArmButtonPushed(app, event)
            app.CurrentState = 'Arming';
            cla(app.CaptureDataAxes, 'reset');
            setAppViewState (app, app.CurrentState)
            
            setDeviceParameters(app)
            updateSubplotPanel(app)
            updateVectorPlotPanel(app)

            plotParams = generatePlotParams(app);
            updateDataPlotPanel(app, plotParams)

            app.CurrentState = 'Armed';
            setAppViewState (app, app.CurrentState)
        end

        % Value changed function: AcquireSwitch
        function AcquireSwitchFlip(app, event)
            value = app.AcquireSwitch.Value;
            flipAcquire(app, value);
        end

        % Value changed function: CaptureLengthField
        function CaptureLengthFieldValueChanged(app, event)
            app.CurrentState = 'Unarm';
            if app.AcquireSwitch.Value == "Start"
                app.AcquireSwitch.Value = "Stop";
                flipAcquire(app, "Stop");
            end
            setAppViewState(app, app.CurrentState);
        end

        % Value changed function: Rate
        function RateValueChanged(app, event)
            app.CurrentState = 'Unarm';
            setAppViewState(app, app.CurrentState);
        end

        % Value changed function: ChannelsList
        function ChannelsListValueChanged(app, event)
            app.ChannelNumbers = str2num(app.ChannelsList.Value); %#ok<ST2NM> 
            app.ChannelCount = length(app.ChannelNumbers);
            setMinMaxYTableDefault(app, -10, 10)
            app.OffsetData = zeros(1, app.ChannelCount);
            app.SGChannelList = app.ChannelNumbers(find(app.ChannelNumbers>=16));

            % Populate the plot selected channel list
            if isrow(app.ChannelNumbers)
                channelListCell = cellstr(num2str(app.ChannelNumbers'));
            else
                channelListCell = cellstr(num2str(app.ChannelNumbers));
            end

            app.ChannelplotselectDropDown.Items = channelListCell;
            app.ChannelplotselectDropDown.Value = channelListCell{1};

            cellfun(@(x) delete(x), app.LiveAxesList)
            cellfun(@(x) delete(x), app.DataAxesList)

            app.LiveAxesList = {};
            app.DataAxesList = {};
            app.LiveVectorAxesList = {};
            
            updateSubplotPanel(app)
            updateCapturePlotPanel(app)
            updateVectorPlotPanel(app)

            plotParams = generatePlotParams(app);
            updateDataPlotPanel(app, plotParams);
            app.CurrentState = 'Unarm';
            if app.AcquireSwitch.Value == "Start"
                app.AcquireSwitch.Value = "Stop";
                flipAcquire(app, "Stop");
            end
            setAppViewState(app, app.CurrentState);
        end

        % Value changing function: ChannelsList
        function ChannelsListValueChanging(app, event)
            app.CurrentState = 'Unarm';
            if app.AcquireSwitch.Value == "Start"
                app.AcquireSwitch.Value = "Stop";
                flipAcquire(app, "Stop");
            end
            setAppViewState(app, app.CurrentState);
        end

        % Display data changed function: MinMaxYTable
        function MinMaxYTableDisplayDataChanged(app, event)
            setYLimAxes(app)
            updateChannelData(app)
        end

        % Value changed function: CaptureButton
        function CaptureButtonValueChanged(app, event)
            updateCapturePlotPanel(app)
            value = app.CaptureButton.Value;
            if ~value
                % Capture cancelled
                app.CurrentState = 'Acquisition.ReadyForCapture';
                setAppViewState(app, app.CurrentState);
            end
        end

        % Button pushed function: PlotButton
        function PlotButtonPushed(app, event)
            plotParams = generatePlotParams(app);
            updateDataPlotPanel(app, plotParams)
            data = applyOffset(app, app.CaptureData);
            plotCaptureData(app, data)
        end

        % Button pushed function: ApplycalibrationButton
        function ApplycalibrationButtonPushed(app, event)
            data = applyOffset(app, app.CaptureData);
            plotParams = generatePlotParams(app);
            applyCalibration(app, data)
            plotParams.ylabel = 'Force (N)';
            updateDataPlotPanel(app, plotParams)
            
            plotCaptureData(app, app.CaptureDataCalibrate)
        end

        % Button pushed function: ExporttocsvButton
        function ExporttocsvButtonPushed(app, event)
            currentDIR = pwd;

            exportFolderName = char(string(app.SubjectNameEditField.Value) + "_Trial" + num2str(app.TrialNumberField.Value));
            exportFolderDIR = fullfile(currentDIR, exportFolderName);
            mkdir(exportFolderDIR);
            force = true;
            toWorkspace = false;
            timetable = false;
            initialOffsetState = app.OffsetSwitch.Value;

            %% Get data without offset
            app.OffsetSwitch.Value = "Off";
            data_woOffset = applyOffset(app, app.CaptureData);
            applyCalibration(app, data_woOffset);
            forceData_woOffset = app.CaptureDataCalibrate;
  
            % Exporting raw data
            data_woOffset = saveCaptureData(app, data_woOffset, "savingData", toWorkspace=toWorkspace, timetable=timetable);
            exportFileName = fullfile(exportFolderDIR, "data_woOffset.csv");
            writetable(data_woOffset, exportFileName)

            % Exporting force data
            forceData_woOffset = saveCaptureData(app, forceData_woOffset, "savingData", force=force, toWorkspace=toWorkspace, timetable=timetable);
            exportFileName = fullfile(exportFolderDIR, "forceData_woOffset.csv");
            writetable(forceData_woOffset, exportFileName)

            %% get data with offset
            app.OffsetSwitch.Value = "On";
            data_wOffset = applyOffset(app, app.CaptureData);
            applyCalibration(app, data_wOffset);
            forceData_wOffset = app.CaptureDataCalibrate;

            % Exporting raw data
            data_wOffset = saveCaptureData(app, data_wOffset, "savingData", toWorkspace=toWorkspace, timetable=timetable);
            exportFileName = fullfile(exportFolderDIR, "data_wOffset.csv");
            writetable(data_wOffset, exportFileName)

            % Exporting force data
            forceData_wOffset = saveCaptureData(app, forceData_wOffset, "savingData", force=force, toWorkspace=toWorkspace, timetable=timetable);
            exportFileName = fullfile(exportFolderDIR, "forceData_wOffset.csv");
            writetable(forceData_wOffset, exportFileName)

            % Export other params
            params.Channels = app.ChannelNumbers;
            params.ChannelsInfo = app.DAQ.Channels;
            params.OffsetDuration = app.OffsetDuration;
            params.offsetData = app.OffsetData;
            params.CalibratedMatrix = app.CalibratedMatrix;
            params.CaptureDuration = app.CaptureDuration;

            % Raw data
            rawData.CaptureData = app.CaptureDataRaw;
            rawData.OffsetData = app.OffsetDataRaw;
            
            % Timestamps data
            timestamps = app.CaptureTimestamps;

            save(exportFileName, "rawData", ...
                                 "timestamps", ...
                                 "params");
            app.OffsetSwitch.Value = initialOffsetState;
            app.ExportcsvStatus.Text = 'Done!';
        end

        % Button pushed function: ExporttomatButton
        function ExporttomatButtonPushed(app, event)
            exportFileName = char(string(app.SubjectNameEditField.Value) + "_" + num2str(app.TrialNumberField.Value) + ".mat");
            initialOffsetState = app.OffsetSwitch.Value;
            force = true;
            toWorkspace = false;

            % Get data without offset
            app.OffsetSwitch.Value = "Off";
            data_woOffset = applyOffset(app, app.CaptureData);
            applyCalibration(app, data_woOffset);
            forceData_woOffset = app.CaptureDataCalibrate;
  
            data_woOffset = saveCaptureData(app, data_woOffset, "savingData", toWorkspace=toWorkspace);
            forceData_woOffset = saveCaptureData(app, forceData_woOffset, "savingData", force=force, toWorkspace=toWorkspace);

            % Get data with offset
            app.OffsetSwitch.Value = "On";
            data_wOffset = applyOffset(app, app.CaptureData);
            applyCalibration(app, data_wOffset);
            forceData_wOffset = app.CaptureDataCalibrate;

            data_wOffset = saveCaptureData(app, data_wOffset, "savingData", toWorkspace=toWorkspace);
            forceData_wOffset = saveCaptureData(app, forceData_wOffset, "savingData", force=force, toWorkspace=toWorkspace);

            % Capture parameters
            params.Channels = app.ChannelNumbers;
            params.ChannelsInfo = app.DAQ.Channels;
            params.OffsetDuration = app.OffsetDuration;
            params.offsetData = app.OffsetData;
            params.CalibratedMatrix = app.CalibratedMatrix;
            params.CaptureDuration = app.CaptureDuration;

            % Raw data
            rawData.CaptureData = app.CaptureDataRaw;
            rawData.OffsetData = app.OffsetDataRaw;
            
            % Timestamps data
            timestamps = app.CaptureTimestamps;

            save(exportFileName, "data_woOffset", ...
                                 "forceData_woOffset", ...
                                 "data_wOffset", ...
                                 "forceData_wOffset", ...
                                 "rawData", ...
                                 "timestamps", ...
                                 "params");

            app.OffsetSwitch.Value = initialOffsetState;
            app.ExportmatStatus.Text = 'Done!';
        end

        % Value changed function: BiasTick
        function BiasTickValueChanged(app, event)
            value = app.BiasTick.Value;
            if value && app.CurrentState == "Acquisition.ReadyForCapture"
                app.OffsetStartMoment = app.Timestamps(end);
                app.OffsetDataRaw = app.Data;
                app.CurrentState = 'Acquisition.CollectingOffset';
                setAppViewState(app, app.CurrentState);
            end
        end

        % Button pushed function: PlotChosenChannel
        function PlotChosenChannelButtonPushed(app, event)
            chosenChannel = app.ChannelplotselectDropDown.Value;
            if ~isnumeric(chosenChannel)
                chosenChannel = str2double(chosenChannel);
            end
            dataYLim = app.MinMaxYTable.Data;
            indexChannel = find(app.ChannelNumbers==chosenChannel);
            figure
            plot(app.CaptureTimestamps(:), app.CurrentPlottingData(:, indexChannel));
            xlim([app.CaptureTimestamps(1), app.CaptureTimestamps(end)]);
            ylim([dataYLim(indexChannel, 1), dataYLim(indexChannel, 2)]);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1434 733];
            app.UIFigure.Name = 'MATLAB App';

            % Create CaptureDataAxes
            app.CaptureDataAxes = uiaxes(app.UIFigure);
            title(app.CaptureDataAxes, 'Captured data')
            xlabel(app.CaptureDataAxes, 'Time (s)')
            ylabel(app.CaptureDataAxes, 'Voltage (V)')
            zlabel(app.CaptureDataAxes, 'Z')
            app.CaptureDataAxes.Position = [221 241 590 200];

            % Create TriggerChannelLabel
            app.TriggerChannelLabel = uilabel(app.UIFigure);
            app.TriggerChannelLabel.HorizontalAlignment = 'right';
            app.TriggerChannelLabel.Position = [12 371 90 22];
            app.TriggerChannelLabel.Text = 'Trigger Channel';

            % Create TriggerChannel
            app.TriggerChannel = uieditfield(app.UIFigure, 'numeric');
            app.TriggerChannel.HorizontalAlignment = 'center';
            app.TriggerChannel.Position = [119 371 80 22];
            app.TriggerChannel.Value = 1;

            % Create TriggerLevelVLabel
            app.TriggerLevelVLabel = uilabel(app.UIFigure);
            app.TriggerLevelVLabel.HorizontalAlignment = 'right';
            app.TriggerLevelVLabel.Position = [8 341 94 22];
            app.TriggerLevelVLabel.Text = ' Trigger Level (V)';

            % Create TriggerVoltage
            app.TriggerVoltage = uieditfield(app.UIFigure, 'numeric');
            app.TriggerVoltage.HorizontalAlignment = 'center';
            app.TriggerVoltage.Position = [119 341 80 22];
            app.TriggerVoltage.Value = 2;

            % Create TriggerandcaptureparametersLabel
            app.TriggerandcaptureparametersLabel = uilabel(app.UIFigure);
            app.TriggerandcaptureparametersLabel.HorizontalAlignment = 'center';
            app.TriggerandcaptureparametersLabel.Position = [38 401 174 22];
            app.TriggerandcaptureparametersLabel.Text = 'Trigger and capture parameters';

            % Create AcquisitionparametersLabel
            app.AcquisitionparametersLabel = uilabel(app.UIFigure);
            app.AcquisitionparametersLabel.Position = [59 691 129 22];
            app.AcquisitionparametersLabel.Text = 'Acquisition parameters';

            % Create VariablenameEditFieldLabel
            app.VariablenameEditFieldLabel = uilabel(app.UIFigure);
            app.VariablenameEditFieldLabel.HorizontalAlignment = 'right';
            app.VariablenameEditFieldLabel.Position = [22 222 81 22];
            app.VariablenameEditFieldLabel.Text = 'Variable name';

            % Create VariableNameEditField
            app.VariableNameEditField = uieditfield(app.UIFigure, 'text');
            app.VariableNameEditField.HorizontalAlignment = 'center';
            app.VariableNameEditField.Position = [118 222 80 22];
            app.VariableNameEditField.Value = 'capturedData';

            % Create DurationsEditField_2Label
            app.DurationsEditField_2Label = uilabel(app.UIFigure);
            app.DurationsEditField_2Label.HorizontalAlignment = 'right';
            app.DurationsEditField_2Label.Position = [34 251 70 22];
            app.DurationsEditField_2Label.Text = 'Duration (s)';

            % Create CaptureLengthField
            app.CaptureLengthField = uieditfield(app.UIFigure, 'numeric');
            app.CaptureLengthField.ValueChangedFcn = createCallbackFcn(app, @CaptureLengthFieldValueChanged, true);
            app.CaptureLengthField.HorizontalAlignment = 'center';
            app.CaptureLengthField.Position = [119 251 80 22];
            app.CaptureLengthField.Value = 1;

            % Create PlottingtimesEditFieldLabel
            app.PlottingtimesEditFieldLabel = uilabel(app.UIFigure);
            app.PlottingtimesEditFieldLabel.HorizontalAlignment = 'right';
            app.PlottingtimesEditFieldLabel.Position = [12 541 89 22];
            app.PlottingtimesEditFieldLabel.Text = 'Plotting time (s)';

            % Create LivePlotLengthField
            app.LivePlotLengthField = uieditfield(app.UIFigure, 'numeric');
            app.LivePlotLengthField.HorizontalAlignment = 'center';
            app.LivePlotLengthField.Position = [118 541 80 22];
            app.LivePlotLengthField.Value = 0.45;

            % Create ChannelslistEditFieldLabel
            app.ChannelslistEditFieldLabel = uilabel(app.UIFigure);
            app.ChannelslistEditFieldLabel.HorizontalAlignment = 'right';
            app.ChannelslistEditFieldLabel.Position = [27 631 74 22];
            app.ChannelslistEditFieldLabel.Text = 'Channels list';

            % Create ChannelsList
            app.ChannelsList = uieditfield(app.UIFigure, 'text');
            app.ChannelsList.ValueChangedFcn = createCallbackFcn(app, @ChannelsListValueChanged, true);
            app.ChannelsList.ValueChangingFcn = createCallbackFcn(app, @ChannelsListValueChanging, true);
            app.ChannelsList.HorizontalAlignment = 'center';
            app.ChannelsList.Position = [118 631 80 22];
            app.ChannelsList.Value = '0, 1, 2, 16, 17, 18, 19, 20, 21';

            % Create DeviceEditFieldLabel
            app.DeviceEditFieldLabel = uilabel(app.UIFigure);
            app.DeviceEditFieldLabel.HorizontalAlignment = 'right';
            app.DeviceEditFieldLabel.Position = [59 661 42 22];
            app.DeviceEditFieldLabel.Text = 'Device';

            % Create DeviceName
            app.DeviceName = uieditfield(app.UIFigure, 'text');
            app.DeviceName.HorizontalAlignment = 'center';
            app.DeviceName.Position = [118 661 80 22];
            app.DeviceName.Value = 'dev1';

            % Create AcquireSwitchLabel
            app.AcquireSwitchLabel = uilabel(app.UIFigure);
            app.AcquireSwitchLabel.HorizontalAlignment = 'center';
            app.AcquireSwitchLabel.Position = [132 434 46 31];
            app.AcquireSwitchLabel.Text = 'Acquire';

            % Create AcquireSwitch
            app.AcquireSwitch = uiswitch(app.UIFigure, 'slider');
            app.AcquireSwitch.Items = {'Stop', 'Start'};
            app.AcquireSwitch.ValueChangedFcn = createCallbackFcn(app, @AcquireSwitchFlip, true);
            app.AcquireSwitch.Position = [132 463 45 19];
            app.AcquireSwitch.Value = 'Stop';

            % Create ArmedLampLabel
            app.ArmedLampLabel = uilabel(app.UIFigure);
            app.ArmedLampLabel.HorizontalAlignment = 'right';
            app.ArmedLampLabel.Position = [16 504 41 22];
            app.ArmedLampLabel.Text = 'Armed';

            % Create ArmedLamp
            app.ArmedLamp = uilamp(app.UIFigure);
            app.ArmedLamp.Position = [72 504 20 20];

            % Create ArmButton
            app.ArmButton = uibutton(app.UIFigure, 'push');
            app.ArmButton.ButtonPushedFcn = createCallbackFcn(app, @ArmButtonPushed, true);
            app.ArmButton.Position = [21 474 71 26];
            app.ArmButton.Text = 'Arm';

            % Create DurationsEditField_2Label_2
            app.DurationsEditField_2Label_2 = uilabel(app.UIFigure);
            app.DurationsEditField_2Label_2.HorizontalAlignment = 'right';
            app.DurationsEditField_2Label_2.Position = [26 601 75 22];
            app.DurationsEditField_2Label_2.Text = 'Rate (scan/s)';

            % Create Rate
            app.Rate = uieditfield(app.UIFigure, 'numeric');
            app.Rate.ValueChangedFcn = createCallbackFcn(app, @RateValueChanged, true);
            app.Rate.HorizontalAlignment = 'center';
            app.Rate.Position = [118 601 80 22];
            app.Rate.Value = 1000;

            % Create PlotcolumnsEditFieldLabel
            app.PlotcolumnsEditFieldLabel = uilabel(app.UIFigure);
            app.PlotcolumnsEditFieldLabel.HorizontalAlignment = 'right';
            app.PlotcolumnsEditFieldLabel.Position = [18 571 86 22];
            app.PlotcolumnsEditFieldLabel.Text = 'Plot columns #';

            % Create PlotColumnCount
            app.PlotColumnCount = uieditfield(app.UIFigure, 'numeric');
            app.PlotColumnCount.HorizontalAlignment = 'center';
            app.PlotColumnCount.Position = [118 571 80 22];
            app.PlotColumnCount.Value = 3;

            % Create TriggerConditionDropDownLabel
            app.TriggerConditionDropDownLabel = uilabel(app.UIFigure);
            app.TriggerConditionDropDownLabel.HorizontalAlignment = 'right';
            app.TriggerConditionDropDownLabel.Position = [4 311 98 22];
            app.TriggerConditionDropDownLabel.Text = 'Trigger Condition';

            % Create TriggerCondition
            app.TriggerCondition = uidropdown(app.UIFigure);
            app.TriggerCondition.Items = {'Rising', 'Falling'};
            app.TriggerCondition.Position = [119 310 80 22];
            app.TriggerCondition.Value = 'Rising';

            % Create TriggerDelaysLabel
            app.TriggerDelaysLabel = uilabel(app.UIFigure);
            app.TriggerDelaysLabel.HorizontalAlignment = 'right';
            app.TriggerDelaysLabel.Position = [2 280 101 22];
            app.TriggerDelaysLabel.Text = 'Offset duration (s)';

            % Create OffsetDurationField
            app.OffsetDurationField = uieditfield(app.UIFigure, 'numeric');
            app.OffsetDurationField.HorizontalAlignment = 'center';
            app.OffsetDurationField.Position = [118 280 80 22];
            app.OffsetDurationField.Value = 1;

            % Create StatusLabel
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.Position = [220 443 47 22];
            app.StatusLabel.Text = 'Status: ';

            % Create StatusText
            app.StatusText = uilabel(app.UIFigure);
            app.StatusText.Position = [266 443 151 22];
            app.StatusText.Text = '';

            % Create MinMaxYTable
            app.MinMaxYTable = uitable(app.UIFigure);
            app.MinMaxYTable.ColumnName = {'Min Y'; 'Max Y'};
            app.MinMaxYTable.RowName = {'0, 1, 2'};
            app.MinMaxYTable.DisplayDataChangedFcn = createCallbackFcn(app, @MinMaxYTableDisplayDataChanged, true);
            app.MinMaxYTable.Position = [221 108 580 121];

            % Create CaptureButton
            app.CaptureButton = uibutton(app.UIFigure, 'state');
            app.CaptureButton.ValueChangedFcn = createCallbackFcn(app, @CaptureButtonValueChanged, true);
            app.CaptureButton.Text = 'Capture';
            app.CaptureButton.Position = [56 105 111 52];

            % Create DataPlotPanel
            app.DataPlotPanel = uipanel(app.UIFigure);
            app.DataPlotPanel.AutoResizeChildren = 'off';
            app.DataPlotPanel.Title = 'Data Plot Panel';
            app.DataPlotPanel.Position = [828 228 580 485];

            % Create PlotButton
            app.PlotButton = uibutton(app.UIFigure, 'push');
            app.PlotButton.ButtonPushedFcn = createCallbackFcn(app, @PlotButtonPushed, true);
            app.PlotButton.Position = [829 163 111 52];
            app.PlotButton.Text = 'Plot';

            % Create RunningstatPanel
            app.RunningstatPanel = uipanel(app.UIFigure);
            app.RunningstatPanel.Title = 'Running stat';
            app.RunningstatPanel.Scrollable = 'on';
            app.RunningstatPanel.Position = [1192 90 217 125];

            % Create BuffersizeLabel
            app.BuffersizeLabel = uilabel(app.RunningstatPanel);
            app.BuffersizeLabel.Position = [8 73 65 22];
            app.BuffersizeLabel.Text = 'Buffer size:';

            % Create BufferSizeValue
            app.BufferSizeValue = uilabel(app.RunningstatPanel);
            app.BufferSizeValue.Position = [72 73 92 22];
            app.BufferSizeValue.Text = '0';

            % Create FIFOcountLabel
            app.FIFOcountLabel = uilabel(app.RunningstatPanel);
            app.FIFOcountLabel.Position = [8 54 72 22];
            app.FIFOcountLabel.Text = 'FIFO count: ';

            % Create FIFOCountValue
            app.FIFOCountValue = uilabel(app.RunningstatPanel);
            app.FIFOCountValue.Position = [79 54 92 22];
            app.FIFOCountValue.Text = '0';

            % Create TriggerchannelLabel
            app.TriggerchannelLabel = uilabel(app.RunningstatPanel);
            app.TriggerchannelLabel.Position = [8 15 94 22];
            app.TriggerchannelLabel.Text = 'Trigger channel: ';

            % Create TriggerChannelLabelValue
            app.TriggerChannelLabelValue = uilabel(app.RunningstatPanel);
            app.TriggerChannelLabelValue.Position = [93 15 70 22];
            app.TriggerChannelLabelValue.Text = '';

            % Create CapturetimerLabel
            app.CapturetimerLabel = uilabel(app.RunningstatPanel);
            app.CapturetimerLabel.Position = [8 35 86 22];
            app.CapturetimerLabel.Text = 'Capture timer: ';

            % Create CapturetimerLabelValue
            app.CapturetimerLabelValue = uilabel(app.RunningstatPanel);
            app.CapturetimerLabelValue.Position = [93 35 70 22];
            app.CapturetimerLabelValue.Text = '0';

            % Create ExporttocsvButton
            app.ExporttocsvButton = uibutton(app.UIFigure, 'push');
            app.ExporttocsvButton.ButtonPushedFcn = createCallbackFcn(app, @ExporttocsvButtonPushed, true);
            app.ExporttocsvButton.Position = [521 66 90 22];
            app.ExporttocsvButton.Text = 'Export to .csv';

            % Create ApplycalibrationButton
            app.ApplycalibrationButton = uibutton(app.UIFigure, 'push');
            app.ApplycalibrationButton.ButtonPushedFcn = createCallbackFcn(app, @ApplycalibrationButtonPushed, true);
            app.ApplycalibrationButton.Position = [957 163 111 52];
            app.ApplycalibrationButton.Text = 'Apply calibration';

            % Create ExporttomatButton
            app.ExporttomatButton = uibutton(app.UIFigure, 'push');
            app.ExporttomatButton.ButtonPushedFcn = createCallbackFcn(app, @ExporttomatButtonPushed, true);
            app.ExporttomatButton.Position = [625 66 92 22];
            app.ExporttomatButton.Text = 'Export to .mat';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [221 474 580 242];

            % Create SubplotView
            app.SubplotView = uitab(app.TabGroup);
            app.SubplotView.Title = 'Subplot View';

            % Create SubplotAxesPanel
            app.SubplotAxesPanel = uipanel(app.SubplotView);
            app.SubplotAxesPanel.AutoResizeChildren = 'off';
            app.SubplotAxesPanel.Scrollable = 'on';
            app.SubplotAxesPanel.Position = [2 -2 578 220];

            % Create CombinedPlotView
            app.CombinedPlotView = uitab(app.TabGroup);
            app.CombinedPlotView.Title = 'Combined Plot View';

            % Create LiveDataAxes
            app.LiveDataAxes = uiaxes(app.CombinedPlotView);
            title(app.LiveDataAxes, 'Live plot combined')
            xlabel(app.LiveDataAxes, 'X')
            ylabel(app.LiveDataAxes, 'Y')
            zlabel(app.LiveDataAxes, 'Z')
            app.LiveDataAxes.XLim = [-10 10];
            app.LiveDataAxes.YLim = [0 1];
            app.LiveDataAxes.Position = [2 1 577 217];

            % Create VectorViewTab
            app.VectorViewTab = uitab(app.TabGroup);
            app.VectorViewTab.Title = 'Vector View';

            % Create VectorAxesPanel
            app.VectorAxesPanel = uipanel(app.VectorViewTab);
            app.VectorAxesPanel.AutoResizeChildren = 'off';
            app.VectorAxesPanel.Position = [1 1 578 217];

            % Create OffsetSwitchLabel
            app.OffsetSwitchLabel = uilabel(app.UIFigure);
            app.OffsetSwitchLabel.HorizontalAlignment = 'center';
            app.OffsetSwitchLabel.Position = [1145 90 38 22];
            app.OffsetSwitchLabel.Text = 'Offset';

            % Create OffsetSwitch
            app.OffsetSwitch = uiswitch(app.UIFigure, 'toggle');
            app.OffsetSwitch.Position = [1154 147 21 48];

            % Create SavingdirEditFieldLabel
            app.SavingdirEditFieldLabel = uilabel(app.UIFigure);
            app.SavingdirEditFieldLabel.HorizontalAlignment = 'right';
            app.SavingdirEditFieldLabel.Position = [49 67 59 22];
            app.SavingdirEditFieldLabel.Text = 'Saving dir';

            % Create SavingdirEditField
            app.SavingdirEditField = uieditfield(app.UIFigure, 'text');
            app.SavingdirEditField.Position = [123 65 384 22];
            app.SavingdirEditField.Value = '\\fsmresfiles.fsm.northwestern.edu\fsmresfiles\Basic_Sciences\Phys\TreschLab\Sam Analysis\MotionControlProject';

            % Create CalibrationTick
            app.CalibrationTick = uicheckbox(app.UIFigure);
            app.CalibrationTick.Text = 'Apply calibration';
            app.CalibrationTick.Position = [103 512 112 22];
            app.CalibrationTick.Value = true;

            % Create BiasTick
            app.BiasTick = uicheckbox(app.UIFigure);
            app.BiasTick.ValueChangedFcn = createCallbackFcn(app, @BiasTickValueChanged, true);
            app.BiasTick.Text = 'Apply bias';
            app.BiasTick.Position = [103 491 78 22];

            % Create SubjectnameLabel
            app.SubjectnameLabel = uilabel(app.UIFigure);
            app.SubjectnameLabel.HorizontalAlignment = 'right';
            app.SubjectnameLabel.Position = [23 193 80 22];
            app.SubjectnameLabel.Text = 'Subject name';

            % Create SubjectNameEditField
            app.SubjectNameEditField = uieditfield(app.UIFigure, 'text');
            app.SubjectNameEditField.HorizontalAlignment = 'center';
            app.SubjectNameEditField.Position = [118 193 80 22];
            app.SubjectNameEditField.Value = 'subject1';

            % Create TrialLabel
            app.TrialLabel = uilabel(app.UIFigure);
            app.TrialLabel.HorizontalAlignment = 'right';
            app.TrialLabel.Position = [65 165 37 22];
            app.TrialLabel.Text = 'Trial #';

            % Create TrialNumberField
            app.TrialNumberField = uispinner(app.UIFigure);
            app.TrialNumberField.RoundFractionalValues = 'on';
            app.TrialNumberField.Position = [117 165 81 22];

            % Create ChannelplotselectDropDownLabel
            app.ChannelplotselectDropDownLabel = uilabel(app.UIFigure);
            app.ChannelplotselectDropDownLabel.HorizontalAlignment = 'right';
            app.ChannelplotselectDropDownLabel.Position = [828 66 109 22];
            app.ChannelplotselectDropDownLabel.Text = 'Channel plot select';

            % Create ChannelplotselectDropDown
            app.ChannelplotselectDropDown = uidropdown(app.UIFigure);
            app.ChannelplotselectDropDown.Items = {'0', '1', '16', '17', '18', '19', '20', '21'};
            app.ChannelplotselectDropDown.Position = [952 66 100 22];
            app.ChannelplotselectDropDown.Value = '0';

            % Create PlotChosenChannel
            app.PlotChosenChannel = uibutton(app.UIFigure, 'push');
            app.PlotChosenChannel.ButtonPushedFcn = createCallbackFcn(app, @PlotChosenChannelButtonPushed, true);
            app.PlotChosenChannel.Position = [1067 65 100 22];
            app.PlotChosenChannel.Text = 'Plot channel';

            % Create ExportcsvStatus
            app.ExportcsvStatus = uilabel(app.UIFigure);
            app.ExportcsvStatus.HorizontalAlignment = 'center';
            app.ExportcsvStatus.WordWrap = 'on';
            app.ExportcsvStatus.Position = [521 14 90 53];
            app.ExportcsvStatus.Text = '';

            % Create ExportmatStatus
            app.ExportmatStatus = uilabel(app.UIFigure);
            app.ExportmatStatus.HorizontalAlignment = 'center';
            app.ExportmatStatus.WordWrap = 'on';
            app.ExportmatStatus.Position = [625 14 90 53];
            app.ExportmatStatus.Text = '';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = MotionControl

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end