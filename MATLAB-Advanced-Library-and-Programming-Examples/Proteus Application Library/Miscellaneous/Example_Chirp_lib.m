%****************************************************************
%*                                                              *
%*                 IQ Chirp Calculation Example                 *
%*                                                              *
%*                      TABOR ELECTRONICS                       *
%*                 Author: Joan Mercadé (C) 2024                *
%*                                                              *
%****************************************************************

% Load Library
fprintf('Loading Libraries\n');
proteus_lib = TEProteusLib();
% Create Pulse Setup Variable
pulse_setup = proteus_lib.CreateDefaultPulseSetup();
awg_setup   = proteus_lib.CreateDefaultAwgSetup();
fprintf('Done!\n');

%**************************************************************************
%                           CHIRP PARAMETERS
%**************************************************************************
f1                      = 1E9;     
chirp_bw                = 100.0E6;
pulse_width             = 100E-6;
interval_pulses         = 0.0;


% SIGNAL PARAMETERS FOR CARRIER #1, QAM GENERATION
dac_sampling_rate       = 9E9;
carrier_frequency       = f1 + chirp_bw / 2.0;
iq_mode                 = proteus_lib.AWG_IQ_MODE_ONE;
duc_interpol            = proteus_lib.AWG_INTERPOL_X8;
granularity             = 16;
pulse_type              = proteus_lib.PULSE_TYPE_CHIRP_UP;

% AWG Settings
awg_setup.mode          = proteus_lib.AWG_MODE_DUC;
awg_setup.iq_mode       = iq_mode;
awg_setup.interpol      = duc_interpol;
awg_setup.sampling_rate = dac_sampling_rate;
awg_setup.granularity   = granularity;
awg_setup.channel       = proteus_lib.AWG_CHAN_CH01;
awg_setup.segment       = 1;
awg_setup.volt          = 0.55;
awg_setup.six_db1       = true;
awg_setup.cfr1          = carrier_frequency;

pulse_setup.pulse_width     = 100E-6; % Tau for FID
pulse_setup.pulse_type      = proteus_lib.PULSE_TYPE_CHIRP_UP;
pulse_setup.sampling_rate   = awg_setup.sampling_rate / awg_setup.interpol;
pulse_setup.bandwidth       = chirp_bw;
pulse_setup.granul          = 1; %awg_setup.granularity;

% Calculate Chirp Waveform
fprintf('Calculating Chirp\n');
tic;
my_wfm = proteus_lib.GetIqPulse(  pulse_setup);
out_wfm_length = length(my_wfm);
if interval_pulses > 0.0
    out_wfm_length = interval_pulses + pulse_width;
    out_wfm_length = out_wfm_length * pulse_setup.sampling_rate;
    out_wfm_length = round(out_wfm_length / awg_setup.granularity) * awg_setup.granularity;
end

out_wfm = complex(zeros(1, out_wfm_length));
out_wfm(1:length(my_wfm)) = my_wfm;

% Repeat unitl length is a multiple of granularity
out_wfm = proteus_lib.WfmAppendGranularity(out_wfm, awg_setup.granularity);
toc;
fprintf('Done!\n');

% PLOT RESULTS
fprintf('Plotting Chirp Pulse\n');
tiledlayout(1,2);
    
% Left plot
ax1 = nexttile;
xData = 0:(length(my_wfm) - 1);
xData = xData / pulse_setup.sampling_rate;

plot(ax1, xData, real(my_wfm));
hold;
plot(ax1, xData, imag(my_wfm));

title(ax1,'Time Domain');
xlabel('seconds') 
grid(ax1,'on')

% Right plot
ax2 = nexttile;
xData = 0:(length(my_wfm) - 1);
xData = xData * pulse_setup.sampling_rate / length(my_wfm) - pulse_setup.sampling_rate / 2;
xData = xData + awg_setup.cfr1;

plot(ax2, xData, fftshift(abs(fft(my_wfm))));

title(ax2,'Frequency Domain');
xlabel('Hz')
fprintf('Done!\n');

% Download Waveform

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
fprintf('Connecting to Proteus\n');
proteus_lib.ip_addr         = '127.0.0.1'; % '127.0.0.1' = Local Host, your IP address here
proteus_lib.pxi_slot        = 4; % Set 0 to select slot from attached modules
proteus_lib.com_ifc         = proteus_lib.COMM_IFC_LAN; %"LAN" = VISA or "DLL" = PXI
proteus_lib.paranoia_level  = 2; % 0, 1 or 2

% Instrument setup
[inst, idnstr, slotNumber, serial] = proteus_lib.ConnecToProteus();
% inst handler required to use TEProteusInst.m functions directly

% Report model
fprintf('Connected to: %s, slot: %d\n', idnstr(1), slotNumber(1));

% Reset AWG
fprintf('Resetting Proteus\n');
inst.SendScpi('*CLS;*RST');
fprintf('Done!\n');
fprintf('Downloading Waveform to Proteus. %d Samples\n', length(out_wfm));
tic;
result = proteus_lib.SendIqmOneWfm( awg_setup, out_wfm);
toc;
fprintf('Done!\n');

% Channel #3

fprintf('Setting CH3 for CW Generation. CF = %f MHz\n', f1/1E6);

% AWG Settings
awg_setup.mode                          = proteus_lib.AWG_MODE_NCO;
awg_setup.channel                       = proteus_lib.AWG_CHAN_CH03;
awg_setup.nco_mode                      = proteus_lib.AWG_NCO_MODE_SINGLE;
awg_setup.volt                          = 0.55;
awg_setup.six_db1                       = 1;
awg_setup.cfr1                          = f1;

proteus_lib.SetNco(awg_setup);
%proteus_lib.inst.SendScpi([':FREQ:RAST ' num2str(awg_setup.sampling_rate)]); 

% Disconnect, close VISA handle and destroy handle  
fprintf('Disconnecting from Proteus\n');
proteus_lib.DisconnectFromProteus();
fprintf('Done!\n');
fprintf('END!\n');
clear inst;
%close all;