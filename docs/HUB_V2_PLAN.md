# Hub v2 — plan, decisions, open questions

Read with `docs/STANDARDS.md`. Items move from here into STANDARDS once decided.

## 1. Naming — DECIDED (pending trademark check)
- **Developer: Viral. Hub: Viral Game Hub.** Icon: neon crowned skull. One brand for studio + app.
- Play titles (max 30 chars, localized per language): EN `Viral Game Hub – No Ads` · ES `Viral: Juegos sin anuncios`.
- Known same-word users (low risk: small, different territories, "viral" is a common word): Viral Game Studios
  (Spain, indie), Simple Viral Games (India), the game *Viral* (UK). Check EUIPO before any EU marketing push.
- **"Voodoo" is retired as a brand** (Voodoo SAS, Paris, is a giant IP-active mobile publisher). It survives only
  as the skin name ("Voodoo mode"). Rename the game "Voodoo IQ" and its "Blitz" mode (Voodoo also runs an app
  called Blitz) — new names OPEN.
- TODO owner: file "VIRAL GAME HUB" (word + logo) at INPI Argentina, classes 9 and 41. Argentina is first-to-file:
  the registration, not first use, gives the right.
- Code: `Brand.NAME = "Viral Game Hub"`, `Brand.DEVELOPER = "Viral"`; never hard-code either.

## 2. Phases (suggested order)
| Phase | Work | Why this order |
|---|---|---|
| 0 | `brand.gd`; IP name audit of all ~93 games (rename only) | renaming before redesign avoids doing screens twice |
| 1 | ✅ 2026-10-06: Landing kit (Landing, setup screens, pause menu, game Options, drawer removed) in every kit game at once (93 of 95 live; Sudoku + IQ Test custom) | proves the template on every game shape |
| 2 | Hub v2: top bar, Continue, Favorites, Game Browser + filters, Profile, Friends, app Options | needs Landing to exist (rule N3) |
| 3 | Media tiers: `music.gd`, buses, `media_packs` in manifest, catalog deps + ref counting, Storage screen, `CREDITS.json` | before mass migration so games adopt shared media once |
| 4 | Skin system (`skin.gd`, `SkinDef`), Classic + Voodoo for pilots, art reference library | |
| 5 | Roll out to all games **one category at a time** (category media pack + migrations together) | each batch ships one Tier-2 pack |
| 6 | Join links (App Links + fallback page), QR, polish | needs a domain |

## 3. Owner requirements (organized, all decided)
Hub simpler / fewer buttons / no scroll · Options · Profile · Friends · Game menu with filters ·
Landing per game with own art · tap game → Landing directly · Landing: single, multi, 🏆, 🏅 (earned/locked filter),
how-to, options, back to hub · Options: sound, music, theme, difficulty, more · Single-player setup (modes +
difficulty) · Multiplayer setup (modes + invite + link + join code) · only Landing links to hub; all other screens
link to Landing · shared media in 3 tiers · shared art reference library · Classic + Voodoo skins
(black/neon, bones, skulls, dolls, lips) · copyright check on every game.

## 4. Suggestions (status: PROPOSED unless owner approves)
| # | Suggestion | Value | Effort |
|---|---|---|---|
| S1 | **Quick Play** + remember last setup | restores 1-tap play the new menus would cost | S |
| S2 | **Continue** card on hub | most sessions are "the game I played yesterday" | S |
| S3 | Download from Landing (rule N3) | honors "tap → Landing" even for undownloaded games | M |
| S4 | **Daily Challenge** per game (shared seed, daily board) | retention without ads or dark patterns | M |
| S5 | Hub-wide profile progression (XP, hub achievements like "played 10 games") | rewards breadth = the hub's whole pitch | M |
| S6 | Voodoo-doll avatar customizer (parts unlocked by achievements) | identity + uses the theme | M–L |
| S7 | Storage manager (sizes, delete, shared-media ref counts) | needed anyway once media is tiered | S–M |
| S8 | `hub.py check` lints: Landing art present per skin, how-to present, ES complete, `CREDITS.json` entries, name not on IP blocklist, nav rules | keeps 100 games consistent automatically | M |
| S9 | `hub.py audit-ip` (blocklist scan of names/strings/store text) | cheap insurance | S |
| S10 | Accessibility: colour-blind-safe skins, reduce-motion, haptic cues, big-tap mode | neon + small phones = real problem | M |
| S11 | Rating prompt after N plays (stars, top-only display) | already planned; slot into Landing | S |
| S16 | Learning hooks + Learn filter (STANDARDS §15) | owner rule; adds value without ads | S per game |
| S12 | Event schema for the PC/web dev dashboard (plays, time, ratings) | dashboard already decided to live outside the hub | M |
| S13 | Share result card (image) from game-over | free marketing, no ads | S |
| S14 | Offline indicator + queued score submits | Tucumán mobile data is not always reliable | S |
| S15 | ~~Age gate~~ → **DECIDED: Drinking Games archived** (see §6) | Google Play content-rating and policy risk | S |

## 5. Owner decisions (2026-10-06)
1. **Name:** Viral (developer) + Viral Game Hub — go with it for now. New artwork coming from owner.
2. **Floating SettingsDrawer: removed.** Items folded into pause menu / Options (STANDARDS §6). Stub stays for old packs.
3. **Classic skin is the default** and uses each game's traditional colours. Voodoo is opt-in.
4. **Lips motif:** owner is submitting the image → `media/common/art/lips.*` + `CREDITS.json` (owner's own work).
5. **Domain for join links: not yet.** Until then: room code + QR + plain share text; App Links later (§2 Phase 6).
6. **Music:** some AI-generated tracks exist; royalty-free and proprietary `.ogg` files coming. Each one gets a
   `CREDITS.json` entry + licence proof before it ships (STANDARDS §10). Check the AI tool's plan allowed commercial use.

## 6. Risks / standing decisions
- **Drinking Games category: ARCHIVED (decided).** Keep the code and packs; hide them everywhere.
  - Manifest: category `"archived": true` and each of its games `"archived": true`.
  - `catalog.gd`: archived games never appear in Browser, Continue, Favorites, search, invites, leaderboards.
    Already-downloaded copies are hidden, not deleted (local saves kept).
  - `hub.py`: `check`, `export --all` and `publish-packs --all` skip archived games; `verify` doesn't fail on them.
  - Source stays in place (no file moves = no broken paths); add `ARCHIVED.md` in each game folder with the reason.
  - Store listing / IARC questionnaire: no alcohol references anywhere else in the hub.
  - Revisit later with an 18+ gate + responsible-drinking notice.
  - **Archived (8, owner 2026-10-06):** kings_cup, red_or_black, three_man, never_have_i_ever, most_likely_to,
    ride_the_bus, plus spin_the_bottle and would_you_rather (moved into the category: their drinking references).
  - **Count impact (checked 2026-10-06):** 103 games in the manifest − 8 archived = **95 live, 5 to go** for 100.
  - Apps before v0.29 don't know the flag and still list the category until they update.
- Media dependency packs add a failure mode (game downloaded, media pack missing). Catalog must verify deps
  at launch and re-fetch silently.
- Old APKs + new packs: every new kit call guarded; `min_build` (manifest field) only when unavoidable.
