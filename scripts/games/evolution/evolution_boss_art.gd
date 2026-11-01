extends RefCounted

## Evolution's bosses, drawn in code like every other creature (no image assets; the owner's reference pictures of a
## Didinium and of anglerfish, 2026-11-01, were looked at, not used). `draw` paints the body into the pond (under the
## darkness of your sight); `draw_over` paints what must show through the dark: glowing eyes and lures, and the
## warning of the next attack (the aim of a lunge, a claw's reach, the area a sweep will cross, the current of a gulp).
## Local space as in evolution_art.gd: +x is forward, rotated by the boss's `face`.

const Art = preload("res://scripts/games/evolution/evolution_art.gd")
const Data = preload("res://scripts/games/evolution/evolution_data.gd")
const WARN := Color(1.0, 0.25, 0.2)

## Where the boss faces and how open its mouth is, from its state: 0 closed .. 1 wide open.
static func _phase(b: Dictionary) -> float:
	return clampf(b.t / maxf(b.dur, 0.01), 0.0, 1.0)

static func draw(ci: CanvasItem, c: Vector2, r: float, b: Dictionary, t: float, voodoo: bool) -> void:
	var bd := Data.boss_of(b.id)
	var col: Color = bd.get("col", Color.WHITE)
	if b.hit > 0.0:
		col = col.lerp(Color.WHITE, 0.55)
	ci.draw_set_transform(c, b.face, Vector2.ONE)
	match b.id:
		"snapjaw":
			_snapjaw(ci, r, col, b, t, voodoo)
		"lantern":
			_lantern(ci, r, col, b, t, voodoo)
		"ironclaw":
			_ironclaw(ci, r, col, b, t, voodoo)
		"kraken":
			_kraken(ci, r, col, b, t, voodoo)
		"leviathan":
			_leviathan(ci, r, col, b, t, voodoo)
	Art._reset(ci)
	if b.stun > 0.0 or b.state == "tired":
		_dizzy(ci, c, r, t)

