% Digital Modulation And Demodulation DEMO
% ========================================

% It generates IQ-modulated RF bursts with an user-selected modulation
% scheme using the DUC and it captures the waveform with the Digitizer
% using the DDC. Once captured, the first complete burst acquired is
% isolated and fully demodulated. Finally, the contellation/phase diagram
% is shown along with the EVM and other modulation quanlity parameters.

clear;
close all;
clear variables;
clear global;
clc;

proteus_lib = TEProteusLib();

awg_setup   = proteus_lib.CreateDefaultAwgSetup();
mod_setup   = proteus_lib.CreateDefaultModSetup();
dig_setup   = proteus_lib.CreateDefaultDigSetup();

% Control Variables
carrier_freq    = 1000E+6;

% PRBS Setting/ Data Generation Setting
chip_rate       = 10E+6;
num_of_chips    = 1024;
roll_off        = 0.35;
% Modulation Scheme
mod_scheme      = proteus_lib.MOD_SCHEME_QPSK;
PRF             = 1E+3; % Pulse repetition frequency

% Data Source
% DATA_SRC_PRBS = PRBS
% DATA_SRC_USER = User defined data
data_src        = proteus_lib.DATA_SRC_PRBS;
usr_data        = uint8([1,0,1,1,0,1,0,0,0]); % Your data here for DATA_SRC_USER
% PRBS
% PRBS_XX = Standard PRBS Seed = 1;
% PRBS_USER = User defined polynomial and seed
prbs_srq        = proteus_lib.PRBS_9; 
usr_polinom     = [1,0,1,0,1,1]; % 1 + x^2 + x^4 + X^5, Valid for PRBS_USER
usr_seed        = 10; %10...., , Valid for PRBS_USER

module          = proteus_lib.PROTEUS_MODULE_01;
channel         = proteus_lib.AWG_CHAN_CH01;
segment         = 1;
dac_sr          = 9E9;
dac_interpol    = proteus_lib.AWG_INTERPOL_X8; 
ext1_trg        = false;
trg_lvl         = 0.0;
wfmVolt         = 1.3;
wfmOff          = 0.0;

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

% Reset AWG
inst.SendScpi('*CLS;*RST');

% Get options using the standard IEEE-488.2 Command
optstr = proteus_lib.GetProteusOptions();

% SETTING AWG
fprintf(1, 'SETTING AWG\n');
awg_setup.sel_module    = proteus_lib.PROTEUS_MODULE_01;
awg_setup.mode          = proteus_lib.AWG_MODE_DUC;
awg_setup.iq_mode       = proteus_lib.AWG_IQ_MODE_ONE; 
awg_setup.cfr1          = carrier_freq;
awg_setup.offset        = wfmOff;

if ext1_trg
    awg_setup.trg_mode      = proteus_lib.AWG_TRG_MODE_TRIG;
    awg_setup.trg_src       = proteus_lib.TASK_EVENT_TRG1;
    awg_setup.trg_slope     = proteus_lib.AWG_TRG_SLOPE_POS;
    awg_setup.trg_count     = num_of_repeats;
    awg_setup.trg_lvl       = trg_lvl;
else
    awg_setup.trg_mode      = proteus_lib.AWG_TRG_MODE_CONT;
end

awg_setup.sampling_rate         = dac_sr;
awg_setup.interpol              = 8; % Remove
awg_setup.dac_resolution        = 16;

if (awg_setup.sampling_rate / awg_setup.interpol) > 2.5E9
    awg_setup.dac_resolution    = 8;
    awg_setup.interpol          = 1;
end

if (awg_setup.sampling_rate / awg_setup.interpol) < 250E6
    awg_setup.interpol          = 1;
end

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

% Get granularity
granul = proteus_lib.GetGranularity(idnstr(awg_setup.sel_module), optstr, awg_setup.dac_resolution);

fprintf('\nGranularity = %d samples\n', granul);

% Get min and max sampling rates
[minsr, maxsr] = proteus_lib.GetAwgSamplingRateRange();
% Check if sample rate is in the valid range, take corrective action if not
if awg_setup.sampling_rate < minsr
    awg_setup.sampling_rate = minsr;    
elseif awg_setup.sampling_rate > maxsr
    awg_setup.sampling_rate = maxsr;
end

