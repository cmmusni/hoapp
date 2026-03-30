-- Delete all references to kliffzkii@gmail.com test user
-- Run this in Supabase Studio SQL Editor

-- ============================================================================
-- Step 1: Find the user ID
-- ============================================================================
DO $$
DECLARE
    v_user_id uuid;
    v_email text := 'kliffzkii@gmail.com';
BEGIN
    -- Get the user ID
    SELECT id INTO v_user_id 
    FROM auth.users 
    WHERE email = v_email;

    IF v_user_id IS NULL THEN
        RAISE NOTICE 'User % not found', v_email;
    ELSE
        RAISE NOTICE 'Found user: % (ID: %)', v_email, v_user_id;

        -- ============================================================================
        -- Step 2: Delete from household_members
        -- ============================================================================
        DELETE FROM public.household_members
        WHERE user_id = v_user_id;
        RAISE NOTICE 'Deleted household_members records';

        -- ============================================================================
        -- Step 3: Delete from user_roles
        -- ============================================================================
        DELETE FROM public.user_roles
        WHERE user_id = v_user_id;
        RAISE NOTICE 'Deleted user_roles records';

        -- ============================================================================
        -- Step 4: Delete from auth.users (this will cascade to identities)
        -- ============================================================================
        DELETE FROM auth.users
        WHERE id = v_user_id;
        RAISE NOTICE 'Deleted user from auth.users';

        RAISE NOTICE 'Successfully deleted all references to %', v_email;
    END IF;
END $$;

-- ============================================================================
-- Verify deletion
-- ============================================================================
SELECT 
    'auth.users' as table_name,
    COUNT(*) as record_count
FROM auth.users 
WHERE email = 'kliffzkii@gmail.com'

UNION ALL

SELECT 
    'household_members' as table_name,
    COUNT(*) as record_count
FROM public.household_members hm
JOIN auth.users u ON hm.user_id = u.id
WHERE u.email = 'kliffzkii@gmail.com'

UNION ALL

SELECT 
    'user_roles' as table_name,
    COUNT(*) as record_count
FROM public.user_roles ur
JOIN auth.users u ON ur.user_id = u.id
WHERE u.email = 'kliffzkii@gmail.com';
