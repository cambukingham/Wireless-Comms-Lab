"""Interactive waveform and spectrum views for the bench."""

from bisect import bisect_left, bisect_right
import math
import tkinter as tk
from tkinter import ttk

from baseband import bit_level, validate_bits
from duc import BASEBAND_HZ, BASEBAND_RATE, DAC_RATE, baseband_i
from waveforms import SAMPLE_RATE, delay_record, delay_samples, generate


def direct_trace(shape, frequency, vpp, duty, falling, *, delay_ns=0):
    if not 0.1 <= vpp <= 0.5:
        raise ValueError("Use 0.1 to 0.5 Vpp.")
    values, _, _ = generate(shape, frequency, duty, falling)
    values = delay_record(values, delay_samples(delay_ns, SAMPLE_RATE))
    last = min(len(values) - 1, math.ceil(2 * SAMPLE_RATE / frequency))
    # Retain source samples; reduce only the visible region when drawing.
    trace = [(index / SAMPLE_RATE, values[index] * vpp / 2) for index in range(last + 1)]
    return trace, vpp / 2, "Voltage (V)"


def duc_trace(pattern, carrier_hz, voltage, *, bits="10100110", symbol_rate=2.5e6,
              delay_ns=0, phase_deg=0):
    if not 20e6 <= carrier_hz <= 200e6 or not 0.1 <= voltage <= 0.5:
        raise ValueError("Use a 20–200 MHz carrier and 0.1–0.5 Vpp setting.")
    if not math.isfinite(phase_deg):
        raise ValueError("Enter a finite NCO phase in degrees.")
    shift = delay_samples(delay_ns, BASEBAND_RATE) / BASEBAND_RATE
    phase = math.radians(phase_deg % 360)
    if pattern == "bpsk":
        return bit_trace(bits, symbol_rate, shift, 0.5, "BPSK baseband I (relative)")
    duration = 2 / (carrier_hz if pattern == "carrier" else BASEBAND_HZ)
    count = math.ceil(duration * DAC_RATE)
    trace = []
    for index in range(count + 1):
        t = index / DAC_RATE
        trace.append((t, baseband_i(pattern, t - shift) * math.cos(math.tau * carrier_hz * t + phase)))
    return trace, 0.5, "Relative amplitude"


def bit_trace(bits, symbol_rate, shift, amplitude, label):
    bits = validate_bits(bits, symbol_rate)
    trace = []
    count = min(len(bits), 16)
    first = math.floor(-shift * symbol_rate)
    for index in range(first, first + count + 1):
        begin = max(0, index / symbol_rate + shift)
        end = min(count / symbol_rate, (index + 1) / symbol_rate + shift)
        if end > begin:
            value = amplitude * bit_level(bits[index % len(bits)])
            trace.extend(((begin, value), (end, value)))
    return trace, amplitude, f"{label} · {count} symbol intervals"


def nrz_trace(bits, symbol_rate, vpp, delay_ns):
    if not 0.1 <= vpp <= 0.5:
        raise ValueError("Use 0.1 to 0.5 Vpp.")
    shift = delay_samples(delay_ns, SAMPLE_RATE) / SAMPLE_RATE
    return bit_trace(bits, symbol_rate, shift, vpp / 2, "Bipolar NRZ (V)")


class PlotView:
    """Numeric viewport, constrained to the original data axes."""

    def __init__(self, bounds):
        self.full = tuple(bounds)
        self.bounds = self.full

    def reset(self):
        self.bounds = self.full

    def set_bounds(self, bounds):
        result = []
        for start, end, low, high in ((bounds[0], bounds[1], self.full[0], self.full[1]),
                                       (bounds[2], bounds[3], self.full[2], self.full[3])):
            span = min(high - low, max((high - low) * 1e-8, end - start))
            start = max(low, min(start, high - span))
            result.extend((start, start + span))
        self.bounds = tuple(result)

    def zoom(self, factor, *, x=None, y=None, axes="x"):
        x0, x1, y0, y1 = self.bounds
        x = (x0 + x1) / 2 if x is None else x
        y = (y0 + y1) / 2 if y is None else y
        self.set_bounds((x + (x0 - x) * factor if "x" in axes else x0,
                         x + (x1 - x) * factor if "x" in axes else x1,
                         y + (y0 - y) * factor if "y" in axes else y0,
                         y + (y1 - y) * factor if "y" in axes else y1))

    def pan(self, dx, dy):
        x0, x1, y0, y1 = self.bounds
        self.set_bounds((x0 + dx, x1 + dx, y0 + dy, y1 + dy))


