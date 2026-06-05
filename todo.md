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

## Phase 4 — Affiliate Booking Links
Passive revenue. ~2 days of work, scales with event volume.

- [ ] **4.1** Add a "Book accommodation" button on the event Info tab (trip-type events) — deep-links to Booking.com affiliate URL with destination pre-filled
- [ ] **4.2** Add a "Find activities" button on stop cards — deep-links to Viator/GetYourGuide affiliate URL with stop location pre-filled
- [ ] **4.3** Add an "Explore flights" button on the event Info tab — deep-links to Skyscanner affiliate URL with origin + destination + dates pre-filled
- [ ] **4.4** Store affiliate partner IDs in `api_keys.dart` (git-ignored)

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
