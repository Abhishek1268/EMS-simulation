function plot_gridprice
    % Create UI figure
    fig = uifigure('Name', 'Grid Price Viewer', 'Position', [100, 100, 800, 500]);

    % File selector
    [file, path] = uigetfile('*.csv', 'Select grid price data file');
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
    uilabel(fig, 'Text', 'Start Date:', 'Position', [20 450 70 22]);
    startDatePicker = uidatepicker(fig, ...
        'Position', [90 450 150 22], ...
        'Value', min(data.Time), ...
        'Limits', [min(data.Time), max(data.Time)]);

    uilabel(fig, 'Text', 'End Date:', 'Position', [260 450 70 22]);
    endDatePicker = uidatepicker(fig, ...
        'Position', [330 450 150 22], ...
        'Value', max(data.Time), ...
        'Limits', [min(data.Time), max(data.Time)]);

    % Plot Button
    plotBtn = uibutton(fig, 'Text', 'Plot', ...
        'Position', [500 450 100 22], ...
        'ButtonPushedFcn', @(btn,event) updatePlot());

    % Axes
    ax = uiaxes(fig, 'Position', [50 50 700 370]);
    title(ax, 'Grid Price Over Time');
    xlabel(ax, 'Time');
    ylabel(ax, 'Grid Price [€/kWh]');
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
        window = 6; % Smoothing window

        % Clear previous content
        cla(ax);

        % Plot Grid Price
        if ismember('gridPrice', data.Properties.VariableNames)
            plot(ax, t, movmean(data.gridPrice(idx), window), 'k-', 'LineWidth', 1.5);
            ylabel(ax, 'Grid Price [€/kWh]');
            ylim(ax, [0 inf]);
            legend(ax, 'Grid Price', 'Location', 'best');
            title(ax, sprintf('Grid Price from %s to %s', datestr(startDate), datestr(endDate)));
        else
            title(ax, 'gridPrice column not found');
        end
    end
end
