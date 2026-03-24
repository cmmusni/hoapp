-- Allow users to always read their own profile rows
-- This fixes getUserCommunities() returning empty for invited users
-- The existing policy "Profiles are viewable by community members" uses
-- is_community_member() which can fail in edge cases during fresh login.
CREATE POLICY "Users can read own profiles"
  ON profiles FOR SELECT
  USING (user_id = auth.uid());
