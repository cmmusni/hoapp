-- Add 'maintenance' to the user_roles role CHECK constraint
ALTER TABLE user_roles DROP CONSTRAINT IF EXISTS user_roles_role_check;
ALTER TABLE user_roles ADD CONSTRAINT user_roles_role_check
  CHECK (role IN ('community_admin', 'hoa_officer', 'guard', 'resident', 'maintenance'));
