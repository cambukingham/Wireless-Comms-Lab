# WINLAB Proteus Python control

## First step: identify the instrument

Leave the RF signal cables disconnected for this step. Keep Ethernet connected.
An identification query does not require a waveform output or digitizer input.
It also does not switch off an output that was already enabled.

Network settings:

| Device | Address | Mask |
| --- | --- | --- |
| Laptop Ethernet | 192.168.2.1 | 255.255.255.0 |
| PXE6410 Ethernet 2 | 192.168.2.2 | 255.255.255.0 |

The instrument SCPI service listens on TCP port 5025. The initial connection
identified a P9484M, serial 000002233113, version 1.240.22, slot 5.

In WINLAB Bench, open **Connection → Connect over Ethernet** on the laptop.
Transmit, Receive and the Python instrument helpers use the address in
`config.json`, opening a new TCP connection for each operation. Waveform uploads,
DUC control and ADC capture use this path without a local Tabor PCIe driver.
The optional **Check local PXIe driver** diagnostic only works on the chassis
controller with its Tabor driver installed; it does not change the transport.

## Selecting a channel

In **Transmit → Transmit output**, choose AWG channel **1–4**. Setup, Start,
Output Off, readback and **Use in Python** target that output. Changing the
selector alone leaves outputs unchanged; the bench status tracks each output's
last confirmed state. A running operation retains the channel it started with.
Saved TX plans and exported run settings include the selected channel; older
plans without a channel default to CH1.

In **Receive → Receive input**, choose ADC channel **1 or 2** for either real
capture or DDC I/Q. These are the two digitizer inputs, independently numbered
from the four AWG outputs. Capture files record the input channel. Capture uses
one input at a time, and **Disarm ADC** stops acquisition for both inputs.

The P9484M shares waveform memory between CH1/2 and CH3/4. The app reserves direct
segments 1–4 and DUC segments 129–132 by output to avoid overwriting the paired
output's app waveform. Clock changes can still affect a paired output; this is
individual channel targeting, not a synchronized multi-channel sequencer.

Python helpers accept `channel=`, for example `run_wave("setup", channel=2)` and
`run_duc("setup", channel=3)`. `transmit("setup")` and `transmit("stop")` use the
channel captured from Transmit when the script started. Outside the app,
`transmit("stop", channel=2)` explicitly stops CH2. The waveform and DUC command
line scripts also accept `--channel`.

## Inspecting graphs

Transmit previews and Receive time/spectrum graphs support mouse-wheel zoom
along the horizontal axis, Shift+wheel zoom along the vertical axis, and left
drag to pan. Zoom is anchored at the pointer. Use **Fit Y** to scale the visible
signal vertically, and **Reset view**, double-click, or Home to restore the full
view. **Zoom X +/−** also work without a mouse wheel. Click a graph to use the
`+` and `-` keys. I/Q time views retain the same zoom when switching components;
loading a new capture or changing to Spectrum resets the axes.

Receive keeps all captured samples for time-domain zoom. Display reduction is
applied to the visible region and preserves extrema. The spectrum remains a
Hann FFT of the first 4096 samples (or the smaller available power of two);
zooming that plot does not increase its frequency resolution.

## Decoding a received BPSK message

Receive includes a **Decoded message / BPSK** panel in its message workspace. Load or
capture DDC I/Q data, enter the symbol rate in MBd, and supply the intended
repeating message as UTF-8 text, hex bytes, or bits. **Use TX settings** copies
the current BPSK pattern and symbol rate; **Load bytes** accepts the same 1–32
byte files as Transmit. New captures also save the requested TX settings and
can fill this reference automatically. Requested settings are not hardware
readback; confirm they describe the signal that was actually captured.

**Decode / compare** shows recovered text, hex or bits, complete message repeats,
and highlighted byte/bit differences. The alignment page records timing, phase,
carrier offset, training size and source hashes. A separate prefix trains the
alignment; the headline mismatch count uses later, held-out bits. Weak alignment
is labeled uncertain, and short captures request more samples. Changing the
capture or reference clears the old result. Decoding uses the shared cancellable
operation helper and does not communicate with the instrument.

This first decoder handles known repeating BPSK at baseband, with at least four
I/Q samples per symbol and a small residual carrier offset. It needs NumPy in
the Python installation running the app. It does not yet perform blind packet
detection, CRC validation, pulse-shape equalization or continuous clock tracking.
For `WINLAB_TEST_0001` at 2.5 MBd and 156.25 MS/s, use a 48,000-pair capture.

**Export** saves an integrity-checked `message_analysis` artifact, including the
reference, actual recovered bits, error locations and capture hash. Current
analysis is also included in research-note snapshots and exported run bundles.

