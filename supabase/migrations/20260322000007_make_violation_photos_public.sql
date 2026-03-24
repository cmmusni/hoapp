-- ========================================
-- UPDATE VIOLATION PHOTOS BUCKET TO PUBLIC
-- ========================================

-- Update the bucket to be public so images can be displayed
UPDATE storage.buckets 
SET public = true 
WHERE id = 'violation-photos';
