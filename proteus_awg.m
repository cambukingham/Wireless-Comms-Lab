
function info = proteus_awg(type, varargin)
% ============================================================
% PROTEUS_AWG
% General-purpose waveform generator for Tabor Proteus P9484M
%
% Supported:
%   sine, square, ramp, triangle, pulse, bpsk
%
% Example:
%   proteus_awg('sine')
%   proteus_awg('square','Frequency',10e6)
%   proteus_awg('ramp','Frequency',5e6)
%   proteus_awg('triangle','Amplitude',0.5)
%   proteus_awg('pulse','Duty',0.25)
%   proteus_awg('bpsk','Bits',[0 1 1 0], ...
%       'SymbolRate',15.625e6)
%
% ============================================================

%% 1. INPUT PARAMETERS

p = inputParser;

addParameter(p,'IP','192.168.2.2');
addParameter(p,'Channel',1);
addParameter(p,'Segment',1);

addParameter(p,'SampleRate',1e9);
addParameter(p,'Frequency',[]);
addParameter(p,'Samples',1024);
addParameter(p,'Amplitude',0.2);

addParameter(p,'Duty',0.5);
addParameter(p,'Bits',[]);
addParameter(p,'SymbolRate',[]);

parse(p,varargin{:});

opt = p.Results;

%% 2. LOAD TABOR LIBRARY

repo = fullfile(getenv('USERPROFILE'), ...
    'Documents', ...
    'Proteus_Matlab', ...
    'MATLAB-Advanced-Library-and-Programming-Examples');

library = fullfile(repo,'Library');

assert(isfolder(library), ...
    'Tabor library folder not found.');

addpath(genpath(library),'-begin');
rehash;

assert(exist('TEProteusInst','class') == 8, ...
    'TEProteusInst class not found.');

%% 3. VALIDATE PARAMETERS

fs = opt.SampleRate;
N = opt.Samples;

assert(isnumeric(fs) && isscalar(fs) && isfinite(fs) && fs > 0, ...
    'SampleRate must be a positive finite number.');

assert(isnumeric(N) && isscalar(N) && isfinite(N) && ...
    N >= 1024 && N == floor(N), ...
    'Samples must be an integer of at least 1024.');

assert(mod(N,64) == 0, ...
    'Samples must be a multiple of 64.');

assert(isnumeric(opt.Amplitude) && isscalar(opt.Amplitude) && ...
    isfinite(opt.Amplitude) && opt.Amplitude > 0, ...
    'Amplitude must be positive.');

assert(isnumeric(opt.Channel) && isscalar(opt.Channel) && ...
    opt.Channel >= 1 && opt.Channel == floor(opt.Channel), ...
    'Invalid channel.');

assert(isnumeric(opt.Segment) && isscalar(opt.Segment) && ...
    opt.Segment >= 1 && opt.Segment == floor(opt.Segment), ...
    'Invalid segment.');

% Default to 16 cycles across the segment
if isempty(opt.Frequency)
    opt.Frequency = 16*fs/N;
end

f = opt.Frequency;

assert(isnumeric(f) && isscalar(f) && isfinite(f) && ...
    f > 0 && f < fs/2, ...
    'Frequency must be positive and below Nyquist frequency.');

% Calculate cycles per segment
numCycles = f*N/fs;

if abs(numCycles-round(numCycles)) > 1e-9
    warning(['Waveform does not contain an integer number of cycles. ', ...
             'A phase discontinuity may occur at the repetition boundary.']);
end
%% 4. GENERATE TIME VECTOR

n = 0:N-1;
t = n/fs;

phase = mod(f*t,1);

type = lower(char(type));

%% 5. GENERATE SELECTED WAVEFORM

