extends Control

## Stack Tower: tap anywhere to drop the sliding slab onto the tower.

const StEngine = preload("res://scripts/games/stack_tower/stack_tower_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/stack_tower/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/stack_tower/stack_tower_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://stack_tower_save.json"

const SLAB_H := 0.22   # slab height, in tower widths
const VISIBLE := 14    # layers kept on screen

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var started := false
var cam: float = 0.0          # layers scrolled away (smoothed)
var falling: Array = []       # [x, w, layer, y_offset, vy, hue]
var flash: float = 0.0
var flash_text := ""

var field: Control
var score_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/stack_tower/stack_tower_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = StEngine.new()
	_build_ui()
	engine.reset()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 44)
	score_label.add_theme_color_override("font_color", HomeKit.GOLD.lerp(Color.WHITE, 0.6))
	score_label.add_theme_color_override("font_outline_color", Color(HomeKit.GOLD, 0.5))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(score_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76, 0)
	bar.add_child(spacer)

	field = Control.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.gui_input.connect(_on_field_input)
	field.resized.connect(field.queue_redraw)
	root.add_child(field)

	var hint := Label.new()
	hint.text = tr("Tap anywhere to drop.")
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", HomeKit.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_bottom", 26)
	hm.add_child(hint)
	root.add_child(hm)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Tap to drop. Line it up — the overhang gets sliced off.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  " + tr("Play"), "sub": "How high can you build?", "action": _new_game}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _new_game,
		"board": "Best score",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.05)  # right of the score
	add_child(drawer)

# ---------- game flow ----------

func _new_game() -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset()
	started = true
	cam = 0.0
	falling.clear()
	flash = 0.0
	end_dialog.visible = false
	_update()

func _update() -> void:
	score_label.text = str(engine.score)

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_drop()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_drop()

func _drop() -> void:
	if not started or engine.over:
		return
	var layer: int = engine.layers.size()
	var res: String = engine.drop()
	if not engine.last_cut.is_empty():
		falling.append([engine.last_cut[0], engine.last_cut[1], layer, 0.0, 0.0, _hue(layer)])
	match res:
		"perfect":
			_sfx("record" if engine.streak >= StEngine.GROW_AFTER else "pickup")
			flash = 0.6
			flash_text = tr("Perfect!") if engine.streak < 2 else tr("Perfect ×%d") % engine.streak
		"cut":
			_sfx("place")
		"miss":
			_sfx("lose")
			_game_over()
	_update()

func _process(delta: float) -> void:
	if not started and falling.is_empty():
		return
	delta = minf(delta, 0.05)
	engine.step(delta)
	var want := maxf(0.0, engine.layers.size() - VISIBLE * 0.6)
	cam = lerpf(cam, want, minf(1.0, delta * 5.0))
	for f in falling:
		f[4] += 3.0 * delta
		f[3] += f[4] * delta
	falling = falling.filter(func(f): return f[3] < 6.0)
	flash = maxf(0.0, flash - delta)
	field.queue_redraw()

func _game_over() -> void:
	started = false
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("The slab missed!") + "\n" + tr("Height: %d") % engine.score
	if info:
		info.add("Games played")
		info.high("Most perfect drops in a row", engine.best_streak)
		if info.high("Best score", engine.score):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	var t := create_tween()
	t.tween_interval(0.9)
	t.tween_callback(_show_end)

func _show_end() -> void:
	end_dialog.visible = true

# ---------- drawing ----------

static func _hue(layer: int) -> Color:
	return Color.from_hsv(fposmod(0.5 + layer * 0.035, 1.0), 0.85, 1.0)

## Tower width in pixels, the slab height and the screen y of a layer.
func _geom() -> Dictionary:
	var unit: float = minf(field.size.x * 0.6, field.size.y / (VISIBLE * SLAB_H + 1.0)) / StEngine.WIDTH
	var ox: float = (field.size.x - StEngine.WIDTH * unit) / 2.0
	var h: float = StEngine.WIDTH * SLAB_H * unit
	return {"u": unit, "ox": ox, "h": h, "base": field.size.y - h * 1.5}

func _layer_y(i: float, g: Dictionary) -> float:
	return g.base - (i - cam) * g.h

func _slab(x: float, w: float, y: float, col: Color, g: Dictionary) -> void:
	var r := Rect2(g.ox + x * g.u, y, w * g.u, g.h - 2.0)
	field.draw_rect(r, Color(col, 0.22))
	field.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.25)), Color(col, 0.35))
	HomeKit.glow_rect(field, r, col, 2.0)

func _draw_field() -> void:
	if engine.layers.is_empty():
		return
	var g := _geom()
	for f in falling:  # behind the tower
		_slab(f[0], f[1], _layer_y(f[2], g) + f[3] * g.h * 4.0, Color(f[5], 0.7), g)
	for i in engine.layers.size():
		var y := _layer_y(i, g)
		if y > field.size.y + g.h or y < -g.h:
			continue
		var l: Array = engine.layers[i]
		_slab(l[0], l[1], y, _hue(i), g)
	if not engine.over and started:
		var n: int = engine.layers.size()
		_slab(engine.cur_x, engine.cur_w, _layer_y(n, g), _hue(n), g)
	if flash > 0.0:
		var top_y := _layer_y(engine.layers.size() - 1, g)
		var l2: Array = engine.layers[-1]
		var r := Rect2(g.ox + l2[0] * g.u, top_y, l2[1] * g.u, g.h).grow(10.0 * (1.0 - flash / 0.6) + 2.0)
		HomeKit.glow_rect(field, r, Color(Color.WHITE, flash / 0.6), 2.0)
		HomeKit.glow_text(field, Vector2(field.size.x / 2.0, top_y - g.h * 2.0), flash_text, 34, HomeKit.GOLD)

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y / 7.0, 22.0)
	var base := Vector2(c.size.x / 2.0, c.size.y - h)
	var widths := [6.0, 5.6, 5.6, 4.8, 4.8, 4.4]
	var offs := [0.0, 0.2, 0.2, 0.6, 0.6, 0.8]
	for i in widths.size():
		var w: float = widths[i] * h * 1.3
		var r := Rect2(base + Vector2(-3.0 * h * 1.3 + offs[i] * h * 1.3, -i * h * 1.1), Vector2(w, h))
		c.draw_rect(r, Color(_hue(i), 0.25))
		HomeKit.glow_rect(c, r, _hue(i), 2.0)
	var r2 := Rect2(base + Vector2(-0.5 * h, -6.6 * h * 1.1), Vector2(4.4 * h * 1.3, h))
	HomeKit.glow_rect(c, r2, _hue(6), 2.0, 0.25)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.over:
		return
	SaveUtil.write(SAVE_PATH, {"layers": engine.layers, "score": engine.score, "streak": engine.streak, "best": engine.best_streak})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Height: %d") % int(d.get("score", 0))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	_new_game()
	if d == null or d.get("layers", []).is_empty():
		return
	engine.layers = []
	for l in d.layers:
		engine.layers.append([float(l[0]), float(l[1])])
	engine.cur_w = engine.layers[-1][1]
	engine.score = int(d.get("score", 0))
	engine.streak = int(d.get("streak", 0))
	engine.best_streak = int(d.get("best", 0))
	engine._spawn()
	cam = maxf(0.0, engine.layers.size() - VISIBLE * 0.6)
	_update()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
