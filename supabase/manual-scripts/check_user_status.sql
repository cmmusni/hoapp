-- Check what happened with kliffzkii@gmail.com
-- Run this in Supabase Studio SQL Editor

-- Find the user and their assignments
WITH user_info AS (
    SELECT id, email, raw_user_meta_data
    FROM auth.users
    WHERE email = 'kliffzkii@gmail.com'
)
SELECT 
    'User Info' as check_type,
    u.email,
    u.id::text as user_id,
    u.raw_user_meta_data->>'unit_number' as metadata_unit,
    u.raw_user_meta_data->>'community_slug' as metadata_community
FROM user_info u

UNION ALL

SELECT 
    'Household Members' as check_type,
    u.email,
    hm.unit_id::text as unit_id,
    un.unit_no as unit_number,
    c.name as community_name
FROM user_info u
JOIN public.household_members hm ON hm.user_id = u.id
JOIN public.units un ON un.id = hm.unit_id
JOIN public.communities c ON c.id = hm.community_id

UNION ALL

SELECT 
    'User Roles' as check_type,
    u.email,
    ur.role as role,
    c.name as community_name,
    NULL as extra
FROM user_info u
LEFT JOIN public.user_roles ur ON ur.user_id = u.id
LEFT JOIN public.communities c ON c.id = ur.community_id;

-- Check if there are any RLS policies blocking user_roles inserts
SELECT 
    tablename,
    policyname,
    roles::text[],
    cmd,
    with_check::text
FROM pg_policies
WHERE tablename = 'user_roles'
ORDER BY policyname;
