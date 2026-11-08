extends RefCounted

## The ship drawn from its parts (design doc v2 §1.2: big ship, visible mods): hull by tier, wings on
## bigger hulls, one turret per weapon socket (the gun model shows), one engine per engine socket with
## its flame, cargo pods, the scanner's antenna, the shield bubble, the Ghost Core's glow and a lit
## window per crew member. Pieces come from the shared sprite library (Kenney space set, CC0); every
## id is a full string literal so the pack carries it. Enemies use the same drawer.

const SpriteLib = preload("res://scripts/games/the_runner/sprite_lib.gd")

const HULLS := {"moth": "space/player_ship1_green", "runner_1": "space/player_ship2_blue",
	"runner_2": "space/player_ship3_blue", "runner_3": "space/player_ship2_orange", "runner_4": "space/player_ship3_orange"}
const GUNS := {"wpn_1": "space/gun_0", "wpn_2": "space/gun_4", "wpn_3": "space/gun_8"}
const ENGINES := {"eng_1": "space/engine_1", "eng_2": "space/engine_3", "eng_3": "space/engine_5"}
const SHIELDS := {"shd_1": "space/shield_1", "shd_2": "space/shield_2", "shd_3": "space/shield_3"}
const WINGS := ["space/wing_blue_0", "space/wing_blue_3", "space/wing_blue_5"]
const FLAMES := ["space/fire_11", "space/fire_12", "space/fire_13"]
const SCALE_BY_TIER := [1.0, 1.0, 1.12, 1.26, 1.42]

static var _cache := {}

static func tex(id: String) -> Texture2D:
	if id == "":
		return null
	if not _cache.has(id):
		_cache[id] = SpriteLib.texture(id)
	return _cache[id]

## The player's ship as a spec (engine = the_runner_engine.gd instance).
static func spec_of(e) -> Dictionary:
	var hull_id: String = HULLS.moth if e.ship != "runner" else HULLS["runner_%d" % e.tier]
	return {"hull": hull_id, "tier": e.tier if e.ship == "runner" else 1, "guns": e.guns(),
		"gun": GUNS.get(e.modules.get("weapons", "wpn_1"), GUNS.wpn_1), "engines": e.sockets("engines"),
		"engine": ENGINES.get(e.modules.get("engine", "eng_1"), ENGINES.eng_1),
		"shield": SHIELDS.get(e.modules.get("shields", "shd_1"), SHIELDS.shd_1),
		"pods": {"car_1": 0, "car_2": 1, "car_3": 2}.get(e.modules.get("cargo", "car_1"), 0),
		"antenna": {"scn_1": 0, "scn_2": 1, "scn_3": 2}.get(e.modules.get("scanner", "scn_1"), 0),
		"ghost": e.ship == "runner", "crew": e.crew.size(), "specials": e.specials.size()}

## An enemy ship as a spec (one entry of engine.battle_enemies()).
static func spec_enemy(s: Dictionary) -> Dictionary:
	return {"hull": str(s.get("sprite", "space/enemy_black_1")), "tier": 1, "guns": int(s.get("guns", 1)),
		"gun": "space/gun_2", "engines": 0, "shield": "space/shield_1", "pods": 0, "antenna": 0,
		"ghost": false, "crew": 0, "enemy": true}

