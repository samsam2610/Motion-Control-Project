function [time_table_nidaq, nidaq_average_list, nidaq_value_norm, ...
          value_list_norm, value_list_duration, time_table_sum, time_table_combine] = analyze_data(time_table_diff, time_offset, additional_offset, frame_count_total, ...
                                                                                  time_nidaq, data, value_list)
    time_table_sum = [0; cumsum(time_table_diff)] - time_offset-additional_offset;
    
    time_table_nidaq = time_nidaq(1) + data(2, :);
    
    value_list_median = median(value_list);
    value_list_mean = mean(value_list);
    value_list_std = std(value_list);
    value_list_offset = value_list - value_list_median;
    value_list_common = value_list_mean + 5*value_list_std;
    value_list_norm = value_list_offset./max(value_list_offset);
    value_list_duration = [value_list_norm(:), value_list_norm(:)].';
    value_list_duration = value_list_duration(:);
    time_table_start = zeros(frame_count_total, 1);
    exposure_list = zeros(frame_count_total, 3);
    for indexFrame = 1:frame_count_total
        exposure_time = 1/2^10;
        time_table_start(indexFrame) = time_table_sum(indexFrame) - exposure_time;
        exposure_list(indexFrame, :) = [exposure_time, 0, 0];
    end
    time_table_duration = [time_table_sum(:), time_table_start(:)];
    time_table_combine = time_table_duration.';
    time_table_combine = time_table_combine(:);
    
    nidaq_value_norm = data(2, :)./max(data(2, :));
    nidaq_average_list = zeros(frame_count_total, 1);
    for indexFrame = 1:frame_count_total
        time_value_1 = time_table_duration(indexFrame, 2);
        time_value_2 = time_table_duration(indexFrame, 1);
        nidaq_average_list(indexFrame) = find_window(data, time_value_1, time_value_2);
    end
end

