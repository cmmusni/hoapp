-- Migration: Allow anonymous and authenticated users to access community and household data for signup
-- Description: Enables both unauthenticated and newly authenticated users to view
--              community info and units during signup flow and unit assignment
-- Date: 2026-03-30

-- ============================================================================
-- Allow anonymous and authenticated users to read community information
-- ============================================================================
-- This is needed so users can sign up for a specific community through
-- the community-specific signup page (e.g., /eleve-homes/signup)
-- Both anon (during signup) and authenticated (after email confirmation) need access

-- Drop old policy if it exists
DROP POLICY IF EXISTS "Allow anonymous users to read communities" ON public.communities;

CREATE POLICY "Allow public read access to communities"
ON public.communities
FOR SELECT
TO anon, authenticated
USING (true);

COMMENT ON POLICY "Allow public read access to communities" ON public.communities IS
'Allows both unauthenticated and authenticated users to view community basic information (name, slug, logo, colors) needed for the signup page and portal';


-- ============================================================================
-- Allow anonymous and authenticated users to read units
-- ============================================================================
-- This is needed so users can select their unit from a dropdown during signup
-- and so authenticated users can complete unit assignment after email confirmation
-- Only unit_no is exposed - no personal resident information

-- Drop old policy if it exists
DROP POLICY IF EXISTS "Allow anonymous users to read units" ON public.units;

CREATE POLICY "Allow public read access to units"
ON public.units
FOR SELECT
TO anon, authenticated
USING (true);

COMMENT ON POLICY "Allow public read access to units" ON public.units IS
'Allows both unauthenticated and authenticated users to view available unit numbers during signup and unit assignment. Only unit identifiers are exposed, no personal data.';


-- ============================================================================
-- Security Notes:
-- ============================================================================
-- These policies are safe because:
-- 1. Communities table: Only contains public information (name, slug, logo, colors)
--    - No sensitive user data
--    - Information that would be displayed on public marketing pages anyway
--
-- 2. Units table: Only exposes unit identifiers (e.g., "Unit 101", "Unit 402")
--    - No resident names, emails, or personal information
--    - Just structural identifiers for the community
--    - Household members and their details are protected by separate RLS policies
--
-- 3. All other sensitive tables (household_members, user_roles, payments, etc.)
--    remain protected and require authentication
