"""Offline regression checks for channel targeting; never contacts the bench."""

import contextlib
import io
import json
import os
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import bench_api
from channels import AWG_CHANNELS
import duc
import rx_capture
import tx_readings
import wave_playback


class Instrument:
    def __init__(self, *, reject_selection=False):
        self.channel = 1
        self.reject_selection = reject_selection
        self.commands = []
        self.outputs = {ch: "ON" for ch in AWG_CHANNELS}
        self.values = {":SOUR:MODE": "DIRECT", ":FREQ:RAST": "1000000000",
                       ":SOUR:VOLT": "0.2", ":SOUR:VOLT:OFFS": "0",
                       ":DIG:FREQ": "2500000000"}
        self.uploads = []
        self.words = 0

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        pass

    def command(self, command):
        self.commands.append((self.channel, command))
        key, value = command.split(" ", 1) if " " in command else (command, "")
        if key == ":INST:CHAN" and not self.reject_selection:
            self.channel = int(value)
        elif key == ":OUTP":
            self.outputs[self.channel] = value
        elif key == ":DIG:ACQ:DEF":
            self.words = int(value.split(",")[1])
        else:
            self.values[key] = value

    def query(self, command):
        if command == "*IDN?":
            return "Tabor Electronics,P9484M,000002233113,1.240.22"
        if command == "*OPT?":
            return "DUC,AWT"
        if command == ":INST:CHAN?":
            return str(self.channel)
        if command == ":OUTP?":
            return self.outputs[self.channel]
        if command == ":SYST:ERR?":
            return '0,"No error"'
        if command == ":DIG:ACQ:STAT?":
            return "1,1,0,1"
        if command == ":DIG:DATA:SIZE?":
            return str(self.words * 2)
        return self.values[command.removesuffix("?")]

    def check_error(self):
        pass

    def write_waveform(self, payload):
        self.uploads.append((self.channel, payload))

    def query_binary(self, command, length):
        midpoint = 16384 if self.values[":DIG:DDC:MODE"] == "COMP" else 2048
        return struct.pack("<H", midpoint) * (length // 2)


class ChannelRoutingTests(unittest.TestCase):
    def test_direct_all_outputs_and_separate_segments(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            for channel in AWG_CHANNELS:
                with self.subTest(channel=channel):
                    instrument = Instrument()
                    channel_folder = Path(folder) / f"ch{channel}"
                    channel_folder.mkdir()
                    with patch.object(wave_playback, "connect", return_value=instrument), \
                            patch.object(wave_playback, "__file__", str(channel_folder / "wave_playback.py")), \
                            contextlib.redirect_stdout(io.StringIO()):
                        result = wave_playback.run_wave("start", channel=channel)
                    self.assertTrue(result.startswith(f"CH{channel} output ON"))
                    self.assertEqual(instrument.uploads[0][0], channel)
                    self.assertIn((channel, f":TRAC:SEL {channel}"), instrument.commands)
                    self.assertEqual([ch for ch, cmd in instrument.commands if cmd.startswith(":OUTP")],
                                     [channel, channel])
                    self.assertTrue(all(instrument.outputs[ch] == "ON" for ch in AWG_CHANNELS if ch != channel))
            logs = [json.loads(path.read_text()) for path in Path(folder).glob("ch*/logs/*.json")]
            self.assertEqual({record["channel"] for record in logs}, set(AWG_CHANNELS))

    def test_duc_all_outputs_and_separate_segments(self):
        for channel in AWG_CHANNELS:
            with self.subTest(channel=channel):
                instrument = Instrument()
                with patch.object(duc, "Proteus", return_value=instrument):
                    result = duc.run_duc("start", channel=channel)
                self.assertTrue(result.startswith(f"CH{channel} output ON"))
                self.assertEqual(instrument.uploads[0][0], channel)
                self.assertIn((channel, f":TRAC:SEL {128 + channel}"), instrument.commands)
                self.assertEqual([ch for ch, cmd in instrument.commands if cmd.startswith(":OUTP")],
                                 [channel, channel])

    def test_selection_mismatch_does_not_touch_output(self):
        for module, factory, run in ((wave_playback, "connect", wave_playback.run_wave),
                                     (duc, "Proteus", duc.run_duc)):
            instrument = Instrument(reject_selection=True)
            with patch.object(module, factory, return_value=instrument):
                with self.assertRaisesRegex(RuntimeError, "selection"):
                    run("stop", channel=2)
            self.assertFalse(any(cmd.startswith(":OUTP") for _, cmd in instrument.commands))

    def test_invalid_channel_rejected_before_connecting(self):
        for channel in (0, 5, True, 2.0, "2"):
            for module, factory, run in ((wave_playback, "connect", wave_playback.run_wave),
                                         (duc, "Proteus", duc.run_duc),
                                         (tx_readings, "connect", lambda _action, **kw: tx_readings.read_channel(**kw))):
                with patch.object(module, factory) as connect:
                    with self.assertRaises(ValueError):
                        run("stop", channel=channel)
                    connect.assert_not_called()

    def test_readback_restores_selection_without_changing_outputs(self):
        instrument = Instrument()
        instrument.channel = 4
        with patch.object(tx_readings, "connect", return_value=instrument):
            result = tx_readings.read_channel(2)
        self.assertTrue(result.startswith("CH2 output ON"))
        self.assertEqual(instrument.channel, 4)
        self.assertFalse(any(cmd.startswith(":OUTP") for _, cmd in instrument.commands))

    def test_script_snapshot_and_stop_target(self):
        settings = {"mode": "direct", "channel": 3, "shape": "sine"}
        with patch.dict(os.environ, {bench_api.SETTINGS_ENV: json.dumps(settings)}), \
                patch.object(bench_api, "run_wave") as run, patch.object(bench_api, "run_duc") as stop:
            bench_api.transmit("setup")
            self.assertEqual(run.call_args.kwargs["channel"], 3)
            bench_api.transmit("stop")
            stop.assert_called_with("stop", channel=3)
            bench_api.transmit("stop", channel=2)
            stop.assert_called_with("stop", channel=2)
            # Output Off must work even when unrelated panel fields are invalid.
            bench_api.apply_transmit({"channel": 4, "error": "bad frequency"}, "stop")
            stop.assert_called_with("stop", channel=4)
            os.environ[bench_api.SETTINGS_ENV] = json.dumps({"channel": 3, "error": "bad frequency"})
            bench_api.transmit("stop")
            stop.assert_called_with("stop", channel=3)

    def test_adc_routing_and_recorded_channel(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            for channel in (1, 2):
                for mode in ("real", "ddc"):
                    with self.subTest(channel=channel, mode=mode):
                        instrument = Instrument()
                        path = Path(folder) / f"adc-{channel}-{mode}.wlab.json"
                        reference = dict(mode="duc", pattern="bpsk", bits="10100110", symbol_rate=2.5e6)
                        with patch.object(rx_capture, "connect", return_value=instrument), \
                                patch.object(rx_capture.time, "sleep"):
                            rx_capture.capture(path, channel=channel, mode=mode, trigger="SELF", tx_reference=reference)
                        commands = [cmd for _, cmd in instrument.commands]
                        self.assertIn(f":DIG:CHAN {channel}", commands)
                        self.assertIn(f":DIG:TRIG:SOUR CH{channel}", commands)
                        if mode == "ddc":
                            self.assertIn(f":DIG:DDC:CFR{channel} 100000000", commands)
                        settings, samples, _ = rx_capture.load_capture(path)
                        self.assertEqual(settings["channel"], channel)
                        self.assertEqual(settings["requested_tx"], reference)
                        self.assertEqual(len(samples), 4800)


if __name__ == "__main__":
    unittest.main()
