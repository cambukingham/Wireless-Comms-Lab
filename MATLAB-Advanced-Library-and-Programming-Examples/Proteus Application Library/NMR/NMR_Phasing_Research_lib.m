% Resampling Research

clear;
close all;
clear variables;
clear global;
clc;

% Waveform Creation
sample_rate = 5E3;

file_name = "benzine10acq_wfm_11_18ThursWed662024.csv";
% file_name = "benzine1acq_wfm_10_39ThursWed662024.csv";
% file_name = "benzine10acq_wfm_11_02ThursWed662024.csv";
% file_name = "benzine10acq_wfm_11_08ThursWed662024.csv";
% file_name = "acq_wfm_10_39ThursWed662024.csv";

test_signal_raw = readmatrix(file_name);
test_signal = test_signal_raw;

% Delay correction
stop_sample = length(test_signal);
start_sample =stop_sample - round(length(test_signal) * 10/100);

threshold = max(abs(real(test_signal(start_sample:stop_sample))));
threshold = 100 * threshold;

shift_factor = 0;

while abs(test_signal(shift_factor + 1)) < threshold && shift_factor <= stop_sample
    shift_factor = shift_factor + 1;
end


length_signal = length(test_signal);

test_signal = circshift(test_signal,-shift_factor);

% Phase Correction
final_phase_correction = 0.0;
init_flag = true;
pSpec_raw = fft(test_signal);
pSpec_raw = fftshift(pSpec_raw);
min_ratio = 1.0;

for phase_correction = -180:180   
    
    pSpec = exp(1i*phase_correction / 180) * pSpec_raw;

    pSpec = real(pSpec);

    num_sample_pos = sum(pSpec(pSpec > 0.0).^2);
    num_sample_neg = sum(pSpec(pSpec < 0.0).^2);

    if num_sample_pos > num_sample_neg
        current_ratio = num_sample_neg / num_sample_pos;
    else
        current_ratio = num_sample_pos / num_sample_neg;
    end

    if init_flag || current_ratio < min_ratio
        init_flag = false;
        min_ratio = current_ratio;
        final_phase_correction = phase_correction;
    end   
end
%final_phase_correction = -153.0
pSpec = exp(1i*final_phase_correction / 180) * pSpec_raw;

freq_domain_span = 1000;
    
startF = - freq_domain_span/2;
stopF = startF + freq_domain_span;

samplingRateDig = sample_rate;

xData = 0:(length(test_signal) - 1);
xData = xData * samplingRateDig / length(test_signal);
xData = xData - samplingRateDig / 2;

pSpec = pSpec(find(xData >= startF & xData <= stopF));
xData = xData(find(xData >= startF & xData <= stopF));
    
%pSpec = 20 * log10(pSpec / max(pSpec));

%plot(xData, abs(pSpec));
%hold;
plot(xData, real(pSpec));
hold;
plot(xData, imag(pSpec));
title(sprintf('Acq Waveform Spectrum, Corr. Angle = %fº, Corr. Delay = %fms', final_phase_correction, 1000 * shift_factor / sample_rate));
xlabel('Hz') 
ylabel('AU') 
grid('on')
drawnow;
pause(1);


function out_wfm = boxcar_decimation(input_wfm, decimation, sample_ratio)

    out_sample = 1;

    out_wfm = zeros(1, floor(length(input_wfm) / decimation));

    final_sample = length(input_wfm) - decimation * sample_ratio;
    integration_size = decimation * sample_ratio - 1;

    for current_sample = 1:decimation:final_sample 
        out_wfm(out_sample) = sum(input_wfm(current_sample:(current_sample + integration_size)));
        out_sample = out_sample + 1;
    end
    a = 1;
end

function out_wfm = boxcar_decimation2(input_wfm, decimation, sample_ratio)

    out_sample = 1;

    input_wfm = single(input_wfm);
    out_wfm = zeros(1, floor(length(input_wfm) / decimation));
    out_wfm = single(out_wfm);

    final_sample = length(input_wfm) - decimation * sample_ratio;
    integration_size = decimation * sample_ratio - 1;

    for current_sample = 1:decimation:final_sample 
        out_wfm(out_sample) = sum(input_wfm(current_sample:(current_sample + integration_size)));
        out_sample = out_sample + 1;
    end
end

function out_wfm = boxcar_decimation3(input_wfm, decimation, sample_ratio)
    out_wfm = boxcar_decimation2(real(input_wfm), decimation, sample_ratio);
    out_wfm = out_wfm + 1i * boxcar_decimation2(imag(input_wfm), decimation, sample_ratio);
end