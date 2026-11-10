"""Small SCPI connection, read-only unless allow_writes=True.

Uses Python's standard library; VISA and vendor drivers are not needed for
text queries and definite-length binary waveform uploads.
"""

import json
import socket
import time
from pathlib import Path


def connect(*, allow_writes=False):
    """Return a session using the bench address in config.json."""
    config_file = Path(__file__).with_name("config.json")
    config = json.loads(config_file.read_text(encoding="utf-8"))
    return Proteus(**config, allow_writes=allow_writes)


class Proteus:
    def __init__(self, host, port=5025, timeout_seconds=5, allow_writes=False):
        self.host = host
        self.port = port
        self.timeout = timeout_seconds
        self.allow_writes = allow_writes
        self._socket = None
        self._reader = None

    def __enter__(self):
        for attempt in range(3):
            try:
                self._socket = socket.create_connection(
                    (self.host, self.port), timeout=self.timeout
                )
                break
            except (TimeoutError, ConnectionRefusedError):
                if attempt == 2:
                    raise
                time.sleep(1)
        self._reader = self._socket.makefile("rb")
        return self

    def query(self, command):
        # Deliberately restrict this first interface to documented identity
        # queries. No resets, output enables, or channel selection.
        if not self.allow_writes and command not in ("*IDN?", "*OPT?"):
            raise ValueError("This connection supports only *IDN? and *OPT?.")
        self._socket.sendall((command + "\n").encode("ascii"))
        # Some responses end in LF-CR; strip that leftover CR on the next line.
        reply = self._reader.readline(65537)
        if not reply or not reply.endswith(b"\n"):
            raise ConnectionError("Missing or incomplete SCPI response.")
        return reply.decode("ascii").strip()

    def command(self, command):
        if not self.allow_writes:
            raise ValueError("Writes require allow_writes=True.")
        self._socket.sendall((command + "\n").encode("ascii"))

    def write_waveform(self, data):
        if not self.allow_writes:
            raise ValueError("Writes require allow_writes=True.")
        length = str(len(data)).encode("ascii")
        header = b"#" + str(len(length)).encode("ascii") + length
        self._socket.sendall(b":TRAC:DATA 0," + header + data + b"\n")

    def query_binary(self, command, expected_size):
        """Read a definite-length SCPI block using the same buffered stream."""
        if not 1 <= expected_size <= 8_388_608:
            raise ValueError("Invalid binary response size.")
        self.command(command)
        marker = self._reader.read(1)
        # The instrument can end a previous text response with LF followed by CR.
        if marker == b"\r":
            marker = self._reader.read(1)
        digits = self._reader.read(1) if marker == b"#" else b""
        if len(digits) != 1 or not b"1" <= digits <= b"9":
            raise ConnectionError("Expected a definite-length SCPI data block.")
        length = self._reader.read(int(digits))
        if len(length) != int(digits) or not length.isdigit() or int(length) != expected_size:
            raise ConnectionError(f"SCPI block size {length!r} disagrees with {expected_size} bytes.")
        payload = self._reader.read(expected_size)
        if len(payload) != expected_size:
            raise ConnectionError(f"Truncated SCPI block: received {len(payload)} of {expected_size} bytes.")
        # The caller closes the session after a capture. Do not wait for an
        # optional trailing terminator after the declared payload.
        return payload

    def check_error(self):
        error = self.query(":SYST:ERR?")
        if int(error.split(",", 1)[0]) != 0:
            raise RuntimeError(f"Instrument error: {error}")

    def __exit__(self, exc_type, exc_value, traceback):
        try:
            if self._reader is not None:
                self._reader.close()
        finally:
            if self._socket is not None:
                self._socket.close()
