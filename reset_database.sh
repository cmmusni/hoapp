#!/bin/bash

# ========================================
# HOApp Database Reset Script
# ========================================
# This script will completely reset the Supabase database
# to a clean state with no data but with all schema intact.
#
# WARNING: This will DELETE ALL DATA permanently!
# Use only for development/testing purposes.
# ========================================

set -e

echo "🔴 WARNING: This will DELETE ALL DATA in your database!"
echo "This action cannot be undone."
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Reset cancelled."
    exit 1
fi

echo ""
echo "📋 Step 1: Stopping Supabase..."
supabase stop

echo ""
echo "📋 Step 2: Removing database files..."
rm -rf supabase/.branches
rm -rf supabase/.temp

echo ""
echo "📋 Step 3: Starting fresh Supabase instance..."
supabase start

echo ""
echo "📋 Step 4: Running migrations..."
supabase db reset

echo ""
echo "✅ Database reset complete!"
echo ""
echo "Your database now has:"
echo "  ✓ All tables created (empty)"
echo "  ✓ All triggers installed"
echo "  ✓ All RLS policies active"
echo "  ✓ All storage buckets configured"
echo "  ✓ Realtime enabled"
echo ""
echo "🔗 Supabase Studio: http://localhost:54323"
echo ""
