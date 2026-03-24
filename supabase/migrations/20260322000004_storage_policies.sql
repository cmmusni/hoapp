-- ========================================
-- STORAGE BUCKETS & POLICIES
-- ========================================

-- Create storage buckets
INSERT INTO storage.buckets (id, name, public) VALUES
  ('payment_proofs', 'payment_proofs', false),
  ('receipts', 'receipts', false),
  ('pool_registrations', 'pool_registrations', false)
ON CONFLICT (id) DO NOTHING;

-- ========================================
-- PAYMENT PROOFS BUCKET
-- Path: payment_proofs/{community_id}/{user_id}/{payment_id}.jpg
-- ========================================

CREATE POLICY "Payment proofs are readable by owner or staff"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'payment_proofs' AND
    (
      -- Owner can read their own proofs
      (storage.foldername(name))[2] = auth.uid()::text OR
      -- Staff can read proofs in their community
      EXISTS (
        SELECT 1 FROM user_roles ur
        WHERE ur.user_id = auth.uid()
          AND ur.community_id = ((storage.foldername(name))[1])::uuid
          AND ur.role IN ('community_admin', 'hoa_officer')
      )
    )
  );

CREATE POLICY "Payment proofs are insertable by owner"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'payment_proofs' AND
    (storage.foldername(name))[2] = auth.uid()::text
  );

CREATE POLICY "Payment proofs are deletable by staff"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'payment_proofs' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );

-- ========================================
-- RECEIPTS BUCKET
-- Path: receipts/{community_id}/{invoice_id}.pdf
-- ========================================

CREATE POLICY "Receipts are readable by unit members or staff"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'receipts' AND
    (
      -- Staff can read all receipts in their community
      EXISTS (
        SELECT 1 FROM user_roles ur
        WHERE ur.user_id = auth.uid()
          AND ur.community_id = ((storage.foldername(name))[1])::uuid
          AND ur.role IN ('community_admin', 'hoa_officer')
      ) OR
      -- Unit members can read receipts for their unit's invoices
      EXISTS (
        SELECT 1 FROM invoices inv
        JOIN household_members hm ON hm.unit_id = inv.unit_id
        WHERE inv.id = ((storage.foldername(name))[2])::uuid
          AND hm.user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Receipts are insertable by staff"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'receipts' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );

CREATE POLICY "Receipts are deletable by staff"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'receipts' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );

-- ========================================
-- POOL REGISTRATIONS BUCKET
-- Paths:
--   pool_registrations/{community_id}/{user_id}/id_{registration_id}.jpg (resident uploads)
--   pool_registrations/{community_id}/{user_id}/signed_{registration_id}.pdf (staff uploads)
-- ========================================

CREATE POLICY "Pool registrations are readable by owner or staff"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'pool_registrations' AND
    (
      -- Owner can read their own documents
      (storage.foldername(name))[2] = auth.uid()::text OR
      -- Staff can read all pool registrations in their community
      EXISTS (
        SELECT 1 FROM user_roles ur
        WHERE ur.user_id = auth.uid()
          AND ur.community_id = ((storage.foldername(name))[1])::uuid
          AND ur.role IN ('community_admin', 'hoa_officer')
      )
    )
  );

CREATE POLICY "Pool registration IDs are insertable by owner"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'pool_registrations' AND
    (storage.foldername(name))[2] = auth.uid()::text AND
    (storage.filename(name)) LIKE 'id_%'
  );

CREATE POLICY "Pool registration signed docs are insertable by staff"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'pool_registrations' AND
    (storage.filename(name)) LIKE 'signed_%' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );

CREATE POLICY "Pool registrations are deletable by staff"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'pool_registrations' AND
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.community_id = ((storage.foldername(name))[1])::uuid
        AND ur.role IN ('community_admin', 'hoa_officer')
    )
  );
