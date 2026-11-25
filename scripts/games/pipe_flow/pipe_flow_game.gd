extends Control

## Wire Up (game id `pipe_flow`): turn the wire pieces until every bulb is lit.
## Blue and yellow batteries; a bulb lights only with its own colour, and a
## green bulb needs blue and yellow joined. Modes: a 240-level campaign (stars),
## a daily board, random boards by difficulty, a 3-minute time attack, and the Workshop
## (board themes bought with bolts earned in play; no real money).
## All art is drawn in code; the sounds come from pipe_flow_sfx.gd.

## Landing menu style: S9 Arcade Marquee (docs/MENU_STYLES.md).
const MenuStyles = preload("res://scripts/games/pipe_flow/menu_styles.gd")
const PipeEngine = preload("res://scripts/games/pipe_flow/pipe_flow_engine.gd")
const WireSfx = preload("res://scripts/games/pipe_flow/pipe_flow_sfx.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/pipe_flow/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/pipe_flow/pipe_flow_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://pipe_flow_save.json"
const PROGRESS_PATH := "user://pipe_flow_progress.json"
const CLOUD_SAVE := "res://scripts/common/cloud_save.gd"  # [NEW 2026-11-24] STANDARDS §18; APK-side, load() guarded
var cloud: Node = null

const ZEN_NAMES := ["Easy", "Medium", "Hard", "Expert", "Master"]
## Which campaign levels a random board draws from, per difficulty.
const ZEN_RANGE := [[2, 16], [20, 48], [52, 88], [92, 120], [130, 240]]
## Daily board: settings of one of the part-two levels (121-240), harder than before (2026-11-25; was 45-94).
const DAILY_BASE := 121
const DAILY_SPAN := 120
const TIME_ATTACK_SECONDS := 180.0
## Workshop (2026-11-25): board themes bought with ⚡ bolts. Bolts are earned, never sold:
## 10 per campaign star, 50 per full chapter, 30 per daily board, 100 per 7-day streak.
## Some themes also need a goal first. Themes change the Classic look only (Voodoo keeps neon).
## tiles = [tile a, tile b, locked tile, empty tile, tile lip, plate, plate edge].
const BOLTS_STAR := 10
const BOLTS_CHAPTER := 50
const BOLTS_DAILY := 30
const BOLTS_STREAK7 := 100
const THEMES := [
	{"id": "classic", "name": "Blueprint", "price": 0, "need": "", "tiles": ["2f6de6", "2a62d8", "30539c", "264fb8", "1a3a9c", "0d1446", "5c6ad8"]},
	{"id": "copper", "name": "Copper Works", "price": 150, "need": "", "tiles": ["b8693a", "a85f33", "7d5a46", "8f4f2c", "5e3018", "24140c", "d08a52"]},
	{"id": "pcb", "name": "Circuit Board", "price": 300, "need": "", "tiles": ["1f8a52", "1b7c49", "2e6a4c", "17683e", "0d4227", "06210f", "4fd18a"]},
	{"id": "midnight", "name": "Midnight", "price": 300, "need": "", "tiles": ["2b2f45", "262a3e", "3a3550", "20233a", "12142a", "07080f", "6a70a8"]},
	{"id": "sunrise", "name": "Daybreak", "price": 500, "need": "daily:10", "tiles": ["e0785a", "d46c52", "a8667a", "c2604e", "8a3a3a", "2a1020", "ffb27a"]},
	{"id": "amber", "name": "Amber Lab", "price": 600, "need": "streak:7", "tiles": ["c99a2e", "bb8e29", "8c7a4a", "a87d22", "6b4d12", "251a06", "ffd36a"]},
	{"id": "gold", "name": "Gold Standard", "price": 800, "need": "levels:120", "tiles": ["d4b04a", "c7a442", "a08a52", "b8943a", "7a5e1c", "2a2008", "fff0a0"]},
	{"id": "plasma", "name": "Plasma", "price": 1500, "need": "levels:240", "tiles": ["7a3ce0", "6e34d2", "5c4a9a", "6430c0", "3a1680", "12062e", "d27aff"]},
]
var shop_layer: Control

const TURN_SPEED := 14.0  # radians per second for the quarter-turn animation

## The colour of current: blue, yellow, and green for the two mixed.
const CUR := {1: Color("35c9ff"), 2: Color("ffc21c"), 3: Color("3dff7c")}
const COLOR_LEAK := Color("ff4f6a")

const CHAPTER_TIPS := [
	"Tap a piece to turn it. Send the current from the battery to the bulb.",
	"Wires can split: one battery can light several bulbs.",
	"Spare wire and circles are there to confuse you. Not every piece is needed.",
	"Blue and yellow current must not touch. A bulb only lights with its own colour.",
	"Batteries and bulbs with a ring around them can turn too.",
	"A green bulb needs blue and yellow current joined in one wire.",
	"A blue or yellow bulb on a mixed (green) wire stays dark.",
	"Plan the whole circuit before you start tapping.",
	"More bulbs, fewer locked pieces.",
	"Big boards: work out from the batteries.",
	"Nothing is locked any more.",
	"The last chapter. Light them all.",
	# Part two (levels 121-240).
	"Part two: bigger boards, and every piece can turn.",
	"Follow the long wires: they wind across the whole board.",
	"Dead wire everywhere. Trust the batteries, not the clutter.",
	"Find the bulbs in corners first: they have only one way in.",
	"Two green networks: keep each pair of batteries together.",
	"A bulb at the edge of the board can only face inwards.",
	"Two greens, a blue and a yellow. Keep them apart.",
	"More bulbs per battery. Branch early.",
	"Every tile turns. Lock in the edges, then work inwards.",
	"Long wires, many bulbs. Patience.",
	"Four networks, packed tight.",
	"The very last chapter. The whole grid is live.",
]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var mode: String = "campaign"  # campaign | daily | zen | time
var zen_diff: int = 0
var cur_level: int = 1  # campaign level, or the level a random board was built from
var cur_seed: int = 0
var elapsed: float = 0.0
var time_left: float = 0.0
var ta_solved: int = 0
var hints_used: int = 0
var undo: Array = []
var started := false  # a real game is on (not just the board behind Home)
var solved := false
var over := false  # time attack finished
var flow_t: float = 0.0  # drives the running-current animation
var spin: Dictionary = {}  # cell -> angle still to turn (animation)
var shake: Dictionary = {}  # cell -> seconds left of the "locked" wobble
var win_t: float = -1.0  # seconds since solved, for the ripple
var hint_cell: int = -1
var hint_t: float = 0.0
var prev_lit: Dictionary = {}
var prev_short: Dictionary = {}
var burst: Dictionary = {}  # bulb cell -> seconds since it lit (flash ring)
var sparks: Array = []  # {"p", "v", "life", "col"}
var progress: Dictionary = {}

## Look pass (2026-11-25): live circuit backdrop, board plate, HUD bar, cheap disc textures.
var bg_t: float = 0.0  # backdrop clock, runs even behind Home
var intro_t: float = 1.0  # seconds since the board appeared (pop-in)
var pop: Dictionary = {}  # cell -> seconds left of the tap squash
var traces: Array = []  # backdrop circuit traces, points in 0..1
var trace_lines := PackedVector2Array()
var motes: Array = []  # {"x", "y", "s", "r"}
var tex_disc: Texture2D
var tex_glow: Texture2D
var tex_vignette: Texture2D
var hud_bar: Control
var flash: ColorRect

var board: Control
var art_bg: Control
var title_label: Label
var status_label: Label
var tip_label: Label
var hint_btn: Button
var undo_btn: Button
var end_card: Control
var map_layer: Control
var map_from_landing := false
var map_drag = null

func _ready() -> void:
	preload("res://scripts/games/pipe_flow/pipe_flow_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = PipeEngine.new()
	_load_progress()
	if ResourceLoader.exists(CLOUD_SAVE):
		cloud = load(CLOUD_SAVE).new()
		cloud.setup("pipe_flow", PROGRESS_PATH, _progress_score, _load_progress)
		add_child(cloud)
	_build_ui()
	_begin("campaign", 1, PipeEngine.seed_for(1))
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	_make_art()
	bg = HomeKit.backdrop()
	add_child(bg)
	art_bg = Control.new()
	art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_bg.draw.connect(_draw_backdrop)
	add_child(art_bg)
	art_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 24)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(72, 64)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", CUR[2].lerp(Color.WHITE, 0.6))
	title_label.add_theme_color_override("font_outline_color", Color(CUR[2], 0.5))
	title_label.add_theme_constant_override("outline_size", 8)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	bar.add_child(title_label)
	hint_btn = Button.new()
	hint_btn.text = "💡"
	hint_btn.custom_minimum_size = Vector2(72, 64)
	hint_btn.pressed.connect(_on_hint)
	bar.add_child(hint_btn)
	undo_btn = Button.new()
	undo_btn.text = "↶"
	undo_btn.custom_minimum_size = Vector2(72, 64)
	undo_btn.pressed.connect(_on_undo)
	bar.add_child(undo_btn)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(72, 64)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	# HUD: the status line on a glass panel with a bulbs-lit progress bar.
	var hud_m := MarginContainer.new()
	hud_m.add_theme_constant_override("margin_left", 24)
	hud_m.add_theme_constant_override("margin_right", 24)
	root.add_child(hud_m)
	var hud := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.03, 0.04, 0.12, 0.72)
	hsb.set_corner_radius_all(16)
	hsb.set_border_width_all(2)
	hsb.border_color = Color(0.55, 0.5, 1.0, 0.35)
	hsb.shadow_color = Color(0, 0, 0, 0.35)
	hsb.shadow_size = 8
	hsb.shadow_offset = Vector2(0, 3)
	hsb.content_margin_top = 6
	hsb.content_margin_bottom = 8
	hsb.content_margin_left = 14
	hsb.content_margin_right = 14
	hud.add_theme_stylebox_override("panel", hsb)
	hud_m.add_child(hud)
	var hud_box := VBoxContainer.new()
	hud_box.add_theme_constant_override("separation", 4)
	hud.add_child(hud_box)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	status_label.add_theme_constant_override("outline_size", 4)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_box.add_child(status_label)
	hud_bar = Control.new()
	hud_bar.custom_minimum_size = Vector2(0, 10)
	hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_bar.draw.connect(_draw_hud_bar)
	hud_box.add_child(hud_bar)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	tip_label = Label.new()
	tip_label.add_theme_font_size_override("font_size", 22)
	tip_label.add_theme_color_override("font_color", HomeKit.DIM)
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.custom_minimum_size = Vector2(0, 62)
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_bottom", 24)
	hm.add_theme_constant_override("margin_left", 24)
	hm.add_theme_constant_override("margin_right", 24)
	hm.add_child(tip_label)
	root.add_child(hm)

	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = [
		{"text": "🗺 Campaign", "sub": "Collect stars", "color": HomeKit.GOLD, "action": _start_campaign},
		{"text": "📋 Level Select", "sub": "Pick a level", "color": HomeKit.BUTTON, "action": _open_map.bind(true)},
		{"text": "🛒 Workshop", "sub": "Spend bolts on board themes", "color": HomeKit.LIME, "action": _open_shop},
		{"text": "📅 Daily Challenge", "sub": "One board a day, same for everyone", "color": HomeKit.PINK, "action": _start_daily},
		{"text": "⏱ Time Attack", "sub": "3 minutes: light as many boards as you can", "color": HomeKit.PURPLE, "action": _start_time},
	]
	for i in ZEN_NAMES.size():
		modes.append({"text": ZEN_NAMES[i], "sub": "Random board", "row": "zen", "key": "zen" + str(i),
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK, HomeKit.GOLD, HomeKit.PURPLE][i], "action": _start_zen.bind(i)})
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S9 Arcade Marquee, own title font + colours.
		"landing": "marquee",
		"landing_style": MenuStyles,
		"title_font": "res://games/pipe_flow/title.ttf",
		"title_colors": [Color("3cff8a"), Color("ff3c8a"), Color("3cb4ff"), Color("ffd23c")],
		"landing_colors": [Color("04040e"), Color("141436")],
		"help": HELP,
		"info": info,
		"accent": CUR[2],
		"subtitle": "Turn the wires and light every bulb.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [{"text": "💡 Hint", "how": "Flashes one tile that is turned the wrong way.", "action": _hint_now}],
		"board": "Puzzles solved",
		"board_note": "Boards lit in any mode.",
	})
	add_child(home)
	home.track_help_button(hint_btn)
	if info:
		add_child(info)

