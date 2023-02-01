function [time_table, snapshot_store] =  captureImage(videoObject, ...
                                                      triggerUpdate, ...
                                                      terminationUpdate, ...
                                                      frame_rate, ...
                                                      time_record, ...
                                                      time_table_promise)

    time_table = cell(time_record * frame_rate, 9);
    snapshot_store = uint8(zeros(232, 784, time_record * frame_rate));
    ncount = 0;    
    
    % Send back the pollable termination status to the main core
    terminationStatus = parallel.pool.PollableDataQueue;
    pause(0.5);
    send(terminationUpdate, terminationStatus);
    pause(1);

    % Send back the pollable trigger to the main core
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

    % Start the capturing process
    vidStart = false;
    time_table_promise = time_start + seconds(time_table_promise);
    time_intial = time_table_promise(1);
    index_promise = 1;
    index_skip = false;
    WAIT_FACTOR = 0.85;
    start(videoObject);
    tic
    time_start_sys = toc;

    next_frame = time_start_sys + 1/frame_rate;
    while (1)

        ncount = ncount + 1;
        if mod(ncount+1, 500)  % Prevent memory leak.
            flushdata(videoObject); 
        end
        
        % Sam test - don't worry about this
        time_current = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');
        time_promise = time_table_promise(index_promise);
        time_diff = time_current - time_promise; % different between current time and promised time
        time_diff.Format = 's';

        % 
        time_current_sys = toc;
        time_wait = next_frame - time_current_sys;
        if time_wait > 0
            pause(time_wait*WAIT_FACTOR);
        end

        time_previous_sys = time_start_sys;
        time_start_sys = toc;

        [snapshot_store(:, :, index_promise), metadata] = getsnapshot(videoObject);
        time_previous = time_start;
        time_start = datetime(metadata.AbsTime, 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');
        time_table(index_promise, :) = {time2num(time_diff), ...
                                        time_promise, ...
                                        time_start, ...
                                        time2num(time_start-time_promise), ...
                                        time_wait,...
                                        time2num(time_promise-time_intial),...
                                        time2num(time_start-time_intial),...
                                        time_start_sys-time_previous_sys,... % time between frames according to the system
                                        time2num(time_start-time_previous) % metadata time between frames 
                                        };

        next_frame = max([next_frame + 1/frame_rate, time_start_sys + 1/frame_rate]);
       
        index_promise = index_promise + 1;
        index_skip = false;
        if time_current_sys > time_record
            break
        end
    end
    delete(imaqfind)
    disp(ncount)
    
end