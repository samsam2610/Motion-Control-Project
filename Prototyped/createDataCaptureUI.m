function hGui = createDataCaptureUI(deviceObject)
    %createDataCaptureUI Create a graphical user interface for data capture.
    %   hGui = createDataCaptureUI(s) returns a structure of graphics
    %   components handles (hGui) and creates a graphical user interface, by
    %   programmatically creating a figure and adding required graphics
    %   components for visualization of data acquired from a data acquisition
    %   object (s).
    
    %% Continuous data part
    % Create a figure and configure a callback function (executes on window close)
    hGui.Fig = figure('Name','Software-analog triggered data capture', ...
        'NumberTitle', 'off', 'Resize', 'off', ...
        'Toolbar', 'None', 'Menu', 'None',...
        'Position', [100 100 850 650]);
    hGui.Fig.DeleteFcn = {@endDAQ, deviceObject};
    uiBackgroundColor = hGui.Fig.Color;
    
    % Create the continuous data plot axes with legend
    % (one line per acquisition channel)
    hGui.Axes1 = axes;
    hGui.LivePlot = plot(0, zeros(1, numel(deviceObject.Channels)));
    xlabel('Time (deviceObject)');
    ylabel('Voltage (V)');
    title('Continuous data');
    legend({deviceObject.Channels.ID}, 'Location', 'northeastoutside')
    hGui.Axes1.Units = 'Pixels';
    hGui.Axes1.Position = [207 391 488 196];
    % Turn off axes toolbar and data tips for live plot axes
    hGui.Axes1.Toolbar.Visible = 'off';
    disableDefaultInteractivity(hGui.Axes1);

    % Create a stop acquisition button and configure a callback function
    hGui.DAQButton = uicontrol('style', 'pushbutton', 'string', 'Stop DAQ',...
        'units', 'pixels', 'position', [65 394 81 38]);
    hGui.DAQButton.Callback = {@endDAQ, deviceObject};

    % Create capture labels
    hGui.txtTrigParam = uicontrol('Style', 'text', 'String', 'Capture parameters', ...
        'Position', [39 580 114 18], 'BackgroundColor', uiBackgroundColor);

    % Create an editable text field for the capturing time span
    hGui.TimeSpan = uicontrol('style', 'edit', 'string', '5',...
        'units', 'pixels', 'position', [89 550 56 24]);
    hGui.txtTimeSpan = uicontrol('Style', 'text', 'String', 'Capturing time (s)', ...
        'Position', [15 543 70 34], ...
        'BackgroundColor', uiBackgroundColor);
    
    % Create an editable text field for the plotting
    hGui.plotTimeSpan = uicontrol('style', 'edit', 'string', '0.55',...
        'units', 'pixels', 'position', [89 520 56 24]);
    hGui.txtplotTimeSpan = uicontrol('Style', 'text', 'String', 'Plotting time (s)', ...
        'Position', [18 513 66 34], ...
        'BackgroundColor', uiBackgroundColor);

    %% Capture data part
    % Create the captured data plot axes (one line per acquisition channel)
    hGui.Axes2 = axes('Units', 'Pixels', 'Position', [207 99 488 196]);
    hGui.CapturePlot = plot(NaN, NaN(1, numel(deviceObject.Channels)));
    xlabel('Time (deviceObject)');
    ylabel('Voltage (V)');
    title('Captured data');
    hGui.Axes2.Toolbar.Visible = 'off';
    disableDefaultInteractivity(hGui.Axes2);
    

    
    % Create a data capture button and configure a callback function
    hGui.CaptureButton = uicontrol('style', 'togglebutton', 'string', 'Capture',...
        'units', 'pixels', 'position', [65 99 81 38]);
    hGui.CaptureButton.Callback = {@startCapture, hGui};
    
    % Create a status text field
    hGui.StatusText = uicontrol('style', 'text', 'string', '',...
        'units', 'pixels', 'position', [67 28 225 24],...
        'HorizontalAlignment', 'left', 'BackgroundColor', uiBackgroundColor);
    
    % Create text labels
    hGui.txtTrigParam = uicontrol('Style', 'text', 'String', 'Trigger parameters', ...
        'Position', [39 290 114 18], 'BackgroundColor', uiBackgroundColor);

    % Create an editable text field for the trigger channel
    hGui.TrigChannel = uicontrol('style', 'edit', 'string', '1',...
        'units', 'pixels', 'position', [89 258 56 24]);
    hGui.txtTrigChannel = uicontrol('Style', 'text', 'String', 'Channel', ...
        'Position', [37 261 43 15], 'HorizontalAlignment', 'right', ...
        'BackgroundColor', uiBackgroundColor);

    % Create an editable text field for the trigger signal level
    hGui.TrigLevel = uicontrol('style', 'edit', 'string', '1.0',...
        'units', 'pixels', 'position', [89 231 56 24]);
    hGui.txtTrigLevel = uicontrol('Style', 'text', 'String', 'Level (V)', ...
        'Position', [35 231 48 19], 'HorizontalAlignment', 'right', ...
        'BackgroundColor', uiBackgroundColor);

    % Create an editable text field for the trigger signal slope
    hGui.TrigSlope = uicontrol('style', 'edit', 'string', '200.0',...
        'units', 'pixels', 'position', [89 204 56 24]);
    hGui.txtTrigSlope = uicontrol('Style', 'text', 'String', 'Slope (V/s)', ...
        'Position', [17 206 66 17], 'HorizontalAlignment', 'right', ...
        'BackgroundColor', uiBackgroundColor);

    % Create an editable text field for the captured data variable name
    hGui.VarName = uicontrol('style', 'edit', 'string', 'mydata',...
        'units', 'pixels', 'position', [89 159 57 26]);
    hGui.txtVarName = uicontrol('Style', 'text', 'String', 'Variable name', ...
        'Position', [35 152 44 34], 'BackgroundColor', uiBackgroundColor);
    
end
    
function startCapture(obj, ~, hGui)
    if obj.Value
        % If button is pressed clear data capture plot
        for ii = 1:numel(hGui.CapturePlot)
            set(hGui.CapturePlot(ii), 'XData', NaN, 'YData', NaN);
        end
    end
end
    
function endDAQ(~, ~, deviceObject)
    if isvalid(deviceObject)
        if deviceObject.Running
            stop(deviceObject);
        end
    end
end