## Draw the ship centred on `at`, `width` wide (the hull's width), nose along `heading` (radians,
## 0 = right). `moving`: engine flames. `shield`: 0..1 bubble strength. `t`: a clock for pulses.
static func draw(ci: CanvasItem, at: Vector2, width: float, heading: float, sp: Dictionary,
		moving: bool = false, shield: float = 0.0, t: float = 0.0, tint: Color = Color.WHITE) -> void:
	var hull: Texture2D = tex(str(sp.hull))
	if hull == null:
		ci.draw_circle(at, width * 0.3, tint)
		return
	var w := width * float(SCALE_BY_TIER[clampi(int(sp.get("tier", 1)), 0, 4)])
	var h := w * hull.get_height() / float(hull.get_width())
	var base := Transform2D(heading + PI / 2.0, at)   # sprites face up (-y)
	var enemy: bool = sp.get("enemy", false)
	if enemy:
		base = Transform2D(heading + PI / 2.0 + PI, at) # enemy sprites face down: turn them round
	# wings on bigger hulls
	var tier := int(sp.get("tier", 1))
	if tier >= 2 and not enemy:
		var wing: Texture2D = tex(str(WINGS[mini(tier - 2, WINGS.size() - 1)]))
		if wing:
			var ws := Vector2(w * 0.42, w * 0.42 * wing.get_height() / float(wing.get_width()))
			_part(ci, base, wing, Vector2(-w * 0.5, h * 0.05), ws, false, tint)
			_part(ci, base, wing, Vector2(w * 0.5, h * 0.05), ws, true, tint)
	# engines and flames (behind the hull)
	var n_eng := int(sp.get("engines", 0))
	var eng: Texture2D = tex(str(sp.get("engine", "")))
	for i in n_eng:
		var x := (i - (n_eng - 1) / 2.0) * w * 0.26
		if moving:
			var fl: Texture2D = tex(str(FLAMES[int(t * 12.0 + i) % FLAMES.size()]))
			if fl:
				var fs := Vector2(w * 0.12, w * 0.12 * fl.get_height() / float(fl.get_width()))
				_part(ci, base, fl, Vector2(x, h * 0.5 + fs.y * 0.45), fs, false, tint)
		if eng:
			var es := Vector2(w * 0.24, w * 0.24 * eng.get_height() / float(eng.get_width()))
			_part(ci, base, eng, Vector2(x, h * 0.42), es, false, tint)
	# cargo pods on the flanks
	for i in int(sp.get("pods", 0)):
		for side in [-1.0, 1.0]:
			var pr := Rect2(Vector2(side * (w * 0.44 + i * w * 0.09) - w * 0.04, h * 0.05), Vector2(w * 0.08, h * 0.32))
			ci.draw_set_transform_matrix(base)
			ci.draw_rect(pr, Color(0.55, 0.6, 0.68, tint.a))
			ci.draw_rect(pr, Color(0.15, 0.2, 0.3, tint.a), false, 1.5)
	# the hull
	_part(ci, base, hull, Vector2.ZERO, Vector2(w, h), false, tint)
	# turrets
	var n_gun := int(sp.get("guns", 1))
	var gun: Texture2D = tex(str(sp.get("gun", "")))
	if gun:
		var gs := Vector2(w * 0.09, w * 0.09 * gun.get_height() / float(gun.get_width()))
		for i in n_gun:
			var x := (i - (n_gun - 1) / 2.0) * minf(w * 0.8 / maxi(1, n_gun - 1), w * 0.28) if n_gun > 1 else 0.0
			var y := -h * 0.25 + absf(x) / w * h * 0.4
			_part(ci, base, gun, Vector2(x, y), gs, false, tint)
	ci.draw_set_transform_matrix(base)
	# antenna (scanner)
	for i in int(sp.get("antenna", 0)):
		var a0 := Vector2(w * (0.12 + i * 0.1), -h * 0.1)
		var a1 := a0 + Vector2(w * 0.06, -h * 0.32)
		ci.draw_line(a0, a1, Color(0.85, 0.9, 1.0, tint.a), 2.0)
		ci.draw_rect(Rect2(a1 - Vector2(3, 3), Vector2(6, 6)), Color(1.0, 0.4, 0.3, tint.a * (0.5 + 0.5 * sin(t * 5.0 + i))))
	# crew windows
	for i in int(sp.get("crew", 0)):
		var wr := Rect2(Vector2(-w * 0.03, -h * 0.05 + i * h * 0.09), Vector2(w * 0.06, h * 0.05))
		ci.draw_rect(wr, Color(1.0, 0.9, 0.5, 0.9 * tint.a))
	# the Ghost Core
	if sp.get("ghost", false):
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		ci.draw_rect(Rect2(Vector2(-w * 0.05, h * 0.18), Vector2(w * 0.1, w * 0.1)), Color(0.75, 0.45, 1.0, (0.55 + 0.4 * pulse) * tint.a))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	# the shield bubble
	if shield > 0.01:
		var sh: Texture2D = tex(str(sp.get("shield", "space/shield_1")))
		if sh:
			var ss := Vector2(w, h) * 1.45
			_part(ci, base, sh, Vector2.ZERO, ss, false, Color(1, 1, 1, clampf(shield, 0.0, 1.0) * 0.7 * tint.a))
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)

static func _part(ci: CanvasItem, base: Transform2D, t: Texture2D, local: Vector2, sz: Vector2, flip: bool, tint: Color) -> void:
	var m := base * Transform2D(0.0, Vector2(-1.0 if flip else 1.0, 1.0), 0.0, local)
	ci.draw_set_transform_matrix(m)
	ci.draw_texture_rect(t, Rect2(-sz / 2.0, sz), false, tint)
