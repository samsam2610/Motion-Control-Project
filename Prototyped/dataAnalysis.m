close all
%% Generate the graphs
figure
duration = 20;
frequency = 100;
numberOfSamples = duration*10e1*frequency;
[x_square, y_square] = squarewavegen(0.001, 0.005, 0, duration, 6000);
plot(x_square, y_square);
hold on
x_square = round(x_square, 4);

[x_pulse, y_pulse] = squarewavegen(0.0001, 0.01, 0.0005, duration, 10000);
% plot(x_pulse, y_pulse)
hold on
x_pulse = round(x_pulse, 4);

[x_ideal, y_ideal] = squarewavegen(0.002, 0.01, 0, duration, 10000);
plot(x_ideal, y_ideal)
hold on
x_ideal = round(x_ideal, 4);

samplingRate = 200;

s1 = [135 262]; % spot location for snapshot 1
s2 = [111 368]; % spot location for snapshot 2
[lenght, width, height] = size(snapshot_store_1);

value_1 = zeros(height, 1);
value_2 = zeros(height, 1);
time_start_ideal = zeros(height, 2);
time_start_actual_1 = zeros(height, 6);
time_start_actual_2 = zeros(height, 6);
pixel_actual_1 = time_table_1;
pixel_actual_2 = time_table_2;

metaOffset = 0.005;
sysOffset = 0.005;

sys_time_1 = cumsum(cell2mat(time_table_1(:, 8)))+sysOffset;
sys_time_2 = cumsum(cell2mat(time_table_2(:, 8)))+sysOffset;
for index_height = 1:4000
    if isempty(time_table_1{index_height, 2}) || isempty(time_table_2{index_height, 2}) || time_table_2{index_height, 8} == 1 || time_table_1{index_height, 8} == 1
        continue
    end
    time_sys_1 = sys_time_1(index_height);
    pixel_sys_1 = get_y_value(time_sys_1, x_ideal, y_ideal);

    time_sys_2 = sys_time_2(index_height);
    pixel_sys_2 = get_y_value(time_sys_2, x_ideal, y_ideal);

    time_expect_1 = time_table_1{index_height, 7}+metaOffset;
    pixel_expect_1 = get_y_value(time_expect_1, x_ideal, y_ideal);

    time_expect_2 = time_table_2{index_height, 7}+metaOffset;
    pixel_expect_2 = get_y_value(time_expect_2, x_ideal, y_ideal);
    
    % pixel value for the LEDs
    value_1(index_height) = snapshot_store_1(s1(1), s1(2), index_height)/255;
    value_2(index_height) = snapshot_store_2(s2(1), s2(2), index_height)/255;

    % Calculate time each snapshot was supposed to be taken
    current_diff_1 = time_table_1{index_height, 2} - time_table_1{1, 2};
    current_diff_1.Format = 'mm:ss.SSSSSS';
    current_diff_2 = time_table_2{index_height, 2} - time_table_2{1, 2};
    current_diff_2.Format = 'mm:ss.SSSSSS';
    time_start_ideal(index_height, :) = [seconds(current_diff_1), seconds(current_diff_2)];

    % Calculate time each snapshot was supposed to be taken
    current_diff = time_table_1{index_height, 3} - time_table_1{1, 2};
    current_diff.Format = 'mm:ss.SSSSSS';
    time_start_actual_1(index_height, :) = [seconds(current_diff), value_1(index_height), pixel_sys_1, pixel_expect_1, time_table_1{index_height, 7}+metaOffset, seconds(current_diff_1)-seconds(current_diff)];

    current_diff = time_table_2{index_height, 3} - time_table_2{1, 2};
    current_diff.Format = 'mm:ss.SSSSSS';
    time_start_actual_2(index_height, :) = [seconds(current_diff), value_2(index_height), pixel_sys_2, pixel_expect_2, time_table_2{index_height, 7}+metaOffset, seconds(current_diff_2)-seconds(current_diff)];


end

scatter(time_start_actual_1(1:samplingRate*duration, 1)+0.0005, time_start_actual_1(1:samplingRate*duration, 2)-0.005, 42, 'filled');
hold on
scatter(time_start_actual_2(1:samplingRate*duration, 1)+0.0005, time_start_actual_2(1:samplingRate*duration, 2)+0.005, 42, 'filled');
hold on
scatter(time_start_ideal(1:samplingRate*duration, 1)+0.0005, zeros(samplingRate*duration, 1)-0.0001, 'filled');
