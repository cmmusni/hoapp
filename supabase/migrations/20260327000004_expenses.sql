-- Expenses table for community expense tracking (staff-managed)
CREATE TABLE IF NOT EXISTS public.expenses (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  community_id uuid NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES auth.users(id),
  category text NOT NULL DEFAULT 'other',
  description text NOT NULL,
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  currency text NOT NULL DEFAULT 'PHP',
  expense_date date NOT NULL DEFAULT CURRENT_DATE,
  vendor text,
  receipt_url text,
  notes text,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_expenses_community ON public.expenses(community_id);
CREATE INDEX idx_expenses_category ON public.expenses(community_id, category);
CREATE INDEX idx_expenses_date ON public.expenses(community_id, expense_date DESC);

-- RLS
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

-- Staff can view all expenses in their community
CREATE POLICY "Staff can view community expenses"
  ON public.expenses FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_roles.user_id = auth.uid()
        AND user_roles.community_id = expenses.community_id
        AND user_roles.role IN ('admin', 'staff', 'maintenance')
    )
  );

-- Staff can create expenses
CREATE POLICY "Staff can create expenses"
  ON public.expenses FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_roles.user_id = auth.uid()
        AND user_roles.community_id = expenses.community_id
        AND user_roles.role IN ('admin', 'staff')
    )
  );

-- Staff can update expenses
CREATE POLICY "Staff can update expenses"
  ON public.expenses FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_roles.user_id = auth.uid()
        AND user_roles.community_id = expenses.community_id
        AND user_roles.role IN ('admin', 'staff')
    )
  );

-- Admin can delete expenses
CREATE POLICY "Admin can delete expenses"
  ON public.expenses FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_roles.user_id = auth.uid()
        AND user_roles.community_id = expenses.community_id
        AND user_roles.role = 'admin'
    )
  );

-- Storage bucket for expense receipts
INSERT INTO storage.buckets (id, name, public)
VALUES ('expense-receipts', 'expense-receipts', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for expense-receipts bucket
CREATE POLICY "Staff can upload expense receipts"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'expense-receipts'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Anyone can view expense receipts"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'expense-receipts');

CREATE POLICY "Staff can delete expense receipts"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'expense-receipts'
    AND auth.role() = 'authenticated'
  );
