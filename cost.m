%% Load and Prepare Data

% Reference time and time format
ref_time = datetime('01-01-2023 00:00:00', 'InputFormat', 'dd-MM-yyyy HH:mm:ss');
time_format = 'dd-MM-yyyy HH:mm:ss';
dt = 1; % 1 hour duration assumed for all kW -> kWh conversion

model_name = 'Logic_test_EV';
sim(model_name);

% If signals were logged as timeseries (structure with time):
if isstruct(out.enableBattery)
    enableBattery = out.enableBattery.signals.values(end) > 0;
else
    enableBattery = out.enableBattery(end) > 0;
end

if isstruct(out.enableEV)
    enableEV = out.enableEV.signals.values(end) > 0;
else
    enableEV = out.enableEV(end) > 0;
end

fprintf("enableBattery = %d\n", enableBattery);
fprintf("enableEV = %d\n", enableEV);

%%------------------------------------Load Dynamic Data------------------------------------%%

%% Load Data for Dynamic Pricing (EMS with Dynamic Pricing)
try
    data_dynamic = readtable('ems_dynamic_data.csv');
catch e
    error('Failed to load ems_dynamic_data.csv: %s', e.message);
end

fprintf('Class of data_dynamic.Time: %s\n', class(data_dynamic.Time));
disp('Sample of data_dynamic.Time:');
disp(data_dynamic.Time(1:5));

% Convert Time to datetime if needed
if iscell(data_dynamic.Time) || isstring(data_dynamic.Time)
    try
        data_dynamic.Time = datetime(data_dynamic.Time, 'InputFormat', time_format);
    catch e
        error('Failed to parse Time column as datetime: %s', e.message);
    end
elseif isnumeric(data_dynamic.Time)
    % If numeric timestamps are seconds since reference time
    data_dynamic.Time = ref_time + seconds(data_dynamic.Time);
elseif ~isdatetime(data_dynamic.Time)
    error('Unsupported Time column format: %s', class(data_dynamic.Time));
end
%data_dynamic.Time = datetime(data_dynamic.Time, 'InputFormat', 'dd-MM-yyyy HH:mm:ss');

column_mapping = {
    'Time', 'Time';
    'loadDemand', 'loadDemand';
    'pv_power', 'pv_power';
    'gridToLoad', 'gridToLoad';
    'pvToLoad', 'pvToLoad';
    'pvToGrid', 'pvToGrid';
    'pvToBattery', 'pvToBattery';
    'pvToEV', 'pvToEV';
    'gridToBattery', 'gridToBattery';
    'gridToEV', 'gridToEV';
    'batteryToLoad', 'batteryToLoad';
    'batteryToEV', 'batteryToEV';
    'batterySoC', 'batterySoC';
    'evPower', 'evPower';
    'updatedEvSoC', 'updatedEvSoC';
    'unmetLoad', 'unmetLoad'
    'gridPower', 'gridPower'};

for i = 1:size(column_mapping, 1)
    if ismember(column_mapping{i, 1}, data_dynamic.Properties.VariableNames)
        data_dynamic.Properties.VariableNames{column_mapping{i, 1}} = column_mapping{i, 2};
    end
end

expected_columns = column_mapping(:,2)';
if ~all(ismember(expected_columns, data_dynamic.Properties.VariableNames))
    error('Missing required columns in ems_dynamic_data.csv');
end

time_dynamic = data_dynamic.Time;
hours_dynamic = hours(time_dynamic - ref_time);


% Extract and convert energy data to kWh
pv_to_load_kwh_dynamic      = data_dynamic.pvToLoad       * dt;
grid_to_load_kwh_dynamic    = data_dynamic.gridToLoad     * dt;
grid_power_kwh_dynamic      = data_dynamic.gridPower      * dt;
pv_to_grid_kwh_dynamic      = data_dynamic.pvToGrid       * dt;
soc_dynamic = data_dynamic.batterySoC / 100;
pv_power_kwh_dynamic = data_dynamic.pv_power * dt;
load_demand_kwh_dynamic     = data_dynamic.loadDemand     * dt;
unmet_load_kwh_dynamic      = data_dynamic.unmetLoad      * dt;

if enableEV
    pv_to_ev_kwh_dynamic        = data_dynamic.pvToEV         * dt;
    grid_to_ev_kwh_dynamic      = data_dynamic.gridToEV       * dt;
    ev_power_kwh_dynamic        = data_dynamic.evPower        * dt;
end

if enableBattery
    battery_to_load_kwh_dynamic = data_dynamic.batteryToLoad  * dt;
    pv_to_battery_kwh_dynamic   = data_dynamic.pvToBattery    * dt;
    grid_to_battery_kwh_dynamic = data_dynamic.gridToBattery  * dt;
end

if enableBattery && enableEV
    battery_to_ev_kwh_dynamic   = data_dynamic.batteryToEV    * dt;
end

if enableEV
% Positive energy from PV to EV used for savings
pv_to_ev_savings_kwh_dynamic = max(0, -pv_to_ev_kwh_dynamic);
end

