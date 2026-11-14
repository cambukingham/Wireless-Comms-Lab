% EXAMPLE FOR DIRECT MODE AND DIGITIZER
%======================================
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
% a sync pulse. Its duration (in states) is equal to the channel number.
% Marker 2 is just geenrating a random stream of bits.
% Digitizer can capture up to 2 of the AWG channels and show multiple
% frames with different trigger modes.

clear;
close all;
clear variables;
clear global;
clc;

% CREATE PROTEUS OBJECTS
proteus_lib = TEProteusLib();
awg_setup   = proteus_lib .CreateDefaultAwgSetup();
dig_setup   = proteus_lib .CreateDefaultDigSetup();

% Basic settings
sel_module          = proteus_lib.PROTEUS_MODULE_01;
dac_sampling_rate   = 9E9;
adc_sampling_rate   = 2.7E9;
dac_interpolation   = proteus_lib.AWG_INTERPOL_X1;
num_of_frames       = 100;
pre_trigger         = 50; % Percentage
t_multiplier        = 4; % Number of cycles acquired
acq_verbose         = true;

% Waveform and Marker Parameters
ch2_triang  = true;
minCycles   = 1;
period      = 1E-6;
wfmVolt     = 0.40;
wfmOff      = 0.0;
mkrVolt     = 1.0;
mkrOff      = 0.5;

dig_channel = proteus_lib.DIG_CHAN_ONE;

fprintf(1, 'INITIALIZING SETTINGS\n');

proteus_lib.lib_verbose = acq_verbose;

% pid = feature('getpid');
% fprintf(1,'\nProcess ID %d\n',pid);

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
proteus_lib.ip_addr         = '127.0.0.1'; % '127.0.0.1' = Local Host, your IP address here
proteus_lib.pxi_slot        = 0; % Set 0 to select slot from attached modules
proteus_lib.com_ifc         = proteus_lib.COMM_IFC_LAN; %"LAN" = VISA or "DLL" = PXI
proteus_lib.paranoia_level  = 2; % 0, 1 or 2

% Instrument setup
[inst, idnstr, slotNumber, serial] = proteus_lib.ConnecToProteus();
% inst handler required to use TEProteusInst.m functions directly

% Report model
fprintf('Connected to: %s, slot: %d\n', idnstr(1), slotNumber(1));

num_of_modules = length(idnstr);

% Report model
for module_ptr = 1:num_of_modules
    fprintf('Connected to: %s, slot: %d\n', idnstr(module_ptr), slotNumber(module_ptr));
end

% Get options using the standard IEEE-488.2 Command
% Get options using the standard IEEE-488.2 Command
optstr = proteus_lib.GetProteusOptions();

% Set AWG settings
awg_setup.sampling_rate         = dac_sampling_rate;
awg_setup.interpol              = dac_interpolation;
awg_setup.dac_resolution        = 16;

if (awg_setup.sampling_rate / awg_setup.interpol) > 2.5E9
    awg_setup.dac_resolution    = 8;
    awg_setup.interpol          = 1;
end

if (awg_setup.sampling_rate / awg_setup.interpol) < 250E6
    awg_setup.interpol          = 1;
end

% Get Active Channels and Segment #
[chanList, segmList] = proteus_lib.GetChannels(idnstr(1), awg_setup.sampling_rate / awg_setup.interpol);
numOfChannels = length(chanList);

fprintf(1, 'Calculating WAVEFORMS\n');

% SETTING AWG
fprintf(1, 'SETTING AWG\n');

awg_setup.sel_module    = sel_module;
awg_setup.volt          = wfmVolt;
awg_setup.offset        = wfmOff;
awg_setup.mode          = proteus_lib.AWG_MODE_DIRECT;
awg_setup.mkr_mode      = proteus_lib.AWG_MKR_MODE_TWO;
awg_setup.mkr1_state    = 1;
awg_setup.mkr1_volt     = mkrVolt;
awg_setup.mkr1_offset   = mkrOff;
awg_setup.mkr2_state    = 1;
awg_setup.mkr2_volt     = mkrVolt;
awg_setup.mkr2_offset   = mkrOff;

