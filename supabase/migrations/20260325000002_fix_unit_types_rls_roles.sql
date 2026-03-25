-- Fix unit_types RLS to use SECURITY DEFINER helper functions
-- The previous policies used role IN ('admin', 'staff') but the actual roles are 'community_admin', 'hoa_officer'

DROP POLICY IF EXISTS "Staff can select unit types" ON unit_types;
DROP POLICY IF EXISTS "Staff can insert unit types" ON unit_types;
DROP POLICY IF EXISTS "Staff can update unit types" ON unit_types;
DROP POLICY IF EXISTS "Staff can delete unit types" ON unit_types;
DROP POLICY IF EXISTS "Members can read unit types" ON unit_types;

-- Members can read unit types in their community
CREATE POLICY "Members can read unit types"
  ON unit_types FOR SELECT
  USING (is_community_member(community_id));

-- Staff can insert unit types
CREATE POLICY "Staff can insert unit types"
  ON unit_types FOR INSERT
  WITH CHECK (is_community_staff(community_id));

-- Staff can update unit types
CREATE POLICY "Staff can update unit types"
  ON unit_types FOR UPDATE
  USING (is_community_staff(community_id))
  WITH CHECK (is_community_staff(community_id));

-- Staff can delete unit types
CREATE POLICY "Staff can delete unit types"
  ON unit_types FOR DELETE
  USING (is_community_staff(community_id));