if ismember('gridPrice', data_dynamic.Properties.VariableNames)
    gridPrice = data_dynamic.gridPrice;
    time = datetime(data_dynamic.Time, 'InputFormat', 'dd-MM-yyyy HH:mm:ss');
    fprintf("✅ gridPrice loaded from CSV (data_dynamic).\n");
end
if ismember('gridThreshold', data_dynamic.Properties.VariableNames)
    gridThreshold = data_dynamic.gridThreshold;
    time = datetime(data_dynamic.Time, 'InputFormat', 'dd-MM-yyyy HH:mm:ss');
    fprintf("✅ gridThreshold loaded from CSV (data_dynamic).\n");
end
disp(table(data_dynamic.Time(1:5), gridPrice(1:5), gridThreshold(1:5), 'VariableNames', {'Time', 'gridPrice','gridThreshold'}));

plot(data_dynamic.Time, data_dynamic.gridPrice, 'LineWidth', 1.5);
xlabel('Time');
ylabel('Grid Price (€/kWh)');
title('Grid Price Over Time');
grid on;

%%------------------------------------Load Static Data------------------------------------%%

%% Load Data for Static Pricing (EMS with Static Pricing)
try
    data_static = readtable('ems_static_data.csv');
catch e
    error('Failed to load ems_static_data.csv: %s', e.message);
end

fprintf('Class of data_static.Time: %s\n', class(data_static.Time));
disp('Sample of data_static.Time:');
disp(data_static.Time(1:5));

% Convert Time to datetime if needed
if iscell(data_static.Time) || isstring(data_static.Time)
    try
        data_static.Time = datetime(data_static.Time, 'InputFormat', time_format);
    catch e
        error('Failed to parse Time column as datetime: %s', e.message);
    end
elseif isnumeric(data_static.Time)
    % If numeric timestamps are seconds since reference time
    data_static.Time = ref_time + seconds(data_static.Time);
elseif ~isdatetime(data_static.Time)
    error('Unsupported Time column format: %s', class(data_static.Time));
end

for i = 1:size(column_mapping, 1)
    if ismember(column_mapping{i, 1}, data_static.Properties.VariableNames)
        data_static.Properties.VariableNames{column_mapping{i, 1}} = column_mapping{i, 2};
    end
end

if ~all(ismember(expected_columns, data_static.Properties.VariableNames))
    error('Missing required columns in ems_static_data.csv');
end

time_static = data_static.Time;
hours_static = hours(time_static - ref_time);

% Extract and convert energy data to kWh
pv_to_load_kwh_static      = data_static.pvToLoad       * dt;
grid_to_load_kwh_static    = data_static.gridToLoad     * dt;
grid_power_kwh_static      = data_static.gridPower      * dt;
pv_to_grid_kwh_static      = data_static.pvToGrid       * dt;
load_demand_kwh_static     = data_static.loadDemand     * dt;
unmet_load_kwh_static      = data_static.unmetLoad      * dt;
soc_static = data_static.batterySoC / 100;
pv_power_kwh_static = data_static.pv_power * dt;


if enableEV
    pv_to_ev_kwh_static        = data_static.pvToEV         * dt;
    grid_to_ev_kwh_static      = data_static.gridToEV       * dt;
    ev_power_kwh_static        = data_static.evPower        * dt;
end

if enableBattery
    battery_to_load_kwh_static = data_static.batteryToLoad  * dt;
    pv_to_battery_kwh_static   = data_static.pvToBattery    * dt;
    grid_to_battery_kwh_static = data_static.gridToBattery  * dt;
end

if enableBattery && enableEV
    battery_to_ev_kwh_static   = data_static.batteryToEV    * dt;
end

if enableEV
% Positive energy from PV to EV used for savings
pv_to_ev_savings_kwh_static = max(0, -pv_to_ev_kwh_static);
end

%%------------------------------------No-EMS Data------------------------------------%%

%% Load Data for no_ems Pricing (EMS with no_ems Pricing)
try
    data_no_ems = readtable('no_ems.csv');
catch e
    error('Failed to load no_ems_data.csv: %s', e.message);
end

fprintf('Class of data_no_ems.Time: %s\n', class(data_no_ems.Time));
disp('Sample of data_no_ems.Time:');
disp(data_no_ems.Time(1:5));

% Convert Time to datetime if needed
if iscell(data_no_ems.Time) || isstring(data_no_ems.Time)
    try
        data_no_ems.Time = datetime(data_no_ems.Time, 'InputFormat', time_format);
    catch e
        error('Failed to parse Time column as datetime: %s', e.message);
    end
elseif isnumeric(data_no_ems.Time)
    % If numeric timestamps are seconds since reference time
    data_no_ems.Time = ref_time + seconds(data_no_ems.Time);
elseif ~isdatetime(data_no_ems.Time)
    error('Unsupported Time column format: %s', class(data_no_ems.Time));
end

% If time column is valid datetime already:
time_no_ems = data_no_ems.Time;

% If it's not datetime yet (e.g., numeric or string), make sure it becomes datetime before this
if ~isdatetime(time_no_ems)
    error('Time column in no_ems.csv is not datetime after conversion.');
