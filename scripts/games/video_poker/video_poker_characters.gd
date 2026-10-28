extends RefCounted

## The computer players as characters: each has a name, an icon, a playing style
## (an index into video_poker_ai.gd STYLES, for the coach's labels) and traits that
## replace that style's numbers, a quirk, a skill and a few lines to say. The first
## ROSTER_SIZE are the random table-mates; the rest are bosses (Career stages).
## Characters are found by seat name, so nothing is added to the table or saves.
## (Written once from a table of EN/ES text; the Spanish is in tools/i18n/es.json.)
##
## traits: tight (0 loose .. 1 tight), aggr, bluff: as STYLES. quirk: "" none,
##   "bully" (more aggressive when its stack is the biggest), "tilt" (wilder when
##   its stack gets short), "trapper" (sometimes checks a strong hand to slow-play),
##   "sticky" (calls wider). skill: levels above the table's computer level.
##   sharp: reads hands more exactly and bluffs a bit more.

const ROSTER_SIZE := 16

const ALL := [
	{"id": "zuzu", "name": "Mama Zuzu", "icon": "👵", "style": 0, "tight": 0.9, "aggr": 0.25, "bluff": 0.02, "quirk": "trapper", "skill": 0, "sharp": false, "boss": false,
		"bio": "Plays few hands and has seen it all. When Mama bets, believe her.",
		"win": "Mama knew.", "allin": "Mama is all in. Think hard, child.", "bust": "Mama will be back, child."},
	{"id": "bones", "name": "Bones", "icon": "💀", "style": 3, "tight": 0.2, "aggr": 0.12, "bluff": 0.02, "quirk": "sticky", "skill": 0, "sharp": false, "boss": false,
		"bio": "Calls everything to see what you have. Never bluff Bones.",
		"win": "Bones found a winner!", "allin": "Bones is not folding.", "bust": "Bones is all out of chips."},
	{"id": "lou", "name": "Lucky Lou", "icon": "🍀", "style": 2, "tight": 0.2, "aggr": 0.9, "bluff": 0.28, "quirk": "", "skill": 0, "sharp": false, "boss": false,
		"bio": "Raises on a hunch, and the hunch is often wrong. Call Lou down.",
		"win": "Told you I was lucky!", "allin": "Feeling lucky!", "bust": "The luck ran out..."},
	{"id": "mojo", "name": "Madame Mojo", "icon": "🔮", "style": 1, "tight": 0.6, "aggr": 0.75, "bluff": 0.14, "quirk": "", "skill": 0, "sharp": false, "boss": false,
		"bio": "Solid and aggressive, with a good read on you.",
		"win": "The cards told me so.", "allin": "The spirits say: all in.", "bust": "The spirits were quiet today."},
	{"id": "gator", "name": "Gator", "icon": "🐊", "style": 1, "tight": 0.5, "aggr": 0.8, "bluff": 0.16, "quirk": "bully", "skill": 0, "sharp": false, "boss": false,
		"bio": "Pushes you around when he has the big stack. Stand up to him with strong hands.",
		"win": "Chomp!", "allin": "Gator bites!", "bust": "Gator needs a swamp break."},
	{"id": "jinx", "name": "Jinx", "icon": "🐈‍⬛", "style": 4, "tight": 0.45, "aggr": 0.55, "bluff": 0.12, "quirk": "", "skill": 0, "sharp": false, "boss": false,
		"bio": "Tricky: mixes bets and checks so you can't read her.",
		"win": "Bad luck for you.", "allin": "Jinx is all in!", "bust": "I jinxed myself."},
	{"id": "hex", "name": "Doc Hex", "icon": "🩺", "style": 0, "tight": 0.8, "aggr": 0.4, "bluff": 0.05, "quirk": "trapper", "skill": 0, "sharp": false, "boss": false,
		"bio": "Patient. Often checks a monster to lure you in.",
		"win": "The diagnosis: a winning hand.", "allin": "Doctor's orders: all in.", "bust": "I need a second opinion."},
	{"id": "ruby", "name": "Ruby", "icon": "💎", "style": 1, "tight": 0.65, "aggr": 0.7, "bluff": 0.1, "quirk": "", "skill": 0, "sharp": false, "boss": false,
		"bio": "Tight and aggressive. Few hands, big bets.",
		"win": "Another gem for the collection.", "allin": "Ruby shines all in.", "bust": "I lost my shine."},
	{"id": "tex", "name": "Tex", "icon": "🤠", "style": 2, "tight": 0.3, "aggr": 0.85, "bluff": 0.22, "quirk": "tilt", "skill": 0, "sharp": false, "boss": false,
		"bio": "Bets big, and gets wilder when his stack gets short.",
		"win": "Yeehaw!", "allin": "All in, partner!", "bust": "Reckon I'm done."},
	{"id": "lola", "name": "Lola", "icon": "💃", "style": 4, "tight": 0.4, "aggr": 0.6, "bluff": 0.15, "quirk": "", "skill": 0, "sharp": false, "boss": false,
		"bio": "Loves a bluff. Don't let her push you off good hands.",
		"win": "Dance with me, darling.", "allin": "All in. I dare you.", "bust": "Lola takes a bow."},
	{"id": "skully", "name": "Skully", "icon": "🎭", "style": 3, "tight": 0.3, "aggr": 0.15, "bluff": 0.03, "quirk": "sticky", "skill": 0, "sharp": false, "boss": false,
		"bio": "Hates to fold. Bet your good hands, never bluff.",
		"win": "Heh heh heh.", "allin": "Skully doesn't fold.", "bust": "Skully goes home."},
	{"id": "rook", "name": "Rook", "icon": "♜", "style": 0, "tight": 0.85, "aggr": 0.35, "bluff": 0.04, "quirk": "trapper", "skill": 0, "sharp": false, "boss": false,
		"bio": "Silent and careful. A big bet from Rook is the real thing.",
		"win": "Check. Mate.", "allin": "Rook takes the board.", "bust": "Rook retreats."},
	{"id": "velvet", "name": "Velvet", "icon": "🌹", "style": 1, "tight": 0.55, "aggr": 0.7, "bluff": 0.15, "quirk": "", "skill": 0, "sharp": false, "boss": false,
		"bio": "Smooth and steady. Raises when she acts last.",
		"win": "Smooth.", "allin": "Velvet pushes it all in.", "bust": "Velvet fades away."},
	{"id": "marisol", "name": "Marisol", "icon": "🌴", "style": 4, "tight": 0.5, "aggr": 0.5, "bluff": 0.1, "quirk": "", "skill": 0, "sharp": false, "boss": false,
		"bio": "Balanced and patient. Hard to read and hard to beat.",
		"win": "Good game.", "allin": "Marisol goes all in.", "bust": "Marisol gives a wave."},
	{"id": "moe", "name": "Big Moe", "icon": "🥊", "style": 1, "tight": 0.35, "aggr": 0.85, "bluff": 0.2, "quirk": "bully", "skill": 0, "sharp": false, "boss": false,
		"bio": "Big stack, big bets. Wait for a hand and hit back.",
		"win": "Moe wins again!", "allin": "Moe is going all in!", "bust": "Moe is down for the count."},
	{"id": "raven", "name": "Raven", "icon": "🐦‍⬛", "style": 1, "tight": 0.5, "aggr": 0.65, "bluff": 0.13, "quirk": "tilt", "skill": 0, "sharp": false, "boss": false,
		"bio": "Calm until she loses a big pot, then she gets reckless.",
		"win": "Nevermore.", "allin": "Raven swoops in, all in.", "bust": "Raven flies off."},
	{"id": "dan", "name": "Dusty Dan", "icon": "🌵", "style": 3, "tight": 0.25, "aggr": 0.3, "bluff": 0.05, "quirk": "sticky", "skill": 0, "sharp": false, "boss": true,
		"bio": "Boss of the Back Room. Calls everything and sits on a big pile. Make him pay for it.",
		"win": "That's how it's done out here.", "allin": "Dan pushes the whole dust pile.", "bust": "Well, I'll be."},
	{"id": "vesper", "name": "Madame Vesper", "icon": "🕯", "style": 0, "tight": 0.88, "aggr": 0.4, "bluff": 0.05, "quirk": "trapper", "skill": 0, "sharp": true, "boss": true,
		"bio": "Boss of the Candle Cellar. Very tight. A bet from her usually means a monster, and she loves to trap.",
		"win": "The candle burns for me.", "allin": "Vesper blows out the candle: all in.", "bust": "The candle goes out."},
	{"id": "marrow", "name": "Captain Marrow", "icon": "⚓", "style": 2, "tight": 0.25, "aggr": 0.9, "bluff": 0.28, "quirk": "bully", "skill": 0, "sharp": false, "boss": true,
		"bio": "Boss of the Riverboat. Bets like a storm, especially with the big stack. Let him bluff himself dry.",
		"win": "Full steam ahead!", "allin": "All hands on deck: all in!", "bust": "The ship goes down."},
	{"id": "sable", "name": "Doctor Sable", "icon": "🧪", "style": 4, "tight": 0.45, "aggr": 0.6, "bluff": 0.16, "quirk": "", "skill": 0, "sharp": true, "boss": true,
		"bio": "Boss of Omaha Night. Tricky and sharp: mixes bets, checks and bluffs and reads you well.",
		"win": "Experiment successful.", "allin": "The final experiment: all in.", "bust": "The experiment failed."},
	{"id": "baroness", "name": "The Baroness", "icon": "🦇", "style": 1, "tight": 0.7, "aggr": 0.75, "bluff": 0.1, "quirk": "", "skill": 0, "sharp": true, "boss": true,
		"bio": "Boss of the Stud Parlour. Tight, aggressive and sharp. Few hands, and she bets every one of them.",
		"win": "A very good hand, darling.", "allin": "The Baroness is all in.", "bust": "Even bats must sleep."},
	{"id": "ike", "name": "Iron Ike", "icon": "⚙", "style": 1, "tight": 0.4, "aggr": 0.85, "bluff": 0.18, "quirk": "bully", "skill": 1, "sharp": false, "boss": true,
		"bio": "Boss of the Vault. Starts with a bigger stack and uses it to bully you. Hit back with strong hands.",
		"win": "The vault stays closed.", "allin": "Ike throws it all in.", "bust": "Even iron rusts."},
	{"id": "scarlet", "name": "Sister Scarlet", "icon": "🕯", "style": 1, "tight": 0.55, "aggr": 0.7, "bluff": 0.2, "quirk": "tilt", "skill": 1, "sharp": true, "boss": true,
		"bio": "Boss of the High Table. Sharp, and wilder when her stack gets short. Be patient and take your spots.",
		"win": "It is written.", "allin": "Scarlet goes all in.", "bust": "The candle gutters."},
	{"id": "king", "name": "The Skull King", "icon": "👑", "style": 1, "tight": 0.55, "aggr": 0.8, "bluff": 0.18, "quirk": "bully", "skill": 1, "sharp": true, "boss": true,
		"bio": "Boss of the Skull Throne. Sharp, aggressive and starts with twice the chips. The final test.",
		"win": "The throne is mine.", "allin": "The King wagers his crown: all in.", "bust": "The crown falls."},
]

static var _by_name := {}

## The character called `name`, or {} (the player, "Player 2", an unknown name).
static func find(name: String) -> Dictionary:
	if _by_name.is_empty():
		for c in ALL:
			_by_name[c.name] = c
	return _by_name.get(name, {})

## The table-mates a random table is made of.
static func roster() -> Array:
	return ALL.slice(0, ROSTER_SIZE)

static func names() -> Array:
	var out: Array = []
	for c in roster():
		out.append(c.name)
	return out

## What `name` says after `kind` ("win", "allin", "bust"): an English line for the
## screen to translate, or "".
static func line(name: String, kind: String) -> String:
	return str(find(name).get(kind, ""))
