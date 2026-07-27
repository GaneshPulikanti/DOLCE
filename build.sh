#!/bin/bash
# Download Flutter SDK into the build runner environment
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

# Enable web support and build release bundle
flutter config --enable-web
flutter build web --release
