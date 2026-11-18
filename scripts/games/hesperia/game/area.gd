extends Node2D
const Cond = preload("res://scripts/games/hesperia/core/cond.gd")
const Art = preload("res://scripts/games/hesperia/game/art.gd")
const Data = preload("res://scripts/games/hesperia/data.gd")
const WorldState = preload("res://scripts/games/hesperia/world_state.gd")
## One map (overworld area, interior or dungeon room) built from data/slice_maps.json.
## Tiles are drawn in code (placeholder art; swap in a TileSet later). Collision is a tile grid + entity rects,
## so it is cheap and deterministic. Overlay worlds (Aurea) later load res://maps/aurea/<cell> over this layout.

signal warp(map_id, tx, ty)
signal edge(dir)
signal talk(npc_id)
signal read_text(text)
signal boss_won(boss_id)

const T := 16
const ENEMY := preload("res://scripts/games/hesperia/game/enemy.gd")
const CRAB := preload("res://scripts/games/hesperia/game/boss_crab.gd")
const HYDRA := preload("res://scripts/games/hesperia/game/boss_hydra.gd")
const Fx := preload("res://scripts/games/hesperia/game/fx.gd")
const Sounds := preload("res://scripts/games/hesperia/hesperia_sounds.gd")

## Visual pass: everything that must draw above the y-sorted actors (sparks, slashes, bolts, flames, rings).
class TopLayer extends Node2D:
	var a
	func _draw() -> void:
		a.draw_top(self)

const COLORS := {
	".": Color(0.30, 0.55, 0.28), ",": Color(0.86, 0.79, 0.56), "F": Color(0.40, 0.38, 0.43), "=": Color(0.52, 0.37, 0.21),
	"#": Color(0.30, 0.28, 0.29), "T": Color(0.30, 0.55, 0.28), "H": Color(0.62, 0.44, 0.34), "~": Color(0.13, 0.28, 0.58),
	"m": Color(0.28, 0.48, 0.68), "M": Color(0.26, 0.33, 0.19), "D": Color(0.10, 0.08, 0.08),
}
const SOLID := ["#", "T", "H", "~"]

var map_id: String = ""
var def: Dictionary = {}
var w: int = 0
var h: int = 0
var rows: Array = []
var player
var blocks: Array = []        # Vector2i tile positions
var drops: Array = []
var bolts: Array = []
var fx: Array = []
var boss_node = null
var boss_def: Dictionary = {}
var portal: Dictionary = {}   # {tile:Vector2i, to, tx, ty} after a boss falls
var push_acc: float = 0.0
var push_frame: int = -10
var shake_t: float = 0.0
var fire_overlay: bool = false
var t_anim: float = 0.0
var parts: Array = []         # visual-only particles {p, v, t, m, c, g, s}
var rings: Array = []         # expanding shock rings {p, t, m, c, r}
var top: Node2D
var marsh: bool = false       # mostly marsh tiles -> ambience / grade

func setup(id: String, p) -> void:
	map_id = id
	player = p
	def = Data.maps[id]
	w = int(def["w"])
	h = int(def["h"])
	rows = def["rows"]
	var mc := 0
	for r in rows:
		mc += String(r).count("m") + String(r).count("M")
	marsh = mc > w * h / 8
	top = TopLayer.new()
	top.a = self
	top.z_index = 20
	add_child(top)
	blocks = []
	for b in def.get("blocks", []):
		blocks.append(Vector2i(int(b["x"]), int(b["y"])))
	for e in def.get("enemies", []):
		var en := Node2D.new()
		en.set_script(ENEMY)
		add_child(en)
		en.position = tile_center(Vector2i(int(e["x"]), int(e["y"])))
		en.setup(e["id"], self, p)
	if def.has("boss"):
		_spawn_boss()
	if def.has("enter"):
		WorldState.notify_event("enter:" + String(def["enter"]))

func pixel_size() -> Vector2:
	return Vector2(w * T, h * T)

func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t.x * T + T * 0.5, t.y * T + T * 0.5)

func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / T)), int(floor(p.y / T)))

