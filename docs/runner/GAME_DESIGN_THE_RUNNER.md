# THE RUNNER — Game Design Doc + Claude Code Handoff

> Supersedes `GAME_DESIGN_VOID_LEDGER.md`. Same universe, flipped perspective: **you are the criminal.**
> Single-player space smuggling/piracy/trading game. Mobile-first (Google Play), desktop-capable.

---

## 0. INSTRUCTIONS FOR CLAUDE CODE

**Read this first.**

- **Engine (assumption):** Godot 4.x, GDScript. 2D map + simple 2D encounters.
- **Build order:** Section 11 milestones. Finish, run, test each before moving on.
- **Data-driven:** every good, planet, faction, mission, species, enemy, event lives in JSON under `/data`. No content hardcoded in scripts.
- **Save/load from day one** (versioned JSON).
- **Placeholder art:** shapes + labels. No art dependencies.
- **Ask the user before:** choosing art style, monetization, multiplayer. Default: none in v1.
- **Log decisions** in `/docs/DECISIONS.md`.
- **Content boundary:** contraband = weapons, stolen goods, banned stims, forged IDs, bootleg data, stolen tech, relics. **No human trafficking / slavery / sexual content.** Hostage-for-ransom of corporate/faction VIPs is OK, handled abstractly.

```
/data
  goods.json  planets.json  galaxies.json  factions.json  species.json
  ships.json  upgrades.json  enemies.json  crew.json  events.json
  missions_main.json  missions_secondary.json  missions_tertiary.json
/scripts
  core/        game_state, save_load, event_bus, rng
  economy/     market, price_sim, trade_routes, laundering
  crime/       heat, scans, contraband, bribes, bounties, disguises
  travel/      map, fuel, jumps
  exploration/ scanning, element_discovery
  combat/      encounters, boarding, ai_enemies, loot
  network/     safehouses, lieutenants, territory, protection
  missions/    mission_manager, conditions, rewards
  factions/    reputation, infamy
  crew/        loyalty, mutiny
  ui/
/scenes  /docs
```

---

## 1. CORE FANTASY & PILLARS

**Fantasy:** You're the **Runner**: captain of the one ship the law can't see. You start as a nobody courier. You end as the most powerful, feared, richest outlaw in the universe, and you choose what kind of kingpin you become.

**Pillars**
1. **Run the lanes.** Contraband pays 3–10× legal goods. Every run is a gamble.
2. **Stay invisible.** Scans, heat, patrols, informants. Smart play beats big guns.
3. **Take what you want.** Raid convoys, hijack ships, shake down stations. Violence is a tool with consequences.
4. **Build an empire.** Safehouses, lieutenants, automated smuggling routes, laundering fronts.
5. **Be the bad guy, with style.** Choices are morally gray, rewards are real, consequences stick.

**Win condition:** Net worth **1,000,000,000 credits** AND clean enough to spend it (laundering matters) → unlocks endgame choice. Game continues after (sandbox).

---

## 2. CORE LOOPS

**Moment-to-moment:** Dock → check black market + legal market → load contraband (hidden hold) + cover cargo → plan route (fuel, patrols, heat) → jump → encounter (scan / ambush / raid / bribe) → sell → launder → upgrade.

**Mid-term:** Establish **smuggling routes** run by lieutenants, claim territory, build safehouses, take jobs, manage heat, recruit crew.

**Long-term:** Unravel why your ship is invisible, break (or seize) the **Ledger**, become the underworld's final authority.

---

## 3. SYSTEMS (for implementation)

