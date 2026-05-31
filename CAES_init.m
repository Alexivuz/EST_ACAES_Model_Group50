%% CAES_init.m
% =========================================================================
% ACAES (Adiabatic Compressed Air Energy Storage) — Initialisation Script
% =========================================================================
% Run this script BEFORE starting the Simulink simulation (ACAES.slx).
% It loads the supply/demand CSV data and sets all physical, control,
% and economic parameters for the ACAES system.
%
% System: 12 wind turbines supplying a village in North Brabant
% Storage: 3-stage adiabatic CAES with TES, HP cavern, throttle valve
%
% Reference: "Adiabatic Compressed Air Energy Storage: A Complete Physical
%            and Engineering Analysis" — theoretical ceiling ~93.6% RTE
% =========================================================================
clear; clc; close all;

%% ===== STEP 1: LOAD CSV DATA ============================================
% Format: comment lines starting with #, then  time[s], power[MW]

supplyFile = 'data/Team50_supply.csv';
demandFile = 'data/Team50_demand.csv';

% --- Read supply (wind farm output) ---
raw_supply = readmatrix(supplyFile, 'CommentStyle', '#');
t_supply_s     = raw_supply(:, 1);   % [s]
P_supply_MW    = raw_supply(:, 2);   % [MW]

% --- Read demand (village consumption) ---
raw_demand = readmatrix(demandFile, 'CommentStyle', '#');
t_demand_s     = raw_demand(:, 1);   % [s]
P_demand_MW    = raw_demand(:, 2);   % [MW]

% --- Sanity checks ---
assert(length(t_supply_s) == length(t_demand_s), ...
    'ERROR: supply and demand files have different number of rows.');
assert(all(t_supply_s == t_demand_s), ...
    'ERROR: supply and demand time vectors do not match.');

% --- Derived time quantities ---
t_vec        = t_supply_s;                      % [s] time vector
dt           = t_vec(2) - t_vec(1);             % [s] timestep (900 s = 15 min)
dt_hours     = dt / 3600;                       % [hours]
N_steps      = length(t_vec);
t_sim_end    = t_vec(end) + dt;                 % [s] total simulation duration

% --- Convert to Watts ---
P_supply_W   = P_supply_MW * 1e6;              % [W]
P_demand_W   = P_demand_MW * 1e6;              % [W]
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
fprintf('  Mean surplus: %.3f MW\n', mean(P_supply_MW - P_demand_MW));

%% ===== STEP 2: THERMODYNAMIC CONSTANTS ==================================
R_air       = 287.05;     % [J/(kg·K)]  specific gas constant for dry air
cp_air      = 1005.0;     % [J/(kg·K)]  specific heat at constant pressure
cv_air      = 717.95;     % [J/(kg·K)]  specific heat at constant volume
gamma       = 1.4;        % [-]         heat capacity ratio (cp/cv)
T0          = 293.15;     % [K]         ambient temperature (20 °C)
P0          = 101325;     % [Pa]        ambient pressure (1 atm)

%% ===== STEP 3: HIGH-PRESSURE (HP) AIR STORE =============================
% Isochoric (constant volume) underground cavern or steel pressure vessel.
% Air is stored at high pressure; energy is stored as pressure + thermal.
%
% Sizing rationale:
%   Mean surplus power ~ 0.45 MW, peak ~ 60 MW
%   At 40-70 bar in 500 m³:  mass range 23,789 – 41,632 kg
%   Pressure energy capacity ~ 20 MWh  (fillable in ~44h at mean surplus)


V_hp           = 5000;    % m³   — was 500, gives ~200 MWh capacity


P_hp_min    = 4.0e6;      % [Pa]   40 bar — minimum operating pressure
P_hp_max    = 7.0e6;      % [Pa]   70 bar — maximum; realistic for 3-stage
                          %         Per-stage ratio: (70/1)^(1/3) = 4.12
                          %         Within compressor efficiency sweet spot
P_throttle  = 4.0e6;      % [Pa]   40 bar — throttle outlet pressure
                          %         Matches P_hp_min for maximum energy extraction
                          %         Maintains constant turbine inlet conditions

