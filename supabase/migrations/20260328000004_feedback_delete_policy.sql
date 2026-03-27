-- Allow staff to delete feedback in their community
CREATE POLICY "Staff can delete community feedback"
  ON feedback FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND user_roles.community_id = feedback.community_id
        AND user_roles.role IN ('community_admin', 'hoa_officer')
    )
  );

-- Platform admin can delete any feedback
CREATE POLICY "Platform admin can delete feedback"
  ON feedback FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM platform_roles
      WHERE platform_roles.user_id = auth.uid()
        AND platform_roles.role = 'app_admin'
    )
  );
