"""Acquire one Proteus ADC frame, preserving the original SCPI sample bytes."""

import math
import struct
import time
from datetime import datetime, timezone

from proteus import connect
from channels import ADC_CHANNELS
from research_files import load_artifact, save_artifact

RANGES = {"LOW": 0.25, "MED": 0.4, "HIGH": 0.5}
MAX_FRAME = 196608


def validate_capture_settings(*, channel, mode, rate, input_range, samples, center_hz,
                              decimation, ddc_phase, trigger, level, slope, pretrigger, timeout):
    if type(channel) is not int or channel not in ADC_CHANNELS or mode not in ("real", "ddc") or input_range not in RANGES:
        raise ValueError("Choose a valid ADC channel, mode and range.")
    if not 800e6 <= rate <= 2.7e9:
        raise ValueError("Use an ADC clock from 0.8 to 2.7 GS/s in dual-channel mode.")
    if type(samples) is not int or not 48 <= samples <= MAX_FRAME or samples % 48:
        raise ValueError(f"Frame length must be a multiple of 48 from 48 to {MAX_FRAME}.")
    if type(pretrigger) is not int or not 0 <= pretrigger < samples or pretrigger % 48:
        raise ValueError("Pretrigger must be a multiple of 48 smaller than the frame.")
    if mode == "ddc" and not 0 <= center_hz < rate / 2:
        raise ValueError(f"DDC center must be between 0 and {rate / 2e6:g} MHz (exclusive upper limit).")
    if mode == "ddc" and (decimation not in (4, 16) or not math.isfinite(ddc_phase)):
        raise ValueError("Use x4 or x16 DDC decimation and a finite phase.")
    if trigger not in ("CPU", "EXT", "SELF") or slope not in ("POS", "NEG") or not 0.1 <= timeout <= 60:
        raise ValueError("Choose a valid trigger, edge, and timeout from 0.1 to 60 s.")
    threshold = 5 if trigger == "EXT" else RANGES[input_range] / 2
    if trigger != "CPU" and not -threshold <= level <= threshold:
        raise ValueError(f"Trigger level must be within ±{threshold:g} V for the selected trigger.")


