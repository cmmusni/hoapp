-- Allow staff to create pool access registrations on behalf of unit residents
-- Changes:
-- 1. Replace UNIQUE(community_id, user_id) with UNIQUE(community_id, unit_id) for unit-based registration
-- 2. Update INSERT RLS to allow staff to create registrations
-- 3. Update INSERT RLS for swimmers to allow staff

-- =============================================
-- 1. Change unique constraint to per-unit
-- =============================================

-- Drop old per-user unique constraint
ALTER TABLE pool_access_registrations
  DROP CONSTRAINT IF EXISTS pool_access_registrations_community_id_user_id_key;

-- Add per-unit unique index (one registration per unit per community)
-- Partial index: only enforced when unit_id is not null
CREATE UNIQUE INDEX IF NOT EXISTS pool_access_registrations_community_unit_unique
  ON pool_access_registrations (community_id, unit_id)
  WHERE unit_id IS NOT NULL;

-- =============================================
-- 2. Allow staff to INSERT pool registrations
-- =============================================

DROP POLICY IF EXISTS "Pool access is insertable by community members" ON pool_access_registrations;

CREATE POLICY "Pool access is insertable by owner or staff"
  ON pool_access_registrations FOR INSERT
  WITH CHECK (
    (user_id = auth.uid() AND is_community_member(community_id))
    OR is_community_staff(community_id)
  );

-- =============================================
-- 3. Allow staff to INSERT swimmers
-- =============================================

DROP POLICY IF EXISTS "Swimmers insertable by registration owner" ON pool_registered_swimmers;

CREATE POLICY "Swimmers insertable by registration owner or staff"
  ON pool_registered_swimmers FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM pool_access_registrations r
      WHERE r.id = pool_registered_swimmers.registration_id
        AND (r.user_id = auth.uid() OR is_community_staff(r.community_id))
    )
  );