func tile_at(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= w or y >= h:
		return "#"
	return rows[y][x]

## Footstep surface under a point: grass / sand / wood / stone / wet.
func ground_at(p: Vector2) -> String:
	var c := tile_at(tile_of(p).x, tile_of(p).y)
	match c:
		",":
			return "sand"
		"=":
			return "wood"
		"m", "M":
			return "wet"
		"F", "D":
			return "wood" if def.get("kind", "") == "interior" else "stone"
	return "grass"

func speed_at(p: Vector2) -> float:
	var c := tile_at(tile_of(p).x, tile_of(p).y)
	return 0.6 if (c == "m" or c == "M") else 1.0

# -- spawn bosses ---------------------------------------------------------------------------------
func _spawn_boss() -> void:
	boss_def = def["boss"]
	var bid: String = boss_def["id"]
	if WorldState.has_flag("boss_" + bid):
		_open_portal()
		return
	var pos := tile_center(Vector2i(int(boss_def["x"]), int(boss_def["y"])))
	if bid == "b00":
		boss_node = Node2D.new()
		boss_node.set_script(CRAB)
		add_child(boss_node)
		boss_node.position = pos
		boss_node.setup(self, player)
	elif bid == "b01":
		boss_node = Node2D.new()
		boss_node.set_script(HYDRA)
		add_child(boss_node)
		boss_node.setup(self, player, pos)
	boss_node.defeated.connect(_on_boss_defeated)

func boss_alive() -> bool:
	return boss_node != null and is_instance_valid(boss_node)

func _on_boss_defeated() -> void:
	var bid: String = boss_def["id"]
	WorldState.set_flag("boss_" + bid)
	WorldState.notify_event("kill:" + bid)
	var after: Dictionary = boss_def.get("after", {})
	if after.get("item", "") != "":
		WorldState.add_item(after["item"])
		WorldState.bus.emit_signal("toast", "%s %s" % [Data.tr_ui("got_item"), Data.name_of(after["item"])])
	if after.get("heart", false):
		WorldState.max_half_hearts += 2
		WorldState.half_hearts = WorldState.max_half_hearts
		WorldState.bus.emit_signal("toast", Data.tr_ui("level_up"))
	if boss_node != null and is_instance_valid(boss_node):
		var bp: Vector2 = boss_node.position if bid != "b01" else tile_center(Vector2i(int(boss_def["x"]), int(boss_def["y"])))
		for k in 3:
			burst(bp + Vector2(randf_range(-10, 10), randf_range(-8, 8)), Color(1.0, 0.85, 0.5), 16, 90.0, 0.8, 0.0, 2.0)
		ring(bp, Color(1, 0.9, 0.6), 40.0, 0.6)
		shake_t = 0.5
		Sounds.boss_down(self)
	boss_node = null
	_open_portal()
	emit_signal("boss_won", bid)

func _open_portal() -> void:
	var after: Dictionary = boss_def.get("after", {})
	if after.has("exit"):
		portal = {"tile": Vector2i(12, 6), "to": after["exit"]["to"], "tx": int(after["exit"]["tx"]), "ty": int(after["exit"]["ty"])}

# -- collision ------------------------------------------------------------------------------------
func _npc_visible(n: Dictionary) -> bool:
	return Cond.eval(n.get("show_if", ""), WorldState) and not (n.has("hide_if") and Cond.eval(n["hide_if"], WorldState))

func _chest_visible(c: Dictionary) -> bool:
	return _npc_visible(c)

func blocked(r: Rect2, who, push_dir: Vector2i = Vector2i.ZERO, is_enemy: bool = false) -> bool:
	if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > w * T or r.end.y > h * T:
		return true
	var x0 := int(floor(r.position.x / T))
	var x1 := int(floor((r.end.x - 0.01) / T))
	var y0 := int(floor(r.position.y / T))
	var y1 := int(floor((r.end.y - 0.01) / T))
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if SOLID.has(tile_at(tx, ty)):
				return true
	for g in def.get("gates", []):
		if not WorldState.has_flag(g["flag"]):
			if r.intersects(Rect2(Vector2(g["x"], g["y"]) * T, Vector2(T, T))):
				return true
	for n in def.get("npcs", []):
		if _npc_visible(n) and r.intersects(Rect2(Vector2(n["x"], n["y"]) * T + Vector2(2, 2), Vector2(T - 4, T - 4))):
			return true
	for c in def.get("chests", []):
		if _chest_visible(c) and r.intersects(Rect2(Vector2(c["x"], c["y"]) * T + Vector2(1, 3), Vector2(T - 2, T - 5))):
			return true
	for s in def.get("signs", []):
		if r.intersects(Rect2(Vector2(s["x"], s["y"]) * T + Vector2(3, 3), Vector2(T - 6, T - 6))):
			return true
	for i in blocks.size():
		var br := Rect2(Vector2(blocks[i]) * T, Vector2(T, T))
		if r.intersects(br):
			if who == player and push_dir != Vector2i.ZERO:
				_try_push(i, push_dir)
			return true
	return false

func _try_push(i: int, dir_v: Vector2i) -> void:
	var frame := Engine.get_process_frames()
	if frame - push_frame > 3:
		push_acc = 0.0
	push_frame = frame
	push_acc += get_process_delta_time()
	if push_acc < 0.35:
		return
	push_acc = 0.0
	var to: Vector2i = blocks[i] + dir_v
	if SOLID.has(tile_at(to.x, to.y)) or to in blocks:
		return
	for g in def.get("gates", []):
		if not WorldState.has_flag(g["flag"]) and Vector2i(int(g["x"]), int(g["y"])) == to:
			return
	for c in def.get("chests", []):
		if Vector2i(int(c["x"]), int(c["y"])) == to:
			return
	blocks[i] = to
	Sounds.push(self)

# -- per-frame ------------------------------------------------------------------------------------
func _process(dt: float) -> void:
	t_anim += dt
	if shake_t > 0.0:
		shake_t -= dt
	# plates
	for pl in def.get("plates", []):
		var tl := Vector2i(int(pl["x"]), int(pl["y"]))
		var pressed: bool = (tl in blocks) or tile_of(player.position) == tl
		if pressed and not WorldState.has_flag(pl["flag"]):
			WorldState.set_flag(pl["flag"])
			WorldState.bus.emit_signal("toast", Data.tr_ui("opened_gate"))
			shake_t = 0.3
			Sounds.gate(self)
			burst(tile_center(tl), Color(0.85, 0.75, 0.5), 10, 45.0, 0.5, 0.0, 1.5)
			ring(tile_center(tl), Color(1, 0.9, 0.5), 14.0, 0.4)
	# bolts
	var keep: Array = []
	for b in bolts:
		b["pos"] += b["vel"] * dt
		b["ttl"] -= dt
		var tl := tile_of(b["pos"])
		var dir_v := Vector2i(int(signf(b["vel"].x)), int(signf(b["vel"].y)))
		if b["ttl"] <= 0.0 or SOLID.has(tile_at(tl.x, tl.y)) and tile_at(tl.x, tl.y) != "~":
			burst(b["pos"], Color(1.0, 0.6, 0.2), 8, 50.0, 0.35)
			continue
		if attack(Rect2(b["pos"] - Vector2(4, 4), Vector2(8, 8)), dir_v, 2, b["src"]):
			burst(b["pos"], Color(1.0, 0.7, 0.25), 12, 70.0, 0.4)
			ring(b["pos"], Color(1.0, 0.6, 0.2), 12.0, 0.25)
			continue
		if randf() < 0.7:
			parts.append({"p": b["pos"] + Vector2(randf_range(-2, 2), randf_range(-2, 2)), "v": -b["vel"] * 0.08, "t": 0.3, "m": 0.3, "c": Color(1.0, 0.55, 0.15), "g": -20.0, "s": 2.0})
		keep.append(b)
	bolts = keep
	# fx
	var fk: Array = []
	for f in fx:
		f["ttl"] -= dt
		if f["ttl"] > 0.0:
			fk.append(f)
	fx = fk
	# visual particles / rings
	var damp := pow(0.04, dt)
	var pk: Array = []
	for q in parts:
		q["t"] -= dt
		if q["t"] <= 0.0:
			continue
		q["v"] = q["v"] * damp + Vector2(0, float(q["g"]) * dt)
		q["p"] += q["v"] * dt
		pk.append(q)
	parts = pk
	var rk: Array = []
	for q in rings:
		q["t"] -= dt
		if q["t"] > 0.0:
			rk.append(q)
	rings = rk
	if fire_overlay and randf() < 0.5:
		var fp := Vector2(randf() * w * T, randf() * h * T)
		parts.append({"p": fp, "v": Vector2(randf_range(-6, 6), -randf_range(15, 30)), "t": 0.9, "m": 0.9, "c": Color(1.0, 0.5, 0.12), "g": -10.0, "s": 2.0})
	if top != null:
		top.queue_redraw()
	# drops
	var dk: Array = []
	for d in drops:
		d["ttl"] -= dt
		if d["ttl"] <= 0.0:
			continue
		if d["pos"].distance_to(player.position) < 10.0:
			_collect(d["kind"])
			if d["kind"] == "obol":
				Sounds.coin(self)
			else:
				Sounds.heart(self)
			var cc := Color(1.0, 0.4, 0.5) if d["kind"] == "heart" else (Color(1.0, 0.88, 0.4) if d["kind"] == "obol" else Color(0.45, 0.85, 1.0))
			burst(d["pos"], cc, 9, 40.0, 0.45, -30.0, 1.0)
			ring(d["pos"], cc, 9.0, 0.3)
			continue
		dk.append(d)
	drops = dk
	queue_redraw()

func _collect(kind: String) -> void:
	match kind:
		"heart":
			WorldState.heal(2)
		"obol":
			WorldState.add_item("obol", 1 + randi() % 3)
		"magic":
			WorldState.magic = min(WorldState.max_magic, WorldState.magic + 4)
			WorldState.bus.emit_signal("changed")

func spawn_bolt(p: Vector2, v: Vector2, src: String) -> void:
	bolts.append({"pos": p, "vel": v, "ttl": 0.9, "src": src})

func flame_fx(p: Vector2) -> void:
	fx.append({"pos": p, "ttl": 0.25})
	Sounds.fire(self)
	burst(p, Color(1.0, 0.55, 0.15), 14, 55.0, 0.45, -60.0, 2.0)
	burst(p, Color(1.0, 0.9, 0.5), 5, 30.0, 0.3, -40.0, 1.0)

## Visual-only particle burst (sparks, dust, puffs). Capped so a busy fight stays cheap on mid-range phones.
func burst(p: Vector2, col: Color, n: int, spd: float = 40.0, life: float = 0.45, grav: float = 0.0, sz: float = 1.5) -> void:
	for i in n:
		if parts.size() > 240:
			return
		var v := Vector2.from_angle(randf() * TAU) * spd * randf_range(0.35, 1.0)
		var l := life * randf_range(0.6, 1.0)
		parts.append({"p": p, "v": v, "t": l, "m": l, "c": col, "g": grav, "s": sz})

func ring(p: Vector2, col: Color, r: float, life: float = 0.3) -> void:
	rings.append({"p": p, "t": life, "m": life, "c": col, "r": r})

## Weapon contact: white-hot sparks + a small ring. Called by enemies/bosses when a hit lands.
func hit_spark(p: Vector2, blocked_hit: bool = false) -> void:
	if blocked_hit:
		burst(p, Color(0.85, 0.85, 0.95), 6, 60.0, 0.25, 0.0, 1.0)
		Sounds.block(self)
		return
	if boss_alive():
		Sounds.boss_hit(self)
	else:
		Sounds.hit(self)
	burst(p, Color(1.0, 0.95, 0.7), 8, 85.0, 0.28, 0.0, 1.0)
	burst(p, Color(1.0, 0.55, 0.3), 4, 40.0, 0.35, 0.0, 2.0)
	ring(p, Color(1, 1, 1), 10.0, 0.18)

func shake(sec: float) -> void:
	shake_t = sec

## Run a hit rect against everything hittable. Returns true if anything was hit.
func attack(r: Rect2, dir_v: Vector2i, dmg: int, src: String) -> bool:
	var hit := false
	for n in get_children():
		if n.is_in_group("hittable") and is_instance_valid(n) and not n.is_queued_for_deletion():
			if n.hit_rect(r, dir_v, dmg, src):
				hit = true
	return hit

func enemy_died(e) -> void:
	var roll := randf()
	var kind := ""
	if roll < 0.25:
		kind = "heart"
	elif roll < 0.55:
		kind = "obol"
	elif roll < 0.65:
		kind = "magic"
	if kind != "":
		drops.append({"pos": e.position, "kind": kind, "ttl": 12.0})
	WorldState.notify_event("kill:" + e.id)
	burst(e.position, Color(0.92, 0.9, 0.85), 12, 45.0, 0.55, -15.0, 2.0)   # death puff
	Sounds.enemy_die(self)
	burst(e.position, Color(1.0, 0.85, 0.45), 6, 70.0, 0.35, 0.0, 1.0)
	ring(e.position, Color(1, 1, 1), 12.0, 0.25)
	e.queue_free()

# -- interaction ----------------------------------------------------------------------------------
func interact(p) -> bool:
	var probe: Vector2 = p.position + Vector2(p.facing) * 11.0
	var best = null
	var bestd := 9999.0
	for n in def.get("npcs", []):
		if _npc_visible(n):
			var c := tile_center(Vector2i(int(n["x"]), int(n["y"])))
			var d := c.distance_to(probe)
			if d < 12.0 and d < bestd:
				best = {"k": "npc", "d": n}
				bestd = d
	for c in def.get("chests", []):
		if _chest_visible(c) and not WorldState.has_flag(c.get("flag", "")):
			var cc := tile_center(Vector2i(int(c["x"]), int(c["y"])))
			var d := cc.distance_to(probe)
			if d < 12.0 and d < bestd:
				best = {"k": "chest", "d": c}
				bestd = d
	for s in def.get("signs", []):
		var sc := tile_center(Vector2i(int(s["x"]), int(s["y"])))
		var d := sc.distance_to(probe)
		if d < 12.0 and d < bestd:
			best = {"k": "sign", "d": s}
			bestd = d
	if best == null:
		return false
	match best["k"]:
		"npc":
			emit_signal("talk", best["d"]["id"])
		"sign":
			emit_signal("read_text", best["d"]["text"])
		"chest":
			_open_chest(best["d"])
	return true

func _open_chest(c: Dictionary) -> void:
	WorldState.set_flag(c.get("flag", "chest_" + str(c["x"]) + "_" + str(c["y"])))
	if c.has("item"):
		WorldState.add_item(c["item"], int(c.get("n", 1)))
		var nm := Data.name_of(c["item"])
		var n := int(c.get("n", 1))
		WorldState.bus.emit_signal("toast", "%s %s%s" % [Data.tr_ui("got_item"), nm, (" x" + str(n)) if n > 1 else ""])
	var chp := tile_center(Vector2i(int(c["x"]), int(c["y"])))
	Sounds.chest(self)
	burst(chp, Color(1.0, 0.9, 0.45), 16, 50.0, 0.7, -40.0, 1.0)
	ring(chp, Color(1.0, 0.9, 0.5), 14.0, 0.4)
	if c.has("msg"):
		emit_signal("read_text", c["msg"])

## Called every frame by the player: doors, portals, edges.
func check_player_tile(p) -> void:
	var tl := tile_of(p.position)
	for d in def.get("doors", []):
		if Vector2i(int(d["x"]), int(d["y"])) != tl:
			continue
		if d.has("show_if") and not Cond.eval(d["show_if"], WorldState):
			continue
		if d.get("lock_in_boss", false) and boss_alive():
			continue
		if d.has("req") and not Cond.eval(d["req"], WorldState):
			_door_msg(d)
			p.position += Vector2(0, 14) if tl.y == 4 or tl.y == 0 else Vector2(0, -14)
			return
		if d.has("locked"):
			var fl := "door_%s_%d_%d" % [map_id, int(d["x"]), int(d["y"])]
			if not WorldState.has_flag(fl):
				if WorldState.item_count(d["locked"]) > 0:
					WorldState.remove_item(d["locked"])
					WorldState.set_flag(fl)
					WorldState.bus.emit_signal("toast", Data.tr_ui("used_key"))
				else:
					_door_msg(d)
					p.position += Vector2(0, 14)
					return
		emit_signal("warp", d["to"], int(d["tx"]), int(d["ty"]))
		return
	if not portal.is_empty() and tl == portal["tile"]:
		emit_signal("warp", portal["to"], portal["tx"], portal["ty"])
		return
	# edges (overworld): leaving the map on a side that has a neighbour
	var edges: Dictionary = def.get("edges", {})
	if p.position.y < 6.5 and edges.has("n"):
		emit_signal("edge", "n")
	elif p.position.y > h * T - 6.5 and edges.has("s"):
		emit_signal("edge", "s")
	elif p.position.x < 6.5 and edges.has("w"):
		emit_signal("edge", "w")
	elif p.position.x > w * T - 6.5 and edges.has("e"):
		emit_signal("edge", "e")

func _door_msg(d: Dictionary) -> void:
	if d.has("msg"):
		emit_signal("read_text", d["msg"])

# -- drawing --------------------------------------------------------------------------------------
## Autotile: edge art (art/e_|c_|d_<what>_<dir>.png, tools/slice_art.py) when a neighbour is one of `other`.
## e_ = one side, c_ = two sides (corner), d_ = diagonal only. null = no edge (or no art for this case).
func _edge_tex(x: int, y: int, other: String, what: String) -> Texture2D:
	var hit := func(dx: int, dy: int) -> bool:
		var nx := x + dx
		var ny := y + dy
		return nx >= 0 and ny >= 0 and nx < w and ny < h and other.contains(rows[ny][nx])
	var n: bool = hit.call(0, -1)
	var s: bool = hit.call(0, 1)
	var e: bool = hit.call(1, 0)
	var wv: bool = hit.call(-1, 0)
	var ids: Array[String] = []
	if (n or s) and (e or wv):
		ids.append("c_%s_%s%s" % [what, "n" if n else "s", "e" if e else "w"])
	for d in [[n, "n"], [s, "s"], [e, "e"], [wv, "w"]]:
		if d[0]:
			ids.append("e_%s_%s" % [what, d[1]])
	if ids.is_empty():
		for d in [[-1, -1, "nw"], [1, -1, "ne"], [-1, 1, "sw"], [1, 1, "se"]]:
			if hit.call(d[0], d[1]):
				ids.append("d_%s_%s" % [what, d[2]])
	for id in ids:
		var t := Art.tex(id)
		if t != null:
			return t
	return null

func _draw() -> void:
	for y in h:
		for x in w:
			var c: String = rows[y][x]
			var col: Color = COLORS.get(c, Color.MAGENTA)
			var j := float((x * 7 + y * 13) % 3) * 0.015
			col = Color(col.r + j, col.g + j, col.b + j)
			# ground tile art (art/tile_*.png, see tools/slice_art.py); falls back to the flat colours below
			var outdoor: bool = def.get("kind", "") == "outdoor"
			var tt: Texture2D = null
			var over: Texture2D = null
			var v := (x * 7 + y * 13) % 11
			var grass_id := "tile_flowers" if v == 0 else ("tile_grass2" if v < 4 else "tile_grass")
			match c:
				".": tt = _edge_tex(x, y, "~,", "sand"); tt = tt if tt != null else Art.tex(grass_id)
				"T": tt = Art.tex(grass_id); over = Art.tex("tile_tree")
				",": tt = _edge_tex(x, y, "~", "sea"); tt = tt if tt != null else Art.tex("tile_sand")
				"~": tt = Art.tex("tile_sea")
				"m": tt = Art.tex("tile_marsh_water")
				"M": tt = Art.tex("tile_mud")
				"=": tt = Art.tex("tile_boardwalk")
				"F": tt = Art.tex("tile_floor")
				"H": tt = Art.tex("tile_roof") if outdoor else Art.tex("tile_dwall")
				"#":
					if outdoor:
						tt = Art.tex(grass_id); over = Art.tex("tile_cliff")
					else:
						tt = Art.tex("tile_dwall")
				"D": tt = Art.tex("tile_floor") if not outdoor else Art.tex("tile_roof"); over = Art.tex("tile_door")
			if tt != null:
				draw_texture(tt, Vector2(x * T, y * T))
			else:
				draw_rect(Rect2(x * T, y * T, T, T), col)
			if outdoor and (c == "H" or c == "D"):
				_draw_building(x, y, c)
			if over != null:
				if c == "T":
					Fx.shadow(self, Vector2(x * T + 9, y * T + T - 1), 7.0, 0.28)
				draw_texture(over, Vector2(x * T + (T - over.get_width()) * 0.5, y * T + T - over.get_height()))
				if c == "T" or c == "#" or c == "D":
					continue
			if c == "T":
				draw_circle(Vector2(x * T + 8, y * T + 7), 7.0, Color(0.12, 0.35, 0.16))
				draw_rect(Rect2(x * T + 7, y * T + 11, 2, 5), Color(0.35, 0.22, 0.12))
			elif c == "~" or c == "m":
				var o := sin(t_anim * 2.0 + x + y) * 0.04
				draw_rect(Rect2(x * T, y * T + 6, T, 1), Color(0.5, 0.7, 1.0, 0.25 + o))
				# visual pass: sun glints on the sea, slow ripples on marsh water
				var hsh := (x * 31 + y * 17) % 9
				if c == "~":
					var g := sin(t_anim * 1.6 + float(hsh) * 1.9)
					if g > 0.82:
						var gp := Vector2(x * T + 2 + (hsh * 5) % 11, y * T + 3 + (hsh * 3) % 10)
						draw_rect(Rect2(gp, Vector2(2 if g > 0.93 else 1, 1)), Color(1, 1, 0.92, (g - 0.82) * 6.0))
					var ws := fposmod(t_anim * 6.0 + float(hsh) * 4.0, 20.0) - 4.0
					draw_rect(Rect2(x * T + ws, y * T + 11 + hsh % 3, 3, 1), Color(0.75, 0.9, 1.0, 0.18))
				elif hsh == 0 or hsh == 5:
					var ph := fposmod(t_anim * 0.45 + float(x + y) * 0.13, 1.0)
					draw_arc(Vector2(x * T + 8, y * T + 9), 1.0 + ph * 6.0, 0.0, TAU, 12, Color(0.8, 1.0, 0.9, 0.35 * (1.0 - ph)), 1.0)
			elif c == "H":
				draw_rect(Rect2(x * T, y * T, T, 1), Color(0.4, 0.28, 0.2))
	for g in def.get("gates", []):
		var open: bool = WorldState.has_flag(g["flag"])
		if not open:
			# bronze portcullis: shaded bars, cross-bar, spiked tips (was 4 flat grey bars)
			var gx: float = float(g["x"]) * T
			var gy: float = float(g["y"]) * T
			draw_rect(Rect2(gx, gy + T - 2, T, 2), Color(0, 0, 0, 0.3))
			for k in 4:
				var bx := gx + 2 + k * 4
				draw_rect(Rect2(bx, gy + 1, 2, T - 1), Color(0.62, 0.5, 0.32))
				draw_rect(Rect2(bx, gy + 1, 1, T - 1), Color(0.9, 0.78, 0.5))
				draw_rect(Rect2(bx, gy, 2, 1), Color(1, 0.9, 0.6))
			draw_rect(Rect2(gx + 1, gy + 6, T - 2, 2), Color(0.45, 0.35, 0.22))
			draw_rect(Rect2(gx + 1, gy + 6, T - 2, 1), Color(0.75, 0.62, 0.4))
	for pl in def.get("plates", []):
		var on: bool = WorldState.has_flag(pl["flag"])
		var pr := Rect2(pl["x"] * T + 2, pl["y"] * T + 2, T - 4, T - 4)
		draw_rect(pr.grow(1), Color(0, 0, 0, 0.35))
		Fx.bevel(self, pr if not on else pr.grow(-1), Color(0.8, 0.68, 0.3) if on else Color(0.55, 0.5, 0.28), 0.3 if not on else 0.1, 0.4)
		if on:
			draw_rect(Rect2(pr.get_center() - Vector2(1, 1), Vector2(2, 2)), Color(1, 0.95, 0.6, 0.6 + 0.4 * sin(t_anim * 4.0)))
	for s in def.get("signs", []):
		var sp := Vector2(s["x"] * T, s["y"] * T)
		Fx.shadow(self, sp + Vector2(8, 15), 4.0, 0.25)
		draw_rect(Rect2(sp + Vector2(7, 9), Vector2(2, 6)), Color(0.4, 0.28, 0.16))
		Fx.bevel(self, Rect2(sp + Vector2(3, 2), Vector2(10, 8)), Color(0.72, 0.55, 0.32), 0.3, 0.45)
		draw_rect(Rect2(sp + Vector2(5, 4), Vector2(6, 1)), Color(0.4, 0.28, 0.16, 0.7))
		draw_rect(Rect2(sp + Vector2(5, 6), Vector2(4, 1)), Color(0.4, 0.28, 0.16, 0.7))
	for c in def.get("chests", []):
		if not _chest_visible(c):
			continue
		var opened: bool = WorldState.has_flag(c.get("flag", ""))
		var cp := Vector2(c["x"] * T, c["y"] * T)
		Fx.shadow(self, cp + Vector2(8, 14), 7.0, 0.3)
		if not opened:
			Fx.bevel(self, Rect2(cp + Vector2(1, 6), Vector2(T - 2, T - 8)), Color(0.5, 0.32, 0.16), 0.2, 0.4)
			Fx.bevel(self, Rect2(cp + Vector2(1, 3), Vector2(T - 2, 4)), Color(0.62, 0.4, 0.2), 0.3, 0.3)
			draw_rect(Rect2(cp + Vector2(3, 3), Vector2(2, 11)), Color(0.85, 0.7, 0.3))
			draw_rect(Rect2(cp + Vector2(11, 3), Vector2(2, 11)), Color(0.85, 0.7, 0.3))
			Fx.bevel(self, Rect2(cp + Vector2(6, 6), Vector2(4, 4)), Color(0.95, 0.8, 0.35), 0.3, 0.4)
			var tw := fposmod(t_anim * 0.7 + float(c["x"]) * 0.3, 1.0)       # occasional glint
			if tw < 0.12:
				var gp := cp + Vector2(4 + tw * 60.0, 4)
				draw_rect(Rect2(gp, Vector2(1, 1)), Color(1, 1, 0.9))
		else:
			Fx.bevel(self, Rect2(cp + Vector2(1, 6), Vector2(T - 2, T - 8)), Color(0.32, 0.22, 0.13), 0.1, 0.3)
			draw_rect(Rect2(cp + Vector2(2, 6), Vector2(T - 4, 2)), Color(0.08, 0.05, 0.04))
			draw_rect(Rect2(cp + Vector2(1, 1), Vector2(T - 2, 4)), Color(0.4, 0.27, 0.15))
	for d in def.get("doors", []):
		if d.has("show_if") and not Cond.eval(d["show_if"], WorldState):
			continue
		if d.get("lock_in_boss", false) and boss_alive():
			draw_rect(Rect2(d["x"] * T, d["y"] * T, T, T), Color(0.6, 0.6, 0.65))
	for b in blocks:
		# carved stone block: drop shadow, bevel, crack line (was flat grey square)
		var br := Rect2(b.x * T + 1, b.y * T + 1, T - 2, T - 2)
		draw_rect(Rect2(br.position + Vector2(1, 2), br.size), Color(0, 0, 0, 0.35))
		Fx.bevel(self, br, Color(0.58, 0.57, 0.6), 0.3, 0.45)
		draw_rect(br, Color(0.22, 0.21, 0.24), false, 1.0)
		draw_rect(Rect2(br.position + Vector2(3, 6), Vector2(5, 1)), Color(0.4, 0.4, 0.43))
		draw_rect(Rect2(br.position + Vector2(8, 7), Vector2(1, 3)), Color(0.4, 0.4, 0.43))
	if not portal.is_empty():
		# swirling blue gate: glow, two counter-rotating arcs, rising motes
		var pc := tile_center(portal["tile"])
		Fx.glow(self, pc, 14.0 + sin(t_anim * 4.0) * 1.5, Color(0.4, 0.8, 1.0, 0.45), 5)
		draw_arc(pc, 7.0, t_anim * 3.0, t_anim * 3.0 + PI * 1.3, 16, Color(0.8, 0.95, 1.0, 0.9), 1.0)
		draw_arc(pc, 4.5, -t_anim * 4.0, -t_anim * 4.0 + PI * 1.1, 12, Color(0.6, 0.9, 1.0, 0.9), 1.0)
		for k in 4:
			var ph := fposmod(t_anim * 0.8 + float(k) * 0.25, 1.0)
			draw_rect(Rect2(pc + Vector2(sin(float(k) * 2.3) * 6.0, 6.0 - ph * 18.0), Vector2.ONE), Color(0.85, 1.0, 1.0, 1.0 - ph))
	for n in def.get("npcs", []):
		if not _npc_visible(n):
			continue
		var c := tile_center(Vector2i(int(n["x"]), int(n["y"])))
		var ntex := Art.tex(n["id"])
		var feet := (ntex.get_height() * 0.5 - 1.0) if ntex != null else 6.0
		Fx.shadow(self, c + Vector2(0, feet), 5.0, 0.3)
		# idle: 1px breathing bob, desynced per NPC (visual only; collision uses the tile)
		var bob := -1.0 if fposmod(t_anim * 0.9 + float(int(n["x"]) * 3 + int(n["y"])) * 0.37, 1.0) < 0.5 else 0.0
		Art.actor(self, n["id"], c + Vector2(0, bob), 12.0, Art.color_for(n["id"]))
		if c.distance_to(player.position) < 26.0:
			# talk prompt: little speech bubble bobbing above the head
			var top_y := (ntex.get_height() * 0.5) if ntex != null else 8.0
			var bp := (c + Vector2(0, -top_y - 7.0 + sin(t_anim * 5.0) * 1.0)).round()
			draw_rect(Rect2(bp + Vector2(-4, -5), Vector2(9, 8)), Color(0.08, 0.06, 0.08))
			draw_rect(Rect2(bp + Vector2(-3, -4), Vector2(7, 6)), Color(1, 0.96, 0.85))
			draw_colored_polygon(PackedVector2Array([bp + Vector2(-1, 2), bp + Vector2(2, 2), bp + Vector2(0, 4)]), Color(1, 0.96, 0.85))
			draw_rect(Rect2(bp + Vector2(0, -3), Vector2(1, 3)), Color(0.75, 0.4, 0.1))
			draw_rect(Rect2(bp + Vector2(0, 1), Vector2(1, 1)), Color(0.75, 0.4, 0.1))
	for d in drops:
		var col2 := Color(0.9, 0.2, 0.3) if d["kind"] == "heart" else (Color(0.9, 0.8, 0.3) if d["kind"] == "obol" else Color(0.3, 0.7, 0.9))
		# bobbing pickup with shadow, highlight and a blink when about to expire
		var dp: Vector2 = d["pos"]
		var hover := roundf(sin(t_anim * 4.0 + dp.x) * 1.5) - 2.0
		if d["ttl"] < 3.0 and int(d["ttl"] * 8.0) % 2 == 0:
			continue
		Fx.shadow(self, dp + Vector2(0, 3), 3.0, 0.3)
		var dc := dp + Vector2(0, hover)
		match d["kind"]:
			"heart":
				Fx.heart(self, dc + Vector2(0, -1), 3.4, col2.darkened(0.5))
				Fx.heart(self, dc + Vector2(0, -1), 2.8, col2)
				draw_rect(Rect2(dc + Vector2(-2, -2), Vector2(1, 1)), Color(1, 0.8, 0.8))
			"obol":
				var sq := absf(sin(t_anim * 3.0 + dp.y))          # spinning coin
				Fx.ellipse(self, dc, 3.0 * sq + 0.6, 3.0, Color(0.55, 0.38, 0.1))
				Fx.ellipse(self, dc, 2.3 * sq + 0.4, 2.3, col2)
			_:
				draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -4), dc + Vector2(3, 0), dc + Vector2(0, 4), dc + Vector2(-3, 0)]), col2)
				draw_rect(Rect2(dc + Vector2(-1, -2), Vector2(1, 2)), Color(0.85, 1, 1))
	# bolts and flame fx are drawn in draw_top() so they sit above actors
	if fire_overlay:
		for i in 14:
			var hx := float((i * 53) % (w * T))
			var hy := float((i * 97) % (h * T))
			draw_circle(Vector2(hx, hy), 3.0 + sin(t_anim * 9.0 + i) * 1.5, Color(1.0, 0.45, 0.1, 0.55))
			Fx.glow(self, Vector2(hx, hy), 9.0 + sin(t_anim * 7.0 + i) * 2.0, Color(1.0, 0.5, 0.15, 0.3), 3)

