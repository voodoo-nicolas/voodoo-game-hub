extends Control

## The real-time battle screen (design doc v2 §1.3): the encounter's picture as the backdrop, your
## ship and the enemy wing drawn from their parts, laser shots, hull / shield bars. Steer with the
## Pad's stick (or drag a finger on the field, or WASD); tap an enemy to target it; guns fire by
## themselves in range. Buttons: Shields, Evade, Flee, plus Hack / Board / the once-per-run calls
## when you have them. The rules run in the_runner_battle.gd; when it ends, `finished` carries the
## outcome and the sim's result info (the game hands both to engine.end_battle()).

signal finished(outcome: String, info: Dictionary)

const UI = preload("res://scripts/games/the_runner/the_runner_ui.gd")
const S = preload("res://scripts/games/the_runner/the_runner_spiral.gd")
const D = preload("res://scripts/games/the_runner/the_runner_data.gd")
const Battle = preload("res://scripts/games/the_runner/the_runner_battle.gd")
const ShipArt = preload("res://scripts/games/the_runner/the_runner_ship_art.gd")
const SoundLib = preload("res://scripts/games/the_runner/sound_lib.gd")

var game: Control
var engine: RefCounted
var pad: Control = null
var art_id := "sky_dragon"
var sim = null
var _field: Control
var _buttons: VBoxContainer
var _top: VBoxContainer
var _drag_from := Vector2.ZERO
var _drag := Vector2.ZERO
var _dragging := false
var _clock := 0.0
var _ended := false
var _player_spec := {}
var _enemy_specs := []
var _shots_seen := 0
var _btn_state := ""

func start() -> void:
	sim = Battle.new()
	sim.setup(engine.battle_player(), engine.battle_enemies())
	_player_spec = ShipArt.spec_of(engine)
	for f in sim.foes:
		_enemy_specs.append(ShipArt.spec_enemy(f))
	_build()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UI.backdrop(art_id))
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_field = Control.new()
	_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.draw.connect(_draw_field)
	add_child(_field)
	# top: names and bars
	var tp := UI.panel(0.8)
	tp.anchor_left = 0.16
	tp.anchor_right = 0.70
	tp.offset_top = game.hud_height() + 6
	tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tp)
	_top = UI.vbox(3)
	tp.add_child(_top)
	# ability buttons down the right edge, above the Pad's A / B (its stick sits bottom left)
	var bp := UI.panel(0.75)
	bp.anchor_left = 1.0
	bp.anchor_right = 1.0
	bp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bp.offset_right = -10
	bp.offset_top = game.hud_height() + 6
	add_child(bp)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	bp.add_child(_buttons)
	_refresh_top()
	_refresh_buttons()

# ---------------------------------------------------------------- arena <-> screen

func _k() -> float:
	return minf(size.x / Battle.ARENA.x, size.y / Battle.ARENA.y)

func _to_screen(p: Vector2) -> Vector2:
	return (size - Battle.ARENA * _k()) / 2.0 + p * _k()

func _to_arena(s: Vector2) -> Vector2:
	return (s - (size - Battle.ARENA * _k()) / 2.0) / _k()

# ---------------------------------------------------------------- the clock

func _process(delta: float) -> void:
	if sim == null or _ended or get_tree().paused:
		return
	_clock += delta
	var move := Vector2.ZERO
	if pad != null and is_instance_valid(pad) and pad.visible:
		move = pad.get_vector("move")
	elif InputMap.has_action("pad_move_left"):
		move = Input.get_vector("pad_move_left", "pad_move_right", "pad_move_up", "pad_move_down")
	if _dragging and _drag.length() > 12.0:
		move = (_drag / 90.0).limit_length(1.0)
	sim.tick(delta, move)
	_sounds()
	_field.queue_redraw()
	_refresh_top()
	_refresh_buttons()
	if sim.outcome != "":
		_ended = true
		if sim.outcome in ["won", "boarded"]:
			SoundLib.play(self, "scifi/explosion_crunch")
		finished.emit(sim.outcome, sim.result_info())

func _sounds() -> void:
	if sim.shots.size() > _shots_seen:
		for i in range(_shots_seen, sim.shots.size()):
			if sim.shots[i].mine:
				SoundLib.play(self, "scifi/laser_small", -8.0)
			elif sim.shots[i].hit:
				SoundLib.play(self, "scifi/impact_metal", -6.0)
	_shots_seen = sim.shots.size()

func _gui_input(event: InputEvent) -> void:
	if sim == null or _ended:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var i: int = sim.foe_at(_to_arena(event.position), 110.0)
			if i >= 0:
				sim.pick_target(i)
			else:
				_dragging = true
				_drag_from = event.position
				_drag = Vector2.ZERO
		else:
			_dragging = false
			_drag = Vector2.ZERO
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_drag = event.position - _drag_from
		accept_event()

# ---------------------------------------------------------------- HUD

func _refresh_top() -> void:
	for ch in _top.get_children():
		ch.queue_free()
	var t: Dictionary = sim.target_foe()
	var ed: Dictionary = D.ENEMIES[str(engine.encounter.get("enemy", "pirate"))]
	_top.add_child(UI.label("%s  ·  %d/%d" % [UI.tr_s(ed.name), sim.alive_foes().size(), sim.foes.size()], 18, UI.c("bad")))
	if not t.is_empty():
		var shield_txt := " · 🛡 %d" % int(t.shield) if float(t.max_shield) > 0 else ""
		_top.add_child(UI.meter(UI.tr_s("Target"), float(t.hull), float(t.max), UI.c("bad"), 110.0, "%d%s" % [int(t.hull), shield_txt]))
	_top.add_child(UI.meter(UI.tr_s("Your hull"), float(sim.p.hull), float(sim.p.max_hull), UI.c("go"), 110.0))
	if int(sim.p.max_shield) > 0:
		_top.add_child(UI.meter(UI.tr_s("Shield"), float(sim.p.shield), float(sim.p.max_shield), UI.c("clean"), 110.0))
	if sim.flee_t >= 0.0:
		_top.add_child(UI.label(UI.tr_s("Spooling the jump drive... %.1f s") % sim.flee_t, 16, UI.c("warn")))

