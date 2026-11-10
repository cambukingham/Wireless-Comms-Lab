"""Edit research scripts and run them in a separate Python process."""

import builtins
import io
import json
import keyword
import os
import queue
import subprocess
import sys
import threading
import tkinter as tk
import tokenize
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from bench_api import SETTINGS_ENV

LAB_FOLDER = Path(__file__).resolve().parent
EXPERIMENTS_FOLDER = LAB_FOLDER.parent / "experiments"
DRIVER_FOLDER = (LAB_FOLDER.parent / "Rutgers (2)" / "Rutgers" / "SourceFiles").resolve()


def is_bench_path(path):
    resolved = path.resolve()
    return any(resolved.is_relative_to(folder) for folder in (LAB_FOLDER, DRIVER_FOLDER))


def experiment_script_path(path):
    path = path.resolve()
    if is_bench_path(path):
        raise ValueError("This folder contains the bench application. Choose an experiment script outside it.")
    if path.suffix.lower() != ".py":
        raise ValueError("Choose a Python script with a .py extension.")
    return path


STARTER = '''from waveforms import generate

# Prepare one repeatable 1 MHz waveform offline.
values, payload, cycles = generate("sine", 1e6)
print(f"Prepared {len(values)} samples across {cycles} cycles")
print(f"Binary payload: {len(payload)} bytes")
'''
EXAMPLES = {
    "Offline waveform": STARTER,
    "Identify Proteus": '''from proteus import connect

with connect() as instrument:
    print(instrument.query("*IDN?"))
    print("Options:", instrument.query("*OPT?"))
''',
    "Prepare DUC with output off": '''from duc import run_duc

# Program the 100 MHz mixer test with CH1 off.
print(run_duc("setup", pattern="mixer", carrier_hz=100e6, voltage=0.2))
''',
    "Use Transmit settings": '''from bench_api import transmit

# Uses the AWG channel selected in Transmit. Use "start" to enable it.
print(transmit("setup"))
''',
    "Python I/Q function": '''from math import cos, tau
from bench_api import transmit, transmit_settings

period = transmit_settings()["period_s"]

def baseband(t):
    return 0.5 * cos(tau * t / period)  # Real values drive I, with Q = 0.

print(transmit("setup", baseband=baseband))
''',
    "Python real baseband": '''from math import cos, tau
from bench_api import transmit, transmit_settings

period = transmit_settings()["period_s"]

def baseband(t):
    return cos(tau * t / period)  # Real normalized voltage on the selected AWG output.

print(transmit("setup", baseband=baseband))
''',
    "Save real TX samples": '''from math import sin, tau
from research_files import save_tx_samples

# One 1 MHz period on the direct playback sample grid (1 GS/s).
samples = [sin(tau * n / 1000) for n in range(1000)]
print(save_tx_samples("sine-samples.wlab.json", samples))
''',
    "Capture an ADC frame": '''from datetime import datetime
from rx_capture import capture

path = datetime.now().strftime("capture-%Y%m%d-%H%M%S.wlab.json")
print(capture(path, channel=1, mode="real", samples=4800))
''',
}
SYNTAX_COLORS = {
    "keyword": "#6515bd", "string": "#007521", "comment": "#17606e",
    "number": "#a74400", "builtin": "#0057c2",
}
BUILTIN_NAMES = frozenset(dir(builtins))


def syntax_spans(source):
    """Yield Python token colors and Tk coordinates, even during partial edits."""
    try:
        for token in tokenize.generate_tokens(io.StringIO(source).readline):
            name = tokenize.tok_name[token.type]
            if name in ("STRING", "FSTRING_START", "FSTRING_MIDDLE", "FSTRING_END"):
                tag = "string"
            elif name in ("COMMENT", "NUMBER"):
                tag = name.lower()
            elif name == "NAME" and keyword.iskeyword(token.string):
                tag = "keyword"
            elif name == "NAME" and token.string in BUILTIN_NAMES:
                tag = "builtin"
            else:
                continue
            yield tag, "%d.%d" % token.start, "%d.%d" % token.end
    except (tokenize.TokenError, SyntaxError):
        # An unfinished string or indentation error can occur while typing.
        return


