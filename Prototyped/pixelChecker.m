close all
%% Generate the graphs
figure
duration = 20;
frequency = 100;
numberOfSamples = duration*10e1*frequency;
[x_square, y_square] = squarewavegen(0.001, 0.005, 0, duration, 6000);

x_square = round(x_square, 4);

[x_pulse, y_pulse] = squarewavegen(0.0001, 0.01, 0.0005, duration, 10000);
x_pulse = round(x_pulse, 4);

[x_ideal, y_ideal] = squarewavegen(0.001, 0.01, 0, duration, 10000);
x_ideal = round(x_ideal, 4);

%%
samplingRate = 200;

s1 = [135 262]; % spot location for snapshot 1
s2 = [111 368]; % spot location for snapshot 2
[lenght, width, height] = size(snapshot_store_1);

time_start_actual_1 = zeros(height, 6);
time_start_actual_2 = zeros(height, 6);

for index_height = 1:4000
    if isempty(time_table_1{index_height, 2}) || isempty(time_table_2{index_height, 2}) || time_table_2{index_height, 8} == 1 || time_table_1{index_height, 8} == 1
        continue
    end
    
    % pixel value for the LEDs
    value_1(index_height) = snapshot_store_1(s1(1), s1(2), index_height)/255;
    value_2(index_height) = snapshot_store_2(s2(1), s2(2), index_height)/255;
   
    if value_1 == 1
        % Calculate time each snapshot was supposed to be taken
        current_diff = time_table_1{index_height, 3} - time_table_1{1, 2};
        current_diff.Format = 'mm:ss.SSSSSS';
        time_start_actual_1(index_height, :) = [seconds(current_diff), value_1(index_height)];
    end

    if value_2 == 1
        % Calculate time each snapshot was supposed to be taken
        current_diff = time_table_2{index_height, 3} - time_table_2{1, 2};
        current_diff.Format = 'mm:ss.SSSSSS';
        time_start_actual_2(index_height, :) = [seconds(current_diff), value_2(index_height)];
    end

end

%%
close all
startIndex = 2.5;
endIndex = 2.8;


figure
samplingFrequency = 6000;
plot(x_square(startIndex*samplingFrequency:endIndex*samplingFrequency), y_square(startIndex*samplingFrequency:endIndex*samplingFrequency));
hold on

samplingFrequency = 10000;
plot(x_ideal(startIndex*samplingFrequency:endIndex*samplingFrequency), y_ideal(startIndex*samplingFrequency:endIndex*samplingFrequency));
hold on

samplingFrequency = 100;
scatter(time_start_actual_1(startIndex*samplingFrequency:endIndex*samplingFrequency, 1)+0.005, time_start_actual_1(startIndex*samplingFrequency:endIndex*samplingFrequency, 2)-0.0001, 80, 'filled');
hold on
scatter(time_start_actual_2(startIndex*samplingFrequency:endIndex*samplingFrequency, 1)+0.005, time_start_actual_2(startIndex*samplingFrequency:endIndex*samplingFrequency, 2)+0.0001, 80, 'filled');
hold on