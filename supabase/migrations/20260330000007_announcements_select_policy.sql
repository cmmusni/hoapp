-- Migration: Allow community members to read announcements
-- Description: Add SELECT policy so residents can view announcements
-- Date: 2026-03-30

-- ============================================================================
-- Allow community members to read announcements
-- ============================================================================
DROP POLICY IF EXISTS "announcements_select_members" ON public.announcements;

CREATE POLICY "announcements_select_members"
ON public.announcements
FOR SELECT
TO authenticated
USING (
  community_id IN (
    SELECT community_id 
    FROM public.household_members 
    WHERE user_id = auth.uid()
  )
  OR
  community_id IN (
    SELECT community_id 
    FROM public.user_roles 
    WHERE user_id = auth.uid()
  )
);

COMMENT ON POLICY "announcements_select_members" ON public.announcements IS
'Allows authenticated users to read announcements from communities they belong to (via household_members or user_roles)';
