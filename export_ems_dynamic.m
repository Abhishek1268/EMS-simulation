model_name = 'Logic_test_EV';
%sim(model_name);

save('ems_dynamic_data.mat', 'out');

tout = out.tout;
signal_names = {'gridThreshold', 'gridPrice', 'signal1', 'signal2', 'gridToLoad_dynamic', 'pvToLoad', 'pvToGrid',...
                'pvToBattery', 'pvToEV', 'gridToBattery', 'gridToEV', ...
                'batteryToLoad', 'batteryToEV', 'batterySoC', 'evPower', ...
                'updatedEvSoC', 'unmetLoad', 'gridPower'};
output_names = {'Time', 'gridThreshold', 'gridPrice', 'loadDemand', 'pv_power', 'gridToLoad', 'pvToLoad', 'pvToGrid',...
                'pvToBattery', 'pvToEV', 'gridToBattery', 'gridToEV', ...
                'batteryToLoad', 'batteryToEV', 'batterySoC', 'evPower', ...
                'updatedEvSoC', 'unmetLoad', 'gridPower'};

% Step 1: Convert time from seconds to DD-MM-YYYY hh:mm:ss
ref_time = datetime('01-01-2023 00:00:00', 'InputFormat', 'dd-MM-yyyy HH:mm:ss');
time_datetime = ref_time + seconds(tout);
time_formatted = cellstr(datetime(time_datetime, 'Format', 'dd-MM-yyyy HH:mm:ss'));

% Step 2: Create data matrix (keep time in seconds for internal use)
expected_columns = length(signal_names); % 17
data_matrix = zeros(length(tout), length(signal_names) + 1);
data_matrix(:, 1) = tout; % Store time in seconds

% Debug out.ev structure
fprintf('Class of out.ev: %s\n', class(out.ev));
fprintf('Fields of out.ev: %s\n', strjoin(fieldnames(out.ev), ', '));
if isfield(out.ev, 'signals') && isfield(out.ev.signals, 'values')
    fprintf('Size of out.ev.signals.values: %s\n', mat2str(size(out.ev.signals.values)));
end

% Extract data from my_data structure (timeseries objects)
try
    if isstruct(out.ev) && isfield(out.ev, 'signals') && isfield(out.ev.signals, 'values')
        signal_data = out.ev.signals.values;
        if isnumeric(signal_data) && size(signal_data, 2) == expected_columns
            for i = 1:expected_columns
                if length(signal_data(:, i)) == length(tout)
                    data_matrix(:, i+1) = signal_data(:, i);
                else
                    error('Data length for signal %s (column %d) does not match tout', ...
                          signal_names{i}, i);
                end
            end
        else
            error('out.ev.signals.values is not a numeric array with %d columns. Actual size: %s', ...
                  expected_columns, mat2str(size(signal_data)));
        end
    else
        error('out.ev is not a struct with signals.values field');
    end
catch e
    fprintf('Error: %s\n', e.message);
    rethrow(e);
end

% Step 3: Create table with formatted time
% Combine formatted time (strings) with numeric data
T = array2table([time_formatted, num2cell(data_matrix(:, 2:end))], 'VariableNames', output_names);

% Step 4: Write to .csv
writetable(T, 'ems_dynamic_data.csv');
disp('Data successfully saved to ems_dynamic_data.csv');

% Step 5: Write to .xlsx
writetable(T, 'ems_dynamic_data.xlsx');
disp('Data successfully saved to ems_dynamic_data.xlsx');