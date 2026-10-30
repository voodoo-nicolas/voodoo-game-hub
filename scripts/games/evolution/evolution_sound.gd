extends RefCounted

## Evolution's own sounds, synthesized in code the first time they play (then cached), so the pack stays
## tiny. They go out through the app's Sfx.play_stream (guarded by the game: older apps stay silent).
##   speck  : a tiny pop for a bit of food
##   eat    : a soft wet "bloop" for a small creature (pitch it down for bigger ones)
##   gulp   : a bigger, lower swallow with a bubble
##   bite   : a dull thud when something bites you
##   evolve : a rising sparkle when you get a new body part
##   chime  : two soft notes for a finished mission
##   zap    : a crackle (electric shock)
##   whoosh : a rush of water (boost, ink, camouflage)
##   spit   : a short wet squirt (acid, harpoon)
##   poison : a wobbling sour note
##   chomp / slurp / munch : eating a creature, one picked at random (owner 2026-10-30: "a variation of 2 or 3
##            sounds at least, not the current one"; eat / gulp are no longer used for meals)
##   chomp  : a jaw snap: a click, a short crunch of noise and a low thump
##   slurp  : a wet rising suck with a bubbly wobble
##   munch  : two quick soft bites, the second lower

const RATE := 22050
static var _cache := {}

static func stream(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var dur := _duration(name)
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var v := 0.0
		match name:
			"speck":
				v = sin(TAU * (1100.0 * t - 4000.0 * t * t)) * exp(-t * 55.0) * 0.30
			"eat":
				var ph := TAU * 640.0 * (1.0 - exp(-5.5 * t)) / 5.5
				var env := (1.0 - exp(-t * 500.0)) * exp(-t * 15.0)
				v = (sin(ph) * 0.55 + sin(ph * 2.0) * 0.18) * env
				if t > 0.07:
					var t2 := t - 0.07
					v += sin(TAU * (900.0 * t2 + 1500.0 * t2 * t2)) * exp(-t2 * 40.0) * 0.25
				if t < 0.012:
					v += (randf() * 2.0 - 1.0) * 0.18 * (1.0 - t / 0.012)
			"gulp":
				var ph2 := TAU * 300.0 * (1.0 - exp(-4.0 * t)) / 4.0
				var env2 := (1.0 - exp(-t * 300.0)) * exp(-t * 9.0)
				v = (sin(ph2) * 0.6 + sin(ph2 * 0.5) * 0.35) * env2
				if t > 0.12:
					var t3 := t - 0.12
					v += sin(TAU * (500.0 * t3 + 2600.0 * t3 * t3)) * exp(-t3 * 28.0) * 0.28
			"bite":
				var nz := randf() * 2.0 - 1.0
				lp += (nz - lp) * 0.18
				v = lp * exp(-t * 18.0) * 0.9 + sin(TAU * 95.0 * t) * exp(-t * 16.0) * 0.5
			"evolve":
				var notes := [523.0, 659.0, 784.0, 1046.0, 1318.0]
				for k in notes.size():
					var t0: float = float(k) * 0.11
					if t >= t0:
						var tn := t - t0
						v += sin(TAU * notes[k] * tn) * exp(-tn * 5.0) * 0.28 * (1.0 - exp(-tn * 200.0))
						v += sin(TAU * notes[k] * 2.0 * tn) * exp(-tn * 9.0) * 0.08
			"chime":
				v = sin(TAU * 660.0 * t) * exp(-t * 7.0) * 0.35
				if t > 0.12:
					var tc := t - 0.12
					v += sin(TAU * 880.0 * tc) * exp(-tc * 7.0) * 0.35
			"zap":
				var nz2 := randf() * 2.0 - 1.0
				var gate := 1.0 if fmod(t * 60.0, 1.0) < 0.5 else 0.3
				v = nz2 * gate * exp(-t * 7.0) * 0.5 + sin(TAU * (1500.0 * t - 2500.0 * t * t)) * exp(-t * 9.0) * 0.35
			"whoosh":
				var nz3 := randf() * 2.0 - 1.0
				lp += (nz3 - lp) * (0.05 + 0.25 * sin(PI * t / dur))
				v = lp * sin(PI * t / dur) * 1.6
			"spit":
				var nz4 := randf() * 2.0 - 1.0
				lp += (nz4 - lp) * 0.3
				v = lp * exp(-t * 14.0) * 0.8 + sin(TAU * (900.0 * t - 1800.0 * t * t)) * exp(-t * 18.0) * 0.3
			"chomp":
				var nz5 := randf() * 2.0 - 1.0
				lp += (nz5 - lp) * 0.45
				v = lp * exp(-t * 30.0) * 0.55 + sin(TAU * (180.0 * t - 160.0 * t * t)) * exp(-t * 20.0) * 0.55
				if t < 0.006:
					v += (randf() * 2.0 - 1.0) * 0.5
			"slurp":
				phase += TAU * (260.0 + 900.0 * t / dur + 60.0 * sin(TAU * 32.0 * t)) / float(RATE)
				var envs := sin(PI * t / dur) * (0.85 + 0.15 * sin(TAU * 18.0 * t))
				var nz6 := randf() * 2.0 - 1.0
				lp += (nz6 - lp) * 0.08
				v = (sin(phase) * 0.42 + lp * 0.5) * envs
			"munch":
				for k2 in 2:
					var t0b: float = float(k2) * 0.12
					if t >= t0b:
						var tb := t - t0b
						var f0: float = 420.0 if k2 == 0 else 300.0
						var nz7 := randf() * 2.0 - 1.0
						v += (sin(TAU * f0 * (1.0 - exp(-7.0 * tb)) / 7.0) * 0.45 + nz7 * 0.2 * exp(-tb * 60.0)) * (1.0 - exp(-tb * 400.0)) * exp(-tb * 22.0)
			"poison":
				phase += TAU * (220.0 + 45.0 * sin(TAU * 7.0 * t)) / float(RATE)
				v = sin(phase) * exp(-t * 3.0) * 0.4 + sin(phase * 1.5) * exp(-t * 4.0) * 0.15
		var s16 := clampi(int(v * 32000.0), -32768, 32767)
		data.encode_s16(i * 2, s16)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	_cache[name] = w
	return w

static func _duration(name: String) -> float:
	match name:
		"speck":
			return 0.07
		"eat":
			return 0.24
		"gulp":
			return 0.36
		"bite":
			return 0.22
		"evolve":
			return 1.0
		"chime":
			return 0.55
		"zap":
			return 0.38
		"whoosh":
			return 0.4
		"spit":
			return 0.26
		"poison":
			return 0.7
		"chomp":
			return 0.2
		"slurp":
			return 0.3
		"munch":
			return 0.3
	return 0.2
