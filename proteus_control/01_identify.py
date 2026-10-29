"""Read instrument identity/options and save a dated connection record."""

import json
from datetime import datetime, timezone
from pathlib import Path

from proteus import Proteus


def main():
    folder = Path(__file__).resolve().parent
    config = json.loads((folder / "config.json").read_text(encoding="utf-8"))
    try:
        with Proteus(**config) as instrument:
            identity = instrument.query("*IDN?")
            if "Tabor" not in identity or "P9484M" not in identity:
                raise ValueError(f"Unexpected instrument: {identity}")
            options = instrument.query("*OPT?")
    except (OSError, ValueError, ConnectionError) as error:
        raise SystemExit(f"Connection check failed: {error}") from error

    now = datetime.now(timezone.utc)
    record = {
        "time_utc": now.isoformat(),
        "connection": config,
        "identity": identity,
        "options": options,
    }
    logs = folder / "logs"
    logs.mkdir(exist_ok=True)
    destination = logs / (now.strftime("%Y%m%dT%H%M%S_%fZ") + "_identity.json")
    destination.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"Instrument: {identity}")
    print(f"Options: {options}")
    print(f"Record: {destination}")
    print("Identification only: no settings or output states changed.")


if __name__ == "__main__":
    main()
