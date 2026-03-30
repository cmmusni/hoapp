-- Clean up stale metadata for users who are already properly assigned
-- This affects users who signed up before metadata cleanup was implemented
-- Safe to run - only clears metadata for users already assigned to units

-- Preview: Show which users will be affected
SELECT 
    u.id,
    u.email,
    c.name as assigned_community,
    un.unit_no as assigned_unit,
    hm.member_role,
    u.raw_user_meta_data->>'community_slug' as stale_community_slug,
    u.raw_user_meta_data->>'unit_number' as stale_unit_number,
    'Will clear metadata' as action
FROM auth.users u
JOIN public.household_members hm ON hm.user_id = u.id
JOIN public.communities c ON c.id = hm.community_id
JOIN public.units un ON un.id = hm.unit_id
WHERE u.raw_user_meta_data->>'community_slug' IS NOT NULL 
   OR u.raw_user_meta_data->>'unit_number' IS NOT NULL
ORDER BY u.email;

-- Count
SELECT COUNT(*) as users_with_stale_metadata
FROM auth.users u
JOIN public.household_members hm ON hm.user_id = u.id
WHERE u.raw_user_meta_data->>'community_slug' IS NOT NULL 
   OR u.raw_user_meta_data->>'unit_number' IS NOT NULL;

-- CLEANUP: Clear stale metadata
-- Run this to clean up the metadata for already-assigned users
-- This is safe because users are already properly assigned to their units

DO $$
DECLARE
    user_record RECORD;
    updated_count INTEGER := 0;
BEGIN
    -- Loop through users with stale metadata who are already assigned
    FOR user_record IN 
        SELECT DISTINCT u.id, u.email
        FROM auth.users u
        JOIN public.household_members hm ON hm.user_id = u.id
        WHERE u.raw_user_meta_data->>'community_slug' IS NOT NULL 
           OR u.raw_user_meta_data->>'unit_number' IS NOT NULL
    LOOP
        -- Clear the community_slug and unit_number from metadata
        -- Keep other metadata like full_name
        UPDATE auth.users
        SET raw_user_meta_data = 
            raw_user_meta_data 
            - 'community_slug'
            - 'unit_number'
        WHERE id = user_record.id;
        
        updated_count := updated_count + 1;
        
        RAISE NOTICE 'Cleared metadata for: %', user_record.email;
    END LOOP;
    
    RAISE NOTICE 'Total users updated: %', updated_count;
END $$;

-- Verify: Check that metadata was cleared
SELECT 
    u.email,
    u.raw_user_meta_data->>'full_name' as full_name,
    u.raw_user_meta_data->>'community_slug' as community_slug,
    u.raw_user_meta_data->>'unit_number' as unit_number,
    c.name as assigned_community,
    un.unit_no as assigned_unit,
    CASE 
        WHEN u.raw_user_meta_data->>'community_slug' IS NULL 
             AND u.raw_user_meta_data->>'unit_number' IS NULL
        THEN '✅ Metadata cleared'
        ELSE '⚠️ Still has metadata'
    END as status
FROM auth.users u
JOIN public.household_members hm ON hm.user_id = u.id
JOIN public.communities c ON c.id = hm.community_id  
JOIN public.units un ON un.id = hm.unit_id
ORDER BY u.email;