# ---------- game flow ----------

func _start_campaign() -> void:
	SaveUtil.delete(SAVE_PATH)
	var lvl := _next_level()
	_begin("campaign", lvl, PipeEngine.seed_for(lvl))

func _start_level(lvl: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	_close_map()
	_begin("campaign", lvl, PipeEngine.seed_for(lvl))

func _start_daily() -> void:
	SaveUtil.delete(SAVE_PATH)
	var day := _today()
	_begin("daily", DAILY_BASE + day % DAILY_SPAN, day * 7919 + 13)

func _start_zen(diff: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	zen_diff = diff
	_next_zen()

func _next_zen() -> void:
	var r: Array = ZEN_RANGE[zen_diff]
	_begin("zen", rng.randi_range(r[0], r[1]), rng.randi())

func _start_time() -> void:
	SaveUtil.delete(SAVE_PATH)
	ta_solved = 0
	time_left = TIME_ATTACK_SECONDS
	over = false
	_begin("time", 2, rng.randi())

func _restart() -> void:
	if mode == "time" and over:
		_start_time()
		return
	_begin(mode, cur_level, cur_seed, mode == "time")

## Builds the board for level `lvl` (settings) and `seed_value` and starts playing it.
func _begin(m: String, lvl: int, seed_value: int, keep_clock: bool = false) -> void:
	mode = m
	cur_level = lvl
	cur_seed = seed_value
	engine.generate(PipeEngine.params_for(lvl), seed_value)
	engine.level = lvl if m == "campaign" else 0
	if not keep_clock:
		elapsed = 0.0
	solved = false
	started = true
	hints_used = 0
	undo.clear()
	spin.clear()
	shake.clear()
	burst.clear()
	sparks.clear()
	hint_cell = -1
	win_t = -1.0
	intro_t = 0.0
	pop.clear()
	_close_end()
	_close_map()
	_close_shop()
	_sync_state()
	_update(false)

func _sync_state() -> void:
	prev_lit.clear()
	prev_short.clear()
	for c in engine.w * engine.h:
		if engine.is_lit(c):
			prev_lit[c] = true
		if engine.is_shorted(c):
			prev_short[c] = true
	hint_btn.visible = mode != "time"
	undo_btn.disabled = true
	match mode:
		"campaign":
			title_label.text = tr("Level %d") % cur_level
			tip_label.text = tr(CHAPTER_TIPS[PipeEngine.chapter_of(cur_level)])
		"daily":
			title_label.text = tr("📅 Daily Challenge")
			tip_label.text = tr("One board a day, the same for everyone.")
		"time":
			title_label.text = tr("⏱ Time Attack")
			tip_label.text = tr("Light the bulbs fast: every board is harder than the last.")
		_:
			title_label.text = tr(ZEN_NAMES[zen_diff])
			tip_label.text = tr(CHAPTER_TIPS[PipeEngine.chapter_of(cur_level)])
	# Title pops in with each new board.
	title_label.pivot_offset = title_label.size / 2.0
	title_label.scale = Vector2(1.18, 1.18)
	title_label.modulate.a = 0.3
	var tw := title_label.create_tween().set_parallel()
	tw.tween_property(title_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title_label, "modulate:a", 1.0, 0.25)

## Re-reads the board after a change: sounds and sparks for bulbs that just lit
## or shorted, the status line, and the win check.
func _update(announce: bool = true) -> void:
	var now_lit := {}
	var now_short := {}
	for c in engine.w * engine.h:
		if engine.is_lit(c):
			now_lit[c] = true
			if announce and not prev_lit.has(c):
				burst[c] = 0.0
				_spark_burst(c, _bulb_colour(c), 14)
				_play("green" if engine.color[c] == PipeEngine.GREEN else "zap")
		elif prev_lit.has(c) and announce:
			_play("power", -6.0)
		if engine.is_shorted(c):
			now_short[c] = true
			if announce and not prev_short.has(c):
				_spark_burst(c, COLOR_LEAK, 8)
				_play("short", -3.0)
	prev_lit = now_lit
	prev_short = now_short
	undo_btn.disabled = undo.is_empty() or solved
	_status()
	board.queue_redraw()
	if hud_bar:
		hud_bar.queue_redraw()
	if announce and not solved and engine.is_won():
		_on_solved()

func _status() -> void:
	var lit := "💡 %d/%d" % [engine.lit_bulbs, engine.bulb_total]
	if mode == "time":
		status_label.text = "%s   ·   %s   ·   %s" % [_clock(maxf(time_left, 0.0)), lit, tr("Boards: %d") % ta_solved]
	else:
		status_label.text = "%s   ·   %s   ·   %s" % [lit, tr("Moves: %d") % engine.moves, _clock(elapsed)]

static func _clock(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]

static func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

func _process(delta: float) -> void:
	var redraw := false
	bg_t += delta
	if art_bg and is_visible_in_tree():
		art_bg.queue_redraw()
	if intro_t < 1.0:
		intro_t += delta
		redraw = true
	if not pop.is_empty():
		for c in pop.keys():
			pop[c] -= delta
			if pop[c] <= 0.0:
				pop.erase(c)
		redraw = true
	if mode == "time" and started and not over and time_left < 15.0:
		var p: float = 0.5 + 0.5 * sin(bg_t * 8.0)
		status_label.modulate = Color.WHITE.lerp(Color(1.0, 0.45, 0.5), p)
	else:
		status_label.modulate = Color.WHITE
	if started:
		flow_t += delta
		redraw = true
	if started and not solved and not over:
		var before := int(elapsed)
		elapsed += delta
		if mode == "time":
			time_left -= delta
			if int(time_left) != int(time_left + delta):
				_status()
			if time_left <= 0.0:
				_time_up()
		elif int(elapsed) != before:
			_status()
	if not spin.is_empty():
		for c in spin.keys():
			spin[c] = move_toward(spin[c], 0.0, delta * TURN_SPEED)
			if spin[c] == 0.0:
				spin.erase(c)
		redraw = true
	if not shake.is_empty():
		for c in shake.keys():
			shake[c] -= delta
			if shake[c] <= 0.0:
				shake.erase(c)
		redraw = true
	if not burst.is_empty():
		for c in burst.keys():
			burst[c] += delta
			if burst[c] > 0.8:
				burst.erase(c)
		redraw = true
	if not sparks.is_empty():
		for s in sparks:
			s.p += s.v * delta
			s.v *= 0.94
			s.v.y += s.get("g", 0.0) * delta
			s.life -= delta
		sparks = sparks.filter(func(s): return s.life > 0.0)
		redraw = true
	if hint_t > 0.0:
		hint_t -= delta
		redraw = true
	if win_t >= 0.0 and win_t < 3.0:
		win_t += delta
		redraw = true
	if redraw:
		board.queue_redraw()

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if solved or over or not started:
		return
	var g := _geom()
	var p: Vector2 = (event.position - g.origin) / g.cell
	if p.x < 0 or p.y < 0 or p.x >= engine.w or p.y >= engine.h:
		return
	var cell: int = int(p.y) * engine.w + int(p.x)
	if engine.kind[cell] == PipeEngine.EMPTY:
		return
	if not engine.can_turn(cell):
		if engine.fixed[cell]:
			shake[cell] = 0.3
			_play("turn", -10.0, 0.6)
		return
	engine.rotate(cell)
	undo.append(cell)
	spin[cell] = spin.get(cell, 0.0) - PI / 2.0
	pop[cell] = 0.18
	hint_cell = -1
	_play("turn", -4.0, rng.randf_range(0.92, 1.08))
	_update()

func _on_undo() -> void:
	if undo.is_empty() or solved or over:
		return
	var cell: int = undo.pop_back()
	engine.unrotate(cell)
	spin[cell] = spin.get(cell, 0.0) + PI / 2.0
	_play("turn", -8.0, 0.8)
	_update()

func _on_hint() -> void:
	home.try_help(_hint_now)

## 💡 help (STANDARDS §17): flashes one tile that is turned the wrong way.
func _hint_now() -> bool:
	if solved or over or not started:
		return false
	hint_cell = engine.hint_cell(rng)
	if hint_cell < 0:
		return false
	hint_t = 2.5
	hints_used += 1
	_play("notify")
	return true

func _on_solved() -> void:
	solved = true
	win_t = 0.0
	hint_cell = -1
	SaveUtil.delete(SAVE_PATH)
	_play("done")
	var stars: int = engine.stars(hints_used)
	var greens := 0
	for c in engine.w * engine.h:
		if engine.kind[c] == PipeEngine.BULB and engine.color[c] == PipeEngine.GREEN:
			greens += 1
		if engine.kind[c] == PipeEngine.BULB:
			_spark_burst(c, _bulb_colour(c), 10)
	_win_fx()
	var note := ""
	if info:
		info.add("Puzzles solved")
		if greens > 0:
			info.add("Green bulbs lit", greens)
	match mode:
		"campaign":
			var best: int = int(progress.stars.get(str(cur_level), 0))
			if stars > best:
				progress.stars[str(cur_level)] = stars
			_save_progress()
			if info:
				info.high("Campaign levels", _cleared())
				info.high("Campaign stars", _total_stars())
				if stars == 3:
					info.add("Perfect levels")
		"daily":
			var day := _today()
			if int(progress.get("daily_day", 0)) != day:
				if int(progress.get("daily_day", 0)) == day - 1:
					progress.daily_streak = int(progress.get("daily_streak", 0)) + 1
				else:
					progress.daily_streak = 1
				progress.daily_day = day
				progress.daily_done = int(progress.get("daily_done", 0)) + 1
				progress.best_streak = maxi(int(progress.get("best_streak", 0)), int(progress.daily_streak))
				if int(progress.daily_streak) % 7 == 0:
					progress.streak7 = int(progress.get("streak7", 0)) + 1
				_save_progress()
				note = tr("Daily streak: %d") % int(progress.daily_streak)
				if info:
					info.high("Daily streak", int(progress.daily_streak))
			else:
				note = tr("Already done today. Come back tomorrow for a new one.")
		"time":
			ta_solved += 1
			time_left += 5.0
	if info:
		info.celebrate(tr("Solved!"))
	if mode == "time":
		# No card between boards: a short flash, then the next, harder one.
		var t := create_tween()
		t.tween_interval(0.9)
		t.tween_callback(_next_time_board)
		return
	var msg := tr("Moves: %d") % engine.moves + "   ·   " + _clock(elapsed)
	if note != "":
		msg += "\n" + note
	var t2 := create_tween()
	t2.tween_interval(1.5)
	t2.tween_callback(_show_solved_card.bind(stars, msg))

func _next_time_board() -> void:
	if over:
		return
	var lvl: int = mini(2 + ta_solved * 2, PipeEngine.LEVEL_COUNT)
	_begin("time", lvl, rng.randi(), true)

func _time_up() -> void:
	over = true
	time_left = 0.0
	started = true
	_play("short")
	var msg := tr("Boards lit: %d") % ta_solved
	if info:
		if info.high("Time attack best", ta_solved) and ta_solved > 0:
			msg += "\n" + tr("New best!")
	var buttons := [
		{"text": tr("Play again"), "action": _start_time},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	]
	_show_card(tr("Time's up!"), "", msg, buttons)

func _show_solved_card(stars: int, msg: String) -> void:
	var star_text := ""
	for i in 3:
		star_text += "★" if i < stars else "☆"
	var buttons: Array = []
	match mode:
		"campaign":
			if cur_level < PipeEngine.LEVEL_COUNT:
				buttons.append({"text": tr("Next level"), "action": _start_level.bind(cur_level + 1)})
			else:
				msg += "\n" + tr("Every level lit!")
			if stars < 3:
				buttons.append({"text": tr("Try for 3 stars"), "action": _restart})
			buttons.append({"text": tr("📋 Levels"), "action": _open_map.bind(false)})
		"zen":
			buttons.append({"text": tr("Next puzzle"), "action": _next_zen})
		"daily":
			buttons.append({"text": tr("Play again"), "action": _restart})
	buttons.append({"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home})
	_show_card(tr("Solved!"), star_text, msg, buttons)

## A small result card over the board: title, stars, a line of text, buttons.
func _show_card(title_text: String, stars_text: String, msg: String, buttons: Array) -> void:
	_close_end()
	end_card = ColorRect.new()
	end_card.color = Color(0, 0, 0, 0.7)
	end_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(end_card)
	end_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	end_card.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.16, 0.96)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = CUR[2]
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 44)
	t.add_theme_color_override("font_color", Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	if stars_text != "":
		# Stars pop in one by one.
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		for k in stars_text.length():
			var s := Label.new()
			s.text = stars_text[k]
			s.custom_minimum_size = Vector2(96, 104)
			s.pivot_offset = Vector2(48, 52)
			s.add_theme_font_size_override("font_size", 84)
			var on: bool = stars_text[k] == "★"
			s.add_theme_color_override("font_color", CUR[2] if on else Color(1, 1, 1, 0.3))
			s.add_theme_color_override("font_outline_color", Color(CUR[2], 0.5 if on else 0.0))
			s.add_theme_constant_override("outline_size", 10)
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			s.scale = Vector2.ZERO
			row.add_child(s)
			var st := s.create_tween()
			st.tween_interval(0.25 + 0.18 * k)
			st.tween_property(s, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if on:
				st.tween_callback(_play.bind("zap", -10.0, 1.0 + 0.15 * k))
	var m := Label.new()
	m.text = msg
	m.add_theme_font_size_override("font_size", 28)
	m.add_theme_color_override("font_color", HomeKit.DIM.lerp(Color.WHITE, 0.5))
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.custom_minimum_size = Vector2(380, 0)
	box.add_child(m)
	for spec in buttons:
		var b := Button.new()
		b.text = spec.text
		b.custom_minimum_size = Vector2(380, 68)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_card_button.bind(spec.action))
		box.add_child(b)
	# Card slides up and fades in; the dim layer fades too.
	end_card.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	var ct := end_card.create_tween().set_parallel()
	ct.tween_property(end_card, "modulate:a", 1.0, 0.25)
	ct.tween_method(_card_scale.bind(panel), 0.85, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _card_scale(v: float, panel: Control) -> void:
	if is_instance_valid(panel):
		panel.pivot_offset = panel.size / 2.0
		panel.scale = Vector2(v, v)

func _card_button(action: Callable) -> void:
	if action.is_valid():
		action.call()

func _close_end() -> void:
	if end_card and is_instance_valid(end_card):
		end_card.queue_free()
	end_card = null

# ---------- campaign progress and the level map ----------

func _load_progress() -> void:
	var d = SaveUtil.read(PROGRESS_PATH)
	progress = d if d is Dictionary else {}
	if not progress.get("stars") is Dictionary:
		progress["stars"] = {}

func _save_progress() -> void:
	SaveUtil.write(PROGRESS_PATH, progress)
	if cloud:
		cloud.saved()
		cloud.report_completion(_cloud_cleared(), PipeEngine.LEVEL_COUNT)

## Cloud vs device (STANDARDS §18): the copy with more levels cleared (then stars) wins.
func _progress_score(d: Dictionary) -> int:
	var st = d.get("stars", {})
	if not st is Dictionary:
		return 0
	var n := 0
	var total := 0
	for k in st:
		if int(st[k]) > 0:
			n += 1
			total += int(st[k])
	return n * 4 + total

func _cloud_cleared() -> int:
	var n := 0
	for k in progress.get("stars", {}):
		if int(progress.stars[k]) > 0:
			n += 1
	return n

func _cleared() -> int:
	var n := 0
	for k in progress.stars:
		if int(progress.stars[k]) > 0:
			n += 1
	return n

func _total_stars() -> int:
	var n := 0
	for k in progress.stars:
		n += int(progress.stars[k])
	return n

## First level without a star (the one after the last cleared run), capped at the last level.
func _next_level() -> int:
	for lvl in range(1, PipeEngine.LEVEL_COUNT + 1):
		if int(progress.stars.get(str(lvl), 0)) == 0:
			return lvl
	return PipeEngine.LEVEL_COUNT

## A level is open when the one before it has been cleared.
func _unlocked(lvl: int) -> bool:
	return lvl <= 1 or int(progress.stars.get(str(lvl - 1), 0)) > 0

func _open_map(from_landing: bool) -> void:
	_close_end()
	_close_map()
	map_from_landing = from_landing
	map_layer = ColorRect.new()
	(map_layer as ColorRect).color = Color(0.03, 0.04, 0.1, 0.97)
	map_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(map_layer)
	map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_layer.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_drag = HomeKit._DragScroll.new()
	scroll.add_child(map_drag)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	box.add_child(bar)
	var home_btn := HomeKit.neon_button(tr("🏠 Home"), HomeKit.BUTTON, 24, 60)
	home_btn.custom_minimum_size.x = 170
	home_btn.pressed.connect(_map_home)
	bar.add_child(home_btn)
	if not from_landing:
		var back := HomeKit.neon_button(tr("‹ Back"), HomeKit.BUTTON, 24, 60)
		back.custom_minimum_size.x = 150
		back.pressed.connect(_map_back)
		bar.add_child(back)
	var heading := Label.new()
	heading.text = tr("Levels")
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color", CUR[2].lerp(Color.WHITE, 0.6))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(heading)
	var total := Label.new()
	total.text = "★ %d / %d" % [_total_stars(), PipeEngine.LEVEL_COUNT * 3]
	total.add_theme_font_size_override("font_size", 28)
	total.add_theme_color_override("font_color", CUR[2])
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(total)

	for ch in PipeEngine.CHAPTERS.size():
		var first: int = ch * PipeEngine.CHAPTER_SIZE + 1
		var name_label := Label.new()
		name_label.text = tr("Chapter %d") % (ch + 1) + " · " + tr(PipeEngine.CHAPTERS[ch].name)
		name_label.add_theme_font_size_override("font_size", 26)
		name_label.add_theme_color_override("font_color", HomeKit.DIM.lerp(Color.WHITE, 0.4))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(name_label)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		box.add_child(grid)
		for i in PipeEngine.CHAPTER_SIZE:
			var lvl: int = first + i
			var stars: int = int(progress.stars.get(str(lvl), 0))
			var b := Button.new()
			b.text = str(lvl) + "\n" + ("🔒" if not _unlocked(lvl) else "★".repeat(stars) + "☆".repeat(3 - stars))
			b.custom_minimum_size = Vector2(0, 92)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 24)
			b.disabled = not _unlocked(lvl)
			if stars == 3:
				b.add_theme_color_override("font_color", CUR[2])
			b.pressed.connect(_map_pick.bind(lvl))
			grid.add_child(b)

func _map_pick(lvl: int) -> void:
	if map_drag and map_drag.moved:
		return
	if _unlocked(lvl):
		_start_level(lvl)

func _map_home() -> void:
	if map_drag and map_drag.moved:
		return
	_go_home()

func _map_back() -> void:
	if map_drag and map_drag.moved:
		return
	_close_map()

func _close_map() -> void:
	if map_layer and is_instance_valid(map_layer):
		map_layer.queue_free()
	map_layer = null
	map_drag = null

# ---------- sound and sparks ----------

func _play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s and s.has_method("play_stream"):
		s.play_stream(WireSfx.stream(sound), volume_db, pitch, "game")

func _bulb_colour(c: int) -> Color:
	return CUR.get(engine.color[c], CUR[2])

func _spark_burst(cell: int, col: Color, count: int) -> void:
	var centre := _cell_center(cell)
	for i in count:
		var a: float = rng.randf() * TAU
		sparks.append({"p": centre, "v": Vector2(cos(a), sin(a)) * rng.randf_range(80.0, 260.0),
			"life": rng.randf_range(0.3, 0.7), "col": col.lerp(Color.WHITE, rng.randf() * 0.6)})

## Solved: a soft white flash and confetti falling over the board.
func _win_fx() -> void:
	if flash:
		flash.color.a = 0.28
		var t := flash.create_tween()
		t.tween_property(flash, "color:a", 0.0, 0.5)
	var g := _geom()
	var span := Vector2(g.cell * engine.w, g.cell * engine.h)
	var cols: Array = [CUR[1], CUR[2], CUR[3], Color("ff5fa8"), Color.WHITE]
	for i in 48:
		var p: Vector2 = g.origin + Vector2(rng.randf() * span.x, rng.randf_range(-0.1, 0.3) * span.y)
		sparks.append({"p": p, "v": Vector2(rng.randf_range(-90, 90), rng.randf_range(-320, -60)),
			"life": rng.randf_range(1.0, 1.8), "col": cols[i % cols.size()], "g": 520.0, "sq": true})

# ---------- look pass art ----------

static func _radial(stops: Array, w: int = 64, h: int = 64) -> GradientTexture2D:
	var gr := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(s[0])
		cols.append(s[1])
	gr.offsets = offs
	gr.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = gr
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = w
	t.height = h
	return t

## Disc / glow / vignette textures (one draw_texture_rect is ~100x cheaper than draw_circle)
## and the backdrop's circuit traces + floating motes.
func _make_art() -> void:
	tex_disc = _radial([[0.0, Color.WHITE], [0.86, Color.WHITE], [1.0, Color(1, 1, 1, 0)]])
	tex_glow = _radial([[0.0, Color(1, 1, 1, 1)], [0.3, Color(1, 1, 1, 0.5)], [1.0, Color(1, 1, 1, 0)]])
	tex_vignette = _radial([[0.0, Color(0, 0, 0, 0)], [0.55, Color(0, 0, 0, 0)], [1.0, Color(0, 0, 0, 0.6)]], 128, 128)
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	for k in 16:
		var p := Vector2(r.randf(), r.randf())
		var pts: Array = [p]
		var horiz := r.randf() < 0.5
		for step in r.randi_range(3, 6):
			var d: float = r.randf_range(0.05, 0.18) * (1.0 if r.randf() < 0.5 else -1.0)
			if r.randf() < 0.25:
				p += Vector2(d, absf(d) * signf(r.randf() - 0.5)) * 0.7
			elif horiz:
				p += Vector2(d, 0)
			else:
				p += Vector2(0, d)
			horiz = not horiz
			pts.append(p)
		traces.append(pts)
		for j in pts.size() - 1:
			trace_lines.append(pts[j])
			trace_lines.append(pts[j + 1])
	for k in 26:
		motes.append({"x": r.randf(), "y": r.randf(), "s": r.randf_range(0.006, 0.02), "r": r.randf_range(3.0, 9.0)})

func _dot(ci: CanvasItem, p: Vector2, rad: float, col: Color) -> void:
	ci.draw_texture_rect(tex_disc, Rect2(p - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false, col)

func _bloom(ci: CanvasItem, p: Vector2, rad: float, col: Color) -> void:
	ci.draw_texture_rect(tex_glow, Rect2(p - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false, col)

static func _along(pts: Array, t: float) -> Vector2:
	var total := 0.0
	for j in pts.size() - 1:
		total += (pts[j + 1] - pts[j]).length()
	var want: float = t * total
	for j in pts.size() - 1:
		var l: float = (pts[j + 1] - pts[j]).length()
		if want <= l and l > 0.0:
			return pts[j].lerp(pts[j + 1], want / l)
		want -= l
	return pts[pts.size() - 1]

## Bulbs lit, as a glowing bar under the status line.
func _draw_hud_bar() -> void:
	var s := hud_bar.size
	var rr := Rect2(Vector2(0, 2), Vector2(s.x, s.y - 4))
	hud_bar.draw_rect(rr, Color(1, 1, 1, 0.08))
	if engine == null or engine.bulb_total <= 0:
		return
	var f: float = clampf(float(engine.lit_bulbs) / engine.bulb_total, 0.0, 1.0)
	if f <= 0.0:
		return
	var col: Color = CUR[3] if f >= 1.0 else CUR[2]
	var fill := Rect2(rr.position, Vector2(rr.size.x * f, rr.size.y))
	hud_bar.draw_rect(fill.grow(2), Color(col, 0.25))
	hud_bar.draw_rect(fill, col)
	hud_bar.draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.4)), Color(1, 1, 1, 0.35))

# ---------- drawing ----------

func _geom() -> Dictionary:
	var side_w: float = board.size.x - 24.0
	var side_h: float = board.size.y - 16.0
	var cell: float = floor(minf(minf(side_w / engine.w, side_h / engine.h), 150.0))
	var span := Vector2(cell * engine.w, cell * engine.h)
	return {"cell": cell, "origin": ((board.size - span) / 2.0).floor()}

## Look (STANDARDS §9): "classic" = blue tiles on indigo with a glowing current (default);
## "voodoo" = neon on black, with skull bulbs. Set by the kit (Options → Look).
var skin: String = "classic"
var bg: Control
var _sb_cell: float = -1.0
var _sb: Dictionary = {}

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		if bg is ColorRect:
			bg.color = Color("1a1146") if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	_sb_cell = -1.0
	if art_bg:
		art_bg.queue_redraw()
	if board:
		board.queue_redraw()

func _is_classic() -> bool:
	return skin == "classic"

func _draw_backdrop() -> void:
	var s := art_bg.size
	var classic := _is_classic()
	if classic:
		# Slowly breathing gradient.
		var br: float = 0.5 + 0.5 * sin(bg_t * 0.35)
		var top := Color("0f0a33")
		var bottom := Color("3a1f8c").lerp(Color("2a2a9c"), br * 0.5)
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(0, s.y)])
		art_bg.draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))
		# Faint bolts in the dark, like wallpaper.
		var bolt := PackedVector2Array([Vector2(0.55, 0.0), Vector2(0.18, 0.5), Vector2(0.47, 0.5), Vector2(0.3, 1.0), Vector2(0.82, 0.38), Vector2(0.52, 0.38)])
		for spec in [[Vector2(s.x * 0.84, s.y * 0.28), s.y * 0.2], [Vector2(s.x * 0.12, s.y * 0.82), s.y * 0.15]]:
			var poly := PackedVector2Array()
			for p in bolt:
				poly.append(spec[0] + (p - Vector2(0.5, 0.5)) * spec[1])
			art_bg.draw_colored_polygon(poly, Color(1, 1, 1, 0.035))
	# Big soft light pools drifting behind the board (depth).
	var pool_a: Color = Color(CUR[1], 0.10) if classic else Color(HomeKit.PURPLE, 0.12)
	var pool_b: Color = Color(CUR[2], 0.06) if classic else Color(HomeKit.PINK, 0.08)
	_bloom(art_bg, Vector2(s.x * (0.25 + 0.08 * sin(bg_t * 0.13)), s.y * 0.35), s.x * 0.75, pool_a)
	_bloom(art_bg, Vector2(s.x * (0.8 + 0.06 * cos(bg_t * 0.11)), s.y * 0.72), s.x * 0.6, pool_b)
	# Circuit traces (one batched multiline) with current pulses running along them.
	var sc := PackedVector2Array()
	sc.resize(trace_lines.size())
	for j in trace_lines.size():
		sc[j] = trace_lines[j] * s
	var line_col: Color = Color(0.6, 0.65, 1.0, 0.14) if classic else Color(HomeKit.PURPLE, 0.14)
	art_bg.draw_multiline(sc, line_col, 2.0)
	var pad: float = s.x * 0.007
	for k in traces.size():
		var pts: Array = traces[k]
		art_bg.draw_texture_rect(tex_disc, Rect2(pts[0] * s - Vector2(pad, pad), Vector2(pad, pad) * 2.0), false, line_col * Color(1, 1, 1, 2.0))
		if k % 2 == 0:
			var tt: float = fposmod(bg_t * 0.09 + k * 0.37, 1.0)
			var pc: Color = (CUR[1] if k % 4 == 0 else CUR[2]) if classic else (HomeKit.PINK if k % 4 == 0 else HomeKit.CYAN)
			var fade: float = sin(tt * PI)
			_bloom(art_bg, _along(pts, tt) * s, s.x * 0.03, Color(pc, 0.55 * fade))
			_dot(art_bg, _along(pts, tt) * s, s.x * 0.005, Color(Color.WHITE, 0.8 * fade))
	# Floating motes, rising slowly.
	for m in motes:
		var y: float = fposmod(m.y - bg_t * m.s, 1.0)
		var x: float = m.x + 0.015 * sin(bg_t * 0.7 + m.r)
		var a: float = 0.18 * sin(y * PI)
		_bloom(art_bg, Vector2(x, y) * s, m.r, Color(1, 1, 1, a) if classic else Color(HomeKit.CYAN, a))
	# Vignette pulls the eye to the board.
	art_bg.draw_texture_rect(tex_vignette, Rect2(Vector2(-s.x * 0.15, -s.y * 0.1), s * Vector2(1.3, 1.2)), false)

