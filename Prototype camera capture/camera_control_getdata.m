%% This file is to test on the treadmill/TDT computer - using TDT pulse as trigger. 
%% The test is about the accuracy of the absolute timestamp
clear all
%% Each run unique ID
imaqreset
daqreset
TIME_START = string(datetime('now', 'Format','dd_MMM_yyyy-HH_mm_ss'));

%% Setting parameters
SYSTEM_NAME = 'NIDAQ'; % type "NIDAQ" or "TDT" for trigger type
COMPUTER_NAME = 'Dell'; % type "Karen" or "Dell" for testing paths

DAQ_RATE = 10000;
DAQ_CHANNEL = [1];
DAQ_DEVICE_NAME = "Dev1";
DAQ_UNIT_NAME = "Voltage";

CAMERA_PROFILE = 'Y800 (1280x1024)';
CAMERA_EXPOSURE = 1/2^10;
CAMERA_GAIN = 16;
CAMERA_FRAMERATE = 200;

VIDEO_TIME_RECORD = 30; % seconds
VIDEO_FRAMERATE = 200; % fps
FRAME_COUNT = VIDEO_TIME_RECORD * VIDEO_FRAMERATE;
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
    VIDEO_NAME_PATH = ["E:\Test 2\Camera_1", ...
                       "E:\Test 2\Camera_2"];

case 'Karen'
    VIDEO_NAME_PATH = ["D:\test\Camera_1", ...
                       "D:\test\Camera_2"];
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


% %% Create the waitbar for the cancelation button
% hWaitBar = waitbar(0, 'Recording progress', 'CreateCancelBtn', ...
%                    @(src, event) setappdata(gcbf(), 'Cancelled', true));
% setappdata(hWaitBar, 'Cancelled', false);

%% Setup camera object
% Create connection to the device using the specified adaptor with the specified 
% format.
% Prepare the video file
videoData = struct;

video_name_file = VIDEO_NAME_PATH(1) + ".avi";
videoExport_1 = VideoWriter(video_name_file, 'Grayscale AVI'); 
videoExport_1.FrameRate = VIDEO_FRAMERATE;
time_store_1(1, 1) = 2;
time_store_1 = zeros(FRAME_COUNT+1, 6);
fileID_1 = fopen(VIDEO_NAMES(1) + ".txt", 'wt');
videoObject_1 = videoinput('tisimaq_r2013_64', '1', CAMERA_PROFILE);
videoObject_1.ReturnedColorspace = "grayscale";
% videoObject_1.ROIPosition =  [239 535 785 232];
videoObject_1.ROIPosition =  [495 351 VIDEO_WIDTH VIDEO_HEIGHT];
triggerconfig(videoObject_1, 'manual');
videoObject_1.LoggingMode = 'disk&memory';
videoObject_1.DiskLogger = videoExport_1;

set(videoObject_1,'TriggerRepeat', 0);
set(videoObject_1,'FramesPerTrigger', FRAME_COUNT);
set(videoObject_1,'FramesAcquiredFcnCount', 100);

videoObject_1.UserData = time_store_1;
videoObject_1.FramesAcquiredFcn = @(src, event) saveCaptureData(src, event, fileID_1);


src = getselectedsource(videoObject_1);
src.Exposure = CAMERA_EXPOSURE;
src.Gain = CAMERA_GAIN;
src.FrameRate = CAMERA_FRAMERATE;
src.GainAuto = 'Off';


video_name_file = VIDEO_NAME_PATH(2) + ".avi";
videoExport_2 = VideoWriter(video_name_file, 'Grayscale AVI'); 
videoExport_2.FrameRate = VIDEO_FRAMERATE;
time_store_2 = zeros(FRAME_COUNT, 6);

fileID_2 = fopen(VIDEO_NAMES(2) + ".txt", 'wt');

videoObject_2 = videoinput('tisimaq_r2013_64', '2', CAMERA_PROFILE);
videoObject_2.ReturnedColorspace = "grayscale";
videoObject_2.ROIPosition =  [320 108 VIDEO_WIDTH VIDEO_HEIGHT];
triggerconfig(videoObject_2, 'manual');
set(videoObject_2,'TriggerRepeat', 0);
set(videoObject_2,'FramesPerTrigger', FRAME_COUNT);
set(videoObject_2,'FramesAcquiredFcnCount', 100);
videoObject_2.LoggingMode = 'disk&memory';
videoObject_2.DiskLogger = videoExport_2;

videoObject_2.UserData = time_store_2;
videoObject_2.FramesAcquiredFcn = @(src, event) saveCaptureData(src, event, fileID_2);


src = getselectedsource(videoObject_2);
src.Exposure = CAMERA_EXPOSURE;
src.Gain = CAMERA_GAIN;
src.FrameRate = CAMERA_FRAMERATE;
src.GainAuto = 'Off';

disp('Starting NIDAQ');
fid1 = fopen("log.bin","w");
fid2 = fopen("time.txt", "wt");
deviceObject.ScansAvailableFcn = @(src,event) captureNidaqData(src, event, fid1, fid2);
%% Start the data acquisition

disp('Starting the camera...');
start(videoObject_1);
start(videoObject_2);
disp('Sending triggers ...')
trigger([videoObject_1, videoObject_2]);
start(deviceObject, 'continuous');

disp('Logging the data...')
abs_time_1 = videoObject_1.InitialTriggerTime;
abs_time_2 = videoObject_2.InitialTriggerTime;

wait(videoObject_1, Inf, 'logging');
wait(videoObject_2, Inf, 'logging');

while (videoObject_1.FramesAcquired ~= videoObject_1.DiskLoggerFrameCount) || (videoObject_2.FramesAcquired ~= videoObject_2.DiskLoggerFrameCount)
    pause(.1)
end
stop(deviceObject)

%% Saving the data
disp(videoObject_1.FramesAcquired)
disp(videoObject_1.DiskLoggerFrameCount)
fclose(fileID_2);
fclose(fileID_1);
fclose(fid1);
fclose(fid2);
%% Cleaning up
delete(videoObject_1)
delete(videoObject_2)
delete(imaqfind)
clear all