end
for i = 1:length(column_mapping)
    col = column_mapping{i};
    if ~ismember(col, data_no_ems.Properties.VariableNames)
        data_no_ems.(col) = zeros(height(data_no_ems), 1);
    end
end

for i = 1:size(column_mapping, 1)
    if ismember(column_mapping{i, 1}, data_no_ems.Properties.VariableNames)
        data_no_ems.Properties.VariableNames{column_mapping{i, 1}} = column_mapping{i, 2};
    end
end

if ~all(ismember(expected_columns, data_no_ems.Properties.VariableNames))
    error('Missing required columns in no_ems.csv');
end

time_no_ems = data_no_ems.Time;
hours_no_ems = hours(time_no_ems - ref_time);

% Extract and convert energy data to kWh
pv_to_load_kwh_no_ems      = data_no_ems.pvToLoad       * dt;
grid_to_load_kwh_no_ems    = data_no_ems.gridToLoad     * dt;
grid_power_kwh_no_ems      = data_no_ems.gridPower      * dt;
pv_to_grid_kwh_no_ems      = data_no_ems.pvToGrid       * dt;
load_demand_kwh_no_ems     = data_no_ems.loadDemand     * dt;
unmet_load_kwh_no_ems      = data_no_ems.unmetLoad      * dt;
soc_no_ems = data_no_ems.batterySoC / 100;
pv_power_kwh_no_ems = data_no_ems.pv_power * dt;


if enableEV
    pv_to_ev_kwh_no_ems        = data_no_ems.pvToEV         * dt;
    grid_to_ev_kwh_no_ems      = data_no_ems.gridToEV       * dt;
    ev_power_kwh_no_ems        = data_no_ems.evPower        * dt;
end

if enableBattery
    battery_to_load_kwh_no_ems = data_no_ems.batteryToLoad  * dt;
    pv_to_battery_kwh_no_ems   = data_no_ems.pvToBattery    * dt;
    grid_to_battery_kwh_no_ems = data_no_ems.gridToBattery  * dt;
end

if enableBattery && enableEV
    battery_to_ev_kwh_no_ems   = data_no_ems.batteryToEV    * dt;
end

if enableEV
% Positive energy from PV to EV used for savings
pv_to_ev_savings_kwh_no_ems = max(0, -pv_to_ev_kwh_no_ems);
end

%%------------------------------------System Parameters------------------------------------%%

%% System Parameters (Common for Both Scenarios)
pv_capacity = 10;                            % kW
battery_capacity = 10;                       % kWh
pv_cost_per_kw = 300;                        % €/kW
battery_cost_per_kwh = 500;                  % €/kWh
inverter_cost = 2000;                        % €
installation_cost = 6000;                    % €
hems_cost = 1000;                            % € (Home Energy Management System)
project_lifetime = 20;                       % years
export_rate = 0.10;                          % €/kWh
fixed_price = 0.39;                          % €/kWh for static pricing
annual_maintenance = 150;                    % €/year
price_escalation = 0.03;                     % 3% annual increase
peak_price_escalation = 0.04;                % 4% for peak prices
off_peak_price_escalation = 0.02;            % 2% for off-peak prices
discount_rate = 0.04;                        % 4% for NPV

if enableBattery
    battery_lifetime_cycles = 3000;              % Full cycles
    battery_replacement_cost = battery_cost_per_kwh * battery_capacity;
    battery_replacement_year = 13;               % Replace in Year 13
    battery_cost_escalation = 0.03;              % 3% annual increase
    battery_discharge_cost_per_kwh = 0.05;       % €/kWh for battery degradation (example)
end

if enableEV
    ev_charge_efficiency = 0.95;                 % EV charging efficiency
end


initial_investment = pv_cost_per_kw * pv_capacity + inverter_cost + installation_cost + hems_cost;
if enableBattery
    initial_investment = initial_investment + battery_cost_per_kwh * battery_capacity;
end


%%------------------------------------Dynamic------------------------------------%%

%% Scenario 1: PV + Storage + Dynamic Pricing (Year 1)
hours_of_day = mod(hours_dynamic, 24);
is_peak = hours_of_day >= 8 & hours_of_day < 20;

grid_purchase_cost_dynamic = sum(grid_to_load_kwh_dynamic .* gridPrice);
grid_export_revenue_dynamic = sum(pv_to_grid_kwh_dynamic .* export_rate);

pv_to_load_savings_dynamic = sum(pv_to_load_kwh_dynamic .* fixed_price);

if enableBattery
    pv_to_battery_savings_dynamic = sum(-pv_to_battery_kwh_dynamic .* fixed_price);
else
    pv_to_battery_savings_dynamic = 0;
end

if enableEV
    pv_to_ev_savings_dynamic = sum(pv_to_ev_savings_kwh_dynamic .* fixed_price);
    grid_to_ev_cost_dynamic = sum(-grid_to_ev_kwh_dynamic .* gridPrice) / ev_charge_efficiency;
else
    pv_to_ev_savings_dynamic = 0;
    grid_to_ev_cost_dynamic = 0;
end


if enableBattery && enableEV
    battery_discharge_savings_dynamic = sum((abs(battery_to_load_kwh_dynamic) + abs(battery_to_ev_kwh_dynamic)) .* fixed_price);
    battery_discharge_kwh_dynamic = abs(battery_to_load_kwh_dynamic) + abs(battery_to_ev_kwh_dynamic);