func _cache_styles(cell: float) -> void:
	if is_equal_approx(_sb_cell, cell):
		return
	_sb_cell = cell
	_sb.clear()
	var radius := int(cell * 0.11)
	var make := func(fill: Color, border: Color, bw: int) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = fill
		s.set_corner_radius_all(radius)
		s.set_border_width_all(bw)
		s.border_color = border
		s.anti_aliasing = true
		return s
	if _is_classic():
		var tc: Array = _theme().tiles
		_sb["lip"] = make.call(Color(tc[4]), Color(tc[4]), 0)
		_sb["a"] = make.call(Color(tc[0]), Color(tc[0]).lightened(0.25), 2)
		_sb["b"] = make.call(Color(tc[1]), Color(tc[1]).lightened(0.25), 2)
		_sb["fixed"] = make.call(Color(tc[2]), Color(tc[2]).lightened(0.2), 2)
		_sb["empty"] = make.call(Color(tc[3]), Color(tc[3]).lightened(0.15), 2)
	else:
		_sb["lip"] = make.call(Color(0.02, 0.02, 0.06), Color(0, 0, 0, 0), 0)
		_sb["a"] = make.call(Color(0.06, 0.07, 0.15), Color(HomeKit.PURPLE, 0.55), 2)
		_sb["b"] = make.call(Color(0.05, 0.06, 0.13), Color(HomeKit.PURPLE, 0.45), 2)
		_sb["fixed"] = make.call(Color(0.09, 0.08, 0.17), Color(HomeKit.PINK, 0.4), 2)
		_sb["empty"] = make.call(Color(0.04, 0.05, 0.1), Color(HomeKit.PURPLE, 0.3), 2)
	_sb["body"] = make.call(Color.WHITE, Color(0, 0, 0, 0.35), 2)
	_sb["cap"] = make.call(Color("c9c3bd"), Color("6e6862"), 2)

