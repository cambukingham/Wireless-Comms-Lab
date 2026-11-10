"""Receive controls and offline time/FFT views for verified ADC artifacts."""

import cmath
import math
import tkinter as tk
from datetime import datetime
from pathlib import Path
from tkinter import filedialog, ttk

from config_checks import receive_advice
from channels import ADC_CHANNELS
from message_analysis_panel import MessageAnalysis
from rx_capture import RANGES, load_capture, validate_capture_settings
from signal_preview import SignalPreview
from waveform_compare_panel import WaveformComparison
from message_decoder import bits_bytes, display_bytes

CAPTURE_FILES = [("WINLAB capture", "*.wlab.json"), ("JSON files", "*.json")]


def spectrum(samples, sample_rate, *, iq):
    """Hann-windowed spectrum of the first 4096 samples or smaller power of two."""
    count = 1 << (min(len(samples), 4096).bit_length() - 1)
    values = [complex(samples[n] * (0.5 - 0.5 * math.cos(math.tau * n / (count - 1))))
              for n in range(count)]
    j = 0
    for i in range(1, count):
        bit = count >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j ^= bit
        if i < j:
            values[i], values[j] = values[j], values[i]
    size = 2
    while size <= count:
        half = size // 2
        for i in range(half):
            twiddle = cmath.exp(-1j * math.tau * i / size)
            for start in range(i, count, size):
                product = twiddle * values[start + half]
                values[start], values[start + half] = values[start] + product, values[start] - product
        size *= 2
    bins = range(-count // 2, count // 2) if iq else range(0, count // 2 + 1)
    magnitudes = [abs(values[index]) for index in bins]
    reference = max(magnitudes) or 1.0
    return [(index * sample_rate / count, 20 * math.log10(max(magnitude / reference, 1e-5)))
            for index, magnitude in zip(bins, magnitudes)]


class ReceivePanel(ttk.Frame):
    def __init__(self, parent, submit, use_range, get_tx):
        super().__init__(parent, padding=12)
        self.submit = submit
        self.use_range = use_range
        self.get_tx = get_tx
        self.loaded = None
        self.capture_reference = None
        self.columnconfigure(0, weight=1)
        self.rowconfigure(3, weight=1)

        channel_bar = ttk.LabelFrame(self, text="Receive input", padding=8)
        channel_bar.grid(row=0, column=0, sticky="ew", pady=(0, 6))
        ttk.Label(channel_bar, text="ADC channel").pack(side="left", padx=(0, 8))
        channel = tk.StringVar(value="1")
        ttk.Combobox(channel_bar, textvariable=channel, values=ADC_CHANNELS,
                     state="readonly", width=5).pack(side="left")
        ttk.Label(channel_bar, text="One input per capture. Disarm ADC stops both inputs.").pack(side="left", padx=12)
        form = ttk.LabelFrame(self, text="Single-frame ADC capture", padding=8)
        self.capture_form = form
        form.grid(row=1, column=0, sticky="ew")
        self.show_settings = tk.BooleanVar(value=True)
        ttk.Checkbutton(channel_bar, text="Show capture settings", variable=self.show_settings,
                         command=lambda: form.grid() if self.show_settings.get() else form.grid_remove()).pack(side="right")
        self.fields = {"Channel": channel}
        definitions = (
            ("Mode", "Real ADC", ("Real ADC", "DDC I/Q")),
            ("ADC clock (GS/s)", "2.5", ()), ("Input range", "HIGH", tuple(RANGES)),
            ("Frame samples", "4800", ()), ("Pretrigger samples", "0", ()),
            ("DDC center (MHz)", "100", ()), ("DDC decimation", "16", ("4", "16")),
            ("DDC phase (deg)", "0", ()), ("Trigger", "CPU", ("CPU", "EXT", "SELF")),
            ("Trigger level (V)", "0", ()), ("Trigger edge", "POS", ("POS", "NEG")),
            ("Trigger timeout (s)", "5", ()),
        )
        for index, (label, default, choices) in enumerate(definitions):
            value = tk.StringVar(value=default)
            self.fields[label] = value
            row, column = divmod(index, 3)
            ttk.Label(form, text=label).grid(row=row, column=column * 2, sticky="w", padx=(0, 4), pady=3)
            widget = (ttk.Combobox(form, textvariable=value, values=choices, state="readonly", width=10)
                      if choices else ttk.Entry(form, textvariable=value, width=10))
            widget.grid(row=row, column=column * 2 + 1, sticky="w", padx=(0, 12), pady=3)

        controls = ttk.Frame(self)
        controls.grid(row=3, column=0, sticky="ew", pady=6)
        self.capture_button = ttk.Button(controls, text="Capture & save…", command=self.capture)
        self.disarm_button = ttk.Button(controls, text="Disarm ADC", command=self.disarm)
        for button in (self.capture_button, self.disarm_button):
            button.pack(side="left", padx=(0, 4))
        ttk.Button(controls, text="Load capture…", command=self.load).pack(side="left", padx=(0, 4))
        ttk.Button(controls, text="Use range for TX pad estimate",
                   command=lambda: use_range(RANGES[self.fields["Input range"].get()])).pack(side="left", padx=(0, 4))
        self.view = tk.StringVar(value="Time (I / real)")
        self.view_box = ttk.Combobox(controls, textvariable=self.view, state="readonly", width=16,
                                     values=("Time (I / real)", "Spectrum"))
        self.view_box.pack(side="right")
        self.view_box.bind("<<ComboboxSelected>>", lambda _: self.plot())
        self.workspace = ttk.Notebook(self)
        self.workspace.grid(row=4, column=0, sticky="nsew")
        chart = ttk.Frame(self.workspace)
        self.workspace.add(chart, text="Waveform")
        self.message_analysis = MessageAnalysis(self.workspace, submit, get_tx)
        self.workspace.add(self.message_analysis, text="Message / differences / integrity")
        self.waveform_compare = WaveformComparison(self.workspace, submit, get_tx, lambda: self.capture_reference)
        self.workspace.add(self.waveform_compare, text="Compare waveforms")
        self.workspace.bind("<<NotebookTabChanged>>", self._workspace_changed)
        summary = ttk.Frame(chart)
        summary.pack(side="bottom", fill="x", pady=(5, 0))
        self.message_summary = tk.StringVar(value="Decode a message to show the recovered text here.")
        ttk.Label(summary, textvariable=self.message_summary, wraplength=900).pack(side="left", fill="x", expand=True)
        ttk.Button(summary, text="Open message / differences",
                   command=lambda: self.workspace.select(self.message_analysis)).pack(side="right", padx=5)
        self.message_analysis.status.trace_add("write", self._refresh_message_summary)
        self.message_analysis.frame.trace_add("write", self._refresh_message_summary)
        self.figure = SignalPreview(chart)
        self.figure.toolbar(chart).pack(fill="x", pady=(0, 4))
        self.figure.pack(fill="both", expand=True)
        self.figure.show(message="Capture or load a frame to inspect its samples.")
        self.note = tk.StringVar(value="Capture results and file verification appear here.")
        ttk.Label(self, textvariable=self.note, justify="left", wraplength=760).grid(row=5, column=0, sticky="w")
        self.warning = ttk.Label(self, justify="left", wraplength=760)
        self.warning.grid(row=2, column=0, sticky="w", pady=(4, 0))
        self.rowconfigure(3, weight=0)
        self.rowconfigure(4, weight=1)
        for variable in self.fields.values():
            variable.trace_add("write", self.refresh_warnings)
        self.refresh_warnings()

    def _workspace_changed(self, _event=None):
        if self.workspace.select() in (str(self.message_analysis), str(self.waveform_compare)):
            self.show_settings.set(False)
            self.capture_form.grid_remove()

    def _refresh_message_summary(self, *_args):
        panel = self.message_analysis
        if panel.result is None:
            self.message_summary.set(panel.status.get())
            return
        try:
            selected = list(panel.frame_box.cget("values")).index(panel.frame.get())
            bits = panel.frames[selected]["received_bits"]
            text = display_bytes(bits_bytes(bits)) if len(bits) % 8 == 0 else bits
        except (ValueError, IndexError):
            text = "No complete message"
        self.message_summary.set(f"Recovered: {text}\n{panel.result['summary']}")

    def capture_settings(self):
        values = {label: var.get() for label, var in self.fields.items()}
        ddc = values["Mode"] == "DDC I/Q"
        trigger = values["Trigger"]

        def number(label, convert=float):
            try:
                return convert(values[label])
            except ValueError as error:
                raise ValueError(f"Enter a {'whole number' if convert is int else 'number'} for {label}.") from error

        return dict(channel=int(values["Channel"]), mode="ddc" if ddc else "real",
                    rate=number("ADC clock (GS/s)") * 1e9, input_range=values["Input range"],
                    samples=number("Frame samples", int), pretrigger=number("Pretrigger samples", int),
                    center_hz=number("DDC center (MHz)") * 1e6 if ddc else 0,
                    decimation=int(values["DDC decimation"]) if ddc else 1,
                    ddc_phase=number("DDC phase (deg)") if ddc else 0, trigger=trigger,
                    level=number("Trigger level (V)") if trigger != "CPU" else 0,
                    slope=values["Trigger edge"] if trigger != "CPU" else "POS", timeout=number("Trigger timeout (s)"))

    def refresh_warnings(self, *_args):
        try:
            params = self.capture_settings()
            validate_capture_settings(**params)
        except ValueError as error:
            self.warning.configure(style="ConfigError.TLabel", text=f"Fix before capture · {error}")
            return None
        advice = receive_advice(params, self.get_tx())
        if advice:
            self.warning.configure(style="ConfigWarning.TLabel", text=f"Check · {advice}")
        else:
            info = "DDC fields apply in I/Q mode. " if params["mode"] == "real" else ""
            if params["trigger"] == "CPU":
                info += "Trigger level and edge apply to EXT or SELF."
            self.warning.configure(style="TLabel", text=info.strip() or "RX settings pass the offline checks.")
        return params

    def settings_snapshot(self):
        try:
            params = self.capture_settings()
            validate_capture_settings(**params)
        except ValueError as error:
            return {"error": str(error), "draft": {label: var.get() for label, var in self.fields.items()}}
        return params

    def capture(self):
        params = self.refresh_warnings()
        if params is None:
            self.note.set("Review the configuration message above before capturing.")
            return
        path = filedialog.asksaveasfilename(parent=self, filetypes=CAPTURE_FILES,
                                            defaultextension=".wlab.json",
                                            initialfile=datetime.now().strftime("capture-%Y%m%d-%H%M%S.wlab.json"))
        if path:
            tx = self.get_tx()
            if "error" not in tx:
                params["tx_reference"] = tx
            self.submit(self.note, f"Capturing ADC CH{params['channel']} frame", "capture", path, params,
                        on_done=lambda: self.open_capture(path))

    def disarm(self):
        # Acquisition start/stop is global to both ADC inputs.
        self.submit(self.note, "Disarming ADC", "disarm")

    def load(self):
        path = filedialog.askopenfilename(parent=self, filetypes=CAPTURE_FILES)
        if path:
            self.open_capture(path)

    def open_capture(self, path):
        try:
            settings, samples, checksum = load_capture(path)
            sample_rate = settings.get("sample_rate")
            pretrigger = settings.get("pretrigger")
            if (not isinstance(sample_rate, (int, float)) or not 0 < sample_rate <= 2.7e9
                    or type(pretrigger) is not int or not 0 <= pretrigger < len(samples)):
                raise ValueError("Invalid sample rate or trigger index in the capture.")
        except (ValueError, OSError) as error:
            self.loaded = None
            self.capture_reference = None
            self.message_analysis.set_capture(None)
            self.figure.show(message="Capture file could not be displayed.")
            self.note.set(str(error))
            return
        self.loaded = settings, samples
        self.capture_reference = {"file": str(Path(path).resolve()), "sha256": checksum, "settings": settings}
        self.message_analysis.set_capture(self.capture_reference)
        iq = settings["mode"] == "ddc"
        self.view_box.configure(values=("Time (I / real)", "Time (Q)", "Spectrum") if iq
                                else ("Time (I / real)", "Spectrum"))
        self.view.set("Time (I / real)")
        self.note.set(f"{Path(path).name} | ADC CH{settings['channel']} | {len(samples):,} {'I/Q pairs' if iq else 'real samples'} "
                      f"at {sample_rate / 1e6:g} MS/s\nSHA-256 verified: {checksum[:16]}…")
        self.figure.show()
        self.plot()

    def plot(self):
        if self.loaded is None:
            return
        settings, samples = self.loaded
        rate = settings["sample_rate"]
        iq = settings["mode"] == "ddc"
        if self.view.get() == "Spectrum":
            points = spectrum(samples, rate, iq=iq)
            self.figure.show((points, 0, "Hann FFT (dB relative to peak)"),
                             axes=(1e-6, "Baseband frequency (MHz)" if iq else "Frequency (MHz)", -100, 0),
                             preserve_view=True)
            return
        q = self.view.get() == "Time (Q)"
        values = [sample.imag if q else sample.real for sample in samples]
        pretrigger = settings["pretrigger"]
        points = [((index - pretrigger) / rate, value) for index, value in enumerate(values)]
        limit = 1.0 if iq else settings["full_scale_vpp"] / 2
        self.figure.show((points, limit, "Q (normalized)" if q else "I (normalized)" if iq else "Voltage (V, nominal)"),
                         preserve_view=True)
