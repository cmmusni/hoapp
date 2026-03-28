-- Recurring billing templates for automatic invoice generation
CREATE TABLE IF NOT EXISTS public.recurring_billings (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  community_id uuid NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  unit_id uuid REFERENCES public.units(id) ON DELETE CASCADE,
  category text NOT NULL CHECK (category IN ('dues', 'water', 'amenity', 'insurance', 'other')),
  description text,
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  currency text NOT NULL DEFAULT 'PHP',
  frequency text NOT NULL CHECK (frequency IN ('monthly', 'quarterly', 'yearly')),
  day_of_month int NOT NULL DEFAULT 1 CHECK (day_of_month >= 1 AND day_of_month <= 28),
  due_day_offset int NOT NULL DEFAULT 15 CHECK (due_day_offset >= 1 AND due_day_offset <= 90),
  is_active boolean NOT NULL DEFAULT true,
  apply_to_all boolean NOT NULL DEFAULT false,
  line_items jsonb,
  next_run_date date NOT NULL,
  last_run_date date,
  notes text,
  created_by uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_recurring_billings_community ON public.recurring_billings(community_id);
CREATE INDEX idx_recurring_billings_active ON public.recurring_billings(community_id, is_active) WHERE is_active = true;
CREATE INDEX idx_recurring_billings_next_run ON public.recurring_billings(next_run_date) WHERE is_active = true;

-- RLS
ALTER TABLE public.recurring_billings ENABLE ROW LEVEL SECURITY;

-- Staff can view all recurring billings in their community
CREATE POLICY "Staff can view community recurring billings"
  ON public.recurring_billings FOR SELECT
  USING (is_community_staff(community_id));

-- Staff can create recurring billings
CREATE POLICY "Staff can create recurring billings"
  ON public.recurring_billings FOR INSERT
  WITH CHECK (is_community_staff(community_id));

-- Staff can update recurring billings
CREATE POLICY "Staff can update recurring billings"
  ON public.recurring_billings FOR UPDATE
  USING (is_community_staff(community_id));

-- Staff can delete recurring billings
CREATE POLICY "Staff can delete recurring billings"
  ON public.recurring_billings FOR DELETE
  USING (is_community_staff(community_id));

-- Trigger to auto-update updated_at
CREATE TRIGGER set_recurring_billings_updated_at
  BEFORE UPDATE ON public.recurring_billings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
