model_name = 'Logic_test_EV';
%sim(model_name);

save('no_ems.mat', 'out');

tout = out.tout;
signal_names = {'signal1', 'signal2', 'gridToLoad_noems', 'pvToLoad', 'pvToGrid', ...
                'pvToBattery', 'batteryToLoad', 'pvToEV', 'gridToEV', 'updatedEvSoC', 'evPower', ...
                'unmetLoad', 'gridPower'};
output_names = {'Time', 'loadDemand', 'pv_power', 'gridToLoad', 'pvToLoad', 'pvToGrid', ...
                'pvToBattery', 'batteryToLoad','pvToEV', 'gridToEV', 'updatedEvSoC', 'evPower', ...
                'unmetLoad', 'gridPower'};

% Step 1: Convert time from seconds to DD-MM-YYYY hh:mm:ss
ref_time = datetime('01-01-2023 00:00:00', 'InputFormat', 'dd-MM-yyyy HH:mm:ss');
time_datetime = ref_time + seconds(tout);
time_formatted = cellstr(datetime(time_datetime, 'Format', 'dd-MM-yyyy HH:mm:ss'));

% Step 2: Create data matrix (keep time in seconds for internal use)
expected_columns = length(signal_names); % 13
data_matrix = zeros(length(tout), length(signal_names) + 1);
data_matrix(:, 1) = tout; % Store time in seconds

% Debug out.ev structure
fprintf('Class of out.no_ems: %s\n', class(out.no_ems));
fprintf('Fields of out.no_ems: %s\n', strjoin(fieldnames(out.no_ems), ', '));
if isfield(out.no_ems, 'signals') && isfield(out.no_ems.signals, 'values')
    fprintf('Size of out.no_ems.signals.values: %s\n', mat2str(size(out.no_ems.signals.values)));
end

% Extract data from my_data structure (timeseries objects)
try
    if isstruct(out.no_ems) && isfield(out.no_ems, 'signals') && isfield(out.no_ems.signals, 'values')
        signal_data = out.no_ems.signals.values;
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
            error('out.no_ems.signals.values is not a numeric array with %d columns. Actual size: %s', ...
                  expected_columns, mat2str(size(signal_data)));
        end
    else
        error('out.no_ems is not a struct with signals.values field');
    end
catch e
    fprintf('Error: %s\n', e.message);
    rethrow(e);
end

% Step 3: Create table with formatted time
% Combine formatted time (strings) with numeric data
T = array2table([time_formatted, num2cell(data_matrix(:, 2:end))], 'VariableNames', output_names);

% Step 4: Write to .csv
writetable(T, 'no_ems.csv');
disp('Data successfully saved to no_ems.csv');

% Step 5: Write to .xlsx
writetable(T, 'no_ems.xlsx');
disp('Data successfully saved to no_ems.xlsx');