a = ones(200, 800, 1000);
video_name_file = "test" + ".avi";
videoExport = VideoWriter(video_name_file, 'Motion JPEG AVI'); 
videoExport.FrameRate = 200;

open(videoExport); 
tic

for i = 1:1000
%     parfeval(backgroundPool, @writeVideo, 0, videoExport, b);
    writeVideo(videoExport, a(:, :, i));
end
toc
close(videoExport)