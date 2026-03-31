-- Create a security-definer function to let admins look up user emails
-- from auth.users (which is not directly queryable from the client).
-- Only community staff can call this.

CREATE OR REPLACE FUNCTION get_community_user_emails(p_community_id UUID)
RETURNS TABLE (user_id UUID, email TEXT, display_name TEXT) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify caller is staff of this community
  IF NOT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
      AND user_roles.community_id = p_community_id
      AND user_roles.role IN ('community_admin', 'hoa_officer')
  ) THEN
    RAISE EXCEPTION 'Only community staff can look up user emails';
  END IF;

  RETURN QUERY
  SELECT 
    au.id AS user_id,
    au.email::TEXT AS email,
    COALESCE(
      p.full_name,
      au.raw_user_meta_data->>'full_name',
      split_part(au.email, '@', 1)
    ) AS display_name
  FROM user_roles ur
  JOIN auth.users au ON au.id = ur.user_id
  LEFT JOIN profiles p ON p.user_id = ur.user_id AND p.community_id = ur.community_id
  WHERE ur.community_id = p_community_id;
END;
$$;
