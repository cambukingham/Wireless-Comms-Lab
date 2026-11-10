"""Versioned, integrity-checked artifacts for captures, messages and TX samples."""

import base64
import binascii
import hashlib
import hmac
import json
import os
import tempfile
from pathlib import Path

MAX_BYTES = 8_388_608
FORMAT = "winlab-bench-v1"


def digest(kind, settings, data):
    header = json.dumps([FORMAT, kind, settings], sort_keys=True, separators=(",", ":"),
                        allow_nan=False).encode("utf-8")
    return hashlib.sha256(header + b"\0" + data).hexdigest()


def artifact_record(kind, settings, data=b""):
    if len(data) > MAX_BYTES:
        raise ValueError("Artifact payload exceeds the bench file limit.")
    checksum = digest(kind, settings, data)
    return dict(format=FORMAT, kind=kind, settings=settings, sha256=checksum,
                data=base64.b64encode(data).decode("ascii"))


def save_artifact(path, kind, settings, data=b""):
    record = artifact_record(kind, settings, data)
    write_text_atomic(path, json.dumps(record, indent=2, allow_nan=False))
    return record["sha256"]


def write_text_atomic(path, text):
    """Publish the file only after writing a complete replacement."""
    path = Path(path)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                         prefix=f".{path.name}.", suffix=".partial", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(text)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def load_artifact(path, kind):
    path = Path(path)
    if path.stat().st_size > 12_000_000:
        raise ValueError("Bench file exceeds the size limit.")
    return parse_artifact(path.read_bytes(), kind)


def parse_artifact(content, kind):
    if len(content) > 12_000_000:
        raise ValueError("Bench file exceeds the size limit.")
    try:
        record = json.loads(content)
        if record["format"] != FORMAT or record["kind"] != kind:
            raise ValueError(f"Expected a WINLAB {kind} file.")
        settings = record["settings"]
        data = base64.b64decode(record["data"], validate=True)
        checksum = record["sha256"]
        if not isinstance(settings, dict) or len(data) > MAX_BYTES:
            raise ValueError("Invalid artifact settings or payload length.")
        if not hmac.compare_digest(digest(kind, settings, data), checksum):
            raise ValueError("Artifact SHA-256 check failed.")
    except (KeyError, TypeError, binascii.Error) as error:
        raise ValueError("Invalid WINLAB artifact.") from error
    return settings, data, checksum


def save_tx_samples(path, samples, *, iq=False):
    """Save a normalized DAC record at 1 GS/s real or 312.5 MS/s complex."""
    from baseband import real_payload, repeat_count
    from duc import BASEBAND_RATE, encode_iq
    from waveforms import SAMPLE_RATE

    count = len(samples)
    if not count:
        raise ValueError("Provide at least one sample.")
    repeats = repeat_count(count)
    payload = (encode_iq(samples) if iq else real_payload(samples)) * repeats
    return save_artifact(path, "tx_samples", dict(iq=iq, count=count * repeats,
                         sample_rate=BASEBAND_RATE if iq else SAMPLE_RATE), payload)


def load_tx_samples(path, *, iq, sample_rate, expected_sha256=None):
    from baseband import MAX_RECORD_SAMPLES

    settings, payload, checksum = load_artifact(path, "tx_samples")
    if expected_sha256 is not None and checksum != expected_sha256:
        raise ValueError("The loaded sample file has changed since it was selected.")
    count = settings.get("count")
    if (settings.get("iq") is not iq or settings.get("sample_rate") != sample_rate
            or type(count) is not int or not 1024 <= count <= MAX_RECORD_SAMPLES
            or count % 64 or len(payload) != count * (4 if iq else 2)):
        raise ValueError("Sample file has the wrong format, rate, or record length for this mode.")
    return payload, checksum
