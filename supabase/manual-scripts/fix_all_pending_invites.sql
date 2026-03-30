-- Find and fix ALL users with pending invite tokens
-- This handles users who signed up via invite but the invite wasn't processed

-- Step 1: Find all users with unprocessed invite tokens
SELECT 
    u.email,
    u.created_at,
    u.email_confirmed_at,
    u.raw_user_meta_data->>'invite_token' as invite_token,
    u.raw_user_meta_data->>'community_slug' as community_slug,
    i.email as invite_email,
    c.name as invited_to_community,
    un.unit_no as invited_to_unit,
    i.role as invited_role,
    CASE 
        WHEN hm.id IS NOT NULL THEN 'Already has household'
        WHEN i.accepted_at IS NOT NULL THEN 'Invite already accepted'
        WHEN i.id IS NULL THEN 'Invite not found (may be expired)'
        ELSE '⚠️ Needs processing'
    END as status
FROM auth.users u
LEFT JOIN public.invites i ON i.token = u.raw_user_meta_data->>'invite_token'
LEFT JOIN public.communities c ON c.id = i.community_id
LEFT JOIN public.units un ON un.id = i.unit_id
LEFT JOIN public.household_members hm ON hm.user_id = u.id
WHERE u.raw_user_meta_data->>'invite_token' IS NOT NULL
  AND u.email_confirmed_at IS NOT NULL
ORDER BY u.created_at DESC;

-- Step 2: Process all pending invites
DO $$
DECLARE
    user_record RECORD;
    v_invite_record RECORD;
    v_existing_primary UUID;
    v_member_role TEXT;
    processed_count INTEGER := 0;
    skipped_count INTEGER := 0;
BEGIN
    -- Loop through users with invite tokens
    FOR user_record IN 
        SELECT 
            u.id as user_id,
            u.email,
            u.raw_user_meta_data->>'invite_token' as invite_token
        FROM auth.users u
        LEFT JOIN public.household_members hm ON hm.user_id = u.id
        WHERE u.raw_user_meta_data->>'invite_token' IS NOT NULL
          AND u.email_confirmed_at IS NOT NULL
          AND hm.id IS NULL  -- Not already assigned
    LOOP
        -- Get invite details
        SELECT 
            i.id as invite_id,
            i.unit_id,
            i.community_id,
            i.role,
            i.accepted_at
        INTO v_invite_record
        FROM public.invites i
        WHERE i.token = user_record.invite_token;
        
        -- Skip if invite not found or already accepted
        IF v_invite_record.invite_id IS NULL THEN
            RAISE NOTICE 'Skipping %: Invite not found', user_record.email;
            skipped_count := skipped_count + 1;
            CONTINUE;
        END IF;
        
        IF v_invite_record.accepted_at IS NOT NULL THEN
            RAISE NOTICE 'Skipping %: Invite already accepted', user_record.email;
            skipped_count := skipped_count + 1;
            CONTINUE;
        END IF;
        
        -- Determine member role (primary or secondary)
        SELECT id INTO v_existing_primary
        FROM public.household_members
        WHERE unit_id = v_invite_record.unit_id
          AND member_role = 'primary';
        
        IF v_existing_primary IS NOT NULL THEN
            v_member_role := 'secondary';
        ELSE
            v_member_role := 'primary';
        END IF;
        
        -- Add to household_members
        INSERT INTO public.household_members (
            user_id, unit_id, community_id, member_role, created_at
        ) VALUES (
            user_record.user_id,
            v_invite_record.unit_id,
            v_invite_record.community_id,
            v_member_role,
            NOW()
        )
        ON CONFLICT DO NOTHING;
        
        -- Add user role
        INSERT INTO public.user_roles (
            user_id, community_id, role, created_at
        ) VALUES (
            user_record.user_id,
            v_invite_record.community_id,
            COALESCE(v_invite_record.role, 'resident'),
            NOW()
        )
        ON CONFLICT DO NOTHING;
        
        -- Mark invite as accepted
        UPDATE public.invites
        SET accepted_at = NOW(),
            accepted_by = user_record.user_id
        WHERE id = v_invite_record.invite_id;
        
        -- Clear metadata
        UPDATE auth.users
        SET raw_user_meta_data = 
            raw_user_meta_data 
            - 'community_slug'
            - 'unit_number'
            - 'invite_token'
        WHERE id = user_record.user_id;
        
        processed_count := processed_count + 1;
        RAISE NOTICE 'Processed invite for: % (role: %)', user_record.email, v_member_role;
    END LOOP;
    
    RAISE NOTICE 'Total processed: %, Skipped: %', processed_count, skipped_count;
END $$;

-- Step 3: Verify all users are now properly configured
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
WHERE u.email IN (
    SELECT email 
    FROM auth.users 
    WHERE raw_user_meta_data->>'invite_token' IS NOT NULL
)
ORDER BY u.email;
