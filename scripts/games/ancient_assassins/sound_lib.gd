extends RefCounted

## Shared sound library (media/common/sfx/; catalog: docs/claude/sfx-library.md):
## real recordings -- cards, chips, dice, impacts, footsteps, doors, lasers,
## engines, an announcer voice, ambience -- that any game can play.
##
## GENERATED: `python tools/hub.py sync` copies tools/templates/sound_lib.gd to
## scripts/games/<id>/sound_lib.gd for every game that uses it. Edit the
## template, never a copy -- `hub.py check` fails if a copy differs.
##
##     const SoundLib = preload("res://scripts/games/<id>/sound_lib.gd")
##     SoundLib.play(self, "casino/card_slide")      # one of its 8 takes, at random
##     SoundLib.play(self, "voice/fight", -3.0)      # volume_db relative to normal
##     var rain := SoundLib.loop(self, "weather/thunder_rain", -10.0)
##     rain.queue_free()                             # stops the loop
##
## A sound id is "<set>/<name>": the file <name>.ogg, or, for a sound with
## several takes, <name>_1.ogg, <name>_2.ogg... (never the same take twice in
## a row). **Write every id as a full string literal** in the game's scripts
## ("casino/chip_lay", not "casino/" + kind): `sync` finds them there and puts
## exactly those files in the game's pack, so they play on every app version
## and the APK stays small. `hub.py check` fails on an id that isn't in the
## library.
##
## Sounds play through the Sfx autoload's play_stream(), so the player's sound
## settings apply (group "game" unless told otherwise: taps / game / results
## / alerts). Apps without Sfx (before v0.23) stay silent. A loop reads the
## group's volume when it starts and pauses with the game.

const DIR := "res://media/common/sfx/"
## The same sound again within this many ms is skipped (no stacking), as Sfx.
const REPEAT_GAP_MS := 35

static var _takes: Dictionary = {}  # id -> Array of paths
static var _last_take: Dictionary = {}  # id -> index played last
static var _last_ms: Dictionary = {}  # id -> Time.get_ticks_msec() of last play

## Plays one take of a sound once.
static func play(node: Node, id: String, volume_db: float = 0.0, group: String = "game", pitch: float = 1.0) -> void:
	var sfx = node.get_node_or_null("/root/Sfx")
	if sfx == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(id, -100000)) < REPEAT_GAP_MS:
		return
	_last_ms[id] = now
	var stream := stream_for(id)
	if stream:
		sfx.play_stream(stream, volume_db, pitch, group)

## Starts a sound looping on a new AudioStreamPlayer child of `node` (freed
## with it; queue_free() it to stop). Returns it even when the sound is off
## or missing, so callers never check for null.
static func loop(node: Node, id: String, volume_db: float = 0.0, group: String = "game") -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	node.add_child(player)
	var stream := stream_for(id)
	if stream == null or node.get_node_or_null("/root/Sfx") == null:
		return player
	var settings = node.get_node_or_null("/root/Settings")
	if settings and settings.has_method("group_db"):
		var extra = settings.group_db(group)
		if extra == null:
			return player
		volume_db += float(extra)
	stream = stream.duplicate()
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	player.stream = stream
	player.volume_db = volume_db
	player.play()
	return player

## One take of a sound (null if it isn't there).
static func stream_for(id: String) -> AudioStream:
	var paths := takes(id)
	if paths.is_empty():
		return null
	var i := 0
	if paths.size() > 1:
		var last := int(_last_take.get(id, -1))
		if last == -1:
			i = randi() % paths.size()
		else:
			i = randi() % (paths.size() - 1)
			if i >= last:
				i += 1
	_last_take[id] = i
	return load(paths[i])

## Every take of a sound, as res:// paths.
static func takes(id: String) -> Array:
	if _takes.has(id):
		return _takes[id]
	var found := []
	var base := DIR + id
	if ResourceLoader.exists(base + ".ogg"):
		found.append(base + ".ogg")
	else:
		var n := 1
		while ResourceLoader.exists("%s_%d.ogg" % [base, n]):
			found.append("%s_%d.ogg" % [base, n])
			n += 1
	if found.is_empty():
		push_warning("SoundLib: no sound '%s'" % id)
	_takes[id] = found
	return found