def clip_segment(x0, y0, x1, y1, bounds):
    """Clip a line to the viewport so it cannot overwrite axes and labels."""
    xmin, xmax, ymin, ymax = bounds
    dx, dy = x1 - x0, y1 - y0
    enter, leave = 0.0, 1.0
    for p, q in ((-dx, x0 - xmin), (dx, xmax - x0), (-dy, y0 - ymin), (dy, ymax - y0)):
        if p == 0:
            if q < 0:
                return None
        elif p < 0:
            enter = max(enter, q / p)
        else:
            leave = min(leave, q / p)
        if enter > leave:
            return None
    return x0 + enter * dx, y0 + enter * dy, x0 + leave * dx, y0 + leave * dy


class SignalPreview(tk.Canvas):
    def __init__(self, parent):
        super().__init__(parent, background="white", height=220, highlightthickness=0, takefocus=True)
        self.trace = None
        self.message = ""
        self.axes = None
        self.overlays = []
        self.viewport = None
        self._xs = []
        self._drag = None
        self.bind("<Configure>", self.redraw)
        self.bind("<MouseWheel>", self._wheel)
        self.bind("<Button-4>", lambda event: self._wheel(event, 1))
        self.bind("<Button-5>", lambda event: self._wheel(event, -1))
        self.bind("<ButtonPress-1>", self._pan_start)
        self.bind("<B1-Motion>", self._pan_move)
        self.bind("<ButtonRelease-1>", self._pan_end)
        self.bind("<Double-Button-1>", lambda _: self.reset_view())
        self.bind("<Home>", lambda _: self.reset_view())
        self.bind("<Key-plus>", lambda _: self.zoom(0.5))
        self.bind("<Key-equal>", lambda _: self.zoom(0.5))
        self.bind("<Key-minus>", lambda _: self.zoom(2))

    def toolbar(self, parent):
        bar = ttk.Frame(parent)
        buttons = ttk.Frame(bar)
        buttons.pack(anchor="w")
        for text, command in (("Zoom X +", lambda: self.zoom(0.5)),
                              ("Zoom X −", lambda: self.zoom(2)),
                              ("Fit Y", self.fit_y), ("Reset view", self.reset_view)):
            ttk.Button(buttons, text=text, command=command).pack(side="left", padx=(0, 4))
        hint = ttk.Label(bar, text="Wheel: zoom X · Shift+wheel: zoom Y · Drag: pan · Double-click: reset",
                         wraplength=540)
        hint.pack(fill="x", pady=(2, 0))
        bar.bind("<Configure>", lambda event: hint.configure(wraplength=max(180, event.width - 8)))
        return bar

    def show(self, trace=None, message="", *, axes=None, preserve_view=False, overlays=None):
        previous = self.viewport if preserve_view else None
        self.trace = trace
        self.message = message
        self.axes = axes
        self.overlays = overlays or []
        self._drag = None
        self.configure(cursor="")
        if trace is not None and trace[0]:
            points, limit, _ = trace
            self._xs = [point[0] for point in points]
            first, last = self._xs[0], self._xs[-1]
            if last <= first:
                last = first + 1e-9
            low, high = axes[2:] if axes else (-limit, limit)
            self.viewport = PlotView((first, last, low, high))
            if previous is not None and previous.full == self.viewport.full:
                self.viewport.set_bounds(previous.bounds)
        else:
            self._xs = []
            self.viewport = None
        self.redraw()

    def _plot_box(self):
        return 66, self.winfo_width() - 24, 28, self.winfo_height() - 47

    def _data_position(self, event):
        left, right, top, bottom = self._plot_box()
        if not self.viewport or right <= left or bottom <= top:
            return None
        x0, x1, y0, y1 = self.viewport.bounds
        fx = max(0, min(1, (event.x - left) / (right - left)))
        fy = max(0, min(1, (event.y - top) / (bottom - top)))
        return x0 + fx * (x1 - x0), y1 - fy * (y1 - y0)

    def zoom(self, factor):
        if self.viewport:
            self.viewport.zoom(factor)
            self.redraw()

    def reset_view(self):
        if self.viewport:
            self.viewport.reset()
            self.redraw()

    def _visible_points(self, points=None):
        first, last, _, _ = self.viewport.bounds
        points = self.trace[0] if points is None else points
        xs = self._xs if points is self.trace[0] else [point[0] for point in points]
        begin = max(0, bisect_left(xs, first) - 1)
        end = min(len(xs), bisect_right(xs, last) + 1)
        return points[begin:end]

    def fit_y(self):
        if not self.viewport:
            return
        x0, x1, _, _ = self.viewport.bounds
        values = [value for t, value in self._visible_points() if x0 <= t <= x1]
        for _, points, _ in self.overlays:
            values.extend(value for t, value in self._visible_points(points) if x0 <= t <= x1)
        if not values:
            return
        low, high = min(values), max(values)
        margin = max((high - low) * 0.08, (self.viewport.full[3] - self.viewport.full[2]) * 1e-5)
        self.viewport.set_bounds((x0, x1, low - margin, high + margin))
        self.redraw()

    def _wheel(self, event, direction=None):
        position = self._data_position(event)
        if position is None:
            return "break"
        direction = direction if direction is not None else event.delta
        if direction:
            self.viewport.zoom(0.8 if direction > 0 else 1.25, x=position[0], y=position[1],
                               axes="y" if event.state & 1 else "x")
            self.redraw()
        return "break"

    def _pan_start(self, event):
        if self._data_position(event) is not None:
            self.focus_set()
            self._drag = event.x, event.y, self.viewport.bounds
            self.configure(cursor="fleur")

    def _pan_move(self, event):
        if self._drag is None:
            return
        x, y, bounds = self._drag
        left, right, top, bottom = self._plot_box()
        if right <= left or bottom <= top:
            return
        x0, x1, y0, y1 = bounds
        dx = -(event.x - x) * (x1 - x0) / (right - left)
        dy = (event.y - y) * (y1 - y0) / (bottom - top)
        self.viewport.set_bounds((x0 + dx, x1 + dx, y0 + dy, y1 + dy))
        self.redraw()

    def _pan_end(self, _event):
        self._drag = None
        self.configure(cursor="")

    def redraw(self, _event=None):
        self.delete("all")
        width, height = self.winfo_width(), self.winfo_height()
        if width < 220 or height < 115:
            return
        if self.trace is None or self.viewport is None:
            self.create_text(12, 12, text=self.message, anchor="nw", width=width - 24)
            return
        _, _, units = self.trace
        left, right, top, bottom = self._plot_box()
        first, last, low, high = self.viewport.bounds
        span = last - first
        if self.axes is None:
            scale, time_units = (1e6, "µs") if span >= 1e-6 else (1e9, "ns")
            x_label = f"Time ({time_units})"
        else:
            scale, x_label, _, _ = self.axes
        self.create_text(left, 9, text=units, anchor="nw")
        for tick in range(5):
            x = left + (right - left) * tick / 4
            self.create_line(x, top, x, bottom, fill="#e0e0e0")
            self.create_text(x, bottom + 12, text=f"{(first + span * tick / 4) * scale:.6g}")
        for tick, label in enumerate((f"{high:.4g}", f"{(low + high) / 2:.4g}", f"{low:.4g}")):
            y = top + (bottom - top) * tick / 2
            self.create_line(left, y, right, y, fill="#c9c9c9")
            self.create_text(left - 6, y, text=label, anchor="e")
        self.create_text((left + right) / 2, height - 10, text=x_label)
        self._draw_points(self._visible_points(), "#174b9c")
        for _, points, color in self.overlays:
            self._draw_points(self._visible_points(points), color)

    def _draw_points(self, points, color):
        left, right, top, bottom = self._plot_box()
        first, last, low, high = self.viewport.bounds
        span = last - first
        stride = max(1, math.ceil(len(points) / max(1, right - left)))
        reduced = []
        for start in range(0, len(points), stride):
            block = range(start, min(start + stride, len(points)))
            indices = {start, min(start + stride, len(points)) - 1,
                       min(block, key=lambda index: points[index][1]),
                       max(block, key=lambda index: points[index][1])}
            reduced.extend(points[index] for index in sorted(indices))
        path = []

        def flush():
            if len(path) >= 4:
                self.create_line(*path, fill=color, width=2, tags="signal")
            path.clear()

        def pixel(t, value):
            return (left + (right - left) * (t - first) / span,
                    top + (bottom - top) * (high - value) / (high - low))

        for (t0, v0), (t1, v1) in zip(reduced, reduced[1:]):
            clipped = clip_segment(t0, v0, t1, v1, self.viewport.bounds)
            if clipped is None:
                flush()
                continue
            a, b = pixel(*clipped[:2]), pixel(*clipped[2:])
            if path and (abs(path[-2] - a[0]) > 1e-6 or abs(path[-1] - a[1]) > 1e-6):
                flush()
            if not path:
                path.extend(a)
            path.extend(b)
        flush()
