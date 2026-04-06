-- Update portal_access_log to track unique (fingerprint + ip_address) combos
-- instead of fingerprint alone. A new IP from a known device, or a new device
-- from a known IP, both trigger email notification.

-- Drop the old fingerprint-only unique index
drop index if exists idx_portal_access_log_fingerprint;

-- Create composite unique index on fingerprint + ip_address
create unique index if not exists idx_portal_access_log_fp_ip
  on public.portal_access_log (fingerprint, ip_address);
