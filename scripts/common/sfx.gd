extends Node

## Autoload `Sfx`: the app's sound library. Every sound is synthesized in
## code the first time it plays (then cached), so the library costs no
## download space. Any of them can be swapped for a recording by adding
## `res://assets/sfx/<name>.ogg` (or .wav) -- no code change.
##
## Games never reference `Sfx` directly (packs also run on apps from before
## v0.23, which simply stay silent):
##
##     func _sfx(name: String) -> void:
##         var s = get_node_or_null("/root/Sfx")
##         if s:
##             s.play(name)
##
## Free, with no game code:
## - every button press plays "tap" (hooked up here, app-wide, like vibration);
##   a button with `set_meta("sfx", "key")` plays that sound instead, "" none
## - GameInfo plays "win" / "lose" / "draw" / "record" with its results
##
## The libraries (names for play()):
##   Basic   tap back toggle invalid win lose draw record tick notify
##   Cards   card_deal card_flip card_place card_shuffle
##   Board   place capture slide merge
##   Dice    dice_roll dice_land  -- Party: spin_tick whoosh drumroll buzzer
##   Arcade  shoot explode powerup hit jump pickup
##   Word    key letter_right letter_wrong
## A sound only one game uses lives in that game's own folder (its pack):
## load the stream there and call play_stream(stream).
##
## Everything plays on the "SFX" bus, which feeds Master -- so the Options
## screen's Mute all and Volume (Settings sets Master) cover it all. Each
## sound is also in a group (GROUP_OF: taps, game, results, alerts) with its
## own on/off and volume in Options and the in-game ⚙ drawer's 🔊 Sound.

const BUS := "SFX"
const FILE_DIR := "res://assets/sfx/"
const RATE := 22050
const VOICES := 8
## The same sound again within this many ms is skipped (no stacking).
const REPEAT_GAP_MS := 35
## Sounds that repeat a lot get a slight random pitch so they don't drone.
const VARY := ["tap", "key", "place", "card_deal", "card_place", "spin_tick", "hit", "tick"]
## Every library sound (the list in the header, in code form).
const LIBRARY := [
	"tap", "back", "toggle", "invalid", "win", "lose", "draw", "record", "tick", "notify",
	"card_deal", "card_flip", "card_place", "card_shuffle",
	"place", "capture", "slide", "merge",
	"dice_roll", "dice_land", "spin_tick", "whoosh", "drumroll", "buzzer",
	"shoot", "explode", "powerup", "hit", "jump", "pickup",
	"key", "letter_right", "letter_wrong",
]

## Which Options group (Settings.SOUND_GROUPS) each sound belongs to, for
## its on/off switch and volume. Anything not listed is "game".
const GROUP_OF := {
	"tap": "taps", "back": "taps", "toggle": "taps", "key": "taps", "tick": "taps",
	"win": "results", "lose": "results", "draw": "results", "record": "results",
	"notify": "alerts", "invalid": "alerts",
}

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary = {}  # name -> AudioStream
var _last_ms: Dictionary = {}  # name -> Time.get_ticks_msec() of last play
var _warm_task: int = -1
var _warm_queue: Array = []  # web build: library sounds still to render

func _ready() -> void:
	# The GameInfo card pauses games; its sounds must still play.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, "Master")
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_on_node_added)
	# Synthesizing takes ~0.5 s for the whole library on a PC -- do it on a
	# worker thread at launch, so no first play stutters on a phone.
	# The browser build has no threads (the task would run right here and
	# hold up the first screen): there, one sound per frame instead.
	if OS.has_feature("web"):
		_warm_queue = LIBRARY.duplicate()
	else:
		_warm_task = WorkerThreadPool.add_task(_warm_up)
		set_process(false)

func _process(_delta: float) -> void:
	if _warm_queue.is_empty():
		set_process(false)
		return
	get_stream(_warm_queue.pop_front())

func _exit_tree() -> void:
	if _warm_task != -1:
		WorkerThreadPool.wait_for_task_completion(_warm_task)
		_warm_task = -1

## Runs on a worker thread: renders the library, then hands it over.
func _warm_up() -> void:
	var made := {}
	for sound in LIBRARY:
		if not ResourceLoader.exists(FILE_DIR + sound + ".ogg") and not ResourceLoader.exists(FILE_DIR + sound + ".wav"):
			made[sound] = _render(_recipe(sound))
	_store.call_deferred(made)

