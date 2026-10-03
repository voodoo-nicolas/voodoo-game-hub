extends Control

## Charades -- landscape, phone on the guesser's forehead. Tilt down (screen
## to the floor) = got it, tilt up (screen to the ceiling) = pass. Tapping
## the right / left half of the screen does the same, for PCs and phones
## without a working tilt sensor.

const CHEngine = preload("res://scripts/games/charades/charades_engine.gd")
const HomeKit = preload("res://scripts/games/charades/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const CAT_ICONS := {"Animals": "🐘", "Actions": "🏃", "Jobs": "👩‍🚒", "Food": "🍕", "Sports": "⚽", "Things": "☂️"}
const COLOR_PLAY := Color(0.12, 0.3, 0.6)
const COLOR_RIGHT := Color(0.15, 0.6, 0.25)
const COLOR_PASS := Color(0.8, 0.45, 0.1)
## Tilt thresholds on the screen-normal share of gravity (-1..1): past
## TILT_ON counts, and the phone must come back inside TILT_REARM before the
## next word can be marked.
const TILT_ON := 0.6
const TILT_REARM := 0.35

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: CHEngine
var state := "menu"         # menu | countdown | play | results
var time_left := 0.0
var countdown := 0.0
var armed := false
var cooldown := 0.0
var tilt_flipped := false   # some phones report the sensor the other way round

var bg: ColorRect
var menu_box: Control
var tilt_btn: Button
var play_box: Control
var word_label: Label
var timer_label: Label
var hint_label: Label
var results_box: Control
var results_title: Label
var results_grid: GridContainer

func _ready() -> void:
	preload("res://scripts/games/charades/charades_i18n.gd").install(self)
	Orientation.lock_landscape()
	engine = CHEngine.new()
	_build_ui()
	_show_menu()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 16)
	top.add_theme_constant_override("margin_left", 24)
	top.add_theme_constant_override("margin_right", 70)
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
	title.text = tr("🎭 Charades")
	title.add_theme_font_size_override("font_size", 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 44)
	timer_label.custom_minimum_size = Vector2(160, 0)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(timer_label)

	_build_menu(root)
	_build_play(root)
	_build_results(root)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/charades/charades_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _label(size: int, color: Color = Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _build_menu(root: VBoxContainer) -> void:
	menu_box = CenterContainer.new()
	menu_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(menu_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	menu_box.add_child(box)
	var pick := _label(40)
	pick.text = tr("Pick a category")
	box.add_child(pick)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	box.add_child(grid)
	for cat in CHEngine.CATEGORIES:
		var b := Button.new()
		b.text = "%s  %s" % [CAT_ICONS[cat], tr(cat)]
		b.custom_minimum_size = Vector2(420, 120)
		b.add_theme_font_size_override("font_size", 40)
		b.pressed.connect(_start.bind(cat))
		grid.add_child(b)
	var how := _label(28, Color(0.75, 0.75, 0.85))
	how.text = tr("Hold the phone to your forehead. Tilt down = got it ✓ · tilt up = pass ✗")
	box.add_child(how)
	tilt_btn = Button.new()
	tilt_btn.add_theme_font_size_override("font_size", 26)
	tilt_btn.pressed.connect(_toggle_tilt)
	box.add_child(tilt_btn)

func _build_play(root: VBoxContainer) -> void:
	play_box = Control.new()
	play_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_box.mouse_filter = Control.MOUSE_FILTER_STOP
	play_box.gui_input.connect(_on_play_input)
	root.add_child(play_box)
	word_label = _label(150)
	word_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	word_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # content, not UI
	word_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	word_label.add_theme_constant_override("outline_size", 10)
	word_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_box.add_child(word_label)
	hint_label = _label(26, Color(1, 1, 1, 0.6))
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -70
	hint_label.offset_bottom = -20
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_box.add_child(hint_label)

func _build_results(root: VBoxContainer) -> void:
	results_box = VBoxContainer.new()
	results_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_box.add_theme_constant_override("separation", 16)
	root.add_child(results_box)
	results_title = _label(60, Color(1, 0.85, 0.3))
	results_box.add_child(results_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	results_box.add_child(scroll)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cc)
	results_grid = GridContainer.new()
	results_grid.columns = 3
	results_grid.add_theme_constant_override("h_separation", 60)
	results_grid.add_theme_constant_override("v_separation", 6)
	cc.add_child(results_grid)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	var rm := MarginContainer.new()
	rm.add_theme_constant_override("margin_bottom", 30)
	rm.add_child(row)
	results_box.add_child(rm)
	var again := Button.new()
	again.text = tr("Play Again")
	again.custom_minimum_size = Vector2(380, 96)
	again.add_theme_font_size_override("font_size", 34)
	again.pressed.connect(func(): _start(engine.category))
	row.add_child(again)
	var cats := Button.new()
	cats.text = tr("Categories")
	cats.custom_minimum_size = Vector2(380, 96)
	cats.add_theme_font_size_override("font_size", 34)
	cats.pressed.connect(_show_menu)
	row.add_child(cats)

# ---------- flow ----------

func _show_menu() -> void:
	state = "menu"
	bg.color = HomeKit.BG
	menu_box.visible = true
	play_box.visible = false
	results_box.visible = false
	timer_label.text = ""
	tilt_btn.text = tr("Tilt: down = ✓ (tap to swap)") if not tilt_flipped else tr("Tilt: up = ✓ (tap to swap)")

func _toggle_tilt() -> void:
	tilt_flipped = not tilt_flipped
	_show_menu()

func _start(cat: String) -> void:
	engine.start_round(cat, TranslationServer.get_locale().begins_with("es"))
	menu_box.visible = false
	results_box.visible = false
	play_box.visible = true
	state = "countdown"
	countdown = 3.0
	bg.color = COLOR_PLAY
	hint_label.text = tr("Put the phone on your forehead!")
	time_left = CHEngine.ROUND_SECONDS
	timer_label.text = ""

func _process(delta: float) -> void:
	match state:
		"countdown":
			countdown -= delta
			word_label.text = str(ceili(countdown)) if countdown > 0 else ""
			if countdown <= 0:
				state = "play"
				armed = false
				cooldown = 0.4
				word_label.text = engine.current
				hint_label.text = tr("✗ tap left to pass · tap right if they got it ✓")
		"play":
			time_left -= delta
			timer_label.text = "%d" % ceili(maxf(time_left, 0))
			if time_left <= 0:
				_end_round()
				return
			cooldown -= delta
			_read_tilt()

func _read_tilt() -> void:
	var a: Vector3 = Input.get_accelerometer()
	if a.length() < 2.0:
		return  # no sensor (PC) -- taps only
	var z := a.z / a.length()  # gravity's share along the screen normal
	if tilt_flipped:
		z = -z
	if not armed:
		if absf(z) < TILT_REARM:
			armed = true
		return
	if cooldown > 0:
		return
	if z > TILT_ON:
		_mark(true)    # screen tipped toward the floor
	elif z < -TILT_ON:
		_mark(false)   # screen tipped toward the ceiling

func _on_play_input(event: InputEvent) -> void:
	if state != "play" or cooldown > 0:
		return
	var pos := Vector2(-1, -1)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos.x >= 0:
		_mark(pos.x > play_box.size.x / 2.0)

func _mark(correct: bool) -> void:
	engine.mark(correct)
	armed = false
	cooldown = 0.6
	var flash := COLOR_RIGHT if correct else COLOR_PASS
	bg.color = flash
	bg.create_tween().tween_property(bg, "color", COLOR_PLAY, 0.5)
	word_label.text = tr("Got it! ✓") if correct else tr("Pass ✗")
	var tw := word_label.create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(_show_current_word)

func _show_current_word() -> void:
	if state == "play":
		word_label.text = engine.current

func _end_round() -> void:
	state = "results"
	timer_label.text = ""
	play_box.visible = false
	results_box.visible = true
	bg.color = Color(0.1, 0.08, 0.16)
	var n := engine.score()
	results_title.text = tr("Time's up! %d correct") % n
	for c in results_grid.get_children():
		c.queue_free()
	for r in engine.results:
		var l := _label(32, Color(0.55, 1, 0.55) if r[1] else Color(1, 0.65, 0.4))
		l.text = ("✓ " if r[1] else "✗ ") + r[0]
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		results_grid.add_child(l)
	if info:
		info.add("Rounds played")
		info.add("Words guessed", n)
		info.best("Most words in a round", n)

# ---------- Home screen (home_kit.gd) ----------

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/charades/charades_help.gd"),
		"info": info,
		"accent": HomeKit.PINK,
		"subtitle": "Phone on your forehead, friends act it out. 60 seconds a round!",
		"logo": _draw_home_logo,
		"multi_heading": "Party · one phone, a group of friends",
		"modes": [{"text": "🎭  Play", "sub": "Pick a category", "multi": true, "color": HomeKit.PINK, "action": _show_menu}],
		"restart": _show_menu,
		"board": "Most words in a round",
		"board_note": "The most words guessed in one 60-second round.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 170.0)
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	# a phone held sideways with a word on it, and two tilt arrows
	var r := Rect2(ctr - Vector2(h * 0.75, h * 0.32), Vector2(h * 1.5, h * 0.64))
	HomeKit.glow_rect(c, r, HomeKit.PINK, 3.0, 0.1)
	HomeKit.glow_text(c, ctr, tr("Charades").to_upper(), int(h * 0.17), Color.WHITE)
	for side in [-1, 1]:
		var a := ctr + Vector2(side * h * 0.95, 0)
		HomeKit.glow_polyline(c, PackedVector2Array([a + Vector2(0, -h * 0.2), a + Vector2(side * h * 0.06, 0), a + Vector2(0, h * 0.2)]),
			HomeKit.LIME if side > 0 else HomeKit.GOLD, 2.5)