## Stars circling its head while it is dizzy: bite now!
static func _dizzy(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	for k in 4:
		var a := t * 3.0 + TAU * float(k) / 4.0
		var p := c + Vector2(cos(a) * r * 0.7, sin(a) * r * 0.25 - r * 1.05)
		Art.disc(ci, p, maxf(r * 0.07, 3.0), Color(1.0, 0.95, 0.5, 0.9))

# ---------- Old Snapjaw: a giant Didinium ----------

## A barrel of clear jelly with two girdles of beating cilia and a cone-shaped snout in front.
static func _snapjaw(ci: CanvasItem, r: float, col: Color, b: Dictionary, t: float, voodoo: bool) -> void:
	var beat := t * (3.0 if b.state == "tired" else 9.0)
	# the body: a rounded barrel, a little wider at the back
	var pts := PackedVector2Array()
	for i in 36:
		var a := TAU * float(i) / 36.0
		var v := Vector2(cos(a) * r * 1.05, sin(a) * r * 0.82)
		v.y *= 1.0 + 0.08 * cos(a)            # (a slightly blunt back)
		v *= 1.0 + 0.02 * sin(a * 5.0 + t * 2.0)
		pts.append(v)
	if voodoo:
		Art._torso(ci, pts, col, true, r)
	else:
		Art.disc(ci, Vector2.ZERO, r * 1.25, Color(col, 0.08))
		ci.draw_colored_polygon(pts, Color(col.darkened(0.35), 0.55))
		ci.draw_colored_polygon(Art._scaled(pts, 0.86), Color(col, 0.35))
		Art.strip(ci, Art._closed(pts), Color(col.lightened(0.4), 0.9), maxf(r * 0.035, 1.5), true)
		# granules and food vacuoles inside
		for k in 14:
			var g := Vector2(fmod(float(k) * 0.618, 1.0) - 0.5, fmod(float(k) * 0.381, 1.0) - 0.5) * Vector2(r * 1.4, r * 1.1)
			var gc := Color("9bbf6a") if k % 3 == 0 else Color(col.darkened(0.3), 0.7)
			Art.disc(ci, g, r * (0.05 + 0.04 * float(k % 4)), Color(gc, 0.75))
		Art.disc(ci, Vector2(-r * 0.25, r * 0.1), r * 0.24, Color(col.darkened(0.4), 0.5))    # the big nucleus
	# two girdles of cilia: rows of short hairs round the barrel
	for gx in [r * 0.45, -r * 0.35]:
		var segs := PackedVector2Array()
		for j in 22:
			var f := float(j) / 21.0
			var y: float = lerpf(-r * 0.8, r * 0.8, f)
			var top := Vector2(gx, y)
			var sway := sin(beat + f * 9.0) * r * 0.12
			segs.append(top)
			segs.append(top + Vector2(-r * 0.2 + sway, sign(y) * r * 0.08))
		ci.draw_multiline(segs, Color(col.lightened(0.5), 0.85), maxf(r * 0.025, 1.2))
		Art.strip(ci, PackedVector2Array([Vector2(gx, -r * 0.8), Vector2(gx + r * 0.05, 0.0), Vector2(gx, r * 0.8)]), Color(col.lightened(0.3), 0.7), maxf(r * 0.05, 2.0), true)
	# the snout: a hollow cone, longer while it lunges
	var ext := 0.0
	if b.state == "tell":
		ext = 0.15 * _phase(b)
	elif b.state == "attack":
		ext = 0.45
	var base_x := r * 0.95
	var tip_x := r * (1.55 + ext)
	var cone := PackedVector2Array([Vector2(base_x, -r * 0.34), Vector2(tip_x, -r * 0.12), Vector2(tip_x + r * 0.05, 0.0), Vector2(tip_x, r * 0.12), Vector2(base_x, r * 0.34)])
	var snout_col := col.lerp(WARN, 0.6 * _phase(b)) if b.state == "tell" else col
	Art._part(ci, cone, snout_col.lightened(0.15), voodoo, r * 0.04, 0.9)
	for k in 4:
		var f := float(k + 1) / 5.0
		var x := lerpf(base_x, tip_x, f)
		var h := lerpf(r * 0.34, r * 0.12, f)
		ci.draw_line(Vector2(x, -h), Vector2(x, h), Color(snout_col.lightened(0.4), 0.6), maxf(r * 0.02, 1.0), true)
	Art.disc(ci, Vector2(tip_x + r * 0.02, 0.0), r * 0.07, Color(0.05, 0.05, 0.08, 0.9))    # the mouth at the tip

# ---------- Lantern Mother: an anglerfish ----------

static func _lantern(ci: CanvasItem, r: float, col: Color, b: Dictionary, t: float, voodoo: bool) -> void:
	var open := 0.55
	if b.state == "attack":
		open = 0.35 + 0.65 * _phase(b)
		if b.t >= b.dur - 0.35:
			open = 0.15
	elif b.state == "tired":
		open = 0.3
	# ragged tail and fins behind
	var sway := sin(t * 2.5) * r * 0.15
	var tail := PackedVector2Array([Vector2(-r * 0.9, -r * 0.25), Vector2(-r * 1.75, -r * 0.6 + sway), Vector2(-r * 1.6, sway * 0.3), Vector2(-r * 1.8, r * 0.55 + sway), Vector2(-r * 0.9, r * 0.25)])
	Art._part(ci, tail, col.darkened(0.2), voodoo, r * 0.03, 0.9)
	for s in [-1.0, 1.0]:
		var fin := PackedVector2Array([Vector2(-r * 0.1, s * r * 0.6), Vector2(-r * 0.75, s * (r * 1.05 + sway * 0.5)), Vector2(-r * 0.6, s * r * 0.55)])
		Art._part(ci, fin, col.darkened(0.1), voodoo, r * 0.025, 0.8)
	# the head-heavy body
	var body := PackedVector2Array()
	for i in 30:
		var a := TAU * float(i) / 30.0
		var x := cos(a)
		var hh := 0.85 if x > 0.0 else 0.85 - 0.45 * absf(x)
		body.append(Vector2(x * r * (1.0 if x > 0.0 else 1.05), sin(a) * r * hh) * (1.0 + 0.03 * sin(a * 7.0 + 1.3)))
	Art._torso(ci, body, col, voodoo, r)
	if not voodoo:
		for k in 7:       # rough, warty skin
			var p := Vector2(r * (0.3 - 0.17 * float(k)), r * 0.45 * sin(float(k) * 2.1))
			Art.disc(ci, p, r * 0.05, Color(col.lightened(0.25), 0.45))
	# the gaping mouth: dark inside, rows of needle teeth
	var jaw := r * 0.75 * open
	var mouth := PackedVector2Array([Vector2(r * 0.25, 0.0), Vector2(r * 1.05, -jaw - r * 0.12), Vector2(r * 1.2, -jaw * 0.2), Vector2(r * 1.2, jaw * 0.3), Vector2(r * 1.0, jaw + r * 0.16)])
	ci.draw_colored_polygon(mouth, Color(0.04, 0.02, 0.05, 0.97))
	var teeth := Color(0.95, 0.92, 0.8)
	for k in 7:
		var f := float(k) / 6.0
		var up := Vector2(lerpf(r * 0.45, r * 1.08, f), lerpf(-r * 0.1, -jaw - r * 0.1, f))
		var lo := Vector2(lerpf(r * 0.45, r * 1.02, f), lerpf(r * 0.1, jaw + r * 0.13, f))
		var ln := r * (0.16 + 0.12 * float(k % 2)) * (0.6 + 0.6 * open)
		ci.draw_colored_polygon(PackedVector2Array([up + Vector2(-r * 0.03, 0), up + Vector2(r * 0.03, 0), up + Vector2(0, ln)]), teeth)
		ci.draw_colored_polygon(PackedVector2Array([lo + Vector2(-r * 0.03, 0), lo + Vector2(r * 0.03, 0), lo + Vector2(0, -ln * 1.2)]), teeth)
	# the small pale eye
	Art.disc(ci, Vector2(r * 0.35, -r * 0.45), r * 0.11, Color(0.75, 0.9, 0.95, 0.95))
	Art.disc(ci, Vector2(r * 0.37, -r * 0.45), r * 0.05, Color(0.02, 0.02, 0.04))
	# the rod of the lure, arching forward over the head
	var rod := PackedVector2Array()
	var tip := lure_local(b, r, t)
	for j in 10:
		var f := float(j) / 9.0
		var p := Vector2(r * 0.2, -r * 0.8).lerp(tip, f) + Vector2(0.0, -sin(PI * f) * r * 0.45)
		rod.append(p)
	Art.strip(ci, rod, col.lightened(0.3), maxf(r * 0.04, 1.5), true)

## The lure's bulb, in her local space.
static func lure_local(b: Dictionary, r: float, t: float) -> Vector2:
	return Vector2(r * 1.55, -r * 0.95) + Vector2(sin(t * 1.7), cos(t * 2.3)) * r * 0.06

# ---------- Ironclaw: a Japanese spider crab ----------

static func _ironclaw(ci: CanvasItem, r: float, col: Color, b: Dictionary, t: float, voodoo: bool) -> void:
	var walk := t * (1.5 if b.state == "idle" else 0.4)
	# eight long jointed legs, four a side
	for s in [-1.0, 1.0]:
		for k in 4:
			var base_a: float = s * (0.75 + 0.45 * float(k))
			var root := Vector2.from_angle(base_a) * r * 0.65
			var knee := Vector2.from_angle(base_a + s * 0.15 + 0.12 * sin(walk + float(k) * 1.7)) * r * 1.75
			var foot := knee + Vector2.from_angle(base_a + s * 0.75 + 0.2 * sin(walk + float(k) * 1.7 + 1.0)) * r * 1.25
			var leg := PackedVector2Array([root, knee, foot])
			Art.strip(ci, leg, col.darkened(0.25), maxf(r * 0.13, 3.0), true)
			Art.strip(ci, leg, col.lightened(0.15), maxf(r * 0.06, 1.5), true)
			Art.disc(ci, knee, r * 0.09, col.lightened(0.1))
	# the carapace: a rounded heart shape with spikes and white spots
	var shell := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		var k := 1.0 + 0.12 * cos(a) - 0.06 * cos(a * 2.0)
		shell.append(Vector2(cos(a) * r * 0.95, sin(a) * r * 0.85) * k)
	Art._torso(ci, shell, col, voodoo, r)
	if not voodoo:
		for k in 9:
			var p := Vector2(r * (0.45 - 0.13 * float(k)), r * 0.55 * sin(float(k) * 2.4))
			Art.disc(ci, p, r * 0.06, Color(1.0, 0.95, 0.9, 0.55))
	# the armoured front rim (bites from the front clang off it)
	var rim := PackedVector2Array()
	for j in 13:
		var a := lerpf(-1.1, 1.1, float(j) / 12.0)
		rim.append(Vector2(cos(a) * r * 1.02, sin(a) * r * 0.93))
	Art.strip(ci, rim, Color(0.85, 0.88, 0.95, 0.9), maxf(r * 0.1, 3.0), true)
	for j in range(1, 12, 2):
		var a := lerpf(-1.1, 1.1, float(j) / 12.0)
		var p := Vector2(cos(a) * r * 1.02, sin(a) * r * 0.93)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 0.05).rotated(a), p + Vector2(0, r * 0.05).rotated(a), p + Vector2(r * 0.16, 0).rotated(a)]), Color(0.9, 0.92, 1.0))
	# eyes on stalks
	for s in [-1.0, 1.0]:
		var e := Vector2(r * 0.9, s * r * 0.22)
		ci.draw_line(Vector2(r * 0.7, s * r * 0.15), e, col.darkened(0.3), maxf(r * 0.05, 1.5), true)
		Art.disc(ci, e, r * 0.08, Color(0.08, 0.05, 0.05))
	# the two big claws, over the shell: the left one stays put, the right one (pulled back while she aims) shoots
	# out during the attack: the same reach as the engine's claw_tip
	_claw(ci, r, col, Vector2.from_angle(-0.38) * r * 1.7, -0.38, false, voodoo)
	var reach := 1.7
	if b.state == "tell":
		reach = 1.4
	elif b.state == "attack":
		reach += 1.2 * sin(PI * _phase(b))
	elif b.grab > 0.0:
		reach = 2.3
	_claw(ci, r, col, Vector2.from_angle(0.38) * r * reach, 0.38, b.state == "tell" or b.grab > 0.0, voodoo)

