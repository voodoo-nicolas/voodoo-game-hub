# Vellmoor: a non-linear map, missions, side quests, characters and story threads

Written 2026-10-23 at the owner's request ("side quests, more missions, more characters, more stories; make the maps non-linear, several directions to travel"). **Everything here is PROPOSED and nothing is built.** It stays inside the owner's canon (`story_canon_parts_1-2.md`, `story_scenes_1-6.md`, bible) and answers no OPEN question: where an idea touches one, the row says `touches C-n / S-n` (numbers as in `WORLD_LIST.md`) or `needs owner`. Characters are labelled by role, never named. Keep, change or cut anything; the owner's call.

The main story's own people, places and objects are in `WORLD_LIST.md`; ids `PE-`, `PL-`, `OB-` below point there. New ids: `LC-` location, `CH-` character, `SQ-` side quest, `TH-` story thread, `G`/`W` story gate / free-roam window.

## 1. Rules that make it non-linear

1. **A spine with windows.** The main story is 12 gates (G1-G12, section 4) that must happen in order. Between them are four free-roam windows (W1-W4) where the player picks the direction. A gate is the only hard lock.
2. **Every district has at least three exits** and the city has five edges (north hill, west gate, east row, south works, south-east harbor). No corridor that only leads one way back.
3. **Every journey has at least two routes with different costs**: street (fast, full sun), shaded (slow, safe), vehicle (fare, time), roofs and sewers (night, a key or a vampire day). The cost types are time, sun, being seen (Watcher, hunters, church), hazard and unlock.
4. **Clues are a network, not a chain.** Every story thread (section 7) has 6-8 beats and each beat can be found in two or more places, in any order. A thread pays off when 5 of its beats are found. A beat found early changes later dialogue (flags in the dialogue runner already support this).
5. **Soft gates only**: time of day (shops close at 18:00, the bar opens at 18:00, the church at 21:00), the sun (open streets cost Health by day), items (hat, scarf, keys, silver cloth), trust (Friend / Watcher / Hunter / Devotee reactions) and the vampirism day. Nothing is locked "by story" except at a gate.
6. **Time pressure, no fail screen.** The shopkeeper's "2 or 3 more days" and the sun are the pressure; the calming dose (G10) stalls it. Ignoring every side quest never blocks the spine.
7. **The world moves.** People have a day place and a night place; the Watcher and the hunters get closer each day; the arc lights (SQ-19) change a street for good.
8. **Progressive reveal still applies**: a route type (shade, roofs, sewers, carriage) is shown to the player only once the story or a person introduces it.
9. **Distances and the clock must be tuned together.** The clock runs 30 real seconds per game hour. Proposal: Home to Harbor by the main road is about 90 s of walking (3 game hours); the whole Day-1 window W1 (07:00-18:00) is 330 s. Tune in `turned_tuning.json` when the first big map exists.

### Mission types in the Journal (one new tab each, revealed when the first one appears)
**Main** (the spine), **Threads** (the 8 stories of section 7), **Side quests** (SQ, section 5), **Jobs** (short repeatable errands, section 6), **Collections** (pages, posters, shelters).

## 2. The map

Vellmoor is a seaside city. A river (the Vell) comes out of the forest, runs through the city as a canal and reaches the harbor. The two supplied night paintings show the west gate with the forest road and the harbor beyond.

```
                        NORTH: OLD TOWN HILL (D5)
                    cathedral, archive, cloister, cemetery
                                   |
   WEST: FOREST (D8) --- WEST GATE (D7) --- RESIDENTIAL (D3) --- MARKET QUARTER (D1) --- LANTERN ROW (D2)
     old man's house       hunters' lodge      YOUR HOUSE            market square             the bar
                                                  \                      |
                              the canal (Vell) ----\---------------------+-------------- HARBOR QUARTER (D4)
                                                                         |                 Tobacco Row, docks, ship
                                                   RAILWAY and WORKS (D6)
                                          station, gasworks, electric works, cigar company
                                                         |
                                  UNDERCITY (D9): sewers, catacombs, canal tunnel, boiler passage under D1-D6
                                  ROOFTOPS: the bell tower (D5) to the clock tower (D1) to the gasworks (D6)
        rail from D6 to Marrowgate   |   ships from D4 to Saltmere   |   ferry to Dunwick Ferry  (D10, closed until Part 3)
```

