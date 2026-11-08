# THE RUNNER — Master Design Doc v2 (Claude Code Handoff)

> \*\*Supersedes\*\* `GAME\_DESIGN\_VOID\_LEDGER.md` and `GAME\_DESIGN\_THE\_RUNNER.md`.
> Keeps: the ship \*Runner\*, the Ghost Core, the Ledger, heat/smuggling/dirty-vs-clean money.
> Adds: races, 10 factions, Paragon/Outlaw alignment, 31 good perks + 15 flaws, 16 recruitable crew, quests with reward values, full lore, conquest endgame.
> \*\*All tables in this doc are the source of truth. Convert them to JSON in `/data`.\*\*
> \*\*v2.1 changes:\*\* real-time combat · 2 starting perk picks · Sskarn NPC-only · Paragon \& Outlaw are two independent bars · quests change only the factions they list (explicit +/-) · every faction has bonuses at 50 / 75 / 100% rep.

\---

## 0\. INSTRUCTIONS FOR CLAUDE CODE

* **Engine (assumed):** Godot 4.x, GDScript. Mobile-first (Google Play).
* **Data-driven:** races, perks, factions, crew, quests, planets, ships → JSON in `/data`. No hardcoded content.
* **Build in milestones** (Section 15). Run and test each before the next.
* **Placeholder art:** shapes/labels. Ship sprite must support **visible modular parts** (see 1.2).
* **Config flags** (top of `/data/config.json`): `starting\_perk\_picks` (default **2**), `crew\_flaw\_strength` (default **0.5**), `perk\_stack\_cap` (default **2 sources**), `battle\_mode` (default `realtime`; also `realtime\_pause` | `turn\_based`).
* **Log decisions** in `/docs/DECISIONS.md`.
* **Content boundary:** no human trafficking, slavery, or sexual content. Atrocity-tier Outlaw quests are abstract (text + stat outcome, no graphic depiction).
* **Ask the user** before art style or monetization. Default: none in v1.

\---

## 1\. WORLD SCALE, TRAVEL \& BATTLE

### 1.1 Spacing

* Planets are **far apart on a scrolling space map**. Travel between neighbors takes **real flight time** (base: 20–40 s; farther = longer; speed perks shorten it).
* Between planets there is **open space** with: random encounters, derelicts, asteroid fields, patrols, blind spots.
* Tap planet → set course → ship flies. Fuel is spent per distance.

### 1.2 Big ship, visible mods

* Ship sprite is drawn **large** (roughly 1/6 to 1/4 of screen width) in flight.
* Installed parts show on the hull: weapon turrets, engines, shield emitters, cargo pods, antenna/scanner, Ghost Core glow, crew-count windows.
* Part slots by hull tier in Section 6. Each slot has a visual socket.

### 1.3 Space battles

* Triggered in open space (random, scripted, bounty targets, raids, ambushes).
* **Default `realtime`:** ships move and fire in real time. Tap to target, tap ability buttons (cooldowns), drag to steer. No pause by default (optional pause toggle in settings for accessibility).
* Enemy factions use the same ship system: bigger enemy = more parts, visible weapons.
* Battle options: fight, flee, bribe, bluff, surrender cargo, board, dump \& run.
* Crew perks and ship parts feed directly into battle stats.

\---

## 2\. CHARACTER CREATION (start of game)

Screens, in order:

1. **Name** (text input, 2–16 chars).
2. **Gender:** Male / Female / Non-binary / Other (cosmetic + dialogue pronouns only, no stat effect).
3. **Race** (Section 3, **8 playable**). Show perks, flaw, home faction, and hostile races.
4. **Starting perk picks:** choose `starting\_perk\_picks` (**default 2**) from the good-perk list (Section 5.1), excluding perks you already have.

   * Result at start: **2 racial good perks + 2 chosen good perks = 4 good, + 1 racial flaw.**
5. **Starting faction standing:** start at **10% rep (100 FP)** with your race's home faction (Reptilian Humanoids pick Sunscale or Ashscale; Humans pick Terran Concord or Black Meridian).
6. Tutorial begins at **Cradle Station** with the Runner (Skiff tier).

\---

## 3\. RACES (8 playable + 1 NPC-only)

> Assumption: the "3 humanoid races" = \*\*Thalassi\*\* (aquatic), \*\*Ssaryn\*\* (reptilian humanoid, split into two rival clans), \*\*Noctari\*\* (shadow humanoid). \*\*Sskarn\*\* (feral reptilian) is the unaligned mercenary race and is \*\*NPC-only\*\*: not selectable at character creation; appears as crew (Gristle), hunt-guild contractors, and enemies.

