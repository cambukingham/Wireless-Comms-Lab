"""Editable Markdown notes and bench context snapshots."""

import json
import tkinter as tk
from datetime import datetime
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from research_files import write_text_atomic
from run_bundle import export_bundle, new_run_id, verify_bundle

NOTES_TYPES = [("Markdown notes", "*.md"), ("Plain text", "*.txt")]
BUNDLE_TYPES = [("WINLAB run bundle", "*.zip")]
TEMPLATE = """# Experiment notes

## Question

## Procedure

## Observations and files

## Next run

"""


class ResearchNotes(ttk.Frame):
    def __init__(self, parent, get_context, get_script):
        super().__init__(parent, padding=10)
        self.get_context = get_context
        self.get_script = get_script
        self.attachments = []
        self.path = None
        self.saved = TEMPLATE
        self.columnconfigure(0, weight=1)
        self.rowconfigure(1, weight=1)
        controls = ttk.Frame(self)
        controls.grid(row=0, column=0, columnspan=2, sticky="ew", pady=(0, 6))
        for label, command in (("New", self.new), ("Open…", self.open), ("Save", self.save),
                               ("Save as…", lambda: self.save(save_as=True)),
                               ("Insert bench snapshot", self.insert_context)):
            ttk.Button(controls, text=label, command=command).pack(side="left", padx=(0, 4))
        run_menu_button = ttk.Menubutton(controls, text="Run bundle…")
        menu = tk.Menu(run_menu_button, tearoff=False)
        for label, command in (("Add calibration files…", lambda: self.attach("calibration")),
                               ("Add supporting files…", lambda: self.attach("supporting_file")),
                               ("Clear attachments", self.clear_attachments),
                               ("Export run bundle…", self.export_run), ("Verify run bundle…", self.verify_run)):
            menu.add_command(label=label, command=command)
        run_menu_button.configure(menu=menu)
        run_menu_button.pack(side="left")
        self.attachment_label = tk.StringVar(value="0 attachments")
        ttk.Label(controls, textvariable=self.attachment_label).pack(side="left", padx=6)
        self.editor = tk.Text(self, wrap="word", undo=True, font="TkFixedFont", padx=8, pady=8)
        self.editor.grid(row=1, column=0, sticky="nsew")
        scroll = ttk.Scrollbar(self, orient="vertical", command=self.editor.yview)
        scroll.grid(row=1, column=1, sticky="ns")
        self.editor.configure(yscrollcommand=scroll.set)
        self.editor.insert("1.0", TEMPLATE)
        self.editor.edit_reset()
        self.status = tk.StringVar(value="Untitled notes")
        ttk.Label(self, textvariable=self.status).grid(row=2, column=0, sticky="w", pady=(5, 0))
        self.editor.bind("<Control-s>", self.save_shortcut)

    def text(self):
        return self.editor.get("1.0", "end-1c")

    def confirm_leave(self):
        if self.text() == self.saved:
            return True
        answer = messagebox.askyesnocancel("Research notes", "Save changes to the notes?", parent=self)
        return answer is False or (answer is True and self.save())

    def replace(self, text, path):
        self.editor.delete("1.0", "end")
        self.editor.insert("1.0", text)
        self.editor.edit_reset()
        self.path, self.saved = path, text
        self.status.set(str(path) if path else "Untitled notes")

    def new(self):
        if self.confirm_leave():
            self.replace(TEMPLATE, None)

    def open(self):
        if not self.confirm_leave():
            return
        name = filedialog.askopenfilename(parent=self, filetypes=NOTES_TYPES, title="Open research notes")
        if name:
            path = Path(name)
            try:
                self.replace(path.read_text(encoding="utf-8-sig"), path)
            except (OSError, UnicodeError) as error:
                self.status.set(f"Could not open notes: {error}")

    def save(self, *, save_as=False):
        path = self.path
        if path is None or save_as:
            name = filedialog.asksaveasfilename(parent=self, filetypes=NOTES_TYPES, defaultextension=".md",
                                               initialfile="experiment-notes.md", title="Save research notes")
            if not name:
                return False
            path = Path(name)
        text = self.text()
        try:
            write_text_atomic(path, text)
        except OSError as error:
            self.status.set(f"Could not save notes: {error}")
            return False
        self.path, self.saved = path, text
        self.status.set(f"Saved {path}")
        return True

    def save_shortcut(self, _event):
        self.save()
        return "break"

    def insert_context(self):
        timestamp = datetime.now().astimezone().isoformat(timespec="seconds")
        context = json.dumps(self.get_context(), indent=2, ensure_ascii=False, allow_nan=False)
        self.editor.insert("end-1c", f"\n\n### Bench snapshot {timestamp}\n\n```json\n{context}\n```\n")
        self.editor.see("end")
        self.status.set("Snapshot inserted. Save the notes to keep it.")

    def attach(self, role):
        paths = filedialog.askopenfilenames(parent=self, title="Select files for the run bundle")
        existing = {path for _, path in self.attachments}
        for name in paths:
            path = Path(name).resolve()
            if path not in existing:
                self.attachments.append((role, path))
                existing.add(path)
        self.attachment_label.set(f"{len(self.attachments)} attachments")
        if paths:
            self.status.set(f"Selected for bundle: {', '.join(Path(name).name for name in paths)}")

    def clear_attachments(self):
        self.attachments.clear()
        self.attachment_label.set("0 attachments")
        self.status.set("Attachment selection cleared.")

    def export_run(self):
        run_id = new_run_id()
        path = filedialog.asksaveasfilename(parent=self, title="Export run bundle", filetypes=BUNDLE_TYPES,
                                            defaultextension=".zip", initialfile=f"{run_id}.zip")
        if not path:
            return
        try:
            manifest = export_bundle(path, run_id, context=self.get_context(), notes=self.text(),
                                     script=self.get_script(), attachments=self.attachments)
        except (OSError, ValueError) as error:
            self.status.set(f"Could not export bundle: {error}")
            return
        self.status.set(f"Saved {Path(path).name} | {manifest['run_id']} | {len(manifest['files'])} verified files")

    def verify_run(self):
        path = filedialog.askopenfilename(parent=self, title="Verify run bundle", filetypes=BUNDLE_TYPES)
        if not path:
            return
        try:
            manifest = verify_bundle(path)
        except (OSError, ValueError) as error:
            self.status.set(f"Bundle verification failed: {error}")
            return
        self.status.set(f"Verified {manifest['run_id']} | {len(manifest['files'])} files")