% Initial conditions — start at minimum pressure (empty store)
P_hp_init   = P_hp_min;                          % [Pa]
T_hp_init   = T0;                                % [K]
m_hp_init   = P_hp_min * V_hp / (R_air * T0);   % [kg] from ideal gas law

fprintf('\nHP Store: %.0f m³, %.0f–%.0f bar\n', V_hp, P_hp_min/1e5, P_hp_max/1e5);
fprintf('  Initial air mass: %.1f kg\n', m_hp_init);
fprintf('  Max air mass:     %.1f kg\n', P_hp_max * V_hp / (R_air * T0));

%% ===== STEP 4: THERMAL ENERGY STORE (TES) ===============================
% Stores compression heat in a thermal fluid (e.g. Therminol, molten salt).
% 3 stages — one per compressor stage — each with its own TES tank.
%
% Sizing rationale:
%   With 3-stage compression to 70 bar, compressor outlet T ~ 450-520 K
%   TES capacity per stage: m_TES * cp_TES * (T_max - T0)
%     = 5000 * 1900 * (573.15 - 293.15) = 2.66e9 J ≈ 739 kWh per stage
%   Total TES capacity: 3 × 739 = 2,217 kWh ≈ 2.2 MWh
%   This is well-matched to the HP store's ~20 MWh pressure capacity.

N_stages    = 3;           % [-]    number of compression/expansion stages
m_TES       = 50000;        % [kg]   thermal fluid mass per stage (5 tonnes)
cp_TES      = 1900;        % [J/(kg·K)]  specific heat of thermal fluid
                           %         (typical for Therminol VP-1 or similar)
UA_TES_wall = 1.5;         % [W/K]  heat loss coefficient to ambient
                           %         Models slow thermal leakage during idle
T_TES_init  = T0;          % [K]    initial TES temperature (= ambient)
T_TES_max   = 573.15;      % [K]    maximum TES temperature (300 °C)

TES_cap_kWh = N_stages * m_TES * cp_TES * (T_TES_max - T0) / 3.6e6;
fprintf('\nTES: %d stages × %.0f kg @ cp=%.0f J/(kg·K)\n', N_stages, m_TES, cp_TES);
fprintf('  Max TES temp:  %.0f °C\n', T_TES_max - 273.15);
fprintf('  Total capacity: %.1f kWh\n', TES_cap_kWh);

%% ===== STEP 5: COMPRESSOR EFFICIENCY ====================================
% Isentropic efficiency varies with pressure ratio (off-design degradation).
% These curves are fitted to experimental data from multi-stage industrial
% compressors operating adiabatically (no intercooling).
%
% The peak efficiency (~0.82-0.85) occurs at PR ≈ 2.5-3.0.
% Efficiency drops at both low PR (throttling losses) and high PR
% (transonic flow, increased clearance losses, adverse pressure gradients).
%% Isentropic efficiency curves — optimised adiabatic stages
PR_vec       = [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0];
eta_comp_vec = [0.62, 0.73, 0.82, 0.87, 0.87, 0.85, 0.81, 0.74, 0.65];
eta_turb_vec = [0.70, 0.79, 0.85, 0.90, 0.90, 0.89, 0.86, 0.80, 0.73];
%% ===== STEP 6: COMPONENT EFFICIENCIES ===================================
% Mechanical and electrical conversion efficiencies for the drivetrain.

%% Component efficiencies — best realistic values
eta_mech_comp  = 0.99;    % was 0.97  (high-grade magnetic bearings)
eta_motor      = 0.98;    % was 0.96  (premium IE4-class motor)
eta_mech_turb  = 0.99;    % was 0.98
eta_gen        = 0.99;    % was 0.97  (permanent magnet generator)
epsilon_HEX    = 0.96;    % was 0.92  (purpose-built counterflow HEX)


% [-]  HEX effectiveness (counterflow, balanced)
                           %      ε=1 is theoretical ideal; 0.92 is realistic
dP_HEX_frac   = 0.005;    % [-]  fractional pressure drop across each HEX

% Parasitic losses
leakage_frac   = 0.003;    % [-]  air leakage rate from HP store (0.3%/cycle)

%% ===== STEP 7: GRID ECONOMICS ===========================================
% Sell/buy asymmetry provides the economic incentive for storage:
% buy expensive grid power during deficit, sell cheap surplus wind.

