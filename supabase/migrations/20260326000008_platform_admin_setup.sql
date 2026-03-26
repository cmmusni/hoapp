-- Platform roles: add RLS policies and seed the first app_admin

-- Allow users to read their own platform role
CREATE POLICY "Users can read own platform role"
  ON platform_roles FOR SELECT
  USING (user_id = auth.uid());

-- Seed the platform admin (Clifford's user ID from the logs)
INSERT INTO platform_roles (user_id, role)
VALUES ('fa5b3e17-9ca4-46dc-a8e7-e9095c950eda', 'app_admin')
ON CONFLICT (user_id) DO NOTHING;

-- Update beta_access_requests policies to use platform_roles instead of user_roles
DROP POLICY IF EXISTS "Admins can view beta requests" ON beta_access_requests;
DROP POLICY IF EXISTS "Admins can update beta requests" ON beta_access_requests;

CREATE POLICY "Platform admins can view beta requests"
  ON beta_access_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM platform_roles
      WHERE platform_roles.user_id = auth.uid()
        AND platform_roles.role = 'app_admin'
    )
  );

CREATE POLICY "Platform admins can update beta requests"
  ON beta_access_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM platform_roles
      WHERE platform_roles.user_id = auth.uid()
        AND platform_roles.role = 'app_admin'
    )
  );
