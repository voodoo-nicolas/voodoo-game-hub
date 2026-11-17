extends RefCounted

## Career: one ladder for each game (Table.VARIANTS), 25 stages in all, each a small tournament against a boss and two to four
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
	# Texas Hold'em
	{"id": "back_room", "title": "Back Room", "blurb": "A quiet table behind the bar. Everyone here calls too much.", "variant": "holdem", "limit": "nl",
		"others": ["Bones", "Skully"], "boss": "Dusty Dan", "level": 0, "hpl": 6, "boss_stack": 1.0, "xp": 100, "fast": 18},
	{"id": "candle_cellar", "title": "Candle Cellar", "blurb": "Dim candles and tight players. Wait for your hands.", "variant": "holdem", "limit": "nl",
		"others": ["Mama Zuzu", "Lola"], "boss": "Madame Vesper", "level": 0, "hpl": 6, "boss_stack": 1.0, "xp": 150, "fast": 22},
	{"id": "the_vault", "title": "The Vault", "blurb": "Hard players and a boss with a bigger stack.", "variant": "holdem", "limit": "nl",
		"others": ["Gator", "Velvet", "Raven"], "boss": "Iron Ike", "level": 2, "hpl": 6, "boss_stack": 1.5, "xp": 400, "fast": 32},
	{"id": "skull_throne", "title": "The Skull Throne", "blurb": "The last table. The King starts with twice your chips.", "variant": "holdem", "limit": "nl",
		"others": ["Madame Mojo", "Gator", "Jinx", "Velvet"], "boss": "The Skull King", "level": 2, "hpl": 5, "boss_stack": 2.0, "xp": 800, "fast": 40},
	# Omaha
	{"id": "omaha_porch", "title": "Pot Limit Porch", "blurb": "Four cards each and friendly players. Learn to use exactly two.", "variant": "omaha", "limit": "pl",
		"others": ["Bones", "Lola"], "boss": "Dusty Dan", "level": 0, "hpl": 6, "boss_stack": 1.0, "xp": 120, "fast": 24},
	{"id": "omaha_night", "title": "Omaha Night", "blurb": "Pot limit Omaha: four cards, big swings.", "variant": "omaha", "limit": "pl",
		"others": ["Jinx", "Ruby"], "boss": "Doctor Sable", "level": 1, "hpl": 6, "boss_stack": 1.0, "xp": 250, "fast": 28},
	{"id": "high_table", "title": "High Table", "blurb": "Pot limit Omaha with the best players in town.", "variant": "omaha", "limit": "pl",
		"others": ["Madame Mojo", "Doc Hex", "Big Moe"], "boss": "Sister Scarlet", "level": 2, "hpl": 6, "boss_stack": 1.5, "xp": 500, "fast": 36},
	# Five Card Draw
	{"id": "draw_kitchen", "title": "Kitchen Table", "blurb": "Five cards, one draw, loose callers. Bet your good hands.", "variant": "draw", "limit": "nl",
		"others": ["Skully", "Mama Zuzu"], "boss": "Madame Vesper", "level": 0, "hpl": 6, "boss_stack": 1.0, "xp": 120, "fast": 22},
	{"id": "riverboat", "title": "Riverboat", "blurb": "Five Card Draw on the water. Loose and loud.", "variant": "draw", "limit": "nl",
		"others": ["Lucky Lou", "Tex"], "boss": "Captain Marrow", "level": 1, "hpl": 6, "boss_stack": 1.0, "xp": 200, "fast": 25},
	{"id": "lighthouse", "title": "The Lighthouse", "blurb": "A storm outside and hard players in. Draw smart, bluff rarely.", "variant": "draw", "limit": "nl",
		"others": ["Rook", "Big Moe", "Raven"], "boss": "Iron Ike", "level": 2, "hpl": 6, "boss_stack": 1.5, "xp": 400, "fast": 32},
	# Seven Card Stud
	{"id": "tea_room", "title": "Tea Room", "blurb": "Stud with gentle players. Watch the cards that show.", "variant": "stud", "limit": "fl",
		"others": ["Marisol", "Ruby"], "boss": "Madame Vesper", "level": 0, "hpl": 8, "boss_stack": 1.0, "xp": 120, "fast": 26},
	{"id": "stud_parlour", "title": "Stud Parlour", "blurb": "Seven Card Stud, Limit. Watch the cards that show.", "variant": "stud", "limit": "fl",
		"others": ["Rook", "Marisol"], "boss": "The Baroness", "level": 1, "hpl": 8, "boss_stack": 1.0, "xp": 300, "fast": 30},
	{"id": "masquerade", "title": "Masquerade", "blurb": "Masks, candles and the sharpest stud players in town.", "variant": "stud", "limit": "fl",
		"others": ["Velvet", "Doc Hex", "Rook"], "boss": "Sister Scarlet", "level": 2, "hpl": 7, "boss_stack": 1.5, "xp": 450, "fast": 34},
	# Short Deck
	{"id": "short_alley", "title": "Back Alley Sixes", "blurb": "36 cards: no twos to fives. A flush beats a full house here.", "variant": "short", "limit": "nl",
		"others": ["Tex", "Lucky Lou"], "boss": "Dusty Dan", "level": 0, "hpl": 6, "boss_stack": 1.0, "xp": 120, "fast": 20},
	{"id": "short_express", "title": "Night Express", "blurb": "A short deck on a fast train. Hands run big: don't fall in love with them.", "variant": "short", "limit": "nl",
		"others": ["Jinx", "Gator"], "boss": "Captain Marrow", "level": 1, "hpl": 6, "boss_stack": 1.0, "xp": 250, "fast": 26},
	{"id": "short_crown", "title": "The Six Crown", "blurb": "Lady Six's table. She starts with more chips and bets them all.", "variant": "short", "limit": "nl",
		"others": ["Madame Mojo", "Big Moe", "Raven"], "boss": "Lady Six", "level": 2, "hpl": 5, "boss_stack": 1.5, "xp": 500, "fast": 32},
	# Pineapple
	{"id": "pine_grove", "title": "Pineapple Grove", "blurb": "Three cards, throw one away before the flop. Keep the best two.", "variant": "pineapple", "limit": "nl",
		"others": ["Bones", "Ruby"], "boss": "Madame Vesper", "level": 0, "hpl": 6, "boss_stack": 1.0, "xp": 120, "fast": 22},
	{"id": "pine_market", "title": "Night Market", "blurb": "Busy stalls and tricky players. Your discard tells you what's left.", "variant": "pineapple", "limit": "nl",
		"others": ["Doc Hex", "Velvet"], "boss": "Doctor Sable", "level": 1, "hpl": 6, "boss_stack": 1.0, "xp": 250, "fast": 28},
	{"id": "pine_summit", "title": "Thorn Summit", "blurb": "Old Thorn waits at the top. Patient, tight and he loves a trap.", "variant": "pineapple", "limit": "nl",
		"others": ["Rook", "Marisol", "Gator"], "boss": "Old Thorn", "level": 2, "hpl": 6, "boss_stack": 1.5, "xp": 500, "fast": 34},
	# Crazy Pineapple
	{"id": "crazy_fair", "title": "Crazy Fair", "blurb": "Keep three cards until after the flop, then throw one away.", "variant": "crazy", "limit": "nl",
		"others": ["Lucky Lou", "Skully"], "boss": "Captain Marrow", "level": 0, "hpl": 6, "boss_stack": 1.0, "xp": 120, "fast": 22},
	{"id": "crazy_carousel", "title": "Carousel", "blurb": "Round and round: loose players and big pots.", "variant": "crazy", "limit": "nl",
		"others": ["Jinx", "Big Moe"], "boss": "Iron Ike", "level": 1, "hpl": 6, "boss_stack": 1.0, "xp": 250, "fast": 28},
	{"id": "crazy_spiral", "title": "The Spiral", "blurb": "Mister Twitch's table. Wild bets, wilder when he's losing.", "variant": "crazy", "limit": "nl",
		"others": ["Lola", "Raven", "Tex"], "boss": "Mister Twitch", "level": 2, "hpl": 6, "boss_stack": 1.5, "xp": 500, "fast": 34},
	# Omaha Hi-Lo
	{"id": "hilo_dock", "title": "Split Dock", "blurb": "Half the pot for the best high, half for the best low.", "variant": "omahahilo", "limit": "pl",
		"others": ["Mama Zuzu", "Tex"], "boss": "Doctor Sable", "level": 0, "hpl": 6, "boss_stack": 1.0, "xp": 120, "fast": 24},
	{"id": "hilo_mirror", "title": "Hall of Mirrors", "blurb": "Everyone wants both halves. Scoop when you can.", "variant": "omahahilo", "limit": "pl",
		"others": ["Velvet", "Doc Hex"], "boss": "The Baroness", "level": 1, "hpl": 6, "boss_stack": 1.0, "xp": 250, "fast": 30},
	{"id": "hilo_masks", "title": "The Twin Masks", "blurb": "The Masks play both ways and rarely get scooped. Take a half, then the whole.", "variant": "omahahilo", "limit": "pl",
		"others": ["Madame Mojo", "Marisol", "Ruby"], "boss": "The Twin Masks", "level": 2, "hpl": 6, "boss_stack": 1.5, "xp": 500, "fast": 36},
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
## Ladders are per game: the stage before is the previous one of the same
## variant. A stage already starred stays open (stars from the old single ladder).
static func unlocked(index: int, earned: Dictionary) -> bool:
	if index <= 0 or index >= STAGES.size():
		return index <= 0
	if int(earned.get(STAGES[index].id, 0)) >= 1:
		return true
	var prev := previous(index)
	return prev < 0 or int(earned.get(STAGES[prev].id, 0)) >= 1

## The index of the stage before `index` in its game's ladder, or -1 (the first).
static func previous(index: int) -> int:
	var v := str(STAGES[index].variant)
	for i in range(index - 1, -1, -1):
		if str(STAGES[i].variant) == v:
			return i
	return -1

## The stage indices of one game's ladder, in order.
static func ladder(variant: String) -> Array:
	var out: Array = []
	for i in STAGES.size():
		if str(STAGES[i].variant) == variant:
			out.append(i)
	return out

## Stars and clears counted over one ladder ("" = all games).
static func ladder_stars(variant: String, earned: Dictionary) -> int:
	var n := 0
	for s in STAGES:
		if variant == "" or str(s.variant) == variant:
			n += int(earned.get(s.id, 0))
	return n

static func ladder_cleared(variant: String, earned: Dictionary) -> int:
	var n := 0
	for s in STAGES:
		if (variant == "" or str(s.variant) == variant) and int(earned.get(s.id, 0)) >= 1:
			n += 1
	return n

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
