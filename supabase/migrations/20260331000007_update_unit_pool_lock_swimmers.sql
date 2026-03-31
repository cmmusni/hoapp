-- Update get_unit_pool_lock to also return swimmer names
CREATE OR REPLACE FUNCTION public.get_unit_pool_lock(
  p_community_id uuid,
  p_unit_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reg_id uuid;
  v_last_edited_at timestamptz;
  v_swimmer_count int;
  v_next_editable timestamptz;
  v_swimmers jsonb;
  v_registrant_name text;
BEGIN
  -- Find the registration for this unit
  SELECT id, last_edited_at, full_name
    INTO v_reg_id, v_last_edited_at, v_registrant_name
    FROM pool_access_registrations
   WHERE community_id = p_community_id
     AND unit_id = p_unit_id
   LIMIT 1;

  IF v_reg_id IS NULL THEN
    RETURN jsonb_build_object('locked', false);
  END IF;

  -- Count swimmers and collect names
  SELECT count(*), coalesce(jsonb_agg(
    jsonb_build_object(
      'full_name', s.full_name,
      'birthdate', s.birthdate::text
    ) ORDER BY s.sort_order
  ), '[]'::jsonb)
    INTO v_swimmer_count, v_swimmers
    FROM pool_registered_swimmers s
   WHERE s.registration_id = v_reg_id;

  IF v_swimmer_count = 0 THEN
    RETURN jsonb_build_object('locked', false);
  END IF;

  -- Unit has swimmers -> locked
  v_next_editable := v_last_edited_at + interval '90 days';

  RETURN jsonb_build_object(
    'locked', true,
    'next_editable_date', v_next_editable::text,
    'can_edit', (now() > v_next_editable),
    'registrant_name', v_registrant_name,
    'swimmers', v_swimmers
  );
END;
$$;
