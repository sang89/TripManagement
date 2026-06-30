# Apple Developer Account Migration — Personal → LLC

Checklist for migrating both apps (TripManagement + PropertyManagement) from the personal
Apple Developer account to the LLC account.

## Prerequisites

- [ ] LLC account enrolled in Apple Developer Program (paid, $99/year)
- [ ] Both accounts active at the same time during transfer window

---

## Step 1 — Transfer apps on App Store Connect

Do one app at a time. Start with PropertyManagement to validate the process.

1. Log in to [App Store Connect](https://appstoreconnect.apple.com) with the **personal** account
2. My Apps → select app → **App Information** → scroll to **App Transfer**
3. Enter the LLC account's Apple ID (the account email)
4. LLC account receives a transfer invitation — accept it
5. Repeat for TripManagement

**Blockers that prevent transfer:**
- Active subscriptions in dispute
- Pending contract or tax issues on either account
- App has iCloud entitlements (must be removed first)
- Binary currently in review

Transfers preserve: ratings, reviews, download history, IAP products.

---

## Step 2 — Generate a new APNs key under the LLC account

The personal account's APNs `.p8` key becomes invalid after migration. The new Team ID
(different for the LLC account) must be used for all Firebase push notification setup.

1. Log in to [developer.apple.com](https://developer.apple.com) with the **LLC** account
2. Certificates, IDs & Profiles → **Keys** → **+**
3. Name: `FCM Push Notifications`, enable **Apple Push Notifications service (APNs)**
4. Download the `.p8` file — **save it securely, it can only be downloaded once**
5. Note the **Key ID** and **Team ID** (shown in account settings top-right)

---

## Step 3 — Upload new APNs key to both Firebase projects

Do this for **both** Firebase projects:

### TripManagement (`tripmanagement-5ec73`)
1. Firebase Console → TripManagement → Project Settings → **Cloud Messaging**
2. Apple app configuration → **APNs Authentication Key** → Upload
3. Upload the `.p8` from Step 2, enter Key ID and Team ID

### PropertyManagement (`propertymanagement-e49e3`)
Same steps, same `.p8` key (one key works across multiple apps/projects).

---

## Step 4 — Regenerate code signing under the LLC account

1. In Xcode → Preferences → Accounts → add the LLC Apple ID
2. For each app target, set **Team** to the LLC account
3. Let Xcode auto-manage signing, or manually:
   - Generate a new **Apple Distribution** certificate under LLC
   - Regenerate **App Store** provisioning profiles for each bundle ID
   - Update profiles in Xcode

Bundle IDs do NOT change — they transfer with the app.

---

## Step 5 — Update RevenueCat

RevenueCat is linked to App Store credentials from the original account.

1. RevenueCat Dashboard → **Project Settings → App Store Connect API**
2. Generate a new API key under the LLC App Store Connect account
3. Update the key in RevenueCat
4. Re-verify the **App-Specific Shared Secret** for each app (used for receipt validation)

---

## Step 6 — Update keychain access groups (if used)

Keychain access group identifiers are prefixed with the Team ID (`OLDTEAMID.com.yourapp`).
After migration the Team ID changes, so any hardcoded keychain group identifiers must be updated
in the app's `.entitlements` files.

Check both apps:
- `ios/Runner/Runner.entitlements` — look for `keychain-access-groups`
- Update `OLDTEAMID` → `NEWTEAMID` if present

---

## Step 7 — Ship new builds signed with LLC certificates

1. Update bundle version / build number
2. Archive and upload both apps from Xcode using the LLC account
3. Submit for review (or distribute via TestFlight first to validate push)

---

## Step 8 — Validate push notifications

After the new build is live (or via TestFlight):
- Send a test push notification to an iOS device
- Confirm it arrives — this validates the new APNs key is wired correctly in Firebase

---

## Post-migration cleanup

- [ ] Remove personal account's APNs key from both Firebase projects (after LLC key is confirmed working)
- [ ] Revoke old Distribution certificates from the personal account
- [ ] Delete old provisioning profiles
- [ ] Delete the APNs `.p8` file from Downloads after uploading to Firebase

---

## What is NOT affected by this migration

| Service | Reason |
|---|---|
| Firebase projects | Tied to Google account, not Apple |
| Supabase | Independent of Apple account |
| Google Maps / Places / Directions | Tied to Google Cloud project |
| Gemini API | Tied to Google account |
| Android / Google Play | Separate migration if needed |
| App Store ratings & reviews | Preserved during app transfer |
