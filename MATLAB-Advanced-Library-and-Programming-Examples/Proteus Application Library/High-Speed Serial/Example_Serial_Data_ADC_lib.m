%**************************************************************************
%*                                                                        *
%*                       High_Speed Serial Generation                     *
%*                                                                        *
%*                            TABOR ELECTRONICS                           *
%*                       Author: Joan Mercadé (C) 2024                    *
%*                                                                        *
%**************************************************************************

% This script generates any standard PRBs sequence with any number of bits.
% Baud rate and sample rate can be set independently and they don't have to
% be a multiple. The script can also inject different types of jitter, even
% simultanoeusly. Supported jitter types are sinusoidal (multiple
% components), random (Gaussian distribution), SSC (Spread Spectrum Clock)
% with triangular profile, and multi-tone with minimum peak to rms jitter
% ratio. Edge shape can be set to gaussian, exponential, linear, and
% cosine. Rise time should be at least 1.8 times the sampling period for
% precide edge positioning and jitter quality.
% The serial data and clock signals are acquired by the Proteus Digitizer
% and processed to obtain an equivalent-time acquisition with high timing
% resolution. The resulting acquisition is shown as an eye diagram and
% jitter for the serial data waveform is measured.

clear;
close all;
clear variables;
clear global;
clc;

% CREATE PROTEUS OBJECTS
proteus_lib     = TEProteusLib();
awg_setup       = proteus_lib.CreateDefaultAwgSetup();
dig_setup       = proteus_lib.CreateDefaultDigSetup();
pulse_setup     = proteus_lib.CreateDefaultPulseSetup();
eq_time_setup   = proteus_lib.CreateDefaultEqTimeSetup(); 

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
proteus_lib.ip_addr         = '127.0.0.1'; % '127.0.0.1' = Local Host, your IP address here
proteus_lib.pxi_slot        = 0; % Set 0 to select slot from attached modules
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

% DATA CONFIG
baud_rate           = 1E9;
prbs_seq            = proteus_lib.PRBS_12;
% DATA_TYPE_BILVL_NRZ
% DATA_TYPE_BILVL_RZ
% DATA_TYPE_PAM3
% DATA_TYPE_PAM4
% DATA_TYPE_PAM8
data_wfm_type       = proteus_lib.DATA_TYPE_BILVL_NRZ;

% PULSE_EDGE_LINEAR
% PULSE_EDGE_GAUSSIAN
edge_shape          = proteus_lib.PULSE_EDGE_GAUSSIAN;
rise_time           = 0.25 / baud_rate; 
data_ch             = 1;
data_segm           = 1;
clk_ch              = 3;
clk_div             = 2;
clk_segm            = 1;
sample_rate         = 9E9;
interp_factor       = 1;
signal_ampl         = 0.4; % Negative values for MAX
granularity         = 32;
dac_resolution      = 16;

seed                = [1,zeros(1, prbs_seq -1)];
bits_per_symbol     = proteus_lib.GetSerialBitsPerSymbol(data_wfm_type);
num_of_bits         = clk_div * (2^prbs_seq - 1); % Even number for perfect clock
num_of_bits         = num_of_bits * bits_per_symbol;

% ADC settings
adc_sample_rate     = 2.6987654E9;
adc_num_of_bits     = 10 * num_of_bits;

% Visualization Data
eq_time_size        = 3.0; % In UI units
eq_time_delay       = 0.60; % In UI units
eq_time_clk_int     = false; % Clock interpolation
eq_time_all_edges   = false;
% Eye Diagram and Jitter Analysis
show_color_grade    = false;
show_jitter         = true;
jitter_box_size     = 0.005; % Volts
jitter_box_offset   = 0.0;
jitter_box_width    = 0.40; %UI
use_right_crossing  = true;
optimize_jitter     = true;

% Sample Rate and DAC mode must be made consistent
if sample_rate / interp_factor > 2.5E9
    interp_factor   = 1;
    dac_resolution  = 8;
    granularity     = 64;
end

% AWG Parameters
awg_setup.sel_module        = proteus_lib.PROTEUS_MODULE_01;
awg_setup.sampling_rate     = sample_rate;
awg_setup.interpol          = interp_factor;
awg_setup.dac_resolution    = dac_resolution;
awg_setup.volt              = signal_ampl;
awg_setup.mode              = proteus_lib.AWG_MODE_DIRECT;

