% FREQUENCY RESPOPNSE
%===================================================

clear;
close all;
clear variables;
clear global;
clc;

% CREATE PROTEUS OBJECTS
proteus_lib     = TEProteusLib();
awg_setup       = proteus_lib .CreateDefaultAwgSetup();
scope_setup     = proteus_lib.CreateDefaultInfiniiumSetup();

% Test Parameters
awg_test_chan   = proteus_lib.AWG_CHAN_CH01;
awg_sample_rate = 9E9;
start_freq      = 10E6;
stop_freq       = 2E9;
step_freq       = 10E6;

num_of_cycles   = 100;
freq_res        = 100E3;
min_wfm_size    = 2048;

wfmVolt         = 1.0;
wfmOff          = 0.0;
mkrVolt         = 1.0;
mkrOff          = 0.0;

fprintf(1, 'INITIALIZING SETTINGS\n');

% pid = feature('getpid');
% fprintf(1,'\nProcess ID %d\n',pid);

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
proteus_lib.ip_addr         = '127.0.0.1'; %'192.168.10.48'; % '127.0.0.1' = Local Host, your IP address here
proteus_lib.pxi_slot        = 4; % Set 0 to select slot from attached modules
proteus_lib.com_ifc         = proteus_lib.COMM_IFC_DLL; %"LAN" = VISA or "DLL" = PXI
proteus_lib.paranoia_level  = 2; % 0, 1 or 2

% Instrument setup
[inst, idnstr, slotNumber, serial] = proteus_lib.ConnecToProteus();
% inst handler required to use TEProteusInst.m functions directly

% Report model
fprintf('Connected to: %s, slot: %d\n', idnstr(1), slotNumber(1));
 % Scope session
scope_descriptor = 'TCPIP0::192.168.10.46::inst0::INSTR';
[scope_session, scope_idn] = proteus_lib.ConnectToInfiniium(scope_descriptor);
fprintf('Connected to %s\n', scope_idn);

% Reset AWG
inst.SendScpi('*CLS;*RST');

% Get options using the standard IEEE-488.2 Command
% Get options using the standard IEEE-488.2 Command
optstr = proteus_lib.GetProteusOptions();

% Set AWG settings
awg_setup.sampling_rate         = awg_sample_rate;
awg_setup.interpol              = 1;
awg_setup.dac_resolution        = 16;

if (awg_setup.sampling_rate / awg_setup.interpol) > 2.5E9
    awg_setup.dac_resolution    = 8;
    awg_setup.interpol          = 1;
end

if (awg_setup.sampling_rate / awg_setup.interpol) < 250E6
    awg_setup.interpol          = 1;
end

% Get granularity
granul = proteus_lib.GetGranularity(idnstr(1), optstr, awg_setup.dac_resolution);

fprintf('\nGranularity = %d samples\n', granul);

% % Get Active Channels and Segment #
% [chanList, segmList] = proteus_lib.GetChannels(idnstr(1), awg_setup.sampling_rate / awg_setup.interpol);
% numOfChannels = length(chanList);

% SETTING AWG
fprintf(1, 'SETTING AWG\n');

awg_setup.channel       = awg_test_chan;

awg_setup.volt          = wfmVolt;
awg_setup.offset        = wfmOff;
awg_setup.mode          = proteus_lib.AWG_MODE_DIRECT;
awg_setup.mkr_mode      = proteus_lib.AWG_MKR_MODE_TWO;
awg_setup.mkr1_state    = 1;
awg_setup.mkr1_volt     = mkrVolt;
awg_setup.mkr1_offset   = mkrOff;
awg_setup.mkr2_state    = 1;
awg_setup.mkr2_volt     = mkrVolt;
awg_setup.mkr2_offset   = mkrOff;

mkrDiv = 2;
if awg_setup.dac_resolution == 8
    mkrDiv = 8;
    awg_setup.mkr_mode = proteus_lib.AWG_MKR_MODE_FOUR;
end

%  TEST LOOP
current_freq = start_freq;
time_window         = 1.0 / freq_res;
basic_num_of_samples  = time_window * awg_setup.sampling_rate;
basic_num_of_samples  = round(basic_num_of_samples);

awg_num_of_samples = basic_num_of_samples;
while mod(awg_num_of_samples, granul) ~= 0
    awg_num_of_samples = awg_num_of_samples + basic_num_of_samples;
end

time_window         = awg_num_of_samples / awg_setup.sampling_rate;

% Marker set up
myMkr1 = uint8(zeros(1, awg_num_of_samples / mkrDiv));
myMkr1(1:100) = uint8(1); % Sync marker duration depends on the channel
myMkr2 = rand(1, length(myMkr1)); % Random data is different for each channel
myMkr2 = uint8(myMkr2 > 0.5);
myMkr = proteus_lib.FormatMkr2(awg_setup.dac_resolution, myMkr1, myMkr2);

