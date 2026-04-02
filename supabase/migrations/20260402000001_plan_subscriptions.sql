-- Track plan upgrade payments via PayMongo
CREATE TABLE IF NOT EXISTS plan_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  plan TEXT NOT NULL CHECK (plan IN ('professional', 'enterprise')),
  amount INTEGER NOT NULL, -- in centavos
  currency TEXT NOT NULL DEFAULT 'PHP',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'expired', 'failed')),
  paymongo_checkout_id TEXT,
  paymongo_payment_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  paid_at TIMESTAMPTZ
);

-- RLS
ALTER TABLE plan_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view their community subscriptions"
  ON plan_subscriptions FOR SELECT
  USING (has_community_role(community_id, 'community_admin'));

CREATE POLICY "Service role can insert/update"
  ON plan_subscriptions FOR ALL
  USING (true)
  WITH CHECK (true);