static func _claw(ci: CanvasItem, r: float, col: Color, tip: Vector2, ang: float, raised: bool, voodoo: bool) -> void:
	var shoulder := Vector2.from_angle(ang * 1.4) * r * 0.75
	var elbow := shoulder.lerp(tip, 0.5) + Vector2.from_angle(ang).orthogonal() * r * 0.18 * signf(ang)
	var arm := PackedVector2Array([shoulder, elbow, tip])
	Art.strip(ci, arm, col.darkened(0.3), maxf(r * 0.24, 4.0), true)
	Art.strip(ci, arm, col.lightened(0.1), maxf(r * 0.13, 2.0), true)
	Art.disc(ci, elbow, r * 0.14, col.lightened(0.05))
	var fwd := (tip - elbow).normalized()
	var side := fwd.orthogonal()
	var gape := 0.6 if raised else 0.22
	# (side = fwd turned -90°, so the -side edge pairs with the finger turned +gape: the outline never crosses itself)
	var pincer := PackedVector2Array([tip - side * r * 0.2, tip + fwd.rotated(gape) * r * 0.6, tip + fwd * r * 0.16, tip + fwd.rotated(-gape) * r * 0.6, tip + side * r * 0.2])
	Art._part(ci, pincer, col.lightened(0.2) if not raised else col.lerp(WARN, 0.5), voodoo, r * 0.03, 0.95)

