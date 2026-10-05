extends Control

## Trace It / Calcá -- learn to draw by tracing: the live camera shows the
## paper, the picture sits on top, the player follows its lines in pencil.
## Single player, no scores: progress is drawings finished.
##
## Built so far (milestone "Free mode"): Home (kit), the Free mode picker
## (gallery, camera photo, built-in drawings), the drawing session (camera +
## overlay with move / pinch / turn, lock, opacity, looks, line colour,
## flips, grid, teaching steps), camera permission screens, the set-up
## tutorial, Done, save / Resume. Coming next: the accuracy check (hooks
## into _on_done), guide levels, courses, lessons, progress, sync.
##
## Parts: trace_it_engine.gd (logic, tested headlessly), trace_it_camera.gd,
## trace_it_overlay.gd, trace_it_art.gd (+ trace_it_drawings.json),
## trace_it_fx.gd (shaders). Pictures never leave the phone: an imported
## photo is kept only as user://trace_it_free_source.png for Resume.

const TraceItEngine = preload("res://scripts/games/trace_it/trace_it_engine.gd")
const Art = preload("res://scripts/games/trace_it/trace_it_art.gd")
const Cam = preload("res://scripts/games/trace_it/trace_it_camera.gd")
const Overlay = preload("res://scripts/games/trace_it/trace_it_overlay.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const HomeKit = preload("res://scripts/games/trace_it/home_kit.gd")
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://trace_it_free.json"
const SOURCE_PATH := "user://trace_it_free_source.png"
const PREFS_PATH := "user://trace_it_prefs.json"
const UNLOCK_HOLD := 0.8   # seconds to hold 🔒 to unlock
const PANEL_BG := Color(0.03, 0.04, 0.08, 0.86)

var info = null
var home
var engine := TraceItEngine.new()
var camera: Cam
var overlay: Overlay
var started := false       # a session began this scene (else _save_game skips)
var session_on := false
var snapping := false
var source: Dictionary = {}
var source_desc: Dictionary = {}   # what Resume rebuilds: {kind, id}
var draw_time := 0.0
var prefs := {"tutorial_seen": false, "steps_on": true, "lessons_on": true, "lessons_seen": []}
var _save_t := -1.0
var _hold_t := -1.0
var _just_unlocked := false
# A photo being prepared on a worker thread (TraceItArt.photo_source).
var _prep_task := -1
var _prep_result: Dictionary = {}
var _prep_desc: Dictionary = {}
var _prep_fresh := true
var busy_card: Control   # the release that ends an unlock hold isn't a tap

var paper: ColorRect           # stands in for the camera when there is none
var session_ui: Control
var title_label: Label
var hint_label: Label
var swap_btn: Button
var tools_panel: PanelContainer
var tools_btn: Button
var lock_btn: Button
var opacity_slider: HSlider
var opacity_label: Label
var look_row: GridContainer
var shade_row: HBoxContainer
var shade_btns := {}
var look_btns := {}
var color_btns: Array = []
var grid_btn: Button
var steps_btn: Button
var steps_bar: PanelContainer
var step_label: Label
var step_tip: Label
var prev_btn: Button
var next_btn: Button
var snap_bar: Control
var picker: Control
var picker_box: VBoxContainer
var picker_drag: Node
var picker_filled := false
var lessons_toggle: Button
var lesson_card: Control
var lesson_title: Label
var lesson_text: Label
var lesson_go: Button
var _lesson_then := ""   # drawing id to open after the lesson ("" = back to the picker)
var steps_toggle: Button
var perm_card: Control
var perm_text: Label
var perm_allow: Button
var perm_settings: Button
var tutorial: Control
var done_card: Control
var confirm_card: Control
var done_text: Label


func _ready() -> void:
	preload("res://scripts/games/trace_it/trace_it_i18n.gd").install(self)
	Orientation.lock_portrait()
	var p = SaveUtil.read(PREFS_PATH)
	if p is Dictionary:
		prefs.merge(p, true)
	engine.steps_on = bool(prefs.steps_on)
	_build_ui()
	camera.choice = int(prefs.get("camera", 0))


func _exit_tree() -> void:
	if _prep_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_prep_task)
		_prep_task = -1
	var s := get_node_or_null("/root/Settings")
	DisplayServer.screen_set_keep_on(bool(s.keep_awake) if s else false)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	paper = ColorRect.new()
	paper.color = Color(0.93, 0.92, 0.88)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.visible = false
	add_child(paper)

	camera = Cam.new()
	camera.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camera.state_changed.connect(_on_camera_state)
	camera.light_changed.connect(_on_light)
	add_child(camera)

	overlay = Overlay.new(engine)
	overlay.changed.connect(_on_overlay_changed)
	add_child(overlay)
	overlay.visible = false

	_build_session_ui()
	_build_snap_bar()
	_build_picker()
	_build_lesson_card()
	_build_permission_card()
	_build_tutorial()
	_build_done_card()
	_build_confirm_card()
	busy_card = Control.new()
	busy_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	busy_card.visible = false
	add_child(busy_card)
	var bdim := ColorRect.new()
	bdim.color = Color(0, 0, 0, 0.75)
	bdim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	busy_card.add_child(bdim)
	var blabel := HomeKit.label(tr("Preparing your picture..."), 30, HomeKit.CYAN, true, true)
	blabel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	blabel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	blabel.grow_vertical = Control.GROW_DIRECTION_BOTH
	busy_card.add_child(blabel)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/trace_it/trace_it_help.gd"))
	home = HomeKit.new({
		"help": preload("res://scripts/games/trace_it/trace_it_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Learn to draw: trace any picture onto paper, step by step.",
		"logo": _draw_home_logo,
		"modes": [{"text": "🖼  Free mode", "sub": "Your photos or our drawings", "action": _open_picker}],
		"save_path": SAVE_PATH,
		"resume": _resume,
		"resume_text": _resume_text,
		"restart": _restart_drawing,
		"board": "none",
		"more": [["📐 Set up the phone", HomeKit.GOLD, _show_tutorial]],
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.42)
	add_child(drawer)


func _draw_home_logo(c: Control) -> void:
	var s := c.size
	var cx := s.x / 2.0
	var h := s.y
	# A sheet of paper with a traced star, and a pencil finishing the line.
	var sheet := Rect2(cx - h * 0.55, h * 0.12, h * 1.1, h * 0.76)
	HomeKit.glow_rect(c, sheet, HomeKit.BLUE, 3.0, 0.08)
	var star := PackedVector2Array()
	var sc := Vector2(cx - h * 0.08, h * 0.5)
	for i in 11:
		var r := h * (0.27 if i % 2 == 0 else 0.11)
		var a := -PI / 2 + PI * i / 5.0
		star.append(sc + Vector2(cos(a), sin(a)) * r)
	HomeKit.glow_polyline(c, star.slice(0, 8), HomeKit.CYAN, 3.0)
	# The rest of the star is still the faint guide.
	for i in range(7, 10):
		c.draw_line(star[i], star[i + 1], Color(HomeKit.CYAN, 0.3), 2.0)
	var tip := star[7]
	var dir := Vector2(1, -1.4).normalized()
	var back := tip + dir * h * 0.5
	var side := dir.orthogonal() * h * 0.045
	HomeKit.glow_polyline(c, PackedVector2Array([tip, tip + dir * h * 0.09 + side, back + side, back - side, tip + dir * h * 0.09 - side, tip]), HomeKit.GOLD, 3.0)
	HomeKit.glow_line(c, tip + dir * h * 0.09 + side, tip + dir * h * 0.09 - side, HomeKit.GOLD, 2.0)


func _panel(bg: Color = PANEL_BG) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	return p


func _btn(text: String, color: Color, cb: Callable, font := 26, h := 68.0) -> Button:
	var b := HomeKit.neon_button(text, color, font, h)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _build_session_ui() -> void:
	session_ui = Control.new()
	session_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	session_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session_ui.visible = false
	add_child(session_ui)

	# Top: pause, what you're drawing, camera swap, Done.
	var top := _panel()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 10
	top.offset_right = -10
	top.offset_top = 10
	session_ui.add_child(top)
	var col := VBoxContainer.new()
	top.add_child(col)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	col.add_child(bar)
	bar.add_child(home_pause_button())
	title_label = HomeKit.label("", 26, HomeKit.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	bar.add_child(title_label)
	swap_btn = _btn("📷", HomeKit.BLUE, _on_swap_camera, 24, 64)
	swap_btn.custom_minimum_size.x = 96
	bar.add_child(swap_btn)
	var done := _btn(tr("✓ Done"), HomeKit.LIME, _on_done, 26, 64)
	done.custom_minimum_size.x = 150
	bar.add_child(done)
	hint_label = HomeKit.label("", 22, HomeKit.GOLD, true, true)
	hint_label.visible = false
	col.add_child(hint_label)

	# Bottom: the steps bar, the tools, and the big lock.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = 10
	bottom.offset_right = -10
	bottom.offset_bottom = -10
	bottom.add_theme_constant_override("separation", 8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session_ui.add_child(bottom)

	steps_bar = _panel()
	bottom.add_child(steps_bar)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 10)
	steps_bar.add_child(srow)
	prev_btn = _btn("◀", HomeKit.PURPLE, _on_prev_step, 30, 72)
	prev_btn.custom_minimum_size.x = 78
	srow.add_child(prev_btn)
	var scol := VBoxContainer.new()
	scol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(scol)
	step_label = HomeKit.label("", 24, HomeKit.PURPLE, false, true)
	scol.add_child(step_label)
	step_tip = HomeKit.label("", 20, HomeKit.WHITE, true, true)
	scol.add_child(step_tip)
	next_btn = _btn("▶", HomeKit.PURPLE, _on_next_step, 30, 72)
	next_btn.custom_minimum_size.x = 78
	srow.add_child(next_btn)

	tools_panel = _panel()
	bottom.add_child(tools_panel)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 10)
	tools_panel.add_child(tcol)
	var orow := HBoxContainer.new()
	orow.add_theme_constant_override("separation", 12)
	tcol.add_child(orow)
	opacity_label = HomeKit.label("", 22, HomeKit.WHITE)
	opacity_label.custom_minimum_size.x = 120
	orow.add_child(opacity_label)
	opacity_slider = HSlider.new()
	opacity_slider.min_value = 0
	opacity_slider.max_value = 100
	opacity_slider.step = 1
	opacity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opacity_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	opacity_slider.custom_minimum_size.y = 48
	opacity_slider.focus_mode = Control.FOCUS_NONE
	opacity_slider.value_changed.connect(_on_opacity)
	orow.add_child(opacity_slider)

	look_row = GridContainer.new()
	look_row.columns = 3
	look_row.add_theme_constant_override("h_separation", 8)
	look_row.add_theme_constant_override("v_separation", 8)
	tcol.add_child(look_row)
	for st in [["photo", "Photo"], ["gray", "Gray"], ["lines", "Lines"], ["invert", "Invert"], ["hatch", "Hatching"], ["dots", "Dots"]]:
		var b := _btn(tr(st[1]), HomeKit.CYAN, _on_look.bind(st[0]), 22, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		look_row.add_child(b)
		look_btns[st[0]] = b

	# The Shading step of a photo: shade with tones, hatching or dots.
	shade_row = HBoxContainer.new()
	shade_row.add_theme_constant_override("separation", 8)
	tcol.add_child(shade_row)
	shade_row.add_child(HomeKit.label(tr("Shade with:"), 22, HomeKit.WHITE))
	for st in [["tones", "Tones"], ["hatch", "Hatching"], ["dots", "Dots"]]:
		var b := _btn(tr(st[1]), HomeKit.PURPLE, _on_shading.bind(st[0]), 22, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shade_row.add_child(b)
		shade_btns[st[0]] = b

	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	tcol.add_child(crow)
	crow.add_child(HomeKit.label(tr("Lines:"), 22, HomeKit.WHITE))
	for i in engine.LINE_COLORS.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(56, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_color.bind(i))
		crow.add_child(b)
		color_btns.append(b)

	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 8)
	tcol.add_child(arow)
	for spec in [["↔", _on_flip_h], ["↕", _on_flip_v], ["⟳90°", _on_turn90], ["⟲", _on_reset_place]]:
		var b := _btn(spec[0], HomeKit.BLUE, spec[1], 24, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arow.add_child(b)
	grid_btn = _btn("", HomeKit.BLUE, _on_grid, 22, 56)
	grid_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arow.add_child(grid_btn)
	steps_btn = _btn("", HomeKit.PURPLE, _on_steps_toggle, 22, 56)
	steps_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.add_child(steps_btn)

	var lpanel := _panel()
	bottom.add_child(lpanel)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	lpanel.add_child(lrow)
	tools_btn = _btn("", HomeKit.CYAN, _on_tools_toggle, 24, 88)
	tools_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lrow.add_child(tools_btn)
	lock_btn = _btn("", HomeKit.GOLD, _on_lock_pressed, 30, 88)
	lock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_btn.set_meta("sfx", "toggle")
	lock_btn.button_down.connect(_on_lock_down)
	lock_btn.button_up.connect(_on_lock_up)
	lock_btn.draw.connect(_draw_lock_progress)
	lrow.add_child(lock_btn)


func home_pause_button() -> Button:
	var b := Button.new()
	b.text = "⏸"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(76, 64)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(func(): home.pause())
	return b


func _build_snap_bar() -> void:
	snap_bar = _panel()
	snap_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	snap_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	snap_bar.offset_left = 10
	snap_bar.offset_right = -10
	snap_bar.offset_bottom = -10
	snap_bar.visible = false
	add_child(snap_bar)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	snap_bar.add_child(col)
	col.add_child(HomeKit.label(tr("Point the camera at the picture you want to trace, then tap 📸."), 22, HomeKit.WHITE, true, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var cancel := _btn(tr("✕ Cancel"), HomeKit.DIM, _cancel_snap, 26, 96)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	var shoot := _btn("📸", HomeKit.LIME, _on_shutter, 44, 96)
	shoot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shoot.set_meta("sfx", "")
	row.add_child(shoot)


func _screen(title: String, color: Color) -> Array:
	# A full-screen page in the game's style: [root, content box].
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var bg := HomeKit.backdrop()
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var drag := HomeKit._DragScroll.new()
	scroll.add_child(drag)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	box.add_child(HomeKit.label(title, 40, color, true, true))
	return [root, box, drag]


func _build_picker() -> void:
	var parts := _screen(tr("🖼 Free mode"), HomeKit.CYAN)
	picker = parts[0]
	picker_box = parts[1]
	picker_drag = parts[2]


## Filled the first time it opens (rendering every thumbnail takes a moment).
func _fill_picker() -> void:
	if picker_filled:
		return
	picker_filled = true
	var box := picker_box
	box.add_child(HomeKit.label(tr("What do you want to draw?"), 24, HomeKit.DIM, true, true))
	box.add_child(_btn(tr("🖼 A photo from my gallery"), HomeKit.CYAN, _pick_gallery, 26, 84))
	box.add_child(_btn(tr("📷 Take a photo with the camera"), HomeKit.BLUE, _start_snap, 26, 84))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	steps_toggle = _btn("", HomeKit.PURPLE, _on_picker_steps, 22, 70)
	steps_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(steps_toggle)
	lessons_toggle = _btn("", HomeKit.GOLD, _on_lessons_toggle, 22, 70)
	lessons_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lessons_toggle)
	box.add_child(HomeKit.label(tr("Or trace one of our drawings"), 26, HomeKit.WHITE, true, true))
	for c in Art.collections():
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		box.add_child(head)
		var study := HomeKit.label("%s %s" % [c.get("icon", ""), Art.text(c, "title")], 28, HomeKit.CYAN)
		study.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		study.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_child(study)
		var lb := _btn(tr("📖 Lesson"), HomeKit.GOLD, _on_lesson_button.bind(str(c.get("id", ""))), 22, 60)
		lb.custom_minimum_size.x = 170
		head.add_child(lb)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 16)
		box.add_child(grid)
		for id in c.get("drawings", []):
			var d := Art.find(str(id))
			if not d.is_empty():
				grid.add_child(_drawing_button(d, str(c.get("id", ""))))
	box.add_child(HomeKit.label(tr("Your pictures never leave your phone."), 20, HomeKit.DIM, true, true))
	box.add_child(_btn(tr("Back"), HomeKit.DIM, _close_picker, 24, 64))


func _drawing_button(d: Dictionary, study: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 260)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HomeKit.style_button(b, HomeKit.CYAN)
	b.pressed.connect(_pick_drawing.bind(str(d.get("id", "")), study))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 10
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var thumb := TextureRect.new()
	thumb.texture = ImageTexture.create_from_image(Art.render(d, -1, 200, 4.0))
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(thumb)
	var cap := HomeKit.label(Art.text(d, "title"), 20, HomeKit.WHITE, true, true)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cap)
	return b


func _build_lesson_card() -> void:
	var parts := _screen("", HomeKit.GOLD)
	lesson_card = parts[0]
	var box: VBoxContainer = parts[1]
	lesson_title = box.get_child(0)
	lesson_text = HomeKit.label("", 25, HomeKit.WHITE, true)
	box.add_child(lesson_text)
	lesson_go = _btn(tr("✏ Draw it"), HomeKit.LIME, _on_lesson_go, 28, 84)
	box.add_child(lesson_go)
	box.add_child(_btn(tr("Back"), HomeKit.DIM, _close_lesson, 24, 64))


func _build_permission_card() -> void:
	perm_card = Control.new()
	perm_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	perm_card.visible = false
	add_child(perm_card)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	perm_card.add_child(dim)
	var p := _panel(Color(0.05, 0.07, 0.13, 0.98))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(600, 0)
	perm_card.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	p.add_child(col)
	col.add_child(HomeKit.label(tr("📷 Camera"), 36, HomeKit.CYAN, false, true))
	perm_text = HomeKit.label("", 24, HomeKit.WHITE, true, true)
	col.add_child(perm_text)
	perm_allow = _btn(tr("Allow the camera"), HomeKit.LIME, _on_allow_camera, 26, 80)
	col.add_child(perm_allow)
	perm_settings = _btn(tr("Open settings"), HomeKit.GOLD, _on_open_settings, 26, 80)
	col.add_child(perm_settings)
	col.add_child(_btn(tr("Draw without the camera"), HomeKit.DIM, _on_no_camera, 22, 64))


func _build_tutorial() -> void:
	var parts := _screen(tr("📐 Set up the phone"), HomeKit.GOLD)
	tutorial = parts[0]
	var box: VBoxContainer = parts[1]
	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 300)
	art.draw.connect(_draw_setup.bind(art))
	box.add_child(art)
	for line in [
		tr("1. Prop the phone 25-35 cm above the paper, camera facing down: on a stack of books, across two glasses, or on a phone stand."),
		tr("2. Use good, even light. Put the lamp on the side away from your drawing hand, so your hand's shadow doesn't fall on the lines."),
		tr("3. Move the picture where you want it on the paper, then tap 🔒 Lock so your hand can't move it."),
		tr("4. Draw lightly first. Watch the screen to see the picture and your pencil together."),
	]:
		box.add_child(HomeKit.label(line, 24, HomeKit.WHITE, true))
	box.add_child(_btn(tr("Got it"), HomeKit.LIME, _close_tutorial, 28, 84))


## The phone held over the paper on a stack of books, camera looking down.
func _draw_setup(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	var cx := w / 2.0
	var table := h * 0.9
	HomeKit.glow_line(c, Vector2(cx - w * 0.42, table), Vector2(cx + w * 0.42, table), HomeKit.DIM, 2.0)
	# Paper and pencil.
	HomeKit.glow_line(c, Vector2(cx - w * 0.2, table - 4), Vector2(cx + w * 0.16, table - 4), HomeKit.WHITE, 3.0)
	HomeKit.glow_line(c, Vector2(cx + w * 0.05, table - 8), Vector2(cx + w * 0.12, table - h * 0.2), HomeKit.GOLD, 3.0)
	# Books.
	for i in 3:
		var y := table - (i + 1) * h * 0.11
		HomeKit.glow_rect(c, Rect2(cx - w * 0.4, y, w * 0.16, h * 0.1), [HomeKit.PINK, HomeKit.PURPLE, HomeKit.BLUE][i], 2.0, 0.15)
	# Phone lying across the books, reaching over the paper.
	var top := table - h * 0.36
	HomeKit.glow_rect(c, Rect2(cx - w * 0.28, top - h * 0.05, w * 0.5, h * 0.05), HomeKit.CYAN, 3.0, 0.2)
	var lens := Vector2(cx, top)
	HomeKit.glow_circle(c, lens + Vector2(0, 4), 6.0, HomeKit.LIME, 2.0)
	# What the camera sees.
	var cone := Color(HomeKit.LIME, 0.35)
	c.draw_line(lens + Vector2(0, 8), Vector2(cx - w * 0.18, table - 6), cone, 2.0)
	c.draw_line(lens + Vector2(0, 8), Vector2(cx + w * 0.14, table - 6), cone, 2.0)
	var mid := Vector2(cx + w * 0.3, (top + table) / 2.0)
	HomeKit.glow_text(c, mid, tr("25-35 cm"), 24, HomeKit.GOLD)
	HomeKit.glow_line(c, Vector2(cx + w * 0.24, top + 4), Vector2(cx + w * 0.24, table - 6), Color(HomeKit.GOLD, 0.7), 2.0)


func _build_done_card() -> void:
	var parts := _screen(tr("✓ Drawing finished!"), HomeKit.LIME)
	done_card = parts[0]
	var box: VBoxContainer = parts[1]
	done_text = HomeKit.label("", 26, HomeKit.WHITE, true, true)
	box.add_child(done_text)
	box.add_child(_btn(tr("🖼 Draw another"), HomeKit.CYAN, _on_draw_another, 28, 84))
	box.add_child(_btn(tr("🏠 Home"), HomeKit.DIM, _on_done_home, 26, 72))


func _build_confirm_card() -> void:
	confirm_card = Control.new()
	confirm_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_card.visible = false
	add_child(confirm_card)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_card.add_child(dim)
	var p := _panel(Color(0.05, 0.07, 0.13, 0.98))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(560, 0)
	confirm_card.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	p.add_child(col)
	col.add_child(HomeKit.label(tr("Is your drawing finished?"), 30, HomeKit.LIME, true, true))
	var yes := _btn(tr("✓ Yes, finished"), HomeKit.LIME, _on_done_confirmed, 26, 80)
	yes.set_meta("sfx", "")
	col.add_child(yes)
	col.add_child(_btn(tr("✏ Keep drawing"), HomeKit.DIM, func(): confirm_card.visible = false, 24, 70))


# ---------------------------------------------------------------- picker

func _open_picker() -> void:
	_fill_picker()
	_refresh_picker()
	picker.visible = true


func _close_picker() -> void:
	picker.visible = false
	if not session_on:
		home.show_home()


func _refresh_picker() -> void:
	steps_toggle.text = tr("🪜 Step by step: ON") if engine.steps_on else tr("🪜 Step by step: OFF")
	lessons_toggle.text = tr("📖 Lessons: ON") if prefs.lessons_on else tr("📖 Lessons: OFF")


## Lessons are a teaching option: when on, a study's lesson shows the first
## time one of its drawings is picked. 📖 always opens it.
func _on_lessons_toggle() -> void:
	prefs["lessons_on"] = not bool(prefs.lessons_on)
	SaveUtil.write(PREFS_PATH, prefs)
	_refresh_picker()


func _on_lesson_button(study: String) -> void:
	if picker_drag.moved:
		return
	_show_lesson(study, "")


func _show_lesson(study: String, then_draw: String) -> void:
	var c := _collection(study)
	if c.is_empty():
		return
	lesson_title.text = "%s %s" % [c.get("icon", ""), Art.text(c, "title")]
	var paras: Array = c.get("lesson_es", []) if Art.spanish() and c.has("lesson_es") else c.get("lesson", [])
	lesson_text.text = "\n\n".join(PackedStringArray(paras))
	_lesson_then = then_draw
	lesson_go.visible = then_draw != ""
	var seen: Array = prefs.get("lessons_seen", [])
	if not seen.has(study):
		seen.append(study)
		prefs["lessons_seen"] = seen
		SaveUtil.write(PREFS_PATH, prefs)
	lesson_card.visible = true


func _close_lesson() -> void:
	lesson_card.visible = false


func _on_lesson_go() -> void:
	lesson_card.visible = false
	var d := Art.find(_lesson_then)
	if not d.is_empty():
		_begin(Art.drawing_source(d), {"kind": "drawing", "id": _lesson_then}, true)


static func _collection(id: String) -> Dictionary:
	for c in Art.collections():
		if c.get("id") == id:
			return c
	return {}


func _on_picker_steps() -> void:
	engine.steps_on = not engine.steps_on
	prefs["steps_on"] = engine.steps_on
	SaveUtil.write(PREFS_PATH, prefs)
	_refresh_picker()


func _pick_drawing(id: String, study: String = "") -> void:
	if picker_drag and picker_drag.moved:
		return   # the release that ended a scroll, not a tap
	var d := Art.find(id)
	if d.is_empty():
		return
	if bool(prefs.lessons_on) and study != "" and not prefs.get("lessons_seen", []).has(study):
		_show_lesson(study, id)
		return
	_begin(Art.drawing_source(d), {"kind": "drawing", "id": id}, true)


func _pick_gallery() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		_toast(tr("This phone can't open the gallery from here. Try 📷 Take a photo."))
		return
	DisplayServer.file_dialog_show(tr("Pick a picture"), "", "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
			PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp;Images;image/*"]), _on_file_picked)


func _on_file_picked(ok: bool, paths: PackedStringArray, _filter: int) -> void:
	if not ok or paths.is_empty():
		return
	var img := load_picture(paths[0])
	if img == null:
		_toast(tr("Couldn't open that picture. Try a JPG or PNG."))
		return
	_begin_photo(img)


## A picture from a path or an Android content:// URI.
static func load_picture(path: String) -> Image:
	var img := Image.new()
	if img.load(path) == OK and not img.is_empty():
		return img
	var buf := FileAccess.get_file_as_bytes(path)
	if buf.is_empty():
		return null
	for fn in [img.load_jpg_from_buffer, img.load_png_from_buffer, img.load_webp_from_buffer]:
		if fn.call(buf) == OK and not img.is_empty():
			return img
	return null


func _begin_photo(img: Image) -> void:
	_prepare_photo(img, {"kind": "photo"}, true)


## Finds the photo's lines on a worker thread (~0.5-1.5 s on a phone);
## _process picks the result up and starts the session.
func _prepare_photo(img: Image, desc: Dictionary, fresh: bool) -> void:
	if _prep_task >= 0:
		return
	picker.visible = false
	busy_card.visible = true
	_prep_desc = desc
	_prep_fresh = fresh
	_prep_result = {}
	_prep_task = WorkerThreadPool.add_task(_prep_job.bind(img), false, "trace_it photo")


func _prep_job(img: Image) -> void:
	_prep_result = Art.photo_source(img)


func _prep_done() -> void:
	WorkerThreadPool.wait_for_task_completion(_prep_task)
	_prep_task = -1
	busy_card.visible = false
	var s := _prep_result
	if s.is_empty():
		_toast(tr("Couldn't open that picture. Try a JPG or PNG."))
		_open_picker()
		return
	Art.name_photo_steps(s)
	if _prep_fresh:
		s.full.save_png(SOURCE_PATH)   # only for Resume; stays on the phone
	_begin(s, _prep_desc, _prep_fresh)


func _start_snap() -> void:
	picker.visible = false
	snapping = true
	session_ui.visible = false
	overlay.visible = false
	snap_bar.visible = true
	camera.start()


func _cancel_snap() -> void:
	snapping = false
	snap_bar.visible = false
	if not session_on:
		camera.stop()
		_open_picker()
	else:
		_show_session()


func _on_shutter() -> void:
	if camera.state != "running":
		_toast(tr("The camera isn't ready yet."))
		return
	_sfx("tick")
	var img: Image = await camera.snapshot()
	if not is_instance_valid(self) or not snapping:
		return
	if img == null:
		_toast(tr("Couldn't take the photo. Try again."))
		return
	snapping = false
	snap_bar.visible = false
	_begin_photo(img)


# ---------------------------------------------------------------- session

## `fresh`: a new drawing (placement and steps start over). Resume passes
## false and has already loaded the engine.
func _begin(s: Dictionary, desc: Dictionary, fresh: bool) -> void:
	source = s
	source_desc = desc
	if fresh:
		_reset_place()
		engine.locked = false
		engine.step = 0
		draw_time = 0.0
		if desc.kind == "drawing":
			engine.style = "lines"
		elif info:
			info.add("Photos traced")
	picker.visible = false
	lesson_card.visible = false
	started = true
	session_on = true
	overlay.set_source(s)
	_show_session()
	if camera.state != "running":
		camera.start()
	DisplayServer.screen_set_keep_on(true)
	_save_game()
	if not prefs.tutorial_seen:
		_show_tutorial()


func _show_session() -> void:
	session_ui.visible = true
	overlay.visible = true
	_refresh_session()


func _refresh_session() -> void:
	overlay.refresh()
	var locked := engine.locked
	var drawing: bool = source.get("kind") == "drawing"
	var what: String = source.get("title", "")
	title_label.text = what if what != "" else tr("Your picture")
	swap_btn.visible = camera.camera_count() > 1 and not locked
	swap_btn.text = camera.camera_label()
	tools_panel.visible = not locked and bool(prefs.get("tools_open", false))
	tools_btn.visible = not locked
	tools_btn.text = tr("🛠 Hide tools") if tools_panel.visible else tr("🛠 Tools")
	lock_btn.text = tr("🔒 Hold to unlock") if locked else tr("🔓 Lock")
	opacity_slider.set_value_no_signal(round(engine.opacity * 100))
	opacity_label.text = tr("👁 %d%%") % int(round(engine.opacity * 100))
	look_row.visible = not drawing and not engine.steps_on
	for k in look_btns:
		HomeKit.style_button(look_btns[k], HomeKit.LIME if k == engine.style else HomeKit.CYAN)
	shade_row.visible = not drawing and engine.steps_on
	for k in shade_btns:
		HomeKit.style_button(shade_btns[k], HomeKit.LIME if k == engine.shading else HomeKit.PURPLE)
	for i in color_btns.size():
		var c: Color = engine.LINE_COLORS[i]
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(5 if i == engine.line_color else 2)
		sb.border_color = HomeKit.LIME if i == engine.line_color else Color(0.5, 0.5, 0.6)
		for st in ["normal", "hover", "pressed"]:
			color_btns[i].add_theme_stylebox_override(st, sb)
	if engine.grid == 0:
		grid_btn.text = tr("# Guides")
	elif engine.grid == TraceItEngine.GOLDEN_GRID:
		grid_btn.text = "# φ"
	elif engine.grid == TraceItEngine.GOLDEN_SPIRAL:
		grid_btn.text = "# 🌀"
	else:
		grid_btn.text = "# %d×%d" % [engine.grid, engine.grid]
	steps_btn.text = tr("🪜 Step by step: ON") if engine.steps_on else tr("🪜 Step by step: OFF")
	steps_bar.visible = engine.steps_on
	if engine.steps_on:
		var defs: Array = source.get("steps", [])
		var cur: Dictionary = defs[engine.step] if engine.step < defs.size() else {}
		step_label.text = tr("Step %d of %d: %s") % [engine.step + 1, engine.step_count, str(cur.get("name", ""))]
		step_tip.text = str(cur.get("tip", ""))
		prev_btn.disabled = engine.step == 0
		next_btn.text = "▶" if engine.step < engine.step_count - 1 else "✓"


func _on_overlay_changed() -> void:
	_save_t = 1.0


func _process(delta: float) -> void:
	if _prep_task >= 0 and WorkerThreadPool.is_task_completed(_prep_task):
		_prep_done()
	if session_on and not snapping and not done_card.visible and not confirm_card.visible:
		draw_time += delta
	if _save_t > 0:
		_save_t -= delta
		if _save_t <= 0:
			_save_game()
	if _hold_t >= 0:
		_hold_t += delta
		lock_btn.queue_redraw()
		if _hold_t >= UNLOCK_HOLD:
			_hold_t = -1.0
			engine.locked = false
			_just_unlocked = true
			_sfx("toggle")
			_refresh_session()
			_save_game()


# ---------------------------------------------------------------- tools

func _on_opacity(v: float) -> void:
	engine.opacity = v / 100.0
	_refresh_session()
	_save_t = 1.0


func _on_look(style: String) -> void:
	engine.style = style
	_refresh_session()
	_save_t = 0.5


func _on_color(i: int) -> void:
	engine.line_color = i
	_refresh_session()
	_save_t = 0.5


func _on_shading(technique: String) -> void:
	engine.shading = technique
	_refresh_session()
	_save_t = 0.5


func _on_flip_h() -> void:
	engine.flip_h = not engine.flip_h
	_refresh_session()
	_save_t = 0.5


func _on_flip_v() -> void:
	engine.flip_v = not engine.flip_v
	_refresh_session()
	_save_t = 0.5


func _on_turn90() -> void:
	engine.turn_by(PI / 2.0)
	_refresh_session()
	_save_t = 0.5


func _on_reset_place() -> void:
	_reset_place()
	_refresh_session()
	_save_t = 0.5


## Back to the start: fitted, a little above the middle (clear of the bars).
func _reset_place() -> void:
	engine.reset_placement()
	engine.offset = Vector2(0, -size.y * 0.04)


func _on_grid() -> void:
	engine.next_grid()
	_refresh_session()
	_save_t = 0.5


func _on_steps_toggle() -> void:
	engine.steps_on = not engine.steps_on
	prefs["steps_on"] = engine.steps_on
	SaveUtil.write(PREFS_PATH, prefs)
	_refresh_session()
	_save_t = 0.5


func _on_tools_toggle() -> void:
	prefs["tools_open"] = not bool(prefs.get("tools_open", false))
	SaveUtil.write(PREFS_PATH, prefs)
	_refresh_session()


func _on_prev_step() -> void:
	engine.set_step(engine.step - 1)
	_refresh_session()
	_save_t = 0.5


func _on_next_step() -> void:
	if engine.step >= engine.step_count - 1:
		_on_done()
		return
	engine.set_step(engine.step + 1)
	_sfx("tick")
	_refresh_session()
	_save_t = 0.5


## Steps through every camera. A picture that "breathes" is the camera
## refocusing; another back camera (often the wide one) may have fixed focus.
func _on_swap_camera() -> void:
	camera.next_camera()
	prefs["camera"] = camera.choice
	SaveUtil.write(PREFS_PATH, prefs)


# Lock: one tap locks; unlocking needs a hold, so a hand brushing the
# screen while drawing can't unlock it.
func _on_lock_pressed() -> void:
	if engine.locked or _just_unlocked:
		_just_unlocked = false
		return
	engine.locked = true
	_refresh_session()
	_save_game()


func _on_lock_down() -> void:
	_just_unlocked = false
	if engine.locked:
		_hold_t = 0.0


func _on_lock_up() -> void:
	_hold_t = -1.0
	lock_btn.queue_redraw()


func _draw_lock_progress() -> void:
	if _hold_t <= 0:
		return
	var r := Rect2(Vector2.ZERO, lock_btn.size)
	var k := clampf(_hold_t / UNLOCK_HOLD, 0.0, 1.0)
	lock_btn.draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), Color(HomeKit.GOLD, 0.35))


# ---------------------------------------------------------------- camera

func _on_camera_state(state: String) -> void:
	match state:
		"running":
			perm_card.visible = false
			paper.visible = false
			if not hint_label.text.begins_with("💡"):
				hint_label.visible = false
		"need_permission", "denied":
			_show_permission(state == "denied")
		"no_camera":
			paper.visible = not snapping
			hint_label.text = tr("No camera found: the picture still works, on a blank page.")
			hint_label.visible = true
			if snapping:
				_toast(tr("No camera found."))
				_cancel_snap()
	if session_on:
		_refresh_session()
	elif snapping:
		swap_btn.text = camera.camera_label()


func _show_permission(denied: bool) -> void:
	var why := tr("Trace It shows your paper through the camera, with the picture on top, so you can follow its lines. Nothing is recorded or sent: the camera image stays on your phone.")
	if denied:
		why += "\n\n" + tr("The camera is off for this app. Turn it on in Settings > Permissions > Camera.")
	perm_text.text = why
	perm_allow.text = tr("Try again") if denied else tr("Allow the camera")
	perm_settings.visible = denied and Engine.has_singleton("AndroidRuntime")
	perm_card.visible = true


func _on_allow_camera() -> void:
	camera.request_permission()


func _on_open_settings() -> void:
	Cam.open_app_settings()


func _on_no_camera() -> void:
	perm_card.visible = false
	paper.visible = true
	if snapping:
		_cancel_snap()


func _on_light(dark: bool) -> void:
	if dark:
		hint_label.text = tr("💡 More light, please: in the dark the camera slows down.")
		hint_label.visible = true
	elif hint_label.text.begins_with("💡"):
		hint_label.visible = false


# ---------------------------------------------------------------- tutorial

func _show_tutorial() -> void:
	tutorial.visible = true
	if home.is_home_visible():
		home.hide_home()


func _close_tutorial() -> void:
	tutorial.visible = false
	if not prefs.tutorial_seen:
		prefs["tutorial_seen"] = true
		SaveUtil.write(PREFS_PATH, prefs)
	if not session_on and not picker.visible:
		home.show_home()


# ---------------------------------------------------------------- done

func _on_done() -> void:
	confirm_card.visible = true


## Where the accuracy check will come in (next milestone).
func _on_done_confirmed() -> void:
	confirm_card.visible = false
	_sfx("win")
	var secs := int(draw_time)
	if info:
		info.add("Drawings finished")
		info.add("Time drawing", secs)
	done_text.text = tr("Well done! You drew for %d:%02d.") % [secs / 60, secs % 60] + "\n\n" + tr("Each drawing makes the next one easier. Try the same picture with less opacity, or with Step by step.")
	done_card.visible = true
	session_on = false
	SaveUtil.delete(SAVE_PATH)
	SaveUtil.delete(SOURCE_PATH)


func _on_draw_another() -> void:
	done_card.visible = false
	session_ui.visible = false
	overlay.visible = false
	_open_picker()


func _on_done_home() -> void:
	home.go_home()


func _restart_drawing() -> void:
	if source.is_empty():
		return
	engine.set_step(0)
	draw_time = 0.0
	_refresh_session()


# ---------------------------------------------------------------- save

func _save_game() -> void:
	if not started or not session_on or source_desc.is_empty():
		return
	SaveUtil.write(SAVE_PATH, {
		"source": source_desc, "engine": engine.to_dict(),
		"time": draw_time,
	})


## Resume's detail on Home: what was being drawn.
func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary):
		return ""
	var desc: Dictionary = d.get("source", {})
	if desc.get("kind") == "drawing":
		return Art.text(Art.find(str(desc.get("id", ""))), "title")
	return tr("Your picture")


func _resume() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary):
		_open_picker()
		return
	var desc: Dictionary = d.get("source", {})
	var s := {}
	if desc.get("kind") == "drawing":
		var dd := Art.find(str(desc.get("id", "")))
		if not dd.is_empty():
			s = Art.drawing_source(dd)
	elif desc.get("kind") == "photo":
		var img := Image.load_from_file(SOURCE_PATH) if FileAccess.file_exists(SOURCE_PATH) else null
		if img:
			engine.from_dict(d.get("engine", {}))
			draw_time = float(d.get("time", 0.0))
			_prepare_photo(img, desc, false)
			return
	if s.is_empty():
		SaveUtil.delete(SAVE_PATH)
		_open_picker()
		return
	engine.from_dict(d.get("engine", {}))
	draw_time = float(d.get("time", 0.0))
	_begin(s, desc, false)


# ---------------------------------------------------------------- misc

func _toast(text: String) -> void:
	var l := HomeKit.label(text, 24, HomeKit.WHITE, true, true)
	var p := _panel(Color(0.08, 0.05, 0.12, 0.95))
	p.add_child(l)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_bottom = -260
	p.custom_minimum_size.x = 560
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	move_child(p, home.get_index())
	var tw := p.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _sfx(key: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(key)