elseif enableBattery && ~enableEV
    battery_discharge_savings_dynamic = sum(abs(battery_to_load_kwh_dynamic) .* fixed_price);
    battery_discharge_kwh_dynamic = abs(battery_to_load_kwh_dynamic);
elseif ~enableBattery
    battery_discharge_savings_dynamic = 0;
    battery_discharge_kwh_dynamic = 0;
end

if enableBattery
    grid_charge_cost_dynamic = sum(-grid_to_battery_kwh_dynamic .* gridPrice);
    battery_charge_kwh_dynamic = -pv_to_battery_kwh_dynamic - grid_to_battery_kwh_dynamic;
    battery_throughput_kwh_dynamic = sum(abs(battery_charge_kwh_dynamic) + abs(battery_discharge_kwh_dynamic));
    equivalent_cycles_dynamic = battery_throughput_kwh_dynamic / (2 * battery_capacity);
    battery_degradation_cost_dynamic = (equivalent_cycles_dynamic / battery_lifetime_cycles) * battery_replacement_cost;
else
    grid_charge_cost_dynamic = 0;
    battery_charge_kwh_dynamic = 0;
    battery_throughput_kwh_dynamic = 0;
    equivalent_cycles_dynamic = 0;
    battery_degradation_cost_dynamic = 0;
end


op_cost_pv_storage_dynamic = grid_purchase_cost_dynamic + grid_charge_cost_dynamic + ...
                             battery_degradation_cost_dynamic + annual_maintenance + ...
                             grid_to_ev_cost_dynamic;
                         
total_revenue_pv_storage_dynamic = pv_to_load_savings_dynamic + pv_to_battery_savings_dynamic + ...
                                   battery_discharge_savings_dynamic + grid_export_revenue_dynamic + ...
                                   pv_to_ev_savings_dynamic;

net_profit_pv_storage_annual_dynamic = total_revenue_pv_storage_dynamic - op_cost_pv_storage_dynamic;
roi_pv_storage_annual_dynamic = (net_profit_pv_storage_annual_dynamic / initial_investment) * 100;



%%------------------------------------Static------------------------------------%%

%% Scenario 3: PV + Storage + Static Pricing (Year 1)
grid_purchase_cost_static = sum(grid_to_load_kwh_static .* fixed_price);
grid_export_revenue_static = sum(pv_to_grid_kwh_static * export_rate);

pv_to_load_savings_static = sum(pv_to_load_kwh_static .* fixed_price);

if enableBattery
    pv_to_battery_savings_static = sum(-pv_to_battery_kwh_static .* fixed_price);
else
    pv_to_battery_savings_static = 0;
end

if enableEV
    pv_to_ev_savings_static = sum(pv_to_ev_savings_kwh_static .* fixed_price);
    grid_to_ev_cost_static = sum(-grid_to_ev_kwh_static .* gridPrice) / ev_charge_efficiency;
else
    pv_to_ev_savings_static = 0;
    grid_to_ev_cost_static = 0;
end



if enableBattery && enableEV
    battery_discharge_savings_static = sum((abs(battery_to_load_kwh_static) + abs(battery_to_ev_kwh_static)) .* fixed_price);
    battery_discharge_kwh_static = abs(battery_to_load_kwh_static) + abs(battery_to_ev_kwh_static);
elseif enableBattery && ~enableEV
    battery_discharge_savings_static = sum(abs(battery_to_load_kwh_static) .* fixed_price);
    battery_discharge_kwh_static = abs(battery_to_load_kwh_static);
elseif ~enableBattery
    battery_discharge_savings_static = 0;
    battery_discharge_kwh_static = 0;
end

if enableBattery
    grid_charge_cost_static = sum(-grid_to_battery_kwh_static .* fixed_price);
    
    battery_charge_kwh_static = -pv_to_battery_kwh_static - grid_to_battery_kwh_static;
    battery_throughput_kwh_static = sum(abs(battery_charge_kwh_static) + abs(battery_discharge_kwh_static));
    equivalent_cycles_static = battery_throughput_kwh_static / (2 * battery_capacity);
    battery_degradation_cost_static = (equivalent_cycles_static / battery_lifetime_cycles) * battery_replacement_cost;
else
    grid_charge_cost_static = 0;
    battery_charge_kwh_static = 0;
    battery_throughput_kwh_static = 0;
    equivalent_cycles_static = 0;
    battery_degradation_cost_static = 0;
end




op_cost_pv_storage_static = grid_purchase_cost_static + grid_charge_cost_static + ...
                            battery_degradation_cost_static + annual_maintenance + ...
                            grid_to_ev_cost_static;

total_revenue_pv_storage_static = pv_to_load_savings_static + pv_to_battery_savings_static + ...
                                  battery_discharge_savings_static + grid_export_revenue_static + ...
                                  pv_to_ev_savings_static;

net_profit_pv_storage_annual_static = total_revenue_pv_storage_static - op_cost_pv_storage_static;
roi_pv_storage_annual_static = (net_profit_pv_storage_annual_static / initial_investment) * 100;