% Set scope settings

scope_setup.chan_scope  = [1, 3];
scope_setup.volt_pp     = [1.2, 5.0];
scope_setup.time_window = 1.0 / freq_res;
scope_setup.trig_lvl    = -1.0;
scope_setup.trig_pos    = 100.0;
proteus_lib.SetInfiniiumScope(  scope_session,...
                                scope_setup);

init_flag = true;

x_freq = double.empty;
ampl_resp = double.empty;
phas_resp = double.empty;

while current_freq <= stop_freq
    
    num_of_cycles       = round(current_freq * time_window);
    myWfm               = 0:(awg_num_of_samples - 1);
    myWfm               = cos(2 * pi * myWfm * num_of_cycles / awg_num_of_samples);
    actual_freq         = num_of_cycles / time_window
    %myWfm               = proteus_lib.WfmRepeatForMinSize(myWfm, min_wfm_size);   

    % DOWNLOAD
    awg_setup.segment = 1;

    proteus_lib.SendWfmToProteus(   awg_setup,...
                                    myWfm,...
                                    init_flag);   
    if init_flag
        proteus_lib.SendMkrToProteus(awg_setup, myMkr);
    end   
    
    pause(0.01);

    scope_setup.chan_scope = 1;
    scope_wfm = proteus_lib.GetInfiniiumWfm(    scope_session,...
                                                scope_setup);

    % scope_setup.chan_scope = 3;
    % trg_wfm = proteus_lib.GetInfiniiumWfm(    scope_session,...
    %                                             scope_setup);

    num_shown_points = 400;
    xData = 0:(num_shown_points - 1);
    xData = xData * scope_wfm.XIncrement;

    %plot(xData, scope_wfm.YData(1:num_shown_points), xData, trg_wfm.YData(1:num_shown_points));

    valid_scope_samples = 1.0 / scope_wfm.XIncrement * 1.0 / freq_res;
    valid_scope_samples = round(valid_scope_samples);
    fft_wfm = scope_wfm.YData - mean(scope_wfm.YData);
    fft_wfm = fft_wfm(1:valid_scope_samples);
    
    ft_window = flattopwin(valid_scope_samples);
    %ft_window = ft_window';
    
    fft_wfm = fft_wfm .* ft_window;
    mySpec = fft(fft_wfm);    
    % mySpec = mySpec(1:(floor(length(mySpec) / 2)));
    % plot(mySpec);
    % if init_flag
    %     hold;
    % end
    scope_time_window = scope_wfm.XIncrement * length(fft_wfm);
    fft_freq_resolution = (1.0 / scope_wfm.XIncrement) / valid_scope_samples;
    current_bin = actual_freq / fft_freq_resolution;
    current_bin = round(current_bin) + 1;

    %plot(abs(mySpec((current_bin - 5):(current_bin + 5))));

    x_freq = [x_freq, current_freq];

    ampl_resp = [ampl_resp, abs(mySpec(current_bin))];
    phas_resp = [phas_resp, angle(mySpec(current_bin))];


    init_flag = false;
    current_freq = current_freq + step_freq;
end

ampl_resp = 20.0 * log10(ampl_resp);
ampl_resp = ampl_resp - ampl_resp(1);
% plot(x_freq, ampl_resp);
% grid on;
% ylim([-90, 10]);
phas_resp2 = unwrap(phas_resp);
wfm_delay = phas_resp2 ./ x_freq;
wfm_delay = -mean(wfm_delay) / (2 * pi);
%wfm_delay = wfm_delay;
% wfm_delay = phas_resp2(end) - phas_resp2(1);
% wfm_delay = - wfm_delay / (2 * pi *(x_freq(end) - x_freq(1)));
% 
phas_resp2 = phas_resp2 + (wfm_delay * 2 * pi * x_freq);

phas_resp2 = phas_resp2 * 180.0 / pi;
% plot(x_freq, phas_resp2);

% Disconnect, close VISA handle and destroy handle  
proteus_lib.DisconnectFromProteus();
proteus_lib.DisconnectFromInfiniium(scope_session);

tiledlayout(1,2);

ax1 = nexttile;
semilogx(ax1, x_freq, ampl_resp);
title(ax1,sprintf('Frequency Response(Magnitude)'));

xlabel('Hz') 
ylabel('dB') 

grid(ax1,'on');

ylim([-40, 10]);
xlim([x_freq(1), x_freq(end)]);
save("freq_response_complete",'x_freq', 'ampl_resp', 'phas_resp2'); 

ax2 = nexttile;
plot(ax2, x_freq, smooth(phas_resp2, 11));
title(ax2,sprintf('Frequency Response(Phase)'));

xlabel('Hz') 
ylabel('degrees') 

grid(ax2,'on');

%ylim([-40, 10]);

clear inst;
%close all;