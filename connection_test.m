
%% P9484M - SCPI COMMAND DIAGNOSTIC + WAVEFORM TEST

clear;
clc;

%% Library setup

repo = fullfile(getenv('USERPROFILE'), ...
    'Documents', ...
    'Proteus_Matlab', ...
    'MATLAB-Advanced-Library-and-Programming-Examples');

library = fullfile(repo, 'Library');

addpath(genpath(library), '-begin');
rehash;

%% Connect

ip = '192.168.2.2';
inst = [];

try

    inst = TEProteusInst(ip, 1);
    inst.Connect();

    fprintf('Connected to P9484M.\n');

    idn = inst.SendScpi('*IDN?');
    fprintf('%s\n', idn.RespStr);

    %% Clear previous errors

    inst.SendCmd('*CLS');

    %% Generate waveform

    fs = 1e9;
    cycles = 16;
    N = 1024;

    n = 0:N-1;
    wave = sin(2*pi*cycles*n/N);

    dac = uint16(round((wave + 1)*32767.5));
    dac = dac(:);

    %% Test configuration commands individually

    commands = {
        ':INST:CHAN 1'
        ':OUTP OFF'
        sprintf(':FREQ:RAST %.0f', fs)
        sprintf(':TRAC:DEF 1,%d', N)
        ':TRAC:SEL 1'
        ':SOUR:FUNC:MODE ARB'
        ':SOUR:FUNC:SEG 1'
        ':SOUR:VOLT 0.2'
    };

    fprintf('\nTesting SCPI commands...\n');

    for k = 1:numel(commands)

        fprintf('\nCommand %d: %s\n', k, commands{k});

        inst.SendCmd(commands{k});

        [err, desc] = inst.QuerySysErr();

        fprintf('Error: %d | %s\n', err, desc);

        if err ~= 0
            error('SCPI command failed: %s', commands{k});
        end

    end

    %% Upload waveform

    fprintf('\nUploading waveform...\n');

    inst.SendBinaryData(':TRAC:DATA 0,', dac, 'uint16');

    [err, desc] = inst.QuerySysErr();

    fprintf('Upload error: %d | %s\n', err, desc);

    assert(err == 0, 'Waveform upload generated an error.');

    %% Verify operation complete

    opc = inst.SendScpi('*OPC?');

    fprintf('Operation complete: %s\n', opc.RespStr);

    %% Enable output only if all checks passed

    fprintf('\nEnabling output...\n');

    inst.SendCmd(':OUTP ON');

    [err, desc] = inst.QuerySysErr();

    fprintf('Output error: %d | %s\n', err, desc);

    assert(err == 0, 'Output configuration failed.');

    fprintf('\nSUCCESS: Waveform output enabled!\n');

    fprintf('Frequency: %.3f MHz\n', cycles*fs/N/1e6);

    fprintf('Sample rate: %.3f GS/s\n', fs/1e9);

    fprintf('Samples: %d\n', N);

    fprintf('\nPress Enter to stop waveform generation.\n');
    pause;

    inst.SendCmd(':OUTP OFF');

catch ME

    fprintf('\nTEST FAILED:\n%s\n', getReport(ME));

    if ~isempty(inst)
        try
            inst.SendCmd(':OUTP OFF');
        catch
        end
    end

end

%% Disconnect

if ~isempty(inst)

    try
        inst.Disconnect();
        fprintf('\nDisconnected successfully.\n');
    catch
        fprintf('\nDisconnect encountered an issue.\n');
    end

    delete(inst);

end