# ---------- Grey Kraken: a giant squid ----------

static func _kraken(ci: CanvasItem, r: float, col: Color, b: Dictionary, t: float, voodoo: bool) -> void:
	var head := Vector2(r * 0.45, 0.0)
	# eight arms forward, waving
	for k in 8:
		var f0 := (float(k) + 0.5) / 8.0 - 0.5
		var line := PackedVector2Array()
		for j in 10:
			var f := float(j) / 9.0
			line.append(head + Vector2(r * (0.1 + 1.3 * f), f0 * r * (0.7 + 0.8 * f) + sin(t * 2.5 - f * 4.0 + float(k) * 1.3) * r * 0.16 * f))
		if voodoo:
			Art.strip(ci, line, col, maxf(r * 0.04, 1.5), true)
		else:
			Art._tapered(ci, line, r * 0.2, Color(col.darkened(0.1), 0.95))
	# the two long tentacles: they rear back before a sweep and lash across during it
	for s in [-1.0, 1.0]:
		var tl := PackedVector2Array()
		if b.state == "tell":
			# reared back: a curl from the head out to the glowing tip (Boss.kraken_tips: 1.25 rad, 1.9 x her radius)
			var tip_l := Vector2.from_angle(s * 1.25) * r * 1.9
			var ctrl := head + Vector2(r * 1.3, s * r * 0.6)
			for j in 14:
				var f := float(j) / 13.0
				tl.append(head.lerp(ctrl, f).lerp(ctrl.lerp(tip_l, f), f))
		else:
			var end_a: float = s * 0.35 + 0.15 * sin(t * 1.5 + s)
			var reach := 1.9
			if b.state == "attack":
				end_a = (b.aim - 0.9 + 1.8 * _phase(b)) - b.face + s * 0.12
				reach = 3.3
			for j in 14:
				var f := float(j) / 13.0
				var dirv := Vector2.from_angle(lerpf(0.0, end_a, f))
				tl.append(head + dirv * r * reach * f + dirv.orthogonal() * sin(t * 3.0 - f * 6.0) * r * 0.1 * f)
		if voodoo:
			Art.strip(ci, tl, col, maxf(r * 0.05, 1.6), true)
		else:
			Art._tapered(ci, tl, r * 0.16, col.lightened(0.1))
		var club: Vector2 = tl[tl.size() - 1]
		Art.disc(ci, club, r * 0.13, col.lightened(0.2))
	# the long mantle with the fins at the back
	var ml := r * 1.6
	var pts := PackedVector2Array()
	var low := PackedVector2Array()
	for i in 16:
		var u := float(i) / 15.0
		var h := r * 0.62 * sin(PI * pow(u, 0.55)) * (1.0 - 0.45 * u)
		var x := head.x - (ml + head.x) * u
		pts.append(Vector2(x, -h))
		low.append(Vector2(x, h))
	for i in range(14, 0, -1):
		pts.append(low[i])
	var flap := sin(t * 2.4) * r * 0.12
	for s in [-1.0, 1.0]:
		Art._part(ci, PackedVector2Array([Vector2(-ml * 0.55, s * r * 0.25), Vector2(-ml * 1.0, s * (r * 0.95 + flap)), Vector2(-ml * 1.05, s * r * 0.1)]), col, voodoo, r * 0.03, 0.85)
	Art._torso(ci, pts, col, voodoo, r)
	if not voodoo:
		for k in 10:     # the chromatophores: red-brown speckles
			Art.disc(ci, Vector2(-ml * (0.05 + 0.085 * float(k)), r * 0.35 * sin(float(k) * 2.7)), r * 0.05, Color(0.6, 0.25, 0.3, 0.45))
	# the huge eyes
	for s in [-1.0, 1.0]:
		var e := head + Vector2(-r * 0.05, s * r * 0.48)
		Art.disc(ci, e, r * 0.26, Color(0.92, 0.9, 0.85))
		Art.disc(ci, e + Vector2(r * 0.04, 0), r * 0.17, Color(0.05, 0.06, 0.1))
		Art.disc(ci, e + Vector2(-r * 0.02, -r * 0.07), r * 0.05, Color.WHITE)

