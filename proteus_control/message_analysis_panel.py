"""Receive-side decoded message display and reference comparisons."""

from copy import deepcopy
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, ttk

from message_decoder import bits_bytes, display_bytes, reference_bits
from research_files import save_artifact


class MessageAnalysis(ttk.LabelFrame):
    def __init__(self, parent, submit, get_tx):
        super().__init__(parent, text="Decoded message / BPSK", padding=8)
        self.submit = submit
        self.get_tx = get_tx
        self.capture = None
        self.result = None
        self.revision = 0
        self.source = "Manual reference"
        self.columnconfigure(0, weight=1)
        self.columnconfigure(1, weight=1)
        self.rowconfigure(4, weight=1, minsize=160)
        self.kind = tk.StringVar(value="Bits")
        self.baud = tk.StringVar(value="2.5")
        self.view = tk.StringVar(value="Text")
        self.diff_kind = tk.StringVar(value="Bytes")
        self.errors_only = tk.BooleanVar(value=False)
        self.frame = tk.StringVar()
        self.frames = []
        self.intended_preview = tk.StringVar(value="Intended: \\xa6 (8 bits)")

        settings = ttk.Frame(self)
        settings.grid(row=0, column=0, sticky="ew")
        ttk.Label(settings, text="Reference").pack(side="left")
        ttk.Combobox(settings, textvariable=self.kind, state="readonly", width=13,
                     values=("Text (UTF-8)", "Hex bytes", "Bits")).pack(side="left", padx=4)
        ttk.Label(settings, text="MBd").pack(side="left", padx=(6, 2))
        ttk.Entry(settings, textvariable=self.baud, width=7).pack(side="left")
        self.reference = tk.Text(self, height=2, width=44, wrap="char", undo=True)
        self.reference.grid(row=1, column=0, sticky="ew", pady=4)
        self.reference.insert("1.0", "10100110")
        self.reference.edit_modified(False)
        self.reference.bind("<<Modified>>", self._reference_edited)

        actions = ttk.Frame(self)
        actions.grid(row=2, column=0, sticky="ew")
        ttk.Button(actions, text="Use TX settings", command=self.use_tx).pack(side="left", padx=(0, 4))
        ttk.Button(actions, text="Load bytes…", command=self.load_reference).pack(side="left", padx=(0, 4))
        self.decode_button = ttk.Button(actions, text="Decode / compare", command=self.analyze)
        self.decode_button.pack(side="left", padx=(0, 4))
        self.export_button = ttk.Button(actions, text="Export…", command=self.export, state="disabled")
        self.export_button.pack(side="left")

        self.status = tk.StringVar(value="Load a DDC I/Q capture and specify its intended repeating message.")
        status_label = ttk.Label(self, textvariable=self.status, justify="left", wraplength=470)
        status_label.grid(row=3, column=0, columnspan=2, sticky="ew", pady=5)
        self.bind("<Configure>", lambda event: status_label.configure(wraplength=max(200, event.width - 20)))

        display = ttk.Frame(self)
        display.grid(row=0, column=1, sticky="ew", padx=(12, 0))
        ttk.Label(display, textvariable=self.intended_preview, wraplength=450,
                  justify="left").pack(fill="x", pady=(0, 3))
        display_controls = ttk.Frame(display)
        display_controls.pack(fill="x")
        ttk.Label(display_controls, text="Recovered message").pack(side="left")
        ttk.Combobox(display_controls, textvariable=self.view, values=("Text", "Hex", "Bits"),
                     width=7, state="readonly").pack(side="right")
        self.received = tk.Text(self, height=3, width=44, wrap="char", state="disabled")
        self.received.grid(row=1, column=1, rowspan=2, sticky="nsew", padx=(12, 0), pady=4)
        self.received.tag_configure("mismatch", foreground="#a51c30", background="#ffe0df")

        notebook = ttk.Notebook(self)
        notebook.grid(row=4, column=0, columnspan=2, sticky="nsew")
        diff = ttk.Frame(notebook)
        notebook.add(diff, text="Message differences")
        details = ttk.Frame(notebook)
        notebook.add(details, text="Alignment / integrity")
        frame_bar = ttk.Frame(diff)
        frame_bar.pack(fill="x", pady=3)
        self.frame_box = ttk.Combobox(frame_bar, textvariable=self.frame, state="readonly", width=20)
        self.frame_box.pack(side="left")
        ttk.Combobox(frame_bar, textvariable=self.diff_kind, state="readonly", width=6,
                     values=("Bytes", "Bits")).pack(side="left", padx=4)
        ttk.Checkbutton(frame_bar, text="Errors only", variable=self.errors_only).pack(side="left")
        table = ttk.Frame(diff)
        table.pack(fill="both", expand=True)
        self.diff = ttk.Treeview(table, columns=("index", "expected", "actual", "check"),
                                 show="headings", height=10)
        for key, text, width in (("index", "Offset", 52), ("expected", "Intended", 105),
                                 ("actual", "Received", 105), ("check", "Result", 72)):
            self.diff.heading(key, text=text)
            self.diff.column(key, width=width, minwidth=40, stretch=True)
        self.diff.tag_configure("mismatch", foreground="#a51c30", background="#ffe0df")
        scroll = ttk.Scrollbar(table, command=self.diff.yview)
        self.diff.configure(yscrollcommand=scroll.set)
        self.diff.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")
        self.details = tk.Text(details, height=12, width=44, wrap="word", state="disabled")
        detail_scroll = ttk.Scrollbar(details, command=self.details.yview)
        self.details.configure(yscrollcommand=detail_scroll.set)
        self.details.pack(side="left", fill="both", expand=True)
        detail_scroll.pack(side="right", fill="y")

        self.kind.trace_add("write", self._inputs_changed)
        self.baud.trace_add("write", self._inputs_changed)
        for variable in (self.view, self.diff_kind, self.errors_only, self.frame):
            variable.trace_add("write", lambda *_: self.render())

    @staticmethod
    def _set_text(widget, text):
        widget.configure(state="normal")
        widget.delete("1.0", "end")
        widget.insert("1.0", text)
        widget.configure(state="disabled")

    def _clear_result(self):
        self.result = None
        self.frames = []
        self.frame_box.configure(values=())
        self.frame.set("")
        self.export_button.state(["disabled"])
        self._set_text(self.received, "")
        self._set_text(self.details, "")
        self.diff.delete(*self.diff.get_children())

    def _inputs_changed(self, *_args):
        self.revision += 1
        self._clear_result()
        try:
            bits = reference_bits(self.reference.get("1.0", "end-1c"), self.kind.get())
            preview = display_bytes(bits_bytes(bits)) if len(bits) % 8 == 0 else bits
            self.intended_preview.set(f"Intended: {preview} ({len(bits)} bits)")
        except ValueError:
            self.intended_preview.set("Intended: review the reference above")
        self.status.set("Reference or symbol rate changed. Decode again to compare this capture.")

    def _reference_edited(self, _event=None):
        if self.reference.edit_modified():
            self.source = "Manual reference"
            self.reference.edit_modified(False)
            self._inputs_changed()

    def set_reference(self, text, kind, source, baud=None):
        self.kind.set(kind)
        if baud is not None:
            self.baud.set(f"{baud / 1e6:g}")
        self.reference.delete("1.0", "end")
        self.reference.insert("1.0", text)
        self.reference.edit_modified(False)
        self.source = source
        self._inputs_changed()
        self.status.set(f"{source}. Check that this reference belongs to the loaded capture.")

    def use_tx(self):
        settings = self.get_tx()
        if settings.get("mode") != "duc" or settings.get("pattern") != "bpsk" or "error" in settings:
            self.status.set("Select BPSK bit pattern in Transmit and enter valid settings, then copy them here.")
            return
        self.set_reference(settings["bits"], "Bits", "Copied from current TX settings", settings["symbol_rate"])

    def load_reference(self):
        path = filedialog.askopenfilename(parent=self, title="Load intended message bytes")
        if not path:
            return
        try:
            with open(path, "rb") as stream:
                data = stream.read(33)
            if not 1 <= len(data) <= 32:
                raise ValueError("Use a message file of 1–32 bytes.")
        except (OSError, ValueError) as error:
            self.status.set(str(error))
            return
        self.set_reference(data.hex(" "), "Hex bytes", f"Loaded {Path(path).name} ({len(data)} bytes)")

    def set_capture(self, capture):
        self.capture = deepcopy(capture)
        self.revision += 1
        self._clear_result()
        if capture is None:
            self.status.set("Load a verified DDC I/Q capture before decoding.")
            return
        tx = capture["settings"].get("requested_tx") or {}
        if tx.get("mode") == "duc" and tx.get("pattern") == "bpsk" and "bits" in tx:
            self.set_reference(tx["bits"], "Bits", "Requested TX reference saved with capture", tx["symbol_rate"])
        else:
            self.status.set("Capture loaded. Choose its intended reference and symbol rate, then Decode / compare.")

    def analyze(self):
        if self.capture is None or self.capture["settings"]["mode"] != "ddc":
            self.status.set("Load a DDC I/Q capture. Real RF samples need downconversion first.")
            return
        try:
            bits = reference_bits(self.reference.get("1.0", "end-1c"), self.kind.get())
            baud = float(self.baud.get()) * 1e6
            if not .1e6 <= baud <= 20e6:
                raise ValueError("Use a finite symbol rate from 0.1 to 20 MBd.")
        except ValueError as error:
            self.status.set(str(error))
            return
        revision = self.revision
        self._clear_result()

        def complete(result):
            if revision != self.revision:
                self.status.set("Analysis discarded because its capture or reference changed. Decode again.")
                return
            self.result = result
            self.export_button.state(["!disabled"])
            labels = []
            self.frames = result["frames"]
            for number, frame in enumerate(self.frames, 1):
                labels.append(f"{number}: {'validation' if frame['validation'] else 'training/boundary'} · {frame['bit_errors']} errors")
            self.frame_box.configure(values=labels)
            selected = next((index for index, frame in enumerate(self.frames) if frame["validation"]), 0)
            if labels:
                self.frame.set(labels[selected])
            else:
                self.frame.set("")
            self.status.set(f"{result['summary']}\n{result['bit_errors']} / {result['complete_symbols']} total bit mismatches. "
                            f"{len(self.frames)} complete message repeats. "
                            "Alignment uses a separate training prefix.")
            self.render()
            self._set_text(self.details, self.detail_text())

        self.submit(self.status, "Decoding BPSK message", "decode_bpsk", self.capture["file"], bits, baud,
                    self.capture["sha256"], self.source, on_result=complete)

    def detail_text(self):
        result = self.result
        return (f"{result['algorithm']}\nReference: {result['reference_source']}\n"
                f"Capture SHA-256: {result['capture']['sha256']}\n"
                f"Reference SHA-256: {result['reference_sha256']}\n"
                f"Timing offset: {result['timing_offset_samples']:.4g} samples\n"
                f"Samples/symbol: {result['samples_per_symbol']:.6g}\n"
                f"Phase / polarity correction: {result['phase_deg']:.3f}°\n"
                f"Estimated carrier offset: {result['carrier_offset_hz']:.3f} Hz\n"
                f"Training samples: {result['training_samples']}\n"
                f"Held-out bits: {result['validation_symbols']}\n"
                f"Held-out mismatch fraction: {result['validation_error_fraction']:.6g}\n"
                f"Training alignment score: {result['alignment_quality']:.4f}\n\n"
                + "\n\n".join(result["warnings"]))

    def render(self):
        if self.result is None:
            return
        result = self.result
        self.diff.delete(*self.diff.get_children())
        try:
            selected = list(self.frame_box.cget("values")).index(self.frame.get())
            frame = self.frames[selected]
        except (ValueError, IndexError):
            self._set_text(self.received, "No complete message frame. Capture a longer record.")
            return
        actual = frame["received_bits"]
        intended = result["reference_bits"]
        if self.view.get() == "Bits":
            display = actual
        elif result["byte_aligned"]:
            data = bits_bytes(actual)
            display = data.hex(" ").upper() if self.view.get() == "Hex" else display_bytes(data)
        else:
            display = "Reference is not whole bytes. Select Bits to inspect the decoded pattern."
        self._set_text(self.received, display)
        if self.view.get() == "Bits":
            for index, (a, b) in enumerate(zip(actual, intended)):
                if a != b:
                    self.received.tag_add("mismatch", f"1.0+{index}c", f"1.0+{index + 1}c")
        elif self.view.get() == "Hex" and result["byte_aligned"]:
            for index, (a, b) in enumerate(zip(bits_bytes(actual), bits_bytes(intended))):
                if a != b:
                    self.received.tag_add("mismatch", f"1.0+{index * 3}c", f"1.0+{index * 3 + 2}c")
        if self.diff_kind.get() == "Bytes" and result["byte_aligned"]:
            pairs = zip(bits_bytes(intended), bits_bytes(actual))
            rows = [(index, f"{b:02X} {display_bytes(bytes([b]))}", f"{a:02X} {display_bytes(bytes([a]))}", a != b)
                    for index, (b, a) in enumerate(pairs)]
        else:
            rows = [(index, b, a, a != b) for index, (b, a) in enumerate(zip(intended, actual))]
        for index, expected, received, error in rows:
            if not self.errors_only.get() or error:
                self.diff.insert("", "end", values=(index, expected, received, "Mismatch" if error else "Match"),
                                 tags=("mismatch",) if error else ())

    def export(self):
        if self.result is None:
            return
        path = filedialog.asksaveasfilename(parent=self, title="Export decoded message analysis",
                                            defaultextension=".wlab.json", initialfile="message-analysis.wlab.json",
                                            filetypes=[("WINLAB analysis", "*.wlab.json")])
        if path:
            try:
                checksum = save_artifact(path, "message_analysis", self.result)
            except (OSError, ValueError) as error:
                self.status.set(str(error))
            else:
                self.status.set(f"Analysis saved. SHA-256 {checksum[:16]}…")

    def snapshot(self):
        return deepcopy(self.result)
