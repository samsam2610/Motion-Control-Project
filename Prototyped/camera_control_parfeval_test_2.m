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
v = videoinput('tisimaq_r2013_64', 1, 'Y800 (1024x768)');
v.ReturnedColorspace = "grayscale";
v.ROIPosition =  [239 535 785 232];
src = getselectedsource(v);
src.Exposure = 1/2^8;
src.Gain = 22;
clear f
triggerconfig(v, 'manual');
set(v,'TriggerRepeat',inf);
camera_count = 1;
time_record = 5;
frame_rate = 200;
sample_count = frame_rate * time_record;
time_table_promise = 0:1/frame_rate:(time_record);

parpool('local', 2);
triggerUpdate = parallel.pool.PollableDataQueue;




f(1) = parallel.    FevalFuture;
f(1) = parfeval(@captureImage, 2, v, triggerUpdate, frame_rate, time_record, time_table_promise);
pause(0.5)
triggerStatus = poll(triggerUpdate);

deviceObject.ScansAvailableFcn = @(src,event) triggerDetect(src, triggerStatus);
start(deviceObject, 'continuous');
wait(f(1))
[time_table, snapshot_store] = fetchOutputs(f(1));
% [time_table, snapshot_store] =  captureImage(v, frame_rate, time_record, time_table_promise);
%%



time_table_clean = time_table(time_table(:, 1)~=0, :);
diff_time = diff(time_table(:, 2));
jit_time = or(diff_time > (1/frame_rate + 1/frame_rate * 0.5), diff_time < (1/frame_rate - 1/frame_rate * 0.5));
variation  = diff(diff_time);

delete(v)
delete(imaqfind)
clear v

function [time_table, snapshot_store] =  captureImage(videoObject, triggerUpdate, frame_rate, time_record, time_table_promise)
    time_table = zeros(time_record * frame_rate, 4);
    time_table_index = 1;
    snapshot_store = uint8(zeros(232, 784, length(time_table)));
    ncount = 0;

    triggerStatus = parallel.pool.PollableDataQueue;
    send(triggerUpdate, triggerStatus);
    while (1)
        [value, ~] = poll(triggerStatus);
        if value == 1
            break
        end
    end

    start(videoObject);
    tic
    time_start = toc;


    for index_promise = 1:length(time_table_promise)
        ncount = ncount + 1;
        if mod(ncount+1,500)  % Prevent memory leak.
            flushdata(videoObject); 
        end
        
        time_current = toc;
        time_promise = time_table_promise(index_promise);
        time_diff = time_current - time_promise; % different between current time and promised time
        time_tolerane = abs(time_diff) <= 0.25*(1/frame_rate);

        if time_diff > 0 && ~time_tolerane % passed the promised time and higher than tolerance
            time_table_index = time_table_index + 1;
            time_table(ncount, :) = [0, time_promise, 0, time_promise-time_start];
            continue
        elseif time_diff < 0 && ~time_tolerane % still time until promised time -> wait till the tolerance
            time_earliest = time_promise - 0.1*(1/frame_rate);
            pause(time_earliest - time_current);
            time_previous = time_start;
            time_start = toc;
            snapshot_store(:, :, time_table_index) = getsnapshot(videoObject);
            time_table_index = time_table_index + 1;
            time_table(ncount, :) = [time_start-time_previous, time_promise, time_start, time_promise-time_start];

        elseif time_tolerane % within time tolerance -> proceed
            time_previous = time_start;
            time_start = toc;
            snapshot_store(:, :, time_table_index) = getsnapshot(videoObject);
            time_table_index = time_table_index + 1;
            time_table(ncount, :) = [time_start-time_previous, time_promise, time_start, time_promise-time_start];

        end

    end
    delete(imaqfind)
    disp(ncount)
end

function triggerOutput = triggerDetect(src, triggerStatus)
    [data, timestamps, ~] = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");
    status = 0;
    if any(data >= 1.0)
        status = 1;
    end
    send(triggerStatus, status);
    
end