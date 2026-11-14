% NMR Demo with DUC and DDC
% *************************

% It generates a pulsed RF signal using the DUC and optimizes waveform
% memory usage using sequencing. It captures multiple acquisitions of the RF 
% waveform directly or using the DDC (Digital Down Converter). DUC/DDC
% can be synchronized and TX to RX phase drift can be shown in either case.
% It shows all the acquisitions (acquisition # cbe selected usiong an slide
% control).
%
% WARNING: Use only with DLL connection to minimize transfer times. Not
% tested with LAN connection.

clear;
close all;
clear variables;
clear global;
clc;

% CREATE PROTEUS OBJECTS
proteus_lib = TEProteusLib();
awg_setup   = proteus_lib.CreateDefaultAwgSetup();
dig_setup   = proteus_lib.CreateDefaultDigSetup();

% Main Settings
% *************
num_of_avg          = 1;
show_time_domain    = false;
freq_domain_span    = 2500.0;
awg_channel         = proteus_lib.AWG_CHAN_CH01;
dig_channel         = proteus_lib.DIG_CHAN_ONE;
% TASK_EVENT_NONE
% TASK_EVENT_TRG1
% TASK_EVENT_TRG2
ext_trig            = proteus_lib.TASK_EVENT_NONE;
trg_lvl             = 0.6; % Set the level to 50% of the pulse amplitude************
trg_slope           = proteus_lib.AWG_TRG_SLOPE_POS;
% Delay for each digitizer channel
delay               = 0.0;  % ADC Trigger Delay
dac_sampling_rate   = 8E9; % This give us 50MS/s baseband sample rate for ADC
adc_sampling_rate   = 0.8e9; % automatically calculated when coherent acq
acq_length          = 0.5; % in seconds
total_decim         = 10000; % 10,000 = 5KHz BW,
box_decimation      = 1000;
box_f_ratio         = 1;
snr_wfm_fraction    = 25.0;

% Test Signal
% Use PULSE_TYPE_NMR_FID to simulate FID
% Use PULSE_TYPE_SQUARE for square pulses
% Use PULSE_TYPE_GAUSSIAN for Gaussian pulses
pulse_type          = proteus_lib.PULSE_TYPE_NMR_FID;
carrier_frequency   = 102.258E6;
time_parameter      = 5E-3; % Tau for FID, width for other pulses, in seconds
offset_freq         = 500.0; % Set desired freque for FID simulation, should be zero otherwise
rep_freq            = 0.25; % Repetition frequency for pulses in Hz

% *************
% *************
% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
proteus_lib.ip_addr         = '127.0.0.1'; %'192.168.10.48'; % '127.0.0.1' = Local Host, your IP address here
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

% Reset AWG
inst.SendScpi('*CLS;*RST');

% DDC and DUC activation
% ======================
use_ddc             = true;     % true = DDC on, false = DDC off
sync_nco            = true;     % true = Coherent acq
%=======================

use_dtr_trigger     = true;     % Digitizer will be triggered by AWG
adc_granularity     = 48;

% AWG Settings
awg_setup.mode              = proteus_lib.AWG_MODE_DUC;
awg_setup.iq_mode           = proteus_lib.AWG_IQ_MODE_ONE;
awg_setup.interpol          = proteus_lib.AWG_INTERPOL_X8;
awg_setup.granularity       = 32;
awg_setup.min_segment       = 64;
awg_setup.dac_resolution    = proteus_lib.AWG_DAC_MODE_16;
awg_setup.sampling_rate     = dac_sampling_rate;
awg_setup.channel           = awg_channel;
awg_setup.segment           = 1;
awg_setup.volt              = 0.45;
awg_setup.cfr1              = carrier_frequency;
awg_setup.trg_slope         = trg_slope;
if awg_setup.iq_mode == proteus_lib.AWG_IQ_MODE_HALF            % Values must be corrected for proper calculations when mode = HALF
    awg_setup.granularity   = 64;
    awg_setup.min_segment   = 128;
    awg_setup.interpol      = proteus_lib.AWG_INTERPOL_X4;
end

% Digitizer Settings

dig_setup.ch_state(1)           = proteus_lib.DIG_CHAN_DISABLE;
dig_setup.ch_state(2)           = proteus_lib.DIG_CHAN_DISABLE;
dig_setup.ch_state(dig_channel) = proteus_lib.DIG_CHAN_ENABLE;
dig_setup.cfr(dig_channel)      = awg_setup.cfr1;
dig_setup.trg_delay             = delay;

