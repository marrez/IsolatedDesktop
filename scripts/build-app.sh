#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$ROOT/dist/Isolated Desktop.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/IsolatedDesktop" "$APP/Contents/MacOS/IsolatedDesktop"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - --entitlements "$ROOT/Resources/IsolatedDesktop.entitlements" "$APP"
echo "Application créée : $APP"
