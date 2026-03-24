#!/bin/bash
set -e

# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:$(pwd)/flutter/bin"
flutter --version

# Get dependencies for all packages
cd packages/core_domain && flutter pub get
cd ../core_data && flutter pub get
cd ../core_ui && flutter pub get
cd ../../apps/web_portal && flutter pub get