# ---------- the Hollow Leviathan ----------

static func _leviathan(ci: CanvasItem, r: float, col: Color, b: Dictionary, t: float, voodoo: bool) -> void:
	var open := 0.0
	if b.state == "tell":
		open = 0.5 * _phase(b)
	elif b.state == "attack":
		open = 1.0
	# the flukes at the end of the tail, beating slowly
	var beat := sin(t * 1.6) * r * 0.22
	var fl := Vector2(-r * 2.15, beat)
	Art._part(ci, PackedVector2Array([fl + Vector2(r * 0.15, 0.0), fl + Vector2(-r * 0.55, -r * 0.85 + beat * 0.3), fl + Vector2(-r * 0.3, -r * 0.08), fl + Vector2(-r * 0.3, r * 0.08), fl + Vector2(-r * 0.55, r * 0.85 + beat * 0.3)]), col.darkened(0.15), voodoo, r * 0.03, 1.0)
	# a sperm whale's shape: a huge blunt box of a head, then a long body tapering to the tail
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 22:
		var u := float(i) / 21.0                 # 0 = the snout, 1 = the tail
		var x := lerpf(r * 1.1, -r * 2.15, u)
		var h: float
		if u < 0.06:
			h = r * lerpf(0.5, 0.68, u / 0.06)     # the square front of the head
		elif u < 0.4:
			h = r * 0.68
		else:
			h = r * lerpf(0.68, 0.12, pow((u - 0.4) / 0.6, 0.8))
		var bend := beat * pow(u, 3.0)          # the tail swings with the flukes
		top.append(Vector2(x, -h + bend))
		bot.append(Vector2(x, h + bend))
	bot.reverse()
	var pts := top.duplicate()
	pts.append_array(bot)
	Art._torso(ci, pts, col, voodoo, r)
	if not voodoo:
		# wrinkled ridges along the back, pale scars from squid suckers
		for k in 6:
			var x := r * (0.6 - 0.25 * float(k))
			Art.strip(ci, PackedVector2Array([Vector2(x, -r * 0.55), Vector2(x - r * 0.08, -r * 0.2), Vector2(x, r * 0.15)]), Color(col.lightened(0.2), 0.35), maxf(r * 0.02, 1.0), true)
		for k in 5:
			Art.arc(ci, Vector2(r * (0.5 - 0.3 * float(k)), r * 0.3 * cos(float(k) * 1.9)), r * 0.06, 0.0, TAU, 10, Color(0.85, 0.85, 0.8, 0.35), maxf(r * 0.012, 1.0))
	# the mouth: a long jaw under the head that drops open to gulp
	var jaw := r * 0.42 * open
	var m0 := Vector2(r * 1.0, r * 0.08)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.1, r * 0.2), m0, m0 + Vector2(0.0, jaw + r * 0.04), Vector2(r * 0.1, r * 0.24 + jaw * 0.3)]), Color(0.06, 0.02, 0.04, 0.95))
	for k in 6:
		var p := Vector2(lerpf(r * 0.25, r * 0.95, float(k) / 5.0), r * 0.2 + jaw * (0.3 + 0.7 * float(k) / 5.0))
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.03, 0), p + Vector2(r * 0.03, 0), p + Vector2(0, -r * 0.09)]), Color(0.92, 0.9, 0.8))
	# hollow eye: a dark socket with a faint ember
	Art.disc(ci, Vector2(r * 0.55, -r * 0.3), r * 0.12, Color(0.02, 0.02, 0.03))
	# the weak spots (cracks in the hide, Boss.weak_spots): dim, bright while it is dizzy
	var dizzy: bool = b.state == "tired" or b.stun > 0.0
	for k in 3:
		var p := Vector2(r * (0.35 - 0.45 * float(k)), -r * 0.42)
		var glow := (0.8 + 0.2 * sin(t * 6.0 + float(k))) if dizzy else 0.18
		Art.disc(ci, p, r * 0.18, Color(1.0, 0.5, 0.2, 0.25 * glow))
		Art.disc(ci, p, r * 0.09, Color(1.0, 0.7, 0.3, glow))

