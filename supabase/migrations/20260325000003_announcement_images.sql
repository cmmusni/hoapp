-- ========================================
-- ADD IMAGE URL TO ANNOUNCEMENTS
-- ========================================

ALTER TABLE announcements ADD COLUMN image_url TEXT;

-- ========================================
-- ANNOUNCEMENT IMAGES STORAGE BUCKET
-- ========================================

INSERT INTO storage.buckets (id, name, public) VALUES
  ('announcement-images', 'announcement-images', true)
ON CONFLICT (id) DO NOTHING;

-- Path: announcement-images/{community_id}/{filename}

-- Anyone can read announcement images (public bucket)
CREATE POLICY "Announcement images are publicly readable"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'announcement-images');

-- Staff can upload announcement images
CREATE POLICY "Announcement images are uploadable by staff"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'announcement-images' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );

-- Staff can update/overwrite announcement images
CREATE POLICY "Announcement images are updatable by staff"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'announcement-images' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );

-- Staff can delete announcement images
CREATE POLICY "Announcement images are deletable by staff"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'announcement-images' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );
