%****************************************************************
%*                                                              *
%*                Multi-tone Calculation Example                *
%*                                                              *
%*                      TABOR ELECTRONICS                       *
%*                 Author: Joan Mercadé (C) 2024                *
%*                                                              *
%****************************************************************

% Load Library
myLib = TEProteusLib();

% Create Multi-Tone Setup Variable
multi_tone_setup = myLib.CreateDefaultMtoneSetup();

multi_tone_setup.num_of_tones   = 16;
multi_tone_setup.spacing        = 10.0E6;
multi_tone_setup.notch_start    = 0;
multi_tone_setup.notch_size     = 0;
multi_tone_setup.phase_distr    = myLib.MTONE_PHASE_NEWMAN;
multi_tone_setup.num_of_repeats = 10;

% Other variables
% AWG Parameters
final_sr                        = 1.125E9;
granularity                     = 16;

% CALL MULTI-TONE FUNCTION
[my_wfm, mtone_sr] = myLib.GetMultiTone(multi_tone_setup);
%final_sr = mtone_sr; 

% RESAMPLING
final_wfm_length = floor((length(my_wfm) / mtone_sr) * final_sr);
final_wfm_length = floor(final_wfm_length / granularity) * granularity;
final_sr = final_wfm_length / length(my_wfm) * mtone_sr;

my_wfm = myLib.ResamplingDirect(    my_wfm, ...
                                    final_wfm_length, ...
                                    true);

% PLOT RESULTS
tiledlayout(1,3);
    
% Left plot
ax1 = nexttile;

xData = 0:(length(my_wfm) - 1);
xData = xData / final_sr;

plot(ax1, xData, real(my_wfm));
hold;
plot(ax1, xData, imag(my_wfm));

title(ax1,'Time Domain');
xlabel('seconds') 
grid(ax1,'on')

% Center plot
ax2 = nexttile;

xData = 0:(length(my_wfm) - 1);
xData = xData * final_sr / length(my_wfm) - final_sr / 2;

% Apply flattop window
time_domain_window = flattopwin(length(my_wfm));
time_domain_window = time_domain_window';
my_wfm_fft = my_wfm .* time_domain_window;

plot(ax2, xData, fftshift(abs(fft(my_wfm_fft))));

title(ax2,'Frequency Domain');
xlabel('Hz')

% Right plot
ax3 = nexttile;

[xData, yData, papr] = myLib.CCDF(my_wfm, 100);
semilogy(ax3, xData, yData);
minGraph = min(yData);
% Plot Gaussian CCDF
my_wfm = wgn(2, 10000000, 1.0);
my_wfm = my_wfm(1,:) + 1i * my_wfm(2, :);

[xData, yData, papr2] = myLib.CCDF(my_wfm, 100);
hold;
semilogy(ax3, xData, yData);

title(ax3,sprintf('CCDF. PAPR = %f', papr));
xlabel('dB');
ylabel('%');

ylim([minGraph 100]);