-- Migration: Fix infinite recursion in household_members RLS policies
-- Root cause: Multiple overlapping policies, some with raw subqueries on
-- household_members from within household_members policies, and is_unit_member()
-- which also queries household_members. The combination causes recursive
-- policy evaluation in PostgreSQL.
--
-- Fix: Drop ALL existing policies, create a SECURITY DEFINER helper for
-- primary-member checks, and recreate clean per-operation policies.

-- ============================================================================
-- Step 1: Drop ALL existing policies on household_members
-- ============================================================================
DROP POLICY IF EXISTS "Household members are viewable by unit members or staff" ON public.household_members;
DROP POLICY IF EXISTS "Household members are insertable by unit members or staff" ON public.household_members;
DROP POLICY IF EXISTS "Household members are updatable by unit members or staff" ON public.household_members;
DROP POLICY IF EXISTS "Household members are deletable by staff" ON public.household_members;
DROP POLICY IF EXISTS "Primary members can add members to their unit" ON public.household_members;
DROP POLICY IF EXISTS "Primary members can remove members from their unit" ON public.household_members;
DROP POLICY IF EXISTS "Staff manage household members" ON public.household_members;
DROP POLICY IF EXISTS "View household members in community" ON public.household_members;
DROP POLICY IF EXISTS "household_members_insert_self" ON public.household_members;
DROP POLICY IF EXISTS "household_members_select_own" ON public.household_members;
DROP POLICY IF EXISTS "Allow users to join units during signup" ON public.household_members;

-- ============================================================================
-- Step 2: Create SECURITY DEFINER helper for primary-member check
-- (Runs as the function owner, bypassing RLS — no recursion)
-- ============================================================================
CREATE OR REPLACE FUNCTION is_primary_member_of_unit(unit_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM household_members
    WHERE user_id = auth.uid()
      AND unit_id = unit_uuid
      AND member_role = 'primary'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- ============================================================================
-- Step 3: Recreate clean policies (no self-referencing raw subqueries)
-- ============================================================================

-- SELECT: community members (via user_roles) or own rows
CREATE POLICY "hm_select"
ON public.household_members
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR community_id IN (
    SELECT community_id FROM user_roles WHERE user_id = auth.uid()
  )
);

-- INSERT: staff, primary members of the unit, or self-insert during signup
CREATE POLICY "hm_insert"
ON public.household_members
FOR INSERT
TO authenticated
WITH CHECK (
  is_community_staff(community_id)
  OR is_primary_member_of_unit(unit_id)
  OR user_id = auth.uid()
);

-- UPDATE: staff or primary members of the unit
CREATE POLICY "hm_update"
ON public.household_members
FOR UPDATE
TO authenticated
USING (
  is_community_staff(community_id)
  OR is_primary_member_of_unit(unit_id)
);

-- DELETE: staff, or primary members (cannot delete themselves)
CREATE POLICY "hm_delete"
ON public.household_members
FOR DELETE
TO authenticated
USING (
  is_community_staff(community_id)
  OR (
    user_id IS DISTINCT FROM auth.uid()
    AND is_primary_member_of_unit(unit_id)
  )
);
