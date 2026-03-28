-- ========================================
-- SEED DATA FOR DEMO
-- ========================================

-- This seed file creates basic community structure.
-- Users must be created via signup in the app, as they require Supabase Auth.

-- Create community: Elevé Homes
INSERT INTO communities (id, name, slug, address, settings) VALUES
  (
    '11111111-1111-1111-1111-111111111111',
    'Elevé Homes',
    'eleve-homes',
    '123 Main Street, Metro Manila, Philippines',
    '{
      "brand": {
        "primary": "#215E3F",
        "surface": "#ECEFF1"
      },
      "logo_url": null
    }'::jsonb
  )
ON CONFLICT (slug) DO NOTHING;

-- Create sample units
INSERT INTO units (id, community_id, unit_no, unit_type) VALUES
  ('00000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Unit 401', 'residential'),
  ('00000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Unit 402', 'residential'),
  ('00000003-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'Unit 407', 'residential'),
  ('00000004-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'Unit 501', 'residential'),
  ('00000005-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'Unit 502', 'residential')
ON CONFLICT (community_id, unit_no) DO NOTHING;

-- Create amenity: Pool + Function Room
INSERT INTO amenities (id, community_id, name, rules) VALUES
  (
    '0a111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'Pool + Function Room',
    '{
      "unit": "day",
      "open": "08:00",
      "close": "22:00",
      "price": 6000,
      "currency": "PHP",
      "allow_same_day": false,
      "max_days_ahead": 60
    }'::jsonb
  )
ON CONFLICT DO NOTHING;

-- ========================================
-- NOTE: User-dependent data removed
-- ========================================
-- To add demo users:
-- 1. Sign up via the app (e.g., admin@eleve.test, officer@eleve.test, resident@eleve.test)
-- 2. Use the admin account to invite users and assign roles
-- 3. Link residents to units via the Households page
--
-- This ensures proper Supabase Auth integration and profile creation.
-- ========================================
