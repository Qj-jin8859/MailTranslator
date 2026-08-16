#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MailTranslator"
CONFIGURATION="${CONFIGURATION:-release}"
BIN_PATH="$ROOT/.build/$CONFIGURATION/$APP_NAME"
APP_DIR="$ROOT/dist/$APP_NAME.app"

cd "$ROOT"
if [ "$CONFIGURATION" = "release" ]; then
    swift build -c release --product MailTranslator -Xswiftc -Osize -Xlinker -dead_strip
else
    swift build -c "$CONFIGURATION" --product MailTranslator
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/menu-bar-icon.png" "$APP_DIR/Contents/Resources/menu-bar-icon.png"

if [ "$CONFIGURATION" = "release" ]; then
    strip -x "$APP_DIR/Contents/MacOS/$APP_NAME"
fi

# Ad-hoc signing keeps local macOS Gatekeeper happy during development.
codesign --force --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "Built: $APP_DIR"
