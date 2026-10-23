# Turned: the main story's people, places and objects (what must exist)

Made 2026-10-23 from `story_canon_parts_1-2.md` (the owner's plot canon) and `story_scenes_1-6.md` (scenes 1-6), checked against what is in the game now (`docs/claude/turned.md`). Side content is in `WORLD_MAP_AND_QUESTS.md`; the pictures to make are in `ART_PROMPTS_V2.md` (same ids).

**Rules kept.** Characters are labelled by role, never named (the owner never wants "Elias" or variants). Nothing here answers an OPEN question: where the story needs one, the row says `OPEN n` (canon file numbering `C-n`, scene-script flags `S-n`) and the thing is listed as a slot to fill. `Built` = exists in the game today; `Ph` = a placeholder exists (drawn in code or invented text); `New` = nothing yet.

Source tags: `S1`-`S6` = scene 1-6 of the scene script, `P2.1`-`P2.12` = Part 2 beat, `C` = canon (chain of events, organization, clue plan), `B` = story bible.

## 1. People (20)

| Id | Label | Who / what they do | Where, when | Source | Open questions | Status | Art |
|---|---|---|---|---|---|---|---|
| PE-01 | **You** (player) | Unnamed ("you"). Wakes Friday with two bite marks. Weakens day by day; sun, thirst, senses | everywhere | S1-S6, C | gender and name (bible 3, DECIDE); the mockups show a young man | Ph | sheet: day, coat, hat+scarf, burned skin, pale/thirsty; bust with 4 moods; mirror variants (dim reflection) |
| PE-02 | **Tavernkeep** | Afraid, not angry: "You've got nerve coming back after Wednesday night." Throws you out, locks and bolts the door | bar, Fri evening | S2, S3 | S-7 why he closed the bar for you | New | sprite, bust (afraid, hard) |
| PE-03 | **Bar patrons** | The whole room goes silent and afraid of you | bar interior | S2 | none | New | 4-6 sprites, one crowd painting |
| PE-04 | **Witness** | Follows you from the bar; arrived late Wednesday, saw you outside with "a couple of people"; holds the same note; goes to your house, then to the shop; vanishes in scene 5 | Fri night | S3, S4, S5 | S-3 name (never Elias), S-8 why he disappears | New | sprite, bust (scared, pale, hard) |
| PE-05 | **The two people from Wednesday** | Talking with you outside the bar before the blank. Never shown whole: the recall attempt returns "a sound, a smell, half a face" | memory fragments | S4, S1 note | S-6 who they are (one may be PE-19) | New | 3 fragment pictures (half a face in lamplight, hand with a ring, a silhouette) |
| PE-06 | **Shopkeeper** (cigar shop owner) | Denies everything, then checks your neck, asks "Have you bitten anyone yet?", gives the timer (2-3 days), takes the watch, leads you through the forest, is scratched, hides his arm, leaves after P2 beat 4 | harbor shop, forest, old man's house | S5, S6, P2.1-P2.4 | S-5 why he knows so much; C-6 his fate after he leaves | New | sprite (3 outfits: shop, travel, arm wrapped), bust (guarded, kind, afraid) |
| PE-07 | **Old Man** (ex-priest) | Exiled by the church; lives alone in the forest; recognizes the change; holds the ORIGINAL recipe; flinches at the sigil; cannot go to the harbor and will not say why | forest house, Fri night, Sat morning | S6, P2.1-P2.5, C | C-4 what he was to B, his stance; C-5 B's consent; C-8 is he a vampire himself | New | sprite, bust (weary, sharp, ashamed), hands with notes |
| PE-08 | **Harbor Man** (captain) | Living member of the organization; owns the same watch; the vanished member's initials mean something to him; gives the calming dose (weaker remedy) | ship at the harbor, Sat | P2.7-P2.12, C | C-7 what he wants (protection, observation, recruitment); why he needs the old man's list | New | sprite, bust, captain's coat variants |
| PE-09 | **Harbor locals** | Stare at your clothes, let you sit in the captain's quarters, offer water | docks, ship | P2.7 | none | New | 6 sprites: docker, sailor, fishwife, customs officer, boy with a cart, net mender |
| PE-10 | **Hat owner** | Owns the unattended hat you steal in the sun section; a moral choice sets the tone | street on the way to the harbor | P2.6 | what happens to them (consequence is a side quest, `SQ-12`) | New | sprite (clerk, no hat), bust |
| PE-11 | **Vamp A** | The original vampire; made B; you are A's blood relative | not yet | C | C-1 where A is; C-2 how you are related; C-11 who in your family | New | not drawn yet: a faded portrait slot in the house (the built `portrait` look) |
| PE-12 | **Vamp B** (Coat Owner) | Owned the coat and watch; turned you; a weaker vampire; no original recipe; the ending's cure/immortality choice is embodied in B | offstage until a later part | C | C-3 why B wants A's blood; C-5; S-10 who wrote the note; S-11 who bit you | New | silhouette and hands only for now; full design waits for the owner |
| PE-13 | **The church's people** | The looming threat: a priest in the street, the officials who exiled the Old Man | city, church square | C (tone), C-4 | who they are is unwritten | New | 2 sprites (priest, church guard), bust (priest) |
| PE-14 | **The organization** | A secret society (sigil, initials); thought dead by the Old Man; only PE-08 is alive on screen | harbor | C | how many members | New | the sigil as a drawing (see OB-20) |
| PE-15 | **Watcher** (grey coat) | Built villager who stares and says "You should not be out in that sun." Stays a placeholder: not the Witness | street | B 5, built | decision 46: separate from PE-04 | Built (Ph) | sprite exists in code; paint |
| PE-16 | **Baker** (vendor) | Built; friendly with the scarf on, worried without | street | built | none | Built (Ph) | sprite, bust |
| PE-17 | **Woman with the parasol** | Built, walks | street | built | none | Built (Ph) | sprite |
| PE-18 | **Man with the newspaper** | Built, walks | street | built | none | Built (Ph) | sprite |
| PE-19 | **Coachman** | Built, stands by the carriage | street | built | none | Built (Ph) | sprite |
| PE-20 | **Lamplighter** | Built, with a pole | street | built | none | Built (Ph) | sprite |

Not listed on purpose: the bible's **Friend / Hunter / Devotee** roles and the later acts' people (Marrowgate, Saltmere, Dunwick Ferry). They are in `WORLD_MAP_AND_QUESTS.md` as proposals.

## 2. Places (24)

Everything is in **Vellmoor** (city, harbor, forest: decision 46). Timeline: Friday = Day 1 from 07:00; the bar, witness, shop and forest walk fill Friday; the old man's house is Friday night; the sun trek and the harbor are Saturday (Day 2).

| Id | Place | What happens there | Source | Status | Paintings needed (portrait scenes unless said) |
|---|---|---|---|---|---|
| PL-01 | **Your bedroom** | Wake, neck, pockets, the coat on the chair, the wall calendar (Friday), later the ticking coat and the hidden watch pocket (night) | S1, S2, S4 | Built | day, night (2) |
| PL-02 | **Bathroom** | The mirror (new info: bruising, blood on the pillow, dim reflection), the bloodstained towel | S1 | Built | 1 |
| PL-03 | **Upstairs landing, study and library** | Built; hints (the globe turned to Marrowgate, the missing book) are placeholders | built | Built (Ph) | 1 (study) |
| PL-04 | **Ground floor: parlour, kitchen, entrance hall** | The front door (stays shut until mirror + coat), the scarf, the locked cellar door; the portrait (clue plan: a family resemblance) | built | Built (Ph) | 1 hall, 1 parlour, 1 kitchen |
| PL-05 | **Cellar** | Locked; a hook for a later key | built, decision 38 | Built (door only) | 0 now |
| PL-06 | **Your street** (day and night) | Neighbours, the sun/shade mechanic, lamps; the walk home with footsteps behind you | S3 | Built | day, night (2) |
| PL-07 | **The bar** (placeholder name "The Crooked Lantern") | Front: door, lock and bolt. Inside: the note's meeting place, the afraid room | S2, S3 | New | exterior night, interior (2) |
| PL-08 | **The corner and alley** (the chase) | You duck around a corner and grab the follower | S3 | Ph | 1 |
| PL-09 | **The city at night** (crossing to the harbor) | Gas lamps too bright, a dog barks, smells, extreme thirst, constant ticking | S4 | New | 2 (lamp street, tram stop or bridge) |
| PL-10 | **Cigar shop, front** | Witness asks the owner about you and the matches; "¿Algo más o ya se van?"; the water that burns | S5 | New | 1 |
| PL-11 | **Cigar shop, storeroom** (tobacco drying) | You wake; the owner checks the bite; the timer | S5 | New | 1 |
| PL-12 | **The harbor / docks** | Locals stare; the ship; the wait | P2.7 | New | 2 (docks by day, docks by night) |
| PL-13 | **The ship and the captain's quarters** | You sit, thirst grows, the harbor man arrives, you black out, wake with the calming dose | P2.7-P2.11 | New | deck 1, quarters 1 |
| PL-14 | **City gate** | You leave the city by night; the gate in the moonlit images | S6 | New | 1 (the supplied gate paintings are the reference) |
| PL-15 | **Forest path** (night) | The lamp, the branch, the arm, the dirt | S6 | New | 1 |
| PL-16 | **Old Man's house, outside** (vines, one dim window) | Arrival | S6 | New | 1 |
| PL-17 | **Old Man's house, main room** | Recognition, the recipe, the watch, the shopkeeper told to leave | P2.1-P2.4 | New | 1 |
| PL-18 | **Old Man's study** (notes, herb shelves, books) | The initials on his notes, "the first batch" line | C clue plan | New | 1 |
| PL-19 | **Forest road, morning** (sun trek start) | Sun tolerable, then unbearable | P2.6 | New | 1 |
| PL-20 | **Streets of the sun trek** (market edge, colonnade, clothes line) | Shade-hopping; the hat; the scarf | P2.6 | New | 2 |
| PL-21 | **The church** (outside, a square) | Looming; why the Old Man will not enter the city's streets near it | C (tone) | New | 1 exterior |
| PL-22 | **Vellmoor, seen from outside** (world map picture) | Establishing view: city, gate, forest road, harbor | supplied gate pictures | New | the two supplied pictures, repainted clean |
| PL-23 | **Memory fragment scenes** | A sound, a smell, half a face (the recall attempts) | S1 note | New | 3 small paintings |
| PL-24 | **The unknown** (blackout dream or new place at the end of Part 2; B's lair; where A is; the ending's room) | Not designed: needs C-1, C-9 | C | Do not make | none yet |

## 3. Objects (28)

Items you carry (`Inv`), things you look at or use (`Use`), close-up cards (`Card`: the macro painting shown when you examine it, like the "Coat Pocket" card in the mockups).

| Id | Object | Kind | What it does / where | Source | Status | Art |
|---|---|---|---|---|---|---|
| OB-01 | **Stranger's coat** | Inv | Heavy wool, smells of smoke and rain; fits too well (a hint); left pocket empty, right pocket the matches, inner pocket sewn shut; a hidden pocket at night holds the watch | S1, S2, S4 | Ph | prop (on the chair), worn variant, Card |
| OB-02 | **Box of matches** | Inv | Cigar company logo; you left them at home; leads to the shop | S2, S4 | Built (item) | Card |
| OB-03 | **The note** | Inv | "Meet me at The Crooked Lantern. Wednesday. 10 PM. Come alone." (S-1 9 or 10 PM; bar name is a placeholder) | S2 | Built (item) | Card |
| OB-04 | **The witness's note** | Use | The same note, same day and time, from his pocket | S4 | New | Card |
| OB-05 | **Pocket watch** (silver) | Inv | Ticks constantly (only you hear it); warm and humming; burns your hand; sigil and initials engraved; you drop it, it breaks, the ticking stops; the shopkeeper keeps it | S4, S6, C | Built (item) | Card (closed, open with sigil and initials, broken) |
| OB-06 | **Wall calendar** | Use | Shows Friday: two days are lost | S2 | New | prop |
| OB-07 | **Mirror** | Use | Neck close-up; adds bruising and blood on the pillow; the reflection is dim and wrong while the turning is unfinished (proposal, bible 8b) | S1 | Ph | Card (neck, built landing art), mirror variants |
| OB-08 | **Blood on the pillow and bloodstained towel** | Use | A clue; built (the towel) | S1 | Built (towel) | prop |
| OB-09 | **Tavern door: lock and bolt** | Use | Slammed, locked, bolted | S3 | New | prop |
| OB-10 | **Water glass / jug** | Use | You drink greedily, then it burns; coughing; blackout | S5 | New | prop, Card |
| OB-11 | **Cigar boxes and logo** | Use | The same logo as on the matches | S4, S5 | New | prop, Card (logo) |
| OB-12 | **Tobacco leaves drying** | Use | The storeroom you wake in | S5 | New | prop |
| OB-13 | **Oil lamp** | Use | The shopkeeper leads the forest walk with it | S6 | New | prop (lit, sprite) |
| OB-14 | **Torn cloth and dirt** | Use | He wraps the cut arm and rubs dirt on the blood: the smell and hunger fade | S6 | New | Card (the arm) |
| OB-15 | **Old Man's house door and window** | Use | Vines, a dim light | S6 | New | prop |
| OB-16 | **Old books and the Old Man's notes** | Use | The same initials; "the first batch"; the original recipe | C clue plan | New | props, 3 Cards (a page, the recipe, the initials) |
| OB-17 | **Herb list** | Inv | "A specific list of herbs from the harbor"; you hand it to the harbor man. The list itself is not written (owner) | P2.2, P2.8 | New | Card (placeholder text: TODO) |
| OB-18 | **Unattended hat** | Inv | Stolen to keep walking in the sun; gear that lowers sun damage | P2.6 | New | prop, icon |
| OB-19 | **Scarf for the face** | Inv | Found along the way; wrapped around the face; the built scarf (neck) is a different use | P2.6 | Built (neck scarf) | icon, worn variant |
| OB-20 | **The sigil** (organization mark) | Use | On the watch; the Old Man flinches; the harbor man knows it | C | New | drawing (one clean vector-like emblem), Card |
| OB-21 | **Initials** (B's) | Use | Engraved on the watch; on the Old Man's notes; the harbor man's attention sharpens | C | New | in OB-05 and OB-16 |
| OB-22 | **The harbor man's watch** | Use | The same watch; you notice it on waking | P2.9 | New | Card |
| OB-23 | **Calming dose** | Inv | The weaker remedy that finally calms the thirst; strength returns slowly | P2.10 | New | icon, Card (vial) |
| OB-24 | **Captain's desk, harbor map, ship's log** | Use | Where you wait; set dressing and a clue place | P2.7 | New | props |
| OB-25 | **Ship** | Use | The place; exterior seen from the dock | P2.7 | New | prop (in PL-12 painting) |
| OB-26 | **Family portrait** | Use | A family resemblance (clue plan); built as a line in the parlour | C | Built (line) | Card |
| OB-27 | **Bite marks** (neck) | Use | Two small holes; touched, then seen in the mirror | S1 | Built | the same Card as OB-07 (the Landing art), nothing new |
| OB-28 | **Cellar key** | Inv | Not in canon: the hook for the locked cellar (decision 38). Listed so the lock has an answer later | built hook | New | icon |

## 4. Counts, so they can be checked

- **People: 20** = PE-01..PE-20. 6 built villagers (PE-15..PE-20), 7 principals who need a full sheet and busts (PE-01 You, PE-02 Tavernkeep, PE-04 Witness, PE-06 Shopkeeper, PE-07 Old Man, PE-08 Harbor Man, PE-13 the priest), 2 crowds (PE-03, PE-09), 1 minor (PE-10), 2 slots that stay unseen or silhouettes (PE-11 A, PE-12 B), 1 fragment set (PE-05), 1 emblem (PE-14).
- **Places: 24** = PL-01..PL-24. 6 built (PL-01..PL-06), 1 placeholder (PL-08), 16 new (PL-07, PL-09..PL-23), 1 not to be made yet (PL-24).
- **Objects: 28** = OB-01..OB-28. 7 built or partly built (OB-02, 03, 05, 08, 19, 26, 27), 2 placeholders (OB-01, 07), 19 new.
- **Paintings (the "Paintings needed" column, summed): 34** = bedroom 2, bathroom 1, study 1, hall 1, parlour 1, kitchen 1, street 2, bar 2, alley 1, city night 2, cigar shop 2, harbor 2, ship 2, gate 1, forest path 1, old man's house 3, forest road 1, sun-trek streets 2, church 1, world pictures 2, memory fragments 3.
- **Cards (macro paintings): 19** (OB-05 has 3 states and OB-16 has 3 pages; the neck card, OB-07 = OB-27, exists already as the Landing art, so 18 are new).

## 5. What is not here
Parts 3 onward (the end of the blackout, B's reveal, A, the cure-or-immortality choice room, the other towns), because they depend on the OPEN answers. Do not design them before the owner answers C-1, C-3, C-9 and C-10.
