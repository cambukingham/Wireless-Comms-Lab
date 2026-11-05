"""Direct CH1 waveform playback. Defaults: 1 MHz, 200 mVpp, zero offset.

Examples:
  python 03_wave.py preview square --freq 1e6
  python 03_wave.py start square --freq 1e6 --duty 0.25
  python 03_wave.py start sawtooth --falling
  python 03_wave.py stop
"""

import argparse
import json
import math
from datetime import datetime, timezone
from pathlib import Path

from proteus import Proteus
from waveforms import SAMPLE_RATE, SHAPES, generate


def checked(instrument, command):
    print(command, flush=True)
    instrument.command(command)
    instrument.check_error()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=("preview", "setup", "start", "stop"))
    parser.add_argument("shape", nargs="?", choices=SHAPES, default="sine")
    parser.add_argument("--freq", type=float, default=1e6, help="Frequency in Hz (1e6 = 1 MHz)")
    parser.add_argument("--vpp", type=float, default=0.2, help="Peak-to-peak volts into 50 ohms")
    parser.add_argument("--duty", type=float, default=0.5, help="High fraction for square/pulse; 0.25 = 25%%")
    parser.add_argument("--falling", action="store_true", help="Reverse sawtooth slope")
    args = parser.parse_args()
    if not math.isfinite(args.vpp) or not 0.1 <= args.vpp <= 0.5:
        parser.error("For initial scope tests, --vpp must be between 0.1 and 0.5 V.")
    if args.falling and args.shape != "sawtooth":
        parser.error("--falling applies only to sawtooth.")
    if args.duty != 0.5 and args.shape not in ("square", "pulse"):
        parser.error("--duty applies only to square/pulse.")
    try:
        values, payload, cycles = generate(args.shape, args.freq, args.duty, args.falling)
    except ValueError as error:
        parser.error(str(error))
    if args.action != "stop":
        print(f"{args.shape}: {args.freq:g} Hz, {args.vpp:g} Vpp, zero offset, into 50 ohms")
        print(f"{len(values)} samples, {cycles} cycles, {SAMPLE_RATE:g} samples/s")
        if args.shape in ("square", "pulse"):
            print(f"High time: {args.duty / args.freq:g} s ({100*args.duty:g}% duty)")
    if args.action == "preview":
        print("Preview only: waveform calculated; no instrument connection.")
        return
    folder = Path(__file__).resolve().parent
    config = json.loads((folder / "config.json").read_text())
    with Proteus(**config, allow_writes=True) as instrument:
        identity = instrument.query("*IDN?")
        if "P9484M,000002233113," not in identity:
            raise RuntimeError(f"Unexpected instrument: {identity}")
        instrument.command(":INST:CHAN 1")
        instrument.command(":OUTP OFF")
        try:
            for _ in range(32):
                previous = instrument.query(":SYST:ERR?")
                if int(previous.split(",", 1)[0]) == 0:
                    break
                print(f"Previous error: {previous}")
            else:
                raise RuntimeError("Error queue did not clear.")
            if args.action != "stop":
                for command in (
                    ":SOUR:MODE DIRECT", ":SOUR:INT NONE", ":SOUR:PTR X1",
                    f":FREQ:RAST {SAMPLE_RATE}", ":TRAC:FORM U16",
                    ":SOUR:FUNC:MODE ARB", ":INIT:CONT ON",
                    f":TRAC:DEF 1,{len(values)}", ":TRAC:SEL 1",
                ):
                    checked(instrument, command)
                instrument.write_waveform(payload)
                instrument.check_error()
                for command in (
                    ":SOUR:FUNC:MODE:SEGM 1", f":SOUR:VOLT {args.vpp}",
                    ":SOUR:VOLT:OFFS 0",
                ):
                    checked(instrument, command)
                for query, expected in ((":FREQ:RAST?", SAMPLE_RATE),
                                        (":SOUR:VOLT?", args.vpp),
                                        (":SOUR:VOLT:OFFS?", 0)):
                    actual = float(instrument.query(query))
                    instrument.check_error()
                    if not math.isclose(actual, expected, rel_tol=1e-6, abs_tol=1e-4):
                        raise RuntimeError(f"Readback mismatch: {query} returned {actual}")
            if args.action == "start":
                checked(instrument, ":OUTP ON")
            state = instrument.query(":OUTP?")
            instrument.check_error()
            expected_on = args.action == "start"
            if (state.upper() in ("ON", "1")) != expected_on:
                raise RuntimeError(f"Unexpected output state: {state}")
            print(f"CH1 output: {state}")
            now = datetime.now(timezone.utc)
            logs = folder / "logs"
            logs.mkdir(exist_ok=True)
            record = dict(vars(args), identity=identity, output_state=state,
                          sample_rate=SAMPLE_RATE, samples=len(values),
                          time_utc=now.isoformat())
            (logs / (now.strftime("%Y%m%dT%H%M%S_%fZ") + "_wave.json")).write_text(
                json.dumps(record, indent=2) + "\n")
            if expected_on:
                print("Output stays ON. Stop with -> python 03_wave.py stop")
        except BaseException:
            try:
                instrument.command(":OUTP OFF")
            except OSError:
                pass
            raise


if __name__ == "__main__":
    main()
