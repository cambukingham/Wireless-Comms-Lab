"""Execute one cancellable bench operation in an isolated process."""

import json
import sys

from bench_api import apply_transmit, transmit
from connection_checks import check_ethernet, check_pxie
from rx_capture import capture, disarm
from tx_readings import read_channel
from message_decoder import analyze_capture
from waveform_comparison import compare_waveforms


def main():
    action, raw = sys.argv[1:]
    args = json.loads(raw)
    operations = {
        "ethernet": check_ethernet, "pxie": check_pxie, "transmit": apply_transmit,
        "output_off": lambda channel=1: transmit("stop", channel=channel), "read_ch1": read_channel,
        "capture": lambda path, params: capture(path, **params), "disarm": disarm,
        "decode_bpsk": analyze_capture,
        "compare_waveforms": compare_waveforms,
    }
    try:
        result = operations[action](*args)
    except Exception as error:
        print(json.dumps({"error": str(error)}))
        return 1
    print(json.dumps({"result": result}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