switch awg_setup.channel
    case proteus_lib.AWG_CHAN_CH01
        dig_setup.trg_src(dig_channel) = proteus_lib.DIG_TRG_DTR_CH1;

    case proteus_lib.AWG_CHAN_CH02
        dig_setup.trg_src(dig_channel) = proteus_lib.DIG_TRG_DTR_CH2;

    case proteus_lib.AWG_CHAN_CH03
        dig_setup.trg_src(dig_channel) = proteus_lib.DIG_TRG_DTR_CH3;

    case proteus_lib.AWG_CHAN_CH04
        dig_setup.trg_src(dig_channel) = proteus_lib.DIG_TRG_DTR_CH4;
end

if use_ddc
    dig_setup.ddc           = proteus_lib.DIG_MODE_COMPLEX;
    dig_setup.adc_resol     = proteus_lib.DIG_ADC_RESOL_COMPLEX;
else
    dig_setup.mode          = proteus_lib.DIG_MODE_REAL;
    dig_setup.adc_resol     = proteus_lib.DIG_ADC_RESOL_REAL;
end

if sync_nco
    dig_setup.clk_src       = proteus_lib.DIG_CLK_SRC_DIG;
else
    dig_setup.clk_src       = proteus_lib.DIG_CLK_SRC_AWG;
end

% The Carrier Frequency for the ADC must be an integer submultiple (x1, x2,
% x4, x8) of the AWG sampling rate. Four (4) is selected in this case.
if sync_nco
    dig_setup.sampling_rate = awg_setup.sampling_rate / 8;
else
    dig_setup.sampling_rate = adc_sampling_rate;
end


dig_setup.rng(dig_channel)  = proteus_lib.DIG_RNG_250MV;
dig_setup.num_of_frames     = 1;
dig_setup.pre_trigger       = 1; % Percentage of the acquisition

if dig_setup.ddc == proteus_lib.DIG_MODE_COMPLEX
    dig_setup.ddc_decim     = proteus_lib.DIG_DDC_DECIM_X16;       % This is the decimation factor for DDC
else
    dig_setup.ddc_decim     = proteus_lib.DIG_DDC_DECIM_NONE; % This is the decimation factor for Direct
    sync_nco                = false;
end

fprintf('NMR EXAMPLE STARTS\n');

% RF Pulse Parameters
pulse_setup = proteus_lib.CreateDefaultPulseSetup();
pulse_setup.pulse_type          = pulse_type;
pulse_setup.quality             = 8;
pulse_setup.edge_shape          = proteus_lib.PULSE_EDGE_GAUSSIAN;
pulse_setup.pulse_width         = time_parameter;  % Pulse Width
pulse_setup.freq_offset         = offset_freq;
pulse_setup.bandwidth           = 5.0E6;
pulse_setup.rise_time           = 5.0E-6;
pulse_setup.pulse_rep_freq      = rep_freq;  % PRI
pulse_setup.trg_src             = ext_trig;


num_of_pulses                   = 1;        % Num of pulses in the sequence




% Frame length calculation for ADC according to pulse width amd pretrigger
% setting.
dig_setup.frame_length = dig_setup.sampling_rate * acq_length;
dig_setup.frame_length = dig_setup.frame_length / dig_setup.ddc_decim;
% if dig_setup.ddc == proteus_lib.DIG_MODE_COMPLEX
%     dig_setup.frame_length = 2 * dig_setup.frame_length;
% end
dig_setup.frame_length = ceil(dig_setup.frame_length / adc_granularity) * adc_granularity;

% Pulse RF Signal Calculation and Download

% The final waveform will be generated by a sequence specified in a
% task list as follows:
%
%   Task #      segment             num of repetitions
% _________________________________________________________

%   TASK1       pulse_section       0 or 1
%   TASK2       pulse_section       repeat_pulse_section - 1
%   TASK3       trans_section       0 or 1
%   TASK4       off_section         repeat_off_section
%
% Depending on the characteristics of the pulsed waveform any of the
% Tasks listed above may or not exist. If repeat_pulse_section = 1,
% then TASK3 will not exists. If repeat_pulse_section = 0, neither task
% nor task 2 will exist and Task 3 will become the first task in the
% list carrying the full pulse. this only happens when duration of the
% pulse is lower than the minimum segment length. Task 3 may not exist
% if the overall length of the waveform is a multiple of the minimum
% segment length and the length of the pulse is also a multiple of it.
% Task 4 may bot exist in case Task1, 2 and 3 already implements the
% complete waveform.   

fprintf('CALCULATING EXCITATION PULSE\n');
tic;
[   myWfm,...
    map_wfm,...
    task_list] = proteus_lib.GetPulseWfms(  awg_setup,...
                                            pulse_setup);
toc;

