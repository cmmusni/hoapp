-- Storage bucket for community logos
INSERT INTO storage.buckets (id, name, public)
VALUES ('community-logos', 'community-logos', true)
ON CONFLICT (id) DO NOTHING;

-- Community admins can upload logos for their community
CREATE POLICY "Community admins can upload logos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'community-logos'
    AND EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid()
        AND community_id = (storage.foldername(name))[1]::uuid
        AND role IN ('community_admin')
    )
  );

-- Community admins can update/replace logos
CREATE POLICY "Community admins can update logos"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'community-logos'
    AND EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid()
        AND community_id = (storage.foldername(name))[1]::uuid
        AND role IN ('community_admin')
    )
  );

-- Community admins can delete logos
CREATE POLICY "Community admins can delete logos"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'community-logos'
    AND EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid()
        AND community_id = (storage.foldername(name))[1]::uuid
        AND role IN ('community_admin')
    )
  );

-- Public read access (logos are displayed publicly on login page)
CREATE POLICY "Anyone can view community logos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'community-logos');
