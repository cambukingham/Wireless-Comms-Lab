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
