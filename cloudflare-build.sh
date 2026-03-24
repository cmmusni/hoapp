#!/bin/bash

# Cloudflare Pages build script
# This script builds the HOApp web portal for Cloudflare Pages deployment

set -e  # Exit on error

echo "========================================="
echo "HOApp Cloudflare Pages Build"
echo "========================================="

# Install Flutter if not present
if ! command -v flutter &> /dev/null; then
    echo "Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable
    export PATH="$PATH:`pwd`/flutter/bin"
fi

# Verify Flutter installation
flutter --version

# Get dependencies for all packages
echo "Installing dependencies..."
cd packages/core_domain && flutter pub get
cd ../core_data && flutter pub get
cd ../core_ui && flutter pub get
cd ../../apps/web_portal && flutter pub get

# Build web application
echo "Building web application..."
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo "Build completed successfully!"
echo "Output directory: apps/web_portal/build/web"