fprintf('Sampling Rate = %dGS/s\n', awg_setup.sampling_rate / 1E9);
fprintf('Interpolation Factor = X%d\n', awg_setup.interpol);

% Get min and max output voltage
[minvolt, maxvolt] = proteus_lib.GetAwgVoltageRange();
% Check if voltage is in the valid range, take corrective action if not
if wfmVolt < minvolt
   wfmVolt = minvolt; 
elseif wfmVolt > maxvolt
    wfmVolt = maxvolt;
end

awg_setup.volt = wfmVolt; 

fprintf('Vpp = %dmV\n', wfmVolt * 1E3);

% IFF Pulse Calculation
actual_granularity              = granul / 2;     

% Modulation Settings
mod_setup.mod_type              = mod_scheme;
mod_setup.usr_data              = data_src;
mod_setup.apply_fsk_corr        = false;
mod_setup.num_of_symbols        = num_of_chips;
mod_setup.symbol_rate           = chip_rate;
mod_setup.filter_type           = proteus_lib.MOD_BB_FILTER_SQRT;
mod_setup.roll_off              = roll_off;
mod_setup.oversampling          = 32;

% Calculate baseband complex wfm
[rf_pulse_wfm, sr_bb_in]        = proteus_lib.GetModWfm(mod_setup);

% Resampling must be carrier out for the DUC baseband sampling rate
sample_rate_bb_out = awg_setup.sampling_rate / awg_setup.interpol; 
wfm_length_in = length(rf_pulse_wfm);
%Calculation of lenght of the interpolated waveform
wfm_length_out = floor(wfm_length_in * sample_rate_bb_out /...
    (sr_bb_in * actual_granularity)) * actual_granularity;

%%%%%%%%%%%%%%%%%%%%%       RESAMPLING      %%%%%%%%%%%%%%%%%%%%%%%%%
fprintf(1, 'BASEBAND WAVEFORM RESAMPLING\n');
tic;
wfm_out = proteus_lib.ResamplingDirect(rf_pulse_wfm, wfm_length_out, false);
toc;
%%%%%%%%%%%%%%%%%%%%%%   FINAL WFM SETUP    %%%%%%%%%%%%%%%%%%%%%%%

total_time_window   = 1/PRF;
min_wfm_length      = 64;
total_samples       = sample_rate_bb_out * total_time_window;
total_samples       = total_samples - wfm_length_out;
total_samples       = (total_samples / min_wfm_length) * min_wfm_length;
num_of_reps         = total_samples / min_wfm_length;

dl_wfms             = complex(zeros(1, min_wfm_length));
dl_wfms             = [dl_wfms, wfm_out];
map_wfm             = [min_wfm_length, wfm_length_out];
awg_setup.wfm_map   = map_wfm;

% Task list two dimensional array is created
task_list           = uint32(zeros(2, proteus_lib.TASK_MATRIX_WIDTH)); 
% Task List Population
task_list(1, proteus_lib.TASK_SEGMENT_PTR)   = 2;
task_list(1, proteus_lib.TASK_TYPE)          = proteus_lib.TASK_TYPE_SINGLE;
task_list(1, proteus_lib.TASK_LOOPS)         = 1;
task_list(1, proteus_lib.TASK_NEXT)          = 2;
task_list(1, proteus_lib.TASK_DTR_FLAG)      = 1; 
task_list(1, proteus_lib.TASK_ENABLE_EVENT)  = proteus_lib.TASK_EVENT_NONE;
task_list(1, proteus_lib.TASK_ABORT_EVENT)   = proteus_lib.TASK_EVENT_NONE;

task_list(2, proteus_lib.TASK_SEGMENT_PTR)   = 1;
task_list(2, proteus_lib.TASK_TYPE)          = proteus_lib.TASK_TYPE_SINGLE;
task_list(2, proteus_lib.TASK_LOOPS)         = num_of_reps;
task_list(2, proteus_lib.TASK_NEXT)          = 1;
task_list(2, proteus_lib.TASK_DTR_FLAG)      = 1; 
task_list(2, proteus_lib.TASK_ENABLE_EVENT)  = proteus_lib.TASK_EVENT_NONE;
task_list(2, proteus_lib.TASK_ABORT_EVENT)   = proteus_lib.TASK_EVENT_NONE;
fprintf(1, 'DOWNLOADING WAVEFORM AND TASK LIST\n');
result = proteus_lib.SendIqmOneListToProteus(   awg_setup,...
                                                dl_wfms,...
                                                task_list);