% Set ADC settings
dig_setup.mode                                  = proteus_lib.DIG_ACQ_MODE_DUAL;
dig_setup.ch_state(proteus_lib.DIG_CHAN_ONE)    = proteus_lib.DIG_CHAN_ENABLE;
dig_setup.ch_state(proteus_lib.DIG_CHAN_TWO)    = proteus_lib.DIG_CHAN_ENABLE;
dig_setup.ddc                                   = proteus_lib.DIG_MODE_REAL;
dig_setup.data_type                             = proteus_lib.DIG_DATA_TYPE_FRAMES;
dig_setup.acq_type                              = proteus_lib.DIG_ACQ_TYPE_ALL;
dig_setup.adc_resol                             = proteus_lib.DIG_ADC_RESOL_REAL;
dig_setup.trg_src(proteus_lib.DIG_CHAN_ONE)     = proteus_lib.DIG_TRG_CH1;
dig_setup.trg_src(proteus_lib.DIG_CHAN_TWO)     = proteus_lib.DIG_TRG_CH1;
dig_setup.trg_delay                             = 0.0; %390E-9;
dig_setup.clk_src                               = proteus_lib.DIG_CLK_SRC_DIG;
dig_setup.sampling_rate                         = adc_sampling_rate;
dig_setup.rng(proteus_lib.DIG_CHAN_ONE)         = proteus_lib.DIG_RNG_500MV;
dig_setup.rng(proteus_lib.DIG_CHAN_TWO)         = proteus_lib.DIG_RNG_500MV;
dig_setup.num_of_frames                         = num_of_frames;
dig_setup.pre_trigger                           = pre_trigger;
dig_setup.granul                                = proteus_lib.DIG_GRANUL_DUAL;

if dig_setup.mode == proteus_lib.DIG_ACQ_MODE_DUAL && dig_setup.sampling_rate > 2.7E9
    dig_setup.sampling_rate = 2.7E9;
end

if dig_setup.mode == proteus_lib.DIG_ACQ_MODE_SINGLE
    dig_setup.ch_state(proteus_lib.DIG_CHAN_ONE)    = proteus_lib.DIG_CHAN_ENABLE;
    dig_setup.ch_state(proteus_lib.DIG_CHAN_TWO)    = proteus_lib.DIG_CHAN_DISABLE;
    dig_setup.granul                                = proteus_lib.DIG_GRANUL_SINGLE;
    if dig_setup.ddc == proteus_lib.DIG_MODE_COMPLEX && dig_setup.sampling_rate > 2.7E9
        dig_setup.sampling_rate = 2.7E9;
    end
end

if dig_setup.ddc == proteus_lib.DIG_MODE_COMPLEX
    dig_setup.adc_resol = proteus_lib.DIG_ADC_RESOL_COMPLEX;
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

% Get granularity
dac_granul              = proteus_lib.GetGranularity(idnstr(awg_setup.sel_module), optstr, awg_setup.dac_resolution);
awg_setup.granularity   = dac_granul;

fprintf('\nGranularity = %d samples\n', dac_granul);

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

% Calculate Digitizer Acquisition parameters
adc_frame_length        = period * dig_setup.sampling_rate * t_multiplier;
dig_setup.frame_length  = ceil(adc_frame_length / dig_setup.granul) * dig_setup.granul;

for channel = 1:numOfChannels  
    
    % Calculate basic square wave
    if mod(channel, 4) == 1
        myWfm = getSquareWfm(   awg_setup.sampling_rate / awg_setup.interpol,... 
                                minCycles,...
                                period,...
                                awg_setup.granularity);
    end

    mkrDiv = 2;
    if awg_setup.dac_resolution == 8
        mkrDiv = 8;
    end

    myMkr1 = uint8(zeros(1, length(myWfm) / mkrDiv));
    myMkr1(1:channel) = uint8(1); % Sync marker duration depends on the channel
    myMkr2 = rand(1, length(myMkr1)); % Random data is different for each channel
    myMkr2 = uint8(myMkr2 > 0.5);    
    myMkr = proteus_lib.FormatMkr2(awg_setup.dac_resolution, myMkr1, myMkr2);

    % Waveform Downloading
    % ********************    
    fprintf(1, 'DOWNLOADING WAVEFORM FOR CH%d\n', chanList(channel));
    awg_setup.channel = chanList(channel);
    awg_setup.segment = segmList(channel);
    
    proteus_lib.SendWfmToProteus(   awg_setup,...
                                    myWfm,...
                                    true);   

    %proteus_lib.SendMkrToProteus(awg_setup, myMkr);

    fprintf(1, 'WAVEFORM DOWNLOADED!\n'); 

    % ********************TASK LIST*********************
    task_list       = uint32(zeros(1, proteus_lib.TASK_MATRIX_WIDTH));
    task_list(1, proteus_lib.TASK_SEGMENT_PTR)  = 1;
    task_list(1, proteus_lib.TASK_TYPE)         = proteus_lib.TASK_TYPE_SINGLE;
    task_list(1, proteus_lib.TASK_LOOPS)        = 1;
    task_list(1, proteus_lib.TASK_NEXT)         = 1;
     
    task_list(1, proteus_lib.TASK_ENABLE_EVENT) = proteus_lib.TASK_EVENT_NONE;
    task_list(1, proteus_lib.TASK_ABORT_EVENT)  = proteus_lib.TASK_EVENT_NONE;
    if channel == 1
        task_list(1, proteus_lib.TASK_DTR_FLAG) = 1;
    else
        task_list(1, proteus_lib.TASK_DTR_FLAG) = 0;
    end
    proteus_lib.TaskListSetup(awg_setup, task_list);
    
    % **************************************************    
    % The new waveform is calculated for the next channel
    if ch2_triang
        if mod(channel - 1, 4) < 3
            % Integration
            myWfm = myWfm - mean(myWfm);
            myWfm = cumsum(myWfm);
            % DC removal
            myWfm = myWfm - mean(myWfm);
            % Normalization to the -1.0/+1.0 range
            myWfm = myWfm / max(abs(myWfm));
        end
    end
