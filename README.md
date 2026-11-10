# WINLAB Wireless Communications Bench

Python desktop controls and offline analysis for the lab's Tabor Proteus
P9484M-AWT in a PXE6410 chassis. This branch includes waveform generation,
DUC/NCO control, ADC/DDC capture, Python scripting, message decoding and waveform
comparison. The original Rutgers and MATLAB examples remain as references.

## Install on a Windows laptop

1. Install **64-bit Python 3.12**, including Tcl/Tk and the Python launcher.
2. Clone the **Python** branch:

   ```powershell
   git clone --branch Python https://github.com/cambukingham/Wireless-Comms-Lab.git
   cd Wireless-Comms-Lab
   ```

3. Double-click **Setup WINLAB Bench.cmd**. This creates `.venv`, installs the
   pinned NumPy dependency, checks Tkinter, and creates a **WINLAB Bench** shortcut
   in your per-user Start menu. The first setup needs internet access.
4. Open that shortcut, or double-click **Launch WINLAB Bench.cmd** in the checkout.

Setup does not connect to the instrument or enable an output. No administrator
installation of a Tabor driver is needed for laptop Ethernet control.

If you prefer manual installation:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\pythonw.exe .\proteus_control\bench_panel.py
```

Keep the checkout in place after setup: the shortcut points to that folder.
Rerun setup after moving the folder. After pulling updates, rerun setup if
`requirements.txt` changed.

## Connect to the lab Proteus

The current bench uses:

| Endpoint | IPv4 address | Subnet mask |
| --- | --- | --- |
| Laptop physical Ethernet | `192.168.2.1` | `255.255.255.0` |
| PXE6410 Ethernet 2 | `192.168.2.2` | `255.255.255.0` |

For this direct cable, leave gateway and DNS blank. Only one laptop on this
subnet should use `192.168.2.1` at a time. Configure the physical Ethernet
adapter, rather than a WSL/Hyper-V virtual adapter.

The app reads `proteus_control/config.json`; the default SCPI endpoint is
`192.168.2.2:5025`. Select **Connection → Connect over Ethernet**. The chassis
SCPI service must be running. **Check local PXIe driver** is an optional diagnostic
for software running on the chassis controller itself.

Hardware writes currently check for the lab P9484M serial **000002233113**.
This checkout targets that shared bench; changing the IP alone does not retarget
the write helpers to a different physical module. Offline comparison accepts
sample logs from other instruments without opening a hardware connection.

## First use

- **Transmit:** choose the wired AWG output, waveform/mode and level. Setup loads
  samples with that output off; Start enables it. Output Off targets the selected
  output. Selecting another channel leaves an already-running output unchanged.
- **Receive:** select ADC input 1 or 2. Capture saves the raw samples and settings;
  file loading and analysis work offline.
- **Python:** edit experiments under `experiments/`. Bench modules are available
  to scripts run by the app. The built-in examples include offline generation,
  transmit setup, custom I/Q and capture.
- **Message / differences / integrity:** decode a known repeating BPSK reference
  and inspect received text, bits, byte differences and held-out error counts.
- **Compare waveforms:** independently import sent/reference and received data,
  including WINLAB logs and CSVs, then inspect aligned overlays and residuals.

For the initial cabled test, bypass the TE3202 amplifiers. The verified loopback
used a 0.2 Vpp AWG setting through a 6 dB attenuator into the ADC on HIGH range.
Switch the selected output off before changing RF wiring. Hardware limits and
attenuation depend on the actual signal path.

## Development and research files

Run the offline regression suite without connecting to hardware:

```powershell
.\.venv\Scripts\python.exe -B -m unittest discover -s proteus_control -p "test_*.py" -v
```

See [the app guide](proteus_control/README.md) for channel behavior, scripting,
capture formats, comparison controls and limitations. The current BPSK decoder
uses known-reference training; it is not a blind packet receiver or CRC check.
Waveform references reconstructed from TX settings are labeled separately from
measured samples.

Generated captures, run data, Python caches, virtual environments and `.lnk`
shortcuts are ignored by Git. Existing files stay on your computer. Share bench
data deliberately with the app's export tools or another agreed research-data
location. `experiments/loopback-message.txt` is the 16-byte sample payload
`WINLAB_TEST_0001`, with no trailing newline.
