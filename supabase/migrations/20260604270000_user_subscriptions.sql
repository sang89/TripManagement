-- user_subscriptions
-- Mirrors PropertyManagement's schema. One row per user per app.
-- Tier: 'free' | 'pro' | 'admin'
-- trial_ends_at: set when a free trial is started; persists after expiry for hadTrial detection.
-- current_period_end: end of current paid period (set by Stripe/RevenueCat webhooks).
--
-- isPro: tier IN ('pro','admin') OR (trial_ends_at > now())

CREATE TABLE IF NOT EXISTS public.user_subscriptions (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  app                   text NOT NULL CHECK (app IN ('trip_management', 'property_management')),
  tier                  text NOT NULL DEFAULT 'free',
  trial_ends_at         timestamptz,
  current_period_end    timestamptz,
  revenuecat_id         text,
  stripe_customer_id    text,
  stripe_sub_id         text UNIQUE,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, app)
);

CREATE INDEX IF NOT EXISTS user_subscriptions_user_app_idx
  ON public.user_subscriptions (user_id, app);

ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own subscription"
  ON public.user_subscriptions FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users insert own subscription"
  ON public.user_subscriptions FOR INSERT
  WITH CHECK (user_id = auth.uid());
