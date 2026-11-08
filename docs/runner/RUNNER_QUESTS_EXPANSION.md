# THE RUNNER — Quest Expansion (v2.2)

> Companion to `GAME_DESIGN_THE_RUNNER_V2.md`. **Same rules, same format.** IDs continue from V2 (N07+, P15+, O15+, F07+). Convert to `quests.json`.
> Count: V2 had 56 quests (incl. 16 crew discovery). **This file adds 88 more → 144 total.**

## RULES (recap from V2)
- **Faction changes** are explicit FP (100 FP = 10%) and affect **only** the factions listed. No hidden rival penalties.
- **Bars:** `PP` fills the Paragon bar, `OP` the Outlaw bar. Independent. Bars never drop.
- **(d)** = dirty credits (must be laundered). Others = clean.
- **Credit scale by sector:** S1 800–4,000 · S2 3,000–10,000 · S3 6,000–20,000 · S4 25,000–100,000. Master Negotiator etc. multiply.
- **Unlock column** uses: quest IDs, faction rep % (e.g., *Concord ≥25%*), bar points (e.g., *PP ≥10*), or sector.
- **Abbreviations:** Concord = Terran Concord · Synthesis = The Synthesis · Aerie = High Aerie · Verdant = Verdant Canopy · Deepcourt = Thalassi Deepcourt · Sunscale = Sunscale Covenant · Meridian = Black Meridian · Bloom = The Bloom · Veilbound · Ashscale = Ashscale Warbands · Guilds = Sskarn Hunt-Guilds.
- **Branch** = player chooses; each branch lists its own deltas.

---

## 1. MAIN STORY SPINE (M05–M15)
*M01–M04 are N01–N04 in V2 (Act I). Act I ends at N12.*

| ID | Quest | Summary | Unlock | Faction changes | Bars | Credits |
|---|---|---|---|---|---|---|
| M05 | **Through the Veil** | Cross the first Gate into Sector 2. Run the blockade, bribe the officers, or use a forged pass. | N11 | **Run:** Concord −100, Meridian +50 · **Bribe:** Concord −25 · **Forged pass:** Veilbound +100 | Run: OP +1 · Others: none | 2,000 |
| M06 | **Blind Node I: Voidglass Vault** | Explore a derelict vault. Find the first Blind Node. Ghost Core gains +10% stealth. | M05 | none | none | 8,000 |
| M07 | **Pick a Patron** | Four factions each offer a lead. Choose one to open its main chain. | M06 | **Chosen faction +150** | none | 5,000 |
| M08 | **Safehouse** | Build your first hideout; reduces heat decay time. | M07 | none | none | −4,000 (cost) |
| M09 | **Blind Node II: Ember Archive** | Take the vault three ways. | M08, Sector 3 | **Heist:** Veilbound +100, Concord −100 · **Negotiate:** Sunscale +100 · **Buy (−20,000):** none | Heist: OP +2 · Negotiate: PP +2 · Buy: none | 12,000 |
| M10 | **Vask's Gambit** | Queen Vask steals the Ghost Core. Chase across the Drift; fight her flagship (boss 1). | M09 | **Defeat:** Ashscale −200 · **Bargain:** Ashscale +200, Sunscale −100 | Defeat: PP +2 · Bargain: OP +2 | 15,000 |
| M11 | **Blind Node III: Oath Vault** | Pass the Hunt-Guilds' three trials to reach the final node. | M10 | Guilds +150 | none | 10,000 |
| M12 | **The Keeper Revealed** | Meet Marrow. Learn the Ledger's secret. Pick a side. | M11 | **Stand with Accord:** Concord +100 · **Stand with Pact:** Meridian +100 · **Stay quiet:** none | PP +3 / OP +3 / none | 0 |
| M13a | **Muster of Light** | Rally the Accord fleet. | M12, PP ≥50, ≥3 Accord factions ≥50% | Each of 3 chosen Accord factions +100 | PP +3 | 20,000 |
| M13b | **Black Muster** | Rally the Pact armada. | M12, OP ≥50, ≥3 Pact factions ≥50% | Each of 3 chosen Pact factions +100 | OP +3 | 20,000 (d) |
| M13c | **Quiet Muster** | Gather the Hunt-Guilds and ghost-runners. | M12, Guilds ≥50%, all 3 Blind Nodes | Guilds +150 | none | 20,000 |
| M14 | **Into the Hollow** | Fly the gauntlet through the Hollow Deep: drones, traps, sealed gates. | M13a/b/c | none | none | 40,000 |
| M15 | **AUDITOR** | Final confrontation. Marshal Vane. Endgame choice. | M14 | Per ending | Per ending | 100,000 |

