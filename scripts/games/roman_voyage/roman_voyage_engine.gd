extends RefCounted

## Voyage of Aeneas -- pure logic (no Nodes), headless-testable.
## The fleet sails from fallen Troy to the mouth of the Tiber: 13 story stops
## from Virgil's Aeneid (public domain, 1st century BC) with a sea event on
## every leg between them. Each stop offers choices; a choice changes ships,
## crew, food, the gods' favor and Juno's wrath. Juno's wrath raises the odds
## and the damage of storms. Reach the Tiber with any ship left to win.
##
## Choice dict: "text", "fx" {ships, crew, food, favor, wrath}, "res" (result text),
## optional "chance" (0..1) + "fail" fx + "res_fail", "need" {"favor": n},
## "flag" (set on pick), "if"/"unless" (flag that shows / hides the choice),
## "storm": true (damage from wrath, see _storm_loss()).
## Every text is English and goes through tr() in the game.

const DIFFS := [
	{"name": "Easy", "ships": 10, "crew": 140, "food": 30, "eat": 2, "mult": 1.0, "wrath": 0},
	{"name": "Normal", "ships": 7, "crew": 110, "food": 20, "eat": 3, "mult": 1.5, "wrath": 2},
	{"name": "Hard", "ships": 5, "crew": 85, "food": 16, "eat": 4, "mult": 2.0, "wrath": 4},
]
const CREW_PER_SHIP := 20
const MAX_FAVOR := 10
const MAX_WRATH := 10

