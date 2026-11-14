% XY_Plot_Example

clear;
close all;
clear variables;
clear global;
clc;

myLib = TEProteusLib();
awg_setup = myLib .CreateDefaultAwgSetup();

% Set AWG settings
awg_setup.sampling_rate         = 2500E6;
awg_setup.interpol              = 1;
awg_setup.dac_resolution        = 16;
awg_setup.volt                  = 0.5;
awg_setup.offset                = 0.0;
awg_setup.mode                  = myLib.AWG_MODE_DIRECT;
% awg_setup.mkr_mode              = proteus_lib.MKR_MODE_TWO;
% awg_setup.mkr1_state            = 1;
% awg_setup.mkr1_volt             = mkrVolt;
% awg_setup.mkr1_offset           = mkrOff;
% awg_setup.mkr2_state            = 1;
% awg_setup.mkr2_volt             = mkrVolt;
% awg_setup.mkr2_offset           = mkrOff;

% Target channels
ch_x    = 1;
seg_x   = 1;
ch_y    = 2;
seg_y   = 2;
z_mkr   = true;
ch_z    = 1;
seg_z   = 1;

fileName = "taborlogo.plt";

[x_coord, y_coord, z_flag] = myLib.ReadPlt(fileName,10,true);

% Get granularity
granul = 32;

% Granularity handling
[x_coord, num_of_reps] = myLib.WfmAppendGranularity(x_coord, granul);
y_coord = myLib.WfmAppendGranularity(y_coord, granul);
z_flag = myLib.WfmAppendGranularity(z_flag, granul);

if z_mkr
    z_flag = myLib.WfmCompress(z_flag, 2);
end

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
myLib.ip_addr = '127.0.0.1'; % '127.0.0.1' = Local Host, your IP address here
myLib.pxi_slot = 0; % Set 0 to select slot from attached modules
myLib.com_ifc = myLib.COMM_IFC_DLL; %"LAN" = VISA or "DLL" = PXI
myLib.paranoia_level = 2; % 0, 1 or 2

% Instrument setup
[inst, idnstr, slotNumber, serial] = myLib.ConnecToProteus();
% inst handler required to use TEProteusInst.m functions directly

% Report model
fprintf('Connected to: %s, slot: %d\n', idnstr(1), slotNumber(1));

% Reset AWG
inst.SendScpi('*CLS;*RST');


if (awg_setup.sampling_rate / awg_setup.interpol) > 2.5E9
    awg_setup.dac_resolution    = 8;
    awg_setup.interpol          = 1;
end

if (awg_setup.sampling_rate / awg_setup.interpol) < 250E6
    awg_setup.interpol          = 1;
end

% Waveform Downloading
    % *******************
    
fprintf(1, 'DOWNLOADING WAVEFORM FOR CH%d\n, X', ch_x);
awg_setup.channel = ch_x;
awg_setup.segment = seg_x;

myLib.SendWfmToProteus( awg_setup,...
                        x_coord,...
                        true);
fprintf(1, 'X WAVEFORM DOWNLOADED!\n');

fprintf(1, 'DOWNLOADING WAVEFORM FOR CH%d\n, Y', ch_y);
awg_setup.channel = ch_y;
awg_setup.segment = seg_y;

myLib.SendWfmToProteus( awg_setup,...
                        y_coord,...
                        true);
fprintf(1, ' Y WAVEFORM DOWNLOADED!\n');

% Disconnect, close VISA handle and destroy handle  
myLib.DisconnectFromProteus();

clear inst;
close all;