extends RefCounted
## Every sound and music cue in Hesperia, in one place.
## In the hub: real recordings from the shared library (media/common/sfx/) through the game's copy of the
## hub template sound_lib.gd; `hub.py sync` packs exactly the ids written below, so keep every id a full
## string literal ("impact/footstep_grass", never "impact/" + x). Music comes from the hub's Music autoload.
## Standalone (no hub autoloads): everything is silent, nothing breaks.
## The port tool (tools/port_to_hub.py) places this file at scripts/games/hesperia/hesperia_sounds.gd.

const LIB_PATH := "res://scripts/games/hesperia/sound_lib.gd"

static var _lib = null
static var _tried: bool = false

static func _play(node: Node, id: String, db: float = 0.0, pitch: float = 1.0) -> void:
	if node == null or not node.is_inside_tree():
		return
	if not _tried:
		_tried = true
		if ResourceLoader.exists(LIB_PATH):
			_lib = load(LIB_PATH)
	if _lib != null:
		_lib.play(node, id, db, "game", pitch)

static func _vary() -> float:
	return randf_range(0.92, 1.08)

# ---------------------------------------------------------------- hero
static func step(node: Node, ground: String) -> void:
	match ground:
		"sand":
			_play(node, "impact/footstep_snow", -17.0, _vary())
		"wood":
			_play(node, "impact/footstep_wood", -15.0, _vary())
		"stone":
			_play(node, "impact/footstep_concrete", -16.0, _vary())
		"wet":
			_play(node, "impact/footstep_carpet", -14.0, _vary() * 0.85)
		_:
			_play(node, "impact/footstep_grass", -16.0, _vary())

static func swing(node: Node) -> void:
	_play(node, "rpg/cloth", -6.0, randf_range(1.35, 1.55))

static func hit(node: Node) -> void:
	_play(node, "impact/punch_medium", -4.0, _vary())

static func block(node: Node) -> void:
	_play(node, "impact/metal_light", -5.0, _vary())

static func hurt(node: Node) -> void:
	_play(node, "impact/punch_heavy", -3.0, 0.9)

static func fire(node: Node) -> void:
	_play(node, "rpg/chop", -8.0, 0.6)

# ---------------------------------------------------------------- world
static func enemy_die(node: Node) -> void:
	_play(node, "creature/hurt", -6.0, randf_range(1.3, 1.5))

static func boss_hit(node: Node) -> void:
	_play(node, "impact/plate_heavy", -4.0, _vary())

static func boss_down(node: Node) -> void:
	_play(node, "jingles/win_victory", -2.0)

static func coin(node: Node) -> void:
	_play(node, "reward/coin_short", -6.0, _vary())

static func heart(node: Node) -> void:
	_play(node, "reward/coin_plingy", -6.0, 1.2)

static func chest(node: Node) -> void:
	_play(node, "rpg/creak", -4.0)
	_play(node, "reward/powerup", -6.0)

static func door(node: Node) -> void:
	_play(node, "rpg/door_open", -6.0, _vary())

static func push(node: Node) -> void:
	_play(node, "impact/mining", -6.0, 0.7)

static func gate(node: Node) -> void:
	_play(node, "rpg/metal_latch", -3.0, 0.8)

static func died(node: Node) -> void:
	_play(node, "jingles/lose_failed", -3.0)

static func quest(node: Node) -> void:
	_play(node, "reward/accomplished", -5.0)

# ---------------------------------------------------------------- UI
static func page(node: Node) -> void:
	_play(node, "rpg/book_flip", -10.0, _vary())

static func menu_open(node: Node) -> void:
	_play(node, "rpg/book_open", -6.0)

static func menu_close(node: Node) -> void:
	_play(node, "rpg/book_close", -6.0)

static func buy(node: Node) -> void:
	_play(node, "rpg/handle_coins", -5.0)

# ---------------------------------------------------------------- music (hub Music autoload: calm / lively / techno)
static func music(node: Node, style: String) -> void:
	if node == null or not node.is_inside_tree():
		return
	var m = node.get_node_or_null("/root/Music")
	if m != null and m.has_method("play"):
		m.play(style, node)
