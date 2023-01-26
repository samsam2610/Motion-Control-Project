%% Connect to Device
% Create connection to the device using the specified adaptor with the specified 
% format.
delete(imaqfind)
v = videoinput('tisimaq_r2013_64', 1, 'Y800 (1024x768)');
v.ReturnedColorspace = "grayscale";
v.ROIPosition =  [239 535 785 232];
clear f
triggerconfig(v, 'manual');
set(v,'TriggerRepeat',inf);
camera_count = 1;
time_record = 5;
frame_rate = 200;
sample_count = frame_rate * time_record;
time_table_promise = 1:1/frame_rate:time_record;

% f(1) = parallel.FevalFuture;
% f(1) = parfeval(@captureImage, 2, v, frame_rate, time_record);
% wait(f(1))
% [time_table, snapshot_store] = fetchOutputs(f(1));
[time_table, snapshot_store] =  captureImage(v, frame_rate, time_record, time_table_promise);
%%



time_table_clean = time_table(time_table(:, 1)~=0, :);
diff_time = diff(time_table(:, 2));
jit_time = or(diff_time > (1/frame_rate + 1/frame_rate * 0.5), diff_time < (1/frame_rate - 1/frame_rate * 0.5));
variation  = diff(diff_time);

delete(v)
delete(imaqfind)
clear v

function [time_table, snapshot_store] =  captureImage(videoObject, frame_rate, time_record, time_table_promise)
    time_table = zeros(time_record * frame_rate, 2);
    time_table_index = 1;
    snapshot_store = uint8(zeros(232, 784, length(time_table)));
    ncount = 0;
    start(videoObject);
    tic
    time_start = toc;
    next_frame = time_start + 1/frame_rate;

    while (1)
        ncount = ncount + 1;
        if mod(ncount+1,500)  % Prevent memory leak.
            flushdata(videoObject); 
        end
        time_current = toc;
        time_wait = abs(next_frame - time_current);

        pause(time_wait*0.85);

        time_previous = time_start;
        time_start = toc;
        snapshot_store(:, :, time_table_index) = getsnapshot(videoObject);

        time_table_index = time_table_index + 1;
        next_frame = max([next_frame + 1/frame_rate, time_start + 1/frame_rate]);
        time_table(ncount, :) = [time_start-time_previous, next_frame];

        if sum(time_current) > time_record
            break
        end
    end
    delete(imaqfind)
    disp(ncount)
end