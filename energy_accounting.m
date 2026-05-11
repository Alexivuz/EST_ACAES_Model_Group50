% exergy_accounting.m — run after simulation
load('ACAES_simout.mat');

% Charging exergy
W_chg = cumtrapz(t, W_dot_comp_total);  % [J]

% Exergy components
Ex_HP_final   = simout.HP_Ex(end);
Ex_TES_final  = simout.TES_U_total(end);

% Losses during charging
Ex_dest_HEX_mix  = cumtrapz(t, simout.Ex_dest_HEX_total);
Ex_dest_HP_mix   = cumtrapz(t, simout.Ex_dest_HP_mix);

% Discharging
W_dis = cumtrapz(t, simout.P_elec);  % [J]
Ex_dest_throttle = cumtrapz(t_dis, simout.Ex_dest_thr);
Ex_exh           = cumtrapz(t_dis, simout.Ex_dot_exh);

% Round-trip efficiency
eta_RT = W_dis(end) / W_chg(end);
fprintf('Round-trip efficiency: %.1f%%\n', eta_RT*100);

% Exergy waterfall
labels = {'W_chg','HP Store','TES Store','HEX Mix Loss','HP Mix Loss',...
    'Throttle Loss','Exhaust Loss','W_dis','Unaccounted'};