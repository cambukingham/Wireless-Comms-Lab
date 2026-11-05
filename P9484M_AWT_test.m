%% Connect
ip   = "192.168.2.2";             % chassis IP
inst = tcpclient(ip, 5025);        % confirm port in the manual
inst.Timeout = 10;
scpi = @(s) writeline(inst, s);

writeline(inst, "*IDN?");
disp(readline(inst))               % should print Tabor / Proteus ID

scpi("*CLS"); scpi("*RST");

%% Build the waveform (exact integer cycles, loops seamlessly)
fs     = 1e9;                      % sample rate (1 GS/s)
f0     = 10e6;                     % sine frequency
cycles = 16;                       % whole cycles in the segment
N      = round(cycles * fs / f0);  % 1600 samples
assert(mod(N, 64) == 0, "Segment length must be a multiple of 64");
assert(abs(N*f0/fs - cycles) < 1e-9, "Not an integer number of cycles");

n    = 0:N-1;
y    = sin(2*pi*cycles*n/N);       % exactly 'cycles' periods, no end jump
dac  = uint16(round((y+1)/2 * 65534) + 1);   % stay inside full scale
%% Send it
scpi(":INST:CHAN 1");
scpi(":TRAC:DEF 1, " + N);         % define segment 1 of length N
scpi(":TRAC:SEL 1");


bytes  = typecast(dac, "uint8");   % little-endian
nbytes = numel(bytes);
digits = sprintf("%d", nbytes);
hdr    = sprintf("#%d%s", strlength(digits), digits);   % e.g. #49000
write(inst, uint8(char(":TRAC:DATA 0," + hdr)));
write(inst, bytes);
write(inst, uint8(10));   

%% Play it
scpi(":FREQ:RAST " + fs);
scpi(":SOUR:FUNC:MODE ARB");
scpi(":SOUR:FUNC:SEG 1");
scpi(":SOUR:VOLT 0.5");            % amplitude, volts
scpi(":OUTP ON");

writeline(inst, ":SYST:ERR?");
disp(readline(inst))               % check for errors
