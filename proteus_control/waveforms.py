"""Waveform math only. Values are normalized to [-1, 1] before DAC encoding."""

import math
import struct
from fractions import Fraction

SAMPLE_RATE = 1_000_000_000
SHAPES = ("sine", "square", "triangle", "sawtooth", "pulse")


def delay_samples(delay_ns, sample_rate):
    """Round a requested positive delay to the nearest sample."""
    if not 0 <= delay_ns <= 1_000_000:
        raise ValueError("Use a record delay from 0 to 1,000,000 ns.")
    return round(delay_ns * sample_rate / 1e9)


def delay_record(record, samples, stride=1):
    """Circularly delay values or a packed record with stride bytes per sample."""
    shift = (samples * stride) % len(record)
    return record[-shift:] + record[:-shift] if shift else record


def plan_waveform(shape, frequency, duty=0.5):
    if shape not in SHAPES:
        raise ValueError("Unknown waveform shape.")
    if not math.isfinite(frequency) or not 0 < frequency <= 100_000_000:
        raise ValueError("Choose a frequency above 0 and at most 100 MHz.")
    if not math.isfinite(duty) or not 0 < duty < 1:
        raise ValueError("Duty cycle must be greater than 0 and less than 1.")
    ratio = Fraction(str(frequency)) / SAMPLE_RATE
    # A repeatable record must contain whole periods AND a multiple of 64 samples.
    count = math.lcm(ratio.denominator, 64)
    count *= max(1, math.ceil(1024 / count))
    if count > 1_000_000:
        raise ValueError("Exact frequency needs too much memory; try a rounder frequency, e.g. 1e6.")
    if shape in ("square", "pulse") and min(duty, 1-duty) * SAMPLE_RATE / frequency < 2:
        raise ValueError("High and low intervals must each span at least two samples.")
    return count, ratio


def generate(shape, frequency, duty=0.5, falling=False):
    count, ratio = plan_waveform(shape, frequency, duty)
    values = []
    for n in range(count):
        phase = ((n * ratio.numerator) % ratio.denominator) / ratio.denominator
        if shape == "sine":
            value = math.sin(2 * math.pi * phase)
        elif shape in ("square", "pulse"):
            value = 1.0 if phase < duty else -1.0
        elif shape == "triangle":
            value = 1 - 4 * abs(phase - 0.5)
        else:
            value = 2 * phase - 1
            if falling:
                value = -value
        values.append(value)
    codes = [round((v + 1) * 32767.5) for v in values]
    return values, struct.pack(f"<{count}H", *codes), count * ratio
