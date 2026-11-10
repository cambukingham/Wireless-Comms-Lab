"""Classic Windows-style Proteus research bench."""

import json
import math
import tkinter as tk
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from antenna_panel import AntennaPanel
from baseband import validate_bits
from channels import AWG_CHANNELS, validate_awg_channel
from config_checks import check_transmit
from duc import BASEBAND_RATE
from receive_panel import ReceivePanel
from research_files import load_artifact, load_tx_samples, save_artifact
from research_notes import ResearchNotes
from script_workspace import EXAMPLES, ScriptWorkspace, launch_script
from signal_preview import SignalPreview, direct_trace, duc_trace, nrz_trace
from tx_readings import estimate_pad
from waveforms import SAMPLE_RATE, SHAPES, delay_samples


def main():
    root = tk.Tk()
    root.title("WINLAB Proteus Control")
    if root.tk.call("tk", "windowingsystem") == "win32":
        root.iconbitmap(default=str(Path(__file__).with_name("winlab-antenna.ico")))
    width = min(1320, int(root.winfo_screenwidth() * 0.92))
    height = min(840, int(root.winfo_screenheight() * 0.87))
    root.geometry(f"{width}x{height}")
    root.minsize(min(width, 820), min(height, 480))
    style = ttk.Style(root)
    style.theme_use("classic")
    style.configure("ConfigError.TLabel", foreground="#9a1b26")
    style.configure("ConfigWarning.TLabel", foreground="#8b4900")
    tabs = ttk.Notebook(root)
    operation_block = ttk.LabelFrame(root, text="Bench status", padding=6)
    operation_block.pack(side="bottom", fill="x", padx=8, pady=(0, 8))
    operation_state = tk.StringVar(value="Ready")
    operation_detail = tk.StringVar(value="Idle. Instrument connection unchecked.")
    tx_states = {channel: "Unchecked" for channel in AWG_CHANNELS}
    tx_state = tk.StringVar()

    def set_tx_state(channel, value):
        tx_states[channel] = value
        tx_state.set("TX: " + " | ".join(f"CH{number} {state}" for number, state in tx_states.items()))

    set_tx_state(1, "Unchecked")
    adc_state = tk.StringVar(value="ADC: Unchecked")
    operation_block.columnconfigure(1, weight=1)
    badge_text = tk.StringVar()
    badge = tk.Label(operation_block, textvariable=badge_text, width=13, padx=5, pady=4,
                     relief="groove", borderwidth=2, font="TkDefaultFont")
    badge.grid(row=0, column=0, rowspan=2, sticky="w", padx=(0, 8))

    def refresh_badge(*_args):
        state = operation_state.get()
        if state == "Ready" and "ON" in tx_states.values():
            state = "Transmitting"
        background, foreground = {
            "Ready": ("#196539", "white"), "Active": ("#a51c30", "white"),
            "Transmitting": ("#a51c30", "white"), "Not ready": ("#f0a332", "#251603"),
            "Cancelling": ("#275b9f", "white"),
        }.get(state, ("#646464", "white"))
        badge_text.set(state)
        badge.configure(background=background, foreground=foreground)

    operation_state.trace_add("write", refresh_badge)
    tx_state.trace_add("write", refresh_badge)
    refresh_badge()
    cancel_button = ttk.Button(operation_block, text="Cancel operation", state="disabled")
    cancel_button.grid(row=0, column=2, rowspan=2, padx=(6, 0), sticky="e")
    ttk.Label(operation_block, textvariable=operation_detail, wraplength=620).grid(row=0, column=1, sticky="w")
    hardware_status = ttk.Frame(operation_block)
    hardware_status.grid(row=1, column=1, sticky="w")
    ttk.Label(hardware_status, textvariable=tx_state).pack(side="left", padx=(0, 12))
    ttk.Label(hardware_status, textvariable=adc_state).pack(side="left")
    tabs.pack(fill="both", expand=True, padx=8, pady=8)
    connections = ttk.Frame(tabs, padding=12)
    transmit = ttk.Frame(tabs, padding=12)
    tabs.add(connections, text="Connection")
    tabs.add(transmit, text="Transmit")
    pending = None

    transmit.columnconfigure(0, weight=1)
    transmit.rowconfigure(1, weight=1)
    tool_names = {"Basic waveforms": "direct", "Direct baseband": "baseband", "Digital upconverter": "duc"}
    tool_choice = tk.StringVar(value="Basic waveforms")
    settings = ttk.Frame(transmit)
    settings.grid(row=0, column=0, sticky="ew")
    settings.columnconfigure(0, weight=1)
    direct = ttk.LabelFrame(settings, text="Basic waveforms", padding=8)
    baseband_panel = ttk.LabelFrame(settings, text="Direct baseband", padding=8)
    panel = ttk.LabelFrame(settings, text="Digital upconverter", padding=8)
    tool_panels = {"direct": direct, "baseband": baseband_panel, "duc": panel}
    selected_tool = "direct"

    plot_box = ttk.LabelFrame(transmit, text="Signal preview (calculated)", padding=6)
    plot_box.grid(row=1, column=0, sticky="nsew", pady=(8, 4))
    preview = SignalPreview(plot_box)
    preview.toolbar(plot_box).pack(fill="x", pady=(0, 4))
    preview.pack(fill="both", expand=True)

    pattern = tk.StringVar(value="5 MHz cosine (I)")
    carrier = tk.StringVar(value="100")
    voltage = tk.StringVar(value="0.2")
    bits = tk.StringVar(value="10100110")
    symbol_rate = tk.StringVar(value="2.5")
    period_us = tk.StringVar(value="3.2")
    record_delay = tk.StringVar(value="0")
    nco_phase = tk.StringVar(value="0")
    status = tk.StringVar(value="Selected-channel operation results appear here.")
    tx_channel = tk.StringVar(value="1")
    choices = {"5 MHz cosine (I)": "mixer", "Constant I (reference)": "carrier",
               "BPSK bit pattern": "bpsk", "Python I/Q function": "python",
               "Verified I/Q sample file": "samples"}
    pattern_box = ttk.Combobox(panel, textvariable=pattern, values=list(choices),
                               state="readonly", width=24)
    bits_field = ttk.Entry(panel, textvariable=bits)
    rate_field = ttk.Entry(panel, textvariable=symbol_rate)
    repeat_field = ttk.Entry(panel, textvariable=period_us)
    fields = (
        ("Baseband", pattern_box),
        ("Carrier (MHz)", ttk.Entry(panel, textvariable=carrier)),
        ("DAC level (Vpp)", ttk.Entry(panel, textvariable=voltage)),
        ("Bits (repeat)", bits_field), ("Symbol rate (MBd)", rate_field),
        ("Python repeat (µs)", repeat_field),
    )
    def place_fields(parent, fields):
        for row, (label, widget) in enumerate(fields):
            ttk.Label(parent, text=label).grid(row=row, column=0, sticky="w", padx=(0, 12), pady=4)
            widget.grid(row=row, column=1, sticky="ew", pady=4)

    place_fields(panel, fields)

    baseband_choices = {"Bipolar NRZ bit pattern": "nrz", "Python real function": "python",
                        "Verified real sample file": "samples"}
    baseband_source = tk.StringVar(value="Bipolar NRZ bit pattern")
    baseband_level = tk.StringVar(value="0.2")
    sample_sources = {}
    baseband_bits = ttk.Entry(baseband_panel, textvariable=bits)
    baseband_rate = ttk.Entry(baseband_panel, textvariable=symbol_rate)
    baseband_repeat = ttk.Entry(baseband_panel, textvariable=period_us)
    place_fields(baseband_panel, (
        ("Signal", ttk.Combobox(baseband_panel, textvariable=baseband_source, values=list(baseband_choices),
                                state="readonly", width=24)),
        ("Amplitude (Vpp)", ttk.Entry(baseband_panel, textvariable=baseband_level)),
        ("Bits (repeat)", baseband_bits), ("Symbol rate (MBd)", baseband_rate),
        ("Python repeat (µs)", baseband_repeat),
    ))

    timing = ttk.LabelFrame(settings, text="Timing", padding=8)
    timing.grid(row=0, column=1, sticky="ns", padx=(8, 0))
    phase_entry = ttk.Entry(timing, textvariable=nco_phase, width=9)
    place_fields(timing, (
        ("Record delay (ns)", ttk.Entry(timing, textvariable=record_delay, width=9)),
        ("NCO phase (deg)", phase_entry),
    ))
    timing_note = tk.StringVar()
    ttk.Label(timing, textvariable=timing_note, wraplength=180, justify="left").grid(
        row=2, column=0, columnspan=2, sticky="w", pady=(6, 0))

    readings = ttk.Frame(transmit)
    readings.grid(row=0, column=1, rowspan=2, sticky="ns", padx=(10, 0))
    channel_panel = ttk.LabelFrame(readings, text="Transmit output", padding=8)
    channel_panel.pack(fill="x", pady=(0, 8))
    ttk.Label(channel_panel, text="AWG channel").pack(side="left", padx=(0, 8))
    ttk.Combobox(channel_panel, textvariable=tx_channel, values=AWG_CHANNELS,
                 state="readonly", width=5).pack(side="left")
    ttk.Label(readings, text=("Selects the output for all TX actions and Python settings.\n"
                             "Changing selection does not stop another output.\n"
                             "CH1/2 and CH3/4 share resources; changing the DAC clock can affect the paired channel."),
              wraplength=230, justify="left").pack(fill="x", pady=(0, 8))
    pad_panel = ttk.LabelFrame(readings, text="Attenuation estimate (50 ohms)", padding=8)
    pad_panel.pack(fill="x")
    tx_override = tk.StringVar()
    rx_full_scale = tk.StringVar()
    path_gain = tk.StringVar(value="0")
    installed_pad = tk.StringVar(value="0")
    headroom = tk.StringVar(value="6")
    place_fields(pad_panel, tuple(
        (label, ttk.Entry(pad_panel, textvariable=variable, width=9)) for label, variable in (
            ("TX Vpp override", tx_override), ("RX full-scale Vpp", rx_full_scale),
            ("Net path gain (dB)", path_gain), ("Pad in path (dB)", installed_pad),
            ("Headroom (dB)", headroom),
        )
    ))
    estimate_text = tk.StringVar()
    estimate_label = ttk.Label(pad_panel, textvariable=estimate_text, wraplength=215, justify="left")
    estimate_label.grid(row=5, column=0, columnspan=2, sticky="w", pady=(6, 0))
    hardware = ttk.LabelFrame(readings, text="AWG CH1 readback", padding=8)
    hardware.pack(fill="x", pady=(8, 0))
    readback_text = tk.StringVar(value="Read programmed settings from the Proteus.")
    ttk.Label(hardware, textvariable=readback_text, wraplength=220, justify="left").pack(anchor="w")

    shape = tk.StringVar(value="sine")
    wave_freq = tk.StringVar(value="1")
    wave_vpp = tk.StringVar(value="0.2")
    duty = tk.StringVar(value="50")
    falling = tk.BooleanVar(value=False)
    shape_box = ttk.Combobox(direct, values=SHAPES, textvariable=shape, state="readonly")
    duty_field = ttk.Entry(direct, textvariable=duty)
    slope_field = ttk.Checkbutton(direct, text="Falling", variable=falling)
    place_fields(direct, (
        ("Shape", shape_box), ("Frequency (MHz)", ttk.Entry(direct, textvariable=wave_freq)),
        ("Amplitude (Vpp)", ttk.Entry(direct, textvariable=wave_vpp)),
        ("Duty cycle (%)", duty_field), ("Sawtooth slope", slope_field),
    ))

    def number(variable, label):
        try:
            value = float(variable.get())
        except ValueError as error:
            raise ValueError(f"Enter a number for {label}.") from error
        if not math.isfinite(value):
            raise ValueError(f"Enter a finite value for {label}.")
        return value

    def wave_settings():
        name = shape.get()
        fraction = number(duty, "Duty cycle") / 100 if name in ("square", "pulse") else 0.5
        return name, number(wave_freq, "Frequency") * 1e6, number(wave_vpp, "Amplitude"), fraction, (
            name == "sawtooth" and falling.get())

    def duc_settings():
        source = choices[pattern.get()]
        result = dict(pattern=source, carrier_hz=number(carrier, "Carrier") * 1e6,
                      voltage=number(voltage, "DAC level"), delay_ns=number(record_delay, "Record delay"),
                      phase_deg=number(nco_phase, "NCO phase"))
        if source == "bpsk":
            result.update(bits=bits.get(), symbol_rate=number(symbol_rate, "Symbol rate") * 1e6)
        elif source == "python":
            result["period_s"] = number(period_us, "Python repeat") * 1e-6
        elif source == "samples":
            result.update(sample_settings(True))
        return result

    def baseband_settings():
        source = baseband_choices[baseband_source.get()]
        result = dict(shape=source, vpp=number(baseband_level, "Amplitude"),
                      delay_ns=number(record_delay, "Record delay"))
        if source == "nrz":
            result.update(bits=bits.get(), symbol_rate=number(symbol_rate, "Symbol rate") * 1e6)
        elif source == "python":
            result["period_s"] = number(period_us, "Python repeat") * 1e-6
        else:
            result.update(sample_settings(False))
        return result

    def sample_settings(iq):
        path, checksum = sample_sources.get(iq, (None, None))
        if path is None:
            raise ValueError("Choose TX files → Load samples first.")
        return dict(sample_file=path, sample_sha256=checksum)

    def capture_transmit():
        try:
            if selected_tool == "direct":
                name, frequency, level, fraction, reverse = wave_settings()
                result = dict(mode="direct", shape=name, freq=frequency, vpp=level,
                              duty=fraction, falling=reverse, delay_ns=number(record_delay, "Record delay"))
            elif selected_tool == "baseband":
                result = dict(mode="baseband", **baseband_settings())
            else:
                result = dict(mode="duc", **duc_settings())
            result["channel"] = validate_awg_channel(int(tx_channel.get()))
            if any(isinstance(value, float) and not math.isfinite(value) for value in result.values()):
                raise ValueError
            return result
        except ValueError as error:
            return {"channel": int(tx_channel.get()),
                    "error": str(error) or "Enter finite numeric values in the active Transmit tool."}

    def script_status(state, detail):
        states = {
            "active": ("Active", f"Running Python script {detail}"),
            "cancelling": ("Cancelling", "Stopping Python script."),
            "cancelled": ("Not ready", "Script cancelled. Verify any hardware state it changed."),
            "error": ("Not ready", f"Python exited with code {detail}. See script output."),
            "done": ("Ready", "Python finished successfully."),
        }
        title, message = states[state]
        operation_state.set(title)
        operation_detail.set(message)
        if state == "active":
            for channel in AWG_CHANNELS:
                set_tx_state(channel, "Unverified")
            adc_state.set("ADC: Unverified after script")
        cancel_button.state(["!disabled"] if state == "active" else ["disabled"])
    scripts = ScriptWorkspace(tabs, bench_busy=lambda: pending is not None,
                              transmit_snapshot=capture_transmit, operation_status=script_status)
    tabs.add(scripts, text="Python")

    preview_job = None
    tx_warning = ttk.Label(transmit, justify="left", wraplength=760)
    tx_warning.grid(row=3, column=0, columnspan=2, sticky="ew")

    def refresh_tx_warnings():
        severity, text = check_transmit(capture_transmit())
        if severity == "info" and text == "TX settings pass the offline checks.":
            text = ("Duty applies to square and pulse. Slope applies to sawtooth."
                    if selected_tool == "direct" else "Bits and symbol rate apply to the selected bit-pattern source.")
        style_name = {"error": "ConfigError.TLabel", "warning": "ConfigWarning.TLabel"}.get(severity, "TLabel")
        prefix = {"error": "Fix before transmit · ", "warning": "Check · "}.get(severity, "")
        tx_warning.configure(text=prefix + text, style=style_name)
        return severity

    def refresh_pad(*_args):
        estimate_label.configure(style="TLabel")
        if not rx_full_scale.get().strip():
            estimate_text.set("Enter receiver full-scale Vpp. TX defaults to the programmed level.")
            return
        try:
            level = {"direct": wave_vpp, "baseband": baseband_level, "duc": voltage}[selected_tool]
            tx_level = tx_override.get().strip() or level.get()
            full_scale = float(rx_full_scale.get())
            estimate = estimate_pad(float(tx_level), full_scale,
                                    path_gain_db=float(path_gain.get()), pad_db=float(installed_pad.get()),
                                    headroom_db=float(headroom.get()))
        except ValueError as error:
            estimate_text.set(str(error))
            estimate_label.configure(style="ConfigWarning.TLabel")
            return
        advice = ""
        if estimate.additional_db > 0.01:
            estimate_label.configure(style="ConfigWarning.TLabel")
            advice = ("\nCheck · projected RX exceeds full scale." if estimate.rx_vpp > full_scale
                      else "\nCheck · projected RX exceeds the headroom target.")
        estimate_text.set(f"Minimum total pad {estimate.minimum_db:.2f} dB\n"
                          f"Additional pad {estimate.additional_db:.2f} dB\n"
                          f"Estimated RX {estimate.rx_vpp:.4g} Vpp (target {estimate.target_vpp:.4g}){advice}")

    def refresh_preview():
        nonlocal preview_job
        preview_job = None
        refresh_tx_warnings()
        timing_note.set("")
        try:
            requested = float(record_delay.get())
            rate = BASEBAND_RATE if selected_tool == "duc" else SAMPLE_RATE
            effective = delay_samples(requested, rate) * 1e9 / rate
            kind = "Waveform" if selected_tool == "direct" else "Baseband"
            phase_hint = "\nNCO phase applies in DUC mode." if selected_tool != "duc" else ""
            timing_note.set(f"{kind} shift {effective:g} ns\nWraps within each repeat.{phase_hint}")
            if selected_tool == "direct":
                trace = direct_trace(*wave_settings(), delay_ns=requested)
            elif selected_tool == "baseband":
                params = baseband_settings()
                source = params.pop("shape")
                if source == "python":
                    preview.show(message="Use in Python to supply your real baseband(t) function.")
                    return
                if source == "samples":
                    preview.show(message=f"Verified real samples: {Path(params['sample_file']).name}")
                    return
                trace = nrz_trace(**params)
            else:
                params = duc_settings()
                if params["pattern"] == "python":
                    preview.show(message="Use in Python to supply your baseband(t) function. "
                                         "The preview will be available for the built-in sources.")
                    return
                if params["pattern"] == "samples":
                    preview.show(message=f"Verified I/Q samples: {Path(params['sample_file']).name}")
                    return
                trace = duc_trace(**params)
        except ValueError as error:
            preview.show(message=str(error))
        else:
            preview.show(trace)

    def schedule_preview(*_args):
        nonlocal preview_job
        if preview_job is not None:
            root.after_cancel(preview_job)
        preview_job = root.after(180, refresh_preview)

    def select_tool(_event=None):
        nonlocal selected_tool
        tool_panels[selected_tool].grid_remove()
        selected_tool = tool_names[tool_choice.get()]
        tool_panels[selected_tool].grid(row=0, column=0, sticky="ew")
        schedule_preview()
        refresh_pad()

    for variable in (shape, wave_freq, wave_vpp, duty, falling, pattern, carrier, voltage,
                     bits, symbol_rate, period_us, record_delay, nco_phase, baseband_source, baseband_level):
        variable.trace_add("write", schedule_preview)
    for variable in (wave_vpp, voltage, baseband_level, tx_override, rx_full_scale, path_gain,
                     installed_pad, headroom):
        variable.trace_add("write", refresh_pad)
    select_tool()

    buttons = ttk.Frame(transmit)
    buttons.grid(row=2, column=0, columnspan=2, sticky="w", pady=4)
    chooser = ttk.Combobox(buttons, values=list(tool_names), textvariable=tool_choice,
                           state="readonly", width=21)
    chooser.grid(row=0, column=0, padx=(0, 8))
    chooser.bind("<<ComboboxSelected>>", select_tool)
    ttk.Label(transmit, textvariable=status, relief="sunken", padding=6,
              wraplength=760).grid(row=4, column=0, columnspan=2, sticky="ew")
    worker = ThreadPoolExecutor(max_workers=1)
    action_buttons = []

    connection_status = tk.StringVar(value="Click Connect over Ethernet to identify the Proteus. Outputs are unchanged.")
    operation_process = None
    cancelled = False
    slot = tk.StringVar(value="5")
    connections.columnconfigure(0, weight=1)
    ethernet_panel = ttk.LabelFrame(connections, text="Laptop → Proteus over Ethernet", padding=12)
    ethernet_panel.grid(row=0, column=0, sticky="ew")
    address = json.loads(Path(__file__).with_name("config.json").read_text(encoding="utf-8"))
    ttk.Label(ethernet_panel, text=f"Proteus address: {address['host']}    TCP port: {address['port']}").pack(anchor="w")
    ttk.Label(ethernet_panel, text=(
        "Transmit, Receive and Python instrument controls use this Ethernet address.\n"
        "No local PCIe driver is needed on the laptop. Each operation opens its own connection."
    ), justify="left", wraplength=700).pack(anchor="w", pady=(6, 10))
    ttk.Label(connections, textvariable=connection_status, justify="left", wraplength=760,
              relief="sunken", padding=8).grid(row=1, column=0, sticky="ew", pady=10)
    pxie_panel = ttk.LabelFrame(connections, text="Optional diagnostic — chassis computer only", padding=12)
    pxie_panel.grid(row=2, column=0, sticky="ew")
    ttk.Label(pxie_panel, text=(
        "Use this only when the app is running on the chassis controller with Tabor's local driver.\n"
        "This checks local hardware; it does not select the connection for Transmit or Receive."
    ), justify="left", wraplength=700).grid(row=0, column=0, columnspan=3, sticky="w", pady=(0, 8))
    ttk.Label(pxie_panel, text="Physical slot").grid(row=1, column=0, sticky="w")
    ttk.Entry(pxie_panel, textvariable=slot, width=5).grid(row=1, column=1, sticky="w", padx=8)

    def poll(result_text, operation, label, on_done, channel, on_result):
        nonlocal pending, operation_process, cancelled
        if not pending.done():
            root.after(100, poll, result_text, operation, label, on_done, channel, on_result)
            return
        success = False
        if cancelled:
            detail = f"{label} cancelled."
            if operation in ("capture", "disarm"):
                detail += " Use Disarm ADC to confirm the digitizer is idle."
            elif operation in ("transmit", "output_off"):
                detail += f" Use Output Off or Read CH{channel} to verify that output's state."
            result_text.set(detail)
            operation_state.set("Ready" if operation in ("ethernet", "pxie", "read_ch1", "decode_bpsk", "compare_waveforms") else "Not ready")
            operation_detail.set(detail)
        else:
            try:
                result = pending.result()
                result_text.set(result.get("summary", "Analysis completed.") if isinstance(result, dict) else result)
            except Exception as error:
                result_text.set(f"Operation failed: {error}")
                operation_state.set("Not ready")
                operation_detail.set(f"{label} failed. {str(error)[:180]}")
            else:
                success = True
                operation_state.set("Ready")
                operation_detail.set(f"{label} completed.")
                if operation in ("transmit", "output_off", "read_ch1"):
                    state = "ON" if result.startswith(f"CH{channel} output ON") else "OFF"
                    set_tx_state(channel, state)
                elif operation in ("capture", "disarm"):
                    adc_state.set("ADC: Disarmed")
        if not success and operation in ("transmit", "output_off", "read_ch1"):
            set_tx_state(channel, "Unverified")
        if not success and operation in ("capture", "disarm"):
            adc_state.set("ADC: Unverified")
        pending = None
        operation_process = None
        cancelled = False
        cancel_button.state(["disabled"])
        for button in action_buttons:
            button.state(["!disabled"])
        if success and on_done is not None:
            on_done()
        if success and on_result is not None:
            on_result(result)

    def submit(result_text, label, operation, *args, on_done=None, on_result=None):
        nonlocal pending, operation_process
        if pending is not None or scripts.process is not None:
            result_text.set("Wait for the active bench operation or script to finish.")
            return
        try:
            helper = Path(__file__).resolve().with_name("bench_worker.py")
            operation_process = launch_script(helper, args=(operation, json.dumps(args, allow_nan=False)))
        except (OSError, ValueError) as error:
            result_text.set(f"Could not start operation: {error}")
            operation_state.set("Not ready")
            operation_detail.set(f"{label} could not start.")
            return
        pending = worker.submit(collect_result, operation_process)
        channel = (args[0].get("channel", 1) if operation == "transmit" else
                   args[0] if operation in ("output_off", "read_ch1") and args else None)
        for button in action_buttons:
            button.state(["disabled"])
        result_text.set(f"{label}…")
        operation_state.set("Active")
        operation_detail.set(f"{label}…")
        if operation in ("transmit", "output_off", "read_ch1"):
            set_tx_state(channel, "Checking" if operation == "read_ch1" else "Updating")
        elif operation in ("capture", "disarm"):
            adc_state.set("ADC: Capturing" if operation == "capture" else "ADC: Disarming")
        cancel_button.state(["!disabled"])
        root.after(100, poll, result_text, operation, label, on_done, channel, on_result)

    def collect_result(process):
        with process:
            output, _ = process.communicate()
        try:
            result = json.loads(output.strip().splitlines()[-1])
        except (IndexError, ValueError) as error:
            raise RuntimeError(output.strip()[-600:] or f"Helper exited with code {process.returncode}.") from error
        if process.returncode != 0 or "error" in result:
            raise RuntimeError(result.get("error", f"Helper exited with code {process.returncode}."))
        return result["result"]

    def cancel_operation(_event=None):
        nonlocal cancelled
        if operation_process is None:
            scripts.stop()
            return
        if operation_process.poll() is not None:
            return
        try:
            operation_process.terminate()
        except OSError as error:
            if operation_process.poll() is None:
                operation_detail.set(f"Could not cancel: {error}")
                return
        cancelled = True
        cancel_button.state(["disabled"])
        operation_state.set("Cancelling")
        operation_detail.set("Stopping the active helper process…")

    def connect_pxie():
        try:
            number = int(slot.get())
            if number < 1:
                raise ValueError
        except ValueError:
            connection_status.set("Enter a positive physical slot number.")
            return
        submit(connection_status, "Checking local PXIe", "pxie", number)

    ethernet_button = ttk.Button(ethernet_panel, text="Connect over Ethernet",
                                 command=lambda: submit(connection_status, "Checking Ethernet", "ethernet"))
    ethernet_button.pack(anchor="w")
    pxie_button = ttk.Button(pxie_panel, text="Check local PXIe driver", command=connect_pxie)
    pxie_button.grid(row=1, column=2, sticky="w", padx=8)
    action_buttons.extend((ethernet_button, pxie_button))

    cancel_button.configure(command=cancel_operation)
    root.bind("<Escape>", cancel_operation)

    receive = ReceivePanel(tabs, submit, lambda value: rx_full_scale.set(f"{value:g}"), capture_transmit)
    tabs.insert(2, receive, text="Receive")
    tabs.bind("<<NotebookTabChanged>>", lambda _: receive.refresh_warnings() if tabs.select() == str(receive) else None)
    action_buttons.extend((receive.capture_button, receive.disarm_button, receive.message_analysis.decode_button,
                           receive.waveform_compare.compare_button))

    def transmit_action(action):
        channel = validate_awg_channel(int(tx_channel.get()))
        if action == "stop":
            submit(status, f"Switching CH{channel} output off", "output_off", channel)
            return
        config = capture_transmit()
        if refresh_tx_warnings() == "error":
            status.set("Review the configuration message before transmitting.")
        elif config.get("pattern") == "python" or config.get("shape") == "python":
            status.set("Use in Python to supply the baseband function and run the script.")
        else:
            label = f"Configuring CH{channel}" if action == "setup" else f"Starting CH{channel} playback"
            submit(status, label, "transmit", config, action)

    read_button = ttk.Button(hardware, text="Read CH1",
                             command=lambda: submit(readback_text, f"Reading CH{tx_channel.get()}",
                                                    "read_ch1", int(tx_channel.get())))
    read_button.pack(anchor="w", pady=(6, 0))
    action_buttons.append(read_button)

    def channel_changed(*_args):
        channel = int(tx_channel.get())
        hardware.configure(text=f"AWG CH{channel} readback")
        read_button.configure(text=f"Read CH{channel}")
        readback_text.set(f"Read programmed settings from AWG CH{channel}.")
        status.set(f"AWG CH{channel} selected. Outputs are unchanged; Start and Output Off target this channel.")
        direct.configure(text=f"CH{channel} Basic waveforms")
        baseband_panel.configure(text=f"CH{channel} Direct baseband")
        panel.configure(text=f"CH{channel} Digital upconverter")

    tx_channel.trace_add("write", channel_changed)
    channel_changed()

    for column, (label, action) in enumerate((("Setup (Off)", "setup"), ("Start", "start"),
                                               ("Output Off", "stop"))):
        button = ttk.Button(buttons, text=label,
                            command=lambda action=action: transmit_action(action))
        button.grid(row=0, column=column + 1, padx=4)
        action_buttons.append(button)

    def use_in_python():
        example = "Use Transmit settings"
        if selected_tool == "duc" and choices[pattern.get()] == "python":
            example = "Python I/Q function"
        elif selected_tool == "baseband" and baseband_choices[baseband_source.get()] == "python":
            example = "Python real baseband"
        scripts.load_example(EXAMPLES[example])
        tabs.select(scripts)
        scripts.editor.focus_set()

    ttk.Button(buttons, text="Use in Python", command=use_in_python).grid(row=0, column=4, padx=4)

    artifact_filters = [("WINLAB bench file", "*.wlab.json"), ("JSON files", "*.json")]

    def choose_tool(mode):
        tool_choice.set(next(label for label, key in tool_names.items() if key == mode))
        select_tool()

    def load_message(binary):
        path = filedialog.askopenfilename(parent=root, title="Load message bytes" if binary else "Load bit text")
        if not path:
            return
        try:
            with open(path, "rb") as stream:
                raw = stream.read(33 if binary else 4097)
            if binary and not 1 <= len(raw) <= 32:
                raise ValueError("Use a message file from 1 to 32 bytes for a repeating bit pattern.")
            if not binary and len(raw) > 4096:
                raise ValueError("Use a text file with 1 to 256 binary digits.")
            text = "".join(f"{byte:08b}" for byte in raw) if binary else raw.decode("ascii")
            text = validate_bits(text, 2.5e6)
        except (OSError, ValueError) as error:
            status.set(str(error))
            return
        bits.set(text)
        if selected_tool == "duc":
            pattern.set("BPSK bit pattern")
        else:
            baseband_source.set("Bipolar NRZ bit pattern")
            choose_tool("baseband")
        status.set(f"Loaded {len(text)} bits from {Path(path).name}. Review settings before Start.")

    def verify_samples(path, iq, expected=None):
        path = str(Path(path).resolve())
        payload, checksum = load_tx_samples(path, iq=iq, sample_rate=BASEBAND_RATE if iq else SAMPLE_RATE,
                                             expected_sha256=expected)
        return path, checksum, len(payload) // (4 if iq else 2)

    def load_samples():
        path = filedialog.askopenfilename(parent=root, title="Load TX samples", filetypes=artifact_filters)
        if not path:
            return
        try:
            metadata, _, checksum = load_artifact(path, "tx_samples")
            iq = metadata.get("iq") is True
            path, checksum, count = verify_samples(path, iq, checksum)
        except (OSError, ValueError) as error:
            status.set(str(error))
            return
        sample_sources[iq] = path, checksum
        if iq:
            pattern.set("Verified I/Q sample file")
            choose_tool("duc")
        else:
            baseband_source.set("Verified real sample file")
            choose_tool("baseband")
        status.set(f"Loaded {count:,} {'I/Q pairs' if iq else 'real samples'}. SHA-256 {checksum[:16]}…")

    def save_plan():
        config = capture_transmit()
        if "error" in config:
            status.set(config["error"])
            return
        path = filedialog.asksaveasfilename(parent=root, title="Save TX plan", filetypes=artifact_filters,
                                            defaultextension=".wlab.json", initialfile="transmit.wlab.json")
        if path:
            try:
                checksum = save_artifact(path, "tx_plan", config)
            except (OSError, ValueError) as error:
                status.set(str(error))
            else:
                status.set(f"Saved {Path(path).name}. SHA-256 {checksum[:16]}…")

    def export_tx_log():
        from waveform_comparison import export_series, tx_descriptor
        config = capture_transmit()
        if refresh_tx_warnings() == "error":
            status.set("Review the TX configuration before exporting its reference samples.")
            return
        path = filedialog.asksaveasfilename(parent=root, title="Export requested TX waveform samples",
                                            filetypes=artifact_filters, defaultextension=".wlab.json",
                                            initialfile="tx-waveform.wlab.json")
        if path:
            try:
                export_series(path, tx_descriptor(config))
            except (OSError, ValueError, RuntimeError, KeyError) as error:
                status.set(str(error))
            else:
                status.set("Exported requested TX samples for comparison. This is a reconstructed reference, not a measured output.")

    def load_plan():
        path = filedialog.askopenfilename(parent=root, title="Load TX plan", filetypes=artifact_filters)
        if not path:
            return
        try:
            plan, _, checksum = load_artifact(path, "tx_plan")
            mode = plan["mode"]
            updates = [(record_delay, plan.get("delay_ns", 0)),
                       (tx_channel, str(validate_awg_channel(plan.get("channel", 1))))]
            if mode == "direct":
                if plan["shape"] not in SHAPES or type(plan["falling"]) is not bool:
                    raise ValueError("Invalid direct waveform settings.")
                updates.extend(((shape, plan["shape"]), (wave_freq, plan["freq"] / 1e6),
                                (wave_vpp, plan["vpp"]), (duty, plan["duty"] * 100), (falling, plan["falling"])))
                source = plan["shape"]
            elif mode in ("duc", "baseband"):
                iq = mode == "duc"
                source = plan["pattern" if iq else "shape"]
                names = choices if iq else baseband_choices
                label = next((label for label, key in names.items() if key == source), None)
                if label is None:
                    raise ValueError("Invalid source in TX plan.")
                if iq:
                    updates.extend(((pattern, label), (carrier, plan["carrier_hz"] / 1e6),
                                    (voltage, plan["voltage"]), (nco_phase, plan.get("phase_deg", 0))))
                else:
                    updates.extend(((baseband_source, label), (baseband_level, plan["vpp"])))
                if source in ("nrz", "bpsk"):
                    updates.extend(((bits, validate_bits(plan["bits"], plan["symbol_rate"])),
                                    (symbol_rate, plan["symbol_rate"] / 1e6)))
                elif source == "python":
                    updates.append((period_us, plan["period_s"] * 1e6))
                elif source == "samples":
                    linked_path = Path(plan["sample_file"])
                    if not linked_path.is_absolute():
                        linked_path = Path(path).parent / linked_path
                    sample_path, sample_hash, _ = verify_samples(linked_path, iq, plan["sample_sha256"])
                    sample_sources[iq] = sample_path, sample_hash
            else:
                raise ValueError("Invalid transmit mode in TX plan.")
        except (OSError, ValueError, TypeError, KeyError, AttributeError) as error:
            status.set(f"Could not load plan: {error}")
            return
        for variable, value in updates:
            variable.set(f"{value:.12g}" if isinstance(value, float) else value)
        choose_tool(mode)
        status.set(f"Loaded {Path(path).name}. SHA-256 {checksum[:16]}… Review settings before Start.")

    files_button = ttk.Menubutton(buttons, text="TX files…")
    files_menu = tk.Menu(files_button, tearoff=False)
    for label, command in (("Load bit text…", lambda: load_message(False)),
                           ("Load message bytes…", lambda: load_message(True)),
                           ("Load samples…", load_samples), ("Save TX plan…", save_plan),
                           ("Load TX plan…", load_plan), ("Export waveform log…", export_tx_log)):
        files_menu.add_command(label=label, command=command)
    files_button.configure(menu=files_menu)
    files_button.grid(row=0, column=5, padx=4)

    antenna = AntennaPanel(tabs)
    tabs.add(antenna, text="Antenna")

    def note_context():
        return {
            "requested_tx_settings": capture_transmit(),
            "requested_rx_settings": receive.settings_snapshot(),
            "verified_rx_capture": receive.capture_reference,
            "rx_message_analysis": receive.message_analysis.snapshot(),
            "waveform_comparison": receive.waveform_compare.snapshot(),
            "rf_path": antenna.snapshot(),
            "bench_status": {"state": badge_text.get(), "detail": operation_detail.get(),
                             "tx": tx_state.get(), "adc": adc_state.get()},
        }

    def script_snapshot():
        name = scripts.path.name if scripts.path else "editor.py"
        return name, scripts.editor.get("1.0", "end-1c")

    notes = ResearchNotes(tabs, note_context, script_snapshot)
    tabs.add(notes, text="Research Notes")

    def close():
        if pending is not None or scripts.process is not None:
            messagebox.showinfo("Bench is busy", "Wait for the operation or stop the Python script.", parent=root)
        elif scripts.confirm_discard() and notes.confirm_leave() and antenna.confirm_leave():
            worker.shutdown(wait=False)
            root.destroy()

    root.protocol("WM_DELETE_WINDOW", close)
    root.mainloop()


if __name__ == "__main__":
    main()
