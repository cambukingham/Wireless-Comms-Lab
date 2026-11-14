% PROTEUS FREQUENCY RESPONSE (MAGNITUDE, PHASE) SCRIPT
%=====================================================

clear;
close all;
clear variables;
clear global;
clc;

% CREATE PROTEUS OBJECTS
proteus_lib     = TEProteusLib();
awg_setup       = proteus_lib .CreateDefaultAwgSetup();
scope_setup     = proteus_lib.CreateDefaultScopeSetup();
cal_setup       = proteus_lib.CreateDefaultCalSetup();

% Test Parameters
cal_setup.awg_sample_rate   = 9E9;
cal_setup.awg_interpol      = proteus_lib.AWG_INTERPOL_X1;
cal_setup.start_freq        = [10E6, 4400E6];
cal_setup.stop_freq         = 4.45E9;
cal_setup.step_freq         = [100E6, 100E6];
cal_setup.wfmVolt           = [0.4 , 0.5];

cal_setup.sel_module        = proteus_lib.PROTEUS_MODULE_02;
cal_setup.awg_test_channel  = proteus_lib.AWG_CHAN_CH01;
cal_setup.awg_sync_channel  = proteus_lib.AWG_CHAN_CH03;
cal_setup.sync_pulse_width  = 1E-6;
cal_setup.avg_freq_range    = [0.0 , 1E9, 2E9, 3E9];
cal_setup.num_of_avg        = [1, 1, 1, 1]; % 1,1,2,4
cal_setup.WfmOffset         = 0.0;
cal_setup.freq_res          = 100E3;
cal_setup.verbose           = true;

cal_setup.scope_type        = proteus_lib.SCOPE_MODEL_KEYSIGHT;
cal_setup.scope_test        = cal_setup.awg_test_channel;
cal_setup.scope_sync        = cal_setup.awg_sync_channel; % 0 = ext trigger
cal_setup.scope_sample_rate = 20E9;
cal_setup.scope_range   = [0.10 * 8, 0.10 * 8]; % Voltage range for scope channels
cal_setup.scope_offset  = [0.0, 0.0]; % Offset Range for scope channels
cal_setup.scope_trg_lvl     = 0.10; % Trigger level

fprintf(1, 'INITIALIZING SETTINGS\n');

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
proteus_lib.ip_addr         = '127.0.0.1'; % '127.0.0.1' = Local Host, your IP address here
proteus_lib.pxi_slot        = 3; % Set 0 to select slot from attached modules
proteus_lib.com_ifc         = proteus_lib.COMM_IFC_LAN; %"LAN" = VISA or "DLL" = PXI
proteus_lib.paranoia_level  = 2; % 0, 1 or 2

% Instrument setup
[inst, idnstr, slotNumber, serial] = proteus_lib.ConnecToProteus();
% inst handler required to use TEProteusInst.m functions directly

num_of_modules = length(idnstr);

% Report model
for module_ptr = 1:num_of_modules
    fprintf('Connected to: %s, slot: %d\n', idnstr(module_ptr), slotNumber(module_ptr));
end

% Check valid range for selected module
if cal_setup.sel_module < 1 && proteus_lib.com_ifc == proteus_lib.COMM_IFC_LAN
    cal_setup.sel_module  = 1;
elseif cal_setup.sel_module > num_of_modules && proteus_lib.com_ifc == proteus_lib.COMM_IFC_LAN
    cal_setup.sel_module = num_of_modules;
elseif proteus_lib.com_ifc == proteus_lib.COMM_IFC_DLL
    cal_setup.sel_module = 1;
end

% Selected module reported
fprintf('\nModule: %s, slot: %d Selected\n',...
        idnstr(cal_setup.sel_module),...
        slotNumber(cal_setup.sel_module));

