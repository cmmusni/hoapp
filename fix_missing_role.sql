-- Quick fix: Add missing user_roles for kliffzkii@gmail.com
-- Run this in Supabase Studio SQL Editor

INSERT INTO public.user_roles (user_id, community_id, role, created_at)
SELECT 
    u.id as user_id,
    hm.community_id,
    'resident' as role,
    NOW() as created_at
FROM auth.users u
JOIN public.household_members hm ON hm.user_id = u.id
WHERE u.email = 'kliffzkii@gmail.com'
AND NOT EXISTS (
    SELECT 1 FROM public.user_roles ur 
    WHERE ur.user_id = u.id 
    AND ur.community_id = hm.community_id
);

-- Verify the fix
SELECT 
    u.email,
    c.name as community,
    un.unit_no as unit,
    ur.role
FROM auth.users u
JOIN public.household_members hm ON hm.user_id = u.id
JOIN public.communities c ON c.id = hm.community_id
JOIN public.units un ON un.id = hm.unit_id
JOIN public.user_roles ur ON ur.user_id = u.id AND ur.community_id = hm.community_id
WHERE u.email = 'kliffzkii@gmail.com';
