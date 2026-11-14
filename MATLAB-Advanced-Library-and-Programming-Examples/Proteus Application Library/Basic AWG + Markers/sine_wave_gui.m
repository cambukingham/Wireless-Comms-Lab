% This script creates a GUI for generating a sine wave with a
% Tabor Electronics Proteus P9484M arbitrary waveform generator.

% It is recommended to clear all variables and close all figures before starting
clear;
close all;
clc;

disp('Creating Sine Wave GUI...');

% Create the main figure
fig = uifigure('Name', 'Sine Wave Generator', 'Position', [100 100 350 250]);

% Create Frequency label and edit field
uicontrol(fig, 'Style', 'text', 'Position', [20 200 100 22], 'String', 'Frequency (MHz):');
freq_edit = uicontrol(fig, 'Style', 'edit', 'Position', [130 200 100 22], 'String', '10');

% Create Amplitude label and edit field
uicontrol(fig, 'Style', 'text', 'Position', [20 160 100 22], 'String', 'Amplitude (V):');
amp_edit = uicontrol(fig, 'Style', 'edit', 'Position', [130 160 100 22], 'String', '0.5');

% Create Channel label and dropdown
uicontrol(fig, 'Style', 'text', 'Position', [20 120 100 22], 'String', 'Channel:');
chan_dropdown = uicontrol(fig, 'Style', 'popupmenu', 'Position', [130 120 100 22], 'String', {'1', '2', '3', '4'});

% Create Generate button
generate_button = uicontrol(fig, 'Style', 'pushbutton', 'Position', [130 80 100 40], 'String', 'Generate');
generate_button.Callback = @generate_button_callback;

% Create Status text area
status_text = uicontrol(fig, 'Style', 'text', 'Position', [20 20 310 40], 'String', 'Status: Idle');

% Callback function for the Generate button
function generate_button_callback(~, ~)
    
    status_text.String = 'Status: Generating...';
    drawnow;
    
    try
        % Get the values from the GUI
        frequency = str2double(freq_edit.String) * 1E6;
        amplitude = str2double(amp_edit.String);
        channel = chan_dropdown.Value;
        
        % Validate input
        if isnan(frequency) || isnan(amplitude)
            status_text.String = 'Status: Error - Invalid input.';
            return;
        end
        
        % Add the path to the TEProteusLib files if they are not in the current folder
        % addpath('<path_to_TEProteusLib>');
        
        % Instantiate the TEProteusLib class
        proteus_lib = TEProteusLib();
        
        % Set the connection parameters
        proteus_lib.ip_addr = '192.168.1.150'; % Replace with the actual IP address of the P9484M
        proteus_lib.com_ifc = proteus_lib.COMM_IFC_LAN;
        proteus_lib.paranoia_level = 2; % Use high paranoia level for robust error checking
        
        % Connect to the instrument
        [inst, idn_str, slot_number, ~] = proteus_lib.ConnecToProteus();
        
        % Print the instrument information
        status_text.String = sprintf('Status: Connected to %s, Slot: %d', idn_str, slot_number);
        drawnow;
        
        % Create a multi-tone setup
        mtone_setup = proteus_lib.CreateDefaultMtoneSetup();
        mtone_setup.num_of_tones = 1;
        mtone_setup.spacing = frequency;
        mtone_setup.oversampling = 100;
        
        % Generate the sine wave data
        [sine_wave, sample_rate] = proteus_lib.GetMultiTone(mtone_setup);
        
        % AWG setup
        awg_setup = proteus_lib.CreateDefaultAwgSetup();
        awg_setup.channel = channel;
        awg_setup.segment = 1;
        awg_setup.volt = amplitude;
        awg_setup.sampling_rate = sample_rate;
        
        % Send the waveform to the instrument
        proteus_lib.SendWfmToProteus(awg_setup, sine_wave, true);
        
        status_text.String = 'Status: Sine wave generated successfully.';
        
    catch ME
        status_text.String = sprintf('Status: Error - %s', ME.message);
    end
    
    % Disconnect from the instrument
    if exist('proteus_lib', 'var')
        proteus_lib.DisconnectFromProteus();
        fprintf('Disconnected from the instrument.\n');
    end
end