def launch_script(path, import_folder=None, transmit_snapshot=None, *, args=()):
    env = os.environ.copy()
    paths = [str(LAB_FOLDER)]
    if import_folder is not None:
        paths.append(str(import_folder))
    if env.get("PYTHONPATH"):
        paths.append(env["PYTHONPATH"])
    env["PYTHONPATH"] = os.pathsep.join(paths)
    env["PYTHONIOENCODING"] = "utf-8"
    env.pop(SETTINGS_ENV, None)
    if transmit_snapshot is not None:
        env[SETTINGS_ENV] = json.dumps(transmit_snapshot, allow_nan=False)
    executable = Path(sys.executable)
    if executable.name.lower() == "pythonw.exe":
        executable = executable.with_name("python.exe")
    return subprocess.Popen(
        [str(executable), "-B", "-u", str(path), *args], cwd=path.parent, env=env,
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace",
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )


class ScriptWorkspace(ttk.Frame):
    def __init__(self, parent, bench_busy, transmit_snapshot=None, operation_status=None):
        super().__init__(parent, padding=8)
        self.bench_busy = bench_busy
        self.transmit_snapshot = transmit_snapshot
        self.operation_status = operation_status or (lambda *_args: None)
        self.stopped = False
        self.path = None
        self.folder = EXPERIMENTS_FOLDER
        self.folder.mkdir(exist_ok=True)
        self.entries = []
        self.saved_text = STARTER
        self.process = None
        self.import_folder = None
        self.highlight_job = None
        self.events = queue.Queue(maxsize=1024)
        self.columnconfigure(0, weight=1)
        self.rowconfigure(2, weight=1)

        bar = ttk.Frame(self)
        bar.grid(row=0, column=0, sticky="ew", pady=(0, 6))
        for label, command in (("Open…", self.open), ("Save", self.save),
                               ("Save & Run", self.run), ("Stop Script", self.stop)):
            ttk.Button(bar, text=label, command=command).pack(side="left", padx=(0, 4))
        examples = ttk.Menubutton(bar, text="Examples")
        menu = tk.Menu(examples, tearoff=False)
        for label, source in EXAMPLES.items():
            menu.add_command(label=label, command=lambda source=source: self.load_example(source))
        examples.configure(menu=menu)
        examples.pack(side="left", padx=(0, 4))
        ttk.Button(bar, text="Import folder…", command=self.choose_import_folder).pack(side="left")

        info = ttk.Frame(self)
        info.grid(row=1, column=0, sticky="ew", pady=(0, 6))
        self.filename = tk.StringVar(value="Untitled.py")
        self.import_info = tk.StringVar(value="Imports: script folder and bench modules")
        ttk.Label(info, textvariable=self.filename).pack(side="left")
        ttk.Label(info, textvariable=self.import_info).pack(side="right")

        panes = tk.PanedWindow(self, orient="horizontal", sashwidth=8, sashrelief="raised")
        panes.grid(row=2, column=0, sticky="nsew")
        self.file_column(panes)
        self.editor = self.text_area(panes, "Python source", editable=True)
        for tag, color in SYNTAX_COLORS.items():
            self.editor.tag_configure(tag, foreground=color)
        self.editor.insert("1.0", STARTER)
        self.editor.edit_modified(False)
        self.editor.bind("<<Modified>>", self.editor_changed)
        self.editor.bind("<Tab>", self.indent)
        self.editor.bind("<Control-s>", lambda event: self.save() and "break")
        self.bind("<F5>", lambda event: self.run())
        self.editor.bind("<F5>", lambda event: self.run())
        self.highlight()
        self.console = self.text_area(panes, "Script output", editable=False)
        self.console.configure(state="disabled")

    def file_column(self, panes):
        box = ttk.LabelFrame(panes, text="Script files", padding=6, width=220)
        panes.add(box, minsize=160, width=220, stretch="never")
        box.columnconfigure(0, weight=1)
        box.rowconfigure(2, weight=1)
        tools = ttk.Frame(box)
        tools.grid(row=0, column=0, columnspan=2, sticky="ew", pady=(0, 4))
        ttk.Button(tools, text="New", width=5, command=lambda: self.load_example("")).pack(side="left")
        ttk.Button(tools, text="Folder…", width=8, command=self.choose_folder).pack(side="left", padx=3)
        ttk.Button(tools, text="Refresh", width=8, command=self.refresh_files).pack(side="left")
        self.folder_label = tk.StringVar()
        ttk.Label(box, textvariable=self.folder_label, wraplength=180).grid(
            row=1, column=0, columnspan=2, sticky="w", pady=(0, 4))
        self.files = tk.Listbox(box, width=22, exportselection=False)
        scroll = ttk.Scrollbar(box, orient="vertical", command=self.files.yview)
        self.files.configure(yscrollcommand=scroll.set)
        self.files.grid(row=2, column=0, sticky="nsew")
        scroll.grid(row=2, column=1, sticky="ns")
        self.files.bind("<Double-1>", self.open_selected)
        self.files.bind("<Return>", self.open_selected)
        self.refresh_files()

    def choose_folder(self):
        folder = filedialog.askdirectory(parent=self, initialdir=self.folder)
        if folder:
            self.refresh_files(Path(folder))

    def refresh_files(self, folder=None):
        folder = folder if folder is not None else self.folder
        try:
            folder = folder.resolve()
            if is_bench_path(folder):
                raise ValueError("This folder contains the bench application. Choose an experiment folder.")
            entries = [(path, path.is_dir()) for path in folder.iterdir()
                       if path.name not in (".git", "__pycache__", ".venv") and not is_bench_path(path)]
        except (OSError, ValueError, RuntimeError) as error:
            messagebox.showerror("Script files", str(error), parent=self)
            return
        entries = [(path, is_dir) for path, is_dir in entries if is_dir or path.suffix.lower() == ".py"]
        entries.sort(key=lambda entry: (not entry[1], entry[0].name.casefold()))
        self.folder = folder
        self.folder_label.set(folder.name or str(folder))
        self.entries = ([(folder.parent, True)] if folder.parent != folder else []) + entries
        self.files.delete(0, "end")
        for path, is_dir in self.entries:
            self.files.insert("end", "../" if path == folder.parent else path.name + ("/" if is_dir else ""))

    def open_selected(self, _event):
        selected = self.files.curselection()
        if selected:
            path, is_dir = self.entries[selected[0]]
            if is_dir:
                self.refresh_files(path)
            elif self.process is None and self.confirm_discard():
                self.open_path(path)
        return "break"

    def text_area(self, panes, label, *, editable):
        box = ttk.LabelFrame(panes, text=label, padding=4)
        panes.add(box, minsize=160, stretch="always")
        box.columnconfigure(0, weight=1)
        box.rowconfigure(0, weight=1)
        area = tk.Text(box, font="TkFixedFont", width=48 if editable else 40, height=16,
                       wrap="none", undo=editable, padx=10, pady=8)
        vertical = ttk.Scrollbar(box, orient="vertical", command=area.yview)
        horizontal = ttk.Scrollbar(box, orient="horizontal", command=area.xview)
        area.configure(yscrollcommand=vertical.set, xscrollcommand=horizontal.set)
        area.grid(row=0, column=0, sticky="nsew")
        vertical.grid(row=0, column=1, sticky="ns")
        horizontal.grid(row=1, column=0, sticky="ew")
        return area

    def indent(self, _event):
        self.editor.insert("insert", "    ")
        return "break"

    def editor_changed(self, _event):
        if self.editor.edit_modified():
            self.editor.edit_modified(False)
            if self.highlight_job is not None:
                self.after_cancel(self.highlight_job)
            self.highlight_job = self.after(120, self.highlight)

    def highlight(self):
        self.highlight_job = None
        for tag in SYNTAX_COLORS:
            self.editor.tag_remove(tag, "1.0", "end")
        for tag, start, end in syntax_spans(self.editor.get("1.0", "end-1c")):
            self.editor.tag_add(tag, start, end)

    def choose_import_folder(self):
        folder = filedialog.askdirectory(parent=self, initialdir=self.import_folder or self.folder)
        if folder:
            self.import_folder = Path(folder)
            self.import_info.set(f"Extra import folder: {self.import_folder.name}")

    def load_example(self, source):
        if self.process is None and self.confirm_discard():
            self.replace_source(source, None)

    def replace_source(self, source, path):
        self.path, self.saved_text = path, source
        self.filename.set(path.name if path else "Untitled.py")
        self.editor.delete("1.0", "end")
        self.editor.insert("1.0", source)
        self.editor.edit_reset()
        if self.highlight_job is not None:
            self.after_cancel(self.highlight_job)
        self.highlight()

    def confirm_discard(self):
        return self.editor.get("1.0", "end-1c") == self.saved_text or messagebox.askyesno(
            "Unsaved changes", "Discard changes to the script?", parent=self)

    def open(self):
        if self.process is not None or not self.confirm_discard():
            return
        name = filedialog.askopenfilename(parent=self, initialdir=self.folder,
                                         filetypes=[("Python scripts", "*.py")])
        if not name:
            return
        self.open_path(Path(name))

    def open_path(self, path):
        try:
            path = experiment_script_path(path)
            source = path.read_text(encoding="utf-8-sig")
        except (OSError, ValueError, RuntimeError) as error:
            messagebox.showerror("Open script", str(error), parent=self)
            return
        self.replace_source(source, path)
        if path.parent != self.folder:
            self.refresh_files(path.parent)
        self.editor.focus_set()

    def save(self):
        if self.process is not None:
            return False
        path = self.path
        if path is None:
            name = filedialog.asksaveasfilename(parent=self, initialdir=self.folder,
                                               defaultextension=".py",
                                               filetypes=[("Python scripts", "*.py")])
            if not name:
                return False
            path = Path(name)
        source = self.editor.get("1.0", "end-1c")
        try:
            path = experiment_script_path(path)
            path.write_text(source, encoding="utf-8")
        except (OSError, ValueError, RuntimeError) as error:
            messagebox.showerror("Save script", str(error), parent=self)
            return False
        self.path, self.saved_text = path, source
        self.filename.set(path.name)
        self.refresh_files(path.parent)
        return True

    def run(self):
        if self.bench_busy() or self.process is not None:
            self.append("Wait for the active bench operation or script to finish.\n")
            return
        if not self.save():
            return
        try:
            snapshot = self.transmit_snapshot() if self.transmit_snapshot else None
            self.process = launch_script(self.path, self.import_folder, snapshot)
        except (OSError, ValueError) as error:
            self.append(f"Could not start Python: {error}\n")
            return
        self.append(f"\nRunning {self.path.name}\n")
        self.stopped = False
        self.operation_status("active", self.path.name)
        threading.Thread(target=self.read_output, args=(self.process,), daemon=True).start()
        self.after(75, self.poll)

    def read_output(self, process):
        with process.stdout:
            for line in process.stdout:
                self.events.put(line)
        self.events.put(process.wait())

    def poll(self):
        for _ in range(100):
            try:
                event = self.events.get_nowait()
            except queue.Empty:
                break
            if isinstance(event, int):
                self.process = None
                self.append(f"[Python exited with code {event}]\n")
                state = "cancelled" if self.stopped else "error" if event else "done"
                self.operation_status(state, str(event))
                return
            self.append(event)
        self.after(75, self.poll)

    def stop(self):
        if self.process is not None and self.process.poll() is None:
            try:
                self.process.terminate()
                self.stopped = True
                self.operation_status("cancelling", "Python script")
                self.append("Stopping Python. Check hardware state before continuing.\n")
            except OSError as error:
                self.append(f"Could not stop Python: {error}\n")

    def append(self, text):
        self.console.configure(state="normal")
        self.console.insert("end", text)
        self.console.see("end")
        self.console.configure(state="disabled")