|#|Race|Type|Home faction(s)|Good perk 1|Good perk 2|Flaw|Flavor|
|-|-|-|-|-|-|-|-|
|1|**Terran**|Human|Terran Concord (Paragon) *or* Black Meridian (Outlaw)|Master Negotiator|Efficient Refit|Needs Upkeep|Adaptable, everywhere, expensive crew|
|2|**Synthari**|Cyborg / AI|The Synthesis (Paragon)|Engineer|Hacker|Cold Logic|Machine minds and cyborgs; calculate everything|
|3|**Kestrai**|Avian|The High Aerie (Paragon)|Pilot|Dodge Master|Brittle|Hollow-boned sky-nomads; best flyers|
|4|**Sskarn** *(NPC only)*|Feral reptilian|*Unaligned* (Hunt-Guilds, neutral)|Bounty Hunter|Intimidating|Short Fuse|Predator mercenaries; take any contract|
|5|**Mycelari**|Fungal|The Bloom (Outlaw)|Cargo Scrapper|Field Medic|Marked|Hive-mycelium; consume, regrow, spread|
|6|**Verdanti**|Plant-like|Verdant Canopy (Paragon)|Iron Hull|Navigator|Slow Reflexes|Living trees; tough, efficient, slow|
|7|**Thalassi**|Aquatic humanoid|Thalassi Deepcourt (Paragon)|Cartographer|Shieldwright|Poor Haggler|Deep-water cartographers; surface money confuses them|
|8|**Ssaryn**|Reptilian humanoid|Sunscale Covenant (Paragon) *or* Ashscale Warbands (Outlaw)|Sharpshooter|Boarder|Stubborn|Two clans, one blood, one old war|
|9|**Noctari**|Shadow humanoid|The Veilbound (Outlaw)|Stealthy|Smuggler's Hold|Glass Jaw|Dim-world dwellers; forgers, spies, thieves|

### 3.1 Race compatibility (crew + player)

A crew member **refuses to join** if any race on the ship is in their **Hostile** list.

|Hostile pair|Reason|
|-|-|
|Synthari ✕ Mycelari|Contamination vs sterilization|
|Synthari ✕ Noctari|Machines see through shadows; Noctari hate being seen|
|Kestrai ✕ Sskarn|Prey vs predator|
|Thalassi ✕ Mycelari|Spore pollution of water|
|Verdanti ✕ Mycelari|Rot vs growth|
|Thalassi ✕ Ssaryn|Ancient reef-vs-shore war|

All other pairs are compatible. **Synergy bonus** (optional, +3% to a relevant stat): Terran+any, Synthari+Verdanti, Kestrai+Thalassi, Mycelari+Noctari, Ssaryn+Sskarn.

\---

## 4\. LORE \& BACKSTORY

### 4.1 The Spiral

Eons ago the **Architects** (the Hollow) seeded life across **the Spiral**, a chain of galaxies connected by **Gates**. They built the **Ledger**, a network that recorded every world, trade, and life, so the Spiral could be "balanced." Then they went silent. The Gates went dark. This is **the Silence**.

### 4.2 The Reopening

\~300 years ago the Gates woke up. Nine species who had never met poured through. Trade boomed. War followed. Two power blocs formed:

* **The Luminary Accord** (Paragon): six factions committed to law, mutual protection, and open trade.
* **The Eclipse Pact** (Outlaw): four factions that reject the Accord's "Ledger-governed order" and take what they can.
* **The Sskarn Hunt-Guilds** stay neutral and sell contracts to both.

The Accord inherited control of the **Ledger Net**, the surveillance system that tracks every ship, cargo, and credit. It keeps trade safe, but it also decides who counts. The Pact lives in the blind spots.

### 4.3 The Runner

You are a small-time courier, broke, owing **Mother Kessel** (a Black Meridian loan shark). A dying smuggler, **Old Marrow**, gives you his ship, the **Runner**, with one warning: *"They can't see you. Don't let them find out why."*

The Runner carries a **Ghost Core**, a stolen Architect device that **hides it from the Ledger**. Everyone wants it. For the first time, one ship can go anywhere, and the Spiral's balance depends on who holds the key.

### 4.4 The Truth (revealed Act II)

Marrow was the Ledger's first **Keeper**. He built the Ghost Core after learning the Ledger doesn't just watch the Spiral; it **steers markets and wars** to keep the Spiral "stable," and it is slowly ending free choice. The Accord doesn't know. The Pact suspects.

### 4.5 Your Choice

You decide what to do with the Ledger, and who you become:

* **Paragon:** unite the Spiral and rebuild the Ledger as a public good, or destroy it and trust the Accord's honor.
* **Outlaw:** seize the Ledger and rule the Spiral from the dark.
* **Neutral/Ghost:** vanish into the network.

### 4.6 Nemeses

* **Marshal Idris Vane** (Terran Concord): hunts you across all acts. Becomes an ally (Paragon) or a recurring boss (Outlaw).
* **Queen Vask** (Ashscale Warbands): steals the Ghost Core in Act II.
* **AUDITOR**: the Ledger's AI. Final boss/negotiator.

\---

## 5\. PERKS

### 5.1 Good perks (31)

Original five from the design notes are marked ★.

