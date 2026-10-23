> Owner's handoff `turned-game-spec.md` (D:\Dev\RPG\Turned\), saved 2026-10-23 as **story only**. Its tech proposal (sections 5-7: new Godot project, dialogue runner, tap-to-explore) is NOT followed: the hub game already exists as a real-time top-down game (`docs/claude/turned.md`). How the scenes map onto it, and the conflicts, are in `DECISIONS.md` (section "Owner's scenes 1-6"). Text below is the owner's, only the markdown export escapes were removed.

# TURNED: Game Handoff for Claude Code

Status: story drafted through Scene 6. No code yet.
Legend: **[DECIDED]** = the author said it. **[PROPOSED]** = suggestion, change freely. **[OPEN]** = needs an author answer.

---

## 1\. Concept

Narrative mystery game, played in second person. The player wakes up bitten (two marks on the neck), with a memory gap and a coat that isn't theirs. They are slowly turning into a vampire and have a few days to find out what happened and how to stop it.

* Genre: narrative / adventure with light inventory and dialogue. **[DECIDED]**
* Tone: dark, tense, small-town, gaslit-era feel (oil lamps, harbor, taverns, a forest chapel/house). **[DECIDED]**
* Platform: mobile (Google Play), single player. **[PROPOSED]** (matches the author's other games)
* Languages: story was drafted in English and Spanish. Build with localization from day one (es + en). **[PROPOSED]**

---

## 2\. World rules established so far **[DECIDED]**

|Rule|Where it shows up|
|-|-|
|Player is thirsty all the time; water does NOT help and hurts (coughing, blackout)|Scene 5|
|Light, sound and smell are painfully strong|Scenes 4, 6|
|Player smells blood and gets a sudden hunger; it fades when the blood is covered with dirt|Scene 6|
|The silver pocket watch burns the player's hand but is harmless to others|Scene 6|
|The watch ticks constantly; only the player seems to hear it (**[OPEN]**)|Scenes 4, 5, 6|
|The watch broke when dropped and the ticking stopped|Scene 6|
|Timer: the shopkeeper says the player has "2 or 3 more days" before they become dangerous|Scene 5|
|Bite marks are hidden by the collar; the player doesn't yet know what they are|Scenes 1, 4|

---

## 3\. Story so far (scene scripts)

### Scene 1: Waking up

Beats: wake achy; rub face; hand slides to neck, find two small holes; hobble to bathroom; mirror shows the bites; try to remember last night, can't; check pockets; go back to the room; find the coat is a stranger's, not yours.
Design notes: the bites are found twice (touch, then mirror). The mirror should add new info (bruising, blood on the pillow, etc.). **[PROPOSED]** Recall attempt should return fragments (a sound, a smell, half a face) instead of just "I can't remember". **[PROPOSED]**

### Scene 2: The coat and the bar

* Coat is heavy wool, smells of smoke and rain.
* Left pocket: empty. Right pocket: box of matches (the box has the cigar company's logo, see Scene 4).
* Inside pocket, sewn shut with crude stitches. Tear it open. Note inside.
* Note text: *"Meet me at The Crooked Lantern. Wednesday. 10 PM. Come alone."* **[OPEN: 9 or 10 PM; bar name is a placeholder]**
* Wall calendar shows Friday. Two days lost.
* Coat fits too well (hint at the turning).
* Go to the bar. Tavernkeep shouts "YOU! You've got nerve coming back after Wednesday night! We don't need more trouble." The whole room is afraid of the player, not angry.

### Scene 3: Thrown out and followed

* Tavernkeep: "Go home." Player pleads for info. Door slams, lock, bolt.
* Player walks away. Someone steps out of the bar, sees the player, runs.
* Player walks home. Footsteps match theirs: slow when they slow, stop when they stop.
* Player ducks around a corner, grabs the follower: "Why are you following me?!"
* Follower stares at the player's neck and coat: "...It's really you."

### Scene 4: The witness and the pocket watch

The follower is a witness from Wednesday.

* Wednesday: he arrived late, saw the player talking with a couple of people outside. Tavernkeep told him "We're closed, anyone inside can finish and go, tonight is over", then slammed the door.
* Thursday: nothing. Friday: nothing, drinks. Then the player shows up, and gets thrown out.
* Player says they remember nothing, found the coat and the note.
* Witness reads the note, goes pale, drops it, and takes out **the same note** from his own pocket. Same day, same time.
* Matches: player left them at home. Both go to the player's house.
* Upstairs, the coat is **ticking**. Player finds a hidden pocket and a **silver pocket watch**. It feels wrong, warm, humming. Player hides it from the witness (**[DECIDED]** player does not mention it yet).
* Witness recognizes the matches: a cigar company, shop is across town by the harbor.
* Cross the city: gas lamps too bright, dog barking, sharp smells, extreme thirst, constant ticking.
* Arrive at the cigar shop.

### Scene 5: The cigar shop (drafted in Spanish)

* Witness asks the owner if he knows the player, about the matches, anything strange lately. Owner denies everything, "¿Algo más o ya se van?"
* Player looks pale, says: *"Tengo mucha sed. Estoy mareado, débil."* Witness gets him a seat and asks for water.
* Owner hesitates: *"¿Agua? ¿Seguro?"* Gives it anyway, and watches.
* Player drinks greedily, then it **burns**, coughing, blackout.
* Wakes in the shop's back storeroom (tobacco drying). The witness is gone. Only the owner is there.
* Owner: *"¿Hace cuánto te lo hicieron?"* Player touches the neck: two holes. Owner opens the collar and checks: *"¿Cuatro días? ¿Cinco?"* Player: *"Dos, creo."*
* Owner asks: *"¿Mordiste a alguien ya?"* Player doesn't understand. Owner realizes the player has no idea what is happening.
* Owner knows an old ex-priest with old books who may know. Timer: *"Quizás te quedan dos o tres días. Y cuando eso pase, no quiero estar cerca tuyo."*

### Scene 6: The watch and the forest (drafted in Spanish)

* Player shows the watch. It **burns** the hand. Drops it, it breaks, ticking stops. Palm is red and swollen.
* Owner picks it up with a bare hand: *"No está caliente."* Concludes the player can't touch it. He keeps it.
* Night walk to the priest's house. Owner explains: the priest left the church after disagreeing with something it did. Lives alone, reads, researches.
* Player's senses are overwhelmed. Anxious, energetic, confused.
* Leave the city. Dark forest path. Owner leads with an oil lamp.
* A branch scrapes the owner's arm. Player **smells blood**; sudden hunger. Owner hides it and cleans it fast. Player asks to see it. Owner refuses and backs away. Owner covers it with torn cloth and rubs dirt on it. Smell and hunger fade.
* From here, owner walks behind the player, hiding his arm.
* They reach a small house covered in vines, with a dim light in the window. They enter.

---

## 4\. Continuity flags **[OPEN]**

1. **Time of meeting:** 9 PM vs 10 PM.
2. **Timeline:** Scene 5 says 2 days (Wed to Fri). The original dictation also said "10 days". Currently using **2 days**.
3. **Witness and owner have no names yet.** Never use the name "Elias" or variants (author's request).
4. **Bar name** is a placeholder.
5. **Cigar owner:** why does he know so much? Needs a reason (family, past). Also why he denied knowing about the matches at first.
6. **"A couple other people"** the player talked with Wednesday: who are they?
7. **Why did the tavernkeep close the bar for the player?**
8. **Witness disappears** in Scene 5. Needs an explanation.
9. **Pocket watch:** now broken and held by the owner. What does it do?
10. **Who owns the coat and who wrote the note?** Two people got the same note.
11. **Who bit the player?**

---

## 5\. Technical proposal **[PROPOSED]**

Engine: author's other mobile games use **Godot**. Recommend Godot 4 for consistency unless Claude Code suggests otherwise.

### Architecture

* **Scene/state machine:** each story scene is a data file, not hardcoded.
* **Dialogue runner:** lines, speaker, choices, conditions, effects.
* **Inventory + flags:** coat, note, matches, watch (hand-held, broken, owned by owner).
* **Player stats:** `thirst`, `hunger`, `days_left` (timer), `senses_overload`.
* **Localization:** all text keys go in CSV/JSON for es/en.

### Data shape (example)

```json
{
  "id": "scene_02_coat",
  "background": "bedroom_night",
  "nodes": [
    { "type": "text", "key": "s02_coat_smell" },
    { "type": "interact", "target": "coat_right_pocket", "gives": "matches" },
    { "type": "interact", "target": "coat_inner_pocket", "requires": "tear_stitches", "gives": "note" },
    { "type": "goto", "scene": "scene_02b_bar" }
  ]
}
```

### Interaction model

Hybrid: short tap-to-explore moments (pockets, mirror, drawers) plus dialogue scenes. The current script is linear; add choices at these points: **[PROPOSED]**

* Scene 3: how to confront the follower (threaten / calm / ask).
* Scene 4: whether to tell the witness about the watch.
* Scene 5: whether to trust the owner.
* Scene 6: whether to touch the witness's bleeding arm.

---

## 6\. MVP scope (build in this order)

1. Project setup, scene loader, text/dialogue runner, localization keys.
2. Scene 1 (wake-up exploration: neck, bathroom, mirror, pockets, coat).
3. Scene 2 (pockets, note, bar front, tavernkeep, calendar).
4. Scenes 3–4 (chase and dialogue; watch discovery).
5. Scene 5 (water burn, blackout, shop dialogue).
6. Scene 6 (watch burns, forest, bleeding arm hunger moment).
7. Placeholder scene 7: priest's house (not written yet).

Art: simple placeholders first. Don't spend time on final art until the story is locked.

---

## 7\. First prompt to give Claude Code

> Read `turned-game-spec.md`. Set up a Godot 4 project for a mobile narrative game called "Turned". Build the data-driven scene loader and dialogue runner first, with es/en localization keys. Then implement Scenes 1–2 as playable using placeholder art. Don't invent story content; use the text in the spec and mark any missing text as TODO. Ask me about anything marked [OPEN] before you hardcode it.

---

## 8\. Next story scene (not written yet)

Scene 7: the priest's house. Options: he checks the player's neck first; he recognizes the broken watch; the hunger returns inside the house and the owner must decide what to do.

