#!/bin/bash

# HOApp Production Build Script
# This script builds HOApp web application for production deployment

set -e  # Exit on error

echo "========================================="
echo "HOApp Production Build"
echo "========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please create a .env file with your Supabase credentials."
    echo "Copy .env.example and fill in your values:"
    echo "  cp .env.example .env"
    exit 1
fi

# Load environment variables
echo -e "\n${BLUE}Loading environment variables...${NC}"
export $(grep -v '^#' .env | xargs)

# Verify required variables
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo -e "${RED}Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Environment variables loaded${NC}"
echo "  SUPABASE_URL: $SUPABASE_URL"
echo "  SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..."

# Step 1: Clean previous builds
echo -e "\n${YELLOW}Step 1: Cleaning previous builds...${NC}"
cd apps/web_portal
flutter clean
cd ../..

# Step 2: Install dependencies
echo -e "\n${YELLOW}Step 2: Installing dependencies...${NC}"
cd packages/core_domain && flutter pub get
cd ../core_data && flutter pub get
cd ../core_ui && flutter pub get
cd ../../apps/web_portal && flutter pub get
cd ../..

# Step 3: Build domain models
echo -e "\n${YELLOW}Step 3: Building domain models...${NC}"
cd packages/core_domain
flutter pub run build_runner build --delete-conflicting-outputs
cd ../..

# Step 4: Run tests (optional - comment out to skip)
echo -e "\n${YELLOW}Step 4: Running tests...${NC}"
echo -e "${BLUE}Skipping tests for production build...${NC}"
# Uncomment to run tests before building:
# ./run_tests.sh || {
#     echo -e "${RED}Tests failed! Aborting build.${NC}"
#     exit 1
# }

# Step 5: Build web application
echo -e "\n${YELLOW}Step 5: Building web application for production...${NC}"
cd apps/web_portal
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

# Step 6: Verify build
echo -e "\n${YELLOW}Step 6: Verifying build...${NC}"
if [ ! -d "build/web" ]; then
    echo -e "${RED}Error: Build directory not found!${NC}"
    exit 1
fi

if [ ! -f "build/web/index.html" ]; then
    echo -e "${RED}Error: index.html not found in build!${NC}"
    exit 1
fi

# Calculate build size
BUILD_SIZE=$(du -sh build/web | cut -f1)
echo -e "${GREEN}✓ Build successful!${NC}"
echo -e "  Output: apps/web_portal/build/web"
echo -e "  Size: $BUILD_SIZE"

# Step 7: Deployment instructions
echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "1. Deploy to Netlify:"
echo "   netlify deploy --prod --dir=apps/web_portal/build/web"
echo ""
echo "2. Deploy to Vercel:"
echo "   vercel --prod"
echo ""
echo "3. Deploy to Cloudflare Pages:"
echo "   - Push to GitHub"
echo "   - Cloudflare Pages will auto-deploy"
echo ""
echo "4. Manual deployment:"
echo "   - Upload contents of apps/web_portal/build/web"
echo "   - Configure SPA routing (all routes → /index.html)"
echo ""
echo -e "${YELLOW}Remember to:${NC}"
echo "  - Set environment variables in hosting platform"
echo "  - Configure custom domain"
echo "  - Enable HTTPS"
echo "  - Update WEB_BASE_URL in Supabase Edge Functions"
echo ""
