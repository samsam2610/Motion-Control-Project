%% 200 fps
time_table_raw = readmatrix('Camera_1_10_Feb_2023-07_58_00.txt');
time_table = datetime(time_table_raw, 'Format', 'yyyy-MM-dd HH:mm:ss.SSSSSSS');
time_table_diff = time2num(diff(time_table));
time_table_sum = [0; cumsum(time_table_diff)];
time_table_sum(end)
plot(time_table_sum(2:end), time_table_diff);
hold on
%% 300 fps
time_table_raw = readmatrix('Camera_1_10_Feb_2023-13_31_09.txt');
time_table = datetime(time_table_raw, 'Format', 'yyyy-MM-dd HH:mm:ss.SSSSSSS');
time_table_diff = time2num(diff(time_table));
time_table_sum = [0; cumsum(time_table_diff)];
time_table_sum(end)
plot(time_table_sum(2:end), time_table_diff);
hold on
%% 400 fps
time_table_raw = readmatrix('Camera_1_10_Feb_2023-14_01_13.txt');
time_table = datetime(time_table_raw, 'Format', 'yyyy-MM-dd HH:mm:ss.SSSSSSS');
time_table_diff = time2num(diff(time_table));
time_table_sum = [0; cumsum(time_table_diff)];
time_table_sum(end)
plot(time_table_sum(2:end), time_table_diff);
hold on