### Edges (every pair that touches; the exits per district)
| From | To | Ways |
|---|---|---|
| D3 Residential | D1 Market | street (always); canal towpath |
| D3 | D7 West Gate | street; carriage |
| D3 | D2 Lantern Row | the alley behind the bar (the chase corner) |
| D1 Market | D2 | street |
| D1 | D5 Old Town | the long stair; the colonnades (shade); bell tower roofs |
| D1 | D6 Works | street; tram |
| D1 | D4 Harbor | main road; canal towpath |
| D2 | D4 | back lanes; sewer (key) |
| D4 | D6 | the quay railway; the canal tunnel |
| D5 | D9 | crypt door (night) |
| D7 | D8 Forest | forest road (day); river path; toll bridge |
| D8 | D4 | river path along the Vell to the canal (long, shaded) |
| D6 | D10 | rail to Marrowgate (closed) |
| D4 | D10 | ship to Saltmere, ferry to Dunwick (closed) |

### Routes for the trips the story forces (so there is always a choice)
**Home to the cigar shop (Friday night, with the witness, scene 4):**
| Route | Time | Sun | Seen | Hazard | Opens |
|---|---|---|---|---|---|
| Main road via the Market | medium | night: lamps too bright (senses) | Watcher, crowds | none | always (witness leads) |
| Canal towpath | long | none | cats, a barge man | fog, wet stone | always, the witness objects |
| Old Town colonnades | long | none | church patrol | none | until 21:00 |
| Works and the tram | medium | none | night guards | steam (hides noise) | fare |
| Sewers | short | none | rats | tide, bad air | a key (SQ-21), Day 3+ |
| Roofs | short | none | few | falls | vampire day 4+ |

**Forest to the harbor (Saturday morning, the sun trek, P2.6):**
| Route | Time | Sun | Seen | Notes |
|---|---|---|---|---|
| West gate road | medium | full, awnings and a hat stall | gate guard | the hat theft spot (PE-10) |
| River path along the Vell | long | trees, bridges | charcoal burners, the miller | the scarf can be found here; arrives at the harbor from behind |
| Over the hill to Old Town and down | long | arcades | the church (the Old Man will not go there: unexplained, `touches C-4`) | |
| Wait until dusk | costs a day | none | none | allowed: the harbor scene happens at night instead |

## 3. Districts and locations (LC-01 to LC-44)

`Built` = exists today, `New` = nothing yet. "Hours" are the soft gates.

### D1 Market Quarter (centre)
| Id | Location | Notes | Hours |
|---|---|---|---|
| LC-01 | Market square | the baker's stall, newspaper man, coachman, lamplighter (built people) | 07-18 |
| LC-02 | Clock tower | a roof route to D5 and D6 | open |
| LC-03 | Courier office | the newspaper (SQ-02) | 08-17 |
| LC-04 | Apothecary | salves, garlic wards (a vampire is repelled: bible 8b) | 08-18 |
| LC-05 | Tailor | the street shop front is built; the coat's cut (CH-07) | 08-17 |
| LC-06 | General store | a shop interior in the mockup style | 08-18 |
| LC-07 | Hat stall | where a hat can be taken (PE-10) | 08-17 |

### D2 Lantern Row
| Id | Location | Notes | Hours |
|---|---|---|---|
| LC-08 | The bar (placeholder "The Crooked Lantern") | `PL-07`: exterior and inside | from 18:00 |
| LC-09 | Boarding house | registry book and visitor notes (a clue about Wednesday) | open |
| LC-10 | Pawnbroker | buys silver, knows hunters (SQ-09) | 09-19 |
| LC-11 | Music hall | night life, the Devotee (CH-12) | from 19:00 |
| LC-12 | Barber-surgeon | pays to heal burns | 09-19 |
| LC-13 | Back alley | the chase corner (`PL-08`) | open |