func _draw_board() -> void:
	if engine.kind.is_empty():
		return
	var g := _geom()
	var cell: float = g.cell
	var origin: Vector2 = g.origin
	var n: int = engine.w * engine.h
	_cache_styles(cell)
	var frame := Rect2(origin, Vector2(cell * engine.w, cell * engine.h))
	# Board pops in: a small scale-up around its centre.
	if intro_t < 0.45:
		var e: float = ease(clampf(intro_t / 0.45, 0.0, 1.0), -2.0)
		var k: float = 0.9 + 0.1 * e
		var mid: Vector2 = frame.get_center()
		board.draw_set_transform(mid * (1.0 - k), 0.0, Vector2(k, k))
	# The plate the tiles sit in: drop shadow, bevelled frame and four screws.
	var plate := frame.grow(cell * 0.14)
	if not _sb.has("plate"):
		var ps := StyleBoxFlat.new()
		ps.set_corner_radius_all(int(cell * 0.22))
		ps.anti_aliasing = true
		ps.set_border_width_all(3)
		if _is_classic():
			ps.bg_color = Color(_theme().tiles[5])
			ps.border_color = Color(_theme().tiles[6])
		else:
			ps.bg_color = Color(0.02, 0.02, 0.06)
			ps.border_color = Color(HomeKit.PURPLE, 0.6)
		ps.shadow_color = Color(0, 0, 0, 0.55)
		ps.shadow_size = int(cell * 0.3)
		ps.shadow_offset = Vector2(0, cell * 0.1)
		_sb["plate"] = ps
	board.draw_style_box(_sb.plate, plate)
	board.draw_rect(Rect2(plate.position + Vector2(cell * 0.25, 3), Vector2(plate.size.x - cell * 0.5, 2)), Color(1, 1, 1, 0.18))
	for cc in [plate.position, Vector2(plate.end.x, plate.position.y), plate.end, Vector2(plate.position.x, plate.end.y)]:
		var sp: Vector2 = cc + (frame.get_center() - cc).normalized() * cell * 0.1
		_dot(board, sp, cell * 0.035, Color(0.7, 0.72, 0.8, 0.8))
		board.draw_line(sp - Vector2(cell * 0.022, 0), sp + Vector2(cell * 0.022, 0), Color(0, 0, 0, 0.6), 1.5)
	if _is_classic():
		HomeKit.glow_rect(board, frame.grow(4), Color("7a4dff", 0.6), 3.0)
	else:
		HomeKit.glow_rect(board, frame.grow(6), Color(HomeKit.PURPLE, 0.7), 2.0)
	var gap: float = maxf(2.0, cell * 0.025)
	# Tiles.
	for i in n:
		var pos: Vector2 = origin + Vector2(i % engine.w, i / engine.w) * cell
		var r := Rect2(pos + Vector2(gap, gap), Vector2(cell - gap * 2.0, cell - gap * 2.0))
		var sb: StyleBoxFlat
		if engine.kind[i] == PipeEngine.EMPTY:
			sb = _sb.empty
		elif engine.fixed[i] and engine.kind[i] == PipeEngine.WIRE:
			sb = _sb.fixed
		else:
			sb = _sb.a if ((i % engine.w) + (i / engine.w)) % 2 == 0 else _sb.b
		var wob := 0.0
		if shake.has(i):
			wob = sin(shake[i] * 60.0) * cell * 0.03
		if pop.has(i):
			r = r.grow(-cell * 0.06 * sin(pop[i] / 0.18 * PI))
		board.draw_style_box(_sb.lip, Rect2(r.position + Vector2(wob, cell * 0.05), r.size))
		board.draw_style_box(sb, Rect2(r.position + Vector2(wob, 0.0), r.size))
		if _is_classic() and engine.kind[i] != PipeEngine.EMPTY:
			board.draw_rect(Rect2(r.position + Vector2(cell * 0.1 + wob, cell * 0.04), Vector2(r.size.x - cell * 0.2, cell * 0.03)), Color(1, 1, 1, 0.12))
	# Wires in three passes, so glows never cover a neighbour's casing.
	for pass_no in 3:
		for i in n:
			if engine.kind[i] != PipeEngine.EMPTY and engine.mask[i] != 0:
				_draw_wire(board, i, _cell_center(i), cell, pass_no)
	for i in n:
		if engine.kind[i] == PipeEngine.EMPTY:
			continue
		var centre := _cell_center(i)
		if engine.kind[i] == PipeEngine.SOURCE:
			_draw_battery(board, centre, cell, int(engine.color[i]), true, flow_t)
		elif engine.kind[i] == PipeEngine.BULB:
			_draw_bulb(board, i, centre, cell)
		elif engine.fixed[i] and not PipeEngine.rotated(engine.mask[i]) == engine.mask[i]:
			for corner in [Vector2(-1, -1), Vector2(1, 1)]:
				board.draw_circle(centre + corner * cell * 0.39, cell * 0.025, Color(1, 1, 1, 0.3))
		if (engine.kind[i] == PipeEngine.SOURCE or engine.kind[i] == PipeEngine.BULB) and not engine.fixed[i]:
			_draw_turn_ring(centre, cell)
	for s in sparks:
		var a: float = clampf(s.life * 2.2, 0.0, 1.0)
		if s.has("sq"):
			var sz: float = cell * 0.07
			var wv: float = absf(sin(s.life * 9.0))
			board.draw_rect(Rect2(s.p - Vector2(sz * wv, sz * 0.6) / 2.0, Vector2(sz * wv + 1.0, sz * 0.6)), Color(s.col, a))
		else:
			_bloom(board, s.p, cell * 0.09 + 3.0 * a, Color(s.col, a * 0.5))
			_dot(board, s.p, cell * 0.025 + 1.5 * a, Color(s.col.lerp(Color.WHITE, 0.5), a))
	if hint_cell >= 0 and hint_t > 0.0:
		var hp: Vector2 = origin + Vector2(hint_cell % engine.w, hint_cell / engine.w) * cell
		var pulse: float = 0.5 + 0.5 * sin(hint_t * 10.0)
		HomeKit.glow_rect(board, Rect2(hp, Vector2(cell, cell)).grow(-gap), Color(1, 1, 1, 0.5 + 0.5 * pulse), 3.0, 0.08 * pulse)
	board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## One cell's wire arms. pass 0 = glow under everything, 1 = casing, 2 = core,
