extends Control

## Block Escape -- slide coloured blocks out of the board through the gate of their
## own colour before the clock runs out. Chained blocks wait for N others to leave;
## arrowed blocks only slide one way. 300 Levels (guaranteed solvable, see
## block_escape_gen.gd), a Daily board, and Zen (no clock).
## Helps (shared pool, STANDARDS §17): ⏳ +30 s, 🔨 Hammer (smash one block), 💡 Hint.

## Landing menu style: S10 Bento Grid (docs/MENU_STYLES.md); last two games: S11 Sticker Board
## (arrows), S3 Rail List (hesperia).
const MenuStyles = preload("res://scripts/games/block_escape/menu_styles.gd")
const Engine_ = preload("res://scripts/games/block_escape/block_escape_engine.gd")
const Gen = preload("res://scripts/games/block_escape/block_escape_gen.gd")
const HELP = preload("res://scripts/games/block_escape/block_escape_help.gd")
const HomeKit = preload("res://scripts/games/block_escape/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const I18N_PATH := "res://scripts/games/block_escape/block_escape_i18n.gd"
## Written by tools/block_escape_gen.gd; a level missing here is generated from the same seed.
const LEVELS_PATH := "res://games/block_escape/levels.json"

const SAVE_PATH := "user://block_escape_save.json"
const PROGRESS_PATH := "user://block_escape_progress.json"
const EXTRA_TIME := 30
const ZEN := [["🙂 Easy", 40], ["😐 Normal", 110], ["😈 Hard", 200], ["🤯 Expert", 300]]

## Classic look: bright toy colours on a sky backdrop (original palette).
const SKY := Color("cfe3f7")
const FRAME := Color("4a4f5c")
const FLOOR := Color("9aa3b1")
const INK := Color("1f2a3a")
const TOY := [Color("e8382f"), Color("2f8fe8"), Color("f5b81c"), Color("38b54a"), Color("a64fd8"),
	Color("f07a1a"), Color("f06aa8"), Color("16b5a8")]
const NEON := [Color("ff4f4f"), Color("38b6ff"), Color("ffd23f"), Color("8cff5a"), Color("b36bff"),
	Color("ff8a3d"), Color("ff5fa2"), Color("27e0d0")]
## Colour is never the only cue (STANDARDS §9): each colour also has a mark, on blocks and gates.
const MARKS := ["●", "■", "▲", "◆", "★", "✚", "♥", "⬢"]

var info = null
var home
var engine: Engine_
var bg: ColorRect
var skin: String = "classic"
var title_label: Label
var time_label: Label
var left_label: Label
var feedback_label: Label
var board: Control
var end_dialog: ColorRect
var lose_dialog: ColorRect
var feedback_timer: Timer
var my_buttons: Array = []
var help_btns: Array = []

var mode: String = "levels"  # levels | daily | zen
var level: int = 1
var zen_tier: int = 0
var day: int = 0
var time_left: float = 0.0
var elapsed: float = 0.0
var helps_used: int = 0
var playing: bool = false
var hammer_armed: bool = false
var progress: Dictionary = {}
var levels_cache: Array = []
var puzzle_start: Dictionary = {}

var drag_block: int = -1
var drag_from_px := Vector2.ZERO
var drag_from_pos := Vector2i.ZERO
var vis: Dictionary = {}      # block index -> Vector2 (drawn position, in cells)
var leaving: Array = []       # {cells, color, from: Vector2, dir: Vector2, t}
var hint_block: int = -1
var hint_t: float = 0.0
var smash_t: float = 0.0
var smash_at := Vector2.ZERO
var shake_t: float = 0.0
var warned: bool = false

func _ready() -> void:
	if ResourceLoader.exists(I18N_PATH):
		load(I18N_PATH).install(self)
	Orientation.lock_portrait()
	engine = Engine_.new()
	_load_progress()
	_build_ui()
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("lively", self, 1, 2.0)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
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
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.add_theme_font_size_override("font_size", 30)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	my_buttons.append(pause_btn)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	bar.add_child(title_label)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 34)
	time_label.custom_minimum_size = Vector2(120, 0)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(time_label)

	left_label = Label.new()
	left_label.add_theme_font_size_override("font_size", 22)
	left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(left_label)

	var bm := MarginContainer.new()
	bm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm.add_theme_constant_override("margin_left", 8)
	bm.add_theme_constant_override("margin_right", 8)
	root.add_child(bm)
	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	bm.add_child(board)

	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 24)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size = Vector2(0, 64)
	root.add_child(feedback_label)

	var row_margin := MarginContainer.new()
	row_margin.add_theme_constant_override("margin_bottom", 30)
	row_margin.add_theme_constant_override("margin_left", 12)
	row_margin.add_theme_constant_override("margin_right", 12)
	root.add_child(row_margin)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	row_margin.add_child(actions)
	var time_btn := _button("⏳", _on_help.bind(_help_time))
	var hammer_btn := _button("🔨", _on_help.bind(_help_hammer))
	var hint_btn := _button("💡", _on_help.bind(_help_hint))
	for b in [time_btn, hammer_btn, hint_btn]:
		actions.add_child(b)
	help_btns = [[time_btn, "⏳"], [hammer_btn, "🔨"], [hint_btn, "💡"]]
	actions.add_child(_button(tr("⟲ Retry"), _restart))

	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.timeout.connect(_clear_feedback)
	add_child(feedback_timer)

	end_dialog = UI.build_dialog(tr("All out!"), [
		{"text": tr("Next level"), "action": _next_puzzle},
		{"text": tr("⟲ Play again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)
	lose_dialog = UI.build_dialog(tr("Time's up!"), [
		{"text": tr("⏳ +%d seconds (help)") % EXTRA_TIME, "action": _lose_more_time},
		{"text": tr("⟲ Try again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(lose_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = [
		{"text": "🧱 Levels", "sub": "300 levels against the clock · collect stars", "action": _start_levels},
		{"text": "📅 Daily Challenge", "sub": "One board a day, the same for everyone", "action": _start_daily},
	]
	for i in ZEN.size():
		modes.append({"text": ZEN[i][0], "sub": "Zen · no clock", "row": "zen", "key": "zen" + str(i),
			"action": _start_zen.bind(i)})
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S10 Bento Grid; toy-brick colours.
		"landing": "bento",
		"landing_style": MenuStyles,
		"title_colors": [TOY[0], TOY[2], TOY[1]],
		"landing_colors": [Color("0a1430"), Color("1b2d5c")],
		"menu_color": TOY[1],
		"help": HELP,
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Slide every block out through the gate of its colour. Beat the clock.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [
			{"text": "⏳ More time", "how": "Adds 30 seconds to the clock.", "action": _help_time},
			{"text": "🔨 Hammer", "how": "Tap a block to smash it. It counts as out, so chains count down too.", "action": _help_hammer},
			{"text": "💡 Hint", "how": "Shows a block that can get out right now.", "action": _help_hint},
		],
		"board": "Levels cleared",
		"board_note": "Highest Levels-mode level cleared.",
	})
	add_child(home)
	for hb in help_btns:
		home.track_help_button(hb[0], hb[1])
	if info:
		add_child(info)
	if skin == "classic":
		_set_skin("classic")

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	my_buttons.append(b)
	return b

func _style_buttons() -> void:
	for b in my_buttons:
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			if skin == "classic":
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color("2f74d0").darkened(0.15 if st == "pressed" else 0.0).lightened(0.08 if st == "hover" else 0.0)
				sb.set_corner_radius_all(22)
				sb.border_color = Color("1d4f96")
				sb.set_border_width_all(2)
				sb.border_width_bottom = 6
				b.add_theme_stylebox_override(st, sb)
			else:
				b.remove_theme_stylebox_override(st)
		for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			if skin == "classic":
				b.add_theme_color_override(fc, Color.WHITE)
			else:
				b.remove_theme_color_override(fc)
		if skin == "classic":
			b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
		else:
			b.remove_theme_color_override("font_disabled_color")

# ---------- looks ----------

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = SKY if skin == "classic" else HomeKit.BG
		for ch in bg.get_children():
			ch.visible = skin != "classic"
	for l in [title_label, left_label]:
		if l:
			l.add_theme_color_override("font_color", INK if skin == "classic" else Color.WHITE)
	_style_buttons()
	_update_hud()
	if board:
		board.queue_redraw()

func _classic() -> bool:
	return skin == "classic"

func _col(k: int) -> Color:
	return (TOY if _classic() else NEON)[k % TOY.size()]

func _update_hud() -> void:
	if title_label == null:
		return
	match mode:
		"levels":
			title_label.text = tr("Level %d") % level
		"daily":
			title_label.text = tr("📅 Daily Challenge")
		_:
			title_label.text = tr(ZEN[zen_tier][0])
	if mode == "zen":
		time_label.text = "∞"
	else:
		var t := int(ceil(maxf(time_left, 0.0)))
		time_label.text = "%d:%02d" % [t / 60, t % 60]
	var low := mode != "zen" and time_left <= 10.0 and playing
	var tc := INK if _classic() else Color.WHITE
	if low:
		tc = Color("d62828") if _classic() else Color("ff4f4f")
	time_label.add_theme_color_override("font_color", tc)
	left_label.text = (tr("Blocks left: %d") % engine.left()) if engine.rows > 0 else ""

# ---------- geometry ----------

func _cell() -> float:
	if engine.cols == 0:
		return 1.0
	return minf(board.size.x / (engine.cols + 1.3), board.size.y / (engine.rows + 1.3))

func _origin() -> Vector2:
	var s := _cell()
	var o := Vector2((board.size.x - s * engine.cols) / 2.0, (board.size.y - s * engine.rows) / 2.0)
	if shake_t > 0.0:
		o.x += sin(shake_t * 60.0) * 6.0 * shake_t / 0.25
	return o

func _cell_at(p: Vector2) -> Vector2i:
	var q := (p - _origin()) / _cell()
	return Vector2i(int(floor(q.x)), int(floor(q.y)))

# ---------- drawing ----------

func _draw_board() -> void:
	if engine == null or engine.rows == 0:
		return
	var s := _cell()
	var o := _origin()
	var classic := _classic()
	var fw := s * 0.5  # frame width
	var area := Rect2(o, Vector2(engine.cols * s, engine.rows * s))
	var frame_col := FRAME if classic else Color("12162a")
	_round_rect(area.grow(fw), frame_col, s * 0.35)
	if not classic:
		HomeKit.glow_rect(board, area.grow(fw), HomeKit.CYAN, 2.0, 0.0)
	# gates on the frame: colour + the colour's mark + an arrow out
	var font: Font = ThemeDB.fallback_font
	for g in engine.gates:
		var gr := _gate_rect(g, s, o, fw)
		var gc := _col(int(g.color))
		_round_rect(gr, gc.darkened(0.3), s * 0.12)
		_round_rect(gr.grow(-2.0), gc, s * 0.12)
		var side := int(g.side)
		var d := Vector2(Engine_.DIRS[side])
		var along := Vector2(absf(d.y), absf(d.x))  # direction along the frame
		var span := gr.size.x if side % 2 == 0 else gr.size.y
		_arrow(gr.get_center() + along * span * 0.25, side, s * 0.13, Color(1, 1, 1, 0.9))
		var mark: String = MARKS[int(g.color) % MARKS.size()]
		var fs := int(s * 0.28)
		var mw: float = font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var mc := gr.get_center() - along * span * 0.25
		board.draw_string(font, mc + Vector2(-mw / 2.0, fs * 0.36), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
	# floor + holes
	for y in engine.rows:
		for x in engine.cols:
			var r := Rect2(o + Vector2(x * s, y * s), Vector2(s, s))
			if engine.holes[y * engine.cols + x] == 1:
				_round_rect(r.grow(fw * 0.15), frame_col, s * 0.2)
			else:
				board.draw_rect(r.grow(-1.0), FLOOR if classic else Color(0.1, 0.12, 0.2))
				board.draw_rect(r.grow(-s * 0.08), FLOOR.lightened(0.08) if classic else Color(0.13, 0.15, 0.26))
	for lv in leaving:
		var a := clampf(1.0 - lv.t / 0.35, 0.0, 1.0)
		_draw_block(lv.cells, lv.from + lv.dir * (lv.t / 0.35) * 2.5, int(lv.color), s, o, a, 0, 0)
	for bi in engine.blocks.size():
		var b: Dictionary = engine.blocks[bi]
		if b.gone:
			continue
		var p: Vector2 = vis.get(bi, Vector2(b.pos))
		_draw_block(b.cells, p, int(b.color), s, o, 1.0, int(b.axis), int(b.lock))
		if bi == hint_block and hint_t > 0.0:
			var bb := _block_box(b.cells, p, s, o)
			var hcol := Color.WHITE if classic else HomeKit.GOLD
			board.draw_rect(bb.grow(4.0), Color(hcol, 0.5 + 0.5 * sin(hint_t * 10.0)), false, 6.0)
	if smash_t > 0.0:
		var k := smash_t / 0.4
		for i in 8:
			var ang := TAU * i / 8.0
			board.draw_circle(smash_at + Vector2(cos(ang), sin(ang)) * s * (1.2 - k), s * 0.12 * k, Color(1, 1, 1, k))
	if hammer_armed and playing:
		board.draw_rect(area, Color(1, 0.6, 0.1, 0.12))
		board.draw_rect(area, Color("ff9f1c"), false, 4.0)

func _gate_rect(g: Dictionary, s: float, o: Vector2, fw: float) -> Rect2:
	var a := float(g.start) * s + s * 0.06
	var l := float(g.len) * s - s * 0.12
	match int(g.side):
		0: return Rect2(o + Vector2(a, -fw * 0.92), Vector2(l, fw * 0.84))
		1: return Rect2(o + Vector2(engine.cols * s + fw * 0.08, a), Vector2(fw * 0.84, l))
		2: return Rect2(o + Vector2(a, engine.rows * s + fw * 0.08), Vector2(l, fw * 0.84))
	return Rect2(o + Vector2(-fw * 0.92, a), Vector2(fw * 0.84, l))

func _arrow(c: Vector2, side: int, r: float, col: Color) -> void:
	var d := Vector2(Engine_.DIRS[side])
	var n := Vector2(-d.y, d.x)
	board.draw_colored_polygon(PackedVector2Array([c + d * r, c - d * r * 0.6 + n * r, c - d * r * 0.6 - n * r]), col)

func _block_box(cells: Array, p: Vector2, s: float, o: Vector2) -> Rect2:
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for cc in cells:
		mn = mn.min(Vector2(cc))
		mx = mx.max(Vector2(cc) + Vector2.ONE)
	return Rect2(o + (p + mn) * s, (mx - mn) * s)

## One toy brick: shadow, body (cells joined), a round stud per cell, the colour's
## mark, arrows for one-way blocks, chains + count for locked ones. Original drawing.
func _draw_block(cells: Array, p: Vector2, colour: int, s: float, o: Vector2, alpha: float, axis: int, lock: int) -> void:
	var classic := _classic()
	var col := _col(colour)
	var m := s * 0.05
	var rad := s * 0.2
	for pass_i in 2:  # 0 shadow, 1 body
		for cc in cells:
			var r := Rect2(o + (p + Vector2(cc)) * s, Vector2(s, s)).grow(-m)
			if cells.has(cc + Vector2i(1, 0)):
				r.size.x += m * 2.0
			if cells.has(cc + Vector2i(0, 1)):
				r.size.y += m * 2.0
			if pass_i == 0:
				_round_rect(Rect2(r.position + Vector2(0, s * 0.07), r.size), Color(col.darkened(0.45), alpha), rad)
			else:
				_round_rect(r, Color(col, alpha) if classic else Color(col, 0.22 * alpha), rad)
				if not classic:
					board.draw_rect(r, Color(col, alpha), false, 2.0)
	for cc in cells:
		var c := o + (p + Vector2(cc) + Vector2(0.5, 0.5)) * s
		if classic:
			board.draw_circle(c + Vector2(0, s * 0.03), s * 0.24, Color(col.darkened(0.25), alpha))
			board.draw_circle(c, s * 0.22, Color(col.lightened(0.12), alpha))
			board.draw_circle(c - Vector2(s * 0.06, s * 0.07), s * 0.07, Color(1, 1, 1, 0.35 * alpha))
		else:
			board.draw_arc(c, s * 0.2, 0, TAU, 20, Color(col, 0.7 * alpha), 2.0)
	var box := _block_box(cells, p, s, o)
	var font: Font = ThemeDB.fallback_font
	var fs := int(s * 0.34)
	var c0 := o + (p + Vector2(cells[0]) + Vector2(0.5, 0.5)) * s
	var mark: String = MARKS[colour % MARKS.size()]
	var mw: float = font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	board.draw_string(font, c0 + Vector2(-mw / 2.0, fs * 0.36), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85 * alpha))
	if axis != 0:
		var cen := box.get_center()
		var dirs := [1, 3] if axis == Engine_.AXIS_H else [0, 2]
		var dv := Vector2(Engine_.DIRS[dirs[0]])
		board.draw_line(cen - dv * s * 0.25, cen + dv * s * 0.25, Color(1, 1, 1, 0.95 * alpha), 5.0)
		for d in dirs:
			_arrow(cen + Vector2(Engine_.DIRS[d]) * s * 0.3, d, s * 0.14, Color(1, 1, 1, 0.95 * alpha))
	if lock > 0:
		var chain := Color("cfd3da") if classic else Color("e0e0ff")
		var ins := box.grow(-s * 0.12)
		for seg in [[ins.position, ins.end], [Vector2(ins.end.x, ins.position.y), Vector2(ins.position.x, ins.end.y)]]:
			var a: Vector2 = seg[0]
			var b2: Vector2 = seg[1]
			var n := int(a.distance_to(b2) / (s * 0.16))
			for i in n + 1:
				board.draw_arc(a.lerp(b2, float(i) / maxf(1.0, n)), s * 0.06, 0, TAU, 10, Color(chain.darkened(0.3), alpha), 3.0)
		var cen := box.get_center()
		board.draw_circle(cen, s * 0.26, Color("f5c518"))
		board.draw_arc(cen, s * 0.26, 0, TAU, 24, Color("8a6d00"), 3.0)
		var t := str(lock)
		var tf := int(s * 0.36)
		var tw: float = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tf).x
		board.draw_string(font, cen + Vector2(-tw / 2.0, s * 0.13), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tf, INK)

func _round_rect(r: Rect2, col: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	board.draw_style_box(sb, r)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y * 0.2, 34.0)
	var o := c.size / 2.0 - Vector2(2.5 * k, 2.0 * k)
	var parts := [[0, 0, 2, 2], [2, 0, 2, 1], [0, 2, 1, 2], [3, 1, 1, 3], [1, 2, 2, 1]]
	var cols := [HomeKit.PINK, HomeKit.GOLD, HomeKit.CYAN, HomeKit.LIME, HomeKit.PURPLE]
	HomeKit.glow_rect(c, Rect2(o - Vector2(k, k) * 0.4, Vector2(4.8 * k, 4.8 * k)), Color("9aa3b1"), 2.0, 0.0)
	for i in parts.size():
		var p: Array = parts[i]
		var rect := Rect2(o + Vector2(p[1] * k, p[0] * k), Vector2(p[3] * k, p[2] * k)).grow(-3.0)
		HomeKit.glow_rect(c, rect, cols[i], 2.0, 0.25)
	# a pink gate on the right frame and a pink block sliding out of it
	HomeKit.glow_rect(c, Rect2(o + Vector2(4.4 * k, 0.1 * k), Vector2(0.25 * k, 1.8 * k)), HomeKit.PINK, 3.0, 0.8)
	HomeKit.glow_rect(c, Rect2(o + Vector2(5.0 * k, 0.15 * k), Vector2(1.0 * k, 1.7 * k)), HomeKit.PINK, 2.0, 0.15)

# ---------- input ----------

func _on_board_input(event: InputEvent) -> void:
	if not playing:
		return
	# Mouse events only: phones send touches as emulated mouse too (CLAUDE.md gotcha).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var bi := engine.block_at(_cell_at(event.position))
			if hammer_armed:
				if bi >= 0:
					_smash(bi)
				return
			if bi < 0:
				return
			if not engine.can_move(bi):
				shake_t = 0.25
				_sfx("invalid")
				_feedback(tr("Chained: %d more blocks must get out first.") % int(engine.blocks[bi].lock), _soft())
				board.queue_redraw()
				return
			drag_block = bi
			drag_from_px = event.position
			drag_from_pos = engine.blocks[bi].pos
		else:
			drag_block = -1
	elif event is InputEventMouseMotion and drag_block >= 0:
		_drag_to(event.position)

## Moves the dragged block toward the finger one cell at a time; it stops at the
## first block or wall in the way (trying the other axis first).
func _drag_to(px: Vector2) -> void:
	var bi := drag_block
	var s := _cell()
	var want: Vector2i = drag_from_pos + Vector2i(roundi((px.x - drag_from_px.x) / s), roundi((px.y - drag_from_px.y) / s))
	var guard := 0
	while engine.can_move(bi) and engine.blocks[bi].pos != want and guard < 24:
		guard += 1
		var d: Vector2i = want - engine.blocks[bi].pos
		var order: Array = []
		if absi(d.x) >= absi(d.y):
			order = [1 if d.x > 0 else 3]
			if d.y != 0:
				order.append(2 if d.y > 0 else 0)
		else:
			order = [2 if d.y > 0 else 0]
			if d.x != 0:
				order.append(1 if d.x > 0 else 3)
		var moved := false
		for dir in order:
			if engine.step(bi, dir):
				moved = true
				_sfx("tick")
				break
		if not moved:
			break
		var gi := engine.exit_now(bi)
		if gi >= 0:
			_escape(bi, gi)
			return
	board.queue_redraw()

func _escape(bi: int, gi: int) -> void:
	var b: Dictionary = engine.blocks[bi]
	leaving.append({"cells": b.cells.duplicate(), "color": b.color, "from": vis.get(bi, Vector2(b.pos)),
		"dir": Vector2(Engine_.DIRS[int(engine.gates[gi].side)]), "t": 0.0})
	engine.remove(bi)
	drag_block = -1
	vis.erase(bi)
	if hint_block == bi:
		hint_t = 0.0
	_sfx("whoosh")
	_buzz(20)
	if info:
		info.add("Blocks escaped")
	_after_change()

func _smash(bi: int) -> void:
	hammer_armed = false
	var b: Dictionary = engine.blocks[bi]
	smash_at = _block_box(b.cells, Vector2(b.pos), _cell(), _origin()).get_center()
	smash_t = 0.4
	engine.remove(bi)
	vis.erase(bi)
	_sfx("explode")
	_buzz(40)
	_clear_feedback()
	_after_change()

func _after_change() -> void:
	_update_hud()
	board.queue_redraw()
	if engine.solved():
		_on_solved()
	else:
		_save_game()

# ---------- helps (STANDARDS §17) ----------

func _on_help(action: Callable) -> void:
	if playing:
		home.try_help(action)

func _help_time() -> bool:
	if not playing or mode == "zen":
		return false
	time_left += EXTRA_TIME
	helps_used += 1
	warned = false
	_feedback(tr("+%d seconds!") % EXTRA_TIME, _soft())
	_sfx("powerup")
	_update_hud()
	_save_game()
	return true

func _help_hammer() -> bool:
	if not playing or hammer_armed or engine.solved():
		return false
	hammer_armed = true
	helps_used += 1
	_feedback(tr("🔨 Tap a block to smash it."), _soft(), 0.0)
	_sfx("powerup")
	_save_progress()
	board.queue_redraw()
	return true

func _help_hint() -> bool:
	if not playing or engine.solved():
		return false
	var h := engine.hint()
	if h.is_empty():
		return false
	hint_block = int(h[0])
	hint_t = 3.0
	helps_used += 1
	_sfx("powerup")
	return true

## "Time's up" → ⏳: back into the same board with 30 more seconds.
func _lose_more_time() -> void:
	lose_dialog.visible = false
	playing = true
	if not home.try_help(_help_time):
		playing = false
		lose_dialog.visible = true

# ---------- clock + animation ----------

func _process(delta: float) -> void:
	var redraw := false
	if playing and engine.rows > 0 and not engine.solved():
		elapsed += delta
		if mode != "zen":
			time_left -= delta
			if time_left <= 10.0 and not warned:
				warned = true
				_sfx("notify")
			if time_left <= 0.0:
				_time_up()
		_update_hud()
	for bi in engine.blocks.size():
		var b: Dictionary = engine.blocks[bi]
		if b.gone:
			continue
		var target := Vector2(b.pos)
		var cur: Vector2 = vis.get(bi, target)
		if cur != target:
			cur = cur.lerp(target, minf(1.0, delta * 22.0))
			if cur.distance_to(target) < 0.01:
				cur = target
			vis[bi] = cur
			redraw = true
	for lv in leaving:
		lv.t += delta
	if not leaving.is_empty():
		leaving = leaving.filter(_still_leaving)
		redraw = true
	for v in ["hint_t", "shake_t", "smash_t"]:
		if get(v) > 0.0:
			set(v, maxf(0.0, get(v) - delta))
			redraw = true
	if redraw:
		board.queue_redraw()

func _still_leaving(l: Dictionary) -> bool:
	return l.t < 0.35

func _time_up() -> void:
	time_left = 0.0
	playing = false
	drag_block = -1
	_sfx("lose")
	SaveUtil.delete(SAVE_PATH)  # no Resume into a board with no time left
	_save_progress()
	lose_dialog.get_meta("message_label").text = tr("Blocks left: %d") % engine.left()
	lose_dialog.visible = true
	_update_hud()

# ---------- win ----------

## 3 ★ = half the clock left and no help; 2 ★ = a quarter left; 1 ★ = out in time.
func _stars() -> int:
	if mode == "zen":
		return 0
	var frac := time_left / maxf(1.0, float(engine.time_limit))
	if frac >= 0.5 and helps_used == 0:
		return 3
	if frac >= 0.25:
		return 2
	return 1

func _on_solved() -> void:
	playing = false
	drag_block = -1
	hammer_armed = false
	_sfx("win")
	SaveUtil.delete(SAVE_PATH)
	var stars := _stars()
	var note := ""
	match mode:
		"levels":
			var key := str(level)
			progress.stars[key] = maxi(int(progress.stars.get(key, 0)), stars)
			progress.next = maxi(int(progress.next), mini(level + 1, Gen.LEVELS))
			note = "★".repeat(stars) + "☆".repeat(3 - stars)
		"daily":
			if int(progress.get("daily_day", -1)) != day:
				progress.daily_streak = int(progress.get("daily_streak", 0)) + 1 if int(progress.get("daily_day", -1)) == day - 1 else 1
				progress.daily_day = day
			note = tr("Daily streak: %d") % int(progress.daily_streak)
	_save_progress()
	if info:
		info.add("Boards cleared")
		if mode == "levels":
			info.high("Levels cleared", _levels_done())
			info.high("Stars", _total_stars())
		if mode == "daily":
			info.high("Daily streak", int(progress.daily_streak))
		if stars == 3:
			info.add("3-star clears")
		info.celebrate(tr("All out!"))
	var t := int(elapsed)
	var msg := tr("Time %d:%02d") % [t / 60, t % 60]
	if note != "":
		msg += "\n" + note
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	_update_hud()
	board.queue_redraw()

## Levels cleared in a row from level 1 (the leaderboard number).
func _levels_done() -> int:
	var n := 0
	while progress.stars.has(str(n + 1)):
		n += 1
	return n

func _total_stars() -> int:
	var t := 0
	for k in progress.stars:
		t += int(progress.stars[k])
	return t

# ---------- puzzles ----------

static func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

func _level_puzzle(lvl: int) -> Dictionary:
	if levels_cache.is_empty() and FileAccess.file_exists(LEVELS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH))
		if data is Array:
			levels_cache = data
	if lvl - 1 < levels_cache.size() and levels_cache[lvl - 1] is Dictionary:
		return levels_cache[lvl - 1].duplicate(true)
	return Gen.generate(lvl, Gen.seed_for(lvl), true)

func _start_levels() -> void:
	_start_level(clampi(int(progress.get("next", 1)), 1, Gen.LEVELS))

func _start_level(lvl: int) -> void:
	mode = "levels"
	level = lvl
	_begin(_level_puzzle(lvl))
	if lvl == 1 and not progress.stars.has("1"):
		_feedback(tr("Drag a block to the gate of its colour."), _soft(), 0.0)

func _start_daily() -> void:
	mode = "daily"
	day = _today()
	_begin(Gen.generate(150, day * 7919 + 13, true))

func _start_zen(i: int) -> void:
	mode = "zen"
	zen_tier = i
	var base: int = ZEN[i][1]
	_begin(Gen.generate(clampi(base + randi_range(-15, 15), 1, Gen.LEVELS), randi(), true))

func _begin(p: Dictionary) -> void:
	SaveUtil.delete(SAVE_PATH)
	puzzle_start = p.duplicate(true)
	engine.load_puzzle(p)
	time_left = float(engine.time_limit)
	elapsed = 0.0
	helps_used = 0
	_begin_play()

func _begin_play() -> void:
	playing = true
	warned = false
	hint_t = 0.0
	drag_block = -1
	vis.clear()
	leaving.clear()
	end_dialog.visible = false
	lose_dialog.visible = false
	_clear_feedback()
	if hammer_armed:
		_feedback(tr("🔨 Tap a block to smash it."), _soft(), 0.0)
	_update_hud()
	board.queue_redraw()
	_save_game()

func _next_puzzle() -> void:
	match mode:
		"levels":
			_start_level(mini(level + 1, Gen.LEVELS))
		"zen":
			_start_zen(zen_tier)
		_:
			_start_levels()

func _restart() -> void:
	if puzzle_start.is_empty():
		_start_levels()
		return
	_begin(puzzle_start.duplicate(true))

func _on_pause() -> void:
	drag_block = -1
	home.pause()

func _go_home() -> void:
	home.go_home()

# ---------- feedback ----------

func _soft() -> Color:
	return Color("1d4f96") if _classic() else Color(0.95, 0.88, 0.6)

## `secs` 0 keeps the text until something replaces it.
func _feedback(text: String, col: Color, secs: float = 3.0) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", col)
	feedback_timer.stop()
	if secs > 0.0:
		feedback_timer.start(secs)

func _clear_feedback() -> void:
	if hammer_armed and playing:
		return
	feedback_label.text = ""

# ---------- save / progress ----------

func _load_progress() -> void:
	var d = SaveUtil.read(PROGRESS_PATH)
	progress = d if d is Dictionary else {}
	if not progress.has("stars") or not progress.stars is Dictionary:
		progress.stars = {}
	if not progress.has("next"):
		progress.next = 1
	hammer_armed = bool(progress.get("hammer", false))  # a paid-for 🔨 waits for the next board

func _save_progress() -> void:
	progress.hammer = hammer_armed
	SaveUtil.write(PROGRESS_PATH, progress)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if engine == null or not playing or engine.rows == 0 or engine.solved():
		return
	SaveUtil.write(SAVE_PATH, {"state": engine.to_dict(), "start": puzzle_start, "mode": mode, "level": level,
		"zen": zen_tier, "day": day, "time_left": time_left, "elapsed": elapsed, "helps": helps_used})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if not d is Dictionary:
		return ""
	if str(d.get("mode", "")) == "levels":
		return tr("Level %d") % int(d.get("level", 1))
	return ""

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if not d is Dictionary or not d.get("state") is Dictionary or not engine.load_puzzle(d.state):
		_start_levels()
		return
	puzzle_start = d.start if d.get("start") is Dictionary else {}
	mode = str(d.get("mode", "levels"))
	level = int(d.get("level", 1))
	zen_tier = clampi(int(d.get("zen", 0)), 0, ZEN.size() - 1)
	day = int(d.get("day", 0))
	time_left = float(d.get("time_left", engine.time_limit))
	elapsed = float(d.get("elapsed", 0.0))
	helps_used = int(d.get("helps", 0))
	_begin_play()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

func _buzz(ms: int) -> void:
	var st = get_node_or_null("/root/Settings")
	if st and st.has_method("buzz"):
		st.buzz(ms)
