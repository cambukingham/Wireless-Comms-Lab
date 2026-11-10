"""Portable waveform logs and offline comparisons, independent of instrument access."""

import csv
from datetime import datetime, timezone
import hashlib
import io
import json
import math
from pathlib import Path
import struct

from research_files import load_artifact, load_tx_samples, save_artifact
from rx_capture import load_capture

MAX_SAMPLES = 262144
COMPARE_SAMPLES = 65536


def _numpy():
    try:
        import numpy as np
    except ImportError as error:
        raise RuntimeError("Waveform comparison needs NumPy in the Python installation running WINLAB Bench.") from error
    return np


def save_waveform_log(path, samples, sample_rate, *, iq=False, units="relative", domain=None,
                      center_hz=None, repeat=False, provenance=None):
    """Public export helper for samples recorded/generated on any bench."""
    if not 2 <= len(samples) <= MAX_SAMPLES or not math.isfinite(sample_rate) or sample_rate <= 0:
        raise ValueError(f"Use 2–{MAX_SAMPLES:,} samples and a positive finite sample rate.")
    domain = domain or ("baseband" if iq else "real")
    if domain not in ("baseband", "real"):
        raise ValueError("Waveform domain must be real or baseband.")
    values = []
    for sample in samples:
        value = complex(sample)
        if not math.isfinite(value.real) or not math.isfinite(value.imag) or (not iq and value.imag != 0):
            raise ValueError("Samples must be finite; complex samples require iq=True.")
        values.extend((value.real, value.imag) if iq else (value.real,))
    if center_hz is not None and not math.isfinite(center_hz):
        raise ValueError("Center frequency must be finite.")
    settings = dict(samples=len(samples), sample_rate=sample_rate, iq=bool(iq), units=str(units),
                    domain=domain, center_hz=center_hz, repeat=bool(repeat),
                    provenance=provenance or {}, encoding="f64-le-iq" if iq else "f64-le")
    return save_artifact(path, "waveform_log", settings, struct.pack(f"<{len(values)}d", *values))


def _tx_series(settings, folder=None):
    """Reconstruct requested DAC/baseband samples, explicitly not a measured TX."""
    np = _numpy()
    from baseband import bit_period, real_payload
    from duc import BASEBAND_RATE, iq_payload
    from waveforms import SAMPLE_RATE, delay_record, delay_samples, generate
    config = settings.copy()
    mode = config.get("mode")
    iq = mode == "duc"
    rate = BASEBAND_RATE if iq else SAMPLE_RATE
    source = config.get("pattern" if iq else "shape")
    if source == "python":
        raise ValueError("A Python function cannot be reconstructed from settings. Export its actual samples with save_waveform_log().")
    if source == "samples":
        if not config.get("sample_sha256"):
            raise ValueError("This TX plan lacks its sample checksum. Export actual samples, or reload and save the plan with its sample hash.")
        path = Path(config["sample_file"])
        if not path.is_absolute() and folder:
            path = Path(folder) / path
        payload, _ = load_tx_samples(path, iq=iq, sample_rate=rate, expected_sha256=config.get("sample_sha256"))
    elif iq:
        payload = iq_payload(source, bits=config.get("bits", "10100110"), symbol_rate=config.get("symbol_rate", 2.5e6))
    elif source == "nrz":
        samples, repeats = bit_period(config["bits"], config["symbol_rate"], rate)
        payload = real_payload(samples) * repeats
    elif source in ("sine", "square", "triangle", "sawtooth", "pulse"):
        _, payload, _ = generate(source, config["freq"], config.get("duty", .5), config.get("falling", False))
    else:
        raise ValueError("Choose a supported TX waveform or load a log containing actual samples.")
    payload = delay_record(payload, delay_samples(config.get("delay_ns", 0), rate), stride=4 if iq else 2)
    values = np.frombuffer(payload, dtype="<u2").astype(float) / 32767.5 - 1
    if iq:
        values = values[0::2] + 1j * values[1::2]
        values *= np.exp(1j * np.deg2rad(config.get("phase_deg", 0)))
    else:
        values *= config.get("vpp", .2) / 2
    return dict(values=values, sample_rate=rate, iq=iq, units="normalized DAC" if iq else "V nominal",
                domain="baseband" if iq else "real", center_hz=config.get("carrier_hz") if iq else None,
                repeat=True, provenance=dict(source="Reconstructed requested TX; not a measured output", settings=config))


