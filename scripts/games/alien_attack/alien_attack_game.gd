extends Control

## Alien Attack -- slide to move your cannon; it fires on its own.

const AAEngine = preload("res://scripts/games/alien_attack/alien_attack_engine.gd")
const HomeKit = preload("res://scripts/games/alien_attack/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://alien_attack_best.json"
const ROW_COLORS := [Color(1, 0.4, 0.8), Color(0.7, 0.5, 1), Color(0.4, 0.8, 1), Color(0.4, 1, 0.6), Color(1, 0.9, 0.4)]
## 8×6 pixel alien ("#" = filled), two animation frames
const SPRITES := [
	["..#..#..", "...##...", "..####..", ".##.##.#", "########", "#.#..#.#"],
	["..#..#..", "#..##..#", "#.####.#", "###.##.#", ".######.", ".#....#."],
]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: AAEngine
var board: Control
var info_label: Label
var start_dialog: ColorRect
var over_dialog: ColorRect
var pause_dialog: ColorRect
var running := false
var best: int = 0
var anim: float = 0.0
var stars: Array = []
var banner_time: float = 0.0
## Skull mode (skulls and voodoo dolls instead of aliens). Loaded, never
## preloaded: packs also run on apps before v0.21, which keep the aliens.
const VOODOO_PATH := "res://scripts/common/voodoo.gd"
var Voodoo = load(VOODOO_PATH) if ResourceLoader.exists(VOODOO_PATH) else null
var voodoo_on: bool = false
var rotate_hint: Control

## Called by the ⚙ drawer's Skull mode toggle; redraws in place.
func _set_voodoo(on: bool) -> void:
	voodoo_on = on and Voodoo != null
	if board:
		board.queue_redraw()

func _ready() -> void:
	preload("res://scripts/games/alien_attack/alien_attack_i18n.gd").install(self)
	Orientation.lock_landscape()
	engine = AAEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
	for i in 60:
		stars.append(Vector2(randf() * AAEngine.FIELD.x, randf() * AAEngine.FIELD.y))
	voodoo_on = Voodoo != null and Voodoo.is_on()
	_build_ui()
	engine.reset()
	_update_info()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Landscape: one slim bar (Hub · score line · Restart) so the field gets
	# the height.
	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 8)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 60)
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
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(info_label)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.add_theme_font_size_override("font_size", 24)
	restart_btn.pressed.connect(_start)
	bar.add_child(restart_btn)

	var bm := MarginContainer.new()
	bm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm.add_theme_constant_override("margin_left", 8)
	bm.add_theme_constant_override("margin_right", 8)
	bm.add_theme_constant_override("margin_bottom", 8)
	root.add_child(bm)
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	bm.add_child(board)

	start_dialog = UI.build_dialog(tr("👾 Alien Attack"), [
		{"text": tr("Start"), "action": _start},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	start_dialog.get_meta("message_label").text = tr("Slide to move. Your cannon fires by itself — dodge the bombs!")
	add_child(start_dialog)
	over_dialog = UI.build_dialog(tr("Game Over"), [
		{"text": tr("Play Again"), "action": _start},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(over_dialog)
	pause_dialog = UI.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	])
	add_child(pause_dialog)
	# Phones that ignore the landscape lock (or the PC build) get asked to turn.
	rotate_hint = ColorRect.new()
	rotate_hint.color = Color(0.03, 0.03, 0.07, 0.96)
	rotate_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	rotate_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	rotate_hint.visible = false
	var hint := Label.new()
	hint.text = "⟳\n" + tr("Rotate your device to landscape")
	hint.add_theme_font_size_override("font_size", 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	rotate_hint.add_child(hint)
	add_child(rotate_hint)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/alien_attack/alien_attack_help.gd"))
	_build_home()
	if info:
		add_child(info)
		if best > 0:
			info.high("Best score", best)
	add_child(SettingsDrawer.new())

func _start() -> void:
	engine.reset()
	over_dialog.visible = false
	running = true
	banner_time = 1.5
	_update_info()

func _resume() -> void:
	running = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and running and home:
			home.pause()

func _update_info() -> void:
	info_label.text = tr("👾 Alien Attack") + "     " + tr("Wave %d   Score: %d   Lives: %s   Best: %d") % [engine.wave, engine.score, "♥".repeat(max(0, engine.lives)), best]

func _process(delta: float) -> void:
	anim += delta
	var vp := get_viewport_rect().size
	rotate_hint.visible = vp.x < vp.y
	banner_time = max(0.0, banner_time - delta)
	if running:
		var pre := [engine.score, engine.lives, engine.shots.size()]
		var ev := engine.step(min(delta, 0.05))
		_watch_sfx(pre, ev)
		if ev == "wave":
			banner_time = 1.5
		elif ev == "over":
			running = false
			if engine.score > best:
				best = engine.score
				SaveUtil.write(BEST_PATH, {"best": best})
			if info:
				info.add("Games played")
				info.best("Best score", best)
				info.high("Highest wave", engine.wave)
			over_dialog.get_meta("message_label").text = tr("Score: %d") % engine.score + "\n" + tr("Best: %d") % best
			over_dialog.visible = true
		_update_info()
	board.queue_redraw()

func _scale() -> float:
	return min(board.size.x / AAEngine.FIELD.x, board.size.y / AAEngine.FIELD.y)

func _origin() -> Vector2:
	return (board.size - AAEngine.FIELD * _scale()) / 2.0

func _draw_board() -> void:
	var s := _scale()
	var o := _origin()
	board.draw_rect(Rect2(o, AAEngine.FIELD * s), Color(0.02, 0.02, 0.06))
	for st in stars:
		board.draw_rect(Rect2(o + st * s, Vector2(2, 2)), Color(1, 1, 1, 0.4))
	var frame := int(anim * 2.0) % 2
	for b in engine.shield_blocks:
		var sc := Color(0.35, 1, 0.5) if b.hp >= AAEngine.SHIELD_HP else Color(0.25, 0.7, 0.35)
		board.draw_rect(Rect2(o + b.rect.position * s, b.rect.size * s + Vector2(0.5, 0.5)), sc)
	for a in engine.aliens:
		if not a.alive:
			continue
		var r := engine.alien_rect(a)
		if voodoo_on:
			# Skull mode: rows of skulls, with voodoo dolls in the middle row,
			# bobbing in step with the march.
			var bob := Vector2(0, (2.0 if frame == 0 else -2.0) * s)
			var center: Vector2 = o + r.get_center() * s + bob
			var size: float = r.size.y * s * 1.25
			if a.row == 2:
				Voodoo.draw_doll(board, center, size, Voodoo.BONE, Voodoo.INK, Color(0, 0, 0, 0.6))
			else:
				Voodoo.draw_skull(board, center, size, ROW_COLORS[a.row].lerp(Voodoo.BONE, 0.55), Voodoo.INK, Color(0, 0, 0, 0.6))
			continue
		var sprite: Array = SPRITES[frame]
		var px := r.size.x / 8.0
		var py := r.size.y / 6.0
		for yy in 6:
			var line: String = sprite[yy]
			for xx in 8:
				if line[xx] == "#":
					board.draw_rect(Rect2(o + (r.position + Vector2(xx * px, yy * py)) * s, Vector2(px, py) * s + Vector2(0.5, 0.5)), ROW_COLORS[a.row])
	for p in engine.shots:
		board.draw_rect(Rect2(o + (p - Vector2(2, 10)) * s, Vector2(4, 16) * s), Color(0.6, 1, 1))
	for b in engine.bombs:
		board.draw_rect(Rect2(o + (b - Vector2(3, 8)) * s, Vector2(6, 14) * s), Color(1, 0.5, 0.3))
	# cannon (blinks after a hit)
	if engine.hit_flash <= 0.0 or int(anim * 10.0) % 2 == 0:
		var c := o + Vector2(engine.ship_x, AAEngine.SHIP_Y) * s
		var w := AAEngine.SHIP_W * s
		board.draw_rect(Rect2(c + Vector2(-w / 2.0, 0), Vector2(w, 16 * s)), Color(0.4, 1, 0.5))
		board.draw_rect(Rect2(c + Vector2(-w * 0.3, -8 * s), Vector2(w * 0.6, 10 * s)), Color(0.4, 1, 0.5))
		board.draw_rect(Rect2(c + Vector2(-3 * s, -20 * s), Vector2(6 * s, 14 * s)), Color(0.4, 1, 0.5))
	if banner_time > 0.0 and running:
		board.draw_string(ThemeDB.fallback_font, o + Vector2(0, AAEngine.FIELD.y * s * 0.6), tr("Wave %d") % engine.wave,
			HORIZONTAL_ALIGNMENT_CENTER, AAEngine.FIELD.x * s, 48, Color(1, 0.9, 0.4))

func _on_board_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		engine.set_ship((event.position.x - _origin().x) / _scale())

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/alien_attack/alien_attack_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/alien_attack/alien_attack_help.gd"),
		"info": info,
		"accent": HomeKit.LIME,
		"subtitle": "Slide to aim. Your cannon fires by itself — dodge the bombs!",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  Play", "sub": "Three lives, endless waves", "action": _start}],
		"restart": _start,
		"board_note": "Your best score.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var px := minf(c.size.y / 9.0, 16.0)
	var sprite: Array = SPRITES[0]
	var o := Vector2(c.size.x / 2.0 - px * 4.0, c.size.y / 2.0 - px * 4.5)
	for yy in 6:
		for xx in 8:
			if sprite[yy][xx] == "#":
				var r := Rect2(o + Vector2(xx, yy) * px, Vector2(px - 1, px - 1))
				c.draw_rect(r.grow(3), Color(ROW_COLORS[0], 0.18))
				c.draw_rect(r, ROW_COLORS[0])
	# the cannon and its shot
	var base := Vector2(c.size.x / 2.0, c.size.y - 10)
	HomeKit.glow_line(c, base + Vector2(0, -px * 1.2), base + Vector2(0, -px * 2.6), HomeKit.CYAN, 3.0)
	HomeKit.glow_rect(c, Rect2(base + Vector2(-px * 1.6, -px * 1.0), Vector2(px * 3.2, px)), HomeKit.LIME, 2.0, 0.3)

## Sounds from what changed this frame (the engine only reports waves).
func _watch_sfx(pre: Array, ev: String) -> void:
	if engine.lives < pre[1] or ev == "over":
		_sfx("explode")
	elif engine.score > pre[0]:
		_sfx("hit")
	elif ev == "wave":
		_sfx("powerup")
	if engine.shots.size() > pre[2]:
		_sfx("shoot")

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
