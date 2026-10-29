# Existing demos: behavior and dependencies

Reviewed by reading source, not by executing the demos. The confirmed hardware
is P9484M serial 000002233113, slot 5, LAN 192.168.2.2:5025. Its installed
options include DUC and AWT. No instrument commands were sent during this review;
the previously started 10 MHz CH1 tone was not changed.

## Control paths and drivers

I/Q describes waveform data, not a special communications driver.

Laptop path:

Python -> PyVISA -> VISA backend -> Ethernet SCPI server -> Proteus hardware.

The supplied `SourceFiles/tevisainst.py` is Tabor's Python VISA wrapper. It needs
NumPy and PyVISA. It defaults to `pyvisa.ResourceManager()`; use an installed
vendor VISA runtime such as NI-VISA for the original examples' expected setup.
The wrapper also offers `use_ni_visa=False`, which selects `@py` (pyvisa-py).
That backend must be checked against the wrapper's buffer/attribute calls;
its existence does not establish that every original example works unchanged.

Local chassis path:

Python on the embedded chassis PC -> `teproteus.py` -> `TEProteus.dll` -> PXI hardware.

Installing that DLL on the Ethernet-connected laptop does not create local PXI
access. This path needs the vendor's installed driver/runtime on the chassis,
compatible Python/DLL architecture, and actual slot discovery (our slot is 5,
whereas the original scripts hard-code 4). The local API is useful when the
experiment needs native transfer/streaming features or LAN transfer becomes a
measured bottleneck. Do not assume hardware sample rate equals LAN data rate.

The current small `proteus.py` uses sockets and already uploads binary DAC data.
It could be extended for I/Q SCPI transfers too; using the vendor wrapper is a
reasonable choice for reusing the supplied acquisition and binary-transfer code.
No need to avoid drivers when they serve the experiment.

## Python demo map

Paths below are relative to `C:/Projects/WINLAB/Rutgers (2)/Rutgers`.

| File | Current source behavior | Assumptions / issues |
| --- | --- | --- |
| `9484_WIFI_AWG_TEST_PXI.py` | Reads WiFi I/Q CSVs, then calls `makeDCData(2048)` before upload. Uses DUC, x8 interpolation and task playback; carrier variable is 2.422 GHz. Includes digitizer/FFT code, but final acquisition loop is commented out. | Active connection is local PXI slot 4. This is currently a constant-I/Q carrier example, not playback of the loaded WiFi waveform. |
| `9484_WIFI_AWG_TEST_PXI_2CH.py` | Similar DUC/task setup on CH1 and CH2 at 2.422 and 2.0 GHz; each uses constant I/Q. | Active local PXI slot 4. Both calls use segment 1; CH1/CH2 share waveform memory, so segment ownership needs redesign before reuse. Capture loop is commented out. |
| `9484_WIFI_AWG_TEST_PXI_2CH_PS.py` | Uses LAN. CH1 uploads the loaded WiFi I/Q at 2.422 GHz. CH3 uses generated on/off I/Q segments with task sequencing at 2.0 GHz. | Effective address is the last assignment, 169.254.18.80. In `setTaskDUC`, `md = ...SEGM...` is assigned but `cmd` is sent, so the segment-selection command is not sent. Needs correction. |
| `rutgers_radio_demo.py` | Two LAN instruments: transmitter 192.168.1.21 and receiver 192.168.1.14. DUC/task playback with multiband configuration, digitizer acquisition and plots. | References LTE QPSK real/imag CSVs absent from this folder. Defaults include 2.4 GHz and 5.180 GHz enabled, 7.2 GHz disabled. Assumes a different physical setup. |
| `rutgers_radio_demo_wDemod.py` | Similar two-instrument setup; enables digitizer complex DDC, 300 MHz DDC tuning and x16 decimation. Separates alternating I/Q capture words and plots I plus an FFT of I. | Same missing LTE files and old addresses. This is digital downconversion, not a complete LTE demodulator or EVM/BER measurement. Complex sample format/scaling and spectral orientation need validation. |
| `ScopeFFT.py` | Acquires from the Proteus digitizer at 5.4 GS/s, frame length 4800, plots time samples and FFT in a loop. | Does not control the Tektronix scope. LAN address 192.168.1.14; source import path points to `../SourceFiles` despite the actual sibling folder. Includes reset/output enable even though waveform download calls are commented out. |

