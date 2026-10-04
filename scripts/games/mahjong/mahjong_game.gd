extends Control

## Mahjong Solitaire: clear the stacked tiles in matching pairs. Only free
## tiles (nothing on top, left or right side open) can be taken.

const MjEngine = preload("res://scripts/games/mahjong/mahjong_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/mahjong/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/mahjong/mahjong_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://mahjong_save.json"

const LEVELS := ["Easy", "Normal", "Hard"]
const KINDS := [18, 24, 36]
const SYMBOLS := ["🍎", "🍊", "🍋", "🍉", "🍇", "🍓", "🍒", "🥝", "🌶", "🥕", "🌽", "🍄",
	"🌵", "🌻", "🌙", "⭐", "☀", "⚡", "🔥", "💧", "❄", "🍀", "🎲", "🎯",
	"🎸", "🎈", "🎁", "💎", "🔔", "⚓", "🚀", "👑", "💀", "🦋", "🐟", "🐙"]
## Rim colour per symbol group, so similar fruit still read apart.
const RIMS := [Color("29e6ff"), Color("ff2bd6"), Color("7dff3a"), Color("ffae2b"), Color("9b4dff"), Color("ff4f9a")]
const ASPECT := 1.28  # tile height / width

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var level: int = 0
var started := false
var solved := false
var elapsed: float = 0.0
var selected: int = -1
var hinted: Array = []
var used_hint := false

var board: Control
var status_label: Label
var end_dialog: Control
var stuck_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/mahjong/mahjong_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = MjEngine.new()
	_build_ui()
	_deal(0)
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

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
	var title := Label.new()
	title.text = tr("Mahjong")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.LIME.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.LIME, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 30)
	root.add_child(bm)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	bm.add_child(row)
	for b in [["↶ " + tr("Undo"), _undo], ["💡 " + tr("Hint"), _hint], ["🔀 " + tr("Shuffle"), _shuffle]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(170, 64)
		btn.pressed.connect(b[1])
		row.add_child(btn)

	end_dialog = UI.build_dialog("", [
		{"text": tr("New game"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	stuck_dialog = UI.build_dialog(tr("No more matching pairs."), [
		{"text": "🔀 " + tr("Shuffle"), "action": _shuffle},
		{"text": "↶ " + tr("Undo"), "action": _undo},
		{"text": tr("New game"), "action": _restart},
	])
	add_child(stuck_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in LEVELS.size():
		modes.append({"text": LEVELS[i], "sub": tr("%d tiles") % _count(i), "row": "levels",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_game.bind(i)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.LIME,
		"subtitle": "Match free tiles in pairs until the table is clear.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Games solved",
		"board_note": "Tables cleared, any layout.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.975)  # under the buttons
	add_child(drawer)

static func _count(kind: int) -> int:
	var n := 0
	for l in MjEngine.layout(kind):
		n += l.size()
	return n

# ---------- game flow ----------

func _new_game(lvl: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	_deal(lvl)

func _restart() -> void:
	_deal(level)

func _deal(lvl: int) -> void:
	level = lvl
	engine.deal(lvl, KINDS[lvl], rng)
	started = true
	solved = false
	elapsed = 0.0
	selected = -1
	hinted = []
	used_hint = false
	end_dialog.visible = false
	stuck_dialog.visible = false
	_status()
	board.queue_redraw()

func _process(delta: float) -> void:
	if started and not solved:
		var before := int(elapsed)
		elapsed += delta
		if int(elapsed) != before:
			_status()

func _status() -> void:
	var s := int(elapsed)
	status_label.text = tr("%s   ·   Tiles left: %d   ·   %d:%02d") % [tr(LEVELS[level]), engine.remaining(), s / 60, s % 60]

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if solved:
		return
	var i := _tile_at(event.position)
	if i < 0:
		return
	if not engine.is_free(i):
		_sfx("invalid")
		return
	hinted = []
	if selected == i:
		selected = -1
	elif selected >= 0 and engine.tiles[selected].s == engine.tiles[i].s:
		engine.remove_pair(selected, i)
		selected = -1
		_sfx("merge")
		_after_pair()
	else:
		selected = i
		_sfx("toggle")
	board.queue_redraw()

func _after_pair() -> void:
	_status()
	if engine.won():
		_on_won()
	elif engine.hint().is_empty():
		stuck_dialog.visible = true

func _on_won() -> void:
	solved = true
	SaveUtil.delete(SAVE_PATH)
	var s := int(elapsed)
	var msg := tr("Table cleared!") + "\n" + tr("Time: %d:%02d") % [s / 60, s % 60]
	if info:
		info.add("Games solved")
		if not used_hint and engine.shuffles == 0:
			info.add("Solved without help")
		if info.low("Best time (%s)" % LEVELS[level], s):
			msg += "\n" + tr("New best time!")
		info.celebrate(tr("Table cleared!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

func _undo() -> void:
	stuck_dialog.visible = false
	if engine.undo():
		selected = -1
		hinted = []
		_sfx("back")
		_status()
		board.queue_redraw()

func _hint() -> void:
	hinted = engine.hint()
	used_hint = true
	if hinted.is_empty():
		stuck_dialog.visible = true
	else:
		_sfx("notify")
	board.queue_redraw()

func _shuffle() -> void:
	stuck_dialog.visible = false
	if engine.remaining() == 0:
		return
	engine.reshuffle(rng)
	selected = -1
	hinted = []
	_sfx("card_shuffle")
	board.queue_redraw()

# ---------- drawing ----------

func _geom() -> Dictionary:
	var minx := 999
	var maxx := -999
	var miny := 999
	var maxy := -999
	for t in engine.tiles:
		minx = mini(minx, t.x)
		maxx = maxi(maxx, t.x + 2)
		miny = mini(miny, t.y)
		maxy = maxi(maxy, t.y + 2)
	var span_x: float = maxx - minx + 0.6
	var span_y: float = maxy - miny + 0.6
	var hu: float = minf((board.size.x - 24.0) / span_x, (board.size.y - 16.0) / (span_y * ASPECT))
	var hv: float = hu * ASPECT
	var o := Vector2((board.size.x - span_x * hu) / 2.0 - minx * hu + 0.3 * hu,
		(board.size.y - span_y * hv) / 2.0 - miny * hv + 0.3 * hv)
	return {"hu": hu, "hv": hv, "o": o}

func _rect_of(i: int, g: Dictionary) -> Rect2:
	var t: Dictionary = engine.tiles[i]
	var lift: float = t.z * g.hu * 0.24
	return Rect2(g.o + Vector2(t.x * g.hu - lift, t.y * g.hv - lift), Vector2(g.hu * 2.0, g.hv * 2.0))

func _order() -> Array:
	var ids: Array = []
	for i in engine.tiles.size():
		if engine.tiles[i].on:
			ids.append(i)
	ids.sort_custom(func(a, b):
		var ta: Dictionary = engine.tiles[a]
		var tb: Dictionary = engine.tiles[b]
		if ta.z != tb.z:
			return ta.z < tb.z
		if ta.x != tb.x:
			return ta.x < tb.x
		return ta.y < tb.y)
	return ids

func _tile_at(p: Vector2) -> int:
	var g := _geom()
	var ids := _order()
	for k in range(ids.size() - 1, -1, -1):
		if _rect_of(ids[k], g).has_point(p):
			return ids[k]
	return -1

func _draw_board() -> void:
	if engine.tiles.is_empty():
		return
	var g := _geom()
	var on := {}
	for i in engine.tiles.size():
		if engine.tiles[i].on:
			on[i] = true
	var font := ThemeDB.fallback_font
	for i in _order():
		var t: Dictionary = engine.tiles[i]
		var r := _rect_of(i, g).grow(-1.5)
		var free: bool = engine._free_among(i, on)
		var rim: Color = RIMS[t.s % RIMS.size()]
		var depth: float = g.hu * 0.16
		board.draw_rect(Rect2(r.position + Vector2(depth, depth), r.size), Color(0.0, 0.0, 0.02))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.08, 0.16) if free else Color(0.035, 0.04, 0.08)
		sb.set_corner_radius_all(int(g.hu * 0.25))
		sb.border_color = Color(rim, 0.95 if free else 0.35)
		sb.set_border_width_all(2)
		if i == selected or i in hinted:
			sb.border_color = HomeKit.GOLD if i == selected else HomeKit.LIME
			sb.set_border_width_all(4)
			sb.shadow_color = Color(sb.border_color, 0.5)
			sb.shadow_size = 10
		board.draw_style_box(sb, r)
		var fs := int(g.hu * 1.05)
		var sym: String = SYMBOLS[t.s % SYMBOLS.size()]
		var w := font.get_string_size(sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(r.get_center().x - w / 2.0, r.get_center().y - font.get_height(fs) / 2.0 + font.get_ascent(fs))
		board.draw_string(font, pos, sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 1.0 if free else 0.45))

func _draw_home_logo(c: Control) -> void:
	var w := minf(c.size.y * 0.42, 60.0)
	var h := w * ASPECT
	var o := c.size / 2.0
	var font := ThemeDB.fallback_font
	var spots := [[-1.6, 0.25, 0, "🎋"], [-0.55, 0.25, 0, "🍀"], [0.5, 0.25, 0, "🔥"], [-1.07, -0.25, 1, "🀄"], [-0.02, -0.25, 1, "🍀"]]
	for s in spots:
		var r := Rect2(o + Vector2(s[0] * w, s[1] * h - h / 2.0) - Vector2(s[2] * 6, s[2] * 6), Vector2(w, h))
		c.draw_rect(Rect2(r.position + Vector2(5, 5), r.size), Color(0, 0, 0.02))
		HomeKit.glow_rect(c, r, [HomeKit.LIME, HomeKit.CYAN][s[2]], 2.0, 0.15)
		var fs := int(w * 0.55)
		var tw := font.get_string_size(s[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		c.draw_string(font, r.get_center() + Vector2(-tw / 2.0, fs * 0.35), s[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or solved:
		return
	var ts: Array = []
	for t in engine.tiles:
		ts.append([t.x, t.y, t.z, t.s, 1 if t.on else 0])
	SaveUtil.write(SAVE_PATH, {"level": level, "tiles": ts, "time": elapsed, "moves": engine.moves,
		"history": engine.history, "shuffles": engine.shuffles, "hint": used_hint})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var left := 0
	for t in d.get("tiles", []):
		left += int(t[4])
	return tr(LEVELS[clampi(int(d.get("level", 0)), 0, 2)]) + "   ·   " + tr("Tiles left: %d") % left

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or d.get("tiles", []).is_empty():
		_deal(0)
		return
	_deal(clampi(int(d.get("level", 0)), 0, 2))
	engine.tiles = []
	for t in d.tiles:
		engine.tiles.append({"x": int(t[0]), "y": int(t[1]), "z": int(t[2]), "s": int(t[3]), "on": int(t[4]) == 1})
	engine.history = []
	for p in d.get("history", []):
		engine.history.append([int(p[0]), int(p[1])])
	engine.moves = int(d.get("moves", 0))
	engine.shuffles = int(d.get("shuffles", 0))
	used_hint = bool(d.get("hint", false))
	elapsed = float(d.get("time", 0.0))
	_status()
	board.queue_redraw()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
