-- Enhanced Diagnostic: Show ALL users and their full membership status
-- Checks profiles, household_members, and user_roles (mobile reads from profiles)
-- Run in Supabase Studio SQL Editor.
--
-- TIP: To inspect ONE user, set the variable below; otherwise it shows everyone.
-- Replace '' with an email like 'cristelleanneg@gmail.com' to filter.

-- ============================================================================
-- 1. PER-USER DETAIL (one row per user × profile)
-- ============================================================================
WITH params AS (SELECT lower('') AS filter_email)
SELECT
    u.email,
    u.id AS user_id,
    u.created_at AS signup_at,
    u.last_sign_in_at,
    CASE WHEN u.email_confirmed_at IS NOT NULL THEN 'Yes' ELSE 'No' END AS email_confirmed,

    -- profiles (this is what the mobile splash screen reads)
    p.community_id IS NOT NULL AS has_profile,
    c.name AS profile_community,
    c.slug AS profile_slug,

    -- household membership (unit assignment)
    hm.id IS NOT NULL AS has_household,
    hm.member_role,
    hc.name AS household_community,
    un.unit_no AS unit,

    -- role
    ur.id IS NOT NULL AS has_role,
    ur.role,

    -- pending signup metadata
    u.raw_user_meta_data->>'community_slug' AS pending_community,
    u.raw_user_meta_data->>'unit_number' AS pending_unit,

    CASE
        -- Profile present and matched with role + household → fully working
        WHEN p.community_id IS NOT NULL AND hm.id IS NOT NULL AND ur.id IS NOT NULL
            THEN '✅ Fully configured (mobile + web should both work)'

        -- Profile exists but no household/role → mobile sees community but features may break
        WHEN p.community_id IS NOT NULL AND (hm.id IS NULL OR ur.id IS NULL)
            THEN '⚠️ Profile only — missing household or role'

        -- Has household + role but NO profile row → mobile shows "Join Your Community"
        --   (this is the most likely cause of the "newly installed app" bug)
        WHEN p.community_id IS NULL AND hm.id IS NOT NULL
            THEN '🐛 BROKEN: Has household but no profile row — mobile dialog will appear'

        -- Pending email confirmation
        WHEN p.community_id IS NULL AND hm.id IS NULL
             AND u.raw_user_meta_data->>'community_slug' IS NOT NULL
             AND u.email_confirmed_at IS NULL
            THEN '📧 PENDING: awaiting email confirmation'

        -- Confirmed but never assigned
        WHEN p.community_id IS NULL AND hm.id IS NULL
             AND u.raw_user_meta_data->>'community_slug' IS NOT NULL
             AND u.email_confirmed_at IS NOT NULL
            THEN '🔄 PENDING: confirmed, needs admin to assign unit / accept invite'

        -- Truly new account, no metadata, no assignment
        WHEN p.community_id IS NULL AND hm.id IS NULL AND ur.id IS NULL
            THEN 'ℹ️ Unassigned user (no community yet)'

        ELSE '❓ Unknown state'
    END AS status
FROM auth.users u
CROSS JOIN params
LEFT JOIN public.profiles p ON p.user_id = u.id
LEFT JOIN public.communities c ON c.id = p.community_id
LEFT JOIN public.household_members hm
       ON hm.user_id = u.id
      AND (p.community_id IS NULL OR hm.community_id = p.community_id)
LEFT JOIN public.communities hc ON hc.id = hm.community_id
LEFT JOIN public.units un ON un.id = hm.unit_id
LEFT JOIN public.user_roles ur
       ON ur.user_id = u.id
      AND ur.community_id = COALESCE(p.community_id, hm.community_id)
WHERE params.filter_email = '' OR lower(u.email) = params.filter_email
ORDER BY
    CASE
        WHEN p.community_id IS NULL AND hm.id IS NOT NULL THEN 1   -- broken first
        WHEN p.community_id IS NOT NULL AND (hm.id IS NULL OR ur.id IS NULL) THEN 2
        WHEN p.community_id IS NULL AND u.raw_user_meta_data->>'community_slug' IS NOT NULL THEN 3
        WHEN p.community_id IS NOT NULL THEN 4
        ELSE 5
    END,
    u.email;

-- ============================================================================
-- 2. SUMMARY COUNT BY STATUS
-- ============================================================================
SELECT status, COUNT(*) AS user_count
FROM (
    SELECT
        CASE
            WHEN p.community_id IS NOT NULL AND hm.id IS NOT NULL AND ur.id IS NOT NULL
                THEN 'Fully configured'
            WHEN p.community_id IS NOT NULL AND (hm.id IS NULL OR ur.id IS NULL)
                THEN 'Profile only (missing household/role)'
            WHEN p.community_id IS NULL AND hm.id IS NOT NULL
                THEN 'BROKEN: household but no profile'
            WHEN p.community_id IS NULL AND hm.id IS NULL
                 AND u.raw_user_meta_data->>'community_slug' IS NOT NULL
                 AND u.email_confirmed_at IS NULL
                THEN 'Pending email confirmation'
            WHEN p.community_id IS NULL AND hm.id IS NULL
                 AND u.raw_user_meta_data->>'community_slug' IS NOT NULL
                THEN 'Pending: confirmed, awaiting assignment'
            WHEN p.community_id IS NULL AND hm.id IS NULL
                THEN 'Unassigned user (no community)'
            ELSE 'Unknown'
        END AS status
    FROM auth.users u
    LEFT JOIN public.profiles p ON p.user_id = u.id
    LEFT JOIN public.household_members hm
           ON hm.user_id = u.id
          AND (p.community_id IS NULL OR hm.community_id = p.community_id)
    LEFT JOIN public.user_roles ur
           ON ur.user_id = u.id
          AND ur.community_id = COALESCE(p.community_id, hm.community_id)
) sub
GROUP BY status
ORDER BY user_count DESC;

-- ============================================================================
-- 3. STALE METADATA (assigned but signup metadata still present)
-- ============================================================================
SELECT
    u.email,
    c.name AS assigned_community,
    un.unit_no AS assigned_unit,
    u.raw_user_meta_data->>'community_slug' AS metadata_community,
    u.raw_user_meta_data->>'unit_number' AS metadata_unit,
    '⚠️ Stale metadata (should be cleared)' AS issue
FROM auth.users u
JOIN public.household_members hm ON hm.user_id = u.id
JOIN public.communities c ON c.id = hm.community_id
JOIN public.units un ON un.id = hm.unit_id
WHERE u.raw_user_meta_data->>'community_slug' IS NOT NULL
   OR u.raw_user_meta_data->>'unit_number' IS NOT NULL;

-- ============================================================================
-- 4. ORPHAN HOUSEHOLDS — has household_member row but missing profile row
--     This is the exact data shape that triggers the mobile "Join Your Community" dialog.
-- ============================================================================
SELECT
    u.email,
    c.name AS community,
    un.unit_no AS unit,
    hm.member_role,
    hm.created_at AS household_created_at,
    'Run: INSERT INTO profiles(user_id, community_id) VALUES (''' || u.id || ''', ''' || hm.community_id || ''')' AS fix_sql
FROM auth.users u
JOIN public.household_members hm ON hm.user_id = u.id
JOIN public.communities c ON c.id = hm.community_id
JOIN public.units un ON un.id = hm.unit_id
LEFT JOIN public.profiles p
       ON p.user_id = u.id AND p.community_id = hm.community_id
WHERE p.user_id IS NULL
ORDER BY hm.created_at DESC;
