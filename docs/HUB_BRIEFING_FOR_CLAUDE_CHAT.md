# Viral Game Hub: briefing for Claude Chat

*Written 2026-11-13 by Claude Code (the half that works in the repo) for Claude Chat (the half that talks with the owner). Paste or upload this at the start of a chat. The repo is the source of truth; this is a snapshot.*

## 1. Who and what
- **Owner / developer:** a solo indie developer, working under the developer name **Viral**. The project is basically the owner + Claude Code. The owner is terse, often uses voice, prefers doing over discussing, and checks numbers carefully.
- **Product:** **Viral Game Hub**: one free app holding a fast-growing library of mini-games ("a million games behind one icon"). The name is still pending a trademark check (INPI/EUIPO), so in code it lives in a single constant (`scripts/common/brand.gd`) and a rename is a one-line change.
- **"Voodoo"** is *only* the name of an optional neon-skull visual skin (and the package id `com.viral.voodoo`, the repo name, which are never renamed). It is not the brand.
- **Free, no ads, ever.** Bilingual **English + Spanish** throughout.
- **Goal:** 100+ games live before switching on monetization. Currently **121 games** in the catalog.
- **Platforms:** Android APK (main; also a Google Play bundle), Windows PC build (self-updating), and a web build for iPhone/Safari (live at `voodoo-nicolas.github.io/voodoo-game-hub/play/`).
- **Public repo:** github.com/voodoo-nicolas/voodoo-game-hub. App version **v0.40.0** (build 54).

## 2. Engine and tech stack
- **Godot 4.7.2**, all code in **GDScript**. UI is built in code (not hand-made scenes). No Gradle/Android Studio project.
- **Supabase** backend: accounts/auth, leaderboards, friends and invites, Realtime rooms for online multiplayer, achievements, entitlements (for the future store). Claude cannot touch the production database; SQL is written as files the owner runs.
- **GitHub Releases** hosts the game packs (tag `packs-v1`), media packs, music (`music-v1`) and app releases.
- **Python tooling:** `tools/hub.py` does everything: `check` (lint, read-only), `test <id>` (headless boot test), `sync`, `export`, `apk`, `pc`, `web`, `bump-pack`, `bump-app`, `publish-packs`, `release`, `verify`, `i18n`.

## 3. How games run ("Option B" architecture)
- The **APK is only the hub shell** + shared code (`scripts/common/`, `scripts/hub/`, `scripts/account/`). It contains no games.
- **Each game is a downloadable `.pck` pack** (Godot resource pack) on GitHub Releases. First tap downloads it to the phone, mounts it, launches it. A small game pack is ~10 KB.
- **`manifest.json`** (in the repo, read live from GitHub) is the catalog: categories, titles (EN/ES), icons, modes (online/local/CPU), skins, learning tags, age info, and each pack's version + URL. Bump a game's version + push manifest → every installed app updates that game. **New games appear without an app update.**
- Packs must keep working on older app versions, so games call into app systems defensively (check that a node/script exists first).
- Each game is 4 files: `<id>_engine.gd` (pure rules/logic, testable without a screen), `<id>_game.gd` (the UI), `<id>_help.gd` (How to Play, achievements, facts), `<id>_i18n.gd` (generated translations).
- Shipping flow: headless logic test → boot test → bump version → export → (owner OK) publish packs → commit, manifest last → (owner OK) app release → verify.

## 4. The shared systems ("libraries" and kits)
Everything a game needs is shared, so every game looks and behaves the same way:
- **Landing / Home kit**: each game opens on its own Landing screen (Play, Resume, Quick Play, modes, How to Play, 🏆 leaderboards, 🏅 achievements, 📊 stats, ⚙ Options). Navigation rules: only the Landing goes back to the hub; every other screen has 🏠 Home; Android Back goes one step up; leaving play auto-saves and Resume is one tap.
- **Pause menu** (standard): Resume / helps / Restart / How to Play / 🏆 / 📊 / 📸 / ⚙ Options / 🏠 Home.
- **Skins**: *Classic* (default) and *Voodoo* (neon-skull, opt-in, "Voodoo Mode"). Arcade games keep their own backgrounds.
- **Helps / hints**: every game offers helps (💡 hint, ❤ extra life, ⏭ skip...): 3 per game, one comes back 24 h after the last use.
- **Music library**: one `Music` autoload; every game's music comes from it. The owner adds tracks via the **Viral Music Drop** tool (published as release `music-v1` + `music.json`).
- **Sound library**: recorded sound effects in `media/common/sfx/`, each game picks its sounds through its `sound_lib.gd`; packs carry only the sounds they use.
- **Sprite library**: ready-made art (space, smoke, isometric dungeon/library, gothic, village, forest, characters...) in `media/common/sprites/`, used through each game's `sprite_lib.gd`.
- **Pad**: one shared on-screen game controller (stick + 4 buttons default, different layouts/looks), plus a dev-only "Pad Lab" app to tune it.
- **Accounts & online**: sign-in, profiles, avatars, friends, invites, online lobbies and rooms (realtime multiplayer), leaderboards, achievements (capped at 1000 points per game).
- **GameInfo**: How to Play pages, stats, and **learning hooks**: games that teach something show it (logic, maths, words, history...). The owner loves games that teach; teaching aids are switchable options. Not marketed as kids' education.
- **i18n**: every string EN + ES (`tools/i18n/es.json`, generated per game).
- **Layout rules**: phone safe area, fits any width, readable at text size 1.0-1.4, portrait/landscape handling.
- **Assets**: free/CC0/self-made first; the owner's own art is made with Gemini or ChatGPT. Every asset is credited in `media/CREDITS.json` with licence proof. Never non-commercial or no-derivatives licences.

