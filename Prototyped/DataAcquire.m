%%
clear all
%%
deviceObject = daq("ni");
flush(deviceObject)
deviceObject.Rate = 1000;

durationRecording = seconds(30);
triggerTimeOut = 10;

deviceName = "Dev1";
unitName = "Voltage";
channelNumbers = [1, 16, 17, 18, 19, 20, 21];
for index = 1:length(channelNumbers)
    channelNumber = channelNumbers(index);
    channel = addinput(deviceObject, deviceName, "ai" + num2str(channelNumber), unitName);
    channel.TerminalConfig = 'SingleEnded';
end

%% Set trigger
t = addtrigger(deviceObject, "Digital", "StartTrigger", "External", "Dev1/PFI0");
t.Condition = 'RisingEdge';

%% Arm trigger
deviceObject.DigitalTriggerTimeout = triggerTimeOut;

%% Read data
disp('Waiting for trigger')
Dev1_1 = read(deviceObject, durationRecording);
% Dev1_1 = [];
% tic;
% start(deviceObject, "continuous")
% 
% while toc < durationRecording % Increase or decrease the pause duration to fit your needs.
%     data = read(deviceObject);
%     Dev1_1 = [Dev1_1; data];
%     
% end
% stop(deviceObject)

%% Plot data
% 
figure
for index = 1:length(channelNumbers)
    channelNumber = channelNumbers(index);
    channelName = deviceName + "_" + "ai" + num2str(channelNumber);
    subplot(4, 3, index);
    plot(Dev1_1.Time, Dev1_1.(channelName));
    ylim([-10 10])
    title(Dev1_1.Properties.VariableNames{index});
end
xlabel("Time")
ylabel("Amplitude (V)")



%% Clean
clear deviceObject