# Camera Hunter (id `hue_hunt`)

Photograph real things that match a colour (or an object / shape / property in Object rounds).
Owner briefs + decisions: `docs/hue_hunt/DESIGN.md` (read it first; OPEN items are there).

## Files (`scripts/games/hue_hunt/`)
- `hue_hunt_engine.gd`: colour maths (sRGB -> Lab D65, CIEDE2000 kL 2, median 15x15 sample with clip
  rejection, % match), RoundSpecs for 7 types, `resolve()` awards + tie-breaks, match plans, solo helpers.
  Tunables at the top (CLOSE 12/8/5, PCT_ZERO_DE 40, MIN_SEPARATION 15): placeholders until playtests.
- `hue_hunt_room.gd`: multiplayer table state machine (round -> [vote -> best] -> reveal -> next / final),
  flags, power-ups, catch-up. Pure; the acting host runs it.
- `hue_hunt_powerups.gd` (registry), `hue_hunt_judge.gd` (ObjectJudge: v1 = players' vote; plug a labeler here).
- `hue_hunt_game.gd`: UI, camera, solo modes, Colour Book, multiplayer wiring. Landing S11 Sticker Board.
- Data: `hue_hunt_colors.json` (150 XKCD CC0 colours) and `hue_hunt_objects.json` (101 prompts) are
  GENERATED from `tools/hue_hunt/colors.csv` / `objects.csv` by `build_colors.py <rgb.txt>` /
  `build_objects.py`. JSON (not .gd) so the i18n extractor doesn't harvest them; ES names live in the data.

## APK side (ships with app build 65; manifest `min_build` 65)
- `scripts/common/camera_service.gd`: shared camera (Trace It's code made shared): live feed, `snapshot()`,
  `patch()`, `thumbnail_jpg()`. Loaded guarded; missing = "update the app" message.
- `scripts/common/online_table.gd`: table cap 6 -> 8. Older apps clamp to 6.

## Multiplayer
- OnlineTable rooms (5-letter codes). Acting host = lowest player number still here (host migration).
  Whole state broadcast as event `state` (`ver`, `match_id`); clients send `lock`, `flag`, `vote`, `best`,
  `power`; everyone sends `thumb` (128 px, 256 in Object rounds) once. Thumbnails never enter the state,
  are never saved and are dropped after the reveal. Times are Unix seconds + the host's `now` offset.
- Never saved locally (online rule). Helps are solo only; power-ups are multiplayer only (STANDARDS §17 note).

## Tests
- `tools/test_hue_hunt.gd` (headless): CIEDE2000 reference pairs, sampling, data, every round type, ties,
  plans, room with JSON round trips, power-ups, a full 4-player Object round.
- `tools/test_camera_service.gd`: patch / thumbnail helpers.
- Not covered: a two-phone run of the game screen, anything on a real camera.

## Known gaps
- Voodoo skin only restyles the top bar.
- Text scale 1.4 / safe area not checked on a device.
- Daily Color has no per-day leaderboard (needs a Supabase table: owner's OK).