% Basic Pulse Parameters
pulse_setup.prbs_seq        = prbs_seq;
pulse_setup.data_wfm_type   = data_wfm_type;
pulse_setup.pulse_type      = proteus_lib.PULSE_TYPE_TRAPEZOIDAL;
pulse_setup.edge_shape      = edge_shape;
pulse_setup.pulse_width     = 1 / baud_rate; % 1 / Baud Rate
pulse_setup.rise_time       = rise_time;
pulse_setup.sampling_rate   = awg_setup.sampling_rate / awg_setup.interpol;
pulse_setup.granul          = 1;
pulse_setup.quality         = 2;

% Jitter settings
% ***************
pulse_setup.jit_unit        = proteus_lib.PULSE_JITTER_UNIT_UI;
% Sinusoidal Jitter
pulse_setup.jit_enable(proteus_lib.PULSE_JITTER_CAT_SINE)     = false;
pulse_setup.jit_sine_freq   = [500E3, 1000E3];
pulse_setup.jit_sine_ampl   = [0.1, 0.1];
% Random (Gaussian) Jitter
pulse_setup.jit_enable(proteus_lib.PULSE_JITTER_CAT_RAND)     = false;
pulse_setup.jit_rnd_freq    = 50E6;
pulse_setup.jit_rnd_ampl    = 0.1;
% SSC (Spread Spectrum Clock), Triangular
pulse_setup.jit_enable(proteus_lib.PULSE_JITTER_CAT_SSC)      = false;
pulse_setup.jit_ssc_freq    = 50E3;
pulse_setup.jit_ssc_dev     = 20000; %ppm 10,000 = 1%
% Multitone (Newman phase distribution for minimum peak jitter)
pulse_setup.jit_enable(proteus_lib.PULSE_JITTER_CAT_MTONE)    = false; 
pulse_setup.jit_mtone_tones = 40; 
pulse_setup.jit_mtone_space = 25E3;
pulse_setup.jit_mtone_ampl  = 0.1;

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

% START CALCULATION

clk_rise_time   = 2.5 / adc_sample_rate;

fprintf('\nGetting PRBS data for %d bits\n', num_of_bits);
tic;
prbs_data                = proteus_lib.GetStdPrbsData(  pulse_setup.prbs_seq,...
                                                        seed,...
                                                        num_of_bits,...
                                                        bits_per_symbol);

% prbs_data = myLib.GetRandomData(length(prbs_data), 1);
% prbs_data(1:14:end) = 1;
% prbs_data(1:16:end) = 0;
% prbs_data = zeros(1, length(prbs_data));
% prbs_data(1:7:end) = + 1;
toc;
fprintf('\nGetting Serial Data Waveform\n');
tic;
% Waveform is calculated as a superposition of pulses for "1" bits in the
% data sequence
[   data_wfm_out,...
    sample_rate_out]    = proteus_lib.GetSerialDataWfm( prbs_data,...
                                                        pulse_setup);
toc;
clear prbs_data;
% Calculate final DAC's sample rate to keep accurate timing 
awg_setup.sampling_rate = sample_rate_out * awg_setup.interpol;

fprintf('\nAdapting Waveform for downloading\n');
% The full DAC range is used
% The base waveform is repeated as many times as required so the overall
% number of samples is a multiple of the granularity
tic;
data_wfm_out                = proteus_lib.NormalizeFull(data_wfm_out);
[data_wfm_out, num_reps]    = proteus_lib.WfmAppendGranularity(data_wfm_out, granularity);
toc;

% Jitter Profile is calculated for the granularity-compatible waveform as
% the longer the better
fprintf('\nAdding Jitter Profile for %d samples\n', length(data_wfm_out));
% Jitter profile is calculated and applied if any of the jitter components
% is active. Otherwise, the origibnal waveform is returned.
tic;
[   data_wfm_out,...
    actual_frequency,...
    actual_ssc_frequency] = proteus_lib.GetAndApplyJitter(    data_wfm_out,...
                                                        pulse_setup);
toc;

