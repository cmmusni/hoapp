-- ========================================
-- HOApp Database Reset Script (SQL Version)
-- ========================================
-- This SQL script will drop all tables and recreate them
-- WARNING: This will DELETE ALL DATA permanently!
-- ========================================

BEGIN;

-- ========================================
-- DROP ALL TABLES
-- ========================================

-- Drop views first
DROP VIEW IF EXISTS violations_public CASCADE;

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS notification_tokens CASCADE;
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS pool_access_registrations CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS invoices CASCADE;
DROP TABLE IF EXISTS amenity_bookings CASCADE;
DROP TABLE IF EXISTS amenities CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS tickets CASCADE;
DROP TABLE IF EXISTS violations CASCADE;
DROP TABLE IF EXISTS announcements CASCADE;
DROP TABLE IF EXISTS household_members CASCADE;
DROP TABLE IF EXISTS invites CASCADE;
DROP TABLE IF EXISTS platform_roles CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
DROP TABLE IF EXISTS units CASCADE;
DROP TABLE IF EXISTS buildings CASCADE;
DROP TABLE IF EXISTS communities CASCADE;

-- ========================================
-- CLEAN STORAGE BUCKETS
-- ========================================

-- Delete all files from storage buckets
DELETE FROM storage.objects WHERE bucket_id IN (
  'payment_proofs', 
  'receipts', 
  'pool_registrations',
  'violation_photos',
  'pool_access_docs'
);

-- Note: We keep the buckets themselves as they have policies attached

COMMIT;

-- ========================================
-- INSTRUCTIONS
-- ========================================
-- After running this script, you need to run the migrations to recreate the schema:
-- 
-- For local development:
--   supabase db reset
-- 
-- Or apply migrations manually:
--   supabase migration up
-- 
-- For remote (production/staging):
--   supabase db push
-- ========================================