func _refresh_buttons() -> void:
	var list := [["shields", "🛡 " + UI.tr_s("Shields")], ["evade", "↯ " + UI.tr_s("Evade")]]
	if sim.p.get("hack", false):
		list.append(["hack", "⌁ " + UI.tr_s("Hack")])
	if sim.can_board():
		list.append(["board", "⚓ " + UI.tr_s("Board")])
	for a in sim.p.get("calls", []):
		if S.ABILITIES.has(a):
			list.append([a, S.ABILITIES[a].icon + " " + UI.tr_s(S.ABILITIES[a].name)])
	if not sim.p.get("duel", false):
		list.append(["flee", "🏃 " + UI.tr_s("Flee")])
	# rebuild only when something changed (cooldowns show as disabled)
	var state := ""
	for it in list:
		state += "%s:%s;" % [it[0], sim.ready(it[0])]
	if state == _btn_state:
		return
	_btn_state = state
	for ch in _buttons.get_children():
		ch.queue_free()
	for it in list:
		var b := UI.button(it[1], _use.bind(it[0]), UI.c("go") if it[0] in ["board"] else UI.c("accent"), 18, 52)
		b.custom_minimum_size.x = 150
		b.disabled = not sim.ready(it[0])
		_buttons.add_child(b)

func _use(a: String) -> void:
	if sim.use(a):
		match a:
			"shields": SoundLib.play(self, "scifi/force_field")
			"flee": SoundLib.play(self, "scifi/thruster_fire")
			_: SoundLib.play(self, "scifi/computer_noise")
	_btn_state = ""

# ---------------------------------------------------------------- drawing

func _draw_field() -> void:
	var k := _k()
	var ship_w := size.x / 5.5
	# shots
	for s in sim.shots:
		var col := Color(0.4, 1.0, 0.6) if s.mine else Color(1.0, 0.35, 0.3)
		var a := _to_screen(s.a)
		var b := _to_screen(s.b)
		if not s.hit:
			b += Vector2(30, -24)
		_field.draw_line(a, b, Color(col, clampf(float(s.t) * 6.0, 0.0, 1.0)), 3.0)
		if s.hit:
			_field.draw_rect(Rect2(b - Vector2(5, 5), Vector2(10, 10)), Color(1.0, 0.9, 0.5, clampf(float(s.t) * 5.0, 0.0, 1.0)))
	# allies
	for al in sim.allies:
		var ap := _to_screen(al.pos)
		ShipArt.draw(_field, ap, ship_w * 0.45, 0.0, {"hull": "space/player_ship1_blue", "tier": 1, "guns": 1,
			"gun": "space/gun_0", "engines": 1, "engine": "space/engine_1"}, true, 0.0, _clock)
	# enemies
	for i in sim.foes.size():
		var f: Dictionary = sim.foes[i]
		if not f.alive:
			continue
		var fp := _to_screen(f.pos)
		var head: float = (sim.p.pos - f.pos).angle()
		var tint := Color(1, 1, 1, 0.55) if f.hacked > 0.0 else Color.WHITE
		ShipArt.draw(_field, fp, ship_w * 0.7, head, _enemy_specs[i], true, f.shield / maxf(1.0, f.max_shield) if f.max_shield > 0 else 0.0, _clock, tint)
		if i == sim.target:
			var r := ship_w * 0.5
			_field.draw_arc(fp, r, 0, TAU, 40, Color(UI.c("warn"), 0.9), 2.5, true)
			_field.draw_line(fp + Vector2(-r - 8, 0), fp + Vector2(-r + 6, 0), UI.c("warn"), 2.0)
			_field.draw_line(fp + Vector2(r - 6, 0), fp + Vector2(r + 8, 0), UI.c("warn"), 2.0)
		var hb := Rect2(fp + Vector2(-ship_w * 0.3, ship_w * 0.42), Vector2(ship_w * 0.6, 6))
		_field.draw_rect(hb, Color(0, 0, 0, 0.6))
		_field.draw_rect(Rect2(hb.position, Vector2(hb.size.x * clampf(f.hull / f.max, 0.0, 1.0), 6)), UI.c("bad"))
	# you
	var pp := _to_screen(sim.p.pos)
	var t: Dictionary = sim.target_foe()
	var ph: float = (t.pos - sim.p.pos).angle() if not t.is_empty() else 0.0
	if sim.p.vel.length() > 20.0:
		ph = sim.p.vel.angle()
	var ps: float = sim.p.shield / maxf(1.0, float(sim.p.max_shield)) if int(sim.p.max_shield) > 0 else 0.0
	var tint2 := Color(1, 1, 1, 0.6) if sim.evade_t > 0.0 else Color.WHITE
	ShipArt.draw(_field, pp, ship_w, ph, _player_spec, sim.p.vel.length() > 20.0, ps, _clock, tint2)
	if sim.spore_t > 0.0:
		_field.draw_circle(_to_screen(Battle.ARENA * Vector2(0.75, 0.5)), 220.0 * k, Color(0.7, 0.5, 1.0, 0.12))
