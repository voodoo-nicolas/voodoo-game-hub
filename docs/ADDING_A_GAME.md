# Adding a game to Viral Game Hub

Games are Godot scenes shipped as downloadable `.pck` packs; the app (APK) holds only shared code. The quick path is `python tools/hub.py new-game ID --title "Title" --icon "🎲" --category "Cards"` and the `viral-minigame` skill (`.claude/skills/viral-minigame/SKILL.md`), which also lists the Definition of done (navigation, Landing, pause/save/resume, EN + ES, safe area, credits). This page covers the two things a game declares for the hub: its **catalog metadata** and its **challenges (Viral XP)**.

## 1. Catalog metadata (`manifest.json`, `categories[].games[]`)

```json
{"id": "my_game", "family": "Solitaire", "title": "My Game", "icon": "🎲", "title_es": "Mi juego",
 "modes": "online,local,cpu", "board": "Wins", "skins": "classic,voodoo",
 "learn": ["logic"], "quick": true, "original": true}
```

| field | meaning |
|---|---|
| `id` | never renamed (saves, packs, server rows use it) |
| `family` | similar games sit together inside a category: listed by family, then title. Omit = its own family |
| `modes` | comma list of `cpu` (solo vs computer), `local` (same phone), `online`, `party`. Drives the Solo / 2 Player / Group / Same phone / Online chips. Empty = a solo game |
| `board` | the leaderboard stat (`"none"` = no board) |
| `quick` | a round fits in ~5 minutes (⚡ chip) |
| `original` | a Viral original, not a classic (⭐ chip) |
| `learn` | what it teaches: `vocab math logic memory art music geo science` (🧠 chip) |
| `skins` | `classic,voodoo` |

Categories: Puzzle & Board, Intelligence, Cards, Word, Arcade, **Adventure**, Dice, Party. A category with no games is allowed. Arcade and Adventure games keep their own backgrounds (`HomeKit.OWN_BG_GAMES`; `hub.py check` enforces it). Don't ship a game with alcohol references, and never third-party IP.

## 2. Challenges and Viral XP

- **Viral XP** = points for completing a challenge. Permanent, never spent, never decreases. **Viral Power** = the player's lifetime sum over all games (one number on the profile and friends list).
- Every game already earns XP with no work: the stats it records (`<id>_help.gd` `STATS`) become tiered badges (Wins 1/10/50/100, Games played, ...), worth 10 / 20-30 / 60 / 120 XP by tier.
- Add your own in `<id>_help.gd`:

```gdscript
const CHALLENGES := [
	{"id": "boss_1", "title": "Boss Slayer", "icon": "🐉", "desc": "Beat the first boss",
	 "xp": 40, "hidden": false, "repeatable": false,
	 "event": "bossDefeated", "min": {"boss": 1}},
	{"id": "lap", "title": "Lap", "xp": 5, "repeatable": true},           # up to 10 awards
]
```

`xp` is capped at 200 per challenge (and 1,500 per game on the server). Titles/descs are English literals; add Spanish to `tools/i18n/es.json`. Games that only need counters can keep using `ACHIEVEMENTS` (same format as before, plus an optional `"xp"`); both work.

**Report a challenge** (idempotent: paying out once, or up to 10 times for `repeatable`):

```gdscript
# Packs run on older apps: guard the APK-side script.
const ACH := "res://scripts/common/achievements.gd"
...
if ResourceLoader.exists(ACH):
	var A = load(ACH)
	A.report_challenge("my_game", "boss_1")                       # = hub.reportChallenge(gameId, challengeId)
	A.on_event("my_game", "bossDefeated", {"boss": 2})            # the adapter: declared rules decide
```

`on_event` rules are `CHALLENGES` entries with `"event"` plus optional `"min"` (payload field >= n), `"max"` (<= n) and `"equals"`. A game that can't call into the hub at all still earns XP from its stats; a game whose events live in its own code only needs one `on_event` line per event, no rewrite.

What happens: the award is written to `user://challenges_<game>.json` (the local log: `[unix_time, icon, title, desc, xp]`), a toast shows, and the hub syncs new awards to Supabase (`xp_report`, one row per user + game + challenge, so repeats are ignored). Totals are derived from the log. The Player page's "Compare achievements" lists, per game, the challenges either player has earned.

**Trust:** achievements are reported by the app, so a modified client can claim any of them. XP is capped and cosmetic; if a game's ranking ever matters competitively, validate on the server first.

## 3. Check it

`python tools/hub.py check`, `python tools/hub.py test <id>`, `python tools/xp_report.py` (which games can earn XP), `godot --headless --path . --script res://tools/test_xp.gd`.