## open ends and the pulses of current.
func _draw_wire(ci: CanvasItem, i: int, centre: Vector2, cell: float, pass_no: int) -> void:
	var m: int = engine.mask[i]
	var p: int = engine.power[i]
	var powered: bool = p != 0
	var col: Color = CUR[p] if powered else Color(0.2, 0.22, 0.32)
	if powered and win_t >= 0.0 and not _is_classic():
		col = col.lerp(Color.WHITE, 0.15)
	if powered and win_t >= 0.0:
		var dist: float = (centre - _cell_center(_first_source())).length() / cell
		var wave: float = clampf(1.0 - absf(dist - win_t * 7.0) / 1.5, 0.0, 1.0)
		col = col.lerp(Color.WHITE, wave * 0.75)
	if powered:
		# A travelling shimmer, so the current looks like it moves.
		var d: int = maxi(engine.depth[i], 0)
		col = col.lerp(Color.WHITE, 0.12 + 0.12 * sin(flow_t * 7.0 - d * 0.9))
	var wc: float = cell * 0.25
	var angle: float = spin.get(i, 0.0)
	var half: float = cell * 0.5
	var dark: Color = Color(0.04, 0.05, 0.1) if not powered else col.darkened(0.55)
	if not _is_classic():
		dark = Color(0.02, 0.02, 0.05) if not powered else col.darkened(0.7)
	for k in 4:
		var d: Array = PipeEngine.DIRS[k]
		if m & d[0] == 0:
			continue
		var dir := Vector2(d[1], d[2]).rotated(angle)
		var end: Vector2 = centre + dir * half
		var open: bool = engine.open_end(i, k)
		match pass_no:
			0:
				if powered:
					ci.draw_line(centre, end, Color(col, 0.13), wc * 1.9, true)
					ci.draw_line(centre, end, Color(col, 0.2), wc * 1.35, true)
			1:
				ci.draw_line(centre, end, dark, wc, true)
			2:
				ci.draw_line(centre, end, col, wc * 0.5, true)
				if powered and angle == 0.0:
					_draw_pulses(ci, i, k, centre, dir, half, wc)
				if open:
					var tip: Vector2 = centre + dir * half * 0.94
					_dot(ci, tip, wc * 0.34, Color("c97c3a") if _is_classic() else Color(HomeKit.PINK, 0.9))
					if powered and not solved and fposmod(flow_t * 3.0 + i, 1.0) < 0.55:
						_bloom(ci, tip + dir * wc * 0.3, wc * 0.7, Color(1, 1, 0.85, 0.9))
	if pass_no == 0 and powered:
		_bloom(ci, centre, wc * 1.3, Color(col, 0.4))
	elif pass_no == 1:
		_dot(ci, centre, wc * 0.52, dark)
	elif pass_no == 2:
		_dot(ci, centre, wc * 0.26, col)

