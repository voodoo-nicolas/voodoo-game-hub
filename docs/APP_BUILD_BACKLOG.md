# App build backlog

Things that need a new APK build (shared code in `scripts/common/`, `scripts/hub/`, `scripts/account/`). Collect here, ship them together to limit app versions. Anything that can live in a pack does not belong here. Add an entry from any session; note the game/date.

- [x] **Shared hint system** (owner, 2026-11-01): BUILT pack-side on 2026-11-08 as the Landing kit's helps pool (STANDARDS §17: 3 per game, one back 24 h after the LAST help used), no app build needed. Still open: cross-device sync of the pool (pack-only through `Auth.db_call` + the progress table, like Creation) -- not an app build either.
- [ ] **Hint cooldown counter**: anonymous count of players at 3 hints vs. waiting on the cooldown, as a per-game difficulty signal.
- [x] **Reminder** (done 2026-11-08): every game now has helps or is in `NO_HELPS` (`hub.py check` fails otherwise).
- [ ] **Creation hub thumbnail** (2026-11-01): `media/hub/game_art/creation/` (tile = Creation of Adam hands, public domain; hero = owner art cropped to planets + city, 2026-11-02) is APK-side art, so it only shows after the next app build.
