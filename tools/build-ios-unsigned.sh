#!/usr/bin/env bash
# Build on macOS; Apple credentials are used only later by the local installer.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/housecapture.XXXXXX")"
out="$repo/artifacts/ios"
mkdir -p "$out"

{
  printf 'Source: %s\n' "$(git -C "$repo" rev-parse HEAD)"
  xcodebuild -version
  xcodegen --version
  printf '\nUnsigned Release build for physical iPhone/iPad. Requires local signing.\n'
} | tee "$out/build-info.txt"

cd "$repo/apps/house-capture"
xcodegen generate
xcodebuild \
  -project HouseCapture.xcodeproj \
  -scheme HouseCapture \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$work/build" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  build 2>&1 | tee "$out/xcodebuild.log"

app="$work/build/Build/Products/Release-iphoneos/HouseCapture.app"
python3 "$repo/tools/validate-ios-app.py" "$app" | tee "$out/validation.txt"
lipo -archs "$app/HouseCapture" | tee -a "$out/validation.txt"
xcrun vtool -show-build "$app/HouseCapture" | tee -a "$out/validation.txt"

mkdir -p "$work/package/Payload"
ditto "$app" "$work/package/Payload/HouseCapture.app"
ipa="$out/3D-Model-Anything-unsigned.ipa"
ditto -c -k --keepParent "$work/package/Payload" "$ipa"
unzip -t "$ipa" > "$out/zip-check.txt"
cd "$out"
shasum -a 256 3D-Model-Anything-unsigned.ipa > SHA256SUMS.txt
printf '\nPackage prepared; physical-device capture still needs testing.\n'
