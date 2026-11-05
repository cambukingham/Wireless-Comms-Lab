# Waveforms, then NCO, then ADC

Use the existing direct connection from AWG CH1 to Tektronix analog CH1,
50-ohm input, DC coupling, bypassing TE3202. Default output is 200 mVpp
(-100 to +100 mV), zero offset. Scope bandwidth and analog signal-path response
will round abrupt transitions; a drawn mathematical edge is not instantaneous.
Non-50%-duty square/pulse waveforms also have a nonzero mean despite zero offset.
The analog output path may change that mean and cause pulse droop.

## Run from PowerShell

```powershell
cd C:\Projects\WINLAB\proteus_control
python 03_wave.py preview square --freq 1e6
python 03_wave.py start square --freq 1e6
python 03_wave.py start triangle --freq 1e6
python 03_wave.py start sawtooth --freq 1e6
python 03_wave.py start sawtooth --freq 1e6 --falling
python 03_wave.py start pulse --freq 1e6 --duty 0.25
python 03_wave.py start sine --freq 2e6 --vpp 0.2
python 03_wave.py stop
```

Run one start command at a time and inspect the scope. At 1 MHz start with
200 ns/div and 100 mV/div. A 25%-duty pulse at 1 MHz is high for 250 ns and
low for 750 ns. Pulse and square use the same bipolar two-level generator;
the duty setting determines their high time. Pulse is not a unipolar output.

`preview` calculates samples and prints settings without connecting. `setup`
uploads but leaves CH1 off. `start` configures then enables CH1; output stays
on after Python exits. `stop` disables CH1. Each connected action saves a
settings record in logs. On error the script attempts to turn CH1 off; if
Ethernet is lost, use the chassis controls to ensure the output is off.

## Understand the files

- `waveforms.py`: pure waveform math and unsigned 16-bit encoding.
- `03_wave.py`: command-line arguments, configuration, upload, readback and output.
- `proteus.py`: Ethernet connection and SCPI transport.
- `config.json`: chassis address and timeout.

Frequency and Vpp can change on the command line; keep sample rate at 1 GS/s.
The generator chooses an integer number of periods in a record whose length
is divisible by 64, so waveform repetition does not add a record-boundary glitch.
There are finite-memory limits: some exact requested frequencies are rejected
rather than silently rounded. Initial software limits are 50 MHz maximum and
0.1 to 0.5 Vpp; these are experiment limits, not the hardware's complete ratings.
Square/pulse high and low times must each cover at least two samples. Actual duty
is quantized to the sample grid. Waveforms are sampled ideal shapes, not
band-limited synthesis; high-frequency versions can show aliasing and rounding.

Each setup replaces CH1 segment 1 and changes the sample clock shared with CH2.
The script does not reset the whole instrument. Avoid running other control
programs concurrently. After later task/NCO experiments, verify trigger and
module-wide settings before relying on this basic startup sequence again.

## Next: NCO

Keep the same scope connection and compare a stored sine with the instrument's
own oscillator. Start at 20 ns/div and 100 mV/div. At 10 MHz, the period is
100 ns. At 25 MHz, it is 40 ns.

```powershell
python 03_wave.py start sine --freq 10e6
python 04_nco.py start --freq 10e6
python 04_nco.py start --freq 25e6
python 04_nco.py stop
```

`04_nco.py` uses the same Ethernet connection. `setup` programs and checks
settings with CH1 off. `start` applies the settings and enables CH1. The script
sets a 1 GS/s DAC clock and disables interpolation, both shared settings.
The displayed Vpp is the programmed level. Measure the actual level on the scope.
The hardware oscillator generates the sine internally, so changing its frequency
takes a tuning command. The DUC experiment will feed time-varying I/Q into that
oscillator's mixer to produce a modulated carrier.

## Then: loopback and ADC

After confirming input limits/range and selecting attenuation, connect AWG CH1
through the attenuator to digitizer CH1 IN. Do not connect TE3202 output into this
first loopback. Configure ADC sample rate, range, trigger and frame length, read
binary samples and convert codes to volts. Compare requested and measured
frequency, Vpp, duty, shape and FFT, accounting for analog bandwidth and timing.
The AWG and ADC are separate subsystems even within one Proteus module.
ADC acquisition and automatic loopback measurement are not implemented yet.
