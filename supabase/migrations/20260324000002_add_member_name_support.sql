-- Migration: Support non-registered household members
-- This allows adding household members without requiring them to have user accounts

-- Step 1: Make user_id nullable in household_members (idempotent)
DO $$ 
BEGIN
  ALTER TABLE household_members ALTER COLUMN user_id DROP NOT NULL;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

-- Step 2: Add member_name column for non-registered members (idempotent)
DO $$ 
BEGIN
  ALTER TABLE household_members ADD COLUMN member_name TEXT;
EXCEPTION
  WHEN duplicate_column THEN NULL;
END $$;

-- Step 3: Add constraint to ensure either user_id OR member_name is provided
DO $$ 
BEGIN
  ALTER TABLE household_members
    ADD CONSTRAINT household_members_user_or_name_check
    CHECK (
      (user_id IS NOT NULL AND member_name IS NULL) OR 
      (user_id IS NULL AND member_name IS NOT NULL)
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Step 4: Update RLS policies to handle both cases
-- Drop existing policies
DROP POLICY IF EXISTS "Users can view household members in their community" ON household_members;
DROP POLICY IF EXISTS "Staff can manage household members" ON household_members;
DROP POLICY IF EXISTS "Primary members can manage their unit" ON household_members;
DROP POLICY IF EXISTS "View household members in community" ON household_members;
DROP POLICY IF EXISTS "Staff manage household members" ON household_members;

-- Recreate with support for null user_id (no circular dependencies)
CREATE POLICY "View household members in community"
  ON household_members FOR SELECT
  USING (
    community_id IN (
      SELECT community_id FROM user_roles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Staff manage household members"
  ON household_members FOR ALL
  USING (
    community_id IN (
      SELECT community_id FROM user_roles 
      WHERE user_id = auth.uid() 
      AND role IN ('community_admin', 'hoa_officer')
    )
  );

-- Step 5: Create index for better query performance (idempotent)
CREATE INDEX IF NOT EXISTS idx_household_members_member_name 
  ON household_members(member_name) 
  WHERE member_name IS NOT NULL;
