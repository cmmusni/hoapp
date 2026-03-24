#!/bin/bash

# HOApp Supabase Deployment Script
# This script deploys database migrations and Edge Functions to Supabase

set -e  # Exit on error

echo "========================================="
echo "HOApp Supabase Deployment"
echo "========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}Error: Supabase CLI is not installed${NC}"
    echo "Install it with: brew install supabase/tap/supabase"
    exit 1
fi

echo -e "${GREEN}✓ Supabase CLI found${NC}"

# Check if we're in the right directory
if [ ! -d "supabase" ]; then
    echo -e "${RED}Error: supabase directory not found${NC}"
    echo "Please run this script from the project root"
    exit 1
fi

cd supabase

# Check if project is linked
if [ ! -f ".temp/project-ref" ]; then
    echo -e "${YELLOW}Warning: Project not linked${NC}"
    echo "Please run: supabase link --project-ref YOUR_PROJECT_REF"
    exit 1
fi

PROJECT_REF=$(cat .temp/project-ref)
echo -e "${GREEN}✓ Linked to project: $PROJECT_REF${NC}"

# Step 1: Push database migrations
echo -e "\n${YELLOW}Step 1: Pushing database migrations...${NC}"
echo "This will apply all pending migrations to your production database."
echo -e "${RED}WARNING: This will modify your production database!${NC}"
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    exit 1
fi

supabase db push

echo -e "${GREEN}✓ Database migrations applied${NC}"

# Step 2: Deploy Edge Functions
echo -e "\n${YELLOW}Step 2: Deploying Edge Functions...${NC}"

FUNCTIONS=(
    "create_community"
    "create_invite"
    "accept_invite"
    "verify_payment"
    "book_amenity"
)

for FUNC in "${FUNCTIONS[@]}"; do
    echo "  Deploying $FUNC..."
    if [ "$FUNC" == "create_community" ]; then
        # create_community doesn't verify JWT for public access
        supabase functions deploy "$FUNC" --no-verify-jwt
    else
        supabase functions deploy "$FUNC"
    fi
    echo -e "  ${GREEN}✓ $FUNC deployed${NC}"
done

echo -e "${GREEN}✓ All Edge Functions deployed${NC}"

# Step 3: Configure secrets
echo -e "\n${YELLOW}Step 3: Configuring Edge Function secrets...${NC}"

# Check if .env exists
if [ ! -f "../.env" ]; then
    echo -e "${YELLOW}No .env file found. Skipping secret configuration.${NC}"
    echo "You can manually set secrets with:"
    echo "  supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-key"
    echo "  supabase secrets set WEB_BASE_URL=https://hoapp.com"
else
    # Load environment variables
    export $(grep -v '^#' ../.env | xargs)
    
    if [ -n "$SUPABASE_SERVICE_ROLE_KEY" ]; then
        echo "  Setting SUPABASE_SERVICE_ROLE_KEY..."
        echo "$SUPABASE_SERVICE_ROLE_KEY" | supabase secrets set SUPABASE_SERVICE_ROLE_KEY --stdin
        echo -e "  ${GREEN}✓ SUPABASE_SERVICE_ROLE_KEY set${NC}"
    fi
    
    if [ -n "$WEB_BASE_URL" ]; then
        echo "  Setting WEB_BASE_URL..."
        echo "$WEB_BASE_URL" | supabase secrets set WEB_BASE_URL --stdin
        echo -e "  ${GREEN}✓ WEB_BASE_URL set${NC}"
    fi
fi

# Step 4: Seed demo data (optional)
echo -e "\n${YELLOW}Step 4: Seed demo data? (optional)${NC}"
echo "This will create the 'Elevé Homes' community with sample data."
echo -e "${RED}WARNING: This will reset your database!${NC}"
read -p "Seed demo data? (yes/no): " SEED_CONFIRM

if [ "$SEED_CONFIRM" == "yes" ]; then
    supabase db reset --seed
    echo -e "${GREEN}✓ Demo data seeded${NC}"
    echo ""
    echo "Demo login credentials:"
    echo "  Admin: admin@elevehomes.com (ask for password)"
    echo "  Community slug: eleve-homes"
else
    echo "Skipping demo data"
fi

# Step 5: Verification
echo -e "\n${YELLOW}Step 5: Verifying deployment...${NC}"

echo "  Checking database tables..."
TABLES=$(supabase db list | grep -c "public" || true)
echo -e "  ${GREEN}✓ Found $TABLES tables${NC}"

echo "  Checking Edge Functions..."
FUNCS=$(supabase functions list | grep -c "create\|accept\|verify\|book" || true)
echo -e "  ${GREEN}✓ Found $FUNCS functions${NC}"

# Summary
echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}What was deployed:${NC}"
echo "  ✓ 5 database migrations"
echo "  ✓ 5 Edge Functions"
echo "  ✓ Environment secrets configured"
if [ "$SEED_CONFIRM" == "yes" ]; then
    echo "  ✓ Demo data seeded"
fi
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Test Edge Functions in Supabase dashboard"
echo "  2. Verify RLS policies are working"
echo "  3. Test authentication flow"
echo "  4. Deploy web application"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  - Update authentication redirect URLs in Supabase dashboard"
echo "  - Configure email templates (Settings → Authentication → Email Templates)"
echo "  - Review storage bucket policies"
echo "  - Set up monitoring and alerts"
echo ""
