extends Control

## Dominoes (the Draw game) against one to three computer players. The line
## of tiles snakes across the table from the first tile outwards; your hand
## sits along the bottom.

const DomEngine = preload("res://scripts/games/dominoes/dominoes_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/dominoes/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/dominoes/dominoes_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://dominoes_save.json"

const ME := 0
const COLS := 14  # table width in half-tiles
const CPU_DELAY := 0.8
const FACE := Color(0.06, 0.07, 0.14)
const RIM := Color("29e6ff")
const RIM_CPU := Color("9b4dff")
const PIP := Color(0.95, 0.97, 1.0)
const HILITE := Color("7dff3a")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var started := false
var result_recorded := false
var selected: int = -1  # hand index waiting for an end to be picked
var placed: Array = []  # per chain tile: {"rect": Rect2, "inner_first": bool, "vertical": bool}

var table: Control
var hand_view: Control
var status_label: Label
var opp_label: Label
var action_btn: Button
var cpu_timer: Timer
var round_dialog: Control
var round_btn: Button
var round_next: Callable

func _ready() -> void:
	preload("res://scripts/games/dominoes/dominoes_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = DomEngine.new()
	_build_ui()
	engine.new_game(2, rng)
	started = false
	_render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

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
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("Dominoes")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", RIM.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(RIM, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	opp_label = Label.new()
	opp_label.add_theme_font_size_override("font_size", 22)
	opp_label.add_theme_color_override("font_color", RIM_CPU.lerp(Color.WHITE, 0.4))
	opp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(opp_label)

	table = Control.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.mouse_filter = Control.MOUSE_FILTER_STOP
	table.draw.connect(_draw_table)
	table.gui_input.connect(_on_table_input)
	table.resized.connect(table.queue_redraw)
	root.add_child(table)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	hand_view = Control.new()
	hand_view.custom_minimum_size = Vector2(0, 170)
	hand_view.mouse_filter = Control.MOUSE_FILTER_STOP
	hand_view.draw.connect(_draw_hand)
	hand_view.gui_input.connect(_on_hand_input)
	hand_view.resized.connect(hand_view.queue_redraw)
	root.add_child(hand_view)

	var am := MarginContainer.new()
	am.add_theme_constant_override("margin_bottom", 28)
	root.add_child(am)
	var ab := HBoxContainer.new()
	ab.alignment = BoxContainer.ALIGNMENT_CENTER
	am.add_child(ab)
	action_btn = Button.new()
	action_btn.custom_minimum_size = Vector2(300, 68)
	action_btn.pressed.connect(_on_action)
	ab.add_child(action_btn)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.timeout.connect(_cpu_turn)
	add_child(cpu_timer)

	round_dialog = UI.build_dialog("", [
		{"text": tr("Next round"), "action": _on_round_button},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(round_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for n in [1, 2, 3]:
		modes.append({"text": tr("vs %d") % n + " 🤖", "sub": tr("1 computer") if n == 1 else tr("%d computers") % n, "row": "cpu",
			"color": [HomeKit.CYAN, HomeKit.PURPLE, HomeKit.PINK][n - 1], "action": _new_game.bind(n + 1)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": RIM,
		"solo_heading": "vs Computer",
		"subtitle": "Match the ends, empty your hand, score the pips. First to 100.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Wins",
		"board_note": "Games (to 100 points) won.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.16)  # beside the computers' line, above the table
	add_child(drawer)

# ---------- game flow ----------

func _new_game(n: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.new_game(n, rng)
	_begin()

func _restart() -> void:
	engine.new_game(engine.players, rng)
	_begin()

func _begin() -> void:
	started = true
	result_recorded = false
	selected = -1
	round_dialog.visible = false
	cpu_timer.stop()
	_sfx("card_shuffle")
	_render()
	_maybe_cpu()

func _maybe_cpu() -> void:
	if not engine.round_over and engine.turn != ME:
		cpu_timer.start(CPU_DELAY)

func _cpu_turn() -> void:
	if engine.round_over or engine.turn == ME:
		return
	var p: int = engine.turn
	var choice: Array = engine.cpu_choice(p)
	var drew := 0
	while choice.is_empty() and engine.draw():
		drew += 1
		choice = engine.cpu_choice(p)
	if choice.is_empty():
		engine.pass_turn()
		_flash(tr("🤖 %d draws %d and passes.") % [p, drew] if drew > 0 else tr("🤖 %d passes.") % p)
	else:
		engine.play(p, choice[0], choice[1])
		_sfx("place")
		if drew > 0:
			_flash(tr("🤖 %d drew %d.") % [p, drew])
	_after_move()

func _after_move() -> void:
	selected = -1
	_render()
	if engine.round_over:
		_end_round()
	else:
		_maybe_cpu()

var _flash_text := ""
func _flash(t: String) -> void:
	_flash_text = t

func _on_action() -> void:
	if engine.round_over or engine.turn != ME or not engine.playable(ME).is_empty():
		return
	if engine.draw():
		_sfx("card_deal")
		_render()
	else:
		engine.pass_turn()
		_after_move()

func _play_mine(i: int, side: int) -> void:
	if engine.play(ME, i, side):
		_sfx("place")
		_flash("")
		_after_move()

func _end_round() -> void:
	var w: int = engine.round_winner
	var gw: int = engine.game_winner()
	var msg := (tr("You win the round!") if w == ME else tr("🤖 %d wins the round.") % w) + "  +%d" % engine.round_points
	msg += "\n" + _scores_text()
	if gw >= 0:
		SaveUtil.delete(SAVE_PATH)
		msg = (tr("You win the game!") if gw == ME else tr("🤖 %d wins the game.") % gw) + "\n" + _scores_text()
		if info and not result_recorded:
			result_recorded = true
			info.result("win" if gw == ME else "loss")
			msg += "\n" + info.summary(["Wins", "Losses", "Best streak"])
		round_btn_text(tr("Play Again"))
		round_next = _restart
	else:
		if info and w == ME:
			info.add("Rounds won")
		round_btn_text(tr("Next round"))
		round_next = _next_round
	round_dialog.get_meta("message_label").text = msg
	var t := create_tween()
	t.tween_interval(1.0)
	t.tween_callback(_show_round_dialog)

func _show_round_dialog() -> void:
	round_dialog.visible = engine.round_over

func round_btn_text(t: String) -> void:
	for b in round_dialog.find_children("*", "Button", true, false):
		if b.text == tr("Next round") or b.text == tr("Play Again"):
			b.text = t

func _on_round_button() -> void:
	if round_next.is_valid():
		round_next.call()

func _next_round() -> void:
	engine.new_round(rng)
	round_dialog.visible = false
	selected = -1
	_sfx("card_shuffle")
	_render()
	_maybe_cpu()

func _scores_text() -> String:
	var parts: Array = [tr("You: %d") % engine.scores[0]]
	for p in range(1, engine.players):
		parts.append("🤖 %d: %d" % [p, engine.scores[p]])
	return "   ·   ".join(parts) + "   (" + tr("to %d") % DomEngine.TARGET + ")"

func _render() -> void:
	var parts: Array = []
	for p in range(1, engine.players):
		parts.append(tr("🤖 %d: %d tiles") % [p, engine.hands[p].size()])
	opp_label.text = "   ·   ".join(parts) + "   ·   " + tr("Boneyard: %d") % engine.boneyard.size()
	var mine: bool = engine.turn == ME and not engine.round_over
	var can: bool = not engine.playable(ME).is_empty()
	if engine.round_over:
		status_label.text = ""
	elif not mine:
		status_label.text = (_flash_text + "  " if _flash_text != "" else "") + tr("🤖 %d is playing...") % engine.turn
	elif selected >= 0:
		status_label.text = tr("Tap the glowing end to play there.")
	elif can:
		status_label.text = (_flash_text + "  " if _flash_text != "" else "") + tr("Your turn: tap a glowing tile.")
	else:
		status_label.text = tr("No tile fits.")
	action_btn.visible = mine and not can
	action_btn.text = tr("Draw a tile (%d left)") % engine.boneyard.size() if not engine.boneyard.is_empty() else tr("Pass")
	status_label.text += "\n" + _scores_text()
	table.queue_redraw()
	hand_view.queue_redraw()

# ---------- table layout ----------

## Cells (column, row) for each chain tile: the first tile in the middle,
## the right part snaking down and the left part snaking up.
func _layout() -> Array:
	var n: int = engine.chain.size()
	var out: Array = []
	out.resize(n)
	if n == 0:
		return out
	var s: int = engine.left_count
	out[s] = {"c": 6, "r": 0, "dir": 1, "inner_first": true}
	var c := 8
	var r := 0
	var dir := 1
	for k in range(s + 1, n):
		if (dir == 1 and c + 2 > COLS) or (dir == -1 and c < 0):
			r += 1
			dir = -dir
			c = COLS - 2 if dir == -1 else 0
		out[k] = {"c": c, "r": r, "dir": dir, "inner_first": dir == 1}
		c += 2 * dir
	c = 4
	r = 0
	dir = -1
	for k in range(s - 1, -1, -1):
		if (dir == 1 and c + 2 > COLS) or (dir == -1 and c < 0):
			r -= 1
			dir = -dir
			c = COLS - 2 if dir == -1 else 0
		out[k] = {"c": c, "r": r, "dir": dir, "inner_first": dir == 1}
		c += 2 * dir
	return out

func _draw_table() -> void:
	var lay := _layout()
	var rmin := 0
	var rmax := 0
	for t in lay:
		if t:
			rmin = mini(rmin, t.r)
			rmax = maxi(rmax, t.r)
	var rows := maxi(rmax - rmin + 1, 3)
	var u: float = minf((table.size.x - 24.0) / COLS, (table.size.y - 20.0) / (rows * 1.35))
	u = minf(u, 52.0)
	var row_h := u * 1.35
	var ox: float = (table.size.x - u * COLS) / 2.0
	var oy: float = table.size.y / 2.0 - ((rmin + rmax) / 2.0) * row_h - u / 2.0
	board_rect = Rect2(Vector2(ox, 0), Vector2(u * COLS, table.size.y))
	board_rect = board_rect.grow_individual(8, 0, 8, 0)
	table.draw_rect(Rect2(Vector2(ox - 10, 4), Vector2(u * COLS + 20, table.size.y - 8)), Color(0.02, 0.05, 0.08, 0.7))
	if not _is_classic():
		HomeKit.glow_rect(table, Rect2(Vector2(ox - 10, 4), Vector2(u * COLS + 20, table.size.y - 8)), Color(RIM_CPU, 0.5), 1.5)
	placed = []
	for k in lay.size():
		var t = lay[k]
		var tile: Array = engine.chain[k]
		var rect := Rect2(ox + t.c * u, oy + t.r * row_h, u * 2.0, u)
		var first: int = tile[0]
		var second: int = tile[1]
		# Each tile's inner half touches its neighbour towards the first tile.
		var flip: bool = (t.dir == 1) != (k >= engine.left_count)
		var left_half: int = second if flip else first
		var right_half: int = first if flip else second
		_draw_tile(table, rect, left_half, right_half, false, RIM)
		placed.append(rect)
	end_targets = {}
	if selected >= 0 and not engine.chain.is_empty():
		var sides: Array = engine.sides_for(engine.hands[ME][selected])
		for side in sides:
			var rect: Rect2 = placed[0] if side == 0 else placed[-1]
			end_targets[side] = rect
			HomeKit.glow_rect(table, rect.grow(5), HILITE, 3.0, 0.15)
	if engine.chain.is_empty():
		var font := ThemeDB.fallback_font
		table.draw_string(font, Vector2(0, table.size.y / 2.0), tr("The first tile goes here"), HORIZONTAL_ALIGNMENT_CENTER, table.size.x, 24, Color(HomeKit.DIM, 0.5))

var board_rect := Rect2()
var end_targets: Dictionary = {}

## Look (STANDARDS §9): "classic" = ivory tiles on green felt (default); "voodoo" = the neon
## board. Set by the kit (Options → Look).
var skin: String = "classic"
var bg: ColorRect

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.felt_dark if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if table:
		table.queue_redraw()
	if hand_view:
		hand_view.queue_redraw()

func _is_classic() -> bool:
	return skin == "classic"

func _draw_tile(c: Control, rect: Rect2, a: int, b: int, vertical: bool, rim: Color, glow := false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = FACE
	sb.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) * 0.18))
	sb.border_color = rim
	sb.set_border_width_all(2)
	sb.shadow_color = Color(rim, 0.45 if glow else 0.18)
	sb.shadow_size = 10 if glow else 4
	var line_col := Color(rim, 0.6)
	if _is_classic():
		sb.bg_color = Color("f4efe4")
		sb.border_color = HomeKit.CLASSIC.yellow if glow else Color("8a8473")
		sb.set_border_width_all(4 if glow else 2)
		sb.shadow_color = Color(0, 0, 0, 0.3)
		sb.shadow_size = 3
		sb.shadow_offset = Vector2(1, 2)
		line_col = Color("8a8473")
	c.draw_style_box(sb, rect.grow(-2))
	var half: Rect2
	var other: Rect2
	if vertical:
		half = Rect2(rect.position, Vector2(rect.size.x, rect.size.y / 2.0))
		other = Rect2(rect.position + Vector2(0, rect.size.y / 2.0), half.size)
		c.draw_line(Vector2(rect.position.x + 6, rect.get_center().y), Vector2(rect.end.x - 6, rect.get_center().y), line_col, 1.5)
	else:
		half = Rect2(rect.position, Vector2(rect.size.x / 2.0, rect.size.y))
		other = Rect2(rect.position + Vector2(rect.size.x / 2.0, 0), half.size)
		c.draw_line(Vector2(rect.get_center().x, rect.position.y + 6), Vector2(rect.get_center().x, rect.end.y - 6), line_col, 1.5)
	_pips(c, half, a)
	_pips(c, other, b)

const SPOTS := {0: [], 1: [[1, 1]], 2: [[0, 0], [2, 2]], 3: [[0, 0], [1, 1], [2, 2]],
	4: [[0, 0], [2, 0], [0, 2], [2, 2]], 5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]],
	6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]]}

func _pips(c: Control, r: Rect2, v: int) -> void:
	var s := minf(r.size.x, r.size.y)
	var o := r.get_center() - Vector2(s, s) * 0.5
	for sp in SPOTS[v]:
		c.draw_circle(o + Vector2(0.24 + sp[0] * 0.26, 0.24 + sp[1] * 0.26) * s, s * 0.085, HomeKit.CLASSIC.ink if _is_classic() else PIP)

# ---------- hand ----------

func _hand_rects() -> Array:
	var n: int = engine.hands[ME].size() if not engine.hands.is_empty() else 0
	var out: Array = []
	if n == 0:
		return out
	var per_row := mini(n, 10)
	var rows_n := int(ceil(n / float(per_row)))
	var w: float = minf(62.0, (hand_view.size.x - 24.0) / per_row - 8.0)
	var h: float = minf(w * 2.0, (hand_view.size.y - 10.0) / rows_n - 8.0)
	w = minf(w, h / 2.0)
	for i in n:
		var row := i / per_row
		var in_row := mini(per_row, n - row * per_row)
		var x0: float = (hand_view.size.x - in_row * (w + 8.0)) / 2.0
		out.append(Rect2(x0 + (i % per_row) * (w + 8.0), 5.0 + row * (h + 8.0), w, h))
	return out

func _draw_hand() -> void:
	if engine.hands.is_empty():
		return
	var rects := _hand_rects()
	var mine: bool = engine.turn == ME and not engine.round_over
	var can: Array = engine.playable(ME)
	for i in rects.size():
		var t: Array = engine.hands[ME][i]
		var ok: bool = mine and i in can
		var r: Rect2 = rects[i]
		if i == selected:
			r.position.y -= 6
		_draw_tile(hand_view, r, t[0], t[1], true, HILITE if ok else Color(RIM, 0.45), ok)

func _on_hand_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if engine.round_over or engine.turn != ME:
		return
	var rects := _hand_rects()
	for i in rects.size():
		if rects[i].grow(4).has_point(event.position):
			var sides: Array = engine.sides_for(engine.hands[ME][i])
			if sides.is_empty():
				_sfx("invalid")
				return
			if sides.size() == 1 or engine.left_end() == engine.right_end():
				_play_mine(i, sides[0])
			else:
				selected = i
				_sfx("toggle")
				_render()
			return

func _on_table_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if selected < 0:
		return
	for side in end_targets:
		if end_targets[side].grow(20).has_point(event.position):
			_play_mine(selected, side)
			return
	selected = -1
	_render()

func _draw_home_logo(c: Control) -> void:
	var u := minf(c.size.y / 3.0, 50.0)
	var o := c.size / 2.0
	_draw_tile(c, Rect2(o + Vector2(-u * 2.6, -u * 0.5), Vector2(u * 2.0, u)), 6, 4, false, RIM)
	_draw_tile(c, Rect2(o + Vector2(-u * 0.5, -u * 1.0), Vector2(u, u * 2.0)), 4, 4, true, HomeKit.MAGENTA, true)
	_draw_tile(c, Rect2(o + Vector2(u * 0.6, -u * 0.5), Vector2(u * 2.0, u)), 4, 1, false, RIM)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.round_over or engine.game_winner() >= 0:
		return
	SaveUtil.write(SAVE_PATH, {"players": engine.players, "hands": engine.hands, "boneyard": engine.boneyard,
		"chain": engine.chain, "left": engine.left_count, "turn": engine.turn, "scores": engine.scores,
		"passes": engine.passes})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var sc: Array = d.get("scores", [0])
	return tr("vs %d") % (int(d.get("players", 2)) - 1) + " 🤖   ·   " + tr("You: %d") % int(sc[0])

static func _tiles(a: Variant) -> Array:
	var out: Array = []
	for t in a:
		out.append([int(t[0]), int(t[1])])
	return out

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_new_game(2)
		return
	engine.players = clampi(int(d.get("players", 2)), 2, 4)
	engine.hands = []
	for h in d.get("hands", []):
		engine.hands.append(_tiles(h))
	engine.boneyard = _tiles(d.get("boneyard", []))
	engine.chain = _tiles(d.get("chain", []))
	engine.left_count = int(d.get("left", 0))
	engine.turn = int(d.get("turn", 0))
	engine.passes = int(d.get("passes", 0))
	engine.scores = []
	for v in d.get("scores", []):
		engine.scores.append(int(v))
	engine.round_over = false
	if engine.hands.size() != engine.players or engine.scores.size() != engine.players:
		_new_game(2)
		return
	started = true
	result_recorded = false
	selected = -1
	round_dialog.visible = false
	_render()
	_maybe_cpu()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
