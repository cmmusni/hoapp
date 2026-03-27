-- ============================================================
-- Delete a provisioned beta user and their community
-- ============================================================
-- Usage: Replace 'test@example.com' below with the beta user's
--        email, then run this in the Supabase SQL Editor.
-- ============================================================

DO $$
DECLARE
  v_email text := 'test@example.com';  -- ← CHANGE THIS
  v_request record;
  v_user_id uuid;
  v_community_id uuid;
BEGIN
  -- 1. Find the beta access request
  SELECT * INTO v_request
  FROM beta_access_requests
  WHERE email = v_email
  LIMIT 1;

  IF v_request IS NULL THEN
    RAISE EXCEPTION 'No beta_access_requests found for email: %', v_email;
  END IF;

  v_user_id := v_request.provisioned_user_id;
  v_community_id := v_request.provisioned_community_id;

  RAISE NOTICE '--- Found beta request ---';
  RAISE NOTICE 'Request ID   : %', v_request.id;
  RAISE NOTICE 'Name         : %', v_request.name;
  RAISE NOTICE 'Email        : %', v_request.email;
  RAISE NOTICE 'Status       : %', v_request.status;
  RAISE NOTICE 'User ID      : %', v_user_id;
  RAISE NOTICE 'Community ID : %', v_community_id;
  RAISE NOTICE '--------------------------';

  -- 2. Delete audit logs for the community
  IF v_community_id IS NOT NULL THEN
    DELETE FROM audit_logs WHERE community_id = v_community_id;
    RAISE NOTICE 'Deleted audit_logs for community %', v_community_id;
  END IF;

  -- 3. Delete user_roles
  IF v_user_id IS NOT NULL AND v_community_id IS NOT NULL THEN
    DELETE FROM user_roles WHERE user_id = v_user_id AND community_id = v_community_id;
    RAISE NOTICE 'Deleted user_roles for user % in community %', v_user_id, v_community_id;
  END IF;

  -- 4. Delete profiles
  IF v_user_id IS NOT NULL AND v_community_id IS NOT NULL THEN
    DELETE FROM profiles WHERE user_id = v_user_id AND community_id = v_community_id;
    RAISE NOTICE 'Deleted profiles for user % in community %', v_user_id, v_community_id;
  END IF;

  -- 5. Delete the community
  IF v_community_id IS NOT NULL THEN
    DELETE FROM communities WHERE id = v_community_id;
    RAISE NOTICE 'Deleted community %', v_community_id;
  END IF;

  -- 6. Delete the beta access request
  DELETE FROM beta_access_requests WHERE id = v_request.id;
  RAISE NOTICE 'Deleted beta_access_requests row %', v_request.id;

  -- 7. Delete the auth user
  IF v_user_id IS NOT NULL THEN
    DELETE FROM auth.users WHERE id = v_user_id;
    RAISE NOTICE 'Deleted auth.users row %', v_user_id;
  END IF;

  RAISE NOTICE '✅ Done — all data for % has been removed.', v_email;
END $$;
