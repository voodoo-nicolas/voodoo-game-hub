extends Node

## Autoload `Music`: the hub's shared music library (STANDARDS §10, §13).
## Every game takes its music from here -- never its own synth or files
## (owner, 2026-10-07) -- so one 🎵 switch and one volume cover it all, and
## real tracks, when they come, are added once for every game.
##
## Games never reference `Music` directly (packs also run on apps from
## before v0.33, which simply play no music):
##
##     func _music(style: String, index: int = -1) -> void:
##         var m = get_node_or_null("/root/Music")
##         if m:
##             m.play(style, self, index)
##
## Styles (names for play()), four tracks each:
##   calm    slow and warm, 78-94 BPM: menus, puzzles, thinking games
##   lively  moderate techno, 118-126 BPM: arcade levels
##   techno  driving techno, 136-148 BPM: bosses, swarms, finales
##
## - play(style, owner, index = -1, fade = 1.5): crossfades to that style's
##   track `index` (wrapped round; -1 = the next one after the last played).
##   `owner` is the game's node: when it leaves the tree (🏠 Home, the hub, a
##   scene reload) the music fades out by itself. Asking for what is already
##   playing does nothing, so a game can call it every stage.
## - prepare(style, index = -1): get a track ready ahead of time (a
##   synthesized track takes a moment the first time) -- e.g. from _ready().
## - stop(fade = 1.5).
## - While the tree is paused (pause menu, How to Play card) the music drops
##   by PAUSED_DB and keeps going.
## - The player's switch and volume are the Settings sound group "music"
##   (hub Options and every game's ⚙ Options); Mute all covers it too.
##   Everything plays on the "Music" bus, which feeds Master.
##
## Tracks are synthesized in code (SONGS) -- no download cost: rendered on a
## worker thread the first time each one is wanted (~0.5-1 s a track on a
## PC, several times that on a phone; in the browser build, which has no
## threads, WEB_BUDGET_USEC of work a frame), then kept in memory and in user://music_synth/
## (~1.3 MB a track), so each one is made once per install -- bump
## SYNTH_VERSION when SONGS or the instruments change. Real music
## replaces a style's synthesized tracks once that style has files:
##   res://media/common/music/<style>/*.ogg   (Tier 1 media pack, STANDARDS §10)
##   res://media/hub/music/<style>/*.ogg      (in the APK)
## Every file needs its media/CREDITS.json entry + licence proof; OGG
## ~96 kbps, loop on. `tools/music_preview.gd` writes the synthesized tracks
## to builds/music_preview/ to listen to.

const BUS := "Music"
const RATE := 22050
const STYLES := ["calm", "lively", "techno"]
const FILE_DIRS := ["res://media/common/music/", "res://media/hub/music/"]
## The music sits under the game's own sounds.
const BASE_DB := -8.0
const PAUSED_DB := -10.0
const CACHE_DIR := "user://music_synth/"
const SYNTH_VERSION := 1
## Browser build: synthesizing work allowed per frame.
const WEB_BUDGET_USEC := 4000

var _tracks := {}          # "style:index" -> AudioStreamWAV (synthesized)
var _files := {}           # style -> Array of AudioStream (looked up once)
var _players: Array[AudioStreamPlayer] = []  # [current, incoming]
var _key := ""             # the track playing, or wanted
var _want := ""            # wanted but still being synthesized
var _want_fade := 1.5
var _owner_ref: WeakRef = null
var _last_index := {}      # style -> index last played
var _tween: Tween
var _queue: Array = []     # keys still to synthesize, most urgent first
var _rendering := ""       # the key on the worker thread / being rendered
var _task := -1
var _job: Dictionary = {}  # browser build: the track being rendered, bar by bar
var _preview_t := 0.0
var _bus_db := -80.0

func _ready() -> void:
	# Fades and the render queue carry on behind a paused game.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, "Master")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)

func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

# ---------- the API ----------

func play(style: String, owner: Node = null, index: int = -1, fade: float = 1.5) -> void:
	if not STYLES.has(style):
		return
	_owner_ref = weakref(owner) if owner else null
	_preview_t = 0.0
	var count := _count(style)
	if index < 0:
		index = int(_last_index.get(style, -1)) + 1
	index = posmod(index, count)
	_last_index[style] = index
	var key := "%s:%d" % [style, index]
	if key == _key and (_want == key or _players[0].playing):
		return
	_key = key
	var stream := _stream_of(key)
	if stream == null:
		_want = key
		_want_fade = fade
		_request(key, true)
		return
	_want = ""
	_crossfade(stream, fade)

