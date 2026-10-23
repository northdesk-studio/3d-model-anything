"""Check an unsigned iPhone Release app before local personal signing."""
import plistlib
import subprocess
import sys
from pathlib import Path

app = Path(sys.argv[1])
info = plistlib.loads((app / "Info.plist").read_bytes())
errors = []

if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
    errors.append("Expected a physical-device iPhoneOS build")
if info.get("CFBundleIdentifier") != "com.wesbos.housecapture":
    errors.append("Unexpected bundle identifier")
if info.get("CFBundleExecutable") != "HouseCapture":
    errors.append("Unexpected executable")
if info.get("MinimumOSVersion") != "17.0":
    errors.append("Unexpected minimum iOS version")
if set(info.get("UIDeviceFamily", [])) != {1, 2}:
    errors.append("Expected iPhone and iPad support")
if not info.get("NSCameraUsageDescription"):
    errors.append("Missing camera permission description")
for resource in ["HouseCapture", "Assets.car", "PrivacyInfo.xcprivacy", "Support.json", "PrivacyPolicy.json"]:
    if not (app / resource).is_file():
        errors.append(f"Missing resource: {resource}")
if (app / "embedded.mobileprovision").exists():
    errors.append("Unexpected signing profile in unsigned package")

binary = app / "HouseCapture"
if binary.is_file():
    arches = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).split()
    if "arm64" not in arches:
        errors.append("Missing arm64 device architecture")
    build = subprocess.check_output(["xcrun", "vtool", "-show-build", str(binary)], text=True)
    if "IOSSIMULATOR" in build or not any(line.split() == ["platform", "IOS"] for line in build.splitlines()):
        errors.append("Mach-O target is not iOS device")

if errors:
    raise SystemExit("\n".join(errors))
print("PASS: device target, arm64, iOS 17+, resources, camera usage and unsigned profile checks")
print("This validates packaging only. LiDAR capture/export must be tested on the iPhone.")
