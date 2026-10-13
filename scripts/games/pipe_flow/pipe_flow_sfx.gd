extends RefCounted

## Wire Up's own electrical sounds, made in code (no audio files, no download
## size). Played through the shared Sfx autoload's play_stream() when the app
## has it (older apps stay silent): see PipeFlow `_zap()`.
##
##   turn    a relay click when a piece is turned
##   zap     a bulb catching current: crackle, rising whine, bright ping
##   green   the same with a mixed-colour shimmer
##   short   a bulb fed the wrong colour: low buzz
##   power   current coming back up the wire after a bulb goes out
##   done    the level-complete surge

const RATE := 22050

static var _cache: Dictionary = {}

static func stream(name: String) -> AudioStreamWAV:
	if not _cache.has(name):
		_cache[name] = _render(name)
	return _cache[name]

static func _render(name: String) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	match name:
		"turn":
			buf.resize(int(0.09 * RATE))
			_noise(buf, 0.0, 0.012, 0.5, 60.0, 0.9)
			_tone(buf, 0.0, 0.08, 210.0, 120.0, "tri", 0.35, 38.0)
			_tone(buf, 0.03, 0.05, 1800.0, 1500.0, "square", 0.05, 70.0)
		"zap":
			buf.resize(int(0.5 * RATE))
			_noise(buf, 0.0, 0.14, 0.35, 16.0, 0.6)
			_tone(buf, 0.0, 0.16, 140.0, 1100.0, "saw", 0.18, 6.0)
			_tone(buf, 0.14, 0.36, 1320.0, 1320.0, "sine", 0.3, 9.0)
			_tone(buf, 0.14, 0.36, 1980.0, 1980.0, "sine", 0.12, 12.0)
		"green":
			buf.resize(int(0.7 * RATE))
			_noise(buf, 0.0, 0.14, 0.3, 16.0, 0.6)
			_tone(buf, 0.0, 0.18, 140.0, 1300.0, "saw", 0.16, 6.0)
			_tone(buf, 0.16, 0.5, 1046.0, 1046.0, "sine", 0.26, 6.0)
			_tone(buf, 0.24, 0.42, 1568.0, 1568.0, "sine", 0.22, 6.0)
			_tone(buf, 0.32, 0.36, 2093.0, 2093.0, "sine", 0.16, 7.0)
		"short":
			buf.resize(int(0.4 * RATE))
			_noise(buf, 0.0, 0.3, 0.4, 7.0, 0.5)
			_tone(buf, 0.0, 0.34, 220.0, 70.0, "square", 0.22, 6.0)
			_tone(buf, 0.0, 0.34, 110.0, 55.0, "saw", 0.2, 5.0)
		"power":
			buf.resize(int(0.3 * RATE))
			_noise(buf, 0.0, 0.1, 0.2, 20.0, 0.7)
			_tone(buf, 0.0, 0.26, 90.0, 520.0, "saw", 0.16, 7.0)
		"done":
			buf.resize(int(1.3 * RATE))
			_noise(buf, 0.0, 0.3, 0.3, 8.0, 0.5)
			_tone(buf, 0.0, 0.35, 100.0, 1500.0, "saw", 0.16, 3.0)
			for i in 5:
				var f: float = [523.25, 659.25, 783.99, 1046.5, 1318.5][i]
				_tone(buf, 0.3 + i * 0.1, 0.9 - i * 0.1, f, f, "sine", 0.22, 4.0)
		_:
			buf.resize(1)
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav

static func _tone(buf: PackedFloat32Array, at: float, len_s: float, f1: float, f2: float,
		wave: String, vol: float, dec: float) -> void:
	var start := int(at * RATE)
	var count := int(len_s * RATE)
	var phase := 0.0
	for i in count:
		var j := start + i
		if j >= buf.size():
			break
		var t := float(i) / RATE
		var k := t / len_s
		phase = fmod(phase + lerpf(f1, f2, k) / RATE, 1.0)
		var s: float
		match wave:
			"square":
				s = 1.0 if phase < 0.5 else -1.0
			"tri":
				s = 4.0 * absf(phase - 0.5) - 1.0
			"saw":
				s = 2.0 * phase - 1.0
			_:
				s = sin(TAU * phase)
		var env := minf(t / 0.003, 1.0) * exp(-t * dec) * minf((len_s - t) / 0.006, 1.0)
		buf[j] += s * env * vol

## Crackle: noise with a fast random gate, so it sounds like arcing.
static func _noise(buf: PackedFloat32Array, at: float, len_s: float, vol: float, dec: float, bright: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var start := int(at * RATE)
	var count := int(len_s * RATE)
	var low := 0.0
	var gate := 1.0
	for i in count:
		var j := start + i
		if j >= buf.size():
			break
		if i % 90 == 0:
			gate = 1.0 if rng.randf() < 0.65 else 0.15
		var raw := rng.randf_range(-1.0, 1.0)
		low += (raw - low) * bright
		var t := float(i) / RATE
		buf[j] += (raw - low * 0.6) * gate * exp(-t * dec) * vol * minf((len_s - t) / 0.004, 1.0)
