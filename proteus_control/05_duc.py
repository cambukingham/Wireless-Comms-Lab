"""Try the Proteus DUC with a carrier, mixer, or repeating BPSK test."""

import argparse

from duc import PATTERNS, run_duc


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("setup", "start", "stop"))
    parser.add_argument("--pattern", choices=(*PATTERNS, "bpsk"), default="mixer")
    parser.add_argument("--carrier-mhz", type=float, default=100)
    parser.add_argument("--vpp", type=float, default=0.2, help="Programmed DAC level")
    parser.add_argument("--channel", type=int, choices=(1, 2, 3, 4), default=1)
    parser.add_argument("--bits", default="10100110", help="Repeating BPSK bit pattern")
    parser.add_argument("--symbol-mbd", type=float, default=2.5, help="BPSK symbols per second in millions")
    parser.add_argument("--delay-ns", type=float, default=0, help="Circular baseband delay in ns")
    parser.add_argument("--phase-deg", type=float, default=0, help="NCO phase in degrees")
    args = parser.parse_args()
    try:
        print(run_duc(args.action, args.pattern, args.carrier_mhz * 1e6, args.vpp,
                      bits=args.bits, symbol_rate=args.symbol_mbd * 1e6,
                      delay_ns=args.delay_ns, phase_deg=args.phase_deg, channel=args.channel))
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(1, f"DUC operation failed: {error}\n")


if __name__ == "__main__":
    main()
