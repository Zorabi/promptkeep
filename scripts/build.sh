#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="build/词笺.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc Sources/Models.swift Sources/Store.swift Sources/PromptKeep.swift -parse-as-library -O -target arm64-apple-macosx13.0 -o "$APP/Contents/MacOS/PromptKeep"
xcrun swift scripts/make-icon.swift "$PWD/Assets"
iconutil -c icns Assets/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PromptKeep</string>
<key>CFBundleIdentifier</key><string>dongx.promptkeep</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>词笺</string>
<key>CFBundleDisplayName</key><string>词笺</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.4.2</string>
<key>CFBundleVersion</key><string>8</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>UTExportedTypeDeclarations</key><array><dict>
<key>UTTypeIdentifier</key><string>dongx.promptkeep.record</string>
<key>UTTypeDescription</key><string>词笺提示词引用</string>
<key>UTTypeConformsTo</key><array><string>public.data</string></array>
</dict></array>
<key>NSHumanReadableCopyright</key><string>Copyright (c) 2026 dongx</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
echo "$PWD/$APP"
