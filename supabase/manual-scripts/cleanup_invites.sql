-- Cleanup invites table: delete invites that are expired AND already accepted
-- These are safe to remove since the user has already been onboarded.
-- No other tables reference invites via foreign keys.

-- Step 1: Preview what will be deleted
SELECT id, email, role, invite_kind, accepted_at, expires_at, created_at
FROM invites
WHERE accepted_at IS NOT NULL
  AND expires_at < now()
ORDER BY created_at;

-- Step 2: Run the delete (uncomment below after reviewing the preview)
-- DELETE FROM invites
-- WHERE accepted_at IS NOT NULL
--   AND expires_at < now();