%%------------------------------------No-EMS------------------------------------%%

%% Scenario : PV + no_ems Pricing (Year 1)
hours_of_day = mod(hours_no_ems, 24);
is_peak = hours_of_day >= 8 & hours_of_day < 20;

grid_purchase_cost_no_ems = sum(grid_to_load_kwh_no_ems .* fixed_price);
grid_export_revenue_no_ems = sum(pv_to_grid_kwh_no_ems * export_rate);

pv_to_load_savings_no_ems = sum(pv_to_load_kwh_no_ems .* fixed_price);

if enableBattery
    pv_to_battery_savings_no_ems = sum(-pv_to_battery_kwh_no_ems .* fixed_price);
else
    pv_to_battery_savings_no_ems = 0;
end

if enableEV
    pv_to_ev_savings_no_ems = sum(pv_to_ev_savings_kwh_no_ems .* fixed_price);
    grid_to_ev_cost_no_ems = sum(-grid_to_ev_kwh_no_ems .* gridPrice) / ev_charge_efficiency;
else
    pv_to_ev_savings_no_ems = 0;
    grid_to_ev_cost_no_ems = 0;
end



if enableBattery && enableEV
    battery_discharge_savings_no_ems = sum((abs(battery_to_load_kwh_no_ems) + abs(battery_to_ev_kwh_no_ems)) .* fixed_price);
    battery_discharge_kwh_no_ems = abs(battery_to_load_kwh_no_ems) + abs(battery_to_ev_kwh_no_ems);
elseif enableBattery && ~enableEV
    battery_discharge_savings_no_ems = sum(abs(battery_to_load_kwh_no_ems) .* fixed_price);
    battery_discharge_kwh_no_ems = abs(battery_to_load_kwh_no_ems);
elseif ~enableBattery
    battery_discharge_savings_no_ems = 0;
    battery_discharge_kwh_no_ems = 0;
end

if enableBattery
    grid_charge_cost_no_ems = sum(-grid_to_battery_kwh_no_ems .* fixed_price);
    battery_charge_kwh_no_ems = -pv_to_battery_kwh_no_ems - grid_to_battery_kwh_no_ems;
    battery_throughput_kwh_no_ems = sum(abs(battery_charge_kwh_no_ems) + abs(battery_discharge_kwh_no_ems));
    equivalent_cycles_no_ems = battery_throughput_kwh_no_ems / (2 * battery_capacity);
    battery_degradation_cost_no_ems = (equivalent_cycles_no_ems / battery_lifetime_cycles) * battery_replacement_cost;
else
    grid_charge_cost_no_ems = 0;
    battery_charge_kwh_no_ems = 0;
    battery_throughput_kwh_no_ems = 0;
    equivalent_cycles_no_ems = 0;
    battery_degradation_cost_no_ems = 0;
end


op_cost_pv_storage_no_ems = grid_purchase_cost_no_ems + grid_charge_cost_no_ems + ...
                             battery_degradation_cost_no_ems + annual_maintenance + ...
                             grid_to_ev_cost_no_ems;
                         
total_revenue_pv_storage_no_ems = pv_to_load_savings_no_ems + pv_to_battery_savings_no_ems + ...
                                   battery_discharge_savings_no_ems + grid_export_revenue_no_ems + ...
                                   pv_to_ev_savings_no_ems;

net_profit_pv_storage_annual_no_ems = total_revenue_pv_storage_no_ems - op_cost_pv_storage_no_ems;
roi_pv_storage_annual_no_ems = (net_profit_pv_storage_annual_no_ems / initial_investment) * 100;

%%------------------------------------Life-time------------------------------------%%

%% Lifetime Financials with Escalation and NPV
years = 1:project_lifetime;
revenue_dynamic = zeros(1, project_lifetime);
op_cost_dynamic = zeros(1, project_lifetime);
net_profit_dynamic = zeros(1, project_lifetime);
savings_dynamic = zeros(1, project_lifetime);
grid_only_cost_year = zeros(1, project_lifetime);
battery_replacement_dynamic = zeros(1, project_lifetime);

revenue_static = zeros(1, project_lifetime);
op_cost_static = zeros(1, project_lifetime);
net_profit_static = zeros(1, project_lifetime);
savings_static = zeros(1, project_lifetime);
grid_only_cost_static_year = zeros(1, project_lifetime);
battery_replacement_static = zeros(1, project_lifetime);
if enableBattery
    replacement_cost_year_13 = battery_replacement_cost * (1 + battery_cost_escalation)^(battery_replacement_year - 1);
else
    replacement_cost_year_13 = 0;
end

if enableBattery
    battery_replacement_dynamic(battery_replacement_year) = replacement_cost_year_13;
    battery_replacement_static(battery_replacement_year) = replacement_cost_year_13;
else
    battery_discharge_savings_dynamic = 0;
    battery_discharge_savings_static = 0;
end

degradation_rate = 0.0154;
battery_capacity_dynamic = battery_capacity * (1 - degradation_rate * (years - 1));
battery_capacity_dynamic(years >= battery_replacement_year) = battery_capacity;

