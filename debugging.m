figure
t_h = out.P_net_log.Time / 3600;
plot(t_h, out.P_net_log.Data / 1e6)
xlabel('Time [hours]'); ylabel('Net Power [MW]')
title('Net Power seen by Simulink')
grid on

figure
t_h = out.mode_log.Time / 3600;
stairs(t_h, out.mode_log.Data)
yticks([0 1 2]); yticklabels({'Idle','Charging','Discharging'})
xlabel('Time [hours]'); title('Operating Mode')
grid on

figure
t_h = out.P_chg_log.Time / 3600;
plot(t_h, out.P_chg_log.Data / 1e6)
xlabel('Time [hours]'); ylabel('MW')
title('Compressor Power Command')
grid on

figure
t_h = out.P_net_log.Time / 3600;
P_net_MW = out.P_net_log.Data / 1e6;

plot(t_h, P_net_MW)
xlabel('Time [hours]')
ylabel('P_{net} [MW]')
title('Net Power: positive should mean charging')
grid on

figure
t_h = out.mode_log.Time / 3600;

stairs(t_h, out.mode_log.Data)
yticks([0 1 2])
yticklabels({'Idle','Charging','Discharging'})
xlabel('Time [hours]')
title('Operating Mode')
grid on

%% Step 1: Check mode values

disp('Unique mode values:')
unique(out.mode_log.Data)

disp('Minimum and maximum net power [MW]:')
[min(out.P_net_log.Data)/1e6, max(out.P_net_log.Data)/1e6]