---

## 2. NEUTRAL / STORY-INTRO (N07–N12)

| ID | Quest | Summary | Unlock | Faction changes | Bars | Credits |
|---|---|---|---|---|---|---|
| N07 | **Vending Mystery II: Wrong Shipment** | VEND-O-MATIC sells you crates that turn out to be real contraband. Deliver or dump. | N05 | none | none | 600 + random item |
| N08 | **Vending Mystery III: Machine Uprising** | Hacked vending drones swarm Cradle Station. Fight them in open space. | N07, N09 | none | none | 1,500 + cosmetic |
| N09 | **First Blood** | Combat tutorial against a lone pirate raider. | N03 | none | none | 800 |
| N10 | **Marrow's Cache** | Find the stash Marrow hid in Scrapyard Gamma. Rare part plus a clue. | N04 | none | none | 1,200 + rare part |
| N11 | **Rift Key** | Get your first Rift Key. **Buy it (8,000 cr)** · **steal from a Concord depot** · **do a Concord courier job**. | N10 | **Steal:** Concord −100 · **Courier:** Concord +100 | Steal: OP +1 · Courier: PP +1 · Buy: none | 0 (key) |
| N12 | **Debt Day** | Final payment to Mother Kessel. **Pay in full (5,000 cr)** or **burn her ledger**. | N02, N11 | **Pay:** Meridian +100 · **Burn:** Meridian −150 (Kessel becomes a nemesis) | Pay: none · Burn: OP +1 | −5,000 or 0 |

---

## 3. PARAGON QUESTS (P15–P28)

| ID | Quest | Summary | Unlock | Faction changes | PP | Credits |
|---|---|---|---|---|---|---|
| P15 | **Customs Audit** | Audit a corrupt port, expose the official taking bribes. | Concord ≥25% | Concord +150, Meridian −75 | +1 | 3,500 |
| P16 | **Emergency Powers** | A martial-law decree is up for vote. **Support it** or **oppose it**. | P15, Concord ≥50% | **Support:** Concord +200, Deepcourt −100 · **Oppose:** Concord −150, Deepcourt +100 | Support: 0 · Oppose: +2 | 6,000 |
| P17 | **Wind Courier** | Deliver sealed letters across four Aerie nests before storm fronts hit. | Aerie ≥25% | Aerie +150 | +1 | 2,800 |
| P18 | **Reforest the Wastes** | Plant seed-pods on a dead moon and defend them from Bloom spore raiders. | Verdant ≥25% | Verdant +200, Bloom −100 | +2 | 5,000 |
| P19 | **Reef Reclamation** | Clean spore pollution from Abyssal Reef with a decontamination run. | Deepcourt ≥25% | Deepcourt +200, Bloom −100 | +2 | 5,500 |
| P20 | **Second Light** | Defend a Sunscale pilgrim convoy from an Ashscale ambush. | P07, Sunscale ≥50% | Sunscale +200, Ashscale −150 | +2 | 6,000 |
| P21 | **Open Source** | Free a captive Synthari mind from a crime lord's server farm. | Synthesis ≥25% | Synthesis +200, Meridian −100 | +2 | 5,000 |
| P22 | **Plague Ship** | A quarantined ship needs medics. Ferry them and accept the risk. | PP ≥10 | One Paragon faction of your choice +150 | +2 | 6,500 |
| P23 | **Hospital Convoy** | Escort a convoy of medical ships through a pirate-infested lane. | Any Paragon faction ≥25% | Concord +100, Aerie +100 | +1 | 3,500 |
| P24 | **Orbital Evacuation** | A station is collapsing. Save as many civilians as possible before breakup. | Sector 2 | Deepcourt +100, Concord +100 | +2 | 4,500 |
| P25 | **Peace Summit Escort** | Guard delegates through hostile space to a Concord–Sunscale summit. | Concord ≥50%, Sunscale ≥25% | Concord +150, Sunscale +150, Ashscale −75 | +2 | 8,000 |
| P26 | **Spy Hunt** | Find the Meridian informant inside Concord ranks. | Concord ≥50% | Concord +200, Meridian −150 | +1 | 7,000 |
| P27 | **Lighthouse Duty** | Restock a remote lighthouse keeper. Quiet reward: a safe dock with no heat. | PP ≥3 | none | +1 | 1,500 + safe dock |
| P28 | **Sunrise Fleet** *(capstone)* | Rally a defensive fleet against an Ashscale invasion. | PP ≥50, ≥3 Accord factions ≥50% | All 6 Accord +100 each, Ashscale −250 | +3 | 30,000 |