battery_capacity_static = battery_capacity * (1 - degradation_rate * (years - 1));
battery_capacity_static(years >= battery_replacement_year) = battery_capacity;

for t = 1:project_lifetime
    degradation_factor = 1;
    if enableBattery
        degradation_factor = battery_capacity_dynamic(t) / battery_capacity;
    end

    annual_maintenance_year = annual_maintenance * (1 + price_escalation)^(t-1);
    pv_to_load_savings_dynamic_year = pv_to_load_savings_dynamic * (1 + price_escalation)^(t-1);
    pv_to_battery_savings_dynamic_year = pv_to_battery_savings_dynamic * (1 + price_escalation)^(t-1);
    battery_discharge_savings_dynamic_year = battery_discharge_savings_dynamic * degradation_factor;
    grid_export_revenue_dynamic_year = grid_export_revenue_dynamic * (1 + price_escalation)^(t-1);
    pv_to_ev_savings_dynamic_year = pv_to_ev_savings_dynamic * (1 + price_escalation)^(t-1);

    grid_purchase_cost_dynamic_year = grid_purchase_cost_dynamic * (1 + price_escalation)^(t-1);
    grid_charge_cost_dynamic_year = grid_charge_cost_dynamic * (1 + price_escalation)^(t-1);
    grid_to_ev_cost_dynamic_year = grid_to_ev_cost_dynamic * (1 + price_escalation)^(t-1);
    battery_degradation_cost_dynamic_year = battery_degradation_cost_dynamic * degradation_factor;

    revenue_dynamic(t) = pv_to_load_savings_dynamic_year + pv_to_battery_savings_dynamic_year + ...
                         battery_discharge_savings_dynamic_year + grid_export_revenue_dynamic_year + ...
                         pv_to_ev_savings_dynamic_year;

    op_cost_dynamic(t) = grid_purchase_cost_dynamic_year + grid_charge_cost_dynamic_year + ...
                         battery_degradation_cost_dynamic_year + annual_maintenance_year + ...
                         grid_to_ev_cost_dynamic_year;
    net_profit_dynamic(t) = revenue_dynamic(t) - op_cost_dynamic(t);



    % ----- Static Pricing -----
    pv_to_load_savings_static_year = pv_to_load_savings_static * (1 + price_escalation)^(t-1);
    pv_to_battery_savings_static_year = pv_to_battery_savings_static * (1 + price_escalation)^(t-1);
    battery_discharge_savings_static_year = battery_discharge_savings_static * degradation_factor;
    grid_export_revenue_static_year = grid_export_revenue_static * (1 + price_escalation)^(t-1);
    pv_to_ev_savings_static_year = pv_to_ev_savings_static * (1 + price_escalation)^(t-1);

    grid_purchase_cost_static_year = grid_purchase_cost_static * (1 + price_escalation)^(t-1);
    grid_charge_cost_static_year = grid_charge_cost_static * (1 + price_escalation)^(t-1);
    grid_to_ev_cost_static_year = grid_to_ev_cost_static * (1 + price_escalation)^(t-1);
    battery_degradation_cost_static_year = battery_degradation_cost_static * degradation_factor;

    revenue_static(t) = pv_to_load_savings_static_year + pv_to_battery_savings_static_year + ...
                        battery_discharge_savings_static_year + grid_export_revenue_static_year + ...
                        pv_to_ev_savings_static_year;

    op_cost_static(t) = grid_purchase_cost_static_year + grid_charge_cost_static_year + ...
                        battery_degradation_cost_static_year + annual_maintenance_year + ...
                        grid_to_ev_cost_static_year;
    net_profit_static(t) = revenue_static(t) - op_cost_static(t);
end
% Dynamic KPIs
if enableBattery
    lifetime_operating_cost_dynamic = sum(op_cost_dynamic) + sum(battery_replacement_dynamic);
else
    lifetime_operating_cost_dynamic = sum(op_cost_dynamic);
end

lifetime_savings_dynamic = sum(revenue_dynamic);

if enableBattery 
    net_profit_lifetime_dynamic = sum(net_profit_dynamic) - sum(battery_replacement_dynamic);
else
    net_profit_lifetime_dynamic = sum(net_profit_dynamic);
end

roi_pv_storage_dynamic = (net_profit_lifetime_dynamic / initial_investment) * 100;

%payback period
cumulative_profit_dynamic = cumsum(net_profit_dynamic);
payback_period_dynamic = find(cumulative_profit_dynamic >= initial_investment, 1);

if isempty(payback_period_dynamic)
    payback_period_dynamic = Inf;
end

npv_dynamic = -initial_investment;
for t = 1:project_lifetime
    if enableBattery
        npv_dynamic = npv_dynamic + (net_profit_dynamic(t) - battery_replacement_dynamic(t)) / (1 + discount_rate)^t;
    else
        npv_dynamic = npv_dynamic + (net_profit_dynamic(t))/ (1 + discount_rate)^t;
    end
end

% Static KPIs
if enableBattery
    lifetime_operating_cost_static = sum(op_cost_static) + sum(battery_replacement_static);
else
    lifetime_operating_cost_static = sum(op_cost_static);
end

