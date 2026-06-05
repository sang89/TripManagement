# TripManagement — Monetization Reference

## Model

**Freemium + Pro.** Free users can plan events immediately with no sign-up friction; Pro unlocks higher limits and premium features. Subscriptions are per-app — TripManagement Pro is completely separate from PropertyManagement Pro, even though both apps share the same Supabase project.

---

## Pricing

| Plan | Price | Notes |
|---|---|---|
| **Monthly** | **$4.99 / month** | RevenueCat package `$rc_monthly`; Stripe price `kStripePriceIdMonthly` |
| **Annual** | **$39.99 / year** (~$3.33/mo) | RevenueCat package `$rc_annual`; Stripe price `kStripePriceIdAnnual`; "Save 33%" badge shown in UI |

Annual is the default selection in `PaywallScreen`.

---

## Basic vs Pro

| Feature | Free | Pro |
|---|---|---|
| Organizer-owned events | 3 max | Unlimited |
| Guests per event | 10 max | Unlimited |
| RSVP & basic planning | ✓ | ✓ |
| AI Trip Planner | Pro only | ✓ |
| Expense export (PDF & image) | — | ✓ |
| Offline access | — | ✓ |
| Event templates | — | ✓ |

**AI Trip Planner gating:** event organizers always have access to the AI chat (sparkle AppBar button) at no cost. Non-organizer members require a Pro subscription.

---

## Platform Split

| Platform | Purchase processor | Source of truth |
|---|---|---|
| iOS | RevenueCat → App Store | RevenueCat entitlement `pro` |
| Android | RevenueCat → Google Play | RevenueCat entitlement `pro` |
| Web | Stripe Checkout | Stripe webhook → `user_subscriptions` table |

### isPro determination

- **Mobile:** `SubscriptionProvider._loadFromRevenueCat()` — checks `info.entitlements.active['pro']`
- **Web:** `SubscriptionProvider._loadFromSupabase()` — queries `user_subscriptions` for a row with `user_id = auth.uid() AND app = 'trip_management' AND status IN ('active', 'trialing') AND current_period_end > now()`

---

## Freemium Gates

| Gate | Free limit | Where enforced |
|---|---|---|
| Event creation | 3 organizer-owned events | `EventsScreen._onFabTap()` |
| Guest count | 10 guests per event | `_GuestsTabState._showAddGuest()` |
| Expense export | Pro only | `_ExpensesTabState._showExportOptions()` |
| AI chat | Pro only | `_EventDetailScreenState._openAiSheet()` |

All gates push to `/paywall`.

---

## PaywallScreen (`lib/screens/subscription/paywall_screen.dart`)

Full-screen Scaffold styled to match PropertyManagement's upgrade sheet:

1. **Hero** — dark navy gradient (`#0D1F35 → #1B3D6B`) with decorative glow orbs, gold `workspace_premium_rounded` icon, gold "PRO" badge chip, "Upgrade to Pro" title, subtitle. Close button top-right.
2. **Billing toggle** — animated gradient pill slider (Annual left / Monthly right). Annual selected by default with "Save 33%" amber badge.
3. **Feature cards** — five cards with colored icon squares and `check_circle_rounded` icons.
4. **Comparison table** — Basic vs Pro columns; Pro column has gradient pill header.
5. **CTA button** — gradient (`AppTheme.primary → AppTheme.primaryLight`) 54px height, shows selected plan price.
6. **Restore purchases** — mobile-only text link below CTA.

---

## Web Stripe Flow

```
Flutter web
  → StripeService.launchCheckout(priceId)
  → stripe-create-checkout Edge Function
  → Stripe Checkout Session (hosted page)
  → browser redirect on payment
  → stripe-webhook Edge Function (checkout.session.completed)
  → upserts user_subscriptions row
  → SubscriptionProvider.load() on next foreground
```

**Edge Function secrets:**
```
supabase secrets set STRIPE_SECRET_KEY='sk_live_...'
supabase secrets set STRIPE_WEBHOOK_SECRET='whsec_...'
supabase secrets set SUPABASE_SERVICE_ROLE_KEY='<key>'
```

Stripe webhook URL: `https://qgeocaectbdfonrorwco.supabase.co/functions/v1/stripe-webhook`

Events to subscribe: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`

---

## iOS / Android RevenueCat

Package: `purchases_flutter: ^10.2.2`

API keys live in `lib/config/api_keys.dart` (git-ignored):
- `kRevenueCatAppleApiKey` — iOS
- `kRevenueCatGoogleApiKey` — Android

Guard in `SubscriptionProvider._ensureRcConfigured()`: if either key contains `'REPLACE_ME'`, RevenueCat is skipped and the user stays on the free tier (prevents crash during development).

`MainActivity` must extend `FlutterFragmentActivity` (already done). In-App Purchase capability must be enabled in Xcode.

**RevenueCat webhook** (future): will POST to a `revenuecat-webhook` Edge Function and upsert `user_subscriptions` with `platform = 'ios'|'android'`.

---

## `user_subscriptions` Table

The `app` column (`trip_management` | `property_management`) ensures subscriptions are never shared between apps.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid FK→auth.users | |
| `app` | text | `trip_management` \| `property_management` |
| `platform` | text | `ios` \| `android` \| `web` |
| `stripe_customer_id` | text nullable | web only |
| `stripe_subscription_id` | text UNIQUE nullable | web only |
| `stripe_price_id` | text nullable | web only |
| `revenuecat_original_app_user_id` | text nullable | mobile (future) |
| `status` | text | `active` \| `trialing` \| `past_due` \| `canceled` \| `unpaid` \| `paused` |
| `current_period_end` | timestamptz nullable | |
| `trial_end` | timestamptz nullable | |
| `created_at` / `updated_at` | timestamptz | |

**RLS:** users can SELECT their own rows; only service role (Edge Functions) can INSERT/UPDATE.

---

## Future Work

- [ ] RevenueCat webhook Edge Function (`revenuecat-webhook`) to sync mobile purchases into `user_subscriptions`
- [ ] Offline access implementation (Phase 5)
- [ ] Event templates (Phase 5)
- [ ] Affiliate booking links — commission revenue from hotel/activity bookings (Phase 4)
