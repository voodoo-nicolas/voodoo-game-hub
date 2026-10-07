extends Control

## Sketch It: a drawing-and-guessing party game for teams sharing one phone.
## The artist sees a secret word, draws it, and their team shouts guesses
## before the clock runs out. No letters, no numbers -- just drawing.

const SketchEngine = preload("res://scripts/games/sketch_it/sketch_it_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/sketch_it/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/sketch_it/sketch_it_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://sketch_it_save.json"

const WORD_LEVELS := ["Easy words", "Hard words", "Mixed"]
const TIMES := [45, 60, 90]
const TARGET := 5
const TEAM_COLORS := [Color("29e6ff"), Color("ff2bd6"), Color("7dff3a"), Color("ffae2b")]
const INKS := [Color(0.95, 0.97, 1.0), Color("29e6ff"), Color("ff2bd6"), Color("7dff3a"), Color("ffae2b"), Color("ff3b3b")]
## Classic skin: marker colours on a whiteboard, one per INKS entry.
const CLASSIC_INKS := [Color("1d2433"), Color("1e5bd8"), Color("8e2fb0"), Color("1f8a3a"), Color("e8710a"), Color("d62828")]
const WIDTHS := [6.0, 16.0]

var bg: ColorRect
var skin: String = "classic"
var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var word_level: int = 0
var time_pick: int = 1
var teams: int = 2
var started := false
var phase := "idle"  # idle, handoff, word, drawing, reveal, over
var time_left: float = 0.0
var swaps_left: int = 1
var strokes: Array = []  # [{"c": Color, "w": float, "p": PackedVector2Array}]
var ink: int = 0
var width_i: int = 0
var drawing_stroke := false

var canvas: Control
var team_label: Label
var timer_label: Label
var peek_btn: Button
var tools_box: Control
var ink_buttons: Array = []
var width_btn: Button
var card: ColorRect
var card_title: Label
var card_word: Label
var card_note: Label
var card_buttons: VBoxContainer
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/sketch_it/sketch_it_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = SketchEngine.new()
	engine.load_words()
	_build_ui()
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _lang() -> String:
	return "es" if TranslationServer.get_locale().begins_with("es") else "en"

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop() as ColorRect
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
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	timer_label = Label.new()
	timer_label.custom_minimum_size = Vector2(96, 64)
	timer_label.add_theme_font_size_override("font_size", 36)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(timer_label)
	team_label = Label.new()
	team_label.add_theme_font_size_override("font_size", 28)
	team_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	team_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(team_label)

	var cm := MarginContainer.new()
	cm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cm.add_theme_constant_override("margin_left", 16)
	cm.add_theme_constant_override("margin_right", 16)
	root.add_child(cm)
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.clip_contents = true
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_on_canvas_input)
	cm.add_child(canvas)

	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 16)
	tm.add_theme_constant_override("margin_right", 16)
	tm.add_theme_constant_override("margin_bottom", 30)
	root.add_child(tm)
	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	tm.add_child(tools)
	tools_box = tools

	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", 8)
	tools.add_child(row1)
	for i in INKS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(56, 56)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("sfx", "toggle")
		b.pressed.connect(_pick_ink.bind(i))
		row1.add_child(b)
		ink_buttons.append(b)
	width_btn = Button.new()
	width_btn.custom_minimum_size = Vector2(64, 56)
	width_btn.focus_mode = Control.FOCUS_NONE
	width_btn.pressed.connect(_toggle_width)
	row1.add_child(width_btn)

	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 8)
	tools.add_child(row2)
	var undo := Button.new()
	undo.text = "↶"
	undo.custom_minimum_size = Vector2(72, 60)
	undo.pressed.connect(_undo)
	row2.add_child(undo)
	var clear := Button.new()
	clear.text = "🗑"
	clear.custom_minimum_size = Vector2(72, 60)
	clear.pressed.connect(_clear)
	row2.add_child(clear)
	peek_btn = Button.new()
	peek_btn.text = tr("👁 Word")
	peek_btn.custom_minimum_size = Vector2(150, 60)
	peek_btn.button_down.connect(_peek.bind(true))
	peek_btn.button_up.connect(_peek.bind(false))
	row2.add_child(peek_btn)

	var row3 := HBoxContainer.new()
	row3.alignment = BoxContainer.ALIGNMENT_CENTER
	row3.add_theme_constant_override("separation", 12)
	tools.add_child(row3)
	var got := Button.new()
	got.text = tr("✔ Guessed it!")
	got.custom_minimum_size = Vector2(250, 72)
	got.add_theme_font_size_override("font_size", 28)
	_tint(got, HomeKit.LIME)
	got.set_meta("sfx", "")
	got.pressed.connect(_on_guessed)
	row3.add_child(got)
	var give := Button.new()
	give.text = tr("✖ Give up")
	give.custom_minimum_size = Vector2(190, 72)
	give.pressed.connect(_on_give_up)
	_tint(give, HomeKit.PINK)
	row3.add_child(give)

	_build_card()
	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for n in [2, 3, 4]:
		modes.append({"text": tr("%d teams") % n, "row": "teams", "multi": true,
			"color": TEAM_COLORS[n - 2], "action": _new_game.bind(n)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.MAGENTA,
		"subtitle": "Draw the secret word. Your team shouts guesses before time runs out.",
		"logo": _draw_home_logo,
		"modes": modes,
		"multi_heading": "Teams on one phone",
		"extra": _add_options,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Drawings guessed",
		"board_note": "Drawings your team guessed, all time.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.06)  # beside the timer, off the canvas
	add_child(drawer)
	_refresh_tools()

func _build_card() -> void:
	card = ColorRect.new()
	card.color = Color(0.01, 0.01, 0.04, 0.96)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.visible = false
	add_child(card)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.custom_minimum_size = Vector2(560, 0)
	center.add_child(box)
	card_title = Label.new()
	card_title.add_theme_font_size_override("font_size", 34)
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(card_title)
	card_word = Label.new()
	card_word.add_theme_font_size_override("font_size", 64)
	card_word.add_theme_color_override("font_color", Color.WHITE)
	card_word.add_theme_constant_override("outline_size", 12)
	card_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_word.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(card_word)
	card_note = Label.new()
	card_note.add_theme_font_size_override("font_size", 24)
	card_note.add_theme_color_override("font_color", HomeKit.DIM)
	card_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(card_note)
	card_buttons = VBoxContainer.new()
	card_buttons.add_theme_constant_override("separation", 14)
	box.add_child(card_buttons)

func _show_card(title: String, word: String, note: String, color: Color, buttons: Array) -> void:
	card_title.text = title
	card_title.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.3))
	card_word.text = word
	card_word.visible = word != ""
	card_word.add_theme_color_override("font_outline_color", Color(color, 0.45))
	card_note.text = note
	card_note.visible = note != ""
	for c in card_buttons.get_children():
		c.queue_free()
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(0, 84)
		btn.add_theme_font_size_override("font_size", 30)
		btn.pressed.connect(b[1])
		card_buttons.add_child(btn)
	card.visible = true

