#!/bin/bash
# If executed inside web directory, move to repo root
if [ -f "../pubspec.yaml" ]; then
  cd ..
fi

# Download Flutter SDK into build environment if not present
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

export PATH="$PATH:`pwd`/flutter/bin"

# Enable web support and build release bundle
flutter config --enable-web
flutter build web --release