## Outdoor buildings: roof edges outlined + ridge highlight; the lowest row becomes the front wall
## (whitewashed plaster, timber sill, shuttered windows), so huts read as houses, not flat roofs.
func _draw_building(x: int, y: int, c: String) -> void:
	var o := Vector2(x * T, y * T)
	var wall := not "HD".contains(tile_at(x, y + 1))
	var hl := "HD".contains(tile_at(x - 1, y))
	var hr := "HD".contains(tile_at(x + 1, y))
	if not wall:
		if not "HD".contains(tile_at(x, y - 1)):
			draw_rect(Rect2(o, Vector2(T, 1)), Color(1, 0.85, 0.65, 0.45))      # ridge catches the light
		if not hl:
			draw_rect(Rect2(o, Vector2(1, T)), Color(0.25, 0.12, 0.08, 0.7))
		if not hr:
			draw_rect(Rect2(o + Vector2(T - 1, 0), Vector2(1, T)), Color(0.25, 0.12, 0.08, 0.7))
		return
	draw_rect(Rect2(o, Vector2(T, T)), Color(0.86, 0.8, 0.67))                 # plaster
	draw_rect(Rect2(o, Vector2(T, 3)), Color(0.42, 0.24, 0.15))                # eave overhang
	draw_rect(Rect2(o + Vector2(0, 3), Vector2(T, 2)), Color(0.2, 0.12, 0.08, 0.45))   # eave shadow
	draw_rect(Rect2(o + Vector2(0, T - 3), Vector2(T, 3)), Color(0.5, 0.36, 0.22))     # timber sill
	draw_rect(Rect2(o + Vector2(0, T - 3), Vector2(T, 1)), Color(0.65, 0.5, 0.32))
	for k in 3:                                                                  # plaster texture
		var hh := (x * 13 + y * 7 + k * 5) % 11
		draw_rect(Rect2(o + Vector2(2 + hh, 6 + (hh * 3) % 6), Vector2(2, 1)), Color(0.74, 0.68, 0.56))
	if c == "H" and (x + y) % 3 == 1:                                           # shuttered window, warm light inside
		var wpos := o + Vector2(5, 6)
		draw_rect(Rect2(wpos - Vector2(1, 1), Vector2(8, 7)), Color(0.36, 0.24, 0.14))
		draw_rect(Rect2(wpos, Vector2(6, 5)), Color(0.95, 0.72, 0.35, 0.85 + 0.1 * sin(t_anim * 2.0 + x)))
		draw_rect(Rect2(wpos + Vector2(2, 0), Vector2(1, 5)), Color(0.36, 0.24, 0.14))
		draw_rect(Rect2(wpos + Vector2(-3, -1), Vector2(2, 7)), Color(0.3, 0.45, 0.6))   # blue shutters
		draw_rect(Rect2(wpos + Vector2(7, -1), Vector2(2, 7)), Color(0.3, 0.45, 0.6))
	if not hl:
		draw_rect(Rect2(o, Vector2(2, T)), Color(0.5, 0.36, 0.22))                 # corner posts
	if not hr:
		draw_rect(Rect2(o + Vector2(T - 2, 0), Vector2(2, T)), Color(0.5, 0.36, 0.22))
	Fx.shadow(self, o + Vector2(8, T + 1), 9.0, 0.18)