%%%%%%%%%%%%%%%%%%%%%%%%% Digitizer Section %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
multi_acq                       = true;
dig_setup.ch_state(1)           = proteus_lib.DIG_CHAN_DISABLE;
dig_setup.ch_state(2)           = proteus_lib.DIG_CHAN_DISABLE;

% Digitizer Settings
digChan                         = proteus_lib.DIG_CHAN_ONE;
adc_sample_rate                 = 2.7E+9;
sync_nco                        = false;
num_of_frames                   = 1;
acq_time_factor                 = 2;
rollOff                         = roll_off;

[bps, gLim, modName] = proteus_lib.GetModParam(mod_setup.mod_type);    % Get modulation-type-related variables

axislimits = [-gLim gLim];
% M = 16;

cTitle = sprintf('Mod: %s, Carrier: %dMHz, SR: %dMBaud', modName, ...
                  awg_setup.cfr1 / 1E6, ...
                  mod_setup.symbol_rate / 1E6);
                    
constDiagram = comm.ConstellationDiagram('Name',... 
                                         'PROTEUS VSG/VSA DEMO', ...
                                         'Title', cTitle, ...
                                         'ReferenceConstellation',qammod(0:2^bps-1,2^bps), ...
                                         'SamplesPerSymbol', 128,...
                                         'ChannelNames',{'Constellation'}, ...
                                         'ShowLegend',true, ...
                                         'XLimits',axislimits, ...
                                         'YLimits',axislimits, ...)
                                         'EnableMeasurements', true);


fprintf('\nSetting Digitizer Settings\n');

dig_setup.sampling_rate         = adc_sample_rate;
dig_setup.ch_state(digChan)     = proteus_lib.DIG_CHAN_ENABLE;
dig_setup.granul                = proteus_lib.DIG_GRANUL_DUAL;
dig_setup.ddc_decim             = proteus_lib.DIG_DDC_DECIM_X16; 
dig_setup.cfr(digChan)          = awg_setup.cfr1;
dig_setup.trg_src(digChan)      = proteus_lib.DIG_TRG_DTR_CH1;
dig_setup.ddc                   = proteus_lib.DIG_MODE_COMPLEX;
dig_setup.adc_resol             = proteus_lib.DIG_ADC_RESOL_COMPLEX;
dig_setup.clk_src               = proteus_lib.DIG_CLK_SRC_AWG;

if sync_nco
    dig_setup.sampling_rate = awg_setup.sampling_rate / 4;
end

dig_setup.rng(digChan)          = proteus_lib.DIG_RNG_500MV;
dig_setup.num_of_frames         = num_of_frames;
dig_setup.pre_trigger           = 50;

% Frame length calculation for ADC according to pulse width amd pretrigger setting.
adc_granularity                 = dig_setup.granul;
dig_setup.frame_length          = dig_setup.sampling_rate * total_time_window * acq_time_factor;
dig_setup.frame_length          = dig_setup.frame_length / dig_setup.ddc_decim;
dig_setup.frame_length          = 2 * dig_setup.frame_length;
dig_setup.frame_length          = ceil(dig_setup.frame_length / adc_granularity) * adc_granularity;

% Coherent operation of NCOs in DUC and DDC activation if required
if sync_nco
    inst.SendScpi(':DIG:DDC:CLKS AWG');
end

% Get all frames from digitizer
fprintf('Acquired Waveforms Upload to Computer Starts\n');
%tic;

% while true
[acq_wfm, wfm_hdr] = proteus_lib.GetWfmFromProteusDig(dig_setup);

fprintf('Acquired Waveforms Upload to Computer Ends\n');

% formatting of wfm data
fprintf(1, '\nDEMODULATING ACQUIRED WAVEFORM\n');
acq_wfm = proteus_lib.InterleavedToComplex(acq_wfm);
acq_wfm = proteus_lib.SamplesToFrames(acq_wfm, dig_setup.frame_length);
acq_wfm = IsolatePulse(acq_wfm, dig_setup.sampling_rate/dig_setup.ddc_decim, 10E-6);
acq_wfm = conj(acq_wfm);

