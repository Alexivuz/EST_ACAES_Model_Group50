%% CAES_extract_results.m
% Run this script after the Simulink simulation completes.
% It extracts all signals from 'out', computes KPIs, and prints a summary.
% No need to run extract_from_out.m separately.

fprintf('\n== Extracting simulation results... ==\n');

%% ── STEP 1: EXTRACT SIGNALS FROM 'out' ───────────────────────────────────

t        = out.P_net_log.Time;           % [s] simulation time vector
dt_s     = mean(diff(t));                % [s] timestep
dt_h     = dt_s / 3600;                 % [hours] timestep

% Power signals [W]
P_net_W   = out.P_net_log.Data;
P_chg_W   = out.P_chg_log.Data;
P_dis_W   = out.P_dis_log.Data;
P_sell_W  = out.P_sell_log.Data;
P_buy_W   = out.P_buy_log.Data;

% Rebuild supply and demand by interpolating onto simulation time grid
P_supply_W_sim = interp1(t_vec, P_supply_W, t, 'linear', 'extrap');
P_demand_W_sim = interp1(t_vec, P_demand_W, t, 'linear', 'extrap');

% Storage state
SOC_hp    = out.SOC_hp_log.Data;         % [-]
SOC_tes   = out.SOC_TES_log.Data;        % [-]
P_hp_Pa   = out.P_hp_log.Data;           % [Pa]
T_hp_K    = out.T_hp_log.Data;           % [K]

% TES temperatures — merge 3 stages into N×3 matrix
T_TES     = horzcat(out.T_TES_log1.Data, ...
                    out.T_TES_log2.Data, ...
                    out.T_TES_log3.Data);  % [K]

% Losses [W]
loss_tes  = out.loss_TES_log.Data;
loss_thr  = out.loss_thr_log.Data;

% Other
mode_vec  = out.mode_log.Data;           % 0=idle, 1=charge, 2=discharge
profit_v  = out.profit_log.Data;         % [£]
eta_RT_v  = out.eta_RT_log.Data;         % [-]

fprintf('Signals extracted successfully.\n');

%% ── STEP 2: CUMULATIVE ENERGY [kWh] ──────────────────────────────────────

E_chg     = trapz(t, P_chg_W)        / 3.6e6;
E_dis     = trapz(t, P_dis_W)        / 3.6e6;
E_sold    = trapz(t, P_sell_W)       / 3.6e6;
E_bought  = trapz(t, P_buy_W)        / 3.6e6;
E_supply  = trapz(t, P_supply_W_sim) / 3.6e6;
E_demand  = trapz(t, P_demand_W_sim) / 3.6e6;

%% ── STEP 3: LOSSES [kWh] ─────────────────────────────────────────────────

E_loss_tes   = trapz(t, loss_tes) / 3.6e6;
E_loss_thr   = trapz(t, loss_thr) / 3.6e6;
E_loss_total = E_loss_tes + E_loss_thr;

%% ── STEP 4: KPIs ─────────────────────────────────────────────────────────

if E_chg > 0
    eta_RT = (E_dis / E_chg) * 100;
else
    eta_RT = 0;
end

if E_demand > 0
    self_suf = (1 - E_bought / E_demand) * 100;
else
    self_suf = 0;
end

storage_util   = mean(SOC_hp) * 100;
peak_SOC_hp    = max(SOC_hp)  * 100;
peak_SOC_tes   = max(SOC_tes) * 100;
peak_P_hp_MPa  = max(P_hp_Pa) / 1e6;
peak_T_TES_C   = max(T_TES(:)) - 273.15;
profit         = profit_v(end);

frac_charge    = mean(mode_vec == 1) * 100;
frac_discharge = mean(mode_vec == 2) * 100;
frac_idle      = mean(mode_vec == 0) * 100;

%% ── STEP 5: PRINT SUMMARY ────────────────────────────────────────────────

fprintf('\n══════════════════════════════════════════\n');
fprintf('   CAES SIMULATION — RESULTS SUMMARY\n');
fprintf('══════════════════════════════════════════\n');

fprintf('\n  SIMULATION INFO\n');
fprintf('  %-30s %8.1f hours\n',  'Duration:',         t(end)/3600);
fprintf('  %-30s %8.1f min\n',    'Timestep:',         dt_s/60);

fprintf('\n  ENERGY ACCOUNTING\n');
fprintf('  %-30s %8.2f kWh\n', 'Total supply:',        E_supply);
fprintf('  %-30s %8.2f kWh\n', 'Total demand:',        E_demand);
fprintf('  %-30s %8.2f kWh\n', 'Total energy charged:', E_chg);
fprintf('  %-30s %8.2f kWh\n', 'Total energy recovered:', E_dis);
fprintf('  %-30s %8.2f %%\n',  'Round-trip efficiency:', eta_RT);

