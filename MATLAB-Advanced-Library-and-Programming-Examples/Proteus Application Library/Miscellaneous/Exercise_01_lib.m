% EXERCISE #1
%===================================================

clear;
close all;
clear variables;
clear global;
clc;

% Waveform and Marker Parameters
freq1       = 1.234E6;
freq2       = 4.001E6;
freq_resol  = 1E3;

wfmVolt     = 0.25;
wfmOff      = 0.0;

mkrVolt     = 1.0;
mkrOff      = 0.5;

ext1_trg    = false;
cpu_trg     = false;
trg_lvl     = 0.0;
num_of_repeats = 1;

% CREATE PROTEUS OBJECTS
proteus_lib = TEProteusLib();
awg_setup   = proteus_lib.CreateDefaultAwgSetup();

fprintf(1, 'INITIALIZING SETTINGS\n');

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
proteus_lib.ip_addr         = '192.168.10.59'; % '127.0.0.1' = Local Host, your IP address here
% proteus_lib.pxi_slot        = 3; % Set 0 to select slot from attached modules
proteus_lib.com_ifc         = proteus_lib.COMM_IFC_LAN; %"LAN" = VISA or "DLL" = PXI
proteus_lib.paranoia_level  = 2; % 0, 1 or 2

% Instrument setup
[inst, idnstr, slotNumber, serial] = proteus_lib.ConnecToProteus();
% inst handler required to use TEProteusInst.m functions directly

% Report model
fprintf('Connected to: %s, slot: %d\n', idnstr(1), slotNumber(1));

% Reset AWG
inst.SendScpi('*CLS;*RST');

% Get options using the standard IEEE-488.2 Command
% Get options using the standard IEEE-488.2 Command
optstr = proteus_lib.GetProteusOptions();

% Set AWG settings
awg_setup.sampling_rate         = 9E9;
awg_setup.interpol              = 4;
awg_setup.dac_resolution        = proteus_lib.AWG_DAC_MODE_16;

if (awg_setup.sampling_rate / awg_setup.interpol) > 2.5E9
    awg_setup.dac_resolution    = proteus_lib.AWG_DAC_MODE_8;
    awg_setup.interpol          = 1;
end

% Get granularity
granul = proteus_lib.GetGranularity(idnstr(1), optstr, awg_setup.dac_resolution);

fprintf('\nGranularity = %d samples\n', granul);
fprintf(1, 'Calculating WAVEFORMS\n');

% SETTING AWG
fprintf(1, 'SETTING AWG\n');

awg_setup.volt          = wfmVolt;
awg_setup.offset        = wfmOff;
awg_setup.mode          = proteus_lib.AWG_MODE_DIRECT;
awg_setup.mkr1_state    = 1;
awg_setup.mkr1_volt     = mkrVolt;
awg_setup.mkr1_offset   = mkrOff;
awg_setup.mkr2_state    = 1;
awg_setup.mkr2_volt     = mkrVolt;
awg_setup.mkr2_offset   = mkrOff;
awg_setup.mkr3_state    = 1;
awg_setup.mkr3_volt     = mkrVolt;
awg_setup.mkr3_offset   = mkrOff;
awg_setup.mkr4_state    = 1;
awg_setup.mkr4_volt     = mkrVolt;
awg_setup.mkr4_offset   = mkrOff;

if awg_setup.dac_resolution == proteus_lib.AWG_DAC_MODE_8
    awg_setup.mkr_mode  = proteus_lib.AWG_MKR_MODE_FOUR;
else
    awg_setup.mkr_mode  = proteus_lib.AWG_MKR_MODE_TWO;
end

if ext1_trg
    awg_setup.trg_mode      = proteus_lib.AWG_TRG_MODE_TRIG;
    awg_setup.trg_src       = proteus_lib.TASK_EVENT_TRG1;
    awg_setup.trg_slope     = proteus_lib.AWG_TRG_SLOPE_POS;
    awg_setup.trg_count     = num_of_repeats;
    awg_setup.trg_lvl       = trg_lvl;
