function R = CAES_extract_results_annual()
% CAES_EXTRACT_RESULTS_ANNUAL
% Fixes held-value problem from enabled subsystems by zeroing
% P_chg when mode~=1 and P_dis when mode~=2 before all calculations.
% Run after: out = sim('ACAES')

%% ── get output ───────────────────────────────────────────────────────────
if ~evalin('base','exist(''out'',''var'')')
    error('No ''out'' variable. Run: out = sim(''ACAES'')');
end
out = evalin('base','out');

%% ── time vector ──────────────────────────────────────────────────────────
t    = out.tout(:);
N    = length(t);
dt_s = median(diff(t));
fprintf('Timesteps: %d  |  Duration: %.2f days  |  dt: %.0f s (%.0f min)\n', ...
        N, t(end)/86400, dt_s, dt_s/60);

%% ── signal reader ────────────────────────────────────────────────────────
rd = @(fn, def) read_ts(out, fn, t, N, def);

%% ── read all signals ─────────────────────────────────────────────────────
mode_vec = rd('mode_log',    0);   % read mode FIRST — used to correct others
P_net_W  = rd('P_net_log',   0);
P_chg_W  = rd('P_chg_log',   0);
P_dis_W  = rd('P_dis_log',   0);
P_sell_W = rd('P_sell_log',  0);
P_buy_W  = rd('P_buy_log',   0);
SOC_hp   = rd('SOC_hp_log',  0);
SOC_tes  = rd('SOC_TES_log', 0);
P_hp_Pa  = rd('P_hp_log',    4e6);
T_hp_K   = rd('T_hp_log',    293.15);
profit_v = rd('profit_log',  0);
E_stored = rd('E_stored_log',0);
eta_RT_v = rd('eta_RT_log',  0);
loss_tes = rd('loss_TES_log',0);
loss_thr = rd('loss_thr_log',0);
T1       = rd('T_TES_log1',  293.15);
T2       = rd('T_TES_log2',  293.15);
T3       = rd('T_TES_log3',  293.15);

%% ── CRITICAL FIX: zero held values from enabled subsystems ───────────────
% Enabled subsystems hold their last output when disabled.
% This inflates E_chg and E_dis by 5-10x.
% Solution: force zero whenever mode does not match the subsystem.

P_chg_W(mode_vec ~= 1) = 0;   % compressor only runs when charging
P_dis_W(mode_vec ~= 2) = 0;   % turbine only runs when discharging

% Also clean any NaN or Inf values
P_chg_W(~isfinite(P_chg_W)) = 0;
P_dis_W(~isfinite(P_dis_W)) = 0;

% Compute net power from workspace data if P_net_log is wrong
t_data   = evalin('base','t_vec');
sup_data = evalin('base','P_supply_W');
dem_data = evalin('base','P_demand_W');
supply_W = interp1(t_data, sup_data, t, 'previous', sup_data(end));
demand_W = interp1(t_data, dem_data, t, 'previous', dem_data(end));

%% ── fix P_sell and P_buy using mode and corrected powers ─────────────────
% Recompute from scratch to avoid held-value contamination
P_sell_W_corr = zeros(N,1);
P_buy_W_corr  = zeros(N,1);

for i = 1:N
    pnet = supply_W(i) - demand_W(i);
    if mode_vec(i) == 1      % CHARGING
        pb = max(0, P_chg_W(i) - pnet);   % buy if surplus < compressor need
        ps = max(0, pnet - P_chg_W(i));   % sell leftover surplus
    elseif mode_vec(i) == 2  % DISCHARGING
        net_after = pnet + P_dis_W(i);
        pb = max(0, -net_after);
        ps = max(0,  net_after);
    else                     % IDLE
        pb = max(0, -pnet);
        ps = max(0,  pnet);
    end
    P_sell_W_corr(i) = ps;
    P_buy_W_corr(i)  = pb;
end

%% ── loss signals — detect cumulative vs power ────────────────────────────
is_cum_tes = all(diff(loss_tes) >= -abs(max(loss_tes))*1e-6);
is_cum_thr = all(diff(loss_thr) >= -abs(max(loss_thr))*1e-6);

if is_cum_tes
    E_loss_tes_J = loss_tes(end);
    loss_tes_W   = max(0, gradient(loss_tes, t));
else
    E_loss_tes_J = trapz(t, loss_tes);
    loss_tes_W   = loss_tes;
end

if is_cum_thr
    E_loss_thr_J = loss_thr(end);
    loss_thr_W   = max(0, gradient(loss_thr, t));
else
    E_loss_thr_J = trapz(t, loss_thr);
    loss_thr_W   = loss_thr;
end

%% ── component loss estimates ─────────────────────────────────────────────
eta_comp    = 0.82 * 0.97 * 0.95;
eta_turb    = 0.85 * 0.98;
eta_gen     = 0.96;
loss_comp_W = P_chg_W * (1 - eta_comp);
loss_turb_W = P_dis_W * (1 - eta_turb) / max(eta_turb, 0.01);
loss_gen_W  = P_dis_W * (1 / eta_gen - 1);

