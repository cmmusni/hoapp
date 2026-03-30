-- Assign residents who have roles but no units to their proper units
-- These 4 users have resident roles but are missing household_members records
-- Valid member_role values: 'primary', 'member', 'child', 'tenant', 'other'

-- Step 1: View users needing unit assignment
SELECT 
    u.email,
    u.raw_user_meta_data->>'full_name' as full_name,
    ur.role,
    c.name as community,
    '⚠️ Needs unit assignment' as status
FROM auth.users u
JOIN public.user_roles ur ON ur.user_id = u.id
LEFT JOIN public.household_members hm ON hm.user_id = u.id
LEFT JOIN public.communities c ON c.id = ur.community_id
WHERE hm.id IS NULL 
  AND ur.role = 'resident'
ORDER BY u.email;

-- Step 2: Assign users to units
-- INSTRUCTIONS: Replace 'UNIT_NUMBER_HERE' with actual unit numbers for each user

DO $$
DECLARE
    v_community_id UUID;
    v_unit_id UUID;
    v_user_id UUID;
    v_existing_primary UUID;
    v_member_role TEXT;
BEGIN
    -- Get Elevé Homes community ID (adjust if they're in different communities)
    SELECT id INTO v_community_id
    FROM public.communities
    WHERE slug = 'eleve-homes';
    
    IF v_community_id IS NULL THEN
        RAISE EXCEPTION 'Community not found';
    END IF;

    -- ========== USER 1: longasadianajane0628@gmail.com ==========
    -- Replace 'UNIT_NUMBER_HERE' with actual unit number (e.g., '301')
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'longasadianajane0628@gmail.com';
    
    SELECT id INTO v_unit_id 
    FROM public.units 
    WHERE community_id = v_community_id 
      AND unit_no = 'UNIT_NUMBER_HERE';  -- ⚠️ REPLACE THIS
    
    IF v_unit_id IS NOT NULL THEN
        -- Check if unit already has primary member
        SELECT id INTO v_existing_primary
        FROM public.household_members
        WHERE unit_id = v_unit_id AND member_role = 'primary';
        
        v_member_role := CASE WHEN v_existing_primary IS NULL THEN 'primary' ELSE 'member' END;
        
        INSERT INTO public.household_members (user_id, unit_id, community_id, member_role, created_at)
        VALUES (v_user_id, v_unit_id, v_community_id, v_member_role, NOW());
        
        RAISE NOTICE 'Assigned longasadianajane0628@gmail.com to unit as %', v_member_role;
    ELSE
        RAISE NOTICE 'Unit not found for longasadianajane0628@gmail.com - SKIPPED';
    END IF;

    -- ========== USER 2: rainetanmontejo@gmail.com ==========
    -- Replace 'UNIT_NUMBER_HERE' with actual unit number
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'rainetanmontejo@gmail.com';
    
    SELECT id INTO v_unit_id 
    FROM public.units 
    WHERE community_id = v_community_id 
      AND unit_no = 'UNIT_NUMBER_HERE';  -- ⚠️ REPLACE THIS
    
    IF v_unit_id IS NOT NULL THEN
        SELECT id INTO v_existing_primary
        FROM public.household_members
        WHERE unit_id = v_unit_id AND member_role = 'primary';
        
        v_member_role := CASE WHEN v_existing_primary IS NULL THEN 'primary' ELSE 'member' END;
        
        INSERT INTO public.household_members (user_id, unit_id, community_id, member_role, created_at)
        VALUES (v_user_id, v_unit_id, v_community_id, v_member_role, NOW());
        
        RAISE NOTICE 'Assigned rainetanmontejo@gmail.com to unit as %', v_member_role;
    ELSE
        RAISE NOTICE 'Unit not found for rainetanmontejo@gmail.com - SKIPPED';
    END IF;

    -- ========== USER 3: sheila_s_agustin@yahoo.com ==========
    -- Replace 'UNIT_NUMBER_HERE' with actual unit number
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'sheila_s_agustin@yahoo.com';
    
    SELECT id INTO v_unit_id 
    FROM public.units 
    WHERE community_id = v_community_id 
      AND unit_no = 'UNIT_NUMBER_HERE';  -- ⚠️ REPLACE THIS
    
    IF v_unit_id IS NOT NULL THEN
        SELECT id INTO v_existing_primary
        FROM public.household_members
        WHERE unit_id = v_unit_id AND member_role = 'primary';
        
        v_member_role := CASE WHEN v_existing_primary IS NULL THEN 'primary' ELSE 'member' END;
        
        INSERT INTO public.household_members (user_id, unit_id, community_id, member_role, created_at)
        VALUES (v_user_id, v_unit_id, v_community_id, v_member_role, NOW());
        
        RAISE NOTICE 'Assigned sheila_s_agustin@yahoo.com to unit as %', v_member_role;
    ELSE
        RAISE NOTICE 'Unit not found for sheila_s_agustin@yahoo.com - SKIPPED';
    END IF;

    -- ========== USER 4: yeefrederick27@gmail.com ==========
    -- Replace 'UNIT_NUMBER_HERE' with actual unit number
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'yeefrederick27@gmail.com';
    
    SELECT id INTO v_unit_id 
    FROM public.units 
    WHERE community_id = v_community_id 
      AND unit_no = 'UNIT_NUMBER_HERE';  -- ⚠️ REPLACE THIS
    
    IF v_unit_id IS NOT NULL THEN
        SELECT id INTO v_existing_primary
        FROM public.household_members
        WHERE unit_id = v_unit_id AND member_role = 'primary';
        
        v_member_role := CASE WHEN v_existing_primary IS NULL THEN 'primary' ELSE 'member' END;
        
        INSERT INTO public.household_members (user_id, unit_id, community_id, member_role, created_at)
        VALUES (v_user_id, v_unit_id, v_community_id, v_member_role, NOW());
        
        RAISE NOTICE 'Assigned yeefrederick27@gmail.com to unit as %', v_member_role;
    ELSE
        RAISE NOTICE 'Unit not found for yeefrederick27@gmail.com - SKIPPED';
    END IF;

    RAISE NOTICE 'Unit assignment completed';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error: %', SQLERRM;
        RAISE;
END $$;

-- Step 3: Verify assignments
SELECT 
    u.email,
    u.raw_user_meta_data->>'full_name' as full_name,
    c.name as community,
    un.unit_no as unit,
    hm.member_role,
    ur.role,
    '✅ Assigned' as status
FROM auth.users u
JOIN public.user_roles ur ON ur.user_id = u.id
JOIN public.household_members hm ON hm.user_id = u.id
JOIN public.communities c ON c.id = hm.community_id
JOIN public.units un ON un.id = hm.unit_id
WHERE u.email IN (
    'longasadianajane0628@gmail.com',
    'rainetanmontejo@gmail.com',
    'sheila_s_agustin@yahoo.com',
    'yeefrederick27@gmail.com'
)
ORDER BY u.email;