## Above-actor effects (TopLayer, z 20): particles, shock rings, glowing bolts, layered torch flames.
func draw_top(ci: CanvasItem) -> void:
	for f in fx:
		var k: float = f["ttl"] / 0.25
		Fx.glow(ci, f["pos"], 10.0 * k + 3.0, Color(1.0, 0.55, 0.15, 0.55), 4)
		ci.draw_circle(f["pos"], 3.0 * k + 1.0, Color(1.0, 0.95, 0.7, 0.9))
	for b in bolts:
		Fx.glow(ci, b["pos"], 8.0 + sin(t_anim * 30.0) * 1.0, Color(1.0, 0.5, 0.15, 0.6), 4)
		ci.draw_circle(b["pos"], 2.5, Color(1.0, 0.95, 0.7))
	for q in rings:
		var k2: float = 1.0 - float(q["t"]) / float(q["m"])
		var c: Color = q["c"]
		ci.draw_arc(q["p"], 2.0 + float(q["r"]) * k2, 0.0, TAU, 20, Color(c.r, c.g, c.b, (1.0 - k2) * 0.8), 1.0)
	for q in parts:
		var k3: float = float(q["t"]) / float(q["m"])
		var c2: Color = q["c"]
		var sz: float = maxf(1.0, roundf(float(q["s"]) * (0.5 + 0.5 * k3)))
		ci.draw_rect(Rect2((q["p"] as Vector2).round() - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(c2.r, c2.g, c2.b, minf(1.0, k3 * 1.6)))
