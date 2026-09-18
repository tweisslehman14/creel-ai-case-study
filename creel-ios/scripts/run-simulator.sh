#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE_ID="${1:-$(xcrun simctl list devices available -j | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); a=[x for k,v in d["devices"].items() if "iOS" in k for x in v if x["name"].startswith("iPhone")]; print(next((x["udid"] for x in a if x["state"]=="Booted"),a[0]["udid"] if a else ""))')}"
if [ -z "$DEVICE_ID" ]; then echo "Install an iOS simulator runtime in Xcode Settings > Components first." >&2; exit 1; fi
BUILD_DIR="${CREEL_BUILD_DIR:-/tmp/creel-derived-data}"
xcodebuild -project Creel.xcodeproj -scheme Creel -configuration Debug -sdk iphonesimulator -destination "id=$DEVICE_ID" -derivedDataPath "$BUILD_DIR" CODE_SIGNING_ALLOWED=NO build
STATE="$(xcrun simctl list devices -j | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["state"] for v in d["devices"].values() for x in v if x["udid"]==sys.argv[1]))' "$DEVICE_ID")"
if [ "$STATE" != "Booted" ]; then xcrun simctl boot "$DEVICE_ID"; fi
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl install "$DEVICE_ID" "$BUILD_DIR/Build/Products/Debug-iphonesimulator/Creel.app"
xcrun simctl launch "$DEVICE_ID" com.creel.journal
open -a Simulator
