CAMERA_PROFILE = 'Y800 (1280x1024)';
CAMERA_EXPOSURE = 1/2^9;
CAMERA_GAIN = 22;
CAMERA_FRAMERATE = 200;

VIDEO_TIME_RECORD = 3600; % seconds
VIDEO_FRAMERATE = 200; % fps
VIDEO_WIDTH = 785; 
VIDEO_HEIGHT = 232;

deviceObject = daq('ni');

deviceObject.Rate = DAQ_RATE; % Set acquisition rate, in scans/second
deviceName = DAQ_DEVICE_NAME; % Set the device name
unitName = DAQ_UNIT_NAME; % Unit of the measurement
channelNumbers = DAQ_CHANNEL; % Channel to record

for index = 1:length(channelNumbers)
    channelNumber = channelNumbers(index);
    channel = addinput(deviceObject, deviceName, "ai" + num2str(channelNumber), unitName);
    channel.TerminalConfig = 'SingleEnded';
end
VIDEO_NAMES = ["Camera_1", "Camera_2"];
VIDEO_NAME_PATH = ["C:\Users\sqt3245\Dropbox\Tresch Lab\MotionControlProject\Prototype camera capture\Camera_1", ...
                    "E:\Test 2\Camera_2"];

delete(imaqfind)
videoObject_1 = videoinput('tisimaq_r2013_64', '1', CAMERA_PROFILE);
videoObject_1.ReturnedColorspace = "grayscale";
% videoObject_1.ROIPosition =  [239 535 785 232];
videoObject_1.ROIPosition =  [443 389 VIDEO_WIDTH VIDEO_HEIGHT];
triggerconfig(videoObject_1, 'manual');
set(videoObject_1,'TriggerRepeat', Inf);
set(videoObject_1,'FramesPerTrigger', 1000);
src = getselectedsource(videoObject_1);
src.Exposure = CAMERA_EXPOSURE;
src.Gain = CAMERA_GAIN;
src.FrameRate = CAMERA_FRAMERATE;
snapshot_store = uint8(zeros(232, 784));
time_store = zeros(1000, 1);
time_current = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');

%% Create the waitbar for the cancelation button
hWaitBar = waitbar(0, 'Recording progress', 'CreateCancelBtn', ...
                   @(src, event) setappdata(gcbf(), 'Cancelled', true));
setappdata(hWaitBar, 'Cancelled', false);

% set the pollable triggers to send to workers for start capturing signal 
triggerUpdate_1 = parallel.pool.PollableDataQueue;

% set the pollable termination signal to send to workers to terminating the capturing process
terminationUpdate_1 = parallel.pool.PollableDataQueue;

[time_store, time_start, snapshot_store] =  saveCaptureData(videoObject_1, ...
                                                            triggerUpdate_1, ...
                                                            terminationUpdate_1, ...
                                                            200, ...
                                                            10, ...
                                                            VIDEO_NAMES(1), ...
                                                            VIDEO_NAME_PATH(1));
pause(2)
terminationStatus_1 = poll(terminationUpdate_1);
while (1)
    if ~isa(terminationStatus_1, class(terminationUpdate_1))
        terminationStatus_1 = poll(terminationUpdate_1);
    end
    if isa(terminationStatus_1, class(terminationUpdate_1))
        break
    end
end

% Acquire pollable triggers from the cores
pause(2)
triggerStatus_1 = poll(triggerUpdate_1);
while (1)
    if ~isa(triggerStatus_1, class(triggerUpdate_1))
        triggerStatus_1 = poll(triggerUpdate_1);
    end
    if isa(triggerStatus_1, class(triggerUpdate_1))
        break
    end
end
beta = 1;

while current_running_time < VIDEO_TIME_RECORD
    current_running_time = toc;
    % Check to see if the cancel button was pressed.
    if getappdata(hWaitBar, 'Cancelled')
        datetime_current = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');
        fprintf('Turning off the recording cancelled.\n');
        send(terminationStatus_1, datetime_current);
        delete(hWaitBar);
        break;
    end
    waitbar(current_running_time/VIDEO_TIME_RECORD);
end
