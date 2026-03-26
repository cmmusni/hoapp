-- Add plan column to communities table
-- Plans: 'starter' (free), 'professional', 'enterprise'
ALTER TABLE communities
  ADD COLUMN plan TEXT NOT NULL DEFAULT 'starter'
  CHECK (plan IN ('starter', 'professional', 'enterprise'));
