-- Add category fields to invoice_line_items for multi-category invoices
ALTER TABLE invoice_line_items ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE invoice_line_items ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE invoice_line_items ADD COLUMN IF NOT EXISTS period_start DATE;
ALTER TABLE invoice_line_items ADD COLUMN IF NOT EXISTS period_end DATE;
