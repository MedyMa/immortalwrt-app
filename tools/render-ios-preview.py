"""Capture only acknowledged preview pages, within one bounded render deadline."""
import json
import os
from pathlib import Path
import struct
import subprocess
import time
import uuid
import zlib

BUNDLE = "com.medyma.immortalwrtApp"
RENDER_SECONDS = 540
PAGE_SECONDS = 40


def run(args, timeout=60, deadline=None, **kwargs):
    if deadline is not None:
        timeout = min(timeout, deadline - time.monotonic())
    if timeout <= 0:
        raise TimeoutError("iOS preview render deadline exceeded")
    print("Running:", " ".join(map(str, args)), flush=True)
    return subprocess.run(args, check=True, timeout=timeout, **kwargs)


def wait_ready(marker, expected, deadline):
    while time.monotonic() < deadline:
        try:
            value = json.loads(marker.read_text(encoding="utf-8"))
            if value == expected:
                return
        except (FileNotFoundError, json.JSONDecodeError):
            pass
        time.sleep(min(0.25, max(0, deadline - time.monotonic())))
    raise TimeoutError(f"Preview page did not acknowledge readiness: {expected}")


def validate_screenshot(path):
    """Decode simulator RGB/RGBA PNGs using stdlib; reject black/blank content."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Screenshot is not a PNG")
    offset, compressed, header = 8, bytearray(), None
    while offset < len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        if len(payload) != length or offset + 12 + length > len(data):
            raise ValueError("Truncated PNG")
        crc = struct.unpack_from(">I", data, offset + 8 + length)[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise ValueError("Invalid PNG checksum")
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            compressed.extend(payload)
        offset += 12 + length
        if kind == b"IEND":
            break
    if header is None:
        raise ValueError("Missing PNG header")
    width, height, depth, color, compression, filtering, interlace = header
    if depth != 8 or color not in (2, 6) or compression or filtering or interlace:
        raise ValueError(f"Unsupported simulator PNG format: {header}")
    if width < 100 or height < 100:
        raise ValueError("Screenshot dimensions are too small")
    channels = 3 if color == 2 else 4
    stride = width * channels
    raw = zlib.decompress(compressed)
    if len(raw) != (stride + 1) * height:
        raise ValueError("Invalid PNG pixel data")
    previous = bytearray(stride)
    minimum, maximum, bright, count = 255, 0, 0, 0
    # Exclude the status bar and navigation bar: they can render over black content.
    for y in range(height):
        start = y * (stride + 1)
        method = raw[start]
        row = bytearray(raw[start + 1:start + 1 + stride])
        if method > 4:
            raise ValueError("Invalid PNG filter")
        for i in range(stride):
            left = row[i - channels] if i >= channels else 0
            up = previous[i]
            upper_left = previous[i - channels] if i >= channels else 0
            if method == 1:
                predictor = left
            elif method == 2:
                predictor = up
            elif method == 3:
                predictor = (left + up) // 2
            elif method == 4:
                p = left + up - upper_left
                distances = (abs(p - left), abs(p - up), abs(p - upper_left))
                predictor = (left, up, upper_left)[distances.index(min(distances))]
            else:
                predictor = 0
            row[i] = (row[i] + predictor) & 255
        if height // 8 <= y < height * 7 // 8:
            for x in range(width // 10, width * 9 // 10, 4):
                i = x * channels
                value = max(row[i:i + 3])
                minimum = min(minimum, value)
                maximum = max(maximum, value)
                bright += value > 35
                count += 1
        previous = row
    if not count or bright / count < 0.005 or maximum - minimum < 12:
        raise ValueError(f"Screenshot has black or blank page content: {path}")


def install_preview(device, deadline):
    """Allow cold simulator installation to settle, with one bounded retry.

    bootstatus alone does not prove the installation service will answer. A
    timed-out install may finish server-side; installing the same preview again
    is safe. Persistent simulator hangs still fail before any capture.
    """
    install_deadline = min(deadline, time.monotonic() + 300)
    for attempt in range(2):
        try:
            run(["xcrun", "simctl", "install", device,
                 "build/ios/iphonesimulator/Runner.app"],
                timeout=120, deadline=install_deadline)
            return
        except subprocess.TimeoutExpired:
            if attempt == 1 or time.monotonic() >= install_deadline:
                raise
            print("Simulator installation timed out; rechecking boot readiness before one retry",
                  flush=True)
            run(["xcrun", "simctl", "bootstatus", device, "-b"],
                timeout=60, deadline=install_deadline)


def render(out=Path("ios-native-pages")):
    deadline = time.monotonic() + RENDER_SECONDS
    device = None
    out.mkdir(exist_ok=True)
    # Prevent artifacts from previous invocations being presented as fresh pages.
    for path in out.glob("ios-*.png"):
        path.unlink()
    try:
        listing = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "--json"],
                                 capture_output=True, deadline=deadline).stdout)["devices"]
        candidates = [(runtime, item) for runtime, devices in listing.items()
                      if "iOS-27" in runtime for item in devices if "iPhone" in item["name"]]
        if not candidates:
            raise RuntimeError("No available iOS 27 iPhone simulator")
        runtime, template = candidates[0]
        # Cloning isolates appearance/status changes from existing runner simulators.
        device = run(["xcrun", "simctl", "clone", template["udid"], "ImmortalWrt preview " + uuid.uuid4().hex],
                     capture_output=True, deadline=deadline).stdout.decode().strip()
        run(["xcrun", "simctl", "boot", device], timeout=60, deadline=deadline)
        run(["xcrun", "simctl", "bootstatus", device, "-b"], timeout=120, deadline=deadline)
        install_preview(device, deadline)
        container = run(["xcrun", "simctl", "get_app_container", device, BUNDLE, "data"],
                        timeout=120, capture_output=True, deadline=deadline).stdout.decode().strip()
        marker = Path(container) / "Documents/ios-preview-ready.json"
        run(["xcrun", "simctl", "status_bar", device, "override", "--time", "9:41",
             "--batteryState", "charged", "--batteryLevel", "100"], deadline=deadline)
        for appearance in ("light", "dark"):
            run(["xcrun", "simctl", "ui", device, "appearance", appearance], deadline=deadline)
            for tab in range(6):
                expected = dict(nonce=uuid.uuid4().hex, tab=tab, appearance=appearance)
                marker.unlink(missing_ok=True)
                env = dict(os.environ, SIMCTL_CHILD_IOS_PREVIEW_TAB=str(tab),
                           SIMCTL_CHILD_IOS_PREVIEW_NONCE=expected["nonce"],
                           SIMCTL_CHILD_IOS_PREVIEW_APPEARANCE=appearance)
                cold_start = appearance == "light" and tab == 0
                page_deadline = min(deadline, time.monotonic() + (90 if cold_start else PAGE_SECONDS))
                # A launch timeout is a failure: it never grants permission to capture.
                run(["xcrun", "simctl", "launch", "--terminate-running-process", device, BUNDLE],
                    timeout=60 if cold_start else 20, deadline=page_deadline, env=env)
                wait_ready(marker, expected, page_deadline)
                pending = out / f"pending-{appearance}-{tab}.png"
                try:
                    run(["xcrun", "simctl", "io", device, "screenshot", str(pending)],
                        timeout=30, deadline=page_deadline)
                    validate_screenshot(pending)
                    pending.replace(out / f"ios-{appearance}-{tab}.png")
                finally:
                    pending.unlink(missing_ok=True)
    finally:
        if device:
            for action in ("shutdown", "delete"):
                try:
                    run(["xcrun", "simctl", action, device], timeout=20)
                except (subprocess.SubprocessError, OSError) as error:
                    print(f"Simulator cleanup {action} failed: {error}", flush=True)


if __name__ == "__main__":
    render()
