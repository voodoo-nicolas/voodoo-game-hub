extends Control

const ThreeManEngine = preload("res://scripts/games/three_man/three_man_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

## Dice are drawn, not typeset: the Unicode die glyphs (⚀-⚅) are missing from
## most phone fonts and rendered as boxes.
const DIE_GOLD := Color("ffae2b")

var info = null  # GameInfo; null on apps without it, so guard every use
var engine
var num_players: int = 4

var setup_box: Control
var tiebreak_box: Control
var play_box: Control

var players_label: Label
var tiebreak_rolls_label: Label
var tiebreak_status_label: Label
var tiebreak_btn: Button

var turn_label: Label
var three_man_label: Label
var dice_view: Control
var dice_values := [1, 1]
var messages_label: Label
var roll_btn: Button

func _ready() -> void:
	preload("res://scripts/games/three_man/three_man_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = ThreeManEngine.new()
	_build_ui()
	_show_setup()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_margin.add_child(top_bar)

	var hub_btn := Button.new()
	hub_btn.text = tr("Hub")
	hub_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("3️⃣ Three Man")
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	top_bar.add_child(spacer)

	_build_setup(root)
	_build_tiebreak(root)
	_build_play(root)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/three_man/three_man_help.gd"))
		add_child(info)
	add_child(SettingsDrawer.new())

func _build_setup(root: VBoxContainer) -> void:
	setup_box = CenterContainer.new()
	setup_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(setup_box)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	setup_box.add_child(box)

	var label := Label.new()
	label.text = tr("How many players?")
	label.add_theme_font_size_override("font_size", 31)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	var counter_row := HBoxContainer.new()
	counter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	counter_row.add_theme_constant_override("separation", 24)
	box.add_child(counter_row)

	var minus_btn := Button.new()
	minus_btn.text = "－"
	minus_btn.custom_minimum_size = Vector2(64, 64)
	minus_btn.add_theme_font_size_override("font_size", 35)
	minus_btn.pressed.connect(func():
		num_players = max(2, num_players - 1)
		players_label.text = str(num_players)
	)
	counter_row.add_child(minus_btn)

	players_label = Label.new()
	players_label.text = str(num_players)
	players_label.add_theme_font_size_override("font_size", 46)
	players_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	players_label.custom_minimum_size = Vector2(70, 0)
	players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter_row.add_child(players_label)

	var plus_btn := Button.new()
	plus_btn.text = "＋"
	plus_btn.custom_minimum_size = Vector2(64, 64)
	plus_btn.add_theme_font_size_override("font_size", 35)
	plus_btn.pressed.connect(func():
		num_players = min(12, num_players + 1)
		players_label.text = str(num_players)
	)
	counter_row.add_child(plus_btn)

	var start_btn := Button.new()
	start_btn.text = tr("Start Game")
	start_btn.custom_minimum_size = Vector2(220, 56)
	start_btn.add_theme_font_size_override("font_size", 26)
	start_btn.pressed.connect(_on_start_pressed)
	box.add_child(start_btn)

	var rules_label := Label.new()
	rules_label.text = tr("Roll 1 die each — lowest goes first (ties re-roll).\nThen pass the phone: roll 2 dice on your turn.\n7 = right drinks · 11 = left drinks · Doubles = give that many\nAny 3 (or 2&1) = become/feed 3 Man. Keep rolling while someone drinks!")
	rules_label.add_theme_font_size_override("font_size", 19)
	rules_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
	rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	rules_label.custom_minimum_size = Vector2(300, 0)
	box.add_child(rules_label)

func _build_tiebreak(root: VBoxContainer) -> void:
	tiebreak_box = CenterContainer.new()
	tiebreak_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tiebreak_box.visible = false
	root.add_child(tiebreak_box)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	tiebreak_box.add_child(box)

	var label := Label.new()
	label.text = tr("Rolling to see who goes first…")
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	tiebreak_rolls_label = Label.new()
	tiebreak_rolls_label.add_theme_font_size_override("font_size", 24)
	tiebreak_rolls_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75))
	tiebreak_rolls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tiebreak_rolls_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tiebreak_rolls_label.custom_minimum_size = Vector2(300, 0)
	box.add_child(tiebreak_rolls_label)

	tiebreak_status_label = Label.new()
	tiebreak_status_label.add_theme_font_size_override("font_size", 28)
	tiebreak_status_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	tiebreak_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tiebreak_status_label)

	tiebreak_btn = Button.new()
	tiebreak_btn.text = tr("Roll for First")
	tiebreak_btn.custom_minimum_size = Vector2(220, 56)
	tiebreak_btn.add_theme_font_size_override("font_size", 26)
	tiebreak_btn.pressed.connect(_on_tiebreak_pressed)
	box.add_child(tiebreak_btn)

func _build_play(root: VBoxContainer) -> void:
	play_box = CenterContainer.new()
	play_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_box.visible = false
	root.add_child(play_box)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	play_box.add_child(box)

	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 31)
	turn_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(turn_label)

	three_man_label = Label.new()
	three_man_label.add_theme_font_size_override("font_size", 22)
	three_man_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7))
	three_man_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(three_man_label)

	dice_view = Control.new()
	dice_view.custom_minimum_size = Vector2(300, 150)
	dice_view.draw.connect(_draw_dice)
	box.add_child(dice_view)

	messages_label = Label.new()
	messages_label.add_theme_font_size_override("font_size", 25)
	messages_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	messages_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	messages_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	messages_label.custom_minimum_size = Vector2(300, 0)
	box.add_child(messages_label)

	roll_btn = Button.new()
	roll_btn.text = tr("🎲 Roll")
	roll_btn.custom_minimum_size = Vector2(220, 56)
	roll_btn.add_theme_font_size_override("font_size", 26)
	roll_btn.pressed.connect(_on_roll_pressed)
	box.add_child(roll_btn)