## Receive workspaces and waveform comparison

Receive has full-width workspaces for **Waveform**, **Message / differences /
integrity**, and **Compare waveforms**. The message page places reference and
received text side by side, leaving the lower area for the difference table or
alignment details. The waveform page retains a decoded-message summary. Turn
off **Show capture settings** when inspecting a file to free more vertical space.
Entering the message or comparison workspace collapses that capture form
automatically; the checkbox brings it back whenever needed.

In **Compare waveforms**, select reference/sent and received sources independently.
**Use current TX** reconstructs the requested samples; **Use captured TX** uses
the requested TX settings recorded in the loaded capture. Neither is a measured
analog output. **Use loaded RX** selects the current capture. **Load file** accepts
WINLAB captures, TX sample files/plans, portable waveform logs, and CSV sample
files from another bench. CSV headers must be `time_s,value` or `time_s,i,q`, with
uniform time spacing in seconds; their amplitude units are treated as relative.
Legacy bench direct-wave JSON settings logs are reconstructed and labeled as such.
Python functions require an export of their actual generated samples.

Comparison converts both sources to the lower sample rate using a windowed-sinc
low-pass resampler, then uses Auto lag, a manual lag, or start-to-start alignment.
**Match RF centers** explicitly applies a known center-frequency difference to the
reference; an extra frequency shift can be entered in kHz. The overlay shows the
reference in blue, received samples in orange, and their difference in green.
I/real, Q and magnitude views share the existing zoom/pan controls.

**Fit gain / phase** applies a fitted constant complex gain and DC offset. The
gain, phase, lag, correlation and residual are reported so a fitted overlay is
not confused with an absolute calibration. Raw-level error is also reported when
units match. **Raw levels** leaves amplitudes unchanged and requires matching
units. Repeated references have whole-period timing ambiguity; lag is not a
calibrated physical latency. Comparisons use up to 65,536 common-rate samples
per source, support rate ratios up to 64:1, and require matching RF/baseband domains.

Use **Export log** for portable sample logs on either source, or **Transmit → TX
files → Export waveform log** for a requested-TX reference. Export is manual.
Scripts on any bench can call:

```python
from waveform_comparison import save_waveform_log

save_waveform_log("sent.wlab.json", samples, sample_rate=312.5e6,
                  iq=True, units="normalized DAC", domain="baseband",
                  center_hz=100e6, repeat=True,
                  provenance={"instrument": "bench A", "channel": 1})
```

An exported comparison records source hashes, original rates, alignment and fit
settings, and metrics. It does not automatically copy external source files.

From this directory, run with Python 3:

```powershell
python 01_identify.py
```

No additional Python packages are needed. If `python` is unavailable, use a
working Python installation's executable path. Connection failures can mean
an address/cable issue, a stopped chassis SCPI service, or a firewall rule.

## Files

- `config.json`: address, port, and response timeout.
- `proteus.py`: opens/closes the TCP connection; permits only identity/options queries.
- `01_identify.py`: checks the model and records the responses.
- `logs/`: dated JSON records produced by a successful check.

## Experiment progression

1. Identify the instrument and installed options with no RF wiring.
2. Prepare a simple tone and explicit output-off/setup/output-on controls.
3. Measure AWG CH1 using a suitable 50-ohm oscilloscope or spectrum analyzer.
   Select amplitude and any attenuation after checking that receiver's limits.
4. Add digitizer acquisition, then a characterized transmit/receive loopback.
5. Add TE3202 amplification after establishing the required power budget.

Step 2 is implemented in `02_tone.py` and verified on the instrument. It uses
1 GS/s direct playback of 3200 unsigned 16-bit samples (32 sine cycles).
The settings and instrument error responses are checked before enabling CH1.
This changes CH1 segment 1 and the clock shared with CH2. A successful start
leaves CH1 running after the program exits.

```powershell
python 02_tone.py setup
python 02_tone.py start
python 02_tone.py stop
```

`setup` loads the waveform with CH1 off; `start` repeats setup and enables CH1;
`stop` switches CH1 off. The tested target is 10 MHz, 200 mVpp into 50 ohms,
zero offset. Physical amplitude/frequency still need confirmation on the scope.
The tone script explicitly enables writes; identification remains read-only.

Steps 3 onward need measurement/acquisition work. Before wiring a loopback, confirm the
digitizer's input limits and choose attenuation for the actual output level.
Do not connect a TE3202 output directly to a digitizer input for the first test.
For the initial measurement, bypass the amplifiers and leave antennas disconnected.

Existing Rutgers examples are references rather than startup scripts: some reset
the instrument, use a different slot, or enable RF outputs. This project leaves
those originals untouched.
