#!/usr/bin/env bash
# scripts/notarize.sh
# Usage: bash scripts/notarize.sh <path/to/Helmsman.dmg>
#
# Prerequisites (set these as CI secrets or in a local .env):
#   APPLE_ID          — your Apple ID email
#   APPLE_TEAM_ID     — your 10-char Team ID
#   NOTARY_PASSWORD   — app-specific password from appleid.apple.com
set -euo pipefail

DMG="${1:?DMG path required}"

: "${APPLE_ID:?Set APPLE_ID env var}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID env var}"
: "${NOTARY_PASSWORD:?Set NOTARY_PASSWORD env var}"

echo "▶ Submitting for notarization: $DMG"
xcrun notarytool submit "$DMG" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$NOTARY_PASSWORD" \
  --wait \
  --verbose

echo "▶ Stapling notarization ticket..."
xcrun stapler staple "$DMG"

echo "✓ Notarization complete: $DMG"

# Verify
spctl --assess --type open --context context:primary-signature --verbose "$DMG" \
  && echo "✓ Gatekeeper assessment passed" \
  || echo "⚠ Gatekeeper assessment failed — check signing"
