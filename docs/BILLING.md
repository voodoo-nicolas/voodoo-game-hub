# Billing: products to create in Play Console

Source of truth for the ids: `scripts/common/config.gd` (`STORE_*`). The server
(`supabase/functions/_shared/store.ts`) and `tools/hub.py` carry copies;
`python tools/hub.py check` fails if they differ. The full list for Play
Console: `python tools/hub.py products` → `builds/play_products.csv`.

All products are **auto-renewing subscriptions** (since 2026-11-19; the old
one-time $0.99 game purchases and `hub_all` were never live).

| Product id | Base plan | Price | Offers |
|---|---|---|---|
| `hub_monthly` | `monthly` (auto-renewing, 1 month) | USD 4.99 | One offer for new subscribers: **7-day free trial**, then **USD 2.99/month for 3 billing periods**, then USD 4.99 |
| `game_<id>_monthly` (one per paid game) | `monthly` (auto-renewing, 1 month) | USD 1.00 | none |

- Per-game trial: **3 days**, ours, server-side (`store_trials`, no card, signed-in players only). Set by the manifest's `"store": {"trial_days": 3}`.
- Free games (`"free": true` in the manifest, 14 today) get no product.
- Today: 115 game subscriptions + 1 hub subscription (`hub.py products`).
- Play package: `com.viral.gamehub` (Config.PLAY_PACKAGE; Edge Function env `PLAY_PACKAGE_NAME`).
- Ids: lowercase, start with a letter, max 40 characters — game ids are ≤40 (checked), so `game_` + id + `_monthly` stays within Play's limit.

## In the app
- Paywall: price, trial length, trial end date, "Renews monthly. Cancel any time in Google Play.", **Restore purchases**.
- Options → ⭐ Membership: status, Manage subscription, **Restore purchases** (shown while the store is switched on).
- Restore = query Google Play for this account's subscriptions → each token goes to `purchase-verify` → Supabase entitlements re-synced → hub redraws.
- The whole store stays off until the manifest says `"store": {"enabled": true}`.

## Steps for you in Play Console
1. Monetize → Subscriptions → create `hub_monthly`, base plan `monthly`, USD 4.99, then the offer (free trial 7 days + intro USD 2.99 × 3 periods, eligibility: new customers).
2. Create `game_<id>_monthly` for each row in `builds/play_products.csv` (base plan `monthly`, USD 1.00).
3. License testers + closed testing track; server go-live steps in `docs/monetization/LAUNCH_CHECKLIST.md`.
