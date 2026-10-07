extends Node

## Neon Blast's own sound kit (in the pack, so it works on any app version;
## the app's shared Sfx library is too small and has too few voices for a
## shooter) and its adaptive music director.
##
## The effects are synthesized in code on a worker thread the first time the
## game opens, then kept on disk (CACHE_DIR) and in static vars, so later
## launches and going Home and back don't redo it.
##
## Music comes from the hub's shared library (the Music autoload, apps from
## v0.33; older apps play none) -- the game never makes or ships its own
## (STANDARDS §10). The library's three styles are the intensity tiers:
##   calm    few enemies around
##   lively  the screen is filling up
##   techno  swarmed, or a boss is out
## The game calls set_intensity() every frame with how crowded it is; the
## director asks Music for the matching style (quick to step up, slow to
## calm down), moves on to the style's next track now and then, and
## reset_calm() (the player died: the screen is empty again) goes straight
## back to calm. The player's 🎵 Music switch and volume are the app-wide
## ones (⚙ Options → Sound); the genres the owner set for Neon Blast in
## Music Drop apply.
##
## Loops: "hum" (an awake gravity well nearby) and "skitter" (protons loose)
## play continuously at a volume the game sets with set_loop().
## duck(): the "deafening silence" after a well bursts -- the effects and
## loops drop out, then fade back in. The music plays on: the Music library
## has no duck.

const RATE := 22050
const VOICES := 16
const TIERS := ["calm", "lively", "techno"]

const FADE_UP := 2.0
const FADE_DOWN := 3.5
## Intensity (weighted enemies near the ship) where each tier starts.
const LIVELY_AT := 12.0
const TECHNO_AT := 30.0
## A tier must be wanted this long before the music moves to it.
const HOLD_UP := 1.2
const HOLD_DOWN := 6.0
## Move on to the tier's next track after this long.
const SWAP_AFTER := 100.0

const LOOPS := ["hum", "skitter"]

static var _cache := {}  # key -> AudioStreamWAV (effects, loops)
static var _lock := Mutex.new()
static var _task := -1
static var _cancel := false

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_ms := {}
var _loop_players := {}
var _loop_target := {}

var _playing := false      # a game is on and wants music
var _tier := ""            # the style last asked of Music
var _want_tier := "calm"
var _want_t := 0.0
var _tier_t := 0.0
var _duck_t := 0.0
var _duck_len := 0.0

func _ready() -> void:
	var bus := "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_players.append(p)
	for key in LOOPS:
		var l := AudioStreamPlayer.new()
		l.bus = bus
		l.volume_db = -80.0
		add_child(l)
		_loop_players[key] = l
		_loop_target[key] = 0.0
	_start_render()

func _exit_tree() -> void:
	# Rendering carries on next time the game opens (finished items are kept).
	if _task != -1:
		_cancel = true
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_cancel = false

# ---------- effects ----------

## Plays an effect. `pitch` shifts it (chains of pickups climb), `gap_ms`
## skips repeats of the same sound closer than that.
func play(key: String, volume_db: float = 0.0, pitch: float = 1.0, gap_ms: int = 30) -> void:
	if _duck_t > 0.0 and _duck_len - _duck_t > 0.08:
		return  # the silence after a well bursts
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(key, -100000)) < gap_ms:
		return
	var stream := _stream_of(key)
	if stream == null:
		return
	var extra = _group_db("game")
	if extra == null:
		return
	_last_ms[key] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db + float(extra)
	p.pitch_scale = pitch
	p.play()

## A continuous loop ("hum", "skitter") at `level` 0..1 (0 = silent).
func set_loop(key: String, level: float) -> void:
	_loop_target[key] = clampf(level, 0.0, 1.0)

## Everything drops out for `seconds`, then fades back over ~2 s.
func duck(seconds: float) -> void:
	_duck_len = seconds
	_duck_t = seconds

func silence_loops() -> void:
	for key in LOOPS:
		_loop_target[key] = 0.0
		(_loop_players[key] as AudioStreamPlayer).volume_db = -80.0

func _group_db(group: String):
	var s = get_node_or_null("/root/Settings")
	if s and s.has_method("group_db"):
		return s.group_db(group)
	return 0.0

func _stream_of(key: String) -> AudioStreamWAV:
	_lock.lock()
	var s: AudioStreamWAV = _cache.get(key)
	_lock.unlock()
	return s

