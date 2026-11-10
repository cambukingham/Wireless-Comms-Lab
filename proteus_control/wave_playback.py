"""Direct AWG playback shared by the bench app and command line."""

import json
import math
from datetime import datetime, timezone
from pathlib import Path

from baseband import bit_period, function_period, real_payload
from channels import playback_segment, select_awg_channel, validate_awg_channel
from proteus import connect
from research_files import load_tx_samples
from waveforms import SAMPLE_RATE, delay_record, delay_samples, generate


def checked(instrument, command):
    print(command, flush=True)
    instrument.command(command)
    instrument.check_error()


def run_wave(action, shape="sine", freq=1e6, vpp=0.2, duty=0.5, falling=False, *, delay_ns=0,
             bits="10100110", symbol_rate=2.5e6, baseband=None, period_s=3.2e-6,
             sample_file=None, sample_sha256=None, channel=1):
    validate_awg_channel(channel)
    segment = playback_segment(channel)
    if action not in ("preview", "setup", "start", "stop"):
        raise ValueError(f"Unknown waveform action: {action}")
    sample_count = 0
    if action != "stop":
        if not 0.1 <= vpp <= 0.5:
            raise ValueError("Use 0.1 to 0.5 Vpp for this playback mode.")
        if falling and shape != "sawtooth":
            raise ValueError("Falling slope applies only to sawtooth.")
        if duty != 0.5 and shape not in ("square", "pulse"):
            raise ValueError("Duty cycle applies only to square and pulse.")
        if shape == "nrz":
            samples, repeats = bit_period(bits, symbol_rate, SAMPLE_RATE)
            payload = real_payload(samples) * repeats
            name = f"Bipolar NRZ at {symbol_rate / 1e6:g} MBd"
        elif shape == "python":
            samples, repeats = function_period(baseband, period_s, SAMPLE_RATE)
            payload = real_payload(samples) * repeats
            name = f"Python baseband, {round(period_s * SAMPLE_RATE) * 1e6 / SAMPLE_RATE:g} us repeat"
        elif shape == "samples":
            payload, _ = load_tx_samples(sample_file, iq=False, sample_rate=SAMPLE_RATE,
                                         expected_sha256=sample_sha256)
            name = "Verified real sample file"
        else:
            _, payload, cycles = generate(shape, freq, duty, falling)
            name = f"{shape.title()} at {freq:g} Hz across {cycles} cycles"
        shift = delay_samples(delay_ns, SAMPLE_RATE)
        payload = delay_record(payload, shift, stride=2)
        sample_count = len(payload) // 2
        summary = f"{name}, {vpp:g} Vpp setting, zero offset into 50 ohms"
        details = f"{sample_count:,} samples at {SAMPLE_RATE:g} samples/s"
        if shape in ("square", "pulse"):
            details += f", {100 * duty:g}% duty"
        if delay_ns:
            details += f", {shift * 1e9 / SAMPLE_RATE:g} ns record delay"
        if action == "preview":
            return f"{summary}\n{details}\nOffline preview."
    folder = Path(__file__).resolve().parent
    with connect(allow_writes=True) as instrument:
        identity = instrument.query("*IDN?")
        if "P9484M,000002233113," not in identity:
            raise RuntimeError(f"Unexpected instrument: {identity}")
        select_awg_channel(instrument, channel)
        instrument.command(":OUTP OFF")
        try:
            for _ in range(32):
                previous = instrument.query(":SYST:ERR?")
                if int(previous.split(",", 1)[0]) == 0:
                    break
                print(f"Previous error: {previous}")
            else:
                raise RuntimeError("Error queue did not clear.")
            if instrument.query(":OUTP?").upper() not in ("OFF", "0"):
                raise RuntimeError(f"CH{channel} did not confirm output OFF.")
            if action != "stop":
                for command in (
                    ":SOUR:MODE DIRECT", ":SOUR:INT NONE", ":SOUR:PTR X1",
                    f":FREQ:RAST {SAMPLE_RATE}", ":TRAC:FORM U16",
                    ":SOUR:FUNC:MODE ARB", ":INIT:CONT ON",
                    f":TRAC:DEF {segment},{sample_count}", f":TRAC:SEL {segment}",
                ):
                    checked(instrument, command)
                instrument.write_waveform(payload)
                instrument.check_error()
                for command in (
                    f":SOUR:FUNC:MODE:SEGM {segment}", f":SOUR:VOLT {vpp}",
                    ":SOUR:VOLT:OFFS 0",
                ):
                    checked(instrument, command)
                for query, expected in ((":FREQ:RAST?", SAMPLE_RATE),
                                        (":SOUR:VOLT?", vpp),
                                        (":SOUR:VOLT:OFFS?", 0)):
                    actual = float(instrument.query(query))
                    instrument.check_error()
                    if not math.isclose(actual, expected, rel_tol=1e-6, abs_tol=1e-4):
                        raise RuntimeError(f"Readback mismatch: {query} returned {actual}")
            if action == "start":
                checked(instrument, ":OUTP ON")
            state = instrument.query(":OUTP?")
            instrument.check_error()
            expected = ("ON", "1") if action == "start" else ("OFF", "0")
            if state.upper() not in expected:
                raise RuntimeError(f"Unexpected output state: {state}")
            now = datetime.now(timezone.utc)
            logs = folder / "logs"
            logs.mkdir(exist_ok=True)
            record = dict(action=action, channel=channel, segment=segment, shape=shape, freq=freq, vpp=vpp, duty=duty,
                          falling=falling, delay_ns=delay_ns, identity=identity, output_state=state,
                          sample_rate=SAMPLE_RATE, samples=sample_count,
                          time_utc=now.isoformat())
            if shape == "nrz":
                record.update(bits=bits, symbol_rate=symbol_rate)
            elif shape == "python":
                record["period_s"] = period_s
            elif shape == "samples":
                record.update(sample_file=sample_file, sample_sha256=sample_sha256)
            (logs / (now.strftime("%Y%m%dT%H%M%S_%fZ") + "_wave.json")).write_text(
                json.dumps(record, indent=2) + "\n")
        except BaseException:
            try:
                instrument.command(":OUTP OFF")
            except OSError:
                pass
            raise
    if action == "stop":
        return f"CH{channel} output OFF."
    state_label = "ON" if action == "start" else "OFF"
    return f"CH{channel} output {state_label}. {summary}\n{details}"
