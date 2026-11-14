%****************************************************************
%*                                                              *
%*                   Fast Decimation Example                    *
%*                                                              *
%*                      TABOR ELECTRONICS                       *
%*                 Author: Joan Mercadé (C) 2025                *
%*                                                              *
%****************************************************************

% Fast decimation apples two steps. The first step consists of a simple
% boxcar moving averaging plus simple decimation. The decimation factor for
% this step should be selected so a good enough flatness within the band of
% interest is accomplished. The second step is an accurate, maximally flat
% frequency response, high stop-band rejection, decimation process. The
% first step is very fast and greatly reduces the time required by the
% accurate decimation process. In this example a single step and two-step
% decimation is applied to the same signal and execution times for each one
% are shown.

% Load Library
fprintf('Loading Libraries\n');
proteus_lib = TEProteusLib();

num_of_cycles           = 1234;
wfm_length              = 3456789;
samples_to_show         = 100;

decimated_wfm_length    = 10000;
fast_decim_ratio        = 5; %5;

% wfm_calculation
% Just a pure sinewave
wfm = 1:wfm_length;
wfm = wfm - 1.0;
wfm = sin(2. * pi * wfm * num_of_cycles / wfm_length);

% Direct decimation
fprintf('\nOne-Step Direct Decimation\n');
tic;
decim_wfm_1 = proteus_lib.ResamplingDirect( wfm, ...
                                            decimated_wfm_length, ...
                                            true);
toc;

% Two-step decimation
fprintf('\nTwo-Step Fast/Direct Decimation\n');
tic;
% Boxcar decination ratio calculation
boxcar_decimation_factor = round(wfm_length / decimated_wfm_length / fast_decim_ratio);
% 1st step: Apply fast decimation
decim_wfm_2 = proteus_lib.BoxcarDecimation( wfm,...
                                            boxcar_decimation_factor,...
                                            1);
% 2nd step: Apply the remaining accurate direct decimation
decim_wfm_2 = proteus_lib.ResamplingDirect( decim_wfm_2, ...
                                            decimated_wfm_length, ...
                                            true);
toc;
fprintf('\n\n');
plot(decim_wfm_1(1:samples_to_show));
hold;
plot(decim_wfm_2(1:samples_to_show));