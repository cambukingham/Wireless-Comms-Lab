% EXAMPLE DEMO FOR A SYNTHESIZER WITH PHASE MEMORY
clear;
close all;
clear variables;
clear global;
clc;

% Control Variables
freq_1      = 1.234E9;
freq_2      = 2.123E9;
time_freq_1 = 100E-6;
time_freq_2 = 100E-6;
trans_time  = 10E-6;

% Load Library
proteus_lib = TEProteusLib();
% % Create AWG Setup Variable
awg_setup   = proteus_lib.CreateDefaultAwgSetup();
% Create Pulse Setup Variable
pulse_setup = proteus_lib.CreateDefaultPulseSetup();

% AWG settings
dac_sample_rate = 5E9;
interpolation   = proteus_lib.AWG_INTERPOL_X8;
granularity     = 8;

% Waveform Calculation
% AWG Settings
awg_setup.sampling_rate = dac_sample_rate;
awg_setup.channel       = proteus_lib.AWG_CHAN_CH01;
awg_setup.mode          = proteus_lib.AWG_MODE_DUC;
awg_setup.iq_mode       = proteus_lib.AWG_IQ_MODE_TWO;
awg_setup.interpol      = interpolation;
awg_setup.segment       = 1;
awg_setup.volt          = 0.55;
awg_setup.cfr1          = freq_1;
awg_setup.cfr2          = freq_2;

% Basic Pulse Parameters
bb_sample_rate              = awg_setup.sampling_rate / awg_setup.interpol;
pulse_setup.pulse_type      = proteus_lib.PULSE_TYPE_TRAPEZOIDAL;
pulse_setup.edge_shape      = proteus_lib.PULSE_EDGE_GAUSSIAN;

pulse_setup.pulse_width     = time_freq_1;
pulse_setup.rise_time       = trans_time;
pulse_setup.sampling_rate   = bb_sample_rate;
pulse_setup.initial_phase   = 0.0;

pulse_setup.granul          = 1;
pulse_setup.quality         = 5;

% Calculate Pulse Waveform
pulse_wfm = proteus_lib.GetIqPulse(pulse_setup);
% Get full waveforms
wfm_length = (time_freq_1 + time_freq_2) * bb_sample_rate;
wfm_length = round(wfm_length / granularity) * granularity;
freq_1_wfm = zeros(1, wfm_length);
freq_1_wfm(1:length(pulse_wfm)) = pulse_wfm;
freq_2_wfm = 1.0 - freq_1_wfm;

% plot(freq_1_wfm);
% hold;
% plot(freq_2_wfm);

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
proteus_lib.ip_addr         = '192.168.10.59'; % '127.0.0.1' = Local Host, your IP address here
proteus_lib.pxi_slot        = 3; % Set 0 to select slot from attached modules
proteus_lib.com_ifc         = proteus_lib.COMM_IFC_LAN; %"LAN" = VISA or "DLL" = PXI
proteus_lib.paranoia_level  = 2; % 0, 1 or 2

% Instrument setup
[inst, idnstr, slotNumber, serial] = proteus_lib.ConnecToProteus();
% inst handler required to use TEProteusInst.m functions directly

% Report model
fprintf('Connected to: %s, slot: %d\n', idnstr(1), slotNumber(1));

% Reset AWG
inst.SendScpi('*CLS;*RST');

% Download Waveforms
proteus_lib.SendIqmTwoWfm(  awg_setup,...
                            freq_1_wfm,...
                            freq_2_wfm);

% Reference Signal
awg_setup.channel   = proteus_lib.AWG_CHAN_CH02;
awg_setup.segment   = 2;
freq_1_wfm          = zeros(1, wfm_length);
freq_1_wfm          = freq_1_wfm + 1.0;
freq_2_wfm          = zeros(1, wfm_length);

% Download Waveforms
proteus_lib.SendIqmTwoWfm(  awg_setup,...
                            freq_1_wfm,...
                            freq_2_wfm);

% Disconnect, close VISA handle and destroy handle  
proteus_lib.DisconnectFromProteus();

clear inst;
close all;