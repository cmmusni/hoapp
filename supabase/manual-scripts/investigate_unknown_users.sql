-- Investigate the "Unknown state" user
-- This query helps identify edge cases that don't fit the normal patterns

SELECT 
    u.email,
    u.created_at,
    u.email_confirmed_at,
    CASE 
        WHEN u.email_confirmed_at IS NOT NULL THEN 'Yes'
        ELSE 'No'
    END as email_confirmed,
    u.raw_user_meta_data->>'full_name' as full_name,
    u.raw_user_meta_data->>'community_slug' as metadata_community,
    u.raw_user_meta_data->>'unit_number' as metadata_unit,
    u.raw_user_meta_data->>'invite_token' as has_invite_token,
    CASE 
        WHEN hm.id IS NOT NULL THEN 'Yes'
        ELSE 'No'
    END as has_household,
    hm.member_role,
    hm.community_id as household_community_id,
    CASE 
        WHEN ur.id IS NOT NULL THEN 'Yes'
        ELSE 'No'
    END as has_role,
    ur.role,
    ur.community_id as role_community_id,
    c.name as community_name,
    un.unit_no as unit_number,
    -- Detailed diagnosis
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
        
        -- Has unit but no role
        WHEN hm.id IS NOT NULL AND ur.id IS NULL 
        THEN 'Needs Fix: Has unit but no role'
        
        -- Regular user without community
        WHEN hm.id IS NULL AND ur.id IS NULL 
             AND u.raw_user_meta_data->>'community_slug' IS NULL
        THEN 'Regular user (no community)'
        
        -- Properly configured
        WHEN hm.id IS NOT NULL AND ur.id IS NOT NULL 
        THEN 'Properly configured'
        
        -- Has role but no unit (unusual)
        WHEN hm.id IS NULL AND ur.id IS NOT NULL 
        THEN 'Has role but no unit (unusual)'
        
        ELSE 'Unknown state'
    END as status,
    -- Additional diagnostics
    CASE 
        WHEN hm.id IS NULL AND ur.id IS NULL THEN 'No household and no role'
        WHEN hm.id IS NOT NULL AND ur.id IS NOT NULL AND hm.community_id != ur.community_id THEN 'Community mismatch between household and role'
        WHEN hm.id IS NOT NULL AND ur.id IS NULL THEN 'Has household but no role'
        WHEN hm.id IS NULL AND ur.id IS NOT NULL THEN 'Has role but no household'
        ELSE 'Other'
    END as issue_type,
    -- Show all metadata for debugging
    u.raw_user_meta_data as full_metadata
FROM auth.users u
LEFT JOIN public.household_members hm ON hm.user_id = u.id
LEFT JOIN public.user_roles ur ON ur.user_id = u.id AND ur.community_id = hm.community_id
LEFT JOIN public.communities c ON c.id = hm.community_id
LEFT JOIN public.units un ON un.id = hm.unit_id
WHERE 
    -- Focus on the unknown state users
    NOT (
        -- Not pending signup
        (u.raw_user_meta_data->>'community_slug' IS NOT NULL 
         AND u.raw_user_meta_data->>'unit_number' IS NOT NULL
         AND hm.id IS NULL)
        OR
        -- Not needs fix
        (hm.id IS NOT NULL AND ur.id IS NULL)
        OR
        -- Not regular user
        (hm.id IS NULL AND ur.id IS NULL 
         AND u.raw_user_meta_data->>'community_slug' IS NULL)
        OR
        -- Not properly configured
        (hm.id IS NOT NULL AND ur.id IS NOT NULL)
        OR
        -- Not has role but no unit
        (hm.id IS NULL AND ur.id IS NOT NULL)
    )
ORDER BY u.created_at DESC;
