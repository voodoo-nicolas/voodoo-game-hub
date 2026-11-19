# Store launch checklist

Exact steps for PLAN.md's "Still to do". Nothing here switches the store on:
that is the very last step, and only `manifest.json`'s
`"store": {"enabled": true}` does it.

Paths are from the `store` worktree (`C:\Users\nick_\code\voodoo-game-hub-store`).
Godot = `C:\Users\nick_\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`.
Supabase CLI = `%LOCALAPPDATA%\Programs\supabase\supabase.exe`, project ref `swyzfsyvmqxabhvvhhtn`.

## A. Test on PC first (no Play, no server writes)

1. Back up `%APPDATA%\Godot\app_userdata\Voodoo` (tests share the PC build's saves).
2. Headless test (switches the store on in memory only, restores `user://store.json`):
   ```
   & $godot --headless --path . --script res://tools/test_store.gd
   ```
3. Play it by hand with the store forced on and purchases faked
   (PowerShell, from the worktree):
   ```
   $env:HUB_STORE="1"; $env:HUB_FAKE_BILLING="1"; & $godot --path .
   ```
   Check, signed out then signed in:
   - a free game (e.g. Sudoku) opens straight away, no card;
   - a paid game signed out -> "Sign in to play ... free for 3 days";
   - signed in -> "Start 3-day free trial" opens the game, tile shows "⏳ 3 days left";
   - Buy / All games -> unlocks at once (fake purchases live only in memory +
     `user://store.json`, never on the server);
   - Options -> membership line, Restore purchases, Manage subscription;
   - a finished game sometimes shows a promo card (at most 1 per 3 games, 10 min apart).
   Without a sign-in, Buy says "Sign in first" -- that's correct.
4. Restore the backup when done (fake entitlements stay in `store.json` otherwise).

## B. Play Console (you)

1. Upgrade the developer account to Full distribution ($25, ID check) if not done.
2. Create the app `com.viral.voodoo`: listing, privacy policy URL, content
   rating questionnaire, data safety form, target audience. Rename Wordle first.
3. Play App Signing: **upload the existing `voodoo-release` key** (never let
   Google generate a new one -- sideloaded installs must keep updating).
4. Billing plugin + Gradle build (Claude) -- **done 2026-10-05**: plugin
   3.3.0 in `addons/GodotGooglePlayBilling/` (enabled), preset `AndroidPlay`
   (Gradle, `.aab`, `play` feature, target SDK 36), `python tools/hub.py aab`
   -> `builds/voodoo-vX.Y.Z-play.aab`, signed with the release key (checked:
   same SHA-256 as `voodoo-release`), BILLING permission in. First run ~25 min
   (downloads), later ~12 min. The sideloaded APK still exports, unchanged.
5. Upload the first `.aab` to the **Internal testing** track (products can only
   be created once an app bundle with the billing permission is uploaded).
6. Products:
   ```
   python tools/hub.py products      # -> builds/play_products.csv
   ```
   - **One-time products** (Monetize -> Products -> In-app products): one row of
     the CSV each, product id exactly `game_<id>`, price $0.99
     (`game_voodoo_iq` $1.99). Let Play convert the price to other countries.
     Free games are already left out of the CSV.
   - **Subscription** (Monetize -> Subscriptions): product id `hub_all`, base
     plan id `monthly`, auto-renewing, 1 month, $4.99.
     **One** offer on that base plan, offer id `trial-intro` (eligibility: new
     customer acquisition, "never had this subscription"), with two phases:
       1. free trial, 7 days;
       2. introductory price, $2.99 per month for 3 billing periods.
     It must be one offer, not two: a purchase can use only one offer, and
     `store_billing.gd` buys the best one Play lists for that account (Play
     stops listing it once the account has used it -> full price, and the
     paywall's terms drop the trial text).
   - Activate everything.
7. License testers (Setup -> License testing): your and testers' Google
   accounts, response "RESPOND_NORMALLY" -- they buy with test cards, no charge.

## C. Server (you run, Claude prepares)

1. SQL editor: run `supabase/migrations/20261005000000_store.sql` once.
2. Google Cloud: a service account in the project linked to Play Console;
   download its JSON key. Play Console -> Users and permissions -> invite the
   service account's email with "View financial data" and "Manage orders and
   subscriptions". (Can take up to 24 h to start working.)
3. Secrets (PowerShell; the JSON goes in as one line):
   ```
   & $supa secrets set --project-ref swyzfsyvmqxabhvvhhtn PLAY_SERVICE_ACCOUNT_JSON="$(Get-Content key.json -Raw)"
   & $supa secrets set --project-ref swyzfsyvmqxabhvvhhtn PLAY_RTDN_TOKEN=<32+ random letters>
   ```
   (`PLAY_PACKAGE_NAME` defaults to `com.viral.voodoo`; set it only if that changes.)
   Delete `key.json` from disk afterwards; never put it in the repo.
4. Deploy:
   ```
   & $supa functions deploy purchase-verify --project-ref swyzfsyvmqxabhvvhhtn --use-api
   & $supa functions deploy play-rtdn --project-ref swyzfsyvmqxabhvvhhtn --use-api --no-verify-jwt
   ```
5. Real-time notifications: Google Cloud Pub/Sub topic (e.g. `play-rtdn`),
   grant `google-play-developer-notifications@system.gserviceaccount.com`
   "Pub/Sub Publisher" on it, push subscription to
   `https://swyzfsyvmqxabhvvhhtn.supabase.co/functions/v1/play-rtdn?token=<PLAY_RTDN_TOKEN>`.
   Play Console -> Monetization setup -> topic name -> "Send test notification"
   (the function log should show it, 200).
6. Tester grants (free access without paying): see the comment at the end of
   the migration.

## D. Internal-track test with real Play Billing

On a phone installed from the internal track, signed in with a license tester:
buy one game, subscribe, cancel in Play, Restore purchases on a second phone,
a pending payment ("slow test card"), a refund from Play Console (RTDN should
remove the entitlement). Check rows in `store_entitlements`.

## E. Launch

1. Merge `master` into `store`, retest A, then merge `store` into `master`.
2. Paid packs that need the store's APK: `"min_build"` on their `games` entries.
3. `hub.py bump-app minor`, build, release (Play + GitHub APK until the Play
   listing replaces it -- PLAN.md Decision 5).
4. Update CLAUDE.md's "never a login wall" rule (paid games need sign-in for a trial).
5. Last: push `manifest.json` with `"store": {"enabled": true, ...}`.
   Switching it back to false reopens every game instantly.
