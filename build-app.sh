#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
swift build -c release --triple arm64-apple-macosx13.0
swift build -c release --triple x86_64-apple-macosx13.0

app=".build/SMBWatchdog.app"
mkdir -p "$app/Contents/MacOS"
lipo -create \
    ".build/arm64-apple-macosx/release/SMBWatchdog" \
    ".build/x86_64-apple-macosx/release/SMBWatchdog" \
    -output "$app/Contents/MacOS/SMBWatchdog"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SMBWatchdog</string>
    <key>CFBundleIdentifier</key>
    <string>com.helenfac.SMBWatchdog</string>
    <key>CFBundleName</key>
    <string>SMB Watchdog</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
PLIST

printf 'Created %s\n' "$app"
