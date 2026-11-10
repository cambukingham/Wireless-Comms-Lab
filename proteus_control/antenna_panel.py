"""Save and reopen passive antenna and RF-path profiles for an experiment."""

import math
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from research_files import load_artifact, save_artifact

PROFILE_TYPES = [("WINLAB antenna profile", "*.wlab.json"), ("JSON files", "*.json")]
FIELDS = (
    ("antenna", "Antenna model / asset ID"), ("port", "Instrument port"),
    ("frequency_mhz", "Reference frequency (MHz)"), ("polarization", "Polarization"),
    ("gain_dbi", "Antenna gain (dBi)"), ("cable_loss_db", "Cable loss (dB)"),
    ("pad_db", "Inline pad (dB)"), ("azimuth_deg", "Azimuth (deg)"),
    ("elevation_deg", "Elevation (deg)"),
)
NUMBERS = {
    "frequency_mhz": (0, None), "gain_dbi": (None, None), "cable_loss_db": (0, None),
    "pad_db": (0, None), "azimuth_deg": (0, 360), "elevation_deg": (-90, 90),
}


def normalize_path(values):
    result = {}
    for key, label in FIELDS:
        value = values.get(key)
        text = "" if value is None else str(value).strip()
        if key not in NUMBERS:
            result[key] = text
        elif not text:
            result[key] = None
        else:
            low, high = NUMBERS[key]
            try:
                number = float(text)
                if (not math.isfinite(number) or (low is not None and number < low)
                        or (high is not None and number > high) or (key == "frequency_mhz" and number == 0)):
                    raise ValueError
            except ValueError as error:
                raise ValueError(f"Check {label}.") from error
            result[key] = number % 360 if key == "azimuth_deg" else number
    return result


class AntennaPanel(ttk.Frame):
    def __init__(self, parent):
        super().__init__(parent, padding=10)
        self.path = None
        self.checksum = None
        self.name = tk.StringVar()
        self.entries = {}
        self.status = tk.StringVar(value="Untitled RF path profile")
        self.columnconfigure(0, weight=1)
        self.columnconfigure(1, weight=1)
        self.rowconfigure(2, weight=1)

        bar = ttk.Frame(self)
        bar.grid(row=0, column=0, columnspan=2, sticky="ew", pady=(0, 6))
        ttk.Label(bar, text="Profile name").pack(side="left")
        ttk.Entry(bar, textvariable=self.name, width=28).pack(side="left", padx=(4, 12))
        for label, command in (("New", self.new), ("Open…", self.open), ("Save", self.save),
                               ("Save as…", lambda: self.save(save_as=True))):
            ttk.Button(bar, text=label, command=command).pack(side="left", padx=(0, 4))

        for column, (role, title) in enumerate((("tx", "Transmit path"), ("rx", "Receive path"))):
            form = ttk.LabelFrame(self, text=title, padding=7)
            form.grid(row=1, column=column, sticky="nsew", padx=(0, 6) if column == 0 else (6, 0))
            form.columnconfigure(1, weight=1)
            fields = {}
            for row, (key, label) in enumerate(FIELDS):
                value = tk.StringVar()
                fields[key] = value
                ttk.Label(form, text=label).grid(row=row, column=0, sticky="w", padx=(0, 8), pady=2)
                ttk.Entry(form, textvariable=value, width=18).grid(row=row, column=1, sticky="ew", pady=2)
            self.entries[role] = fields

        detail = ttk.LabelFrame(self, text="Geometry, adapters and calibration notes", padding=5)
        detail.grid(row=2, column=0, columnspan=2, sticky="nsew", pady=(6, 0))
        self.notes = tk.Text(detail, height=3, wrap="word", undo=True)
        self.notes.pack(fill="both", expand=True)
        ttk.Label(self, textvariable=self.status, wraplength=750).grid(row=3, column=0, columnspan=2,
                                                                      sticky="w", pady=(5, 0))
        self.saved = self.draft()

    def draft(self):
        return dict(name=self.name.get(), notes=self.notes.get("1.0", "end-1c"), **{
            role: {key: value.get() for key, value in fields.items()}
            for role, fields in self.entries.items()
        })

    def snapshot(self):
        draft = self.draft()
        if draft == self.saved and self.path is not None:
            return {"file": str(self.path), "sha256": self.checksum, "profile": self.validate(draft)}
        return {"draft": draft}

    def validate(self, data):
        if not all(isinstance(data.get(key), dict) for key in ("tx", "rx")):
            raise ValueError("A profile needs transmit and receive path records.")
        name = data.get("name")
        notes = data.get("notes", "")
        if not isinstance(name, str) or not name.strip() or not isinstance(notes, str):
            raise ValueError("Enter a profile name.")
        return dict(name=name.strip(), notes=notes, tx=normalize_path(data["tx"]), rx=normalize_path(data["rx"]))

    def confirm_leave(self):
        if self.draft() == self.saved:
            return True
        answer = messagebox.askyesnocancel("Antenna profile", "Save changes to the RF path profile?", parent=self)
        return answer is False or (answer is True and self.save())

    def replace(self, profile, path=None, checksum=None):
        self.name.set(profile.get("name", ""))
        for role, fields in self.entries.items():
            for key, field in fields.items():
                value = profile.get(role, {}).get(key)
                field.set("" if value is None else value)
        self.notes.delete("1.0", "end")
        self.notes.insert("1.0", profile.get("notes", ""))
        self.notes.edit_reset()
        self.path, self.checksum = path, checksum
        self.saved = self.draft()
        self.status.set(f"{path.name} | SHA-256 {checksum[:16]}…" if path else "Untitled RF path profile")

    def new(self):
        if self.confirm_leave():
            self.replace({})

    def open(self):
        if not self.confirm_leave():
            return
        name = filedialog.askopenfilename(parent=self, filetypes=PROFILE_TYPES, title="Open antenna profile")
        if name:
            try:
                profile, _, checksum = load_artifact(name, "antenna_profile")
                self.replace(self.validate(profile), Path(name), checksum)
            except (OSError, ValueError) as error:
                self.status.set(f"Could not load profile: {error}")

    def save(self, *, save_as=False):
        try:
            profile = self.validate(self.draft())
        except ValueError as error:
            self.status.set(str(error))
            return False
        path = self.path
        if path is None or save_as:
            name = filedialog.asksaveasfilename(parent=self, filetypes=PROFILE_TYPES, defaultextension=".wlab.json",
                                               initialfile="antenna-profile.wlab.json", title="Save antenna profile")
            if not name:
                return False
            path = Path(name)
        try:
            checksum = save_artifact(path, "antenna_profile", profile)
        except (OSError, ValueError) as error:
            self.status.set(f"Could not save profile: {error}")
            return False
        self.replace(profile, path, checksum)
        return True
