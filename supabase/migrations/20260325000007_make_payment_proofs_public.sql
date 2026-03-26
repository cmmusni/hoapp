-- Make payment-proofs bucket public so uploaded images can be displayed via public URLs
-- Storage RLS policies still control who can upload/delete files
UPDATE storage.buckets SET public = true WHERE id = 'payment-proofs';
