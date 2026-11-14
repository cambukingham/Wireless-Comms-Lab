%% 
clear;
close all;
clear variables;
clear global;
clc;

% CREATE PROTEUS OBJECTS
proteus_lib     = TEProteusLib();
scope_setup     = proteus_lib.CreateDefaultScopeSetup();

 % Scope session
scope_descriptor = 'TCPIP0::192.168.1.170::inst0::INSTR';
[scope_session, scope_idn, scope_type] = proteus_lib.ConnectToScope(scope_descriptor);
fprintf('Connected to %s\n', scope_idn);

% Set scope settings
scope_setup.scope_model = scope_type;
scope_setup.chan_scope  = [1];
scope_setup.volt_pp     = [0.5];
scope_setup.offset      = [0.0];
scope_setup.time_window = 50E-6;
scope_setup.sample_rate = 5E9;
scope_setup.trg_channel = 1;
scope_setup.trig_lvl    = 0.0;
scope_setup.trig_pos    = 100.0;
proteus_lib.SetScope(   scope_session,...
                        scope_setup);

waveform = proteus_lib.GetScopeWfm( scope_session,...
                                        scope_setup,...
                                        true);

plot(waveform.YData);


proteus_lib.DisconnectFromScope(scope_session);