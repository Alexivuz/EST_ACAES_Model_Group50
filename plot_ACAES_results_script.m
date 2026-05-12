function plot_ACAES_results()
    % 1. Get the simulation output object
    if evalin('base', 'exist(''out'',''var'')')
        simOut = evalin('base', 'out');
    else
        simOut = [];
    end

    % 2. Mapping of variables
    vars = {'P_supply', 'P_demand', 'P_hp', 'SOC_hp'};
    % Dictionary of possible names for each
    map.P_supply = {'P_supply_W', 'P_supply', 'P_supply_MW'};
    map.P_demand = {'P_demand_W', 'P_demand', 'P_demand_MW'};
    map.P_hp     = {'P_hp', 'P_hp_out', 'P_turbine'};
    map.SOC_hp   = {'SOC_hp', 'SOC_hp_out', 'SOC_tank'};

    dataStruct = struct();

    % 3. Extraction Logic
    for i = 1:length(vars)
        v = vars{i};
        found = false;
        candidates = map.(v);
        
        for j = 1:length(candidates)
            name = candidates{j};
            
            % Check inside the 'out' object first (Modern Simulink)
            if ~isempty(simOut) && isprop(simOut, name)
                raw = simOut.(name);
                found = true;
            % Check the base workspace (Old style / Loose variables)
            elseif evalin('base', sprintf('exist(''%s'',''var'')', name))
                raw = evalin('base', name);
                found = true;
            end
            
            if found
                if isa(raw, 'timeseries')
                    dataStruct.(v).t = raw.Time;
                    dataStruct.(v).y = raw.Data;
                elseif isstruct(raw) && isfield(raw, 'time')
                    dataStruct.(v).t = raw.time;
                    dataStruct.(v).y = raw.signals.values;
                else
                    % Fallback for simple arrays
                    dataStruct.(v).t = (1:length(raw))';
                    dataStruct.(v).y = raw;
                end
                break;
            end
        end
        
        if ~found
            fprintf('Skipping %s: Not found in "out" or Workspace.\n', v);
            dataStruct.(v) = [];
        end
    end

    % 4. Robust Plotting
    figure('Color', 'w', 'Name', 'ACAES Model Results');
    
    % Subplot 1: Power
    subplot(2,1,1); hold on; grid on;
    if ~isempty(dataStruct.P_supply), plot(dataStruct.P_supply.t, dataStruct.P_supply.y, 'b', 'LineWidth', 1.5); end
    if ~isempty(dataStruct.P_demand), plot(dataStruct.P_demand.t, dataStruct.P_demand.y, 'r', 'LineWidth', 1.5); end
    title('Power Profile'); ylabel('Power [W]');
    legend('Supply', 'Demand', 'Location', 'best');

    % Subplot 2: Energy Storage
    subplot(2,1,2); hold on; grid on;
    if ~isempty(dataStruct.SOC_hp), plot(dataStruct.SOC_hp.t, dataStruct.SOC_hp.y, 'g', 'LineWidth', 1.5); end
    title('Storage State of Charge'); ylabel('SOC [0-1]'); xlabel('Time [s]');
    
    fprintf('Plotting complete.\n');
end