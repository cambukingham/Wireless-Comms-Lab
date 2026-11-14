
%% ============================================================
%  TABOR PROTEUS P9484M - CONTINUOUS SINE WAVE GENERATION
%  MATLAB R2024b | Tabor TEProteusInst Library | Ethernet
%
%  Output:
%    Channel       : 1
%    Sample rate   : 1 GS/s
%    Frequency     : 15.625 MHz
%    Segment length: 1024 samples
%    Cycles        : 16
%    Amplitude     : 0.2 V (instrument setting)
%
% ============================================================

clear;
clc;

%% 1. LOAD TABOR LIBRARY

repo = fullfile(getenv('USERPROFILE'), ...
    'Documents', ...
    'Proteus_Matlab', ...
    'MATLAB-Advanced-Library-and-Programming-Examples');

library = fullfile(repo, 'Library');

assert(isfolder(library), 'Tabor library folder not found.');

addpath(genpath(library), '-begin');
rehash;

assert(exist('TEProteusInst', 'class') == 8, ...
    'TEProteusInst class not found.');

fprintf('Tabor library loaded successfully.\n');

%% 2. WAVEFORM PARAMETERS

ip = '192.168.2.2';

channel = 1;
segment = 1;

fs = 1e9;              % 1 GS/s
cycles = 16;
N = 1024;

amplitude = 0.2;       % Output amplitude setting (V)

assert(mod(N,64) == 0, ...
    'Segment length must be a multiple of 64.');

f0 = cycles*fs/N;

fprintf('\nWaveform parameters:\n');
fprintf('Sample rate: %.3f GS/s\n', fs/1e9);
fprintf('Frequency: %.6f MHz\n', f0/1e6);
fprintf('Samples: %d\n', N);
fprintf('Cycles: %d\n', cycles);

%% 3. GENERATE WAVEFORM

n = 0:N-1;

wave = sin(2*pi*cycles*n/N);

% Convert sine wave to unsigned 16-bit DAC values
dac = uint16(round((wave + 1)*32767.5));

% Column vector
dac = dac(:);

fprintf('\nWaveform generated successfully.\n');

%% 4. CONNECT TO PROTEUS

inst = [];
connected = false;

