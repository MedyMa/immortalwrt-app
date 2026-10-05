"""Preview regressions runnable on every host without Flutter or a simulator."""
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zlib

TOOLS = Path(__file__).resolve().parent


def load(name):
    spec = importlib.util.spec_from_file_location(name, TOOLS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


prepare = load("prepare-ios-preview")
render = load("render-ios-preview")


def png(path, pixel, method=0):
    width = height = 128
    rows, previous = [], bytearray(width * 3)
    for y in range(height):
        row = bytearray(value for x in range(width) for value in pixel(x, y))
        encoded = bytearray(len(row))
        for i, value in enumerate(row):
            left = row[i - 3] if i >= 3 else 0
            up = previous[i]
            upper = previous[i - 3] if i >= 3 else 0
            predictors = (0, left, up, (left + up) // 2)
            if method == 4:
                p = left + up - upper
                distances = (abs(p - left), abs(p - up), abs(p - upper))
                predictor = (left, up, upper)[distances.index(min(distances))]
            else:
                predictor = predictors[method]
            encoded[i] = (value - predictor) & 255
        rows.append(bytes([method]) + encoded)
        previous = row
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" +
                     chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) +
                     chunk(b"IDAT", zlib.compress(b"".join(rows))) + chunk(b"IEND", b""))


