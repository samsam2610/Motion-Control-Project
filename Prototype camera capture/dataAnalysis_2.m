%%
time_nidaq_raw = readmatrix('time.txt');
time_nidaq = datetime(time_nidaq_raw, 'Format', 'yyyy-MM-dd HH:mm:ss.SSSSSSS');

fid2 = fopen('log.bin','r');
[data,count] = fread(fid2,[2,inf],'double');
fclose(fid2);

time_table_raw = readmatrix('Camera_2_27_Feb_2023-22_52_51.txt');
time_table = datetime(time_table_raw, 'Format', 'yyyy-MM-dd HH:mm:ss.SSSSSSS');
time_offset = seconds(time_nidaq(1) - time_table(1));
time_table_diff = time2num(diff(time_table));
%%
videoObject = VideoReader('E:\Test 2\Camera_2.avi');
frame_count_total = videoObject.FrameRate * videoObject.Duration;
value_list = zeros(frame_count_total, 1);
for indexFrame = 1:frame_count_total
    frame = readFrame(videoObject);
    if indexFrame == 1600
        disp('hello')
    end
    value_list(indexFrame, 1) = mean(frame(82:114, 534:552), 'all');
end


%%
offset_list = 0.005:0.0001:0.006;
offset_list_length = length(offset_list);
TP_list = zeros(offset_list_length, 1);
FP_list = zeros(offset_list_length, 1);
TN_list = zeros(offset_list_length, 1);
FN_list = zeros(offset_list_length, 1);
accuracy_list = zeros(offset_list_length, 1);
precision_list = zeros(offset_list_length, 1);
recall_list = zeros(offset_list_length, 1);
F1_list = zeros(offset_list_length, 1);
specificity_list = zeros(offset_list_length, 1);
for indexOffset = 1:offset_list_length
    additional_offset = offset_list(indexOffset);

    [time_table_nidaq, nidaq_average_list, nidaq_value_norm, ...
     value_list_norm, value_list_duration, time_table_sum, time_table_combine] = analyze_data(time_table_diff, time_offset, additional_offset, frame_count_total, ...
                                                                                      time_nidaq, data, value_list);
    comparison_list = [nidaq_average_list, value_list_norm > 0.02];
    comparison_sum = sum(comparison_list, 2)==2;
    [TP, FP, TN, FN , accuracy, precision, recall, F1, specificity] = calculate_TFPN(comparison_list);
    TP_list(indexOffset) = TP;
    FP_list(indexOffset) = FP;
    TN_list(indexOffset) = TN;
    FN_list(indexOffset) = FN;
    accuracy_list(indexOffset) = accuracy;
    precision_list(indexOffset) = precision;
    recall_list(indexOffset) = recall;
    F1_list(indexOffset) = F1;
    specificity_list(indexOffset) = specificity;
end
stat_sum = table(offset_list', TP_list, FP_list, TN_list, FN_list, accuracy_list, precision_list, recall_list, F1_list, specificity_list);
%%
% additional_offset = stat_sum{find(stat_sum.accuracy_list == max(stat_sum.accuracy_list), 1), 1};
additional_offset = 0.75;
[time_table_nidaq, nidaq_average_list, nidaq_value_norm, ...
 value_list_norm, value_list_duration, time_table_sum, time_table_combine] = analyze_data(time_table_diff, time_offset, additional_offset, frame_count_total, ...
                                                                            time_nidaq, data, value_list);

comparison_list = [nidaq_average_list, value_list_norm > 0.02];
comparison_sum = sum(comparison_list, 2)==2;
[TP, FP, TN, FN , accuracy, precision, recall, F1, specificity] = calculate_TFPN(comparison_list)
figure
hold on
plot(data(1, :), nidaq_value_norm)


scatter(time_table_combine, value_list_duration);
plot(time_table_sum(2:end), time_table_diff*5);
scatter(time_table_sum(1:end), nidaq_average_list/2);
scatter(time_table_sum(1:end), comparison_sum);

