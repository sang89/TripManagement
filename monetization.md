# TripManagement — Monetization Reference

## Freemium Model

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

---

## API Cost Reference

Tracks every billable API call with per-call pricing, trigger conditions, and monthly cost projections. **Update this section whenever a new API call is added or an existing one changes.**

### Free credit summary

| Provider | Free allowance | Notes |
|---|---|---|
| Google Maps Platform | **$200/month** credit | Shared across all Google APIs on the key — autocomplete, place details, text search, photo, directions |
| Stadia Maps | **200,000 tiles/month** | Independent from Google credit |
| Supabase | Free tier: 500 MB DB, 2 GB bandwidth, 500K Edge Function invocations/month | Shared with PropertyManagement |
| Google Gemini (direct) | Free tier varies by model | Debug builds only — not billed in production (Edge Function used instead) |
| Yelp Fusion API | **500 calls/day** (Base plan, free) | 1 call per restaurant detail sheet open; falls back to Yelp search URL if limit hit or key missing |

---

### Google Maps Platform — per-call pricing

All calls use `kGooglePlacesApiKey`. Prices are in USD and consume the $200/month free credit first.

#### Places API (New)

| Endpoint | Trigger | Cost/call | Free calls/month (from $200 credit) |
|---|---|---|---|
| `POST places:autocomplete` | Each debounced keystroke in a location search field | **$0.00283** | ~70,700 |
| `GET places/{placeId}` — Basic fields | User selects a prediction from autocomplete | **$0.017** | ~11,760 |
| `GET places/{placeId}` — Advanced fields (rating, priceLevel, photos) | `fetchRestaurantDetails()` — called after autocomplete select when the destination is a restaurant | **$0.020** | ~10,000 |
| `POST places:searchText` | User taps **"Find me a spot"** in the Cravings tab | **$0.032** | ~6,250 |
| `GET places/{photoRef}/media` | Each restaurant photo rendered in the UI — triggered in two places: (1) each result card in the Cravings tab (up to 5 per search), (2) each restaurant option row in the Polls tab | **$0.007** | ~28,570 |

#### Directions API

| Endpoint | Trigger | Cost/call | Free calls/month |
|---|---|---|---|
| `GET directions/json` | `TripMapWidget` mount + every stop-pin change on trip-type events with ≥2 stops | **$0.005** | ~40,000 |

---

### Per-feature cost breakdown

#### Location autocomplete (trip/event creation, stop editing)

Each search session = type N characters (one request per debounced keystroke, min 3 chars) + one place-details call on selection.

| Action | Calls | Cost |
|---|---|---|
| 5-character query → select a place | 3 autocomplete + 1 place details | $0.00849 + $0.017 = **$0.025** |
| Typical session (8 chars typed) | 6 autocomplete + 1 place details | $0.01698 + $0.017 = **$0.034** |

#### Cravings tab (Quick Bites events only)

One "Find me a spot" session = 1 text search + up to 5 photo fetches (one per result card).

| Action | Calls | Cost |
|---|---|---|
| Search that returns 10 results | 1 text search + 10 photos | $0.032 + $0.070 = **$0.102** |
| Viewing Polls tab with 5 pitched restaurants | 5 photo fetches (one per poll option row) | **$0.035** |
| Pitching a restaurant (no extra API call) | 0 — uses data already fetched in the search | **$0.000** |
| Reacting to a poll option (any emoji) | Supabase write only, no external API | **$0.000** |
| Viewing restaurant detail sheet (up to 4 extra photos) | 0–4 photo fetches | **$0–$0.028** |
| Tapping "View on Yelp" (resolves exact listing) | 1 Yelp Fusion Business Search call | **$0** (free tier; 500/day cap) |

> **Photo caching note:** `Image.network` caches images in memory for the session and on disk via the platform HTTP cache. A user who searches, then opens the Polls tab, will NOT re-fetch the same photos — the platform cache serves them. Cost above is the worst case (cold cache).

#### Route display (trip-type events)

| Scenario | Calls | Cost |
|---|---|---|
| Open a trip with 3 stops | 1 directions call | **$0.005** |
| Add/move one stop | 1 directions call | **$0.005** |

---

### Monthly cost estimates

Assumptions: MAU = monthly active users, avg sessions/user/month below.

#### Small scale (100 MAU)

| Usage pattern | Calls/month | Cost before credit | After $200 credit |
|---|---|---|---|
| Autocomplete: 2 searches/user | 200 text + 100 details | $0.57 + $1.70 | **$0** |
| Cravings: 3 searches/user, 2 poll views/user | 300 text search + 1,500 photos + 1,000 poll photos | $9.60 + $10.50 + $7.00 | **$0** |
| Directions: 5 trip views/user | 500 | $2.50 | **$0** |
| **Monthly total** | | **~$32** | **$0 (within free credit)** |

#### Medium scale (1,000 MAU)

| Usage pattern | Calls/month | Cost before credit | After $200 credit |
|---|---|---|---|
| Autocomplete: 2 searches/user | 2,000 text + 1,000 details | $5.66 + $17.00 | **$0** |
| Cravings: 3 searches/user, 2 poll views/user | 3,000 text search + 15,000 photos + 10,000 poll photos | $96 + $105 + $70 | **$96** |
| Directions: 5 trip views/user | 5,000 | $25 | **$0** |
| **Monthly total** | | **~$319** | **~$119 out-of-pocket** |

#### Large scale (10,000 MAU)

At this scale all costs are out-of-pocket (credit exhausted in the first ~620 text search calls).

| Feature | Calls/month | Cost/month |
|---|---|---|
| Autocomplete | 20,000 text + 10,000 details | $56.60 + $170 = **$227** |
| Cravings text search | 30,000 | **$960** |
| Cravings + poll photos | 250,000 | **$1,750** |
| Directions | 50,000 | **$250** |
| **Monthly total** | | **~$3,187** |

> At 10K MAU the photo cost dominates. Mitigation options: add a CDN proxy layer that caches `/media` responses so each unique photo is fetched from Google only once regardless of how many users view it.

---

### Supabase

| Resource | Free limit | Est. usage at 1K MAU |
|---|---|---|
| Database rows | 500 MB | Well within — events + polls + votes are small |
| Bandwidth | 2 GB/month | Well within for API-only traffic |
| Edge Function invocations | 500K/month | ~5K AI chat calls + session-signup page loads (2 invocations per public signup: GET form + POST submit) at 1K MAU — well within |
| Realtime connections | 200 concurrent | Sufficient until ~500+ simultaneous active users |

Paid tier (Pro, $25/month): 8 GB DB, 250 GB bandwidth, 2M Edge Function invocations.

---

### Cost-control checklist

When adding any new feature that calls an external API:

- [ ] Add the endpoint + per-call cost to the table above.
- [ ] Add it to the relevant per-feature breakdown section.
- [ ] Re-run the monthly estimate rows (or add a new feature row).
- [ ] Consider whether the call can be avoided with client-side caching (`CacheEntry`, `Image.network` disk cache, or a local `Map<>`).
- [ ] Update this file in the same PR as the feature code.