## 5. The games (121, by hub category)
- **Puzzle & Board (31):** Chess, Sudoku, Mines, Tic-Tac-Toe, Four in a Row, Checkers, Reversi, Ocean Battle, Dots and Boxes, Mancala, Backgammon, Nine Men's Morris, Peg Solitaire, Light Flip, Box Pusher, Sliding 15-Puzzle, 2048, Kakuro, Nonogram, Code Breaker, Tower of Hanoi, Calcudoku, Wire Up, Five in a Row, Mahjong Solitaire, Color Flood, Block Collapse, Binary Grid, Hex, Maze Trail, Bridge Master
- **Intelligence (15):** Trivia, Quick Math, Memory Grid, Color Clash, Number Series, Digit Recall, IQ Test, Sketch It, Trace It, Trivia Battle, Color Sort, Hidato, Creation, Evolution, Gridmaster
- **Cards (16):** Solitaire, Blackjack, War, Crazy Eights, Go Fish, Gin Rummy, Spider Solitaire, FreeCell, Pyramid Solitaire, Speed, Memory Match, Tri-Peaks, Hearts, Poker, Sevens, Rummy
- **Word (9):** Hangman, Five Letters, Word Search, Crossword, Anagrams, Word Hunt, Word Ladder, Cryptogram, Word Chain
- **Arcade (25):** Snake, Block Drop, Paddle Ball, Brick Breaker, Bird Hop, Alien Attack, Road Hopper, Gem Match, Memory Lights, Bop the Mole, Reaction Test, Bubble Pop, Rock Blaster, City Defense, Maze Muncher, Moon Lander, Stack Tower, Sky Hop, Air Hockey, Barrel Climb, Cannon Duel, Mini Golf, Pool, Tilt Maze, Bug Chain
- **Adventure (8):** Neon Blast, Star Runner, Sky Strike, Last Shift, Turned, The Runner, Crypt Crawler, Beached
- **Dice (8):** Yacht Dice, Farkle, Liar's Dice, Shut the Box, Dominoes, Pig, Bunco, Ship Captain Crew
- **Party (9):** Party Spinner, Charades, Truth or Dare, Fortune Ball, Spirit Board, Fastest Finger, Emoji Guess, Who Am I?, Tarot of Destiny

### The bigger flagship games
- **IQ Test (Voodoo IQ):** a full IQ test, 9 sections (incl. interpersonal, faces), practice mode with answers/review, a ranked board, a junior board (ages 13-15), achievements.
- **Evolution:** microbe pond: you evolve a creature with traits, endless mode, bosses.
- **Turned:** gothic vampire story game (owner's story bible); Prologue + Day 1; progressive reveal; a bar as setting (only game allowed alcohol as a setting).
- **Beached:** castaway survival sim on the real clock (garden, spear, quests).
- **The Runner:** space smuggling trader: map, docks, 144 quests, multiple endings.
- **Neon Blast / Sky Strike:** arcade shooters; Neon Blast has a survival campaign, bosses, familiars.
- **Crypt Crawler:** dungeon crawler with Adventure mode and twin-stick controls.
- **Creation:** alchemy/combination game (combine elements to discover new ones).
- **Trace It:** camera tracing/drawing game.
- **Poker, Chess, Pool:** deep versions (Chess lessons/daily puzzles/shop; Pool with spin).
- **Bridge Master:** physics bridge builder, 300 levels all proven solvable.
- **Maze Trail / Tilt Maze:** 195 levels each, marble shop.

Many recent updates are live but **not yet phone-tested**.

## 6. Monetization (built, NOT live)
- Store code sits on a separate branch, not merged. The owner decided (2026-10-06): hub and games first.
- Plan: 3-day trials for signed-in players, $0.99 per game (IQ Test $1.99), $4.99/month for the whole hub (7-day trial + $2.99 × 3 intro), 15 games always free. Still no ads.

## 7. Hard rules worth knowing in any discussion
- No ads, ever. No alcohol promotion anywhere (incidental background scenery OK; Turned's bar is the one story setting).
- No copying existing commercial games' names, art or levels: original takes on genres (there's an IP audit).
- Everything bilingual EN/ES.
- Every game meets the same standards (`docs/STANDARDS.md`): navigation, Landing, pause/save/resume, skins, safe area, achievements, credits.
- The owner approves anything public: publishing packs, app releases, store text, database changes, deletions.

## 8. Where things are documented (in the repo)
`CLAUDE.md` (master instructions) · `docs/STANDARDS.md` (all rules) · `docs/HUB_V2_PLAN.md` (roadmap + open decisions) · `docs/monetization/PLAN.md` · `docs/claude/*.md` (one note per system/game) · `reference/art/ART_STYLE.md`.

## 9. Tips for Claude Chat
- You can't see the code; Claude Code can. If an idea needs facts about the code, the owner can ask Claude Code and paste back the answer.
- Good things to help with in chat: game ideas and designs, story/quest writing, level/economy balance, store/marketing text drafts, art prompts (for Gemini/ChatGPT), translation checks, strategy and roadmap.
- Write ideas as short, concrete briefs: Claude Code turns them into games.