awg_setup.wfm_map = map_wfm;
% Download all segments, build task list, set up DDC, and activate task list
fprintf('DOWNLOADING PULSE WAVEFORM\n');
if awg_setup.iq_mode == proteus_lib.AWG_IQ_MODE_HALF
    result = proteus_lib.SendIqmHalfListToProteus(  awg_setup,...
                                                    myWfm,...
                                                    task_list);
   
elseif awg_setup.iq_mode == proteus_lib.AWG_IQ_MODE_ONE

    result = proteus_lib.SendIqmOneListToProteus(   awg_setup,...
                                                    myWfm,...
                                                    task_list);     
end

% Setup and Arm Trigger

if ext_trig ~= proteus_lib.TASK_EVENT_NONE
    proteus_lib.SetExtTriggerAwg(awg_setup);
end

clear myWfm;

% -------------------------------------
% Operate the ADC with direct functions
% -------------------------------------    

%DIGITIZER SECTION 

fprintf('ACQUISITION STARTS\n');

% Coherent operation of NCOs in DUC and DDC activation if required
if sync_nco
    inst.SendScpi(':DIG:DDC:CLKS AWG');
end
% Get all frames from digitizer
fprintf('Acquired Waveforms Upload to Computer Starts\n');
%tic;

output_wfm_length = round(dig_setup.frame_length / total_decim);

acq_wfm = zeros(1, output_wfm_length);
acq_wfm = complex(acq_wfm);

hold_flag = true;
for acq_num = 1:num_of_avg
    fprintf('Acquisition #%d of %d\n', acq_num, num_of_avg);
    current_wfm = proteus_lib.GetWfmFromProteusDig(dig_setup);
    current_wfm = proteus_lib.InterleavedToComplex(current_wfm);
    % plot(real(current_wfm));
    % if hold_flag
    %     hold;
    %     holf_flag = false;
    % end
    current_wfm = proteus_lib.BoxcarDecimation(current_wfm, box_decimation, box_f_ratio);
    current_wfm = proteus_lib.ResamplingDirect(     current_wfm, ...
                                                output_wfm_length, ...
                                                true);
    acq_wfm = acq_wfm + current_wfm;
end

acq_wfm = acq_wfm / num_of_avg;

fprintf('Acquired Waveforms Upload to Computer Ends\n'); 

% formatting of wfm data
%acq_wfm = proteus_lib.InterleavedToComplex(acq_wfm);
%acq_wfm = proteus_lib.SamplesToFrames(acq_wfm, dig_setup.frame_length);

% total_decim         = 10000;
% box_decimation      = 1000;
% box_f_ratio         = 1;

% DECIMATION
%fprintf('Acquired Waveform Decimation Starts\n');
%tic;



%toc;
fprintf('Acquired Waveform Decimation Ends\n');

tiledlayout(1,2);

ax1 = nexttile;

x_wfm = 0:(length(acq_wfm) - 1);

x_wfm = x_wfm / dig_setup.sampling_rate * dig_setup.ddc_decim * total_decim;

plot(ax1, x_wfm, real(acq_wfm), x_wfm, imag(acq_wfm));
xlim([x_wfm(1) x_wfm(length(x_wfm))]);

title(ax1,'Acq Waveform');    
xlabel(ax1,'Sec') 
ylabel(ax1,'lvls') 
grid(ax1,'on')

ax2 = nexttile;

pSpec = abs(fft(conj(acq_wfm)));
%pSpec = real(fft(acq_wfm));
pSpec = circshift(pSpec,round(length(pSpec) /2));

startF = - freq_domain_span/2;
stopF = startF + freq_domain_span;

samplingRateDig = dig_setup.sampling_rate / (dig_setup.ddc_decim * total_decim);

xData = 0:(length(acq_wfm) - 1);
xData = xData * samplingRateDig / length(acq_wfm);
xData = xData - samplingRateDig / 2;

pSpec = pSpec(find(xData >= startF & xData <= stopF));
xData = xData(find(xData >= startF & xData <= stopF));
    
%pSpec = 20 * log10(pSpec / max(pSpec));

plot(ax2, xData, pSpec);

title(ax2,'Acq Waveform Spectrum');    
xlabel(ax2,'Hz') 
ylabel(ax2,'dB') 
grid(ax2,'on')

%*************************************
%*          SNR CALCULATION          *
%*************************************

stop_sample = length(acq_wfm);

start_sample =stop_sample - round(length(acq_wfm) * snr_wfm_fraction/100);
noise_amp = std(acq_wfm(start_sample:stop_sample));

peak_amp = max(abs(acq_wfm));

snr = 20.0 * log10(peak_amp / noise_amp);

title(ax1,sprintf('Acq Waveform, SNR = %fdB', snr));


proteus_lib.DisconnectFromProteus();
clear inst;

fprintf('END\n');

clear proteus_lib;