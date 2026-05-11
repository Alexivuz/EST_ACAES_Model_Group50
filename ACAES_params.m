% Run before simulation
clear; clc;

%% Thermodynamic constants
R_air = 287.05; cp_air = 1005.0; cv_air = 717.95; gamma = 1.4;
T0 = 293.15; P0 = 101325;

%% HP Store
V_hp = 1000; P_hp_min = 4e6; P_hp_max = 7e6;
m_hp_init = P_hp_min*V_hp/(R_air*T0);
T_hp_init = T0; P_hp_init = P_hp_min;
UA_hp_wall = 0;  % 0 = AD case; set to 5.0 for TR case

%% TES
N_stages = 3; m_TES = 5000; cp_TES = 2000;
UA_TES = 2.0; T_TES_init = T0;
T_TES_max = 500;  % [K] max TES temperature

%% Compressors
eta_is_comp = 0.85; eta_mech_comp = 0.97; eta_motor = 0.96;
PR_vec = [1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0];
eta_is_vec = [0.60 0.72 0.80 0.85 0.85 0.83 0.78 0.70 0.60];
leakage_frac = 0.005; dP_HEX_frac = 0.005; dP_pipe_frac = 0.002;

%% Heat exchangers
epsilon_HEX = 0.92; UA_HEX_amb = 1.0; m_dot_des_HEX = 5.0;

%% Turbines
eta_is_turb = 0.88; eta_mech_turb = 0.98; eta_gen = 0.97;
PR_turb_vec = [1.5 2.0 2.5 3.0 3.5 4.0 5.0 6.0 7.0];
eta_t_vec   = [0.72 0.80 0.86 0.88 0.87 0.84 0.78 0.72 0.65];

%% Throttle
Kv_throttle = 0.01; tau_valve = 0.5; P_throttle = 4e6;

%% Mass flows
m_dot_chg_nom = 5.0; m_dot_dis_nom = 5.0;

%% Save to workspace
save('ACAES_params.mat');
disp('Parameters loaded.');