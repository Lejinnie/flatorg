#!/bin/bash

# Firebase App Distribution script for FlatOrg.
# Every run ships BOTH Android (locally) and iOS (via GitHub Actions).
#
# Usage:
#   ./firebase_distribute.sh                          # both, group: testing, auto-bump patch
#   ./firebase_distribute.sh --release                # both, group: hwb-33
#   ./firebase_distribute.sh -v 2.1.0 -m "notes"      # both, with version + notes
#   ./firebase_distribute.sh --release -m "notes"     # both, hwb-33, with notes

set -euo pipefail

cd "$(dirname "$(realpath "$0")")"

RELEASE_NOTES=""
NEW_VERSION=""
GROUP="testing"

# ── Argument parsing ────────────────────────────────────────────────────────
# Manual loop to support both short (-m, -v) and long (--release) flags.

while [[ $# -gt 0 ]]; do
  case $1 in
    -m)
      RELEASE_NOTES="$2"
      shift 2
      ;;
    -v)
      NEW_VERSION="$2"
      shift 2
      ;;
    --release)
      GROUP="hwb-33"
      shift
      ;;
    *)
      echo "Usage: $0 [-m \"release notes\"] [-v x.x.x] [--release]"
      exit 1
      ;;
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
echo "Distribution group: $GROUP"
sed -i "s/^version: .*/version: ${VERSION}+${BUILD}/" pubspec.yaml

# ── Release notes ────────────────────────────────────────────────────────────

if [ -z "$RELEASE_NOTES" ]; then
  RELEASE_NOTES="v${VERSION}+${BUILD} uploaded at $(date +%H:%M)"
fi

# ── Push version bump so the iOS runner gets the updated pubspec ─────────────

BRANCH=$(git rev-parse --abbrev-ref HEAD)
git add pubspec.yaml
git commit -m "chore: bump version to ${VERSION}+${BUILD}"
git push -u origin "$BRANCH"

# ── Trigger iOS build via GitHub Actions ─────────────────────────────────────

echo "Triggering iOS build (TestFlight) on GitHub Actions..."
gh workflow run ios-distribute.yml \
  -f version="${VERSION}+${BUILD}" \
  -f release_notes="$RELEASE_NOTES"

echo "iOS build dispatched. To watch progress run:"
echo "  gh run watch"

# ── Build & distribute Android locally ───────────────────────────────────────

echo "Building release APK..."
flutter build apk --release

APP_ID=$(grep "mobilesdk_app_id" android/app/google-services.json | cut -d '"' -f 4)

echo "Uploading Android APK to Firebase App Distribution..."
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app "$APP_ID" \
  --groups "$GROUP" \
  --release-notes "$RELEASE_NOTES"

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "=== Distribution summary ==="
echo "  Version:  v${VERSION}+${BUILD}"
echo "  Group:    $GROUP"
echo "  Android:  uploaded"
echo "  iOS:      uploading to TestFlight via GitHub Actions (check 'gh run watch')"
echo "  Notes:    $RELEASE_NOTES"