func _store(made: Dictionary) -> void:
	for sound in made:
		if not _cache.has(sound):
			_cache[sound] = made[sound]

## Plays a library sound. `volume_db` is relative to its normal level.
func play(sound: String, volume_db: float = 0.0) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(sound, -100000)) < REPEAT_GAP_MS:
		return
	_last_ms[sound] = now
	var stream := get_stream(sound)
	if stream == null:
		return
	var pitch := 1.0
	if sound in VARY:
		pitch = randf_range(0.94, 1.06)
	play_stream(stream, volume_db, pitch, GROUP_OF.get(sound, "game"))

## Plays any stream (e.g. one from a game's own pack) on the SFX bus, at
## the volume the player set for `group` -- or not at all if it's off.
func play_stream(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0, group: String = "game") -> void:
	if stream == null or _players.is_empty():
		return
	var settings = get_node_or_null("/root/Settings")
	if settings:
		var extra = settings.group_db(group)
		if extra == null:
			return
		volume_db += float(extra)
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

## The stream for a library sound: a recording in assets/sfx/ if there is
## one, else the synthesized version. null for an unknown name.
func get_stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var stream: AudioStream = null
	for ext in ["ogg", "wav"]:
		var path: String = FILE_DIR + sound + "." + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null:
		var recipe: Array = _recipe(sound)
		if not recipe.is_empty():
			stream = _render(recipe)
	if stream == null:
		push_warning("Sfx: unknown sound '%s'" % sound)
	_cache[sound] = stream
	return stream

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		# A method Callable, not a lambda: freed with the button automatically.
		node.pressed.connect(_on_button_pressed.bind(node))

## A button plays "tap", or the sound in its "sfx" meta:
## `btn.set_meta("sfx", "key")`, or "" for none (the game plays its own).
func _on_button_pressed(button: BaseButton) -> void:
	var sound: String = str(button.get_meta("sfx", "tap"))
	if sound != "":
		play(sound)

# ---------- the synthesizer ----------
#
# A recipe is an Array of voices, mixed together. Each voice is a Dictionary:
#   t: "sine" | "tri" | "square" | "saw" | "noise"
#   at: start (s)    len: length (s)    vol: 0..1
#   f / f2: start / end pitch in Hz (tones; slides from f to f2)
#   atk: attack (s)  dec: exponential decay rate (bigger = shorter)
#   lp / lp2: noise low-pass, 0..1 (1 = unfiltered), sliding from lp to lp2
#   hp: true = keep only the hiss above the low-pass (clicks, swishes)
#   swell: true = envelope rises then falls (whooshes) instead of decaying

