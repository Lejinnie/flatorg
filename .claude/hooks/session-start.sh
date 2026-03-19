#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Install Flutter SDK if not already present
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
fi

# Export PATH for this session
echo "export PATH=\"\$HOME/flutter/bin:\$HOME/flutter/bin/cache/dart-sdk/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
export PATH="$HOME/flutter/bin:$HOME/flutter/bin/cache/dart-sdk/bin:$PATH"

# Suppress analytics prompts
flutter --disable-analytics 2>/dev/null || true
dart --disable-analytics 2>/dev/null || true

# Resolve project dependencies
cd "$CLAUDE_PROJECT_DIR"
flutter pub get
