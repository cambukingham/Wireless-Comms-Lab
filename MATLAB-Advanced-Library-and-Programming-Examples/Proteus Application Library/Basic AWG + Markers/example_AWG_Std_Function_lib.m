% EXAMPLE FOR DIRECT MODE
%===================================================
% This example calculates up to 4 different standard signals and download
% them into each available channel in the target Proteus device.
% Waveform types are sine, triangle, square, and ramp.

clear;
close all;
clear variables;
clear global;
clc;

% Load Library
proteus_lib = TEProteusLib();
proteus_lib.lib_verbose = true;

% Standard Signal Parameters
% Signal parameters
freq                = 12.34E6;
phase               = 0.0;
duty_cycle          = 50.0;
num_of_cycles       = 1;
samples_per_cycle   = 100;

% AWG Settings
wfmVolt     = 1.3;
wfmOff      = 0.0;
interpol    = proteus_lib.AWG_INTERPOL_X2;
ext1_trg    = false;
cpu_trg     = false;
trg_lvl     = 0.0;

min_wfm_length = 128;

% CREATE PROTEUS OBJECTS
awg_setup = proteus_lib.CreateDefaultAwgSetup();

fprintf(1, 'INITIALIZING SETTINGS\n');

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
proteus_lib.ip_addr         = '127.0.0.1'; % '127.0.0.1' = Local Host, your IP address here
proteus_lib.pxi_slot        = 5; % Set 0 to select slot from attached modules
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

% Get options using the standard IEEE-488.2 Command
optstr = proteus_lib.GetProteusOptions();

% Set AWG settings
awg_setup.sel_module            = proteus_lib.PROTEUS_MODULE_01;

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

% Reset AWG
inst.SendScpi('*CLS;*RST');

% Calculate basic sine wave
[wfm_length, Fs] = proteus_lib.GetStdWfmSettings(   freq,...
                                                    num_of_cycles,...
                                                    samples_per_cycle,...
                                                    1);

% Set AWG Settings
awg_setup.sampling_rate         = Fs * interpol;
awg_setup.interpol              = interpol;
awg_setup.repeat_sample         = proteus_lib.AWG_REPEAT_X1;
awg_setup.dac_resolution        = proteus_lib.AWG_DAC_MODE_16;
% Set the right DAC Mode
if (awg_setup.sampling_rate / awg_setup.interpol) > 2.5E9
    awg_setup.dac_resolution    = proteus_lib.AWG_DAC_MODE_8;
    awg_setup.interpol          = 1;
end

% Get granularity
granul = proteus_lib.GetGranularity(idnstr(awg_setup.sel_module), optstr, awg_setup.dac_resolution);
fprintf('\nGranularity = %d samples\n', granul);

% Get min and max sampling rates
[minsr, maxsr] = proteus_lib.GetAwgSamplingRateRange();
% Check if sample rate is in the valid range, take corrective action if not
if awg_setup.sampling_rate < minsr
    awg_setup.sampling_rate = minsr;    
elseif awg_setup.sampling_rate > maxsr
    awg_setup.sampling_rate = maxsr;
end

fprintf('Sampling Rate = %fGS/s\n', awg_setup.sampling_rate / 1E9);
fprintf('Interpolation Factor = X%d\n', awg_setup.interpol);

% Get min and max output voltage
[minvolt, maxvolt] = proteus_lib.GetAwgVoltageRange();
% Check if voltage is in the valid range, take corrective action if not
if wfmVolt < minvolt
   wfmVolt = minvolt; 
elseif wfmVolt > maxvolt
    wfmVolt = maxvolt;
end

fprintf('Vpp = %dmV\n', wfmVolt * 1E3);

% Get Active Channels and Segment #
[chanList, segmList] = proteus_lib.GetChannels( idnstr(awg_setup.sel_module),...
                                                awg_setup.sampling_rate / awg_setup.interpol);
numOfChannels = length(chanList);

fprintf(1, '\nCalculating WAVEFORMS\n');

% SETTING AWG
fprintf(1, 'SETTING AWG\n');

awg_setup.volt          = wfmVolt;
awg_setup.offset        = wfmOff;
awg_setup.mode          = proteus_lib.AWG_MODE_DIRECT;

% Setup trigger
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

% Download Wfms for all available channels
for channel = 1:numOfChannels         
    
    % Waveform Downloading
    % *******************    
    fprintf(1, 'DOWNLOADING WAVEFORM FOR CH%d\n', chanList(channel));
    awg_setup.channel = chanList(channel);
    awg_setup.segment = segmList(channel);
    
    % Set Standard Waveform Type for Each Channel
    type_of_signal  = proteus_lib.STD_FUNC_SINE;   
    switch channel
        case proteus_lib.AWG_CHAN_CH01
            % Sine wave
            type_of_signal      = proteus_lib.STD_FUNC_SINE;
        case proteus_lib.AWG_CHAN_CH02
            % Triangle wave
            type_of_signal      = proteus_lib.STD_FUNC_TRIANGLE;
        case proteus_lib.AWG_CHAN_CH03
            % Square wave
            type_of_signal      = proteus_lib.STD_FUNC_SQUARE;
        case proteus_lib.AWG_CHAN_CH04
            % Ramp wave
            type_of_signal      = proteus_lib.STD_FUNC_RAMP;
    end
            
    % Calculate Standard Waveform
    [myWfm, actual_sampling_rate] = proteus_lib.GetStdWfm(  type_of_signal,...
                                                            freq,...
                                                            phase,...
                                                            duty_cycle,...
                                                            num_of_cycles,...
                                                            samples_per_cycle,...
                                                            1);
    % Repeat copies of the waveform so total length is the minimum
    % multiple of granularity
    myWfm = proteus_lib.WfmAppendGranularity(myWfm, granul);
    % Repeat copies of the waveform until the minimum length is reached
    myWfm = proteus_lib.WfmRepeatForMinSize(myWfm, min_wfm_length);
    
    awg_setup.sampling_rate = actual_sampling_rate;
    % Download waveform
    proteus_lib.SendWfmToProteus(   awg_setup,...
                                    myWfm,...
                                    true); 
    

    fprintf(1, 'WAVEFORMS DOWNLOADED!\n');    
end
% Set Sample Rate
inst.SendScpi([':FREQ:RAST ' num2str(awg_setup.sampling_rate)]);

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