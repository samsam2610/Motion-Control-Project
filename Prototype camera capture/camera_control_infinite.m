%% This file is to test on the treadmill/TDT computer - using TDT pulse as trigger. 
%% The test is about the accuracy of the absolute timestamp

%% Each run unique ID
TIME_START = string(datetime('now', 'Format','dd_MMM_yyyy-HH_mm_ss'));

%% Setting parameters
SYSTEM_NAME = 'TDT'; % type "NIDAQ" or "TDT" for trigger type
COMPUTER_NAME = 'Karen'; % type "Karen" or "Dell" for testing paths

DAQ_RATE = 1000;
DAQ_CHANNEL = [1];
DAQ_DEVICE_NAME = "Dev1";
DAQ_UNIT_NAME = "Voltage";

CAMERA_PROFILE = 'Y800 (1280x1024)';
CAMERA_EXPOSURE = 1/2^9;
CAMERA_GAIN = 22;
CAMERA_FRAMERATE = 200;

VIDEO_TIME_RECORD = 3600; % seconds
VIDEO_FRAMERATE = 200; % fps
VIDEO_WIDTH = 785; 
VIDEO_HEIGHT = 232;

TIME_TABLE_OFFSET = 0.1; % offset 0 to a percentage of framerate - guessed number - not sure

VIDEO_EXPORT = true;
VIDEO_NAMES = ["Camera_1", "Camera_2"];


for indexName = 1:length(VIDEO_NAMES)
    VIDEO_NAMES(indexName) = VIDEO_NAMES(indexName) + "_" + TIME_START;
end

%% Setup video name path based on computer
switch COMPUTER_NAME
case 'Dell'
    VIDEO_NAME_PATH = ["C:\Users\sqt3245\Dropbox\Tresch Lab\MotionControlProject\Prototype camera capture\Camera_1", ...
                       "E:\Test 2\Camera_2"];

case 'Karen'
    VIDEO_NAME_PATH = ["C:\Users\sqt3245\test\Camera_1", ...
                       "D:\test"];
end

%% Setup TDT/NIDAQ connection
switch SYSTEM_NAME
case 'TDT'
    addpath(genpath('C:\TDT\TDTMatlabSDK'));
    syn = SynapseAPI('localhost');

case 'NIDAQ'
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
end


%% Create the waitbar for the cancelation button
hWaitBar = waitbar(0, 'Recording progress', 'CreateCancelBtn', ...
                   @(src, event) setappdata(gcbf(), 'Cancelled', true));
setappdata(hWaitBar, 'Cancelled', false);

%% Setup camera object
% Create connection to the device using the specified adaptor with the specified 
% format.
delete(imaqfind)
videoObject_1 = videoinput('tisimaq_r2013_64', '1', CAMERA_PROFILE);
videoObject_1.ReturnedColorspace = "grayscale";
% videoObject_1.ROIPosition =  [239 535 785 232];
videoObject_1.ROIPosition =  [428 630 VIDEO_WIDTH VIDEO_HEIGHT];
triggerconfig(videoObject_1, 'manual');
set(videoObject_1,'TriggerRepeat', inf);
set(videoObject_1,'FramesPerTrigger', 1);
src = getselectedsource(videoObject_1);
src.Exposure = CAMERA_EXPOSURE;
src.Gain = CAMERA_GAIN;
src.FrameRate = CAMERA_FRAMERATE;

videoObject_2 = videoinput('tisimaq_r2013_64', '2', CAMERA_PROFILE);
videoObject_2.ReturnedColorspace = "grayscale";
videoObject_2.ROIPosition =  [445 760 VIDEO_WIDTH VIDEO_HEIGHT];
triggerconfig(videoObject_2, 'manual');
set(videoObject_2,'TriggerRepeat', inf);
set(videoObject_2,'FramesPerTrigger', 1);
src = getselectedsource(videoObject_2);
src.Exposure = CAMERA_EXPOSURE;
src.Gain = CAMERA_GAIN;
src.FrameRate = CAMERA_FRAMERATE;

clear f