try

    fprintf('\nConnecting to Proteus...\n');

    inst = TEProteusInst(ip, 1);

    inst.Connect();
    connected = true;

    fprintf('Connection established!\n');

    %% 5. IDENTIFY INSTRUMENT

    idnResult = inst.SendScpi('*IDN?');

    assert(idnResult.ErrCode == 0, ...
        'Instrument identification failed.');

    fprintf('\nConnected instrument:\n%s\n', ...
        idnResult.RespStr);

    assert(contains(idnResult.RespStr, 'P9484M'), ...
        'Unexpected instrument model.');

    %% 6. CLEAR STATUS

    fprintf('\nClearing instrument status...\n');

    inst.SendCmd('*CLS');

    %% 7. SELECT CHANNEL

    fprintf('\nSelecting channel %d...\n', channel);

    inst.SendCmd(sprintf(':INST:CHAN %d', channel));

    [err, desc] = inst.QuerySysErr();

    assert(err == 0, ...
        sprintf('Channel selection failed: %s', desc));

    %% 8. DISABLE OUTPUT DURING CONFIGURATION

    inst.SendCmd(':OUTP OFF');

    [err, desc] = inst.QuerySysErr();

    assert(err == 0, ...
        sprintf('Could not disable output: %s', desc));

    %% 9. CONFIGURE SAMPLE RATE

    fprintf('\nSetting sample rate...\n');

    inst.SendCmd(sprintf(':FREQ:RAST %.0f', fs));

    [err, desc] = inst.QuerySysErr();

    assert(err == 0, ...
        sprintf('Sample-rate configuration failed: %s', desc));

    %% 10. ENABLE CONTINUOUS PLAYBACK

    fprintf('Enabling continuous playback...\n');

    inst.SendCmd(':INIT:CONT ON');

    [err, desc] = inst.QuerySysErr();

    assert(err == 0, ...
        sprintf('Continuous mode failed: %s', desc));

    %% 11. DEFINE WAVEFORM MEMORY

    fprintf('\nDefining waveform segment...\n');

    inst.SendCmd(sprintf(':TRAC:DEF %d,%d', segment, N));

    [err, desc] = inst.QuerySysErr();

    assert(err == 0, ...
        sprintf('Segment definition failed: %s', desc));

    %% 12. SELECT WAVEFORM MEMORY

    inst.SendCmd(sprintf(':TRAC:SEL %d', segment));

    [err, desc] = inst.QuerySysErr();

    assert(err == 0, ...
        sprintf('Segment selection failed: %s', desc));

    %% 13. UPLOAD WAVEFORM

    fprintf('\nUploading waveform to Proteus...\n');

    inst.SendBinaryData(':TRAC:DATA 0,', dac, 'uint16');

    fprintf('Binary transfer completed.\n');

    %% 14. WAIT FOR UPLOAD COMPLETION

    opc = inst.SendScpi('*OPC?');

    assert(opc.ErrCode == 0, ...
        'Operation-complete query failed.');

    fprintf('Upload completion response: %s\n', ...
        strtrim(opc.RespStr));

    %% 15. SELECT SEGMENT FOR PLAYBACK

    fprintf('\nSelecting segment for playback...\n');

    % Correct Tabor Proteus segment-selection command
    inst.SendCmd(sprintf(':FUNC:MODE:SEGM %d', segment));

    [err, desc] = inst.QuerySysErr();

    fprintf('Segment selection: %d | %s\n', err, desc);

    assert(err == 0, ...
        sprintf('Playback segment selection failed: %s', desc));

    %% 16. CONFIGURE OUTPUT AMPLITUDE

    fprintf('\nSetting output amplitude...\n');

    inst.SendCmd(sprintf(':SOUR:VOLT %.3f', amplitude));

    [err, desc] = inst.QuerySysErr();

    fprintf('Amplitude setting: %d | %s\n', err, desc);

    assert(err == 0, ...
        sprintf('Amplitude configuration failed: %s', desc));

    %% 17. FINAL ERROR CHECK

    fprintf('\nChecking instrument error queue...\n');

    [err, desc] = inst.QuerySysErr();

    fprintf('Error status: %d | %s\n', err, desc);

    assert(err == 0, ...
        'Instrument reports an error. Output will remain disabled.');

    %% 18. ENABLE OUTPUT

    fprintf('\nEnabling channel output...\n');

    inst.SendCmd(':OUTP ON');

    [err, desc] = inst.QuerySysErr();

    fprintf('Output command: %d | %s\n', err, desc);

    assert(err == 0, ...
        'Output enable failed.');

    %% 19. CONFIRM SUCCESS

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('       WAVEFORM GENERATION ACTIVE       \n');
    fprintf('========================================\n');

    fprintf('Instrument: P9484M\n');
    fprintf('Channel: %d\n', channel);
    fprintf('Frequency: %.6f MHz\n', f0/1e6);
    fprintf('Sample rate: %.3f GS/s\n', fs/1e9);
    fprintf('Samples: %d\n', N);
    fprintf('Cycles: %d\n', cycles);
    fprintf('Amplitude setting: %.3f V\n', amplitude);
    fprintf('Playback: Continuous\n');

    %% 20. KEEP OUTPUT RUNNING

    fprintf('\nWaveform is running continuously.\n');
    fprintf('Press ENTER to stop the waveform.\n');

    input('', 's');

    %% 21. DISABLE OUTPUT

    fprintf('\nDisabling output...\n');

    inst.SendCmd(':OUTP OFF');

    [err, desc] = inst.QuerySysErr();

    fprintf('Output shutdown: %d | %s\n', err, desc);

catch ME

    fprintf('\n========================================\n');
    fprintf('              ERROR OCCURRED            \n');
    fprintf('========================================\n');

    fprintf('%s\n', getReport(ME));

    % Safety shutdown
    if connected

        try
            inst.SendCmd(':OUTP OFF');
            fprintf('\nOutput disabled after error.\n');
        catch
            fprintf('\nCould not confirm output shutdown.\n');
        end

    end

end

%% 22. DISCONNECT

if connected

    fprintf('\nDisconnecting from Proteus...\n');

    try
        inst.Disconnect();
        fprintf('Disconnected successfully.\n');
    catch ME
        fprintf('Disconnect warning: %s\n', ME.message);
    end

    delete(inst);

end

fprintf('\nTest completed.\n');