### D3 Residential (your street)
| Id | Location | Notes |
|---|---|---|
| LC-14 | Your house | six rooms, built (`PL-01`..`PL-05`) |
| LC-15 | Your street | built (`PL-06`) |
| LC-16 | Doctor's surgery | CH-01 |
| LC-17 | Neighbours' houses (three) | the widow, the family with the child, the empty house (a shelter) |
| LC-18 | The little garden | trees (built shade) and a bench |

### D4 Harbor Quarter
| Id | Location | Notes |
|---|---|---|
| LC-19 | Tobacco Row: the cigar shop | `PL-10`, `PL-11` |
| LC-20 | Docks | `PL-12` |
| LC-21 | The ship | `PL-13` |
| LC-22 | Fish market | the fishwife (CH-14) |
| LC-23 | Customs house | CH-16 |
| LC-24 | Sailors' mission | church-run hostel: the church is also at the harbor (a possible reason for `C-4`, not decided) |
| LC-25 | Warehouse row | a shelter (loft) and SQ-18 |
| LC-26 | Lighthouse | CH-19, a night shelter |

### D5 Old Town Hill
| Id | Location | Notes |
|---|---|---|
| LC-27 | Cathedral square | `PL-21` |
| LC-28 | Cloister garden | herbs (SQ-22) |
| LC-29 | Archive | records (SQ-23) |
| LC-30 | Cemetery and crypts | the way down to the undercity |
| LC-31 | Bell tower | the way up to the roofs (SQ-24) |

### D6 Railway and Works
| Id | Location | Notes |
|---|---|---|
| LC-32 | Station | rail to Marrowgate (closed until Part 3) |
| LC-33 | Gasworks | the roof route's end, heat and noise |
| LC-34 | Electric works | arc lights (SQ-19) |
| LC-35 | Cigar company office | the logo on the matches (SQ-11) |
| LC-36 | Tenements | many doors, Jobs |

### D7 West Gate
| Id | Location | Notes |
|---|---|---|
| LC-37 | The gate and guard post | `PL-14` |
| LC-38 | Hunters' lodge | silver (TH-07) |
| LC-39 | Wayside stable | the carriage line (SQ-04) |

### D8 Forest
| Id | Location | Notes |
|---|---|---|
| LC-40 | Forest path | `PL-15` |
| LC-41 | The Old Man's house | `PL-16`, `PL-17`, `PL-18` |
| LC-42 | Charcoal burners' camp | SQ-16 |
| LC-43 | River mill | the miller (CH-27) |
| LC-44 | Ruined chapel | a shelter (cellar) |

### D9 Undercity and the roofs
Not separate locations: the sewers, catacombs, canal tunnel and boiler passage connect D1-D6 (night, key, or Day 3+); the roof route runs D5 to D1 to D6. They are the third route on almost every trip.

**Totals: 44 locations in 8 districts + the undercity + the roofs; 2 of those 44 are built (your house and street, counted as LC-14, LC-15).**

## 4. The spine with free-roam windows

