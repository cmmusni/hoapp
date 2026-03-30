-- List users who don't have community or user_roles
-- Run this in Supabase Studio SQL Editor

-- Show users without any community association
SELECT 
    u.id,
    u.email,
    u.created_at,
    u.email_confirmed_at,
    u.raw_user_meta_data->>'full_name' as full_name,
    'No community association' as status
FROM auth.users u
LEFT JOIN public.household_members hm ON hm.user_id = u.id
LEFT JOIN public.user_roles ur ON ur.user_id = u.id
WHERE hm.id IS NULL AND ur.id IS NULL
ORDER BY u.created_at DESC;

-- Count summary
SELECT 
    COUNT(*) as total_users_without_community
FROM auth.users u
LEFT JOIN public.household_members hm ON hm.user_id = u.id
LEFT JOIN public.user_roles ur ON ur.user_id = u.id
WHERE hm.id IS NULL AND ur.id IS NULL;