---

## 4. OUTLAW QUESTS (O15–O28)

| ID | Quest | Summary | Unlock | Faction changes | OP | Credits (d) |
|---|---|---|---|---|---|---|
| O15 | **Debt Collector's List** | Collect on five debtors. Spare them or squeeze them. | Meridian ≥25% | Meridian +150 | +1 | 3,500 |
| O16 | **Rigged Auction** | Rig a high-society auction for a Veilbound client. | Veilbound ≥25% | Veilbound +150, Concord −50 | +1 | 5,000 |
| O17 | **Rot Harvest** | Carry spore crates through patrol zones. | Bloom ≥25% | Bloom +200, Synthesis −100 | +2 | 6,000 |
| O18 | **Name Auction** | Sell a Concord officer's secret identity to the highest bidder. | Veilbound ≥50% | Veilbound +200, Concord −200 | +2 | 8,000 |
| O19 | **Blackmail Package** | Assemble leverage against a Deepcourt envoy. | Meridian ≥50% | Meridian +200, Deepcourt −150 | +2 | 9,000 |
| O20 | **Warband Initiation** | Survive an Ashscale raid trial to earn a banner. | Ashscale ≥25% | Ashscale +200, Sunscale −100 | +2 | 6,000 |
| O21 | **Hostage Convoy** | Capture a convoy and hold VIPs only for ransom. | Ashscale ≥50% | Ashscale +200, Aerie −150 | +3 | 12,000 |
| O22 | **Smuggler's Gauntlet** | Run five patrol zones back-to-back with a loaded hidden hold. | OP ≥10 | Meridian +100, Concord −100 | +2 | 10,000 |
| O23 | **Black Box Heist** | Steal a flagship's black-box recorder for a buyer. | Veilbound ≥50% | Veilbound +150, Concord −150 | +2 | 9,000 |
| O24 | **False Flag** | Stage an Ashscale-style raid on a Verdant grove to pin it on them. | Meridian ≥50% | Meridian +150, Ashscale −150, Verdant −150 | +3 | 14,000 |
| O25 | **Station Takeover** | Seize a small station and make it a Tributary. | OP ≥30, Ashscale ≥50% | Ashscale +150, owner faction −200 | +3 | 15,000 |
| O26 | **Counterfeit Credits** | Run a press of fake clean credits. | Veilbound ≥25% | Veilbound +100, Concord −100 | +1 | 4,000 |
| O27 | **The Gilded Heist** | Crack the Gilded Rock's vault with Rook inside. | C15 | Veilbound +150, Meridian +100 | +2 | 18,000 |
| O28 | **Eclipse Armada** *(capstone)* | Assemble a pirate armada and strike a Concord outpost. | OP ≥50, ≥3 Pact factions ≥50% | All 4 Pact +100 each, Concord −250, Sunscale −100 | +3 | 40,000 |

