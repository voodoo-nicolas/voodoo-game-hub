extends RefCounted

## Builds the on-screen version of one Voodoo IQ item from what the server sends
## (`display`, never the answer) -- a port of each generator's mount() in the
## prototype (docs/voodoo-iq-prototype.html). The view emits `submitted(value)`
## once with what the player answered, in the form the server's checkAnswer
## expects (option index, typed text, tap outcome, timing offset in ms), and
## `timer_ready` when an item whose timer waits (digits, blocks, audio, motor
## trials) is ready to be answered.

const T = preload("res://scripts/games/voodoo_iq/voodoo_iq_text.gd")
const Art = preload("res://scripts/games/voodoo_iq/voodoo_iq_art.gd")
const Audio = preload("res://scripts/games/voodoo_iq/voodoo_iq_audio.gd")

const BG := Color("#07070C")
const PANEL := Color("#12121C")
const FG := Color("#EDEDF5")
const FG2 := Color("#A8A8C0")
## Content width, set by the game from the real screen before building (Large text
## leaves ~600 of the 720-wide design, so nothing may assume 680).
static var W := 680.0
## The highest generator version this pack can draw, sent with session-start
## (server engine.ts GV). 1 = the second LOG set, 2 = the second SPA set, 3 = the
## second LIN set (2026-10-25). Raise it only together with the views for the
## generators that version adds.
const GV := 3

class ItemView extends VBoxContainer:
	signal submitted(value)
	signal timer_ready
	var done := false
	var accent := Color.WHITE
	var option_buttons: Array = []
	## the runner's keyboard / hidden handling can ask for this
	func submit(v) -> void:
		if done:
			return
		done = true
		for b in option_buttons:
			b.disabled = true
		submitted.emit(v)
	func ready_now() -> void:
		timer_ready.emit()

# ------------------------------------------------------------------ public

static func build(item: Dictionary, blitz: bool) -> ItemView:
	var v := ItemView.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.accent = T.sec_color(str(item.get("sec", "LOG")))
	var d: Dictionary = item.get("display", {})
	var gid := str(item.get("gid", ""))
	match gid:
		"series": _series(v, d)
		"matrix": _matrix(v, d)
		"digits": _digits(v, d)
		"arith": _arith(v, d)
		"topview": _topview(v, d)
		"rotation": _rotation(v, d)
		"rotquick": _rotquick(v, d)
		"corsi": _corsi(v, d)
		"oddword", "oddquick": _oddword(v, d)
		"anagram": _anagram(v, d)
		"analogy": _analogy(v, d)
		"pitch", "pitchhl", "melody", "chord": _music(v, gid, d, blitz)
		"natclass": _natclass(v, d)
		"natodd", "natquick": _natodd(v, d)
		"tap": _tap(v, d)
		"timing": _timing(v, d)
		"face", "facequick": _face(v, d)
		"faceodd": _faceodd(v, d)
		"syll", "syllquick": _syll(v, d)
		"fallacy": _fallacy(v, d)
		"symsum": _symsum(v, d)
		"scales": _scales(v, d)
		"ordering": _ordering(v, d)
		"letters": _letters(v, d)
		"funcmachine": _funcmachine(v, d)
		"operators": _operators(v, d)
		"fraccmp": _fraccmp(v, d)
		"wordprob": _wordprob(v, d)
		"dice": _dice(v, d)
		"sudoku": _sudoku(v, d)
		"paperfold": _paperfold(v, d)
		"cubenet": _cubenet(v, d)
		"gears": _gears(v, d)
		"mirror": _mirror(v, d)
		"countshapes": _countshapes(v, d)
		"cubecount": _cubecount(v, d)
		"direction": _direction(v, d)
		"pieces": _pieces(v, d)
		"remote": _remote(v, d)
		"synonym": _synonym(v, d)
		"cloze": _cloze(v, d)
		"unscramble": _unscramble(v, d)
		"proverb": _proverb(v, d)
		"inference": _inference(v, d)
		_:
			v.add_child(_label("?", 30, FG))
	return v

# ------------------------------------------------------------------ widgets