func _recipe(sound: String) -> Array:
	match sound:
		# --- Basic ---
		"tap":
			return [{"t": "sine", "f": 1500, "f2": 1150, "len": 0.035, "dec": 90, "vol": 0.22}]
		"back":
			return [{"t": "sine", "f": 950, "f2": 560, "len": 0.07, "dec": 45, "vol": 0.25}]
		"toggle":
			return [{"t": "sine", "f": 1100, "len": 0.04, "dec": 70, "vol": 0.22},
				{"t": "sine", "f": 1650, "at": 0.05, "len": 0.05, "dec": 60, "vol": 0.22}]
		"invalid":
			return [{"t": "square", "f": 190, "f2": 170, "len": 0.09, "dec": 12, "vol": 0.16},
				{"t": "square", "f": 160, "f2": 140, "at": 0.12, "len": 0.13, "dec": 12, "vol": 0.16}]
		"win":
			return _notes("tri", [523.3, 659.3, 784.0, 1046.5], 0.09, 0.45, 0.32) \
				+ _notes("sine", [1046.5, 1318.5, 1568.0, 2093.0], 0.09, 0.45, 0.12)
		"lose":
			return [{"t": "tri", "f": 392.0, "len": 0.2, "dec": 6, "vol": 0.3},
				{"t": "tri", "f": 329.6, "at": 0.2, "len": 0.2, "dec": 6, "vol": 0.3},
				{"t": "tri", "f": 261.6, "f2": 220.0, "at": 0.4, "len": 0.55, "dec": 4, "vol": 0.32}]
		"draw":
			return [{"t": "tri", "f": 523.3, "len": 0.18, "dec": 9, "vol": 0.28},
				{"t": "tri", "f": 523.3, "at": 0.2, "len": 0.3, "dec": 7, "vol": 0.28}]
		"record":
			return _notes("square", [784.0, 988.0, 1175.0, 1568.0, 1976.0], 0.06, 0.3, 0.14) \
				+ [{"t": "sine", "f": 3136.0, "at": 0.3, "len": 0.4, "dec": 8, "vol": 0.12}]
		"tick":
			return [{"t": "sine", "f": 2200, "len": 0.02, "dec": 160, "vol": 0.25}]
		"notify":
			return [{"t": "sine", "f": 880.0, "len": 0.22, "dec": 9, "vol": 0.35},
				{"t": "sine", "f": 1318.5, "at": 0.12, "len": 0.35, "dec": 9, "vol": 0.35}]
		# --- Cards ---
		"card_deal":
			return [{"t": "noise", "len": 0.09, "swell": true, "lp": 0.5, "hp": true, "vol": 0.5}]
		"card_flip":
			return [{"t": "noise", "len": 0.05, "dec": 60, "lp": 0.35, "hp": true, "vol": 0.55},
				{"t": "sine", "f": 900, "len": 0.02, "dec": 150, "vol": 0.12}]
		"card_place":
			return [{"t": "noise", "len": 0.04, "dec": 80, "lp": 0.3, "vol": 0.6},
				{"t": "sine", "f": 140, "f2": 100, "len": 0.06, "dec": 60, "vol": 0.3}]
		"card_shuffle":
			var v: Array = []
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			var t := 0.0
			while t < 0.55:
				v.append({"t": "noise", "at": t, "len": 0.025, "dec": 140, "lp": 0.45, "hp": true, "vol": rng.randf_range(0.3, 0.55)})
				t += rng.randf_range(0.022, 0.045)
			v.append({"t": "noise", "at": t, "len": 0.06, "dec": 60, "lp": 0.3, "vol": 0.5})
			return v
		# --- Board & Puzzle ---
		"place":
			return [{"t": "sine", "f": 330, "f2": 240, "len": 0.08, "dec": 55, "vol": 0.45},
				{"t": "noise", "len": 0.015, "dec": 200, "lp": 0.4, "hp": true, "vol": 0.3}]
		"capture":
			return [{"t": "sine", "f": 300, "f2": 220, "len": 0.07, "dec": 55, "vol": 0.4},
				{"t": "sine", "f": 210, "f2": 140, "at": 0.06, "len": 0.12, "dec": 30, "vol": 0.45},
				{"t": "noise", "at": 0.06, "len": 0.05, "dec": 70, "lp": 0.25, "vol": 0.4}]
		"slide":
			return [{"t": "noise", "len": 0.12, "swell": true, "lp": 0.12, "lp2": 0.25, "vol": 0.6}]
		"merge":
			return [{"t": "sine", "f": 500, "f2": 950, "len": 0.09, "dec": 25, "vol": 0.35}]
		# --- Dice & Party ---
		"dice_roll":
			var v: Array = []
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			var t := 0.0
			var gap := 0.03
			while t < 0.6:
				v.append({"t": "sine", "f": rng.randf_range(1400, 2600), "at": t, "len": 0.03, "dec": 140, "vol": rng.randf_range(0.12, 0.22)})
				v.append({"t": "noise", "at": t, "len": 0.02, "dec": 200, "lp": 0.5, "hp": true, "vol": 0.25})
				t += gap * rng.randf_range(0.7, 1.4)
				gap *= 1.12  # the dice slow down
			return v
		"dice_land":
			return [{"t": "sine", "f": 1900, "len": 0.03, "dec": 140, "vol": 0.22},
				{"t": "noise", "len": 0.03, "dec": 150, "lp": 0.4, "vol": 0.4},
				{"t": "sine", "f": 1600, "at": 0.07, "len": 0.03, "dec": 140, "vol": 0.16}]
		"spin_tick":
			return [{"t": "noise", "len": 0.012, "dec": 300, "lp": 0.6, "hp": true, "vol": 0.45},
				{"t": "sine", "f": 1800, "len": 0.015, "dec": 250, "vol": 0.12}]
		"whoosh":
			return [{"t": "noise", "len": 0.4, "swell": true, "lp": 0.05, "lp2": 0.3, "vol": 0.7}]
		"drumroll":
			var v: Array = []
			var t := 0.0
			while t < 1.0:
				v.append({"t": "noise", "at": t, "len": 0.04, "dec": 70, "lp": 0.2, "vol": 0.12 + t * 0.2})
				t += 0.04
			v.append({"t": "noise", "at": 1.0, "len": 0.6, "dec": 6, "lp": 0.6, "vol": 0.4})
			v.append({"t": "sine", "f": 90, "f2": 60, "at": 1.0, "len": 0.3, "dec": 12, "vol": 0.5})
			return v
		"buzzer":
			return [{"t": "square", "f": 110, "len": 0.5, "dec": 2, "vol": 0.14},
				{"t": "square", "f": 116.5, "len": 0.5, "dec": 2, "vol": 0.14}]
		# --- Arcade ---
		"shoot":
			return [{"t": "square", "f": 1100, "f2": 220, "len": 0.12, "dec": 18, "vol": 0.15}]
		"explode":
			return [{"t": "noise", "len": 0.6, "dec": 6, "lp": 0.5, "lp2": 0.03, "vol": 0.5},
				{"t": "sine", "f": 120, "f2": 40, "len": 0.35, "dec": 9, "vol": 0.4}]
		"powerup":
			return [{"t": "square", "f": 330, "f2": 1320, "len": 0.35, "dec": 3, "vol": 0.13},
				{"t": "sine", "f": 660, "f2": 2640, "len": 0.35, "dec": 3, "vol": 0.12}]
		"hit":
			return [{"t": "square", "f": 260, "f2": 90, "len": 0.12, "dec": 22, "vol": 0.16},
				{"t": "noise", "len": 0.08, "dec": 40, "lp": 0.4, "vol": 0.4}]
		"jump":
			return [{"t": "square", "f": 280, "f2": 720, "len": 0.13, "dec": 12, "vol": 0.13}]
		"pickup":
			return [{"t": "square", "f": 988, "len": 0.07, "dec": 10, "vol": 0.12},
				{"t": "square", "f": 1319, "at": 0.07, "len": 0.22, "dec": 12, "vol": 0.12}]
		# --- Word ---
		"key":
			return [{"t": "noise", "len": 0.018, "dec": 220, "lp": 0.5, "hp": true, "vol": 0.35},
				{"t": "sine", "f": 1250, "len": 0.02, "dec": 180, "vol": 0.1}]
		"letter_right":
			return [{"t": "sine", "f": 1046.5, "len": 0.14, "dec": 18, "vol": 0.3},
				{"t": "sine", "f": 2093.0, "len": 0.1, "dec": 25, "vol": 0.08}]
		"letter_wrong":
			return [{"t": "tri", "f": 247, "f2": 220, "len": 0.13, "dec": 20, "vol": 0.3}]
	return []

## A rising run of notes, each `step` s apart; the last one rings `tail` s.
func _notes(wave: String, freqs: Array, step: float, tail: float, vol: float) -> Array:
	var v: Array = []
	for i in freqs.size():
		var last := i == freqs.size() - 1
		v.append({"t": wave, "f": freqs[i], "at": step * i, "len": tail if last else step * 1.6,
			"dec": 5.0 if last else 14.0, "vol": vol})
	return v

func _render(voices: Array) -> AudioStreamWAV:
	var total_s := 0.0
	for vo in voices:
		total_s = maxf(total_s, float(vo.get("at", 0.0)) + float(vo["len"]))
	var n := int(total_s * RATE) + 1
	var mix := PackedFloat32Array()
	mix.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for vo in voices:
		_add_voice(mix, vo, rng)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(mix[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav

func _add_voice(mix: PackedFloat32Array, vo: Dictionary, rng: RandomNumberGenerator) -> void:
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
		var k := t / len_s  # 0..1 through the voice
		var env: float
		if swell:
			env = sin(PI * k)
		else:
			env = minf(t / atk, 1.0) * exp(-t * dec)
		env *= minf((len_s - t) / 0.004, 1.0)  # no click at the end
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