|ID|Perk|Effect|
|-|-|-|
|G01 ★|Bounty Hunter|+50% credits on Bounty missions|
|G02 ★|Stealthy|+15% stealth (scan pass chance)|
|G03 ★|Pilot|+15% ship speed, +10% evasion|
|G04 ★|Engineer|Repairs −30% cost, 40% faster|
|G05 ★|Master Negotiator|+10% credits from missions|
|G06|Sharpshooter|+15% weapon accuracy|
|G07|Heavy Gunner|+15% turret damage|
|G08|Smuggler's Hold|+25% hidden cargo capacity|
|G09|Haggler|−10% buy prices, +10% sell prices|
|G10|Prospector|+25% rare element find chance, +15% scanner range|
|G11|Navigator|−20% fuel use, +10% jump range|
|G12|Shieldwright|+20% shield capacity and recharge|
|G13|Iron Hull|+20% hull HP|
|G14|Boarder|+25% boarding success, +15% boarding loot|
|G15|Silver Tongue|Bribes cost −30%, bribe success +15%|
|G16|Quartermaster|+15% cargo capacity|
|G17|Field Medic|Hull self-repairs 1%/min in flight; crew injuries heal 2×|
|G18|Hacker|Enemy lock-on −20%; disable 1 enemy system per battle|
|G19|Lucky|+10% loot rarity; once per run, ignore a critical failure|
|G20|Charismatic|+10% faction points gained|
|G21|Inspiring|+25% crew loyalty|
|G22|Intimidating|+25% raid tribute; weak enemies flee earlier|
|G23|Cold Reactor|Energy weapon cooldown −15%|
|G24|Dodge Master|+20% evasion|
|G25|Cargo Scrapper|+30% salvage yield from wrecks|
|G26|Tactician|First-shot initiative; +10% allied damage|
|G27|Fence Contact|Black-market sells +15%; laundering fee −10%|
|G28|Cartographer|Reveals extra map; survey data sells +30%|
|G29|Veteran|+10% XP|
|G30|Efficient Refit|Ship upgrades cost −10%|
|G31|Contract Broker|+1 active quest slot|

### 5.2 Flaws / bad perks (15)

|ID|Flaw|Effect|
|-|-|-|
|B01|Brittle|−15% hull HP|
|B02|Spendthrift|+10% buy prices|
|B03|Short Fuse|Bribe cost +25%|
|B04|Conspicuous|−15% stealth|
|B05|Fuel Guzzler|+25% fuel use|
|B06|Cold Logic|−20% crew loyalty|
|B07|Glass Jaw|−15% shield capacity|
|B08|Poor Haggler|−8% sell prices|
|B09|Slow Reflexes|−15% evasion|
|B10|Cumbersome Cargo|−10% cargo capacity|
|B11|Marked|+15% heat gain|
|B12|Needs Upkeep|+20% crew wages|
|B13|Fragile Systems|Repairs +20% cost|
|B14|Stubborn|−20% flee success|
|B15|Gullible|Trap events twice as likely|

**Race-assigned flaws:** B12 Terran · B06 Synthari · B01 Kestrai · B03 Sskarn · B11 Mycelari · B09 Verdanti · B08 Thalassi · B14 Ssaryn · B07 Noctari.
**Unused flaws (B02, B04, B05, B10, B13, B15)** are curse/event penalties: cursed cargo, damaged parts, bad deals, "Faustian bargains" for extra credits.

### 5.3 Stacking rules

* Same perk from multiple sources: 1st at 100%, 2nd at 50%, no third.
* Any single stat bonus capped at **+60%** total.
* Flaws stack the same way (cap −40%).

### 5.4 How crew perks work

Each recruited crew member gives the ship:

