"""Small read-only SCPI connection for the first Proteus experiment.

Uses Python's standard library; VISA and vendor drivers are not needed for
these text queries. Waveform transfers will need a separate binary-data API.
"""

import socket
import time


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
