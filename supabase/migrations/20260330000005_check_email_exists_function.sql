-- Migration: Add function to check if email exists
-- Description: Helper function for signup validation to prevent duplicate emails
-- Date: 2026-03-30

-- ============================================================================
-- Function to check if an email address already exists
-- ============================================================================
CREATE OR REPLACE FUNCTION public.check_email_exists(email_address text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM auth.users 
    WHERE email = email_address
  );
END;
$$;

COMMENT ON FUNCTION public.check_email_exists(text) IS
'Returns true if the email address already exists in auth.users, false otherwise. Used for signup validation.';

-- Grant execute permission to anonymous users (for signup page)
GRANT EXECUTE ON FUNCTION public.check_email_exists(text) TO anon;
GRANT EXECUTE ON FUNCTION public.check_email_exists(text) TO authenticated;
