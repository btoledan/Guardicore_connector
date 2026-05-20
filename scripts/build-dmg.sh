#!/usr/bin/env bash
# scripts/build-dmg.sh
# Usage: bash scripts/build-dmg.sh <archive.xcarchive> <export-dir> <output.dmg>
set -euo pipefail

ARCHIVE="${1:?archive path required}"
EXPORT_DIR="${2:?export dir required}"
DMG_NAME="${3:-Helmsman.dmg}"
EXPORT_PLIST="scripts/ExportOptions.plist"

echo "▶ Exporting archive..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST"

APP_PATH=$(find "$EXPORT_DIR" -name "*.app" | head -1)
echo "  App: $APP_PATH"

echo "▶ Creating DMG..."
# Use hdiutil to create a writable DMG, copy app, then convert to read-only
TMP_DMG="${EXPORT_DIR}/tmp_rw.dmg"
VOLUME_NAME="Helmsman"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  -o "${EXPORT_DIR}/${DMG_NAME}"

# Generate checksum
pushd "$EXPORT_DIR" > /dev/null
sha256sum "$DMG_NAME" > "${DMG_NAME}.sha256"
popd > /dev/null

echo "✓ DMG: ${EXPORT_DIR}/${DMG_NAME}"
echo "✓ SHA256: $(cat "${EXPORT_DIR}/${DMG_NAME}.sha256")"
