function dataCapture(src, ~, c, hGui)
    %dataCapture Process DAQ acquired data when called by ScansAvailable event.
    %  dataCapture processes latest acquired data and timestamps from data
    %  acquisition object (src), and, based on specified capture parameters (c
    %  structure) and trigger configuration parameters from the user interface
    %  elements (hGui handles structure), updates UI plots and captures data.
    %
    %   c.TimeSpan        = triggered capture timespan (seconds)
    %   c.bufferTimeSpan  = required data buffer timespan (seconds)
    %   c.bufferSize      = required data buffer size (number of scans)
    %   c.plotTimeSpan    = continuous acquired data timespan (seconds)
    %
   
    [eventData, eventTimestamps] = read(src, src.ScansAvailableFcnCount, ...
        'OutputFormat', 'Matrix');
    
    
    % The read data is stored in a persistent buffer (dataBuffer), which is
    % sized to allow triggered data capture.
    % Since multiple calls to dataCapture will be needed for a triggered
    % capture, a trigger condition flag (trigActive) and a corresponding
    % data timestamp (trigMoment) are used as persistent variables.
    % Persistent variables retain their values between calls to the function.
    
    persistent dataBuffer trigActive trigMoment
    
    % If dataCapture is running for the first time, initialize persistent vars
    if eventTimestamps(1)==0
        dataBuffer = [];          % data buffer
        trigActive = false;       % trigger condition flag
        trigMoment = [];          % data timestamp when trigger condition met
        prevData = [];            % last data point from previous callback execution
    else
        prevData = dataBuffer(end, :);
    end
    
    % Store continuous acquisition timestamps and data in persistent FIFO
    % buffer dataBuffer
    latestData = [eventTimestamps, eventData];
    dataBuffer = [dataBuffer; latestData];
    numSamplesToDiscard = size(dataBuffer,1) - c.bufferSize;
    if (numSamplesToDiscard > 0)
        dataBuffer(1:numSamplesToDiscard, :) = [];
    end
    
    
    % Update live data plot
    % Plot latest plotTimeSpan seconds of data in dataBuffer
    samplesToPlot = min([round(c.plotTimeSpan * src.Rate), size(dataBuffer,1)]);
    firstPoint = size(dataBuffer, 1) - samplesToPlot + 1;
    % Update x-axis limits
    xlim(hGui.Axes1, [dataBuffer(firstPoint,1), dataBuffer(end,1)]);
    % Live plot has one line for each acquisition channel
    for ii = 1:numel(hGui.LivePlot)
        set(hGui.LivePlot(ii), 'XData', dataBuffer(firstPoint:end, 1), ...
                               'YData', dataBuffer(firstPoint:end, 1+ii))
    end
    
    
    % If capture is requested, analyze latest acquired data until a trigger
    % condition is met. After enough data is acquired for a complete capture,
    % as specified by the capture timespan, extract the capture data from the
    % data buffer and save it to a base workspace variable.
    
    % Get capture toggle button value (1 or 0) from UI
    captureRequested = hGui.CaptureButton.Value;
    
    if captureRequested && (~trigActive)
        % State: "Looking for trigger event"
    
        % Update UI status
        hGui.StatusText.String = 'Waiting for trigger';
    
        % Get the trigger configuration parameters from UI text inputs and
        %   place them in a structure.
        % For simplicity, validation of user input is not addressed in this example.
        trigConfig.Channel = sscanf(hGui.TrigChannel.String, '%u');
        trigConfig.Level = sscanf(hGui.TrigLevel.String, '%f');
        trigConfig.Slope = sscanf(hGui.TrigSlope.String, '%f');
    
        % Determine whether trigger condition is met in the latest acquired data
        % A custom trigger condition is defined in trigDetect user function
        [trigActive, trigMoment] = trigDetect(prevData, latestData, trigConfig);
    
    
    elseif captureRequested && trigActive && ((dataBuffer(end,1)-trigMoment) > c.TimeSpan)
        % State: "Acquired enough data for a complete capture"
        % If triggered and if there is enough data in dataBuffer for triggered
        % capture, then captureData can be obtained from dataBuffer.
        hGui.StatusText.String = 'Acquired enough data for a complete capture'

        % Find index of sample in dataBuffer with timestamp value trigMoment
        trigSampleIndex = find(dataBuffer(:,1) == trigMoment, 1, 'first');
        % Find index of sample in dataBuffer to complete the capture
        lastSampleIndex = round(trigSampleIndex + c.TimeSpan * src.Rate());
        captureData = dataBuffer(trigSampleIndex:lastSampleIndex, :);
    
        % Reset trigger flag, to allow for a new triggered data capture
        trigActive = false;
    
        % Update captured data plot (one line for each acquisition channel)
        for ii = 1:numel(hGui.CapturePlot)
            set(hGui.CapturePlot(ii), 'XData', captureData(:, 1), ...
                                      'YData', captureData(:, 1+ii))
        end
    
        % Update UI to show that capture has been completed
        hGui.CaptureButton.Value = 0;
        hGui.StatusText.String = '';
    
        % Save captured data to a base workspace variable
        % For simplicity, validation of user input and checking whether a variable
        % with the same name already exists are not addressed in this example.
        % Get the variable name from UI text input
        varName = hGui.VarName.String;
        % Use assignin function to save the captured data in a base workspace variable
        assignin('base', varName, captureData);
    
    elseif captureRequested && trigActive && ((dataBuffer(end,1)-trigMoment) < c.TimeSpan)
        % State: "Capturing data"
        % Not enough acquired data to cover capture timespan during this callback execution
        hGui.StatusText.String = 'Capturing data';
    
    elseif ~captureRequested
        % State: "Capture not requested"
        % Capture toggle button is not pressed, set trigger flag and update UI
        trigActive = false;
        hGui.StatusText.String = '';
    end
    
    drawnow

end