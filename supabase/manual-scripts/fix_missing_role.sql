-- Quick fix: Add missing user_roles for users who signed up before RLS policies were fixed
-- Run this in Supabase Studio SQL Editor

-- CHANGE THIS EMAIL to the user you want to fix, or remove the WHERE clause to fix ALL users
INSERT INTO public.user_roles (user_id, community_id, role, created_at)
SELECT 
    u.id as user_id,
    hm.community_id,
    'resident' as role,
    NOW() as created_at
FROM auth.users u
JOIN public.household_members hm ON hm.user_id = u.id
WHERE u.email = 'USER_EMAIL_HERE' -- CHANGE THIS, or remove this line to fix ALL users
AND NOT EXISTS (
    SELECT 1 FROM public.user_roles ur 
    WHERE ur.user_id = u.id 
    AND ur.community_id = hm.community_id
);

-- Verify the fix (change the email to match above)
SELECT 
    u.email,
    c.name as community,
    un.unit_no as unit,
    ur.role
FROM auth.users u
JOIN public.household_members hm ON hm.user_id = u.id
JOIN public.communities c ON c.id = hm.community_id
JOIN public.units un ON un.id = hm.unit_id
LEFT JOIN public.user_roles ur ON ur.user_id = u.id AND ur.community_id = hm.community_id
WHERE u.email = 'USER_EMAIL_HERE'; -- CHANGE THIS