## Story stops, in the order of the Aeneid (books 1-7). "god" names the emblem drawn.
const STOPS := [
	{"id": "thrace", "place": "Thrace", "god": "mars",
		"text": "You land in Thrace to found a new city. As you cut myrtle for an altar, the roots bleed, and a voice from the ground: it is Polydorus, Priam's murdered son. \"Flee this cruel land!\"",
		"fact": "Polydorus, youngest son of King Priam of Troy, had been sent to Thrace with gold for safety; its king murdered him for it (Aeneid, book 3).",
		"choices": [
			{"text": "Give Polydorus a proper funeral, then leave", "fx": {"favor": 2, "food": -2}, "res": "The rites are done. The gods approve of your piety."},
			{"text": "Ignore the omen and keep building", "fx": {"wrath": 2, "crew": -15}, "res": "Sickness and quarrels break out. At last you sail, fewer than before."},
		]},
	{"id": "delos", "place": "Delos", "god": "apollo",
		"text": "On the sacred island of Delos, the temple of Apollo shakes and a voice answers: \"Seek out your ancient mother.\"",
		"fact": "Apollo kept his Greek name in Rome, one of the few gods who did. His oracle meant Italy, home of Dardanus, founder of Troy's royal line.",
		"choices": [
			{"text": "Sacrifice a bull to Apollo", "fx": {"favor": 2, "food": -3}, "res": "Apollo is honoured. The sea ahead looks kinder."},
			{"text": "Thank the god and sail on", "fx": {}, "res": "You leave with the riddle and your stores intact."},
		]},
	{"id": "crete", "place": "Crete", "god": "penates",
		"text": "Your father Anchises thinks the \"ancient mother\" is Crete. You build walls there, but a plague strikes men and fields alike.",
		"fact": "In a dream, the Penates, Troy's household gods carried by Aeneas, told him the real goal was Italy. Romans kept Penates in every home.",
		"choices": [
			{"text": "Leave Crete at once", "fx": {"food": -3}, "res": "You load what you can and put to sea before the plague spreads."},
			{"text": "Stay one more season to harvest", "fx": {"food": 8}, "chance": 0.5, "fail": {"food": 2, "crew": -25}, "res": "The harvest holds and no one falls sick. Lucky.", "res_fail": "The plague takes many before you sail."},
		]},
	{"id": "strophades", "place": "Strophades Islands", "god": "harpy",
		"text": "You feast on cattle you found grazing, but Harpies, bird-women with filthy claws, swoop down on your tables.",
		"fact": "Celaeno, queen of the Harpies, cursed the Trojans: they would not found their city until hunger made them eat their own tables.",
		"choices": [
			{"text": "Draw swords and fight them", "fx": {"food": -2, "crew": -5}, "chance": 0.6, "fail": {"food": -6, "crew": -5, "wrath": 1}, "res": "Your swords drive them off, though their feathers turn the blades.", "res_fail": "Steel cannot hurt them. Celaeno curses you as they ruin the feast."},
			{"text": "Abandon the feast and row away", "fx": {"food": -4}, "res": "You lose the meat but no men."},
		]},
	{"id": "buthrotum", "place": "Buthrotum", "god": "apollo",
		"text": "In Buthrotum you find Helenus, Priam's son and a seer, ruling a little copy of Troy with Andromache.",
		"fact": "Helenus warned Aeneas to sail round Sicily rather than through the straits of Scylla and Charybdis, to honour Juno above all, and to visit the Sibyl of Cumae.",
		"choices": [
			{"text": "Ask Helenus for a prophecy", "fx": {"favor": 1}, "flag": "warned", "res": "Helenus warns you of the straits ahead and tells you to win Juno over."},
			{"text": "Accept his gifts of food and men", "fx": {"food": 8, "crew": 15}, "res": "Your ships leave heavier with grain, and new oarsmen join you."},
			{"text": "Offer at Juno's altar, as he urges", "fx": {"wrath": -2, "food": -3}, "res": "Juno's anger cools, a little."},
		]},
	{"id": "straits", "place": "Straits of Messina", "god": "neptune",
		"text": "Between Italy and Sicily lie Scylla, a six-headed monster in her cave, and Charybdis, a whirlpool that swallows the sea three times a day.",
		"fact": "Scylla and Charybdis were placed on either side of the Strait of Messina; \"between Scylla and Charybdis\" still means choosing between two dangers.",
		"choices": [
			{"text": "Take the long way round Sicily, as Helenus said", "if": "warned", "fx": {"food": -4}, "res": "A long, dull, safe voyage. Helenus was right."},
			{"text": "Hug Scylla's cliff", "fx": {"crew": -12}, "res": "Six heads snatch six men at a time from the decks."},
			{"text": "Risk the whirlpool's edge", "fx": {}, "chance": 0.5, "fail": {"ships": -2}, "res": "You slip past while Charybdis sleeps.", "res_fail": "The whirlpool spins two ships down into the deep."},
			{"text": "Pray to Neptune for safe passage", "need": {"favor": 3}, "fx": {"favor": -3}, "res": "The sea lies flat and you pass between the monsters untouched."},
		]},
	{"id": "cyclops", "place": "Mount Etna", "god": "cyclops",
		"text": "Under smoking Etna a ragged Greek begs for rescue: Achaemenides, left behind by Ulysses. The blinded Cyclops Polyphemus and his brothers are coming down the hill.",
		"fact": "Ulysses is the Latin name of Odysseus. Romans placed the Cyclopes' forge under Mount Etna, where they made Jupiter's thunderbolts.",
		"choices": [
			{"text": "Take the Greek aboard and row hard", "fx": {"crew": 1, "favor": 1}, "res": "Mercy to an enemy: the gods notice. You escape with one more oarsman."},
			{"text": "Stop to load sheep and water first", "fx": {"food": 8}, "chance": 0.5, "fail": {"food": 8, "ships": -1}, "res": "Loaded and away before the giants reach the shore.", "res_fail": "A hurled boulder smashes one ship as you pull away."},
		]},
	{"id": "drepanum", "place": "Drepanum, Sicily", "god": "lar",
		"text": "In the harbour of Drepanum your old father Anchises, who carried the gods out of Troy, dies in your arms.",
		"fact": "Aeneas carried Anchises on his back out of burning Troy; Romans called Aeneas \"pius\" for this devotion to family and gods.",
		"choices": [
			{"text": "Bury him with full honours", "fx": {"favor": 2, "food": -3}, "res": "You raise a tomb. Piety is Rome's first virtue."},
			{"text": "A quick burial; time is short", "fx": {"food": -1}, "res": "You sail on, heavy-hearted."},
		]},
	{"id": "storm", "place": "Sea off Sicily", "god": "juno", "storm": true,
		"text": "Juno sees you almost in Italy. She bribes Aeolus, king of the winds, to let every wind loose on your fleet at once.",
		"fact": "Juno, queen of the gods (Hera to the Greeks), hated Troy and loved Carthage. In the Aeneid it is Neptune who calms her storm.",
		"choices": [
			{"text": "Pray to Neptune to calm the sea", "need": {"favor": 3}, "fx": {"favor": -3}, "res": "Neptune rises, angry that anyone stirs his sea without leave, and smooths the waves."},
			{"text": "Ride out the storm", "storm": true, "fx": {}, "res": "The storm passes. You count the ships that are left."},
		]},
	{"id": "carthage", "place": "Carthage", "god": "venus",
		"text": "Wrecked on Africa's shore, you are welcomed by Dido, queen of Carthage. Your mother Venus makes her fall in love with you. Stay, and be king?",
		"fact": "Jupiter sent Mercury, the messenger god, to remind Aeneas of his duty. Virgil made Dido's curse the mythical root of the wars between Rome and Carthage.",
		"choices": [
			{"text": "Obey Mercury and sail for Italy", "fx": {"favor": 2, "wrath": 1, "food": 6}, "res": "You leave at night. Dido's pyre burns behind you, and Juno's hate burns hotter."},
			{"text": "Stay with Dido for a while", "fx": {"food": 12, "crew": 20, "favor": -3}, "res": "Months of feasting. Jupiter is displeased; at last you go anyway."},
		]},
	{"id": "games", "place": "Eryx, Sicily", "god": "iris",
		"text": "While you hold funeral games for Anchises, Iris, sent by Juno and disguised as an old woman, urges the weary Trojan women to burn the ships.",
		"fact": "Iris, goddess of the rainbow, was Juno's messenger. Jupiter answered Aeneas' prayer with a downpour; four ships were lost.",
		"choices": [
			{"text": "Pray to Jupiter for rain", "need": {"favor": 2}, "fx": {"favor": -2, "ships": -1}, "res": "Jupiter sends a cloudburst. Only one ship is lost."},
			{"text": "Fight the fire yourselves", "fx": {"ships": -2, "crew": -5}, "res": "You save most of the fleet, but two ships burn to the waterline."},
			{"text": "Leave the weary behind to found a town", "fx": {"crew": -25, "food": 6, "wrath": -1}, "res": "The tired and old stay in Sicily and found Acesta. The rest sail lighter."},
		]},
	{"id": "cumae", "place": "Cumae", "god": "sibyl",
		"text": "At Cumae the Sibyl, Apollo's priestess, will guide you to the Underworld to see your father, if you find the golden bough for Proserpina.",
		"fact": "In the Underworld, Anchises showed Aeneas the souls of future Romans, from Romulus to Augustus. Proserpina is the Roman Persephone.",
		"choices": [
			{"text": "Seek the golden bough and go below", "fx": {"favor": 3, "food": -3}, "flag": "underworld", "res": "Two doves of Venus lead you to the bough. Below, your father shows you Rome's future."},
			{"text": "Make an offering and press on", "fx": {"favor": 1, "food": -1}, "res": "The Sibyl's leaves scatter in the wind. You sail north."},
		]},
	{"id": "tiber", "place": "Mouth of the Tiber", "god": "jupiter", "final": true,
		"text": "Hungry, your men eat even the flat bread they used as plates. \"We are eating our tables!\" Celaeno's curse is fulfilled: this is the land. You have reached Latium.",
		"fact": "Aeneas married Lavinia, daughter of King Latinus. His son Ascanius founded Alba Longa, and their line led to Romulus and Remus, founders of Rome.",
		"choices": [
			{"text": "Found your city", "fx": {}, "res": "The voyage is over. Rome's story begins."},
		]},
]

