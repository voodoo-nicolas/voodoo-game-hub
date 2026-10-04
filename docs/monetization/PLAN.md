# Monetization plan — trials, $1 games, hub subscription

**Status: APPROVED plan (2026-10-04), decisions at the bottom. Nothing here
is built or live yet.**
Target: the next big release. Until the plan is approved, nothing in this folder ships, and nothing goes into
`supabase/migrations/` (so it can't be run by accident).

## The ask (as given)

- Every game playable free for **3 days** from its first play.
- Then: buy that game (**$0.99**) or subscribe to the whole hub
  (**$4.99 / month**, all games).
- Entitlements stored in Supabase; paywall at trial end with a clear
  $1 vs $5 choice; Google Play Billing for payment.
- Keep the manifest (modes, categories) and the account system as they are.

## Things that change the shape of the plan

These come from how the project works today, and each one is a decision
for you (see "Decisions" at the bottom).

1. **Google Play Billing only works in an app installed from the Play
   Store.** Today the APK is sideloaded from GitHub Releases, and the
   Android Developer Console account is *Personal, Limited distribution*.
   Selling anything means a Play Store listing (Play Console, $25 one-time,
   merchant/payments profile for payouts, privacy policy, content rating,
   the Wordle rename). Google's policy also *requires* Play Billing for
   digital goods sold inside a Play app — no Stripe/PayPal links.
2. **Billing needs a Gradle Android build.** `export_presets.cfg` has
   `use_gradle_build=false` and no plugins. The billing library comes from
   the official Godot plugin (`godot-sdk-integrations/godot-google-play-billing`,
   an Android v2 plugin for Godot 4.2+), which needs the Android build
   template installed and `hub.py apk` switched to a Gradle export. This is
   the biggest infrastructure step and can be done (and tested) **before**
   anything is charged.
3. **"Free, no login wall" vs. tracking trials.** A trial needs an identity
   that survives reinstall. Options:
   **Decided: signed-in players only** (Decision 4). Options considered:
   - Supabase anonymous sign-in: every install silently
     gets a real `auth.uid()`; signing up later upgrades the same user, so
     trials and purchases follow them. Still no login screen.
   - Trials only for signed-in players (a soft login wall — against the
     project's rule).
   - Trials stored on the phone only (reinstall = new trial; simplest,
     leakiest).
   Purchases themselves don't need any of this: Google ties them to the
   Google account and the app can always restore them from Play.
4. **The client is the only lock.** The repo is public and packs are
   public GitHub downloads, so anyone determined can play without paying.
   That's normal for a $1 game; the gate is a nudge for honest players,
   not DRM. Don't spend effort hardening it.
5. **Old apps have no gate.** Packs also run on every older APK. At launch
   every paid pack gets `"min_build": <launch build>`, so old apps show
   "Update app" instead of playing for free forever.
6. **The pitch changes.** CLAUDE.md and the store text say "free, ad-free".
   It becomes "free to try, ad-free" — worth saying deliberately, and worth
   deciding whether a set of games stays free forever (see Decisions).
7. **The trial clock must be the server's.** The phone's date is
   user-editable; `started_at` comes from Postgres `now()`, and the client
   only caches it for offline play.

## Architecture

```
 tile tap / resume / invite          Store (autoload, APK)                 Supabase
 ─────────────────────────►  Store.gate(id, launch)  ──── store_status() ──►  trials, entitlements
                                │   cached in user://entitlements.json         (RPC, read own rows)
                                │                    ──── store_start_trial(id) ─► (RPC, server time)
                                ▼
                       allowed? ── yes ─► Catalog.mount + change_scene (as today)
                                └─ no ──► Paywall overlay ── Buy / Subscribe ──► Play Billing (plugin)
                                                                                  │ purchase token
                                          ◄── entitlement row ── purchase-verify ◄┘ (Edge Function:
                                                                 Google Play Developer API,
                                                                 acknowledges, writes row)
                             Google RTDN (Pub/Sub push) ──► play-rtdn (Edge Function):
                                                            renewals, cancels, refunds, holds
```

### Client (all APK-side: `scripts/common/`, `scripts/hub/`)

- **`scripts/common/store.gd`** — new autoload `Store` (PROCESS_MODE_ALWAYS).
  - `access(game_id) -> Dictionary`:
    `{state: "free" | "trial" | "trial_over" | "owned" | "subscribed" | "new", days_left, hours_left}`.
  - `gate(game_id, on_allowed: Callable)` — the one call every launch path
    uses; shows the paywall itself when needed.
  - `start_trial(id)`, `buy_game(id)`, `subscribe()`, `restore()`,
    `manage_subscription()` (opens Play's subscription page).
  - Signals `entitlements_changed`, `purchase_failed(reason)`.
  - Wraps the billing plugin through `Engine.has_singleton("GodotGooglePlayBilling")`;
    without it (PC build, sideloaded APK, tests) it reports
    `billing_available = false` and follows the policy in Decision 5.
  - Offline: trusts the cached state; a subscription stays valid offline
    until its `expires_at` plus a few days' grace.
  - Kill switch: `manifest.json` top-level `"store": {"enabled": false, "trial_days": 3}`
    read via Catalog. Off = everything free (today's behaviour). This lets
    the gate ship dark in an APK and be switched on without another release,
    and changes trial length without an APK.
- **Gate points in `hub.gd`**: `_launch()` is reached from the tile tap,
  `_resume_last_game()` and invite/Multiplayer launches
  (`Social.take_launch_request()` → `_on_tile_pressed`), so gating at the
  top of `_launch()` (via `Store.gate`) covers every path. A game already
  open keeps running if its trial ends mid-session; the next launch is gated.
- **`scripts/hub/paywall.gd`** — modal in the hub's dialog style (neon,
  `Settings.palette()`): game icon + title, "Your 3-day trial has ended"
  (or "Try free for 3 days" on first tap), two big choices
  **Buy {title} — $0.99** / **All 100 games — $4.99/month (first 3 months $2.99)**, small
  "Restore purchases", "Not now". Prices come from Play
  (`queryProductDetails`), never hard-coded, so they show in local currency.
  Subscription terms text as Play policy requires (renews monthly, cancel
  any time in Google Play).
- **Tiles**: a small badge per state — "3 days left", "Trial over" (dim,
  not red — see hub look rules), owned/subscribed show nothing.
- **Options**: "⭐ Membership" row — status, Subscribe / Manage, Restore.
- **Games need no code change.** Nothing in a pack knows about the store.

### House promos ("ads for the hub" — no ad network, ever)

Our own cards, promoting the subscription and other games. Decided
2026-10-04: no third-party ads, so "ad-free" stays true.

- **Where**: a card that slides up a moment after a game ends
  (`GameInfo.result()` / `celebrate()` — APK-side, so every game gets it
  with no game code), reusing the achievement toast's slide-in but
  tappable, with a ✕. Not on game Home screens: the Home kit lives in
  each pack, and promos stay APK-side so they can change without
  re-exporting 100 packs.
- **What** (picked by `Store.promo_for(game_id)`):
  - trial / free game, not subscribed → "All 100 games — 7 days free";
  - owns this game only → "Unlock the other 99 for $4.99/mo";
  - otherwise → "Liked Snake? Try Sky Hop" (a game from the same category
    the player hasn't tried — Achievements already tracks games tried).
- **Rules**: never during play; never to subscribers (cross-promo of
  other games still allowed, rarer); at most one per 3 finished games and
  one per 10 minutes (counters in `user://store.json`); never in an online
  match; manifest `"store": {"promos": false}` turns them off remotely.
- **Tap**: subscribe → Play's purchase sheet straight from the game
  (`Store` is an autoload); "Try X" → `Social.launch_request = id` + go to
  the hub, the same path invites use.

### Online play

Recommended: **only the host needs access**. A guest invited into a room
plays that match free (the invite/join path passes a flag past the gate).
Every online match is then an ad for the game. Locked-out guests joining
by code are the same thing.

### Server (Supabase)

Draft SQL: [`entitlements_draft.sql`](entitlements_draft.sql).

- `store_trials (user_id, game, started_at)` — one row per user per game,
  `started_at default now()`; never updated.
- `store_entitlements (user_id, product_id, kind, state, expires_at,
  purchase_token unique, order_id, source, updated_at)` — kind `game` /
  `hub`; source `play` / `grant` (free unlocks you hand out: testers,
  friends, refunds-by-hand).
- RLS on, **no client write policies**. Clients call:
  - `store_status()` → my trials, my live entitlements, and server `now()`.
  - `store_start_trial(game)` → inserts if absent, returns `started_at`
    (idempotent: a second call can't restart a trial).
- **Edge Function `purchase-verify`** (`{token, product_id}`): calls the
  Google Play Developer API (`purchases.products` / `purchases.subscriptionsv2`)
  with a service-account key stored as a function secret, checks the
  `obfuscatedAccountId` matches the caller, **acknowledges the purchase**
  (Google auto-refunds anything not acknowledged within 3 days), and upserts
  the entitlement.
- **Edge Function `play-rtdn`**: Pub/Sub push endpoint for Real-time
  Developer Notifications — renewals extend `expires_at`; cancel (keeps
  access to period end), grace period (keeps access), on hold / expired /
  revoked / voided (refund) remove it. Verify the Pub/Sub JWT.
- Both follow the Voodoo IQ functions' layout (`index.ts` + `handler.ts`,
  tests on a FakeDb in `_tests/`).

### Google Play products

| Product id | Type | Price |
|---|---|---|
| `game_<id>` (one per paid game, e.g. `game_chess`) | one-time, non-consumable | $0.99 (except Voodoo IQ) |
| `hub_all` — base plan `monthly` | subscription | $4.99/month; offers: 7-day free trial, then intro $2.99/month for 3 months |
| `game_voodoo_iq` | one-time, non-consumable | $1.99 (also in `hub_all`) |

`hub.py products` (to write) generates the list from `manifest.json` for
bulk entry; `hub.py check` verifies every paid game has a product id. Each
purchase is tagged with `obfuscatedAccountId = auth.uid()` so the server can
link it to the player.

## Build order (each phase shippable on its own, store stays switched off)

0. **Prep — now.** This plan + draft SQL. Answer the decisions below.
1. **Play Store groundwork.** Play Console app + internal testing track,
   Gradle build + billing plugin in `hub.py apk`, privacy policy page
   (`docs/`), Wordle rename. Ship an APK through the internal track with
   the store **off** — proves the build pipeline without charging anyone.
2. **Identity.** None needed beyond today's accounts (trials are for
   signed-in players, Decision 4). The paywall's first screen for a
   logged-out player is "Sign in to start your free trial".
3. **Server.** Tables + RPCs (you run the SQL), `purchase-verify`,
   `play-rtdn`, Google Cloud service account + Pub/Sub topic. Tested with
   Play's license-tester accounts (test purchases cost nothing).
4. **Client.** `Store` autoload, paywall, tile badges, Options row, gate in
   `_launch()`. Tested end-to-end on the internal track with license testers.
5. **Launch.** Grants for existing testers, `min_build` on paid packs,
   `"store": {"enabled": true}` in the manifest, Play production release.

Rough size: phase 1 is the riskiest (build tooling); phases 3–4 are a
couple of sessions each, similar to Voodoo IQ's backend + client.

## Implementation map (read 2026-10-04, for the build sessions)

Findings from reading the code, so tomorrow starts at the keyboard.

**Play Store requirements found while reading**
- New Play apps must upload an **Android App Bundle (.aab)**, not an APK:
  `export_presets.cfg` `gradle_build/export_format=1` for the Play preset;
  `hub.py` gets an `aab` command next to `apk` (keep `apk` for local/PC
  testing). Needs `use_gradle_build=true` + Godot's Android build template
  installed into the project (`android/` folder — mostly gitignored).
- **Target SDK**: Play requires a recent `targetSdk` (API 35 since Aug
  2025, likely 36 by Aug 2026) — check what Godot 4.7.2 defaults to and
  install that platform; build-tools here are 34.0.0.
- Billing plugin: `godot-sdk-integrations/godot-google-play-billing` (v2
  Android plugin, goes in `addons/`, enabled in project settings). Check
  its 4.7 compatibility and the Play Billing Library version it bundles
  (Play requires PBL 7+).
- Play App Signing with our own key: upload `voodoo-release` via Play's
  PEPK tool when creating the app (Decision 5).

**Client — new files (APK)**
- `scripts/common/store.gd` — autoload `Store`, registered in
  `project.godot` after `Social` (it uses `Auth.db_call`, `Catalog`).
  `PROCESS_MODE_ALWAYS`. Pure helpers kept static for headless tests:
  `static func access_state(game, status, now, cfg) -> Dictionary`,
  `static func promo_pick(...)`. Cache `user://store.json`.
- `scripts/hub/paywall.gd` — overlay built like `hub.gd`'s
  `_build_dialog_frame` (same neon dialog look), reachable from the hub
  and from Options.
- `tools/test_store.gd` — headless: trial math (server `now` vs
  `started_at`, 72 h edge, offline cache, clock set back), entitlement
  precedence (free > sub > owned > trial), promo frequency caps.

**Client — edits (APK)**
- `scripts/common/catalog.gd` `_apply_manifest()`: carry `"free"` from the
  category entry (like `modes`/`board`), and read a top-level `"store"`
  block into `Catalog.store_config` (missing = `{enabled: false}`).
- `scripts/hub/hub.gd`: `_launch()` (line ~544) starts with
  `Store.gate(game, _launch_now)`; that one spot covers tile taps,
  `_resume_last_game()` and `Social.take_launch_request()`. Online guests:
  `Social.pending.mode in ["join"]` passes the gate. `_make_tile()` (~440)
  adds the trial badge.
- `scripts/hub/options_screen.gd`: new "⭐ Membership" `_section` next to
  Account (status, Subscribe / Manage, Restore purchases).
- `scripts/common/game_info.gd`: after `result()` / `celebrate()`, ask
  `Store.promo_for(ID)` and show the promo card (toast code at ~600 is the
  model; make it tappable).
- `scripts/common/config.gd`: `const PLAY_BUILD := false` flipped by the
  Play export (custom feature `play` → `OS.has_feature("play")` is
  cleaner, no file edit): skips `Catalog.check_app_update()` and hides
  Options' "Check for updates".
- `tools/i18n/es.json` + `hub.py i18n` for every new string.

**Server**
- `supabase/migrations/<date>_store.sql` from `entitlements_draft.sql`.
- `supabase/functions/purchase-verify/`, `supabase/functions/play-rtdn/`
  (`index.ts` + `handler.ts`), `_shared/play.ts` (service-account JWT →
  OAuth token via WebCrypto RS256, Play Developer API calls),
  `_tests/store_test.ts` on the FakeDb with a fake Play API.
- Secrets (user sets with the Supabase CLI): `PLAY_SERVICE_ACCOUNT_JSON`,
  `PLAY_PACKAGE_NAME=com.viral.voodoo`.

**Tooling**
- `hub.py products` → CSV of `game_<id>` products from manifest (paid
  games only, Voodoo IQ at 1.99); `hub.py check` → every paid game has a
  valid product id, the free list ⊂ catalog.
- `hub.py aab` (Play bundle), `hub.py apk` unchanged.

**Manifest**
- `"free": true` on the 13 free games' category entries (older apps ignore
  unknown fields, so this can be pushed any time).
- `"store": {"enabled": false, "trial_days": 3, "promos": true}` — flip
  `enabled` at launch.

**Docs**: CLAUDE.md gets a "Store" section and the softened login-wall rule
when this ships.

## Decisions (approved 2026-10-04)

1. **Free forever set** (`"free": true` in the manifest; playable signed
   out, no trial). One per category so no category is all-locked.
   Proposed, adjust freely: Tic-Tac-Toe, Connect Four, Sudoku, Minesweeper
   (Puzzle & Board); Trivia (Intelligence); Solitaire (Cards); Hangman,
   Word Search (Word); Snake, Brick Breaker (Arcade); Yacht (Dice & Party);
   King's Cup (Drinking); Party Spinner (Other) — 13 games.
2. **Trials: both.** Each paid game gets our own 3-day trial (no card).
   The hub subscription gets **Play's built-in 7-day free trial** offer
   (Play asks for a payment method, auto-renews unless cancelled, one
   trial per Google account).
3. **Prices: $0.99 / game; Voodoo IQ $1.99; hub $4.99 / month with an
   intro price of $2.99 / month for the first 3 months** (a Play
   subscription offer; it stacks after the 7-day trial). All set in Play
   Console, never in code.
4. **Trials need a signed-in account.** Soft login wall for paid games
   only; free games stay account-free. (Relaxes the "never a login wall"
   rule in CLAUDE.md — update that section when this ships.)
5. **Testers don't pay** — through grants (6) and Play license testers,
   not a special build. **The public GitHub APK stops** once the Play
   listing is live; testers move to Play's internal/closed track.
   - **Upload the existing `voodoo-release` key to Play App Signing**
     (don't let Google generate one), so today's sideloaded installs
     update from Play in place — no uninstall, no lost saves.
   - Play builds turn off the GitHub self-update check (a `Config` flag
     set by the Play export).
6. **Grants: yes.** Lifetime `grant_all` for current testers/friends; the
   user sends the account list, Claude writes the SQL, the user runs it.
7. **Voodoo IQ: whole game paid** ($1.99 alone, included in the hub sub),
   with the same 3-day trial as other games.
8. **Payouts:** the user has a Play payments profile.