def tx_descriptor(settings):
    if "error" in settings:
        raise ValueError(settings["error"])
    checksum = hashlib.sha256(json.dumps(settings, sort_keys=True, allow_nan=False).encode()).hexdigest()
    return dict(kind="tx_settings", settings=settings.copy(), sha256=checksum,
                label="Current TX settings (reconstructed)")


def _csv_series(path, content=None):
    times, values = [], []
    with io.StringIO((Path(path).read_bytes() if content is None else content).decode("utf-8-sig"), newline="") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames == ["time_s", "value"]:
            iq = False
        elif reader.fieldnames == ["time_s", "i", "q"]:
            iq = True
        else:
            raise ValueError("CSV headers must be time_s,value or time_s,i,q. Use seconds and uniformly spaced samples.")
        for row in reader:
            if len(times) >= MAX_SAMPLES:
                raise ValueError("CSV exceeds the waveform sample limit.")
            times.append(float(row["time_s"]))
            values.append(complex(float(row["i"]), float(row["q"])) if iq else float(row["value"]))
    if len(times) < 4:
        raise ValueError("CSV needs at least four samples.")
    step = (times[-1] - times[0]) / (len(times) - 1)
    if (not all(math.isfinite(time) for time in times) or not math.isfinite(step) or step <= 0
            or any(abs((b - a) - step) > step * 1e-4 for a, b in zip(times, times[1:]))):
        raise ValueError("CSV timestamps must increase uniformly; irregular samples need resampling before import.")
    return dict(values=values, sample_rate=1 / step, iq=iq, units="CSV relative",
                domain="baseband" if iq else "real", center_hz=None, repeat=False,
                provenance=dict(source="Imported CSV; amplitude units are unspecified", first_time_s=times[0]))


def load_series(descriptor):
    np = _numpy()
    if descriptor.get("kind") == "tx_settings":
        if tx_descriptor(descriptor["settings"])["sha256"] != descriptor["sha256"]:
            raise ValueError("TX settings changed since selection. Select them again.")
        result = _tx_series(descriptor["settings"])
    else:
        path = Path(descriptor["file"])
        if path.stat().st_size > 12_000_000:
            raise ValueError("Waveform file exceeds 12 MB.")
        if path.suffix.lower() == ".csv":
            content = path.read_bytes()
            checksum = hashlib.sha256(content).hexdigest()
            result = _csv_series(path, content)
        else:
            content = json.loads(path.read_text(encoding="utf-8"))
            kind = content.get("kind")
            if kind == "capture":
                settings, values, checksum = load_capture(path)
                iq = settings["mode"] == "ddc"
                result = dict(values=values, sample_rate=settings["sample_rate"], iq=iq,
                              units="normalized ADC" if iq else "V nominal", domain="baseband" if iq else "real",
                              center_hz=settings.get("center_hz"), repeat=False, provenance=settings)
            elif kind == "tx_samples":
                settings, _, checksum = load_artifact(path, kind)
                payload, _ = load_tx_samples(path, iq=settings["iq"], sample_rate=settings["sample_rate"])
                values = np.frombuffer(payload, dtype="<u2").astype(float) / 32767.5 - 1
                if settings["iq"]:
                    values = values[0::2] + 1j * values[1::2]
                result = dict(values=values, sample_rate=settings["sample_rate"], iq=settings["iq"],
                              units="normalized DAC", domain="baseband" if settings["iq"] else "real",
                              center_hz=None, repeat=True, provenance=settings)
            elif kind == "tx_plan":
                settings, _, checksum = load_artifact(path, kind)
                result = _tx_series(settings, path.parent)
            elif kind == "waveform_log":
                settings, raw, checksum = load_artifact(path, kind)
                count, iq = settings["samples"], settings["iq"]
                if (type(count) is not int or not 2 <= count <= MAX_SAMPLES or type(iq) is not bool
                        or len(raw) != count * (16 if iq else 8)
                        or settings.get("encoding") != ("f64-le-iq" if iq else "f64-le")):
                    raise ValueError("Waveform log sample layout is invalid.")
                values = np.frombuffer(raw, dtype="<f8")
                result = settings.copy()
                result["values"] = values[0::2] + 1j * values[1::2] if iq else values
            elif kind is None and {"shape", "freq", "vpp", "identity"} <= content.keys():
                # Older bench direct-playback JSON logs store settings only.
                checksum = hashlib.sha256(path.read_bytes()).hexdigest()
                settings = {key: content[key] for key in ("shape", "freq", "vpp", "duty", "falling", "delay_ns", "bits", "symbol_rate", "channel") if key in content}
                settings["mode"] = "direct"
                result = _tx_series(settings, path.parent)
                result["provenance"]["logged_identity"] = content["identity"]
            else:
                raise ValueError("Load a WINLAB capture, TX plan/sample file, waveform log, or a supported CSV.")
        if descriptor.get("sha256") is not None and descriptor["sha256"] != checksum:
            raise ValueError("The selected waveform file changed. Reload it before comparing.")
        descriptor = dict(descriptor, sha256=checksum)
    result["values"] = np.asarray(result["values"])
    if (not 2 <= len(result["values"]) <= MAX_SAMPLES or not np.all(np.isfinite(result["values"]))
            or not math.isfinite(result["sample_rate"]) or result["sample_rate"] <= 0
            or result.get("domain") not in ("baseband", "real")
            or (result.get("center_hz") is not None and not math.isfinite(result["center_hz"]))):
        raise ValueError("Waveform values, rate or domain are invalid.")
    result["descriptor"] = descriptor
    return result


