extends Control
const Art = preload("res://scripts/games/hesperia/game/art.gd")
## Animated title backdrop (Landing style S4 "Monument", see Minigame Art/styles/MENU_STYLES.md):
## dusk over the Aegean - gradient sky, twinkling stars, banded sun, drifting clouds, layered headlands,
## a cliff temple with a lit brazier (the one accent colour), shimmering sea, gulls, rising embers,
## and the hero large on the right, cropped by the bottom edge. All procedural; nothing is loaded but the hero strip.

const Fx := preload("res://scripts/games/hesperia/game/fx.gd")

var t: float = 0.0
var male: bool = true
var hair: String = "brown"
var stars: Array = []
var embers: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		stars.append(Vector3(rng.randf(), rng.randf() * 0.42, rng.randf() * TAU))
	for i in 18:
		embers.append({"p": Vector2(rng.randf() * 480.0, rng.randf() * 216.0), "v": rng.randf_range(6, 14), "ph": rng.randf() * TAU})

func _process(dt: float) -> void:
	t += dt
	for e in embers:
		e["p"].y -= float(e["v"]) * dt
		e["p"].x += sin(t + e["ph"]) * 4.0 * dt
		if e["p"].y < 70.0:
			e["p"] = Vector2(randf() * get_viewport_rect().size.x, 216.0 + randf() * 20.0)
	queue_redraw()

func _band(y0: float, y1: float, c0: Color, c1: Color) -> void:
	var w := get_viewport_rect().size.x
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))

func _ridge(base: float, amp: float, freq: float, seed_ph: float, col: Color, scroll: float) -> void:
	var w := get_viewport_rect().size.x
	var pts := PackedVector2Array()
	pts.append(Vector2(0, get_viewport_rect().size.y))
	var x := 0.0
	while x <= w + 4.0:
		var y := base - amp * (0.55 * sin((x + scroll) * freq + seed_ph) + 0.3 * sin((x + scroll) * freq * 2.7 + seed_ph * 1.7) + 0.15 * sin((x + scroll) * freq * 6.1))
		pts.append(Vector2(x, roundf(y)))
		x += 4.0
	pts.append(Vector2(w, get_viewport_rect().size.y))
	draw_colored_polygon(pts, col)

