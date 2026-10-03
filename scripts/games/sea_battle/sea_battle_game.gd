extends Control

## Sea Battle vs the computer. Tap the enemy grid to fire; a hit earns another
## shot. Your own fleet is the small grid below. Shuffle it before firing.

const SeaEngine = preload("res://scripts/games/sea_battle/sea_battle_engine.gd")
const HomeKit = preload("res://scripts/games/sea_battle/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_WATER := Color(0.02, 0.06, 0.16)
const COLOR_GRID := Color(0.16, 0.45, 0.9, 0.5)
const COLOR_SHIP := Color(0.16, 0.9, 1.0, 0.35)
const COLOR_HIT := Color("ff2b6b")
const COLOR_SUNK := Color(0.45, 0.06, 0.2)
const COLOR_MISS := Color(0.75, 0.85, 1.0)
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://sea_battle_save.json"

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: SeaEngine
var enemy_board: Control
var own_board: Control
var status_label: Label
var shuffle_btn: Button
var ships_label: Label
var cpu_timer: Timer
var end_dialog: ColorRect
var playing := false  # a battle is on (not just the one behind Home)
var player_turn := true
var started := false

func _ready() -> void:
	preload("res://scripts/games/sea_battle/sea_battle_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = SeaEngine.new()
	_build_ui()
	_start_new_game()
	playing = false

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🚢 Sea Battle")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start_new_game)
	bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	enemy_board = Control.new()
	enemy_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_board.size_flags_stretch_ratio = 1.8
	enemy_board.mouse_filter = Control.MOUSE_FILTER_STOP
	enemy_board.draw.connect(_draw_enemy)
	enemy_board.gui_input.connect(_on_enemy_input)
	enemy_board.resized.connect(enemy_board.queue_redraw)
	root.add_child(enemy_board)

	var own_row := HBoxContainer.new()
	own_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	own_row.add_theme_constant_override("separation", 12)
	root.add_child(own_row)
	own_board = Control.new()
	own_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	own_board.draw.connect(_draw_own)
	own_board.resized.connect(own_board.queue_redraw)
	own_row.add_child(own_board)
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.custom_minimum_size = Vector2(230, 0)
	own_row.add_child(side)
	var own_label := Label.new()
	own_label.text = tr("Your fleet")
	own_label.add_theme_font_size_override("font_size", 24)
	own_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(own_label)
	shuffle_btn = Button.new()
	shuffle_btn.text = tr("🔀 Shuffle")
	shuffle_btn.custom_minimum_size = Vector2(210, 70)
	shuffle_btn.add_theme_font_size_override("font_size", 26)
	shuffle_btn.pressed.connect(_on_shuffle)
	side.add_child(shuffle_btn)
	ships_label = Label.new()
	ships_label.add_theme_font_size_override("font_size", 24)
	ships_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	ships_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(ships_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	root.add_child(spacer)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.wait_time = 0.7
	cpu_timer.timeout.connect(_cpu_shot)
	add_child(cpu_timer)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/sea_battle/sea_battle_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _start_new_game() -> void:
	playing = true
	result_recorded = false
	cpu_timer.stop()
	engine.new_game()
	player_turn = true
	started = false
	shuffle_btn.disabled = false
	end_dialog.visible = false
	status_label.text = tr("Tap the enemy waters to fire!")
	_redraw()

func _on_shuffle() -> void:
	if not started:
		engine.random_fleet(0)
		_redraw()

func _redraw() -> void:
	enemy_board.queue_redraw()
	own_board.queue_redraw()

# ---------- turns ----------

func _on_enemy_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not player_turn or engine.winner != -1:
		return
	var g := _geom(enemy_board)
	var p: Vector2 = (event.position - g.origin) / g.cell
	var c := floori(p.x)
	var r := floori(p.y)
	if r < 0 or c < 0 or r >= SeaEngine.SIZE or c >= SeaEngine.SIZE:
		return
	var res: Dictionary = engine.fire(1, r * SeaEngine.SIZE + c)
	if not res.valid:
		return
	started = true
	shuffle_btn.disabled = true
	_redraw()
	if res.win:
		_finish()
		return
	if res.sunk > 0:
		status_label.text = tr("You sank a ship! Fire again.")
	elif res.hit:
		status_label.text = tr("Hit! Fire again.")
	else:
		status_label.text = tr("Miss. The enemy is aiming...")
		player_turn = false
		cpu_timer.start()

func _cpu_shot() -> void:
	var res: Dictionary = engine.fire(0, engine.cpu_pick())
	_redraw()
	if res.win:
		_finish()
		return
	if res.hit:
		status_label.text = tr("They sank your ship!") if res.sunk > 0 else tr("You've been hit!")
		cpu_timer.start()
	else:
		status_label.text = tr("They missed. Your turn!")
		player_turn = true

func _finish() -> void:
	player_turn = false
	SaveUtil.delete(SAVE_PATH)
	var won: bool = engine.winner == 0
	end_dialog.get_meta("message_label").text = (tr("Victory! Their fleet is sunk.") if won else tr("Defeat. Your fleet is sunk.")) + _record_result("win" if won else "loss")
	end_dialog.visible = true

# ---------- drawing ----------

func _geom(b: Control) -> Dictionary:
	var cell: float = floor(min(b.size.x - 24.0, b.size.y - 4.0) / SeaEngine.SIZE)
	var total := cell * SeaEngine.SIZE
	return {"cell": cell, "origin": Vector2((b.size.x - total) / 2.0, (b.size.y - total) / 2.0)}

func _draw_grid(b: Control, side: int, reveal: bool) -> void:
	var g := _geom(b)
	var cell: float = g.cell
	var o: Vector2 = g.origin
	var n := SeaEngine.SIZE
	b.draw_rect(Rect2(o, Vector2(cell * n, cell * n)), COLOR_WATER)
	for i in n * n:
		var rect := Rect2(o + Vector2(i % n, i / n) * cell, Vector2(cell, cell))
		var shot: int = engine.shots[side][i]
		var ship: bool = engine.ship_at[side][i] != -1
		if ship and (reveal or engine.winner != -1):
			b.draw_rect(rect.grow(-cell * 0.08), COLOR_SHIP)
		if shot == SeaEngine.HIT:
			b.draw_rect(rect.grow(-cell * 0.08), COLOR_SUNK if engine.is_sunk_cell(side, i) else COLOR_HIT)
			var m := cell * 0.25
			var ce := rect.get_center()
			b.draw_line(ce - Vector2(m, m), ce + Vector2(m, m), Color(1, 1, 1), 3)
			b.draw_line(ce + Vector2(-m, m), ce + Vector2(m, -m), Color(1, 1, 1), 3)
		elif shot == SeaEngine.MISS:
			b.draw_circle(rect.get_center(), cell * 0.12, COLOR_MISS)
	for k in n + 1:
		b.draw_line(o + Vector2(k * cell, 0), o + Vector2(k * cell, n * cell), COLOR_GRID, 1)
		b.draw_line(o + Vector2(0, k * cell), o + Vector2(n * cell, k * cell), COLOR_GRID, 1)

func _draw_enemy() -> void:
	if engine.ship_at[1].is_empty():
		return
	_draw_grid(enemy_board, 1, false)
	ships_label.text = tr("Enemy ships left: %d") % engine.ships_left(1) + "\n" + tr("Your ships left: %d") % engine.ships_left(0)

func _draw_own() -> void:
	if engine.ship_at[0].is_empty():
		return
	_draw_grid(own_board, 0, true)


## Records this game's result in the stats once (end checks can run again
## after a game is over) and returns the recap line for the end screen.
func _record_result(outcome: String) -> String:
	if not info:
		return ""
	if not result_recorded:
		result_recorded = true
		info.result(outcome)
	return "\n" + info.summary()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/sea_battle/sea_battle_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/sea_battle/sea_battle_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Find and sink the computer's fleet before it sinks yours.",
		"logo": _draw_home_logo,
		"modes": [{"text": "⚓  Play", "sub": "vs the computer", "action": _fresh_game}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"restart": _start_new_game,
		"board": "Wins",
		"board_note": "Battles won.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 5.4, 32.0)
	var o := Vector2(c.size.x / 2.0 - k * 2.5, c.size.y / 2.0 - k * 2.5)
	for i in 6:
		c.draw_line(o + Vector2(i * k, 0), o + Vector2(i * k, 5 * k), Color(HomeKit.BLUE, 0.4), 1.5)
		c.draw_line(o + Vector2(0, i * k), o + Vector2(5 * k, i * k), Color(HomeKit.BLUE, 0.4), 1.5)
	HomeKit.glow_rect(c, Rect2(o + Vector2(1, 1) * k, Vector2(3 * k, k)).grow(-4), HomeKit.CYAN, 2.0, 0.25)
	for p in [Vector2(2, 1), Vector2(3, 1)]:
		var ce := o + (p + Vector2(0.5, 0.5)) * k
		HomeKit.glow_line(c, ce - Vector2(k, k) * 0.25, ce + Vector2(k, k) * 0.25, HomeKit.PINK, 2.0)
		HomeKit.glow_line(c, ce + Vector2(-k, k) * 0.25, ce + Vector2(k, -k) * 0.25, HomeKit.PINK, 2.0)
	for p in [Vector2(0, 3), Vector2(3, 3), Vector2(4, 0)]:
		c.draw_circle(o + (p + Vector2(0.5, 0.5)) * k, k * 0.12, Color.WHITE)

func _fresh_game() -> void:
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

## Saved on your turn (a computer volley replays from there).
func _save_game() -> void:
	if not playing or engine.winner != -1 or not player_turn:
		return
	SaveUtil.write(SAVE_PATH, {"ship_at": engine.ship_at, "ships": engine.ships, "shots": engine.shots, "started": started})

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_start_new_game()
		return
	_start_new_game()
	engine.ship_at = [_ints(d.ship_at[0]), _ints(d.ship_at[1])]
	engine.shots = [_ints(d.shots[0]), _ints(d.shots[1])]
	engine.ships = [[], []]
	for side in 2:
		for s in d.ships[side]:
			engine.ships[side].append({"cells": _ints(s.cells), "hits": int(s.hits)})
	started = bool(d.get("started", true))
	shuffle_btn.disabled = started
	_redraw()
