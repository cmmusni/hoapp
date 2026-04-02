-- Add expiry tracking to plan_subscriptions
ALTER TABLE plan_subscriptions
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS grace_ends_at TIMESTAMPTZ;

-- Add plan_expires_at to communities for quick access
ALTER TABLE communities
  ADD COLUMN IF NOT EXISTS plan_expires_at TIMESTAMPTZ;

-- Enable pg_cron and pg_net extensions (required for scheduled jobs)
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Function: send reminder notifications 7 days before expiry
CREATE OR REPLACE FUNCTION notify_expiring_subscriptions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  rec RECORD;
BEGIN
  -- Find communities expiring in 7 days that haven't been notified yet
  FOR rec IN
    SELECT c.id AS community_id, c.name, c.plan_expires_at
    FROM communities c
    WHERE c.plan IN ('professional', 'enterprise')
      AND c.plan_expires_at IS NOT NULL
      AND c.plan_expires_at BETWEEN now() AND now() + INTERVAL '7 days'
      AND NOT EXISTS (
        SELECT 1 FROM notifications n
        WHERE n.community_id = c.id
          AND n.type = 'plan_expiry_reminder'
          AND n.created_at > now() - INTERVAL '6 days'
      )
  LOOP
    -- Insert a notification for community admins
    INSERT INTO notifications (community_id, type, title, body)
    SELECT
      rec.community_id,
      'plan_expiry_reminder',
      'Plan Expiring Soon',
      'Your ' || rec.name || ' subscription expires on ' ||
        to_char(rec.plan_expires_at, 'Mon DD, YYYY') ||
        '. Renew to keep your premium features.'
    WHERE EXISTS (SELECT 1 FROM notifications LIMIT 0) -- only if table exists
    ON CONFLICT DO NOTHING;
  END LOOP;
END;
$$;

-- Function: downgrade expired communities after grace period
CREATE OR REPLACE FUNCTION downgrade_expired_subscriptions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  rec RECORD;
  grace_days INTEGER := 7; -- 7-day grace period after expiry
BEGIN
  FOR rec IN
    SELECT c.id AS community_id, c.name, c.plan, c.plan_expires_at
    FROM communities c
    WHERE c.plan IN ('professional', 'enterprise')
      AND c.plan_expires_at IS NOT NULL
      AND c.plan_expires_at + (grace_days || ' days')::INTERVAL < now()
  LOOP
    -- Downgrade to starter
    UPDATE communities
    SET plan = 'starter', plan_expires_at = NULL
    WHERE id = rec.community_id;

    -- Mark active subscriptions as expired
    UPDATE plan_subscriptions
    SET status = 'expired'
    WHERE community_id = rec.community_id
      AND status = 'paid'
      AND (expires_at IS NOT NULL AND expires_at < now());

    RAISE NOTICE 'Downgraded community % (%) from % to starter',
      rec.community_id, rec.name, rec.plan;
  END LOOP;
END;
$$;

-- Schedule: check for expiring subscriptions daily at 2:00 AM UTC
SELECT cron.schedule(
  'notify-expiring-plans',
  '0 2 * * *',
  $$SELECT notify_expiring_subscriptions()$$
);

-- Schedule: downgrade expired plans daily at 3:00 AM UTC
SELECT cron.schedule(
  'downgrade-expired-plans',
  '0 3 * * *',
  $$SELECT downgrade_expired_subscriptions()$$
);

-- Backfill: set expires_at for existing paid subscriptions (30 days from paid_at)
UPDATE plan_subscriptions
SET expires_at = paid_at + INTERVAL '30 days',
    grace_ends_at = paid_at + INTERVAL '37 days'
WHERE status = 'paid'
  AND paid_at IS NOT NULL
  AND expires_at IS NULL;

-- Backfill: set plan_expires_at on communities from their latest paid subscription
UPDATE communities c
SET plan_expires_at = sub.expires_at
FROM (
  SELECT DISTINCT ON (community_id)
    community_id, expires_at
  FROM plan_subscriptions
  WHERE status = 'paid' AND expires_at IS NOT NULL
  ORDER BY community_id, expires_at DESC
) sub
WHERE c.id = sub.community_id
  AND c.plan IN ('professional', 'enterprise')
  AND c.plan_expires_at IS NULL;
