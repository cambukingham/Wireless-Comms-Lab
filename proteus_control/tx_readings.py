"""Selected AWG channel readback and a matched-impedance attenuation estimate."""

import math
from dataclasses import dataclass

from proteus import connect
from channels import select_awg_channel, validate_awg_channel


@dataclass(frozen=True)
class PadEstimate:
    minimum_db: float
    additional_db: float
    rx_vpp: float
    target_vpp: float


def estimate_pad(tx_vpp, rx_full_scale_vpp, *, path_gain_db=0, pad_db=0, headroom_db=6):
    """Estimate voltage across a matched path using gain before the entered pad."""
    if not all(math.isfinite(value) for value in (tx_vpp, rx_full_scale_vpp, path_gain_db,
                                                  pad_db, headroom_db)):
        raise ValueError("Enter finite attenuation planning values.")
    if tx_vpp <= 0 or rx_full_scale_vpp <= 0 or pad_db < 0 or headroom_db < 0:
        raise ValueError("Use positive Vpp values and nonnegative pad and headroom.")
    minimum = max(0, 20 * (math.log10(tx_vpp) - math.log10(rx_full_scale_vpp))
                  + path_gain_db + headroom_db)
    try:
        rx_vpp = tx_vpp * 10 ** ((path_gain_db - pad_db) / 20)
        target_vpp = rx_full_scale_vpp * 10 ** (-headroom_db / 20)
    except OverflowError as error:
        raise ValueError("Path gain or attenuation is out of range.") from error
    if not math.isfinite(rx_vpp) or not target_vpp:
        raise ValueError("Path gain or attenuation is out of range.")
    return PadEstimate(minimum, max(0, minimum - pad_db), rx_vpp, target_vpp)


def read_channel(channel=1):
    """Query the requested AWG output and restore the previous selection."""
    validate_awg_channel(channel)
    with connect(allow_writes=True) as instrument:
        identity = instrument.query("*IDN?")
        if "P9484M,000002233113," not in identity:
            raise RuntimeError(f"Unexpected instrument: {identity}")
        previous = int(instrument.query(":INST:CHAN?"))
        try:
            select_awg_channel(instrument, channel)
            output = instrument.query(":OUTP?").upper()
            mode = instrument.query(":SOUR:MODE?").upper()
            clock = float(instrument.query(":FREQ:RAST?"))
            vpp = float(instrument.query(":SOUR:VOLT?"))
            offset = float(instrument.query(":SOUR:VOLT:OFFS?"))
            if output not in ("ON", "OFF", "1", "0") or not mode:
                raise RuntimeError(f"Unexpected CH{channel} output or source-mode response.")
            state = "ON" if output in ("ON", "1") else "OFF"
            lines = [f"CH{channel} output {state} | {mode} | DAC {clock / 1e9:g} GS/s",
                     f"Level {vpp:g} Vpp | Offset {offset:g} V"]
            if mode in ("NCO", "DUC"):
                carrier = float(instrument.query(":NCO:CFR1?"))
                phase = float(instrument.query(":NCO:PHAS1?"))
                lines.append(f"NCO {carrier / 1e6:g} MHz | Phase {phase:g} deg")
            instrument.check_error()
            return "\n".join(lines)
        finally:
            if previous != channel:
                instrument.command(f":INST:CHAN {previous}")
                instrument.check_error()


def read_ch1():
    """Compatibility helper for older experiment scripts."""
    return read_channel(1)
