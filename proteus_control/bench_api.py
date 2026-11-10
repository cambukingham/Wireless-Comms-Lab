"""Use the bench panel's Transmit settings from short Python scripts."""

import json
import os

from duc import run_duc
from channels import validate_awg_channel
from wave_playback import run_wave

SETTINGS_ENV = "WINLAB_TRANSMIT_SETTINGS"


def transmit_settings():
    """Return a copy of the settings captured when Save & Run was pressed."""
    raw = os.environ.get(SETTINGS_ENV)
    if not raw:
        raise RuntimeError("Run this script from the bench app's Python tab to use panel settings.")
    settings = json.loads(raw)
    if "error" in settings:
        raise ValueError(settings["error"])
    return settings


def transmit(action="setup", *, baseband=None, channel=None):
    """Apply the snapshot. A custom baseband(t) returns normalized I + jQ."""
    if action == "stop":
        if channel is None:
            raw = os.environ.get(SETTINGS_ENV)
            channel = json.loads(raw).get("channel", 1) if raw else 1
        return run_duc("stop", channel=channel)
    settings = transmit_settings()
    if channel is not None:
        settings["channel"] = channel
    return apply_transmit(settings, action, baseband=baseband)


def apply_transmit(settings, action, *, baseband=None):
    """Apply the same settings schema from the panel or a script."""
    if action == "stop":
        return run_duc("stop", channel=validate_awg_channel(settings.get("channel", 1)))
    if action not in ("setup", "start"):
        raise ValueError("Use setup, start, or stop.")
    settings = settings.copy()
    mode = settings.pop("mode")
    if mode == "direct" and baseband is None:
        return run_wave(action, **settings)
    if mode == "baseband":
        if baseband is not None and settings["shape"] != "python":
            raise ValueError("Select Python real function to supply baseband(t) in direct baseband mode.")
        return run_wave(action, baseband=baseband, **settings)
    if mode != "duc" or (baseband is not None and settings["pattern"] != "python"):
        raise ValueError("Select Digital upconverter and Python I/Q function to supply baseband(t).")
    return run_duc(action, baseband=baseband, **settings)
