# Monetization Roadmap

## Phase 1 — Subscription Infrastructure
The foundation everything else depends on. Must be done first.

- [x] **1.1** Add `purchases_flutter` (RevenueCat) to `pubspec.yaml` for iOS + Android in-app purchases
- [x] **1.2** Add Stripe web subscription — `stripe-create-checkout` + `stripe-webhook` Edge Functions, `StripeService` in Flutter, price ID placeholders in `api_keys.dart`
- [x] **1.3** Create a `SubscriptionProvider` that exposes `isPro` (checks entitlement from RevenueCat on mobile, Supabase `user_subscriptions` table on web)
- [x] **1.4** Add `user_subscriptions` table to Supabase with RLS — migration `20260604270000_user_subscriptions.sql` (done alongside 1.2)
- [x] **1.5** Add a `PaywallScreen` — shows Pro feature list, price ($39.99/yr / $4.99/mo), 14-day free trial CTA, and a "Restore purchases" button
- [x] **1.6** Wire `SubscriptionProvider` into `MultiProvider` in `main.dart`

## Phase 2 — Freemium Gates
Limit free tier so Pro has clear value. All gates show the `PaywallScreen` when hit.

- [x] **2.1** Gate event creation at **3 active events** for free users — show upgrade prompt on the 4th
- [x] **2.2** Gate guest count at **10 guests per event** for free users — show upgrade prompt when adding the 11th
- [x] **2.3** Gate **expense export** (PDF + photo) behind Pro — currently free, move it to Pro only
- [x] **2.4** Add a **Pro badge** to the Profile tab so free users see the upgrade path clearly

## Phase 3 — AI Trip Planner (Primary Pro Hook)
The feature that justifies the subscription. Gemini is already wired up.

- [x] **3.1** Design the UI: a "Generate with AI" FAB in the Route tab (organizer = free; non-organizer = Pro-only; shows paywall for free non-organizers)
- [x] **3.2** Build the Gemini prompt: takes destination, dates, group size, start location, preferences → generates stops via tool-calling
- [x] **3.3** Add tool declarations in `gemini_tools.dart` for `create_stop` and `clear_stops`
- [x] **3.4** Stream the AI response into the event's stop list with a loading state (stop counter + last stop title in `AiItinerarySheet`)
- [x] **3.5** Add a "Add more stops" follow-up chat within the same AI session (conversation history preserved in `AiItinerarySheet`)
- [x] **3.6** AI itinerary generation gated: organizer always free on own events; non-organizer needs Pro (handled in `_RouteTabState._openAiSheet`). Group chat tab remains free for all users.

## Phase 4 — Affiliate Booking Links (Explore Tab)

The Explore tab currently shows Viator activity suggestions only. Other affiliate categories (Hotels, Cars, Flights) were prototyped and reverted — affiliate programs need to be verified directly with each provider before re-integrating.

### 🎭 Activities (Viator) — live, needs production key

- [x] **4.0** Viator Explore tab built — `/search/freetext` API, pagination, keyword search, random quote header, GYG + Klook browse buttons
- [ ] **4.1** **Viator production key** — flip `kViatorSandbox = false` in `api_keys.dart` once sandbox activates (up to 24h). Production key `31b1a78a-...` already stored. PID `P00305761` and MCID `42383` confirmed correct.
- [ ] **4.2** **Viator terms compliance** — before release: no cross-bidding on "Viator" in ads, content not indexed by search engines. See `viator.md`.
- [ ] **4.3** **GYG affiliate ID** — verify affiliate program exists directly at getyourguide.com, then paste ID as `kGYGAffiliateId` in `api_keys.dart` to track commissions on the "Browse GetYourGuide" button.
- [ ] **4.4** **Klook affiliate ID** — verify affiliate program exists directly at klook.com, then paste ID as `kKlookAffiliateId`.

### 🏨 Hotels / 🚗 Cars / ✈️ Flights — research needed before re-integrating

- [ ] **4.5** Verify **Booking.com** affiliate program directly at `booking.com/affiliate-program` — confirm commission rate, then re-integrate. Signup is via CJ Affiliate.
- [ ] **4.6** Verify **Discover Cars** affiliate program directly at `discovercars.com/affiliate` — confirmed real ($20/booking avg, 365-day cookie, free signup). Re-integrate once signed up.
- [ ] **4.7** Verify **Skyscanner** partner program directly at `partners.skyscanner.net` — CPC model. Apply for API access before re-integrating.
- [ ] **4.8** Research other affiliate programs (Hotels, Flights) — only integrate once affiliate URLs and commission structures are verified directly with each provider, not from third-party blogs.

## Phase 4.5 — Chat Enhancements (shipped June 2026)

- [x] **4.5.1** **@mention** — type `@` to autocomplete event members; inserts `@[userId:displayName]` token; renders as teal span in bubbles; triggers push + in-app notification via `send-mention-notification` Edge Function
- [x] **4.5.2** **GIF messages** — GIF button opens `_GifPickerSheet` (Giphy API, `kGiphyApiKey`); `event_messages.message_type = 'gif'`; rendered with `CachedNetworkImage`; beta key in place, **needs production key before release**
- [x] **4.5.3** **Chat background themes** — 8 presets (gradient + solid); stored in `events.chat_background`; any member can change; propagates live via Realtime
- [ ] **4.5.4** **Giphy production key** — current key `VYp5rjs3lqSmUCzTrWQfjeo18v371OEC` is beta (limited). Apply for production key at developers.giphy.com before release.

## Phase 5 — Pro Quality-of-Life Features
Rounds out the Pro tier value beyond the AI planner.

- [ ] **5.1** **Event templates**: allow organizers to save an event as a template (title, stop structure, bring-list) and reuse it — Pro only
- [ ] **5.2** **Unlimited polls**: free tier capped at 1 active poll per event; Pro = unlimited
- [ ] **5.3** **Custom event cover photo**: free tier uses generated gradient; Pro can set a photo — minor but visible perk
- [ ] **5.4** **Offline access badge**: no new dev needed (offline is already built); just surface it in the PaywallScreen as a Pro benefit

## Phase 6 — Paywall Polish & Conversion Optimisation
Do this after Phase 1-3 ship and you have real conversion data.

- [ ] **6.1** Add a **14-day trial** on first Pro prompt (RevenueCat supports this natively)
- [ ] **6.2** Trigger the paywall contextually — at the moment of hitting a gate, not on app open
- [ ] **6.3** Add a **"You're on day X of your free trial"** banner in the Profile tab
- [ ] **6.4** Send a push notification on trial day 12: "2 days left on your Pro trial"
- [ ] **6.5** A/B test annual vs monthly pricing display order (RevenueCat supports this)

## Phase 7 — B2B / White-Label (Future, 2026+)
Defer until Phases 1-5 are stable and you have a user base.

- [ ] **7.1** Research wedding planner and event agency outreach channels
- [ ] **7.2** Design a white-label config layer (custom branding, disabled tabs, custom event types)
- [ ] **7.3** Build a simple agency admin dashboard (web-only) for managing multiple events
- [ ] **7.4** Set pricing: ~$500-2000/month per agency depending on event volume