## Sea events: one random one on every leg between two story stops.
const SEA := [
	{"id": "calm", "god": "neptune", "text": "Calm seas and a fair wind. The men cast nets over the side.",
		"choices": [
			{"text": "Fish all day", "fx": {"food": 3}, "res": "A good catch."},
			{"text": "Row hard while the weather holds", "fx": {"food": -1, "wrath": -1}, "res": "You make great distance; Juno loses track of you for a while."},
		]},
	{"id": "dolphins", "god": "neptune", "text": "Dolphins race your prows: a good sign from Neptune, god of the sea.",
		"fact": "Neptune is the Roman Poseidon. Romans held his festival, the Neptunalia, on 23 July, in the heat of summer.",
		"choices": [
			{"text": "Pour an offering into the sea", "fx": {"favor": 2, "food": -2}, "res": "The dolphins leap higher."},
			{"text": "Enjoy the sight and sail on", "fx": {"favor": 1}, "res": "The men's spirits lift."},
		]},
	{"id": "squall", "god": "juno", "storm": true, "text": "Black clouds race in from the south. Juno has found you again.",
		"choices": [
			{"text": "Pray to Neptune", "need": {"favor": 2}, "fx": {"favor": -2}, "res": "The squall passes around you."},
			{"text": "Ride it out", "storm": true, "fx": {}, "res": "The squall blows itself out."},
		]},
	{"id": "goats", "god": "faunus", "text": "A small island full of wild goats and fresh springs.",
		"fact": "Faunus, Roman god of the wild woods and herds, was said to be a king of Latium before the Trojans came.",
		"choices": [
			{"text": "Land and hunt", "fx": {"food": 6}, "chance": 0.75, "fail": {"food": 2, "crew": -4}, "res": "Plenty of meat and water.", "res_fail": "Cliffs and loose rock: some men fall."},
			{"text": "Fill the water jars and go", "fx": {"food": 2}, "res": "Quick and safe."},
		]},
	{"id": "circe", "god": "circe", "text": "Strange howls drift from the island of Circe, the sorceress who turns men into beasts.",
		"fact": "In the Aeneid, Neptune filled the Trojans' sails so they slipped past Circe's island in the night.",
		"choices": [
			{"text": "Steer far from her shore", "fx": {"food": -2}, "res": "A wide, slow detour. Every man is still a man."},
			{"text": "Land for fresh water", "fx": {"food": 3}, "chance": 0.5, "fail": {"crew": -10}, "res": "You fill the jars and leave before dusk.", "res_fail": "Ten men wander off and come back as grunting swine. You leave them."},
		]},
	{"id": "somnus", "god": "somnus", "text": "Night. The helmsman nods at the tiller. Somnus, god of sleep, is on board.",
		"fact": "The helmsman Palinurus was put to sleep by Somnus and fell overboard: the price Neptune asked for the fleet's safe crossing.",
		"choices": [
			{"text": "Keep watch yourself all night", "fx": {"food": -1}, "res": "You steer till dawn. Nobody is lost."},
			{"text": "Let the helmsman be", "fx": {}, "chance": 0.6, "fail": {"ships": -1, "crew": -5}, "res": "He wakes in time.", "res_fail": "He falls overboard, and his ship drifts onto rocks."},
		]},
	{"id": "shrine", "god": "jupiter", "text": "A temple of Jupiter stands on a headland, smoke rising from its altar.",
		"fact": "Jupiter (Zeus to the Greeks) was king of the gods; his great temple in Rome stood on the Capitoline Hill.",
		"choices": [
			{"text": "Offer a sacrifice", "fx": {"favor": 2, "food": -3}, "res": "Thunder rolls on the right: a good omen."},
			{"text": "Pass by", "fx": {}, "res": "The smoke fades behind you."},
		]},
	{"id": "rivals", "god": "mars", "text": "Greek ships on the horizon, old enemies from the war at Troy.",
		"fact": "Mars, god of war, was honoured above most gods in Rome, as father of Romulus and Remus.",
		"choices": [
			{"text": "Hide in a cove till they pass", "fx": {"food": -2}, "res": "They sail by without seeing you."},
			{"text": "Attack and take their stores", "fx": {"food": 8, "crew": -6}, "chance": 0.6, "fail": {"ships": -1, "crew": -10}, "res": "You win, with grain to show for it.", "res_fail": "They were stronger than they looked."},
		]},
	{"id": "venus", "god": "venus", "text": "A scent of roses on the wind: your mother Venus watches over you.",
		"fact": "Venus (Aphrodite to the Greeks) was the mother of Aeneas. Julius Caesar's family claimed descent from her through Aeneas' son Iulus.",
		"choices": [
			{"text": "Ask her to soften Juno", "fx": {"wrath": -2}, "res": "Venus pleads with Juno. The queen of the gods sulks, but less."},
			{"text": "Ask her to guide your ships", "fx": {"favor": 2}, "res": "A star leads the way at night."},
		]},
]

