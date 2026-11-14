% CALCULATION OF FREQUENCY AND STEP RESPONSES FOR INTERPOLATION FILTERS
% IMPLEMENTED IN PROTEUS. 

clear;
close all;
clear variables;
clear global;
clc;
% Load Library
myLib = TEProteusLib();

% DAC parameters

% PROTEUS INTERPOLATION FACTORS
% AWG_INTERPOL_X1         = 1
% AWG_INTERPOL_X2         = 2
% AWG_INTERPOL_X4         = 4
% AWG_INTERPOL_X8         = 8
interpol_factor = myLib.AWG_INTERPOL_X8;
sampling_rate   = 9E9;

% Pulse parameters

% PULSE_TYPE_SQUARE
% PULSE_TYPE_TRAPEZOIDAL
% PULSE_TYPE_GAUSSIAN
% PULSE_TYPE_NMR_FID
% PULSE_TYPE_CHIRP_UP
% PULSE_TYPE_CHIRP_DOWN
pulse_type      = myLib.PULSE_TYPE_TRAPEZOIDAL;
edge_shape      = myLib.PULSE_EDGE_GAUSSIAN;
pulse_width     = 100E-9;
rise_time       = 2E-9; % Set to 2E9 for no ringing

% Spectrum Display settings
att_limit       = -160;

%*************************************************************************
%                           INTERPOLATION FILTER
%*************************************************************************

flag_invsinc        = false;
% Get Interpolation Filter
my_interpol_filter = myLib.GetInterpolFilter(interpol_factor, flag_invsinc);
% Normalize Interpolation Filter
my_interpol_filter = my_interpol_filter / interpol_factor;

%*************************************************************************
%                           PULSE INTERPOLATION
%*************************************************************************

% Create Pulse Setup Variable and Populate Fields
pulse_setup                 = myLib.CreateDefaultPulseSetup();
pulse_setup.pulse_type      = pulse_type;
pulse_setup.edge_shape      = edge_shape;
pulse_setup.pulse_width     = pulse_width;
pulse_setup.rise_time       = rise_time;
pulse_setup.sampling_rate   = sampling_rate / interpol_factor;
pulse_setup.granul          = 1;
pulse_setup.quality         = 5;
pulse_setup.freq_offset     = 0E6;

% Calculate Pulse Before Interpolation Waveform
my_wfm      = myLib.GetIqPulse(  pulse_setup);
my_wfm      = real(my_wfm);
my_wfm      = [zeros(1,100), my_wfm, zeros(1,100)];
my_wfm      = 2.0 * my_wfm - 1.0;
% Interpolate as Proteus
my_wfm_int  = myLib.ProteusInterpolation(interpol_factor, my_wfm, flag_invsinc);

% Calculate and display maximum peak level for the interpolated waveform
max_after_interpolation = max(abs(my_wfm_int));
fprintf("\nMaximum Absolute Peak after Interpolation = %f\n", max_after_interpolation);

%*************************************************************************
%                           DISPLAY RESULTS
%*************************************************************************

% Calculate Frequency response
[freq_resp, f_data] = freqz(my_interpol_filter,1);
freq_resp           = abs(freq_resp);
freq_resp           = 20.0 * log10(freq_resp);
freq_resp(freq_resp < att_limit) = att_limit;
f_data              = f_data * sampling_rate / (2*pi);

% Calculate x data for pulses
x_data_1    = 1:length(my_wfm);
x_data_1    = x_data_1 - 1;
x_data_1    = x_data_1 / pulse_setup.sampling_rate;
x_data_2    = 1:length(my_wfm_int);
x_data_2    = x_data_2 - 1;
x_data_2    = x_data_2 / sampling_rate;

% Show Frequency Response for Interpolation Filter
tiledlayout(1,2);
ax1 = nexttile;
plot(ax1, f_data, freq_resp);

title(ax1,'Interpolation Filter Response');
xlabel('Hz') 
ylabel('dB') 
grid on;

% Show Pulses Before and After Interpolation
ax2 = nexttile;
plot(ax2, x_data_1, my_wfm);
hold;
scatter(ax2, x_data_1, my_wfm, '.');
plot(ax2, x_data_2, my_wfm_int);
scatter(ax2, x_data_2, my_wfm_int, '.');

title(ax2,'Input and Interpolated Pulses');
xlabel('Seconds') 
ylabel('Amplitude')