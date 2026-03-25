-- Fix RLS policies for unit_types: add explicit WITH CHECK for INSERT/UPDATE
DROP POLICY IF EXISTS "Staff can manage unit types" ON unit_types;

-- Separate policies for clarity and correctness
CREATE POLICY "Staff can select unit types"
  ON unit_types FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.community_id = unit_types.community_id
        AND user_roles.user_id = auth.uid()
        AND user_roles.role IN ('admin', 'staff')
    )
  );

CREATE POLICY "Staff can insert unit types"
  ON unit_types FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.community_id = unit_types.community_id
        AND user_roles.user_id = auth.uid()
        AND user_roles.role IN ('admin', 'staff')
    )
  );

CREATE POLICY "Staff can update unit types"
  ON unit_types FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.community_id = unit_types.community_id
        AND user_roles.user_id = auth.uid()
        AND user_roles.role IN ('admin', 'staff')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.community_id = unit_types.community_id
        AND user_roles.user_id = auth.uid()
        AND user_roles.role IN ('admin', 'staff')
    )
  );

CREATE POLICY "Staff can delete unit types"
  ON unit_types FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.community_id = unit_types.community_id
        AND user_roles.user_id = auth.uid()
        AND user_roles.role IN ('admin', 'staff')
    )
  );
