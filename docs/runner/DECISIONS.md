# The Runner: decisions log

The owner's design doc (`GAME_DESIGN_THE_RUNNER.md` §0) asks for every decision to be logged here.
Owner answers are marked **(owner)**; everything else is a default chosen while building, open to change.

## Settled with the owner (2026-11-02)
- **D-1 (owner)** Id `the_runner`, title "The Runner" in English and Spanish, category Adventure (next to Turned). Ids are never renamed.
- **D-2 (owner)** Fixed hero: the man in the landing art. No look picker in pack v1.
- Single player only, Pad overlay mostly transparent, Menu button → ship computer with six tabs **(owner, kickoff message)**.

## Defaults chosen while building pack v1
- **D-3** Content lives in `scripts/games/the_runner/the_runner_data.gd` as constants, not JSON under `/data` (design doc §0). Why: the hub's translation tool (`hub.py i18n`) only reads English text from `.gd` files; JSON names would never be translated. Same tables, same "no content in the engine" rule.
- **D-4** Engine: Godot / GDScript (design doc open question 1). Art: the owner's paintings as they are (open question 2). Combat: turn-based (Attack / Evade / Run) (open question 3). Monetization: none (hub rule, open question 4). Phone + PC (open question 5). Scope v1: one system, Cradle Reach (open question 6). Tone: gritty with pulp (open question 7).
- **D-5** One system map, `system_1.webp`: ten worlds placed on the picture's own planets (bright-spot detection, not guessed). The Sun and the black hole in the picture are hazards ("The Maw"). The other orbit pictures (`system_2/3`, `system_rings`, `system_star`, `system_blackhole`) are imported for later systems.
- **D-6** Starting ship is the Moth (design doc: the Runner comes with M03). The Runner = more hold, tank, hull, guns, and the Ghost Core (+3 stealth).
- **D-7** No "stims": contraband is forged IDs, bootleg data, unlicensed weapons, stolen tech, Hollow relics. Keeps the game out of the `drug_reference` rating descriptor. Manifest content: 12+, `violence_cartoon` (owner to confirm).
- **D-8** Scan formula: design doc §9 with base 0.65 (not 0.5) and law weighted 0.04 (not 0.08): the doc's numbers gave an 11% pass chance at Luna with a clean hidden hold. Contraband in the open hold multiplies the pass chance by 0.35.
- **D-9** Pirate tribute = 100 + 15% of cargo value + 5% of your credits (max 2,000). A share of all your money (first version) worked as a wealth tax: the 10,000-trip simulation never got past ~36k.
- **D-10** Safety net: broke, nothing to sell, can't move → Mother Kessel lends 500 (owe 600), any port. A tow when the tank runs dry costs 500 or goes on the debt. No run can soft-lock.
- **D-11** Unpaid fines no longer become debt: they take what you have.
- **D-12** Dirty credits pay for contraband, black-market parts, bribes, tribute, fuel, repairs and the debt. Legal goods and legal parts need clean credits. Net worth = clean + half the parts' price + cargo at base price + 30% dirty − debt.
- **D-13** Skill tree = the six specializations of design doc §7.2, three ranks each, all live. First branch learned = primary, second = secondary, the rest stay locked.
- **D-14** Hints (owner rule 2026-11-01): the Fixer's tip in the Market names the best trade from here. 3 at most, +1 every 24 h, in `user://the_runner_hints.json` (outside the run save, so a new run doesn't refill them).
- **D-15** Leaderboard: "Best net worth" (higher is better; only positive values post). Act I done = `info.result("win")` once.
- **D-16** The Pad shows only on the system map (stick flies, A = GO / DOCK, B = STOP, its pause and menu pills replace the status bar's ⏸ and ☰ there). Dock, market and menus are tap screens: the Pad hides. `_pad()` is not defined (owner 2026-10-29: Controls in Options stay hidden).
- **D-17** Saving: the kit's pause saves the whole run (`user://the_runner_save.json`, version 1), including an open encounter and the ship's place mid-flight.

## Not built yet (say so, don't assume)
Design doc milestones M6-M11 beyond what is listed above: factions' questlines and reputation effects per faction (only infamy / street cred numbers exist), safehouses, lieutenants, automated smuggling routes, territory, piracy actions beyond fights (hijack, board, ransom), crew and mutiny, disguises / transponders, galaxy gates and galaxies 2-4, Acts II-III and the endings, the Ledger story beyond M04, a galaxy map screen (the constellation pictures are imported, unused). Pack v1 LIVE 2026-11-02 (4.9 MB; art imported lossy). Not phone-tested.
