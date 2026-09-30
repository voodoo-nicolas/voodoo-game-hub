extends Control

## Alien Attack -- slide to move your cannon; it fires on its own.

const AAEngine = preload("res://scripts/games/alien_attack/alien_attack_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")

const BEST_PATH := "user://alien_attack_best.json"
const ROW_COLORS := [Color(1, 0.4, 0.8), Color(0.7, 0.5, 1), Color(0.4, 0.8, 1), Color(0.4, 1, 0.6), Color(1, 0.9, 0.4)]
## 8×6 pixel alien ("#" = filled), two animation frames
const SPRITES := [
	["..#..#..", "...##...", "..####..", ".##.##.#", "########", "#.#..#.#"],
	["..#..#..", "#..##..#", "#.####.#", "###.##.#", ".######.", ".#....#."],
]

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

func _ready() -> void:
	preload("res://scripts/games/alien_attack/alien_attack_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = AAEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
	for i in 60:
		stars.append(Vector2(randf() * AAEngine.FIELD.x, randf() * AAEngine.FIELD.y))
	_build_ui()
	engine.reset()
	_update_info()
	start_dialog.visible = true

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
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
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("👾 Alien Attack")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start)
	bar.add_child(restart_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 26)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

	var bm := MarginContainer.new()
	bm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm.add_theme_constant_override("margin_left", 8)
	bm.add_theme_constant_override("margin_right", 8)
	bm.add_theme_constant_override("margin_bottom", 24)
	root.add_child(bm)
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	bm.add_child(board)

	start_dialog = UI.build_dialog(tr("👾 Alien Attack"), [
		{"text": tr("Start"), "action": _start},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	start_dialog.get_meta("message_label").text = tr("Slide to move. Your cannon fires by itself — dodge the bombs!")
	add_child(start_dialog)
	over_dialog = UI.build_dialog(tr("Game Over"), [
		{"text": tr("Play Again"), "action": _start},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(over_dialog)
	pause_dialog = UI.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("Exit to Hub"), "action": UI.exit_to_hub.bind(self)},
	])
	add_child(pause_dialog)
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
		if is_node_ready() and running:
			running = false
			pause_dialog.visible = true

func _update_info() -> void:
	info_label.text = tr("Wave %d   Score: %d   Lives: %s   Best: %d") % [engine.wave, engine.score, "♥".repeat(max(0, engine.lives)), best]

func _process(delta: float) -> void:
	anim += delta
	banner_time = max(0.0, banner_time - delta)
	if running:
		var ev := engine.step(min(delta, 0.05))
		if ev == "wave":
			banner_time = 1.5
		elif ev == "over":
			running = false
			if engine.score > best:
				best = engine.score
				SaveUtil.write(BEST_PATH, {"best": best})
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
	for a in engine.aliens:
		if not a.alive:
			continue
		var r := engine.alien_rect(a)
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
