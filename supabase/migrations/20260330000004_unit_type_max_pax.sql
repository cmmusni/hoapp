-- Add max_pax column to unit_types so staff/admin can configure
-- the maximum number of registered swimmers per unit type.
ALTER TABLE unit_types
  ADD COLUMN IF NOT EXISTS max_pax INT NOT NULL DEFAULT 5;

-- Backfill sensible defaults for existing rows based on name patterns
UPDATE unit_types SET max_pax = 7
  WHERE lower(name) LIKE '%loft%'
     OR lower(name) LIKE '%cluster%';

UPDATE unit_types SET max_pax = 5
  WHERE lower(name) LIKE '%2%'
     OR lower(name) LIKE '%two%';

UPDATE unit_types SET max_pax = 3
  WHERE lower(name) LIKE '%1%'
     OR lower(name) LIKE '%one%';
