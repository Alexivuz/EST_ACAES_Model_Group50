%% CAES_init.m
% Run this script BEFORE starting Simulink simulation
% It loads supply/demand data and sets all system parameters
clear; clc; close all;

%% ===== STEP 1: LOAD CSV DATA =====
% Reads Team50_supply.csv and Team50_demand.csv
% Format: header lines starting with #, then  time[s], power[MW]

supplyFile = 'data/Team50_supply.csv';
demandFile = 'data/Team50_demand.csv';

% --- Read supply ---
raw_supply = readmatrix(supplyFile, 'CommentStyle', '#');
t_supply_s     = raw_supply(:, 1);   % [s]
P_supply_MW    = raw_supply(:, 2);   % [MW]

% --- Read demand ---
raw_demand = readmatrix(demandFile, 'CommentStyle', '#');
t_demand_s     = raw_demand(:, 1);   % [s]
P_demand_MW    = raw_demand(:, 2);   % [MW]

% --- Sanity checks ---
assert(length(t_supply_s) == length(t_demand_s), ...
    'ERROR: supply and demand files have different number of rows.');
assert(all(t_supply_s == t_demand_s), ...
    'ERROR: supply and demand time vectors do not match.');

% --- Prepare variables used by the rest of CAES_init ---
t_vec        = t_supply_s;                      % [s] time vector
dt           = t_vec(2) - t_vec(1);             % [s] timestep (900 s = 15 min)
dt_hours     = dt / 3600;                       % [hours]
N_steps      = length(t_vec);
t_sim_end    = t_vec(end) + dt;                 % [s] total simulation duration

P_supply_W   = P_supply_MW * 1e6;              % convert MW → W
P_demand_W   = P_demand_MW * 1e6;              % convert MW → W
P_net_W      = P_supply_W - P_demand_W;        % [W] positive = surplus (charge)

% --- Simulink timeseries objects ---
Supply_TS = timeseries(P_supply_W, t_vec, 'Name', 'Supply_Power');
Demand_TS = timeseries(P_demand_W, t_vec, 'Name', 'Demand_Power');

fprintf('CSV data loaded successfully.\n');
fprintf('  Timestep:    %.0f s (%.2f hours)\n', dt, dt_hours);
fprintf('  Data points: %d\n', N_steps);
fprintf('  Duration:    %.1f days\n', t_sim_end / 86400);
fprintf('  Supply range: %.3f – %.3f MW\n', min(P_supply_MW), max(P_supply_MW));
fprintf('  Demand range: %.3f – %.3f MW\n', min(P_demand_MW), max(P_demand_MW));

%% ===== STEP 4: PHYSICAL PARAMETERS =====
% (Paste the sizing parameters from Section 2.2 here)
% Thermodynamic constants
R_air       = 287.05;     % [J/kg·K]
cp_air      = 1005.0;     % [J/kg·K]
cv_air      = 717.95;     % [J/kg·K]
gamma       = 1.4;        % [-]
T0          = 293.15;     % [K]  ambient temperature
P0          = 101325;     % [Pa] ambient pressure


V_hp        = 500;

P_hp_min    = 4.0e6;    % [Pa]  40 bar — compressor start pressure
P_hp_max    = 8.0e6;    % [Pa]  80 bar — achievable with 3-stage compression
P_throttle  = 3.8e6;    % [Pa]  38 bar — BELOW P_hp_min so gate never blocks
%        the throttle valve itself regulates expansion

P_hp_init   = P_hp_min; % [Pa]  start at minimum — must match P_hp_min
m_hp_init   = P_hp_min * V_hp / (R_air * T0);   % recalculate initial mass

% Lower the SOC threshold so discharge fires earlier
SOC_hp_charge_start = 0.02;    % was 0.05 — discharge allowed above 2% SOC
% at P_hp_min=4 MPa, 2% SOC = P_hp > 4.06 MPa


% HP store


% Initial conditions
T_hp_init   = T0;


% TES
N_stages    = 3;
m_TES       = 50000;
cp_TES      = 1900;
UA_TES_wall = 1.5;        % [W/K] heat loss coefficient
T_TES_init  = T0;
T_TES_max = 573.15;   % [K] maximum TES temperature, 300 °C

% Compressor efficiency lookup table
PR_vec         = [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0];
eta_comp_vec   = [0.55, 0.68, 0.78, 0.82, 0.82, 0.80, 0.74, 0.66, 0.55];
eta_turb_vec   = [0.65, 0.75, 0.82, 0.85, 0.85, 0.83, 0.79, 0.73, 0.65];

% Component efficiencies
eta_mech_comp  = 0.97;
eta_motor      = 0.95;
eta_mech_turb  = 0.98;
eta_gen        = 0.96;
epsilon_HEX    = 0.90;
dP_HEX_frac    = 0.005;
leakage_frac   = 0.003;

% Grid economics
grid_sell_price = 0.10;   % [£/kWh]
grid_buy_price  = 0.25;   % [£/kWh]

% Controller thresholds
SOC_hp_charge_stop     = 0.88;
SOC_TES_discharge_min  = 0.02;
P_net_charge_thresh    = 1000000;   % [W] minimum surplus to charge
P_net_discharge_thresh = 50000;   % [W] minimum deficit to discharge

% Valve dynamics
tau_valve   = 30;   % [s] valve response time (30s = slow, appropriate for 1hr timestep)
Kv_throttle = 0.005;

% Rated power for compressor and turbine [W]
P_comp_rated_W = 1e6;   % 5 MW compressor rated power
P_turb_rated_W = 1e6;   % 5 MW turbine rated power

fprintf('\n=== PARAMETERS LOADED ===\n');
fprintf('HP store capacity: %.1f m³ at %.0f-%.0f bar\n', V_hp, P_hp_min/1e5, P_hp_max/1e5);
fprintf('Initial air mass:  %.1f kg\n', m_hp_init);
fprintf('TES capacity:      %.1f kWh\n', N_stages*m_TES*cp_TES*(T_TES_init+190-T0)/3.6e6);
fprintf('\nRun CAES_main.slx now.\n');