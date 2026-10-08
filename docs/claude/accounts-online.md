# Accounts, online play, friends, leaderboards, achievements (APK-side)

All in `scripts/common/` / `scripts/hub/`: every game gets them with no game code unless noted.

## Accounts (Supabase)
- App is fully playable with zero account; accounts are additive, never a login wall.
- `scripts/common/auth.gd` (autoload `Auth`): Supabase Auth + PostgREST over plain `HTTPRequest` (follow `hub.gd`'s HTTP convention). API: `sign_up`, `sign_in`, `sign_out`, `request_password_reset`, `is_logged_in`, `get_display_name`, `reconcile_stat`/`push_stat`, `submit_score`, `fetch_leaderboard`, `db_call()` (PostgREST RPC; never name it `rpc`: clashes with Node.rpc); signals `signed_in`/`signed_out`/`auth_error`.
- Only the publishable/anon key lives in the repo (`scripts/common/config.gd`, `docs/reset-password.html`). The `service_role` key must never appear in the codebase.
- `scripts/account/account_screen.gd`: sign-in/sign-up UI (first `LineEdit` use).
- Synced data: only the persistent best-score files (Snake, Whack-a-Mole, Simon) -> `player_stats`. Each game's `_load_best()`/`_save_best()` calls `Auth.reconcile_stat`/`push_stat` if `Auth.is_logged_in()`; never block offline/logged-out play. Reconcile = max(local, cloud).
- Password reset redirects to the static `docs/reset-password.html` (GitHub Pages), not an app deep link (no Android deep-link infrastructure).
- Session: `user://auth_session.json` via `SaveUtil` (tokens, expiry, user id, display name). Auto-refresh ~60 s before expiry; Supabase rotates the refresh token on every use: overwrite the stored one. Refreshes are single-flight (overlapping ones spend it twice and can revoke the session). Only a 4xx signs the player out; a network failure keeps the session.
- Schema/RLS SQL lives in the Supabase dashboard (and `supabase/migrations/`, `docs/*.sql` run by the owner). Claude cannot touch prod (see memory `no-prod-db`).
- **Free Supabase projects pause after ~1 week idle**: the domain stops resolving; sign-in, score sync and online play fail. Owner restores it at supabase.com/dashboard.

## Online two-player (Realtime; no tables, nothing stored)
- `scripts/common/online_session.gd`: Supabase Realtime Phoenix WebSocket. Room = broadcast channel `voodoo-<game_id>-<4-letter code>`; presence gives roles `host`/`guest`; moves are broadcasts. Works with the anon key. `online_lobby.gd` = shared Host / Join-by-code screen.
- **Wire a game with `scripts/common/online_match.gd` (`OnlineMatch`)**; its header is the how-to. Game supplies `_online_state()` (JSON-safe whole game), applies `remote_move`/`remote_state`, calls `send_move()` after a local move. Host = player 1 = authority: pushes full state when the guest (re)appears/asks; every move carries the sender's resulting state, a mismatch triggers resync. Online games are never saved locally; an online game ending must not delete the local save.
- Online so far: Tic-Tac-Toe, Connect Four, Checkers, Reversi, Chess, Mancala, Dots and Boxes, Morris, Backgammon, Memory, Five in a Row, Hex, Poker (heads-up). Dice/shuffle games send the whole state as the move (Backgammon: every roll and move; Memory: host deals, each flip is a move).
- **Never `preload` online scripts from a game** (packs run on older apps): `ResourceLoader.exists(ONLINE_LOBBY_PATH)` then `load()`; otherwise no Online button.
- Join links: after Host the lobby shows the code, a QR of `Config.JOIN_PAGE_URL` (`docs/j/index.html?g=<id>&c=<CODE>`), 📋 Copy invite, 💬 WhatsApp (`wa.me/?text=`). No app deep link yet (no domain, no intent filters): the page says to type the code. QR encoder `scripts/common/qr.gd` (`tools/test_qr.gd` writes test images).
- Names + rejoin: lobby "Your name" field (saved, defaults to account name) carried in presence; `my_name()`/`opponent_name()`. Room saved in `user://online_room.json` during a match; a killed app reopens to "↩ Rejoin game XXXX" (same code, role, presence key). A returning host asks the guest for the game (`state_please`) instead of pushing a blank board.
- Seat view: in Chess and Checkers the guest's board is drawn rotated 180° (`flipped`, `_view_index()`); only drawing and tap handling convert, the engine uses real coordinates.
- Test without the server: `tools/test_online_pair.gd` plays whole games between two copies joined by a fake session (JSON round trip); add a driver when wiring a new game. It records online results: back up user data first.

## Leaderboards
- Table `scores` (one best per player per game), `docs/leaderboards.sql`. GameInfo posts a new "Best score" via `Auth.submit_score` when signed in and shows 🏆 Top 10 (`Auth.fetch_leaderboard`); hides if the table is missing. Only games whose STATS include "Best score". The `scores` table keeps each player's highest number, so lower-is-better games rank a growing counter ("Wins", "Puzzles solved") or have none. The kit posts the `board` metric whenever Home shows (signed in).
- Hub 🏆 screen: every board, Everyone / Friends. Boards come from manifest per-game `"board"` (omitted = "Best score", `"none"` = no board) and `"modes"` ("online,local,party,cpu"); Catalog carries both: keep them right when adding a game.

## Achievements (`achievements.gd`, header = how-to)
- Generic badges from GameInfo stats (tiers of "Wins", "Games played", other counters, "Best streak", "Online wins", beating own records via `_records`), optional per-game `ACHIEVEMENTS` in `<id>_help.gd` ({id, icon, title, desc, key, at, lower}), hub-wide `HUB` ones (games tried, badges, friends, invites; `user://achievements.json`). Unlocked badges stored in the stats file as `_ach`. GameInfo checks on every save, slides a toast; earned badges backfill silently. Total goes on the leaderboard as game id `achievements`. Test: `tools/test_achievements.gd`.

## Friends + invites
- `Social` autoload (`social.gd`) over `Auth.db_call()`. Server: `supabase/migrations/20261004000000_friends.sql` (owner runs it). Until it exists `Social.available` is false and friend UI hides. 6-letter friend codes, requests, online status (heartbeat 60 s), invites polled every 12 s and popped anywhere ("Join"/"Not now"; Options "🔔 Game invites": Always / Not during games / Off).
- Open a game into online play: `Social.launch_online(id, mode, code, invite_to)` -> hub (`Social.take_launch_request()`, same as a tile tap) -> game's OnlineMatch `take_pending()` -> lobby `auto_start()` ("host"+invite, "join", "invite", "lobby"). The kit hides Home when the lobby opens. Test: `tools/test_social_launch.gd`.
- Hub screens share base `scripts/hub/hub_screen.gd`: Leaderboards, Achievements, Friends, Multiplayer.
