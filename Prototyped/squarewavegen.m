function [x, y] = squarewavegen(duration, interval, delay, length, samplingRate)
    signal_length = length*samplingRate;
    x = zeros(signal_length, 1);
    y = zeros(signal_length, 1);
    delay_length = round(samplingRate*delay, 3);
    interval_length = round(interval*samplingRate, 3);
    duration_length = round(duration*samplingRate, 3);
    signal_up = ones(duration_length, 1);
    pulse_count = floor((length - delay)/(interval));

    index_start = 1+delay_length;
    for index_pulse = 1:pulse_count
        index_end = index_start+duration_length-1;
        if index_end <= signal_length
            y(index_start:index_end) = signal_up;
        else
            y(index_start:end) = ones(signal_length-index_start, 1);
        end
        index_start = index_start + interval_length;
    end
    x = linspace(0, length, samplingRate*length)';
           
end