"""Bench diagnostics for the laptop LAN and chassis-local PXIe paths."""

import argparse
import importlib.util
import sys
from pathlib import Path

from proteus import connect

LAB_FOLDER = Path(__file__).resolve().parent


def check_ethernet():
    with connect() as instrument:
        endpoint = f"{instrument.host}:{instrument.port}"
        identity = instrument.query("*IDN?")
        options = instrument.query("*OPT?")
    if not identity:
        raise RuntimeError("The SCPI server returned an empty identity.")
    return f"Ethernet {endpoint}\n{identity}\nOptions: {options}"


def check_pxie(slot_number):
    if sys.platform != "win32":
        raise RuntimeError("Run the PXIe check on the Windows chassis controller.")
    wrapper = LAB_FOLDER.parent / "Rutgers (2)" / "Rutgers" / "SourceFiles" / "teproteus.py"
    if not wrapper.is_file():
        raise RuntimeError("The bundled Tabor teproteus.py wrapper is missing.")
    spec = importlib.util.spec_from_file_location("teproteus", wrapper)
    driver = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(driver)
        admin = driver.TEProteusAdmin()
    except (ImportError, OSError, TypeError) as error:
        raise RuntimeError(
            "This diagnostic requires the chassis computer with NumPy and a Tabor TEProteus.dll "
            "matching Python's architecture. On a laptop, use Connect over Ethernet instead; "
            "Transmit and Receive already use Ethernet."
        ) from error
    with admin:
        slots = [slot_id for slot_id in admin.get_slot_ids() if not admin.get_slot_is_dummy(slot_id)]
        numbers = [admin.get_slot_number_in_chassis(slot_id) for slot_id in slots]
        matches = [slot_id for slot_id, number in zip(slots, numbers) if number == slot_number]
        if len(matches) != 1:
            raise RuntimeError(f"Expected one Proteus in slot {slot_number}. Found slots {numbers}.")
        slot_id = matches[0]
        if admin.get_slot_is_in_use(slot_id):
            raise RuntimeError(f"Slot {slot_number} is busy. Close its other instrument session first.")
        instrument = admin.open_instrument(slot_id, reset_hot_flag=False)
        if instrument is None:
            raise RuntimeError(f"Tabor could not open PXIe slot {slot_number}.")
        with instrument:
            identity = instrument.send_scpi_query("*IDN?")
            options = instrument.send_scpi_query("*OPT?")
        if not identity:
            raise RuntimeError(f"Slot {slot_number} returned an empty identity.")
    return f"Local PXIe slot {slot_number}\n{identity}\nOptions: {options}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("connection", choices=("ethernet", "pxie"))
    parser.add_argument("slot", nargs="?", type=int, default=5)
    args = parser.parse_args()
    try:
        print(check_ethernet() if args.connection == "ethernet" else check_pxie(args.slot))
    except Exception as error:
        parser.exit(1, f"Connection check failed: {error}\n")


if __name__ == "__main__":
    main()
