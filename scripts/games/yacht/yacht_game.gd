extends Control

## Yacht Dice -- roll up to three times, tap dice to hold them, then tap a box
## on the scorecard to score this turn.

const YEngine = preload("res://scripts/games/yacht/yacht_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://yacht_best.json"
const PIPS := {1: [[1, 1]], 2: [[0, 0], [2, 2]], 3: [[0, 0], [1, 1], [2, 2]], 4: [[0, 0], [2, 0], [0, 2], [2, 2]],
	5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]], 6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]]}

var info = null  # GameInfo; null on apps without it, so guard every use
var engine: YEngine
var dice_row: Control
var roll_btn: Button
var total_label: Label
var hint_label: Label
var cat_buttons: Dictionary = {}
var end_dialog: ColorRect
var best: int = 0
var shake: float = 0.0

func _ready() -> void:
	preload("res://scripts/games/yacht/yacht_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = YEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
	_build_ui()
	_start()

func _names() -> Dictionary:
	return {"ones": tr("Ones"), "twos": tr("Twos"), "threes": tr("Threes"), "fours": tr("Fours"), "fives": tr("Fives"),
		"sixes": tr("Sixes"), "three_kind": tr("3 of a Kind"), "four_kind": tr("4 of a Kind"), "full_house": tr("Full House"),
		"small_straight": tr("Small Straight"), "large_straight": tr("Large Straight"), "yacht": tr("Yacht"), "chance": tr("Chance")}

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.25, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
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
	title.text = tr("🎲 Yacht Dice")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start)
	bar.add_child(restart_btn)

	total_label = Label.new()
	total_label.add_theme_font_size_override("font_size", 28)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(total_label)

	dice_row = Control.new()
	dice_row.custom_minimum_size = Vector2(0, 150)
	dice_row.mouse_filter = Control.MOUSE_FILTER_STOP
	dice_row.draw.connect(_draw_dice)
	dice_row.gui_input.connect(_on_dice_input)
	root.add_child(dice_row)

	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.85))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_label)

	var rc := CenterContainer.new()
	root.add_child(rc)
	roll_btn = Button.new()
	roll_btn.custom_minimum_size = Vector2(320, 80)
	roll_btn.add_theme_font_size_override("font_size", 30)
	roll_btn.pressed.connect(_on_roll)
	roll_btn.set_meta("sfx", "")  # _on_roll rattles the dice instead of a tap
	rc.add_child(roll_btn)

	var gm := MarginContainer.new()
	gm.add_theme_constant_override("margin_left", 16)
	gm.add_theme_constant_override("margin_right", 16)
	gm.add_theme_constant_override("margin_bottom", 30)
	gm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(gm)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	gm.add_child(grid)
	for cat in YEngine.CATEGORIES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 23)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_category.bind(cat))
		grid.add_child(b)
		cat_buttons[cat] = b

	end_dialog = UI.build_dialog(tr("Game Over"), [
		{"text": tr("Play Again"), "action": _start},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/yacht/yacht_help.gd"))
		add_child(info)
		if best > 0:
			info.high("Best score", best)
	add_child(SettingsDrawer.new())

func _start() -> void:
	engine.reset()
	end_dialog.visible = false
	_refresh()

func _process(delta: float) -> void:
	if shake > 0.0:
		shake -= delta
		dice_row.queue_redraw()

func _on_roll() -> void:
	if engine.roll():
		shake = 0.25
		_sfx("dice_roll")
		_refresh()

func _on_category(cat: String) -> void:
	if engine.use(cat):
		_sfx("merge")
		_refresh()
		if engine.is_over():
			var t := engine.total()
			if t > best:
				best = t
				SaveUtil.write(BEST_PATH, {"best": best})
			if info:
				info.add("Games played")
				info.best("Best score", best)
			end_dialog.get_meta("message_label").text = tr("Final score: %d") % t + "\n" + tr("Best: %d") % best
			end_dialog.visible = true

func _refresh() -> void:
	var names := _names()
	var up := engine.upper_total()
	total_label.text = tr("Total: %d   Upper: %d/63   Best: %d") % [engine.total(), up, best]
	roll_btn.disabled = not engine.can_roll()
	roll_btn.text = tr("🎲 Roll (%d left)") % engine.rolls_left
	if not engine.has_rolled():
		hint_label.text = tr("Roll the dice to start your turn.")
	elif engine.rolls_left > 0:
		hint_label.text = tr("Tap dice to hold them, roll again, or pick a box.")
	else:
		hint_label.text = tr("Pick a box to score.")
	for cat in YEngine.CATEGORIES:
		var b: Button = cat_buttons[cat]
		if engine.scores.has(cat):
			b.text = "✓ %s: %d" % [names[cat], engine.scores[cat]]
			b.disabled = true
		else:
			var preview := YEngine.score_for(cat, engine.dice) if engine.has_rolled() else 0
			b.text = "%s: %s" % [names[cat], str(preview) if engine.has_rolled() else "–"]
			b.disabled = not engine.has_rolled()
	dice_row.queue_redraw()

func _die_rect(i: int) -> Rect2:
	var s: float = min(120.0, (dice_row.size.x - 60.0) / 5.0 - 12.0)
	var total := 5 * s + 4 * 16.0
	var x := (dice_row.size.x - total) / 2.0 + i * (s + 16.0)
	return Rect2(Vector2(x, (dice_row.size.y - s) / 2.0), Vector2(s, s))

func _draw_dice() -> void:
	for i in 5:
		var r := _die_rect(i)
		if shake > 0.0 and not engine.held[i]:
			r.position += Vector2(randf_range(-4, 4), randf_range(-4, 4))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.97, 0.97, 0.95) if engine.has_rolled() else Color(0.6, 0.65, 0.63)
		sb.set_corner_radius_all(int(r.size.x * 0.16))
		if engine.held[i]:
			sb.set_border_width_all(6)
			sb.border_color = Color(1, 0.8, 0.2)
		dice_row.draw_style_box(sb, r)
		if engine.has_rolled():
			for sp in PIPS[engine.dice[i]]:
				var p := r.position + Vector2(0.22 + sp[0] * 0.28, 0.22 + sp[1] * 0.28) * r.size.x
				dice_row.draw_circle(p, r.size.x * 0.085, Color(0.12, 0.12, 0.14))
		if engine.held[i]:
			dice_row.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.end.y + 22), tr("Held").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color(1, 0.8, 0.2))

func _on_dice_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in 5:
			if _die_rect(i).has_point(event.position):
				var was: bool = engine.held[i]
				engine.toggle_hold(i)
				if engine.held[i] != was:
					_sfx("toggle" if engine.held[i] else "back")
				dice_row.queue_redraw()
				return

## Plays a sound from the app's library (silent on apps from before v0.23).
func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