# ---------- flow ----------

func _show_setup() -> void:
	setup_box.visible = true
	tiebreak_box.visible = false
	play_box.visible = false

func _on_start_pressed() -> void:
	if info:
		info.add("Games played")
	engine.reset(num_players)
	setup_box.visible = false
	play_box.visible = false
	tiebreak_box.visible = true
	tiebreak_rolls_label.text = ""
	tiebreak_status_label.text = ""
	tiebreak_btn.text = tr("Roll for First")

func _on_tiebreak_pressed() -> void:
	var result: Dictionary = engine.roll_tiebreak()
	var pieces: PackedStringArray = []
	for p in result.rolls.keys():
		pieces.append("P%d: %d" % [p + 1, result.rolls[p]])
	tiebreak_rolls_label.text = ", ".join(pieces)

	if result.resolved:
		tiebreak_status_label.text = tr("Player %d goes first!") % (result.first_player + 1)
		tiebreak_btn.text = tr("Start Playing ➜")
		tiebreak_btn.pressed.disconnect(_on_tiebreak_pressed)
		tiebreak_btn.pressed.connect(_on_begin_play)
	else:
		var names: PackedStringArray = []
		for p in result.pool:
			names.append("P%d" % (p + 1))
		tiebreak_status_label.text = tr("Tied: %s — reroll!") % ", ".join(names)

func _on_begin_play() -> void:
	tiebreak_box.visible = false
	play_box.visible = true
	messages_label.text = ""
	_set_dice(1, 1)
	_update_turn_display()

func _update_turn_display() -> void:
	turn_label.text = tr("Player %d's turn") % (engine.current_player + 1)
	three_man_label.text = tr("3 Man: Player %d") % (engine.three_man + 1) if engine.three_man >= 0 else tr("3 Man: not assigned yet")
	roll_btn.text = tr("🎲 Roll")

func _on_roll_pressed() -> void:
	var result: Dictionary = engine.roll_turn()
	if info:
		info.add("Rolls")
	_set_dice(result.die1, result.die2)
	messages_label.text = "\n".join(result.messages)
	three_man_label.text = tr("3 Man: Player %d") % (engine.three_man + 1) if engine.three_man >= 0 else tr("3 Man: not assigned yet")

	if result.continue_turn:
		roll_btn.text = tr("🎲 Roll Again")
	else:
		roll_btn.text = tr("Next Player ➜")
		roll_btn.pressed.disconnect(_on_roll_pressed)
		roll_btn.pressed.connect(_on_next_player_pressed)

func _on_next_player_pressed() -> void:
	engine.advance_player()
	roll_btn.pressed.disconnect(_on_next_player_pressed)
	roll_btn.pressed.connect(_on_roll_pressed)
	messages_label.text = ""
	_set_dice(1, 1)
	_update_turn_display()

# ---------- dice ----------

func _set_dice(a: int, b: int) -> void:
	dice_values = [a, b]
	dice_view.queue_redraw()

func _draw_dice() -> void:
	var c := dice_view.size * 0.5
	dice_view.draw_set_transform(c + Vector2(-72, 4), deg_to_rad(-8.0), Vector2.ONE)
	_draw_die(dice_view, 110.0, dice_values[0])
	dice_view.draw_set_transform(c + Vector2(72, -4), deg_to_rad(9.0), Vector2.ONE)
	_draw_die(dice_view, 110.0, dice_values[1])
	dice_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A neon die of side `d` centered on the canvas transform's origin: dark body
## with a glowing gold edge, a slab underneath for thickness, glowing pips.
func _draw_die(c: CanvasItem, d: float, value: int) -> void:
	var h := d * 0.5
	var col := DIE_GOLD
	_die_slab(c, Rect2(-h + d * 0.05, -h + d * 0.1, d, d), col.darkened(0.65), col.darkened(0.45), d * 0.2, 0.0)
	_die_slab(c, Rect2(-h, -h, d, d), Color(0.08, 0.06, 0.1), col, d * 0.2, 0.55)
	_die_slab(c, Rect2(-h + d * 0.07, -h + d * 0.06, d * 0.86, d * 0.38), Color(col, 0.13), Color(col, 0.0), d * 0.14, 0.0)
	var o := d * 0.25
	var spots := {
		1: [Vector2.ZERO],
		2: [Vector2(-o, -o), Vector2(o, o)],
		3: [Vector2(-o, -o), Vector2.ZERO, Vector2(o, o)],
		4: [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)],
		5: [Vector2(-o, -o), Vector2(o, -o), Vector2.ZERO, Vector2(-o, o), Vector2(o, o)],
		6: [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, 0), Vector2(o, 0), Vector2(-o, o), Vector2(o, o)],
	}
	for p in spots.get(clampi(value, 1, 6), []):
		c.draw_circle(p, d * 0.1 + 2.5, Color(col, 0.28))
		c.draw_circle(p, d * 0.1, col.lightened(0.75))

func _die_slab(c: CanvasItem, rect: Rect2, fill: Color, border: Color, radius: float, glow: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	sb.set_border_width_all(2 if border.a > 0.0 else 0)
	sb.border_color = border
	if glow > 0.0:
		sb.shadow_color = Color(border, glow * 0.6)
		sb.shadow_size = 8
	c.draw_style_box(sb, rect)