The WiFi CSVs contain unsigned DAC code values. Their names alone do not prove
the modulation standard, bandwidth, sample rate, or normalization. Validate
length, range, sample rate and metadata before treating them as a calibrated
WiFi reference waveform.

## What the I/Q examples actually do

1. Read or synthesize I and Q arrays.
2. Quantize them to unsigned 16-bit DAC codes.
3. Interleave them as I0,Q0,I1,Q1,... using NumPy.
4. Upload the binary array to a waveform segment.
5. Select `:SOUR:MODE DUC`, `:SOUR:INT X8`, and `:SOUR:IQM ONE`.
6. Set the DAC clock to 8 times the intended baseband sample rate.
7. Tune the NCO with `:SOUR:NCO:CFR1` and select segment/task playback.

I and Q are internal components of one modulated RF signal in this mode. They
do not necessarily appear on two separate analog output connectors. Physical
baseband I/Q on separate outputs is a different experiment/configuration.
Constant I/Q produces a carrier; time-varying I/Q produces modulation.

The radio receive example uses a different path: RF ADC samples -> DDC ->
decimation -> complex I/Q words -> Python processing. A calibrated complex FFT
should use I+jQ with consistent signed conversion, rate and scaling; the
existing FFT plots are not established power measurements. For example,
`scaleTodBm` squares voltage into power but then uses 20*log10 rather than the
10*log10 power ratio. Do not interpret that function's output as calibrated dBm.

## Dependencies observed

- NumPy: arrays, quantization, interleaving and FFTs.
- Matplotlib: plots and GUI buttons.
- PyVISA: required by the supplied `tevisainst.py`, even where a script then uses PXI.
- VISA runtime: NI-VISA or another compatible vendor runtime for the default backend.
- pyvisa-py: optional alternative backend; not a substitute for the local PXI DLL.
- keyboard: imported by these demos; avoid needing it in new scripts by using explicit actions/Ctrl+C.
- `teproteus.py` / `teproteus_streaming.py`: local native DLL wrappers, not package-manager drivers.
- `tep_task_table.py`: task-row binary packing helpers.
- `tep_interleaved_wave.py`: waveform formatting helpers.
- `teproteus_functions.py`: waveform, IQ conversion, kernel/FIR and scaling helpers;
  some functions reference FIR coefficient CSVs absent from this bundle.

The bundled Python used for our connection/tone tests currently has NumPy, but
not Matplotlib, PyVISA, pyvisa-py or keyboard. This observation is specific to
that interpreter, not all Python installations on the laptop. Standard
System32 paths did not reveal visa64.dll or TEProteus.dll on the laptop; that
is not an exhaustive inventory and says nothing about the chassis installation.

## MATLAB reference map

The supplied `Proteus_SCPI_MATLAB_Script_Examples_Ver._3.0` folder contains:

1. Opening a session: LAN VISA or local DLL, identity/options and hardware limits.
2. Waveform generation: channels, segment memory, markers, voltage and DAC format.
3. DUC: RF generation with interpolation, NCO and I/Q modes.
4. Digitizer: baseband/RF capture, useful as a second reference for Python acquisition.

## Recommended project progression

Keep original examples unchanged. Add understandable examples to this project:

1. Existing `01_identify.py` and `02_tone.py`: already tested on the hardware.
2. Offline I/Q preparation: generated quadrature tone, quantization and plots;
   explicit complex sample rate, not just a CSV filename.
3. Low-carrier DUC output within the MSO4034's 350 MHz bandwidth, retaining a
   low output level and explicit setup/start/stop. Check shared module I/Q mode.
4. Capture with the Proteus digitizer and save raw data plus configuration.
   Set up the RF input connection/attenuation separately before acquisition.
5. Complex DDC, spectra and known-signal validation, then supplied WiFi playback.
6. GHz carrier tests with a suitable receiver/analyzer; the MSO4034 cannot
   directly validate the demos' 2.4/5 GHz RF waveforms at full bandwidth.

Separate waveform preparation, hardware transport, transmitter configuration,
receiver configuration and analysis. Use the same experiment settings regardless
of LAN VISA vs local DLL; keep transport details out of waveform math.

## References

- Tabor programming manual, especially sections 5.2, 5.4, 5.9, 9.1 and digitizer commands:
  https://www.taborelec.com/GenericHendler/GetFile.ashx?D=1&DG=5257
- PyVISA backend configuration:
  https://pyvisa.readthedocs.io/en/latest/introduction/configuring.html
- The actual supplied source files, whose active code is summarized above.
