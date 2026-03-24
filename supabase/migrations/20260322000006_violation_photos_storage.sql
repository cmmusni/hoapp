-- ========================================
-- VIOLATION PHOTOS STORAGE BUCKET
-- ========================================

-- Create violation-photos bucket
INSERT INTO storage.buckets (id, name, public) VALUES
  ('violation-photos', 'violation-photos', false)
ON CONFLICT (id) DO NOTHING;

-- ========================================
-- VIOLATION PHOTOS POLICIES
-- Path: violation-photos/{community_id}/{violation_id}/{filename}
-- ========================================

-- Staff can read all violation photos in their community
CREATE POLICY "Violation photos are readable by staff"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'violation-photos' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );

-- Reporter can read their own violation photos
CREATE POLICY "Violation photos are readable by reporter"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'violation-photos' AND
    EXISTS (
      SELECT 1 FROM violations v
      WHERE v.id = ((storage.foldername(name))[2])::uuid
        AND v.reporter_user_id = auth.uid()
    )
  );

-- Any authenticated community member can upload violation photos
-- (When creating a new violation, we don't have the violation_id yet,
--  so we allow uploads and rely on folder structure for organization)
CREATE POLICY "Violation photos are insertable by community members"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'violation-photos' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
    )
  );

-- Staff can delete violation photos in their community
CREATE POLICY "Violation photos are deletable by staff"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'violation-photos' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );

-- Reporter can delete their own violation photos (before submission or for corrections)
CREATE POLICY "Violation photos are deletable by reporter"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'violation-photos' AND
    EXISTS (
      SELECT 1 FROM violations v
      WHERE v.id = ((storage.foldername(name))[2])::uuid
        AND v.reporter_user_id = auth.uid()
    )
  );
