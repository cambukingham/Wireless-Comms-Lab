"""Build and verify portable research run bundles without accessing hardware."""

import hashlib
import json
import os
import re
import tempfile
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from uuid import uuid4
from zipfile import ZIP_DEFLATED, BadZipFile, ZipFile

from research_files import artifact_record, parse_artifact

BUNDLE_FORMAT = "winlab-run-v1"
MAX_BUNDLE_BYTES = 64 * 1024 * 1024
MAX_MEMBER_BYTES = 16 * 1024 * 1024


def new_run_id():
    return f"run-{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}-{uuid4().hex[:8]}"


def json_bytes(value):
    return (json.dumps(value, indent=2, allow_nan=False, ensure_ascii=False) + "\n").encode("utf-8")


def file_bytes(path):
    with Path(path).open("rb") as stream:
        data = stream.read(MAX_MEMBER_BYTES + 1)
    if len(data) > MAX_MEMBER_BYTES:
        raise ValueError(f"{Path(path).name} exceeds the per-file bundle limit of 16 MiB.")
    return data


def verified_artifact(path, kind, expected):
    data = file_bytes(path)
    _, _, actual = parse_artifact(data, kind)
    if expected != actual:
        raise ValueError(f"{Path(path).name} changed since it was loaded. Reload it before exporting.")
    return data


def safe_basename(name):
    return re.sub(r"[^\w. -]", "_", Path(name).name).strip(". ") or "file"


def export_bundle(path, run_id, *, context, notes, script, attachments=()):
    """Snapshot the current bench state and copy the files it references."""
    path = Path(path)
    context = deepcopy(context)
    manifest = dict(format=BUNDLE_FORMAT, run_id=run_id,
                    created_utc=datetime.now(timezone.utc).isoformat(), files=[])
    total_bytes = 0
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".winlab-run-", suffix=".partial",
                                         delete=False) as stream:
            temporary = Path(stream.name)
        with ZipFile(temporary, "w", compression=ZIP_DEFLATED) as archive:
            def add(name, data, role):
                nonlocal total_bytes
                total_bytes += len(data)
                if len(data) > MAX_MEMBER_BYTES or total_bytes > MAX_BUNDLE_BYTES:
                    raise ValueError("Bundle exceeds the 16 MiB per file or 64 MiB total limit.")
                archive.writestr(name, data)
                manifest["files"].append(dict(path=name, role=role, bytes=len(data),
                                               sha256=hashlib.sha256(data).hexdigest()))

            tx = context.get("requested_tx_settings", {})
            if tx.get("sample_file"):
                member = "tx/samples.wlab.json"
                add(member, verified_artifact(tx["sample_file"], "tx_samples", tx["sample_sha256"]), "tx_samples")
                tx["sample_file"] = "samples.wlab.json"
            if "mode" in tx:
                member = "tx/plan.wlab.json"
                add(member, json_bytes(artifact_record("tx_plan", tx)), "tx_plan")
                context["tx_plan"] = member
            capture = context.get("verified_rx_capture")
            if capture:
                member = "rx/capture.wlab.json"
                add(member, verified_artifact(capture["file"], "capture", capture["sha256"]), "rx_capture")
                capture["file"] = member
            analysis = context.get("rx_message_analysis")
            if analysis:
                if not capture or analysis["capture"]["sha256"] != capture["sha256"]:
                    raise ValueError("Message analysis does not belong to the loaded capture. Decode it again.")
                analysis["capture"]["file"] = "capture.wlab.json"
                member = "rx/message-analysis.wlab.json"
                add(member, json_bytes(artifact_record("message_analysis", analysis)), "message_analysis")
                context["rx_message_analysis"] = dict(file=member, summary=analysis["summary"])
            profile = context.get("rf_path", {})
            if profile.get("file"):
                member = "rf/antenna-profile.wlab.json"
                add(member, verified_artifact(profile["file"], "antenna_profile", profile["sha256"]), "rf_profile")
                profile["file"] = member
            add("notes.md", notes.encode("utf-8"), "notes")
            name, source = script
            if source:
                add(f"scripts/{safe_basename(name)}", source.encode("utf-8"), "editor_script")
            for index, (role, source_path) in enumerate(attachments, 1):
                name = f"attachments/{index:02d}-{safe_basename(source_path)}"
                add(name, file_bytes(source_path), role)
            add("bench-context.json", json_bytes(context), "bench_context")
            archive.writestr("manifest.json", json_bytes(manifest))
        verify_bundle(temporary)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return manifest


def verify_bundle(path):
    """Check the manifest against every member without extracting or executing it."""
    try:
        with ZipFile(path) as archive:
            names = archive.namelist()
            if len(names) != len(set(names)) or archive.getinfo("manifest.json").file_size > 1_000_000:
                raise ValueError("Duplicate files or invalid manifest size in run bundle.")
            manifest = json.loads(archive.read("manifest.json"))
            if manifest.get("format") != BUNDLE_FORMAT or not isinstance(manifest.get("run_id"), str):
                raise ValueError("Expected a WINLAB run bundle.")
            remaining = set(names) - {"manifest.json"}
            total = 0
            for entry in manifest["files"]:
                name = entry["path"]
                member = PurePosixPath(name)
                if name not in remaining or member.is_absolute() or ".." in member.parts or "\\" in name:
                    raise ValueError(f"Unexpected bundle member {name!r}.")
                info = archive.getinfo(name)
                total += info.file_size
                if (info.file_size != entry["bytes"] or info.file_size > MAX_MEMBER_BYTES
                        or total > MAX_BUNDLE_BYTES):
                    raise ValueError(f"Invalid file size for {name}.")
                if hashlib.sha256(archive.read(info)).hexdigest() != entry["sha256"]:
                    raise ValueError(f"SHA-256 check failed for {name}.")
                remaining.remove(name)
            if remaining or "bench-context.json" not in names:
                raise ValueError("Bundle file list does not match its manifest.")
    except (BadZipFile, KeyError, TypeError, AttributeError) as error:
        raise ValueError("Invalid WINLAB run bundle.") from error
    return manifest
