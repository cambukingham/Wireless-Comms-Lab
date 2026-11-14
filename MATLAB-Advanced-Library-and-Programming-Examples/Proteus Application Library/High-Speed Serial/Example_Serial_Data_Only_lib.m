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

clear;
close all;
clear variables;
clear global;
clc;

% CREATE PROTEUS OBJECTS
proteus_lib = TEProteusLib();
awg_setup   = proteus_lib.CreateDefaultAwgSetup();
pulse_setup = proteus_lib.CreateDefaultPulseSetup();

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

% Sample Rate and DAC mode must be made consistent
if sample_rate / interp_factor > 2.5E9
    interp_factor   = 1;
    dac_resolution  = 8;
    granularity     = 64;
end

% AWG Parameters
awg_setup.sel_module        = proteus_lib.PROTEUS_MODULE_02;
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

clk_rise_time   = 1.8 / sample_rate;

fprintf('\nGetting PRBS data for %d bits\n', num_of_bits);
tic;
prbs_data                = proteus_lib.GetStdPrbsData(  pulse_setup.prbs_seq,...
                                                        seed,...
                                                        num_of_bits,...
                                                        bits_per_symbol);
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

proteus_lib.SendWfmToProteus( awg_setup,...
                        clk_wfm,...
                        true);

clear clk_wfm;

%***************************************************
%***************************************************

% Disconnect, close VISA handle and destroy handle  
proteus_lib.DisconnectFromProteus();

fprintf('END\n');
clear proteus_lib;
clear inst;
%close all;