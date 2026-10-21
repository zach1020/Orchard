#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
DESTINATION="$(pwd)/../Orchard.app"
STAGE="$(mktemp -d /private/tmp/orchard-build.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
APP_DIR="$STAGE/Orchard.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/Orchard" "$APP_DIR/Contents/MacOS/Orchard"
cp Sources/Orchard/Resources/OrchardLogo.png "$APP_DIR/Contents/Resources/OrchardLogo.png"
cp Assets/Orchard.icns "$APP_DIR/Contents/Resources/Orchard.icns"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Orchard</string>
<key>CFBundleIdentifier</key><string>local.orchard.desktop</string>
<key>CFBundleName</key><string>Orchard</string>
<key>CFBundleDisplayName</key><string>Orchard</string>
<key>CFBundleIconFile</key><string>Orchard.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
mkdir -p "$APP_DIR/Contents/Resources/Licenses"
for license in .build/checkouts/*/LICENSE*(N); do
    if [[ -f "$license" ]]; then
        dependency="$(basename "$(dirname "$license")")"
        cp "$license" "$APP_DIR/Contents/Resources/Licenses/$dependency-$(basename "$license").txt"
    fi
done
codesign --force --sign - "$APP_DIR"
ditto "$APP_DIR" "$DESTINATION"
xattr -d com.apple.FinderInfo "$DESTINATION" 2>/dev/null || true
printf 'Built %s\n' "$DESTINATION"