switch type

    case 'sine'

        wave = sin(2*pi*f*t);

    case 'square'

        wave = ones(1,N);

        wave(phase >= opt.Duty) = -1;

    case 'ramp'

        wave = 2*phase-1;

    case 'triangle'

        wave = 1-4*abs(phase-0.5);

    case 'pulse'

        wave = -ones(1,N);

        wave(phase < opt.Duty) = 1;

    case 'bpsk'

        % Samples per symbol
        assert(~isempty(opt.SymbolRate), ...
            'Specify SymbolRate for BPSK.');

        spsExact = fs/opt.SymbolRate;
        sps = round(spsExact);

        assert(sps >= 1 && abs(spsExact-sps) < 1e-9, ...
            'SampleRate/SymbolRate must be an integer.');

        numSymbols = N/sps;

        assert(numSymbols == floor(numSymbols), ...
            'Samples must contain a whole number of symbols.');

        % Default alternating binary sequence
        bits = opt.Bits;

        if isempty(bits)
            bits = mod(0:numSymbols-1,2);
        end

        bits = double(bits(:).');

        assert(numel(bits) == numSymbols, ...
            'Bits must contain exactly Samples/(SampleRate/SymbolRate) bits.');

        assert(all(bits == 0 | bits == 1), ...
            'BPSK bits must contain only zeros and ones.');

        % Map 0 -> phase 0, 1 -> phase pi
        symbols = 1-2*bits;

        symbolIndex = floor(n/sps)+1;

        carrier = sin(2*pi*f*t);

        wave = carrier .* symbols(symbolIndex);

    otherwise

        error(['Unknown waveform type: ',type, ...
            '. Use sine, square, ramp, triangle, pulse or bpsk.']);

end

%% 6. CONVERT TO DAC FORMAT

% Normalize waveform to 16-bit unsigned DAC values
wave = max(-1,min(1,wave));

dac = uint16(round((wave+1)*32767.5));

dac = dac(:);

%% 7. DISPLAY PARAMETERS

fprintf('\n====================================\n');
fprintf('       PROTEUS WAVEFORM GENERATOR    \n');
fprintf('====================================\n');

fprintf('Waveform: %s\n',type);
fprintf('Sample rate: %.3f GS/s\n',fs/1e9);
fprintf('Frequency: %.6f MHz\n',f/1e6);
fprintf('Samples: %d\n',N);
fprintf('Amplitude setting: %.3f V\n',opt.Amplitude);
fprintf('Channel: %d\n',opt.Channel);
fprintf('Segment: %d\n',opt.Segment);

if strcmp(type,'bpsk')
    fprintf('Symbol rate: %.6f MHz\n',opt.SymbolRate/1e6);
    fprintf('Bits: ');
    fprintf('%d ',bits);
    fprintf('\n');
end

%% 8. CONNECT AND PROGRAM INSTRUMENT

inst = [];
connected = false;

try

    fprintf('\nConnecting to P9484M...\n');

    inst = TEProteusInst(opt.IP,1);
    inst.Connect();

    connected = true;

    fprintf('Connection established.\n');

    %% Identify instrument

    idn = inst.SendScpi('*IDN?');

    assert(idn.ErrCode == 0, ...
        'Instrument identification failed.');

    fprintf('Instrument: %s\n',idn.RespStr);

    assert(contains(idn.RespStr,'P9484M'), ...
        'Unexpected instrument model.');

    %% Clear status

    inst.SendCmd('*CLS');

    %% Select channel and disable output

    inst.SendCmd(sprintf(':INST:CHAN %d',opt.Channel));
    checkError(inst,'Channel selection');

    inst.SendCmd(':OUTP OFF');
    checkError(inst,'Output disable');

    %% Set sample rate

    inst.SendCmd(sprintf(':FREQ:RAST %.0f',fs));
    checkError(inst,'Sample rate');

    %% Continuous playback

    inst.SendCmd(':INIT:CONT ON');
    checkError(inst,'Continuous playback');

    %% Define memory segment

    inst.SendCmd(sprintf(':TRAC:DEF %d,%d',opt.Segment,N));
    checkError(inst,'Segment definition');

    inst.SendCmd(sprintf(':TRAC:SEL %d',opt.Segment));
    checkError(inst,'Segment selection');

    %% Upload waveform

    fprintf('\nUploading waveform...\n');

    inst.SendBinaryData(':TRAC:DATA 0,',dac,'uint16');

    fprintf('Waveform upload completed.\n');

    %% Wait for completion

    opc = inst.SendScpi('*OPC?');

    assert(opc.ErrCode == 0, ...
        'Upload completion query failed.');

    fprintf('Operation complete: %s\n',strtrim(opc.RespStr));

    %% Select playback segment

    inst.SendCmd(sprintf(':FUNC:MODE:SEGM %d',opt.Segment));
    checkError(inst,'Playback segment');

    %% Set output amplitude

    inst.SendCmd(sprintf(':SOUR:VOLT %.6f',opt.Amplitude));
    checkError(inst,'Output amplitude');

    %% Final error check

    checkError(inst,'Final configuration');

    %% Enable output

    inst.SendCmd(':OUTP ON');
    checkError(inst,'Output enable');

    fprintf('\n====================================\n');
    fprintf('       WAVEFORM OUTPUT ACTIVE       \n');
    fprintf('====================================\n');

    fprintf('Your waveform is now playing continuously.\n');

    %% Return information

    info.Type = type;
    info.Frequency = f;
    info.SampleRate = fs;
    info.Samples = N;
    info.Amplitude = opt.Amplitude;
    info.Channel = opt.Channel;
    info.Segment = opt.Segment;
    info.Waveform = wave;
    info.DAC = dac;

catch ME

    fprintf('\nERROR: %s\n',getReport(ME));

    if connected
        try
            inst.SendCmd(':OUTP OFF');
        catch
        end
    end

    if connected
        try
            inst.Disconnect();
        catch
        end
    end

    if ~isempty(inst)
        try
            delete(inst);
        catch
        end
    end

    rethrow(ME);

end

%% 9. DISCONNECT WITHOUT STOPPING OUTPUT

if connected

    inst.Disconnect();
    delete(inst);

    fprintf('\nMATLAB disconnected.\n');
    fprintf('Waveform output left enabled.\n');

end

end


%% ============================================================
%  LOCAL HELPER: CHECK INSTRUMENT ERROR QUEUE
% ============================================================

function checkError(inst,stage)

    [err,desc] = inst.QuerySysErr();

    fprintf('%s: %d | %s\n',stage,err,desc);

    assert(err == 0, ...
        sprintf('%s failed: %s',stage,desc));

end
