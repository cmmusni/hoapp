-- Pool registered swimmers table
-- Each registration can have multiple swimmers (household members allowed to use the pool)
-- Max pax is determined by unit type (configured in pool_access_registrations.max_pax or community settings)

CREATE TABLE pool_registered_swimmers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id UUID NOT NULL REFERENCES pool_access_registrations(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  birthdate DATE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_pool_swimmers_registration ON pool_registered_swimmers(registration_id);

-- RLS
ALTER TABLE pool_registered_swimmers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Swimmers viewable by registration owner or staff"
  ON pool_registered_swimmers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM pool_access_registrations r
      WHERE r.id = pool_registered_swimmers.registration_id
        AND (r.user_id = auth.uid() OR is_community_staff(r.community_id))
    )
  );

CREATE POLICY "Swimmers insertable by registration owner"
  ON pool_registered_swimmers FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM pool_access_registrations r
      WHERE r.id = pool_registered_swimmers.registration_id
        AND r.user_id = auth.uid()
    )
  );

CREATE POLICY "Swimmers updatable by registration owner or staff"
  ON pool_registered_swimmers FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM pool_access_registrations r
      WHERE r.id = pool_registered_swimmers.registration_id
        AND (r.user_id = auth.uid() OR is_community_staff(r.community_id))
    )
  );

CREATE POLICY "Swimmers deletable by registration owner or staff"
  ON pool_registered_swimmers FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM pool_access_registrations r
      WHERE r.id = pool_registered_swimmers.registration_id
        AND (r.user_id = auth.uid() OR is_community_staff(r.community_id))
    )
  );

-- Add max_pax field to pool_access_registrations
ALTER TABLE pool_access_registrations ADD COLUMN IF NOT EXISTS max_pax INT DEFAULT 5;
