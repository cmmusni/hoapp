-- Configurable plan pricing managed by platform admins
CREATE TABLE IF NOT EXISTS plan_pricing (
  plan TEXT PRIMARY KEY CHECK (plan IN ('starter', 'professional', 'enterprise')),
  price_centavos INTEGER NOT NULL DEFAULT 0,
  original_price_centavos INTEGER, -- strikethrough / was-price
  label TEXT NOT NULL DEFAULT '',  -- e.g. "Free", "₱2,999", "Custom"
  period TEXT NOT NULL DEFAULT '',  -- e.g. "/month", ""
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed default pricing
INSERT INTO plan_pricing (plan, price_centavos, original_price_centavos, label, period) VALUES
  ('starter',       0,      NULL,   'Free',    ''),
  ('professional', 299900, 399900, '₱2,999', '/month'),
  ('enterprise',    0,      NULL,   'Custom',  '')
ON CONFLICT (plan) DO NOTHING;

-- Everyone can read pricing (it's public info)
ALTER TABLE plan_pricing ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read plan pricing"
  ON plan_pricing FOR SELECT
  USING (true);

-- Only service role (edge functions / admin operations) can update
CREATE POLICY "Service role can manage pricing"
  ON plan_pricing FOR ALL
  USING (true)
  WITH CHECK (true);
