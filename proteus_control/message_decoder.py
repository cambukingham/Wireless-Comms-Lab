"""Offline, reference-assisted BPSK decoding of verified I/Q captures.

Timing, phase, polarity and a small carrier offset are estimated from a training
prefix only. Later symbol decisions are held out from that fit. This is a
repeating-message bench check, not a blind packet receiver or CRC validator.
"""

import hashlib
import math
from datetime import datetime, timezone
from pathlib import Path

from baseband import validate_bits
from rx_capture import load_capture

ALGORITHM = "bpsk-reference-v1"


def reference_bits(text, kind):
    if kind == "Bits":
        bits = "".join(text.split())
    elif kind == "Hex bytes":
        try:
            data = bytes.fromhex(text)
        except ValueError as error:
            raise ValueError("Enter complete hexadecimal bytes, such as 57 49 4E.") from error
        bits = "".join(f"{byte:08b}" for byte in data)
    elif kind == "Text (UTF-8)":
        bits = "".join(f"{byte:08b}" for byte in text.encode("utf-8"))
    else:
        raise ValueError("Choose Text (UTF-8), Hex bytes, or Bits for the reference.")
    if not bits or len(bits) > 256 or set(bits) - {"0", "1"}:
        raise ValueError("Provide 1–256 bits, or a message of 1–32 bytes.")
    if len(set(bits)) != 2:
        raise ValueError("BPSK alignment needs a reference containing both 0 and 1.")
    return bits


def bits_bytes(bits):
    return bytes(int(bits[index:index + 8], 2) for index in range(0, len(bits) - 7, 8))


def display_bytes(data):
    text = data.decode("utf-8", errors="backslashreplace")
    return "".join(character if character in "\n\t" or ord(character) >= 32
                   else f"\\x{ord(character):02x}" for character in text)


