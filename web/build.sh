#!/bin/bash
set -e

# If executed inside web directory, move to repo root
if [ -f "../pubspec.yaml" ]; then
  cd ..
fi

# Download Flutter SDK into build environment if not present
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

export PATH="$PATH:`pwd`/flutter/bin"

# Configure git safe directory for Vercel container user
git config --global --add safe.directory "*" || true

# Enable web support and build release bundle
flutter config --enable-web
flutter build web --release --no-tree-shake-icons
