% TEST OSCILLOSCOPE

clear;
close all;
clear variables;
clear global;
clc;

% CREATE PROTEUS OBJECTS
proteus_lib = TEProteusLib();
scope_setup = proteus_lib.CreateDefaultScopeSetup();

scope_setup.scope_model = proteus_lib.SCOPE_MODEL_KEYSIGHT;
scope_setup.chan_scope  = [1, 3];
scope_setup.volt_pp     = 8.0;
scope_setup.time_window = 10E-6;
scope_setup.trig_pos    = 100.0;

connStr = 'TCPIP0::192.168.10.46::inst0::INSTR';
[scope_session, idn_str] = proteus_lib.ConnectToScope(  connStr);
fprintf('Connected to %s\n', idn_str);

proteus_lib.SetInfiniiumScope(  scope_session,...
                                scope_setup);
scope_setup.chan_scope = 1;

wfm = proteus_lib.GetScopeWfm(  scope_session,...
                                    scope_setup,...
                                    true);

proteus_lib.DisconnectFromScope(scope_session);

x_data = 0:(wfm.Points - 1);
x_data = x_data * wfm.XIncrement;
x_data = x_data + wfm.XOrigin;

plot(x_data, wfm.YData - mean(wfm.YData));
xlim([x_data(1) x_data(end)]);
grid on;