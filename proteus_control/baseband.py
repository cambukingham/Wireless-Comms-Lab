"""Repeatable bit patterns and Python signals for direct playback and DUC."""

import math
import struct
from fractions import Fraction

MAX_RECORD_SAMPLES = 256_000


def validate_bits(bits, symbol_rate):
    bits = "".join(bits.split())
    if not 1 <= len(bits) <= 256 or set(bits) - {"0", "1"}:
        raise ValueError("Enter 1 to 256 binary digits (0 or 1).")
    if not 100e3 <= symbol_rate <= 20e6:
        raise ValueError("Use a symbol rate from 0.1 to 20 MBd.")
    return bits


def bit_level(bit):
    return 1.0 if bit == "1" else -1.0


def repeat_count(period_samples):
    count = math.lcm(period_samples, 64)
    count *= (1024 + count - 1) // count
    if count > MAX_RECORD_SAMPLES:
        raise ValueError("Aligned baseband record is too long. Use a shorter repeat or a rounder symbol rate.")
    return count // period_samples


def bit_period(bits, symbol_rate, sample_rate):
    bits = validate_bits(bits, symbol_rate)
    ratio = Fraction(str(symbol_rate)) / sample_rate
    # The sample phase and bit index must both repeat at the record boundary.
    period = ratio.denominator * (len(bits) // math.gcd(len(bits), ratio.numerator))
    repeats = repeat_count(period)
    values = (bit_level(bits[(n * ratio.numerator // ratio.denominator) % len(bits)])
              for n in range(period))
    return values, repeats


def function_record(period_s, sample_rate):
    if not 2 / sample_rate <= period_s <= MAX_RECORD_SAMPLES / sample_rate:
        raise ValueError(f"Use a repeat period from {2e9 / sample_rate:g} ns "
                         f"to {MAX_RECORD_SAMPLES * 1e6 / sample_rate:g} us.")
    period = round(period_s * sample_rate)
    return period, repeat_count(period)


def function_period(baseband, period_s, sample_rate):
    if not callable(baseband):
        raise ValueError("Supply a baseband(t) function from the Python tab.")
    period, repeats = function_record(period_s, sample_rate)
    return (baseband(n / sample_rate) for n in range(period)), repeats


def normalized_sample(sample, index):
    try:
        value = complex(sample)
    except (TypeError, ValueError, OverflowError) as error:
        raise ValueError(f"Baseband sample {index} must be a real or complex number.") from error
    magnitude = abs(value)
    if not math.isfinite(magnitude) or magnitude > 1 + 1e-12:
        raise ValueError(f"Baseband sample {index} must have magnitude at most 1.")
    return value


def real_payload(samples):
    """Encode real normalized samples for one DAC output."""
    words = []
    for index, sample in enumerate(samples):
        value = normalized_sample(sample, index)
        if value.imag:
            raise ValueError(f"Sample {index} has a Q component. Direct playback requires real samples.")
        words.append(round((1 + max(-1, min(1, value.real))) * 32767.5))
    return struct.pack(f"<{len(words)}H", *words)
