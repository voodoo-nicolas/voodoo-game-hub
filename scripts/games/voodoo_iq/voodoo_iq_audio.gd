extends RefCounted

## The musical items' tones, synthesized like the prototype's Web Audio `AU.tone`:
## an oscillator (triangle, or sawtooth for chords) with a 15 ms attack, a hold,
## and a 50 ms release, at the prototype's volumes. A whole clip (all its notes at
## their start times) is rendered into one AudioStreamWAV and played once.

const RATE := 22050

static func midi_f(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)

## tones: Array of [freq_hz, start_s, dur_s, volume, "triangle"|"sawtooth"|"square"]
static func render(tones: Array) -> AudioStreamWAV:
	var total := 0.0
	for tn in tones:
		total = maxf(total, float(tn[1]) + float(tn[2]) + 0.05)
	var n := int(total * RATE) + 1
	var buf := PackedFloat32Array()
	buf.resize(n)
	for tn in tones:
		var f: float = tn[0]
		var t0: float = tn[1]
		var dur: float = tn[2]
		var vol: float = tn[3]
		var wave: String = tn[4] if tn.size() > 4 else "triangle"
		var s0 := int(t0 * RATE)
		var s1 := mini(n, int((t0 + dur) * RATE))
		for s in range(s0, s1):
			var t := float(s - s0) / RATE
			var env := vol
			if t < 0.015:
				env = vol * t / 0.015
			elif t > dur - 0.05:
				env = vol * maxf(0.0, (dur - t) / 0.05)
			var ph := fposmod(f * t, 1.0)
			var v := 0.0
			match wave:
				"sawtooth":
					v = 2.0 * ph - 1.0
				"square":
					v = 1.0 if ph < 0.5 else -1.0
				_:
					v = 4.0 * absf(ph - 0.5) - 1.0
			buf[s] += v * env
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for s in n:
		bytes.encode_s16(s * 2, int(clampf(buf[s], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav

## The clip for one musical item (its `display` from the server), and its length.
static func item_clip(gid: String, d: Dictionary) -> Array:
	var tones: Array = []
	var length := 0.0
	match gid:
		"pitch":
			var fr: Array = d.get("freqs", [])
			for i in fr.size():
				tones.append([float(fr[i]), i * 0.75, 0.45, 0.22, "triangle"])
			length = 2.3
		"pitchhl":
			tones.append([float(d.f1), 0.0, 0.4, 0.22, "triangle"])
			tones.append([float(d.f2), 0.6, 0.4, 0.22, "triangle"])
			length = 1.0
		"melody":
			var nd: float = d.get("noteDur", 0.34)
			var gap: float = d.get("gap", 0.08)
			var n1: Array = d.get("notes1", [])
			var len1 := n1.size() * (nd + gap)
			for i in n1.size():
				tones.append([midi_f(n1[i]), i * (nd + gap), nd, 0.22, "triangle"])
			var n2: Array = d.get("notes2", [])
			for i in n2.size():
				tones.append([midi_f(n2[i]), len1 + 0.9 + i * (nd + gap), nd, 0.22, "triangle"])
			length = len1 * 2 + 0.9
		"chord":
			for m in d.get("notes", []):
				tones.append([midi_f(m), 0.0, 1.1, 0.11, "sawtooth"])
			length = 1.2
	return [render(tones), length]

## Headphone check: 440 Hz then 660 Hz.
static func test_tone() -> AudioStreamWAV:
	return render([[440.0, 0.0, 0.5, 0.22, "triangle"], [660.0, 0.6, 0.5, 0.22, "triangle"]])
