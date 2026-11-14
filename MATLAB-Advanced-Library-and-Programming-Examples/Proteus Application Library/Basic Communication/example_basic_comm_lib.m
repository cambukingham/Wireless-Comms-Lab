% BASIC EXAMPLE FOR CONNECTION TO PROTEUS USING VISA OR PXI
%==========================================================
% VISA Communications from MATLAB requires the Instrument Control Toolbox

clear;
close all;
clear variables;
clear global;
clc;

% CREATE PROTEUS OBJECT
proteus_lib = TEProteusLib();

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
proteus_lib.ip_addr         = '127.0.0.1'; % '127.0.0.1' = Local Host (default value), your IP address here
proteus_lib.pxi_slot        = 5; % Set 0 (fefault value) to select slot from attached modules
proteus_lib.com_ifc         = proteus_lib.COMM_IFC_DLL; %"LAN" = VISA (default value) or "DLL" = PXI
proteus_lib.paranoia_level  = 2; % 0, 1 or 2

% Instrument setup
[inst, idnstr, slotNumber, serial] = proteus_lib.ConnecToProteus();
% inst handler required to use TEProteusInst.m functions directly

num_of_modules = length(idnstr);

for module = 1:num_of_modules
    fprintf('\n\n==============================================================\n');
    fprintf('Connected to: Module #%d, %s, Serial #: %d, Slot #: %d\n', module, idnstr(module), serial(module), slotNumber(module));
    if proteus_lib.com_ifc == proteus_lib.COMM_IFC_LAN && num_of_modules > 1
        fprintf('Use SCPI command ":INST:ACT:SEL %d" to access this module\n', module);
    end
    fprintf('==============================================================\n');
    
    proteus_lib.SelectModule(module);   

    % Get options using the standard IEEE-488.2 Command
    [optstr, options_txt] = proteus_lib.GetProteusOptions();
    
    for option_num = 1:length(optstr)
        fprintf('\nOption #%2d Installed: %4s : %30s', option_num, char(optstr(option_num)), char(options_txt(option_num)));     
    end
    
    % Get Number of Channels
    numchan = proteus_lib.GetNumOfChannels(idnstr(module));
    fprintf('\n\nNumber of Channels = %d\n', numchan);
    
    % Get min and max sampling rates
    [minsr, maxsr] = proteus_lib.GetAwgSamplingRateRange();
    fprintf('\nMinimum Sample Rate = %f MSamples/sec\n', minsr / 1E6);
    fprintf('Maximum Sample Rate = %f MSamples/sec\n', maxsr / 1E6);

    % Get min and max output voltage
    [minvolt, maxvolt] = proteus_lib.GetAwgVoltageRange();
    fprintf('\nMinimum Voltage = %f mVpp\n', 1000 * minvolt);
    fprintf('Maximum Voltage = %f mVpp\n', 1000 * maxvolt);
    
    % Get granularity
    granul = proteus_lib.GetGranularity(idnstr(module), optstr, 16);
    fprintf('\nGranularity = %d samples\n', granul);
    
    % Get Sample Resolution
    dacres = proteus_lib.GetDacResolution();
    fprintf('\nSample Resolution = %d bits\n', dacres);
end

% Disconnect, close VISA handle and destroy handle  
proteus_lib.DisconnectFromProteus();

clear inst;
close all;