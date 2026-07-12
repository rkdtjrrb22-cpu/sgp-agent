#!/usr/bin/env bash
# SGP-Agent — iOS 무서명 빌드 검증 (macOS + Xcode 필수)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== SGP-Agent iOS build verify ==="
flutter pub get
cd ios
pod install --repo-update
cd ..
flutter analyze lib ios
flutter build ios --no-codesign
echo "OK — flutter build ios --no-codesign succeeded"
