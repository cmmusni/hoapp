-- Migration: Add SELECT policy for household_members
-- Description: Allow users to read their own household memberships
-- Date: 2026-03-30

-- ============================================================================
-- Allow authenticated users to read their own household memberships
-- ============================================================================
DROP POLICY IF EXISTS "household_members_select_own" ON public.household_members;

CREATE POLICY "household_members_select_own"
ON public.household_members
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

COMMENT ON POLICY "household_members_select_own" ON public.household_members IS
'Allows authenticated users to read their own household memberships';