% Scope session
scope_descriptor = 'TCPIP0::192.168.10.46::inst0::INSTR';
[scope_session, scope_idn] = proteus_lib.ConnectToScope(scope_descriptor);
scope_setup.handle = scope_session;
fprintf('Connected to %s\n', scope_idn);

% Get options using the standard IEEE-488.2 Command
% Get options using the standard IEEE-488.2 Command
optstr = proteus_lib.GetProteusOptions();

% Set AWG settings
awg_setup.sel_module            = cal_setup.sel_module;
awg_setup.sampling_rate         = cal_setup.awg_sample_rate;
awg_setup.interpol              = cal_setup.awg_interpol;
awg_setup.dac_resolution        = 16;

if (awg_setup.sampling_rate / awg_setup.interpol) > 2.5E9
    awg_setup.dac_resolution    = 8;
    awg_setup.interpol          = 1;
end

if (awg_setup.sampling_rate / awg_setup.interpol) < 250E6
    awg_setup.interpol          = 1;
end

% Select Module when Connecting to TaborInstrumentation service (LAN)
if proteus_lib.com_ifc == proteus_lib.COMM_IFC_LAN
    proteus_lib.SelectModule(awg_setup.sel_module);
end

% Reset AWG
inst.SendScpi('*CLS;*RST');

% Get granularity
granul = proteus_lib.GetGranularity(idnstr(1), optstr, awg_setup.dac_resolution);

fprintf('\nGranularity = %d samples\n', granul);

awg_setup.granularity = granul;

[   x_freq,...
    ampl_resp,...
    phase_resp] = proteus_lib.CalAwgChannel(    awg_setup,...
                                                scope_setup,...
                                                cal_setup);

[   ampl_resp,...
    phase_resp,...
    wfm_delay] = proteus_lib.ProcessFreqResp(   x_freq,...
                                                ampl_resp,...
                                                phase_resp);

% REMOVE COMMENTS TO SAVE CALIBRATION DATA
% ****************************************

% proteus_lib.SaveCalibrationFile(    "cal_file_9GSs_ch1.csv",...
%                                     cal_setup.awg_sample_rate / cal_setup.awg_interpol,...
%                                     wfm_delay,...
%                                     proteus_lib.CAL_TYPE_AMPL_PHASE,...
%                                     proteus_lib.CORR_FREQ_UNIT_HZ,...
%                                     proteus_lib.CORR_AMPL_UNIT_DB,...
%                                     proteus_lib.CORR_PHASE_UNIT_DEGREE,...
%                                     x_freq,...
%                                     ampl_resp,...
%                                     phase_resp);
% 
% save("freq_response_complete",'x_freq', 'ampl_resp', 'phase_resp'); 

% ****************************************

% Disconnect, close VISA handle and destroy handle  
proteus_lib.DisconnectFromProteus();
proteus_lib.DisconnectFromScope(scope_session);

tiledlayout(1,2);

ax1 = nexttile;
plot(ax1, x_freq, ampl_resp);
title(ax1,sprintf('Frequency Response(Magnitude)'));

zeroth_hold_atten = pi * x_freq / awg_setup.sampling_rate;
zeroth_hold_atten = sin(zeroth_hold_atten) ./ zeroth_hold_atten;
zeroth_hold_atten = 20.0 * log10(zeroth_hold_atten);
hold;
plot(ax1, x_freq, ampl_resp - zeroth_hold_atten);

xlabel('Hz') 
ylabel('dB') 

grid(ax1,'on');

ylim([-40, 10]);
xlim([x_freq(1), x_freq(end)]);
%save("freq_response_complete",'x_freq', 'ampl_resp', 'phas_resp2'); 

ax2 = nexttile;
plot(ax2, x_freq, phase_resp);
hold;
plot(ax2, x_freq, smooth(phase_resp, 5));
title(ax2,sprintf('Frequency Response(Phase)'));

xlabel('Hz') 
ylabel('degrees') 

grid(ax2,'on');

clear inst;
%close all;