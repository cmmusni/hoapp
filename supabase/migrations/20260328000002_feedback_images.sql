-- ========================================
-- FEEDBACK IMAGES: column + storage bucket
-- ========================================

-- Add image_url column to feedback table
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Create feedback-images storage bucket (public so images render easily)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'feedback-images',
  'feedback-images',
  true,
  5242880, -- 5MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- ========================================
-- STORAGE POLICIES
-- Path: feedback-images/{community_id}/{filename}
-- ========================================

-- Anyone authenticated can read feedback images (public bucket, but explicit policy)
CREATE POLICY "Feedback images are readable by authenticated users"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'feedback-images' AND
    auth.role() = 'authenticated'
  );

-- Community members can upload feedback images
CREATE POLICY "Feedback images are insertable by community members"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'feedback-images' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
    )
  );

-- Staff can delete feedback images
CREATE POLICY "Feedback images are deletable by staff"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'feedback-images' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );
