"""AWG DUC experiments, shared by the CLI and desktop panel."""

import json
import math
import struct
from pathlib import Path

from baseband import bit_period, function_period, normalized_sample
from channels import playback_segment, select_awg_channel, validate_awg_channel
from proteus import Proteus
from research_files import load_tx_samples
from waveforms import delay_record, delay_samples

DAC_RATE = 2_500_000_000
INTERPOLATION = 8
BASEBAND_RATE = DAC_RATE // INTERPOLATION
BASEBAND_HZ = 5_000_000
PAIR_COUNT = 8000  # 128 complete baseband periods, 16,000 DAC words.
SEGMENT = 129
PATTERNS = ("carrier", "mixer")


def baseband_i(pattern, time_seconds):
    return 0.5 if pattern == "carrier" else 0.5 * math.cos(math.tau * BASEBAND_HZ * time_seconds)


def encode_iq(samples):
    """Pack real or complex normalized samples as little-endian unsigned I/Q."""
    words = []
    for index, sample in enumerate(samples):
        value = normalized_sample(sample, index)
        words.extend(round((1 + max(-1, min(1, part))) * 32767.5)
                     for part in (value.real, value.imag))
    return struct.pack(f"<{len(words)}H", *words)


def iq_payload(pattern, *, bits="10100110", symbol_rate=2.5e6, baseband=None, period_s=3.2e-6):
    """Build a looping record at BASEBAND_RATE complex samples per second."""
    if pattern in PATTERNS:
        return encode_iq(baseband_i(pattern, n / BASEBAND_RATE) for n in range(PAIR_COUNT))
    if pattern == "bpsk":
        levels, repeats = bit_period(bits, symbol_rate, BASEBAND_RATE)
        samples = (0.5 * level for level in levels)
    elif pattern == "python":
        samples, repeats = function_period(baseband, period_s, BASEBAND_RATE)
    else:
        raise ValueError(f"Unknown baseband pattern: {pattern}")
    return encode_iq(samples) * repeats


def configure_duc(instrument, payload, carrier_hz, voltage, phase_deg=0, *, segment=SEGMENT):
    def send(command):
        instrument.command(command)
        try:
            instrument.check_error()
        except RuntimeError as error:
            raise RuntimeError(f"{command} failed ({error})") from error

    # Follow Tabor's ONE-mode sequence. Segment length counts individual words.
    for command in (
        f":FREQ:RAST {DAC_RATE}", f":SOUR:INT X{INTERPOLATION}",
        ":SOUR:MODE DUC", ":SOUR:IQM ONE", f":FREQ:RAST {DAC_RATE}",
        ":TRAC:FORM U16", f":TRAC:DEF {segment},{len(payload) // 2}",
        f":TRAC:SEL {segment}",
    ):
        send(command)
    instrument.write_waveform(payload)
    instrument.check_error()
    for command in (
        ":SOUR:FUNC:MODE ARB", f":SOUR:FUNC:MODE:SEGM {segment}",
        ":INIT:CONT ON", ":NCO:MODE SING", f":NCO:CFR1 {carrier_hz:.12g}",
        f":NCO:PHAS1 {phase_deg:.12g}", ":NCO:SIXD1 OFF", f":SOUR:VOLT {voltage:.12g}",
        ":SOUR:VOLT:OFFS 0",
    ):
        send(command)
    for query, expected in ((":SOUR:MODE?", "DUC"), (":SOUR:IQM?", "ONE"),
                            (":SOUR:INT?", f"X{INTERPOLATION}")):
        actual = instrument.query(query).upper()
        instrument.check_error()
        if actual != expected:
            raise RuntimeError(f"{query} returned {actual!r}, expected {expected}")
    for query, expected, tolerance in ((":FREQ:RAST?", DAC_RATE, 1),
                                       (":NCO:CFR1?", carrier_hz, 1),
                                       (":SOUR:VOLT?", voltage, 0.001),
                                       (":SOUR:VOLT:OFFS?", 0, 0.001)):
        actual = float(instrument.query(query))
        instrument.check_error()
        if not math.isclose(actual, expected, rel_tol=1e-6, abs_tol=tolerance):
            raise RuntimeError(f"{query} returned {actual:g}, expected {expected:g}")


