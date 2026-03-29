-- Allow violation reporters to update their own violations while status is 'new'
CREATE POLICY "Violations are updatable by reporter when new"
  ON violations FOR UPDATE
  USING (
    reporter_user_id = auth.uid()
    AND status = 'new'
  )
  WITH CHECK (
    reporter_user_id = auth.uid()
    AND status = 'new'
  );