| Gate / window | Beat | When | Where | How it is not a corridor |
|---|---|---|---|---|
| G1 | Wake, neck, mirror (built) | Fri 07:00 | PL-01, PL-02 | built |
| G2 | The stranger's coat, pockets, the note (matches, sewn pocket) | Fri morning | PL-01 | pockets in any order |
| **W1** | **Friday day: free roam** | 07:00-18:00 (330 s) | D3, D1, D5, D4 by day; the bar is closed | learn the sun, meet neighbours, the baker knows the matches' logo (the shop's location can be learned here), the doctor, the tailor, the church, the harbor; the cigar shop can be visited early (the owner denies everything, as he does later); `S-n` flags change later lines |
| G3 | The bar: the room is afraid; thrown out; lock and bolt | from 18:00 | LC-08 | enter by the front; the barmaid (CH-10) can be spoken to first in the alley |
| G4 | Followed home; you grab the follower | Fri night | D2 to D3 | three ways round the corner (alley, garden, canal steps); threaten / calm / ask (spec choice) |
| G5 | The witness, his twin note, the ticking coat, the hidden pocket and the watch | Fri night | PL-01 | choice: tell him about the watch or hide it (spec) |
| **W2** | **The crossing to the harbor, with the witness** | Fri night | D3 to D4 | six routes (section 2); senses worsen with lamps and noise; the witness follows and comments |
| G6 | The cigar shop; the water burns; blackout | Fri night | PL-10 | after an early visit the owner says "You again?" |
| G7 | Storeroom: the bite checked, "Have you bitten anyone?", the timer | Fri night | PL-11 | choice: trust him (spec) |
| G8 | The watch burns and breaks; the forest walk; the arm; hunger | Fri night | D4 to D7 to D8 | route to the gate: main road / canal / colonnades; the arm: touch or not (spec) |
| G9 | The Old Man's house: recognition, recipe, sigil, temptation; the shopkeeper leaves | Fri night | PL-16..18 | PE-06 leaves the story (his fate `touches C-6`) |
| **W3** | **Saturday: the sun trek** | Sat morning | D8 to D4 | four routes (section 2); hat and scarf; side quests on the way; the Old Man's directions are the only fixed thing |
| G10 | The harbor, the ship, the wait; the herb list; blackout; the calming dose | Sat | PL-12, PL-13 | arrival hour changes the first line |
| G11 | The watch revealed; the implication | Sat | PL-13 | the harbor man's watch (OB-22) |
| **W4** | **Days 2-3: open Vellmoor** | Sat to Mon | all districts | all threads and side quests; the "2 or 3 days" timer; hunters escalate; shelters; the undercity |
| G12 | End of Part 2 / Part 3 start | | | `touches C-9`: not designed |

## 5. Side quests (SQ-01 to SQ-24)

