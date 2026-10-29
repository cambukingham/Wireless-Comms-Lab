"""CH1 scope test: 10 MHz sine, 0.2 Vpp into 50 ohms, zero offset.

Usage: python 02_tone.py setup|start|stop
setup uploads with output OFF; start repeats setup then enables CH1.
stop disables CH1. A successful start leaves the tone running.
CH1 segment 1 is replaced; CH1/CH2 share clock/memory resources.
"""

import argparse
import json
import math
import struct
from pathlib import Path

from proteus import Proteus

SAMPLE_RATE = 1_000_000_000
TONE_HZ = 10_000_000
AMPLITUDE_VPP = 0.2
SAMPLE_COUNT = 3200  # 32 complete cycles; multiple of 64 samples.


def setup(instrument):
    # Direct DAC playback avoids the RF upconverter used by the Wi-Fi demos.
    for command in (
        ":SOUR:MODE DIRECT",
        ":SOUR:INT NONE",
        ":SOUR:PTR X1",
        f":FREQ:RAST {SAMPLE_RATE}",
        ":TRAC:FORM U16",
        ":SOUR:FUNC:MODE ARB",
        ":INIT:CONT ON",
        f":TRAC:DEF 1,{SAMPLE_COUNT}",
        ":TRAC:SEL 1",
    ):
        print(f"Setting {command}", flush=True)
        instrument.command(command)
        instrument.check_error()

    # Unsigned 16-bit DAC codes, small endian
    codes = [round(32767.5 * (1 + math.sin(2 * math.pi * TONE_HZ * n / SAMPLE_RATE)))
             for n in range(SAMPLE_COUNT)]
    instrument.write_waveform(struct.pack(f"<{SAMPLE_COUNT}H", *codes))
    instrument.check_error()
    for command in (
        ":SOUR:FUNC:MODE:SEGM 1",
        f":SOUR:VOLT {AMPLITUDE_VPP}",
        ":SOUR:VOLT:OFFS 0",
    ):
        instrument.command(command)
        instrument.check_error()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("setup", "start", "stop"))
    args = parser.parse_args()
    config = json.loads(Path(__file__).with_name("config.json").read_text())
    with Proteus(**config, allow_writes=True) as instrument:
        identity = instrument.query("*IDN?")
        if "P9484M,000002233113," not in identity:
            raise RuntimeError(f"Unexpected instrument: {identity}")
        instrument.command(":INST:CHAN 1")
        instrument.command(":OUTP OFF")
        try:
            # Report and drain errors left by an earlier interrupted session.
            for _ in range(32):
                previous = instrument.query(":SYST:ERR?")
                if int(previous.split(",", 1)[0]) == 0:
                    break
                print(f"Previous error: {previous}", flush=True)
            else:
                raise RuntimeError("Instrument error queue did not clear.")
            instrument.check_error()
            if args.action != "stop":
                setup(instrument)
            if args.action == "start":
                # Verify settings before allowing a signal onto the scope cable.
                rate = float(instrument.query(":FREQ:RAST?"))
                voltage = float(instrument.query(":SOUR:VOLT?"))
                offset = float(instrument.query(":SOUR:VOLT:OFFS?"))
                if not (math.isclose(rate, SAMPLE_RATE, rel_tol=1e-6)
                        and math.isclose(voltage, AMPLITUDE_VPP, abs_tol=0.001)
                        and abs(offset) < 0.001):
                    raise RuntimeError(f"Unexpected settings: {rate=}, {voltage=}, {offset=}")
                instrument.command(":OUTP ON")
                instrument.check_error()
            state = instrument.query(":OUTP?")
            instrument.check_error()
            print(f"CH1 output state: {state}")
            if args.action == "start":
                print("Tone running: 10 MHz, 0.2 Vpp, zero offset, into 50 ohms.")
                print("To stop: run this script with stop, or switch CH1 output off on the chassis.")
            else:
                print("CH1 output OFF.")
        except BaseException:
            # Best effort: a broken connection can prevent a remote shutdown.
            try:
                instrument.command(":OUTP OFF")
            except OSError:
                pass
            raise


if __name__ == "__main__":
    main()
