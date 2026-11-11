extends RefCounted

## Pastimes and odd jobs (QUESTS.md A / W series + the owner's "a lot of little things to do", 2026-11-09).
## Each runs like any action (real time, an absolute end time, caught up offline) and writes journal lines.
## `group`: "quick" = odd jobs (5-25 seconds, the castaway's ⚡ menu), "long" = pastimes (🧘 menu).
## Fields: en (menu label), icon, min (real MINUTES, 0.1 = 6 s), energy, mood (added when done), stand
## (plate pixels; none = where he is), pose (a castaway pose), lines (journal variants, some are facts),
## loot ([[item id, weight], ...] one roll; "" = nothing), xp (foraging XP on a find), needs (item id
## that must be in the bag, not used up), needs_any (a built structure), stat (quest counter),
## give ([[item id, n], ...] always handed over), wear (a tool that loses one use).

const LIST := [
	# ---------------------------------------------------------------- quick odd jobs
	{"id": "search_sand", "group": "quick", "en": "Search the sand", "icon": "🔍", "min": 0.17, "energy": 1.0, "mood": 0.0, "pose": "craft",
		"loot": [["", 22], ["shell", 24], ["stone", 20], ["stick", 14], ["sand", 10], ["seaweed", 5], ["sea_glass", 3], ["nail", 1], ["old_coin", 1]],
		"lines": ["Sifted the sand with my fingers.", "Dug around in the sand. The sand dug back.", "Searched the beach. The beach was unimpressed."]},
	{"id": "skip_stone", "group": "quick", "en": "Skip a stone", "icon": "🪨", "min": 0.1, "energy": 0.0, "mood": 1.5, "pose": "wave", "needs": "stone",
		"lines": ["Skipped a stone across the water. A clean throw.", "Skipped a stone. It went plop, which counts as a skip."]},
	{"id": "splash", "group": "quick", "en": "Splash in the shallows", "icon": "💦", "min": 0.08, "energy": 0.0, "mood": 2.0, "pose": "wave", "stand": "water",
		"lines": ["Splashed around in the shallows like a person with no obligations.", "Kicked the water. The water forgave me."]},
	{"id": "peek", "group": "quick", "en": "Scan the horizon", "icon": "👀", "min": 0.08, "energy": 0.0, "mood": 0.5, "pose": "idle",
		"lines": ["Scanned the horizon. Water. Still water.", "Looked out to sea. A seagull looked back.", "Nothing on the horizon. A classic."]},
	{"id": "tidy", "group": "quick", "en": "Tidy the camp", "icon": "🧹", "min": 0.25, "energy": 0.3, "mood": 2.5, "pose": "craft", "needs_any": ["campfire", "tent", "hammock", "frond_bed", "frond_shelter", "crafting_stump"],
		"lines": ["Tidied the camp. It looks exactly as tidy as a camp on a rock can.", "Straightened things. Moved a stick six inches. Felt productive."]},
	{"id": "comb", "group": "quick", "en": "Comb the tideline", "icon": "🌊", "min": 0.4, "energy": 1.5, "mood": 0.0, "pose": "craft", "stand": Vector2(1086, 535),
		"loot": [["", 18], ["shell", 26], ["seaweed", 20], ["driftwood", 10], ["stone", 10], ["sea_glass", 7], ["salt", 4], ["bottle", 3], ["pearl", 1], ["conch_shell", 1]],
		"lines": ["Combed the tideline. The sea leaves its homework there.", "Walked the waterline looking down. A fine way to be disappointed slowly."]},
	{"id": "catch_crab", "group": "quick", "en": "Catch a crab", "icon": "🦀", "min": 0.25, "energy": 1.5, "mood": 1.0, "pose": "craft", "stand": Vector2(1339, 535),
		"loot": [["", 30], ["bait", 40], ["fish_small", 20], ["shell", 10]],
		"lines": ["Chased a crab. It won the first round.", "Caught a crab. Let it go. It stared at me with great contempt."]},
	{"id": "dig", "group": "quick", "en": "Dig a hole", "icon": "🕳", "min": 0.33, "energy": 2.0, "mood": 0.5, "pose": "craft", "needs": "shovel",
		"loot": [["sand", 40], ["stone", 25], ["shell", 15], ["", 15], ["nail", 3], ["old_coin", 2]],
		"lines": ["Dug a hole. A very good hole. Possibly the best hole.", "Dug down a metre. Sand all the way. Naturally."]},
	{"id": "fan_fire", "group": "quick", "en": "Fan the fire", "icon": "🔥", "min": 0.17, "energy": 0.2, "mood": 0.5, "pose": "craft", "stand": "campfire",
		"lines": ["Fanned the fire with a frond. It purred and burned a bit longer."]},
	{"id": "stretch", "group": "quick", "en": "Stretch", "icon": "🙆", "min": 0.08, "energy": 0.0, "mood": 1.0, "pose": "wave",
		"lines": ["Stretched. Every joint complained in turn.", "Rolled my shoulders. Something went crunch. Fine."]},
	{"id": "wave_nothing", "group": "quick", "en": "Wave at nothing", "icon": "👋", "min": 0.08, "energy": 0.0, "mood": 1.0, "pose": "shrug",
		"lines": ["Waved at the horizon. Politely. It did not wave back.", "Waved at a cloud. It drifted off, rude."]},
	{"id": "shake_rocks", "group": "quick", "en": "Check the rock pools", "icon": "🦐", "min": 0.3, "energy": 1.5, "mood": 0.5, "pose": "craft", "stand": Vector2(1284, 535),
		"loot": [["", 28], ["seaweed", 30], ["shell", 22], ["bait", 15], ["salt", 5]],
		"lines": ["Peered into the rock pools. A small crab peered back.", "Poked a rock pool. It had opinions."]},
	{"id": "dig_clay", "group": "quick", "en": "Dig for clay", "icon": "🏺", "min": 0.35, "energy": 2.5, "mood": 0.0, "pose": "craft", "needs": "shovel", "wear": "shovel", "stand": Vector2(580, 535),
		"give": [["clay", 2]],
		"lines": ["Dug under the wet sand by the rocks. Grey clay, cold and heavy.", "Clay is rock ground so fine that it holds water. It also holds on to my fingers."]},
	# ---------------------------------------------------------------- longer pastimes
	{"id": "stargaze", "group": "long", "en": "Stargaze", "icon": "🌌", "min": 45.0, "energy": 2.0, "mood": 8.0, "stand": Vector2(954, 535), "pose": "sit",
		"lines": ["Counted stars until I lost count. The Southern Cross points roughly at the south pole.",
			"Lay on the sand and watched the sky turn. Orion is upside down down here. So am I, spiritually.",
			"Stars twinkle because air bends their light. Planets do not. Handy for telling them apart."]},
	{"id": "yoga", "group": "long", "en": "Sunrise stretch", "icon": "🧘", "min": 20.0, "energy": 0.0, "mood": 8.0, "stand": Vector2(866, 535), "pose": "sit",
		"lines": ["Stretched at sunrise. Something clicked. Possibly my spine.",
			"Breathed in, breathed out, felt calm for almost a minute. Slow breathing really does settle the heart.",
			"Sun salutations on a beach. Nobody saw. Best audience I have had."]},
	{"id": "horizon", "group": "long", "en": "Stare at the horizon", "icon": "🔭", "min": 60.0, "energy": 1.0, "mood": 3.0, "stand": Vector2(1020, 535), "pose": "sit",
		"lines": ["Stared at the horizon for an hour. It stared back. It is about five kilometres away at my eye height.",
			"Considered the meaning of it all. Concluded: coconuts. Probably coconuts.",
			"The horizon looks flat because the Earth is very big. A ship's mast shows before its hull does."]},
	{"id": "crab_race", "group": "long", "en": "Crab race", "icon": "🦀", "min": 20.0, "energy": 2.0, "mood": 6.0, "stand": Vector2(1339, 535), "pose": "work",
		"lines": ["Entered a crab in the race. Mine went sideways, the way crabs do. Everyone did.",
			"Bet on the small crab. Won something. Pride, mostly."]},
	{"id": "sandcastle", "group": "long", "en": "Build a sandcastle", "icon": "🏰", "min": 45.0, "energy": 4.0, "mood": 8.0, "stand": Vector2(580, 535), "pose": "work",
		"lines": ["Built a sandcastle with a moat. The tide has already filed a complaint.",
			"A fine castle. Wet sand holds its shape because of water's surface tension between the grains."]},
	{"id": "draw", "group": "long", "en": "Draw in the sand", "icon": "✍", "min": 15.0, "energy": 1.0, "mood": 4.0, "stand": Vector2(1185, 535), "pose": "work",
		"lines": ["Drew a self-portrait in the sand. Flattering. The tide thought otherwise.",
			"Wrote HELLO in huge letters. A plane would see it. No plane did."]},
	{"id": "coconut_friend", "group": "long", "en": "Make a coconut friend", "icon": "🥥", "min": 15.0, "energy": 1.0, "mood": 10.0, "stand": Vector2(932, 535), "pose": "craft",
		"lines": ["Drew a face on a coconut with charcoal. Named it Coco. Coco listens better than most people."]},
	{"id": "chat", "group": "long", "en": "Chat with the coconut", "icon": "💬", "min": 10.0, "energy": 0.0, "mood": 6.0, "stand": Vector2(932, 535), "pose": "sit",
		"lines": ["Told Coco about my day. Coco said nothing, supportively.",
			"Coco and I disagreed about the best way to open a coconut. Awkward.",
			"Asked Coco for advice. The silence was wise."]},
	{"id": "swim", "group": "long", "en": "Go for a swim", "icon": "🏊", "min": 10.0, "energy": 4.0, "mood": 6.0, "stand": "water", "pose": "wave",
		"lines": ["Swam out to where it gets deep and back. The sand is finally out of my ears.",
			"Floated on my back. Salt water holds you up better than fresh: it is denser.",
			"A swim. The fish kept their distance. Wise."]},
	{"id": "sunset", "group": "long", "en": "Watch the sunset", "icon": "🌇", "min": 15.0, "energy": 0.0, "mood": 8.0, "stand": Vector2(1020, 535), "pose": "sit",
		"lines": ["Watched the sun go down. Sunsets are red because the low light crosses more air, and air scatters the blue away.",
			"The sun sank into the sea. No hiss. I listen every time.",
			"A good sunset. I gave it an eight. The sea gave me nothing back."]},
	{"id": "drum", "group": "long", "en": "Play the drum", "icon": "🥁", "min": 5.0, "energy": 1.0, "mood": 7.0, "needs": "drum", "pose": "sit",
		"lines": ["Played the coconut drum. The crabs left. Critics.",
			"A drum solo for an audience of one palm. It swayed. I am counting that.",
			"Kept a beat for five minutes. Lost it. Found a worse one."]},
]

static func get_pastime(id: String) -> Dictionary:
	for p in LIST:
		if p.id == id:
			return p
	return {}

static func group_list(group: String) -> Array:
	var out: Array = []
	for p in LIST:
		if p.group == group:
			out.append(p)
	return out
