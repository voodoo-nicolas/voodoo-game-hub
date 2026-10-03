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

## Letter tiles: tap in order; Undo takes the last one back. Submits when every tile is used.
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
	var render := func() -> void:
		var parts: Array = []
		for i in letters.size():
			parts.append(str(letters[picked[i]]).to_upper() if i < picked.size() else "_")
		out.text = " ".join(parts)
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
			render.call()
			if picked.size() == letters.size():
				var s := ""
				for k in picked:
					s += str(letters[k])
				v.submit(s))
		tiles.add_child(b)
		btns.append(b)
		v.option_buttons.append(b)
	v.add_child(tiles)
	var undo := Button.new()
	undo.text = "⌫ " + T.t("undo")
	undo.custom_minimum_size = Vector2(240, 64)
	undo.add_theme_font_size_override("font_size", 26)
	style_button(undo, FG2)
	undo.pressed.connect(func():
		if v.done or picked.is_empty():
			return
		btns[picked.pop_back()].disabled = false
		render.call())
	v.add_child(_center(undo))
	render.call()

static func _analogy(v: ItemView, d: Dictionary) -> void:
	_prompt(v, T.t("q_analogy"))
	v.add_child(_label("%s : %s  ::  %s : ?" % [d.a, d.b, d.c], 38, Color.WHITE))
	_mc(v, d.get("options", []), 2)

# ------------------------------------------------------------------ MUS

## Play button; the options unlock once the clip has played. Replays per the
## server (practice / IQ: one replay; Blitz: none, autoplay).
static func _music(v: ItemView, gid: String, d: Dictionary, blitz: bool) -> void:
	match gid:
		"pitch": _prompt(v, T.t("q_pitch"))
		"pitchhl": _prompt(v, T.t("q_pitchhl"))
		"melody": _prompt(v, T.t("q_melody"), T.t("q_melody_sub"))
		_: _prompt(v, T.t("q_chord"))
	var clip: Array = Audio.item_clip(gid, d)
	var player := AudioStreamPlayer.new()
	player.stream = clip[0]
	v.add_child(player)
	var max_plays := int(d.get("replays", 0 if blitz else 1)) + 1
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
		if state.plays >= max_plays or btn.disabled or v.done:
			return
		state.plays += 1
		btn.disabled = true
		status.text = T.t("listening")
		player.play()
		var tw := v.create_tween()
		tw.tween_interval(float(clip[1]) + 0.15)
		tw.tween_callback(func():
			status.text = " "
			if state.plays < max_plays:
				btn.disabled = false
				btn.text = "↻ " + T.t("replay_once")
			else:
				btn.text = T.t("no_replays")
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

static func _face_canvas(p: Dictionary, id: Dictionary, eyes: bool, w: float) -> Control:
	return _canvas(func(ci, sz): Art.face(ci, p, id, Rect2(Vector2.ZERO, sz), eyes), Vector2(w, w * (0.39 if eyes else 1.15)))

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
