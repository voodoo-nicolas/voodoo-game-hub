# Account deletion

Google Play requires that players can delete their account both in the app and
on the web. Since 2026-11-19 **we delete everything and keep nothing** (owner
decision: no purchases exist yet, so there are no tax or refund records to keep).

## How a player deletes their account
- **In the app:** Profile → scroll to the bottom → red **Delete account** →
  read what is deleted → (optional) **Open Google Play subscriptions** to cancel
  subscriptions → type `DELETE` → confirm. The app calls the `delete-account`
  Edge Function, signs out, clears this account's local files and goes back to
  the hub home. Offline or a server error shows the reason and a **Retry**.
- **Without the app:** https://viralgamehub.github.io/delete.html → email
  Viralgamingservice@gmail.com, subject "Delete account", from (or naming) the
  account's email. We process it within **30 days**, by running the same
  deletion (Supabase dashboard → Authentication → find the user → note the id →
  call the function as that user, or delete the rows below by hand + delete the user).

Deleting the account does **not** cancel Google Play subscriptions. Google
bills them, not us. The app and the web page both say this.

## What the function deletes (`supabase/functions/delete-account/handler.ts`)
For the caller's user id, in this order. Missing tables are skipped.

| Table | Column | What it held |
|---|---|---|
| `responses` | `session_id` (the user's sessions) | IQ test answers |
| `section_scores` | `session_id`, `user_id` | IQ section scores |
| `blitz_best` | `user_id` | IQ blitz bests |
| `daily` | `user_id` | IQ daily results |
| `duel_results` | `user_id` | IQ duel results |
| `duels` | `created_by` | IQ duels the player created |
| `certificates` | `user_id` | IQ result certificates |
| `scores` | `user_id` | leaderboard rows |
| `player_awards` | `user_id` | achievements earned |
| `game_progress` | `user_id` | cloud saves / progress |
| `user_favorites` | `user_id` | ★ favorites across devices (since 2026-11-20; also cascades from `auth.users`) |
| `friendships` | `requester` **and** `target` | friends and friend requests, both directions |
| `game_invites` | `sender` **and** `recipient` | online game invites / room invitations, both directions |
| `store_trials` | `user_id` | free-trial start dates |
| `store_entitlements` | `user_id` | subscriptions, grants, purchase tokens, order ids |
| `user_purchases`, `purchase_history` | `user_id` | legacy store tables (if they still exist) |
| `founders` | `email` | founder (lifetime) list entry, if any |
| `user_consents` | `user_id` | which Terms/Privacy versions were accepted |
| `client_reports` | `user_id` | bug/feedback reports sent from the app |
| `player_cards` | `user_id` | public player card (gamer tag, avatar, presence) |
| `sessions` | `user_id` | IQ test sessions |
| `profiles` | `id` | profile (nickname, age bracket, country, language) |
| `auth.users` | id | the sign-in itself (email, password hash, Google/Facebook links), via `auth.admin.deleteUser` |

Online rooms use Supabase Realtime channels only (no table); nothing is stored.

## What is kept
**Nothing.** Retention after the request: 0 days in the live database (deleted
at once). Any Supabase backups roll over in their normal cycle (owner: confirm
the plan's backup retention -- Pro keeps daily backups 7 days, Free none);
a deleted account is never restored from them.
Google Play keeps its own order records under Google's privacy policy.

## On the phone
After a successful deletion the app removes `user://store.json`,
`awards_synced.json`, `consent.json`, `online_room.json`, `online_table.json`,
`social_prefs.json` and the sign-in session. Game saves and stats on the phone
are not account data and stay (the player can clear them in Options → Storage
or by uninstalling).

## Deploying
```
supabase functions deploy delete-account
```
Keep JWT verification ON (the default). `SUPABASE_SERVICE_ROLE_KEY` is provided
by Supabase to every function; it is never in the APK. The old
`docs/delete_my_account.sql` RPC is superseded (leave it; old APKs may call it).

## Adding a table
Any new table holding player data goes into `USER_ROWS` and into this file in
the same commit (STANDARDS.md, "User data and account deletion").