def inspect_waveform(path):
    descriptor = dict(kind="file", file=str(Path(path).resolve()), label=Path(path).name)
    result = load_series(descriptor)
    descriptor = result["descriptor"].copy()
    descriptor["info"] = dict(sample_rate=result["sample_rate"], samples=len(result["values"]),
                              domain=result["domain"], units=result["units"], center_hz=result.get("center_hz"),
                              provenance=result.get("provenance", {}))
    return descriptor


def export_series(path, descriptor):
    result = load_series(descriptor)
    return save_waveform_log(path, result["values"], result["sample_rate"], iq=result["iq"], units=result["units"],
                             domain=result["domain"], center_hz=result.get("center_hz"), repeat=result.get("repeat", False),
                             provenance=dict(source=descriptor, details=result.get("provenance", {})))


def resample(values, source_rate, target_rate, maximum=COMPARE_SAMPLES, *, repeat=False):
    """Windowed-sinc rate conversion; the output grid always starts at sample 0."""
    np = _numpy()
    ratio = target_rate / source_rate
    if not 1 / 64 <= ratio <= 1:
        raise ValueError("Rate ratios above 64:1 need preprocessing before comparison.")
    count = maximum if repeat else min(maximum, math.floor((len(values) - 1) * ratio + 1e-8) + 1)
    if math.isclose(source_rate, target_rate, rel_tol=1e-12):
        return np.asarray(values)[np.arange(count) % len(values)] if repeat else np.asarray(values[:count])
    radius = math.ceil(24 / ratio)
    cutoff = .45 * ratio
    offsets = np.arange(-radius, radius + 1)
    output = np.empty(count, dtype=complex if np.iscomplexobj(values) else float)
    for start in range(0, count, 256):
        positions = np.arange(start, min(start + 256, count)) / ratio
        indices = np.floor(positions).astype(int)[:, None] + offsets
        distance = positions[:, None] - indices
        weights = 2 * cutoff * np.sinc(2 * cutoff * distance) * (.5 + .5 * np.cos(np.pi * distance / (radius + 1)))
        if not repeat:
            weights *= (indices >= 0) & (indices < len(values))
        weights /= weights.sum(axis=1)[:, None]
        addresses = indices % len(values) if repeat else np.clip(indices, 0, len(values) - 1)
        output[start:start + len(positions)] = (values[addresses] * weights).sum(axis=1)
    return output


