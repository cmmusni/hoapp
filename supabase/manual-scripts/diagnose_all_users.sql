-- Diagnostic: Show ALL users and their status
-- Run this in Supabase Studio SQL Editor to see which users need fixing

SELECT 
    u.email,
    u.created_at as user_created_at,
    CASE 
        WHEN hm.id IS NOT NULL THEN 'Yes'
        ELSE 'No'
    END as has_household,
    CASE 
        WHEN ur.id IS NOT NULL THEN 'Yes'
        ELSE 'No'
    END as has_role,
    c.name as community,
    un.unit_no as unit,
    ur.role,
    CASE
        WHEN hm.id IS NOT NULL AND ur.id IS NULL THEN '⚠️ NEEDS FIX: Has unit but no role'
        WHEN hm.id IS NULL AND ur.id IS NULL THEN 'ℹ️ Regular user (no community)'
        WHEN hm.id IS NOT NULL AND ur.id IS NOT NULL THEN '✅ Properly configured'
        WHEN hm.id IS NULL AND ur.id IS NOT NULL THEN '⚠️ Has role but no unit (unusual)'
        ELSE 'Unknown'
    END as status
FROM auth.users u
LEFT JOIN public.household_members hm ON hm.user_id = u.id
LEFT JOIN public.user_roles ur ON ur.user_id = u.id AND ur.community_id = hm.community_id
LEFT JOIN public.communities c ON c.id = hm.community_id
LEFT JOIN public.units un ON un.id = hm.unit_id
ORDER BY 
    CASE 
        WHEN hm.id IS NOT NULL AND ur.id IS NULL THEN 1  -- Needs fix first
        WHEN hm.id IS NOT NULL AND ur.id IS NOT NULL THEN 2  -- Properly configured
        WHEN hm.id IS NULL AND ur.id IS NULL THEN 3  -- Regular users
        ELSE 4
    END,
    u.email;

-- Summary count
SELECT 
    status,
    COUNT(*) as user_count
FROM (
    SELECT 
        u.email,
        CASE
            WHEN hm.id IS NOT NULL AND ur.id IS NULL THEN 'Needs Fix (has unit, no role)'
            WHEN hm.id IS NULL AND ur.id IS NULL THEN 'Regular user (no community)'
            WHEN hm.id IS NOT NULL AND ur.id IS NOT NULL THEN 'Properly configured'
            WHEN hm.id IS NULL AND ur.id IS NOT NULL THEN 'Has role but no unit (unusual)'
            ELSE 'Unknown'
        END as status
    FROM auth.users u
    LEFT JOIN public.household_members hm ON hm.user_id = u.id
    LEFT JOIN public.user_roles ur ON ur.user_id = u.id AND ur.community_id = hm.community_id
) subquery
GROUP BY status
ORDER BY user_count DESC;
