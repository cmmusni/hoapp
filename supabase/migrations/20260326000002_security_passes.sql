-- =============================================================
-- Security Pass Feature – tables, indexes, RLS policies
-- =============================================================

-- 1. Pass types (configurable per community)
CREATE TABLE IF NOT EXISTS pass_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  name TEXT NOT NULL,                -- e.g. 'Visitor Pass', 'Gate Pass'
  slug TEXT NOT NULL,                -- e.g. 'visitor', 'gate', 'contractor', 'delivery'
  description TEXT,
  approval_required BOOLEAN NOT NULL DEFAULT true,
  max_validity_hours INT NOT NULL DEFAULT 24,
  multi_use BOOLEAN NOT NULL DEFAULT false,
  max_uses INT NOT NULL DEFAULT 1,
  vehicle_required BOOLEAN NOT NULL DEFAULT false,
  attachment_required BOOLEAN NOT NULL DEFAULT false,
  lead_time_hours INT NOT NULL DEFAULT 0,
  grace_period_hours INT NOT NULL DEFAULT 2,
  active BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(community_id, slug)
);

CREATE INDEX idx_pass_types_community ON pass_types(community_id);

-- 2. Security passes (the actual pass requests)
CREATE TABLE IF NOT EXISTS security_passes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  pass_type_id UUID NOT NULL REFERENCES pass_types(id) ON DELETE CASCADE,
  requested_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('draft','submitted','pending_review','approved','active','used','expired','revoked','rejected')),

  -- Visitor / person info
  visitor_name TEXT,
  visitor_phone TEXT,
  visitor_email TEXT,
  purpose TEXT,
  company_name TEXT,

  -- Vehicle info
  plate_number TEXT,
  vehicle_description TEXT,

  -- Items (gate pass)
  items_description TEXT,

  -- Validity window
  valid_from TIMESTAMPTZ NOT NULL,
  valid_until TIMESTAMPTZ NOT NULL,

  -- Usage tracking
  max_uses INT NOT NULL DEFAULT 1,
  use_count INT NOT NULL DEFAULT 0,

  -- QR / token
  qr_token TEXT UNIQUE,         -- cryptographic token for QR code
  qr_generated_at TIMESTAMPTZ,

  -- Approval
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMPTZ,
  rejection_reason TEXT,

  -- Attachments (photo URLs from storage)
  attachments TEXT[] DEFAULT '{}',

  -- Notes
  notes TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_security_passes_community ON security_passes(community_id);
CREATE INDEX idx_security_passes_requested_by ON security_passes(requested_by);
CREATE INDEX idx_security_passes_status ON security_passes(status);
CREATE INDEX idx_security_passes_qr_token ON security_passes(qr_token);
CREATE INDEX idx_security_passes_valid_window ON security_passes(valid_from, valid_until);

-- 3. Scan logs (entry/exit records)
CREATE TABLE IF NOT EXISTS pass_scan_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pass_id UUID NOT NULL REFERENCES security_passes(id) ON DELETE CASCADE,
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  scanned_by UUID NOT NULL REFERENCES auth.users(id),
  scan_type TEXT NOT NULL DEFAULT 'entry' CHECK (scan_type IN ('entry', 'exit')),
  scan_result TEXT NOT NULL CHECK (scan_result IN ('valid', 'invalid', 'expired', 'revoked', 'used_up')),
  notes TEXT,
  scanned_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_pass_scan_logs_pass ON pass_scan_logs(pass_id);
CREATE INDEX idx_pass_scan_logs_community ON pass_scan_logs(community_id);

-- =============================================================
-- RLS Policies
-- =============================================================

-- Pass types: all community members can read; staff can manage
ALTER TABLE pass_types ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Community members can view pass types"
  ON pass_types FOR SELECT
  USING (is_community_member(community_id));

CREATE POLICY "Staff can manage pass types"
  ON pass_types FOR INSERT
  WITH CHECK (is_community_staff(community_id));

CREATE POLICY "Staff can update pass types"
  ON pass_types FOR UPDATE
  USING (is_community_staff(community_id));

CREATE POLICY "Staff can delete pass types"
  ON pass_types FOR DELETE
  USING (is_community_staff(community_id));

-- Security passes: requesters see own; staff see all in community; guards see approved/active
ALTER TABLE security_passes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own passes"
  ON security_passes FOR SELECT
  USING (
    requested_by = auth.uid()
    OR is_community_staff(community_id)
    OR (
      has_community_role(community_id, 'guard')
      AND status IN ('approved','active','used','expired','revoked')
    )
  );

CREATE POLICY "Authenticated users can create passes"
  ON security_passes FOR INSERT
  WITH CHECK (
    is_community_member(community_id)
    AND requested_by = auth.uid()
  );

CREATE POLICY "Staff can update passes"
  ON security_passes FOR UPDATE
  USING (
    is_community_staff(community_id)
    OR (requested_by = auth.uid() AND status IN ('draft','submitted'))
  );

CREATE POLICY "Staff can delete passes"
  ON security_passes FOR DELETE
  USING (is_community_staff(community_id));

-- Scan logs: guards + staff can insert; staff can read all; guards can read own scans
ALTER TABLE pass_scan_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Guards and staff can create scan logs"
  ON pass_scan_logs FOR INSERT
  WITH CHECK (
    is_community_staff(community_id)
    OR has_community_role(community_id, 'guard')
  );

CREATE POLICY "Staff and guards can view scan logs"
  ON pass_scan_logs FOR SELECT
  USING (
    is_community_staff(community_id)
    OR has_community_role(community_id, 'guard')
  );

-- =============================================================
-- Seed default pass types for all existing communities
-- =============================================================
INSERT INTO pass_types (community_id, name, slug, description, approval_required, max_validity_hours, multi_use, max_uses, vehicle_required, sort_order)
SELECT
  c.id,
  pt.name,
  pt.slug,
  pt.description,
  pt.approval_required,
  pt.max_validity_hours,
  pt.multi_use,
  pt.max_uses,
  pt.vehicle_required,
  pt.sort_order
FROM communities c
CROSS JOIN (VALUES
  ('Visitor Pass',     'visitor',    'Pass for visitors entering the community',       true,  24, false, 1, false, 1),
  ('Gate Pass',        'gate',       'Pass for taking items in or out of the community', true, 12, false, 1, false, 2),
  ('Contractor Pass',  'contractor', 'Pass for contractors and service personnel',      true,  48, true,  5, true,  3),
  ('Delivery Pass',    'delivery',   'Pass for delivery and courier personnel',         false, 4,  false, 1, false, 4)
) AS pt(name, slug, description, approval_required, max_validity_hours, multi_use, max_uses, vehicle_required, sort_order)
ON CONFLICT (community_id, slug) DO NOTHING;
