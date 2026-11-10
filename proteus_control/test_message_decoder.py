"""Synthetic data checks for offline message decoding and honest comparisons."""

import json
from pathlib import Path
import tempfile
import unittest

import numpy as np

from message_decoder import analyze_capture, bits_bytes, decode_bpsk, reference_bits
from research_files import save_artifact
from run_bundle import export_bundle, verify_bundle


class DecoderTests(unittest.TestCase):
    def setUp(self):
        self.message = b"WINLAB_TEST_0001"
        self.bits = "".join(f"{byte:08b}" for byte in self.message)
        self.rate = 156.25e6
        self.baud = 2.5e6

    def signal(self, *, errors=(), bits=None):
        bits = self.bits if bits is None else bits
        rng = np.random.default_rng(451)
        n = np.arange(48000)
        indices = np.floor((n + 23.4) / 62.5).astype(int)
        pattern = np.array([1 if bit == "1" else -1 for bit in bits])
        values = pattern[indices % len(bits)].astype(float)
        for index in errors:
            values[indices == index] *= -1
        values = np.convolve(values, np.ones(5) / 5, mode="same")
        signal = .025 * values * np.exp(1j * (1.65 + 2 * np.pi * 320 * n / self.rate))
        noise = .00015 * (rng.normal(size=len(n)) + 1j * rng.normal(size=len(n)))
        return signal + (.0002 - .0001j) + noise

    def test_fractional_timing_phase_and_frequency_offset(self):
        result = decode_bpsk(self.signal(), self.rate, self.bits, self.baud)
        self.assertTrue(result["reliable_alignment"])
        self.assertEqual(result["bit_errors"], 0)
        self.assertEqual(result["validation_errors"], 0)
        self.assertGreater(result["validation_symbols"], 500)
        self.assertAlmostEqual(result["carrier_offset_hz"], 320, delta=15)
        held_out = [frame for frame in result["frames"] if frame["validation"]]
        self.assertGreaterEqual(len(held_out), 3)
        self.assertTrue(all(bits_bytes(frame["received_bits"]) == self.message for frame in held_out))
        json.dumps(result, allow_nan=False)

    def test_corrupted_validation_bits_are_not_replaced_by_reference(self):
        clean = decode_bpsk(self.signal(), self.rate, self.bits, self.baud)
        damaged = decode_bpsk(self.signal(errors=(310, 450, 600)), self.rate, self.bits, self.baud)
        self.assertEqual(damaged["validation_errors"], 3)
        self.assertEqual(damaged["bit_errors"], 3)
        self.assertEqual(clean["training_samples"], damaged["training_samples"])
        self.assertAlmostEqual(clean["phase_deg"], damaged["phase_deg"], places=9)
        self.assertAlmostEqual(clean["carrier_offset_hz"], damaged["carrier_offset_hz"], places=9)
        self.assertNotEqual(damaged["received_bits"], damaged["expected_bits"])

    def test_wrong_reference_and_noise_do_not_claim_alignment(self):
        wrong = "".join("1" if bit == "0" else "0" for bit in self.bits[:40]) + self.bits[40:]
        result = decode_bpsk(self.signal(), self.rate, wrong, self.baud)
        self.assertGreater(result["validation_errors"], 0)
        rng = np.random.default_rng(5)
        noise = .02 * (rng.normal(size=48000) + 1j * rng.normal(size=48000))
        result = decode_bpsk(noise, self.rate, self.bits, self.baud)
        self.assertFalse(result["reliable_alignment"])
        self.assertTrue(result["warnings"])

    def test_reference_formats_and_short_capture(self):
        self.assertEqual(reference_bits("WINLAB_TEST_0001", "Text (UTF-8)"), self.bits)
        self.assertEqual(reference_bits(self.message.hex(" "), "Hex bytes"), self.bits)
        self.assertEqual(reference_bits("1010 0110", "Bits"), "10100110")
        with self.assertRaises(ValueError):
            reference_bits("00000000", "Bits")
        with self.assertRaisesRegex(ValueError, "longer"):
            decode_bpsk(self.signal()[:4800], self.rate, self.bits, self.baud)

    def test_verified_file_and_changed_file_rejection(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            path = Path(folder) / "capture.wlab.json"
            signal = self.signal()
            words = np.empty(len(signal) * 2, dtype="<u4")
            words[0::2] = np.rint(16384 + signal.real * 16384).astype("<u4")
            words[1::2] = np.rint(16384 + signal.imag * 16384).astype("<u4")
            settings = dict(channel=1, mode="ddc", samples=len(signal), word_bytes=4,
                            sample_rate=self.rate, pretrigger=0)
            checksum = save_artifact(path, "capture", settings, words.tobytes())
            result = analyze_capture(path, self.bits, self.baud, checksum)
            self.assertEqual(result["validation_errors"], 0)
            self.assertEqual(result["capture"]["sha256"], checksum)
            context = dict(verified_rx_capture=dict(file=str(path), sha256=checksum, settings=settings),
                           rx_message_analysis=result)
            bundle = Path(folder) / "run.zip"
            export_bundle(bundle, "message-check", context=context, notes="", script=("", ""))
            manifest = verify_bundle(bundle)
            self.assertIn("message_analysis", [entry["role"] for entry in manifest["files"]])
            # A valid report for another capture must not silently enter this run.
            result["capture"]["sha256"] = "another capture"
            with self.assertRaisesRegex(ValueError, "does not belong"):
                export_bundle(bundle, "mismatch", context=context, notes="", script=("", ""))
            self.assertEqual(verify_bundle(bundle)["run_id"], "message-check")
            with self.assertRaisesRegex(ValueError, "changed"):
                analyze_capture(path, self.bits, self.baud, "outdated hash")


if __name__ == "__main__":
    unittest.main()
