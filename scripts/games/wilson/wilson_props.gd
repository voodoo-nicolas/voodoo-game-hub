extends Node2D

## Beached: PLACEHOLDER drawings for built structures and gather piles (no art yet; ART_PROMPTS.md
## lists the sprites to generate). One node per prop, origin = its base on the sand (plate pixels), so
## the y-sort puts Johnny in front or behind correctly. Drawn once; `refresh()` redraws.

const FROND := Color("5f9a3c")
const FROND_D := Color("3f6e28")
const DRY := Color("c9a86a")
const WOOD := Color("7a5232")
const WOOD_D := Color("4e321e")
const ROPE := Color("c8a874")
const CLOTH := Color("ece4cf")
const LINE := Color("2a1c12")

var kind := ""
var amount := 1.0       # piles: how full (0..1)
var data := {}          # e.g. {"tallies": 3}

func refresh() -> void:
	queue_redraw()

func _poly(pts: Array, col: Color) -> void:
	var p := PackedVector2Array(pts)
	draw_colored_polygon(p, col)
	p.append(pts[0])
	draw_polyline(p, LINE, 2.0)

func _draw() -> void:
	match kind:
		"frond_bed":
			_poly([Vector2(-48, 0), Vector2(-40, -10), Vector2(40, -10), Vector2(48, 0), Vector2(40, 6), Vector2(-40, 6)], FROND)
			for i in 7:
				draw_line(Vector2(-36 + i * 12, -8), Vector2(-30 + i * 12, 4), FROND_D, 2.0)
		"hammock":
			# hung between palm A (445, 382) and palm B (600, 382); this node sits at (522, 372)
			var a := Vector2(-74, -30)
			var b := Vector2(74, -30)
			var pts := []
			for i in 13:
				var f := float(i) / 12.0
				pts.append(a.lerp(b, f) + Vector2(0, sin(PI * f) * 34.0))
			var cloth := PackedVector2Array(pts)
			for i in range(12, -1, -1):
				var f := float(i) / 12.0
				cloth.append(a.lerp(b, f) + Vector2(0, sin(PI * f) * 22.0))
			draw_colored_polygon(cloth, Color("d9c9a3"))
			draw_polyline(PackedVector2Array(pts), LINE, 2.0)
			draw_line(a + Vector2(-8, -6), a, ROPE, 3.0)
			draw_line(b + Vector2(8, -6), b, ROPE, 3.0)
		"frond_shelter", "tent":
			var col := FROND if kind == "frond_shelter" else CLOTH
			_poly([Vector2(-58, 0), Vector2(0, -70), Vector2(58, 0)], col)
			_poly([Vector2(-16, 0), Vector2(0, -34), Vector2(16, 0)], Color(0.12, 0.1, 0.08))
			if kind == "frond_shelter":
				for i in 6:
					draw_line(Vector2(-50 + i * 8, -6 - i * 9), Vector2(-30 + i * 8, -2 - i * 9), FROND_D, 2.0)
			draw_line(Vector2(0, -70), Vector2(0, -80), WOOD, 4.0)
		"crafting_stump":
			_poly([Vector2(-22, 0), Vector2(-22, -28), Vector2(22, -28), Vector2(22, 0)], WOOD)
			draw_set_transform(Vector2(0, -28), 0.0, Vector2(1.0, 0.32))
			draw_circle(Vector2.ZERO, 22.0, Color("b98a5a"))
			draw_arc(Vector2.ZERO, 14.0, 0, TAU, 20, WOOD_D, 2.0)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			var n := int(data.get("tallies", 0))
			for i in mini(n, 12):
				var x := -16 + i * 3 + int(i / 5) * 2
				if i % 5 == 4:
					draw_line(Vector2(x - 14, -20), Vector2(x, -8), LINE, 1.5)
				else:
					draw_line(Vector2(x, -22), Vector2(x, -8), LINE, 1.5)
		"rain_catcher":
			_poly([Vector2(-18, 0), Vector2(-20, -40), Vector2(20, -40), Vector2(18, 0)], WOOD)
			draw_line(Vector2(-20, -12), Vector2(20, -12), Color("666"), 3.0)
			draw_line(Vector2(-20, -30), Vector2(20, -30), Color("666"), 3.0)
			_poly([Vector2(-36, -64), Vector2(36, -64), Vector2(8, -40), Vector2(-8, -40)], FROND)
		"drying_rack":
			draw_line(Vector2(-36, 0), Vector2(-30, -50), WOOD, 4.0)
			draw_line(Vector2(36, 0), Vector2(30, -50), WOOD, 4.0)
			for i in 3:
				draw_line(Vector2(-32, -48 + i * 12), Vector2(32, -48 + i * 12), ROPE, 2.0)
		"fish_trap":
			_poly([Vector2(-26, 0), Vector2(-20, -18), Vector2(20, -18), Vector2(26, 0)], Color(0.48, 0.34, 0.2, 0.8))
			for i in 6:
				draw_line(Vector2(-22 + i * 9, -18), Vector2(-24 + i * 10, 0), WOOD_D, 1.5)
		"sos_flag":
			draw_line(Vector2(0, 0), Vector2(0, -90), WOOD, 4.0)
			_poly([Vector2(2, -88), Vector2(46, -80), Vector2(2, -64)], Color("d84a3a"))
		"garden_plot":
			_poly([Vector2(-44, 0), Vector2(-36, -16), Vector2(36, -16), Vector2(44, 0)], Color("6b4a2e"))
			for i in 4:
				draw_line(Vector2(-30 + i * 20, -2), Vector2(-26 + i * 20, -14), Color("4b321e"), 2.0)
		"canopy":
			draw_line(Vector2(-50, 0), Vector2(-50, -64), WOOD, 4.0)
			draw_line(Vector2(50, 0), Vector2(50, -64), WOOD, 4.0)
			_poly([Vector2(-62, -64), Vector2(62, -64), Vector2(52, -78), Vector2(-52, -78)], FROND)
		"pile_sticks":
			var n := int(ceil(amount * 6.0))
			for i in n:
				var a := -0.5 + float(i) * 0.2
				draw_set_transform(Vector2((i - 3) * 4, -4), a, Vector2.ONE)
				draw_rect(Rect2(-18, -2, 36, 4), WOOD)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		"pile_fronds", "pile_dry":
			var col := FROND if kind == "pile_fronds" else DRY
			var n := int(ceil(amount * 5.0))
			for i in n:
				var a := -0.7 + float(i) * 0.35
				var tip := Vector2(cos(a) * 30.0, -6.0 + sin(a) * 6.0)
				draw_line(Vector2.ZERO, tip, col, 5.0)
				for k in 4:
					var p := Vector2.ZERO.lerp(tip, 0.25 + k * 0.2)
					draw_line(p, p + Vector2(-4, -7), col, 2.0)
		"pile_seaweed":
			var n := int(ceil(amount * 4.0))
			for i in n:
				draw_line(Vector2(-14 + i * 8, 0), Vector2(-10 + i * 8, -10), Color("3d6b3a"), 3.0)
		"shore":
			_poly([Vector2(-26, 0), Vector2(-24, -14), Vector2(4, -16), Vector2(8, 0)], Color("8a6a44"))
			draw_set_transform(Vector2(22, -6), -0.4, Vector2.ONE)
			draw_rect(Rect2(-12, -5, 24, 10), Color(0.45, 0.75, 0.6, 0.85))
			draw_rect(Rect2(12, -2, 6, 4), Color("6b4a2a"))
			draw_set_transform_matrix(Transform2D.IDENTITY)
		"stump":
			_poly([Vector2(-12, 0), Vector2(-12, -14), Vector2(12, -14), Vector2(12, 0)], WOOD)
			draw_set_transform(Vector2(0, -14), 0.0, Vector2(1.0, 0.35))
			draw_circle(Vector2.ZERO, 12.0, Color("c89a66"))
			draw_set_transform_matrix(Transform2D.IDENTITY)
