-- Add a specific user to Elevé Homes community
-- Run this in Supabase Studio SQL Editor
-- This adds the user to user_roles (but NOT household_members since no unit is specified)

-- STEP 1: Preview - Find the user first
-- Replace 'user@example.com' with the actual email
SELECT 
    u.id,
    u.email,
    u.created_at,
    u.email_confirmed_at,
    u.raw_user_meta_data->>'full_name' as full_name,
    CASE 
        WHEN ur.id IS NOT NULL THEN 'Already has role in Elevé Homes'
        WHEN hm.id IS NOT NULL THEN 'Already has unit in Elevé Homes'
        ELSE 'Ready to add'
    END as status
FROM auth.users u
LEFT JOIN public.user_roles ur ON ur.user_id = u.id AND ur.community_id = '9b9fff03-d5c7-4c2b-99c9-a1cdba6bad02'
LEFT JOIN public.household_members hm ON hm.user_id = u.id AND hm.community_id = '9b9fff03-d5c7-4c2b-99c9-a1cdba6bad02'
WHERE u.email = 'user@example.com';  -- ⚠️ REPLACE THIS EMAIL

-- STEP 2: Add user to user_roles for Elevé Homes
-- Replace 'user@example.com' AND choose role: 'resident', 'staff', or 'admin'
INSERT INTO public.user_roles (user_id, community_id, role, created_at)
SELECT 
    u.id,
    '9b9fff03-d5c7-4c2b-99c9-a1cdba6bad02'::uuid as community_id,
    'resident' as role,  -- ⚠️ REPLACE WITH: 'resident', 'staff', or 'admin'
    NOW()
FROM auth.users u
WHERE u.email = 'user@example.com'  -- ⚠️ REPLACE THIS EMAIL
AND NOT EXISTS (
    SELECT 1 FROM public.user_roles ur 
    WHERE ur.user_id = u.id 
    AND ur.community_id = '9b9fff03-d5c7-4c2b-99c9-a1cdba6bad02'
);

-- STEP 3: Verify the user was added
SELECT 
    u.email,
    c.name as community,
    ur.role,
    ur.created_at as added_at,
    '✅ User added to community' as status
FROM auth.users u
JOIN public.user_roles ur ON ur.user_id = u.id
JOIN public.communities c ON c.id = ur.community_id
WHERE u.email = 'user@example.com'  -- ⚠️ REPLACE THIS EMAIL
AND ur.community_id = '9b9fff03-d5c7-4c2b-99c9-a1cdba6bad02';

-- NOTE: This script adds the user to user_roles only (not household_members)
-- If you want to also assign them to a specific unit, use the script below:
/*
-- OPTIONAL: Add to household_members with unit assignment
-- First, find available units:
SELECT id, unit_no FROM public.units 
WHERE community_id = '9b9fff03-d5c7-4c2b-99c9-a1cdba6bad02' 
ORDER BY unit_no;

-- Then insert with the chosen unit_id:
INSERT INTO public.household_members (user_id, unit_id, community_id, member_role, created_at)
SELECT 
    u.id,
    'UNIT_ID_HERE'::uuid,  -- ⚠️ REPLACE WITH ACTUAL UNIT ID
    '9b9fff03-d5c7-4c2b-99c9-a1cdba6bad02'::uuid,
    'primary',
    NOW()
FROM auth.users u
WHERE u.email = 'user@example.com'  -- ⚠️ REPLACE THIS EMAIL
AND NOT EXISTS (
    SELECT 1 FROM public.household_members hm
    WHERE hm.user_id = u.id 
    AND hm.community_id = '9b9fff03-d5c7-4c2b-99c9-a1cdba6bad02'
);
*/