time_record = VIDEO_TIME_RECORD;
frame_rate = VIDEO_FRAMERATE;
sample_count = frame_rate * time_record;
time_table_promise = 0:1/frame_rate:(time_record);
time_table_promise = time_table_promise + TIME_TABLE_OFFSET*1/frame_rate;


% set the pollable triggers to send to workers for start capturing signal 
triggerUpdate_1 = parallel.pool.PollableDataQueue;
triggerUpdate_2 = parallel.pool.PollableDataQueue;

% set the pollable termination signal to send to workers to terminating the capturing process
terminationUpdate_1 = parallel.pool.PollableDataQueue;
terminationUpdate_2 = parallel.pool.PollableDataQueue;

tic

% Start the workers and send the parameters
f(1:2) = parallel.FevalFuture;
f(1) = parfeval(@saveCaptureImage, ... % name of the function to send to the worker
                2, ... % number of expecting outputs
                videoObject_1, ...
                triggerUpdate_1, ...
                terminationUpdate_1, ...
                frame_rate, ...
                time_table_promise, ...
                VIDEO_NAMES(1), ...
                VIDEO_NAME_PATH(1));

f(2) = parfeval(@saveCaptureImage, ... % name of the function to send to the worker
                2, ... % number of expecting outputs
                videoObject_2, ...
                triggerUpdate_2, ...
                terminationUpdate_2, ...
                frame_rate, ...
                time_table_promise, ...
                VIDEO_NAMES(2), ...
                VIDEO_NAME_PATH(2));

% Acquire pollable terminations from the cores
pause(2)
terminationStatus_1 = poll(terminationUpdate_1);
terminationStatus_2 = poll(terminationUpdate_2);
while (1)
    if ~isa(terminationStatus_1, class(terminationUpdate_1))
        terminationStatus_1 = poll(terminationUpdate_1);
    end
    if ~isa(terminationStatus_2, class(terminationUpdate_2))
        terminationStatus_2 = poll(terminationUpdate_2);
    end
    if isa(terminationStatus_1, class(terminationUpdate_1)) && isa(terminationStatus_2, class(terminationUpdate_2))
        break
    end
end

% Acquire pollable triggers from the cores
pause(2)
triggerStatus_1 = poll(triggerUpdate_1);
triggerStatus_2 = poll(triggerUpdate_2);
while (1)
    if ~isa(triggerStatus_1, class(triggerUpdate_1))
        triggerStatus_1 = poll(triggerUpdate_1);
    end
    if ~isa(triggerStatus_2, class(triggerUpdate_2))
        triggerStatus_2 = poll(triggerUpdate_2);
    end
    if isa(triggerStatus_1, class(triggerUpdate_1)) && isa(triggerStatus_2, class(triggerUpdate_2))
        break
    end
end
beta = 1;

switch SYSTEM_NAME
case 'TDT'
    % Read the pulse from TDT info to the camera to start capturing
    while (1)
        params = syn.getParameterValue('PulseGen1', 'out_FloatOut');
        if params > 1
            datetime_current = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');
            send(triggerStatus_1, datetime_current);
            send(triggerStatus_2, datetime_current);
            break
        end
    end

case 'NIDAQ'
    % send trigger info to the camera to start capturing
    deviceObject.ScansAvailableFcn = @(src,event) triggerDetect(src, deviceObject, triggerStatus_1, triggerStatus_2);
    start(deviceObject, 'continuous');

end


current_running_time = toc;
while current_running_time < VIDEO_TIME_RECORD
    current_running_time = toc;
    % Check to see if the cancel button was pressed.
    if getappdata(hWaitBar, 'Cancelled')
        datetime_current = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');
        fprintf('Turning off the recording cancelled.\n');
        send(terminationStatus_1, datetime_current);
        send(terminationStatus_2, datetime_current);
        delete(hWaitBar);
        break;
    end
    waitbar(current_running_time/VIDEO_TIME_RECORD);
end


[time_table_1, snapshot_store_1] = fetchOutputs(f(1));
[time_table_2, snapshot_store_2] = fetchOutputs(f(2));

%% Cleaning up
delete(videoObject_1)
delete(videoObject_2)
delete(imaqfind)
clear videoObject_1 videoObject_2

