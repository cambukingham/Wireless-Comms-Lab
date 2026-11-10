"""Offline checks for the app's editable experiment configurations."""

from pathlib import Path

from baseband import bit_period, function_record
from channels import validate_awg_channel
from duc import BASEBAND_RATE
from waveforms import SAMPLE_RATE, delay_samples, plan_waveform


def check_transmit(settings):
    """Return a blocking error or advisory for the current TX settings."""
    if "error" in settings:
        return "error", settings["error"]
    mode = settings["mode"]
    rate = BASEBAND_RATE if mode == "duc" else SAMPLE_RATE
    source = settings["pattern" if mode == "duc" else "shape"]
    level = settings["voltage" if mode == "duc" else "vpp"]
    try:
        validate_awg_channel(settings.get("channel", 1))
        if not 0.1 <= level <= 0.5:
            raise ValueError("TX level must be between 0.1 and 0.5 Vpp.")
        if mode == "duc" and not 20e6 <= settings["carrier_hz"] <= 200e6:
            raise ValueError("DUC carrier must be between 20 and 200 MHz in this bench mode.")
        shift = delay_samples(settings.get("delay_ns", 0), rate)
        if mode == "direct":
            plan_waveform(source, settings["freq"], settings["duty"])
        elif source in ("nrz", "bpsk"):
            bit_period(settings["bits"], settings["symbol_rate"], rate)
        elif source == "python":
            function_record(settings["period_s"], rate)
        elif source == "samples" and not Path(settings["sample_file"]).is_file():
            raise ValueError("The selected sample file is missing. Reload it from TX files.")
    except ValueError as error:
        return "error", str(error)
    if source == "python":
        return "info", "Use in Python to supply baseband(t). The settings are applied when the script runs."
    if mode == "baseband" and source == "nrz" and len(set("".join(settings["bits"].split()))) == 1:
        return "warning", "All bits have the same value. The AC-coupled output cannot hold a constant level."
    if settings.get("delay_ns") and shift == 0:
        return "warning", "The record delay rounds to zero on the selected sample grid."
    if mode == "direct" and source != "sine" and settings["freq"] > 50e6:
        return "warning", "This shape has harmonics above Nyquist. Use a lower frequency for sharper edges."
    return "info", "TX settings pass the offline checks."


def receive_advice(rx, tx):
    if rx["mode"] == "ddc" and tx.get("mode") == "duc":
        half_band = rx["rate"] / rx["decimation"] / 2
        if abs(rx["center_hz"] - tx["carrier_hz"]) >= half_band:
            return "If receiving the selected TX, its carrier is outside the nominal DDC window."
    return ""
