extends Node2D
const HydraEngine = preload("res://scripts/games/hesperia/core/hydra_engine.gd")
const Art = preload("res://scripts/games/hesperia/game/art.gd")
const Data = preload("res://scripts/games/hesperia/data.gd")
const WorldState = preload("res://scripts/games/hesperia/world_state.gd")
## Lernaean Hydra (bosses.json b01): 5 heads, hp 24, 2 phases. All the rules live in HydraEngine (headless-tested);
## this node only does positions, attack telegraphs and drawing.
## Sword on a head -> stump (regrows). Fire (Torch / Brand) on a stump -> head gone for good.

signal defeated

var area
var player
var eng: HydraEngine
var head_x: Array = []        # world x of each head
var base_y: float = 56.0
var atk: Array = []           # per head: {state: "idle"|"wind"|"lunge", t}
var flash: Array = []

func setup(a, p, center: Vector2) -> void:
	area = a
	player = p
	eng = HydraEngine.new(int(Data.bosses["b01"]["hp"]))
	base_y = center.y
	for i in HydraEngine.HEADS:
		head_x.append(center.x - 56.0 + float(i) * 28.0)
		atk.append({"state": "idle", "t": 1.5 + randf() * 2.5})
		flash.append(0.0)
	add_to_group("hittable")

func head_rect(i: int) -> Rect2:
	var reach := 0.0
	if atk[i]["state"] == "lunge":
		reach = 40.0
	return Rect2(Vector2(head_x[i] - 7.0, base_y + 8.0 + reach - 7.0), Vector2(14, 14))

func _process(dt: float) -> void:
	if player == null:
		return
	eng.tick(dt)
	var speed := 1.6 if eng.phase() == 2 else 1.0
	for i in HydraEngine.HEADS:
		flash[i] = max(0.0, float(flash[i]) - dt)
		if eng.heads[i] != "up":
			atk[i] = {"state": "idle", "t": 1.0}
			continue
		atk[i]["t"] = float(atk[i]["t"]) - dt * speed
		match atk[i]["state"]:
			"idle":
				if atk[i]["t"] <= 0.0 and absf(player.position.x - head_x[i]) < 54.0:
					atk[i] = {"state": "wind", "t": 0.7}
				elif atk[i]["t"] <= 0.0:
					atk[i]["t"] = 0.6
			"wind":
				if atk[i]["t"] <= 0.0:
					atk[i] = {"state": "lunge", "t": 0.5}
			"lunge":
				if head_rect(i).intersects(player.get_rect()):
					player.hurt(2, Vector2(head_x[i], base_y))
				if atk[i]["t"] <= 0.0:
					atk[i] = {"state": "idle", "t": 1.8 + randf() * 1.5}
	# body in the water also hurts a little if you stand under the necks
	if not eng.alive():
		emit_signal("defeated")
		queue_free()
		return
	queue_redraw()

func hit_rect(r: Rect2, dir_v: Vector2i, dmg: int, src: String) -> bool:
	var any := false
	for i in HydraEngine.HEADS:
		if not r.intersects(head_rect(i)):
			continue
		if src == "fire":
			if eng.fire_hit(i):
				flash[i] = 0.3
				any = true
			elif eng.heads[i] == "up":
				# fire on a live head: scorches but does not sever
				flash[i] = 0.1
				any = true
		elif src == "sword":
			if eng.sword_hit(i):
				flash[i] = 0.2
				any = true
				WorldState.bus.emit_signal("toast", Data.tr_ui("hint_hydra"))
	return any

func _draw() -> void:
	# body / pool (art/b01.png body behind the heads if present, else a placeholder strip)
	var body := Art.tex("b01")
	if body != null:
		draw_texture(body, Vector2(float(head_x[2]) - body.get_width() * 0.5, base_y - body.get_height() + 6.0) - Vector2(0, position.y), Color(0.75, 0.8, 0.75))
	else:
		draw_rect(Rect2(Vector2(float(head_x[2]) - 60.0, base_y - 14.0) - position, Vector2(120, 22)), Color(0.15, 0.3, 0.2))
	var head_tex := Art.tex("b01_head")
	for i in HydraEngine.HEADS:
		var x: float = float(head_x[i]) - position.x
		var by := base_y - position.y
		match eng.heads[i]:
			"up":
				var col := Color(0.25, 0.65, 0.35)
				if float(flash[i]) > 0.0:
					col = Color.WHITE
				if atk[i]["state"] == "wind":
					col = Color(0.9, 0.5, 0.2)
				var hr := head_rect(i)
				draw_rect(Rect2(Vector2(x - 3, by), Vector2(6, hr.position.y - base_y + 4.0)), col.darkened(0.2))
				if head_tex != null:
					var mod := Color.WHITE if col == Color(0.25, 0.65, 0.35) else col.lightened(0.3)
					draw_texture(head_tex, hr.get_center() - position - head_tex.get_size() * 0.5, mod)
				else:
					draw_rect(Rect2(hr.position - position, hr.size), col)
			"stump":
				var pct: float = clampf(float(eng.regrow[i]) / (HydraEngine.REGROW_P2 if eng.phase() == 2 else HydraEngine.REGROW_P1), 0.0, 1.0)
				draw_rect(Rect2(Vector2(x - 4, by + 4), Vector2(8, 8)), Color(0.8, 0.25, 0.2))
				draw_rect(Rect2(Vector2(x - 4, by + 13), Vector2(8.0 * pct, 2)), Color(1, 0.85, 0.2))
			"gone":
				draw_rect(Rect2(Vector2(x - 4, by + 5), Vector2(8, 5)), Color(0.15, 0.1, 0.1))
	draw_rect(Rect2(Vector2(float(head_x[2]) - 60.0, base_y - 34.0) - position, Vector2(120.0 * float(eng.hp) / float(eng.max_hp), 3)), Color(0.9, 0.2, 0.2))