# ---------- over the dark: glows and warnings ----------

## `c`, `r` in screen space; `w2s` maps a world point to the screen; `zoom` world -> screen.
static func draw_over(ci: CanvasItem, c: Vector2, r: float, b: Dictionary, t: float, w2s: Callable, zoom: float, player_c: Vector2) -> void:
	var fa: float = b.face
	match b.id:
		"snapjaw":
			if b.state == "tell":
				var a := 0.35 + 0.5 * _phase(b)
				var dir := Vector2.from_angle(fa)
				ci.draw_line(c + dir * r * 1.6, c + dir * r * 7.0, Color(WARN, 0.35 * a), r * 1.2, false)
				Art.disc(ci, c + dir * r * 1.6, r * 0.25, Color(WARN, a))
		"lantern":
			var tip := c + lure_local(b, r, t).rotated(fa)
			var flare := 1.0
			if b.state == "tell":
				flare = 1.0 + 1.5 * _phase(b)
			elif b.state == "attack":
				flare = 2.2
			Art.disc(ci, tip, r * 1.4 * flare, Color(0.3, 0.95, 1.0, 0.06))
			Art.disc(ci, tip, r * 0.55 * flare, Color(0.4, 1.0, 1.0, 0.16))
			Art.disc(ci, tip, r * 0.16 * flare, Color(0.75, 1.0, 1.0, 0.95))
			Art.disc(ci, c + Vector2(r * 0.35, -r * 0.45).rotated(fa), r * 0.06, Color(0.7, 1.0, 1.0, 0.8))
			if b.state == "attack":
				for q in 8:          # the pull: streaks running into her mouth
					var f := fposmod(t * 1.6 + float(q) / 8.0, 1.0)
					var dir := Vector2.from_angle(fa + PI + (float(q) - 3.5) * 0.22)
					var mouth := c + Vector2.from_angle(fa) * r * 0.85
					var p := mouth - dir * r * (4.0 * (1.0 - f) + 0.4)
					ci.draw_line(p, p + dir * r * 0.5, Color(0.6, 1.0, 1.0, 0.5 * f), maxf(r * 0.04, 2.0), true)
			for m in b.minions:
				var mp: Vector2 = w2s.call(m.pos)
				var mr: float = b.r * 0.16 * zoom
				Art.disc(ci, mp, mr * 2.2, Color(0.4, 1.0, 1.0, 0.1))
				var hd: float = m.vel.angle()
				var body := PackedVector2Array([mp + Vector2(mr, 0).rotated(hd), mp + Vector2(-mr * 0.6, -mr * 0.6).rotated(hd), mp + Vector2(-mr * 1.4, 0).rotated(hd), mp + Vector2(-mr * 0.6, mr * 0.6).rotated(hd)])
				ci.draw_colored_polygon(body, Color(0.25, 0.32, 0.4))
				Art.disc(ci, mp + Vector2(mr * 0.9, -mr * 0.8).rotated(hd), mr * 0.3, Color(0.75, 1.0, 1.0, 0.95))
		"ironclaw":
			if b.state == "tell":
				Art.arc(ci, c, r * 2.9, fa + 0.38 - 0.5, fa + 0.38 + 0.5, 20, Color(WARN, 0.25 + 0.5 * _phase(b)), maxf(r * 0.08, 3.0), false)
			for s in [-1.0, 1.0]:
				Art.disc(ci, c + Vector2(r * 0.9, s * r * 0.22).rotated(fa), r * 0.035, Color(1.0, 0.4, 0.3, 0.9))
		"kraken":
			if b.state == "tell":
				var a := 0.15 + 0.3 * _phase(b)
				var pts := PackedVector2Array([c])
				for j in 17:
					pts.append(c + Vector2.from_angle(b.aim - 0.9 + 1.8 * float(j) / 16.0) * r * 3.4)
				ci.draw_colored_polygon(pts, Color(WARN, a * 0.4))
				Art.arc(ci, c, r * 3.4, b.aim - 0.9, b.aim + 0.9, 24, Color(WARN, a + 0.2), maxf(r * 0.05, 2.0), false)
				for s in [-1.0, 1.0]:      # the tentacle tips: bite one to stun her
					var tp := c + Vector2.from_angle(fa + s * 1.25) * r * 1.9
					var pulse := 0.6 + 0.4 * sin(t * 10.0)
					Art.disc(ci, tp, r * 0.35, Color(1.0, 0.85, 0.3, 0.2 * pulse))
					Art.disc(ci, tp, r * 0.15, Color(1.0, 0.9, 0.4, pulse))
			for s in [-1.0, 1.0]:
				Art.disc(ci, c + (Vector2(r * 0.4, s * r * 0.48)).rotated(fa), r * 0.06, Color(0.9, 0.95, 1.0, 0.5))
		"leviathan":
			if b.state == "tell" or b.state == "attack":
				var mouth := c + Vector2.from_angle(fa) * r * 0.95
				var k := 1.0 if b.state == "attack" else _phase(b)
				for q in 12:
					var f := fposmod(t * 1.3 + float(q) / 12.0, 1.0)
					var dir := Vector2.from_angle(fa + PI + (float(q) - 5.5) * 0.17)
					var p := mouth - dir * r * (4.5 * (1.0 - f) + 0.3)
					ci.draw_line(p, p + dir * r * 0.6, Color(0.7, 0.85, 1.0, 0.45 * f * k), maxf(r * 0.04, 2.0), true)
			Art.disc(ci, c + Vector2(r * 0.55, -r * 0.3).rotated(fa), r * 0.04, Color(1.0, 0.45, 0.2, 0.8))
	# Off screen: an arrow on the edge of the screen points at it.
	var s: Vector2 = ci.get_size() if ci is Control else Vector2(1280, 720)
	if c.x < -r * 0.5 or c.y < -r * 0.5 or c.x > s.x + r * 0.5 or c.y > s.y + r * 0.5:
		var dir2 := (c - player_c).normalized()
		var edge := player_c + dir2 * minf(s.x, s.y) * 0.42
		var arrow := PackedVector2Array([edge + dir2 * 26.0, edge + dir2.rotated(2.5) * 18.0, edge + dir2.rotated(-2.5) * 18.0])
		ci.draw_colored_polygon(arrow, Color(WARN, 0.6 + 0.3 * sin(t * 6.0)))
