-- Portal access log: tracks unique device fingerprints that access hoapp.net
-- Email notification is sent only when a new device fingerprint is seen.

create table if not exists public.portal_access_log (
  id uuid primary key default gen_random_uuid(),
  fingerprint text not null,
  user_agent text,
  ip_address text,
  platform text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

-- Only one row per fingerprint
create unique index if not exists idx_portal_access_log_fingerprint
  on public.portal_access_log (fingerprint);

-- Enable RLS but no public policies — only service_role writes
alter table public.portal_access_log enable row level security;
