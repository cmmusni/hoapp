-- Unit Types: community-scoped list of unit types (e.g. "Studio", "2BR", "Penthouse")
CREATE TABLE IF NOT EXISTS unit_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (community_id, name)
);

-- Enable RLS
ALTER TABLE unit_types ENABLE ROW LEVEL SECURITY;

-- Staff can manage unit types
CREATE POLICY "Staff can manage unit types"
  ON unit_types FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.community_id = unit_types.community_id
        AND user_roles.user_id = auth.uid()
        AND user_roles.role IN ('admin', 'staff')
    )
  );

-- Members can read unit types in their community
CREATE POLICY "Members can read unit types"
  ON unit_types FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.community_id = unit_types.community_id
        AND user_roles.user_id = auth.uid()
    )
  );

-- Update units.unit_type to reference unit_types.name for consistency (optional FK, kept as TEXT for flexibility)
