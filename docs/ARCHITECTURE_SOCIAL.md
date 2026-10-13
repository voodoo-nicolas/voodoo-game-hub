# Social + Viral XP: data model (2026-10-13)

Everything runs through Supabase RPC functions (`security definer`, acting only for `auth.uid()`); clients never touch the tables (RLS on, no policies). Migrations are run by the owner: `supabase/migrations/20261004000000_friends.sql`, `20261012000000_presence_avatar.sql`, `20261013000000_awards_player.sql`. Client side: `Auth`, `Social` autoloads, `scripts/common/achievements.gd`, `avatar.gd`.

| table | key | holds |
|---|---|---|
| `auth.users` | id | Supabase accounts (email sign-in only) |
| `player_cards` | user_id | friend_code, display_name, last_seen (heartbeat), **current_game**, **avatar** (`p<n>` or `img:<base64 jpeg 256px>`), **viral_power**, **visibility** (`friends`/`private`) |
| `friendships` | (requester, target) | accepted flag; one row per pair |
| `game_invites` | id | transient room invites (cleared on read / after a day) |
| `player_awards` | (user_id, game_id, challenge_id) | **the award log**: title, icon, xp (0-200), earned_at. Insert-only; `viral_power` = `sum(xp)` recomputed on every report |

**Games / challenges** live in the app and the packs, not the database: `manifest.json` (id, family, modes, quick, original...) and each game's `<id>_help.gd` (`STATS`, `ACHIEVEMENTS`, `CHALLENGES`). The server only stores what was earned.

| RPC | does |
|---|---|
| `social_me`, `social_add`, `social_respond`, `social_remove`, `social_list` | friend code, requests, list (with online, avatar, current game, Viral Power; power hidden for `private`) |
| `social_set_presence(game)` | "I'm in `game`" (`''` = menus); presence is online if `last_seen` < 3 min |
| `social_set_avatar`, `social_set_visibility` | profile settings |
| `xp_report(awards[])` | add new awards (idempotent, per-challenge and per-game caps, 100 per call), return my Viral Power |
| `player_overview(other)` | a friend's games with XP (`{private:true}` if they hid it; null if not a friend) |
| `player_compare(other, game)` | both players' awards in one game |
| `delete_my_account()` | deletes the auth user; every table above cascades |

**Presence:** the app calls `social_me` (+ `social_set_presence`) every 60 s while open; the hub reports `""` and each game launch reports its id. Offline = no heartbeat for 3 minutes.

**Awards flow:** badge unlocked (stats rule, `ACHIEVEMENTS`, or `report_challenge`/`on_event`) -> local log (`stats_<id>.json` `_ach`, `challenges_<id>.json`) -> `Social.sync_awards()` (hub open, first heartbeat, after a report) sends keys not in `user://awards_synced.json` -> `player_awards` -> `viral_power`. Spoofable (client-reported); see `docs/ADDING_A_GAME.md`.

**Account deletion semantics (in force now):** Profile -> Danger zone -> type gamer tag or DELETE -> RPC deletes the auth user; `player_cards`, `friendships` (both directions, so friends' lists lose the entry), `game_invites`, `player_awards` cascade (scores too only if its foreign key cascades: `docs/delete_my_account.sql` says to verify; not checked against production). Not done: password re-authentication, a 30-day grace period, or an export. Local saves on the phone stay.
