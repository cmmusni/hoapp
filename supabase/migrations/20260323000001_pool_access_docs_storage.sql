-- Pool Access Documents Storage Bucket
-- Stores ID documents and signed waivers for pool access registrations

BEGIN;

-- Create bucket for pool access documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'pool-access-docs',
  'pool-access-docs',
  false,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- RLS Policies for pool-access-docs bucket

-- Community members can upload their own documents
CREATE POLICY "community_member_upload_own_docs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'pool-access-docs'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can view their own documents
CREATE POLICY "user_view_own_docs"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'pool-access-docs'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can delete their own documents before approval
CREATE POLICY "user_delete_own_docs"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'pool-access-docs'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Staff/admin can view all documents in their community
CREATE POLICY "staff_view_community_docs"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'pool-access-docs'
  AND EXISTS (
    SELECT 1
    FROM user_roles ur
    WHERE ur.user_id = auth.uid()
    AND ur.role IN ('admin', 'staff')
  )
);

-- Staff/admin can upload signed waivers for users
CREATE POLICY "staff_upload_signed_docs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'pool-access-docs'
  AND EXISTS (
    SELECT 1
    FROM user_roles ur
    WHERE ur.user_id = auth.uid()
    AND ur.role IN ('admin', 'staff')
  )
);

COMMIT;
