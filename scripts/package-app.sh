#!/bin/bash
set -euo pipefail

# Build and package PulseApp as a macOS .app bundle and optional .dmg.
# Usage: ./scripts/package-app.sh [--install] [--dmg]
#   --install   Copy .app to /Applications after packaging
#   --dmg       Create a distributable .dmg disk image

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_NAME="Pulse.app"
APP_DIR="$PROJECT_DIR/$APP_NAME"
VERSION=$(grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' "$PROJECT_DIR/Sources/PulseCore/Version.swift" | tr -d '"')
DMG_NAME="Pulse-${VERSION}.dmg"
DMG_PATH="$PROJECT_DIR/$DMG_NAME"

DO_INSTALL=false
DO_DMG=false
for arg in "$@"; do
    case "$arg" in
        --install) DO_INSTALL=true ;;
        --dmg)     DO_DMG=true ;;
    esac
done

echo "Building PulseApp (release)..."
cd "$PROJECT_DIR"
swift build --product PulseApp -c release

echo "Packaging $APP_NAME..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/PulseApp" "$APP_DIR/Contents/MacOS/PulseApp"
cp "$PROJECT_DIR/Sources/PulseApp/Info.plist" "$APP_DIR/Contents/"

# Remove quarantine so macOS doesn't block the unsigned app
xattr -cr "$APP_DIR" 2>/dev/null || true

echo "Built: $APP_DIR"

if $DO_INSTALL; then
    echo "Installing to /Applications..."
    rm -rf "/Applications/$APP_NAME"
    cp -R "$APP_DIR" "/Applications/$APP_NAME"
    echo "Installed: /Applications/$APP_NAME"
    echo "Launch from Spotlight or: open /Applications/Pulse.app"
fi

if $DO_DMG; then
    echo "Creating $DMG_NAME..."
    rm -f "$DMG_PATH"

    create-dmg \
        --volname "Pulse" \
        --volicon "$PROJECT_DIR/Sources/PulseApp/Info.plist" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "Pulse.app" 150 190 \
        --app-drop-link 450 190 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP_DIR" \
    || true
    # create-dmg exits 2 when it can't set a volicon (plist isn't an icon),
    # but still creates the dmg successfully. Check if it exists.

    if [[ -f "$DMG_PATH" ]]; then
        DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1 | xargs)
        echo "Created: $DMG_PATH ($DMG_SIZE)"
        echo ""
        echo "Users installing from this .dmg should bypass Gatekeeper:"
        echo "  1. Open the .dmg"
        echo "  2. Drag Pulse to Applications"
        echo "  3. Right-click Pulse.app → Open (first launch only)"
        echo "  Or run: xattr -cr /Applications/Pulse.app"
    else
        echo "create-dmg failed. Falling back to hdiutil..."
        STAGING="$PROJECT_DIR/.dmg-staging"
        rm -rf "$STAGING"
        mkdir -p "$STAGING"
        cp -R "$APP_DIR" "$STAGING/"
        ln -s /Applications "$STAGING/Applications"
        hdiutil create -volname "Pulse" -srcfolder "$STAGING" \
            -ov -format UDZO "$DMG_PATH"
        rm -rf "$STAGING"
        DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1 | xargs)
        echo "Created: $DMG_PATH ($DMG_SIZE)"
    fi
fi

if ! $DO_INSTALL && ! $DO_DMG; then
    echo "Run:     open $APP_DIR"
    echo "Install: $0 --install"
    echo "DMG:     $0 --dmg"
fi