% SHOW ACTUAL SINUSOIDAL JITTER FREQUENCIES
if  pulse_setup.jit_enable(proteus_lib.PULSE_JITTER_CAT_SINE)
    fprintf('\nSinusoidal Jitter Components:\n');
    fprintf('-----------------------------\n');
    for component = 1:length(actual_frequency)
        if pulse_setup.jit_sine_ampl(component) > 0.0
            fprintf('Component %d, Target Freq: %fKHz, Actual Freq: %fKHz\n',...
                component,...
                pulse_setup.jit_sine_freq(component) / 1000.0,...
                actual_frequency(component) / 1000.0);
        end
    end
end

if  pulse_setup.jit_enable(proteus_lib.PULSE_JITTER_CAT_MTONE)
    fprintf('\nMulti-Tone Jitter Components:\n');
    fprintf('-----------------------------\n');
    for component = 1:length(actual_frequency)
        fprintf('Component %d, Target Freq: %fKHz, Actual Freq: %fKHz\n',...
            component,...
            component * pulse_setup.jit_mtone_space / 1000.0,...
            actual_frequency(component) / 1000.0);    
    end
end

% SHOW ACTUAL SSC SWEEP PERIOD
if pulse_setup.jit_enable(proteus_lib.PULSE_JITTER_CAT_SSC)
    fprintf('\nSSC Jitter Frequency:\n');
    fprintf('-----------------------\n');
    fprintf('SSC Rep. Rate: Target Freq: %fKHz, Actual Freq: %fKHz\n',...
            pulse_setup.jit_ssc_freq / 1000.0,...
            actual_ssc_frequency / 1000.0);
end
fprintf('\n');

% CLOCK (Dclk / 2)
% ****************
fprintf('\nGetting Data Clock/%d Waveform\n', clk_div);
% Clock waveform is made of 10101010... for a even number of bits
tic;
num_of_bits = num_of_bits / proteus_lib.GetSerialBitsPerSymbol(data_wfm_type);
num_of_bits = num_of_bits * proteus_lib.GetOutSymbolsPerSymbol(data_wfm_type);
pulse_setup.rise_time       = clk_rise_time;
pulse_setup.data_wfm_type   = proteus_lib.DATA_TYPE_BILVL_RZ;
pulse_setup.edge_shape      = proteus_lib.PULSE_EDGE_LINEAR;

clk_wfm                     = proteus_lib.GetSerialClkWfm(    num_of_bits,...
                                                        clk_div,...
                                                        pulse_setup);
toc;

fprintf('\nAdapting Clock Waveform for downloading\n');
tic;
clk_wfm = proteus_lib.NormalizeFull(clk_wfm);
clk_wfm = proteus_lib.WfmAppendGranularity(clk_wfm, granularity);
toc;

% Waveform Downloading
% ********************
fprintf(1, '\nDOWNLOADING DATA WAVEFORM FOR CH%d\n', data_ch);
awg_setup.channel   = data_ch;
awg_setup.segment   = data_segm;

proteus_lib.SendWfmToProteus( awg_setup,...
                        data_wfm_out,...
                        true);

clear data_wfm_out;

fprintf(1, 'DOWNLOADING CLOCK WAVEFORM FOR CH%d\n', clk_ch);

awg_setup.channel = clk_ch;
awg_setup.segment = clk_segm;

proteus_lib.SendWfmToProteus(   awg_setup,...
                                clk_wfm,...
                                true);

clear clk_wfm;

%***************************************************
%                    DIGITIZER
%***************************************************
fprintf('\nSetting Digitizer Settings\n');
dig_setup.sampling_rate = adc_sample_rate;
dig_setup.ch_state(1)   = proteus_lib.DIG_CHAN_ENABLE;
dig_setup.ch_state(2)   = proteus_lib.DIG_CHAN_ENABLE;
dig_setup.granul        = proteus_lib.DIG_GRANUL_DUAL;
dig_setup.ddc_decim     = proteus_lib.DIG_DDC_DECIM_NONE; 

% Calculate frame length

time_window             = adc_num_of_bits * pulse_setup.pulse_width;
dig_setup.frame_length  = time_window * adc_sample_rate;
dig_setup.frame_length  = round(dig_setup.frame_length / dig_setup.granul) * dig_setup.granul;

fprintf(1, 'UPLOADING CLOCK AND DATA WAVEFORMS FROM ADC\n');
tic;
acq_wfm = proteus_lib.GetWfmFromProteusDig(dig_setup);
toc;

% Scale Wfms to Voltage
acq_wfm     = proteus_lib.ScaleAdcWfm(    dig_setup,...
                                    acq_wfm, ...                                                       
                                    false);
