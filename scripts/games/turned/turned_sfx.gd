extends RefCounted

## Placeholder sounds for Turned, synthesized in code (final audio comes later, from the audio plan).
## Played through the hub's Sfx autoload when it is there (so the app's sound settings apply),
## else on a small player of our own. Names: heartbeat, pulse, breath, pickup, unlock, burn,
## step, door, whoosh, death.

const RATE := 22050

static var _streams := {}

static func stream(name: String) -> AudioStreamWAV:
	if _streams.has(name):
		return _streams[name]
	var s := _wav(_samples(name))
	_streams[name] = s
	return s

## Plays `name` from `host` (any node in the tree). `db` trims the volume.
static func play(host: Node, name: String, db: float = 0.0, pitch: float = 1.0) -> void:
	if host == null or not host.is_inside_tree():
		return
	var s := stream(name)
	var sfx := host.get_node_or_null("/root/Sfx")
	if sfx != null and sfx.has_method("play_stream"):
		sfx.play_stream(s, db, pitch, "game")
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	host.add_child(p)
	p.play()

static func _wav(data: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

static func _buf(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * RATE))
	return a

static func _samples(name: String) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	match name:
		"heartbeat":
			var a := _buf(0.95)
			for i in a.size():
				var t := float(i) / RATE
				a[i] = _thump(t, 0.0, 52.0, 0.9) + _thump(t, 0.3, 46.0, 0.6)
			return a
		"pulse":
			var a := _buf(1.4)
			for i in a.size():
				var t := float(i) / RATE
				var env := sin(PI * t / 1.4)
				a[i] = sin(TAU * 58.0 * t) * env * env * 0.7 * (0.75 + 0.25 * sin(TAU * 7.0 * t)) \
					+ sin(TAU * 116.0 * t) * env * 0.12
			return a
		"breath":
			var a := _buf(0.9)
			var lp := 0.0
			for i in a.size():
				var t := float(i) / RATE
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.12
				a[i] = lp * sin(PI * t / 0.9) * 0.55
			return a
		"pickup":
			var a := _buf(0.16)
			for i in a.size():
				var t := float(i) / RATE
				a[i] = sin(TAU * 520.0 * t) * exp(-t * 28.0) * 0.4 + sin(TAU * 780.0 * t) * exp(-t * 34.0) * 0.2
			return a
		"unlock":
			var a := _buf(1.3)
			var notes := [330.0, 392.0, 494.0, 659.0]
			for i in a.size():
				var t := float(i) / RATE
				var v := 0.0
				for k in notes.size():
					var tk := t - float(k) * 0.14
					if tk > 0.0:
						v += sin(TAU * float(notes[k]) * tk) * exp(-tk * 3.2) * 0.2
				a[i] = v
			return a
		"burn":
			var a := _buf(0.4)
			for i in a.size():
				var t := float(i) / RATE
				var click := 1.0 if rng.randf() < 0.012 else 0.0
				a[i] = (rng.randf_range(-1.0, 1.0) * click * 0.7 + rng.randf_range(-0.04, 0.04)) * exp(-t * 4.0)
			return a
		"step":
			var a := _buf(0.07)
			var lp := 0.0
			for i in a.size():
				var t := float(i) / RATE
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.3
				a[i] = lp * exp(-t * 60.0) * 0.6
			return a
		"door":
			var a := _buf(0.5)
			var lp := 0.0
			for i in a.size():
				var t := float(i) / RATE
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
				a[i] = sin(TAU * 70.0 * t) * exp(-t * 14.0) * 0.5 + lp * exp(-t * 6.0) * 0.4
			return a
		"whoosh":
			var a := _buf(0.3)
			var lp := 0.0
			for i in a.size():
				var t := float(i) / RATE
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.06
				a[i] = lp * sin(PI * t / 0.3) * 0.5
			return a
		"cough":
			# two rough coughs
			var a := _buf(0.5)
			var lp := 0.0
			for i in a.size():
				var t := float(i) / RATE
				var u := fposmod(t, 0.22)
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.25
				a[i] = lp * exp(-u * 20.0) * (1.0 if t < 0.44 else 0.0) * 0.7
			return a
		"tick":
			# a watch: a dry click with a small ring
			var a := _buf(0.09)
			for i in a.size():
				var t := float(i) / RATE
				a[i] = (sin(TAU * 2300.0 * t) * 0.35 + rng.randf_range(-1.0, 1.0) * 0.25) * exp(-t * 90.0)
			return a
		"bark":
			# a dog far away: two short rough barks
			var a := _buf(0.42)
			var ph := 0.0
			for i in a.size():
				var t := float(i) / RATE
				var u := fposmod(t, 0.2)
				ph += TAU * (380.0 - 700.0 * u) / RATE
				var env := exp(-u * 16.0) * (1.0 if t < 0.34 else 0.0)
				a[i] = (sin(ph) * 0.5 + rng.randf_range(-1.0, 1.0) * 0.25) * env
			return a
		"death":
			var a := _buf(1.2)
			var ph := 0.0
			for i in a.size():
				var t := float(i) / RATE
				ph += TAU * (220.0 * exp(-t * 2.2) + 40.0) / RATE
				a[i] = sin(ph) * exp(-t * 2.0) * 0.5
			return a
	return _buf(0.05)

## One thump of a heartbeat starting at `start` seconds: a falling low sine with a quick decay.
static func _thump(t: float, start: float, hz: float, amp: float) -> float:
	var x := t - start
	if x < 0.0:
		return 0.0
	return sin(TAU * (hz + 30.0 * exp(-x * 30.0)) * x) * exp(-x * 14.0) * amp * 0.7
