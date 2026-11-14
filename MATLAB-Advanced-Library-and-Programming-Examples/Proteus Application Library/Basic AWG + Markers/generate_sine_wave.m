% This script demonstrates how to generate a 10 MHz sine wave
% using a Tabor Electronics Proteus P9484M arbitrary waveform generator
% and the TEProteusLib library.
%
% To run this script:
% 1. Make sure the TEProteusLib.m and TEProteusInst.m files are in the same
%    directory as this script, or add the path to the files using the
%    addpath function.
% 2. Change the ip_addr variable to the actual IP address of your P9484M.
% 3. Run the script from the MATLAB command window or editor.
%
% The script will connect to the instrument, generate a 10 MHz sine wave,
% send it to the instrument, and then disconnect.

% It is recommended to clear all variables and close all figures before starting
clear;
close all;
clc;

disp('Generating 10 MHz sine wave...');

% Add the path to the TEProteusLib files if they are not in the current folder
% addpath('<path_to_TEProteusLib>');

try
    % Instantiate the TEProteusLib class
    proteus_lib = TEProteusLib();
    
    % Set the connection parameters
    proteus_lib.ip_addr = '127.0.0.1'; % Replace with the actual IP address of the P9484M
    proteus_lib.com_ifc = proteus_lib.COMM_IFC_LAN;
    proteus_lib.paranoia_level = 2; % Use high paranoia level for robust error checking
    
    % Connect to the instrument
    [inst, idn_str, slot_number, ~] = proteus_lib.ConnecToProteus();
    
    % Print the instrument information
    fprintf('Successfully connected to: %s, Slot: %d\n', idn_str, slot_number);
    
catch ME
    fprintf('Error connecting to the instrument: %s\n', ME.message);
    return;
end

try
    % Create a multi-tone setup for a single 10 MHz tone
    mtone_setup = proteus_lib.CreateDefaultMtoneSetup();
    mtone_setup.num_of_tones = 2;
    mtone_setup.spacing = 20E6; % This will be the frequency of the sine wave
    mtone_setup.oversampling = 100;
  
    % Generate the sine wave data
    [sine_wave, sample_rate] = proteus_lib.GetMultiTone(mtone_setup);
    sine_wave = [sine_wave, sine_wave];
    sine_wave = sine_wave / (max(abs(real(sine_wave))));
    
    % AWG setup
    awg_setup = proteus_lib.CreateDefaultAwgSetup();
    awg_setup.channel = 1;
    awg_setup.segment = 1;
    awg_setup.volt = 0.5;
   
    awg_setup.sampling_rate = sample_rate;
    
    % Send the waveform to the instrument
    proteus_lib.SendWfmToProteus(awg_setup, real(sine_wave), true);
    
    fprintf('Sine wave generated successfully.\n');
    
catch ME
    fprintf('Error during sine wave generation: %s\n', ME.message);
end

% Disconnect from the instrument
proteus_lib.DisconnectFromProteus();
fprintf('Disconnected from the instrument.\n');