func _add_options(box: VBoxContainer) -> void:
	box.add_child(home.section("Words"))
	box.add_child(home.choice_row(WORD_LEVELS, word_level, func(i): word_level = i, HomeKit.PURPLE))
	box.add_child(home.section("Time to draw"))
	var names: Array = []
	for t in TIMES:
		names.append(tr("%d seconds") % t)
	box.add_child(home.choice_row(names, time_pick, func(i): time_pick = i, HomeKit.CYAN))

# ---------- game flow ----------

func _new_game(n: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	teams = n
	engine.new_game(n, TARGET, word_level, _lang(), rng)
	started = true
	end_dialog.visible = false
	_handoff()

func _restart() -> void:
	_new_game(teams)

func _team_name(i: int) -> String:
	return tr("Team %d") % (i + 1)

func _scores_text() -> String:
	var parts: Array = []
	for i in engine.scores.size():
		parts.append("%s: %d" % [_team_name(i), engine.scores[i]])
	return "   ·   ".join(parts)

func _handoff() -> void:
	phase = "handoff"
	strokes.clear()
	canvas.queue_redraw()
	swaps_left = 1
	var t: int = engine.turn
	_show_card(tr("%s, your turn!") % _team_name(t), "",
		tr("Pass the phone to your artist. Everyone else, no peeking!") + "\n\n" + _scores_text(),
		TEAM_COLORS[t], [[tr("🎨 I'm the artist — show the word"), _show_word]])
	_refresh_tools()

func _show_word() -> void:
	phase = "word"
	if engine.word == "" or swaps_left == 1:
		engine.next_word(rng)
	var buttons := [[tr("✏️ Start drawing"), _start_drawing]]
	if swaps_left > 0:
		buttons.append([tr("↻ Another word"), _swap_word])
	_show_card(tr("Draw this:"), engine.word.to_upper(), tr("No letters or numbers! You have %d seconds.") % TIMES[time_pick],
		TEAM_COLORS[engine.turn], buttons)

func _swap_word() -> void:
	swaps_left = 0
	engine.next_word(rng)
	_show_word()

func _start_drawing() -> void:
	phase = "drawing"
	card.visible = false
	time_left = TIMES[time_pick]
	strokes.clear()
	canvas.queue_redraw()
	_refresh_tools()
	_sfx("whoosh")

func _process(delta: float) -> void:
	if phase != "drawing":
		return
	var before := int(ceil(time_left))
	time_left -= delta
	var now := int(ceil(time_left))
	if now != before:
		if now <= 5 and now > 0:
			_sfx("tick")
		_refresh_tools()
	if time_left <= 0.0:
		_end_turn(false)

func _on_guessed() -> void:
	if phase == "drawing":
		_end_turn(true)

func _on_give_up() -> void:
	if phase == "drawing":
		_end_turn(false)

func _end_turn(got_it: bool) -> void:
	var team: int = engine.turn
	var took: float = TIMES[time_pick] - time_left
	phase = "reveal"
	if got_it:
		engine.guessed()
		_sfx("letter_right")
		if info:
			info.add("Drawings guessed")
			info.low("Fastest guess time", int(ceil(took)))
	else:
		engine.missed()
		_sfx("buzzer")
	_refresh_tools()
	var win: int = engine.winner()
	if win >= 0:
		_game_over(win)
		return
	var title: String
	if got_it:
		title = tr("Got it in %d seconds!") % int(ceil(took))
	elif time_left <= 0.0:
		title = tr("Time's up! The word was:")
	else:
		title = tr("Too hard? The word was:")
	_show_card(title, engine.word.to_upper(), _scores_text(), TEAM_COLORS[team], [[tr("Next team ▶"), _handoff]])

func _game_over(win: int) -> void:
	phase = "over"
	card.visible = false
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("%s wins!") % _team_name(win) + "\n" + _scores_text()
	if info:
		info.add("Games played")
		info.celebrate(tr("%s wins!") % _team_name(win))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- drawing ----------

func _on_canvas_input(event: InputEvent) -> void:
	if phase != "drawing":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drawing_stroke = true
			strokes.append({"c": INKS[ink], "w": WIDTHS[width_i], "p": PackedVector2Array([event.position])})
		else:
			drawing_stroke = false
		canvas.queue_redraw()
	elif event is InputEventMouseMotion and drawing_stroke and not strokes.is_empty():
		var pts: PackedVector2Array = strokes[-1].p
		if pts.is_empty() or pts[-1].distance_to(event.position) >= 3.0:
			pts.append(event.position)
			strokes[-1].p = pts
			canvas.queue_redraw()

func _draw_canvas() -> void:
	var r := Rect2(Vector2.ZERO, canvas.size)
	var classic := skin == "classic"
	if classic:
		canvas.draw_rect(r, Color.WHITE)
		canvas.draw_rect(r.grow(-3), TEAM_COLORS[engine.turn % TEAM_COLORS.size()].darkened(0.35), false, 6.0)
	else:
		canvas.draw_rect(r, Color(0.02, 0.03, 0.07))
		HomeKit.glow_rect(canvas, r.grow(-2), Color(TEAM_COLORS[engine.turn % TEAM_COLORS.size()], 0.7), 2.0)
	for s in strokes:
		var pts: PackedVector2Array = s.p
		var col: Color = _ink_color(s.c)
		var w: float = s.w
		if pts.size() == 1:
			canvas.draw_circle(pts[0], w / 2.0, col)
			continue
		if not classic:
			canvas.draw_polyline(pts, Color(col, 0.18), w * 2.2, true)
		canvas.draw_polyline(pts, col, w, true)
		for p in pts:
			canvas.draw_circle(p, w / 2.0, col)
	if phase != "drawing" and strokes.is_empty():
		var font := ThemeDB.fallback_font
		canvas.draw_string(font, Vector2(0, canvas.size.y / 2.0), tr("The canvas"), HORIZONTAL_ALIGNMENT_CENTER, canvas.size.x, 28, Color(HomeKit.CLASSIC.pencil, 0.6) if classic else Color(HomeKit.DIM, 0.4))

## A stroke keeps its neon ink; the Classic skin shows the matching marker.
func _ink_color(c: Color) -> Color:
	if skin != "classic":
		return c
	var i: int = INKS.find(c)
	return CLASSIC_INKS[i] if i >= 0 else c

## The kit's Look (Options): "classic" = markers on a whiteboard,
## "voodoo" = neon on black. Re-skins in place.
func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
	if bg.get_child_count() > 0:
		bg.get_child(0).visible = skin != "classic"  # the faint neon grid
	_refresh_tools()
	if canvas:
		canvas.queue_redraw()

func _pick_ink(i: int) -> void:
	ink = i
	_refresh_tools()

func _toggle_width() -> void:
	width_i = 1 - width_i
	_refresh_tools()

func _undo() -> void:
	if phase == "drawing" and not strokes.is_empty():
		strokes.pop_back()
		canvas.queue_redraw()

func _clear() -> void:
	if phase == "drawing":
		strokes.clear()
		canvas.queue_redraw()

func _peek(show: bool) -> void:
	if phase != "drawing":
		return
	peek_btn.text = engine.word.to_upper() if show else tr("👁 Word")

func _refresh_tools() -> void:
	for i in ink_buttons.size():
		var sb := HomeKit.neon_box(INKS[i], "pressed" if i == ink else "normal")
		sb.bg_color = Color(_ink_color(INKS[i]), 0.85 if i == ink else 0.45)
		if skin == "classic":
			sb.bg_color = _ink_color(INKS[i])
			sb.border_color = Color.WHITE if i == ink else Color(1, 1, 1, 0.3)
			sb.shadow_size = 0
		sb.set_corner_radius_all(28)
		sb.set_border_width_all(4 if i == ink else 2)
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			ink_buttons[i].add_theme_stylebox_override(st, sb)
	width_btn.text = "●" if width_i == 1 else "•"
	width_btn.add_theme_font_size_override("font_size", 44 if width_i == 1 else 30)
	if engine.scores.is_empty() or phase == "idle":
		team_label.text = tr("🎨 Sketch It")
		timer_label.text = ""
		return
	var t: int = engine.turn
	team_label.text = _team_name(t) + "  ·  " + "%d" % engine.scores[t]
	team_label.add_theme_color_override("font_color", TEAM_COLORS[t].lerp(Color.WHITE, 0.3))
	timer_label.text = str(maxi(0, int(ceil(time_left)))) if phase == "drawing" else ""
	timer_label.add_theme_color_override("font_color", HomeKit.PINK if phase == "drawing" and time_left <= 10.0 else HomeKit.WHITE)
	tools_box.modulate.a = 1.0 if phase == "drawing" else 0.4
	canvas.queue_redraw()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y * 0.42, 70.0)
	var o := c.size / 2.0
	HomeKit.glow_rect(c, Rect2(o - Vector2(k * 1.5, k), Vector2(k * 3.0, k * 2.0)), HomeKit.PURPLE, 2.5, 0.06)
	# A doodled house and sun on the easel.
	var base := o + Vector2(-k * 0.5, k * 0.6)
	var house := PackedVector2Array([base, base + Vector2(0, -k * 0.7), base + Vector2(k * 0.45, -k * 1.15),
		base + Vector2(k * 0.9, -k * 0.7), base + Vector2(k * 0.9, 0), base])
	HomeKit.glow_polyline(c, house, HomeKit.CYAN, 3.0)
	HomeKit.glow_circle(c, o + Vector2(k * 0.95, -k * 0.45), k * 0.22, HomeKit.GOLD, 3.0)
	HomeKit.glow_line(c, o + Vector2(k * 1.3, k * 0.75), o + Vector2(k * 0.55, -k * 0.05), HomeKit.MAGENTA, 4.0)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

## Scores and whose turn it is; a turn in progress starts over on resume.
func _save_game() -> void:
	if not started or phase == "over" or phase == "idle":
		return
	SaveUtil.write(SAVE_PATH, {"scores": engine.scores, "turn": engine.turn, "teams": teams,
		"level": word_level, "time": time_pick})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var parts: Array = []
	for v in d.get("scores", []):
		parts.append(str(int(v)))
	return tr("%d teams") % int(d.get("teams", 2)) + "   ·   " + " – ".join(parts)

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_new_game(2)
		return
	word_level = clampi(int(d.get("level", 0)), 0, 2)
	time_pick = clampi(int(d.get("time", 1)), 0, 2)
	_new_game(clampi(int(d.get("teams", 2)), 2, 4))
	var sc: Array = d.get("scores", [])
	for i in mini(sc.size(), engine.scores.size()):
		engine.scores[i] = int(sc[i])
	engine.turn = clampi(int(d.get("turn", 0)), 0, teams - 1)
	_handoff()

func _tint(b: Button, color: Color) -> void:
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, HomeKit.neon_box(color, st))

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