static func _label(text: String, size: int, color: Color, width: float = -1.0, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	if width < 0.0:
		width = W
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l

static func _prompt(v: ItemView, text: String, sub: String = "") -> void:
	v.add_child(_label(text, 30, FG))
	if sub != "":
		v.add_child(_label(sub, 22, FG2))

static func box_style(bg: Color, border: Color, width: int = 2, radius: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func style_button(b: BaseButton, accent: Color) -> void:
	b.add_theme_stylebox_override("normal", box_style(PANEL, Color(accent, 0.55)))
	b.add_theme_stylebox_override("hover", box_style(PANEL.lightened(0.06), accent))
	b.add_theme_stylebox_override("pressed", box_style(Color(accent, 0.35), accent, 3))
	b.add_theme_stylebox_override("focus", box_style(PANEL, accent, 3))
	b.add_theme_stylebox_override("disabled", box_style(PANEL.darkened(0.2), Color(accent, 0.25)))
	b.add_theme_color_override("font_color", FG)
	b.add_theme_color_override("font_disabled_color", Color(FG, 0.5))
	b.add_theme_color_override("font_hover_color", FG)
	b.add_theme_color_override("font_pressed_color", FG)

## Multiple choice. `opts` are Strings or Controls (drawings). Letters A..H as in
## the prototype unless no_letter. Each pick submits its index.
static func _mc(v: ItemView, opts: Array, cols: int, no_letter := false, min_h := 76.0) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var letters := str(T.data().get("LETTERS", "ABCDEFGH"))
	var cw := (W - 10.0 * (cols - 1)) / cols
	for i in opts.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(cw, min_h)
		b.add_theme_font_size_override("font_size", 26)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		style_button(b, v.accent)
		var o = opts[i]
		if o is String:
			b.text = (letters[i] + "   " if not no_letter else "") + o
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT if cols == 1 else HORIZONTAL_ALIGNMENT_CENTER
		else:
			var c: Control = o
			c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			c.offset_left = 22 if not no_letter else 6
			c.offset_right = -6
			c.offset_top = 6
			c.offset_bottom = -6
			b.add_child(c)
			if not no_letter:
				var k := Label.new()
				k.text = letters[i]
				k.add_theme_font_size_override("font_size", 18)
				k.add_theme_color_override("font_color", FG2)
				k.position = Vector2(6, 2)
				b.add_child(k)
		b.pressed.connect(v.submit.bind(i))
		v.option_buttons.append(b)
		grid.add_child(b)
	v.add_child(grid)
	return grid

static func _canvas(paint: Callable, size: Vector2) -> Control:
	return Art.canvas(paint, size)

static func _center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc

## Numeric keypad (prototype numPad): fixed_len shows slots and submits when full
## via OK; neg adds a ± key.
static func _numpad(v: ItemView, neg := false, fixed_len := 0, max_len := 7) -> void:
	var disp := _label(" ", 54, FG)
	var state := {"v": ""}
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 10)
	pad.add_theme_constant_override("v_separation", 10)
	var upd := func() -> void:
		var s: String = state.v
		if fixed_len:
			var parts: Array = []
			for i in fixed_len:
				parts.append(s[i] if i < s.length() else "_")
			disp.text = " ".join(parts)
		else:
			disp.text = s if s != "" else " "
	var press := func(k: String) -> void:
		if v.done:
			return
		var s: String = state.v
		if k == "del":
			s = s.substr(0, maxi(0, s.length() - 1))
		elif k == "neg":
			s = s.substr(1) if s.begins_with("-") else "-" + s
		elif k == "ok":
			if s == "" or s == "-":
				return
			v.submit(s)
			return
		elif s.replace("-", "").length() < (fixed_len if fixed_len else max_len):
			s += k
		state.v = s
		upd.call()
	var keys := ["7", "8", "9", "4", "5", "6", "1", "2", "3", "neg" if neg else "del", "0", "ok"]
	if neg:
		keys.append("del")
	for k in keys:
		var b := Button.new()
		b.text = "⌫" if k == "del" else ("±" if k == "neg" else ("OK" if k == "ok" else k))
		b.custom_minimum_size = Vector2(150, 70)
		b.add_theme_font_size_override("font_size", 32)
		style_button(b, v.accent if k != "ok" else Color("#7dff3a"))
		b.set_meta("sfx", "key")
		b.pressed.connect(press.bind(k))
		v.option_buttons.append(b)
		pad.add_child(b)
	upd.call()
	v.add_child(disp)
	v.add_child(_center(pad))

# ------------------------------------------------------------------ LOG

static func _series(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_series"))
	var parts: Array = []
	for x in d.get("seq", []):
		parts.append(str(int(x)))
	parts.append("?")
	v.add_child(_label(",  ".join(parts), 44, Color.WHITE))
	_numpad(v, true)

static func _matrix(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_matrix"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var cells: Array = d.get("cells", [])
	for i in 9:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", box_style(PANEL, Color(v.accent, 0.5) if i < 8 else v.accent, 2, 8))
		p.custom_minimum_size = Vector2(150, 150)
		if i < 8:
			var cell: Dictionary = cells[i]
			p.add_child(_canvas(func(ci, sz): Art.matrix_cell(ci, cell, Rect2(Vector2.ZERO, sz)), Vector2(130, 130)))
		else:
			p.add_child(_label("?", 64, v.accent, 130))
		grid.add_child(p)
	v.add_child(_center(grid))
	var opts: Array = []
	for o in d.get("options", []):
		var cell: Dictionary = o
		opts.append(_canvas(func(ci, sz): Art.matrix_cell(ci, cell, Rect2(Vector2.ZERO, sz)), Vector2(60, 60)))
	_mc(v, opts, 4, false, 110)

## Shows the digits one at a time (0.7 s wait, 0.75 s each, 0.25 s gap), then the keypad.
static func _digits(v: ItemView, d: Dictionary) -> void:
	var back := bool(d.get("back", false))
	_prompt(v, T.t("q_digits_b") if back else T.t("q_digits_f"))
	if back:
		v.add_child(_label(T.t("backwards"), 30, Color("#FFAE2B")))
	var big := _label("…", 120, Color.WHITE)
	v.add_child(big)
	var ds: Array = d.get("digits", [])
	var tw := v.create_tween()
	tw.tween_interval(0.7)
	for x in ds:
		tw.tween_callback(func(): big.text = str(int(x)))
		tw.tween_interval(0.75)
		tw.tween_callback(func(): big.text = " ")
		tw.tween_interval(0.25)
	tw.tween_callback(func():
		big.queue_free()
		_numpad(v, false, ds.size())
		v.ready_now())

static func _arith(v: ItemView, d: Dictionary) -> void:
	v.add_child(_label("%s %s %s =" % [int(d.a), str(d.op), int(d.b)], 64, Color.WHITE))
	_numpad(v, false, 0, 4)

# ------------------------------------------------------------------ SPA

static func _topview(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_topview"), T.t("q_topview_sub"))
	var stack: Array = d.get("stack", [])
	v.add_child(_center(_canvas(func(ci, sz): Art.tv_iso(ci, stack, Rect2(Vector2.ZERO, sz)), Vector2(minf(460, W), 300))))
	var opts: Array = []
	for o in d.get("options", []):
		var g: Array = o
		opts.append(_canvas(func(ci, sz): Art.tv_grid(ci, g, Rect2(Vector2.ZERO, sz)), Vector2(90, 96)))
	_mc(v, opts, 5, false, 130)

static func _rotation(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_rotation"), T.t("q_rotation_sub"))
	var col := Color("#2EE6A6")
	var target: Array = d.get("target", [])
	v.add_child(_center(_canvas(func(ci, sz): Art.poly(ci, target, Rect2(Vector2.ZERO, sz), col), Vector2(200, 200))))
	var opts: Array = []
	for o in d.get("options", []):
		var cells: Array = o
		opts.append(_canvas(func(ci, sz): Art.poly(ci, cells, Rect2(Vector2.ZERO, sz), col), Vector2(110, 110)))
	_mc(v, opts, 4, false, 140)

static func _rotquick(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_rotquick"))
	var col := Color("#2EE6A6")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	for key in ["left", "right"]:
		var cells: Array = d.get(key, [])
		row.add_child(_canvas(func(ci, sz): Art.poly(ci, cells, Rect2(Vector2.ZERO, sz), col), Vector2(200, 200)))
	v.add_child(row)
	_mc(v, [T.t("same_rotated"), T.t("mirror")], 2)

## Corsi blocks: the sequence lights up (0.8 s wait, 0.65 s lit, 0.25 s gap), then the
## player taps the same order; the answer is the tapped block indexes as a string.
static func _corsi(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_corsi"))
	var status := _label(T.t("watch"), 24, FG2)
	v.add_child(status)
	var arena := Control.new()
	arena.custom_minimum_size = Vector2(W, 560)
	v.add_child(arena)
	var pos: Array = T.data().get("CORSI_POS", [])
	var seq: Array = d.get("seq", [])
	var blocks: Array = []
	var taps: Array = []
	var bs := 96.0
	for i in pos.size():
		var b := Button.new()
		b.position = Vector2(float(pos[i][0]) * 0.84 * W, float(pos[i][1]) * 0.84 * 560)
		b.size = Vector2(bs, bs)
		b.custom_minimum_size = Vector2(bs, bs)
		b.disabled = true
		b.add_theme_stylebox_override("disabled", box_style(Color("#2A2A3E"), Color("#55557A"), 2, 10))
		style_button(b, v.accent)
		b.pressed.connect(func():
			if v.done or taps.size() >= seq.size():
				return
			taps.append(i)
			if taps.size() == seq.size():
				var s := ""
				for x in taps:
					s += str(x)
				v.submit(s))
		arena.add_child(b)
		blocks.append(b)
	var lit := box_style(v.accent, Color.WHITE, 3, 10)
	var tw := v.create_tween()
	tw.tween_interval(0.8)
	for x in seq:
		var b: Button = blocks[int(x)]
		tw.tween_callback(func(): b.add_theme_stylebox_override("disabled", lit))
		tw.tween_interval(0.65)
		tw.tween_callback(func(): b.add_theme_stylebox_override("disabled", box_style(Color("#2A2A3E"), Color("#55557A"), 2, 10)))
		tw.tween_interval(0.25)
	tw.tween_callback(func():
		status.text = T.t("your_turn")
		for b in blocks:
			b.disabled = false
		v.ready_now())

# ------------------------------------------------------------------ LIN

static func _oddword(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_oddword"))
	_mc(v, d.get("words", []), 1)

## Letter tiles: tap in order; Undo takes the last one back (also after every tile
## is placed); the player confirms with Submit.
static func _anagram(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_anagram"))
	var letters: Array = d.get("letters", [])
	var out := _label(" ", 52, Color.WHITE)
	v.add_child(out)
	var picked: Array = []
	var tiles := HFlowContainer.new()
	tiles.alignment = FlowContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("h_separation", 8)
	tiles.add_theme_constant_override("v_separation", 8)
	var btns: Array = []
	var submit_btn := Button.new()
	var render := func() -> void:
		var parts: Array = []
		for i in letters.size():
			parts.append(str(letters[picked[i]]).to_upper() if i < picked.size() else "_")
		out.text = " ".join(parts)
		submit_btn.disabled = picked.size() != letters.size()
	for i in letters.size():
		var b := Button.new()
		b.text = str(letters[i]).to_upper()
		b.custom_minimum_size = Vector2(70, 80)
		b.add_theme_font_size_override("font_size", 36)
		style_button(b, v.accent)
		b.set_meta("sfx", "key")
		b.pressed.connect(func():
			if v.done or b.disabled:
				return
			picked.append(i)
			b.disabled = true
			render.call())
		tiles.add_child(b)
		btns.append(b)
		v.option_buttons.append(b)
	v.add_child(tiles)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var undo := Button.new()
	undo.text = "⌫ " + T.t("undo")
	undo.custom_minimum_size = Vector2(200, 64)
	undo.add_theme_font_size_override("font_size", 26)
	style_button(undo, FG2)
	undo.pressed.connect(func():
		if v.done or picked.is_empty():
			return
		btns[picked.pop_back()].disabled = false
		render.call())
	row.add_child(undo)
	submit_btn.text = "✓ " + TranslationServer.translate("Submit")
	submit_btn.custom_minimum_size = Vector2(200, 64)
	submit_btn.add_theme_font_size_override("font_size", 26)
	style_button(submit_btn, v.accent)
	submit_btn.pressed.connect(func():
		if v.done or picked.size() != letters.size():
			return
		var s := ""
		for k in picked:
			s += str(letters[k])
		v.submit(s))
	row.add_child(submit_btn)
	v.add_child(row)
	v.option_buttons.append(undo)
	v.option_buttons.append(submit_btn)
	render.call()

static func _analogy(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_analogy"))
	v.add_child(_label("%s : %s  ::  %s : ?" % [d.a, d.b, d.c], 38, Color.WHITE))
	_mc(v, d.get("options", []), 2)

# ------------------------------------------------------------------ MUS

## Play button; the options unlock once the clip has played. Replays per the
## server (practice / IQ: one replay; Blitz: none, autoplay).
static func _music(v: ItemView, gid: String, d: Dictionary, _blitz: bool) -> void:
	match gid:
		"pitch": _prompt(v, T.t("q_pitch"))
		"pitchhl": _prompt(v, T.t("q_pitchhl"))
		"melody": _prompt(v, T.t("q_melody"), T.t("q_melody_sub"))
		_: _prompt(v, T.t("q_chord"))
	var clip: Array = Audio.item_clip(gid, d)
	var player := AudioStreamPlayer.new()
	player.stream = clip[0]
	v.add_child(player)
	# Replay as often as you like (owner, 2026-10-25), in the test and the Speed Round
	# (where it costs time). The server still sends the prototype's `replays` count.
	var state := {"plays": 0, "ready": false}
	var btn := Button.new()
	btn.text = "▶ " + T.t("play")
	btn.custom_minimum_size = Vector2(320, 84)
	btn.add_theme_font_size_override("font_size", 32)
	btn.set_meta("sfx", "")
	style_button(btn, v.accent)
	var status := _label(" ", 22, FG2)
	v.add_child(_center(btn))
	v.add_child(status)
	var opts: Array = []
	var cols := 4
	var no_letter := false
	match gid:
		"pitch":
			opts = [T.t("first"), T.t("second"), T.t("third")]
			cols = 3
		"pitchhl":
			opts = [T.t("higher"), T.t("lower")]
			cols = 2
		"melody":
			var n: int = d.get("notes1", []).size()
			for i in n:
				opts.append(T.t("note") + " " + str(i + 1))
			cols = mini(n, 5)
			no_letter = true
		_:
			opts = ["1", "2", "3", "4"]
			no_letter = true
	_mc(v, opts, cols, no_letter)
	for b in v.option_buttons:
		b.disabled = true
	var play := func() -> void:
		if btn.disabled or v.done:
			return
		state.plays += 1
		btn.disabled = true
		status.text = T.t("listening")
		player.play()
		var tw := v.create_tween()
		tw.tween_interval(float(clip[1]) + 0.15)
		tw.tween_callback(func():
			status.text = " "
			btn.disabled = v.done
			btn.text = "↻ " + T.t("replay_any")
			if not state.ready:
				state.ready = true
				for b in v.option_buttons:
					b.disabled = v.done
				v.ready_now())
	btn.pressed.connect(play)
	if bool(d.get("autoplay", false)) or gid == "pitchhl":
		var tw := v.create_tween()
		tw.tween_interval(0.25)
		tw.tween_callback(play)

# ------------------------------------------------------------------ NAT

static func _creature(x: Array, size: float) -> Control:
	return _canvas(func(ci, sz): Art.creature(ci, x, Rect2(Vector2.ZERO, sz)), Vector2(size, size))

static func _natclass(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_natclass"), T.t("q_natclass_sub"))
	var letters := str(T.data().get("LETTERS", "ABC"))
	var fams: Array = d.get("families", [])
	for i in fams.size():
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", box_style(PANEL, Color(v.accent, 0.4), 2, 10))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lab := _label(T.t("family") + " " + letters[i], 22, FG, 100)
		lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lab)
		for c in fams[i]:
			row.add_child(_creature(c, 92))
		p.add_child(row)
		v.add_child(p)
	v.add_child(_label(T.t("new_creature"), 22, FG2))
	var q: Array = d.get("query", [])
	v.add_child(_center(_creature(q, 170)))
	var opts: Array = []
	for i in 3:
		opts.append(T.t("family") + " " + letters[i])
	_mc(v, opts, 3, true)

static func _natodd(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_natodd"))
	var opts: Array = []
	for c in d.get("creatures", []):
		opts.append(_creature(c, 100))
	_mc(v, opts, 3, false, 150)

# ------------------------------------------------------------------ KIN

## Reaction tap: tapping the arena before the target appears is "early"; the target
## must be hit within its window ("slow" otherwise); missing it is "miss".
class TapArena extends Control:
	var view
	var window_ms := 1000
	var size_px := 60.0
	var wait_ms := 800
	var px := 0.5
	var py := 0.5
	var shown_at := 0
	var start_at := 0
	var target := Rect2()
	var result := ""
	func _ready() -> void:
		start_at = Time.get_ticks_msec()
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _process(_dt: float) -> void:
		if result != "":
			return
		var now := Time.get_ticks_msec()
		if shown_at == 0 and now - start_at >= wait_ms:
			shown_at = now
			target = Rect2(px * (size.x - size_px), py * (size.y - size_px), size_px, size_px)
			view.ready_now()
			queue_redraw()
		elif shown_at and now - shown_at > window_ms:
			_finish("slow")
	func _gui_input(e: InputEvent) -> void:
		if result != "" or not (e is InputEventMouseButton and e.pressed):
			return
		accept_event()
		if shown_at == 0:
			_finish("early")
		elif target.grow(8).has_point(e.position):
			_finish("hit" if Time.get_ticks_msec() - shown_at <= window_ms else "slow")
		else:
			_finish("miss")
	func _finish(r: String) -> void:
		result = r
		queue_redraw()
		view.submit(r)
	func _draw() -> void:
		var good := result == "hit"
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0E0E18"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("#7dff3a") if good else (Color("#ff4f9a") if result != "" else Color("#2A2A3E")), false, 3.0)
		if shown_at and result == "":
			var c := target.get_center()
			draw_circle(c, size_px / 2.0 + 6, Color("#FF8A3D", 0.25))
			draw_circle(c, size_px / 2.0, Color("#FF8A3D"))
			draw_circle(c, size_px / 5.0, Color.WHITE)

static func _tap(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_tap"))
	var a := TapArena.new()
	a.view = v
	a.window_ms = int(d.window)
	a.size_px = float(d.size) * 1.4  # prototype px are CSS px; the design is 720 wide
	a.wait_ms = int(d.wait)
	a.px = float(d.px)
	a.py = float(d.py)
	a.custom_minimum_size = Vector2(W, 520)
	v.add_child(a)

## Timing: a dot travels to the line in `travel` ms; tap anywhere when it crosses.
## Answer = signed ms offset ("early" before it starts, "late" if never tapped).
class TimingArena extends Control:
	var view
	var tol := 60
	var travel := 1400
	var hide_frac := 1.0
	var start_delay := 700
	var created := 0
	var t0 := 0
	var result = null
	var msg := ""
	func _ready() -> void:
		created = Time.get_ticks_msec()
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _process(_dt: float) -> void:
		if result != null:
			return
		var now := Time.get_ticks_msec()
		if t0 == 0 and now - created >= start_delay:
			t0 = now
			view.ready_now()
		if t0 and float(now - t0) / travel > 1.0 + (300.0 + tol) / travel:
			_finish("late")
		queue_redraw()
	func _gui_input(e: InputEvent) -> void:
		if result != null or not (e is InputEventMouseButton and e.pressed):
			return
		accept_event()
		if t0 == 0:
			_finish("early")
		else:
			_finish(float(Time.get_ticks_msec() - (t0 + travel)))
	func _finish(r) -> void:
		result = r
		if r is float:
			msg = ("+" if r > 0 else "") + str(int(round(r))) + " ms"
		queue_redraw()
		var tw := create_tween()
		tw.tween_interval(0.35)
		tw.tween_callback(view.submit.bind(r))
	func _draw() -> void:
		var ok: bool = result is float and absf(result) <= tol
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0E0E18"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("#7dff3a") if ok else (Color("#ff4f9a") if result != null else Color("#2A2A3E")), false, 3.0)
		var line_x := size.x * 0.78
		draw_line(Vector2(line_x, 20), Vector2(line_x, size.y - 20), Color.WHITE, 4.0)
		var p := 0.0
		if t0:
			var now := Time.get_ticks_msec() if result == null else t0 + travel + (int(result) if result is float else 0)
			p = float(now - t0) / travel
		var x := 14.0 + (line_x - 14.0) * p
		var hidden := result == null and p > hide_frac and p < 1.6
		if not hidden:
			draw_circle(Vector2(x, size.y / 2.0), 22, Color("#FF8A3D"))
		if msg != "":
			draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 24), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color.WHITE)

static func _timing(v: ItemView, d: Dictionary) -> void:
	var hide_frac := float(d.get("hideFrac", 1.0))
	_prompt(v, T.t("q_timing"), T.t("q_timing_hide") if hide_frac < 1.0 else "")
	var a := TimingArena.new()
	a.view = v
	a.tol = int(d.tol)
	a.travel = int(d.travel)
	a.hide_frac = hide_frac
	a.start_delay = int(d.startDelay)
	a.custom_minimum_size = Vector2(W, 300)
	v.add_child(a)

# ------------------------------------------------------------------ INT

## Baked into a texture once: a live face Canvas is ~230 draw calls every frame.
static func _face_canvas(p: Dictionary, id: Dictionary, eyes: bool, w: float) -> Control:
	return Art.baked(func(ci, sz): Art.face(ci, p, id, Rect2(Vector2.ZERO, sz), eyes), Vector2(w, w * (0.39 if eyes else 1.15)))

static func _emo_texts(opts: Array) -> Array:
	var out: Array = []
	for e in opts:
		out.append(T.t("emo_" + str(e)))
	return out

static func _face(v: ItemView, d: Dictionary) -> void:
	var eyes := bool(d.get("eyesOnly", false))
	_prompt(v, T.t("q_eyes") if eyes else T.t("q_face"))
	v.add_child(_center(_face_canvas(d.get("params", {}), d.get("face", {}), eyes, minf(520.0, W) if eyes else 280.0)))
	_mc(v, _emo_texts(d.get("options", [])), 2)

static func _faceodd(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_faceodd"))
	var opts: Array = []
	for f in d.get("faces", []):
		opts.append(_face_canvas(f.get("params", {}), f.get("face", {}), false, 140.0))
	_mc(v, opts, 2, false, 220)

# ------------------------------------------------------------------ EXI

static func _syll(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_syll"), T.t("q_syll_sub"))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box_style(PANEL, Color(v.accent, 0.5), 2, 10))
	var col := VBoxContainer.new()
	for s in d.get("premises", []):
		col.add_child(_label(str(s), 28, Color.WHITE, W - 30, HORIZONTAL_ALIGNMENT_LEFT))
	p.add_child(col)
	v.add_child(p)
	var opts: Array = []
	for o in d.get("options", []):
		opts.append(T.t("none_follows") if str(o) == "__none__" else str(o))
	_mc(v, opts, 1)

static func _fallacy(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_fallacy"))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box_style(PANEL, Color(v.accent, 0.5), 2, 10))
	p.add_child(_label("“" + str(d.get("argument", "")) + "”", 26, Color.WHITE, W - 30, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(p)
	var opts: Array = []
	for k in d.get("options", []):
		opts.append(T.t("fal_" + str(k)))
	_mc(v, opts, 1)

# ------------------------------------------------------------------ LOG, second set (gv 1)
# Not in the prototype (server gens/log2.ts). Text from the server is already in the
# player's language; the rest is in voodoo_iq_more.json.

## The four drawn symbols (shape + colour, so colour is never the only cue).
const SYM_COL := [Color("#FF5FA2"), Color("#4FB3FF"), Color("#FFE14D"), Color("#A6F04B"), Color("#FF8A3D"), Color("#B69CFF")]

static func _sym_pts(s: int, c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match s:
		0:
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8)])
		1:
			for i in 32:
				pts.append(c + Vector2(cos(TAU * i / 32.0), sin(TAU * i / 32.0)) * r)
		2:
			var hh := r * 0.85
			pts = PackedVector2Array([c + Vector2(-hh, -hh), c + Vector2(hh, -hh), c + Vector2(hh, hh), c + Vector2(-hh, hh)])
		4:
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)])
		5:
			var t := r * 0.36
			for q in [[-t, -r], [t, -r], [t, -t], [r, -t], [r, t], [t, t], [t, r], [-t, r], [-t, t], [-r, t], [-r, -t], [-t, -t]]:
				pts.append(c + Vector2(q[0], q[1]))
		_:
			for i in 10:
				var rr := r if i % 2 == 0 else r * 0.45
				var a := -PI / 2.0 + PI * i / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts

static func _sym_draw(ci: CanvasItem, s: int, c: Vector2, r: float) -> void:
	var pts := _sym_pts(s, c, r)
	ci.draw_colored_polygon(pts, SYM_COL[s % 6])
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, Color("#07070C"), 2.0, true)

static func _sym(s: int, size: float = 52.0) -> Control:
	return _canvas(func(ci, sz): _sym_draw(ci, s, sz / 2.0, minf(sz.x, sz.y) * 0.42), Vector2(size, size))

## A centred row of symbols and text pieces: ints are symbols, strings are text.
static func _sym_row(parts: Array, font := 40) -> CenterContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for p in parts:
		if p is String:
			var l := _label(p, font, Color.WHITE, 0)
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			l.custom_minimum_size = Vector2.ZERO
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(l)
		else:
			row.add_child(_sym(int(p)))
	return _center(row)

static func _panel_text(v: ItemView, lines: Array, size := 28) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box_style(PANEL, Color(v.accent, 0.5), 2, 10))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	for s in lines:
		col.add_child(_label(str(s), size, Color.WHITE, W - 30, HORIZONTAL_ALIGNMENT_LEFT))
	p.add_child(col)
	v.add_child(p)

static func _symsum(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_symsum"))
	for e in d.get("eqs", []):
		var parts: Array = []
		var t: Array = e.get("t", [])
		for i in t.size():
			parts.append(str(t[i]) if i % 2 else int(t[i]))
		parts.append_array(["=", str(int(e.get("r", 0)))])
		v.add_child(_sym_row(parts))
	v.add_child(_sym_row([int(d.get("ask", 0)), "=", "?"]))
	_numpad(v)

## One balance with shapes on each pan (drawn in a 280 x 110 box, as on the sample page).
static func _scale_draw(ci: CanvasItem, sc: Dictionary, sz: Vector2) -> void:
	var k := minf(sz.x / 280.0, sz.y / 110.0)
	var o := (sz - Vector2(280, 110) * k) / 2.0
	var at := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * k
	ci.draw_colored_polygon(PackedVector2Array([at.call(140, 34), at.call(124, 100), at.call(156, 100)]), Color("#3B3B57"))
	ci.draw_line(at.call(30, 34), at.call(250, 34), Color("#D2D2E2"), 4.0 * k, true)
	for side in [[70.0, sc.get("l", [])], [210.0, sc.get("r", [])]]:
		var cx: float = side[0]
		var items: Array = side[1]
		ci.draw_line(at.call(cx - 40, 34), at.call(cx - 46, 78), Color("#6A6A90"), 1.5, true)
		ci.draw_line(at.call(cx + 40, 34), at.call(cx + 46, 78), Color("#6A6A90"), 1.5, true)
		var pan := PackedVector2Array()
		for i in 13:
			var t := i / 12.0
			pan.append(at.call(cx - 52 + 104 * t, 78 + 36 * t * (1 - t)))
		ci.draw_colored_polygon(pan, Color("#1A1A28"))
		ci.draw_polyline(pan, Color("#D2D2E2"), 2.5, true)
		var n := items.size()
		var w := minf(22.0, 92.0 / maxf(1, n))
		for i in n:
			_sym_draw(ci, int(items[i]), at.call(cx + (i - (n - 1) / 2.0) * w, 66), 9.0 * k)

static func _scales(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_scales"))
	for sc in d.get("scales", []):
		var s: Dictionary = sc
		v.add_child(_center(_canvas(func(ci, sz): _scale_draw(ci, s, sz), Vector2(minf(420.0, W), 150))))
	v.add_child(_sym_row([str(int(d.get("n", 1))) + " ×", int(d.get("sym", 0)), "=", "? ×", int(d.get("unit", 0))]))
	var opts: Array = []
	for o in d.get("options", []):
		opts.append(str(int(o)))
	_mc(v, opts, 4)

static func _ordering(v: ItemView, d: Dictionary) -> void:
	_panel_text(v, d.get("facts", []))
	v.add_child(_label(str(d.get("note", "")), 22, FG2))
	_prompt(v, str(d.get("q", "")))
	var opts: Array = d.get("options", [])
	_mc(v, opts, 2 if opts.size() == 4 else 3)

static func _letters(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_letters"))
	var parts: Array = d.get("seq", []).duplicate()
	parts.append("?")
	v.add_child(_label("   ".join(parts), 44, Color.WHITE))
	_mc(v, d.get("options", []), 4)

static func _funcmachine(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_funcmachine"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	for head in [T.t("fm_in"), "", T.t("fm_out")]:
		grid.add_child(_label(head, 22, FG2, 120))
	var rows: Array = d.get("ex", []).duplicate()
	rows.append([d.get("x", 0), "?"])
	for row in rows:
		var last: bool = str(row[1]) == "?"
		var col := v.accent if last else Color.WHITE
		grid.add_child(_label(str(int(row[0])), 40, col, 120))
		grid.add_child(_label("→", 40, FG2, 60))
		grid.add_child(_label("?" if last else str(int(row[1])), 40, col, 120))
	v.add_child(_center(grid))
	_numpad(v)

static func _operators(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_operators"))
	var nums: Array = d.get("nums", [])
	var parts: Array = []
	for i in nums.size():
		if i:
			parts.append("_")
		parts.append(str(int(nums[i])))
	v.add_child(_label("  ".join(parts) + "  =  " + str(int(d.get("r", 0))), 44, Color.WHITE))
	var opts: Array = []
	for o in d.get("options", []):
		opts.append("   ".join(o))
	_mc(v, opts, 2)

static func _fraccmp(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_fraccmp"))
	var grid := _mc(v, d.get("options", []), 2, true, 140)
	for b in grid.get_children():
		b.add_theme_font_size_override("font_size", 46)

static func _wordprob(v: ItemView, d: Dictionary) -> void:
	_panel_text(v, [d.get("text", "")])
	_prompt(v, T.t("q_wordprob"))
	_numpad(v)

static func _dice(v: ItemView, d: Dictionary) -> void:
	_panel_text(v, [d.get("text", "")])
	_mc(v, d.get("options", []), 4)

static func _sudoku(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_sudoku"))
	var n := int(d.get("n", 4))
	var bh := int(d.get("bh", 2))
	var bw := int(d.get("bw", 2))
	var grid: Array = d.get("grid", [])
	var tgt: Array = d.get("target", [0, 0])
	var accent := v.accent
	var cell := minf(70.0, (minf(W, 520.0) - 8.0) / n)
	var paint := func(ci: CanvasItem, sz: Vector2) -> void:
		var o := (sz - Vector2(cell, cell) * n) / 2.0
		var font := ThemeDB.fallback_font
		for r in n:
			for c in n:
				var rect := Rect2(o + Vector2(c, r) * cell, Vector2(cell, cell))
				var is_t: bool = r == int(tgt[0]) and c == int(tgt[1])
				ci.draw_rect(rect, Color(accent, 0.3) if is_t else PANEL)
				ci.draw_rect(rect, Color("#3B3B57"), false, 1.0)
				var val := int(grid[r][c])
				var txt := "?" if is_t else (str(val) if val else "")
				if txt != "":
					ci.draw_string(font, rect.position + Vector2(0, cell * 0.7), txt, HORIZONTAL_ALIGNMENT_CENTER, cell, int(cell * 0.55), accent if is_t else Color.WHITE)
		for r in range(0, n + 1, bh):
			ci.draw_line(o + Vector2(0, r * cell), o + Vector2(n * cell, r * cell), Color("#A9A9C4"), 3.0)
		for c in range(0, n + 1, bw):
			ci.draw_line(o + Vector2(c * cell, 0), o + Vector2(c * cell, n * cell), Color("#A9A9C4"), 3.0)
	v.add_child(_center(_canvas(paint, Vector2(cell * n + 8, cell * n + 8))))
	var opts: Array = []
	for i in n:
		opts.append(str(i + 1))
	_mc(v, opts, n if n <= 4 else 3, true)

# ------------------------------------------------------------------ SPA, second set (gv 2)
# Not in the prototype (server gens/spa2.ts).

const PAPER := Color("#F2F2F7")
const SPA_FILL := Color("#2EE6A6")

## A G x G sheet in `rect`: the cells of `reg` ([r0, r1, c0, c1]; a triangle when `tri`)
## drawn solid, the rest faint, and `holes` ([row, col]) punched.
static func _sheet(ci: CanvasItem, rect: Rect2, g: int, reg: Array, tri: bool, holes: Array) -> void:
	var cs := rect.size.x / g
	ci.draw_rect(rect, Color(PAPER, 0.12))
	ci.draw_rect(rect, Color(PAPER, 0.35), false, 1.0)
	if tri:
		ci.draw_colored_polygon(PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end]), PAPER)
	else:
		var r := Rect2(rect.position + Vector2(int(reg[2]), int(reg[0])) * cs, Vector2(int(reg[3]) - int(reg[2]) + 1, int(reg[1]) - int(reg[0]) + 1) * cs)
		ci.draw_rect(r, PAPER)
	for h in holes:
		ci.draw_circle(rect.position + (Vector2(int(h[1]), int(h[0])) + Vector2(0.5, 0.5)) * cs, cs * 0.18, Color("#07070C"))

static func _fold_step(reg: Array, f: String) -> Array:
	var r0 := int(reg[0])
	var r1 := int(reg[1])
	var c0 := int(reg[2])
	var c1 := int(reg[3])
	match f:
		"L": return [r0, r1, (c0 + c1 + 1) / 2, c1]
		"R": return [r0, r1, c0, (c0 + c1 + 1) / 2 - 1]
		"T": return [(r0 + r1 + 1) / 2, r1, c0, c1]
		"B": return [r0, (r0 + r1 + 1) / 2 - 1, c0, c1]
	return reg

static func _paperfold(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_paperfold"))
	var g := int(d.get("g", 4))
	var folds: Array = d.get("folds", [])
	var accent := v.accent
	var size := minf(130.0, (W - 20.0) / (folds.size() + 1) - 14.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var reg: Array = [0, g - 1, 0, g - 1]
	var tri := false
	for f in folds:
		var before := reg.duplicate()
		var was_tri := tri
		var fs: String = str(f)
		var step_paint := func(ci: CanvasItem, sz: Vector2) -> void:
			var rect := Rect2(Vector2(4, 4), Vector2(sz.x - 8, sz.x - 8))
			_sheet(ci, rect, g, before, was_tri, [])
			var cs := rect.size.x / g
			var a := Vector2.ZERO
			var b := Vector2.ZERO
			var from := Vector2.ZERO
			var to := Vector2.ZERO
			var r0 := float(before[0])
			var r1 := float(before[1]) + 1
			var c0 := float(before[2])
			var c1 := float(before[3]) + 1
			match fs:
				"L", "R":
					var m := (c0 + c1) / 2.0
					a = Vector2(m, r0)
					b = Vector2(m, r1)
					from = Vector2((c0 + m) / 2.0 if fs == "L" else (m + c1) / 2.0, (r0 + r1) / 2.0)
					to = Vector2((m + c1) / 2.0 if fs == "L" else (c0 + m) / 2.0, (r0 + r1) / 2.0)
				"T", "B":
					var m := (r0 + r1) / 2.0
					a = Vector2(c0, m)
					b = Vector2(c1, m)
					from = Vector2((c0 + c1) / 2.0, (r0 + m) / 2.0 if fs == "T" else (m + r1) / 2.0)
					to = Vector2((c0 + c1) / 2.0, (m + r1) / 2.0 if fs == "T" else (r0 + m) / 2.0)
				_:
					a = Vector2(0, 0)
					b = Vector2(g, g)
					from = Vector2(g * 0.25, g * 0.75)
					to = Vector2(g * 0.75, g * 0.25)
			ci.draw_dashed_line(rect.position + a * cs, rect.position + b * cs, accent, 3.0, 8.0)
			var p0: Vector2 = rect.position + from * cs
			var p1: Vector2 = rect.position + to * cs
			ci.draw_line(p0, p1, Color("#FF8A3D"), 4.0, true)
			var dir := (p1 - p0).normalized()
			ci.draw_colored_polygon(PackedVector2Array([p1 + dir * 6, p1 - dir * 8 + dir.orthogonal() * 7, p1 - dir * 8 - dir.orthogonal() * 7]), Color("#FF8A3D"))
		row.add_child(_canvas(step_paint, Vector2(size, size)))
		if fs == "D":
			tri = true
		else:
			reg = _fold_step(reg, fs)
	var after := reg.duplicate()
	var holes: Array = d.get("holes", [])
	var tri_end := tri
	row.add_child(_canvas(func(ci, sz): _sheet(ci, Rect2(Vector2(4, 4), Vector2(sz.x - 8, sz.x - 8)), g, after, tri_end, holes), Vector2(size, size)))
	v.add_child(_center(row))
	v.add_child(_label(T.t("q_paperfold_sub"), 22, FG2))
	var opts: Array = []
	for o in d.get("options", []):
		var hs: Array = o
		var opt_paint := func(ci: CanvasItem, sz: Vector2) -> void:
			var s := minf(sz.x, sz.y) - 8
			_sheet(ci, Rect2((sz - Vector2(s, s)) / 2.0, Vector2(s, s)), g, [0, g - 1, 0, g - 1], false, hs)
		opts.append(_canvas(opt_paint, Vector2(100, 100)))
	_mc(v, opts, 4, false, 130)

static func _cubenet(v: ItemView, d: Dictionary) -> void:
	var net: Array = d.get("net", [])
	var corner := str(d.get("ask", "")) == "corner"
	if corner:
		_prompt(v, T.t("q_cubenet_corner"))
	else:
		v.add_child(_sym_row([T.t("q_cubenet_opp"), int(d.get("mark", 0)), "?"], 30))
	var rows := 0
	var cols := 0
	for c in net:
		rows = maxi(rows, int(c[0]) + 1)
		cols = maxi(cols, int(c[1]) + 1)
	var cell := minf(70.0, (minf(W, 480.0) - 8.0) / maxi(rows, cols))
	var accent := v.accent
	var net_paint := func(ci: CanvasItem, _sz: Vector2) -> void:
		for c in net:
			var r := Rect2(Vector2(4 + int(c[1]) * cell, 4 + int(c[0]) * cell), Vector2(cell, cell))
			ci.draw_rect(r, PANEL)
			ci.draw_rect(r, accent, false, 2.0)
			_sym_draw(ci, int(c[2]), r.get_center(), cell * 0.32)
	v.add_child(_center(_canvas(net_paint, Vector2(cols * cell + 8, rows * cell + 8))))
	var opts: Array = []
	for o in d.get("options", []):
		var syms: Array = o if o is Array else [o]
		var sym_paint := func(ci: CanvasItem, sz: Vector2) -> void:
			var n := syms.size()
			var step := minf(sz.x / n, sz.y)
			for i in n:
				_sym_draw(ci, int(syms[i]), Vector2(sz.x / 2.0 + (i - (n - 1) / 2.0) * step, sz.y / 2.0), step * 0.36)
		opts.append(_canvas(sym_paint, Vector2(120 if corner else 70, 60)))
	_mc(v, opts, 2 if corner else 4, false, 96)

static func _gears(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_gears"))
	var gears: Array = d.get("gears", [])
	var links: Array = d.get("links", [])
	var target := int(d.get("target", 0))
	var accent := v.accent
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for g in gears:
		var c := Vector2(float(g.x), float(g.y))
		lo = Vector2(minf(lo.x, c.x - float(g.r)), minf(lo.y, c.y - float(g.r)))
		hi = Vector2(maxf(hi.x, c.x + float(g.r)), maxf(hi.y, c.y + float(g.r)))
	var span := hi - lo
	var box := Vector2(minf(W, 600.0), minf(360.0, minf(W, 600.0) * span.y / span.x + 40))
	var gear_paint := func(ci: CanvasItem, sz: Vector2) -> void:
		var k := minf((sz.x - 30) / span.x, (sz.y - 30) / span.y)
		var o := (sz - span * k) / 2.0 - lo * k
		var at := func(g) -> Vector2: return o + Vector2(float(g.x), float(g.y)) * k
		for l in links:
			if str(l.t) == "mesh":
				continue
			var a: Dictionary = gears[int(l.a)]
			var b: Dictionary = gears[int(l.b)]
			var pa: Vector2 = at.call(a)
			var pb: Vector2 = at.call(b)
			var ra := float(a.r) * k * 0.8
			var rb := float(b.r) * k * 0.8
			var nrm := (pb - pa).normalized().orthogonal()
			var col := Color("#A9A9C4")
			if str(l.t) == "belt":
				ci.draw_line(pa + nrm * ra, pb + nrm * rb, col, 3.0, true)
				ci.draw_line(pa - nrm * ra, pb - nrm * rb, col, 3.0, true)
			else:
				ci.draw_line(pa + nrm * ra, pb - nrm * rb, col, 3.0, true)
				ci.draw_line(pa - nrm * ra, pb + nrm * rb, col, 3.0, true)
		for i in gears.size():
			var g: Dictionary = gears[i]
			var c: Vector2 = at.call(g)
			var r := float(g.r) * k
			var teeth := maxi(8, int(round(float(g.r) * 12)))
			var pts := PackedVector2Array()
			for t in teeth * 4:
				var ang := TAU * t / (teeth * 4.0)
				var rr := r * (1.0 if (t % 4) < 2 else 0.84)
				pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
			var body := Color("#3A3A52") if i != target else Color(accent, 0.45)
			ci.draw_colored_polygon(pts, body)
			var closed := pts.duplicate()
			closed.append(pts[0])
			ci.draw_polyline(closed, Color("#A9A9C4"), 2.0, true)
			ci.draw_circle(c, r * 0.18, Color("#A9A9C4"))
			if i == target:
				ci.draw_string(ThemeDB.fallback_font, c + Vector2(-r, r * 0.35), "?", HORIZONTAL_ALIGNMENT_CENTER, r * 2, int(r * 0.9), Color.WHITE)
		var g0: Dictionary = gears[0]
		var c0: Vector2 = at.call(g0)
		var ar := float(g0.r) * k * 0.6
		ci.draw_arc(c0, ar, -PI * 0.9, -PI * 0.1, 16, Color("#FF8A3D"), 5.0, true)
		var tip := c0 + Vector2(cos(-PI * 0.1), sin(-PI * 0.1)) * ar
		ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(8, 4), tip + Vector2(-6, -8), tip + Vector2(-8, 8)]), Color("#FF8A3D"))
	v.add_child(_center(_canvas(gear_paint, box)))
	var opts: Array = []
	for o in d.get("options", []):
		opts.append(T.t("gear_" + str(o)))
	_mc(v, opts, 1 if opts.size() == 3 else 2)

static func _mirror(v: ItemView, d: Dictionary) -> void:
	var axis := str(d.get("axis", "v"))
	_prompt(v, T.t("q_mirror"))
	var shape: Array = d.get("shape", [])
	var accent := v.accent
	var mirror_paint := func(ci: CanvasItem, sz: Vector2) -> void:
		var s := sz.y - 8
		Art.poly(ci, shape, Rect2(Vector2(4, 4), Vector2(s, s)), SPA_FILL)
		match axis:
			"v": ci.draw_dashed_line(Vector2(s + 18, 0), Vector2(s + 18, sz.y), accent, 3.0, 8.0)
			"h": ci.draw_dashed_line(Vector2(0, sz.y - 2), Vector2(s + 8, sz.y - 2), accent, 3.0, 8.0)
			_: ci.draw_dashed_line(Vector2(0, 0), Vector2(s + 8, s + 8), accent, 3.0, 8.0)
	v.add_child(_center(_canvas(mirror_paint, Vector2(220, 180))))
	v.add_child(_label(T.t("mirror_" + axis), 22, FG2))
	var opts: Array = []
	for o in d.get("options", []):
		var cells: Array = o
		opts.append(_canvas(func(ci, sz): Art.poly(ci, cells, Rect2(Vector2.ZERO, sz), SPA_FILL), Vector2(100, 100)))
	_mc(v, opts, 4, false, 130)

static func _countshapes(v: ItemView, d: Dictionary) -> void:
	var fan := str(d.get("kind", "")) == "fan"
	_prompt(v, T.t("q_count_tri") if fan else T.t("q_count_rect"))
	var accent := v.accent
	var sz0 := Vector2(minf(W, 420.0), 300 if fan else 260)
	var count_paint := func(ci: CanvasItem, sz: Vector2) -> void:
		var col := accent
		if fan:
			var top := Vector2(sz.x / 2.0, 10)
			var bl := Vector2(14, sz.y - 10)
			var br := Vector2(sz.x - 14, sz.y - 10)
			for p in [bl, br]:
				ci.draw_line(top, p, col, 3.0, true)
			for f in d.get("base", []):
				ci.draw_line(top, bl.lerp(br, float(f)), col, 3.0, true)
			for f in d.get("levels", []) + [1.0]:
				ci.draw_line(top.lerp(bl, float(f)), top.lerp(br, float(f)), col, 3.0, true)
		else:
			var r := Rect2(Vector2(10, 10), sz - Vector2(20, 20))
			ci.draw_rect(r, col, false, 3.0)
			for f in d.get("cols", []):
				ci.draw_line(r.position + Vector2(r.size.x * float(f), 0), r.position + Vector2(r.size.x * float(f), r.size.y), col, 3.0)
			for f in d.get("rows", []):
				ci.draw_line(r.position + Vector2(0, r.size.y * float(f)), r.position + Vector2(r.size.x, r.size.y * float(f)), col, 3.0)
	v.add_child(_center(_canvas(count_paint, sz0)))
	_numpad(v)

static func _cubecount(v: ItemView, d: Dictionary) -> void:
	var fill := str(d.get("ask", "")) == "fill"
	_prompt(v, T.t("q_cubefill") if fill else T.t("q_cubecount"), T.t("q_cubecount_sub"))
	var stack: Array = []
	for row in d.get("heights", []):
		var r: Array = []
		for hgt in row:
			var col: Array = []
			for z in int(hgt):
				col.append(1)
			r.append(col)
		stack.append(r)
	v.add_child(_center(_canvas(func(ci, sz): Art.tv_iso(ci, stack, Rect2(Vector2.ZERO, sz), false), Vector2(minf(460, W), 320))))
	_numpad(v)

static func _direction(v: ItemView, d: Dictionary) -> void:
	_panel_text(v, [d.get("text", "")])
	_mc(v, d.get("options", []), 2)

static func _pieces(v: ItemView, d: Dictionary) -> void:
	var turn := bool(d.get("turn", false))
	_prompt(v, T.t("q_pieces"), T.t("q_pieces_turn") if turn else T.t("q_pieces_slide"))
	var n := int(d.get("n", 3))
	var piece: Array = d.get("piece", [])
	var cell := minf(56.0, 220.0 / n)
	var square_paint := func(ci: CanvasItem, _sz: Vector2) -> void:
		for x in n:
			for y in n:
				var r := Rect2(Vector2(4 + x * cell, 4 + y * cell), Vector2(cell, cell))
				var filled := false
				for p in piece:
					if int(p[0]) == x and int(p[1]) == y:
						filled = true
				ci.draw_rect(r, Color("#4FB3FF") if filled else Color("#1A1A28"))
				ci.draw_rect(r, Color("#05050A") if filled else Color("#3B3B57"), false, 2.0 if filled else 1.0)
		ci.draw_rect(Rect2(Vector2(4, 4), Vector2(n, n) * cell), Color("#A9A9C4"), false, 3.0)
	v.add_child(_center(_canvas(square_paint, Vector2(n * cell + 8, n * cell + 8))))
	var opts: Array = []
	for o in d.get("options", []):
		var cells: Array = o
		opts.append(_canvas(func(ci, sz): Art.poly(ci, cells, Rect2(Vector2.ZERO, sz), SPA_FILL), Vector2(100, 100)))
	_mc(v, opts, 4, false, 130)

# ------------------------------------------------------------------ LIN, second set (gv 3)
# Not in the prototype (server gens/lin2.ts; text comes from the server's banks).

static func _remote(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_remote"))
	v.add_child(_label("  ·  ".join(d.get("words", [])), 40, Color.WHITE))
	_mc(v, d.get("options", []), 2)

static func _synonym(v: ItemView, d: Dictionary) -> void:
	var word := str(d.get("word", ""))
	_prompt(v, T.t("q_syn_" + str(d.get("kind", "same"))))
	v.add_child(_label(word.to_upper(), 44, v.accent))
	_mc(v, d.get("options", []), 2)

static func _cloze(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_cloze"))
	_panel_text(v, [str(d.get("sentence", "")).replace("___", "_____")], 30)
	_mc(v, d.get("options", []), 2)

static func _proverb(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_proverb"))
	_panel_text(v, ["“" + str(d.get("saying", "")) + "”"], 30)
	_mc(v, d.get("options", []), 1)

static func _inference(v: ItemView, d: Dictionary) -> void:
	_panel_text(v, [d.get("passage", "")])
	_prompt(v, str(d.get("q", "")))
	_mc(v, d.get("options", []), 1)

## Tap the tiles in order; Undo takes the last one back. Check sends the sentence.
static func _unscramble(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_unscramble"))
	var tiles: Array = d.get("tiles", [])
	var picked: Array = []
	var built := _label(" ", 32, Color.WHITE, W - 30, HORIZONTAL_ALIGNMENT_LEFT)
	var bp := PanelContainer.new()
	bp.add_theme_stylebox_override("panel", box_style(PANEL, Color(v.accent, 0.5), 2, 10))
	bp.custom_minimum_size = Vector2(W, 90)
	bp.add_child(built)
	v.add_child(bp)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	flow.custom_minimum_size = Vector2(W, 0)
	var buttons: Array = []
	var check := Button.new()
	var refresh := func() -> void:
		var words: Array = []
		for i in picked:
			words.append(str(tiles[i]))
		built.text = " ".join(words) if words.size() else " "
		for i in buttons.size():
			buttons[i].disabled = v.done or picked.has(i)
		check.disabled = v.done or picked.size() < tiles.size()
	for i in tiles.size():
		var b := Button.new()
		b.text = str(tiles[i])
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 28)
		style_button(b, v.accent)
		b.pressed.connect(func():
			if not picked.has(i):
				picked.append(i)
			refresh.call())
		buttons.append(b)
		v.option_buttons.append(b)
		flow.add_child(b)
	v.add_child(flow)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var undo := Button.new()
	undo.text = T.t("us_undo")
	undo.custom_minimum_size = Vector2(200, 70)
	undo.add_theme_font_size_override("font_size", 26)
	style_button(undo, v.accent)
	undo.pressed.connect(func():
		if picked.size():
			picked.pop_back()
		refresh.call())
	check.text = T.t("us_check")
	check.custom_minimum_size = Vector2(200, 70)
	check.add_theme_font_size_override("font_size", 26)
	style_button(check, Color("#7dff3a"))
	check.pressed.connect(func():
		var words: Array = []
		for i in picked:
			words.append(str(tiles[i]))
		v.submit(" ".join(words)))
	v.option_buttons.append(undo)
	v.option_buttons.append(check)
	row.add_child(undo)
	row.add_child(check)
	v.add_child(_center(row))
	refresh.call()
