% Pulse Radar Generation Demo with Direct Conversion
% It generates a pulsed RF signal using the DUC and optimizes waveform
% memory usage using sequencing. It captures multiple frames of the RF 
% waveform directly or using the DDC (Digital Down Converter). DUC/DDC
% can be synchronized and TX to RX phase drift can be shown in either case.
% It shows all the acquisitions (acquisition # cbe selected usiong an slide
% control).
clear;
close all;
clear variables;
clear global;
clc;

% CREATE PROTEUS OBJECTS
proteus_lib = TEProteusLib();
awg_setup   = proteus_lib.CreateDefaultAwgSetup();
dig_setup   = proteus_lib.CreateDefaultDigSetup();
pulse_setup = proteus_lib.CreateDefaultPulseSetup();

% Main Settings
% *************
awg_channel         = proteus_lib.AWG_CHAN_CH01;
dig_channel         = proteus_lib.DIG_CHAN_ONE;
dac_sampling_rate   = 2.5E9;
wfmVolt             = 0.5;
carrier_frequency   = 1E9;

% Pulse_settings
% **************
% PULSE_TYPE_SQUARE
% PULSE_TYPE_TRAPEZOIDAL
% PULSE_TYPE_GAUSSIAN
% PULSE_TYPE_CHIRP_UP
% PULSE_TYPE_CHIRP_DOWN
% PULSE_TYPE_BARKER_CODE  
% PULSE_TYPE_FRANK_CODE
% PULSE_TYPE_P1_CODE
% PULSE_TYPE_P2_CODE
% PULSE_TYPE_P3_CODE
% PULSE_TYPE_P4_CODE 
pulse_type          = proteus_lib.PULSE_TYPE_CHIRP_UP;
pulse_width         = 1.0E-6;  % Pulse Width
freq_offset         = 0.0E6;
bandwidth           = 100.0E6;   % For Chirps
rise_time           = 0.1E-6;   % For Trapezoidal
pulse_rep_freq      = 10E3;      % PRI
num_of_pulses       = 1;

% % *************
% % Define IP Address for Target Proteus device descriptor
% % VISA "Socket-Based" TCP-IP Device. Socket# = 5025
% proteus_lib.ip_addr         = '127.0.0.1'; % '127.0.0.1' = Local Host, your IP address here
% proteus_lib.pxi_slot        = 0; % Set 0 to select slot from attached modules
% proteus_lib.com_ifc         = proteus_lib.COMM_IFC_LAN; %"LAN" = VISA or "DLL" = PXI
% proteus_lib.paranoia_level  = 2; % 0, 1 or 2
% 
% % Instrument setup
% [inst, idnstr, slotNumber, serial] = proteus_lib.ConnecToProteus();
% % inst handler required to use TEProteusInst.m functions directly
% 
% num_of_modules = length(idnstr);
% 
% % Report model
% for module_ptr = 1:num_of_modules
%     fprintf('Connected to: %s, slot: %d\n', idnstr(module_ptr), slotNumber(module_ptr));
% end

% AWG Settings
awg_setup.sel_module        = proteus_lib.PROTEUS_MODULE_01;
awg_setup.mode              = proteus_lib.AWG_MODE_DIRECT;
awg_setup.granularity       = 32;
awg_setup.min_segment       = 1024;
awg_setup.dac_resolution    = proteus_lib.AWG_DAC_MODE_16;
awg_setup.sampling_rate     = dac_sampling_rate;
awg_setup.channel           = awg_channel;
awg_setup.segment           = 1;
awg_setup.volt              = wfmVolt;

% Reset AWG
%inst.SendScpi('*CLS;*RST');

fprintf('RADAR DEMO STARTS\n');

% RF Pulse Parameters
pulse_setup.pulse_type          = pulse_type;
pulse_setup.edge_shape          = proteus_lib.PULSE_EDGE_GAUSSIAN;
pulse_setup.polyphase_code      = 4; %proteus_lib.PULSE_BARKER_13;
pulse_setup.pulse_width         = pulse_width;  % Pulse Width
pulse_setup.freq_offset         = freq_offset;
pulse_setup.bandwidth           = bandwidth;
pulse_setup.rise_time           = rise_time;
pulse_setup.pulse_rep_freq      = pulse_rep_freq; 


[   pulse_wfm,...
    map_wfm,...
    task_list] = proteus_lib.GetPulseWfms(  awg_setup,...
                                            pulse_setup);

pulse_wfm = pulse_wfm(1:map_wfm(1));
map_wfm = 0;

wfm_length = 1/pulse_rep_freq * awg_setup.sampling_rate;
final_wfm_length = floor(wfm_length / awg_setup.granularity) * awg_setup.granularity;

myWfm = complex(zeros(1, final_wfm_length));
myWfm(1:length(pulse_wfm)) = pulse_wfm;

awg_setup.sampling_rate = awg_setup.sampling_rate * final_wfm_length / wfm_length;

[myWfm, actual_cf] = proteus_lib.IqDirectModulation(    myWfm,...
                                                        carrier_frequency,...
                                                        awg_setup.sampling_rate);

% proteus_lib.SendWfmToProteus(   awg_setup,...
%                                 myWfm,...
%                                 true);
myWfm = proteus_lib.Quantization (myWfm, awg_setup.dac_resolution, 0);
%csvwrite("radar_demo.csv",myWfm');

% Disconnect, close VISA handle and destroy handle  
% proteus_lib.DisconnectFromProteus();

% clear inst;