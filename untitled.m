%% CAES_results.m — Run after simulation to plot and analyze results
clear figs; close all;

% Extract time from any logged timeseries
t = 'P_net_log.Time' / 3600;   % convert to hours

%% ===== FIGURE 1: SUPPLY, DEMAND, AND NET POWER =====
figure('Name','Energy Balance','Position',[100 100 1200 500]);

subplot(1,2,1)
plot(t, P_supply_log.Data/1000, 'b-', 'LineWidth', 2, 'DisplayName','Supply'); hold on
plot(t, P_demand_log.Data/1000, 'r-', 'LineWidth', 2, 'DisplayName','Demand');
fill([t; flipud(t)], [P_supply_log.Data/1000; flipud(P_demand_log.Data/1000)], ...
     'g', 'FaceAlpha', 0.15, 'EdgeColor','none', 'DisplayName','Area');
xlabel('Time [hours]'); ylabel('Power [kW]');
title('Supply vs. Demand'); legend; grid on;

subplot(1,2,2)
area_chg = max(P_net_log.Data/1000, 0);   % surplus → charge
area_dis = min(P_net_log.Data/1000, 0);   % deficit → discharge
area(t, area_chg, 'FaceColor', [0 0.7 0], 'FaceAlpha', 0.5); hold on
area(t, area_dis, 'FaceColor', [0.9 0 0], 'FaceAlpha', 0.5);
yline(0, 'k--');
xlabel('Time [hours]'); ylabel('Net Power [kW]');
title('Net Power Balance (Green=Surplus, Red=Deficit)');
grid on;

%% ===== FIGURE 2: CAES STORAGE STATE =====
figure('Name','CAES Storage State','Position',[100 100 1200 700]);

subplot(2,2,1)
plot(t, SOC_hp_log.Data, 'b-', 'LineWidth', 2);
ylim([0 1]); ylabel('SOC [-]'); xlabel('Time [hours]');
title('HP Air Store SOC (Pneumatic Storage)'); grid on;
yline(0.05,'r--','Low limit'); yline(0.95,'r--','High limit');

subplot(2,2,2)
plot(t, SOC_TES_log.Data, 'r-', 'LineWidth', 2);
ylim([0 1]); ylabel('SOC [-]'); xlabel('Time [hours]');
title('TES SOC (Thermal Storage)'); grid on;
yline(0.10,'r--','Minimum');

subplot(2,2,3)
plot(t, P_hp_log.Data/1e6, 'b-', 'LineWidth', 2);
ylabel('Pressure [MPa]'); xlabel('Time [hours]');
title('HP Store Pressure'); grid on;
yline(P_hp_min/1e6,'g--','Min'); yline(P_hp_max/1e6,'r--','Max');

subplot(2,2,4)
plot(t, T_TES_log.Data(:,1)-273.15, 'r-', 'LineWidth',1.5,'DisplayName','TES Stage 1'); hold on
plot(t, T_TES_log.Data(:,2)-273.15, 'g-', 'LineWidth',1.5,'DisplayName','TES Stage 2');
plot(t, T_TES_log.Data(:,3)-273.15, 'b-', 'LineWidth',1.5,'DisplayName','TES Stage 3');
ylabel('Temperature [°C]'); xlabel('Time [hours]');
title('TES Temperatures'); legend; grid on;

%% ===== FIGURE 3: ENERGY FLOWS =====
figure('Name','Energy Flows','Position',[100 100 1200 500]);

subplot(1,2,1)
plot(t, P_chg_log.Data/1000, 'b-', 'LineWidth',2,'DisplayName','Compression power in'); hold on
plot(t, P_dis_log.Data/1000, 'g-', 'LineWidth',2,'DisplayName','Turbine power out');
plot(t, P_sell_log.Data/1000, 'y-', 'LineWidth',1.5,'DisplayName','Grid sell');
plot(t, -P_buy_log.Data/1000, 'r-', 'LineWidth',1.5,'DisplayName','Grid buy (negative)');
xlabel('Time [hours]'); ylabel('Power [kW]');
title('Real-Time Energy Flows'); legend; grid on;

subplot(1,2,2)
mode_colors = mode_log.Data;  % 0=idle, 1=charge, 2=discharge
stairs(t, mode_colors, 'k-', 'LineWidth', 2);
yticks([0 1 2]); yticklabels({'Idle','Charging','Discharging'});
xlabel('Time [hours]'); title('System Operating Mode'); grid on;

%% ===== FIGURE 4: EFFICIENCY AND ECONOMICS =====
figure('Name','Efficiency & Economics','Position',[100 100 1200 500]);

subplot(1,2,1)
% Waterfall chart of energy losses
E_in   = E_chg_log.Data(end)/3.6e6;  % [kWh]
E_out  = E_dis_log.Data(end)/3.6e6;
E_comp = loss_comp_log.Data(end)/3.6e6;
E_tes  = loss_TES_log.Data(end)/3.6e6;
E_thr  = loss_thr_log.Data(end)/3.6e6;
E_turb = loss_turb_log.Data(end)/3.6e6;
E_gen  = loss_gen_log.Data(end)/3.6e6;

categories = {'Input','Comp Loss','HEX/TES Loss','Throttle Loss','Turb Loss','Gen Loss','Output'};
values      = [E_in, -E_comp, -E_tes, -E_thr, -E_turb, -E_gen, E_out];
bar(values); xticklabels(categories); xtickangle(30);
ylabel('Energy [kWh]'); title('Energy Waterfall (Single Cycle)'); grid on;
yline(0,'k-');

subplot(1,2,2)
% Economics over time
plot(t, profit_log.Data, 'g-', 'LineWidth', 2);
xlabel('Time [hours]'); ylabel('Cumulative Profit [£]');
title('Economic Balance (Grid Sell - Buy)'); grid on;
yline(0,'k--');

%% ===== PRINT SUMMARY =====
fprintf('\n====== CAES SIMULATION RESULTS SUMMARY ======\n');
fprintf('Simulation period:        %.0f hours\n', t(end));
fprintf('\n--- ENERGY ACCOUNTING ---\n');
fprintf('Total energy charged:     %.2f kWh\n', E_in);
fprintf('Total energy recovered:   %.2f kWh\n', E_out);
fprintf('Round-trip efficiency:    %.1f%%\n', eta_RT_log.Data(end)*100);
fprintf('\n--- LOSS BREAKDOWN ---\n');
fprintf('Compressor losses:        %.2f kWh (%.1f%%)\n', E_comp, E_comp/E_in*100);
fprintf('TES thermal losses:       %.2f kWh (%.1f%%)\n', E_tes,  E_tes/E_in*100);
fprintf('Throttle exergy loss:     %.2f kWh (%.1f%%)\n', E_thr,  E_thr/E_in*100);
fprintf('Turbine losses:           %.2f kWh (%.1f%%)\n', E_turb, E_turb/E_in*100);
fprintf('Generator losses:         %.2f kWh (%.1f%%)\n', E_gen,  E_gen/E_in*100);
fprintf('Unaccounted (leakage etc):%.2f kWh\n', E_in - E_out - E_comp - E_tes - E_thr - E_turb - E_gen);
fprintf('\n--- GRID INTERACTION ---\n');
fprintf('Energy sold to grid:      %.2f kWh\n', E_sold_log.Data(end)/3.6e6);
fprintf('Energy bought from grid:  %.2f kWh\n', E_bought_log.Data(end)/3.6e6);
fprintf('Net economic result:      £%.2f\n', profit_log.Data(end));
fprintf('==============================================\n');