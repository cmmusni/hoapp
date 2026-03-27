-- ========================================
-- ADD ATTACHMENT URL TO ANNOUNCEMENTS
-- ========================================

ALTER TABLE announcements ADD COLUMN attachment_url TEXT;

-- ========================================
-- ANNOUNCEMENT ATTACHMENTS STORAGE BUCKET
-- ========================================

INSERT INTO storage.buckets (id, name, public) VALUES
  ('announcement-attachments', 'announcement-attachments', true)
ON CONFLICT (id) DO NOTHING;

-- Path: announcement-attachments/{community_id}/{filename}

-- Anyone can read announcement attachments (public bucket)
CREATE POLICY "Announcement attachments are publicly readable"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'announcement-attachments');

-- Staff can upload announcement attachments
CREATE POLICY "Announcement attachments are uploadable by staff"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'announcement-attachments' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );

-- Staff can update/overwrite announcement attachments
CREATE POLICY "Announcement attachments are updatable by staff"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'announcement-attachments' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );

-- Staff can delete announcement attachments
CREATE POLICY "Announcement attachments are deletable by staff"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'announcement-attachments' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );
