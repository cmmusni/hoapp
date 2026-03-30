-- Configure community_admin user without unit assignment
-- This is for community administrators who shouldn't have household_members records
-- Valid roles: 'community_admin', 'hoa_officer', 'guard', 'resident', 'maintenance'

-- Step 1: Check current status
SELECT 
    u.email,
    u.raw_user_meta_data->>'full_name' as full_name,
    u.raw_user_meta_data->>'invite_token' as invite_token,
    u.raw_user_meta_data->>'community_slug' as community_slug,
    CASE 
        WHEN hm.id IS NOT NULL THEN 'Has household (should not have)'
        ELSE 'No household (correct)'
    END as household_status,
    CASE 
        WHEN ur.id IS NOT NULL THEN ur.role
        ELSE 'No role (needs one)'
    END as current_role
FROM auth.users u
LEFT JOIN public.household_members hm ON hm.user_id = u.id
LEFT JOIN public.user_roles ur ON ur.user_id = u.id
WHERE u.email = 'mmcalcetas@gmail.com';

-- Step 2: Configure as community_admin (no unit assignment)
DO $$
DECLARE
    v_user_id UUID;
    v_community_id UUID;
BEGIN
    -- Get user ID
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE email = 'mmcalcetas@gmail.com';
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Get Elevé Homes community ID
    SELECT id INTO v_community_id
    FROM public.communities
    WHERE slug = 'eleve-homes';
    
    IF v_community_id IS NULL THEN
        RAISE EXCEPTION 'Community not found';
    END IF;
    
    -- Add community_admin role (full community administrator privileges)
    -- Check if role already exists, then update or insert
    IF EXISTS (
        SELECT 1 FROM public.user_roles 
        WHERE user_id = v_user_id AND community_id = v_community_id
    ) THEN
        -- Update existing role
        UPDATE public.user_roles
        SET role = 'community_admin'
        WHERE user_id = v_user_id AND community_id = v_community_id;
        RAISE NOTICE 'Updated role to community_admin for mmcalcetas@gmail.com';
    ELSE
        -- Insert new role
        INSERT INTO public.user_roles (
            user_id, community_id, role, created_at
        ) VALUES (
            v_user_id, v_community_id, 'community_admin', NOW()
        );
        RAISE NOTICE 'Added community_admin role for mmcalcetas@gmail.com';
    END IF;
    
    -- Clear metadata (they don't need invite token or pending signup data)
    UPDATE auth.users
    SET raw_user_meta_data = 
        raw_user_meta_data 
        - 'community_slug'
        - 'unit_number'
        - 'invite_token'
    WHERE id = v_user_id;
    
    RAISE NOTICE 'Cleared metadata';
    
    -- Mark invite as accepted if it exists
    UPDATE public.invites
    SET accepted_at = NOW()
    WHERE token = (
        SELECT raw_user_meta_data->>'invite_token' 
        FROM auth.users 
        WHERE id = v_user_id
    )
    AND accepted_at IS NULL;
    
    RAISE NOTICE 'Successfully configured mmcalcetas@gmail.com as community_admin';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error: %', SQLERRM;
        RAISE;
END $$;

-- Step 3: Verify configuration
SELECT 
    u.email,
    u.raw_user_meta_data->>'full_name' as full_name,
    ur.role,
    c.name as community,
    CASE 
        WHEN hm.id IS NOT NULL THEN '⚠️ Has household (should remove)'
        ELSE '✅ No household (correct for community_admin)'
    END as household_status,
    CASE 
        WHEN u.raw_user_meta_data->>'invite_token' IS NOT NULL THEN '⚠️ Has stale metadata'
        ELSE '✅ Metadata clean'
    END as metadata_status,
    '✅ Community admin user configured' as status
FROM auth.users u
LEFT JOIN public.user_roles ur ON ur.user_id = u.id
LEFT JOIN public.communities c ON c.id = ur.community_id
LEFT JOIN public.household_members hm ON hm.user_id = u.id
WHERE u.email = 'mmcalcetas@gmail.com';

-- Optional: If they accidentally have a household_members record, remove it
-- Uncomment this section if needed:
/*
DELETE FROM public.household_members
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mmcalcetas@gmail.com');
*/
