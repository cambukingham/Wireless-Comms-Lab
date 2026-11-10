"""Offline checks for cross-bench sample logs and waveform comparisons."""

from pathlib import Path
import tempfile
import unittest

import numpy as np

from waveform_comparison import compare_waveforms, export_series, inspect_waveform, load_series, resample, save_waveform_log, tx_descriptor


class WaveformComparisonTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(dir=Path(__file__).parent)
        self.addCleanup(self.folder.cleanup)
        self.path = Path(self.folder.name)
        self.options = dict(alignment="Auto lag", scaling="Fit gain / phase", match_centers=True)

    def save(self, name, values, rate=1e6, **kwargs):
        path = self.path / name
        save_waveform_log(path, values, rate, iq=np.iscomplexobj(values), units="relative", **kwargs)
        return inspect_waveform(path)

    def test_two_chassis_logs_recover_delay_gain_phase_and_dc(self):
        rng = np.random.default_rng(123)
        sent = rng.normal(size=1024) + 1j * rng.normal(size=1024)
        gain = .23 * np.exp(.7j)
        rx = np.concatenate((np.zeros(37, dtype=complex), gain * sent)) + .01 - .02j
        a = self.save("chassis-a.wlab.json", sent, provenance={"instrument": "chassis A"})
        b = self.save("chassis-b.wlab.json", rx, provenance={"instrument": "chassis B"})
        result = compare_waveforms(a, b, self.options)
        self.assertEqual(result["lag_samples"], 37)
        self.assertEqual(result["samples"], 1024)
        self.assertAlmostEqual(result["gain_magnitude"], .23, places=9)
        self.assertAlmostEqual(result["gain_phase_deg"], np.degrees(.7), places=8)
        self.assertAlmostEqual(result["dc_i"], .01, places=9)
        self.assertLess(result["rmse"], 1e-10)
        self.assertGreater(result["raw_rmse"], .1)
        self.assertEqual(result["sources"][0]["provenance"]["instrument"], "chassis A")
        raw = compare_waveforms(a, b, dict(self.options, scaling="Raw levels"))
        self.assertGreater(raw["rmse"], .1)
        self.assertFalse(raw["fit_applied"])

    def test_repeating_reference_and_different_sample_rates(self):
        rng = np.random.default_rng(4)
        period = np.repeat(rng.choice((-1, 1), 32), 16).astype(complex)
        # Receive at half the source rate, starting at a known sample phase.
        expected = resample(period, 2e6, 1e6, 2000 + 29, repeat=True)[29:]
        received = .3j * expected + .004
        a = self.save("tx.wlab.json", period, rate=2e6, repeat=True)
        b = self.save("rx.wlab.json", received, rate=1e6)
        result = compare_waveforms(a, b, self.options)
        self.assertEqual(result["lag_samples"], -29)
        self.assertEqual(result["samples"], 2000)
        self.assertLess(result["rmse"], 1e-10)
        self.assertTrue(any("ambiguous" in warning for warning in result["warnings"]))

    def test_rate_conversion_rejects_alias_component(self):
        n = np.arange(16000)
        values = np.sin(2 * np.pi * 2e6 * n / 40e6) + .5 * np.sin(2 * np.pi * 18e6 * n / 40e6)
        converted = resample(values, 40e6, 20e6)
        expected = np.sin(2 * np.pi * 2e6 * np.arange(len(converted)) / 20e6)
        self.assertLess(float(np.sqrt(np.mean((converted[100:-100] - expected[100:-100]) ** 2))), .001)

    def test_noninteger_period_on_common_grid_preserves_time(self):
        source_rate, received_rate, period = 2e6, 1.001e6, 511
        frequencies = np.array([3, 7, 11]) * source_rate / period
        def signal(times):
            return np.exp(2j * np.pi * times[:, None] * frequencies).sum(axis=1)
        sent = signal(np.arange(period) / source_rate)
        received = .2j * signal((np.arange(4000) + 29) / received_rate)
        a = self.save("fractional-period-tx.wlab.json", sent, rate=source_rate, repeat=True)
        b = self.save("fractional-period-rx.wlab.json", received, rate=received_rate)
        result = compare_waveforms(a, b, self.options)
        self.assertEqual(result["lag_samples"], -29)
        self.assertLess(result["rmse"], .001)

    def test_rf_center_difference_is_applied_explicitly(self):
        rate = 20e6
        reference = np.ones(1024, dtype=complex) * .5
        received = .1j * np.exp(2j * np.pi * 5e6 * np.arange(4000) / rate)
        a = self.save("carrier.wlab.json", reference, rate=rate, repeat=True, center_hz=100e6)
        b = self.save("ddc.wlab.json", received, rate=rate, center_hz=95e6)
        result = compare_waveforms(a, b, self.options)
        self.assertEqual(result["reference_shift_hz"], 5e6)
        self.assertLess(result["rmse"], 1e-9)

    def test_csv_export_and_changed_file_detection(self):
        path = self.path / "external.csv"
        path.write_text("time_s,i,q\n" + "".join(f"{n / 1e6:.9f},{np.cos(n):.9f},{np.sin(n):.9f}\n" for n in range(256)))
        descriptor = inspect_waveform(path)
        exported = self.path / "portable.wlab.json"
        export_series(exported, descriptor)
        restored = load_series(inspect_waveform(exported))
        self.assertEqual(len(restored["values"]), 256)
        self.assertAlmostEqual(restored["sample_rate"], 1e6)
        path.write_text(path.read_text().replace(",1.000000000,", ",0.500000000,"))
        with self.assertRaisesRegex(ValueError, "changed"):
            load_series(descriptor)

    def test_domain_and_units_mismatch_are_explicit(self):
        values = np.sin(np.arange(1024))
        a = self.save("real.wlab.json", values)
        b = self.save("complex.wlab.json", values.astype(complex))
        with self.assertRaisesRegex(ValueError, "domains"):
            compare_waveforms(a, b, self.options)
        other = self.path / "volts.wlab.json"
        save_waveform_log(other, values, 1e6, units="V nominal")
        with self.assertRaisesRegex(ValueError, "units"):
            compare_waveforms(a, inspect_waveform(other), dict(self.options, scaling="Raw levels"))

    def test_tx_settings_export_is_labeled_reconstruction(self):
        settings = dict(mode="duc", pattern="bpsk", bits="10100110", symbol_rate=2.5e6,
                        carrier_hz=100e6, voltage=.2, phase_deg=0)
        path = self.path / "sent.wlab.json"
        export_series(path, tx_descriptor(settings))
        data = load_series(inspect_waveform(path))
        self.assertEqual(data["domain"], "baseband")
        self.assertEqual(data["center_hz"], 100e6)
        self.assertIn("not a measured", str(data["provenance"]))
        with self.assertRaisesRegex(ValueError, "Python function"):
            load_series(tx_descriptor(dict(settings, pattern="python")))


if __name__ == "__main__":
    unittest.main()