def run_duc(action, pattern="mixer", carrier_hz=100e6, voltage=0.2, *,
            bits="10100110", symbol_rate=2.5e6, baseband=None, period_s=3.2e-6,
            delay_ns=0, phase_deg=0, sample_file=None, sample_sha256=None, channel=1):
    validate_awg_channel(channel)
    if action not in ("setup", "start", "stop"):
        raise ValueError(f"Unknown action: {action}")
    if action != "stop":
        if not 20e6 <= carrier_hz <= 200e6 or not 0.1 <= voltage <= 0.5:
            raise ValueError("Use a 20–200 MHz carrier and a 0.1–0.5 Vpp setting.")
        if not math.isfinite(phase_deg):
            raise ValueError("Enter a finite NCO phase in degrees.")
        phase_deg %= 360
        shift = delay_samples(delay_ns, BASEBAND_RATE)
        if pattern == "samples":
            payload, _ = load_tx_samples(sample_file, iq=True, sample_rate=BASEBAND_RATE,
                                         expected_sha256=sample_sha256)
        else:
            payload = iq_payload(pattern, bits=bits, symbol_rate=symbol_rate,
                                 baseband=baseband, period_s=period_s)
        payload = delay_record(payload, shift, stride=4)
    config = json.loads(Path(__file__).with_name("config.json").read_text())
    with Proteus(**config, allow_writes=True) as instrument:
        identity = instrument.query("*IDN?")
        if "P9484M,000002233113," not in identity:
            raise RuntimeError(f"Unexpected instrument: {identity}")
        select_awg_channel(instrument, channel)
        try:
            instrument.command(":OUTP OFF")
            instrument.check_error()
            if instrument.query(":OUTP?").upper() not in ("OFF", "0"):
                raise RuntimeError(f"CH{channel} did not confirm output OFF.")
            if action != "stop":
                configure_duc(instrument, payload, carrier_hz, voltage, phase_deg,
                              segment=playback_segment(channel, iq=True))
            if action == "start":
                instrument.command(":OUTP ON")
                instrument.check_error()
                if instrument.query(":OUTP?").upper() not in ("ON", "1"):
                    raise RuntimeError(f"CH{channel} did not confirm output ON.")
        except BaseException:
            try:
                instrument.command(":OUTP OFF")
            except OSError as error:
                raise RuntimeError(f"CH{channel} shutdown could not be sent. Check the chassis.") from error
            raise

    if action == "stop":
        return f"CH{channel} output OFF."
    carrier_mhz = carrier_hz / 1e6
    offset_mhz = BASEBAND_HZ / 1e6
    state = "ON" if action == "start" else "OFF"
    if pattern == "carrier":
        details = f"Expected carrier at {carrier_mhz:g} MHz."
    elif pattern == "mixer":
        details = f"Expected peaks at {carrier_mhz - offset_mhz:g} and {carrier_mhz + offset_mhz:g} MHz."
    elif pattern == "bpsk":
        details = f"Repeating BPSK at {carrier_mhz:g} MHz and {symbol_rate / 1e6:g} MBd."
    elif pattern == "samples":
        details = f"Repeating verified I/Q sample file at {carrier_mhz:g} MHz."
    else:
        details = f"Repeating Python I/Q at {carrier_mhz:g} MHz."
    return (f"CH{channel} output {state}. {details} Loaded {len(payload) // 4:,} I/Q pairs. "
            f"Baseband delay {shift * 1e9 / BASEBAND_RATE:g} ns, NCO phase {phase_deg:g} deg.")
