#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
API_BASE_URL_VALUE="${API_BASE_URL:-}"

if ! command -v flutter >/dev/null 2>&1; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter config --enable-web
flutter pub get
flutter build web --no-wasm-dry-run --dart-define=API_BASE_URL="$API_BASE_URL_VALUE"
