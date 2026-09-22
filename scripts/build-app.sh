#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
swift build -c release --disable-sandbox
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$PWD/dist/Notch Timer.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/NotchTimer" "$APP/Contents/MacOS/NotchTimer"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleName</key><string>Notch Timer</string>
    <key>CFBundleDisplayName</key><string>Notch Timer</string>
    <key>CFBundleIdentifier</key><string>com.local.notchtimer</string>
    <key>CFBundleExecutable</key><string>NotchTimer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built: $APP"