func _draw_pulses(ci: CanvasItem, i: int, k: int, centre: Vector2, dir: Vector2, half: float, wc: float) -> void:
	var nb: int = engine.neighbour(i, k)
	var inward := false
	if nb >= 0 and engine.linked(i, k):
		var dn: int = engine.depth[nb]
		var d0: int = engine.depth[i]
		if dn == d0:
			return
		inward = dn < d0
	for j in 2:
		var t: float = fposmod(flow_t * 0.9 + j * 0.5 + (engine.depth[i] % 4) * 0.13, 1.0)
		if inward:
			t = 1.0 - t
		_dot(ci, centre + dir * half * t, wc * 0.2, Color(1, 1, 1, 0.8 * sin(t * PI)))

func _first_source() -> int:
	for c in engine.w * engine.h:
		if engine.kind[c] == PipeEngine.SOURCE:
			return c
	return 0

## A battery: a body in the current's colour, a metal cap and a bolt.
func _draw_battery(ci: CanvasItem, centre: Vector2, cell: float, colour: int, live: bool, t: float) -> void:
	var col: Color = CUR[colour]
	if live:
		var pulse: float = 0.5 + 0.5 * sin(t * 3.0)
		_bloom(ci, centre, cell * 0.6 * (0.95 + 0.05 * pulse), Color(col, 0.35))
	var bw: float = cell * 0.34
	var bh: float = cell * 0.44
	var body := Rect2(centre - Vector2(bw, bh) / 2.0 + Vector2(0, cell * 0.04), Vector2(bw, bh))
	var sb: StyleBoxFlat = _sb.body.duplicate()
	sb.bg_color = col.darkened(0.15)
	ci.draw_style_box(sb, body)
	ci.draw_rect(Rect2(body.position + Vector2(bw * 0.14, bh * 0.1), Vector2(bw * 0.16, bh * 0.8)), Color(1, 1, 1, 0.3))
	var cap := Rect2(Vector2(centre.x - bw * 0.3, body.position.y - cell * 0.1), Vector2(bw * 0.6, cell * 0.12))
	ci.draw_style_box(_sb.cap, cap)
	# Bolt.
	var b: float = cell * 0.13
	var c0: Vector2 = centre + Vector2(0, cell * 0.06)
	ci.draw_colored_polygon(PackedVector2Array([c0 + Vector2(0.15, -1.0) * b, c0 + Vector2(-0.7, 0.1) * b,
		c0 + Vector2(-0.05, 0.1) * b, c0 + Vector2(-0.2, 1.0) * b, c0 + Vector2(0.7, -0.15) * b,
		c0 + Vector2(0.05, -0.15) * b]), Color(1, 1, 1, 0.92))
	_draw_pip(ci, centre + Vector2(-0.36, -0.36) * cell, cell, colour)

