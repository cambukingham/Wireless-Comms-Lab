# Waveforms, then NCO, then ADC

Select the external signal path appropriate to the experiment. The bench
uses a nominal 50-ohm reference. Default output is 200 mVpp (-100 to +100 mV),
zero offset. Instrument and analog signal-path bandwidth round abrupt transitions.
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

Run one start command at a time and inspect the signal. A 25%-duty pulse at 1 MHz is high for 250 ns and
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

Compare a stored sine with the instrument's own oscillator. At 10 MHz, the period is
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
The displayed Vpp is the programmed level. Measure the actual level in the signal path.
The hardware oscillator generates the sine internally, so changing its frequency
takes a tuning command.

## DUC mixer test

From the same folder, run
`python bench_panel.py` for the classic desktop panel, or use the CLI below.
Use Output Off before closing the panel when finished.

```powershell
python 05_duc.py setup --pattern carrier
python 05_duc.py start --pattern carrier
python 05_duc.py start --pattern mixer
python 05_duc.py stop
```

Both patterns use a 100 MHz NCO and a programmed DAC level of 0.2 Vpp by
default. A constant I value and zero Q give a carrier near 100 MHz. A 5 MHz
cosine in I and zero Q give the product of the baseband cosine and the NCO.
Check the received spectrum for peaks at 95 and 105 MHz. A residual 100 MHz peak can
reflect imperfections. The programmed DAC level is a scaling setting, so
measure the actual output level for each pattern.

The DUC code uses 2.5 GS/s, x8 interpolation, and a 312.5 MS/s I/Q sample rate.
It uploads 8,000 interleaved I/Q pairs to CH1 segment 129. Sample clock,
interpolation, and I/Q mode affect other channels on the module. Run the
experiment while CH1 is the only active channel. The CLI and panel share the
same experiment logic and use Ethernet SCPI. Avoid concurrent control sessions.
The next transport milestone is discovery and a short capture through the
vendor DLL on the Windows chassis, then comparison against the LAN path.

