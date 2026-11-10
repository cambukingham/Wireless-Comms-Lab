"""Direct AWG waveform playback. Defaults to CH1, 1 MHz and 200 mVpp."""

import argparse

from wave_playback import run_wave
from waveforms import SHAPES


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("preview", "setup", "start", "stop"))
    parser.add_argument("shape", nargs="?", choices=(*SHAPES, "nrz"), default="sine")
    parser.add_argument("--freq", type=float, default=1e6, help="Frequency in Hz (1e6 = 1 MHz)")
    parser.add_argument("--vpp", type=float, default=0.2, help="Peak-to-peak volts into 50 ohms")
    parser.add_argument("--channel", type=int, choices=(1, 2, 3, 4), default=1)
    parser.add_argument("--duty", type=float, default=0.5, help="High fraction for square/pulse; 0.25 = 25%%")
    parser.add_argument("--falling", action="store_true", help="Reverse sawtooth slope")
    parser.add_argument("--delay-ns", type=float, default=0, help="Circular waveform delay in ns")
    parser.add_argument("--bits", default="10100110", help="Repeating NRZ bit pattern")
    parser.add_argument("--symbol-mbd", type=float, default=2.5, help="NRZ symbols per second in millions")
    args = parser.parse_args()
    settings = vars(args).copy()
    settings["symbol_rate"] = settings.pop("symbol_mbd") * 1e6
    try:
        print(run_wave(**settings))
    except ValueError as error:
        parser.error(str(error))
    except (OSError, RuntimeError) as error:
        parser.exit(1, f"Waveform operation failed: {error}\n")
    if args.action == "start":
        print(f"Output stays ON. Stop with python 03_wave.py stop --channel {args.channel}")


if __name__ == "__main__":
    main()
