-- Delete users who have no community and no household membership
-- Run this in Supabase Studio SQL Editor
-- WARNING: This will permanently delete users who signed up but aren't assigned to any community

-- ============================================================================
-- Step 1: Preview which users will be deleted
-- ============================================================================
SELECT 
    u.email,
    u.created_at,
    'Will be deleted' as action
FROM auth.users u
LEFT JOIN public.household_members hm ON hm.user_id = u.id
LEFT JOIN public.user_roles ur ON ur.user_id = u.id
WHERE hm.id IS NULL 
  AND ur.id IS NULL
ORDER BY u.created_at DESC;

-- ============================================================================
-- Step 2: Delete users without community/household (uncomment to execute)
-- ============================================================================
-- UNCOMMENT THE LINES BELOW TO ACTUALLY DELETE

/*
DELETE FROM auth.users
WHERE id IN (
    SELECT u.id
    FROM auth.users u
    LEFT JOIN public.household_members hm ON hm.user_id = u.id
    LEFT JOIN public.user_roles ur ON ur.user_id = u.id
    WHERE hm.id IS NULL 
      AND ur.id IS NULL
);
*/

-- ============================================================================
-- Step 3: Verify deletion (run after uncommenting and executing Step 2)
-- ============================================================================
/*
SELECT 
    COUNT(*) as remaining_users_without_community
FROM auth.users u
LEFT JOIN public.household_members hm ON hm.user_id = u.id
LEFT JOIN public.user_roles ur ON ur.user_id = u.id
WHERE hm.id IS NULL 
  AND ur.id IS NULL;
*/
