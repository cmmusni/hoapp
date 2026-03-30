-- Add SELECT policies for user_roles and household_members
-- Run this in Supabase Studio SQL Editor

-- ============================================================================
-- Allow users to read their own roles
-- ============================================================================
DROP POLICY IF EXISTS "user_roles_select_own" ON public.user_roles;

CREATE POLICY "user_roles_select_own"
ON public.user_roles
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

COMMENT ON POLICY "user_roles_select_own" ON public.user_roles IS
'Allows authenticated users to read their own roles';

-- ============================================================================
-- Allow users to read their own household memberships
-- ============================================================================
DROP POLICY IF EXISTS "household_members_select_own" ON public.household_members;

CREATE POLICY "household_members_select_own"
ON public.household_members
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

COMMENT ON POLICY "household_members_select_own" ON public.household_members IS
'Allows authenticated users to read their own household memberships';

-- ============================================================================
-- Verify the policies
-- ============================================================================
SELECT 
    tablename,
    policyname,
    roles::text[],
    cmd,
    CASE WHEN qual IS NOT NULL THEN 'Has USING' ELSE 'No USING' END as using_clause
FROM pg_policies
WHERE tablename IN ('user_roles', 'household_members')
ORDER BY tablename, policyname;
