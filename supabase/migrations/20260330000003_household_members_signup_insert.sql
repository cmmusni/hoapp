-- Migration: Allow authenticated users to insert household_members during signup
-- Description: Enables users who just signed up to add themselves to units
-- Date: 2026-03-30

-- ============================================================================
-- Allow authenticated users to join units during signup
-- ============================================================================
-- This is needed so users can automatically be added to their selected unit
-- after email confirmation during the community-specific signup flow

-- Drop old policy if it exists
DROP POLICY IF EXISTS "Allow users to join units during signup" ON public.household_members;

CREATE POLICY "Allow users to join units during signup"
ON public.household_members
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

COMMENT ON POLICY "Allow users to join units during signup" ON public.household_members IS
'Allows authenticated users to add themselves as household members to units. Users can only insert records where their user_id matches the authenticated user.';


-- ============================================================================
-- Allow authenticated users to create their own resident role
-- ============================================================================
-- This is needed so users can be assigned the resident role automatically
-- during the community signup flow

-- Drop old policy if it exists
DROP POLICY IF EXISTS "Allow users to create their own resident role" ON public.user_roles;

CREATE POLICY "Allow users to create their own resident role"
ON public.user_roles
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid() 
  AND role = 'resident'
);

COMMENT ON POLICY "Allow users to create their own resident role" ON public.user_roles IS
'Allows authenticated users to create a resident role for themselves during signup. Limited to resident role only for security.';


-- ============================================================================
-- Security Notes:
-- ============================================================================
-- These policies are safe because:
-- 1. Users can only insert records for themselves (user_id = auth.uid())
-- 2. The resident role policy restricts role assignment to 'resident' only
-- 3. Other roles (admin, officer, guard) still require admin assignment
-- 4. Users cannot modify or delete existing records (only INSERT allowed)
-- 5. Existing RLS policies still control SELECT, UPDATE, DELETE operations