lifetime_savings_static = sum(revenue_static);

if enableBattery
    net_profit_lifetime_static = sum(net_profit_static) - sum(battery_replacement_static);
else
    net_profit_lifetime_static = sum(net_profit_static);
end

roi_pv_storage_static = (net_profit_lifetime_static / initial_investment) * 100;

% payback period 
cumulative_profit_static = cumsum(net_profit_static);
payback_period_static = find(cumulative_profit_static >= initial_investment, 1);

if isempty(payback_period_static)
    payback_period_static = Inf;
end

npv_static = -initial_investment;
for t = 1:project_lifetime
    if enableBattery
        npv_static = npv_static + (net_profit_static(t) - battery_replacement_static(t)) / (1 + discount_rate)^t;
    else
        npv_static = npv_static + (net_profit_static(t))/ (1 + discount_rate)^t;
    end
end

%% Lifetime Financials with Escalation and NPV (for No-EMS scenario)
revenue_no_ems = zeros(1, project_lifetime);
op_cost_no_ems = zeros(1, project_lifetime);
net_profit_no_ems = zeros(1, project_lifetime);
battery_replacement_no_ems = zeros(1, project_lifetime);

if enableBattery
    battery_replacement_no_ems(battery_replacement_year) = replacement_cost_year_13;
else
    battery_replacement_no_ems(battery_replacement_year) = 0;
end

for t = 1:project_lifetime

    annual_maintenance_year = annual_maintenance * (1 + price_escalation)^(t-1);
    pv_to_load_savings_no_ems_year = pv_to_load_savings_no_ems * (1 + price_escalation)^(t-1);
    grid_export_revenue_no_ems_year = grid_export_revenue_no_ems * (1 + price_escalation)^(t-1);
    pv_to_battery_savings_no_ems_year = pv_to_battery_savings_no_ems * (1 + price_escalation)^(t-1);
    battery_discharge_savings_no_ems_year = battery_discharge_savings_no_ems * degradation_factor;
    pv_to_ev_savings_no_ems_year = pv_to_ev_savings_no_ems * (1 + price_escalation)^(t-1);
    grid_to_ev_cost_no_ems_year = grid_to_ev_cost_no_ems * (1 + price_escalation)^(t-1);
    battery_degradation_cost_no_ems_year = battery_degradation_cost_no_ems * degradation_factor;
    grid_purchase_cost_no_ems_year = grid_purchase_cost_no_ems * (1 + price_escalation)^(t-1);

    revenue_no_ems(t) = pv_to_load_savings_no_ems_year + pv_to_battery_savings_no_ems_year + ...
                        battery_discharge_savings_no_ems_year + grid_export_revenue_no_ems_year + ...
                        pv_to_ev_savings_no_ems_year;

    op_cost_no_ems(t) = grid_purchase_cost_no_ems_year + ...
                        battery_degradation_cost_no_ems_year + annual_maintenance_year + ...
                        grid_to_ev_cost_no_ems_year;

    net_profit_no_ems(t) = revenue_no_ems(t) - op_cost_no_ems(t);
end

if enableBattery
    lifetime_operating_cost_no_ems = sum(op_cost_no_ems) + sum(battery_replacement_no_ems);
else
    lifetime_operating_cost_no_ems = sum(op_cost_no_ems);
end

lifetime_savings_no_ems = sum(revenue_no_ems);


if enableBattery
    net_profit_lifetime_no_ems = sum(net_profit_no_ems) - sum(battery_replacement_no_ems);
else
    net_profit_lifetime_no_ems = sum(net_profit_no_ems);
end
roi_no_ems = (net_profit_lifetime_no_ems / initial_investment) * 100;

% payback period
cumulative_profit_no_ems = cumsum(net_profit_no_ems);
payback_period_no_ems = find(cumulative_profit_no_ems >= initial_investment, 1);

if isempty(payback_period_no_ems)
    payback_period_no_ems = Inf;
end

npv_no_ems = -initial_investment;
for t = 1:project_lifetime
    npv_no_ems = npv_no_ems + (net_profit_no_ems(t)) / (1 + discount_rate)^t;
end

%%------------------------------------Export------------------------------------%%

