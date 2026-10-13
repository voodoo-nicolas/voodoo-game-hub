extends RefCounted

## One entry point for per-game art drawn in code (APK side, used by the Game Browser):
##   logo   = transparent neon icon (game_icons.gd for the first seven games, then the
##            game_logos*.gd sets, one per category batch)
##   teaser = 16:9 mini scene of the game (game_teasers*.gd sets)
## Real art (hub_art.gd: tile_art / hero_art) is separate and wins where a game has it.
## New category batch: add its two files to LOGO_SETS / TEASER_SETS.
## Plan + batches: docs/claude/hub-v2.md "Game art drawn in code".

const GameIcons = preload("res://scripts/common/game_icons.gd")
const GameLogos = preload("res://scripts/common/game_logos.gd")
const GameLogosArcade = preload("res://scripts/common/game_logos_arcade.gd")
const GameLogosPuzzle = preload("res://scripts/common/game_logos_puzzle.gd")
const GameLogosCards = preload("res://scripts/common/game_logos_cards.gd")
const GameLogosRest = preload("res://scripts/common/game_logos_rest.gd")
const GameTeasers = preload("res://scripts/common/game_teasers.gd")
const GameTeasersArcade = preload("res://scripts/common/game_teasers_arcade.gd")
const GameTeasersPuzzle = preload("res://scripts/common/game_teasers_puzzle.gd")
const GameTeasersCards = preload("res://scripts/common/game_teasers_cards.gd")
const GameTeasersRest = preload("res://scripts/common/game_teasers_rest.gd")

const LOGO_SETS := [GameLogos, GameLogosArcade, GameLogosPuzzle, GameLogosCards, GameLogosRest]
const TEASER_SETS := [GameTeasers, GameTeasersArcade, GameTeasersPuzzle, GameTeasersCards, GameTeasersRest]

static func has_logo(id: String) -> bool:
	for s in LOGO_SETS:
		if s.has(id):
			return true
	return GameIcons.has(id)

## Draws the logo scaled into Control `c` (call from its `draw` signal).
static func draw_logo(c: Control, id: String) -> void:
	for s in LOGO_SETS:
		if s.has(id):
			s.draw(c, id)
			return
	GameIcons.draw(c, id)

static func has_teaser(id: String) -> bool:
	for s in TEASER_SETS:
		if s.has(id):
			return true
	return false

static func draw_teaser(c: Control, id: String) -> void:
	for s in TEASER_SETS:
		if s.has(id):
			s.draw(c, id)
			return
