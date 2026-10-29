# Creation (id `creation`, category Intelligence) — alchemy / combine-to-discover

Working title **Creation** (display name only: `manifest.json` `title`/`title_es`, `creation_help.gd` `TITLE`; the id never changes). Spec: the owner's "alchemy game" Drive folder (`SPEC.md`, placeholder name "Primordia"). Candidates if the owner wants another name: Elementum, Fusewright, Forgeling (check Play + INPI/EUIPO/USPTO first; "Alchemix" is an existing DeFi project).

## Data pipeline (never edit the JSON by hand)
- `tools/creation/build.py` is the source of truth (`ITEMS`, `RECIPES`, `TIERS` blocks; `#` lines are ignored inside them). `python tools/creation/build.py` validates (undefined ids, duplicate pairs, reachability, sources, every item has a tier, **free tiers completable without a paid-tier ingredient**) and writes `tools/creation/game_data.json` + `scripts/games/creation/creation_data.json` (the copy the pack ships). Exit 1 on any error.
- Now **263 items, 259 recipes** (257 + 2 early-game routes below), max depth 15 (was 18), 97 finales.
- **Tiers are themed, not by depth** (the old depth band is kept as `depth_band`): 1 Nature 53, 2 Life 43, 3 Early Civilization 85, 4 Industry & Modern Life 62, 5 Space & Future 20. Free = tiers 1-3 (181 items), Full Game = tiers 4-5 (82).
- Item names EN/ES live in the data (not `es.json`); `lang` only changes names, never ids.

## Early-game stall (checked 2026-10-19)
`tool` (stone + stick) was depth 9 and gated 128 of 263 items; `life` (depth 5) gates 150 (natural: it is the "spark" step). Added in `build.py`: `earthquake+mountain=ore` (metal route without Tool) and `stone+tree=tool` (a second way to Tool). Now Tool is depth 8 and gates 78 items. Wood (`tree+tool`), Human (`monkey+tool`) still need Tool by design. A simulated greedy player completes all 263 with no dead moment (`tools/test_creation.gd`).

## Code
- `creation_engine.gd`: pure `RefCounted` (combine, `try_combine` statuses new/known/locked/miss/failed_before, failed pairs, shelf search/sort/filter, hints, versioned save with migrate, validator). `creation_gate.gd`: monetization seam. `creation_game.gd`: UI in code (Table + Chip + ShelfDrag inner classes). Tests: `godot --headless --path . --script res://tools/test_creation.gd` (logic, ~1 s) and `tools/test_creation_game.gd` (real mouse events through the scene; WRITES `user://creation_save.json`, delete it after).
- Input: single taps handle `MouseButton` only. Shelf: tap adds to the table; mouse drags at once; touch = hold 0.28 s then drag, otherwise scroll (`ShelfDrag` reads raw input, `scroll_deadzone` is huge so the built-in touch scroll doesn't fight it). Table chips: drag onto another to combine, tap one then another, double-tap duplicates (350 ms), drag to 🗑.
- Save `user://creation_save.json` (autosave on every move/discovery, on pause and exit): found ids, failed pairs, locked silhouettes, table layout (fractions), hints (3/day, resets by local date), settings (`lang` auto/en/es item names; `theme` auto/dark/light), purchase flag. Pause-menu Restart only clears the table; progress reset is ⚙ > Reset progress (confirmed).
- Top bar shows the banner `games/creation/banner.webp` (owner's art, 2026-10-28) instead of the text title (`title_label` stays as a hidden fallback if the file is missing). Shelf checkbox **Hide used-up items** (`settings.hide_spent`, saved) hides found items with `unfound_uses == 0`; silhouettes stay.
- Skins: Classic (light/dark theme per setting or the app's) and Voodoo (neon, always dark). Modals are children of the kit (`home`) so Android back closes them.

## Monetization (NOT LIVE; owner decision needed)
- SPEC §7: one-time **Full Game** (free = tiers 1-3 + 3 hints/day; paid = tiers 4-5 + unlimited hints). Daily challenge is v1.1 and is not listed as a benefit until it exists. No ads.
- `creation_gate.gd` `LIVE = false`: every tier open today; `VOODOO_CREATION_PAYWALL=1` turns the gate on for desktop tests (the Unlock button then fakes the purchase). With it on, paid-tier results are locked silhouettes (`seen_locked`) that become discoveries on unlock.
- **A pack cannot carry the Play Billing plugin** and `docs/monetization/PLAN.md` sells whole games ($0.99 / hub subscription, trials, signed-in only), not in-game unlocks. To sell the Full Game the APK-side `Store` (branch `store`) needs a product kind "unlock" with `has_entitlement("creation_full")` and `buy_product("creation_full")`, a Supabase entitlement row and a Play Console product. The game already calls those guarded (`Gate.store_owns/store_buy`). Open: keep the SPEC one-time unlock, or follow the hub plan (whole-game $0.99 + subscription, then drop the in-game tiers)? Both need `store` merged first.
- SPEC §6 says no accounts/server; the hub does have accounts (leaderboard 🏆 "Discoveries", achievements). Local play needs none.

## Open / not built
- Daily challenge ("Make: Bread"), share card, achievements beyond the 5 discovery goals (v1.1).
- Emoji icons are placeholders; newer emoji (🪨🪵🪙🛞🪈…) may show as boxes on old Android versions. Replace with drawn art later (`media/CREDITS.json` has nothing for this game yet because it ships no assets).
- Check the recipe list against other combine games before launch (mechanic is free; ours is its own, but have the IP lawyer glance at the final store text).
- Not published: no `bump-pack`/`publish-packs`/manifest push done; `manifest.json` has the entry at version 1.
