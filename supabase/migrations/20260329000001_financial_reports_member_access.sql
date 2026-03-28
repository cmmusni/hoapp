-- Allow all community members to view expenses, income, and verified payments
-- for financial transparency. Staff retain full CRUD; members only get SELECT.

-- Members can view expenses in their community (read-only transparency)
DO $$ BEGIN
  CREATE POLICY "Members can view community expenses"
    ON public.expenses FOR SELECT
    USING (is_community_member(community_id));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Members can view manual income in their community (read-only transparency)
DO $$ BEGIN
  CREATE POLICY "Members can view community manual income"
    ON public.manual_income FOR SELECT
    USING (is_community_member(community_id));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Members can view verified payments in their community (read-only transparency)
-- This broadens the existing "owner or staff" policy to include all members
-- for verified payments only, so community finances are transparent.
DO $$ BEGIN
  CREATE POLICY "Members can view verified community payments"
    ON public.payments FOR SELECT
    USING (
      is_community_member(community_id) AND status = 'verified'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
