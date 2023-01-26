function softwareAnalogTriggerCapture
    %softwareAnalogTriggerCapture DAQ data capture using software-analog triggering
    %   softwareAnalogTriggerCapture launches a user interface for live DAQ data
    %   visualization and interactive data capture based on a software analog
    %   trigger condition.
    
    % Configure data acquisition object and add input channels
    deviceObject = daq('ni') 

    % Set acquisition rate, in scans/second
    deviceObject.Rate = 1000;
    
    deviceName = "Dev1";
    unitName = "Voltage";
    channelNumbers = [1, 2, 16, 17, 18, 19, 20, 21];
    for index = 1:length(channelNumbers)
        channelNumber = channelNumbers(index);
        channel = addinput(deviceObject, deviceName, "ai" + num2str(channelNumber), unitName);
        channel.TerminalConfig = 'SingleEnded';
    end

    % Display graphical user interface
    hGui = createDataCaptureUI(deviceObject);

    % Specify the desired parameters for data capture and live plotting.
    % The data capture parameters are grouped in a structure data type,
    % as this makes it simpler to pass them as a function argument.
    
    % Specify triggered capture timespan, in seconds
    capture.TimeSpan = sscanf(hGui.TimeSpan.String, '%f');
    
    % Specify continuous data plot timespan, in seconds
    capture.plotTimeSpan = sscanf(hGui.plotTimeSpan.String, '%f');
    
    % Determine the timespan corresponding to the block of samples supplied
    % to the ScansAvailable event callback function.
    callbackTimeSpan = double(deviceObject.ScansAvailableFcnCount)/deviceObject.Rate;
    % Determine required buffer timespan, seconds
    capture.bufferTimeSpan = max([capture.plotTimeSpan, capture.TimeSpan * 3, callbackTimeSpan * 3]);
    % Determine data buffer size
    capture.bufferSize =  round(capture.bufferTimeSpan * deviceObject.Rate);
    
    % Configure a ScansAvailableFcn callback function
    % The specified data capture parameters and the handles to the UI graphics
    % elements are passed as additional arguments to the callback function.
    deviceObject.ScansAvailableFcn = @(src,event) dataCapture(src, event, capture, hGui);
    
    % Configure a ErrorOccurredFcn callback function for acquisition error
    % events which might occur during background acquisition
    deviceObject.ErrorOccurredFcn = @(src,event) disp(getReport(event.Error));
    
    % Start continuous background data acquisition
    start(deviceObject, 'continuous')
    
    % Wait until data acquisition object is stopped from the UI
    while deviceObject.Running
        pause(0.5)
    end
    
    % Disconnect from hardware
    delete(deviceObject)
end