func _process(delta: float) -> void:
	if _task != -1 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	var duck_db := 0.0
	if _duck_t > 0.0:
		_duck_t = maxf(0.0, _duck_t - delta)
		duck_db = -60.0
	elif _duck_len > 0.0:
		# Fading back in after the silence.
		_duck_len = maxf(0.0, _duck_len - delta * 0.5)
		duck_db = -24.0 * _duck_len
	var game_db = _group_db("game")
	for key in LOOPS:
		var p: AudioStreamPlayer = _loop_players[key]
		var lvl: float = _loop_target[key]
		if lvl <= 0.001 or game_db == null:
			if p.playing:
				p.volume_db = move_toward(p.volume_db, -80.0, delta * 60.0)
				if p.volume_db <= -79.0:
					p.stop()
			continue
		if not p.playing:
			var st := _stream_of(key)
			if st == null:
				continue
			p.stream = st
			p.volume_db = -60.0
			p.play()
		var want: float = linear_to_db(lvl) - 6.0 + float(game_db) + duck_db
		# Loops fade in slowly ("faint skittering fading in").
		p.volume_db = move_toward(p.volume_db, want, delta * (8.0 if want > p.volume_db else 40.0))
	_update_music(delta)

# ---------- music (the hub's Music library) ----------

## A game starts: calm music first.
func start_music() -> void:
	_playing = true
	_want_tier = "calm"
	_want_t = 0.0
	_switch("calm", 1.5)

## The game ended (or the campaign map opened): fade the music out. Does
## nothing when no game music is on, so it never stops music it didn't start.
func stop_music(fade: float = 1.5) -> void:
	if not _playing:
		return
	_playing = false
	_tier = ""
	var m := _music_node()
	if m:
		m.stop(fade)

## How crowded it is right now (the game's weighted enemy count).
func set_intensity(v: float) -> void:
	var want := "calm"
	if v >= TECHNO_AT:
		want = "techno"
	elif v >= LIVELY_AT:
		want = "lively"
	# Hysteresis: stay in the current tier until clearly below it.
	if _tier == "techno" and want != "techno" and v >= TECHNO_AT * 0.7:
		want = "techno"
	elif _tier == "lively" and want == "calm" and v >= LIVELY_AT * 0.65:
		want = "lively"
	if want != _want_tier:
		_want_tier = want
		_want_t = 0.0

## The player died and the screen was cleared: straight back to calm.
func reset_calm() -> void:
	_want_tier = "calm"
	_want_t = 0.0
	if _playing and _tier != "calm":
		_switch("calm", 1.2)

func _update_music(delta: float) -> void:
	if not _playing:
		return
	_want_t += delta
	_tier_t += delta
	if _want_tier != _tier:
		var up: bool = TIERS.find(_want_tier) > TIERS.find(_tier)
		if _want_t >= (HOLD_UP if up else HOLD_DOWN):
			_switch(_want_tier, FADE_UP if up else FADE_DOWN)
	elif _tier_t >= SWAP_AFTER:
		_switch(_tier, 4.0)

## Asks Music for `tier` (its style of the same name), crossfading over
## `fade` s. Index -1 = that style's next track, so coming back to a tier
## (or the SWAP_AFTER move) brings another one. Music fades out by itself
## when the game's scene leaves (🏠 Home, the hub, a reload).
func _switch(tier: String, fade: float) -> void:
	_tier = tier
	_tier_t = 0.0
	var m := _music_node()
	if m:
		m.play(tier, get_parent(), -1, fade)

## The hub's Music autoload (apps from v0.33), or null: older apps simply
## play no music, so the pack needs no min_build.
func _music_node() -> Node:
	return get_node_or_null("/root/Music") if is_inside_tree() else null

# ---------- synthesis (worker thread) ----------

func _start_render() -> void:
	if _task != -1:
		return
	var need := false
	_lock.lock()
	need = _cache.size() < _recipe_names().size() + LOOPS.size()
	_lock.unlock()
	if need:
		_task = WorkerThreadPool.add_task(_render_all)

static func _recipe_names() -> Array:
	return ["shot", "pop_s", "pop_m", "pop_l", "pop_tiny", "geom", "mult", "extra_bomb", "extra_life",
		"bomb", "death", "respawn", "shield_beep", "gate_boom", "gold_ping", "mine_drop", "mine_boom",
		"well_wake", "well_gulp", "well_pop", "repulsor_charge", "repulsor_block", "boss_warn", "boss_hit",
		"boss_block", "boss_part", "boss_phase", "boss_die", "snipe", "ram", "zone_on", "zone_off",
		"tick", "level_start", "level_clear", "level_fail", "drone_shot", "enemy_shot",
		"spawn_grunt", "spawn_wanderer", "spawn_weaver", "spawn_spinner", "spawn_snake", "spawn_well",
		"spawn_rocket", "spawn_mayfly", "spawn_repulsor", "spawn_ufo", "spawn_nufo", "spawn_gate",
		"spawn_layer", "spawn_neutron", "spawn_duck", "spawn_gear",
		"beam_charge", "beam_fire", "shield_up", "shield_down", "tail_rattle", "whip", "snap"]

