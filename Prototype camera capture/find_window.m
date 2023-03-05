function nidaq_average = find_window(nidaq_data, time_value_1, time_value_2)
    lower_bound = nidaq_data(1, :) >= time_value_1;
    upper_bound = nidaq_data(1, :) <= time_value_2;
    value_index = lower_bound & upper_bound;
    if ~isempty(value_index)
        value_list = nidaq_data(2, value_index);
        a = find(value_list(:) > 0, 1);
        nidaq_average = double(~isempty(a));
    else
        nidaq_average = -1;
    end
end