def decode_bpsk(samples, sample_rate, bits, symbol_rate):
    try:
        import numpy as np
    except ImportError as error:
        raise RuntimeError("BPSK analysis needs NumPy in the Python installation used to launch WINLAB Bench.") from error
    bits = validate_bits(bits, symbol_rate)
    if len(set(bits)) != 2:
        raise ValueError("BPSK alignment needs both 0 and 1 in the reference.")
    if not math.isfinite(sample_rate) or sample_rate <= 0:
        raise ValueError("The capture has an invalid sample rate.")
    sps = sample_rate / symbol_rate
    if sps < 4:
        raise ValueError("Use at least four I/Q samples per symbol for this decoder.")
    pattern_length = len(bits)
    training_count = math.ceil(max(32, 2 * pattern_length) * sps)
    minimum = training_count + math.ceil(max(8, pattern_length) * sps)
    if len(samples) < minimum:
        raise ValueError(f"This reference needs at least {minimum:,} I/Q pairs for training and validation; "
                         f"the capture has {len(samples):,}. Capture a longer frame or use a shorter reference.")
    z = np.asarray(samples, dtype=complex)
    if not np.all(np.isfinite(z)):
        raise ValueError("Capture samples must be finite.")
    training = z[:training_count]
    if float(np.mean(abs(training) ** 2)) < 1e-12:
        raise ValueError("The capture has too little signal to decode.")

    # Squaring removes BPSK's sign. Fit phase drift on training blocks only.
    block_size = max(16, round(4 * sps))
    block_count = training_count // block_size
    blocks = training[:block_count * block_size].reshape(block_count, block_size)
    squared = np.mean(blocks * blocks, axis=1)
    times = (np.arange(block_count) * block_size + (block_size - 1) / 2) / sample_rate
    weights = np.abs(squared)
    if float(weights.max()) == 0:
        raise ValueError("No stable BPSK carrier phase was found.")
    slope, _ = np.polyfit(times, np.unwrap(np.angle(squared)), 1, w=weights / weights.max())
    carrier_offset = float(slope / (4 * math.pi))
    if abs(carrier_offset) > .05 * symbol_rate:
        raise ValueError("Carrier offset is too large for this decoder. Set DDC center near the TX carrier.")
    corrected = z * np.exp(-2j * np.pi * carrier_offset * np.arange(len(z)) / sample_rate)
    prefix = np.concatenate(([0j], np.cumsum(corrected[:training_count])))
    levels = np.array([1 if bit == "1" else -1 for bit in bits], dtype=float)
    pattern_fft = np.fft.fft(levels)
    reverse = (-np.arange(pattern_length)) % pattern_length

    def correlations(groups):
        return np.fft.ifft(pattern_fft * np.fft.fft(groups)[reverse])

    def fit_timing(offset):
        count = math.floor((training_count - offset) / sps)
        starts = np.ceil(offset + np.arange(count) * sps).astype(int)
        ends = np.minimum(training_count, np.ceil(offset + (np.arange(count) + 1) * sps).astype(int))
        means = (prefix[ends] - prefix[starts]) / (ends - starts)
        group_index = np.arange(count) % pattern_length
        groups = (np.bincount(group_index, weights=means.real, minlength=pattern_length)
                  + 1j * np.bincount(group_index, weights=means.imag, minlength=pattern_length))
        counts = np.bincount(group_index, minlength=pattern_length)
        mean_reference = correlations(counts).real / count
        variance = np.maximum(1 - mean_reference ** 2, 1e-12)
        covariance = correlations(groups) / count - mean_reference * means.mean()
        scores = abs(covariance) ** 2 / variance
        shift = int(np.argmax(scores))
        gain = covariance[shift] / variance[shift]
        dc = means.mean() - gain * mean_reference[shift]
        quality = float(scores[shift] / max(float(np.mean(abs(means - means.mean()) ** 2)), 1e-20))
        return float(scores[shift]), shift, complex(gain), complex(dc), quality

    grid_count = min(256, max(16, math.ceil(sps * 4)))
    offsets = np.arange(grid_count) * sps / grid_count
    offset = max(offsets, key=lambda value: fit_timing(value)[0])
    step = sps / grid_count
    fine = [(offset + delta) % sps for delta in np.linspace(-step, step, 33)]
    offset = float(max(fine, key=lambda value: fit_timing(value)[0]))
    _, shift, gain, dc, quality = fit_timing(offset)
    if abs(gain) < 1e-8:
        raise ValueError("The reference could not be aligned to a usable BPSK signal.")

    # Decide only complete symbols, using the middle half away from transitions.
    symbol_count = math.floor((len(z) - offset) / sps)
    starts = offset + np.arange(symbol_count) * sps
    lo = np.ceil(starts + .25 * sps).astype(int)
    hi = np.ceil(starts + .75 * sps).astype(int)
    full_prefix = np.concatenate(([0j], np.cumsum(corrected)))
    means = (full_prefix[hi] - full_prefix[lo]) / (hi - lo)
    decisions = ((means - dc) * np.conj(gain) / abs(gain)).real
    received = "".join("1" if value >= 0 else "0" for value in decisions)
    expected = "".join(bits[(index + shift) % pattern_length] for index in range(symbol_count))
    errors = [index for index, (actual, intended) in enumerate(zip(received, expected)) if actual != intended]
    validation_start = int(np.searchsorted(starts, training_count))
    validation_count = symbol_count - validation_start
    validation_errors = sum(index >= validation_start for index in errors)
    frames = []
    for begin in range((-shift) % pattern_length, symbol_count - pattern_length + 1, pattern_length):
        actual = received[begin:begin + pattern_length]
        bit_errors = sum(a != b for a, b in zip(actual, bits))
        byte_errors = None
        if pattern_length % 8 == 0:
            byte_errors = sum(a != b for a, b in zip(bits_bytes(actual), bits_bytes(bits)))
        frames.append(dict(start_bit=begin, validation=begin >= validation_start,
                           received_bits=actual, bit_errors=bit_errors, byte_errors=byte_errors))
    warnings = []
    if quality < .6:
        warnings.append("Reference alignment is weak. Treat decoded text and error counts as uncertain.")
    if not any(frame["validation"] for frame in frames):
        warnings.append("No complete held-out message is available; capture a longer frame for byte comparison.")
    warnings.append("Known-reference alignment resolves timing and polarity. This is a short capture check, not a CRC or long-run BER measurement.")
    return dict(algorithm=ALGORITHM, numpy_version=np.__version__,
                reference_bits=bits, reference_sha256=hashlib.sha256(bits.encode("ascii")).hexdigest(),
                symbol_rate=symbol_rate, sample_rate=sample_rate, samples_per_symbol=sps,
                training_samples=training_count, training_symbols=validation_start,
                timing_offset_samples=offset, reference_start_bit=shift,
                carrier_offset_hz=carrier_offset, phase_deg=math.degrees(math.atan2(gain.imag, gain.real)),
                gain=abs(gain), dc_i=dc.real, dc_q=dc.imag, alignment_quality=min(1.0, max(0.0, quality)),
                reliable_alignment=quality >= .6, complete_symbols=symbol_count,
                received_bits=received, expected_bits=expected, mismatch_indices=errors,
                bit_errors=len(errors), validation_start=validation_start,
                validation_symbols=validation_count, validation_errors=validation_errors,
                validation_error_fraction=validation_errors / validation_count if validation_count else None,
                byte_aligned=pattern_length % 8 == 0, frames=frames, warnings=warnings)


def analyze_capture(path, bits, symbol_rate, expected_sha256=None, reference_source="Manual reference"):
    settings, samples, checksum = load_capture(path)
    if expected_sha256 is not None and checksum != expected_sha256:
        raise ValueError("The capture changed since it was loaded. Reload it before decoding.")
    if settings["mode"] != "ddc":
        raise ValueError("Load a DDC I/Q capture for BPSK decoding. Real RF captures need downconversion first.")
    result = decode_bpsk(samples, settings["sample_rate"], bits, symbol_rate)
    result["capture"] = dict(file=str(Path(path).resolve()), sha256=checksum, settings=settings)
    result["reference_source"] = reference_source
    result["analyzed_utc"] = datetime.now(timezone.utc).isoformat()
    result["summary"] = (f"{'Aligned' if result['reliable_alignment'] else 'Uncertain alignment'} · "
                         f"{result['validation_errors']} mismatches / {result['validation_symbols']} held-out bits")
    return result
