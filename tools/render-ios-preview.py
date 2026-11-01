"""Prepare an isolated display and capture only acknowledged preview pages."""
import argparse
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
PAGE_SECONDS = 60
SESSION_NAME = ".ios-preview-device.json"


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


def acquire_device(session, deadline):
    listing = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "--json"],
                             capture_output=True, deadline=deadline).stdout)["devices"]
    if session.exists():
        if session.stat().st_size > 4096:
            raise RuntimeError("Invalid prepared simulator session")
        identity = json.loads(session.read_text(encoding="utf-8"))
        if not isinstance(identity, dict) or identity.get("schema") != 1 or \
                identity.get("run_id") != os.environ.get("GITHUB_RUN_ID") or \
                identity.get("attempt") != os.environ.get("GITHUB_RUN_ATTEMPT") or \
                not isinstance(identity.get("runtime"), str) or \
                not isinstance(identity.get("device"), str) or \
                not isinstance(identity.get("name"), str) or \
                not identity["name"].startswith("ImmortalWrt preview "):
            raise RuntimeError("Prepared simulator does not belong to this preview run")
        # Match an actual named device; never accept simctl aliases such as all.
        runtime = identity.get("runtime", "")
        found = next((item for item in listing.get(runtime, [])
                      if item["udid"] == identity.get("device") and
                      item["name"] == identity.get("name")), None)
        if "iOS-27" not in runtime or not found or found.get("state") != "Booted":
            raise RuntimeError("Prepared preview simulator is not available and booted")
        return identity["device"], identity, False
    candidates = [(runtime, item) for runtime, devices in listing.items()
                  if "iOS-27" in runtime for item in devices if "iPhone" in item["name"]]
    if not candidates:
        raise RuntimeError("No available iOS 27 iPhone simulator")
    runtime, template = candidates[0]
    device_type = template.get("deviceTypeIdentifier")
    if not device_type:
        types = json.loads(run(["xcrun", "simctl", "list", "devicetypes", "--json"],
                               capture_output=True, deadline=deadline).stdout)["devicetypes"]
        device_type = next((item["identifier"] for item in types
                            if item["name"] == template["name"]), None)
    if not device_type:
        raise RuntimeError("Cannot resolve the iOS 27 iPhone simulator device type")
    name = "ImmortalWrt preview " + uuid.uuid4().hex
    device = run(["xcrun", "simctl", "create", name, device_type, runtime],
                 capture_output=True, deadline=deadline).stdout.decode().strip()
    identity = dict(schema=1, device=device, name=name, runtime=runtime,
                    run_id=os.environ.get("GITHUB_RUN_ID"), attempt=os.environ.get("GITHUB_RUN_ATTEMPT"))
    return device, identity, True


def boot_device(device, deadline):
    developer = Path(run(["xcode-select", "--print-path"], capture_output=True,
                         deadline=deadline).stdout.decode().strip())
    run(["xcrun", "simctl", "boot", device], timeout=60, deadline=deadline)
    simulator = developer / "Applications/Simulator.app"
    if simulator.is_dir():
        try:
            run(["open", "-a", str(simulator), "--args", "-CurrentDeviceUDID", device],
                timeout=30, deadline=deadline)
        except (subprocess.SubprocessError, OSError) as error:
            print(f"Simulator desktop unavailable; using simctl headless display: {error}", flush=True)
    else:
        print("Simulator.app is not installed; using simctl headless display", flush=True)
    run(["xcrun", "simctl", "bootstatus", device, "-b"], timeout=180, deadline=deadline)


def cleanup_device(device):
    for action in ("shutdown", "delete"):
        try:
            run(["xcrun", "simctl", action, device], timeout=20)
        except (subprocess.SubprocessError, OSError) as error:
            print(f"Simulator cleanup {action} failed: {error}", flush=True)


def prepare_device(session=Path(SESSION_NAME)):
    """Warm native display services before the existing Flutter build step.

    The SpringBoard warmup is discarded; it never counts as an app page.
    Hosted CI disposes of the runner if the subsequent build fails or cancels.
    The render phase cleans up its specifically recorded device on all exits.
    """
    deadline = time.monotonic() + 300
    device = None
    prepared = False
    warmup = session.parent / ".ios-preview-warmup.png"
    pending = session.with_suffix(".tmp")
    try:
        device, identity, created = acquire_device(session, deadline)
        if created:
            boot_device(device, deadline)
        run(["xcrun", "simctl", "io", device, "screenshot", str(warmup)],
            timeout=180, deadline=deadline)
        pending.write_text(json.dumps(identity), encoding="utf-8")
        pending.replace(session)
        prepared = True
        print("Isolated simulator and native display prepared before Flutter build", flush=True)
    finally:
        warmup.unlink(missing_ok=True)
        pending.unlink(missing_ok=True)
        if device and not prepared:
            cleanup_device(device)
            session.unlink(missing_ok=True)


def render(out=Path("ios-native-pages")):
    deadline = time.monotonic() + RENDER_SECONDS
    session = out.parent / SESSION_NAME
    device = None
    out.mkdir(exist_ok=True)
    # Prevent artifacts from previous invocations being presented as fresh pages.
    for path in out.glob("ios-*.png"):
        path.unlink()
    try:
        device, identity, created = acquire_device(session, deadline)
        if created:
            boot_device(device, deadline)
        install_preview(device, deadline)
        container = run(["xcrun", "simctl", "get_app_container", device, BUNDLE, "data"],
                        timeout=120, capture_output=True, deadline=deadline).stdout.decode().strip()
        marker = Path(container) / "Documents/ios-preview-ready.json"
        run(["xcrun", "simctl", "status_bar", device, "override", "--time", "9:41",
             "--batteryState", "charged", "--batteryLevel", "100"], deadline=deadline)
        for appearance in ("light", "dark"):
            run(["xcrun", "simctl", "ui", device, "appearance", appearance], deadline=deadline)
            for tab in range(7):
                expected = dict(nonce=uuid.uuid4().hex, tab=tab, appearance=appearance)
                marker.unlink(missing_ok=True)
                env = dict(os.environ, SIMCTL_CHILD_IOS_PREVIEW_TAB=str(tab),
                           SIMCTL_CHILD_IOS_PREVIEW_NONCE=expected["nonce"],
                           SIMCTL_CHILD_IOS_PREVIEW_APPEARANCE=appearance)
                cold_start = appearance == "light" and tab == 0
                page_deadline = min(deadline, time.monotonic() + (120 if cold_start else PAGE_SECONDS))
                # A launch timeout is a failure: it never grants permission to capture.
                run(["xcrun", "simctl", "launch", "--terminate-running-process", device, BUNDLE],
                    timeout=60 if cold_start else 20, deadline=page_deadline, env=env)
                wait_ready(marker, expected, page_deadline)
                pending = out / f"pending-{appearance}-{tab}.png"
                try:
                    run(["xcrun", "simctl", "io", device, "screenshot", str(pending)],
                        timeout=60 if cold_start else 30, deadline=page_deadline)
                    validate_screenshot(pending)
                    pending.replace(out / f"ios-{appearance}-{tab}.png")
                finally:
                    pending.unlink(missing_ok=True)
    finally:
        if device:
            cleanup_device(device)
            session.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare-device", action="store_true")
    args = parser.parse_args()
    if args.prepare_device:
        prepare_device()
    else:
        render()
