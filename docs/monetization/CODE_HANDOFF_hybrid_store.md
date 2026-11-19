# Handoff for Claude Code: hybrid freemium + hub upsell

Put this file in `docs/monetization/` (next to PLAN.md) and tell Claude Code:
"Read docs/monetization/CODE_HANDOFF_hybrid_store.md and do the tasks in it."

---

## Read first

`docs/monetization/PLAN.md` holds the decisions. `scripts/common/store.gd`,
`store_billing.gd`, `paywall.gd` and `supabase/migrations/20261005000000_store.sql`
already implement trials, $0.99 per game, the hub subscription, Play Billing,
server verification and promo cards.

## Do NOT build

A chat session earlier drafted these. They duplicate the existing store, so skip them:

- EntitlementsManager.gd
- GameLauncher.gd (use `Store.gate(game, on_allowed)`)
- IAPManager.gd
- a second PaywallScene
- the chat-drafted SQL (`user_purchases`, `purchase_history`, `can_access_game`, etc.)

## Strategy the code must serve

1. Every paid game has a free trial (manifest `trial_days`, currently 3).
2. After the trial the player chooses: $0.99 for that one game, or the hub
   subscription (all games). The hub is the product we want people to pick.
   The games are its marketing.
3. Games can also be listed on Google Play on their own, as funnels into the hub.
4. Goal: 100 simple games live, then switch monetization on.

## Tasks

### 1. Fix Air Hockey's manifest entry
It has no `modes`, `title_es` or `board`. Without `modes` it won't show on the
Multiplayer screen. Use `"modes": "local,cpu"` and copy `title_es` / `board`
from Paddle Ball and the other new arcade games.

### 2. Audit paywall.gd against the strategy (report, then change only what diverges)
- Does the paywall present the hub as the recommended option and the $0.99
  game as the secondary one?
- Does it show the hub's trial and intro price via `Store.subscription_terms()`?
- Does it say what the hub includes (`Store.game_count()` games)?
- Does a player who already owns a game, or is subscribed, never see a
  double-charge path?
Tell me what you found before editing anything on the paywall.

### 3. Free-tier funnel
Propose which games should be `"free": true` in the manifest. Suggest about
10 to 15, spread across categories, favoring the most engaging ones and the
online-multiplayer board games (they bring a second player in). Apply the
change to the manifest. It does nothing while the store is off.

### 4. Launch checklist (do not flip the store on)
Do not set `"store": {"enabled": true}` in the live manifest. Produce a
checklist with exact steps for:
- Play Console products: `game_<id>` per paid game, and the `hub_all`
  subscription with its 7-day trial and 3-month intro offer
- deploying the `purchase-verify` edge function and its secrets
- testing on PC with `HUB_STORE=1 HUB_FAKE_BILLING=1`
- running `tools/test_store.gd`

### 5. Standalone per-game Play listings (research only)
Report what the build pipeline would need to ship single games as separate
Play listings (package ids, pack/flavor setup) and how a standalone build
should point players to the hub. No implementation yet.

### 6. Supabase sanity check
The user ran part of a chat-drafted SQL in Supabase, and hit
`trigger "on_auth_user_created" for relation "users" already exists`.
That trigger name is common for profile creation. Check the project's migrations:
- do NOT drop `on_auth_user_created`
- list whether `user_purchases` and `purchase_history` exist and whether
  anything in the app uses them
- if they are unused leftovers, tell me and I'll decide whether to remove them

## Report back
One short message per task: what you found, what you changed, what needs my decision.
