extends Node

## Autoload `Music` (since v0.31): background music on the "Music" bus, with
## crossfades, looping and ducking. Settings owns the bus volume and on/off
## (Options "🎵 Music"); this only chooses what plays.
##
## Games never reference `Music` directly (packs also run on apps from
## before v0.31, which simply stay quiet):
##
##     func _music(track: String) -> void:
##         var m = get_node_or_null("/root/Music")
##         if m:
##             m.play_track(track, ID, CATEGORY)
##
## Tracks live in the media tiers (STANDARDS §10), searched most specific
## first, so a game can override a shared track by giving its own file the
## same name:
##   3 game      res://games/<game_id>/music/<name>.ogg   (the game's pack)
##   2 category  res://media/cat/<category>/music/<name>.ogg
##   1 common    res://media/common/music/<name>.ogg      (media-common pack)
##   0 hub       res://media/hub/music/<name>.ogg         (in the APK)
## A track that isn't there (pack not downloaded, old manifest) is skipped:
## play_track() returns false and whatever was playing keeps playing.
##
## - play(stream) / play_track(name): crossfade to it; the same track again
##   is a no-op, so screens can call it freely on _ready.
## - stop(fade): fade out.
## - duck(sec): dip under an important sound (Sfx does this for results and
##   alerts), then come back up. A plain volume dip, not a compressor:
##   predictable and cheap.
## - Music keeps playing while the tree is paused (pause menus, GameInfo).
## - Every track loops (OGG import settings pick the loop point:
##   loop_offset, STANDARDS §10 "Music prep").

const BUS := "Music"
const FADE_SEC := 1.2
## How far the music dips under an important sound, and how fast.
const DUCK_DB := -12.0
const DUCK_DOWN_PER_SEC := 10.0
const DUCK_UP_PER_SEC := 2.0
const EXTS := ["ogg", "wav", "mp3"]

## The res:// path (or resource_path) of what's playing, "" when quiet.
var current: String = ""

var _players: Array[AudioStreamPlayer] = []
var _gain: Array[float] = [0.0, 0.0]     # linear 0..1, per player
var _target: Array[float] = [0.0, 0.0]
var _rate: Array[float] = [1.0, 1.0]     # gain per second while fading
var _base_db: Array[float] = [0.0, 0.0]  # the track's own level
var _front := 0
var _duck_left := 0.0
var _duck := 0.0  # 0 = full volume, 1 = fully ducked

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	preload("res://scripts/common/settings.gd").ensure_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)

## The res:// path of a track in the most specific tier that has it, or "".
static func find_track(track: String, game_id: String = "", category: String = "") -> String:
	var dirs: Array[String] = []
	if game_id != "":
		dirs.append("res://games/%s/music/" % game_id)
	if category != "":
		dirs.append("res://media/cat/%s/music/" % category)
	dirs.append("res://media/common/music/")
	dirs.append("res://media/hub/music/")
	for d in dirs:
		for ext in EXTS:
			var path: String = d + track + "." + ext
			if ResourceLoader.exists(path):
				return path
	return ""

## Crossfades to a named track from the tiers. False if no tier has it.
func play_track(track: String, game_id: String = "", category: String = "", volume_db: float = 0.0) -> bool:
	var path := find_track(track, game_id, category)
	if path == "":
		return false
	if path == current and is_playing():
		return true
	var stream = load(path)
	if not stream is AudioStream:
		return false
	play(stream, FADE_SEC, volume_db)
	return true

## Crossfades to any stream (e.g. one a game made itself).
func play(stream: AudioStream, fade: float = FADE_SEC, volume_db: float = 0.0) -> void:
	if stream == null or _players.is_empty():
		return
	var key := stream.resource_path if stream.resource_path != "" else str(stream.get_instance_id())
	if key == current and is_playing():
		return
	if "loop" in stream:
		stream.set("loop", true)
	var old := _front
	_front = 1 - _front
	var p := _players[_front]
	p.stream = stream
	_base_db[_front] = volume_db
	_gain[_front] = 0.0
	_fade(_front, 1.0, fade)
	_fade(old, 0.0, fade)
	_apply_volumes()
	p.play()
	current = key

func stop(fade: float = FADE_SEC) -> void:
	for i in _players.size():
		_fade(i, 0.0, fade)
	current = ""

func is_playing() -> bool:
	return current != "" and _players[_front].playing

## Dips the music for `sec` seconds (plus the time to come back up).
func duck(sec: float = 1.0) -> void:
	_duck_left = maxf(_duck_left, clampf(sec, 0.2, 4.0))

func _fade(i: int, to: float, sec: float) -> void:
	_target[i] = to
	_rate[i] = 1000.0 if sec <= 0.0 else 1.0 / sec

func _process(delta: float) -> void:
	for i in _players.size():
		_gain[i] = move_toward(_gain[i], _target[i], _rate[i] * delta)
		if _gain[i] <= 0.0 and _target[i] <= 0.0 and _players[i].playing:
			_players[i].stop()
			_players[i].stream = null
	_duck_left = maxf(_duck_left - delta, 0.0)
	var want := 1.0 if _duck_left > 0.0 else 0.0
	_duck = move_toward(_duck, want, delta * (DUCK_DOWN_PER_SEC if want > _duck else DUCK_UP_PER_SEC))
	_apply_volumes()

func _apply_volumes() -> void:
	for i in _players.size():
		_players[i].volume_db = linear_to_db(maxf(_gain[i], 0.0001)) + _base_db[i] + DUCK_DB * _duck
