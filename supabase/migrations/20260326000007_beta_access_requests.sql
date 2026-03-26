-- Beta access requests table
CREATE TABLE IF NOT EXISTS beta_access_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  organization TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  notes TEXT,
  provisioned_community_id UUID REFERENCES communities(id) ON DELETE SET NULL,
  provisioned_user_id UUID,
  processed_by UUID,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Index for quick lookups
CREATE INDEX idx_beta_requests_status ON beta_access_requests(status);
CREATE INDEX idx_beta_requests_email ON beta_access_requests(email);

-- RLS: Only service role can insert (edge function), admins can read/update
ALTER TABLE beta_access_requests ENABLE ROW LEVEL SECURITY;

-- Platform admins (community_admin role holders) can view all requests
CREATE POLICY "Admins can view beta requests"
  ON beta_access_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND user_roles.role = 'community_admin'
    )
  );

-- Platform admins can update requests (approve/reject)
CREATE POLICY "Admins can update beta requests"
  ON beta_access_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND user_roles.role = 'community_admin'
    )
  );