func prepare(style: String, index: int = -1) -> void:
	if not STYLES.has(style):
		return
	if index < 0:
		index = int(_last_index.get(style, -1)) + 1
	_request("%s:%d" % [style, posmod(index, _count(style))], false)

func stop(fade: float = 1.5) -> void:
	_key = ""
	_want = ""
	_owner_ref = null
	_preview_t = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	for p in _players:
		if p.playing:
			_tween.tween_property(p, "volume_db", -60.0, maxf(fade, 0.05))
	_tween.chain().tween_callback(_stop_players)

func is_playing() -> bool:
	return _key != ""

## A few seconds of music for the Options volume slider, when none is on.
func preview() -> void:
	if _key != "":
		return
	play("lively", null, 0, 0.3)
	_preview_t = 4.0

# ---------- playing ----------

func _process(delta: float) -> void:
	# The owner left (🏠 Home, the hub, a reload): fade out.
	if _owner_ref != null:
		var o = _owner_ref.get_ref()
		if o == null or not (o as Node).is_inside_tree():
			stop(0.8)
	if _want != "":
		var s := _stream_of(_want)
		if s:
			_want = ""
			_crossfade(s, _want_fade)
	if _preview_t > 0.0 and _players[0].playing:
		_preview_t -= delta
		if _preview_t <= 0.0:
			stop(1.0)
	_render_queue()
	_apply_volume(delta)

func _apply_volume(delta: float) -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus == -1:
		return
	var s = get_node_or_null("/root/Settings")
	var g = s.group_db("music") if s and s.has_method("group_db") else 0.0
	if g == null:
		AudioServer.set_bus_mute(bus, true)
		return
	var want: float = BASE_DB + float(g) + (PAUSED_DB if get_tree().paused else 0.0)
	_bus_db = want if _bus_db < -79.0 else move_toward(_bus_db, want, delta * 30.0)
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, _bus_db)

