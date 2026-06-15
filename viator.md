# Viator Affiliate API — Rules & Integration Reference

## ⚠️ Terms You Agreed To (Do Not Violate)

These are the terms accepted when starting Viator API development. Violation leads to **immediate account deactivation**.

1. **Affiliate traffic only** — The API license can only be used to drive affiliate traffic to Viator.com. It cannot be used for any other purpose (e.g. data harvesting, competitor analysis, caching product data long-term).

2. **Your app only** — Content and API access can only be used within this app (TripManagement). Redistribution to third-party websites or apps is prohibited.

3. **Follow the technical docs** — Only use the API as described in the official documentation at https://docs.viator.com/partner-api/technical/. Do not call undocumented endpoints.

4. **No bidding on Viator trademarks** — You must not run search ads (Google Ads, etc.) that bid on "Viator" or any Viator trademarked terms/keywords.

5. **No indexing Viator content** — Do not index or SEO-expose Viator product titles, descriptions, or images. Results are displayed in-app only (not crawlable by search engines — this is already the case since it's a native mobile app).

---

## Access Tiers

When you create an affiliate account at partners.viator.com you get **Basic Access** immediately.

| Feature | Basic | Full | Full + Booking |
|---|---|---|---|
| Product search (summaries) | ✓ | ✓ | ✓ |
| Single product details | ✓ | ✓ | ✓ |
| Bulk product data | ✗ | ✓ | ✓ |
| Real-time availability & pricing | ✗ | ✓ | ✓ |
| Traveler reviews & photos | ✗ | ✓ | ✓ |
| In-app booking (no redirect) | ✗ | ✗ | ✓ |

**Our current integration uses Basic Access** (product search summaries → redirect to Viator for booking).

To upgrade to Full Access: log in to the partner dashboard and submit a request — requires meeting minimum traffic/volume qualifications.

---

## API Keys — What You Need

Two separate values live in `lib/config/api_keys.dart`:

```dart
const String kViatorApiKey    = 'REPLACE_ME'; // exp-api-key header for API calls
const String kViatorPartnerId = 'REPLACE_ME'; // 9-digit PID for affiliate URL tracking
```

**How to get them:**
1. Sign up / log in at **partners.viator.com**
2. `kViatorApiKey` → found in the API / Developer section of the partner dashboard (used in the `exp-api-key` request header)
3. `kViatorPartnerId` → your 9-digit **PID** found under Affiliate Tools / Tracking Links

These are **different values** — the API key authenticates API calls; the PID tracks commission attribution in booking URLs.

---

## Affiliate URL Attribution

**How it works:** When a user taps "Book on Viator", we open a URL in the system browser. Viator sets a **30-day cookie**. Any booking the user completes on viator.com within 30 days is credited to your account.

**Required URL parameters** (all four must be present or commission may not track):

| Parameter | Value | Description |
|---|---|---|
| `pid` | Your 9-digit PID | Identifies your affiliate account |
| `mcid` | Provided by Viator | Internal Viator tracking ID — get the correct value from your partner dashboard |
| `medium` | `api` | Type of integration |
| `medium_version` | `2` | API version indicator |

**Example:**
```
https://www.viator.com/tours/Paris/Eiffel-Tower/d479-5231PARIS
  ?pid=P00049694
  &mcid=<YOUR_MCID>
  &medium=api
  &medium_version=2
```

**⚠️ MCID note:** The value `42383` used as a placeholder in the current code is NOT confirmed — get your correct MCID from the Viator partner dashboard before going live. Wrong MCID = commission not tracked.

**Rules for URL parameters:**
- Use only alphanumeric characters and dashes in the optional `campaign` parameter
- Always place `?` before the first parameter, `&` before all subsequent ones
- Never modify or omit `pid` — this is what earns the commission

**Mobile attribution caveat:** Cookie tracking requires the user to complete the booking in the same browser session that set the cookie. If the user switches browsers or clears cookies, attribution is lost. This is industry-standard for affiliate programs — accept this limitation at the affiliate track level.

---

## Current Implementation

**File:** `lib/services/activity_suggestions_service.dart`

- Searches Viator via `POST https://api.viator.com/partner/products/search`
- Authentication header: `exp-api-key: $kViatorApiKey`
- Returns up to 20 results per destination query
- Results cached in memory for 10 minutes per destination string
- If `kViatorApiKey == 'REPLACE_ME'`, returns empty list silently (no API call made)

**Affiliate URL construction** (in `_mapProduct`):
```dart
final sep = webUrl.contains('?') ? '&' : '?';
final affiliateUrl = '$webUrl${sep}pid=$kViatorPartnerId&mcid=42383&medium=api&medium_version=2';
```
→ Replace `42383` with your actual MCID from the partner dashboard.

---

## Phase 2 Upgrades

- **Full Access** — unlocks real-time availability, reviews, traveler photos → richer activity cards
- **Full + Booking Access** — in-app checkout (no browser redirect), solves mobile attribution problem, higher margin potential
- Apply via the partner dashboard once you have booking volume to justify approval
