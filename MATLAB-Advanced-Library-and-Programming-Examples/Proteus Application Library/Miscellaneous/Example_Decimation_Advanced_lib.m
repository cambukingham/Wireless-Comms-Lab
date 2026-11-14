% Demo for user-defined decimation factor
% ======================================

% This demo generates a shifted modulated carrier at any user-defined
% frequency using Proteus' DUC, captures it with the digitzer, and
% demodulates it using the built-in DDC in the ADC. The main purpose of
% this script is showing how demodulation fails when decimation factor is
% insufficient so the down-converter band is half the carrier frequencyu or
% higher. This demo applies direct real-time decimation through the DDC (16x
% decimation factor) first, and then an additional post-acquisition
% decimation process. Time and frequency domain plots for both complex
% signals are shown.

clear;
close all;
clear variables;
clear global;
clc;

proteus_lib = TEProteusLib();

% Signal Settings
% ***************
carrier_frequency       = 5E6;
shift_freq              = +1E6;
additional_decimation   = 16;

% Main Settings
% *************
awg_channel         = proteus_lib.AWG_CHAN_CH01;
dig_channel         = proteus_lib.DIG_CHAN_ONE;

acq_time_factor     = 2;
dac_sampling_rate   = 9E9;
adc_sampling_rate   = 2.7E9;
adc_granularity     = 48;
dac_granularity     = 16;
adc_interpol        = proteus_lib.AWG_INTERPOL_X8;
dac_interpol        = 16;

% *************

% CREATE PROTEUS OBJECTS
awg_setup   = proteus_lib.CreateDefaultAwgSetup();
dig_setup   = proteus_lib.CreateDefaultDigSetup();

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
proteus_lib.ip_addr         = '192.168.10.59'; % '127.0.0.1' = Local Host, your IP address here
proteus_lib.pxi_slot        = 0; % Set 0 to select slot from attached modules
proteus_lib.com_ifc         = proteus_lib.COMM_IFC_DLL; %"LAN" = VISA or "DLL" = PXI
proteus_lib.paranoia_level  = 2; % 0, 1 or 2

% Instrument setup
[inst, idnstr, slotNumber, serial] = proteus_lib.ConnecToProteus();
% inst handler required to use TEProteusInst.m functions directly

% Report model
fprintf('Connected to: %s, slot: %d\n', idnstr(1), slotNumber(1));

% Reset AWG
inst.SendScpi('*CLS;*RST');

% AWG Settings
awg_setup.mode              = proteus_lib.AWG_MODE_DUC;
awg_setup.iq_mode           = proteus_lib.AWG_IQ_MODE_ONE;
awg_setup.interpol          = adc_interpol;
awg_setup.granularity       = dac_granularity;
awg_setup.min_segment       = 64;
awg_setup.dac_resolution    = proteus_lib.AWG_DAC_MODE_16;
awg_setup.sampling_rate     = 9E9;
awg_setup.channel           = awg_channel;
awg_setup.segment           = 1;
awg_setup.volt              = 0.45;
awg_setup.cfr1              = carrier_frequency;
awg_setup.six_db1           = true;

% Digitizer Settings
dig_setup.ch_state(1)           = proteus_lib.DIG_CHAN_DISABLE;
dig_setup.ch_state(2)           = proteus_lib.DIG_CHAN_DISABLE;
dig_setup.ch_state(dig_channel) = proteus_lib.DIG_CHAN_ENABLE;
dig_setup.cfr(dig_channel)      = awg_setup.cfr1;
dig_setup.ddc                   = proteus_lib.DIG_MODE_COMPLEX;
dig_setup.adc_resol             = proteus_lib.DIG_ADC_RESOL_COMPLEX;
dig_setup.sampling_rate         = adc_sampling_rate;
dig_setup.rng(dig_channel)      = proteus_lib.DIG_RNG_500MV;
dig_setup.num_of_frames         = 1;
dig_setup.pre_trigger           = 50;
dig_setup.ddc_decim             = proteus_lib.DIG_DDC_DECIM_X16;
dig_setup.trg_src(dig_channel)  = proteus_lib.DIG_TRG_CPU;

