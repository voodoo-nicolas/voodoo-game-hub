extends Control

## Cryptogram -- a proverb with every letter swapped for another. Tap a coded
## letter, then a key to say what you think it stands for; the same coded
## letter fills in everywhere it appears.

const CGEngine = preload("res://scripts/games/cryptogram/cryptogram_engine.gd")
const HELP = preload("res://scripts/games/cryptogram/cryptogram_help.gd")
const HomeKit = preload("res://scripts/games/cryptogram/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://cryptogram_save.json"
const LEVEL_NAMES := ["Easy", "Normal", "Hard"]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Landing + pause menu
var engine: CGEngine
var bg: ColorRect
var skin: String = "classic"
var info_label: Label
var feedback_label: Label
var scroll: ScrollContainer
var flow: HFlowContainer
var keyboard: VBoxContainer
var end_dialog: ColorRect
var feedback_timer: Timer
var check_timer: Timer
var cells: Array = []        # {"btn", "c", "guess_lab", "cipher_lab"}
var keys := {}               # plain letter -> Button
var selected: String = ""    # the coded letter being decoded
var checking: bool = false
var elapsed: float = 0.0
var playing: bool = false

func _ready() -> void:
	preload("res://scripts/games/cryptogram/cryptogram_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = CGEngine.new()
	engine.load_quotes()
	_build_ui()
	_chill_music()

## Calm background music from the hub's Music library (apps before v0.33 play none).
func _chill_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, 2, 2.0)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
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
	pause_btn.add_theme_font_size_override("font_size", 30)
	pause_btn.pressed.connect(_on_pause_home)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("🔐 Cryptogram")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

	var sm := MarginContainer.new()
	sm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sm.add_theme_constant_override("margin_left", 14)
	sm.add_theme_constant_override("margin_right", 14)
	root.add_child(sm)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sm.add_child(scroll)
	flow = HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 18)
	flow.add_theme_constant_override("v_separation", 14)
	scroll.add_child(flow)

	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 24)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.custom_minimum_size = Vector2(0, 34)
	root.add_child(feedback_label)

	var km := MarginContainer.new()
	km.add_theme_constant_override("margin_left", 8)
	km.add_theme_constant_override("margin_right", 8)
	root.add_child(km)
	keyboard = VBoxContainer.new()
	keyboard.add_theme_constant_override("separation", 6)
	km.add_child(keyboard)

	var row_margin := MarginContainer.new()
	row_margin.add_theme_constant_override("margin_bottom", 30)
	root.add_child(row_margin)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	row_margin.add_child(actions)
	actions.add_child(_button(tr("✔ Check"), _on_check))
	actions.add_child(_button(tr("💡 Hint"), _on_hint))
	actions.add_child(_button(tr("⌫ Clear"), _on_clear))

	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.wait_time = 2.0
	feedback_timer.timeout.connect(_clear_feedback)
	add_child(feedback_timer)
	check_timer = Timer.new()
	check_timer.one_shot = true
	check_timer.wait_time = 2.5
	check_timer.timeout.connect(_end_check)
	add_child(check_timer)

	end_dialog = UI.build_dialog(tr("Decoded!"), [
		{"text": tr("Next puzzle"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in 3:
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard"][i], "sub": ["Short quote", "Medium quote", "Long quote"][i],
			"row": "lvl", "action": _new_game.bind(i)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.MAGENTA,
		"subtitle": "Every letter is swapped. Crack the code.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Puzzles solved",
		"board_note": "Cryptograms decoded at any level.",
	})
	add_child(home)
	if info:
		add_child(info)

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 72)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	return b

func _process(delta: float) -> void:
	if playing and not engine.solved():
		elapsed += delta
		_update_info()

# ---------- looks ----------

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if not cells.is_empty():
		_refresh()

func _is_classic() -> bool:
	return skin == "classic"

## state: "normal", "same" (shares the selected coded letter), "selected", "wrong", "given"
func _cell_style(state: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(3)
	if _is_classic():
		sb.bg_color = Color("f4efe4")
		sb.border_color = Color("8a8473")
		match state:
			"same":
				sb.bg_color = Color("fff0b3")
			"selected":
				sb.bg_color = HomeKit.CLASSIC.yellow
				sb.border_color = Color("6b4423")
			"wrong":
				sb.bg_color = Color("f4b1ad")
				sb.border_color = HomeKit.CLASSIC.red
			"given":
				sb.bg_color = Color("cfe0ff")
	else:
		var c := HomeKit.CYAN
		match state:
			"same":
				c = HomeKit.GOLD
			"selected":
				c = HomeKit.PINK
			"wrong":
				c = Color("ff3b3b")
			"given":
				c = HomeKit.LIME
		sb.bg_color = Color(c, 0.2 if state != "normal" else 0.1)
		sb.border_color = c if state != "normal" else Color(c, 0.55)
	return sb

func _ink() -> Color:
	return HomeKit.CLASSIC.ink if _is_classic() else Color.WHITE

func _faint() -> Color:
	return HomeKit.CLASSIC.pencil if _is_classic() else HomeKit.DIM

# ---------- the text ----------

func _cell_width() -> float:
	var longest := 1
	for w in engine.encoded.split(" ", false):
		longest = maxi(longest, w.length())
	var avail: float = get_viewport_rect().size.x - 40.0
	return clampf(avail / longest - 4.0, 26.0, 50.0)

func _rebuild_text() -> void:
	for c in flow.get_children():
		flow.remove_child(c)
		c.queue_free()
	cells = []
	var k := _cell_width()
	for word in engine.encoded.split(" ", false):
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		for ch in word:
			if engine.guess.has(ch):
				box.add_child(_make_cell(ch, k))
			else:
				var l := Label.new()
				l.text = ch
				l.add_theme_font_size_override("font_size", int(k * 0.7))
				l.add_theme_color_override("font_color", _ink())
				l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
				l.custom_minimum_size = Vector2(0, k * 1.5)
				box.add_child(l)
		flow.add_child(box)

func _make_cell(c: String, k: float) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(k, k * 1.5)
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("sfx", "tap")
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	var g := Label.new()
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.add_theme_font_size_override("font_size", int(k * 0.62))
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := Label.new()
	s.text = c
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", int(k * 0.36))
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(g)
	v.add_child(s)
	b.add_child(v)
	b.pressed.connect(_on_cell.bind(c))
	cells.append({"btn": b, "c": c, "guess_lab": g, "cipher_lab": s})
	return b

func _refresh() -> void:
	var wrong: Array = engine.wrong_letters() if checking else []
	for cell in cells:
		var c: String = cell.c
		var state := "normal"
		if checking and wrong.has(c):
			state = "wrong"
		elif c == selected:
			state = "selected"
		elif engine.given.has(c):
			state = "given"
		elif selected != "" and engine.guess.get(selected, "") != "" and engine.guess[c] == engine.guess[selected]:
			state = "same"
		var sb := _cell_style(state)
		var b: Button = cell.btn
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		var g: Label = cell.guess_lab
		g.text = engine.guess.get(c, "")
		g.add_theme_color_override("font_color", _ink())
		var s: Label = cell.cipher_lab
		s.add_theme_color_override("font_color", _faint())
	_update_info()
	_dim_used_keys()

func _update_info() -> void:
	var t := int(elapsed)
	info_label.text = tr("Time %d:%02d   Hints %d   Filled %d/%d") % [t / 60, t % 60, engine.hints, engine.filled_count(), engine.guess.size()]

# ---------- keyboard ----------

func _build_keyboard() -> void:
	for c in keyboard.get_children():
		keyboard.remove_child(c)
		c.queue_free()
	keys = {}
	var rows := ["QWERTYUIOP", "ASDFGHJKL" + ("Ñ" if engine.spanish else ""), "ZXCVBNM"]
	var kw: float = clampf((get_viewport_rect().size.x - 16.0) / 10.0 - 6.0, 30.0, 64.0)
	for r in rows:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 5)
		for ch in r:
			var b := Button.new()
			b.text = ch
			b.custom_minimum_size = Vector2(kw, kw * 1.2)
			b.add_theme_font_size_override("font_size", int(kw * 0.5))
			b.focus_mode = Control.FOCUS_NONE
			b.set_meta("sfx", "key")
			b.pressed.connect(_on_key.bind(ch))
			row.add_child(b)
			keys[ch] = b
		keyboard.add_child(row)

func _dim_used_keys() -> void:
	var used := {}
	for c in engine.guess:
		if engine.guess[c] != "":
			used[engine.guess[c]] = true
	for ch in keys:
		keys[ch].modulate = Color(1, 1, 1, 0.4) if used.has(ch) else Color(1, 1, 1, 1)

# ---------- play ----------

func _on_cell(c: String) -> void:
	if engine.solved():
		return
	selected = "" if selected == c else c
	_refresh()

func _on_key(p: String) -> void:
	if engine.solved() or engine.guess.is_empty():
		return
	if selected == "":
		_feedback(tr("Tap a coded letter first"), Color(0.9, 0.8, 0.4))
		return
	if not engine.set_guess(selected, p):
		_sfx("invalid")
		_feedback(tr("That letter was given as a hint"), Color(1, 0.7, 0.35))
		return
	_advance_selection()
	_refresh()
	_save_game()
	if engine.solved():
		_on_solved()

func _on_clear() -> void:
	if selected == "" or engine.solved():
		return
	if engine.set_guess(selected, ""):
		_sfx("back")
		_refresh()
		_save_game()

func _on_hint() -> void:
	if engine.solved():
		return
	if engine.hint() == "":
		return
	selected = ""
	_sfx("powerup")
	_refresh()
	_save_game()
	if engine.solved():
		_on_solved()

func _on_check() -> void:
	if engine.solved():
		return
	var wrong: Array = engine.wrong_letters()
	if wrong.is_empty():
		_feedback(tr("No mistakes so far"), Color(0.5, 0.95, 0.5))
		return
	_sfx("letter_wrong")
	checking = true
	_feedback(tr("%d wrong") % wrong.size(), Color(1, 0.45, 0.45))
	_refresh()
	check_timer.start()

func _end_check() -> void:
	checking = false
	_refresh()

func _advance_selection() -> void:
	var order: Array = []
	for ch in engine.encoded:
		if engine.guess.has(ch) and not order.has(ch):
			order.append(ch)
	var at: int = order.find(selected)
	for step in range(1, order.size() + 1):
		var c: String = order[(at + step) % order.size()]
		if engine.guess[c] == "":
			selected = c
			return
	selected = ""

func _on_solved() -> void:
	playing = false
	selected = ""
	_refresh()
	if info:
		info.add("Puzzles solved")
		if engine.hints == 0:
			info.add("No-hint solves")
		info.add("Hints used", engine.hints)
		info.best("Best time (%s)" % LEVEL_NAMES[engine.level], elapsed, true)
	SaveUtil.delete(SAVE_PATH)
	var t := int(elapsed)
	end_dialog.get_meta("message_label").text = tr("Time %d:%02d") % [t / 60, t % 60] + "   " + tr("Hints %d") % engine.hints
	end_dialog.visible = true

func _feedback(text: String, col: Color) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", col)
	feedback_timer.start()

func _clear_feedback() -> void:
	feedback_label.text = ""

# ---------- Landing (home_kit.gd) ----------

func _new_game(level: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.new_game(level, TranslationServer.get_locale().begins_with("es"))
	elapsed = 0.0
	_begin_play()

func _restart() -> void:
	_new_game(engine.level)

func _begin_play() -> void:
	selected = ""
	checking = false
	playing = true
	end_dialog.visible = false
	_clear_feedback()
	_build_keyboard()
	_rebuild_text()
	_advance_first()
	_refresh()
	_save_game()

func _advance_first() -> void:
	for ch in engine.encoded:
		if engine.guess.has(ch) and engine.guess[ch] == "":
			selected = ch
			return

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y * 0.36, 50.0)
	var mid := c.size / 2.0
	var cipher := ["L", "I", "P", "P", "S"]
	var plain := ["H", "E", "L", "L", "O"]
	for i in 5:
		var x := mid.x + (i - 2) * k * 1.2
		HomeKit.glow_rect(c, Rect2(Vector2(x - k * 0.5, mid.y - k * 1.05), Vector2(k, k)), HomeKit.MAGENTA, 2.5, 0.12)
		HomeKit.glow_text(c, Vector2(x, mid.y - k * 0.55), cipher[i], int(k * 0.62), Color.WHITE)
		HomeKit.glow_line(c, Vector2(x, mid.y - k * 0.02), Vector2(x, mid.y + k * 0.1), HomeKit.DIM, 2.0)
		HomeKit.glow_rect(c, Rect2(Vector2(x - k * 0.5, mid.y + k * 0.12), Vector2(k, k)), HomeKit.CYAN, 2.5, 0.12)
		HomeKit.glow_text(c, Vector2(x, mid.y + k * 0.62), plain[i], int(k * 0.62), Color.WHITE)

# ---------- save / resume ----------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if engine == null or not playing or engine.plain == "" or engine.solved():
		return
	var d := engine.to_dict()
	d["elapsed"] = elapsed
	SaveUtil.write(SAVE_PATH, d)

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var t := int(float(d.get("elapsed", 0.0)))
	return tr("Time %d:%02d") % [t / 60, t % 60]

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not engine.from_dict(d):
		_new_game(0)
		return
	elapsed = float(d.get("elapsed", 0.0))
	_begin_play()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
