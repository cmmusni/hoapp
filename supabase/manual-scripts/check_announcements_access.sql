-- Check RLS policies on announcements table
-- Run this in Supabase Studio SQL Editor

-- Check current policies
SELECT 
    tablename,
    policyname,
    roles::text[],
    cmd,
    CASE WHEN qual IS NOT NULL THEN 'Has USING' ELSE 'No USING' END as using_clause
FROM pg_policies
WHERE tablename = 'announcements'
ORDER BY policyname;

-- Check if there are any announcements for eleve-homes
SELECT 
    id,
    title,
    community_id,
    created_at
FROM public.announcements
WHERE community_id = '9b9fff03-d5c7-4c2b-99c9-a1cdba6bad02'
ORDER BY created_at DESC;

-- Test if a specific user can read announcements
-- Replace with actual user email below
SELECT 
    a.id,
    a.title,
    a.community_id,
    c.name as community_name
FROM public.announcements a
JOIN public.communities c ON c.id = a.community_id
WHERE a.community_id IN (
    SELECT community_id 
    FROM public.household_members 
    WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mariellecasbadillo30@gmail.com')
);