elseif cpu_trg
    % CPU TRIGGER
    awg_setup.trg_mode      = proteus_lib.AWG_TRG_MODE_TRIG;
    awg_setup.trg_src       = proteus_lib.TASK_EVENT_CPU;
    awg_setup.cpu_trg_mode  = proteus_lib.AWG_CPU_TRG_LOCAL;
else    
    awg_setup.trg_mode      = proteus_lib.AWG_TRG_MODE_CONT;
end

mkrDiv = proteus_lib.AWG_MKR_DIV_16;
if awg_setup.dac_resolution == proteus_lib.AWG_DAC_MODE_8
    mkrDiv = proteus_lib.AWG_MKR_DIV_8;
end

% Waveform calculation
wfm_length_accurate     = 1 / freq_resol * awg_setup.sampling_rate /...
                            awg_setup.interpol;
wfm_length              = floor(wfm_length_accurate / granul) * granul;
awg_setup.sampling_rate = awg_setup.sampling_rate * wfm_length / wfm_length_accurate;  

% num_of_cycles_1 = round(freq1 / freq_resol);
% num_of_cycles_2 = round(freq2 / freq_resol);
% x_wfm           = 0:(wfm_length - 1);
% x_wfm           = 2 * pi * x_wfm / wfm_length;
% final_wfm       = cos(num_of_cycles_1 * x_wfm);
% final_wfm       = final_wfm + cos(num_of_cycles_2 * x_wfm);  

freq        = [freq1, freq2, 3.234E6];
ampl        = [1.0, 1.0, 0.1];
phase       = [0, 0, 45.0];
final_wfm   = proteus_lib.GetTones( freq,...
                                    ampl,...
                                    phase,...
                                    awg_setup.sampling_rate / awg_setup.interpol,...
                                    wfm_length);
final_wfm   = real(final_wfm);

% Normalize Wfm
final_wfm = proteus_lib.Normalize(final_wfm);

% Marker settings
myMkr1                  = uint8(zeros(1, wfm_length / mkrDiv));
myMkr1(1:10)            = uint8(1); % Sync marker duration depends on the channel
myMkr2                  = uint8(zeros(1, wfm_length / mkrDiv));
myMkr3                  = uint8(zeros(1, wfm_length / mkrDiv));
myMkr4                  = uint8(zeros(1, wfm_length / mkrDiv));

if awg_setup.mkr_mode == proteus_lib.AWG_MKR_MODE_FOUR
    myMkr = proteus_lib.FormatMkr4(awg_setup.dac_resolution, myMkr1, myMkr2, myMkr3, myMkr4);
else
    myMkr = proteus_lib.FormatMkr2(awg_setup.dac_resolution, myMkr1, myMkr2);
end

% Waveform Downloading
% *******************

fprintf(1, 'DOWNLOADING WAVEFORM FOR CH%d\n',1);
awg_setup.channel = proteus_lib.AWG_CHAN_CH01;
awg_setup.segment = 1;

proteus_lib.SendWfmToProteus(   awg_setup,...
                                final_wfm,...
                                true);   

proteus_lib.SendMkrToProteus(awg_setup, myMkr);

fprintf(1, 'WAVEFORM DOWNLOADED!\n');    


inst.SendScpi([':FREQ:RAST ' num2str(awg_setup.sampling_rate)]);

%inst.SendScpi([':SOUR:PTR X' num2str(8)]);
% Trigger AWG
if cpu_trg
    inst.SendScpi(sprintf(':INST:CHAN %d', 1));
    %inst.SendScpi(':TRIG:CPU:MODE GLOBAL');
    inst.SendScpi(':TRIG:IMM');
end

% Disconnect, close VISA handle and destroy handle  
proteus_lib.DisconnectFromProteus();

clear inst;
close all;