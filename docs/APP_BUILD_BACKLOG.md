# App build backlog

Things that need a new APK build (shared code in `scripts/common/`, `scripts/hub/`, `scripts/account/`). Collect here, ship them together to limit app versions. Anything that can live in a pack does not belong here. Add an entry from any session; note the game/date.

- [ ] **Shared hint system** (owner, 2026-11-01): autoload, 3 hints max per game, +1 every 24 h, clock per game; kit UI (count + "next hint in..."); synced through the progress table. Creation ships a pack-only version first; move it here when built.
- [ ] **Hint cooldown counter**: anonymous count of players at 3 hints vs. waiting on the cooldown, as a per-game difficulty signal.
- [ ] **Reminder:** when creating or editing any game, ask the owner whether to add the hint system.
- [ ] **Creation hub thumbnail** (2026-11-01): `media/hub/game_art/creation/` (tile = Creation of Adam hands, public domain; hero = owner art, 2026-11-02) is APK-side art, so it only shows after the next app build.
