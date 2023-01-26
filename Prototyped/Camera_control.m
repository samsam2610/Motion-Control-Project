%% Connect to Device
% Create connection to the device using the specified adaptor with the specified 
% format.
delete(imaqfind)
v = videoinput('tisimaq_r2013_64', 1, 'Y800 (1024x768)');
v.ReturnedColorspace = "grayscale";
v.ROIPosition =  [239 535 785 232];
% p = parpool(2);

triggerconfig(v, 'manual');
set(v,'TriggerRepeat',inf);
tic
frame_rate = 200;

time_record = 5;
time_table = zeros(time_record * frame_rate, 2);
time_table_index = 1;
snapshot_store = uint8(zeros(232, 784, length(time_table)));
ncount = 0;

start(v);
time_start = toc;
next_frame = time_start+1/frame_rate;
while (1)
    time_current = toc;
    time_diff = time_current - time_start;
    ncount = ncount+1;
    if mod(ncount+1,500)  % Prevent memory leak.
%        flushdata(v); 
    end
    if time_current >= next_frame
        time_start = toc;
%         snapshot_store(:, :, time_table_index) = getsnapshot(v);
        getsnapshot(v);
        time_table_index = time_table_index + 1;
        next_frame = max([next_frame + 1/frame_rate, time_start + 0.5/frame_rate]);
        time_table(time_table_index, :) = [time_diff, time_current];
    else
        continue
    end

    if sum(time_current) > time_record
        break
    end
end

time_table = time_table(time_table(:, 1)~=0, :);
diff_time = diff(time_table(:, 2));
jit_time = or(diff_time > (1/frame_rate + 1/frame_rate * 0.5), diff_time < (1/frame_rate - 1/frame_rate * 0.5));
variation  = diff(diff_time);

delete(v)
delete(imaqfind)
clear v
%% Parfeval test