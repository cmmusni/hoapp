-- Check specific user metadata and assignments
-- Run this in Supabase Studio SQL Editor

-- Check the user and their metadata
SELECT 
    id,
    email,
    created_at,
    email_confirmed_at,
    raw_user_meta_data
FROM auth.users
WHERE email = 'mariellecasbadillo30@gmail.com';

-- Check if they have household_members record
SELECT 
    hm.id,
    hm.user_id,
    hm.community_id,
    c.name as community_name,
    hm.unit_id,
    u.unit_no,
    hm.member_role,
    hm.created_at
FROM public.household_members hm
JOIN public.communities c ON c.id = hm.community_id
JOIN public.units u ON u.id = hm.unit_id
WHERE hm.user_id IN (
    SELECT id FROM auth.users WHERE email = 'mariellecasbadillo30@gmail.com'
);

-- Check if they have user_roles record
SELECT 
    ur.id,
    ur.user_id,
    ur.community_id,
    c.name as community_name,
    ur.role,
    ur.created_at
FROM public.user_roles ur
JOIN public.communities c ON c.id = ur.community_id
WHERE ur.user_id IN (
    SELECT id FROM auth.users WHERE email = 'mariellecasbadillo30@gmail.com'
);
