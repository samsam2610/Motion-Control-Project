function [trigDetected, trigMoment] = trigDetect(prevData, latestData, trigConfig)
    %trigDetect Detect if trigger condition is met in acquired data
    %   [trigDetected, trigMoment] = trigDetect(prevData, latestData, trigConfig)
    %   Returns a detection flag (trigDetected) and the corresponding timestamp
    %   (trigMoment) of the first data point which meets the trigger condition
    %   based on signal level and slope specified by the trigger parameters
    %   structure (trigConfig).
    %   The input data (latestData) is an N x M matrix corresponding to N acquired
    %   data scans, with the timestamps as the first column, and channel data
    %   as columns 2:M. The previous data point prevData (1 x M vector of timestamp
    %   and channel data) is used to determine the slope of the first data point.
    %
    %   trigConfig.Channel = index of trigger channel in data acquisition object channels
    %   trigConfig.Level   = signal trigger level (V)
    %   trigConfig.Slope   = signal trigger slope (V/s)
    
    % Condition for signal trigger level
    trigCondition1 = latestData(:, 1+trigConfig.Channel) > trigConfig.Level;
    
    data = [prevData; latestData];
    
    % Calculate slope of signal data points
    % Calculate time step from timestamps
    dt = latestData(2,1)-latestData(1,1);
    slope = diff(data(:, 1+trigConfig.Channel))/dt;
    
    % Condition for signal trigger slope
    trigCondition2 = slope > trigConfig.Slope;
    
    % If first data block acquired, slope for first data point is not defined
    if isempty(prevData)
        trigCondition2 = [false; trigCondition2];
    end
    
    % Combined trigger condition to be used
    trigCondition = trigCondition1 & trigCondition2;
    
    trigDetected = any(trigCondition);
    trigMoment = [];
    if trigDetected
        % Find time moment when trigger condition has been met
        trigTimeStamps = latestData(trigCondition, 1);
        trigMoment = trigTimeStamps(1);
    end
end