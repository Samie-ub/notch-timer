#!/bin/bash
# Build and sign release assets locally. Does not publish anything.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(python3 -c 'import json; print(json.load(open("config/updates.json"))["version"])')
BUILD=$(python3 -c 'import json; print(json.load(open("config/updates.json"))["build"])')
ACCOUNT=$(python3 -c 'import json; print(json.load(open("config/updates.json"))["keychainAccount"])')
OUT="$PWD/dist/releases/$VERSION-$BUILD"
if [ -e "$OUT" ]; then
    echo "Release directory already exists: $OUT. Increase the version/build for a new release." >&2
    exit 1
fi
bash scripts/build-app.sh
TOOLS="$PWD/.build/artifacts/sparkle/Sparkle/bin"
EXPECTED_KEY=$(python3 -c 'import json; print(json.load(open("config/updates.json"))["publicKey"])')
ACTUAL_KEY=$("$TOOLS/generate_keys" --account "$ACCOUNT" -p)
if [ "$ACTUAL_KEY" != "$EXPECTED_KEY" ]; then
    echo "The Keychain signing key does not match config/updates.json." >&2
    exit 1
fi
mkdir -p "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$PWD/dist/settime.app" "$OUT/settime-$VERSION.zip"
"$TOOLS/generate_appcast" --account "$ACCOUNT" --maximum-deltas 0 \
    --download-url-prefix "https://github.com/Samie-ub/notch-timer/releases/download/v$VERSION/" "$OUT"
echo "Signed release assets ready: $OUT"