static func _render_all() -> void:
	for key in _recipe_names() + LOOPS:
		if _cancel:
			return
		_lock.lock()
		var have := _cache.has(key)
		_lock.unlock()
		if have:
			continue
		var path := CACHE_DIR + "fx_%s_v%d.pcm" % [key, FX_VERSION]
		var s: AudioStreamWAV = _load_pcm(path, key in LOOPS)
		if s == null:
			s = _render_loop(key) if key in LOOPS else _render_voices(_recipe(key))
			if s == null:
				continue
			_save_pcm(path, s)
		_lock.lock()
		_cache[key] = s
		_lock.unlock()

## Rendered sounds are kept in user://, so only the first launch synthesizes
## them. The folder's name is from when the game also made its own music:
## those old tracks (<tier>_<n>_v1.pcm, up to 12 files, ~9 MB) stay there
## -- it is the player's data. Bump FX_VERSION whenever a recipe changes.
const CACHE_DIR := "user://geometry_wars_music/"
const FX_VERSION := 1

static func _load_pcm(path: String, loop: bool) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		return null
	var data := FileAccess.get_file_as_bytes(path)
	if data.size() < 64:
		return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = data.size() / 2
	return wav

static func _save_pcm(path: String, wav: AudioStreamWAV) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(wav.data)
	f.close()
	DirAccess.rename_absolute(path + ".tmp", path)

