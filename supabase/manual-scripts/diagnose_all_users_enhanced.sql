-- Enhanced Diagnostic: Show ALL users and their status including pending metadata
-- Run this in Supabase Studio SQL Editor to see which users need fixing

-- Detailed view with metadata check
SELECT 
    u.email,
    u.created_at as user_created_at,
    u.email_confirmed_at,
    CASE 
        WHEN u.email_confirmed_at IS NOT NULL THEN 'Yes'
        ELSE 'No'
    END as email_confirmed,
    u.raw_user_meta_data->>'community_slug' as pending_community,
    u.raw_user_meta_data->>'unit_number' as pending_unit,
    CASE 
        WHEN hm.id IS NOT NULL THEN 'Yes'
        ELSE 'No'
    END as has_household,
    hm.member_role,
    CASE 
        WHEN ur.id IS NOT NULL THEN 'Yes'
        ELSE 'No'
    END as has_role,
    c.name as community,
    un.unit_no as unit,
    ur.role,
    CASE
        -- Pending signup (has metadata but no assignment yet)
        WHEN u.raw_user_meta_data->>'community_slug' IS NOT NULL 
             AND u.raw_user_meta_data->>'unit_number' IS NOT NULL
             AND hm.id IS NULL
             AND u.email_confirmed_at IS NOT NULL
        THEN '🔄 PENDING: Confirmed email, needs to login to complete assignment'
        
        WHEN u.raw_user_meta_data->>'community_slug' IS NOT NULL 
             AND u.raw_user_meta_data->>'unit_number' IS NOT NULL
             AND hm.id IS NULL
             AND u.email_confirmed_at IS NULL
        THEN '📧 PENDING: Awaiting email confirmation'
        
        -- Has unit but no role
        WHEN hm.id IS NOT NULL AND ur.id IS NULL 
        THEN '⚠️ NEEDS FIX: Has unit but no role'
        
        -- Regular user without community
        WHEN hm.id IS NULL AND ur.id IS NULL 
             AND u.raw_user_meta_data->>'community_slug' IS NULL
        THEN 'ℹ️ Regular user (no community)'
        
        -- Properly configured
        WHEN hm.id IS NOT NULL AND ur.id IS NOT NULL 
        THEN '✅ Properly configured'
        
        -- Has role but no unit (unusual)
        WHEN hm.id IS NULL AND ur.id IS NOT NULL 
        THEN '⚠️ Has role but no unit (unusual)'
        
        ELSE '❓ Unknown state'
    END as status
FROM auth.users u
LEFT JOIN public.household_members hm ON hm.user_id = u.id
LEFT JOIN public.user_roles ur ON ur.user_id = u.id AND ur.community_id = hm.community_id
LEFT JOIN public.communities c ON c.id = hm.community_id
LEFT JOIN public.units un ON un.id = hm.unit_id
ORDER BY 
    CASE 
        -- Priority: Show problems first
        WHEN hm.id IS NOT NULL AND ur.id IS NULL THEN 1  -- Needs fix (has unit, no role)
        WHEN u.raw_user_meta_data->>'community_slug' IS NOT NULL 
             AND hm.id IS NULL 
             AND u.email_confirmed_at IS NOT NULL THEN 2  -- Pending login
        WHEN u.raw_user_meta_data->>'community_slug' IS NOT NULL 
             AND hm.id IS NULL 
             AND u.email_confirmed_at IS NULL THEN 3  -- Pending email confirmation
        WHEN hm.id IS NOT NULL AND ur.id IS NOT NULL THEN 4  -- Properly configured
        WHEN hm.id IS NULL AND ur.id IS NULL THEN 5  -- Regular users
        ELSE 6
    END,
    u.email;

-- Summary count by status
SELECT 
    status,
    COUNT(*) as user_count
FROM (
    SELECT 
        u.email,
        CASE
            -- Pending signup (has metadata but no assignment yet)
            WHEN u.raw_user_meta_data->>'community_slug' IS NOT NULL 
                 AND u.raw_user_meta_data->>'unit_number' IS NOT NULL
                 AND hm.id IS NULL
                 AND u.email_confirmed_at IS NOT NULL
            THEN 'Pending: Confirmed email, needs to login'
            
            WHEN u.raw_user_meta_data->>'community_slug' IS NOT NULL 
                 AND u.raw_user_meta_data->>'unit_number' IS NOT NULL
                 AND hm.id IS NULL
                 AND u.email_confirmed_at IS NULL
            THEN 'Pending: Awaiting email confirmation'
            
            WHEN hm.id IS NOT NULL AND ur.id IS NULL 
            THEN 'Needs Fix: Has unit but no role'
            
            WHEN hm.id IS NULL AND ur.id IS NULL 
                 AND u.raw_user_meta_data->>'community_slug' IS NULL
            THEN 'Regular user (no community)'
            
            WHEN hm.id IS NOT NULL AND ur.id IS NOT NULL 
            THEN 'Properly configured'
            
            WHEN hm.id IS NULL AND ur.id IS NOT NULL 
            THEN 'Has role but no unit (unusual)'
            
            ELSE 'Unknown state'
        END as status
    FROM auth.users u
    LEFT JOIN public.household_members hm ON hm.user_id = u.id
    LEFT JOIN public.user_roles ur ON ur.user_id = u.id AND ur.community_id = hm.community_id
) subquery
GROUP BY status
ORDER BY 
    CASE 
        WHEN status LIKE 'Needs Fix%' THEN 1
        WHEN status LIKE 'Pending: Confirmed%' THEN 2
        WHEN status LIKE 'Pending: Awaiting%' THEN 3
        WHEN status = 'Properly configured' THEN 4
        WHEN status = 'Regular user (no community)' THEN 5
        ELSE 6
    END;

-- Additional check: Users with stale metadata (assigned but metadata not cleared)
SELECT 
    u.email,
    c.name as assigned_community,
    un.unit_no as assigned_unit,
    u.raw_user_meta_data->>'community_slug' as metadata_community,
    u.raw_user_meta_data->>'unit_number' as metadata_unit,
    '⚠️ Stale metadata (should be cleared)' as issue
FROM auth.users u
JOIN public.household_members hm ON hm.user_id = u.id
JOIN public.communities c ON c.id = hm.community_id
JOIN public.units un ON un.id = hm.unit_id
WHERE u.raw_user_meta_data->>'community_slug' IS NOT NULL 
   OR u.raw_user_meta_data->>'unit_number' IS NOT NULL;
