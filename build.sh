#!/bin/bash
set -euo pipefail

APP_NAME="HA Menubar Helper"
BUNDLE_ID="com.algkmn.akgha"
EXECUTABLE="AKGHA"
SIGN_IDENTITY="Developer ID Application: Ali Gokmen (6W8XF3QS2U)"
APP_DIR="$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"

echo "==> Building (release, universal)"
swift build -c release --arch arm64 --arch x86_64
BIN_PATH=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"
cp "$BIN_PATH/$EXECUTABLE" "$CONTENTS/MacOS/$EXECUTABLE"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Home Assistant'tan sıcaklık ve nem verisi almak için yerel ağ erişimi gereklidir.</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

echo "==> Codesign (Developer ID)"
if ! security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY"; then
    echo "HATA: imzalama kimligi bulunamadi: $SIGN_IDENTITY" >&2
    exit 1
fi
codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$APP_DIR"
codesign --verify --strict --verbose=2 "$APP_DIR"

if [[ "${1:-}" == "--install" ]]; then
    echo "==> Installing to /Applications"
    rm -rf "/Applications/$APP_DIR"
    cp -R "$APP_DIR" "/Applications/$APP_DIR"
    echo "==> Installed: /Applications/$APP_DIR"
fi

echo "==> Done: $(pwd)/$APP_DIR"