%% Exporting Financial Summary to CSV and XLSX
parameters = {
    'Initial Investment (PV+Storage) (€)', initial_investment, initial_investment, initial_investment;
    '[BOLD] Expenses', '', '', '';
    'Grid Purchase Cost Year 1 (€)', grid_purchase_cost_dynamic, grid_purchase_cost_static, grid_purchase_cost_no_ems;
    'Grid Charging Cost Year 1 (€)', grid_charge_cost_dynamic, grid_charge_cost_static, grid_charge_cost_no_ems;
    'Grid to EV Cost Year 1 (€)', grid_to_ev_cost_dynamic, grid_to_ev_cost_static, grid_to_ev_cost_no_ems;
    'Battery Degradation Cost Year 1 (€)', battery_degradation_cost_dynamic, battery_degradation_cost_static, battery_degradation_cost_no_ems;
    'Annual Maintenance Cost Year 1 (€)', annual_maintenance, annual_maintenance, annual_maintenance;
    'Battery Replacement Cost Year 13 (€)', replacement_cost_year_13, replacement_cost_year_13, replacement_cost_year_13;
    '[BOLD] Savings', '', '', '';
    'PV to Load Savings Year 1 (€)', pv_to_load_savings_dynamic, pv_to_load_savings_static, pv_to_load_savings_no_ems;
    'PV to Battery Savings Year 1 (€)', pv_to_battery_savings_dynamic, pv_to_battery_savings_static, pv_to_battery_savings_no_ems;
    'PV to EV Savings Year 1 (€)', pv_to_ev_savings_dynamic , pv_to_ev_savings_static, pv_to_ev_savings_no_ems;
    'Battery Discharge Savings Year 1 (€)', battery_discharge_savings_dynamic, battery_discharge_savings_static, battery_discharge_savings_no_ems;
    'Grid Export Revenue Year 1 (€)', grid_export_revenue_dynamic, grid_export_revenue_static, grid_export_revenue_no_ems;
    '[BOLD] PV + Storage', '', '', '';
    'Annual Operating Cost Year 1 (€)', op_cost_pv_storage_dynamic, op_cost_pv_storage_static, op_cost_pv_storage_no_ems;
    'Annual Revenue/Savings Year 1 (€)', total_revenue_pv_storage_dynamic, total_revenue_pv_storage_static, total_revenue_pv_storage_no_ems;
    'Net Profit Annual Year 1 (€)', net_profit_pv_storage_annual_dynamic, net_profit_pv_storage_annual_static, net_profit_pv_storage_annual_no_ems;
    %'Annual Savings vs Grid-Only Year 1 (€)', annual_savings_pv_storage_dynamic, annual_savings_pv_storage_static, annual_savings_no_ems;
    'ROI (PV+Storage) Year 1 (%)', roi_pv_storage_annual_dynamic, roi_pv_storage_annual_static, roi_pv_storage_annual_no_ems;
    '[BOLD] Lifetime Cost', '', '', '';
    'Lifetime Operating Cost (€)', lifetime_operating_cost_dynamic, lifetime_operating_cost_static, lifetime_operating_cost_no_ems;
    'Lifetime Savings (€)', sum(lifetime_savings_dynamic), sum(lifetime_savings_static), sum(lifetime_savings_no_ems);
    'Net Profit Lifetime (€)', sum(net_profit_lifetime_dynamic), sum(net_profit_lifetime_static), sum(net_profit_lifetime_no_ems);
    'ROI (PV+Storage) (%)', roi_pv_storage_dynamic, roi_pv_storage_static, roi_no_ems;
    'Payback Period (PV+Storage) (years)', payback_period_dynamic, payback_period_static, payback_period_no_ems;
    'NPV (PV+Storage) (€)', npv_dynamic, npv_static, npv_no_ems;
};

if size(parameters, 1) ~= 26
    error('Parameters cell array does not have 26 rows, has %d rows', size(parameters, 1));
end

blank_row_indices = [1, 8, 14, 19];
for idx = sort(blank_row_indices, 'descend')
    parameters = [parameters(1:idx,:); {'' '' '' ''}; parameters(idx+1:end,:)];
end

bold_indices = false(size(parameters, 1), 1);
for i = 1:size(parameters, 1)
    if startsWith(parameters{i, 1}, '[BOLD]')
        bold_indices(i) = true;
        parameters{i, 1} = strrep(parameters{i, 1}, '[BOLD] ', '');
    elseif isempty(parameters{i, 1})
        bold_indices(i) = true;
    end
end

results_table = table(parameters(:,1), parameters(:,2), parameters(:,3), parameters(:,4), ...
    'VariableNames', {'Parameter', 'Dynamic Pricing Value', 'Static Pricing Value', 'No-EMS Value'});

writetable(results_table, 'ems_cost.csv');

try
    writetable(results_table, 'ems_cost.xlsx', 'WriteVariableNames', true);
    if ispc
        excel = actxserver('Excel.Application');
        excel.Visible = false;
        workbook = excel.Workbooks.Open(fullfile(pwd(), 'ems_cost.xlsx'));
        worksheet = workbook.Worksheets.Item(1);
        worksheet.Rows.Item(1).Font.Bold = true;

        for row = 2:size(parameters,1)+1
            if bold_indices(row-1)
                worksheet.Rows.Item(row).Font.Bold = true;
            end
        end

        last_row = size(parameters,1) + 1;
        range_dynamic = worksheet.Range(sprintf('B2:B%d', last_row));
        range_static = worksheet.Range(sprintf('C2:C%d', last_row));
        range_no_ems = worksheet.Range(sprintf('D2:D%d', last_row));
        range_dynamic.NumberFormat = '0.00';
        range_static.NumberFormat = '0.00';
        range_no_ems.NumberFormat = '0.00';

        workbook.Save();
        workbook.Close(false);
        excel.Quit();
    else
        fprintf('Saved to ems_cost.xlsx. Manual formatting required on non-Windows systems.\n');
    end
catch e
    warning('Excel export/formatting failed: %s', e.message);
    try
        if ispc && exist('excel', 'var') && ~isempty(excel)
            excel.Quit();
        end
    catch
    end
end
