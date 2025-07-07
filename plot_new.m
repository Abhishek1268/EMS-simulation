function plot_new
    fig = uifigure('Name', 'Energy Data Viewer', 'Position', [100, 100, 1000, 600]);

    % File selector
    [file, path] = uigetfile('*.csv', 'Select energy data file');
    if isequal(file, 0)
        uialert(fig, 'No file selected.', 'File Error');
        return;
    end
    filename = fullfile(path, file);
    data = readtable(filename);

    % Ensure datetime
    if ~isdatetime(data.Time)
        data.Time = datetime(data.Time, 'InputFormat', 'dd-MM-yyyy HH:mm:ss');
    end

    % UI controls
    uilabel(fig, 'Text', 'Start Date:', 'Position', [20 550 70 22]);
    startDatePicker = uidatepicker(fig, 'Position', [100 550 150 22], ...
        'Value', min(data.Time), 'Limits', [min(data.Time) max(data.Time)]);

    uilabel(fig, 'Text', 'End Date:', 'Position', [270 550 70 22]);
    endDatePicker = uidatepicker(fig, 'Position', [350 550 150 22], ...
        'Value', max(data.Time), 'Limits', [min(data.Time) max(data.Time)]);

    plotBtn = uibutton(fig, 'Text', 'Plot', 'Position', [530 550 100 22], ...
        'ButtonPushedFcn', @(btn,event) updatePlot());

    ax = uiaxes(fig, 'Position', [50 80 900 440]);
    title(ax, 'Energy Data Visualization');
    grid(ax, 'on');

    function updatePlot()
        startDate = startDatePicker.Value;
        endDate = endDatePicker.Value;

        idx = data.Time >= startDate & data.Time <= endDate;
        if ~any(idx)
            cla(ax);
            title(ax, 'No data in selected range');
            return;
        end

        t = data.Time(idx);
        % Smoothing window (larger = smoother, but slower response)
        window = 8;  

        cla(ax, 'reset'); hold(ax, 'on');

        % --- LEFT Y-AXIS ---
        yyaxis(ax, 'left');

        if ismember('loadDemand', data.Properties.VariableNames)
            smoothed = movmean(data.loadDemand(idx), window);
            area(ax, t, smoothed, ...
                'FaceColor', [0.6 0.6 1], 'FaceAlpha', 0.2, ...
                'EdgeColor', [0.4 0.4 1], 'LineWidth', 1.0, ...
                'DisplayName', 'Load Demand');
        end

        if ismember('pv_power', data.Properties.VariableNames)
            smoothed = movmean(data.pv_power(idx), window);
            area(ax, t, smoothed, ...
                'FaceColor', [1 1 0.3], 'FaceAlpha', 0.2, ...
                'EdgeColor', [0.9 0.7 0.1], 'LineWidth', 1.0, ...
                'DisplayName', 'PV Power');
        end

        if ismember('gridPower', data.Properties.VariableNames)
            smoothed = movmean(data.gridPower(idx), window);
            area(ax, t, smoothed, ...
                'FaceColor', [0.8 0.6 0.5], 'FaceAlpha', 0.2, ...
                'EdgeColor', [0.6 0.3 0.2], 'LineWidth', 1.0, ...
                'DisplayName', 'Grid Power');
        end

        if ismember('evPower', data.Properties.VariableNames)
            smoothed = movmean(data.evPower(idx), window);
            plot(ax, t, smoothed, ...
                '--', 'Color', [0.49 0.18 0.56], 'LineWidth', 1.5, ...
                'DisplayName', 'EV Power');
        end

        ylabel(ax, 'Power [kW]');
        % Compute dynamic Y-axis upper limit
        max_power = 0;
        if ismember('loadDemand', data.Properties.VariableNames)
            max_power = max(max_power, max(movmean(data.loadDemand(idx), window)));
        end
        if ismember('pv_power', data.Properties.VariableNames)
            max_power = max(max_power, max(movmean(data.pv_power(idx), window)));
        end
        if ismember('gridPower', data.Properties.VariableNames)
            max_power = max(max_power, max(movmean(data.gridPower(idx), window)));
        end
        if ismember('evPower', data.Properties.VariableNames)
            max_power = max(max_power, max(movmean(data.evPower(idx), window)));
        end

        % Round up and define Y-tick limits
        tick_step = 0.4;  % Define your custom tick step here
        tick_max = max(4.0, ceil(max_power * 1.1 / tick_step) * tick_step);
        yticks(ax, 0:tick_step:tick_max);
        ylim(ax, [0 tick_max]);

        % --- RIGHT Y-AXIS ---
        yyaxis(ax, 'right');

        if ismember('batterySoC', data.Properties.VariableNames)
            smoothed = movmean(data.batterySoC(idx), window);
            plot(ax, t, smoothed, ...
                'b-', 'LineWidth', 2, 'DisplayName', 'Battery SoC [%]');
        end

        if ismember('gridPrice', data.Properties.VariableNames)
            smoothed = movmean(data.gridPrice(idx), window) * 100;
            plot(ax, t, smoothed, ...
                'k-', 'LineWidth', 1.5, 'DisplayName', 'Grid Price [ct/kWh]');
        end

        ylabel(ax, 'Battery SoC [%] & Grid Price [ct/kWh]');
        ylim(ax, [0 100]);

        legend(ax, 'Location', 'northwest');
        title(ax, sprintf('Energy Plot: %s to %s', ...
            datestr(startDate), datestr(endDate)));
        hold(ax, 'off');
    end
end
