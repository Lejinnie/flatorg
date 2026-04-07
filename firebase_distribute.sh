#!/bin/bash

# 1. Move to the project directory just in case
cd /home/lejinnie/Projects/flatorg

# 2. Build the APK
echo "🚀 Building Release APK..."
flutter build apk --release

# 3. Get the App ID automatically
APP_ID=$(grep "mobilesdk_app_id" android/app/google-services.json | cut -d '"' -f 4)

# 4. Distribute (All in one line to avoid backslash errors)
echo "📦 Uploading to Firebase..."
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk --app "$APP_ID" --groups "hwb-33" --release-notes "Build uploaded via script at $(date +%H:%M)"