Reference: [Tabor Proteus DUC Primer](https://www.taborelec.com/GenericHendler/GetFile.ashx?D=1&DG=6052).

## Research bench app

Double-click `Launch WINLAB Bench.cmd` in the WINLAB folder, or run
`python bench_panel.py` from this folder. The **Connection** tab can read
identity and installed options over Ethernet using `config.json`. **Connect to
local PXIe** opens the selected physical slot on the Windows chassis for the
same identification check, then closes the session. It needs NumPy and Tabor's
`TEProteus.dll` installed on that computer. If the slot is busy, release its
other instrument session before checking. **Transmit** currently uses Ethernet.
The shared **Bench status** block shows Ready, Active, Cancelling, or Not ready
along with the last confirmed CH1 output and ADC state. Green means Ready,
red means an operation is active or CH1 is transmitting, orange flags Not
ready, and blue means cancellation is in progress.
Use **Cancel operation** or **Esc** from any tab. The app stops the active helper
or Python script. An interrupted hardware write can already have reached the
instrument. Use **Read CH1**, **Output Off**, or **Disarm ADC** to verify or
restore the applicable hardware state before continuing.

The **Python** tab has a script browser, syntax-highlighted editor, and output
console. Double-click a folder to navigate or a `.py` file to open it. Use
**Folder…** to jump to another directory. Drag the dividers to resize the panes.
The browser starts in `WINLAB/experiments`. The bench and bundled driver folders
are hidden in its file list and protected from in-app Open and Save. Bench
modules are still importable in scripts.
**Save & Run**
(F5 in the editor) saves a UTF-8 `.py` file and runs it with the app's Python
installation. The console shows prints, tracebacks, and the exit code.
Scripts start in their own folder and can import the bench modules. Use
**Import folder…** to add another directory of Python modules for the current
app session. Installed packages are available from the selected interpreter.

Use **Examples → Identify Proteus** for a read-only connection example.
`from proteus import connect` uses the bench Ethernet settings from
`config.json`. `with connect(allow_writes=True) as instrument` permits SCPI
configuration. The DUC example uses `run_duc` with the output off.
Scripts run with closed standard input. **Stop Script** terminates Python.
Use **Output Off** in Transmit to switch off CH1 separately.

In **Transmit**, choose **Basic waveforms**, **Direct baseband**, or **Digital upconverter** from
the selector below the preview. Basic waveforms offers sine, square, triangle,
sawtooth, and pulse with initial settings of 1 MHz and 0.2 Vpp. Square and pulse
enable the duty-cycle field. Sawtooth enables the falling slope control.
The time-domain preview follows the settings as you edit them. Direct playback
shows the requested voltage. The DUC preview shows relative amplitude from an
ideal mixer calculation. Both previews are calculated offline.
**Setup (Off)** loads the selected waveform with CH1 muted. **Start** loads it
and enables CH1. The same buttons apply to **Digital upconverter** when selected.

**Direct baseband** outputs a real waveform on CH1 without mixing it with a
carrier. **Bipolar NRZ bit pattern** maps `1` to +Vpp/2 and `0` to −Vpp/2 in the
programmed samples. It shares the bit pattern and symbol rate with the DUC's
BPSK option so you can compare the baseband symbols and phase-modulated RF.
The P9484M's direct output is AC-coupled, so the measured baseline can shift
and long runs can droop. The preview shows the programmed levels.

For a custom real signal, select **Python real function** and **Use in Python**.
Return a normalized real value from `baseband(t)` in the range −1 to +1.
Direct playback samples it at 1 GS/s. Complex I/Q mixing remains available in DUC.

**Record delay** shifts the repeating samples, wrapping around the record.
Direct playback rounds to a 1 ns sample. DUC rounds to a 3.2 ns I/Q sample and
delays the baseband. Use **NCO phase** to change carrier phase independently.
Both settings carry into **Use in Python**. Record delay is a signal shift.
Tabor's external-trigger delay is a separate control for triggered playback.

**Read CH1** queries the output state, mode, DAC clock, programmed level and
offset. In NCO and DUC modes it also queries carrier frequency and phase.
The readout restores the previous SCPI channel selection.

**Attenuation estimate** assumes a matched 50-ohm path. Enter the receiver's
full-scale Vpp for its selected range. The planner starts from the programmed
TX level, or a measured Vpp you enter as an override. Enter net gain before
the pad (negative for cable loss), the pad already in the path, and the desired
headroom. It reports the estimated receive Vpp, target Vpp, and minimum pad.
For example, 0.2 Vpp TX, 0.1 Vpp RX full scale, 6 dB headroom, and a 10 dB pad
give about 0.063 Vpp at RX and call for about 2 dB more attenuation. This models
clipping headroom. Confirm the input's maximum rating and actual signal level
before making a loopback connection.

### Modulate with the NCO or reuse Transmit settings from Python

In **Digital upconverter**, select **BPSK bit pattern** and enter `10100110`.
At 2.5 MBd each bit occupies 400 ns. A `1` uses positive I and a `0` uses
negative I, which reverses the carrier phase. The preview shows the first
16 baseband symbols at most. The hardware repeats the full pattern with
rectangular symbols. Adjust **Carrier (MHz)** to tune the NCO.

**Use in Python** loads an example. **Save & Run** passes the currently selected
Transmit tool and its parameters into the new Python process. Editing settings
after a script launches affects its next run. For a built-in source:

```python
from bench_api import transmit

print(transmit("setup"))  # Use "start" for live output or "stop" to turn CH1 off.
```

For your own signal, select **Python I/Q function**, set the carrier, level,
and repeat period, then use **Use in Python**. The callable receives time in
seconds at 312.5 million complex samples/s. A real result sets I with Q at zero.
A complex result sets I and Q. Keep magnitude at or below 1.

```python
from cmath import exp
from math import tau
from bench_api import transmit, transmit_settings

period = transmit_settings()["period_s"]
print(transmit("setup", baseband=lambda t: 0.5 * exp(1j * tau * t / period)))
```

The repeat period is rounded to the nearest I/Q sample. The record contains
whole repeats and is padded to the required alignment by repeating the signal.
Choose a function that wraps cleanly at the end of the period. The custom
callable executes in the script process. The built-in sources have a panel preview.

## Receive and experiment files

Select ADC channel 1 or 2, real sampling or DDC I/Q, input range, ADC clock,
frame and pretrigger lengths, and trigger. The initial Receive workflow uses
the ADC's internal clock in dual-channel mode and enables one channel per frame.
Frame and pretrigger lengths are in real samples or I/Q pairs. In DDC mode
set center frequency, phase and decimation. The sample rate in the capture
file is the measured clock readback divided by the selected decimation.

**Capture & save** arms the digitizer, waits for one frame, checks the SCPI block
length and saves the original bytes with the acquisition settings. **Load capture**
verifies the SHA-256 and opens the same time and FFT views offline. Real time traces
use the nominal voltage range. DDC traces are normalized, and FFT levels are
relative to the peak. Preserve the raw file for calibrated or custom analysis.
You can copy the selected RX range to the attenuation estimate in Transmit.

**TX files** loads bit text or up to 32 message bytes as a repeating bit pattern.
Each message byte is sent most-significant bit first. Save a TX plan to retain
the active mode and parameters, then reload it to review the settings and press
Start when ready. These checksums cover files and settings. Packet framing,
demodulation, and over-the-link error checking are separate experiments.

Use the Python example **Save real TX samples**, or call
`save_tx_samples(path, samples, iq=True)` for interleaved I/Q DAC data. Supply
normalized samples on the selected TX grid (1 GS/s real or 312.5 MS/s I/Q).
**Load samples** verifies the file and selects the matching transmit tool.
The app verifies the hash again before transmission. A TX plan references the
sample file by path and hash, so retain that file with the plan. ADC capture
files have their own sample rate and encoding and open in Receive for analysis.

## Research notes and antenna profiles

Use **Research Notes** to create or open a Markdown lab notebook. **Insert bench
snapshot** appends the requested TX settings, the loaded verified capture and
its hash, the RF path profile or current draft, and bench status with a timestamp.
Use **Save** to keep the note as a portable text file.

The **Antenna** tab records the TX and RX paths separately. Enter antenna or asset
IDs, instrument ports, reference frequencies, polarization, gain, cable loss,
inline attenuation, and orientation as known. Use the free-form notes for
geometry, adapter placement, and calibration provenance. Profiles use the same
SHA-256 verified `.wlab.json` format as the other bench artifacts. The page records
configuration for the experiment. Live switching and rotator control are separate.

## Configuration warnings and run bundles

TX and RX fields stay editable across modes. Red configuration messages explain
what to fix before sending or capturing. Amber messages flag conditions to check,
such as projected RX level above the headroom target or a selected TX carrier
outside the nominal DDC window. Settings for inactive sources are retained for
when you switch back to them. These checks use the requested configuration.

In **Research Notes → Run bundle**, add calibration records or supporting files,
then choose **Export run bundle**. A ZIP with a unique run ID contains the current
TX and RX settings, verified capture if loaded, active RF path profile or draft,
current Python editor contents, notes, and the attachments. The TX plan and its
verified sample file, when selected, are copied together with a relative link.
Edits in the notes and Python editor are captured even before saving those files.

**Verify run bundle** checks every member against `manifest.json`. Extract the
ZIP to inspect the files, open the saved capture in Receive, or load the TX plan
from its `tx` folder. Export records a snapshot of the app; the context identifies
requested settings separately from the settings saved with the capture.
