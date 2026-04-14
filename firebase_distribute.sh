#!/bin/bash

# Firebase App Distribution script for FlatOrg.
# Usage:
#   ./firebase_distribute.sh                    # auto-increments patch version (x.x.x -> x.x.x+1)
#   ./firebase_distribute.sh -v 2.1.0           # sets version to 2.1.0
#   ./firebase_distribute.sh -m "Fixed login"   # adds release notes
#   ./firebase_distribute.sh -v 1.2.0 -m "New feature"

set -euo pipefail

cd /home/lejinnie/Projects/flatorg

RELEASE_NOTES=""
NEW_VERSION=""

while getopts "m:v:" opt; do
  case $opt in
    m) RELEASE_NOTES="$OPTARG" ;;
    v) NEW_VERSION="$OPTARG" ;;
    *) echo "Usage: $0 [-m \"release notes\"] [-v x.x.x]"; exit 1 ;;
  esac
done

# ── Version handling ─────────────────────────────────────────────────────────

# Read the current version+build line from pubspec.yaml.
CURRENT_LINE=$(grep -E '^version:' pubspec.yaml)
CURRENT_VERSION=$(echo "$CURRENT_LINE" | sed -E 's/version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
CURRENT_BUILD=$(echo "$CURRENT_LINE" | sed -E 's/.*\+([0-9]+)/\1/')

if [ -n "$NEW_VERSION" ]; then
  # Validate x.x.x format.
  if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "ERROR: Version must be in x.x.x format (e.g. 1.2.3). Got: $NEW_VERSION"
    exit 1
  fi
  VERSION="$NEW_VERSION"
else
  # Auto-increment the patch number.
  MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
  MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
  PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)
  PATCH=$((PATCH + 1))
  VERSION="${MAJOR}.${MINOR}.${PATCH}"
fi

BUILD=$((CURRENT_BUILD + 1))

echo "Version: $CURRENT_VERSION+$CURRENT_BUILD -> $VERSION+$BUILD"
sed -i "s/^version: .*/version: ${VERSION}+${BUILD}/" pubspec.yaml

# ── Release notes ────────────────────────────────────────────────────────────

if [ -z "$RELEASE_NOTES" ]; then
  RELEASE_NOTES="v${VERSION}+${BUILD} uploaded at $(date +%H:%M)"
fi

# ── Build & distribute ───────────────────────────────────────────────────────

echo "Building release APK..."
flutter build apk --release

APP_ID=$(grep "mobilesdk_app_id" android/app/google-services.json | cut -d '"' -f 4)

echo "Uploading to Firebase App Distribution..."
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app "$APP_ID" \
  --groups "hwb-33" \
  --release-notes "$RELEASE_NOTES"

echo "Done — distributed v${VERSION}+${BUILD}"