class PreparationTests(unittest.TestCase):
    def fixture(self, directory):
        root = Path(directory)
        for relative in ("lib/main.dart", "ios/Runner/AppDelegate.swift", "tools/ios_preview_fixture.dart"):
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text((TOOLS.parent / relative).read_text(encoding="utf-8"), encoding="utf-8")
        return root

    def test_current_sources_prepare_twice_identically(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            prepare.prepare(root)
            paths = list(root.rglob("*.*"))
            first = {p: p.read_bytes() for p in paths}
            prepare.prepare(root)
            self.assertEqual(first, {p: p.read_bytes() for p in paths})
            dart = (root / "lib/main.dart").read_text(encoding="utf-8")
            self.assertEqual(dart.count("Future<void> _loadPreview()"), 1)
            self.assertIn("await WidgetsBinding.instance.endOfFrame", dart)
            self.assertIn("'nonce': config['nonce']", dart)
            self.assertIn("if (tab == 4)", dart)
            self.assertIn("_showDeviceDetails(context, row,", dart)
            self.assertIn("if (tab == 5)", dart)
            self.assertIn("scroll!.position.jumpTo", dart)
            self.assertIn("if (tab == 6)", dart)
            self.assertIn("_showConnection();", dart)

    def test_missing_swift_anchor_fails_before_any_writes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            swift = root / "ios/Runner/AppDelegate.swift"
            swift.write_text("unexpected structure", encoding="utf-8")
            first = (root / "lib/main.dart").read_bytes()
            with self.assertRaisesRegex(ValueError, "channel-property"):
                prepare.prepare(root)
            self.assertEqual(first, (root / "lib/main.dart").read_bytes())
            self.assertFalse((root / "lib/ios_preview_fixture.dart").exists())

    def test_duplicate_anchor_rejected(self):
        with self.assertRaises(ValueError):
            prepare.replace_once("anchor anchor", "anchor", "new", "sample")

    def test_anchor_drift_after_injection_rejected(self):
        source = prepare.inject("anchor", "anchor", "body", "test")
        with self.assertRaisesRegex(ValueError, "anchor"):
            prepare.inject(source.replace("anchor", "renamed"), "anchor", "body", "test")

    def test_partial_or_modified_injection_rejected(self):
        source = prepare.inject("anchor", "anchor", "body", "test")
        for broken in (source.replace("body", "edited"), source.replace("// IOS_PREVIEW_END test", "")):
            with self.assertRaises(ValueError):
                prepare.inject(broken, "anchor", "body", "test")


class ReadinessTests(unittest.TestCase):
    def test_ready_requires_matching_nonce_tab_and_appearance(self):
        expected = dict(nonce="fresh", tab=2, appearance="dark")
        marker = unittest.mock.Mock()
        marker.read_text.side_effect = [FileNotFoundError(), "{", json.dumps(dict(expected, nonce="stale")),
                                       json.dumps(dict(expected, tab=1)), json.dumps(dict(expected, appearance="light")),
                                       json.dumps(expected)]
        with patch.object(render.time, "monotonic", return_value=0), patch.object(render.time, "sleep"):
            render.wait_ready(marker, expected, 1)
        self.assertEqual(marker.read_text.call_count, 6)

    def test_missing_readiness_times_out(self):
        marker = unittest.mock.Mock()
        marker.read_text.side_effect = FileNotFoundError()
        with patch.object(render.time, "monotonic", side_effect=[0, 0, 2]), patch.object(render.time, "sleep"):
            with self.assertRaisesRegex(TimeoutError, "acknowledge"):
                render.wait_ready(marker, {}, 1)

    def test_command_timeout_capped_to_remaining_deadline(self):
        with patch.object(render.time, "monotonic", return_value=95), patch.object(render.subprocess, "run") as call:
            render.run(["launch"], timeout=120, deadline=100)
        self.assertEqual(call.call_args.kwargs["timeout"], 5)

    def test_expired_budget_prevents_command(self):
        with patch.object(render.time, "monotonic", return_value=100), patch.object(render.subprocess, "run") as call:
            with self.assertRaises(TimeoutError):
                render.run(["launch"], deadline=100)
            call.assert_not_called()


class ScreenshotTests(unittest.TestCase):
    def test_black_blank_and_status_bar_only_rejected(self):
        for pixel in (lambda x, y: (0, 0, 0), lambda x, y: (255, 255, 255),
                      lambda x, y: (255, 255, 255) if y < 10 else (0, 0, 0)):
            with self.subTest(pixel=pixel), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "image.png"
                png(path, pixel)
                with self.assertRaisesRegex(ValueError, "black or blank"):
                    render.validate_screenshot(path)

    def test_real_content_accepted_for_each_png_filter(self):
        for method in range(5):
            with self.subTest(filter=method), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "image.png"
                png(path, lambda x, y: (20, 20, 20) if x < 64 else (180, 180, 180), method)
                render.validate_screenshot(path)

    def test_invalid_png_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "image.png"
            path.write_bytes(b"bad image")
            with self.assertRaises(ValueError):
                render.validate_screenshot(path)


class RenderTests(unittest.TestCase):
    def simulated(self, directory, failure=None):
        calls = []
        state = {}
        container = Path(directory) / "container"
        (container / "Documents").mkdir(parents=True)
        def fake(args, **kwargs):
            calls.append(args)
            action = args[2]
            if action == "list":
                data = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-27-0":
                                    [{"name": "iPhone 17", "udid": "template"}]}}
                return subprocess.CompletedProcess(args, 0, json.dumps(data).encode())
            if action == "clone":
                return subprocess.CompletedProcess(args, 0, b"isolated-device\n")
            if action == "boot" and failure == "startup":
                raise subprocess.TimeoutExpired(args, 60)
            if action == "get_app_container":
                return subprocess.CompletedProcess(args, 0, str(container).encode())
            if action == "launch":
                if failure == "launch":
                    raise subprocess.TimeoutExpired(args, 20)
                env = kwargs["env"]
                state.update(nonce=env["SIMCTL_CHILD_IOS_PREVIEW_NONCE"],
                             tab=int(env["SIMCTL_CHILD_IOS_PREVIEW_TAB"]),
                             appearance=env["SIMCTL_CHILD_IOS_PREVIEW_APPEARANCE"])
                (container / "Documents/ios-preview-ready.json").write_text(json.dumps(state), encoding="utf-8")
            if action == "io":
                png(Path(args[-1]), lambda x, y: (0, 0, 0) if failure == "black" else
                    ((20, 20, 20) if x < 64 else (180, 180, 180)))
            return subprocess.CompletedProcess(args, 0)
        return fake, calls

    def test_pages_and_device_sheet_acknowledged_captured_and_cleaned(self):
        with tempfile.TemporaryDirectory() as directory:
            fake, calls = self.simulated(directory)
            out = Path(directory) / "out"
            with patch.object(render, "run", side_effect=fake):
                render.render(out)
            self.assertEqual(len(list(out.glob("ios-*.png"))), 14)
            self.assertEqual(len([c for c in calls if c[2] == "launch"]), 14)
            self.assertTrue((out / "ios-light-5.png").exists())
            self.assertTrue((out / "ios-dark-5.png").exists())
            self.assertTrue((out / "ios-light-6.png").exists())
            self.assertTrue((out / "ios-dark-6.png").exists())
            self.assertEqual([c[2] for c in calls[-2:]], ["shutdown", "delete"])

    def test_launch_timeout_never_captures_and_cleans_simulator(self):
        with tempfile.TemporaryDirectory() as directory:
            fake, calls = self.simulated(directory, "launch")
            with patch.object(render, "run", side_effect=fake), patch.object(render, "wait_ready") as ready:
                with self.assertRaises(subprocess.TimeoutExpired):
                    render.render(Path(directory) / "out")
            ready.assert_not_called()
            self.assertFalse(any(c[2] == "io" for c in calls))
            self.assertEqual([c[2] for c in calls[-2:]], ["shutdown", "delete"])

    def test_slow_screenshot_has_budget_but_keeps_page_deadline(self):
        with tempfile.TemporaryDirectory() as directory:
            fake, calls = self.simulated(directory)
            screenshots = []
            def slow_capture(args, **kwargs):
                if args[2] == "io":
                    screenshots.append(kwargs)
                    if kwargs['timeout'] < 30:
                        raise subprocess.TimeoutExpired(args, kwargs['timeout'])
                return fake(args, **kwargs)
            with patch.object(render, "run", side_effect=slow_capture):
                render.render(Path(directory) / "out")
            self.assertEqual(len(screenshots), 14)
            self.assertTrue(all('deadline' in s for s in screenshots))
            self.assertEqual([c[2] for c in calls[-2:]], ["shutdown", "delete"])

    def test_startup_timeout_stops_before_install_and_cleans_simulator(self):
        with tempfile.TemporaryDirectory() as directory:
            fake, calls = self.simulated(directory, "startup")
            with patch.object(render, "run", side_effect=fake):
                with self.assertRaises(subprocess.TimeoutExpired):
                    render.render(Path(directory) / "out")
            self.assertFalse(any(c[2] in ("install", "launch", "io") for c in calls))
            self.assertEqual([c[2] for c in calls[-2:]], ["shutdown", "delete"])

    def test_install_timeout_rechecks_readiness_and_retries_once(self):
        with tempfile.TemporaryDirectory() as directory:
            fake, calls = self.simulated(directory)
            installs = []
            def slow_install(args, **kwargs):
                if args[2] == "install":
                    installs.append(kwargs)
                    if len(installs) == 1:
                        calls.append(args)
                        raise subprocess.TimeoutExpired(args, kwargs["timeout"])
                return fake(args, **kwargs)
            out = Path(directory) / "out"
            with patch.object(render, "run", side_effect=slow_install):
                render.render(out)
            self.assertEqual(len(installs), 2)
            self.assertEqual(installs[0]["timeout"], 120)
            self.assertEqual(len([c for c in calls if c[2] == "bootstatus"]), 2)
            self.assertEqual(len(list(out.glob("ios-*.png"))), 14)

    def test_cold_container_lookup_has_startup_budget(self):
        with tempfile.TemporaryDirectory() as directory:
            fake, calls = self.simulated(directory)
            timeouts = []
            def cold_container(args, **kwargs):
                if args[2] == "get_app_container":
                    timeouts.append(kwargs.get("timeout", 60))
                    if timeouts[-1] < 90:
                        raise subprocess.TimeoutExpired(args, timeouts[-1])
                return fake(args, **kwargs)
            with patch.object(render, "run", side_effect=cold_container):
                render.render(Path(directory) / "out")
            self.assertEqual(timeouts, [120])

    def test_first_launch_can_warm_engine_but_later_launches_stay_short(self):
        with tempfile.TemporaryDirectory() as directory:
            fake, calls = self.simulated(directory)
            timeouts = []
            def cold_launch(args, **kwargs):
                if args[2] == "launch":
                    timeouts.append(kwargs["timeout"])
                    if len(timeouts) == 1 and timeouts[-1] < 45:
                        raise subprocess.TimeoutExpired(args, timeouts[-1])
                return fake(args, **kwargs)
            with patch.object(render, "run", side_effect=cold_launch):
                render.render(Path(directory) / "out")
            self.assertEqual(timeouts, [60] + [20] * 13)

    def test_persistent_install_timeout_stops_before_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            fake, calls = self.simulated(directory)
            installs = []
            def failing_install(args, **kwargs):
                if args[2] == "install":
                    installs.append(kwargs); calls.append(args)
                    raise subprocess.TimeoutExpired(args, kwargs["timeout"])
                return fake(args, **kwargs)
            with patch.object(render, "run", side_effect=failing_install):
                with self.assertRaises(subprocess.TimeoutExpired):
                    render.render(Path(directory) / "out")
            self.assertEqual(len(installs), 2)
            self.assertEqual(installs[0]["deadline"], installs[1]["deadline"])
            self.assertFalse(any(c[2] in ("launch", "io") for c in calls))
            self.assertEqual([c[2] for c in calls[-2:]], ["shutdown", "delete"])

    def test_black_capture_not_published(self):
        with tempfile.TemporaryDirectory() as directory:
            fake, calls = self.simulated(directory, "black")
            out = Path(directory) / "out"
            with patch.object(render, "run", side_effect=fake):
                with self.assertRaisesRegex(ValueError, "black or blank"):
                    render.render(out)
            self.assertEqual(list(out.glob("*.png")), [])
            self.assertEqual([c[2] for c in calls[-2:]], ["shutdown", "delete"])

    def test_readiness_timeout_never_captures(self):
        with tempfile.TemporaryDirectory() as directory:
            fake, calls = self.simulated(directory)
            with patch.object(render, "run", side_effect=fake), patch.object(render, "wait_ready", side_effect=TimeoutError()):
                with self.assertRaises(TimeoutError):
                    render.render(Path(directory) / "out")
            self.assertFalse(any(c[2] == "io" for c in calls))
            self.assertEqual([c[2] for c in calls[-2:]], ["shutdown", "delete"])

    def test_no_compatible_simulator_reports_failure(self):
        result = subprocess.CompletedProcess([], 0, b'{"devices": {}}')
        with tempfile.TemporaryDirectory() as directory, patch.object(render, "run", return_value=result):
            with self.assertRaisesRegex(RuntimeError, "No available"):
                render.render(Path(directory) / "out")


if __name__ == "__main__":
    unittest.main(verbosity=2)