Each is optional. "Hook" is what the player sees; "Outcomes" are the choices that set flags for the ending (hat theft, resisting blood, who you trust: the canon file's "tie earlier choices to the ending"). `needs owner` = depends on an open decision.

| Id | Name | Giver, where | Hook and steps | Outcomes | Links |
|---|---|---|---|---|---|
| SQ-01 | Lamp Out | Lamplighter (PE-20), D2 | Someone puts out Lantern Row's lamps at dusk. Follow the dark to two hunters darkening an alley around their silver traps | relight them (the lamplighter's favour: a lit route) or use the dark (a night route, but the hunters see you) | TH-07 |
| SQ-02 | Yesterday's Courier | Newspaper man (PE-18), D1 | Six torn pages of the Courier hide in the city: the kiosk, the pawnbroker's wrapping, the barber, the bar, the harbor, the church bin | the town's account of Wednesday night, and of three winters of "fevers"; a collection | TH-01, TH-06; `touches S-7` (the pages' text is the owner's) |
| SQ-03 | The Parasol's Daughter | Woman with the parasol (PE-17), D3 | Her daughter is in bed with a fever and two marks she hides | fetch the doctor / the Old Man's tonic / do nothing | TH-06; `needs owner` (bible 11.3: does anyone else get turned?) |
| SQ-04 | The Night Fare | Coachman (PE-19), D1 | Take a veiled passenger from the market to the station after dark; the passenger is a Knowing figure | learn what they know / be paid / refuse. Unlocks night carriage rides (fast, no sun) | TH-03, Marrowgate |
| SQ-05 | The Grey Coat's Reports | Watcher (PE-15) | Tail the Watcher to a letter drop at the cathedral archive and read it | confront him, feed him a false report, or ignore him: he becomes a Friend or tightens | TH-02, church |
| SQ-06 | Scraps for the Dog | Baker (PE-16), D1/D4 | The dog that barked at you in the night crossing gives your place away | win it over with scraps; it warns you of hunters later (a stealth mechanic) | small |
| SQ-07 | Bad People | the pawnbroker's tip, D2 | A cutpurse gang preys on late walkers in the alley behind the bar | feed on them (the bible's safe, small cost), turn them in, or spare them: sets mercy/predator | bible 9, ending |
| SQ-08 | Rats for Coin | Fishwife (CH-14), D4 | The warehouses are overrun | animal feeding (weak, costs time) paid in coin | bible 9 |
| SQ-09 | Silver for Sale | Pawnbroker (CH-08), D2 | He buys every spoon in the city for someone. Follow it to the lodge and the church. Carrying silver burns you: use a cloth or tongs (a small puzzle) | steal it, ruin the shipment, or leave it | TH-07, OB-05 |
| SQ-10 | The Doctor's Notebook | Doctor (CH-01), D3 | He notices your neck and keeps a book of "fevers with two marks": three cases in forty years | he hides you and sells a salve (less sun damage) or gives you to the hunters if you threaten him | TH-06 |
| SQ-11 | Tobacco Ledgers | Company clerk (CH-21), D6 | The logo on the matches is the company's. Ledgers show a monthly crate to the ship and one to the cathedral | the company is a cover for the society (proposal) | TH-03, TH-05; `touches S-5` |
| SQ-12 | The Clerk's Hat | The hat's owner (PE-10), D1/D4 | The hat you took (P2.6) cost him his job: he turns up again days later | return it, pay him, or ignore him: a Friend or a grudge (he tells the Watcher) | main, ending |
| SQ-13 | Missing Posters | street, five posters | A woman missing since winter; the posters lead to the catacombs | she is found hiding / dead / gone to the society (the answer is the owner's) | TH-06; `needs owner` |
| SQ-14 | The Old Man's Pages | Old Man (PE-07) | Eight pages of his notes are scattered: the house (2), the ruined chapel, the church archive (2 copies), the ship, the shopkeeper's pocket, a gravestone | each carries the initials or "the first batch"; the full set unlocks a memory scene | TH-02, TH-04; the pages' text is the owner's (`C-4`, `C-5`) |
| SQ-15 | Lamp Oil and Bread | Old Man, D8 | He needs supplies from the city | his trust rises (a calmer recipe) | TH-02 |
| SQ-16 | The Burners' Fever | Charcoal burner (CH-25), D8 | The camp's boy is sick; they blame the forest | cure him with the Old Man's herbs: allies and a hiding place in the forest | TH-02 |
| SQ-17 | The Captain's Letters | Harbor man (PE-08), after the dose | Deliver three sealed letters (archive, works, ferryman) to society members | each member protects, watches or recruits you (`needs owner` C-7) | TH-03 |
| SQ-18 | Night Shift | Dock foreman (CH-15), D4 | Move crates before the customs men look | money; reveals what is smuggled (silver ore, herbs) | harbor |
| SQ-19 | The Electric Light | Engineer (CH-20), D6 | Arc lights are going up on the main road: a night with no dark corners | help (a safe road for the city, a bare one for you) or sabotage (dark routes stay); the arc light only reveals, it does no damage (to avoid inventing a rule) | TH-08 |
| SQ-20 | The Bolt on the Door | Barmaid (CH-10), D2 | She saw Wednesday and is afraid | a half-answer, never the whole truth | TH-01; `touches S-7` |
| SQ-21 | A Place to Sleep | nobody, anywhere | Find six day shelters: your house, the shop storeroom, the empty neighbour house, the warehouse loft, the lighthouse, the ruined chapel cellar | each is a save point and a fast-travel stop; each has a risk (hunters, a key, a person) | survival |
| SQ-22 | The Cloister Garden | Lay brother (CH-23), D5 | The garden grows the herbs the weaker remedy lacks (not the list that went to the harbor) | he gives them if you bring the Old Man's word; he tells the church's side of the exile | TH-02; `touches C-7` |
| SQ-23 | Family Records | Archive clerk (CH-24), D5 | Search baptisms and marriages | a missing relative decades back; **the answer is left blank on purpose** | TH-04; `needs owner` (C-2, C-11) |
| SQ-24 | The Bell That Rings Twice | Bell ringer (CH-26), D5 | Ring the bell at the right hour to scatter a hunter patrol | opens the roofs early | TH-07 |

## 6. Jobs (short, repeatable errands; money and small items)
Carry a parcel by the delivery map (J-1); find the lost cat (J-2); fetch lamp oil (J-3); hold a stall while the owner steps away (J-4); wake the lamp keeper (J-5); take a note to the doctor (J-6); count the crates (J-7); return a lost glove to a tenement door (J-8). Eight templates, generated from the people and places above.

## 7. Characters (CH-01 to CH-30) and the Knowing

Roles from the bible (section 5): **Friend** (warns, hides, half-truths), **Watcher** (observes and reports), **Hunter** (silver and lamps), **Devotee** (wants to serve or be turned: feeding on them costs most), **Unaware** (only sees pale skin and a scarf). Their reactions change as the turning worsens: sympathy, then fear, hatred or reverence. The built villagers (PE-15..PE-20) and the main story's people are in `WORLD_LIST.md`.

| Id | Label | District | Role | What they give | Hours |
|---|---|---|---|---|---|
| CH-01 | Doctor | D3 | Friend / informer | SQ-10, a salve | day |
| CH-02 | Widow next door | D3 | Friend | leaves a cloak and a warning on day 2 (bible 8) | day |
| CH-03 | Child who sees you at night | D3 | Unaware | keeps a secret; later a messenger | night |
| CH-04 | Boarding-house caretaker | D2 | Unaware | the registry book: who rented a room Wednesday | open |
| CH-05 | Apothecary | D1 | Friend | salves, garlic wards (vampires are sickened: bible 8b) | day |
| CH-06 | Street boy with posters | D1 | Unaware | SQ-13, sells rumours | day |
| CH-07 | Tailor | D1 | Friend | recognizes the coat's old cut (a proposed clue: older than it looks) | day |
| CH-08 | Pawnbroker | D2 | Hunter's supplier | SQ-09 | day |
| CH-09 | Courier editor | D1 | Unaware | SQ-02 | day |
| CH-10 | Barmaid | D2 | Unaware, afraid | SQ-20 | evening |
| CH-11 | Barmaid's friend at the bar door | D2 | Watcher | reports who enters | evening |
| CH-12 | Music-hall singer | D2 | Devotee | wants to be turned (heavy story cost) | night |
| CH-13 | Barber-surgeon | D2 | Unaware | heals burns for coin | day |
| CH-14 | Fishwife | D4 | Unaware | SQ-08, stares at your clothes | day |
| CH-15 | Dock foreman | D4 | Unaware | SQ-18 | day, night shift |
| CH-16 | Customs officer | D4 | Hunter ally or bribable | silver at the quay | day |
| CH-17 | Ferryman | D4 | Society | letter recipient (SQ-17); the way to Dunwick (closed) | day |
| CH-18 | Mission matron | D4 | Watcher (church) | reports to the cathedral | day |
| CH-19 | Lighthouse keeper | D4 | Friend | a night shelter | night |
| CH-20 | Electric engineer | D6 | Unaware | SQ-19 | day |
| CH-21 | Cigar company clerk | D6 | Society | SQ-11 | day |
| CH-22 | Stationmaster | D6 | Unaware | trains to Marrowgate (closed) | day |
| CH-23 | Lay brother (gardener) | D5 | Friend | SQ-22 | day |
| CH-24 | Archive clerk | D5 | Society, Friend | SQ-23 | to 21:00 |
| CH-25 | Charcoal burner (elder) | D8 | Friend | SQ-16 | day |
| CH-26 | Bell ringer | D5 | Unaware | SQ-24 | day |
| CH-27 | Miller | D8 | Unaware | the river path, a hiding place | day |
| CH-28 | Gate sergeant | D7 | Unaware | checks pale faces in full sun | day |
| CH-29 | Young hunter | D7 | Hunter (reluctant) | can be turned into an ally | day |
| CH-30 | Hunter leader and the church's Examiner | D7, D5 | Hunter | the pursuer (TH-07); follows your trail to the Old Man | escalates |

## 8. Story threads (TH-01 to TH-08)

Each thread has a canon anchor and a payoff that stops where the owner's OPEN answers begin. Beats are found in two or more places in any order; five found pays off the thread.

| Id | Thread | Anchor | Beats (where) | Payoff, and what stays open |
|---|---|---|---|---|
| TH-01 | **Wednesday** | S1-S5, S-6, S-7 | the twin note (PE-04), the boarding-house registry (CH-04), the barmaid (CH-10), the Courier pages (SQ-02), the three memory fragments (a sound, a smell, half a face), the bar's lock | most of Wednesday night; who the two people were, who bit you and who wrote the note stay open (S-6, S-10, S-11) |
| TH-02 | **The Exile** | C (church exiled him), C-4 | his notes (SQ-14), the burners' story (SQ-16), the lay brother (SQ-22), the Examiner, the mission matron, the Old Man's refusal to go near the harbor | why he left the church and why he fears the city; whether he would do it again is the owner's (C-4) |
| TH-03 | **The Society** | C (sigil, initials, harbor man) | the sigil (OB-20), the cigar company ledgers (SQ-11), the captain's letters (SQ-17), the ferryman, the archive clerk, the watch (OB-22) | the society is alive and quiet; what it wants of you is the owner's (C-7) |
| TH-04 | **The Bloodline** | C (you are A's blood relative) | the portrait in your parlour (OB-26), the archive (SQ-23), the study's missing book, B's reaction to your scent, a family letter | scaffold only: the player is never told; the owner's answers C-1, C-2, C-11 write this |
| TH-05 | **Smoke** | S-5 | the matches' logo, the shopkeeper's silence, the company office, his storeroom's old boxes | why a cigar merchant knows about the turned (`touches S-5`); his fate (C-6) |
| TH-06 | **The Last Unfinished** | bible 6.A (Knowing A + Mystery A) | missing posters (SQ-13), the doctor's notebook (SQ-10), the sexton's grave, the daughter (SQ-03), the Courier pages | what happened to the last unfinished turning: this decides what "cure" costs; `needs owner` (bible 11.3) |
| TH-07 | **The Hunters** | bible 5 (Hunter) | silver at the pawnbroker (SQ-09), the lodge, Lamp Out (SQ-01), the bell (SQ-24), the Examiner | a pursuit that tightens each day; ends in an ally or a hunt |
| TH-08 | **The Light** | bible 2 (early electric lights, "new and scary") | the engineer (SQ-19), the arc lamps on the main road, the gasworks | Vellmoor modernizes; dark routes close or stay |

## 9. Build order (each phase: propose a task list and wait for the owner's OK)

| Phase | Builds | Needs from the art pack |
|---|---|---|
| C1 | Lantern Row, the bar, the chase corner, spine G3-G5 | PL-07, PL-08, PE-02, PE-03, PE-04 |
| C2 | The night crossing (W2, three routes) and the cigar shop, G6-G7 | PL-09, PL-10, PL-11, PE-06 |
| C3 | The west gate, the forest, the Old Man's house, G8-G9 | PL-14..PL-18, PE-07 |
| C4 | The sun trek (W3) and the harbor, the ship, G10-G11 | PL-19, PL-20, PL-12, PL-13, PE-08, PE-09, PE-10 |
| C5 | W1 and W4: Market and Residential open, the first eight side quests, Jobs, Journal tabs | LC-01..LC-07, CH-01..CH-09 |
| C6 | Old Town, the Works, the undercity and roofs, shelters (SQ-21) | LC-27..LC-36 |

## 10. Decisions needed from the owner

1. **Format** (see `ART_DIRECTION_V2.md`): the new look is painted scenes with tappable hotspots. Does it replace the top-down walking, sit beside it, or only change the look of the walking game?
2. Does the **clock** run indoors, and how long should a crossing take (rule 9)?
3. **Hat theft**: a forced act or a choice (the canon says "a small moral choice or a forced action")?
4. Which **side quests and characters** to keep. Cut freely: everything here is a proposal.
5. **Other people turned** (bible 11.3) decides SQ-03, SQ-13 and TH-06.
6. **The herb list** (P2.2): the owner writes it; the herbs the weaker remedy lacks (SQ-22) depend on `C-7`.
7. Bar name, the Courier's name, district and street names: all placeholders until the owner picks.
