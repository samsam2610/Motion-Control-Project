%% 
%% Setup trigger object
deviceObject = daq('ni');

% Set acquisition rate, in scans/second
deviceObject.Rate = 1000;

deviceName = "Dev1";
unitName = "Voltage";
channelNumbers = [1];

for index = 1:length(channelNumbers)
    channelNumber = channelNumbers(index);
    channel = addinput(deviceObject, deviceName, "ai" + num2str(channelNumber), unitName);
    channel.TerminalConfig = 'SingleEnded';
end



%% Setup camera object
% Create connection to the device using the specified adaptor with the specified 
% format.
delete(imaqfind)
videoObject_1 = videoinput('tisimaq_r2013_64', '1', 'Y800 (1024x768)');
videoObject_1.ReturnedColorspace = "grayscale";
videoObject_1.ROIPosition =  [239 535 785 232];
triggerconfig(videoObject_1, 'manual');
set(videoObject_1,'TriggerRepeat',inf);
set(videoObject_1,'FramesPerTrigger',1);
src = getselectedsource(videoObject_1);
src.Exposure = 1/2^9;
src.Gain = 22;
src.FrameRate = 200;

videoObject_2 = videoinput('tisimaq_r2013_64', '2', 'Y800 (1024x768)');
videoObject_2.ReturnedColorspace = "grayscale";
videoObject_2.ROIPosition =  [16 536 785 232];
triggerconfig(videoObject_2, 'manual');
set(videoObject_2,'TriggerRepeat',inf);
set(videoObject_2,'FramesPerTrigger',1);
src = getselectedsource(videoObject_2);
src.Exposure = 1/2^9;
src.Gain = 22;
src.FrameRate = 200;

clear f

camera_count = 1;
time_record = 20;
frame_rate = 200;
sample_count = frame_rate * time_record;
time_table_promise = 0:1/frame_rate:(time_record);
time_table_promise = time_table_promise + 0.1*1/frame_rate;

triggerUpdate_1 = parallel.pool.PollableDataQueue;
triggerUpdate_2 = parallel.pool.PollableDataQueue;

f(1:2) = parallel.FevalFuture;
f(1) = parfeval(@captureImage, 2, videoObject_1, triggerUpdate_1, frame_rate, time_record, time_table_promise);
f(2) = parfeval(@captureImage, 2, videoObject_2, triggerUpdate_2, frame_rate, time_record, time_table_promise);
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
deviceObject.ScansAvailableFcn = @(src,event) triggerDetect(src, deviceObject, triggerStatus_1, triggerStatus_2);
start(deviceObject, 'continuous');

wait(f)

[time_table_1, snapshot_store_1] = fetchOutputs(f(1));
[time_table_2, snapshot_store_2] = fetchOutputs(f(2));
% [time_table, snapshot_store] =  captureImage(videoObject_1, frame_rate, time_record, time_table_promise);
%%
time_start_diff = duration(nan(length(time_table_2), 3), 'Format', 'mm:ss.SSSSSS');
for index_table = 1:length(time_table_2)
    current_diff = time_table_2{index_table, 3} - time_table_1{index_table, 3};
    current_diff.Format = 'mm:ss.SSSSSS';
    time_start_diff(index_table) = current_diff;
end

delete(videoObject_1)
delete(videoObject_2)
delete(imaqfind)
clear videoObject_1

function [time_table, snapshot_store] =  captureImage(videoObject, triggerUpdate, frame_rate, time_record, time_table_promise)
    time_table = cell(time_record * frame_rate, 4);
    time_table_index = 1;
    snapshot_store = uint8(zeros(232, 784, time_record * frame_rate));
    ncount = 0;    
    
    triggerStatus = parallel.pool.PollableDataQueue;
    pause(0.5);
    send(triggerUpdate, triggerStatus);
    pause(1);

    while (1)
        [time_start, ~] = poll(triggerStatus);
        if isdatetime(time_start) == 1
            break
        end
    end

    start(videoObject);
    time_table_promise = time_start + seconds(time_table_promise);

    for index_promise = 1:length(time_table_promise)
        ncount = ncount + 1;
        if mod(ncount+1,500)  % Prevent memory leak.
            flushdata(videoObject); 
        end
        
        time_current = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');
        time_promise = time_table_promise(index_promise);
        time_diff = time_current - time_promise; % different between current time and promised time
        time_diff.Format = 's';
        time_tolerane = abs(time_diff) <= seconds(0.1*(1/frame_rate));

        if time_diff > 0 && ~time_tolerane % passed the promised time and higher than tolerance
            time_table(index_promise, :) = {seconds(-1), time_promise, NaT, time_promise-time_start};
            continue
        elseif time_diff < 0 && ~time_tolerane % still time until promised time -> wait till the tolerance
%             time_earliest = time_promise - seconds(0.1*(1/frame_rate));
%             pause(time2num(time_earliest - time_current));
            time_previous = time_start;
            while(1)
                trigger(videoObject);
                [temp_image, ~, metadata] = getdata(videoObject, 1, 'uint8');
                time_current = datetime(metadata.AbsTime, 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');
                time_diff = time_current - time_promise; % different between current time and promised time
                time_diff.Format = 's';
                time_tolerane = abs(time_diff) <= seconds(0.1*(1/frame_rate));
                if time_tolerane
                    snapshot_store(:, :, index_promise) = temp_image;
                    time_start = time_current;
                    time_table(index_promise, :) = {seconds(time_start-time_previous), time_promise, time_start, time_promise-time_start};
                    break
                elseif time_diff > 0 && ~time_tolerane
                    time_table(index_promise, :) = {seconds(-1), time_promise, NaT, time_promise-time_start};
                    break
                end
                
            end
           

        elseif time_tolerane % within time tolerance -> proceed
            time_previous = time_start;
            trigger(videoObject);
            [snapshot_store(:, :, index_promise), ~, metadata] = getdata(videoObject, 1, 'uint8');
            time_start = datetime(metadata.AbsTime, 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');
            time_table(index_promise, :) = {seconds(time_start-time_previous), time_promise, time_start, time_promise-time_start};

        end

    end
    delete(imaqfind)
    disp(ncount)
end