var diff: int = 1
var ships: int = 8
var crew: int = 120
var food: int = 24
var favor: int = 0
var wrath: int = 0
var stop: int = 0           # index in STOPS of the next story stop
var at_sea: bool = false    # true = current event is a sea event before STOPS[stop]
var sea_id: String = ""
var flags: Dictionary = {}
var seen_facts: Array = []  # fact ids met this voyage
var over: bool = false
var won: bool = false
var lost_reason: String = ""
var last_res: String = ""
var last_delta: Dictionary = {}
var decisions: int = 0
var starved: bool = false   # the last leg ran out of food
var used_sea: Array = []
var rng := RandomNumberGenerator.new()

func reset(d: int, seed_value: int) -> void:
	diff = clampi(d, 0, DIFFS.size() - 1)
	var c: Dictionary = DIFFS[diff]
	ships = c.ships
	crew = c.crew
	food = c.food
	favor = 1
	wrath = c.wrath
	stop = 0
	at_sea = false
	sea_id = ""
	flags = {}
	seen_facts = []
	over = false
	won = false
	lost_reason = ""
	last_res = ""
	last_delta = {}
	decisions = 0
	used_sea = []
	rng.seed = seed_value

## The event being shown now.
func event() -> Dictionary:
	if at_sea:
		for e in SEA:
			if e.id == sea_id:
				return e
	return STOPS[stop]

