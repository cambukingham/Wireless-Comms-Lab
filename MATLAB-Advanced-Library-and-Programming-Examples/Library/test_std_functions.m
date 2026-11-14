% It is recommended to clear all variables and close all figures before starting
clear;
close all;
clc;

% Instantiate the TEProteusLib class
proteus_lib = TEProteusLib();

% Signal parameters
type_of_signal  = proteus_lib.STD_FUNC_SINE;
freq            = 10E6;
phase           = 0.0;
duty_cycle      = 50.0;
num_of_cycles   = 10;
oversampling    = 100;
granularity     = 32;

[waveform, Fs] = proteus_lib.GetStdWfm( type_of_signal,...
                                        freq,...
                                        phase,...
                                        duty_cycle,...
                                        num_of_cycles,...
                                        oversampling,...
                                        granularity);

plot(waveform)
grid on