clk_wfm     = double(acq_wfm(2,:));
clk_wfm     = clk_wfm - mean(clk_wfm);
data_wfm    = double(acq_wfm(1,:));
data_wfm    = data_wfm - mean(data_wfm);

clear acq_wfm;

% Eye Diagram
%************           
eq_time_setup.mode          = proteus_lib.DIG_ET_MODE_EYE_DIAG;
eq_time_setup.clk_int       = eq_time_clk_int;
eq_time_setup.all_edges     = eq_time_all_edges;
eq_time_setup.clk_div       = clk_div;
eq_time_setup.size          = eq_time_size; % UIs
eq_time_setup.delay         = eq_time_delay;
eq_time_setup.sampling_rate = dig_setup.sampling_rate;
eq_time_setup.unit_interval = pulse_setup.pulse_width;

[eye_x, eye_y] = proteus_lib.GetEquivalentTimeAcq(  data_wfm, ...
                                                    clk_wfm, ...
                                                    eq_time_setup);

% Show Eye Diagram (single color or color-graded)
% ***********************************************
if show_color_grade 
    numOfBins = proteus_lib.DIG_ET_EYE_BINS;
    numOfLvls = proteus_lib.DIG_ET_EYE_LVLS;
    % Get xyz map for color-graded eye diagram
    [   xyz_map,...
        max_x, min_x,...
        max_y, min_y] = proteus_lib.GetXyzMap(eye_x, eye_y, numOfBins, numOfLvls);    
    % Set values for axis in the graph
    imageX = [min_x, max_x];
    imageY = [min_y, max_y]; 
    % Draw Graph
    imagesc(imageX, imageY, xyz_map);
    hold;
    % Set vertical values from bottom to top
    set(gca,'YDir','normal'); 
    grid on;
    clear xyz_map;
else  
    % Plot graph directly
    scatter(eye_x, eye_y, 2, 'filled');
    grid on;
    hold      
end

if show_jitter
    % Get jitter from equivalent time acquisition
    % *******************************************
    
    % Box is defined around the expected crossing area of the eye diagram
    if use_right_crossing
        box = [ -jitter_box_size / 2 + jitter_box_offset,...
                jitter_box_size / 2 + jitter_box_offset,...
                pulse_setup.pulse_width * (0.5 - jitter_box_width / 2),... 
                pulse_setup.pulse_width * (0.5 + jitter_box_width / 2)];
    
    else
        box = [ -jitter_box_size / 2 + jitter_box_offset,...
                jitter_box_size / 2 + jitter_box_offset,...
                - pulse_setup.pulse_width * (0.5 + jitter_box_width / 2),... 
                - pulse_setup.pulse_width * (0.5 - jitter_box_width / 2)];
    end
    % Jitter is calculated according to the defined box and the optimization
    % mode
    [   jitter_rms,...
        jitter_pp,...
        box_1,...
        box_2,...
        samples_in_box] = proteus_lib.GetJitter(  eye_x, ...
                                            eye_y, ...
                                            box,...
                                            optimize_jitter);
        % Optimal vertical values for box afre updated
        box(1) = box_1;
        box(2) = box_2;
    
    % Jitter analysis box definiton
    box_data_y = [box(1), box(1), box(2), box(2), box(1)];
    box_data_x = [box(3), box(4), box(4), box(3), box(3)];
    % Box plotted
    plot(box_data_x, box_data_y);   
    % Rms jitter shown close to box
    
    if use_right_crossing
        text(   box(3), box(2),...
                sprintf('JITTER(rms):\n%fps', jitter_rms * 1E12),...
                'HorizontalAlignment','right', 'FontSize', 12);
    else
        text(   box(4), box(2),...
                sprintf('JITTER(rms):\n%fps', jitter_rms * 1E12),...
                'HorizontalAlignment','left', 'FontSize', 12);
    end
end

% Add title and axis labels
title(sprintf('EYE DIAGRAM. BAUD RATE = %fMBAUD', 1E-6 / pulse_setup.pulse_width));
xlabel('time (seconds)') 
ylabel('Volts')
drawnow;

%***************************************************
%***************************************************

% Disconnect, close VISA handle and destroy handle  
proteus_lib.DisconnectFromProteus();

fprintf('END\n');
clear proteus_lib;
clear inst;
%close all;