---

## 5. FACTION-ONLY FAVORS (F07–F12, rep only, no bars)

| ID | Quest | Summary | Unlock | Faction changes | Credits |
|---|---|---|---|---|---|
| F07 | **Neutral Ground** | Mediate a dispute at the Gilded Rock. Pick the two sides involved. | Sector 3 | Two chosen factions +75 each, Guilds +50 | 2,500 |
| F08 | **Double Contract** | Take two Guild contracts on the same target. Complete one, drop one. | Guilds ≥25% | Guilds +100, dropped client −100 | 4,000 |
| F09 | **Old Rivals** | Carry a peace note between Sunscale and Ashscale. | Sector 2, Sunscale ≥10% | Sunscale +100, Ashscale +100 | 3,500 |
| F10 | **Tribute to the Deepcourt** | Deliver a ceremonial cargo of pearls. | Deepcourt ≥10% | Deepcourt +150 | 1,000 |
| F11 | **Message in the Spore** | Carry a ceasefire offer from the Bloom to the Synthesis. | Bloom ≥10% | Bloom +100, Synthesis +100 | 3,000 |
| F12 | **Clean Slate** | Pay a Concord fine to reset heat. | Concord ≤ −10% | Concord +100 | −5,000 |

---

## 6. CREW LOYALTY QUESTS (CL01–CL16)

**Rules:** Unlocks after the crew member has been aboard for 3 completed quests. Completing it **upgrades their personal perk to Rank II (+50% effect)** and **reduces their quirk to 25% strength**. Loyalty +25 permanent.

| ID | Crew | Quest | Summary | Faction changes | Bars | Credits |
|---|---|---|---|---|---|---|
| CL01 | Pip | **Black Box Memories** | Pip's recovered memory shows him on Marrow's crew; find Marrow's next waypoint. | none | none | 1,500 |
| CL02 | Marisol | **Torn Insignia** | A Concord tribunal wants her for desertion. **Testify** or **forge the record**. | **Testify:** Concord +100 · **Forge:** Veilbound +100, Concord −50 | Testify: PP +1 · Forge: OP +1 | 3,500 |
| CL03 | Imre | **Back-Alley Lab** | A clinic is experimenting on prisoners. **Shut it down** or **steal the research**. | **Shut:** Concord +100 · **Steal:** Meridian +100 | Shut: PP +1 · Steal: OP +1 | 4,000 |
| CL04 | Tavi | **Wingmates** | Free her flockmates from an Ashscale cage-ship. | Aerie +150, Ashscale −100 | PP +2 | 4,500 |
| CL05 | Oren | **Root Memory** | His elder is dying. Carry a seed-pod to Brass Garden before it wilts. | Verdant +150 | PP +1 | 3,500 |
| CL06 | Nerida | **Lost Reef Charts** | Recover her mentor's charts from a sunken ship under pirate guard. | Deepcourt +100 | PP +1 | 4,000 |
| CL07 | Ravik | **Brother's Blade** | His brother serves Ashscale. **Duel him**, **spare him**, or **bring him to trial**. | **Duel:** Ashscale −100 · **Spare:** Ashscale −50, Sunscale +100 · **Trial:** Sunscale +150 | Duel: OP +1 · Spare/Trial: PP +2 | 5,000 |
| CL08 | Halcyon | **Node Split** | Halcyon's mind fragments. **Back up a copy** or **let the Synthesis reclaim him**. | **Backup:** Synthesis −100 · **Reclaim:** Synthesis +100 (Halcyon leaves for 1 sector) | Backup: none · Reclaim: PP +1 | 4,500 |
| CL09 | Sable | **Burned Name** | Her real identity is on sale. **Buy it back**, **silence the broker**, or **burn the file**. | **Buy:** Veilbound +50 · **Silence:** Veilbound −150 · **Burn:** Veilbound +100 | Silence: OP +2 · Others: OP +1 | 6,000 (d) |
| CL10 | Vorga | **Chain of Command** | Her old captain demands her return. **Fight** or **buy her freedom**. | **Fight:** Ashscale −100 · **Buy:** Ashscale +50 | Fight: OP +1 · Buy: none | 5,000 (d) |
| CL11 | Dax | **Squadron Ghosts** | Confront the officer who abandoned Dax's squadron. | Concord −150 | OP +1 | 5,500 (d) |
| CL12 | Yveth | **Hive Seed** | Plant a seed of her hive on an unclaimed world; defend it. | Bloom +150 | OP +1 | 5,000 (d) |
| CL13 | Quill | **Hive Debt II** | The Synthari enforcer returns. **Hack him**, **bribe him**, or **fight him**. | **Hack:** Synthesis −50 · **Bribe:** none · **Fight:** Synthesis −150 | Hack/Fight: OP +1 | 5,000 (d) |
| CL14 | Brann | **Last Debt** | Settle Brann's debt to Mother Kessel; **pay it** or **betray her**. | **Pay:** Meridian +200 · **Betray:** Meridian −200 | Pay: none · Betray: OP +2 | 6,000 (d) |
| CL15 | Rook | **Stolen Medal** | The medal belongs to a dead Aerie hero. **Return it** or **sell it**. | **Return:** Aerie +150 · **Sell:** Aerie −100 | Return: PP +1 · Sell: OP +1 | 4,000 |
| CL16 | Gristle | **Both Sides** | A Guild trial: take a contract against an Accord target or a Pact target. | Guilds +150, target faction −100 | none | 8,000 |

