-- Backfill missing profiles for users who have roles but no profile row.
-- Uses auth.users email and metadata to populate name and email.

INSERT INTO profiles (user_id, community_id, full_name, email)
SELECT
  ur.user_id,
  ur.community_id,
  COALESCE(
    au.raw_user_meta_data->>'full_name',
    split_part(au.email, '@', 1),
    'User'
  ) AS full_name,
  au.email
FROM user_roles ur
JOIN auth.users au ON au.id = ur.user_id
LEFT JOIN profiles p
  ON p.user_id = ur.user_id AND p.community_id = ur.community_id
WHERE p.user_id IS NULL
ON CONFLICT (user_id, community_id) DO NOTHING;

-- Also backfill full_name for profiles that exist but have NULL/empty full_name
UPDATE profiles
SET full_name = COALESCE(
  au.raw_user_meta_data->>'full_name',
  split_part(au.email, '@', 1),
  'User'
)
FROM auth.users au
WHERE profiles.user_id = au.id
  AND (profiles.full_name IS NULL OR profiles.full_name = '');

-- Also backfill email for profiles that have NULL email
UPDATE profiles
SET email = au.email
FROM auth.users au
WHERE profiles.user_id = au.id
  AND profiles.email IS NULL
  AND au.email IS NOT NULL;
