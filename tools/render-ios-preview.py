import json
import os
from pathlib import Path
import subprocess
import time


def run(args, timeout=60, **kwargs):
    print("Running:", " ".join(args), flush=True)
    return subprocess.run(args, check=True, timeout=timeout, **kwargs)


data = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "--json"], capture_output=True).stdout)["devices"]
device = next(x["udid"] for runtime, devices in data.items() if "iOS-27" in runtime for x in devices if "iPhone" in x["name"])
run(["xcrun", "simctl", "boot", device], timeout=180)
run(["xcrun", "simctl", "bootstatus", device, "-b"], timeout=180)
run(["xcrun", "simctl", "install", device, "build/ios/iphonesimulator/Runner.app"], timeout=120)
run(["xcrun", "simctl", "status_bar", device, "override", "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100"])
out = Path("ios-native-pages")
out.mkdir(exist_ok=True)
for appearance in ["light", "dark"]:
    run(["xcrun", "simctl", "ui", device, "appearance", appearance])
    for tab in range(4):
        env = dict(os.environ, SIMCTL_CHILD_IOS_PREVIEW_TAB=str(tab))
        try:
            run(["xcrun", "simctl", "launch", "--terminate-running-process", device, "com.medyma.immortalwrtApp"], timeout=120, env=env)
        except subprocess.TimeoutExpired:
            print("Launch command timed out; checking rendered simulator frame", flush=True)
        time.sleep(8)
        run(["xcrun", "simctl", "io", device, "screenshot", str(out / f"ios-{appearance}-{tab}.png")])