grid_sell_price = 0.08;    % [£/kWh]  wholesale electricity sell price
grid_buy_price  = 0.22;    % [£/kWh]  retail electricity buy price
                           %           Spread of £0.14/kWh incentivises storage

%% ===== STEP 8: CONTROLLER THRESHOLDS ====================================
% The controller decides operating mode: CHARGE (1), DISCHARGE (2), IDLE (0)
%
% CHARGE when:   P_net > P_net_charge_thresh  AND  SOC_hp < SOC_hp_charge_stop
% DISCHARGE when: P_net < -P_net_discharge_thresh  AND  SOC_hp > SOC_hp_charge_start
%                 AND  SOC_TES > SOC_TES_discharge_min
% IDLE otherwise

SOC_hp_charge_start    = 0.05;     % [-]  minimum HP SOC to allow discharge
                                   %      prevents over-depletion of store
SOC_hp_charge_stop     = 0.95;     % [-]  maximum HP SOC to allow charging
                                   %      prevents over-pressurisation
SOC_TES_discharge_min  = 0.02;     % [-]  minimum TES SOC to allow discharge
                                   %      ensures sufficient reheat temperature

% Power thresholds — minimum surplus/deficit to trigger mode change
% Mean surplus is ~450 kW; we want to capture most of it.
P_net_charge_thresh    = 0.5e6;   % [W]  3.5 MW — only charge on genuine surplus
P_net_discharge_thresh = 100e3;   % [W]  100 kW — discharge on any meaningful deficit
%% ===== STEP 9: VALVE AND FLOW DYNAMICS ===================================
% Throttle valve regulates HP store output to maintain constant pressure
% at turbine inlet (P_throttle). This is physically necessary because
% the HP store pressure varies continuously during discharge.

tau_valve   = 30;          % [s]    valve response time constant
                           %        30s is appropriate for 900s timestep
Kv_throttle = 0.01;        % [m³/s/Pa^0.5]  throttle valve flow coefficient

%% ===== STEP 10: RATED POWER AND MASS FLOWS ==============================
% Compressor and turbine rated power must match the wind farm scale.
%   Wind farm: 12 turbines, peak ~68 MW, mean ~3 MW
%   Village demand: mean ~2.55 MW, peak ~10.8 MW
%   Mean surplus: ~0.45 MW, peak surplus: ~57 MW
%
% Rated at 5 MW — can capture most surplus events and serve most deficits.
% The mass flow rates determine how fast the HP store fills/empties.
P_comp_rated_W = 10e6;    % 10 MW
P_turb_rated_W = 10e6;
m_dot_chg_nom  = 10.0;    % kg/s
m_dot_dis_nom  = 5.0;    % [W]   5 MW turbine rated power

% Nominal mass flow rates [kg/s]
% At 5 MW and 3-stage compression to 70 bar:
%   W_dot = m_dot * cp * T0 * N * [(PR)^((γ-1)/(Nγ)) - 1] / η
%   5e6 = m_dot * 1005 * 293 * 3 * [(4.12)^(0.133) - 1] / 0.82
%   → m_dot ≈ 5 kg/s     % [kg/s]  nominal discharging mass flow

%% ===== SUMMARY ===========================================================
fprintf('\n=== PARAMETERS LOADED ===\n');
fprintf('HP store:   %.0f m³ at %.0f–%.0f bar (throttle: %.0f bar)\n', ...
    V_hp, P_hp_min/1e5, P_hp_max/1e5, P_throttle/1e5);
fprintf('TES:        %d × %.0f kg (%.1f kWh total)\n', N_stages, m_TES, TES_cap_kWh);
fprintf('Rated power: %.1f MW comp / %.1f MW turb\n', P_comp_rated_W/1e6, P_turb_rated_W/1e6);
fprintf('Thresholds: charge > %.0f kW surplus, discharge > %.0f kW deficit\n', ...
    P_net_charge_thresh/1e3, P_net_discharge_thresh/1e3);
fprintf('Economics:   sell £%.2f/kWh, buy £%.2f/kWh\n', grid_sell_price, grid_buy_price);
fprintf('\nRun ACAES.slx now.\n');