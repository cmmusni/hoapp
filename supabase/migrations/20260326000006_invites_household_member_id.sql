-- Add household_member_id to invites table for precise matching
-- when inviting an existing (name-only) household member to sign up
ALTER TABLE invites
  ADD COLUMN household_member_id UUID REFERENCES household_members(id) ON DELETE SET NULL;