## Choices the player may see now: [{index, choice, ok (affordable)}].
func choices() -> Array:
	var out := []
	var list: Array = event().choices
	for i in list.size():
		var c: Dictionary = list[i]
		if c.has("if") and not flags.has(c["if"]):
			continue
		if c.has("unless") and flags.has(c["unless"]):
			continue
		var ok := true
		if c.has("need") and favor < int(c.need.get("favor", 0)):
			ok = false
		out.append({"index": i, "choice": c, "ok": ok})
	return out

## Storm damage: more wrath, more ships lost (1 to 6).
func storm_loss() -> int:
	return 1 + int(wrath / 2)

## Apply choice i of the current event. Returns true if it was legal.
func pick(i: int) -> bool:
	if over:
		return false
	var ev := event()
	var allowed := false
	for c in choices():
		if c.index == i and c.ok:
			allowed = true
	if not allowed:
		return false
	var ch: Dictionary = ev.choices[i]
	var fx: Dictionary = ch.fx.duplicate()
	last_res = ch.res
	starved = false
	if ch.has("chance") and rng.randf() >= float(ch.chance):
		fx = ch.fail.duplicate()
		last_res = ch.res_fail
	if ch.get("storm", false):
		fx["ships"] = int(fx.get("ships", 0)) - storm_loss()
	if ch.has("flag"):
		flags[ch.flag] = true
	if ev.has("fact") and not ev.id in seen_facts:
		seen_facts.append(ev.id)
	_apply(fx)
	decisions += 1
	_advance(ev)
	return true

