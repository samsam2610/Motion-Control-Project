function y_value = get_y_value(x_value, x, y)
    x_value = round(x_value, 4);
    y_index = find(x==x_value);
    y_value = y(y_index);
    if isempty(y_value)
        y_value = 0;
    end
end