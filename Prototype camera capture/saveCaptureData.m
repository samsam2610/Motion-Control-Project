%% Unlike captureImage, saveCaptureImage will attempt to write the frames directly into the video files
function saveCaptureData(src, event, filename)
    
    [~, ~, metadata] = getdata(src, src.FramesAcquiredFcnCount);
%    writematrix(event.Data.AbsTime, filename, 'Delimiter', 'tab', 'WriteMode', 'append');
    for indexFrame = 1:src.FramesAcquiredFcnCount
        fprintf(filename, '%i %i %i %i %i %.7f\n', metadata(indexFrame).AbsTime(1:6));
    end


end