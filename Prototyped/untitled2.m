deviceObject = daq('ni');

% Set acquisition rate, in scans/second
deviceObject.Rate = 1000;

deviceName = "Dev1";
unitName = "Voltage";
channelNumbers = [1];

for index = 1:length(channelNumbers)
    channelNumber = channelNumbers(index);
    channel = addinput(deviceObject, deviceName, "ai" + num2str(channelNumber), unitName);
    channel.TerminalConfig = 'SingleEnded';
end
deviceObject.ScansAvailableFcn = @(src,event) read(src);
start(deviceObject, 'continuous');
