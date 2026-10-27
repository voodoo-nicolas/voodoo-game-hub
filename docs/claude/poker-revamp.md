# Poker revamp (owner decisions 2026-10-26/27)

Goal (owner): "I WANT IT AWESOME". Game id stays `video_poker`, title "Poker"; Video Poker stays a mode. Engine notes: `poker.md`.

## Sources
- Owner's checklist: `C:\Users\nick_\Documents\poker1.txt` (11 sections: variants, modes, core, education, statistics, history, progression, special, multiplayer, technical, order).
- Owner's menu / stats / how-to-play / in-game notes: Google Drive, Viral Game Hub > poker > text file `Poker`. Stats he wants: total games, finishing place / players, biggest single-hand loss, times each hand type made, most won per hand type, worst winning hand, most won with worst hand, date joined, **longest daily login streak (make it hub-wide)**, hands played/won, best chips/hour, bb/100 (not "$"), ROI (tournaments only). How to Play: one per game mode. In game: win-chance %, landscape, show other players, show chips.
- Art (Drive > poker, 11 images, 1536x1024 / 1448x1086 PNG, 2.4-3 MB each): **Classic** = dark green felt, gold, mahogany, skull-in-V crest (cards, table, chips-on-table, casino exterior); **Skull** (= Voodoo skin) = neon purple/blue (cards, table, low-angle table, chips, royal flush, blackjack table, casino exterior). They are **scenes for backgrounds, transitions, menus and style reference**, not sprites. In-game assets (flat top-down felt, card back, J/Q/K/A faces, 6 chips, dealer button) are generated separately by the owner with Gemini from short prompts; number pips are drawn in code. Compress to WebP/JPG (~200 KB). Neon card indices need much brighter contrast at phone size; offer a four-colour deck option. Glasses with an amber drink in the art are fine (alcohol rule, STANDARDS Game Browser section).

## Decisions
- Variants: keep Hold'em, Omaha (PLO), Draw, Stud. Add Short Deck, Pineapple, Omaha Hi-Lo. Later: Stud Hi-Lo, 2-7 Triple Draw. Open-Face Chinese = its own game.
- Modes: one Career with boss opponents (merges Career/Survival/AI Challenges/Boss); Roguelike optional, later. Keep Tournament, Sit & Go, Heads-Up, Quick Play, Practice, Daily Challenge/Puzzles, Private Tables.
- Cut: Poker Bingo, Custom Rule Editor, Scenario Generator. Late or cut: Ghost Mode, Replay Sharing, Spectator, Leagues/Clubs.
- Online: friends/private tables keep host-dealt (host = seat 0). Public/ranked needs a server-authoritative shuffle on Supabase = schema change: ask first, write SQL files for the owner to run. **Ranked/public online is later** (owner skipped the question; default). Chat = preset emotes only, no free text.
- Odds / win-chance display is a **switchable option**; hands played with it (or the coach) are flagged `aids` in the history so leaderboards/ranked can skip them.
- No buying chips, no real money, no ads.
- **Casino hub category** (owner idea): Poker, Blackjack (future game), Roulette, Video Poker, Baccarat, Craps, ... standalone "chunk" that could be marketed separately. Shared casino kit (chip wallet, table look, lobby) in one folder so it can be split into its own app; the casino exterior art is the category entry. Needs an APK build (new hub category), probably an 18+ rating and regional limits if it ever ships alone: check before marketing. Not started.
- STANDARDS §9 says card games use the shared green felt behind Landing and play (Poker is in `FELT_GAMES`). The new dark-room art would contradict it: when Casino games get their own backgrounds, update STANDARDS + `FELT_GAMES` in the same commit (owner to confirm). For now the shared backdrop stays and the new table sits on it.
- Known engine rule to decide: a short all-in raise (less than a full raise) re-opens betting for everyone who already acted; many casinos only allow call/fold. Left as is; owner to say.

## Phases
0. **Foundation (DONE 2026-10-27, unpublished)**: 0.1 rules test + baseline (`tools/test_poker_rules.gd`), 0.2 variant rulesets (`_rules*.gd`), 0.3 deck/describe from rules, 0.4 AI + coach ask the rules (`tools/test_poker_ai.gd`), 0.5 hand history recorder (`_history.gd`, `tools/test_poker_history.gd`).
1. **In progress.** Done: 1.1 look system (`_look.gd`: all colours for classic + voodoo, `Look.tex()` art slots under `games/video_poker/art/<look>/`; table/seats/chips/cards read it; `tools/test_poker_look.gd`; `tools/shot_poker_table.gd` draws the table in both looks for a visual check, needs a window). Next 1.2 cards, 1.3 chips, 1.4 oval layout, 1.5 landscape, 1.6 options, 1.7 backgrounds, 1.8 variant checks into rules, 1.9 proof. Art pipeline + both skins, top-down table, portrait + landscape, new in-game layout (still ~30 variant-name checks in `_game.gd`/`_view.gd` to move into rules).
2. Stats, hand history screens + replay, XP, achievements.
3. Tournament / Sit & Go polish, AI personalities, bosses, Career.
4. New variants (Short Deck plugs in through a rules file: 36-card `new_deck()`, own `hand_score`/`best_cards`/`describe`; the eval hot path stays untouched).
5. Online: friends tables first, then ranked.
Each phase: propose a task list, wait for OK. `publish-packs`/`release` only on the owner's OK.
