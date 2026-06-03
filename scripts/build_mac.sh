#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild が見つかりません。MacのXcode環境で実行してください。" >&2
  exit 1
fi

xcodebuild \
  -project GemstoneDictionary.xcodeproj \
  -scheme GemstoneDictionary \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
