

function create_camera()
    v = videoinput('tisimaq_r2013_64', 1, 'Y800 (1024x768)');
    v.ReturnedColorspace = "grayscale";
    v.ROIPosition =  [239 535 785 232];
end

function 