## Recipes in the app's Sfx format: an Array of voices, each
## {t: sine|tri|square|saw|noise, at, len, vol, f, f2, atk, dec, lp, lp2, hp, swell}.
static func _recipe(key: String) -> Array:
	match key:
		"shot":
			return [{"t": "square", "f": 1900, "f2": 700, "len": 0.045, "dec": 45, "vol": 0.07},
				{"t": "noise", "len": 0.02, "dec": 120, "lp": 0.6, "hp": true, "vol": 0.12}]
		"drone_shot":
			return [{"t": "square", "f": 2400, "f2": 1100, "len": 0.035, "dec": 60, "vol": 0.05}]
		"enemy_shot":
			return [{"t": "tri", "f": 600, "f2": 300, "len": 0.08, "dec": 25, "vol": 0.18}]
		"pop_tiny":
			return [{"t": "noise", "len": 0.05, "dec": 60, "lp": 0.7, "lp2": 0.2, "vol": 0.25},
				{"t": "sine", "f": 1400, "f2": 700, "len": 0.04, "dec": 60, "vol": 0.1}]
		"pop_s":
			return [{"t": "noise", "len": 0.22, "dec": 16, "lp": 0.7, "lp2": 0.06, "vol": 0.42},
				{"t": "sine", "f": 700, "f2": 160, "len": 0.1, "dec": 25, "vol": 0.2}]
		"pop_m":
			return [{"t": "noise", "len": 0.4, "dec": 9, "lp": 0.8, "lp2": 0.04, "vol": 0.5},
				{"t": "sine", "f": 320, "f2": 70, "len": 0.25, "dec": 12, "vol": 0.35},
				{"t": "square", "f": 900, "f2": 200, "len": 0.08, "dec": 30, "vol": 0.06}]
		"pop_l":
			return [{"t": "noise", "len": 0.9, "dec": 4.5, "lp": 0.9, "lp2": 0.02, "vol": 0.6},
				{"t": "sine", "f": 160, "f2": 35, "len": 0.6, "dec": 6, "vol": 0.55},
				{"t": "noise", "at": 0.05, "len": 0.5, "dec": 8, "lp": 0.3, "hp": true, "vol": 0.18}]
		"geom":
			return [{"t": "sine", "f": 2093, "f2": 2637, "len": 0.06, "dec": 35, "vol": 0.16},
				{"t": "tri", "f": 4186, "len": 0.04, "dec": 60, "vol": 0.05}]
		"mult":
			return _notes("square", [880.0, 1108.7, 1318.5, 1760.0], 0.05, 0.25, 0.08) \
				+ _notes("sine", [1760.0, 2217.5, 2637.0, 3520.0], 0.05, 0.3, 0.07)
		"extra_bomb":
			return [{"t": "square", "f": 220, "f2": 880, "len": 0.3, "dec": 4, "vol": 0.12},
				{"t": "sine", "f": 440, "f2": 1760, "len": 0.3, "dec": 4, "vol": 0.14},
				{"t": "sine", "f": 1760, "at": 0.3, "len": 0.35, "dec": 8, "vol": 0.15}]
		"extra_life":
			return _notes("tri", [523.3, 659.3, 784.0, 1046.5, 1318.5], 0.07, 0.5, 0.3)
		"bomb":
			var v: Array = [
				{"t": "noise", "len": 2.4, "dec": 1.6, "lp": 0.95, "lp2": 0.015, "vol": 0.75},
				{"t": "sine", "f": 90, "f2": 22, "len": 1.8, "dec": 2.0, "vol": 0.8},
				{"t": "saw", "f": 220, "f2": 30, "len": 1.2, "dec": 3.0, "vol": 0.12},
				{"t": "tri", "f": 196, "len": 2.0, "dec": 2.2, "vol": 0.06},
				{"t": "tri", "f": 207.7, "len": 2.0, "dec": 2.2, "vol": 0.06},
			]
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for i in 40:  # crackle as the shockwave rolls out
				v.append({"t": "noise", "at": 0.1 + rng.randf() * 1.6, "len": 0.012, "dec": 250, "lp": 0.8, "hp": true,
					"vol": rng.randf_range(0.15, 0.35)})
			return v
		"death":
			# The player's ship going up: a glassy shatter, a falling zap, a
			# sub boom, sparks crackling out and an eerie ring that hangs on.
			var v: Array = [
				{"t": "noise", "len": 1.5, "dec": 3.0, "lp": 0.95, "lp2": 0.02, "vol": 0.55},
				{"t": "saw", "f": 1800, "f2": 45, "len": 1.1, "dec": 2.6, "vol": 0.17},
				{"t": "square", "f": 950, "f2": 35, "len": 0.8, "dec": 3.2, "vol": 0.07},
				{"t": "sine", "f": 120, "f2": 26, "len": 1.3, "dec": 2.8, "vol": 0.6},
				{"t": "tri", "f": 523.3, "at": 0.05, "len": 1.8, "dec": 1.8, "vol": 0.07},
				{"t": "tri", "f": 554.4, "at": 0.05, "len": 1.8, "dec": 1.8, "vol": 0.07},
				{"t": "sine", "f": 3136, "f2": 1568, "at": 0.02, "len": 0.5, "dec": 6, "vol": 0.05},
			]
			for i in 6:  # the glass shatter
				v.append({"t": "noise", "at": i * 0.035, "len": 0.07, "dec": 45, "lp": 0.15, "hp": true, "vol": 0.42 - i * 0.05})
			var rng := RandomNumberGenerator.new()
			rng.seed = 9
			for i in 34:  # sparks
				var at := 0.15 + rng.randf() * 1.2
				v.append({"t": "noise", "at": at, "len": 0.01, "dec": 300, "lp": 0.7, "hp": true,
					"vol": rng.randf_range(0.12, 0.3) * (1.4 - at)})
			return v
		"respawn":
			return [{"t": "sine", "f": 300, "f2": 1200, "len": 0.5, "dec": 3, "vol": 0.18},
				{"t": "tri", "f": 600, "f2": 2400, "len": 0.5, "dec": 3, "vol": 0.08},
				{"t": "noise", "len": 0.5, "swell": true, "lp": 0.05, "lp2": 0.4, "hp": true, "vol": 0.2}]
		"shield_beep":
			return [{"t": "sine", "f": 1760, "len": 0.06, "dec": 30, "vol": 0.28},
				{"t": "square", "f": 1760, "len": 0.04, "dec": 50, "vol": 0.04}]
		"gate_boom":
			return [{"t": "noise", "len": 0.7, "dec": 5.5, "lp": 0.9, "lp2": 0.03, "vol": 0.55},
				{"t": "sine", "f": 140, "f2": 40, "len": 0.5, "dec": 7, "vol": 0.5},
				{"t": "tri", "f": 1318.5, "len": 0.6, "dec": 5, "vol": 0.16},
				{"t": "tri", "f": 1975.5, "at": 0.04, "len": 0.6, "dec": 5, "vol": 0.12}]
		"gold_ping":
			return [{"t": "sine", "f": 2637, "len": 0.08, "dec": 30, "vol": 0.12},
				{"t": "tri", "f": 3951, "len": 0.06, "dec": 45, "vol": 0.05}]
		"mine_drop":
			return [{"t": "square", "f": 260, "f2": 200, "len": 0.05, "dec": 50, "vol": 0.08},
				{"t": "noise", "len": 0.02, "dec": 150, "lp": 0.4, "vol": 0.2}]
		"mine_boom":
			return [{"t": "sine", "f": 110, "f2": 30, "len": 0.5, "dec": 7, "vol": 0.7},
				{"t": "noise", "len": 0.6, "dec": 6, "lp": 0.6, "lp2": 0.03, "vol": 0.5},
				{"t": "square", "f": 400, "f2": 80, "len": 0.15, "dec": 20, "vol": 0.08}]
		"well_wake":
			return [{"t": "sine", "f": 70, "f2": 320, "len": 0.5, "dec": 2.5, "vol": 0.45},
				{"t": "saw", "f": 35, "f2": 160, "len": 0.5, "dec": 2.5, "vol": 0.08}]
		"well_gulp":
			return [{"t": "sine", "f": 240, "f2": 55, "len": 0.16, "dec": 14, "vol": 0.45},
				{"t": "sine", "f": 600, "f2": 1100, "at": 0.06, "len": 0.05, "dec": 40, "vol": 0.12}]
		"well_pop":
			# A big wet bubble popping: the plip, the bloop, a splash, a thump.
			return [{"t": "sine", "f": 160, "f2": 1100, "len": 0.05, "dec": 25, "vol": 0.7},
				{"t": "sine", "f": 1000, "f2": 220, "at": 0.035, "len": 0.17, "dec": 16, "vol": 0.42},
				{"t": "sine", "f": 1600, "f2": 600, "at": 0.06, "len": 0.08, "dec": 35, "vol": 0.15},
				{"t": "noise", "at": 0.02, "len": 0.3, "dec": 12, "lp": 0.55, "lp2": 0.04, "vol": 0.35},
				{"t": "sine", "f": 75, "f2": 35, "len": 0.35, "dec": 9, "vol": 0.6}]
		"repulsor_charge":
			return [{"t": "saw", "f": 90, "f2": 420, "len": 0.35, "dec": 3, "vol": 0.12},
				{"t": "noise", "len": 0.35, "swell": true, "lp": 0.05, "lp2": 0.3, "vol": 0.3}]
		"repulsor_block":
			return [{"t": "tri", "f": 900, "f2": 700, "len": 0.05, "dec": 50, "vol": 0.12}]
		"boss_warn":
			var v: Array = []
			for i in 3:
				v.append({"t": "square", "f": 440, "at": i * 0.5, "len": 0.24, "dec": 2, "vol": 0.1})
				v.append({"t": "square", "f": 330, "at": i * 0.5 + 0.25, "len": 0.24, "dec": 2, "vol": 0.1})
			v.append({"t": "sine", "f": 55, "len": 1.5, "dec": 1, "vol": 0.35})
			return v
		"boss_hit":
			return [{"t": "tri", "f": 1300, "len": 0.06, "dec": 40, "vol": 0.1},
				{"t": "tri", "f": 1750, "len": 0.05, "dec": 50, "vol": 0.07},
				{"t": "noise", "len": 0.03, "dec": 100, "lp": 0.5, "hp": true, "vol": 0.12}]
		"boss_block":
			return [{"t": "square", "f": 180, "f2": 150, "len": 0.05, "dec": 50, "vol": 0.08}]
		"boss_part":
			return [{"t": "noise", "len": 0.6, "dec": 6, "lp": 0.9, "lp2": 0.04, "vol": 0.5},
				{"t": "sine", "f": 200, "f2": 50, "len": 0.4, "dec": 8, "vol": 0.45},
				{"t": "tri", "f": 1046.5, "len": 0.4, "dec": 8, "vol": 0.12},
				{"t": "tri", "f": 1108.7, "len": 0.4, "dec": 8, "vol": 0.1}]
		"boss_phase":
			return [{"t": "saw", "f": 70, "f2": 45, "len": 1.2, "dec": 1.5, "vol": 0.2},
				{"t": "saw", "f": 73, "f2": 47, "len": 1.2, "dec": 1.5, "vol": 0.2},
				{"t": "noise", "len": 1.2, "swell": true, "lp": 0.04, "lp2": 0.15, "vol": 0.5},
				{"t": "sine", "f": 40, "len": 1.2, "dec": 1.2, "vol": 0.5}]
		"boss_die":
			var v: Array = [
				{"t": "noise", "len": 3.2, "dec": 1.1, "lp": 0.95, "lp2": 0.01, "vol": 0.8},
				{"t": "sine", "f": 80, "f2": 20, "len": 2.6, "dec": 1.3, "vol": 0.8},
				{"t": "saw", "f": 300, "f2": 25, "len": 1.8, "dec": 2, "vol": 0.12},
			]
			v.append_array(_notes("tri", [523.3, 659.3, 784.0, 1046.5, 1318.5, 1568.0], 0.12, 1.4, 0.16))
			for i in 6:
				v.append({"t": "noise", "at": 0.3 + i * 0.25, "len": 0.5, "dec": 7, "lp": 0.7, "lp2": 0.03, "vol": 0.35})
			return v
		"beam_charge":
			# The Watcher opening to aim: a rising whine under a hiss.
			return [{"t": "saw", "f": 180, "f2": 1400, "len": 1.3, "dec": 0.4, "vol": 0.09},
				{"t": "sine", "f": 360, "f2": 2800, "len": 1.3, "dec": 0.4, "vol": 0.08},
				{"t": "noise", "len": 1.3, "swell": true, "lp": 0.05, "lp2": 0.5, "hp": true, "vol": 0.18}]
		"beam_fire":
			# The beam: a hard crack, then a buzzing roar.
			var v: Array = [{"t": "noise", "len": 0.25, "dec": 10, "lp": 0.9, "lp2": 0.1, "vol": 0.55},
				{"t": "saw", "f": 95, "len": 1.0, "dec": 1.8, "vol": 0.2},
				{"t": "saw", "f": 99, "len": 1.0, "dec": 1.8, "vol": 0.2},
				{"t": "square", "f": 190, "f2": 170, "len": 1.0, "dec": 2.2, "vol": 0.06},
				{"t": "noise", "len": 1.0, "dec": 1.6, "lp": 0.35, "hp": true, "vol": 0.2}]
			return v
		"shield_up":
			return [{"t": "sine", "f": 300, "f2": 900, "len": 0.6, "dec": 3, "vol": 0.25},
				{"t": "tri", "f": 600, "f2": 1800, "len": 0.6, "dec": 3, "vol": 0.1},
				{"t": "noise", "len": 0.6, "swell": true, "lp": 0.1, "lp2": 0.4, "hp": true, "vol": 0.15}]
		"shield_down":
			# Glass giving way, then a falling hum.
			var v: Array = [{"t": "sine", "f": 1200, "f2": 120, "len": 1.0, "dec": 2.5, "vol": 0.3},
				{"t": "noise", "len": 0.9, "dec": 4, "lp": 0.9, "lp2": 0.05, "vol": 0.45}]
			for i in 7:
				v.append({"t": "noise", "at": i * 0.04, "len": 0.08, "dec": 40, "lp": 0.2, "hp": true, "vol": 0.4 - i * 0.04})
			return v
		"tail_rattle":
			# The scorpion's tell: a dry rattle that speeds up.
			var v: Array = []
			var at := 0.0
			for i in 12:
				v.append({"t": "noise", "at": at, "len": 0.03, "dec": 90, "lp": 0.5, "hp": true, "vol": 0.35})
				v.append({"t": "square", "f": 900 + i * 40, "at": at, "len": 0.02, "dec": 120, "vol": 0.04})
				at += 0.09 - i * 0.004
			return v
		"whip":
			return [{"t": "noise", "len": 0.3, "dec": 9, "lp": 0.2, "lp2": 0.9, "hp": true, "vol": 0.5},
				{"t": "sine", "f": 900, "f2": 140, "len": 0.25, "dec": 10, "vol": 0.2},
				{"t": "noise", "at": 0.22, "len": 0.15, "dec": 25, "lp": 0.8, "lp2": 0.1, "vol": 0.45}]
		"snap":
			return [{"t": "square", "f": 700, "f2": 300, "len": 0.05, "dec": 60, "vol": 0.1},
				{"t": "noise", "len": 0.06, "dec": 70, "lp": 0.6, "hp": true, "vol": 0.35},
				{"t": "square", "f": 500, "f2": 250, "at": 0.08, "len": 0.04, "dec": 70, "vol": 0.08}]
		"snipe":
			return [{"t": "square", "f": 3200, "f2": 700, "len": 0.12, "dec": 18, "vol": 0.07},
				{"t": "sine", "f": 1600, "f2": 400, "len": 0.12, "dec": 18, "vol": 0.12}]
		"ram":
			return [{"t": "sine", "f": 180, "f2": 60, "len": 0.12, "dec": 25, "vol": 0.4},
				{"t": "noise", "len": 0.06, "dec": 60, "lp": 0.5, "vol": 0.3}]
		"zone_on":
			return _notes("sine", [784.0, 1046.5, 1568.0], 0.06, 0.3, 0.2)
		"zone_off":
			return _notes("sine", [1046.5, 784.0, 523.3], 0.07, 0.3, 0.16)
		"tick":
			return [{"t": "sine", "f": 1320, "len": 0.05, "dec": 40, "vol": 0.25}]
		"level_start":
			return [{"t": "noise", "len": 0.7, "swell": true, "lp": 0.03, "lp2": 0.5, "vol": 0.45}] \
				+ _notes("tri", [440.0, 659.3, 880.0], 0.12, 0.6, 0.18)
		"level_clear":
			return _notes("square", [523.3, 659.3, 784.0, 1046.5, 1318.5, 1568.0, 2093.0], 0.07, 0.8, 0.09) \
				+ _notes("tri", [261.6, 329.6, 392.0, 523.3], 0.14, 0.8, 0.25)
		"level_fail":
			return [{"t": "saw", "f": 392, "f2": 98, "len": 1.3, "dec": 2, "vol": 0.12},
				{"t": "tri", "f": 196, "f2": 49, "len": 1.4, "dec": 1.8, "vol": 0.3}]
		# Spawn calls, one per enemy (you hear what
		# just arrived).
		"spawn_grunt":
			return [{"t": "sine", "f": 330, "f2": 660, "len": 0.12, "dec": 14, "vol": 0.16}]
		"spawn_wanderer":
			return [{"t": "tri", "f": 500, "f2": 950, "len": 0.2, "dec": 8, "vol": 0.16},
				{"t": "tri", "f": 520, "f2": 990, "len": 0.2, "dec": 8, "vol": 0.1}]
		"spawn_weaver":
			return [{"t": "square", "f": 900, "f2": 1350, "len": 0.08, "dec": 20, "vol": 0.07},
				{"t": "square", "f": 1100, "f2": 1600, "at": 0.08, "len": 0.08, "dec": 20, "vol": 0.06}]
		"spawn_spinner":
			return [{"t": "saw", "f": 200, "f2": 900, "len": 0.18, "dec": 8, "vol": 0.1}]
		"spawn_snake":
			return [{"t": "noise", "len": 0.45, "swell": true, "lp": 0.3, "lp2": 0.5, "hp": true, "vol": 0.35}]
		"spawn_well":
			return [{"t": "sine", "f": 90, "f2": 50, "len": 0.7, "dec": 2.5, "vol": 0.45},
				{"t": "saw", "f": 45, "f2": 25, "len": 0.7, "dec": 2.5, "vol": 0.07}]
		"spawn_rocket":
			return [{"t": "noise", "len": 0.25, "swell": true, "lp": 0.08, "lp2": 0.35, "vol": 0.35},
				{"t": "square", "f": 500, "f2": 800, "len": 0.15, "dec": 10, "vol": 0.05}]
		"spawn_mayfly":
			return [{"t": "saw", "f": 140, "f2": 170, "len": 0.35, "dec": 4, "vol": 0.08},
				{"t": "saw", "f": 147, "f2": 180, "len": 0.35, "dec": 4, "vol": 0.08}]
		"spawn_repulsor":
			return [{"t": "saw", "f": 80, "f2": 170, "len": 0.4, "dec": 4, "vol": 0.12},
				{"t": "square", "f": 160, "f2": 340, "len": 0.4, "dec": 4, "vol": 0.05}]
		"spawn_ufo", "spawn_nufo":
			var v: Array = []
			for i in 6:
				v.append({"t": "sine", "f": 900 if i % 2 == 0 else 1200, "at": i * 0.07, "len": 0.08, "dec": 10, "vol": 0.14})
			return v
		"spawn_gate":
			return [{"t": "tri", "f": 1046.5, "len": 0.3, "dec": 9, "vol": 0.13},
				{"t": "tri", "f": 1568.0, "at": 0.05, "len": 0.3, "dec": 9, "vol": 0.1}]
		"spawn_layer":
			return [{"t": "square", "f": 220, "f2": 180, "len": 0.08, "dec": 30, "vol": 0.08},
				{"t": "square", "f": 180, "f2": 150, "at": 0.09, "len": 0.08, "dec": 30, "vol": 0.08}]
		"spawn_neutron":
			return [{"t": "sine", "f": 700, "f2": 1400, "len": 0.1, "dec": 18, "vol": 0.13}]
		"spawn_duck":
			return [{"t": "sine", "f": 500, "f2": 420, "len": 0.08, "dec": 25, "vol": 0.13}]
		"spawn_gear":
			return [{"t": "square", "f": 600, "len": 0.03, "dec": 60, "vol": 0.06},
				{"t": "square", "f": 800, "at": 0.04, "len": 0.03, "dec": 60, "vol": 0.06},
				{"t": "square", "f": 1000, "at": 0.08, "len": 0.03, "dec": 60, "vol": 0.06}]
	return []