func _apply(fx: Dictionary) -> void:
	var before := {"ships": ships, "crew": crew, "food": food, "favor": favor, "wrath": wrath}
	ships = maxi(0, ships + int(fx.get("ships", 0)))
	crew = maxi(0, crew + int(fx.get("crew", 0)))
	food = maxi(0, food + int(fx.get("food", 0)))
	favor = clampi(favor + int(fx.get("favor", 0)), 0, MAX_FAVOR)
	wrath = clampi(wrath + int(fx.get("wrath", 0)), 0, MAX_WRATH)
	crew = mini(crew, ships * CREW_PER_SHIP)
	last_delta = {"ships": ships - before.ships, "crew": crew - before.crew, "food": food - before.food,
		"favor": favor - before.favor, "wrath": wrath - before.wrath}

func _advance(ev: Dictionary) -> void:
	if ships <= 0 or crew <= 0:
		over = true
		lost_reason = "ships" if ships <= 0 else "crew"
		return
	if ev.get("final", false):
		over = true
		won = true
		return
	if at_sea:
		at_sea = false
		return
	stop += 1
	# Food for the leg: the fleet eats; hungry men desert.
	var eat: int = DIFFS[diff].eat
	if food >= eat:
		food -= eat
	else:
		food = 0
		crew = maxi(0, crew - 15)
		starved = true
		if crew <= 0:
			over = true
			lost_reason = "crew"
			return
	if STOPS[stop].get("final", false):
		return  # no sea event before the Tiber: straight in
	_draw_sea()

func _draw_sea() -> void:
	# Storm odds grow with Juno's wrath.
	var storm_p := 0.08 + 0.06 * wrath
	var pool: Array = []
	if rng.randf() < storm_p:
		sea_id = "squall"
	else:
		for e in SEA:
			if e.id != "squall" and not e.id in used_sea:
				pool.append(e.id)
		if pool.is_empty():
			used_sea = []
			for e in SEA:
				if e.id != "squall":
					pool.append(e.id)
		sea_id = pool[rng.randi() % pool.size()]
		used_sea.append(sea_id)
	at_sea = true

## Score when the voyage ends (0 if lost).
func score() -> int:
	if not won:
		return 0
	var raw := ships * 100 + crew * 3 + food * 2 + favor * 20 - wrath * 10
	return maxi(0, int(round(raw * float(DIFFS[diff].mult))))

## 0..1 progress along the route for the map strip.
func progress() -> float:
	var steps := float(STOPS.size() - 1)
	return clampf((stop - (0.5 if at_sea else 0.0)) / steps, 0.0, 1.0)

func to_dict() -> Dictionary:
	return {"diff": diff, "ships": ships, "crew": crew, "food": food, "favor": favor, "wrath": wrath,
		"stop": stop, "at_sea": at_sea, "sea_id": sea_id, "flags": flags, "seen_facts": seen_facts,
		"over": over, "won": won, "lost_reason": lost_reason, "decisions": decisions,
		"used_sea": used_sea, "rng_state": str(rng.state), "rng_seed": str(rng.seed)}

func from_dict(d: Dictionary) -> void:
	diff = int(d.get("diff", 1))
	ships = int(d.get("ships", 8))
	crew = int(d.get("crew", 100))
	food = int(d.get("food", 20))
	favor = int(d.get("favor", 0))
	wrath = int(d.get("wrath", 0))
	stop = clampi(int(d.get("stop", 0)), 0, STOPS.size() - 1)
	at_sea = bool(d.get("at_sea", false))
	sea_id = str(d.get("sea_id", ""))
	flags = d.get("flags", {})
	seen_facts = d.get("seen_facts", [])
	over = bool(d.get("over", false))
	won = bool(d.get("won", false))
	lost_reason = str(d.get("lost_reason", ""))
	decisions = int(d.get("decisions", 0))
	used_sea = d.get("used_sea", [])
	rng.seed = int(str(d.get("rng_seed", "1")))
	rng.state = int(str(d.get("rng_state", "1")))
	if at_sea and event().get("id", "") != sea_id:
		at_sea = false

## A help (kit pool): Venus restores one ship, 15 crew and 5 food.
func venus_help() -> bool:
	if over:
		return false
	ships += 1
	crew = mini(crew + 15, ships * CREW_PER_SHIP)
	food += 5
	return true
