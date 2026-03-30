-- Verify and Fix RLS Policies for Community Signup
-- Run this in Supabase Studio SQL Editor or via psql

-- ============================================================================
-- Step 1: Check current policies
-- ============================================================================
SELECT 
    tablename, 
    policyname, 
    roles::text[], 
    cmd,
    CASE WHEN qual IS NOT NULL THEN 'Has USING clause' ELSE 'No USING' END as using_clause,
    CASE WHEN with_check IS NOT NULL THEN 'Has WITH CHECK' ELSE 'No WITH CHECK' END as check_clause
FROM pg_policies 
WHERE tablename IN ('communities', 'units', 'household_members', 'user_roles')
ORDER BY tablename, policyname;

-- ============================================================================
-- Step 2: Drop ALL existing policies that might conflict
-- ============================================================================
DROP POLICY IF EXISTS "Allow anonymous users to read communities" ON public.communities;
DROP POLICY IF EXISTS "Allow public read access to communities" ON public.communities;
DROP POLICY IF EXISTS "Allow anonymous users to read units" ON public.units;
DROP POLICY IF EXISTS "Allow public read access to units" ON public.units;
DROP POLICY IF EXISTS "Allow users to join units during signup" ON public.household_members;
DROP POLICY IF EXISTS "Allow users to create their own resident role" ON public.user_roles;

-- ============================================================================
-- Step 3: Enable RLS on all tables (if not already enabled)
-- ============================================================================
ALTER TABLE public.communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.household_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- Step 4: Create new policies for communities table
-- ============================================================================
CREATE POLICY "communities_select_public"
ON public.communities
FOR SELECT
TO anon, authenticated
USING (true);

-- ============================================================================
-- Step 5: Create new policies for units table
-- ============================================================================
CREATE POLICY "units_select_public"
ON public.units
FOR SELECT
TO anon, authenticated
USING (true);

-- ============================================================================
-- Step 6: Create insert policies for household_members
-- ============================================================================
CREATE POLICY "household_members_insert_self"
ON public.household_members
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- Step 7: Create insert policies for user_roles
-- ============================================================================
CREATE POLICY "user_roles_insert_resident"
ON public.user_roles
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid() 
  AND role = 'resident'
);

-- ============================================================================
-- Step 8: Verify policies were created
-- ============================================================================
SELECT 
    tablename, 
    policyname, 
    roles::text[], 
    cmd
FROM pg_policies 
WHERE tablename IN ('communities', 'units', 'household_members', 'user_roles')
ORDER BY tablename, policyname;

-- ============================================================================
-- Step 9: Test the policies
-- ============================================================================
-- Test as anonymous user (simulating REST API call)
SET ROLE anon;
SELECT COUNT(*) as community_count FROM public.communities WHERE slug = 'eleve-homes';
SELECT COUNT(*) as unit_count FROM public.units;
RESET ROLE;

COMMENT ON POLICY "communities_select_public" ON public.communities IS 
'Allows both anonymous and authenticated users to read community information for signup';

COMMENT ON POLICY "units_select_public" ON public.units IS 
'Allows both anonymous and authenticated users to read units for signup';

COMMENT ON POLICY "household_members_insert_self" ON public.household_members IS 
'Allows authenticated users to add themselves as household members';

COMMENT ON POLICY "user_roles_insert_resident" ON public.user_roles IS 
'Allows authenticated users to create resident role for themselves';