itemToShow  = round(num_of_chips * 0.9); %num_of_chips;

[rxSig, sps] = MyQpskDemod( dig_setup.sampling_rate/dig_setup.ddc_decim, ...
                            mod_setup.symbol_rate, ...
                            rollOff, ...
                            acq_wfm, ...
                            itemToShow);

% Fine synchronization and final demodulation   
[rxSig, sps] = GetMinEvm2(rxSig, bps, sps);

%[evm, peakEvm] = GetEvm(rxSig(1:sps:end), 1, bps);
lWfm = (itemToShow - 1)*sps;
constDiagram(rxSig(1:lWfm));

% Disconnect, close VISA handle and destroy handle  
proteus_lib.DisconnectFromProteus();

clear inst;
close all;



%% Functions

function out_wfm = IsolatePulse(in_wfm, sample_rate, interval_threshold)
    in_wfm_length = length(in_wfm);
    interval_threshold = round(sample_rate * interval_threshold);
    v_threshold = 100;

    %look fot initial quiet zone
    current_interval = 0;
    current_sample = 0;
    while current_interval < interval_threshold && current_sample < in_wfm_length
        current_sample = current_sample + 1;
        if abs(in_wfm(current_sample)) > v_threshold
            current_interval = 0;
        else
            current_interval = current_interval + 1;
        end
    end

    %look for initial pulse location
    current_sample = current_sample + 1;
    while abs(in_wfm(current_sample)) < v_threshold && current_sample < in_wfm_length
        current_sample = current_sample + 1;
    end

    pulse_start = current_sample;

    %look fot next quiet zone

    current_interval = 0;
    quiet_interval_flag = true;
    while current_interval < interval_threshold && current_sample < in_wfm_length
        current_sample = current_sample + 1;
        if abs(in_wfm(current_sample)) > v_threshold
            current_interval = 0;
            quiet_interval_flag = true;
        else
            current_interval = current_interval + 1;
            if quiet_interval_flag
                pulse_stop = current_sample;
                quiet_interval_flag = false;                
            end
        end
    end

    pulse_stop = pulse_stop - 1;

    out_wfm = in_wfm(pulse_start:pulse_stop);

end

function [rxFilter, filterSpan] = MyRxFilter(alfa)
    sps = 128;
    filterSpan = 25;
    
    rxFilter = comm.RaisedCosineReceiveFilter(...
                                    'InputSamplesPerSymbol',sps, ...
                                    'Shape', 'Square root', ...
                                    'FilterSpanInSymbols', filterSpan, ...
                                    'RolloffFactor', alfa, ...
                                    'DecimationFactor',1);

end

function [evm, peakEvm] = GetQpskEvm(qpskSig, sps)    
    sLen = length(qpskSig);
    symbols = qpskSig(1:sps:sLen);    
    symbols = abs(real(symbols)) + 1i * abs(imag(symbols));
    symbols = symbols - 1.0 - 1.0i;
    symbols = symbols / sqrt(2.0);
    symbols = abs(symbols);
    symbols = power(symbols, 2.0);
    peakEvm = max(symbols);
    evm = sum(symbols);
    evm = evm / sLen;
    evm = power(evm, 0.5);
    evm = evm * 100;
    peakEvm = power(peakEvm, 0.5);
    peakEvm = peakEvm * 100.0;
end

function [constPhase, evMin] = GetQpskPhase(sps, qpskSig)
    constPhase = 0.0;
    evMin = 0.0;
    sLen = length(qpskSig);
    for angle = 0.0:5:90.0
        symbols = qpskSig(1:sps:sLen) * exp(1i * angle * pi / 180.0);
        evm =  GetQpskEvm(symbols, 1);
        if angle == 0.0
            evMin = evm;
        elseif evm < evMin
            evMin = evm;
            constPhase = angle;
        end
    end
end

function [delay, ampl] = GetQpskSymbolDelay(qpskSig, sps)
    minVar = 0.0;
    ampl = 0.0;
    delay = 0;
    sLen = length(qpskSig);
    for i = 1:sps
        symbols = qpskSig(i:sps:sLen);
        varSymb = std(abs(symbols));
        if i == 1
            minVar = varSymb;
            ampl = mean(abs(symbols));
        elseif varSymb < minVar
            minVar = varSymb;
            delay = i - 1;
            ampl = mean(abs(symbols));
        end
    end
