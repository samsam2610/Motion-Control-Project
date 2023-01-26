% This script is to test datetime object + time promise system
%% Setup camera object
% Create connection to the device using the specified adaptor with the specified 
% format.
delete(imaqfind)
videoObject_1 = videoinput('tisimaq_r2013_64', 2, 'Y800 (1024x768)');
videoObject_1.ReturnedColorspace = "grayscale";
videoObject_1.ROIPosition =  [239 535 785 232];
triggerconfig(videoObject_1, 'manual');
set(videoObject_1,'TriggerRepeat',inf);
src = getselectedsource(videoObject_1);
src.Exposure = 1/2^8;
src.Gain = 22;

clear f

camera_count = 1;
time_record = 20;
frame_rate = 200;
sample_count = frame_rate * time_record;
time_table_promise = 0:1/frame_rate:(time_record);

datetime_current = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');
[time_table, snapshot_store] = captureImage(videoObject_1, datetime_current, frame_rate, time_record, time_table_promise);

time_table_clean = time_table_1(time_table_1(:, 1)~=0, :);
diff_time = diff(time_table_1(:, 2));
jit_time = or(diff_time > (1/frame_rate + 1/frame_rate * 0.5), diff_time < (1/frame_rate - 1/frame_rate * 0.5));
variation  = diff(diff_time);

delete(videoObject_1)
delete(videoObject_2)
delete(imaqfind)
clear videoObject_1

function [time_table, snapshot_store] =  captureImage(videoObject, datetime_current, frame_rate, time_record, time_table_promise)
    time_table = cell(time_record * frame_rate, 4);
    time_table_index = 1;
    snapshot_store = uint8(zeros(232, 784, length(time_table)));
    ncount = 0;

    start(videoObject);

    time_start = datetime_current;
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
        time_tolerane = abs(time_diff) <= seconds(0.25*(1/frame_rate));

        if time_diff > 0 && ~time_tolerane % passed the promised time and higher than tolerance
            time_table_index = time_table_index + 1;
            time_table(ncount, :) = {-1, time_promise, 0, time_promise-time_start};
            continue
        elseif time_diff < 0 && ~time_tolerane % still time until promised time -> wait till the tolerance
            time_earliest = time_promise - seconds(0.1*(1/frame_rate));
            pause(time2num(time_earliest - time_current));
            time_previous = time_start;
            time_start = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');;
            snapshot_store(:, :, time_table_index) = getsnapshot(videoObject);
            time_table_index = time_table_index + 1;
            time_table(ncount, :) = {time_start-time_previous, time_promise, time_start, time_promise-time_start};

        elseif time_tolerane % within time tolerance -> proceed
            time_previous = time_start;
            time_start = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');;
            snapshot_store(:, :, time_table_index) = getsnapshot(videoObject);
            time_table_index = time_table_index + 1;
            time_table(ncount, :) = {time_start-time_previous, time_promise, time_start, time_promise-time_start};

        end

    end
    delete(imaqfind)
    disp(ncount)
end

