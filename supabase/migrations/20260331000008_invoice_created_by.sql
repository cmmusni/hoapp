-- Add created_by column to invoices to track who created the invoice
ALTER TABLE invoices
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Backfill existing invoices: set created_by to NULL (unknown creator)
-- New invoices will have created_by set by the application.
