-- Manual income entries for community income tracking (staff-managed)
-- Invoice-based income is derived from verified payments; this table stores additional manual entries.
CREATE TABLE IF NOT EXISTS public.manual_income (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  community_id uuid NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES auth.users(id),
  category text NOT NULL DEFAULT 'other',
  description text NOT NULL,
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  currency text NOT NULL DEFAULT 'PHP',
  income_date date NOT NULL DEFAULT CURRENT_DATE,
  source text,
  receipt_url text,
  notes text,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_manual_income_community ON public.manual_income(community_id);
CREATE INDEX idx_manual_income_category ON public.manual_income(community_id, category);
CREATE INDEX idx_manual_income_date ON public.manual_income(community_id, income_date DESC);

-- RLS
ALTER TABLE public.manual_income ENABLE ROW LEVEL SECURITY;

-- Staff can view all manual income in their community
CREATE POLICY "Staff can view community manual income"
  ON public.manual_income FOR SELECT
  USING (is_community_staff(community_id));

-- Staff can create manual income
CREATE POLICY "Staff can create manual income"
  ON public.manual_income FOR INSERT
  WITH CHECK (is_community_staff(community_id));

-- Staff can update manual income
CREATE POLICY "Staff can update manual income"
  ON public.manual_income FOR UPDATE
  USING (is_community_staff(community_id));

-- Staff can delete manual income
CREATE POLICY "Staff can delete manual income"
  ON public.manual_income FOR DELETE
  USING (is_community_staff(community_id));
