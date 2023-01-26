function triggerDetect(src, deviceObject, triggerStatus_1, triggerStatus_2)

    [data, timestamps, ~] = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");

    if any(data >= 1.0)
        datetime_current = datetime('now', 'Format','dd-MMM-yyyy HH:mm:ss.SSSSSSSSS');
        send(triggerStatus_1, datetime_current);
        send(triggerStatus_2, datetime_current);
        stop(deviceObject)
    end
    
end