"""Offline waveform import, overlay and difference controls."""

from copy import deepcopy
import math
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, ttk

from research_files import save_artifact
from signal_preview import SignalPreview
from waveform_comparison import export_series, inspect_waveform, tx_descriptor

WAVE_FILES = [("Waveform files", "*.wlab.json *.json *.csv"), ("All files", "*.*")]


class WaveformComparison(ttk.Frame):
    def __init__(self, parent, submit, get_tx, get_capture):
        super().__init__(parent, padding=8)
        self.submit, self.get_tx, self.get_capture = submit, get_tx, get_capture
        self.sources = {"reference": None, "received": None}
        self.result = None
        self.revision = 0
        self.columnconfigure(0, weight=1)
        self.rowconfigure(3, weight=1)
        self.alignment = tk.StringVar(value="Auto lag")
        self.lag = tk.StringVar(value="0")
        self.scaling = tk.StringVar(value="Fit gain / phase")
        self.match_centers = tk.BooleanVar(value=True)
        self.frequency = tk.StringVar(value="0")
        self.component = tk.StringVar(value="I / real")
        self.show_error = tk.BooleanVar(value=True)
        self.status = tk.StringVar(value="Choose a reference/sent waveform and a received waveform. Importing files never connects to hardware.")
        self.labels = {key: tk.StringVar(value="Not selected") for key in self.sources}
        files = ttk.Frame(self)
        files.grid(row=0, column=0, sticky="ew")
        for row, (key, title) in enumerate((("reference", "Reference / sent"), ("received", "Received"))):
            ttk.Label(files, text=title).grid(row=row, column=0, sticky="w", padx=(0, 8))
            current = self.use_tx if key == "reference" else self.use_capture
            ttk.Button(files, text="Use current TX" if key == "reference" else "Use loaded RX", command=current).grid(row=row, column=1, padx=3, pady=3)
            ttk.Button(files, text="Load file…", command=lambda key=key: self.load(key)).grid(row=row, column=2, padx=3)
            ttk.Button(files, text="Export log…", command=lambda key=key: self.export_log(key)).grid(row=row, column=3, padx=3)
            if key == "reference":
                ttk.Button(files, text="Use captured TX", command=self.use_captured_tx).grid(row=row, column=4, padx=3)
            ttk.Label(files, textvariable=self.labels[key], wraplength=650, justify="left").grid(row=row, column=5, sticky="w", padx=8)
        files.columnconfigure(5, weight=1)
        options = ttk.Frame(self)
        options.grid(row=1, column=0, sticky="ew", pady=5)
        ttk.Combobox(options, textvariable=self.alignment, state="readonly", width=14,
                     values=("Auto lag", "Manual lag", "Start-to-start")).grid(row=0, column=0, padx=(0, 5))
        ttk.Label(options, text="Manual lag (µs)").grid(row=0, column=1)
        ttk.Entry(options, textvariable=self.lag, width=9).grid(row=0, column=2, padx=4)
        ttk.Combobox(options, textvariable=self.scaling, state="readonly", width=17,
                     values=("Fit gain / phase", "Raw levels")).grid(row=0, column=3, padx=4)
        ttk.Checkbutton(options, text="Match RF centers", variable=self.match_centers).grid(row=0, column=4, padx=5)
        ttk.Label(options, text="Extra reference shift (kHz)").grid(row=1, column=0, columnspan=2, sticky="w", pady=4)
        ttk.Entry(options, textvariable=self.frequency, width=9).grid(row=1, column=2, padx=4)
        self.compare_button = ttk.Button(options, text="Compare waveforms", command=self.compare)
        self.compare_button.grid(row=1, column=3, padx=4)
        self.export_button = ttk.Button(options, text="Export comparison…", command=self.export, state="disabled")
        self.export_button.grid(row=1, column=4, padx=4)
        ttk.Combobox(options, textvariable=self.component, state="readonly", width=10,
                     values=("I / real", "Q", "Magnitude")).grid(row=0, column=5, padx=5)
        ttk.Checkbutton(options, text="Show difference", variable=self.show_error).grid(row=1, column=5)
        status = ttk.Label(self, textvariable=self.status, wraplength=1100, justify="left")
        status.grid(row=2, column=0, sticky="ew", pady=4)
        self.bind("<Configure>", lambda event: status.configure(wraplength=max(300, event.width - 20)))
        body = ttk.Notebook(self)
        body.grid(row=3, column=0, sticky="nsew")
        graph = ttk.Frame(body)
        body.add(graph, text="Overlay / difference")
        self.figure = SignalPreview(graph)
        self.figure.toolbar(graph).pack(fill="x")
        ttk.Label(graph, text="Blue: reference (with selected fit)    Orange: received    Green: received − reference").pack(anchor="w", pady=2)
        self.figure.pack(fill="both", expand=True)
        self.figure.show(message="Import samples from either bench to compare them on the same time axis.")
        detail_page = ttk.Frame(body)
        body.add(detail_page, text="Metrics / source logs")
        self.details = tk.Text(detail_page, height=8, wrap="word", state="disabled")
        detail_scroll = ttk.Scrollbar(detail_page, command=self.details.yview)
        self.details.configure(yscrollcommand=detail_scroll.set)
        self.details.pack(side="left", fill="both", expand=True)
        detail_scroll.pack(side="right", fill="y")
        for variable in (self.alignment, self.lag, self.scaling, self.match_centers, self.frequency):
            variable.trace_add("write", self.invalidate)
        self.component.trace_add("write", lambda *_: self.plot())
        self.show_error.trace_add("write", lambda *_: self.plot())

    def invalidate(self, *_args):
        self.revision += 1
        self.result = None
        self.export_button.state(["disabled"])
        self.figure.show(message="Sources or comparison settings changed. Run Compare waveforms again.")
        self.details.configure(state="normal")
        self.details.delete("1.0", "end")
        self.details.configure(state="disabled")

    def set_source(self, key, source):
        self.sources[key] = deepcopy(source)
        self.invalidate()
        info = source.get("info")
        description = source["label"]
        if info:
            description += f" · {info['samples']:,} samples · {info['sample_rate'] / 1e6:g} MS/s · {info['domain']} · {info['units']}"
        self.labels[key].set(description)
        self.status.set("Sources selected. Confirm their domains and comparison settings, then Compare waveforms.")

    def use_tx(self):
        try:
            source = tx_descriptor(self.get_tx())
        except ValueError as error:
            self.status.set(str(error))
            return
        self.set_source("reference", source)

    def use_capture(self):
        capture = self.get_capture()
        if not capture:
            self.status.set("Load or capture RX data first, or import a received log directly.")
            return
        try:
            source = inspect_waveform(capture["file"])
            if source["sha256"] != capture["sha256"]:
                raise ValueError("Loaded RX file changed. Reload the capture first.")
        except (OSError, ValueError, KeyError, RuntimeError) as error:
            self.status.set(str(error))
            return
        self.set_source("received", source)

    def use_captured_tx(self):
        capture = self.get_capture()
        settings = capture["settings"].get("requested_tx") if capture else None
        if not settings:
            self.status.set("This capture has no saved TX settings. Use current TX settings or import a sent waveform log.")
            return
        try:
            source = tx_descriptor(settings)
        except ValueError as error:
            self.status.set(str(error))
            return
        source["label"] = "TX settings recorded with capture (reconstructed)"
        self.set_source("reference", source)

    def load(self, key):
        path = filedialog.askopenfilename(parent=self, title=f"Load {key} waveform", filetypes=WAVE_FILES)
        if not path:
            return
        try:
            source = inspect_waveform(path)
        except (OSError, ValueError, KeyError, RuntimeError) as error:
            self.status.set(str(error))
            return
        self.set_source(key, source)

    def compare(self):
        if not all(self.sources.values()):
            self.status.set("Choose both reference/sent and received sources first.")
            return
        try:
            frequency = float(self.frequency.get()) * 1e3
            lag = float(self.lag.get()) * 1e-6 if self.alignment.get() == "Manual lag" else 0
            if not math.isfinite(frequency) or not math.isfinite(lag):
                raise ValueError("Enter finite frequency and lag values.")
        except ValueError as error:
            self.status.set(str(error))
            return
        options = dict(alignment=self.alignment.get(), manual_lag_s=lag, scaling=self.scaling.get(),
                       match_centers=self.match_centers.get(), extra_shift_hz=frequency)
        self.invalidate()
        revision = self.revision

        def complete(result):
            if revision != self.revision:
                self.status.set("Comparison discarded because its sources or settings changed. Compare again.")
                return
            self.result = result
            self.status.set(result["summary"] + f"\nApplied lag {result['lag_s'] * 1e6:.5g} µs · "
                            f"reference frequency shift {result['reference_shift_hz'] / 1e3:g} kHz · "
                            f"gain {result['gain_magnitude']:.5g}, phase {result['gain_phase_deg']:.3f}° "
                            f"({'applied' if result['fit_applied'] else 'fit reported only'})")
            self.export_button.state(["!disabled"])
            raw = "Different amplitude units; raw error is not compared" if result["raw_rmse"] is None else f"Raw-level RMSE: {result['raw_rmse']:.6g} {result['units']}"
            text = (f"{raw}\nDisplayed RMSE: {result['rmse']:.6g} {result['units']}\n"
                    f"Residual after gain/phase/DC fit: {result['fitted_residual_db']:.3f} dB relative to received variation\n"
                    f"Common-grid lag resolution: {1e9 / result['sample_rate']:.5g} ns\n"
                    f"Fitted DC: {result['dc_i']:.6g} + j{result['dc_q']:.6g}\n"
                    + "\n".join(result["warnings"]) + "\n\n"
                    + "\n\n".join(f"{name}: {source['descriptor']['label']}\nSHA-256: {source['descriptor']['sha256']}\n"
                                     f"Original: {source['sample_rate'] / 1e6:g} MS/s, {source['samples']:,} samples, {source['domain']}, {source['units']}\n"
                                     f"Provenance: {source['provenance']}" for name, source in zip(("Reference", "Received"), result["sources"])))
            self.details.configure(state="normal")
            self.details.delete("1.0", "end")
            self.details.insert("1.0", text)
            self.details.configure(state="disabled")
            self.plot()

        self.submit(self.status, "Comparing waveform files", "compare_waveforms", self.sources["reference"],
                    self.sources["received"], options, on_result=complete)

    def plot(self):
        if self.result is None:
            return
        curves = self.result["curves"]
        component = self.component.get()
        suffix = "q" if component == "Q" else "i"
        values = {}
        for name in ("reference", "received", "error"):
            values[name] = ([math.hypot(i, q) for i, q in zip(curves[name + "_i"], curves[name + "_q"])]
                            if component == "Magnitude" else curves[name + "_" + suffix])
        if component == "Magnitude":
            values["error"] = [received - reference for received, reference in zip(values["received"], values["reference"])]
        names = ("reference", "received", "error") if self.show_error.get() else ("reference", "received")
        limit = max(1e-12, max(abs(value) for name in names for value in values[name])) * 1.08
        times = curves["time_s"]
        overlays = [(name, list(zip(times, values[name])), color) for name, color in
                    (("received", "#cf5b12"), ("error", "#18834b")) if name in names]
        self.figure.show((list(zip(times, values["reference"])), limit, f"{component} ({self.result['units']})"),
                         overlays=overlays, preserve_view=True,
                         axes=(1e6, "Aligned time (µs)", -limit, limit))

    def export_log(self, key):
        source = self.sources[key]
        if not source:
            self.status.set("Select a waveform source before exporting it.")
            return
        path = filedialog.asksaveasfilename(parent=self, title=f"Export {key} sample log", defaultextension=".wlab.json",
                                            initialfile=f"{key}-waveform.wlab.json")
        if path:
            try:
                export_series(path, source)
            except (OSError, ValueError, RuntimeError, KeyError) as error:
                self.status.set(str(error))
            else:
                self.status.set(f"Exported {Path(path).name}. It can be loaded on another bench.")

    def snapshot(self):
        return deepcopy({key: value for key, value in self.result.items() if key != "curves"}) if self.result else None

    def export(self):
        report = self.snapshot()
        if report is None:
            return
        path = filedialog.asksaveasfilename(parent=self, title="Export waveform comparison", defaultextension=".wlab.json",
                                            initialfile="waveform-comparison.wlab.json")
        if path:
            try:
                save_artifact(path, "waveform_comparison", report)
            except (OSError, ValueError) as error:
                self.status.set(str(error))
            else:
                self.status.set(f"Exported comparison to {Path(path).name}.")
