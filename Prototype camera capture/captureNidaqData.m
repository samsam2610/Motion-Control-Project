function captureNidaqData(src, ~, fid1, fid2)
    a = datetime('now', 'Format','yyyy-MM-dd HH:mm:ss.SSSSSSS');
    [data, trigger_time] = read(src, src.ScansAvailableFcnCount);
    trigger_time.Format = 'yyyy MM dd HH mm ss.SSSSSSS';
    data = [seconds(data.Time), data.(1)]' ;
    fwrite(fid1, data, 'double'); 
    fprintf(fid2, '%s\n', char(trigger_time));
  
end