static func _notes(wave: String, freqs: Array, step: float, tail: float, vol: float) -> Array:
	var v: Array = []
	for i in freqs.size():
		var last := i == freqs.size() - 1
		v.append({"t": wave, "f": freqs[i], "at": step * i, "len": tail if last else step * 1.6,
			"dec": 5.0 if last else 14.0, "vol": vol})
	return v

static func _render_voices(voices: Array) -> AudioStreamWAV:
	if voices.is_empty():
		return null
	var total_s := 0.0
	for vo in voices:
		total_s = maxf(total_s, float(vo.get("at", 0.0)) + float(vo["len"]))
	var mix := PackedFloat32Array()
	mix.resize(int(total_s * RATE) + 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for vo in voices:
		_add_voice(mix, vo, rng)
	return _to_wav(mix, false)

static func _add_voice(mix: PackedFloat32Array, vo: Dictionary, rng: RandomNumberGenerator) -> void:
	var kind: String = vo["t"]
	var start := int(float(vo.get("at", 0.0)) * RATE)
	var len_s: float = vo["len"]
	var count := int(len_s * RATE)
	var vol: float = vo.get("vol", 0.3)
	var f1: float = vo.get("f", 440.0)
	var f2: float = vo.get("f2", f1)
	var atk: float = maxf(float(vo.get("atk", 0.003)), 0.0005)
	var dec: float = vo.get("dec", 0.0)
	var swell: bool = vo.get("swell", false)
	var lp1: float = vo.get("lp", 1.0)
	var lp2: float = vo.get("lp2", lp1)
	var hp: bool = vo.get("hp", false)
	var phase := 0.0
	var low := 0.0
	for i in count:
		var j := start + i
		if j >= mix.size():
			break
		var t := float(i) / RATE
		var k := t / len_s
		var env: float
		if swell:
			env = sin(PI * k)
		else:
			env = minf(t / atk, 1.0) * exp(-t * dec)
		env *= minf((len_s - t) / 0.004, 1.0)
		var s := 0.0
		if kind == "noise":
			var raw := rng.randf_range(-1.0, 1.0)
			low += (raw - low) * lerpf(lp1, lp2, k)
			s = raw - low if hp else low
		else:
			phase = fmod(phase + lerpf(f1, f2, k) / RATE, 1.0)
			match kind:
				"square":
					s = 1.0 if phase < 0.5 else -1.0
				"tri":
					s = 4.0 * absf(phase - 0.5) - 1.0
				"saw":
					s = 2.0 * phase - 1.0
				_:
					s = sin(TAU * phase)
		mix[j] += s * env * vol

static func _to_wav(mix: PackedFloat32Array, loop: bool, normalize: float = 0.0) -> AudioStreamWAV:
	var gain := 1.0
	if normalize > 0.0:
		var peak := 0.001
		for x in mix:
			peak = maxf(peak, absf(x))
		gain = normalize / peak
	var data := PackedByteArray()
	data.resize(mix.size() * 2)
	for i in mix.size():
		data.encode_s16(i * 2, int(clampf(mix[i] * gain, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = mix.size()
	return wav

## The continuous loops. Both are exactly whole cycles long, so they loop clean.
static func _render_loop(key: String) -> AudioStreamWAV:
	var mix := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	match key:
		"hum":
			# A deep, slowly throbbing drone: 55 Hz + 110 Hz, 4 throbs a second.
			mix.resize(RATE)
			for i in RATE:
				var t := float(i) / RATE
				var throb := 0.6 + 0.4 * sin(TAU * 4.0 * t)
				mix[i] = (sin(TAU * 55.0 * t) * 0.7 + sin(TAU * 110.0 * t) * 0.25 + sin(TAU * 165.0 * t) * 0.08) * throb * 0.5
		"skitter":
			# Many tiny legs: scattered clicks and chitters, 2 s around.
			mix.resize(RATE * 2)
			for n in 140:
				var start := rng.randi_range(0, mix.size() - 1)
				var length := rng.randi_range(40, 160)
				var amp := rng.randf_range(0.15, 0.5)
				var f := rng.randf_range(2500.0, 5500.0)
				var low := 0.0
				for i in length:
					var j := (start + i) % mix.size()
					var raw := rng.randf_range(-1.0, 1.0)
					low += (raw - low) * 0.3
					var env := exp(-float(i) / (length * 0.25))
					mix[j] += ((raw - low) * 0.7 + sin(TAU * f * i / RATE) * 0.3) * amp * env
	if mix.is_empty():
		return null
	return _to_wav(mix, true, 0.8)