def capture(path, *, channel=1, mode="real", rate=2.5e9, input_range="HIGH", samples=4800,
            center_hz=100e6, decimation=16, ddc_phase=0, trigger="CPU", level=0,
            slope="POS", pretrigger=0, timeout=5, tx_reference=None):
    validate_capture_settings(channel=channel, mode=mode, rate=rate, input_range=input_range, samples=samples,
                              center_hz=center_hz, decimation=decimation, ddc_phase=ddc_phase, trigger=trigger,
                              level=level, slope=slope, pretrigger=pretrigger, timeout=timeout)
    if tx_reference is not None and not isinstance(tx_reference, dict):
        raise ValueError("Requested TX reference must be a settings dictionary.")
    words_per_sample = 2 if mode == "ddc" else 1
    with connect(allow_writes=True) as instrument:
        identity = instrument.query("*IDN?")
        options = instrument.query("*OPT?")
        if "P9484M,000002233113," not in identity or "AWT" not in options:
            raise RuntimeError(f"Expected the bench P9484M-AWT. Found {identity} ({options}).")

        def command(text):
            instrument.command(text)
            try:
                instrument.check_error()
            except RuntimeError as error:
                raise RuntimeError(f"{text} failed ({error})") from error

        for text in (
            ":DIG:INIT OFF", ":DIG:MODE DUAL", ":DIG:DDC:MODE REAL", ":DIG:DDC:CLKS DIG",
            ":DIG:FREQ:SOUR INT", f":DIG:FREQ {rate:.12g}",
            f":DIG:CHAN {3 - channel}", ":DIG:CHAN:STAT DIS", f":DIG:CHAN {channel}",
            ":DIG:CHAN:STAT ENAB", f":DIG:CHAN:RANG {input_range}", ":DIG:CHAN:OFFS 0",
            ":DIG:ACQ:MARK OFF", ":DIG:ACQ:AVER:STAT OFF",
        ):
            command(text)
        actual_rate = float(instrument.query(":DIG:FREQ?"))
        if not math.isclose(actual_rate, rate, rel_tol=1e-5):
            raise RuntimeError(f"ADC clock readback was {actual_rate:g}, requested {rate:g} samples/s.")
        if mode == "ddc":
            ddc_phase %= 360
            for text in (":DIG:DDC:MODE COMP", f":DIG:DDC:DEC X{decimation}",
                         f":DIG:DDC:CFR{channel} {center_hz:.12g}",
                         f":DIG:DDC:PHAS{channel} {ddc_phase:.12g}"):
                command(text)
            actual_decimation = instrument.query(":DIG:DDC:DEC?").upper()
            if actual_decimation != f"X{decimation}":
                raise RuntimeError(f"DDC readback returned {actual_decimation}, requested X{decimation}.")
            center_hz = float(instrument.query(f":DIG:DDC:CFR{channel}?"))
            ddc_phase = float(instrument.query(f":DIG:DDC:PHAS{channel}?"))
        else:
            decimation = 1
            center_hz = None
            ddc_phase = None
        trigger_source = f"CH{channel}" if trigger == "SELF" else trigger
        for text in (f":DIG:ACQ:DEF 1,{samples * words_per_sample}", ":DIG:ACQ:CAPT:ALL",
                     f":DIG:PRET {pretrigger * words_per_sample}",
                     f":DIG:TRIG:SOUR {trigger_source}"):
            command(text)
        if trigger != "CPU":
            command(":DIG:TRIG:TYPE EDGE")
            command(f":DIG:TRIG:SLOP {slope}")
            threshold_command = ":DIG:TRIG:LEV1" if trigger == "EXT" else ":DIG:TRIG:SELF"
            command(f"{threshold_command} {level:.12g}")
        armed = True
        try:
            command(":DIG:INIT ON")
            if trigger == "CPU":
                time.sleep(0.02)
                command(":DIG:TRIG:IMM")
            deadline = time.monotonic() + timeout
            while True:
                status = instrument.query(":DIG:ACQ:STAT?").split(",")
                if len(status) >= 2 and status[1].strip() == "1":
                    break
                if time.monotonic() >= deadline:
                    raise TimeoutError(f"No completed ADC frame after {timeout:g} s waiting for {trigger} trigger.")
                time.sleep(0.05)
            command(":DIG:INIT OFF")
            armed = False
            for text in (":DIG:DATA:FORM U16", ":DIG:DATA:TYPE FRAM", ":DIG:DATA:SEL ALL"):
                command(text)
            length = int(instrument.query(":DIG:DATA:SIZE?"))
            word_count = samples * words_per_sample
            word_bytes = length // word_count
            if length != word_count * word_bytes or word_bytes not in ((2, 4) if mode == "ddc" else (2,)):
                raise RuntimeError(f"Unexpected frame size {length} bytes for {samples:,} {mode} samples.")
            raw = instrument.query_binary(":DIG:DATA:READ?", length)
        finally:
            if armed:
                instrument.command(":DIG:INIT OFF")

    settings = dict(identity=identity, channel=channel, mode=mode, adc_rate=actual_rate,
                    sample_rate=actual_rate / decimation, input_range=input_range,
                    full_scale_vpp=RANGES[input_range], samples=samples, word_bytes=word_bytes,
                    center_hz=center_hz, ddc_phase=ddc_phase, decimation=decimation,
                    trigger=trigger, level=level, slope=slope, pretrigger=pretrigger,
                    captured_utc=datetime.now(timezone.utc).isoformat())
    if tx_reference is not None:
        settings["requested_tx"] = tx_reference
    checksum = save_artifact(path, "capture", settings, raw)
    return f"Saved {samples:,} {mode.upper()} samples ({len(raw):,} bytes)\nSHA-256 {checksum[:16]}…"


def disarm():
    with connect(allow_writes=True) as instrument:
        identity = instrument.query("*IDN?")
        if "P9484M,000002233113," not in identity:
            raise RuntimeError(f"Unexpected instrument: {identity}")
        instrument.command(":DIG:INIT OFF")
        instrument.check_error()
    return "ADC disarmed."


def load_capture(path):
    settings, raw, checksum = load_artifact(path, "capture")
    count = settings.get("samples")
    word_bytes = settings.get("word_bytes")
    mode = settings.get("mode")
    iq = mode == "ddc"
    if (type(settings.get("channel")) is not int or settings["channel"] not in ADC_CHANNELS
            or mode not in ("real", "ddc") or type(count) is not int or not 48 <= count <= MAX_FRAME
            or word_bytes not in ((2, 4) if iq else (2,))
            or len(raw) != count * word_bytes * (2 if iq else 1)):
        raise ValueError("Capture metadata does not match its sample layout.")
    middle = 16384 if iq else 2048
    code = "H" if word_bytes == 2 else "I"
    words = struct.unpack(f"<{len(raw) // word_bytes}{code}", raw)
    if any(word >= middle * 2 for word in words):
        raise ValueError("Sample codes exceed the expected ADC format. Raw data remains in the saved file.")
    if iq:
        samples = [complex((i - middle) / middle, (q - middle) / middle)
                   for i, q in zip(words[::2], words[1::2])]
    else:
        full_scale = settings.get("full_scale_vpp")
        if full_scale not in RANGES.values():
            raise ValueError("Invalid ADC range in capture metadata.")
        samples = [(word - middle) * full_scale / (2 * middle) for word in words]
    return settings, samples, checksum
