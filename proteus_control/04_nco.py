"""Generate a single sine on Proteus AWG CH1 using the hardware NCO."""

import argparse
import json
import math
from pathlib import Path

from proteus import Proteus
from waveforms import SAMPLE_RATE


def set_output(instrument, enabled):
    instrument.command(":OUTP ON" if enabled else ":OUTP OFF")
    instrument.check_error()
    state = instrument.query(":OUTP?").upper()
    expected = ("ON", "1") if enabled else ("OFF", "0")
    if state not in expected:
        raise RuntimeError(f"Unexpected CH1 output state: {state!r}")


def configure_nco(instrument, frequency, voltage):
    for command in (
        ":SOUR:INT NONE",
        f":FREQ:RAST {SAMPLE_RATE}",
        ":SOUR:MODE NCO",
        ":NCO:MODE SING",
        f":NCO:CFR1 {frequency:.12g}",
        ":NCO:PHAS1 0",
        ":NCO:SIXD1 OFF",
        f":SOUR:VOLT {voltage:.12g}",
        ":SOUR:VOLT:OFFS 0",
    ):
        try:
            instrument.command(command)
            instrument.check_error()
        except RuntimeError as error:
            raise RuntimeError(f"{command}: {error}") from error

    if instrument.query(":SOUR:MODE?").upper() != "NCO":
        raise RuntimeError("Proteus did not confirm NCO mode.")
    for query, expected, tolerance in (
        (":FREQ:RAST?", SAMPLE_RATE, 1),
        (":NCO:CFR1?", frequency, 1),
        (":SOUR:VOLT?", voltage, 0.001),
        (":SOUR:VOLT:OFFS?", 0, 0.001),
    ):
        actual = float(instrument.query(query))
        instrument.check_error()
        if not math.isclose(actual, expected, rel_tol=1e-6, abs_tol=tolerance):
            raise RuntimeError(f"{query} returned {actual:g}, expected {expected:g}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("setup", "start", "stop"),
                        help="Configure muted, configure and enable, or turn CH1 off")
    parser.add_argument("--freq", type=float, default=10e6,
                        help="Carrier in Hz, from 1 to 100 MHz (default: 10e6)")
    parser.add_argument("--vpp", type=float, default=0.2,
                        help="Programmed output level, 0.1 to 0.5 Vpp (default: 0.2)")
    args = parser.parse_args()
    if not 1e6 <= args.freq <= 100e6:
        parser.error("--freq must be between 1e6 and 100e6 Hz for this experiment.")
    if not 0.1 <= args.vpp <= 0.5:
        parser.error("--vpp must be between 0.1 and 0.5 V for this experiment.")

    try:
        config = json.loads(Path(__file__).with_name("config.json").read_text())
        with Proteus(**config, allow_writes=True) as instrument:
            identity = instrument.query("*IDN?")
            if "P9484M,000002233113," not in identity:
                raise RuntimeError(f"Unexpected instrument: {identity}")
            instrument.command(":INST:CHAN 1")
            instrument.check_error()
            try:
                set_output(instrument, False)
                if args.action != "stop":
                    configure_nco(instrument, args.freq, args.vpp)
                if args.action == "start":
                    set_output(instrument, True)
            except BaseException:
                try:
                    instrument.command(":OUTP OFF")
                except OSError:
                    print("CH1 shutdown could not be sent. Check the chassis controls.")
                raise
    except (OSError, RuntimeError, ValueError) as error:
        parser.exit(1, f"NCO operation failed: {error}\n")

    if args.action != "stop":
        print(f"CH1 NCO: {args.freq / 1e6:g} MHz, {args.vpp:g} Vpp programmed, zero offset.")
    print("CH1 is ON. Stop with -> python 04_nco.py stop" if args.action == "start"
          else "CH1 is OFF.")


if __name__ == "__main__":
    main()
