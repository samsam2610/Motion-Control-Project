CAMERA_PROFILE = 'Y800 (1280x1024)';
CAMERA_EXPOSURE = 1/2^9;
CAMERA_GAIN = 22;
CAMERA_FRAMERATE = 200;

VIDEO_TIME_RECORD = 3600; % seconds
VIDEO_FRAMERATE = 200; % fps
VIDEO_WIDTH = 785; 
VIDEO_HEIGHT = 232;

delete(imaqfind)
videoObject_1 = videoinput('tisimaq_r2013_64', '1', CAMERA_PROFILE);
videoObject_1.ReturnedColorspace = "grayscale";
% videoObject_1.ROIPosition =  [239 535 785 232];
videoObject_1.ROIPosition =  [443 389 VIDEO_WIDTH VIDEO_HEIGHT];
triggerconfig(videoObject_1, 'immediate');
set(videoObject_1,'TriggerRepeat', Inf);
set(videoObject_1,'FramesPerTrigger', 1000);
src = getselectedsource(videoObject_1);
src.Exposure = CAMERA_EXPOSURE;
src.Gain = CAMERA_GAIN;
src.FrameRate = CAMERA_FRAMERATE;
snapshot_store = uint8(zeros(232, 784));
time_store = zeros(1000, 1);
time_current = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');

video_name_file = "E:\Test 2\Camera_2" + ".avi";
videoExport = VideoWriter(video_name_file); 
videoExport.FrameRate = 200;
open(videoExport); 

start(videoObject_1);

time_current = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');
for i = 1:1000
    [snapshot_store ,time] = getdata(videoObject_1, 1);
    writeVideo(videoExport, snapshot_store);
    time_store(i, 1) = time;
end
stop(videoObject_1);
close(videoExport);
delete(imaqfind)
a = readmatrix('Camera_1_08_Feb_2023-13_35_15.txt');
b = datetime(a, 'Format', 'yyyy-MM-dd HH:mm:ss.SSSSS');