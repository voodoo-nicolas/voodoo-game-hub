extends RefCounted

## Tiny synthesized sound effects (0 bytes of audio files). Placeholder until the hub's shared
## sound library / real recordings are wired in. All 16-bit mono.

const RATE := 22050

static func _make(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

## Two-note "ding-dong" chime that comes before each intercom line.
static func chime() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var second := t >= 0.35
		var f := 1046.5 if second else 784.0
		var local := t - (0.35 if second else 0.0)
		s[i] = sin(TAU * f * t) * exp(-local * 4.5) * 0.45
	return _make(s)

## Low distant thud: decaying low sine plus a little noise.
static func thud() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := int(RATE * 0.7)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 7.0)
		s[i] = (sin(TAU * 55.0 * t) * 0.8 + rng.randf_range(-1.0, 1.0) * 0.25 * exp(-t * 20.0)) * env
	return _make(s)

## Short mechanical click (valves, doors, lockers).
static func click() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var n := int(RATE * 0.08)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		s[i] = rng.randf_range(-1.0, 1.0) * exp(-float(i) / RATE * 60.0) * 0.5
	return _make(s)

## Dull buzz for a locked door.
static func buzz() -> AudioStreamWAV:
	var n := int(RATE * 0.25)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (1.0 if fmod(t * 110.0, 1.0) < 0.5 else -1.0) * 0.25 * (1.0 - t / 0.25)
	return _make(s)

## Rising two-tone blip for picking something up / solving the puzzle.
static func pickup() -> AudioStreamWAV:
	var n := int(RATE * 0.35)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 660.0 if t < 0.15 else 990.0
		s[i] = sin(TAU * f * t) * 0.35 * (1.0 - t / 0.35)
	return _make(s)

## Looping two-tone siren (warbles between two pitches).
static func siren() -> AudioStreamWAV:
	var n := int(RATE * 2.0)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 620.0 + 260.0 * (0.5 + 0.5 * sin(TAU * 0.5 * t))   # exactly one warble per 2 s loop
		phase += TAU * f / RATE
		s[i] = sin(phase) * 0.3
	return _make(s, true)

## Whoosh of the wrench swing (short filtered noise).
static func swing() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := int(RATE * 0.14)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		lp = lp * 0.6 + rng.randf_range(-1.0, 1.0) * 0.4
		s[i] = lp * sin(PI * t) * 0.5
	return _make(s)

## Dull thump when the wrench connects.
static func hit() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n := int(RATE * 0.2)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (sin(TAU * 90.0 * t) * 0.7 + rng.randf_range(-1.0, 1.0) * 0.3) * exp(-t * 18.0)
	return _make(s)

## Falling wail for the coworker being grabbed (placeholder scream).
static func scream() -> AudioStreamWAV:
	var n := int(RATE * 1.0)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 900.0 - 500.0 * t + 40.0 * sin(TAU * 9.0 * t)
		phase += TAU * f / RATE
		s[i] = (sin(phase) * 0.5 + sin(phase * 2.0) * 0.15) * (1.0 - t) * 0.6
	return _make(s)

## Short falling buzz when Nash is hurt.
static func hurt() -> AudioStreamWAV:
	var n := int(RATE * 0.25)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (260.0 - 500.0 * t) / RATE
		s[i] = (1.0 if sin(phase) > 0.0 else -1.0) * 0.3 * (1.0 - t / 0.25)
	return _make(s)

## Pistol shot: sharp noise burst with a low thump (loud on purpose: it draws infected).
static func shot() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var n := int(RATE * 0.3)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (rng.randf_range(-1.0, 1.0) * exp(-t * 25.0) * 0.8 + sin(TAU * 70.0 * t) * exp(-t * 14.0) * 0.6)
	return _make(s)

## Low rough roar when a runner wakes up.
static func roar() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var n := int(RATE * 0.8)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (110.0 + 30.0 * sin(TAU * 7.0 * t)) / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		s[i] = (saw * 0.45 + rng.randf_range(-1.0, 1.0) * 0.2) * sin(PI * minf(1.0, t / 0.8)) * 0.7
	return _make(s)

## Rummaging through a drawer / locker (searching): a few soft scrapes and clicks.
static func rummage() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var n := int(RATE * 0.9)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		# three bursts of filtered noise, like hands moving things around
		var env := 0.0
		for k in 3:
			var c := 0.12 + k * 0.28
			env += exp(-pow((t - c) / 0.07, 2.0))
		lp = lp * 0.75 + rng.randf_range(-1.0, 1.0) * 0.25
		s[i] = lp * env * 0.55
	return _make(s)

## Birds taking off: quick fluttering wing beats.
static func flutter() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 57
	var n := int(RATE * 0.8)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var beat := 0.5 + 0.5 * sin(TAU * 14.0 * t)
		lp = lp * 0.5 + rng.randf_range(-1.0, 1.0) * 0.5
		s[i] = lp * beat * (1.0 - t / 0.8) * 0.4
	return _make(s)

## v0.5: a window shattering: a hard crack, then bright tinkling shards falling.
static func glass() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 63
	var n := int(RATE * 1.2)
	var s := PackedFloat32Array()
	s.resize(n)
	var hp := 0.0
	var last := 0.0
	# the shards: short high pings at random moments
	var pings: Array = []
	for k in 26:
		pings.append([rng.randf_range(0.03, 1.0), rng.randf_range(2600.0, 6200.0), rng.randf_range(0.15, 0.4)])
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		hp = 0.6 * (hp + noise - last)        # high-passed noise for the crack
		last = noise
		var v := hp * exp(-t * 30.0) * 0.9
		for p in pings:
			var dt: float = t - float(p[0])
			if dt >= 0.0 and dt < 0.12:
				v += sin(TAU * float(p[1]) * dt) * exp(-dt * 45.0) * float(p[2])
		s[i] = v * 0.7
	return _make(s)

## v0.5: the infected eating: wet, low tearing sounds.
static func chew() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var n := int(RATE * 1.4)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := 0.0
		for k in 4:
			var c := 0.15 + k * 0.32
			env += exp(-pow((t - c) / 0.06, 2.0))
		lp = lp * 0.9 + rng.randf_range(-1.0, 1.0) * 0.1
		s[i] = (lp * 3.0 + sin(TAU * 60.0 * t) * 0.2) * env * 0.5
	return _make(s)

## v0.5: a coolant can bursting: a pop and a long cold hiss.
static func frost() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var n := int(RATE * 1.3)
	var s := PackedFloat32Array()
	s.resize(n)
	var hp := 0.0
	var last := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		hp = 0.85 * (hp + noise - last)
		last = noise
		var pop := sin(TAU * 140.0 * t) * exp(-t * 40.0) * 0.6
		s[i] = pop + hp * 0.35 * minf(1.0, t / 0.05) * exp(-t * 2.2)
	return _make(s)