## A bulb: socket, glass, and when lit a bloom of light. In the Voodoo skin the glass is a skull.
func _draw_bulb(ci: CanvasItem, i: int, centre: Vector2, cell: float) -> void:
	var need: int = engine.color[i]
	var col: Color = CUR[need]
	var lit: bool = engine.is_lit(i)
	var shorted: bool = engine.is_shorted(i)
	var r: float = cell * 0.2
	var glass: Vector2 = centre + Vector2(0, -cell * 0.05)
	if lit:
		var pulse: float = 0.5 + 0.5 * sin(flow_t * 4.0 + i)
		var big: float = 1.0 + (0.5 * sin(burst[i] / 0.8 * PI) if burst.has(i) else 0.0)
		if win_t >= 0.0:
			big += 0.25 * sin(win_t * 6.0)
		_bloom(ci, glass, r * 3.4 * big * (0.94 + 0.06 * pulse), Color(col, 0.55))
		for ray in 8:
			var a: float = TAU * ray / 8.0 + flow_t * 0.6
			var d: Vector2 = Vector2(cos(a), sin(a))
			ci.draw_line(glass + d * r * 1.35, glass + d * r * (1.9 + 0.4 * pulse) * big, Color(col.lerp(Color.WHITE, 0.5), 0.55), cell * 0.025, true)
	# Socket.
	var sock: Color = col.darkened(0.1) if lit else col.darkened(0.35)
	ci.draw_circle(centre + Vector2(0, cell * 0.17), cell * 0.17, sock.darkened(0.35))
	ci.draw_circle(centre + Vector2(0, cell * 0.155), cell * 0.16, sock)
	for k in 3:
		var y: float = centre.y + cell * (0.04 + 0.05 * k)
		ci.draw_line(Vector2(centre.x - cell * 0.075, y), Vector2(centre.x + cell * 0.075, y), Color(0.75, 0.75, 0.78, 0.9 if lit else 0.55), cell * 0.03, true)
	# Glass.
	var glass_col: Color = col.lerp(Color.WHITE, 0.82) if lit else col.lerp(Color(0.1, 0.09, 0.18), 0.55)
	if _is_classic():
		ci.draw_circle(glass, r, glass_col)
		if not lit:
			ci.draw_arc(glass, r, 0.0, TAU, 24, col.lerp(Color.WHITE, 0.35), maxf(1.5, cell * 0.02), true)
			var fil := Color(col.lerp(Color.WHITE, 0.6), 0.7)
			ci.draw_line(glass + Vector2(-r * 0.4, r * 0.5), glass + Vector2(-r * 0.15, -r * 0.05), fil, cell * 0.02, true)
			ci.draw_line(glass + Vector2(r * 0.4, r * 0.5), glass + Vector2(r * 0.15, -r * 0.05), fil, cell * 0.02, true)
			ci.draw_line(glass + Vector2(-r * 0.15, -r * 0.05), glass + Vector2(r * 0.15, -r * 0.05), fil, cell * 0.02, true)
		else:
			ci.draw_circle(glass + Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.9))
	else:
		_draw_skull(ci, glass, r * 1.05, glass_col, lit)
	if shorted:
		var flick: float = 0.5 + 0.5 * sin(flow_t * 18.0)
		HomeKit.glow_circle(ci, glass, r * 1.35, Color(COLOR_LEAK, 0.55 + 0.4 * flick), 2.5)
	_draw_pip(ci, centre + Vector2(-0.36, -0.36) * cell, cell, need)

func _draw_skull(ci: CanvasItem, c: Vector2, r: float, col: Color, lit: bool) -> void:
	ci.draw_circle(c + Vector2(0, -r * 0.1), r, col)
	ci.draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.5), Vector2(r, r * 0.7)), col)
	var eye := Color(0.03, 0.02, 0.08)
	ci.draw_circle(c + Vector2(-r * 0.38, -r * 0.1), r * 0.26, eye)
	ci.draw_circle(c + Vector2(r * 0.38, -r * 0.1), r * 0.26, eye)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.2), c + Vector2(-r * 0.12, r * 0.45), c + Vector2(r * 0.12, r * 0.45)]), eye)
	for k in 3:
		ci.draw_line(c + Vector2(-r * 0.25 + k * r * 0.25, r * 0.78), c + Vector2(-r * 0.25 + k * r * 0.25, r * 1.15), eye, maxf(1.5, r * 0.07))

## Colour is never the only cue: a ring for blue, a dot for yellow, both for green.
func _draw_pip(ci: CanvasItem, p: Vector2, cell: float, colour: int) -> void:
	var rr: float = cell * 0.055
	var col: Color = Color(1, 1, 1, 0.85)
	if colour == PipeEngine.BLUE or colour == PipeEngine.GREEN:
		ci.draw_arc(p, rr, 0.0, TAU, 14, col, maxf(1.5, cell * 0.018), true)
	if colour == PipeEngine.YELLOW or colour == PipeEngine.GREEN:
		ci.draw_circle(p, rr * (0.45 if colour == PipeEngine.GREEN else 0.8), col)

## A faint turning arrow around a battery or bulb that can be rotated.
func _draw_turn_ring(centre: Vector2, cell: float) -> void:
	var r: float = cell * 0.41
	var a0: float = flow_t * 0.8
	board.draw_arc(centre, r, a0, a0 + PI * 1.3, 18, Color(1, 1, 1, 0.35), maxf(2.0, cell * 0.025), true)
	var tip: Vector2 = centre + Vector2(cos(a0 + PI * 1.3), sin(a0 + PI * 1.3)) * r
	var dir: Vector2 = Vector2(-sin(a0 + PI * 1.3), cos(a0 + PI * 1.3))
	var side: Vector2 = Vector2(dir.y, -dir.x)
	board.draw_colored_polygon(PackedVector2Array([tip + dir * cell * 0.07, tip - dir * cell * 0.02 + side * cell * 0.05, tip - dir * cell * 0.02 - side * cell * 0.05]), Color(1, 1, 1, 0.4))

func _cell_center(i: int) -> Vector2:
	var g := _geom()
	return g.origin + Vector2(i % engine.w + 0.5, i / engine.w + 0.5) * g.cell

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 1.5, 110.0)
	var mid := c.size / 2.0
	var a := mid + Vector2(-k * 1.4, 0)
	var b := mid + Vector2(k * 1.4, 0)
	var col: Color = CUR[2]
	# Battery --- wire --- bulb, lit.
	HomeKit.glow_line(c, a + Vector2(k * 0.3, 0), b - Vector2(k * 0.3, 0), col, k * 0.09)
	HomeKit.glow_circle(c, b + Vector2(0, -k * 0.05), k * 0.42, col, 3.0, 0.25)
	c.draw_circle(b + Vector2(0, -k * 0.05), k * 0.24, col.lerp(Color.WHITE, 0.8))
	c.draw_rect(Rect2(b + Vector2(-k * 0.12, k * 0.2), Vector2(k * 0.24, k * 0.2)), col.darkened(0.2))
	var body := Rect2(a + Vector2(-k * 0.2, -k * 0.3), Vector2(k * 0.4, k * 0.6))
	c.draw_rect(body, Color(col, 0.95))
	c.draw_rect(Rect2(body.position + Vector2(k * 0.08, -k * 0.1), Vector2(k * 0.24, k * 0.1)), Color("c9c3bd"))
	HomeKit.glow_rect(c, body, col, 2.0)

# ---------- Workshop: board themes bought with earned bolts ----------

func _theme() -> Dictionary:
	var id: String = str(progress.get("theme", "classic"))
	for t in THEMES:
		if t.id == id:
			return t
	return THEMES[0]