func _draw() -> void:
	var w := get_viewport_rect().size.x
	var h := get_viewport_rect().size.y
	var hz := roundf(h * 0.62)            # horizon
	# sky
	_band(0, h * 0.28, Color(0.07, 0.05, 0.16), Color(0.24, 0.12, 0.30))
	_band(h * 0.28, h * 0.48, Color(0.24, 0.12, 0.30), Color(0.72, 0.30, 0.30))
	_band(h * 0.48, hz, Color(0.72, 0.30, 0.30), Color(0.98, 0.62, 0.34))
	for s in stars:
		var tw := 0.5 + 0.5 * sin(t * 1.7 + s.z)
		draw_rect(Rect2(roundf(s.x * w), roundf(s.y * h), 1, 1), Color(1, 0.95, 0.9, 0.25 + 0.6 * tw * (1.0 - s.y * 2.0)))
	# sun: glow + banded disc sinking into the sea
	var sc := Vector2(roundf(w * 0.6), hz - 10.0)
	Fx.glow(self, sc, 70.0, Color(1.0, 0.55, 0.3, 0.22), 6)
	for i in 20:
		var yy := sc.y - 26.0 + float(i) * 2.0
		if i > 10 and i % 3 == 0:
			continue                       # retro cut lines in the lower half
		var dy := yy - sc.y
		var hw := sqrt(maxf(0.0, 26.0 * 26.0 - dy * dy))
		var col := Color(1.0, 0.92, 0.6).lerp(Color(1.0, 0.45, 0.25), float(i) / 20.0)
		draw_rect(Rect2(sc.x - hw, yy, hw * 2.0, 2), col)
	# clouds (long thin bands drifting)
	for i in 5:
		var cy := h * (0.12 + 0.07 * float(i))
		var cx := fposmod(float(i) * 97.0 + t * (3.0 + float(i)), w + 160.0) - 80.0
		var cc := Color(0.95, 0.55, 0.45, 0.22) if i > 2 else Color(0.55, 0.3, 0.5, 0.3)
		draw_rect(Rect2(roundf(cx), roundf(cy), 60.0 + float(i) * 14.0, 2), cc)
		draw_rect(Rect2(roundf(cx) + 12.0, roundf(cy) - 2.0, 30.0 + float(i) * 6.0, 2), cc)
	# far headlands
	_ridge(hz - 4.0, 16.0, 0.018, 1.3, Color(0.36, 0.17, 0.30), 0.0)
	_band(hz, hz + 1.0, Color(1.0, 0.75, 0.5, 0.0), Color(1.0, 0.75, 0.5, 0.0))
	# sea
	_band(hz, h, Color(0.30, 0.20, 0.33), Color(0.06, 0.08, 0.16))
	draw_rect(Rect2(0, hz, w, 1), Color(1.0, 0.8, 0.55, 0.6))
	for i in 26:                           # sun glitter column
		var yy := hz + 2.0 + float(i) * 2.6
		var spread := 8.0 + float(i) * 2.2
		var wob := sin(t * 2.0 + float(i) * 1.7) * spread * 0.4
		var a := 0.75 * (1.0 - float(i) / 26.0)
		draw_rect(Rect2(roundf(sc.x - spread * 0.5 + wob), roundf(yy), roundf(spread * (0.4 + 0.3 * sin(t * 3.0 + float(i)))), 1), Color(1.0, 0.75, 0.45, a))
	for i in 18:                           # wave dashes
		var yy := hz + 6.0 + float((i * 37) % 70)
		var xx := fposmod(float(i * 71) + t * 6.0 * (1.0 + float(i % 3)), w + 30.0) - 15.0
		draw_rect(Rect2(roundf(xx), roundf(yy), 6.0 + float(i % 4) * 3.0, 1), Color(0.6, 0.55, 0.75, 0.25))
	# left cliff + temple (landmark), accent = brazier fire
	var cliff := PackedVector2Array([Vector2(0, h), Vector2(0, h * 0.36), Vector2(w * 0.12, h * 0.38), Vector2(w * 0.2, h * 0.47),
		Vector2(w * 0.24, h * 0.62), Vector2(w * 0.3, h * 0.78), Vector2(w * 0.34, h)])
	draw_colored_polygon(cliff, Color(0.12, 0.07, 0.14))
	draw_polyline(PackedVector2Array([Vector2(w * 0.12, h * 0.38), Vector2(w * 0.2, h * 0.47), Vector2(w * 0.24, h * 0.62)]), Color(0.85, 0.45, 0.35, 0.5), 1.0)
	var tb := Vector2(roundf(w * 0.02), roundf(h * 0.36))   # temple base-left
	var tc := Color(0.17, 0.10, 0.19)
	draw_rect(Rect2(tb + Vector2(0, -3), Vector2(44, 3)), tc)
	for k in 6:
		draw_rect(Rect2(tb + Vector2(3 + k * 7, -21), Vector2(3, 18)), tc)
	draw_rect(Rect2(tb + Vector2(-1, -24), Vector2(46, 3)), tc)
	draw_colored_polygon(PackedVector2Array([tb + Vector2(-2, -24), tb + Vector2(46, -24), tb + Vector2(22, -32)]), tc)
	var bz := tb + Vector2(52, -6)
	draw_rect(Rect2(bz + Vector2(-1, 0), Vector2(3, 6)), tc)
	var fl := 1.0 + 0.25 * sin(t * 11.0) + 0.15 * sin(t * 17.0)
	Fx.glow(self, bz + Vector2(0.5, -2), 14.0 * fl, Color(1.0, 0.55, 0.15, 0.35), 5)
	draw_colored_polygon(PackedVector2Array([bz + Vector2(-2, 0), bz + Vector2(3, 0), bz + Vector2(0.5, -6.0 * fl)]), Color(1.0, 0.7, 0.25))
	draw_rect(Rect2(bz + Vector2(0, -2), Vector2(1, 2)), Color(1, 0.95, 0.7))
	# gulls
	for i in 3:
		var gx := fposmod(t * (9.0 + float(i) * 3.0) + float(i) * 140.0, w + 40.0) - 20.0
		var gy := h * (0.2 + 0.08 * float(i)) + sin(t * 1.5 + float(i)) * 3.0
		var flap := 1.0 if sin(t * 8.0 + float(i)) > 0.0 else -1.0
		var gc := Color(0.12, 0.07, 0.15, 0.9)
		draw_line(Vector2(gx - 3, gy - flap), Vector2(gx, gy), gc, 1.0)
		draw_line(Vector2(gx, gy), Vector2(gx + 3, gy - flap), gc, 1.0)
	# foreground rock on the right, hero standing on it (low angle, cropped by the bottom edge)
	var rock := PackedVector2Array([Vector2(w * 0.58, h), Vector2(w * 0.66, h * 0.86), Vector2(w * 0.8, h * 0.82),
		Vector2(w * 0.95, h * 0.85), Vector2(w, h * 0.9), Vector2(w, h)])
	draw_colored_polygon(rock, Color(0.08, 0.05, 0.1))
	draw_polyline(PackedVector2Array([Vector2(w * 0.66, h * 0.86), Vector2(w * 0.8, h * 0.82), Vector2(w * 0.95, h * 0.85)]), Color(1.0, 0.6, 0.4, 0.55), 1.0)
	var base := "hero_m" if male else "hero_f"
	var key := base + ("" if hair == "brown" else "_" + hair) + "_walk_down"
	var ht := Art.anim_frame_tex(key)
	if ht == null:
		ht = Art.anim_frame_tex(base + "_walk_down")
	if ht != null:
		var sz := ht.get_size()
		var sc2 := floorf(h * 0.82 / sz.y)
		var dst := Vector2(sz.x, sz.y) * sc2
		var pos := Vector2(roundf(w * 0.79 - dst.x * 0.5), roundf(h * 0.86 - dst.y + sc2 * 3.0 + sin(t * 1.2) * 1.0))
		draw_texture_rect(ht, Rect2(pos + Vector2(sc2, sc2), dst), false, Color(0.08, 0.03, 0.1, 0.45))   # contact shadow
		draw_texture_rect(ht, Rect2(pos, dst), false, Color(0.92, 0.78, 0.78))                            # dusk-lit
	# embers drifting up from the brazier side
	for e in embers:
		var p: Vector2 = (e["p"] as Vector2).round()
		var a2 := clampf((p.y - 70.0) / 80.0, 0.0, 1.0)
		draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.7, 0.35, 0.7 * a2))
	# vignette
	for i in 6:
		var a3 := 0.05 * float(6 - i)
		draw_rect(Rect2(0, 0, w, 3.0 + float(i) * 3.0), Color(0.02, 0.01, 0.04, a3))
		draw_rect(Rect2(0, h - 3.0 - float(i) * 3.0, w, 3.0 + float(i) * 3.0), Color(0.02, 0.01, 0.04, a3))
	# rule under the logo
	draw_rect(Rect2(roundf(w * 0.05), roundf(h * 0.245), roundf(w * 0.42), 1), Color(0.95, 0.75, 0.4, 0.75))
	draw_rect(Rect2(roundf(w * 0.05), roundf(h * 0.245) + 1, roundf(w * 0.42), 1), Color(0.2, 0.08, 0.15, 0.6))
