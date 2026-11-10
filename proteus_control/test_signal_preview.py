"""Offline checks for zoom, panning, clipping and sample retention."""

import math
from types import SimpleNamespace
import tkinter as tk
import unittest
from unittest.mock import patch

from signal_preview import PlotView, SignalPreview, clip_segment


class PlotViewTests(unittest.TestCase):
    def test_zoom_keeps_pointer_anchor_and_pan_stays_in_data(self):
        view = PlotView((0, 10, -1, 1))
        view.zoom(.5, x=2)
        self.assertEqual(view.bounds, (1, 6, -1, 1))
        view.pan(100, 100)
        self.assertEqual(view.bounds, (5, 10, -1, 1))
        view.pan(-100, -100)
        self.assertEqual(view.bounds, (0, 5, -1, 1))
        view.zoom(100)
        self.assertEqual(view.bounds, view.full)

    def test_vertical_zoom_does_not_change_time_range(self):
        view = PlotView((-80, 80, -100, 0))
        view.zoom(.5, y=-25, axes="y")
        self.assertEqual(view.bounds, (-80, 80, -62.5, -12.5))
        view.reset()
        self.assertEqual(view.bounds, view.full)

    def test_clip_lines_crossing_plot_edges(self):
        bounds = (0, 10, -1, 1)
        self.assertEqual(clip_segment(-5, 0, 15, 0, bounds), (0, 0, 10, 0))
        self.assertEqual(clip_segment(5, -2, 5, 2, bounds), (5, -1, 5, 1))
        self.assertIsNone(clip_segment(0, 2, 10, 2, bounds))


class CanvasTests(unittest.TestCase):
    def setUp(self):
        self.root = tk.Tk()
        self.root.withdraw()
        self.graph = SignalPreview(self.root)
        self.patches = [patch.object(self.graph, "winfo_width", return_value=800),
                        patch.object(self.graph, "winfo_height", return_value=360)]
        for item in self.patches:
            item.start()

    def tearDown(self):
        for item in self.patches:
            item.stop()
        self.root.destroy()

    def test_zoom_recovers_every_original_sample(self):
        # The overview reduces 20,001 samples; narrow views retain every sample.
        points = [(n / 1000, .1 * math.sin(n)) for n in range(20001)]
        self.graph.show((points, 1, "I"))
        self.assertEqual(len(self.graph.trace[0]), len(points))
        self.graph.viewport.set_bounds((10, 10.01, -1, 1))
        self.graph.redraw()
        visible = self.graph._visible_points()
        self.assertGreaterEqual(len(visible), 11)
        self.assertLessEqual(len(visible), 14)
        self.graph.fit_y()
        x0, x1, low, high = self.graph.viewport.bounds
        self.assertAlmostEqual(x0, 10)
        self.assertAlmostEqual(x1, 10.01)
        self.assertLess(high - low, .25)
        self.assertTrue(self.graph.find_withtag("signal"))
        self.assert_clipped()

    def assert_clipped(self):
        left, right, top, bottom = self.graph._plot_box()
        for item in self.graph.find_withtag("signal"):
            coordinates = self.graph.coords(item)
            self.assertTrue(all(left - 1e-6 <= x <= right + 1e-6 for x in coordinates[::2]))
            self.assertTrue(all(top - 1e-6 <= y <= bottom + 1e-6 for y in coordinates[1::2]))

    def test_wheel_drag_and_reset_controls(self):
        self.graph.show(([(0, -.2), (5, .2), (10, -.2)], 1, "V"))
        event = SimpleNamespace(x=400, y=150, delta=120, state=0)
        self.graph._wheel(event)
        before = self.graph.viewport.bounds
        self.assertAlmostEqual(before[1] - before[0], 8)
        event.state = 1
        self.graph._wheel(event)
        self.assertLess(self.graph.viewport.bounds[3] - self.graph.viewport.bounds[2], 2)
        self.graph._pan_start(event)
        self.graph._pan_move(SimpleNamespace(x=440, y=170))
        self.assertNotEqual(self.graph.viewport.bounds[:2], before[:2])
        self.graph._pan_end(event)
        self.assertEqual(self.graph.cget("cursor"), "")
        self.graph.reset_view()
        self.assertEqual(self.graph.viewport.bounds, self.graph.viewport.full)
        self.assert_clipped()

    def test_iq_switch_preserves_view_and_new_axes_reset_it(self):
        self.graph.show(([(0, 0), (1, .2), (2, -.2)], 1, "I"))
        self.graph.zoom(.5)
        bounds = self.graph.viewport.bounds
        self.graph.show(([(0, .2), (1, 0), (2, -.2)], 1, "Q"), preserve_view=True)
        self.assertEqual(self.graph.viewport.bounds, bounds)
        self.graph.show(([(-1, -20), (0, 0), (1, -20)], 0, "dB"),
                        axes=(1, "MHz", -100, 0), preserve_view=True)
        self.assertEqual(self.graph.viewport.bounds, (-1, 1, -100, 0))
        self.graph.show()
        self.assertIsNone(self.graph.viewport)

    def test_overlay_colors_clipping_and_fit_y(self):
        self.graph.show(([(0, 0), (1, .1), (2, 0)], 1, "levels"),
                        overlays=[("received", [(0, 0), (1, .6), (2, 0)], "#cf5b12")])
        self.graph.fit_y()
        self.assertGreater(self.graph.viewport.bounds[3], .6)
        self.assertIn("#cf5b12", [self.graph.itemcget(item, "fill") for item in self.graph.find_withtag("signal")])
        self.graph.zoom(.25)
        self.assert_clipped()


if __name__ == "__main__":
    unittest.main()
