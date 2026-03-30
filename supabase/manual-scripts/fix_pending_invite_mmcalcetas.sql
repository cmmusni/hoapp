-- Fix user with pending invite token
-- This handles users who signed up via invite token but the invite wasn't processed

-- Step 1: Check the invite and see what unit they should be assigned to
SELECT 
    i.id as invite_id,
    i.token,
    i.email,
    i.unit_id,
    i.community_id,
    i.role as invite_role,
    i.accepted_at,
    i.accepted_by,
    c.name as community_name,
    u.unit_no as unit_number,
    'Pending invite' as status
FROM public.invites i
JOIN public.communities c ON c.id = i.community_id
JOIN public.units u ON u.id = i.unit_id
WHERE i.token = '587706e3-55d9-4de7-9a7a-9d487695ab23-mn7yanum';

-- Step 2: Find the user
SELECT 
    id,
    email,
    raw_user_meta_data->>'invite_token' as invite_token,
    raw_user_meta_data->>'community_slug' as community_slug
FROM auth.users
WHERE email = 'mmcalcetas@gmail.com';

-- Step 3: Accept the invite and assign to unit
-- This does what the invite acceptance flow should have done

DO $$
DECLARE
    v_user_id UUID;
    v_invite_id UUID;
    v_unit_id UUID;
    v_community_id UUID;
    v_invite_role TEXT;
BEGIN
    -- Get user ID
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE email = 'mmcalcetas@gmail.com';
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Get invite details
    SELECT 
        i.id, i.unit_id, i.community_id, i.role
    INTO 
        v_invite_id, v_unit_id, v_community_id, v_invite_role
    FROM public.invites i
    WHERE i.token = '587706e3-55d9-4de7-9a7a-9d487695ab23-mn7yanum'
      AND i.accepted_at IS NULL;
    
    IF v_invite_id IS NULL THEN
        RAISE NOTICE 'Invite not found or already accepted';
        RETURN;
    END IF;
    
    -- Check if unit already has a primary member
    DECLARE
        v_existing_primary UUID;
        v_member_role TEXT;
    BEGIN
        SELECT id INTO v_existing_primary
        FROM public.household_members
        WHERE unit_id = v_unit_id
          AND member_role = 'primary';
        
        -- If unit has primary, make this user secondary
        IF v_existing_primary IS NOT NULL THEN
            v_member_role := 'secondary';
        ELSE
            v_member_role := 'primary';
        END IF;
        
        -- Add to household_members
        INSERT INTO public.household_members (
            user_id, unit_id, community_id, member_role, created_at
        ) VALUES (
            v_user_id, v_unit_id, v_community_id, v_member_role, NOW()
        )
        ON CONFLICT DO NOTHING;
        
        RAISE NOTICE 'Added to household_members with role: %', v_member_role;
    END;
    
    -- Add user role (use invite role or default to resident)
    INSERT INTO public.user_roles (
        user_id, community_id, role, created_at
    ) VALUES (
        v_user_id, v_community_id, COALESCE(v_invite_role, 'resident'), NOW()
    )
    ON CONFLICT DO NOTHING;
    
    RAISE NOTICE 'Added user_roles with role: %', COALESCE(v_invite_role, 'resident');
    
    -- Mark invite as accepted
    UPDATE public.invites
    SET accepted_at = NOW(),
        accepted_by = v_user_id
    WHERE id = v_invite_id;
    
    RAISE NOTICE 'Marked invite as accepted';
    
    -- Clear metadata
    UPDATE auth.users
    SET raw_user_meta_data = 
        raw_user_meta_data 
        - 'community_slug'
        - 'unit_number'
        - 'invite_token'
    WHERE id = v_user_id;
    
    RAISE NOTICE 'Cleared metadata';
    RAISE NOTICE 'Successfully processed invite for mmcalcetas@gmail.com';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error: %', SQLERRM;
        RAISE;
END $$;

-- Step 4: Verify the fix
SELECT 
    u.email,
    c.name as community,
    un.unit_no as unit,
    hm.member_role,
    ur.role,
    '✅ Fixed' as status
FROM auth.users u
JOIN public.household_members hm ON hm.user_id = u.id
JOIN public.communities c ON c.id = hm.community_id
JOIN public.units un ON un.id = hm.unit_id
LEFT JOIN public.user_roles ur ON ur.user_id = u.id AND ur.community_id = hm.community_id
WHERE u.email = 'mmcalcetas@gmail.com';