1. **One racial perk** (specified per crew, from their race's two).
2. **One personal perk** (from the good list).
3. **One quirk** = their race flaw at `crew\_flaw\_strength` (default 50%).

\---

## 6\. SHIPS \& CREW SLOTS

The Runner starts as a Skiff and grows. It keeps its name and Ghost Core through every refit.

|Tier|Hull class|Crew slots (besides player)|Part slots|Cost|
|-|-|-|-|-|
|1|**Skiff** (Runner Mk I)|**1**|2 weapons, 1 engine, 1 shield, 1 special|Start|
|2|**Courier** (Mk II)|**2**|3 weapons, 2 engines, 2 shields, 2 special|25,000|
|3|**Corvette** (Mk III)|**3**|4 weapons, 2 engines, 3 shields, 3 special|150,000|
|4|**Cruiser** (Mk IV)|**4**|6 weapons, 3 engines, 4 shields, 4 special|1,000,000|

Optional endgame refit (milestone reward): **Beacon** (Paragon flagship skin) or **Dread** (Outlaw flagship skin), stat parity with the Cruiser plus a unique ability.

Parts have rarity, stats, and visuals. Cargo and **hidden hold** scale with tier.

\---

## 7\. FACTIONS (10 + 1 neutral)

### 7.1 Paragon: **The Luminary Accord**

|Faction|Race base|Home|Leader|Ideology|Rival|
|-|-|-|-|-|-|
|**Terran Concord**|Terran|Cradle Station|Commissioner Hale Okonkwo|Law, order, trade|Black Meridian|
|**The Synthesis**|Synthari|Halcyon Core|Prime Node-Ø|Logic, shared mind|The Bloom|
|**The High Aerie**|Kestrai|Aerie Spire|Matriarch Sorrel Highwind|Freedom of the sky, rescue|Ashscale Warbands|
|**Verdant Canopy**|Verdanti|Brass Garden|Elder Oak-of-Seven-Winters|Growth, patience, restoration|The Bloom|
|**Thalassi Deepcourt**|Thalassi|Abyssal Reef|Tide-Queen Maren Silverdeep|Knowledge, balance, depths|Ashscale Warbands|
|**Sunscale Covenant**|Ssaryn (Clan 1)|Sunspire Citadel|Warden Ixara Sunscale|Honor, duels, protection|Ashscale Warbands|

### 7.2 Outlaw: **The Eclipse Pact**

|Faction|Race base|Home|Leader|Ideology|Rival|
|-|-|-|-|-|-|
|**Black Meridian Syndicate**|Terran|Meridian Station|Mother Kessel|Profit, debt, protection|Terran Concord|
|**The Bloom**|Mycelari|Bloomfall|The Sporemother|Consume and spread|Synthesis, Verdant Canopy|
|**The Veilbound**|Noctari|Drift Market|The Veiled Broker|Secrets, forgery, leverage|Synthesis|
|**Ashscale Warbands**|Ssaryn (Clan 2)|The Cinder Fort|Queen Vask|Conquest, tribute, raids|Sunscale, Aerie, Deepcourt|

### 7.3 Neutral

**Sskarn Hunt-Guilds** (Brimstone Reach). Sell contracts to everyone. No alignment penalties.

### 7.4 Faction Reputation (per-faction bar)

* Each faction has its own **rep bar from −50% to +100%**. Internally: **1,000 FP = 100%** (so **100 FP = 10%**).
* **Quests change only the factions they list.** Each quest has explicit `faction\_deltas` (positive or negative). **No automatic rival penalties.** The "Rival" column in 7.1/7.2 is lore only; any rep loss with a rival must be written into the quest.
* Some quests **add** rep to one faction, some **subtract** from a specific faction, many do both.
* Quest sizes (typical FP): Small +50–100 · Medium +100–200 · Large +200–300 · Capstone +150 to each faction in a bloc.
* **Rep repair:** pay credits to a faction to raise rep (1,000 cr per +10%, only up to +50%). Cannot buy 50%+.
* **Below −25%:** faction ships attack on sight, ports closed. **Below 0%:** no quests, +20% prices.

**Access gates (all factions):** 10% = faction quests unlock · 25% = safe port + 5% discount · 50% = 10% discount.

### 7.5 Faction rep bonuses at 50% / 75% / 100% (any faction)

|Faction|50%|75%|100%|
|-|-|-|-|
|**Terran Concord**|−15% repair cost at Concord ports; safe dock|Escort wing: 2 patrol ships assist once per run|**Commissioner's Writ:** heat decays 2× in Concord space|
|**The Synthesis**|+10% scanner range|+10% energy weapon damage|**Node Link:** hull self-repairs 2%/min; free Hacker perk|
|**The High Aerie**|+10% ship speed|Wingmates: 2 Aerie fighters assist once per run|**Skyborn:** +15% evasion; free Dodge Master perk|
|**Verdant Canopy**|+10% hull HP|−15% fuel use|**Heartwood:** +20% hull HP; hull self-regen|
|**Thalassi Deepcourt**|+10% shield capacity|Reveals 5 extra systems on map|**Deep Blessing:** +20% shields; survey data sells +30%|
|**Sunscale Covenant**|+10% weapon accuracy|Honor-duel challenges unlock (big rewards)|**Sunscale Banner:** +10% damage; +15% crew loyalty|
|**Black Meridian Syndicate**|Black-market sells +10%|Laundering fee −20%|**Syndicate Seat:** debts cleared; +1 smuggling-route slot|
|**The Bloom**|+15% salvage yield|Spore cloud ability: enemy accuracy −20%|**Hive Link:** crew injuries heal 2×; +25% salvage|
|**The Veilbound**|+10% stealth|Forged IDs last 2×|**Shadow Cloak:** once per run, vanish from a battle|
|**Ashscale Warbands**|+15% raid tribute|+15% boarding success|**Warband Banner:** call a raid fleet once per run|
|**Sskarn Hunt-Guilds**|+15% bounty credits|+1 active quest slot|**Guild Master:** top-tier bounty board unlocks|

Bonuses are active while the rep stays at or above the threshold (dropping below removes it).

\---

## 8\. ALIGNMENT: TWO INDEPENDENT BARS

Two bars, filled **independently**: **Paragon bar (0–100)** and **Outlaw bar (0–100)**.

* Each quest adds points to **one** bar (or neither). Sizes: Small +1 · Medium +1 · Large +2 · Capstone +3 or +4.
* Bars **never decrease** (except rare scripted betrayal events). Doing Outlaw things does not erase Paragon progress.
* **Crew gate:** Paragon crew need Paragon bar ≥ 3. Outlaw crew need Outlaw bar ≥ 3. Neutral crew: anyone.
* **Ideology clash:** a Paragon crew member and an Outlaw crew member on the same ship each get **−15% loyalty**. (This is the cost of playing both sides.)
* Outlaw actions also raise **Heat** (scans, bounties, patrols).
* The final choice happens in Act III; you can have both bars high, but only one ending.

### 8.1 Paragon milestones (Paragon bar)

|Points|Title|Bonus|
|-|-|-|
|10|**Respected**|Paragon-port repairs −10%; Paragon crew wages −10%|
|30|**Defender**|+10% shields; piracy encounters −25% in Accord space|
|50|**Champion**|+25% crew loyalty; +5% all ship stats; unlock **Beacon** refit|
|75|**Paragon Hero**|Free repairs at Accord ports; bounty rewards +25%; call allied fleet (1×/run)|
|100|**Legend of the Spiral**|Unlocks **Unify the Spiral** endgame; allied captains join fleet|

### 8.2 Outlaw milestones (Outlaw bar)

|Points|Title|Bonus|
|-|-|-|
|10|**Notorious**|Raid tribute +15%; black-market access everywhere|
|30|**Menace**|+10% weapon damage; heat decays faster in lawless space|
|50|**Warlord**|+25% loot; unlock ship hijacking; weak enemies surrender|
|75|**Terror**|Bounty hunters spawn as nemeses (epic loot); unlock **Dread** refit|
|100|**Scourge of the Stars**|Unlocks **Rule the Spiral** endgame; worlds can be made tributaries|

\---

## 9\. PLANETS \& SECTORS

**Sector 1: Cradle Reach (start)** — Cradle Station (hub, Terran Concord), Scrapyard Gamma, Frostline, Port Vermillion, Brass Garden.
**Sector 2: Veil Expanse (Paragon heartland)** — Aerie Spire, Chorus Nebula, Abyssal Reef, Sunken Orbital, Halcyon Core, Sunspire Citadel.
**Sector 3: Ember Drift (Outlaw heartland)** — Drift Market, Bloomfall, Wreck of the Starlight, Meridian Station, The Gilded Rock, Null Point, Brimstone Reach, The Cinder Fort.
**Sector 4: Hollow Deep (endgame)** — Hollow Gate Alpha, Architect Ruins, The Ledger Core.

Sector gates unlock via main story + Rift Keys.

**Cradle Station hub:** add 6+ NPCs (dockmaster, loan shark's collector, mechanic, bartender, Concord clerk, Veilbound spy). **The Vending Machine** stays as a recurring joke and secret quest line (VEND-O-MATIC 9000: sells wrong goods; its scam grows into a late-game rare-item gag).

\---

## 10\. CREW (16 recruitable)

Rules to recruit: **(1) discovery quest complete, (2) race compatible with every race on the ship, (3) matching bar ≥ 3 (Paragon crew: Paragon bar; Outlaw crew: Outlaw bar; Neutral: none), (4) free crew slot, (5) pay hiring fee.** Opposing-ideology crew on one ship: −15% loyalty each.

|ID|Name|Race|Align|Planet|Racial perk|Personal perk|Quirk|
|-|-|-|-|-|-|-|-|
|C01|**Pip** (salvage drone)|Synthari|Neutral|Scrapyard Gamma|Engineer|Cargo Scrapper|Cold Logic|
|C02|**Marisol Vance** (ex-Concord navigator)|Terran|Paragon|Frostline|Master Negotiator|Navigator|Needs Upkeep|
|C03|**Doc Imre** (field medic)|Terran|Paragon|Sunken Orbital|Efficient Refit|Field Medic|Needs Upkeep|
|C04|**Tavi Quillfeather** (storm pilot)|Kestrai|Paragon|Aerie Spire|Dodge Master|Tactician|Brittle|
|C05|**Oren Thornroot** (agronomist-soldier)|Verdanti|Paragon|Brass Garden|Iron Hull|Quartermaster|Slow Reflexes|
|C06|**Nerida Deepcall** (reef cartographer)|Thalassi|Paragon|Chorus Nebula|Shieldwright|Prospector|Poor Haggler|
|C07|**Ravik Sunscale** (duelist)|Ssaryn|Paragon|Sunspire Citadel|Sharpshooter|Inspiring|Stubborn|
|C08|**Halcyon** (Synthesis node unit)|Synthari|Paragon|Halcyon Core|Hacker|Cold Reactor|Cold Logic|
|C09|**Sable** (forger)|Noctari|Outlaw|Drift Market|Stealthy|Fence Contact|Glass Jaw|
|C10|**Vorga Ashmaw** (boarder)|Ssaryn|Outlaw|Port Vermillion|Boarder|Intimidating|Stubborn|
|C11|**Dax Orlov** (deserter pilot)|Terran|Outlaw|Wreck of the Starlight|Efficient Refit|Pilot|Needs Upkeep|
|C12|**Sporemother Yveth** (hive-envoy)|Mycelari|Outlaw|Bloomfall|Cargo Scrapper|Smuggler's Hold|Marked|
|C13|**Tessa Quill** (rogue Synthari engineer)|Synthari|Outlaw|Null Point|Engineer|Heavy Gunner|Cold Logic|
|C14|**Brann Kole** (ex-enforcer)|Terran|Outlaw|Meridian Station|Master Negotiator|Bounty Hunter|Needs Upkeep|
|C15|**Rook** (exiled pirate pilot)|Kestrai|Outlaw|The Gilded Rock|Pilot|Lucky|Brittle|
|C16|**Gristle** (hunt-guild merc)|Sskarn|Neutral|Brimstone Reach|Intimidating|Contract Broker|Short Fuse|

### 10.1 Discovery quests (one per crew)

`PP`/`OP` = bar points. Faction changes are explicit (FP; 100 FP = 10%).

|ID|Quest|Summary|Reward|
|-|-|-|-|
|C01|**Memory Core**|Find 3 parts across Scrapyard Gamma to repair Pip.|800 cr; Pip joins (starter crew)|
|C02|**Cold Snap**|Restore heat to Frostline before the colony freezes.|1,500 cr · Concord +100 · PP +1|
|C03|**Pressure**|Rescue trapped workers on Sunken Orbital.|2,000 cr · Concord +100 · PP +1|
|C04|**Storm Run**|Fly through an ion storm to deliver medicine to Aerie Spire.|2,500 cr · High Aerie +150 · PP +1|
|C05|**Blight**|Find the saboteur poisoning Brass Garden crops.|2,200 cr · Verdant +150 · PP +1|
|C06|**Harmonics**|Record the Chorus Nebula's song without disturbing it.|3,000 cr · Deepcourt +150 · PP +1|
|C07|**Trial of Light**|Win a Sunscale ritual duel without killing.|3,500 cr · Sunscale +200, Ashscale −100 · PP +2|
|C08|**Firewall**|Defend Halcyon Core's network from an Ashscale hack.|2,800 cr · Synthesis +150, Ashscale −50 · PP +1|
|C09|**Ghost Ledger**|Steal Sable's stolen data back from a Veilbound rival.|4,000 cr (dirty) · Veilbound +150 · OP +1|
|C10|**Honor Among Thieves**|Settle a feud between pirate crews at Port Vermillion.|3,500 cr (dirty) · Ashscale +150 · OP +1|
|C11|**Dead Reckoning**|Find Dax's old squadron wreck; decide what to do with the black box.|3,000 cr · **Give to Concord:** Concord +100, PP +1 · **Sell to the Pact:** Meridian +100, Concord −100, OP +1|
|C12|**Ripe for Harvest**|Spread a spore-bloom through a supply depot.|3,500 cr (dirty) · Bloom +150, Verdant −100 · OP +1|
|C13|**Hive Debt**|Hide Quill from a Synthari enforcer, or hand her over.|**Hide:** 2,800 cr · Veilbound +120, Synthesis −100 · OP +1 · **Hand over:** Synthesis +100 · PP +1 · recruit lost|
|C14|**Collections**|Run a protection racket with Brann; spare or punish a debtor.|4,000 cr (dirty) · Meridian +150 · OP +1|
|C15|**Loaded Dice**|Rig or expose the Gilded Rock casino; Rook is the inside man.|5,000 cr (dirty) · Veilbound +150 · OP +1|
|C16|**Two-Sided Contract**|Complete a hunt that serves both Accord and Pact.|5,000 cr · Hunt-Guilds +100 · no bar change|

\---

## 11\. QUESTS (reward values)

**Format:** `Faction changes` are explicit and affect **only** the factions listed (FP; 100 FP = 10%; negatives allowed). `PP`/`OP` fill the Paragon/Outlaw bars independently. Credits are base; Master Negotiator and similar perks multiply them. JSON field: `faction\_deltas`.

### 11.1 Neutral / story-intro quests

|ID|Quest|Giver|Faction changes|Bars|Credits|
|-|-|-|-|-|-|
|N01|Cold Cargo (tutorial run)|Dockmaster|none|none|500|
|N02|Kessel's Terms (pay the debt)|Mother Kessel|Meridian +50|none|3,000|
|N03|Dead Man's Ship (receive the Runner)|Old Marrow|none|none|Ship|
|N04|Ghost in the Net (learn the Core)|Marrow's log|none|none|0|
|N05|Vending Mystery I|VEND-O-MATIC 9000|none|none|200 + junk|
|N06|Pip's Rule (tutorial for crew)|Pip|none|none|500|

### 11.2 Paragon quests

|ID|Quest|Faction changes|PP|Credits|
|-|-|-|-|-|
|P01|Medicine Run: vaccines through a blockade|Concord +100|+1|1,200|
|P02|Convoy Escort|Concord +100|+1|1,800|
|P03|Pirate Nest: clear a raider base|Concord +200, Ashscale −100|+2|4,000|
|P04|Skyward Rescue: save a stranded flock|High Aerie +100|+1|1,500|
|P05|Seed Ark: deliver terraform seeds|Verdant +150|+1|2,500|
|P06|Reef Defense: protect Abyssal Reef from raiders|Deepcourt +150, Ashscale −75|+1|2,200|
|P07|Light Trial: ritual duel (nonlethal)|Sunscale +200|+2|3,500|
|P08|Firewall: stop a network sabotage|Synthesis +150|+1|2,800|
|P09|Refugee Lanes: shuttle refugees (low pay)|One Paragon faction of your choice +100|+1|800|
|P10|Minefield Sweep: clear the Drift lanes|Concord +120|+1|2,000|
|P11|Break the Ransom Ring: free hostages|High Aerie +200, Ashscale −100|+2|3,000|
|P12|Famine Relief: deliver food **at cost**|Verdant +100|+1|1,000|
|P13|Expose the Corrupt Officer|Concord +150, Meridian −100|+1|2,500|
|P14|Beacon Rising (capstone): defend the Accord summit|All 6 Accord factions +150 each|+3|15,000|

### 11.3 Outlaw quests

|ID|Quest|Faction changes|OP|Credits (dirty)|
|-|-|-|-|-|
|O01|Cold Cargo: smuggle past a patrol|Meridian +100, Concord −50|+1|2,000|
|O02|Protection Racket: shake down a dock|Meridian +150, dock's owner faction −100|+1|3,000|
|O03|Convoy Raid: hit a hauler|Ashscale +200, Concord −100|+2|6,000|
|O04|Spore Bloom: infest a rival's supplies|Bloom +150, Verdant −100|+1|3,500|
|O05|Shadow Heist: steal a vault key|Veilbound +150, victim faction −75|+1|4,000|
|O06|Frame Job: plant evidence on a rival|Meridian +120, Concord −100|+1|2,500|
|O07|Jailbreak: extract a prisoner from a cruiser|Veilbound +200, Concord −150|+2|5,000|
|O08|Hostile Takeover: sabotage a rival's station|Meridian +150, target faction −100|+1|5,000|
|O09|Burn the Granary: cause a famine for leverage|Ashscale +250, Verdant −200|+3|8,000|
|O10|Governor for Ransom: kidnap a VIP|Ashscale +150, Veilbound +100, Concord −200|+3|12,000|
|O11|Tribute Run: collect tribute from small stations|Meridian +100|+1|1,500|
|O12|Poison the Market: crash a rival's black market|Veilbound +120|+1|3,000|
|O13|Sink the Flagship: hijack/destroy a patrol flagship|Ashscale +300, Concord −200|+3|15,000|
|O14|Crown of Shadows (capstone): unite the Pact|All 4 Pact factions +150 each|+4|25,000|

### 11.4 Faction-only favors (rep changes, no bar change)

Quests that swing a faction's rep without touching Paragon/Outlaw bars.

|ID|Quest|Faction changes|Credits|
|-|-|-|-|
|F01|Double Agent: feed the Concord false intel from Meridian|Concord +150, Meridian −150|2,500|
|F02|Peace Offering: deliver a gift to mend a feud|One faction you choose +100|−2,000 (cost)|
|F03|Embargo Run: carry a banned shipment for the Aerie|Aerie +100, Concord −50|2,000|
|F04|Reef Ledger: audit trade records for the Deepcourt|Deepcourt +100|1,800|
|F05|Guild Contract: any hunt posted by the Hunt-Guilds|Hunt-Guilds +100|3,000|
|F06|Hive Tithe: carry spores to a Bloom outpost|Bloom +100, Synthesis −50|2,200|

### 11.5 Branching quests (same quest, different payout)

* **Famine Relief (P12):** sell at cost → Verdant +100, PP +1; sell at **3× markup** → Verdant −100, OP +1, big credit bonus.
* **Dead Reckoning (C11) / Hive Debt (C13):** see 10.1.
* **Governor for Ransom (O10):** return the VIP alive after payment → OP +3, crew loyalty +; or kill → OP +4, Concord −300, crew loyalty −.

### 11.6 Procedural repeatables (generated)

* Paragon: escort, rescue, patrol, aid delivery, station defense (+50 FP to the issuer, PP +1 every 3rd completion).
* Outlaw: raid, smuggle, protection, ransom, sabotage (+50 FP to issuer, −50 FP to the target, OP +1 every 3rd completion).
* Neutral: bounty hunt, survey, trade contract (Hunt-Guilds).
* Reward scales with sector tier and rep tier.

\---

## 12\. MAIN STORY

### Act I — "Cold Cargo" (Cradle Reach)

N01 → N04. Learn trading, pay Kessel, get the Runner, meet Marshal Vane. Recruit Pip. First choice of alignment emerges.
**Choice point:** report the Ghost Core to the Concord, or keep it quiet.

### Act II — "Fractured Lanes" (Veil Expanse + Ember Drift)

* Faction questlines from both blocs; recruit crew from each.
* Gather **3 Blind Nodes** (extend the Ghost Core): Voidglass Vault, Ember Archive, Oath Vault (guarded by the Sskarn Hunt-Guilds).
* **Midpoint twist:** Marrow is alive, reveals the Ledger's secret.
* **Queen Vask steals the Ghost Core.** Retrieve it by force (Outlaw route) or by exposing her to Sunscale (Paragon route).

### Act III — "The Ledger Core" (Hollow Deep)

* Assemble allies (Paragon fleet or Outlaw armada) based on FP and alignment.
* Reach the Ledger Core. Confront Marshal Vane and AUDITOR.

### Endings

|Ending|Requirement|Outcome|
|-|-|-|
|**Unify the Spiral** (Paragon)|Paragon bar = 100, ≥ 4 Accord factions at 75%+|You become the Accord's Archon; Ledger reformed as a public record. Peace.|
|**Rule the Spiral** (Outlaw)|Outlaw bar = 100, ≥ 3 Pact factions at 75%+|You seize the Ledger. The Pact becomes the Spiral's shadow government.|
|**The Ghost** (Neutral/secret)|Neither bar at 100, 3 Blind Nodes, Pip + Halcyon + Quill recruited|You merge with AUDITOR and vanish into the network.|
|**Burned** (fail)|Crew mutiny + heat 100|Your crew sells you out. Restart or continue sandbox.|

\---

## 13\. CONQUEST LAYER (end-game "take over the universe")

**Control meter:** 22 planets total (see Section 9). Each can be **Independent / Allied / Tributary / Hostile**.

* **Paragon path:** Treaty missions + faction rep ≥ 75% → planet becomes **Allied** (benefits: discount, fleet support, income share).
* **Outlaw path:** Raid + tribute → planet becomes **Tributary** (income, but unrest and rebel quests).
* **Win** by controlling **14 of 22** planets (any mix) + clearing the Ledger Core.

Planets generate **passive income** per day, spendable on fleet, flagship, and recruited captains.

\---

## 14\. STRATEGY BUILDS (the point: choices must matter)

Starting picks = 2 extra good perks on top of the race's two.

|Build|Race|Starting picks|Key crew|Main bar|Strength|
|-|-|-|-|-|-|
|**Ghost Smuggler**|Noctari|Silver Tongue + Fence Contact|Sable, Rook, Yveth|Outlaw|Stealth + hidden cargo; fastest early money|
|**Diplomat Admiral**|Terran|Charismatic + Contract Broker|Marisol, Imre, Ravik|Paragon|Faster rep gain, allied fleets, cheap repairs|
|**Iron Bastion**|Verdanti|Shieldwright + Field Medic|Oren, Nerida, Halcyon|Paragon|Tankiest ship; safe in real-time battles|
|**Raider Warlord**|Ssaryn (Ashscale)|Intimidating + Heavy Gunner|Vorga, Dax, Brann|Outlaw|Boarding, tribute, loot|
|**Tech Overlord**|Synthari|Cold Reactor + Efficient Refit|Pip, Quill, Halcyon|Either|Cheapest upgrades, strongest weapons|
|**Merchant Prince**|Terran|Haggler + Quartermaster|Marisol, Gristle, Pip|Neither (rep-focused)|Max trade and contract income|

Race hostility, crew ideology clash, and per-faction rep losses force tradeoffs. A fully optimal "everything" crew is impossible.

\---

## 15\. DATA SCHEMAS

```json
// config.json
{ "starting\_perk\_picks": 2, "crew\_flaw\_strength": 0.5, "perk\_stack\_cap": 2,
  "battle\_mode": "realtime", "faction\_rep\_min": -500, "faction\_rep\_max": 1000 }

// races.json
{ "id": "synthari", "name": "Synthari", "playable": true, "type": "cyborg\_ai",
  "factions": \["synthesis"], "perks": \["G04","G18"], "flaw": "B06",
  "hostile": \["mycelari","noctari"] }
// Sskarn: "playable": false

// perks.json
{ "id": "G01", "name": "Bounty Hunter", "kind": "good",
  "effects": \[{"stat":"bounty\_credits","mult":1.5}] }

// crew.json
{ "id": "C05", "name": "Oren Thornroot", "race": "verdanti", "alignment": "paragon",
  "planet": "brass\_garden", "discovery\_quest": "C05",
  "racial\_perk": "G13", "personal\_perk": "G16", "quirk": "B09" }

// factions.json
{ "id": "terran\_concord", "bloc": "paragon", "rivals\_lore": \["black\_meridian"],
  "bonuses": { "50": "repair\_cost\_-15", "75": "escort\_wing", "100": "heat\_decay\_x2" } }

// quests.json
{ "id": "P03", "name": "Pirate Nest", "type": "paragon",
  "faction\_deltas": { "terran\_concord": 200, "ashscale": -100 },
  "bars": { "paragon": 2, "outlaw": 0 },
  "credits": 4000, "prereqs": {"faction\_rep\_min": {"terran\_concord": 100}}, "next": \[] }
```

\---

## 16\. MILESTONES (build order)

1. **M1 Core loop:** large scrolling map, travel with flight time, ship sprite, 1 sector, 5 planets, market, fuel, save/load.
2. **M2 Character creation:** name, gender, race, starting perk, perk engine (stacking, caps, flaws).
3. **M3 Space combat:** open-space encounters, enemy ships with visible parts, flee/fight/bribe.
4. **M4 Factions + alignment:** per-faction rep bars (−50 to 100%) with explicit quest deltas, 50/75/100% faction bonuses, two independent Paragon/Outlaw bars with milestones.
5. **M5 Quests:** quest manager from JSON; N01–N06 and P01–P05/O01–O05.
6. **M6 Crew:** crew slots by ship tier, recruitment gates (quest, race, alignment), perks applied.
7. **M7 Ships and parts:** four hull tiers, refits, visible parts.
8. **M8 Sectors 2–3:** remaining planets, crew quests C02–C16.
9. **M9 Heat, scans, laundering** (from earlier doc).
10. **M10 Story, endings, conquest layer.**
11. **M11 Polish and balance simulation** (run 10,000 playthrough sim for exploits).

\---

## 17\. DECISIONS \& OPEN QUESTIONS

### Decided

* Combat: **real-time**.
* Starting perks: **2 chosen** (4 good + 1 flaw at start).
* **Sskarn:** NPC-only.
* Paragon and Outlaw: **two independent bars**.
* Quests affect **only the factions listed**; explicit +/- per quest.
* Every faction gives bonuses at **50 / 75 / 100%** rep.

### Still open (ask the user)

1. Art style (pixel, flat vector, realistic)?
2. Monetization and platform scope (mobile only or PC too)?
3. Should the bars ever decrease (e.g., betrayals), or stay permanent? (Default: permanent.)
4. Is the **ideology clash** (−15% loyalty for mixed crews) the right cost for playing both sides?
5. Should faction bonuses at 50/75/100% be lost if rep drops, or kept permanently? (Default: lost.)