def compare_waveforms(reference, received, options):
    np = _numpy()
    ref, rx = load_series(reference), load_series(received)
    if ref["domain"] != rx["domain"]:
        raise ValueError("Compare matching domains: real RF with real RF, or baseband with baseband. Downconvert RF captures before comparing to I/Q.")
    rate = min(ref["sample_rate"], rx["sample_rate"])
    b = resample(rx["values"], rx["sample_rate"], rate)
    repeat = bool(ref.get("repeat"))
    period = math.ceil(len(ref["values"]) * rate / ref["sample_rate"])
    if repeat:
        if period > COMPARE_SAMPLES:
            raise ValueError(f"A repeating reference must fit within {COMPARE_SAMPLES:,} common-rate samples. Use a shorter record or compare a non-repeating log.")
        a = resample(ref["values"], ref["sample_rate"], rate, len(b) + period, repeat=True)
    else:
        a = resample(ref["values"], ref["sample_rate"], rate)
    shift = float(options.get("extra_shift_hz", 0))
    if options.get("match_centers", True) and ref.get("center_hz") is not None and rx.get("center_hz") is not None:
        shift += ref["center_hz"] - rx["center_hz"]
    if not math.isfinite(shift) or abs(shift) >= rate / 2:
        raise ValueError("Reference frequency shift must be finite and within the common Nyquist band.")
    if shift:
        a = a * np.exp(2j * np.pi * shift * np.arange(len(a)) / rate)
    mode = options.get("alignment", "Auto lag")
    minimum = max(32, min(len(a), len(b)) // 2)
    if min(len(a), len(b)) < 64:
        raise ValueError("At least 64 samples at the common sample rate are needed.")
    if mode == "Auto lag":
        length = 1 << (len(a) + len(b) - 2).bit_length()
        correlation = np.fft.ifft(np.fft.fft(b, length) * np.conj(np.fft.fft(a, length)))
        lags = np.arange(-(len(a) - 1), len(b))
        cross = np.concatenate((correlation[-(len(a) - 1):], correlation[:len(b)]))
        start_a = np.maximum(0, -lags)
        start_b = np.maximum(0, lags)
        counts = np.minimum(len(a) - start_a, len(b) - start_b)
        pa = np.concatenate(([0j], np.cumsum(a)))
        pb = np.concatenate(([0j], np.cumsum(b)))
        ea = np.concatenate(([0.0], np.cumsum(abs(a) ** 2)))
        eb = np.concatenate(([0.0], np.cumsum(abs(b) ** 2)))
        sa, sb = pa[start_a + counts] - pa[start_a], pb[start_b + counts] - pb[start_b]
        va = np.maximum(ea[start_a + counts] - ea[start_a] - abs(sa) ** 2 / counts, 0)
        vb = np.maximum(eb[start_b + counts] - eb[start_b] - abs(sb) ** 2 / counts, 0)
        covariance = cross - sb * np.conj(sa) / counts
        denominator = np.sqrt(va * vb)
        scores = np.divide(abs(covariance), denominator, out=np.zeros(len(lags)), where=denominator > 1e-18)
        valid = counts >= minimum
        if repeat:
            valid &= (lags >= -period) & (lags <= 0)
        scores[~valid] = -1
        peak = float(scores.max())
        if peak < 0:
            raise ValueError("No sufficiently long overlap was found.")
        # Periodic signals can have several equivalent alignments. Prefer the
        # largest overlap, then the smallest shift, rather than an edge match.
        candidates = np.flatnonzero(scores >= peak - 1e-8)
        chosen = min(candidates, key=lambda index: (-int(counts[index]), abs(int(lags[index]))))
        lag = int(lags[chosen])
    elif mode in ("Manual lag", "Start-to-start"):
        requested = float(options.get("manual_lag_s", 0)) if mode == "Manual lag" else 0
        if not math.isfinite(requested):
            raise ValueError("Enter a finite manual lag.")
        lag = round(requested * rate)
    else:
        raise ValueError("Choose Auto lag, Manual lag or Start-to-start.")
    ia, ib = max(0, -lag), max(0, lag)
    count = min(len(a) - ia, len(b) - ib)
    if count < minimum:
        raise ValueError("The requested lag leaves too little overlapping data.")
    a, b = a[ia:ia + count], b[ib:ib + count]
    ac, bc = a - a.mean(), b - b.mean()
    energy = float(np.vdot(ac, ac).real)
    rx_energy = float(np.vdot(bc, bc).real)
    if energy < 1e-18 or rx_energy < 1e-18:
        raise ValueError("A waveform has no usable variation. For a constant carrier reference, match its RF center or enter a frequency shift.")
    gain = complex(np.vdot(ac, bc) / energy)
    dc = complex(b.mean() - gain * a.mean())
    fitted = gain * a + dc
    raw_rmse = float(np.sqrt(np.mean(abs(b - a) ** 2))) if ref["units"] == rx["units"] else None
    apply_fit = options.get("scaling", "Fit gain / phase") == "Fit gain / phase"
    if not apply_fit and ref["units"] != rx["units"]:
        raise ValueError("Raw levels require matching amplitude units. Choose Fit gain / phase to compare shape across different units.")
    shown = fitted if apply_fit else a
    error = b - shown
    rmse = float(np.sqrt(np.mean(abs(error) ** 2)))
    relative = float(np.mean(abs(b - fitted) ** 2) / (rx_energy / count))
    corr = min(1.0, float(abs(np.vdot(ac, bc)) / math.sqrt(energy * rx_energy)))
    warnings = ["Lag is waveform alignment, not calibrated propagation time or device latency.",
                "Gain/phase fitting can hide absolute level and phase differences; inspect the fitted parameters and raw-level error."]
    if not math.isclose(ref["sample_rate"], rx["sample_rate"], rel_tol=1e-12):
        warnings.append("Rates differ: a low-pass resampler limits this comparison to the common lower-rate bandwidth.")
    if (ref["domain"] == "baseband" and options.get("match_centers", True)
            and (ref.get("center_hz") is None or rx.get("center_hz") is None)):
        warnings.append("A source has no RF center metadata. No center difference was applied; enter an extra reference shift if needed.")
    if repeat:
        warnings.append("Repeating reference: alignment is ambiguous by whole waveform periods.")
    if corr < .6:
        warnings.append("Low correlation: these waveforms may not describe the same transfer.")
    if len(ref["values"]) * rate / ref["sample_rate"] > COMPARE_SAMPLES or len(rx["values"]) * rate / rx["sample_rate"] > COMPARE_SAMPLES:
        warnings.append(f"Comparison uses at most the first {COMPARE_SAMPLES:,} common-rate samples per source.")
    curves = dict(time_s=(np.arange(count) / rate).tolist(), reference_i=np.real(shown).tolist(),
                  reference_q=np.imag(shown).tolist(), received_i=np.real(b).tolist(), received_q=np.imag(b).tolist(),
                  error_i=np.real(error).tolist(), error_q=np.imag(error).tolist())
    sources = []
    for source in (ref, rx):
        sources.append(dict(descriptor=source["descriptor"], sample_rate=source["sample_rate"],
                            samples=len(source["values"]), units=source["units"], domain=source["domain"],
                            center_hz=source.get("center_hz"), provenance=source.get("provenance", {})))
    return dict(algorithm="waveform-compare-v1", numpy_version=np.__version__,
                analyzed_utc=datetime.now(timezone.utc).isoformat(),
                sources=sources, options=options, sample_rate=rate, samples=count,
                lag_samples=lag, lag_s=lag / rate, reference_start_sample=ia, received_start_sample=ib,
                reference_shift_hz=shift, gain_magnitude=abs(gain), gain_phase_deg=math.degrees(math.atan2(gain.imag, gain.real)),
                dc_i=dc.real, dc_q=dc.imag, fit_applied=apply_fit, correlation=corr, rmse=rmse,
                raw_rmse=raw_rmse, fitted_residual_db=10 * math.log10(max(relative, 1e-30)),
                units=rx["units"], warnings=warnings, curves=curves,
                summary=f"Correlation {corr:.5f} · {count:,} aligned samples at {rate / 1e6:g} MS/s")
