extends RefCounted
## Neon Blast look pass (2026-11-25): what sits behind and in front of the
## arena, never the arena itself (arena_canvas.gd draws play).
##   Backdrop  under the grid: deep-space gradient, three parallax star layers
##             that twinkle, slow drifting nebula clouds, tinted per skin.
##   Overlay   over the arena: a soft vignette (depth, keeps eyes centre),
##             full-screen flashes (bomb, boss kill, level cleared) and a red
##             edge pulse when the ship is hit.
## Cheap on phones: every star / cloud is one draw_texture_rect of a shared
## soft-disc texture (~0.5 µs each, docs gotcha on draw_circle), ~150 a frame;
## only 3 big see-through clouds + 1 vignette (GPU fill).
## Also tiny UI helpers: pop() for banners / labels, press squash for buttons.

const STAR_TILE := 1400.0  # px; star layers repeat every tile
const LAYERS := [  # [count, parallax, size px min, max, alpha]
	[70, 0.08, 1.2, 2.2, 0.45],
	[45, 0.18, 1.8, 3.2, 0.65],
	[22, 0.32, 2.6, 4.6, 0.9],
]

## Shared textures + colours (inner classes reach these as Art.*).
class Art:
	static var _disc: Texture2D
	static var _vignette: Texture2D

	## A white soft disc (bright core, glow falling off to nothing).
	static func disc() -> Texture2D:
		if _disc == null:
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 1))
			g.set_color(1, Color(1, 1, 1, 0))
			g.add_point(0.25, Color(1, 1, 1, 0.75))
			var t := GradientTexture2D.new()
			t.gradient = g
			t.fill = GradientTexture2D.FILL_RADIAL
			t.fill_from = Vector2(0.5, 0.5)
			t.fill_to = Vector2(1.0, 0.5)
			t.width = 64
			t.height = 64
			_disc = t
		return _disc

	## Clear in the middle, dark at the edges.
	static func vignette() -> Texture2D:
		if _vignette == null:
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 0))
			g.set_color(1, Color(1, 1, 1, 1))
			g.add_point(0.55, Color(1, 1, 1, 0))
			g.add_point(0.85, Color(1, 1, 1, 0.45))
			var t := GradientTexture2D.new()
			t.gradient = g
			t.fill = GradientTexture2D.FILL_RADIAL
			t.fill_from = Vector2(0.5, 0.5)
			t.fill_to = Vector2(1.08, 0.5)
			t.width = 128
			t.height = 128
			_vignette = t
		return _vignette

	## Skin colours: [top, bottom, nebula A, nebula B, star tint].
	static func palette(classic: bool) -> Array:
		if classic:
			return [Color(0.015, 0.02, 0.06), Color(0.03, 0.01, 0.07),
				Color(0.1, 0.25, 0.8), Color(0.5, 0.15, 0.7), Color(0.75, 0.85, 1.0)]
		return [Color(0.03, 0.01, 0.05), Color(0.07, 0.01, 0.04),
			Color(0.55, 0.08, 0.35), Color(0.2, 0.1, 0.6), Color(1.0, 0.85, 0.85)]


class Backdrop extends Control:
	var game: Control
	var classic := false
	var _stars: Array = []  # [pos, size, alpha, layer, twinkle phase]
	var _grad: GradientTexture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 7071
		for li in LAYERS.size():
			var l: Array = LAYERS[li]
			for i in int(l[0]):
				_stars.append([Vector2(rng.randf() * STAR_TILE, rng.randf() * STAR_TILE),
					rng.randf_range(l[2], l[3]), float(l[4]) * rng.randf_range(0.6, 1.0), li, rng.randf() * TAU])
		_grad = GradientTexture2D.new()
		_grad.gradient = Gradient.new()
		_grad.fill_from = Vector2(0.5, 0.0)
		_grad.fill_to = Vector2(0.5, 1.0)
		_grad.width = 4
		_grad.height = 64
		_set_colors()

	func set_classic(c: bool) -> void:
		classic = c
		_set_colors()
		queue_redraw()

	func _set_colors() -> void:
		var p := Art.palette(classic)
		_grad.gradient.set_color(0, p[0])
		_grad.gradient.set_color(1, p[1])

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var s := size
		draw_texture_rect(_grad, Rect2(Vector2.ZERO, s), false)
		var cam: Vector2 = game.cam if game else Vector2.ZERO
		var t := Time.get_ticks_msec() / 1000.0
		var p := Art.palette(classic)
		var tex := Art.disc()
		# Nebula clouds: huge, faint, barely moving (furthest layer).
		var clouds := [[Vector2(0.25, 0.3), 0.9, p[2]], [Vector2(0.8, 0.7), 1.1, p[3]], [Vector2(0.55, 0.05), 0.7, p[3]]]
		for c in clouds:
			var r: float = float(c[1]) * maxf(s.x, s.y) * (1.0 + 0.04 * sin(t * 0.21 + float(c[1]) * 5.0))
			var centre: Vector2 = Vector2(c[0]) * s - cam * 0.04 + Vector2(sin(t * 0.05), cos(t * 0.04)) * 30.0
			draw_texture_rect(tex, Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c[2], 0.16))
		# Stars, three parallax depths, wrapped over the view.
		for st in _stars:
			var par: float = LAYERS[int(st[3])][1]
			var q: Vector2 = Vector2(st[0]) - cam * par
			q = Vector2(fposmod(q.x, STAR_TILE), fposmod(q.y, STAR_TILE))
			var tw := 0.65 + 0.35 * sin(t * (1.3 + float(st[3])) + float(st[4]))
			var sz: float = float(st[1]) * 3.0
			var col := Color(p[4], float(st[2]) * tw)
			var x := q.x
			while x < s.x + sz:
				var y := q.y
				while y < s.y + sz:
					draw_texture_rect(tex, Rect2(Vector2(x, y) - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, col)
					y += STAR_TILE
				x += STAR_TILE


class Overlay extends Control:
	var flash_col := Color.WHITE
	var flash_a := 0.0
	var hurt_a := 0.0
	var tint := Color(0, 0, 0)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Full-screen flash fading out (bomb, boss down, level cleared).
	func flash(col: Color, strength: float = 0.35) -> void:
		flash_col = col
		flash_a = maxf(flash_a, strength)

	## The ship was hit: the screen edges burn red.
	func hurt() -> void:
		hurt_a = 1.0

	func _process(delta: float) -> void:
		var busy := flash_a > 0.0 or hurt_a > 0.0
		flash_a = maxf(0.0, flash_a - delta * 1.6)
		hurt_a = maxf(0.0, hurt_a - delta * 1.4)
		if busy:
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_texture_rect(Art.vignette(), r, false, Color(tint, 0.75))
		if hurt_a > 0.0:
			draw_texture_rect(Art.vignette(), r, false, Color(1.0, 0.1, 0.15, hurt_a * 0.8))
		if flash_a > 0.0:
			draw_rect(r, Color(flash_col, flash_a * flash_a))


## A quick scale pop from the centre (banner, score...).
static func pop(c: Control, amount: float = 0.25, time: float = 0.35) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	c.scale = Vector2.ONE * (1.0 + amount)
	tw.tween_property(c, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Buttons squash on press and spring back.
static func squash_on_press(b: BaseButton) -> void:
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2(0.92, 0.92), 0.06))
	b.button_up.connect(func() -> void:
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
