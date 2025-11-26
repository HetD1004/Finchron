#!/usr/bin/env bash
# CI helper to build iOS IPA. Run on macOS with Xcode and CocoaPods installed.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR"
IOS_DIR="$ROOT_DIR/ios"

BUILD_NAME=${1:-$(grep '^version:' pubspec.yaml | sed 's/version: //; s/+.*//')}
BUILD_NUMBER=${2:-$(grep '^version:' pubspec.yaml | sed 's/.*+//')}
EXPORT_METHOD=${3:-app-store}

echo "Building Finchron iOS IPA"
echo "BUILD_NAME=${BUILD_NAME}, BUILD_NUMBER=${BUILD_NUMBER}, EXPORT_METHOD=${EXPORT_METHOD}"

cd "$IOS_DIR"

# Install pods
if [ -f "Podfile" ]; then
  echo "Installing CocoaPods..."
  pod install --repo-update
fi

cd "$APP_DIR"

# Clean
flutter clean
flutter pub get

# Build IPA
flutter build ipa --export-method=${EXPORT_METHOD} --build-name=${BUILD_NAME} --build-number=${BUILD_NUMBER} --export-options-plist="ios/ExportOptions.plist"

echo "IPA build finished. Find artifacts in build/ios/ipa or Xcode Organizer."