-- Invoice line items to support detailed billing breakdowns
-- (water billing, monthly dues, parking, pool, insurance, etc.)

CREATE TABLE invoice_line_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  amount NUMERIC(12, 2) NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_invoice_line_items_invoice ON invoice_line_items(invoice_id);

-- RLS
ALTER TABLE invoice_line_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Line items viewable by invoice viewers"
  ON invoice_line_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM invoices i
      WHERE i.id = invoice_line_items.invoice_id
        AND (is_unit_member(i.unit_id) OR is_community_staff(i.community_id))
    )
  );

CREATE POLICY "Line items manageable by staff"
  ON invoice_line_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM invoices i
      WHERE i.id = invoice_line_items.invoice_id
        AND is_community_staff(i.community_id)
    )
  );

CREATE POLICY "Line items updatable by staff"
  ON invoice_line_items FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM invoices i
      WHERE i.id = invoice_line_items.invoice_id
        AND is_community_staff(i.community_id)
    )
  );

CREATE POLICY "Line items deletable by staff"
  ON invoice_line_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM invoices i
      WHERE i.id = invoice_line_items.invoice_id
        AND is_community_staff(i.community_id)
    )
  );

-- Also add new invoice categories for the billing breakdown
-- Update the invoices category check to include water and insurance
ALTER TABLE invoices DROP CONSTRAINT IF EXISTS invoices_category_check;
ALTER TABLE invoices ADD CONSTRAINT invoices_category_check
  CHECK (category IN ('dues', 'water', 'amenity', 'insurance', 'other'));

-- Add description and period fields to invoices
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS period_start DATE;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS period_end DATE;