%% ── energy integrals [MWh] ───────────────────────────────────────────────
strapz = @(sig) trapz(t, sig) / 3.6e9;   % W·s → MWh

R.E_chg        = strapz(P_chg_W);
R.E_dis        = strapz(P_dis_W);
R.E_sold       = strapz(P_sell_W_corr);
R.E_bought     = strapz(P_buy_W_corr);
R.E_demand     = strapz(demand_W);
R.E_supply     = strapz(supply_W);
R.E_loss_comp  = strapz(loss_comp_W);
R.E_loss_tes   = E_loss_tes_J / 3.6e9;
R.E_loss_thr   = E_loss_thr_J / 3.6e9;
R.E_loss_turb  = strapz(loss_turb_W);
R.E_loss_gen   = strapz(loss_gen_W);
R.E_loss_total = R.E_loss_comp + R.E_loss_tes + R.E_loss_thr ...
               + R.E_loss_turb + R.E_loss_gen;

%% ── sanity checks ────────────────────────────────────────────────────────
fprintf('\n=== SANITY CHECKS ===\n');
fprintf('E_chg < E_supply:      %s  (%.1f vs %.1f MWh)\n', ...
    string(R.E_chg < R.E_supply), R.E_chg, R.E_supply);
fprintf('E_dis < E_chg:         %s  (%.1f vs %.1f MWh)\n', ...
    string(R.E_dis < R.E_chg), R.E_dis, R.E_chg);
fprintf('E_sold < E_supply:     %s  (%.1f vs %.1f MWh)\n', ...
    string(R.E_sold < R.E_supply), R.E_sold, R.E_supply);
fprintf('E_losses < E_chg:      %s  (%.1f vs %.1f MWh)\n', ...
    string(R.E_loss_total < R.E_chg), R.E_loss_total, R.E_chg);
fprintf('=====================\n\n');

%% ── KPIs ─────────────────────────────────────────────────────────────────
sdiv = @(a,b) a / max(b, 1e-9);

R.eta_RT         = sdiv(R.E_dis,    R.E_chg)    * 100;
R.eta_RT_logged  = eta_RT_v(end) * 100;
R.self_suf       = (1 - sdiv(R.E_bought, R.E_demand)) * 100;
R.storage_util   = mean(SOC_hp)  * 100;
R.peak_SOC_hp    = max(SOC_hp)   * 100;
R.peak_SOC_tes   = max(SOC_tes)  * 100;
R.peak_P_MPa     = max(P_hp_Pa)  / 1e6;
R.peak_T_TES_C   = max([T1;T2;T3]) - 273.15;
R.peak_E_stored  = max(E_stored) / 3.6e9;
R.profit         = profit_v(end);
R.frac_charge    = mean(mode_vec == 1) * 100;
R.frac_discharge = mean(mode_vec == 2) * 100;
R.frac_idle      = mean(mode_vec == 0) * 100;
R.t              = t;
R.N              = N;
R.dt_s           = dt_s;

%% ── output table ─────────────────────────────────────────────────────────
fprintf('Building daily summary table...\n');
day_num      = floor(t / 86400) + 1;
hour_of_day  = floor(mod(t, 86400) / 3600);
minute_of_hr = floor(mod(t, 3600)  / 60);
month_num    = min(ceil(day_num / 30.44), 12);

R.data = table(t/3600, day_num, month_num, hour_of_day, minute_of_hr, ...
    supply_W/1e6,    demand_W/1e6,     P_net_W/1e6, ...
    P_chg_W/1e6,     P_dis_W/1e6, ...
    P_sell_W_corr/1e6, P_buy_W_corr/1e6, ...
    SOC_hp*100,      SOC_tes*100, ...
    P_hp_Pa/1e6,     T_hp_K-273.15, ...
    T1-273.15,       T2-273.15,    T3-273.15, ...
    mode_vec, ...
    'VariableNames',{'Time_hr','Day','Month','Hour_of_day','Minute', ...
    'Supply_MW','Demand_MW','Net_MW', ...
    'Compress_MW','Turbine_MW', ...
    'Sell_MW','Buy_MW', ...
    'SOC_HP_pct','SOC_TES_pct', ...
    'P_HP_MPa','T_HP_degC', ...
    'T_TES1_degC','T_TES2_degC','T_TES3_degC','Mode'});

%% ── monthly table ────────────────────────────────────────────────────────
fprintf('Building monthly summary table...\n');
month_names = {'Jan','Feb','Mar','Apr','May','Jun', ...
               'Jul','Aug','Sep','Oct','Nov','Dec'};
month_days  = [31,28,31,30,31,30,31,31,30,31,30,31];
month_ends  = cumsum(month_days);
month_starts= [1, month_ends(1:end-1)+1];

