-- Allow community members to view verified payments for financial transparency.
-- Residents can see aggregated income data from verified payments.
-- The existing "owner or staff" policy still allows users to see their own
-- payments regardless of status, and staff to see all payments.

DO $$ BEGIN
  CREATE POLICY "Members can view verified community payments"
    ON public.payments FOR SELECT
    USING (
      is_community_member(community_id) AND status = 'verified'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