end

% DIGITIZER SECTION 
% *****************
% Get all frames from digitizer
fprintf('Acquired Waveforms and/or Headers Upload to Computer Starts\n');

[acq_wfm, acq_hdr]  = proteus_lib.GetWfmFromProteusDig(dig_setup);

if dig_setup.data_type ~= proteus_lib.DIG_DATA_TYPE_HEADERS    
    if dig_setup.ch_state(proteus_lib.DIG_CHAN_ONE) == proteus_lib.DIG_CHAN_ENABLE
        acq_wfm_ch1         = proteus_lib.SamplesToFrames(acq_wfm(1,:), dig_setup.frame_length);
    elseif dig_setup.ch_state(proteus_lib.DIG_CHAN_TWO) == proteus_lib.DIG_CHAN_ENABLE
        acq_wfm_ch2         = proteus_lib.SamplesToFrames(acq_wfm(1,:), dig_setup.frame_length);
    end
    
    if dig_setup.ch_state(proteus_lib.DIG_CHAN_ONE) == proteus_lib.DIG_CHAN_ENABLE &&... 
       dig_setup.ch_state(proteus_lib.DIG_CHAN_TWO) == proteus_lib.DIG_CHAN_ENABLE
        acq_wfm_ch2         = proteus_lib.SamplesToFrames(acq_wfm(2,:), dig_setup.frame_length);
    end
end

fprintf('Acquired Waveforms and/or Headers Upload to Computer Ends\n');

% *************************************************************************
% Plot Data 

if dig_setup.data_type ~= proteus_lib.DIG_DATA_TYPE_HEADERS
    tiledlayout(1,1);
    if dig_setup.ch_state(proteus_lib.DIG_CHAN_ONE) == proteus_lib.DIG_CHAN_ENABLE &&... 
       dig_setup.ch_state(proteus_lib.DIG_CHAN_TWO) == proteus_lib.DIG_CHAN_ENABLE
        tiledlayout(1,2);
    end
    if dig_setup.ch_state(proteus_lib.DIG_CHAN_ONE) == proteus_lib.DIG_CHAN_ENABLE
        x_data = 1:length(acq_wfm_ch1(1,:));
        x_data = x_data - 1.0;
        x_data = x_data / dig_setup.sampling_rate;
        % x_data = x_data / dig_setup.sampling_rate;
        ax1 = nexttile;
        hold_flag = true;
        for wfm = 1:dig_setup.num_of_frames
            plot(ax1, x_data, acq_wfm_ch1(wfm,:));
            if hold_flag
                hold;
                hold_flag = false;
            end
        end
    
        title(ax1,'CH1 Waveform'); 
        grid(ax1,'on');
        xlim([x_data(1) x_data(end)]);
        ylim([-2048 2048]);
    end
    if dig_setup.ch_state(proteus_lib.DIG_CHAN_TWO) == proteus_lib.DIG_CHAN_ENABLE
        x_data = 1:length(acq_wfm_ch2(1,:));
        x_data = x_data - 1.0;
        x_data = x_data / dig_setup.sampling_rate;
        ax2 = nexttile;
        hold_flag = true;
        for wfm = 1:dig_setup.num_of_frames
            plot(ax2, x_data, acq_wfm_ch2(wfm,:));
            if hold_flag
                hold;
                hold_flag = false;
            end
        end
        
        title(ax2,'CH2 Waveform');
        grid(ax2,'on');
        xlim([x_data(1) x_data(end)]);
        ylim([-2048 2048]);
    end
end

% Disconnect, close VISA handle and destroy handle  
proteus_lib.DisconnectFromProteus();

clear inst;
%close all;

function sqrWfm = getSquareWfm( samplingRate,... 
                                numCycles,...
                                period,...
                                granularity)
                            
    wfmLength = round(numCycles * period *samplingRate);
    wfmLength = round(wfmLength / granularity) * granularity;
    
    period = wfmLength / numCycles;    
    sqrWfm = 0:(wfmLength - 1);    
    sqrWfm = square(sqrWfm * 2 * pi / period);    
                            
end