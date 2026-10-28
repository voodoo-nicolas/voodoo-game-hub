extends RefCounted

## Career: eight stages, each a small tournament against a boss and two to four
## other characters (video_poker_characters.gd). Win it to open the next stage.
## Stars per stage: 1 for winning, 2 for winning without the coach or win chance,
## 3 for winning within `fast` hands. A stage is played as a normal tournament
## table (mode "tourney") with meta.career = the stage id; the finish is counted
## by the game when the match ends. Progress is in the profile (profile.d.career).
##
## Stage: id, title, blurb, variant, limit, others (names), boss (a name), level
## (computer level 0-2), hpl (hands per blind level), boss_stack (the boss's
## starting chips as a multiple of yours), xp (first clear), fast (hands for the
## third star). Texts are English keys the screens translate.

const Characters = preload("res://scripts/games/video_poker/video_poker_characters.gd")

const START_STACK := 1500

const STAGES := [
	{"id": "back_room", "title": "Back Room", "blurb": "A quiet table behind the bar. Everyone here calls too much.", "variant": "holdem", "limit": "nl",
		"others": ["Bones", "Skully"], "boss": "Dusty Dan", "level": 0, "hpl": 6, "boss_stack": 1.0, "xp": 100, "fast": 18},
	{"id": "candle_cellar", "title": "Candle Cellar", "blurb": "Dim candles and tight players. Wait for your hands.", "variant": "holdem", "limit": "nl",
		"others": ["Mama Zuzu", "Lola"], "boss": "Madame Vesper", "level": 0, "hpl": 6, "boss_stack": 1.0, "xp": 150, "fast": 22},
	{"id": "riverboat", "title": "Riverboat", "blurb": "Five Card Draw on the water. Loose and loud.", "variant": "draw", "limit": "nl",
		"others": ["Lucky Lou", "Tex"], "boss": "Captain Marrow", "level": 1, "hpl": 6, "boss_stack": 1.0, "xp": 200, "fast": 25},
	{"id": "omaha_night", "title": "Omaha Night", "blurb": "Pot limit Omaha: four cards, big swings.", "variant": "omaha", "limit": "pl",
		"others": ["Jinx", "Ruby"], "boss": "Doctor Sable", "level": 1, "hpl": 6, "boss_stack": 1.0, "xp": 250, "fast": 28},
	{"id": "stud_parlour", "title": "Stud Parlour", "blurb": "Seven Card Stud, Limit. Watch the cards that show.", "variant": "stud", "limit": "fl",
		"others": ["Rook", "Marisol"], "boss": "The Baroness", "level": 1, "hpl": 8, "boss_stack": 1.0, "xp": 300, "fast": 30},
	{"id": "the_vault", "title": "The Vault", "blurb": "Hard players and a boss with a bigger stack.", "variant": "holdem", "limit": "nl",
		"others": ["Gator", "Velvet", "Raven"], "boss": "Iron Ike", "level": 2, "hpl": 6, "boss_stack": 1.5, "xp": 400, "fast": 32},
	{"id": "high_table", "title": "High Table", "blurb": "Pot limit Omaha with the best players in town.", "variant": "omaha", "limit": "pl",
		"others": ["Madame Mojo", "Doc Hex", "Big Moe"], "boss": "Sister Scarlet", "level": 2, "hpl": 6, "boss_stack": 1.5, "xp": 500, "fast": 36},
	{"id": "skull_throne", "title": "The Skull Throne", "blurb": "The last table. The King starts with twice your chips.", "variant": "holdem", "limit": "nl",
		"others": ["Madame Mojo", "Gator", "Jinx", "Velvet"], "boss": "The Skull King", "level": 2, "hpl": 5, "boss_stack": 2.0, "xp": 800, "fast": 40},
]

static func stage(id: String) -> Dictionary:
	for s in STAGES:
		if s.id == id:
			return s
	return {}

static func index_of(id: String) -> int:
	for i in STAGES.size():
		if STAGES[i].id == id:
			return i
	return -1

## Stars (0-3) for a finished stage: `won`, whether the coach or win chance was
## used in the match (`aids`), and how many hands it took.
static func stars(id: String, won: bool, aids: bool, hands: int) -> int:
	if not won:
		return 0
	var s := stage(id)
	var n := 1
	if not aids:
		n += 1
	if not s.is_empty() and hands <= int(s.fast):
		n += 1
	return n

## Is stage `index` open, given the stars earned so far ({id: stars})?
static func unlocked(index: int, earned: Dictionary) -> bool:
	if index <= 0:
		return true
	return int(earned.get(STAGES[index - 1].id, 0)) >= 1

static func total_stars(earned: Dictionary) -> int:
	var n := 0
	for s in STAGES:
		n += int(earned.get(s.id, 0))
	return n

static func cleared(earned: Dictionary) -> int:
	var n := 0
	for s in STAGES:
		if int(earned.get(s.id, 0)) >= 1:
			n += 1
	return n

## The opponents' names for a stage, the boss last.
static func opponents(s: Dictionary) -> Array:
	var out: Array = (s.others as Array).duplicate()
	out.append(s.boss)
	return out