---

## 7. LOCATION QUESTS (T01–T12)
*Unique, flavor-heavy, tied to specific planets. Mostly one-off.*

| ID | Planet | Quest | Summary | Unlock | Faction changes | Bars | Credits |
|---|---|---|---|---|---|---|---|
| T01 | Scrapyard Gamma | **Ship of Theseus** | Rebuild a derelict from ten salvaged parts for a hermit. | Sector 1 | none | none | 2,000 + a free ship hull |
| T02 | The Gilded Rock | **House Edge** | Win a high-stakes game against a cheating house. | Sector 3 | Veilbound +75 | none | 7,000 |
| T03 | Wreck of the Starlight | **Ghost Ball** | A haunted ballroom is a broken AI sitting on a stash. | Sector 3 | none | none | 6,500 |
| T04 | Drift Market | **Auction Night** | Win a mystery lot against rivals (it's stolen). | Veilbound ≥10% | Veilbound +100 | OP +1 | 9,000 (d) |
| T05 | Sunken Orbital | **Vault Below** | After Pressure, dive for a flooded vault. | C03 | Deepcourt +50 | none | 8,000 |
| T06 | Chorus Nebula | **Echo Hunt** | Track the nebula's "voice" to its source. | C06 | Deepcourt +100 | none | 6,000 |
| T07 | Null Point | **Radio Silence** | Find a lost mining crew in a dead zone. | Sector 3 | none | PP +1 | 7,500 |
| T08 | Brass Garden | **Harvest Festival** | Win the festival's cargo race for a prize. | C05 | Verdant +100 | none | 3,000 |
| T09 | Port Vermillion | **Arena Night** | Fight in a pirate ship arena for tribute. | C10 | Ashscale +75 | OP +1 | 6,500 (d) |
| T10 | Hollow Gate Alpha | **Echoes of the Gate** | Solve an Architect puzzle for a rare element. | Sector 4 | none | none | 30,000 |
| T11 | Architect Ruins | **Dormant Machine** | Wake or put back to sleep an ancient machine. | Sector 4 | none | **Wake:** OP +1 · **Sleep:** PP +1 | 35,000 |
| T12 | Bloomfall | **Spore Tide Survey** | Map the hive's spore-tide cycle safely. | Bloom ≥10% | Bloom +100 | none | 6,000 |

---

## 8. SPECIES QUESTS (S01–S09)
*Open to everyone. If your race (or a crew member's) matches, a bonus option or reward appears.*

| ID | Race | Quest | Summary | Race bonus | Faction changes | Bars | Credits |
|---|---|---|---|---|---|---|---|
| S01 | Terran | **Family Business** | Resolve a feud inside a small trading dynasty. | Terran: unlock a secret deal (+15% reward) | Concord +100 or Meridian +100 (choose) | PP +1 or OP +1 | 4,000 |
| S02 | Synthari | **Mirror Mind** | A copy of yourself in a Synthari mind offers you a deal. | Synthari: skip the trap, get a free upgrade | Synthesis +100 | none | 6,000 |
| S03 | Kestrai | **Nest Feud** | Two nests fight over a ridge. Mediate or pick a side. | Kestrai: both nests like you | Aerie +150 | PP +1 | 4,500 |
| S04 | Sskarn | **Rite of the First Hunt** | Join a Guild hunt of a space beast. | Sskarn crew: bonus loot | Guilds +150 | none | 7,000 |
| S05 | Mycelari | **Spore Census** | Count and map hive growth across a sector. | Mycelari: unlock a hidden hive | Bloom +100 | OP +1 | 5,500 |
| S06 | Verdanti | **Winter Sleep** | Protect dormant elders during a decade-long sleep. | Verdanti: extra rare seed | Verdant +150 | PP +1 | 5,500 |
| S07 | Thalassi | **Tide Debt** | Chart a deadly trench to repay a drowned debt. | Thalassi: full map of the trench | Deepcourt +150 | PP +1 | 6,000 |
| S08 | Ssaryn | **Blood Vow** | Two clan cousins want a marriage truce. Back or break it. | Ssaryn: tie-breaking vote | **Back:** Sunscale +100, Ashscale +50 · **Break:** Ashscale +100, Sunscale −100 | Back: PP +1 · Break: OP +1 | 6,000 |
| S09 | Noctari | **The Name Trade** | Buy or sell a stranger's identity. | Noctari: free forged ID | Veilbound +100 | OP +1 | 6,500 (d) |

---

## 9. QUEST COUNT SUMMARY

| Category | V2 | This file | Total |
|---|---|---|---|
| Main story (M) | 0 listed | 11 | 11 (+4 as N01–N04) |
| Neutral (N) | 6 | 6 | 12 |
| Paragon (P) | 14 | 14 | 28 |
| Outlaw (O) | 14 | 14 | 28 |
| Faction favors (F) | 6 | 6 | 12 |
| Crew discovery (C) | 16 | 0 | 16 |
| Crew loyalty (CL) | 0 | 16 | 16 |
| Location (T) | 0 | 12 | 12 |
| Species (S) | 0 | 9 | 9 |
| **Total** | **56** | **88** | **144** |

---

## 10. IMPLEMENTATION NOTES (Claude Code)

- Add to `quests.json`: `unlock`, `branches` (array of `{id, faction_deltas, bars, credits, flags}`), `dirty_credits` (bool), `repeatable` (bool), `perk_rank_up` (crew id) for CL quests.
- **Unlock parser** supports: quest ID, `faction_rep >= N`, `bar >= N`, `sector == N`, `race == X`, combinations with `AND`/`OR`.
- **Capstones (P28, O28)** require 3 factions ≥50%; check at accept time and at mission start.
- **Race bonus** in S quests: check player race **or** any crew race.
- **Perk Rank II:** multiply that perk's numeric effects by 1.5; clamp to the stack cap.
- **Quirk reduction:** after the crew's CL quest, set quirk strength to 0.25.
- **Branching rewards** must be computed at resolution, not at accept time.
- **Playtest hooks:** log every `faction_deltas` event to catch unreachable 50/75/100% bonuses.
