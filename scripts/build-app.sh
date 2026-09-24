#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
swift build -c release --disable-sandbox
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$PWD/dist/settime.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [ ! -f resources/settime.icns ]; then
    swift scripts/make-app-icon.swift resources/settime.iconset
fi
cp "$BIN_DIR/NotchTimer" "$APP/Contents/MacOS/NotchTimer"
SPARKLE="$PWD/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$PWD/.build/artifacts/sparkle/Sparkle/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE.txt"
cp resources/settime.icns "$APP/Contents/Resources/settime.icns"
# Compile the Chrome-only helper separately so plain `swift run` remains unambiguous.
swiftc -O -target "$(uname -m)-apple-macosx14.0" \
    Sources/TimerCore/TimerEngine.swift Sources/TimerCore/BrowserFocus.swift \
    tools/browser-focus-host/main.swift -o "$APP/Contents/MacOS/BrowserFocusHost"
mkdir -p "$APP/Contents/Resources/browser-extension" "$APP/Contents/Resources/sounds"
cp browser-extension/* "$APP/Contents/Resources/browser-extension/"
cp sounds/pause.mp3 sounds/stop.mp3 sounds/times-up.mp3 "$APP/Contents/Resources/sounds/"
cp sounds/start.m4a "$APP/Contents/Resources/sounds/start.m4a"
rm -f "$APP/Contents/Resources/sounds/start.mp3"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleName</key><string>settime</string>
    <key>CFBundleDisplayName</key><string>settime</string>
    <key>CFBundleIconFile</key><string>settime</string>
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
python3 scripts/configure-updates.py "$APP/Contents/Info.plist"
# Sign nested Sparkle executables inside-out; ad-hoc signing needs no Apple membership.
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign --force --sign - "$FRAMEWORK/XPCServices/Downloader.xpc"
codesign --force --sign - "$FRAMEWORK/XPCServices/Installer.xpc"
codesign --force --sign - "$FRAMEWORK/Autoupdate"
codesign --force --sign - "$FRAMEWORK/Updater.app"
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$APP/Contents/MacOS/BrowserFocusHost"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built: $APP"
