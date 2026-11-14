% DUC/DDC COHERENT OPERATION ALGORITHM FOR DUC AND DDC 

clear;
close all;
clear variables;
clear global;
clc;

% CREATE PROTEUS OBJECTS
proteus_lib = TEProteusLib();

% Transceiver Data as Set in the Example
size_nco_dac        = proteus_lib.AWG_NCO_RES_DAC; % 48 in Proteus
size_nco_adc        = proteus_lib.AWG_NCO_RES_ADC; % 32 in Proteus
dac_sampling_rate   = 9E9;
dac_adc_ratio       = 4; % always a power of 2

% Working Frequency. Can be higher than the DAC sampling rate.
carrier_freq        = 2.7E9; % use integer multiple of 1MHz

[   dac_control_freq_reg,...
    adc_control_freq_reg,...
    freq_dac,...
    freq_adc] = proteus_lib.GetFreqRegisters(   carrier_freq, ...
                                                dac_sampling_rate, ...
                                                dac_adc_ratio, ...
                                                size_nco_dac, ...
                                                size_nco_adc);

fprintf('DAC SR: %e, ADC SR: %e, NCO Target Freq: %e\n',...
    dac_sampling_rate, dac_sampling_rate / dac_adc_ratio, carrier_freq);
fprintf('\nDAC Frequency Control Register: %d = %012X Hex\n',...
    dac_control_freq_reg, dac_control_freq_reg);
fprintf('ADC Frequency Control Register: %d = %08X Hex\n',...
    adc_control_freq_reg, adc_control_freq_reg);
fprintf('\nImage Freqs, ADC 1st or 2nd NZ: DUC = %fMHz, DDC = %fMHz\n ',...
    freq_dac, freq_adc);

% ***********************************************************
% *                   GRAPHICAL DEMO                        *
% ***********************************************************

time_graph = 1e-8;
initial_phase = 45.0;
oversampling = 10;

initial_phase = initial_phase * pi / 180.0;

% Four plots
tiledlayout(4,1);

% NCO DAC
nexttile;
carrier_freq = double(dac_control_freq_reg) * dac_sampling_rate / double(2^size_nco_dac);
num_of_points = round(time_graph * dac_sampling_rate) * oversampling;
x_data = 0:(num_of_points - 1);
x_data = x_data /(dac_sampling_rate * oversampling);
y_data = sin(x_data * 2.0 * pi * carrier_freq + initial_phase);
plot(x_data, y_data);
num_of_points = num_of_points / oversampling;
x_data = 0:(num_of_points - 1);
x_data = x_data /dac_sampling_rate;
y_data = sin(x_data * 2.0 * pi * carrier_freq + initial_phase);
hold;
plot(x_data, y_data);
scatter(x_data, y_data);
xlim([0 time_graph]);
title(strcat('NCO DAC. CF:', num2str(carrier_freq / 1E6),'MHz, SR:',...
        num2str(dac_sampling_rate/1E6), 'MS/s'));
xlabel('Seconds');

% NCO ADC
nexttile;
adc_sampling_rate = dac_sampling_rate / dac_adc_ratio;
oversampling_adc = dac_adc_ratio * dac_adc_ratio;
num_of_points = round(time_graph * adc_sampling_rate) * oversampling_adc;
x_data = 0:(num_of_points - 1);
x_data = x_data /(adc_sampling_rate * oversampling_adc);
y_data = sin(x_data * 2.0E6 * pi * freq_adc + initial_phase);
plot(x_data, y_data);
num_of_points = num_of_points / oversampling_adc;
x_data = 0:(num_of_points - 1);
x_data = x_data /adc_sampling_rate;
y_data = sin(x_data * 2.0E6 * pi * freq_adc + initial_phase);
hold;
plot(x_data, y_data);
scatter(x_data, y_data);
xlim([0 time_graph]);
title(strcat('NCO ADC. CF:', num2str(freq_adc),'MHz, SR:',...
        num2str(dac_sampling_rate/1E6/dac_adc_ratio), 'MS/s'));
xlabel('Seconds');

% NCO DAC AFTER UNDERSAMPLING

nexttile;
num_of_points = round(time_graph * dac_sampling_rate) * oversampling;
x_data = 0:(num_of_points - 1);
x_data = x_data /(dac_sampling_rate * oversampling);
y_data = sin(x_data * 2.0 * pi * carrier_freq + initial_phase);
plot(x_data, y_data);
num_of_points = num_of_points / oversampling;
x_data = 0:(num_of_points - 1);
x_data = x_data /dac_sampling_rate;
y_data = sin(x_data * 2.0 * pi * carrier_freq + initial_phase);
hold;
scatter(x_data, y_data);

scatter(x_data(1:dac_adc_ratio:length(x_data)), y_data(1:dac_adc_ratio:length(x_data)), 100, "filled");
xlim([0 time_graph]);

title(strcat('UNDERSAMPLED NCO DAC AT ADC SR:',...
        num2str(dac_sampling_rate/1E6/dac_adc_ratio), 'MS/s'));
xlabel('Seconds');

nexttile;
plot(x_data(1:dac_adc_ratio:length(x_data)), y_data(1:dac_adc_ratio:length(x_data)));
xlim([0 time_graph]);
hold;
scatter(x_data(1:dac_adc_ratio:length(x_data)), y_data(1:dac_adc_ratio:length(x_data)), "filled");
xlim([0 time_graph]);

title('UNDERSAMPLED NCO DAC AS SEEN AS THE ADC = NCO ADC');
xlabel('Seconds');