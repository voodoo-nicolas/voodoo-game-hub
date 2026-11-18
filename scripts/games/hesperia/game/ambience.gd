extends Control
## Screen-space atmosphere above the world, under the colour grade: pollen + drifting leaves (meadows/coast),
## fireflies + low mist (marsh), dust motes (dungeons/interiors), rising embers (prologue raid).
## Pure decoration: never blocks input, never touches game state. ~40 particles, drawn as pixels.

const Fx := preload("res://scripts/games/hesperia/game/fx.gd")

var kind: String = ""          # meadow | marsh | dungeon | interior | fire | ""
var parts: Array = []
var mist: Array = []
var last_cam: Vector2 = Vector2.ZERO
var cam_pos: Vector2 = Vector2.ZERO
var t: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_kind(k: String) -> void:
	if k == kind:
		return
	kind = k
	parts.clear()
	mist.clear()
	var n: int = {"meadow": 26, "marsh": 22, "dungeon": 24, "interior": 16, "fire": 40}.get(k, 0)
	for i in n:
		parts.append(_spawn(true))
	if k == "marsh":
		for i in 5:
			mist.append({"p": Vector2(randf() * _w(), 60.0 + randf() * 150.0), "s": 0.6 + randf() * 0.8, "w": 70.0 + randf() * 80.0})

func _w() -> float:
	return get_viewport_rect().size.x

func _h() -> float:
	return get_viewport_rect().size.y

func _spawn(anywhere: bool) -> Dictionary:
	var p := Vector2(randf() * _w(), randf() * _h())
	var d := {"p": p, "ph": randf() * TAU, "life": 0.0, "max": 4.0 + randf() * 5.0, "z": 0.6 + randf() * 0.8, "leaf": false}
	match kind:
		"meadow":
			d["leaf"] = randf() < 0.22
			d["v"] = Vector2(8.0 + randf() * 6.0, 3.0 + randf() * 4.0) if d["leaf"] else Vector2(randf_range(-3, 5), randf_range(-4, -1))
		"marsh":
			d["v"] = Vector2(randf_range(-4, 4), randf_range(-3, 3))
		"fire":
			d["v"] = Vector2(randf_range(-8, 8), randf_range(-38, -18))
			d["max"] = 1.5 + randf() * 2.0
			if not anywhere:
				d["p"] = Vector2(randf() * _w(), _h() + 4.0)
		_:
			d["v"] = Vector2(randf_range(-2, 2), randf_range(-1.5, 1.0))
	if anywhere:
		d["life"] = randf() * float(d["max"])
	return d

func _process(dt: float) -> void:
	if not visible or kind == "":
		return
	t += dt
	var dc := cam_pos - last_cam
	last_cam = cam_pos
	if dc.length() > 40.0:       # area change: don't fling everything
		dc = Vector2.ZERO
	for i in parts.size():
		var d: Dictionary = parts[i]
		d["life"] += dt
		var wob := Vector2(sin(t * 1.3 + d["ph"]) * 3.0, cos(t * 0.9 + d["ph"]) * 2.0) * dt
		d["p"] += d["v"] * dt + wob - dc * float(d["z"]) * 0.35
		var p: Vector2 = d["p"]
		if d["life"] > d["max"] or p.x < -10.0 or p.x > _w() + 10.0 or p.y < -10.0 or p.y > _h() + 10.0:
			parts[i] = _spawn(false)
	for m in mist:
		m["p"].x += float(m["s"]) * 4.0 * dt - dc.x * 0.2
		m["p"].y -= dc.y * 0.2
		if m["p"].x - m["w"] > _w():
			m["p"].x = -float(m["w"])
		elif m["p"].x + m["w"] < -20.0:
			m["p"].x = _w() + float(m["w"])
	queue_redraw()

func _fade(d: Dictionary) -> float:
	var l: float = d["life"]
	var mx: float = d["max"]
	return clampf(minf(l / 0.8, (mx - l) / 0.8), 0.0, 1.0)

func _draw() -> void:
	for m in mist:
		var c: Vector2 = m["p"]
		Fx.ellipse(self, c, float(m["w"]), 7.0, Color(0.75, 0.9, 0.8, 0.05))
		Fx.ellipse(self, c + Vector2(10, 2), float(m["w"]) * 0.6, 4.0, Color(0.8, 0.95, 0.85, 0.05))
	for d in parts:
		var a := _fade(d)
		var p: Vector2 = (d["p"] as Vector2).round()
		match kind:
			"meadow":
				if d["leaf"]:
					var sw := sin(t * 3.0 + d["ph"])
					var col := Color(0.55, 0.7, 0.3, 0.75 * a) if int(d["ph"] * 10.0) % 3 != 0 else Color(0.85, 0.65, 0.3, 0.75 * a)
					draw_rect(Rect2(p, Vector2(2 if sw > 0.0 else 1, 1)), col)
				else:
					draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.97, 0.8, 0.55 * a * (0.6 + 0.4 * sin(t * 2.0 + d["ph"]))))
			"marsh":
				var pulse := maxf(0.0, sin(t * 2.2 + d["ph"] * 3.0))
				Fx.glow(self, p + Vector2(0.5, 0.5), 3.5, Color(0.75, 1.0, 0.35, 0.35 * a * pulse), 3)
				draw_rect(Rect2(p, Vector2.ONE), Color(0.95, 1.0, 0.6, a * (0.35 + 0.65 * pulse)))
			"fire":
				var k := clampf(1.0 - float(d["life"]) / float(d["max"]), 0.0, 1.0)
				var ec := Color(1.0, 0.75, 0.3).lerp(Color(0.9, 0.2, 0.05), 1.0 - k)
				Fx.glow(self, p, 3.0, Color(ec.r, ec.g, ec.b, 0.25 * a), 2)
				draw_rect(Rect2(p, Vector2.ONE * (2.0 if k > 0.6 else 1.0)), Color(ec.r, ec.g, ec.b, a))
			_:
				var c2 := Color(0.85, 0.8, 0.7) if kind == "dungeon" else Color(1.0, 0.85, 0.6)
				draw_rect(Rect2(p, Vector2.ONE), Color(c2.r, c2.g, c2.b, 0.3 * a * float(d["z"])))