rows = zeros(12, 9);
for m = 1:12
    mk = day_num >= month_starts(m) & day_num <= month_ends(m);
    if sum(mk) < 2; continue; end
    tm = t(mk);
    rows(m,1) = trapz(tm, supply_W(mk))    / 3.6e9;
    rows(m,2) = trapz(tm, demand_W(mk))    / 3.6e9;
    rows(m,3) = trapz(tm, P_chg_W(mk))     / 3.6e9;
    rows(m,4) = trapz(tm, P_dis_W(mk))     / 3.6e9;
    rows(m,5) = trapz(tm, P_sell_W_corr(mk))/ 3.6e9;
    rows(m,6) = trapz(tm, P_buy_W_corr(mk)) / 3.6e9;
    rows(m,7) = mean(SOC_hp(mk)) * 100;
    rows(m,8) = mean(mode_vec(mk) == 1) * 100;
    rows(m,9) = mean(mode_vec(mk) == 2) * 100;
end

R.monthly = table(month_names', rows(:,1), rows(:,2), rows(:,3), rows(:,4), ...
    rows(:,5), rows(:,6), rows(:,7), rows(:,8), rows(:,9), ...
    'VariableNames',{'Month','E_supply_MWh','E_demand_MWh', ...
    'E_charged_MWh','E_recovered_MWh','E_sold_MWh','E_bought_MWh', ...
    'Mean_SOC_HP_pct','Frac_charging_pct','Frac_discharge_pct'});

%% ── print summary ────────────────────────────────────────────────────────
fprintf('\n╔══════════════════════════════════════════════╗\n');
fprintf('  CAES ANNUAL RESULTS — Team50 North Brabant\n');
fprintf('  Duration: %.1f days  |  Timesteps: %d\n', t(end)/86400, N);
fprintf('╠══════════════════════════════════════════════╣\n');
fprintf('  Annual wind supply:           %12.1f  MWh\n', R.E_supply);
fprintf('  Annual village demand:        %12.1f  MWh\n', R.E_demand);
fprintf('  Energy charged (CAES):        %12.1f  MWh\n', R.E_chg);
fprintf('  Energy recovered:             %12.1f  MWh\n', R.E_dis);
fprintf('  Round-trip efficiency:        %12.1f  %%\n',  R.eta_RT);
fprintf('  Grid self-sufficiency:        %12.1f  %%\n',  R.self_suf);
fprintf('  Sold to grid:                 %12.1f  MWh\n', R.E_sold);
fprintf('  Bought from grid:             %12.1f  MWh\n', R.E_bought);
fprintf('╠══════════════════════════════════════════════╣\n');
fprintf('  LOSS BREAKDOWN\n');
fprintf('  Compressor losses:            %12.2f  MWh  (%4.1f%%)\n', ...
        R.E_loss_comp, sdiv(R.E_loss_comp,R.E_loss_total)*100);
fprintf('  TES thermal losses:           %12.2f  MWh  (%4.1f%%)\n', ...
        R.E_loss_tes,  sdiv(R.E_loss_tes, R.E_loss_total)*100);
fprintf('  Throttle exergy loss:         %12.2f  MWh  (%4.1f%%)\n', ...
        R.E_loss_thr,  sdiv(R.E_loss_thr, R.E_loss_total)*100);
fprintf('  Turbine losses:               %12.2f  MWh  (%4.1f%%)\n', ...
        R.E_loss_turb, sdiv(R.E_loss_turb,R.E_loss_total)*100);
fprintf('  Generator losses:             %12.2f  MWh  (%4.1f%%)\n', ...
        R.E_loss_gen,  sdiv(R.E_loss_gen, R.E_loss_total)*100);
fprintf('╠══════════════════════════════════════════════╣\n');
fprintf('  OPERATIONAL STATISTICS\n');
fprintf('  Time charging:                %12.1f  %%\n',  R.frac_charge);
fprintf('  Time discharging:             %12.1f  %%\n',  R.frac_discharge);
fprintf('  Time idle:                    %12.1f  %%\n',  R.frac_idle);
fprintf('  Mean HP SOC:                  %12.1f  %%\n',  R.storage_util);
fprintf('  Peak HP pressure:             %12.2f  MPa\n', R.peak_P_MPa);
fprintf('  Peak TES temp:                %12.1f  C\n',   R.peak_T_TES_C);
fprintf('  Net profit:                   %12.0f  GBP\n', R.profit);
fprintf('╚══════════════════════════════════════════════╝\n\n');

fprintf('Monthly breakdown:\n');
disp(R.monthly);

%% ── cross-check ──────────────────────────────────────────────────────────
fprintf('Cross-check:\n');
fprintf('  Demand: %.1f MWh | expected 22333 MWh | error %.2f%%\n', ...
        R.E_demand, abs(R.E_demand-22333)/22333*100);
fprintf('  Supply: %.1f MWh | expected 26280 MWh | error %.2f%%\n', ...
        R.E_supply, abs(R.E_supply-26280)/26280*100);

end

%% ── helpers ──────────────────────────────────────────────────────────────
function data = read_ts(out, fieldname, t, N, default_val)
    try
        ts   = out.(fieldname);
        ts_r = resample(ts, t);
        data = double(ts_r.Data(:));
    catch
        fprintf('  WARNING: out.%s not found — using %.4g\n', ...
                fieldname, default_val);
        data = repmat(default_val, N, 1);
    end
end