% Modulation signal calculation
iq_dac_sample_rate  = awg_setup.sampling_rate / awg_setup.interpol;
wfm_length      = (1 / abs(shift_freq)) * iq_dac_sample_rate;
wfm_length      = round(wfm_length / dac_granularity) * dac_granularity;
iq_wfm          = 0:(wfm_length - 1);
iq_wfm          = exp( 2i * pi * iq_wfm /( wfm_length));
if shift_freq < 0
    iq_wfm      = conj(iq_wfm);
end

% Download Waveform TO 
result = proteus_lib.SendIqmOneWfm( awg_setup, iq_wfm);

% DIGITIZER SECTION
% *****************
% frame size calculation
iq_dac_sample_rate      = dig_setup.sampling_rate / dig_setup.ddc_decim;
time_window             = wfm_length / iq_dac_sample_rate;
iq_adc_sample_rate      = dig_setup.sampling_rate / dig_setup.ddc_decim;
adc_wfm_length          = acq_time_factor * time_window * iq_adc_sample_rate;
adc_wfm_length          = round(adc_wfm_length / adc_granularity) * adc_granularity;
dig_setup.frame_length  = adc_wfm_length; %2 * adc_wfm_length;


% Get all frames from digitizer
acq_wfm = proteus_lib.GetWfmFromProteusDig(dig_setup);
% formatting of wfm data
acq_wfm = proteus_lib.InterleavedToComplex(acq_wfm);
acq_wfm = conj(acq_wfm);

% Additional Decimation
decim_wfm_length    = round(adc_wfm_length / additional_decimation);
decim_acq_wfm       = proteus_lib.ResamplingDirect(acq_wfm, decim_wfm_length, false);

% Disconnect, close VISA handle and destroy handle  
proteus_lib.DisconnectFromProteus();

% Show Results
% ************

tiledlayout(2,2);

% Regular Decimation Waveform
ax1 = nexttile;

x_data  = 0:(adc_wfm_length - 1);
x_data  = x_data / iq_dac_sample_rate * 1E6;
plot(ax1, x_data, real(acq_wfm), x_data, imag(acq_wfm));

title(ax1,sprintf('I/Q Wfm. Decimation = %dX',dig_setup.ddc_decim));

xlabel('microseconds');
ylabel('ADC Levels');
%ylim([-8192 8192]); % 15 bits

ax2 = nexttile;
x_data  = 0:(adc_wfm_length - 1);
x_data  = x_data * iq_adc_sample_rate / adc_wfm_length;
x_data = x_data - iq_adc_sample_rate / 2;

t_window = flattopwin(adc_wfm_length);

wfm_spectrum = fft(acq_wfm .* t_window');
wfm_spectrum = fftshift(wfm_spectrum);
wfm_spectrum = abs(wfm_spectrum);
plot(ax2, x_data, wfm_spectrum);

title(ax2,sprintf('Wfm Spectrum. Decimation = %dX', dig_setup.ddc_decim));
xlabel('Hz');

% Extended Decimation Waveform
ax3 = nexttile;

x_data = 0:(decim_wfm_length - 1);
x_data = x_data / iq_dac_sample_rate * additional_decimation * 1E6;
plot(ax3, x_data, real(decim_acq_wfm), x_data, imag(decim_acq_wfm));

title(ax3,sprintf('I/Q Wfm. Decimation = %dX', dig_setup.ddc_decim * additional_decimation));

xlabel('microseconds');
ylabel('ADC Levels');
%ylim([-8192 8192]); % 15 bits

ax4 = nexttile;
x_data  = 0:(decim_wfm_length - 1);
x_data  = x_data * iq_adc_sample_rate / (decim_wfm_length * additional_decimation);
x_data = x_data - iq_adc_sample_rate / (2  * additional_decimation);

t_window = flattopwin(decim_wfm_length);

wfm_spectrum = fft(decim_acq_wfm .* t_window');
wfm_spectrum = fftshift(wfm_spectrum);
wfm_spectrum = abs(wfm_spectrum);
plot(ax4, x_data, wfm_spectrum);

title(ax4,sprintf('Wfm Spectrum. Decimation = %dX', dig_setup.ddc_decim * additional_decimation));
xlabel('Hz');

clear inst;