-- Migration: Allow primary household members to manage members in their unit
-- This enables primary members to add and remove other members from their unit.

-- Allow primary members to INSERT new members into their unit
CREATE POLICY "Primary members can add members to their unit"
ON public.household_members
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM household_members hm
    WHERE hm.unit_id = unit_id
      AND hm.user_id = auth.uid()
      AND hm.member_role = 'primary'
  )
);

-- Allow primary members to DELETE members from their unit (but not themselves)
CREATE POLICY "Primary members can remove members from their unit"
ON public.household_members
FOR DELETE
TO authenticated
USING (
  user_id IS DISTINCT FROM auth.uid()
  AND EXISTS (
    SELECT 1 FROM household_members hm
    WHERE hm.unit_id = household_members.unit_id
      AND hm.user_id = auth.uid()
      AND hm.member_role = 'primary'
  )
);
