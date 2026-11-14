% EXAMPLE FOR DIRECT MODE
%===================================================
% This example calculates up to 4 different signals and download them into
% each available channel in the target Proteus device.
% 
% The basic waveform is an square waveform using the full DAC range and it
% is downloaded to channel #1. For each channel, the waveform is calculated
% by integration of the previous waveform in a similar way to some analog
% signal generators, where the triangular wave is obtained by integration
% of an square wave, and the sinusoidal waveform is obtained by integration
% of the triangular wave. Channel #4, when available, will generate a
% "cosine" wave obatined by integration of the sinewave assigned to channel
% #3.
% Markers for each channel are also calculated and downloaded. Marker 1 is
% a sync pulse. Marker 2 is just geenrating a random stream of bits.

clear;
close all;
clear variables;
clear global;
clc;

% Load Library
proteus_lib = TEProteusLib();
proteus_lib.lib_verbose = true;

% Waveform and Marker Parameters
% Signal parameters
type_of_signal  = proteus_lib.STD_FUNC_SIN;
freq            = 10E6;
phase           = 0.0;
duty_cycle      = 50.0;
num_of_cycles   = 10;
oversampling    = 100;
%granularity     = 32;

wfmVolt     = 1.3;
wfmOff      = 0.0;
s_rate      = 9E9;
interpol    = proteus_lib.AWG_INTERPOL_X4;

mkrVolt     = 1.0;
mkrOff      = 0.5;

ext1_trg    = false;
cpu_trg     = false;
trg_lvl     = 0.0;

min_wfm_length = 2048;

% CREATE PROTEUS OBJECTS
awg_setup = proteus_lib.CreateDefaultAwgSetup();

fprintf(1, 'INITIALIZING SETTINGS\n');

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
proteus_lib.ip_addr         = '127.0.0.1'; % '127.0.0.1' = Local Host, your IP address here
proteus_lib.pxi_slot        = 0; % Set 0 to select slot from attached modules
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

% Get options using the standard IEEE-488.2 Command
optstr = proteus_lib.GetProteusOptions();

% Set AWG settings
awg_setup.sel_module            = proteus_lib.PROTEUS_MODULE_01;
awg_setup.sampling_rate         = s_rate;
awg_setup.interpol              = interpol;
awg_setup.repeat_sample         = proteus_lib.AWG_REPEAT_X1;
awg_setup.dac_resolution        = proteus_lib.AWG_DAC_MODE_16;
% Set the right DAC Mode
if (awg_setup.sampling_rate / awg_setup.interpol) > 2.5E9
    awg_setup.dac_resolution    = proteus_lib.AWG_DAC_MODE_8;
    awg_setup.interpol          = 1;
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

% Reset AWG
inst.SendScpi('*CLS;*RST');

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
% Set the current marker mode depending on DAC mode
if awg_setup.dac_resolution == proteus_lib.AWG_DAC_MODE_8
    awg_setup.mkr_mode  = proteus_lib.AWG_MKR_MODE_FOUR;
else
    awg_setup.mkr_mode  = proteus_lib.AWG_MKR_MODE_TWO;
end
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
% Calculate divider for marker #f states
mkrDiv = proteus_lib.AWG_MKR_DIV_16;
if awg_setup.dac_resolution == proteus_lib.AWG_DAC_MODE_8
    mkrDiv = proteus_lib.AWG_MKR_DIV_8;
end

% Calculate basic square wave
myWfm = getSquareWfm(   awg_setup.sampling_rate / awg_setup.interpol / awg_setup.repeat_sample,... 
                        minCycles,...
                        period,...
                        granul,...
                        min_wfm_length);
% And Markers
myMkr1                  = uint8(zeros(1, length(myWfm) / mkrDiv));
myMkr1(1:10)            = uint8(1); % Sync marker
myMkr2                  = rand(1, length(myMkr1)); % Random data
myMkr2                  = uint8(myMkr2 > 0.5);
myMkr3                  = uint8(zeros(1, length(myWfm) / mkrDiv));
myMkr3(1:20)            = uint8(1); % Second Sync marker
myMkr4                  = rand(1, length(myMkr1)); % Random data
myMkr4                  = uint8(myMkr4 > 0.5);
% Format marker data for downloading depending on the Marker Mode
if awg_setup.mkr_mode == proteus_lib.AWG_MKR_MODE_FOUR
    myMkr = proteus_lib.FormatMkr4(awg_setup.dac_resolution, myMkr1, myMkr2, myMkr3, myMkr4);
else
    myMkr = proteus_lib.FormatMkr2(awg_setup.dac_resolution, myMkr1, myMkr2);
end 

% Download Wfms and Markers for all available channels
for channel = 1:numOfChannels         
    
    % Waveform Downloading
    % *******************    
    fprintf(1, 'DOWNLOADING WAVEFORM FOR CH%d\n', chanList(channel));
    awg_setup.channel = chanList(channel);
    awg_setup.segment = segmList(channel);
    % Download waveform
    proteus_lib.SendWfmToProteus(   awg_setup,...
                                    myWfm,...
                                    true);   
    % Download Markers
    proteus_lib.SendMkrToProteus(awg_setup, myMkr);

    fprintf(1, 'WAVEFORM AND MARKERS DOWNLOADED!\n');    
    
    %The new waveform is calculated for the next channel by integration
    if mod(channel - 1, 4) < 3
        % Integration
        myWfm = cumsum(myWfm);
        % DC removal
        myWfm = myWfm - mean(myWfm);
        % Normalization to the -1.0/+1.0 range
        myWfm = myWfm / max(abs(myWfm));
    end
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

function sqrWfm = getSquareWfm( samplingRate,... 
                                numCycles,...
                                period,...
                                granularity,...
                                min_wfm_length)
                            
    wfmLength = round(numCycles * period * samplingRate);
    wfmLength = round(wfmLength / granularity) * granularity;
    
    period = wfmLength / numCycles;    
    sqrWfm = 0:(wfmLength - 1);    
    sqrWfm = square(sqrWfm * 2 * pi / period); 
    num_of_copies = ceil(min_wfm_length / length(sqrWfm));
    sqrWfm = repmat(sqrWfm, 1, num_of_copies);                           
end