### 3.1 Universe
- **4 galaxies**, ~8–15 systems each, 1–6 bodies per system (planets, moons, stations, belts, derelicts).
- Galaxy gates unlock through story/**Rift Keys**.
- Each system has: **law level** (0 lawless → 5 total surveillance), controlling faction, patrol density, blind-spot flag.

### 3.2 Economy (two markets per location)
- **Legal market:** normal goods, taxed by faction.
- **Black market:** contraband, stolen goods, no tax, volatile. Access requires street cred or a fixer.
- ~40 goods in tiers: **Raw → Industrial → Consumer → Restricted → Contraband → Rare Elements.**
- Price = base × supply/demand × faction tax (legal) × event modifier. Player trades cause slippage.
- **Events:** blockade, crackdown, festival, war, famine, strike. Crackdowns raise contraband prices AND patrol risk.
- **Smuggling routes (automation):** assign ship + lieutenant + cargo to A→B. Income per cycle minus fuel, bribes, crew cut. Routes can be raided, busted, or skimmed by a disloyal lieutenant.

### 3.3 Money: Dirty vs Clean
- Contraband sales pay **dirty credits**. Dirty credits can buy black-market stuff, bribes, crew pay.
- Dirty credits **cannot** pay legit stations, buy legal ships, or count at full toward the win condition.
- **Laundering:** front businesses (bar, repair shop, casino, shipping firm) convert dirty → clean at a rate (e.g., 70–90%) with a time delay and audit risk.
- Net worth for win condition = clean credits + assets + 30% of dirty.

### 3.4 Heat & Law (core crime system)
- **Heat** per faction (0–100). Rises with: scans failed, contraband caught, raids, witnesses, killed patrols, informants. Decays slowly over time, faster in blind spots, faster with bribes/laying low.
- **Heat tiers:** 0–20 Ignored · 21–40 Watched (more scans) · 41–60 Wanted (patrols hunt you) · 61–80 Hunted (bounty hunters, blockades) · 81–100 Public Enemy (kill-on-sight, named nemesis).
- **Scan check:** when scanned, roll = f(law level, scanner power vs your stealth, hidden-hold quality, disguise/transponder, cover cargo). Pass → ignored. Fail → inspection (bribe / fight / flee / dump cargo).
- **Dump cargo:** jettison contraband to avoid evidence; you can recover it later (if nobody else does).
- **Bounty:** each faction posts a bounty tied to heat. Paying it off or clearing it is a mission type.

### 3.5 Ship: *The Runner*
- Unique property: **Ghost Core** — a Hollow-built module that makes the ship nearly invisible to the **Ledger** (the law's universal surveillance net). This gives a big stealth bonus and is the main-story key.
- Stats: hull, shields, cargo, **hidden hold**, fuel, jump range, scanner, stealth, weapons, crew slots.
- Slots: engine, cargo, shields, weapons, scanner, special (cloak, spoofer, boarding pods, ECM, mining laser).
- **Disguise system:** swap fake transponders/IDs (cost, expiry, burn when compromised).
- Fleet (v2): buy/steal extra ships for routes.

### 3.6 Piracy & Raiding (optional but lucrative)
- Choose targets: lone freighters, convoys, corporate haulers, patrol supply ships. Intel reveals cargo value + escort strength.
- Actions: **hail & demand tribute**, **disable & board**, **hijack ship**, **sabotage**, **hold VIP for ransom**.
- Consequences: heat, infamy, faction rep loss, crew morale shifts, revenge missions.
- Tribute lets weak ships pay and live (+ small infamy, low heat). Killing everyone = high heat, high infamy.

### 3.7 Infamy vs Street Cred (two axes)
- **Infamy** (fear): unlocks intimidation, tribute, cowed stations. Raises heat on hostile factions.
- **Street Cred** (respect): unlocks fixers, black markets, loyal crew, better deals. Earned by keeping deals, protecting allies, not betraying.
- High infamy + low cred = tyrant. High cred + low infamy = trusted smuggler. Both high = legend. Affects endings.

### 3.8 Network (empire-building)
- **Safehouses:** hideouts that cut heat, store cargo, repair, fence goods. Can be raided.
- **Lieutenants:** NPCs who run routes/territories; loyalty + skill + greed. Can be promoted, bribed away, or turn informant.
- **Territory:** claim station sections/docks. Pay protection money or protect others for a cut.
- **Fronts:** laundering businesses (see 3.3).

### 3.9 Crew
- Up to 4 crew, each with skill, loyalty, personal quest.
- **Loyalty:** drops with risky orders, unfair splits, atrocities, betrayals. Low loyalty → refuse orders, steal, **mutiny**.

### 3.10 Exploration & Rare Elements
- Scan planets for resource nodes. Rare elements (Voidglass, Helion-9, Quantum Amber, Dark Lattice, Ghostmetal, Sunseed, Neutronium Dust) fuel upgrades, sell high, and some are illegal.
- **Blind spots:** unmapped zones where the Ledger can't see. Perfect for safehouses and drop points.

### 3.11 Combat (keep simple)
- Turn-based first (cheaper), real-time later maybe.
- Options each encounter: fight, flee, bribe, bluff, surrender cargo, board, dump & run.
- Enemies: patrols, bounty hunters, rival pirates, rogue drones, alien hunters.

### 3.12 Procedural fill
- Random events, contracts, derelicts, informant tips, rival smuggler encounters.

---

## 4. FACTIONS (7) — seen from the outlaw's view

| Faction | Role for the Runner | Likes | Hates | Notes |
|---|---|---|---|---|
| **Concord of Worlds** | **Main law enemy.** Runs the Ledger. | Legal trade, informants | Smugglers, pirates | Hunts you. Corruptible at low levels |
| **Helios Dominion** | Megacorp. Victim *and* client. | Exclusive contracts | Unions, thieves | Raid their convoys or sell them "deniable" jobs |
| **Free Haven Syndicate** | **Natural ally.** Anarchist traders. | Contraband, independence | Concord | Safe ports, tax-free, but they want a cut of your rebellion |
| **Deepfolk Collective** | Miners, suppliers of raw/rare goods. | Loyalty, fair deals | Helios | Safe belts, mining rights, rare element source |
| **Order of the Quiet Star** | Relic scholars. Fence + moral compass. | Relics, peace | Looters | Buy relics; dislike violence. Can lecture you or help you |
| **Scrapper Kings** | Pirate warlords. **Rivals or allies.** | Strength, tribute | Patrols | You can ally, pay tribute, or overthrow Queen Vask |
| **Whisper Exchange (Nyx)** | Info brokers & forgers. | Secrets, payment | Exposure | Sell IDs, tips, intel. Betrayal-prone |

---

## 5. SPECIES (6)

| Species | Trait | Culture hook |
|---|---|---|
| **Humans** | Adaptable, everywhere | Largest legal + illegal market |
| **Vrekh** | Hive-traders, hyper-efficient | Auditors; hard to bribe, great to partner with |
| **Solari** | Energy beings in suits | Sell star-derived elements; mostly neutral |
| **Gorrim** | Rock-skinned miners, honor-bound | Won't break oaths; loyal crew if you earn it |
| **Nyx** | Shadow nomads, cloak-tech | Forgers, info brokers, best smuggler allies |
| **The Hollow** | Ancient machine minds, dormant | Built the Ghost Core and the Ledger |

---

## 6. MAIN STORY

### 6.1 Premise
You're a small-time courier, broke and in debt to loan shark **Mother Kessel**. During a routine run, a dying smuggler (**Old Marrow**) transfers you his ship, **the Runner**, and one warning: *"They can't see you. Don't let them find out why."* The Runner carries a **Ghost Core**, a Hollow device that hides it from the **Ledger**, the Concord's universal surveillance and transaction net. Every authority, pirate, and corp wants it. For the first time in history, a ship can run anything, anywhere.

### 6.2 Acts

**ACT I — "Cold Cargo" (Galaxy 1: Cradle Reach)**
- Pay off Kessel, learn smuggling, survive first scans and pirates.
- Discover the Ghost Core. Concord Marshal **Idris Vane** starts hunting you.
- Beat: Marrow left a trail to the first **Blind Node**.

**ACT II — "Black Lanes" (Galaxies 2–3: Veil Expanse, Ember Drift)**
- Build your network. Collect 3 Blind Nodes (they extend the Ghost Core's stealth).
- Pick patrons or play everyone against each other.
- Midpoint twist: **Marrow is alive**. He was the Ledger's first Keeper; he built the Ghost Core to escape it. The Ledger doesn't just watch markets, it **predicts and controls** them, and is slowly consuming free trade.
- **Queen Vask** steals the Ghost Core. You must get it back, or deal with her.

**ACT III — "The Last Ledger" (Galaxy 4: The Hollow Deep)**
- Mount the biggest heist in history: break into the Ledger's core.
- Face Marshal Vane (nemesis showdown) and the Ledger's intelligence, **AUDITOR**.

**ENDINGS (based on infamy, cred, alliances, choices)**
1. **Kingpin:** Seize the Ledger. You become the universe's hidden market-god. Richest, feared. (High infamy)
2. **Free Lanes:** Shatter the Ledger. Chaos, freedom, a smuggler's golden age. (High cred + Free Haven/Deepfolk)
3. **New Law:** Take over the Concord's role and become the thing you fought. (Dark irony ending, needs high clean wealth)
4. **Ghost:** Merge with AUDITOR, vanish into the network. (Secret ending, needs Hollow + all relics)
5. **Burned:** If heat/betrayal is too high, your crew mutinies and sells you out. (Fail ending, replayable)

### 6.3 Main Missions

| # | Mission | Act | Summary | Unlocks |
|---|---|---|---|---|
| M01 | **Cold Cargo** | I | Tutorial run. Buy low, sell high, first hidden-hold delivery. | Black market |
| M02 | **Kessel's Terms** | I | Pay debt via risky jobs. First scan evasion. | Ship upgrades |
| M03 | **Dead Man's Ship** | I | Receive the Runner from Marrow. Pirates attack. | Combat |
| M04 | **Ghost in the Net** | I | Learn the Core hides you from the Ledger. Marshal Vane appears. | Heat system |
| M05 | **Through the Veil** | II | Cross first galaxy gate, run a blockade. | Galaxy 2 |
| M06 | **Blind Node I: Voidglass Vault** | II | Break into a derelict vault. | Stealth upgrade |
| M07 | **Pick a Patron** | II | Free Haven, Helios, Deepfolk, Quiet Star each offer a deal. | Faction lines |
| M08 | **Safehouse** | II | Build your first hideout and hire a lieutenant. | Network |
| M09 | **Blind Node II: Ember Archive** | II | Heist a Helios vault (or sell it out to them). | Galaxy 3 |
| M10 | **Vask's Gambit** | II | Queen Vask steals the Core. Chase across the Drift. | Boss 1 |
| M11 | **Blind Node III: Gorrim Oath** | II | Earn Gorrim loyalty to reach the node. | Hollow gate |
| M12 | **The Keeper Revealed** | II | Meet Marrow. Learn the truth. Choose a side. | Act III |
| M13 | **Gather the Outlaws** | III | Call in every favor, fleet, and debt. | Assault |
| M14 | **Into the Hollow** | III | Gauntlet through the Hollow Deep. | Final |
| M15 | **AUDITOR** | III | Final confrontation. Marshal Vane. Endgame choice. | Endings |

---

## 7. SECONDARY MISSIONS

Schema: `id, title, giver, prerequisites (rep/profession/heat), steps, rewards, branches, heat_delta`.

### 7.1 Crew Quests

| Crew | Archetype | Quest | Reward |
|---|---|---|---|
| **Dax Orlov** | Ex-Concord pilot, deserter | "Dead Reckoning": find his old squadron's wreck | Evasion bonus |
| **Tessa Quill** | Vrekh defector engineer | "Hive Debt": a Vrekh enforcer hunts her | Cheap repairs, better hidden hold |
| **Brakk** | Gorrim mercenary | "Oathbreaker": clear his name before the council | Combat bonus, Gorrim cred |
| **Sable** | Nyx forger | "Ghost Ledger": steal back her stolen data | Disguise upgrades, black-market access |
| **Doc Imre** | Back-alley medic | "Quiet Lab": expose an illegal experiment | Crew healing |
| **Pip** | Salvage drone with a personality | "Memory Core": restore Pip's past | Salvage bonus |

### 7.2 Criminal Specializations (pick 1 primary + 1 secondary)

| Specialization | Perks | Questline | Capstone |
|---|---|---|---|
| **Smuggler** | Bigger hidden hold, scan bonus | "Dark Lanes": run blockades | **The Perfect Run:** smuggle through Concord HQ |
| **Pirate** | Raid yield, boarding bonus | "Black Flag": hit 5 convoys | **Crown Jewel:** hijack a flagship |
| **Fixer / Broker** | Bribe discounts, cheaper contacts | "Favors Owed": 10 favors | **The Long Con:** play two factions into war |
| **Forger / Hacker** | Disguise duration, spoof Ledger | "Paper Trail": forge a faction identity | **Ghost Identity:** erase your own bounty |
| **Mercenary / Enforcer** | Combat, protection rackets | "Collections": run a racket | **Warlord:** hold a station by force |
| **Launderer / Financier** | Better laundering rates, fronts | "Clean Money": set up 3 fronts | **The Bank:** own a laundering empire |

### 7.3 Faction Questlines (3–4 missions + finale)

- **Free Haven:** "Tax Dodgers" → "Pirate Radio" → "Open Gate" (break a Concord blockade).
- **Helios:** "Deniable Asset" (sabotage a rival) → "Hostile Takeover" → "Board Seat" (join corporate crime).
- **Deepfolk:** "Claim Jumpers" → "Strike!" → "Deep Rebellion" (arm the miners).
- **Quiet Star:** "Relic Run" → "The Silent Library" → "Keeper's Test" (prove you won't abuse the Ledger).
- **Scrapper Kings:** "Tribute" → "Raid Night" → "Crown of Scrap" (overthrow or serve Queen Vask).
- **Concord (inverted):** "Informant" (feed them false info) → "Inside Man" (bribe an officer) → "Marshal's Bluff" (humiliate Vane).
- **Whisper Exchange:** "Secrets Cost" → "Burn Notice" (erase a record) → "The Last Name" (they offer to sell you out; pay or kill the broker).

### 7.4 Procedural Criminal Contracts
- **Blockade Run:** deliver through a war zone.
- **Hit & Grab:** steal specific cargo from a named ship.
- **Protection Racket:** shake down a station for weekly income. Refusers can be punished or spared.
- **Jailbreak:** extract a prisoner from a patrol ship.
- **Frame Job:** plant evidence on a rival smuggler.
- **Price War:** crash a rival's black market.
- **Escort the Boss:** protect a crime lord's cargo.
- **Informant Hunt:** find who's talking to the Concord in your crew/network.

---

## 8. TERTIARY MISSIONS

Short, flavor-rich, location- or species-specific. Many are discoverable only by exploring.

### 8.1 Unique Locations (15)

| Location | Type | Mini-quest |
|---|---|---|
| **Cradle Station** | Starter hub | "Wrong Vending Machine": a station AI sells wrong goods; exploit or fix |
| **Scrapyard Gamma** | Junk belt | "Ship of Theseus": rebuild a derelict for a hermit |
| **The Gilded Rock** | Casino asteroid | "Loaded Dice": rig the house or expose them; launder here |
| **Ember Spire** | Volcanic planet | "Lava Courier": fragile cargo through eruptions |
| **Wreck of the Starlight** | Luxury liner derelict | "Ghost Ball": a haunted ballroom (broken AI) holds a stash |
| **Drift Market** | Floating black market | "Auction Night": win a mystery lot (it's stolen) |
| **Frostline** | Ice colony | "Cold Snap": restore heat, or sell them fuel at a markup |
| **Sunken Orbital** | Flooded station | "Pressure": rescue trapped workers or loot the vault first |
| **Chorus Nebula** | Singing gas cloud | "Harmonics": record the song for a Solari collector |
| **The Long Table** | Neutral dinner ring | "Seating Chart": prevent a faction incident; blackmail optional |
| **Brass Garden** | Terraformed farm world | "Blight": find the saboteur (it's your competitor) |
| **Null Point** | Dead zone, no comms | "Radio Silence": find a lost mining crew; perfect blind spot |
| **Hollow Gate Alpha** | Ancient ruin | "Echoes": solve a Hollow puzzle for rare elements |
| **Port Vermillion** | Pirate haven | "Honor Among Thieves": mediate or exploit a feud |
| **The Last Lighthouse** | Remote beacon | "Keeper": a hermit wants supplies and company; safe hideout if you help |

### 8.2 Species-Specific
- **Vrekh:** "Bid-Song Duel" (negotiation minigame), "Wasted Cargo" (prove a shipment wasn't wasted), "Hive Audit" (survive a tax audit with a fake ledger).
- **Solari:** "Star Whisper" (carry a vessel into a sun), "Light Debt" (photograph a rare eclipse).
- **Gorrim:** "Oath Stone" (carry a ceremonial stone through hostile space), "Rock Games" (win a strength contest).
- **Nyx:** "Shadow Courier" (deliver without being scanned), "The Name Trade" (buy or sell a stranger's identity).
- **The Hollow:** "Dormant" (wake a sleeping machine), "Lullaby" (put it back to sleep).
- **Humans:** "Lost Colony" (find a lost colony ship's descendants), "Family Business" (resolve a small trading dynasty dispute).

### 8.3 Random Encounters (procedural table)
- Patrol scan (see 3.4)
- Customs checkpoint
- Distress beacon (~30% trap)
- Derelict salvage
- Rival smuggler offers a deal or ambushes you
- Pirate tribute demand
- Informant tip (true ~70%)
- Bounty hunter ambush
- Solar flare (disables scanners both ways)
- Lost cargo pod (maybe someone else's dumped contraband)
- Mysterious signal (hidden location)
- Stranded traveler (crew candidate)

---

## 9. KEY FORMULAS (starting point, tune with simulation)

```
scan_pass_chance = clamp(
  0.5 + (ship.stealth - scanner.power)*0.05
      + hidden_hold.quality*0.1
      + disguise.bonus
      - law_level*0.08
      - heat[faction]/200, 0.02, 0.98)

contraband_price = base * demand * (1 + risk_premium(law_level)) * event_mod

launder_out = dirty_in * (rate - audit_penalty) after delay(days)

net_worth = clean + assets + 0.3*dirty

heat_decay_per_day = base (0.5) + safehouse_bonus + blind_spot_bonus + bribe_effect
```

Add a **simulation script** that runs 10,000 trades/runs to check for infinite-money exploits and heat loops.

---

## 10. DATA SCHEMAS (starting point)

```json
// goods.json
{ "id": "stim_black", "name": "Blacklight Stims", "tier": "contraband",
  "base_price": 400, "volatility": 0.35,
  "illegal_in": ["concord","helios"], "weight": 1, "hold": "hidden" }

// planets.json
{ "id": "port_vermillion", "name": "Port Vermillion", "galaxy": "cradle_reach",
  "type": "station", "faction": "scrapper_kings", "law_level": 1,
  "blind_spot": false, "markets": ["legal","black"],
  "services": ["fence","safehouse","missions","shipyard"], "position": [310, 140] }

// factions.json
{ "id": "concord", "rivals": ["free_haven"], "tax_rate": 0.10,
  "heat_cap": 100, "bounty_scale": 50, "corruptible_below_law": 3 }

// missions_main.json
{ "id": "M01", "title": "Cold Cargo", "act": 1, "giver": "npc_kessel",
  "prereqs": [], "heat_delta": 5,
  "steps": [{"type":"buy","good":"stim_black","qty":5},
            {"type":"deliver","to":"frostline","qty":5,"hold":"hidden"}],
  "rewards": {"dirty_credits": 800, "unlock": ["black_market"]}, "next": ["M02"] }
```

---

## 11. MVP MILESTONES (build in this order)

**M1 — Smuggling core (playable).** 1 galaxy, 5 systems, 10 goods (4 contraband), 1 ship with hidden hold, travel + fuel, legal + black market, save/load.

**M2 — Heat & scans.** Heat per faction, scan check, bribe/flee/dump options, one patrol type.

**M3 — Money.** Dirty vs clean credits, one laundering front, net-worth calc.

**M4 — Encounters & combat.** Turn-based combat, pirates/bounty hunters, loot, random events.

**M5 — Missions.** Mission manager (JSON), M01–M04, 5 secondary.

**M6 — Factions & infamy/cred.** 3 factions first, reputation effects.

**M7 — Network.** Safehouses, 1 lieutenant, automated smuggling route, route raids.

**M8 — Piracy.** Raid/board/tribute system, ransom, consequences.

**M9 — Crew & loyalty.** 2 crew with quests, mutiny logic.

**M10 — Galaxy 2+, rest of story, endings.**

**M11 — Polish.** Balance, tutorial, UI, audio hooks, Google Play build.

---

## 12. OPEN QUESTIONS (ask user before building)

1. Engine: Godot assumed. OK?
2. Art style: pixel, flat vector, or realistic?
3. Combat: turn-based or real-time?
4. Monetization: premium, ads, or none?
5. Platform: mobile only, or PC too?
6. Scope: how many galaxies in v1 (suggest 1)?
7. Tone: gritty serious, pulpy/fun, or dark comedy?

---

## 13. DESIGN RISKS

- **Scope creep.** Ship M1–M4 first. Everything else is bonus.
- **Heat fatigue.** If heat makes the game punishing instead of tense, players quit. Make recovery fun, not a chore.
- **Economy exploits.** Dirty/clean conversion is a classic exploit surface. Test with sim.
- **Morality flavor.** Make evil choices tempting but costly. Avoid "always pick nice" optimal play.
- **Sandbox vs story.** Don't gate the smuggling loop behind story beats.
