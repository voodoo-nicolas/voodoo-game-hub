extends Control

## Spirit Board -- a neon talking board. "Ask the spirits": type (or say) a
## question and the planchette glides by itself to spell the reply.
## "Séance": everyone puts a finger on the planchette and moves it; resting
## on a letter writes it down. Nothing to save: each séance is fresh.

const SBEngine = preload("res://scripts/games/spirit_board/spirit_board_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## Home screen + pause menu + neon look, copied into this game's folder by
## `hub.py sync` (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/spirit_board/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const INK := Color("ffcf6b")          # the board's letters: candle gold
const TAPE_MAX := 22                  # characters kept on the message line
const FLAME := Color("6a5bff")        # purple-blue voodoo fire
## A minor scale for the planchette's tones, one per stop.
const TONES := [196.0, 220.0, 233.08, 261.63, 293.66, 311.13, 349.23, 392.0]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine: SBEngine
var rng := RandomNumberGenerator.new()
var mode := "ask"                     # "ask" / "seance"
var board: Control
var status_label: Label
var tape_label: Label
var ask_row: HBoxContainer
var seance_row: HBoxContainer
var question_edit: LineEdit
var ask_btn: Button

var tape := ""
var reply := ""
var gone := false                     # GOODBYE reached: the spirit has left
var flashes := {}                     # key -> seconds of glow left
var time := 0.0
var tilt := 0.0
var _prev_pos := SBEngine.REST
# Séance: the fingers on the planchette.
var target := SBEngine.REST
var touches := {}                     # touch index (-1 = mouse) -> true
var touch_seen := false
var _tones: Array = []
var _farewell: AudioStreamWAV

func _ready() -> void:
	preload("res://scripts/games/spirit_board/spirit_board_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = SBEngine.new()
	for f in TONES:
		_tones.append(_make_eerie(f, 0.7))
	_farewell = _make_farewell()
	_build_ui()
	_start("ask")

func _lang() -> String:
	return "es" if TranslationServer.get_locale().begins_with("es") else "en"

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme(HomeKit.PURPLE)
	add_child(HomeKit.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_margin.add_child(top_bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.add_theme_font_size_override("font_size", 30)
	pause_btn.pressed.connect(_on_pause)
	top_bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("🔮 Spirit Board")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76, 0)
	top_bar.add_child(spacer)

	# The question goes near the top, so the phone's keyboard doesn't hide it.
	var rows := MarginContainer.new()
	rows.add_theme_constant_override("margin_left", 24)
	rows.add_theme_constant_override("margin_right", 24)
	root.add_child(rows)
	var rows_box := VBoxContainer.new()
	rows.add_child(rows_box)
	ask_row = HBoxContainer.new()
	ask_row.add_theme_constant_override("separation", 10)
	rows_box.add_child(ask_row)
	question_edit = LineEdit.new()
	question_edit.placeholder_text = tr("Type a question, or ask it out loud")
	question_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_edit.custom_minimum_size = Vector2(0, 72)
	question_edit.add_theme_font_size_override("font_size", 26)
	question_edit.max_length = 80
	question_edit.text_submitted.connect(_on_ask.unbind(1))
	for state in ["normal", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(HomeKit.PANEL, 0.95)
		box.border_color = Color(HomeKit.PURPLE, 0.9 if state == "focus" else 0.5)
		box.set_border_width_all(2)
		box.set_corner_radius_all(14)
		box.content_margin_left = 16
		box.content_margin_right = 16
		question_edit.add_theme_stylebox_override(state, box)
	ask_row.add_child(question_edit)
	ask_btn = Button.new()
	ask_btn.text = tr("Ask")
	ask_btn.custom_minimum_size = Vector2(130, 72)
	ask_btn.pressed.connect(_on_ask)
	ask_row.add_child(ask_btn)
	seance_row = HBoxContainer.new()
	seance_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rows_box.add_child(seance_row)
	var clear_btn := Button.new()
	clear_btn.text = tr("🧹 Clear the board")
	clear_btn.custom_minimum_size = Vector2(320, 72)
	clear_btn.pressed.connect(_on_clear)
	seance_row.add_child(clear_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", HomeKit.DIM)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	var status_m := MarginContainer.new()  # side room for the floating ⚙ tab
	status_m.add_theme_constant_override("margin_left", 48)
	status_m.add_theme_constant_override("margin_right", 48)
	status_m.add_child(status_label)
	root.add_child(status_m)

	tape_label = Label.new()
	tape_label.add_theme_font_size_override("font_size", 50)
	tape_label.add_theme_color_override("font_color", INK.lerp(Color.WHITE, 0.3))
	tape_label.add_theme_color_override("font_outline_color", Color(INK, 0.3))
	tape_label.add_theme_constant_override("outline_size", 10)
	tape_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tape_label.custom_minimum_size = Vector2(0, 74)
	tape_label.clip_text = true
	root.add_child(tape_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	root.add_child(board)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/spirit_board/spirit_board_help.gd"))
	home = HomeKit.new({
		"help": preload("res://scripts/games/spirit_board/spirit_board_help.gd"),
		"info": info,
		"accent": HomeKit.PURPLE,
		"subtitle": "Light the candles. Ask the spirits. Don't forget to say goodbye.",
		"logo": _draw_home_logo,
		"solo_heading": "Hold a séance",
		"modes": [
			{"text": "🔮  Ask the spirits", "sub": "Type or say a question — the planchette answers by itself", "color": HomeKit.PURPLE, "action": _start.bind("ask")},
			{"text": "✋  Séance", "sub": "Everyone's fingers on the planchette — you move it", "color": HomeKit.CYAN, "action": _start.bind("seance")},
		],
		"restart": _restart,
		"board": "Questions asked",
		"board_note": "Questions asked, all time.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.94)  # below the board, clear of the letters
	add_child(drawer)

func _on_pause() -> void:
	question_edit.release_focus()
	home.pause()

func _restart() -> void:
	_start(mode)

func _start(p_mode: String) -> void:
	mode = p_mode
	engine.start(rng)
	target = SBEngine.REST
	_prev_pos = SBEngine.REST
	touches.clear()
	flashes.clear()
	tape = ""
	reply = ""
	gone = false
	ask_row.visible = mode == "ask"
	seance_row.visible = mode == "seance"
	ask_btn.disabled = false
	question_edit.text = ""
	if mode == "ask":
		status_label.text = tr("Ask the spirits a question")
	else:
		status_label.text = tr("Everyone: one finger on the planchette. Rest on a letter to spell.")
	_show_tape()

# ---------- Ask ----------

func _on_ask() -> void:
	if engine.moving or mode != "ask":
		return
	question_edit.release_focus()
	DisplayServer.virtual_keyboard_hide()
	if gone:  # a new spirit answers the call
		engine.start(rng)
		gone = false
	reply = engine.answer_for(question_edit.text, _lang(), rng)
	tape = ""
	_show_tape()
	engine.begin_spell(reply)
	ask_btn.disabled = true
	status_label.text = tr("The planchette begins to move…")
	_sfx("whoosh")
	if info:
		info.add("Questions asked")

func _on_spirit(key: String) -> void:
	if key == "done":
		ask_btn.disabled = false
		question_edit.text = ""
		if reply == "GOODBYE":
			gone = true
			status_label.text = tr("The spirit has left. Ask again to call another.")
		else:
			status_label.text = tr("Ask another question")
		return
	if key == " ":
		tape += " "
	else:
		_landed(key)

# ---------- Séance ----------

func _on_clear() -> void:
	_start("seance")

func _on_board_input(event: InputEvent) -> void:
	if mode != "seance":
		return
	# A phone sends each touch twice (touch + emulated mouse): once a real
	# touch has been seen, only touches count.
	if event is InputEventScreenTouch:
		if not touch_seen:
			touch_seen = true
			touches.erase(-1)
		if event.pressed:
			if _grabs(event.position):
				touches[event.index] = true
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		if touches.has(event.index):
			_push(event.relative / float(touches.size()))
	elif not touch_seen:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _grabs(event.position):
				touches[-1] = true
			elif not event.pressed:
				touches.erase(-1)
		elif event is InputEventMouseMotion and touches.has(-1):
			_push(event.relative)

## A finger lands on (or right beside) the planchette.
func _grabs(p: Vector2) -> bool:
	return p.distance_to(_to_px(engine.pos)) < _lens_r() * 3.2

## Fingers moved by `rel` pixels (already shared out between them).
func _push(rel: Vector2) -> void:
	var r := _board_rect()
	target += Vector2(rel.x / r.size.x, rel.y / r.size.y)
	target = Vector2(clampf(target.x, 0.03, 0.97), clampf(target.y, 0.06, SBEngine.REST.y))

func _seance_pick(key: String) -> void:
	if gone:
		return
	_landed(key)
	if key == "GOODBYE":
		gone = true
		status_label.text = tr("The spirit has left. Clear the board to call another.")

# ---------- both ----------

## The planchette arrived on a symbol: glow, sound, write it down.
func _landed(key: String) -> void:
	flashes[key] = 1.2
	if key == "GOODBYE":
		_play(_farewell, -2.0)
	else:
		_play(_tones[rng.randi_range(0, _tones.size() - 1)], -3.0)
	_buzz(25)
	if key in SBEngine.WORDS:
		if tape != "" and not tape.ends_with(" "):
			tape += " "
		tape += _word(key) + " "
	else:
		tape += key
		if info:
			info.add("Letters spelled")
	_show_tape()

func _word(key: String) -> String:
	match key:
		"YES":
			return tr("Yes").to_upper()
		"NO":
			return tr("No").to_upper()
		"GOODBYE":
			return tr("Goodbye").to_upper()
	return key

func _show_tape() -> void:
	var t := tape.strip_edges()
	if t.length() > TAPE_MAX:
		t = "…" + t.right(TAPE_MAX - 1)
	tape_label.text = t if t != "" else "· · ·"

func _process(delta: float) -> void:
	time += delta
	for k in flashes.keys():
		flashes[k] -= delta
		if flashes[k] <= 0.0:
			flashes.erase(k)
	if mode == "ask":
		var ev := engine.step_spirit(delta)
		if ev != "":
			_on_spirit(ev)
	else:
		# The planchette floats after the fingers, a little behind them.
		var p := engine.pos.lerp(target, 1.0 - exp(-9.0 * delta))
		var speed := SBEngine.dist(p, engine.pos) / maxf(delta, 0.001)
		var k := engine.seance_step(p, speed, delta)
		if k != "":
			_seance_pick(k)
	var vx := (engine.pos.x - _prev_pos.x) / maxf(delta, 0.001)
	tilt = lerpf(tilt, clampf(vx * 0.35, -0.3, 0.3), 1.0 - exp(-6.0 * delta))
	_prev_pos = engine.pos
	board.queue_redraw()

# ---------- drawing ----------

## The board's rectangle inside `board`, leaving room under it for the
## planchette's tail and the candles.
func _board_rect() -> Rect2:
	var avail := board.size
	var w := minf(avail.x - 24.0, (avail.y * 0.72) * SBEngine.ASPECT)
	w = maxf(w, 10.0)
	var h := w / SBEngine.ASPECT
	var top := maxf(6.0, (avail.y - h) * 0.25)
	return Rect2(Vector2((avail.x - w) / 2.0, top), Vector2(w, h))

func _to_px(p: Vector2) -> Vector2:
	var r := _board_rect()
	return r.position + Vector2(p.x * r.size.x, p.y * r.size.y)

func _lens_r() -> float:
	return _board_rect().size.y * 0.055

func _draw_board() -> void:
	var r := _board_rect()
	if r.size.y < 20.0:
		return
	var h := r.size.y
	var font: Font = ThemeDB.fallback_font
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.09, 0.95)
	sb.set_corner_radius_all(int(h * 0.08))
	board.draw_style_box(sb, r)
	HomeKit.glow_rect(board, r, HomeKit.PURPLE, 2.0)
	board.draw_rect(r.grow(-h * 0.03), Color(INK, 0.22), false, 1.5)
	_draw_candles(r)
	# Sun, skull and moon across the top.
	_draw_sun(_to_px(Vector2(0.07, 0.13)), h * 0.05)
	_draw_moon(_to_px(Vector2(0.93, 0.13)), h * 0.055)
	_draw_skull(board, _to_px(Vector2(0.5, 0.135)), h * 0.07, Color(INK, 0.85))
	var under := engine.nearest(engine.pos)
	for s in engine.symbols:
		_draw_symbol(font, s, h, 1.0 if s["key"] != under else 1.35)
	if mode == "seance" and engine.dwell_progress() > 0.0:
		var c := _to_px(engine.pos_of(engine.dwell_key()))
		board.draw_arc(c, h * 0.075, -PI / 2.0, -PI / 2.0 + TAU * engine.dwell_progress(), 40, Color(HomeKit.CYAN, 0.8), 3.0, true)
	_draw_planchette(_to_px(engine.pos), _lens_r())
	# The symbol under the window, magnified on top of the planchette.
	if under != "":
		for s in engine.symbols:
			if s["key"] == under:
				_draw_symbol(font, s, h, 1.25, true)

func _label(key: String) -> String:
	return _word(key) if key in SBEngine.WORDS else key

func _draw_symbol(font: Font, s: Dictionary, h: float, zoom: float, lit: bool = false) -> void:
	var key: String = s["key"]
	var fs := int(h * (0.088 if key.length() > 1 else (0.068 if key >= "0" and key <= "9" else 0.098)) * zoom)
	var col := INK
	var flash: float = flashes.get(key, 0.0)
	if flash > 0.0:
		col = INK.lerp(Color.WHITE, minf(flash, 1.0))
	if lit:
		col = Color.WHITE
	var text := _label(key)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := -font.get_height(fs) / 2.0 + font.get_ascent(fs)
	board.draw_set_transform(_to_px(s["pos"]), s["rot"], Vector2.ONE)
	var glow := 0.18 + (0.5 * minf(flash, 1.0) if flash > 0.0 else 0.0) + (0.3 if lit else 0.0)
	board.draw_string_outline(font, Vector2(-w / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 4), Color(col, glow))
	board.draw_string(font, Vector2(-w / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The planchette: a teardrop pointing up, its glass window at `c`.
func _draw_planchette(c: Vector2, rl: float) -> void:
	var tremble := Vector2(sin(time * 23.0), cos(time * 19.0)) * rl * 0.03
	board.draw_set_transform(c + tremble, tilt, Vector2.ONE)
	var pts := _teardrop(rl)
	board.draw_colored_polygon(pts, Color(0.1, 0.04, 0.16, 0.55))
	HomeKit.glow_polyline(board, pts, HomeKit.MAGENTA, 2.0, true)
	for f in [Vector2(-rl * 1.25, rl * 1.95), Vector2(rl * 1.25, rl * 1.95), Vector2(0, -rl * 1.9)]:
		board.draw_circle(f, rl * 0.13, Color(HomeKit.MAGENTA, 0.6))
	board.draw_circle(Vector2.ZERO, rl, Color(0.5, 0.85, 1.0, 0.06))
	HomeKit.glow_circle(board, Vector2.ZERO, rl, HomeKit.CYAN, 2.0)
	board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _teardrop(rl: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var w := rl * 2.1
	var hh := rl * 2.6
	var oy := rl * 0.45  # the window sits above the shape's middle
	for i in 40:
		var t := TAU * i / 40.0
		pts.append(Vector2(w * sin(t) * sin(t / 2.0), -hh * cos(t) + oy))
	return pts

func _draw_sun(c: Vector2, r: float) -> void:
	HomeKit.glow_circle(board, c, r * 0.55, HomeKit.GOLD, 1.8)
	for i in 8:
		var a := TAU * i / 8.0 + time * 0.2
		HomeKit.glow_line(board, c + Vector2.from_angle(a) * r * 0.75, c + Vector2.from_angle(a) * r * 1.05, HomeKit.GOLD, 1.5)

func _draw_moon(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		pts.append(c + Vector2.from_angle(PI * 0.35 + PI * 1.3 * i / 20.0) * r)
	for i in 21:
		var a := PI * 1.65 - PI * 1.3 * i / 20.0
		pts.append(c + Vector2(r * 0.35, 0) + Vector2.from_angle(a) * r * 0.78)
	HomeKit.glow_polyline(board, pts, Color("b9c7ff"), 1.8, true)

## A neon skull outline (ART_STYLE's voodoo layer), centred on c.
static func _draw_skull(cv: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var head := PackedVector2Array()
	for i in 25:
		var a := PI * 0.8 + PI * 1.4 * i / 24.0
		head.append(c + Vector2(cos(a) * s * 0.62, sin(a) * s * 0.58 - s * 0.08))
	head.append(c + Vector2(s * 0.3, s * 0.42))
	head.append(c + Vector2(-s * 0.3, s * 0.42))
	HomeKit.glow_polyline(cv, head, col, 1.8, true)
	for side in [-1.0, 1.0]:
		cv.draw_circle(c + Vector2(side * s * 0.24, -s * 0.05), s * 0.15, Color(HomeKit.MAGENTA, 0.85))
	cv.draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.1), c + Vector2(-s * 0.07, s * 0.22), c + Vector2(s * 0.07, s * 0.22)]), Color(col, 0.8))
	for i in 3:
		var x := (i - 1) * s * 0.15
		cv.draw_line(c + Vector2(x, s * 0.3), c + Vector2(x, s * 0.42), Color(col, 0.8), 1.5)

## Two candles with purple-blue flames under the board, when there's room.
func _draw_candles(r: Rect2) -> void:
	var room := board.size.y - r.end.y
	if room < 90.0:
		return
	var ch := minf(room * 0.55, 150.0)
	var cw := ch * 0.28
	for i in 2:
		var x := r.position.x + r.size.x * (0.1 if i == 0 else 0.9)
		var base := r.end.y + room * 0.86
		var body := Rect2(Vector2(x - cw / 2.0, base - ch), Vector2(cw, ch))
		board.draw_rect(body, Color(INK, 0.06))
		HomeKit.glow_rect(board, body, Color(INK, 0.6), 1.5)
		var flick := 1.0 + 0.12 * sin(time * 11.0 + i * 2.0) + 0.06 * sin(time * 23.0 + i)
		var tip := Vector2(x, body.position.y - cw * 0.25)
		board.draw_circle(tip + Vector2(0, -cw * 0.6), cw * 1.6 * flick, Color(FLAME, 0.08))
		var flame := PackedVector2Array()
		for k in 24:
			var t := TAU * k / 24.0
			flame.append(tip + Vector2(cw * 0.42 * sin(t) * sin(t / 2.0), -cw * 0.9 * flick * cos(t) - cw * 0.9 * flick))
		board.draw_colored_polygon(flame, Color(FLAME, 0.5))
		HomeKit.glow_polyline(board, flame, FLAME.lerp(Color.WHITE, 0.2), 1.5, true)

func _draw_home_logo(c: Control) -> void:
	var s := minf(c.size.y * 0.9, 170.0)
	var ctr := c.size / 2.0
	var r := Rect2(ctr - Vector2(s * 0.95, s * 0.42), Vector2(s * 1.9, s * 0.84))
	HomeKit.glow_rect(c, r, HomeKit.PURPLE, 2.0, 0.06)
	var font: Font = ThemeDB.fallback_font
	var letters := "ABCDEFG"
	for i in letters.length():
		var x := r.position.x + r.size.x * (0.12 + 0.76 * i / 6.0)
		var d := (float(i) / 6.0 - 0.5) * 2.0
		var y := r.position.y + r.size.y * (0.42 - 0.16 * (1.0 - d * d))
		c.draw_string(font, Vector2(x - s * 0.05, y + s * 0.06), letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.16), INK)
	_draw_skull(c, ctr + Vector2(0, s * 0.2), s * 0.2, INK)
	c.draw_set_transform(ctr + Vector2(s * 0.42, s * 0.12), 0.35, Vector2.ONE)
	var pts := _teardrop(s * 0.09)
	c.draw_colored_polygon(pts, Color(0.1, 0.04, 0.16, 0.6))
	HomeKit.glow_polyline(c, pts, HomeKit.MAGENTA, 2.0, true)
	HomeKit.glow_circle(c, Vector2.ZERO, s * 0.09, HomeKit.CYAN, 2.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------- sound and touch feedback ----------

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

## Plays one of this pack's own sounds (silent on apps from before v0.23).
func _play(stream: AudioStream, db: float = 0.0) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s and s.has_method("play_stream"):
		s.play_stream(stream, db)

## A short buzz, when the player has vibration on (Settings, app v0.21+).
func _buzz(ms: int) -> void:
	var st = get_node_or_null("/root/Settings")
	if st and st.has_method("buzz"):
		st.buzz(ms)

## A hollow, wavering tone: two slightly detuned sines, slow swell and fade.
static func _make_eerie(freq: float, length: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	for k in n:
		var t := float(k) / rate
		var f := freq * (1.0 + 0.01 * sin(TAU * 5.5 * t))
		var v := sin(TAU * f * t) + 0.7 * sin(TAU * f * 1.006 * t) + 0.2 * sin(TAU * f * 2.0 * t)
		var env := minf(1.0, t / 0.08) * exp(-t * 3.5)
		data.encode_s16(k * 2, int(clampf(v * env * 0.3, -1.0, 1.0) * 32767.0))
	return _wav(data, rate)

## GOODBYE: a long tone sliding down into nothing.
static func _make_farewell() -> AudioStreamWAV:
	var rate := 22050
	var length := 1.6
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for k in n:
		var t := float(k) / rate
		var f := 330.0 * pow(0.45, t / length) * (1.0 + 0.015 * sin(TAU * 4.0 * t))
		phase += TAU * f / rate
		var v := sin(phase) + 0.5 * sin(phase * 1.5)
		var env := minf(1.0, t / 0.1) * (1.0 - t / length)
		data.encode_s16(k * 2, int(clampf(v * env * 0.3, -1.0, 1.0) * 32767.0))
	return _wav(data, rate)

static func _wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