func _owned(id: String) -> bool:
	return id == "classic" or (progress.get("owned", []) as Array).has(id)

func _full_chapters() -> int:
	var n := 0
	for ch in PipeEngine.CHAPTERS.size():
		var all := true
		for i in PipeEngine.CHAPTER_SIZE:
			if int(progress.stars.get(str(ch * PipeEngine.CHAPTER_SIZE + i + 1), 0)) == 0:
				all = false
				break
		if all:
			n += 1
	return n

## Bolts earned so far, worked out from progress (so cloud progress carries them too).
func _bolts_earned() -> int:
	var n: int = _total_stars() * BOLTS_STAR + _full_chapters() * BOLTS_CHAPTER
	n += int(progress.get("daily_done", 0)) * BOLTS_DAILY + int(progress.get("streak7", 0)) * BOLTS_STREAK7
	return n

func _bolts() -> int:
	return maxi(_bolts_earned() - int(progress.get("spent", 0)), 0)

## "" when the theme's goal is met, else the goal as text.
func _need_text(t: Dictionary) -> String:
	var need: String = t.need
	if need == "":
		return ""
	var parts := need.split(":")
	var v := int(parts[1])
	match parts[0]:
		"levels":
			if _cleared() >= v:
				return ""
			return tr("Clear %d campaign levels") % v + " (%d/%d)" % [_cleared(), v]
		"daily":
			if int(progress.get("daily_done", 0)) >= v:
				return ""
			return tr("Solve %d daily boards") % v + " (%d/%d)" % [int(progress.get("daily_done", 0)), v]
		"streak":
			if int(progress.get("best_streak", 0)) >= v:
				return ""
			return tr("Reach a %d-day daily streak") % v + " (%d/%d)" % [int(progress.get("best_streak", 0)), v]
	return ""

func _open_shop() -> void:
	_close_end()
	_close_shop()
	shop_layer = ColorRect.new()
	(shop_layer as ColorRect).color = Color(0.03, 0.04, 0.1, 0.97)
	shop_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shop_layer)
	shop_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_layer.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_drag = HomeKit._DragScroll.new()
	scroll.add_child(map_drag)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	box.add_child(bar)
	var home_btn := HomeKit.neon_button(tr("🏠 Home"), HomeKit.BUTTON, 24, 60)
	home_btn.custom_minimum_size.x = 170
	home_btn.pressed.connect(_shop_home)
	bar.add_child(home_btn)
	var heading := Label.new()
	heading.text = tr("Workshop")
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color", CUR[2].lerp(Color.WHITE, 0.6))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(heading)
	var wallet := Label.new()
	wallet.text = "⚡ %d %s" % [_bolts(), tr("bolts")]
	wallet.add_theme_font_size_override("font_size", 34)
	wallet.add_theme_color_override("font_color", CUR[2])
	wallet.add_theme_color_override("font_outline_color", Color(CUR[2], 0.4))
	wallet.add_theme_constant_override("outline_size", 6)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(wallet)
	var how := Label.new()
	how.text = tr("Earn bolts: %d per campaign star, %d per full chapter, %d per daily board, %d per 7-day streak. Themes change the Classic look.") % [BOLTS_STAR, BOLTS_CHAPTER, BOLTS_DAILY, BOLTS_STREAK7]
	how.add_theme_font_size_override("font_size", 20)
	how.add_theme_color_override("font_color", HomeKit.DIM.lerp(Color.WHITE, 0.3))
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(how)
	for t in THEMES:
		box.add_child(_shop_row(t))

func _shop_row(t: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.16, 0.95)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	var equipped: bool = _theme().id == t.id
	sb.border_color = CUR[3] if equipped else Color(0.5, 0.5, 1.0, 0.3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var sw := Control.new()
	sw.custom_minimum_size = Vector2(110, 84)
	sw.draw.connect(_draw_swatch.bind(sw, t))
	row.add_child(sw)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var name_l := Label.new()
	name_l.text = tr(t.name)
	name_l.add_theme_font_size_override("font_size", 28)
	col.add_child(name_l)
	var need := _need_text(t)
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", HomeKit.DIM.lerp(Color.WHITE, 0.3))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 64)
	b.add_theme_font_size_override("font_size", 22)
	if equipped:
		b.text = tr("In use")
		b.disabled = true
		sub.text = tr("Your board")
	elif _owned(t.id):
		b.text = tr("Use")
		sub.text = tr("Owned")
		b.pressed.connect(_shop_use.bind(t.id))
	elif need != "":
		b.text = "🔒"
		b.disabled = true
		sub.text = need
	else:
		b.text = "⚡ %d" % int(t.price)
		b.disabled = _bolts() < int(t.price)
		sub.text = tr("Ready to buy") if not b.disabled else tr("Not enough bolts yet")
		b.pressed.connect(_shop_buy.bind(t.id))
	row.add_child(b)
	return panel

## A tiny 3 x 2 board in the theme's colours, with a lit wire across it.
func _draw_swatch(c: Control, t: Dictionary) -> void:
	var tc: Array = t.tiles
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(tc[5]))
	var cw: float = (s.x - 8) / 3.0
	var chh: float = (s.y - 8) / 2.0
	for i in 6:
		var p := Vector2(4 + (i % 3) * cw, 4 + (i / 3) * chh)
		c.draw_rect(Rect2(p + Vector2(2, 4), Vector2(cw - 4, chh - 4)), Color(tc[4]))
		c.draw_rect(Rect2(p + Vector2(2, 2), Vector2(cw - 4, chh - 4)), Color(tc[i % 2]))
	var y: float = 4 + chh * 0.5
	c.draw_line(Vector2(4 + cw * 0.5, y), Vector2(4 + cw * 2.5, y), Color(CUR[2], 0.35), 10.0)
	c.draw_line(Vector2(4 + cw * 0.5, y), Vector2(4 + cw * 2.5, y), CUR[2], 4.0)
	c.draw_line(Vector2(4 + cw * 2.5, y), Vector2(4 + cw * 2.5, 4 + chh * 1.5), CUR[2], 4.0)
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(tc[6]), false, 2.0)

func _shop_buy(id: String) -> void:
	if map_drag and map_drag.moved:
		return
	for t in THEMES:
		if t.id == id and not _owned(id) and _need_text(t) == "" and _bolts() >= int(t.price):
			progress.spent = int(progress.get("spent", 0)) + int(t.price)
			var owned: Array = progress.get("owned", [])
			owned.append(id)
			progress.owned = owned
			_play("done")
			_shop_use(id)
			return

func _shop_use(id: String) -> void:
	if map_drag and map_drag.moved:
		return
	if not _owned(id):
		return
	progress.theme = id
	_save_progress()
	_sb_cell = -1.0
	board.queue_redraw()
	_play("zap", -6.0)
	_open_shop()

func _shop_home() -> void:
	if map_drag and map_drag.moved:
		return
	_close_shop()
	_go_home()

func _close_shop() -> void:
	if shop_layer and is_instance_valid(shop_layer):
		shop_layer.queue_free()
	shop_layer = null

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or solved or over or engine.kind.is_empty():
		return
	SaveUtil.write(SAVE_PATH, {"mode": mode, "level": cur_level, "seed": cur_seed, "zen": zen_diff,
		"mask": engine.mask, "moves": engine.moves, "time": elapsed, "hints": hints_used,
		"left": time_left, "boards": ta_solved})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if not d is Dictionary or not d.has("mode"):
		return ""
	match str(d.mode):
		"campaign":
			return tr("Level %d") % int(d.get("level", 1)) + "   ·   " + _clock(float(d.get("time", 0)))
		"daily":
			return tr("📅 Daily Challenge") + "   ·   " + _clock(float(d.get("time", 0)))
		"time":
			return tr("⏱ Time Attack") + "   ·   " + _clock(maxf(float(d.get("left", 0)), 0.0))
	return tr(ZEN_NAMES[clampi(int(d.get("zen", 0)), 0, ZEN_NAMES.size() - 1)]) + "   ·   " + _clock(float(d.get("time", 0)))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if not d is Dictionary or not d.has("mode"):
		SaveUtil.delete(SAVE_PATH)  # an old Pipe Flow save: not playable any more
		_start_campaign()
		return
	zen_diff = clampi(int(d.get("zen", 0)), 0, ZEN_NAMES.size() - 1)
	ta_solved = int(d.get("boards", 0))
	time_left = float(d.get("left", TIME_ATTACK_SECONDS))
	over = false
	_begin(str(d.mode), int(d.get("level", 1)), int(d.get("seed", 1)), true)
	var mk: Array = d.get("mask", [])
	if mk.size() == engine.mask.size():
		for c in mk.size():
			engine.mask[c] = int(mk[c])
		engine.moves = int(d.get("moves", 0))
	elapsed = float(d.get("time", 0.0))
	hints_used = int(d.get("hints", 0))
	engine.analyze()
	_sync_state()
	_update(false)
