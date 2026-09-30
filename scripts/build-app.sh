#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="What's Your Status"
EXECUTABLE_NAME="WhatsYourStatus"
BUNDLE_DIR="${ROOT_DIR}/build/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

cd "${ROOT_DIR}"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${EXECUTABLE_NAME}"

rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

if [[ -f "${ROOT_DIR}/icon-wys.png" ]]; then
    if [[ ! -f "${ROOT_DIR}/Resources/AppIcon.icns" || "${ROOT_DIR}/icon-wys.png" -nt "${ROOT_DIR}/Resources/AppIcon.icns" ]]; then
        echo "Generating AppIcon.icns from icon-wys.png..."
        mkdir -p "${ROOT_DIR}/Resources/AppIcon.iconset"
        sips -z 16 16     "${ROOT_DIR}/icon-wys.png" --out "${ROOT_DIR}/Resources/AppIcon.iconset/icon_16x16.png" >/dev/null
        sips -z 32 32     "${ROOT_DIR}/icon-wys.png" --out "${ROOT_DIR}/Resources/AppIcon.iconset/icon_16x16@2x.png" >/dev/null
        sips -z 32 32     "${ROOT_DIR}/icon-wys.png" --out "${ROOT_DIR}/Resources/AppIcon.iconset/icon_32x32.png" >/dev/null
        sips -z 64 64     "${ROOT_DIR}/icon-wys.png" --out "${ROOT_DIR}/Resources/AppIcon.iconset/icon_32x32@2x.png" >/dev/null
        sips -z 128 128   "${ROOT_DIR}/icon-wys.png" --out "${ROOT_DIR}/Resources/AppIcon.iconset/icon_128x128.png" >/dev/null
        sips -z 256 256   "${ROOT_DIR}/icon-wys.png" --out "${ROOT_DIR}/Resources/AppIcon.iconset/icon_128x128@2x.png" >/dev/null
        sips -z 256 256   "${ROOT_DIR}/icon-wys.png" --out "${ROOT_DIR}/Resources/AppIcon.iconset/icon_256x256.png" >/dev/null
        sips -z 512 512   "${ROOT_DIR}/icon-wys.png" --out "${ROOT_DIR}/Resources/AppIcon.iconset/icon_256x256@2x.png" >/dev/null
        sips -z 512 512   "${ROOT_DIR}/icon-wys.png" --out "${ROOT_DIR}/Resources/AppIcon.iconset/icon_512x512.png" >/dev/null
        sips -z 1024 1024 "${ROOT_DIR}/icon-wys.png" --out "${ROOT_DIR}/Resources/AppIcon.iconset/icon_512x512@2x.png" >/dev/null
        iconutil -c icns "${ROOT_DIR}/Resources/AppIcon.iconset" -o "${ROOT_DIR}/Resources/AppIcon.icns"
        rm -rf "${ROOT_DIR}/Resources/AppIcon.iconset"
    fi
    cp "${ROOT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

cp "${BIN_PATH}" "${MACOS_DIR}/${EXECUTABLE_NAME}"
chmod +x "${MACOS_DIR}/${EXECUTABLE_NAME}"

cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>id</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.bhaktitud.whats-your-status</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "${BUNDLE_DIR}"
echo "Built macOS app bundle at: ${BUNDLE_DIR}"