end

function [rxSig, sps] = MyQpskDemod(fs, sRate, alfa, rxSig, symbolsToShow)    
    sps = 128;
    
    %rxSig = MyOldResampleWfm(rxSig, 5, fs, sps * sRate);
    rxSig = resample(rxSig,sps * sRate,fs);
  
    [rxFilter, filterSpan] = MyRxFilter(alfa);
    
    rxSig = rxFilter(rxSig');
    
    rxSig = rxSig((sps*filterSpan + 1):(length(rxSig) - sps*filterSpan));
    
    [delay, ampl] = GetQpskSymbolDelay(rxSig, sps);

    rxSig = sqrt(2.0) * rxSig / ampl;
    rxSig = 2.0 * rxSig((delay + 1):end);
   
    [constPhase, evMin] = GetQpskPhase(sps, rxSig);   
  
    rxSig = rxSig * exp(1i * constPhase * pi / 180.0);
    numOfSymbols = floor(length(rxSig) / sps);
    numOfSymbols = numOfSymbols - filterSpan;
    starS = floor (numOfSymbols / 2 - symbolsToShow / 2);
    finalS = starS + symbolsToShow;
    if starS < 0
        starS = 0;
    end
    if finalS >= numOfSymbols
        finalS = numOfSymbols - 1;
    end
    
    starS = starS*sps + 1; 
    finalS = finalS*sps;   
    rxSig = rxSig(starS:finalS);
end

function [evm, peakEvm] = GetEvm(rxSig, sps, bps)    
    sLen = length(rxSig);
    const = 0 : (2^bps - 1);
    const = getIqMap2(const, bps);
    symbols = rxSig(1:sps:sLen);  
    evmPerSymb = zeros(1, length(symbols));
    sLen = length(symbols);
    
    maxI = max(abs(real(const)));
    maxQ = max(abs(imag(const)));
    limImin = real(const) - 1.0;
    limImax = real(const) + 1.0;
    limQmin = imag(const) - 1.0;
    limQmax = imag(const) + 1.0;
    
    limImin(limImin < -maxI) = -100.0 * maxI;
    limImax(limImax > maxI) = 100.0 * maxI;
    limQmin(limQmin < -maxQ) = -100.0 * maxQ;
    limQmax(limQmax > maxQ) = 100.0 * maxQ;
    
    for i = 1:sLen
        currI = real(symbols(i));
        currQ = imag(symbols(i));
        for j = 1: length(const)
            if currI > limImin(j) && currI <= limImax(j) &&...
                    currQ > limQmin(j) && currQ <= limQmax(j)
                evmPerSymb(i) = abs(symbols(i) - const(j)); 
                break;
            end
        end
    end
    
    rmsAmpl = sqrt(sum(power(abs(const), 2.0)) / length(const));
    evmPerSymb = power(evmPerSymb, 2.0);
    peakEvm = max(evmPerSymb);
    evm = sum(evmPerSymb);
    evm = evm / sLen;
    evm = sqrt(evm);
    evm = evm * 100 / rmsAmpl;
    peakEvm = sqrt(peakEvm);
    peakEvm = peakEvm * 100.0 / rmsAmpl;
end

function symbol = getIqMap2(data, bPerS)
    data = mod(data, 2^bPerS);
    
    if bPerS == 5 % QAM32 mapping
        lev = 6;
        data = data + 1;
        data(data > 4) = data(data > 4) + 1;
        data(data > 29) = data(data > 29) + 1; 

    elseif bPerS == 7 % QAM128 mapping      
        lev = 12;
        data = data + 2;
        data(data > 9) = data(data > 9) + 4;
        data(data > 21) = data(data > 21) + 2;
        data(data > 119) = data(data > 119) + 2;
        data(data > 129) = data(data > 129) + 4;

     elseif bPerS == 9 % QAM512 mapping       
        lev = 24;
        data = data + 4;
        data(data > 19) = data(data > 19) + 8;
        data(data > 43) = data(data > 43) + 8;
        data(data > 67) = data(data > 67) + 8;
        data(data > 91) = data(data > 91) + 4;
        data(data > 479) = data(data > 479) + 4;
        data(data > 499) = data(data > 499) + 8;
        data(data > 523) = data(data > 523) + 8;
        data(data > 547) = data(data > 547) + 8;
    elseif bPerS == 3 % 8QPSK mapping
        lev = 1;
        symbI = sin(data * pi / 4);
        symbQ = cos(data * pi / 4);
        
    else
        lev = 2 ^ (bPerS / 2); % QPSK, QAM16, QAM64, QAM256, QAM1024      
    end    
    
    if bPerS == 3
    else
        symbI = floor(data / lev);
        symbQ = mod(data, lev);
        lev = lev / 2 - 0.5;   
        symbI = (symbI - lev) / lev;
        symbQ = (symbQ - lev) / lev;
    end
    symbol = symbI + 1i * symbQ;
    symbol = 2 * lev * symbol;
end

function [optWfm, newSps] = GetMinEvm2(inWfm, bps, sps)

    newSps = 128;
    if sps < 128
        %inWfm = MyOldResampleWfm(inWfm', 20, sps, newSps);
        inWfm = resample(inWfm',newSps,sps);
        inWfm = inWfm';
    else
        newSps = sps;
    end

    ampLimit = 15.0; % Percentage
    ampStep = 0.1;
    angleLimit = 20.0;
    angleStep = 0.1;
    symb = 0 : (2^bps - 1);
    symb = getIqMap2(symb, bps); 
    
    normAmpl = sqrt(sum(power(abs(symb), 2.0) / length(symb)));
    ampl = sqrt(sum(power(abs(inWfm), 2.0) / length(inWfm)));
    
    inWfm = inWfm * normAmpl / ampl;
    
    numOfAmpSteps = ceil(ampLimit / ampStep);
    numOfAngleSteps = ceil(angleLimit / angleStep);
    
    minEvm = 0.0;
    xOpt = 0;
    ampOpt = 0.0;
    rotOpt = 0.0;   
    % Optimal sampling instant search
    % ===============================  
    xVal = 1:newSps;
    yVal = zeros(1, length(xVal));
    for i = 1:newSps
        cWfm = inWfm(i:newSps:end);         
        curEvm = GetEvm(cWfm, 1, bps); 
        yVal(i) = curEvm;
        if i ==1 || curEvm < minEvm
            minEvm = curEvm;
            xOpt = i;                      
        end                 
    end
    % Waveform alignment in time    
    cWfm = inWfm(xOpt:end);  
    % Next searches work with optimally sampled symbols
    symbols = cWfm(1:newSps:end);
    pMin = minEvm;
    
    % Optimal amplitude search
    % ========================  
    xVal = -numOfAmpSteps:numOfAmpSteps;
    yVal = zeros(1, length(xVal));
    i = 0;    
    for k = -numOfAmpSteps:numOfAmpSteps
        i = i + 1;
        cAmpl = 1 + (k * ampStep / 100);
        curEvm = GetEvm(cAmpl * symbols, 1, bps);
        xVal(i) = cAmpl;
        yVal(i) = curEvm;
        if k == -numOfAmpSteps || curEvm < minEvm
            minEvm = curEvm;            
            ampOpt = cAmpl;                  
        end        
    end 
    % Waveform optimally scaled
    cWfm = ampOpt * cWfm;
    % Next searches work with optimal amplitude symbols
    symbols = cWfm(1:newSps:end);
    pMin = minEvm;
    
    % Optimal carrier phase search
    % ============================
    xVal = -numOfAngleSteps:numOfAngleSteps;
    yVal = zeros(1, length(xVal));
    i = 0;
    for angle = -numOfAngleSteps:numOfAngleSteps
        i = i + 1;
        rotVal = exp(1i * angle * angleStep * pi / 180);              
        curEvm = GetEvm(symbols * rotVal, 1, bps);
        xVal(i) = angle * angleStep;
        yVal(i) = curEvm;
        if angle == -numOfAngleSteps || curEvm < minEvm
            minEvm = curEvm;           
            rotOpt = rotVal;        
        end        
    end
    % Waveform optimally rotated   
    optWfm = cWfm * rotOpt;
    % length must be a multiple of the actual samples per symbol
    finaLength = floor(length(optWfm) / newSps) * newSps;
    optWfm = optWfm(1:finaLength);    
end
