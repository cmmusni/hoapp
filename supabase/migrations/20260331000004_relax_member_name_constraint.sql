-- Relax the check constraint so member_name can be set on registered users too.
-- This allows admins/staff/primary to edit the displayed name for any member.
ALTER TABLE household_members
  DROP CONSTRAINT IF EXISTS household_members_user_or_name_check;

ALTER TABLE household_members
  ADD CONSTRAINT household_members_user_or_name_check
  CHECK (
    user_id IS NOT NULL OR member_name IS NOT NULL
  );