fprintf('\n  GRID INTERACTION\n');
fprintf('  %-30s %8.2f kWh\n', 'Sold to grid:',        E_sold);
fprintf('  %-30s %8.2f kWh\n', 'Bought from grid:',    E_bought);
fprintf('  %-30s %8.1f %%\n',  'Grid self-sufficiency:', self_suf);
fprintf('  %-30s %8.2f GBP\n', 'Net economic result:', profit);

fprintf('\n  STORAGE STATE\n');
fprintf('  %-30s %8.1f %%\n',  'Avg HP store utilisation:', storage_util);
fprintf('  %-30s %8.1f %%\n',  'Peak HP SOC:',          peak_SOC_hp);
fprintf('  %-30s %8.1f %%\n',  'Peak TES SOC:',         peak_SOC_tes);
fprintf('  %-30s %8.2f MPa\n', 'Peak HP pressure:',     peak_P_hp_MPa);
fprintf('  %-30s %8.1f C\n',   'Peak TES temperature:', peak_T_TES_C);

fprintf('\n  OPERATING TIME\n');
fprintf('  %-30s %8.1f %%\n',  'Time charging:',        frac_charge);
fprintf('  %-30s %8.1f %%\n',  'Time discharging:',     frac_discharge);
fprintf('  %-30s %8.1f %%\n',  'Time idle:',            frac_idle);

fprintf('\n  LOSS BREAKDOWN\n');
fprintf('  %-30s %8.2f kWh\n', 'TES thermal losses:',   E_loss_tes);
fprintf('  %-30s %8.2f kWh\n', 'Throttle losses:',      E_loss_thr);
fprintf('  %-30s %8.2f kWh\n', 'Total losses logged:',  E_loss_total);

fprintf('══════════════════════════════════════════\n\n');

%% ===== DEBUG: CHECK KEY SIGNALS =====

% fprintf('\n\n=== DEBUG SIGNAL CHECK ===\n');

% Net power and mode
%fprintf('P_net min/max [MW]: %.3f / %.3f\n', ...
    %min(out.P_net_log.Data)/1e6, max(out.P_net_log.Data)/1e6);

%fprintf('Unique mode values:\n');
%disp(unique(out.mode_log.Data));

% Check if common charging signals exist
%debugSignals = { ...
  %  'P_chg_log', ...
  %  'P_comp_log', ...
  %  'm_dot_to_HP_log', ...
   % 'T_air_to_HP_log', ...
  %  'mdot_in_log', ...
 %   'T_in_log', ...
  %  'SOC_hp_log', ...
 %   'P_hp_log', ...
 %   'T_hp_log' ...
 %   };

%for i = 1:length(debugSignals)
 %   sigName = debugSignals{i};
%
 %   if isfield(out, sigName)
  %      sig = out.(sigName);
%
%       fprintf('\n%s exists.\n', sigName);
 %       fprintf('  min = %.6g\n', min(sig.Data(:)));
  %      fprintf('  max = %.6g\n', max(sig.Data(:)));
   %     fprintf('  first = %.6g\n', sig.Data(1));
    %    fprintf('  last  = %.6g\n', sig.Data(end));
 %   else
  %      fprintf('\n%s does NOT exist in out.\n', sigName);
 %   end
%end

%fprintf('\n=== END DEBUG SIGNAL CHECK ===\n');

%%% ===== DEBUG: WORKSPACE SIGNALS FROM CHARGING TRAIN =====

%fprintf('\n\n=== DEBUG CHARGING TRAIN OUTPUTS ===\n');
%
%workspaceSignals = { ...
%    'T_air_to_HP_log', ...
%    'm_dot_to_HP_log', ...
%    'W_dot_elec_chg_log' ...
%};

%for i = 1:length(workspaceSignals)
  %  sigName = workspaceSignals{i};

  %  if evalin('base', sprintf('exist(''%s'', ''var'')', sigName))
   %     sig = evalin('base', sigName);

   %     fprintf('\n%s exists.\n', sigName);
    %    fprintf('  min   = %.6g\n', min(sig.Data(:)));
    %    fprintf('  max   = %.6g\n', max(sig.Data(:)));
    %    fprintf('  first = %.6g\n', sig.Data(1));
    %    fprintf('  last  = %.6g\n', sig.Data(end));
   % else
   %     fprintf('\n%s does NOT exist in base workspace.\n', sigName);
  %  end
%end

% fprintf('\n=== END DEBUG CHARGING TRAIN OUTPUTS ===\n');