func _crossfade(stream: AudioStream, fade: float) -> void:
	var cur: AudioStreamPlayer = _players[0]
	var incoming: AudioStreamPlayer = _players[1]
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(incoming, "volume_db", 0.0, maxf(fade, 0.05)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if cur.playing:
		_tween.tween_property(cur, "volume_db", -60.0, maxf(fade, 0.05)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(cur.stop)
	_players.reverse()

func _stop_players() -> void:
	for p in _players:
		p.stop()

func _count(style: String) -> int:
	var files := _files_of(style)
	return files.size() if not files.is_empty() else (SONGS[style] as Array).size()

func _stream_of(key: String) -> AudioStream:
	var parts := key.split(":")
	var files := _files_of(parts[0])
	if not files.is_empty():
		return files[int(parts[1]) % files.size()]
	return _tracks.get(key)

## Real tracks for `style` (media pack first, then the APK), looked up once.
## Works in exported builds, where a folder lists .import / .remap files.
func _files_of(style: String) -> Array:
	if _files.has(style):
		return _files[style]
	var out: Array = []
	for root in FILE_DIRS:
		var dir: String = root + style + "/"
		var names := PackedStringArray()
		if ResourceLoader.has_method("list_directory"):
			names = ResourceLoader.call("list_directory", dir)
		elif DirAccess.dir_exists_absolute(dir):
			for f in DirAccess.get_files_at(dir):
				names.append(f.trim_suffix(".import").trim_suffix(".remap"))
		var seen := {}
		for f in names:
			if not f.get_extension().to_lower() in ["ogg", "mp3", "wav"] or seen.has(f):
				continue
			seen[f] = true
			var s = load(dir + f)
			if s is AudioStream:
				if "loop" in s:
					s.loop = true
				elif s is AudioStreamWAV:
					s.loop_mode = AudioStreamWAV.LOOP_FORWARD
				out.append(s)
		if not out.is_empty():
			break
	_files[style] = out
	return out

# ---------- synthesizing ----------

func _request(key: String, urgent: bool) -> void:
	if _tracks.has(key) or key == _rendering or not _files_of(key.split(":")[0]).is_empty():
		return
	_queue.erase(key)
	if urgent:
		_queue.push_front(key)
	else:
		_queue.append(key)

func _render_queue() -> void:
	if OS.has_feature("web"):
		# No threads in the browser: a few milliseconds of work per frame,
		# so a game keeps its frame rate while a track is made.
		if _job.is_empty():
			if _queue.is_empty():
				return
			_rendering = _queue.pop_front()
			var cached := _load_pcm(_rendering)
			if cached:
				_store(_rendering, cached)
				return
			var parts := _rendering.split(":")
			_job = _new_job(parts[0], int(parts[1]))
		if _job_step(_job, WEB_BUDGET_USEC):
			_save_pcm(_rendering, _job.wav)
			_store(_rendering, _job.wav)
			_job = {}
		return
	if _task != -1:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if _queue.is_empty():
		return
	_rendering = _queue.pop_front()
	_task = WorkerThreadPool.add_task(_render_on_worker.bind(_rendering))

## Runs on a worker thread; hands the track over on the main thread.
func _render_on_worker(key: String) -> void:
	var wav := _load_pcm(key)
	if wav == null:
		var parts := key.split(":")
		var job := _new_job(parts[0], int(parts[1]))
		_job_step(job, -1)
		wav = job.wav
		_save_pcm(key, wav)
	_store.call_deferred(key, wav)

static func _pcm_path(key: String) -> String:
	return CACHE_DIR + "%s_v%d.pcm" % [key.replace(":", "_"), SYNTH_VERSION]

## A track made on an earlier run (null if none).
static func _load_pcm(key: String) -> AudioStreamWAV:
	var path := _pcm_path(key)
	if not FileAccess.file_exists(path):
		return null
	var data := FileAccess.get_file_as_bytes(path)
	if data.size() < 4096:
		return null
	return _wav_of(data)

## Keeps a made track for next time (and drops older versions of it).
static func _save_pcm(key: String, wav: AudioStreamWAV) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var stem := key.replace(":", "_") + "_v"
	for name in DirAccess.get_files_at(CACHE_DIR):
		if name.begins_with(stem) and CACHE_DIR + name != _pcm_path(key):
			DirAccess.remove_absolute(CACHE_DIR + name)
	var path := _pcm_path(key)
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(wav.data)
	f.close()
	DirAccess.rename_absolute(path + ".tmp", path)

func _store(key: String, wav: AudioStreamWAV) -> void:
	_tracks[key] = wav
	if _rendering == key:
		_rendering = ""

## The synthesized tracks. prog: [root midi, minor?] per two bars; arp: the
## order of chord tones (0 root, 1 third, 2 fifth, 3 octave); lead: the
## melody of the second half, [16th within the two bars, chord tone (0-5:
## root, third, fifth, then the same an octave up), length in 16ths] -- it
## follows the chords, so it always fits. The other keys pick the patterns.
## Calm loops 8 bars; lively and techno 16 (the second 8 add the lead).
## Changing SONGS or the instruments changes every game's music.
const SONGS := {
	"calm": [
		{"bpm": 86, "prog": [[57, true], [53, false], [48, false], [55, false]], "arp": [0, 1, 2, 3, 2, 1, 2, 0], "wave": "tri"},
		{"bpm": 90, "prog": [[50, true], [58, false], [53, false], [48, false]], "arp": [0, 2, 1, 3, 0, 2, 3, 1], "wave": "tri", "hats": true},
		{"bpm": 78, "prog": [[48, false], [57, true], [53, false], [55, false]], "arp": [3, 2, 1, 0, 1, 2, 3, 2], "wave": "sine", "bell": true},
		{"bpm": 94, "prog": [[54, true], [50, false], [57, false], [52, false]], "arp": [0, 1, 2, 1, 3, 1, 2, 1], "wave": "tri", "kick": true},
	],
	"lively": [
		{"bpm": 124, "prog": [[52, true], [48, false], [55, false], [50, false]], "arp": [0, 1, 2, 1], "bass": "octave",
			"lead": [[0, 3, 3], [3, 2, 1], [4, 3, 2], [6, 4, 2], [8, 5, 6], [14, 4, 2], [16, 3, 3], [19, 2, 1], [20, 1, 2], [22, 2, 2], [24, 0, 6], [30, 1, 2]]},
		{"bpm": 122, "prog": [[54, true], [50, false], [57, false], [52, false]], "arp": [0, 2, 1, 3], "bass": "synco",
			"lead": [[0, 0, 2], [2, 2, 2], [4, 3, 2], [6, 2, 2], [8, 4, 4], [12, 3, 4], [16, 0, 2], [18, 2, 2], [20, 3, 2], [22, 5, 2], [24, 4, 8]]},
		{"bpm": 120, "prog": [[55, true], [51, false], [58, false], [53, false]], "arp": [0, 1, 3, 2], "bass": "octave",
			"lead": [[0, 5, 4], [4, 4, 2], [6, 3, 2], [8, 2, 4], [12, 3, 4], [16, 5, 2], [18, 4, 2], [20, 3, 4], [24, 1, 4], [28, 2, 4]]},
		{"bpm": 126, "prog": [[47, true], [55, false], [50, false], [57, false]], "arp": [0, 1, 2, 3, 2, 1], "bass": "walk",
			"lead": [[0, 3, 1], [2, 3, 1], [4, 4, 2], [7, 3, 1], [8, 2, 3], [11, 1, 1], [12, 2, 4], [16, 3, 1], [18, 3, 1], [20, 5, 2], [23, 4, 1], [24, 3, 8]]},
	],
	"techno": [
		{"bpm": 138, "prog": [[45, true], [45, true], [43, false], [48, false]], "stab": [0, 3, 6, 10, 14], "bass": "roll",
			"lead": [[0, 3, 1], [3, 3, 1], [6, 4, 1], [8, 3, 2], [11, 2, 1], [14, 3, 2], [16, 3, 1], [19, 3, 1], [22, 5, 1], [24, 4, 2], [27, 3, 1], [30, 2, 2]]},
		{"bpm": 140, "prog": [[48, true], [48, true], [44, false], [46, false]], "stab": [2, 6, 7, 11, 15], "bass": "roll",
			"lead": [[0, 0, 2], [2, 3, 2], [4, 2, 1], [6, 3, 2], [8, 4, 2], [10, 3, 2], [12, 2, 4], [16, 0, 2], [18, 3, 2], [20, 5, 2], [22, 4, 2], [24, 3, 6]]},
		{"bpm": 136, "prog": [[52, true], [52, true], [48, false], [50, false]], "stab": [0, 4, 8, 9, 12], "bass": "offbeat",
			"lead": [[0, 5, 2], [2, 4, 1], [3, 3, 1], [4, 4, 2], [6, 3, 2], [8, 2, 6], [16, 5, 2], [18, 4, 1], [19, 3, 1], [20, 4, 2], [22, 5, 2], [24, 3, 6]]},
		{"bpm": 142, "prog": [[50, true], [50, true], [46, false], [48, false]], "stab": [1, 3, 6, 9, 11, 14], "bass": "every",
			"lead": [[0, 3, 1], [1, 3, 1], [2, 4, 2], [4, 3, 1], [6, 2, 2], [8, 3, 4], [12, 1, 2], [14, 2, 2], [16, 3, 1], [17, 3, 1], [18, 5, 2], [20, 4, 2], [22, 3, 2], [24, 2, 8]]},
	],
}

static func _mtof(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)

## A track is made from a score: a list of small events (a note, a drum
## hit, a slice of a pad...), worked through by _job_step -- all at once on
## a worker thread, a few milliseconds a frame in the browser. Lively and
## techno score their first 8 bars, copy them ("double": a seamless 8-bar
## loop twice over is a seamless 16), then add the second half's own parts
## (the lead, more hats) -- half the work.
static func _new_job(style: String, index: int) -> Dictionary:
	var song: Dictionary = SONGS[style][index % (SONGS[style] as Array).size()]
	var spb := int(60.0 / float(song.bpm) / 4.0 * RATE)  # samples per 16th
	var mix := PackedFloat32Array()
	mix.resize(spb * 16 * 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + index * 7 + STYLES.find(style) * 31
	var job := {"style": style, "song": song, "spb": spb, "mix": mix, "rng": rng, "memo": {}, "events": [], "i": 0,
		"pad": {}, "pos": 0, "peak": 0.001, "data": PackedByteArray(), "wav": null,
		"kick": _kick(), "clap": _clap(rng), "hat": _hat(rng, false), "ohat": _hat(rng, true)}
	for bar in (8 if style == "calm" else 16):
		if bar == 8:
			job.events.append(["double"])
		_score_bar(job, bar)
	job.events.append(["peak"])
	job.events.append(["encode"])
	return job

## Works through `job`'s score until it's done (budget -1) or `budget_usec`
## has passed; true once job.wav is ready.
static func _job_step(job: Dictionary, budget_usec: int) -> bool:
	var start := Time.get_ticks_usec()
	var events: Array = job.events
	while int(job.i) < events.size():
		var e: Array = events[job.i]
		var done := true
		match e[0]:
			"note":
				_mix(job.mix, _note(job.memo, e[1], e[2], e[3], e[4]), e[5], e[6])
			"drum":
				_mix(job.mix, job[e[1]], e[2], e[3])
			"riser":
				_mix(job.mix, _riser(job.rng, e[1]), e[2], e[3])
			"pad":
				done = _pad_chunk(job, e)
			"sub":
				done = _sub_chunk(job, e)
			"double":
				var m: PackedFloat32Array = job.mix
				m.append_array(m.duplicate())
				job.mix = m
			"peak":
				done = _peak_chunk(job)
			"encode":
				done = _encode_chunk(job)
		if done:
			job.i = int(job.i) + 1
		if budget_usec >= 0 and Time.get_ticks_usec() - start > budget_usec:
			break
	return int(job.i) >= events.size()

## Score helpers: `at` is the 16th the sound starts on.
static func _e_note(job: Dictionary, kind: String, freq: float, length: int, at: int, gain: float, extra = 0.0) -> void:
	job.events.append(["note", kind, freq, length, extra, at * int(job.spb), gain])

static func _e_drum(job: Dictionary, drum: String, at: int, gain: float) -> void:
	job.events.append(["drum", drum, at * int(job.spb), gain])

static func _e_pad(job: Dictionary, notes: Array, at: int, length16: int, gain: float) -> void:
	job.events.append(["pad", notes, at * int(job.spb), length16 * int(job.spb), gain])

static func _e_riser(job: Dictionary, at: int, length16: int, gain: float) -> void:
	job.events.append(["riser", length16 * int(job.spb), at * int(job.spb), gain])

## Scores one bar: every sound that starts in it.
static func _score_bar(job: Dictionary, bar: int) -> void:
	var song: Dictionary = job.song
	var spb: int = job.spb
	var prog: Array = song.prog
	var c := (bar / 2) % prog.size()
	var root: int = prog[c][0]
	var minor: bool = prog[c][1]
	var third := root + (3 if minor else 4)
	var fifth := root + 7
	var tones := [root, third, fifth, root + 12, third + 12, fifth + 12]
	var s0 := (bar % 2) * 16            # this bar's first 16th within its chord
	var c0 := (bar / 2) * 32            # the chord's first 16th in the track
	var style := str(job.style)
	if bar >= 8:
		# The second half's own parts, over the copy of the first.
		for s in range(s0, s0 + 16):
			if s % 4 == 2:
				_e_drum(job, "ohat", c0 + s, 0.08 if style == "lively" else 0.05)
			elif s % 2 == 0 and style == "lively":
				_e_drum(job, "hat", c0 + s, 0.06)
		for n in song.get("lead", []):
			if n[0] >= s0 and n[0] < s0 + 16:
				_e_note(job, "lead", _mtof(tones[n[1]] + 24), spb * int(n[2]), c0 + n[0], 0.07 if style == "lively" else 0.06)
		if bar == 15 and style == "lively":
			_e_riser(job, c0 + s0, 16, 0.1)
		return
	match style:
		"calm":
			# Warm pad, a lazy arpeggio, a sub bass; some add a bell
			# melody, a soft tick or a soft kick.
			if s0 == 0:
				_e_pad(job, [root + 12, third + 12, fifth + 12, root + 24], c0, 32, 0.16 if not song.get("bell", false) else 0.11)
				job.events.append(["sub", _mtof(root - 12), c0 * spb, spb * 32, 0.3])
			var arp: Array = song.arp
			for s in range(s0 / 2, s0 / 2 + 8):
				var note: int = tones[arp[s % arp.size()]] + 24
				_e_note(job, "pluck_sine" if str(song.wave) == "sine" else "pluck_tri", _mtof(note), spb * 3, c0 + s * 2, 0.09)
			if song.get("bell", false):
				for s in range(s0 / 8, s0 / 8 + 2):
					_e_note(job, "bell", _mtof(tones[[2, 1, 3, 1][s]] + 36), spb * 12, c0 + s * 8, 0.07)
			if song.get("hats", false):
				for s in range(s0 / 4, s0 / 4 + 4):
					_e_drum(job, "hat", c0 + s * 4 + 2, 0.05)
			if song.get("kick", false):
				for s in range(s0 / 8, s0 / 8 + 2):
					_e_drum(job, "kick", c0 + s * 8, 0.22)
		"lively":
			if s0 == 0:
				_e_pad(job, [root + 12, third + 12, fifth + 12], c0, 32, 0.08)
			var arp: Array = song.arp
			for s in range(s0, s0 + 16):
				var at := c0 + s
				if s % 4 == 0:
					_e_drum(job, "kick", at, 0.55)
				if s % 8 == 4:
					_e_drum(job, "clap", at, 0.32)
				if bar == 7 and s % 16 >= 13:
					_e_drum(job, "clap", at, 0.18)  # a little fill into the next half
				if s % 4 == 2:
					_e_drum(job, "hat", at, 0.16)
				match str(song.bass):
					"octave":
						if s % 2 == 0:
							_e_note(job, "bass", _mtof(root - 12 + (12 if (s / 2) % 2 == 1 else 0)), spb * 2, at, 0.22)
					"synco":
						if (s % 16) in [0, 3, 6, 8, 11, 14]:
							_e_note(job, "bass", _mtof(root - 12 + (7 if s % 16 == 14 else 0)), spb * 2, at, 0.24)
					"walk":
						if s % 4 == 0:
							_e_note(job, "bass", _mtof(tones[(s / 4) % 4] - 12), spb * 4, at, 0.24)
				_e_note(job, "pluck_sq", _mtof(tones[arp[s % arp.size()]] + 24), spb, at, 0.035)
		_:
			# Driving techno: four on the floor, offbeat open hats, 16th
			# hats, a rolling bass and acid stabs.
			var stab: Array = song.stab
			for s in range(s0, s0 + 16):
				var at := c0 + s
				if s % 4 == 0:
					_e_drum(job, "kick", at, 0.7)
				if s % 8 == 4:
					_e_drum(job, "clap", at, 0.3)
				if bar == 7 and s % 16 >= 12:
					_e_drum(job, "clap", at, 0.16)
				if s % 4 == 2:
					_e_drum(job, "ohat", at, 0.16)
				_e_drum(job, "hat", at, 0.09 if s % 2 == 0 else 0.05)
				match str(song.bass):
					"roll":
						if s % 4 != 0:
							_e_note(job, "bass", _mtof(root - 12 + (7 if s % 8 == 7 else 0)), spb, at, 0.26)
					"offbeat":
						if s % 4 == 2:
							_e_note(job, "bass", _mtof(root - 12 + (12 if s % 16 == 14 else 0)), spb * 2, at, 0.32)
					"every":
						_e_note(job, "bass", _mtof(root - 12 + (12 if s % 4 == 3 else 0)), spb, at, 0.2 if s % 4 == 0 else 0.26)
				if (s % 16) in stab:
					_e_note(job, "acid", _mtof(tones[s % 3] + 24), spb * 2, at, 0.065, float(s % 16) / 16.0)
			if bar == 7:
				_e_riser(job, c0 + s0, 16, 0.12)

const CHUNK := 4096

## A slow-swelling pad: two detuned saws per note through a low-pass, added
## straight into the mix a slice at a time (one note after another -- the
## filter is linear, so that sounds the same as filtering the whole chord).
static func _pad_chunk(job: Dictionary, e: Array) -> bool:
	var st: Dictionary = job.pad
	if st.is_empty():
		st = {"n": 0, "i": 0, "p1": 0.0, "p2": 0.0, "low": 0.0}
		job.pad = st
	var notes: Array = e[1]
	var at: int = e[2]
	var length: int = e[3]
	var gain: float = e[4]
	var mix: PackedFloat32Array = job.mix
	var size := mix.size()
	var f := _mtof(float(notes[st.n]))
	var inc1 := f * 0.997 / RATE
	var inc2 := f * 1.003 / RATE
	var norm := 1.0 / notes.size()
	var edge := int(RATE * 0.9)
	var p1: float = st.p1
	var p2: float = st.p2
	var low: float = st.low
	var i0: int = st.i
	var i1 := mini(i0 + CHUNK, length)
	for i in range(i0, i1):
		p1 += inc1
		if p1 >= 1.0:
			p1 -= 1.0
		p2 += inc2
		if p2 >= 1.0:
			p2 -= 1.0
		low += ((p1 + p2 - 1.0) * norm - low) * 0.12
		var env := 1.0
		if i < edge:
			env = float(i) / edge
		var back := length - 1 - i
		if back < edge:
			env *= float(back) / edge
		mix[(at + i) % size] += low * env * gain
	if i1 < length:
		st.merge({"i": i1, "p1": p1, "p2": p2, "low": low}, true)
		return false
	if int(st.n) + 1 < notes.size():
		job.pad = {"n": int(st.n) + 1, "i": 0, "p1": 0.0, "p2": 0.0, "low": 0.0}
		return false
	job.pad = {}
	return true

## The calm tracks' sub bass: a plain sine, soft at both ends, a slice at
## a time.
static func _sub_chunk(job: Dictionary, e: Array) -> bool:
	var mix: PackedFloat32Array = job.mix
	var size := mix.size()
	var w: float = TAU * float(e[1]) / RATE
	var at: int = e[2]
	var length: int = e[3]
	var gain: float = e[4]
	var atk := int(0.05 * RATE) + 1
	var rel := int(0.4 * RATE) + 1
	var i0: int = job.pos
	var i1 := mini(i0 + CHUNK * 2, length)
	for i in range(i0, i1):
		var env := 1.0
		if i < atk:
			env = float(i) / atk
		var back := length - 1 - i
		if back < rel:
			env *= float(back) / rel
		mix[(at + i) % size] += sin(w * i) * env * gain
	job.pos = i1
	if i1 < length:
		return false
	job.pos = 0
	return true

static func _peak_chunk(job: Dictionary) -> bool:
	var mix: PackedFloat32Array = job.mix
	var i0: int = job.pos
	var i1 := mini(i0 + CHUNK * 4, mix.size())
	var peak: float = job.peak
	for i in range(i0, i1):
		peak = maxf(peak, absf(mix[i]))
	job.peak = peak
	job.pos = i1
	if i1 < mix.size():
		return false
	job.pos = 0
	return true

static func _encode_chunk(job: Dictionary) -> bool:
	var mix: PackedFloat32Array = job.mix
	var data: PackedByteArray = job.data
	if data.size() != mix.size() * 2:
		data.resize(mix.size() * 2)
		job.data = data
	var gain := 0.85 / float(job.peak)
	var i0: int = job.pos
	var i1 := mini(i0 + CHUNK * 2, mix.size())
	for i in range(i0, i1):
		data.encode_s16(i * 2, int(clampf(mix[i] * gain, -1.0, 1.0) * 32000.0))
	job.pos = i1
	if i1 < mix.size():
		return false
	job.wav = _wav_of(data)
	return true

## 16-bit mono PCM at RATE as a looping stream.
static func _wav_of(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = data.size() / 2
	return wav

# ---------- instruments (from Neon Blast's music, 2026-10-05) ----------

## Adds `src` into `mix` at `at` (wrapping round, so the loop is seamless).
static func _mix(mix: PackedFloat32Array, src: PackedFloat32Array, at: int, gain: float) -> void:
	var n := mix.size()
	var m := mini(src.size(), n)
	var a := at % n
	var first := mini(m, n - a)
	for i in first:
		mix[a + i] += src[i] * gain
	for i in range(first, m):
		mix[i - first] += src[i] * gain

## A rendered note, made once per track and reused (`memo` is per track).
static func _note(memo: Dictionary, kind: String, freq: float, length: int, extra = 0.0) -> PackedFloat32Array:
	var key := "%s|%.2f|%d|%s" % [kind, freq, length, str(extra)]
	if memo.has(key):
		return memo[key]
	var out: PackedFloat32Array
	match kind:
		"bass":
			out = _bass(freq, length)
		"acid":
			out = _acid(freq, length, float(extra))
		"lead":
			out = _lead_tone(freq, length)
		"pluck_tri":
			out = _pluck(freq, length, "tri", 6.0, 0.35)
		"pluck_sine":
			out = _pluck(freq, length, "sine", 6.0, 0.35)
		"pluck_sq":
			out = _pluck(freq, length, "square", 14.0, 0.25)
		"bell":
			out = _pluck(freq, length, "sine", 1.6, 0.8)
	memo[key] = out
	return out

## A fade-in over `a` samples and a fade-out over the last `r`.
static func _edges(out: PackedFloat32Array, a: int, r: int) -> void:
	var n := out.size()
	for i in mini(a, n):
		out[i] *= float(i) / a
	for i in mini(r, n):
		out[n - 1 - i] *= float(i) / r

## A plucked note: quick decay through a low-pass.
static func _pluck(freq: float, length: int, kind: String, dec: float, lp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var inc := freq / RATE
	var ph := 0.0
	var low := 0.0
	var env := 1.0
	var k := exp(-dec / RATE)
	match kind:
		"square":
			for i in length:
				ph += inc
				if ph >= 1.0:
					ph -= 1.0
				low += ((1.0 if ph < 0.5 else -1.0) - low) * lp
				out[i] = low * env
				env *= k
		"sine":
			var w := TAU * inc
			for i in length:
				low += (sin(w * i) - low) * lp
				out[i] = low * env
				env *= k
		_:
			for i in length:
				ph += inc
				if ph >= 1.0:
					ph -= 1.0
				low += (4.0 * absf(ph - 0.5) - 1.0 - low) * lp
				out[i] = low * env
				env *= k
	_edges(out, 1, 200)
	return out

## The lead: two detuned saws through a low-pass that closes a little as
## the note sounds.
static func _lead_tone(freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var inc1 := freq * 0.996 / RATE
	var inc2 := freq * 1.004 / RATE
	var p1 := 0.0
	var p2 := 0.5
	var low := 0.0
	var cut := 0.3
	var ck := exp(-2.5 / RATE)
	var env := 1.0
	var ek := exp(-2.2 / RATE)
	for i in length:
		p1 += inc1
		if p1 >= 1.0:
			p1 -= 1.0
		p2 += inc2
		if p2 >= 1.0:
			p2 -= 1.0
		low += (p1 + p2 - 1.0 - low) * (0.08 + cut)
		out[i] = low * env
		cut *= ck
		env *= ek
	_edges(out, 90, 400)
	return out

## A bass note: a saw whose low-pass closes as it sounds.
static func _bass(freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var inc := freq / RATE
	var ph := 0.0
	var low := 0.0
	var cut := 0.4
	var ck := exp(-18.0 / RATE)
	var env := 1.0
	var ek := exp(-3.0 / RATE)
	for i in length:
		ph += inc
		if ph >= 1.0:
			ph -= 1.0
		low += (2.0 * ph - 1.0 - low) * (0.05 + cut)
		out[i] = low * env
		cut *= ck
		env *= ek
	_edges(out, 60, 120)
	return out

## An acid stab: a square with a resonant-ish filter sweep.
static func _acid(freq: float, length: int, color: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var inc := freq / RATE
	var ph := 0.0
	var low := 0.0
	var band := 0.0
	var sweep := 0.25 + 0.2 * color
	var sk := exp(-10.0 / RATE)
	var env := 1.0
	var ek := exp(-7.0 / RATE)
	for i in length:
		ph += inc
		if ph >= 1.0:
			ph -= 1.0
		var cut := 0.04 + sweep
		band += ((1.0 if ph < 0.5 else -1.0) - low - band * 0.4) * cut
		low += band * cut
		out[i] = (low + band * 0.5) * env
		sweep *= sk
		env *= ek
	_edges(out, 1, 150)
	return out

static func _kick() -> PackedFloat32Array:
	var length := int(0.3 * RATE)
	var out := PackedFloat32Array()
	out.resize(length)
	var ph := 0.0
	for i in length:
		var t := float(i) / RATE
		var f := 45.0 + 110.0 * exp(-t * 28.0)
		ph = fmod(ph + f / RATE, 1.0)
		out[i] = sin(TAU * ph) * exp(-t * 9.0) + (1.0 - minf(1.0, i / 90.0)) * 0.4
	return out

static func _clap(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var length := int(0.22 * RATE)
	var out := PackedFloat32Array()
	out.resize(length)
	var low := 0.0
	for i in length:
		var t := float(i) / RATE
		var raw := rng.randf_range(-1.0, 1.0)
		low += (raw - low) * 0.5
		var bursts := 1.0 if t > 0.03 else (1.0 if fmod(t, 0.01) < 0.004 else 0.2)
		out[i] = (raw - low) * exp(-t * 22.0) * bursts
	return out

static func _hat(rng: RandomNumberGenerator, open: bool) -> PackedFloat32Array:
	var length := int((0.16 if open else 0.045) * RATE)
	var out := PackedFloat32Array()
	out.resize(length)
	var low := 0.0
	for i in length:
		var t := float(i) / RATE
		var raw := rng.randf_range(-1.0, 1.0)
		low += (raw - low) * 0.75
		out[i] = (raw - low) * exp(-t * (16.0 if open else 70.0))
	return out

static func _riser(rng: RandomNumberGenerator, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var low := 0.0
	for i in length:
		var k := float(i) / length
		var raw := rng.randf_range(-1.0, 1.0)
		low += (raw - low) * (0.02 + 0.5 * k)
		out[i] = (raw - low) * k * k
	return out
