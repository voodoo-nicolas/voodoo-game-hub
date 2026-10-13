extends RefCounted

## One entry point for per-game art drawn in code (APK side, used by the Game Browser):
##   logo   = transparent neon icon (game_icons.gd for the first seven games, game_logos.gd for the rest)
##   teaser = 16:9 mini scene of the game (game_teasers.gd)
## Real art (hub_art.gd: tile_art / hero_art) is separate and wins where a game has it.
## Plan + batches: docs/claude/hub-v2.md "Game art".

const GameIcons = preload("res://scripts/common/game_icons.gd")
const GameLogos = preload("res://scripts/common/game_logos.gd")
const GameTeasers = preload("res://scripts/common/game_teasers.gd")

static func has_logo(id: String) -> bool:
	return GameLogos.has(id) or GameIcons.has(id)

## Draws the logo scaled into Control `c` (call from its `draw` signal).
static func draw_logo(c: Control, id: String) -> void:
	if GameLogos.has(id):
		GameLogos.draw(c, id)
	else:
		GameIcons.draw(c, id)

static func has_teaser(id: String) -> bool:
	return GameTeasers.has(id)

static func draw_teaser(c: Control, id: String) -> void:
	GameTeasers.draw(c, id)
