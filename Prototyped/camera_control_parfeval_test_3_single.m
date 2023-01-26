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
videoObject_1 = videoinput('tisimaq_r2013_64', 1, 'Y800 (1024x768)');
videoObject_1.ReturnedColorspace = "grayscale";
videoObject_1.ROIPosition =  [239 535 785 232];
triggerconfig(videoObject_1, 'manual');
set(videoObject_1,'TriggerRepeat',inf);
src = getselectedsource(videoObject_1);
src.Exposure = 1/2^8;
src.Gain = 22;

camera_count = 1;
time_record = 5;
frame_rate = 200;
sample_count = frame_rate * time_record;
time_table_promise = 0:1/frame_rate:(time_record);

triggerUpdate_1 = parallel.pool.PollableDataQueue;

f(1) = parallel.FevalFuture;
f(1) = parfeval(@captureImage, 2, videoObject_1, triggerUpdate_1, frame_rate, time_record, time_table_promise);

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
deviceObject.ScansAvailableFcn = @(src,event) triggerDetect_feval(src, deviceObject, triggerStatus_1);
start(deviceObject, 'continuous');

wait(f)

[time_table_1, snapshot_store_1] = fetchOutputs(f(1));


delete(videoObject_1)

delete(imaqfind)
clear videoObject_1

function [time_table, snapshot_store] =  captureImage(videoObject, triggerUpdate, frame_rate, time_record, time_table_promise)
    triggerStatus = parallel.pool.PollableDataQueue;
    pause(0.5);
    send(triggerUpdate, triggerStatus);
    pause(1);

    time_table = cell(time_record * frame_rate, 4);
    time_table_index = 1;
    snapshot_store = uint8(zeros(232, 784, time_record * frame_rate)) + 255;
    ncount = 0;


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
        time_tolerane = abs(time_diff) <= seconds(0.25*(1/frame_rate));

        if time_diff > 0 && ~time_tolerane % passed the promised time and higher than tolerance
            time_table_index = time_table_index + 1;
            time_table(ncount, :) = {seconds(-1), time_promise, NaT, time_promise-time_start};
            continue
        elseif time_diff < 0 && ~time_tolerane % still time until promised time -> wait till the tolerance
            time_earliest = time_promise - seconds(0.1*(1/frame_rate));
            pause(time2num(time_earliest - time_current));
            time_previous = time_start;
            time_start = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');
            snapshot_store(:, :, time_table_index) = getsnapshot(videoObject);
            time_table_index = time_table_index + 1;
            time_table(ncount, :) = {seconds(time_start-time_previous), time_promise, time_start, time_promise-time_start};

        elseif time_tolerane % within time tolerance -> proceed
            time_previous = time_start;
            time_start = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');
            snapshot_store(:, :, time_table_index) = getsnapshot(videoObject);
            time_table_index = time_table_index + 1;
            time_table(ncount, :) = {seconds(time_start-time_previous), time_promise, time_start, time_promise-time_start};

        end

    end
    delete(imaqfind)
    disp(ncount)
end

