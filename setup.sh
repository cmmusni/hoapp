#!/bin/bash

# HOApp Quick Start Script
# This script helps you get started with HOApp development

set -e

echo "🏗️  HOApp Quick Start"
echo "===================="
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    echo "   Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Installing..."
    brew install supabase/tap/supabase || {
        echo "Failed to install Supabase CLI. Please install manually:"
        echo "   Visit: https://supabase.com/docs/guides/cli"
        exit 1
    }
fi

echo "✅ Prerequisites checked"
echo ""

# Install dependencies
echo "📦 Installing Flutter dependencies..."
make install || {
    echo "❌ Failed to install dependencies"
    exit 1
}
echo "✅ Dependencies installed"
echo ""

# Setup environment file
if [ ! -f .env ]; then
    echo "⚙️  Setting up environment file..."
    cp .env.example .env
    echo "⚠️  Please edit .env with your Supabase credentials"
    echo ""
fi

# Supabase setup
echo "🗄️  Supabase Setup"
echo "=================="
echo ""
echo "Please follow these steps manually:"
echo ""
echo "1. Create a Supabase project at https://supabase.com"
echo "2. Copy your project URL and anon key to .env"
echo "3. Link your local project:"
echo "   cd supabase && supabase link --project-ref YOUR_PROJECT_REF"
echo ""
echo "4. Apply database migrations:"
echo "   make db:push"
echo ""
echo "5. Deploy Edge Functions:"
echo "   make fn:deploy"
echo ""
echo "6. Seed demo data (optional):"
echo "   make seed"
echo ""

# Generate code
echo "🔧 Generating model code..."
echo "Run this to generate .g.dart files:"
echo "   cd packages/core_domain"
echo "   flutter pub run build_runner build --delete-conflicting-outputs"
echo ""

# Final instructions
echo "✅ Setup complete!"
echo ""
echo "🚀 Next steps:"
echo ""
echo "For Web Development:"
echo "  make run:web"
echo ""
echo "For Mobile Development:"
echo "  make run:mobile"
echo ""
echo "Build for Production:"
echo "  make build:web    # Web build"
echo "  make build:apk    # Android APK"
echo ""
echo "📚 Documentation:"
echo "  README.md         # Project overview"
echo "  ARCHITECTURE.md   # System architecture"
echo "  DEPLOYMENT.md     # Deployment guide"
echo "  TODO.md          # Feature implementation list"
echo ""
echo "Happy coding! 🎉"
