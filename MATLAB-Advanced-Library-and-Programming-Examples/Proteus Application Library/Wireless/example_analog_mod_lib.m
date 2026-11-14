%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ANALOG MODULATION: SSB EXAMPLE %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear;
close all;
clear variables;
clear global;
clc;

% CREATE PROTEUS OBJECTS
proteus_lib = TEProteusLib();
awg_setup   = proteus_lib.CreateDefaultAwgSetup();
mod_setup   = proteus_lib.CreateDefaultModSetup();

% Signal Parameters
carrier_frequency   = 1.0E9;
am_index            = 50.0;
fm_deviation        = 1E5;
mod_frequency       = 1E4;
num_of_cycles       = 100;
oversampling        = 10;

module              = proteus_lib.PROTEUS_MODULE_01;
channel             = proteus_lib.AWG_CHAN_CH01;
segment             = 1;
dac_sr              = 9E9;
dac_interpol        = proteus_lib.AWG_INTERPOL_X8; % Remove this
wfmVolt             = 1.3;
wfmOff              = 0.0;

% Modulation Setup
% MOD_ANALOG_AM
% MOD_ANALOG_FM
% MOD_ANALOG_PM
% MOD_ANALOG_SSB
mod_setup.mod_type          = proteus_lib.MOD_ANALOG_SSB;
if mod_setup.mod_type == proteus_lib.MOD_ANALOG_AM
    mod_setup.modul_index       = am_index;
elseif mod_setup.mod_type == proteus_lib.MOD_ANALOG_FM
    mod_setup.modul_index       = fm_deviation;
end
mod_setup.modul_freq        = mod_frequency;
mod_setup.num_of_mod_cycles = num_of_cycles;

% AWG Parameters

% AWG Settings
awg_setup.sel_module        = module;
awg_setup.mode              = proteus_lib.AWG_MODE_DUC;
awg_setup.iq_mode           = proteus_lib.AWG_IQ_MODE_ONE;
awg_setup.interpol          = dac_interpol;
awg_setup.sampling_rate     = dac_sr;
awg_setup.channel           = channel;
awg_setup.segment           = 1;
awg_setup.volt              = wfmVolt;
awg_setup.six_db1           = 1;
awg_setup.six_db2           = 1;
awg_setup.cfr1              = carrier_frequency;

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
proteus_lib.ip_addr         = '192.168.10.59'; % '127.0.0.1' = Local Host, your IP address here
proteus_lib.pxi_slot        = 5; % Set 0 to select slot from attached modules
proteus_lib.com_ifc         = proteus_lib.COMM_IFC_DLL; %"LAN" = VISA or "DLL" = PXI
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
if awg_setup.sel_module < 1 && proteus_lib.com_ifc == proteus_lib.COMM_IFC_LAN
    awg_setup.sel_module = 1;
elseif awg_setup.sel_module > num_of_modules && proteus_lib.com_ifc == proteus_lib.COMM_IFC_LAN
    awg_setup.sel_module = num_of_modules;
elseif proteus_lib.com_ifc == proteus_lib.COMM_IFC_DLL
    awg_setup.sel_module = 1;
end
% Select Module when Connecting to TaborInstrumentation service (LAN)
if proteus_lib.com_ifc == proteus_lib.COMM_IFC_LAN
    proteus_lib.SelectModule(awg_setup.sel_module);
end

% Selected module reported
fprintf('\nModule: %s, slot: %d Selected\n',...
        idnstr(awg_setup.sel_module),...
        slotNumber(awg_setup.sel_module));


% Get options using the standard IEEE-488.2 Command
optstr = proteus_lib.GetProteusOptions();

% Get granularity
granul = proteus_lib.GetGranularity(idnstr(awg_setup.sel_module), optstr, awg_setup.dac_resolution);
actual_granularity          = granul / 2;
fprintf('\nGranularity = %d samples\n', actual_granularity);

% Get min and max sampling rates
[minsr, maxsr] = proteus_lib.GetAwgSamplingRateRange();
% Check if sample rate is in the valid range, take corrective action if not
if awg_setup.sampling_rate < minsr
    awg_setup.sampling_rate = minsr;    
elseif awg_setup.sampling_rate > maxsr
    awg_setup.sampling_rate = maxsr;
end

fprintf('Sampling Rate = %dGS/s\n', awg_setup.sampling_rate / 1E9);
fprintf('Interpolation Factor = X%d\n', awg_setup.interpol);

% Get min and max output voltage
[minvolt, maxvolt] = proteus_lib.GetAwgVoltageRange();
% Check if voltage is in the valid range, take corrective action if not
if wfmVolt < minvolt
   wfmVolt = minvolt; 
elseif wfmVolt > maxvolt
    wfmVolt = maxvolt;
end

awg_setup.volt = wfmVolt; 

fprintf('Vpp = %dmV\n', wfmVolt * 1E3);

% Reset AWG
inst.SendScpi('*CLS;*RST');

%%%%%%%%%%%%%%%%%%%%%   CALCULATE BASEBAND   %%%%%%%%%%%%%%%%%%%%%%%%

fprintf(1, 'CALCULATING BASEBAND WAVEFORM\n');

mod_setup.oversampling      = oversampling; % * mod_setup.modul_index / mod_setup.modul_freq;

tic;
[mod_bb_wfm, bb_sr] = proteus_lib.GetAnalogModWfm(mod_setup);
%[mod_bb_wfm, bb_sr] = proteus_lib.GetModWfm(mod_setup); % Alternative Function call
toc;

%%%%%%%%%%%%%%%%%%%%%       RESAMPLING      %%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(1, 'BASEBAND WAVEFORM RESAMPLING\n');

% Resampling must be carrier out for the DUC baseband sampling rate
sample_rate_bb_out  = awg_setup.sampling_rate / awg_setup.interpol; 
wfm_length_in       = length(mod_bb_wfm);

%Calculation of lenght of the interpolated waveform
wfm_length_out = floor(wfm_length_in * sample_rate_bb_out /...
    (bb_sr * actual_granularity)) * actual_granularity;
tic;
wfm_out = proteus_lib.ResamplingDirect(mod_bb_wfm, wfm_length_out, true);
toc;
% Sample rate must be corrected to compensate for the timing error
% introduced by the granularity requirements
actual_dac_sample_rate = wfm_length_out * bb_sr / wfm_length_in;
actual_dac_sample_rate = actual_dac_sample_rate * awg_setup.interpol; 
%plot(20.0 * log10(fftshift(abs(fft(wfm_out)))))

%%%%%%%%%%%%%%%%%%%%%       DOWNLOAD WFM      %%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(1, 'DOWNLOADING WAVEFORM TO PROTEUS\n');

awg_setup.sampling_rate = actual_dac_sample_rate;

tic;
result = proteus_lib.SendIqmOneWfm(awg_setup, wfm_out);
toc;

% Disconnect, close VISA handle and destroy handle  
proteus_lib.DisconnectFromProteus();
clear inst;
close all;