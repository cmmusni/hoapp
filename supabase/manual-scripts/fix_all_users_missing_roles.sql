-- Fix ALL users who are missing user_roles
-- Run this in Supabase Studio SQL Editor
-- This will add resident roles for all users who have household_members but no user_roles

-- Add missing user_roles for ALL affected users
INSERT INTO public.user_roles (user_id, community_id, role, created_at)
SELECT 
    u.id as user_id,
    hm.community_id,
    'resident' as role,
    NOW() as created_at
FROM auth.users u
JOIN public.household_members hm ON hm.user_id = u.id
WHERE NOT EXISTS (
    SELECT 1 FROM public.user_roles ur 
    WHERE ur.user_id = u.id 
    AND ur.community_id = hm.community_id
);

-- Show which users were fixed
SELECT 
    u.email,
    c.name as community,
    un.unit_no as unit,
    ur.role,
    ur.created_at as role_created_at
FROM auth.users u
JOIN public.household_members hm ON hm.user_id = u.id
JOIN public.communities c ON c.id = hm.community_id
JOIN public.units un ON un.id = hm.unit_id
LEFT JOIN public.user_roles ur ON ur.user_id = u.id AND ur.community_id = hm.community_id
ORDER BY u.email;
