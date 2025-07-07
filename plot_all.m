function plot_all
    % Create UI figure
    fig = uifigure('Name', 'Energy Data Viewer', 'Position', [100, 100, 900, 600]);

    % File selector
    [file, path] = uigetfile('*.csv', 'Select energy data file');
    if isequal(file, 0)
        uialert(fig, 'No file selected.', 'File Error');
        return;
    end
    filename = fullfile(path, file);
    data = readtable(filename);

    % Ensure datetime format
    if ~isdatetime(data.Time)
        data.Time = datetime(data.Time, 'InputFormat', 'dd-MM-yyyy HH:mm:ss');
    end

    % Date Pickers
    uilabel(fig, 'Text', 'Start Date:', 'Position', [20 550 70 22]);
    startDatePicker = uidatepicker(fig, 'Position', [100 550 150 22], ...
        'Value', min(data.Time), 'Limits', [min(data.Time) max(data.Time)]);

    uilabel(fig, 'Text', 'End Date:', 'Position', [270 550 70 22]);
    endDatePicker = uidatepicker(fig, 'Position', [350 550 150 22], ...
        'Value', max(data.Time), 'Limits', [min(data.Time) max(data.Time)]);

    % Plot Button
    plotBtn = uibutton(fig, 'Text', 'Plot', 'Position', [530 550 100 22], ...
        'ButtonPushedFcn', @(btn,event) updatePlot());

    % Axes
    ax = uiaxes(fig, 'Position', [50 80 800 440]);
    title(ax, 'Energy Data Visualization');
    grid(ax, 'on');

    % Update plot when button is clicked
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
        window = 6;

        % Left axis
        yyaxis(ax, 'left');
        cla(ax);
        hold(ax, 'on');

        % Clear old plot completely
        cla(ax, 'reset');
        hold(ax, 'on')

        if ismember('gridPrice', data.Properties.VariableNames)
            plot(ax, t, movmean(data.gridPrice(idx), window) * 100, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Grid Price [ct/kWh]');
        end

        if ismember('loadDemand', data.Properties.VariableNames)
            area(ax, t, movmean(data.loadDemand(idx), window), 'FaceColor', [0.6 0.6 1], ...
                'FaceAlpha', 0.4, 'EdgeColor', 'none', 'DisplayName', 'Load Demand');
        end

        if ismember('pv_power', data.Properties.VariableNames)
            area(ax, t, movmean(data.pv_power(idx), window), 'FaceColor', [1 1 0.2], ...
                'FaceAlpha', 0.6, 'EdgeColor', 'none', 'DisplayName', 'PV Power');
        end

        if ismember('evPower', data.Properties.VariableNames)
            plot(ax, t, movmean(data.evPower(idx), window), '--', 'Color', [0.49 0.18 0.56], ...
                'LineWidth', 1.5, 'DisplayName', 'EV Power');
        end

        if ismember('gridPower', data.Properties.VariableNames)
            area(ax, t, movmean(data.gridPower(idx), window), 'FaceColor', [0.7 0.45 0.3], ...
                'FaceAlpha', 0.6, 'EdgeColor', 'none', 'DisplayName', 'Grid Power');
        end

        ylabel(ax, 'Grid Price [ct/kWh] & Power [kW]');
        ylim(ax, [0 inf]);

        % Right axis
        yyaxis(ax, 'right');
        if ismember('batterySoC', data.Properties.VariableNames)
            plot(ax, t, movmean(data.batterySoC(idx), window), 'b--', 'LineWidth', 2, 'DisplayName', 'Battery SoC [%]');
        end
        ylabel(ax, 'Battery SoC [%]');
        ylim(ax, [0 100]);

        legend(ax, 'Location', 'northeast');
        title(ax, sprintf('Energy Plot: %s to %s', datestr(startDate), datestr(endDate)));
        hold(ax, 'off');
    end
end
