extends RefCounted

## The musical items' tones, synthesized like the prototype's Web Audio `AU.tone`:
## an oscillator (triangle; chords were sawtooth until 2026-10-13) with a 15 ms attack, a hold,
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
			# Players found the stacked sawtooth notes impossible to tell apart
			# (2026-10-13): a softer triangle tone, each note entering a moment after
			# the last and all held for 2 s, so the pile can be heard building.
			var notes: Array = d.get("notes", [])
			for i in notes.size():
				tones.append([midi_f(notes[i]), i * 0.22, 2.0 - i * 0.22, 0.16, "triangle"])
			length = 2.1
		# second set (gv 4, server gens/mus2.ts)
		"rhythm":
			var unit: float = d.get("unit", 0.15)
			var bar: float = float(d.get("slots", 16)) * unit
			for x in d.get("a", []):
				tones.append([midi_f(88), float(x) * unit, 0.08, 0.25, "triangle"])
			for x in d.get("b", []):
				tones.append([midi_f(88), bar + 0.9 + float(x) * unit, 0.08, 0.25, "triangle"])
			length = bar * 2 + 0.9
		"transpose":
			var step := 0.42
			var n1: Array = d.get("notes1", [])
			for i in n1.size():
				tones.append([midi_f(n1[i]), i * step, 0.34, 0.22, "triangle"])
			var t2 := n1.size() * step + 0.9
			var n2: Array = d.get("notes2", [])
			for i in n2.size():
				tones.append([midi_f(n2[i]), t2 + i * step, 0.34, 0.22, "triangle"])
			length = t2 + n2.size() * step
		"beat":
			var iv: float = d.get("interval", 0.55)
			var off: float = d.get("offset", 0.0)
			var beats := int(d.get("beats", 8))
			for i in beats:
				var t := 0.3 + i * iv
				tones.append([midi_f(43), t, 0.18, 0.45, "triangle"])
				tones.append([midi_f(96), t + off, 0.05, 0.12, "square"])
			length = 0.3 + beats * iv
		"contour":
			var notes: Array = d.get("notes", [])
			for i in notes.size():
				tones.append([midi_f(notes[i]), i * 0.42, 0.36, 0.22, "triangle"])
			length = notes.size() * 0.42
		"cadence":
			for m in d.get("chord", []):
				tones.append([midi_f(m), 0.0, 1.1, 0.1, "triangle"])
			var t := 1.6
			for key in ["a", "b"]:
				var ph: Array = d.get(key, [])
				for i in ph.size():
					var last := i == ph.size() - 1
					tones.append([midi_f(ph[i]), t + i * 0.4, 0.8 if last else 0.34, 0.22, "triangle"])
				t += ph.size() * 0.4 + 1.5
			length = t - 1.0
		"consonance":
			for m in d.get("chord1", []):
				tones.append([midi_f(m), 0.0, 1.4, 0.12, "triangle"])
			for m in d.get("chord2", []):
				tones.append([midi_f(m), 2.0, 1.4, 0.12, "triangle"])
			length = 3.4
	return [render(tones), length]

## Headphone check: 440 Hz then 660 Hz.
static func test_tone() -> AudioStreamWAV:
	return render([[440.0, 0.0, 0.5, 0.22, "triangle"], [660.0, 0.6, 0.5, 0.22, "triangle"]])
