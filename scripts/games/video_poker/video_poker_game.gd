extends Control

## Poker: Texas Hold'em, Omaha, Five Card Draw and Seven Card Stud against
## the computer (cash tables and tournaments), on one phone (pass and play)
## or online heads-up, plus the Video Poker machine and 🎓 Training (a
## coach, hand rankings and drills). Play chips only, kept between visits.
##
## The pack id stays video_poker: Poker grew out of the Video Poker game,
## and its stats and leaderboard carry on.
##
## The table is video_poker_table.gd (pure logic and JSON-safe: it is the
## save and the online state), drawn by video_poker_view.gd. The computer
## players and the coach think on a worker thread (video_poker_ai.gd).

const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const AI = preload("res://scripts/games/video_poker/video_poker_ai.gd")
const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")
const Cards = preload("res://scripts/games/video_poker/video_poker_cards.gd")
const View = preload("res://scripts/games/video_poker/video_poker_view.gd")
const Machine = preload("res://scripts/games/video_poker/video_poker_machine.gd")
const Training = preload("res://scripts/games/video_poker/video_poker_training.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/video_poker/home_kit.gd")
const HELP := preload("res://scripts/games/video_poker/video_poker_help.gd")
## Not preloaded: apps before v0.20 / v0.14 don't have them.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"
const TITLE_FOR_HOME := HELP.TITLE

## The table in progress (cash, tournament, pass and play).
const SAVE_PATH := "user://video_poker_save.json"
## The Video Poker machine's hand in progress.
const VP_SAVE_PATH := "user://video_poker_machine.json"
## The player's chips and their last choices.
const CHIPS_PATH := "user://video_poker_chips.json"

const START_CHIPS := 1000
## Below this (and nothing at a table) the house tops you up to START_CHIPS.
const REFILL_BELOW := 100
## Cash tables: [small blind, big blind, buy-in]. You can sit with 40% of it.
const STAKES := [[10, 20, 1000], [50, 100, 5000], [250, 500, 25000]]
const STAKE_NAMES := ["Low stakes", "Mid stakes", "High stakes"]
const MIN_BUYIN := 0.4
## Tournaments, pass and play and online matches: everyone starts with
## MATCH_STACK and the blinds climb these levels.
const MATCH_STACK := 1500
const BLIND_LEVELS := [[10, 20], [15, 30], [25, 50], [50, 100], [75, 150], [100, 200], [150, 300],
	[200, 400], [300, 600], [400, 800], [600, 1200], [1000, 2000], [1500, 3000], [2500, 5000], [4000, 8000]]
const HANDS_PER_LEVEL := {"tourney": 6, "local": 8, "online": 8}
const PRACTICE_STACK := 1000
## Online: the host deals the next hand after this many seconds.
const NEXT_DELAY := 6.0

const VARIANT_NAMES := {"holdem": "Texas Hold'em", "omaha": "Omaha", "draw": "Five Card Draw", "stud": "Seven Card Stud"}
const VARIANT_SHORT := {"holdem": "Hold'em", "omaha": "Omaha", "draw": "5-Card Draw", "stud": "7-Card Stud"}
const LIMIT_NAMES := {"nl": "No limit", "pl": "Pot limit", "fl": "Limit"}
const LEVEL_NAMES := ["Easy", "Normal", "Hard"]

var info = null   # GameInfo; null on apps without it, so guard every use
var home          # HomeKit
var online: Control = null
var rng := RandomNumberGenerator.new()
var started := false

var t = Table.new()
## "" (Home) | cash | tourney | local | online | practice | vp | training
var mode := ""
var chips := START_CHIPS
var prefs := {"variant": "holdem", "limit": "nl", "opps": 3, "level": 1, "coach": false, "stakes": 0, "players": 2}
var ai_level := 1
var stakes := 0
var buyin := 0
var coach_on := false
var viewer := 0
## Tournament / match bookkeeping: hands dealt, blind level, the order
## seats went out in, how many started.
var meta := {"hands": 0, "level": 0, "out": [], "start": 0}
var handled_hand := -1      # hand_no whose end was already counted
var result_recorded := false
var my_player := 0          # online: 1 host, 2 guest

var think_task := -1
var think_result: Dictionary = {}
var think_key := ""
var coach_task := -1
var coach_result: Dictionary = {}
var coach_key := ""
var coach_note := ""
var note := ""              # one-off message for the status line

var raise_to := 0
var discards: Array = []
var cover_seat := -1

# ---------- nodes ----------
var table_screen: VBoxContainer
var title_label: Label
var info_label: Label
var coach_btn: Button
var view: Control
var coach_panel: PanelContainer
var coach_label: Label
var status_label: Label
var size_row: HBoxContainer
var action_row: HBoxContainer
var fold_btn: Button
var call_btn: Button
var raise_btn: Button
var next_btn: Button
var leave_btn: Button
var machine: Control
var training: Control
var cover: ColorRect
var cover_label: Label
var end_dialog: ColorRect
var sheet: Control = null
var chips_label: Label
var variant_btns: Array = []
var limit_btns: Array = []
var cpu_timer: Timer
var next_timer: Timer
var chip_stream: AudioStreamWAV

func _ready() -> void:
	preload("res://scripts/games/video_poker/video_poker_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	_load_chips()
	_build_ui()
	if info:
		info.high("Most chips", chips + _saved_table_chips())
	started = false
	_show_screen("")

func _exit_tree() -> void:
	for task in [think_task, coach_task]:
		if task >= 0:
			WorkerThreadPool.wait_for_task_completion(task)
	think_task = -1
	coach_task = -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- chips and choices ----------

func _load_chips() -> void:
	var d = SaveUtil.read(CHIPS_PATH)
	if d != null:
		chips = int(d.get("chips", START_CHIPS))
		var p: Dictionary = d.get("prefs", {})
		for k in prefs:
			if p.has(k):
				prefs[k] = p[k]
	prefs.opps = clampi(int(prefs.opps), 1, 5)
	prefs.level = clampi(int(prefs.level), 0, 2)
	prefs.players = clampi(int(prefs.players), 2, 6)
	prefs.stakes = clampi(int(prefs.stakes), 0, STAKES.size() - 1)
	prefs.coach = bool(prefs.coach)
	if not Table.VARIANTS.has(str(prefs.variant)):
		prefs.variant = "holdem"
	if not Table.LIMITS.has(str(prefs.limit)):
		prefs.limit = "nl"
	coach_on = prefs.coach
	# The old Video Poker kept its credits in the table save: bring them over
	# (a coin is now 10 chips).
	var old = SaveUtil.read(SAVE_PATH)
	if old != null and not old.has("v") and old.has("credits"):
		chips += int(old.get("credits", 0)) * 10
		SaveUtil.delete(SAVE_PATH)
		_save_chips()
	if d == null:
		_save_chips()

func _save_chips() -> void:
	SaveUtil.write(CHIPS_PATH, {"chips": chips, "prefs": prefs})

## Chips sitting at a saved cash table (not in `chips` while seated).
func _saved_table_chips() -> int:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or str(d.get("mode", "")) != "cash":
		return 0
	var tt = Table.new()
	tt.from_dict(d.get("t", {}))
	for s in tt.seats:
		if int(s.kind) == 1:
			return int(s.stack)  # chips already in a pot stay there
	return 0

## Nothing left to play with: the house tops you up.
func _refill_if_broke() -> bool:
	if chips >= REFILL_BELOW or _saved_table_chips() > 0:
		return false
	chips = START_CHIPS
	_save_chips()
	note = tr("Out of chips? The house spots you %s.") % View._chips(START_CHIPS)
	return true

func _update_most_chips() -> void:
	if not info:
		return
	var total := chips
	if mode == "cash":
		var me := _hero_seat()
		if me >= 0:
			total += int(t.seats[me].stack)
	info.high("Most chips", total)

# ---------- building the screen ----------

## Look (STANDARDS §9): "classic" = traditional ivory cards on green felt (default); "voodoo" = the neon
## board. Set by the kit (Options → Look).
var skin: String = "classic"
var bg: ColorRect

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.felt_dark if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	Cards.classic = skin == "classic"
	_redraw_cards()

func _redraw_cards() -> void:
	for n in find_children("*", "CanvasItem", true, false):
		n.queue_redraw()

func _is_classic() -> bool:
	return skin == "classic"

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)
	_build_table_screen()

	machine = Machine.new()
	machine.visible = false
	machine.pause_pressed.connect(_on_pause)
	machine.chips_changed.connect(_on_machine_chips)
	machine.hand_finished.connect(_on_machine_hand)
	add_child(machine)

	training = Training.new()
	training.visible = false
	training.back_pressed.connect(_leave_training)
	training.practice_pressed.connect(_start_practice)
	add_child(training)

	_build_cover()
	end_dialog = UI.build_dialog("", [
		{"text": tr("Play again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.timeout.connect(_on_cpu_timer)
	add_child(cpu_timer)
	next_timer = Timer.new()
	next_timer.one_shot = true
	next_timer.timeout.connect(_on_next_timer)
	add_child(next_timer)

	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("video_poker", tr(TITLE_FOR_HOME), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_on_remote_new_game)
		online.status_changed.connect(_render)
		add_child(online)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	training.info = info
	var modes: Array = [
		{"text": "💰 Cash game", "sub": "Sit down with the computer. Leave any time.", "action": _ask_cash},
		{"text": "🏆 Tournament", "sub": "Everyone starts equal, the blinds rise, last one standing wins", "action": _ask_tourney},
		{"text": "🎰 Video Poker", "sub": "Jacks or Better, played with your chips", "action": _start_vp, "color": HomeKit.PINK},
		{"text": "🎓 Training", "sub": "A coach at the table, hand rankings and drills", "action": _open_training, "color": HomeKit.LIME},
		{"text": "👥 Pass and play", "sub": "2 to 6 players share one phone", "multi": true, "action": _ask_local},
	]
	if online:
		modes.append({"text": "🌐 Online", "sub": "Heads-up against a friend on another phone", "multi": true,
			"color": HomeKit.PURPLE, "action": online.open_lobby})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Hold'em, Omaha, Draw and Stud. Play chips only.",
		"logo": _draw_home_logo,
		"extra": _add_home_options,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Most chips",
		"board_note": "The most chips you've ever had. Play chips only.",
		"online": online,
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.035)  # the free corner at the end of the top bar
	add_child(drawer)

func _build_table_screen() -> void:
	table_screen = VBoxContainer.new()
	table_screen.add_theme_constant_override("separation", 6)
	add_child(table_screen)
	table_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 16)
	top.add_theme_constant_override("margin_left", 14)
	top.add_theme_constant_override("margin_right", 14)
	table_screen.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(72, 60)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	bar.add_child(titles)
	title_label = HomeKit.label("", 26, HomeKit.GOLD.lerp(Color.WHITE, 0.4), false, true)
	title_label.clip_text = true
	titles.add_child(title_label)
	info_label = HomeKit.label("", 20, HomeKit.DIM, false, true)
	info_label.clip_text = true
	titles.add_child(info_label)
	coach_btn = Button.new()
	coach_btn.text = "🎓"
	coach_btn.custom_minimum_size = Vector2(72, 60)
	coach_btn.toggle_mode = true
	coach_btn.pressed.connect(_toggle_coach)
	bar.add_child(coach_btn)
	# A free corner for the floating ⚙ tab (the whole table below is tappable).
	var tab_space := Control.new()
	tab_space.custom_minimum_size = Vector2(40, 0)
	tab_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(tab_space)

	view = View.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.card_tapped.connect(_on_card_tapped)
	table_screen.add_child(view)

	var pm := MarginContainer.new()
	for side in ["left", "right"]:
		pm.add_theme_constant_override("margin_" + side, 14)
	table_screen.add_child(pm)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pm.add_child(col)
	coach_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(HomeKit.LIME, 0.07)
	sb.border_color = Color(HomeKit.LIME, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	for side in ["left", "right"]:
		sb.set("content_margin_" + side, 12)
	for side in ["top", "bottom"]:
		sb.set("content_margin_" + side, 6)
	coach_panel.add_theme_stylebox_override("panel", sb)
	col.add_child(coach_panel)
	coach_label = HomeKit.label("", 21, HomeKit.LIME.lerp(Color.WHITE, 0.35), true)
	coach_panel.add_child(coach_label)
	status_label = HomeKit.label("", 24, HomeKit.WHITE, true, true)
	col.add_child(status_label)

	size_row = HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 8)
	col.add_child(size_row)
	var specs := [["−", _step_raise.bind(-1)], ["Min", _size_preset.bind("min")], ["½ Pot", _size_preset.bind("half")],
		["Pot", _size_preset.bind("pot")], ["All in", _size_preset.bind("all")], ["+", _step_raise.bind(1)]]
	for s in specs:
		var b := HomeKit.neon_button(tr(s[0]), HomeKit.MAGENTA, 22, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.clip_text = true
		b.pressed.connect(s[1])
		size_row.add_child(b)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 26)
	col.add_child(bm)
	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	bm.add_child(action_row)
	fold_btn = _action_button("Fold", HomeKit.DIM, _on_fold)
	fold_btn.set_meta("sfx", "")
	call_btn = _action_button("Call", HomeKit.CYAN, _on_call)
	call_btn.set_meta("sfx", "")
	raise_btn = _action_button("Raise", HomeKit.MAGENTA, _on_raise)
	raise_btn.set_meta("sfx", "")
	leave_btn = _action_button("Leave table", HomeKit.DIM, _on_leave)
	next_btn = _action_button("Next hand ▶", HomeKit.LIME, _on_next)
	next_btn.set_meta("sfx", "")

func _action_button(text: String, color: Color, action: Callable) -> Button:
	var b := HomeKit.neon_button(tr(text), color, 25, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	action_row.add_child(b)
	return b

## Pass and play: a full-screen cover whenever the phone changes hands.
func _build_cover() -> void:
	cover = ColorRect.new()
	cover.color = HomeKit.BG
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.visible = false
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	cover.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.custom_minimum_size = Vector2(560, 0)
	center.add_child(box)
	box.add_child(HomeKit.label("🂠", 90, HomeKit.PURPLE, false, true))
	cover_label = HomeKit.label("", 38, HomeKit.WHITE, true, true)
	box.add_child(cover_label)
	box.add_child(HomeKit.label(tr("Everyone else, look away!"), 24, HomeKit.DIM, true, true))
	var ready := HomeKit.neon_button(tr("I'm ready"), HomeKit.LIME, 32, 84)
	ready.pressed.connect(_on_cover_ready)
	box.add_child(ready)
	var pause := HomeKit.neon_button(tr("⏸ Pause"), HomeKit.DIM, 26, 64)
	pause.pressed.connect(_on_pause)
	box.add_child(pause)

func _show_screen(which: String) -> void:
	table_screen.visible = which == "table"
	machine.visible = which == "vp"
	training.visible = which == "training"
	if which != "table":
		cover.visible = false

# ---------- Home ----------

func _add_home_options(box: VBoxContainer) -> void:
	_refill_if_broke()
	chips_label = HomeKit.label("", 30, HomeKit.GOLD.lerp(Color.WHITE, 0.35), false, true)
	box.add_child(chips_label)
	_update_chips_label()
	box.add_child(home.section("Game"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	var group := ButtonGroup.new()
	variant_btns = []
	for v in Table.VARIANTS:
		var b := _toggle(tr(VARIANT_SHORT[v]), HomeKit.GOLD, group)
		b.button_pressed = v == prefs.variant
		b.pressed.connect(_pick_variant.bind(v))
		grid.add_child(b)
		variant_btns.append(b)
	box.add_child(home.section("Betting"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var lgroup := ButtonGroup.new()
	limit_btns = []
	for l in Table.LIMITS:
		var b := _toggle(tr(LIMIT_NAMES[l]), HomeKit.CYAN, lgroup)
		b.pressed.connect(_pick_limit.bind(l))
		row.add_child(b)
		limit_btns.append(b)
	_update_limit_buttons()

func _toggle(text: String, color: Color, group: ButtonGroup) -> Button:
	var b := HomeKit.neon_button(text, color, 24, 62)
	b.toggle_mode = true
	b.button_group = group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on := HomeKit.neon_box(color, "pressed")
	on.bg_color = Color(color, 0.45)
	on.set_border_width_all(3)
	b.add_theme_stylebox_override("pressed", on)
	return b

func _update_chips_label() -> void:
	if chips_label:
		chips_label.text = "🪙 " + tr("Your chips: %s") % View._chips(chips)
		if note != "":
			chips_label.text += "\n" + note
			note = ""

func _pick_variant(v: String) -> void:
	prefs.variant = v
	if v == "stud":
		prefs.limit = "fl"
	_update_limit_buttons()
	_save_chips()

func _pick_limit(l: String) -> void:
	if prefs.variant == "stud" and l != "fl":
		_update_limit_buttons()
		return
	prefs.limit = l
	_save_chips()

## Seven Card Stud is played Limit only (antes and a bring-in).
func _update_limit_buttons() -> void:
	for i in limit_btns.size():
		var l: String = Table.LIMITS[i]
		limit_btns[i].disabled = prefs.variant == "stud" and l != "fl"
		limit_btns[i].button_pressed = l == prefs.limit

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y * 0.78, 150.0)
	var w := h / 1.42
	var o := c.size / 2.0
	# chip stacks either side
	for side in [-1, 1]:
		var base := o + Vector2(side * (w * 1.25 + 34), h * 0.32)
		for k in 5:
			var p: Vector2 = base + Vector2(0, -k * 9.0)
			var col: Color = HomeKit.MAGENTA if (k + (1 if side > 0 else 0)) % 2 == 0 else HomeKit.CYAN
			c.draw_circle(p, 24, Color(0.05, 0.05, 0.1))
			HomeKit.glow_circle(c, p, 24, col, 2.0, 0.25)
			c.draw_arc(p, 15, 0, TAU, 24, Color(Color.WHITE, 0.5), 1.5, true)
	# two hole cards, fanned
	var cards := [0, 13]
	for k in 2:
		var ang := (-0.18 if k == 0 else 0.18)
		var center := o + Vector2((k - 0.5) * w * 0.55, 0)
		c.draw_set_transform(center, ang, Vector2.ONE)
		Cards.draw_card(c, Rect2(Vector2(-w / 2.0, -h / 2.0), Vector2(w, h)), cards[k], true, k == 1)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------- setup sheets ----------

## A full-screen panel with a title, the given rows and Start / Cancel.
func _open_sheet(title: String, build: Callable, start_text: String, start: Callable) -> void:
	_close_sheet()
	sheet = ColorRect.new()
	(sheet as ColorRect).color = Color(HomeKit.BG, 0.98)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.add_to_group("modal_overlay")
	add_child(sheet)
	move_child(sheet, home.get_index())
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 40)
	m.add_theme_constant_override("margin_top", 50)
	m.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(m)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	m.add_child(box)
	var tl := HomeKit.label(title, 44, HomeKit.WHITE, true, true)
	tl.add_theme_color_override("font_outline_color", Color(HomeKit.GOLD, 0.5))
	tl.add_theme_constant_override("outline_size", 10)
	box.add_child(tl)
	box.add_child(HomeKit.label("%s · %s" % [tr(VARIANT_NAMES[prefs.variant]), tr(LIMIT_NAMES[_limit_for(prefs.variant)])], 24, HomeKit.DIM, true, true))
	build.call(box)
	box.add_child(HomeKit.gap(8))
	var go := HomeKit.neon_button(tr(start_text), HomeKit.LIME, 32, 84)
	go.pressed.connect(start)
	box.add_child(go)
	var cancel := HomeKit.neon_button(tr("Cancel"), HomeKit.DIM, 26, 66)
	cancel.pressed.connect(_cancel_sheet)
	box.add_child(cancel)

func _close_sheet() -> void:
	if sheet:
		sheet.queue_free()
		sheet = null

func _cancel_sheet() -> void:
	_close_sheet()
	home.show_home()

func _limit_for(variant: String) -> String:
	return "fl" if variant == "stud" else str(prefs.limit)

func _opponent_rows(box: VBoxContainer) -> void:
	box.add_child(home.section("Computer opponents"))
	box.add_child(home.choice_row(["1", "2", "3", "4", "5"], int(prefs.opps) - 1, _set_pref.bind("opps", 1)))
	box.add_child(home.section("Computer level"))
	box.add_child(home.choice_row(LEVEL_NAMES, int(prefs.level), _set_pref.bind("level", 0), HomeKit.MAGENTA))

func _set_pref(i: int, key: String, offset: int) -> void:
	prefs[key] = i + offset
	_save_chips()

func _ask_cash() -> void:
	_refill_if_broke()
	_open_sheet(tr("💰 Cash game"), _cash_rows, "Sit down", _sit_cash)

func _cash_rows(box: VBoxContainer) -> void:
	box.add_child(HomeKit.label("🪙 " + tr("Your chips: %s") % View._chips(chips), 28, HomeKit.GOLD, false, true))
	if note != "":
		box.add_child(HomeKit.label(note, 22, HomeKit.LIME, true, true))
		note = ""
	box.add_child(home.section("Stakes"))
	var group := ButtonGroup.new()
	var best := 0
	for i in STAKES.size():
		if chips >= int(STAKES[i][2] * MIN_BUYIN):
			best = i
	if int(prefs.stakes) > best:
		prefs.stakes = best
	for i in STAKES.size():
		var s: Array = STAKES[i]
		var text := tr(STAKE_NAMES[i]) + "\n" + tr("Blinds %s/%s · buy-in %s") % [View._chips(s[0]), View._chips(s[1]), View._chips(s[2])]
		var b := _toggle(text, HomeKit.GOLD, group)
		b.custom_minimum_size.y = 90
		b.disabled = chips < int(s[2] * MIN_BUYIN)
		b.button_pressed = i == int(prefs.stakes)
		b.pressed.connect(_set_pref.bind(i, "stakes", 0))
		box.add_child(b)
	_opponent_rows(box)

func _ask_tourney() -> void:
	_open_sheet(tr("🏆 Tournament"), _tourney_rows, "Start", _start_tourney)

func _tourney_rows(box: VBoxContainer) -> void:
	box.add_child(HomeKit.label(tr("Free to enter. Everyone starts with %s chips and the blinds go up every %d hands.") % [View._chips(MATCH_STACK), HANDS_PER_LEVEL.tourney], 24, HomeKit.DIM, true, true))
	_opponent_rows(box)

func _ask_local() -> void:
	_open_sheet(tr("👥 Pass and play"), _local_rows, "Start", _start_local)

func _local_rows(box: VBoxContainer) -> void:
	box.add_child(HomeKit.label(tr("Everyone starts with %s chips; the blinds go up every %d hands. Last one with chips wins.") % [View._chips(MATCH_STACK), HANDS_PER_LEVEL.local], 24, HomeKit.DIM, true, true))
	box.add_child(home.section("Players"))
	box.add_child(home.choice_row(["2", "3", "4", "5", "6"], int(prefs.players) - 2, _set_pref.bind("players", 2)))

# ---------- starting a table ----------

## Ends the saved table (Home's New … buttons): chips at a cash table go
## back to the player.
func _discard_save() -> void:
	var at_table := _saved_table_chips()
	if at_table > 0:
		chips += at_table
		_save_chips()
	SaveUtil.delete(SAVE_PATH)

func _new_table(seat_list: Array, sb: int, bb: int) -> void:
	t = Table.new()
	t.variant = str(prefs.variant)
	t.limit = _limit_for(t.variant)
	t.sb = sb
	t.bb = bb
	t.seats = seat_list
	t.button = rng.randi_range(0, seat_list.size() - 1)
	meta = {"hands": 0, "level": 0, "out": [], "start": seat_list.size()}
	handled_hand = -1
	result_recorded = false
	viewer = 0
	discards = []
	coach_result = {}
	coach_key = ""
	coach_note = ""
	think_key = ""
	coach_on = bool(prefs.coach)  # the coach table turns it on for itself
	end_dialog.visible = false
	cover.visible = false

func _cpu_seats(n: int, stack_of: Callable) -> Array:
	var names: Array = AI.NAMES.duplicate()
	names.shuffle()
	var out: Array = []
	for i in n:
		out.append(Table.new_seat(names[i], int(stack_of.call()), 0, rng.randi_range(0, AI.STYLES.size() - 1)))
	return out

func _sit_cash() -> void:
	_close_sheet()
	_discard_save()
	stakes = int(prefs.stakes)
	var s: Array = STAKES[stakes]
	buyin = mini(int(s[2]), chips)
	if buyin < int(s[2] * MIN_BUYIN):
		note = tr("Not enough chips for those stakes.")
		home.show_home()
		return
	chips -= buyin
	_save_chips()
	mode = "cash"
	ai_level = int(prefs.level)
	var seat_list: Array = [Table.new_seat("", buyin, 1)]
	seat_list += _cpu_seats(int(prefs.opps), _cpu_buyin)
	_new_table(seat_list, s[0], s[1])
	_begin()

func _cpu_buyin() -> int:
	var s: Array = STAKES[stakes]
	return int(s[2] * rng.randf_range(0.6, 1.4) / s[1]) * s[1]

func _start_tourney() -> void:
	_close_sheet()
	_discard_save()
	mode = "tourney"
	ai_level = int(prefs.level)
	var seat_list: Array = [Table.new_seat("", MATCH_STACK, 1)]
	seat_list += _cpu_seats(int(prefs.opps), func(): return MATCH_STACK)
	_new_table(seat_list, BLIND_LEVELS[0][0], BLIND_LEVELS[0][1])
	_begin()

func _start_local() -> void:
	_close_sheet()
	_discard_save()
	mode = "local"
	var seat_list: Array = []
	for i in int(prefs.players):
		seat_list.append(Table.new_seat(tr("Player %d") % (i + 1), MATCH_STACK, i + 1))
	_new_table(seat_list, BLIND_LEVELS[0][0], BLIND_LEVELS[0][1])
	_begin()

## Training's coach table: practice chips, the coach on, Normal opponents.
func _start_practice() -> void:
	mode = "practice"
	ai_level = 1
	var seat_list: Array = [Table.new_seat("", PRACTICE_STACK, 1)]
	seat_list += _cpu_seats(maxi(2, int(prefs.opps)), func(): return PRACTICE_STACK)
	_new_table(seat_list, 10, 20)
	coach_on = true
	_begin()

func _begin() -> void:
	started = true
	home.hide_home()
	_show_screen("table")
	_deal()

func _deal() -> void:
	next_timer.stop()
	cpu_timer.stop()
	match mode:
		"cash":
			_refresh_cash_seats()
		"practice":
			for s in t.seats:
				if int(s.stack) <= 0:
					s.stack = PRACTICE_STACK
		"tourney", "local", "online":
			meta.hands = int(meta.hands) + 1
			var per: int = HANDS_PER_LEVEL[mode]
			meta.level = mini((int(meta.hands) - 1) / per, BLIND_LEVELS.size() - 1)
			t.sb = BLIND_LEVELS[meta.level][0]
			t.bb = BLIND_LEVELS[meta.level][1]
	discards = []
	coach_note = ""
	if not t.start_hand(rng):
		_render()
		return
	_sfx("card_shuffle")
	if mode == "local":
		# The first person to act gets the phone.
		cover.visible = false
	_send({"deal": t.hand_no})
	_after_change()

## Cash: busted computer players leave and someone new sits down.
func _refresh_cash_seats() -> void:
	var taken := {}
	for s in t.seats:
		taken[str(s.name)] = true
	for i in t.seats.size():
		var s: Dictionary = t.seats[i]
		if int(s.kind) != 0 or int(s.stack) > 0:
			continue
		var names: Array = AI.NAMES.filter(func(n): return not taken.has(n))
		var nm: String = names.pick_random() if not names.is_empty() else str(s.name)
		taken[nm] = true
		t.seats[i] = Table.new_seat(nm, _cpu_buyin(), 0, rng.randi_range(0, AI.STYLES.size() - 1))

# ---------- whose turn ----------

func _is_online() -> bool:
	return online != null and online.is_online() and mode == "online"

## The local player's seat (for stats): single player's seat, my online seat.
func _hero_seat() -> int:
	for i in t.seats.size():
		var k: int = t.seats[i].kind
		if (_is_online() and k == my_player) or (not _is_online() and mode != "local" and k == 1):
			return i
	return -1

func _hero_can_act() -> bool:
	if t.phase not in ["bet", "draw"] or t.to_act < 0 or cover.visible:
		return false
	var k: int = t.seats[t.to_act].kind
	if _is_online():
		return k == my_player and online.can_act(true)
	if mode == "local":
		return k > 0 and t.to_act == viewer
	return k == 1

func _decision_key() -> String:
	return "%d|%d|%s|%d|%d|%d" % [t.hand_no, t.street, t.phase, t.to_act, t.pot_total(), t.raises]

## After anything changed the table: count a finished hand, start the
## computer thinking, hand the phone over, ask the coach, redraw.
func _after_change() -> void:
	if t.phase == "done":
		if handled_hand != t.hand_no:
			handled_hand = t.hand_no
			_hand_over()
		_render()
		return
	if t.phase in ["bet", "draw"] and t.to_act >= 0:
		var k: int = t.seats[t.to_act].kind
		if k == 0:
			if not _is_online() or online.is_host():
				_schedule_cpu()
		elif mode == "local" and t.to_act != viewer and not cover.visible:
			_show_cover(t.to_act)
		if _hero_can_act():
			_reset_raise()
			_request_coach()
	_render()

func _schedule_cpu() -> void:
	if think_task >= 0 or not cpu_timer.is_stopped():
		return
	var me := _hero_seat()
	var watching: bool = me < 0 or not t.in_hand(me)
	if mode == "local":
		watching = false
	cpu_timer.start(0.22 if watching else rng.randf_range(0.5, 0.85))

func _on_cpu_timer() -> void:
	if think_task >= 0 or t.phase not in ["bet", "draw"] or t.to_act < 0 or int(t.seats[t.to_act].kind) != 0:
		return
	think_key = _decision_key()
	view.thinking = t.to_act
	think_task = WorkerThreadPool.add_task(_think.bind(t.to_dict(), ai_level, rng.randi()))
	view.queue_redraw()

func _think(snapshot: Dictionary, level: int, seed: int) -> void:
	think_result = AI.decide(snapshot, level, seed)

func _process(_delta: float) -> void:
	if think_task >= 0 and WorkerThreadPool.is_task_completed(think_task):
		WorkerThreadPool.wait_for_task_completion(think_task)
		think_task = -1
		view.thinking = -1
		if think_key == _decision_key() and int(t.seats[t.to_act].kind) == 0:
			_apply_cpu(think_result)
		else:
			_after_change()
	if coach_task >= 0 and WorkerThreadPool.is_task_completed(coach_task):
		WorkerThreadPool.wait_for_task_completion(coach_task)
		coach_task = -1
		if coach_result.get("key", "") == _decision_key():
			_render()
		elif _hero_can_act():
			_request_coach()

func _apply_cpu(d: Dictionary) -> void:
	if str(d.get("action", "")) == "draw":
		t.draw(d.get("discards", []))
		_sfx("card_deal")
	else:
		if not t.act(str(d.action), int(d.get("amount", 0))):
			if not t.act("check"):
				t.act("fold")
		_action_sfx()
	_send({"cpu": 1})
	_after_change()

# ---------- your moves ----------

func _on_fold() -> void:
	if not _hero_can_act() or t.phase != "bet":
		return
	_coach_feedback("fold")
	t.act("fold")
	_sfx("card_place")
	_after_move()

func _on_call() -> void:
	if not _hero_can_act():
		return
	if t.phase == "draw":
		_do_draw()
		return
	var l: Dictionary = t.legal()
	_coach_feedback("check" if l.can_check else "call")
	t.act("call")
	_action_sfx()
	_after_move()

func _on_raise() -> void:
	if not _hero_can_act() or t.phase != "bet":
		return
	_coach_feedback("raise")
	t.act("raise", raise_to)
	_action_sfx()
	_after_move()

func _do_draw() -> void:
	if not Table.can_discard(t.seats[t.to_act].hole, discards):
		note = tr("Swap up to 3 cards (4 if you keep an Ace).")
		_sfx("invalid")
		_render()
		return
	t.draw(discards)
	discards = []
	_sfx("card_deal")
	_after_move()

func _after_move() -> void:
	_send({"me": 1})
	_after_change()

func _on_card_tapped(index: int) -> void:
	if t.phase != "draw" or not _hero_can_act():
		return
	if discards.has(index):
		discards.erase(index)
	else:
		discards.append(index)
	_sfx("toggle")
	_render()

func _reset_raise() -> void:
	var l: Dictionary = t.legal()
	raise_to = int(l.min_to)

func _step_raise(d: int) -> void:
	var l: Dictionary = t.legal()
	if not l.can_raise:
		return
	raise_to = clampi(raise_to + d * t.bb, l.min_to, l.max_to)
	_render()

func _size_preset(which: String) -> void:
	var l: Dictionary = t.legal()
	if not l.can_raise:
		return
	var after_call: int = t.pot_total() + int(l.to_call)
	match which:
		"min": raise_to = l.min_to
		"half": raise_to = t.current_bet + after_call / 2
		"pot": raise_to = t.current_bet + after_call
		"all": raise_to = l.max_to
	raise_to = clampi(raise_to, l.min_to, l.max_to)
	_render()

# ---------- the end of a hand ----------

func _hand_over() -> void:
	cpu_timer.stop()
	var me := _hero_seat()
	var my_win := 0
	if me >= 0 and info and t.seats[me].hole.size() > 0:
		info.add("Hands played")
		my_win = int(t.seats[me].won)
		if my_win > 0:
			info.add("Hands won")
			info.high("Biggest pot", my_win)
		for r in t.results:
			if int(r.seat) == me and Eval.is_royal(int(r.score)):
				info.add("Royal flushes")
	var shown := false
	for r in t.results:
		shown = shown or bool(r.shown)
	if my_win > 0:
		_sfx("pickup")
	elif shown:
		_sfx("card_flip")
	match mode:
		"cash":
			_update_most_chips()
		"tourney", "local":
			_track_eliminations()
			_check_match_over()
		"online":
			_check_match_over()  # changes nothing both phones share
	if _is_online() and online.is_host() and not end_dialog.visible:
		next_timer.start(NEXT_DELAY)
	_save_game()

func _track_eliminations() -> void:
	for i in t.seats.size():
		if int(t.seats[i].stack) <= 0 and not meta.out.has(i):
			meta.out.append(i)

func _check_match_over() -> void:
	var left: Array = []
	for i in t.seats.size():
		if int(t.seats[i].stack) > 0:
			left.append(i)
	var me := _hero_seat()
	var msg := ""
	match mode:
		"tourney":
			if left.size() > 1 and (me < 0 or int(t.seats[me].stack) > 0):
				return
			SaveUtil.delete(SAVE_PATH)
			started = false
			if left.size() == 1 and left[0] == me:
				msg = tr("You won the tournament!")
				_record("win")
			else:
				var place: int = left.size() + 1
				msg = tr("You finished %s of %d.") % [_ordinal(place), int(meta.start)]
				_record("loss")
			if info:
				msg += "\n" + info.summary(["Wins", "Hands won", "Biggest pot"])
		"local":
			if left.size() > 1:
				return
			SaveUtil.delete(SAVE_PATH)
			started = false
			msg = tr("%s wins the game!") % _name(left[0]) if left.size() == 1 else tr("Game over.")
			if info and not result_recorded:
				result_recorded = true
				info.add("Pass and play games")
				info.celebrate(msg)
		"online":
			if left.size() > 1:
				return
			var i_won: bool = left.size() == 1 and left[0] == me
			msg = online.result_text(i_won) if online else ""
			if info and not result_recorded:
				result_recorded = true
				info.result("win" if i_won else "loss", true)
			if info:
				msg += "\n" + info.summary(["Online wins", "Online losses"])
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

func _record(outcome: String) -> void:
	if info and not result_recorded:
		result_recorded = true
		info.result(outcome)

## "1st", "2nd", "3rd", "4th"...
func _ordinal(n: int) -> String:
	match n:
		1: return tr("1st")
		2: return tr("2nd")
		3: return tr("3rd")
	return tr("%dth") % n

func _on_next() -> void:
	if t.phase != "done" and t.phase != "idle":
		return
	if _is_online() and not online.is_host():
		return
	if mode == "cash" or mode == "practice":
		var me := _hero_seat()
		if me >= 0 and int(t.seats[me].stack) <= 0:
			_rebuy()
			return
	if end_dialog.visible:
		return
	_deal()

func _on_next_timer() -> void:
	if _is_online() and online.is_host() and t.phase == "done" and not end_dialog.visible:
		_deal()

## Cash: out of chips at the table -- buy back in from your chips.
func _rebuy() -> void:
	var me := _hero_seat()
	if mode == "practice":
		t.seats[me].stack = PRACTICE_STACK
		_deal()
		return
	var s: Array = STAKES[stakes]
	var amount := mini(int(s[2]), chips)
	if amount < int(s[1]) * 10:
		_on_leave()
		return
	chips -= amount
	t.seats[me].stack = amount
	_save_chips()
	_deal()

func _on_leave() -> void:
	if mode == "cash":
		var me := _hero_seat()
		if me >= 0:
			chips += int(t.seats[me].stack)
			t.seats[me].stack = 0
		_save_chips()
		_update_most_chips()
	SaveUtil.delete(SAVE_PATH)
	started = false
	home.go_home()

# ---------- coach ----------

func _toggle_coach() -> void:
	coach_on = not coach_on
	if mode != "practice":
		prefs.coach = coach_on
		_save_chips()
	if coach_on and _hero_can_act():
		_request_coach()
	_render()

func _request_coach() -> void:
	if not coach_on or _is_online() or coach_task >= 0 or not _hero_can_act():
		return
	var key := _decision_key()
	if coach_result.get("key", "") == key:
		return
	coach_key = key
	coach_task = WorkerThreadPool.add_task(_coach_think.bind(t.to_dict(), rng.randi(), key))

func _coach_think(snapshot: Dictionary, seed: int, key: String) -> void:
	var r := AI.advise(snapshot, seed)
	r["key"] = key
	coach_result = r

## A word from the coach when your move went against the numbers.
func _coach_feedback(action: String) -> void:
	if not coach_on or coach_result.get("key", "") != _decision_key():
		return
	var eq: float = coach_result.eq
	var need: float = coach_result.need
	var advice: String = coach_result.advice
	if action == "fold" and need > 0.0 and eq >= need + 0.08:
		coach_note = tr("Coach: that fold gave up about %d%% when you only needed %d%%.") % [roundi(eq * 100), roundi(need * 100)]
	elif action == "call" and need > 0.0 and eq < need - 0.08:
		coach_note = tr("Coach: that call needed %d%%; you had about %d%%.") % [roundi(need * 100), roundi(eq * 100)]
	elif (action == "raise" and (advice == "Raise" or advice == "Bet")) or (action == advice.to_lower()):
		coach_note = tr("Coach: 👍 good play.")
		if info:
			info.add("Coach-approved plays")
	else:
		coach_note = ""

# ---------- drawing the screen ----------

func _name(i: int) -> String:
	var n: String = str(t.seats[i].name)
	return n if n != "" else tr("You")

func _render() -> void:
	if not is_instance_valid(view):
		return
	view.t = t
	view.viewer = viewer
	view.discards = discards
	view.show_styles = coach_on and not _is_online()
	view.hide_viewer = cover.visible
	view.you_text = "You"
	coach_btn.button_pressed = coach_on
	coach_btn.visible = not _is_online()
	if t.seats.is_empty():
		title_label.text = tr(TITLE_FOR_HOME)
		info_label.text = ""
		status_label.text = tr("Waiting for the host to deal...") if _is_online() else ""
		for b in [fold_btn, call_btn, raise_btn, leave_btn, next_btn]:
			b.visible = false
		size_row.visible = false
		coach_panel.visible = false
		view.queue_redraw()
		return
	title_label.text = "%s · %s" % [tr(VARIANT_SHORT[t.variant]), tr(LIMIT_NAMES[t.limit])]
	info_label.text = _info_text()
	status_label.text = _status_text()
	_render_buttons()
	_render_coach()
	view.queue_redraw()

func _info_text() -> String:
	var blinds := tr("Blinds %s/%s") % [View._chips(t.sb), View._chips(t.bb)]
	if t.variant == "stud":
		blinds = tr("Ante %s · bring-in %s · bets %s/%s") % [t.stud_ante(), t.stud_bring_in(), View._chips(t.bb), View._chips(t.bb * 2)]
	var parts: Array = [blinds]
	match mode:
		"cash":
			parts.append(tr("Your chips: %s") % View._chips(chips))
		"tourney", "local", "online":
			var per: int = HANDS_PER_LEVEL[mode]
			var into: int = (int(meta.hands) - 1) % per
			parts.append(tr("Level %d · up in %d") % [int(meta.level) + 1, per - into])
		"practice":
			parts.append(tr("Practice chips"))
	return "  ·  ".join(parts)

func _event_text() -> String:
	var e: Dictionary = t.last_event
	if e.is_empty() or int(e.get("seat", -1)) < 0 or int(e.seat) >= t.seats.size():
		return ""
	var who := _name(int(e.seat))
	var amt := View._chips(int(e.get("amount", 0)))
	var s: Dictionary = t.seats[int(e.seat)]
	match str(s.act):
		"Fold": return tr("%s folds.") % who
		"Check": return tr("%s checks.") % who
		"Call": return tr("%s calls %s.") % [who, amt]
		"Bet": return tr("%s bets %s.") % [who, amt]
		"Raise": return tr("%s raises to %s.") % [who, amt]
		"Complete": return tr("%s completes to %s.") % [who, amt]
		"All in": return tr("%s is all in for %s!") % [who, amt]
		"Draw": return tr("%s draws %d.") % [who, int(e.amount)]
		"Stand pat": return tr("%s stands pat.") % who
	return ""

func _status_text() -> String:
	var lines: Array = []
	if note != "":
		lines.append(note)
		note = ""
	if t.phase == "done":
		for r in t.results:
			if int(r.won) <= 0:
				continue
			var mine: bool = str(t.seats[int(r.seat)].name) == ""
			var amount := View._chips(int(r.won))
			if str(r.desc) != "":
				lines.append(tr("You win %s with %s.") % [amount, str(r.desc)] if mine
					else tr("%s wins %s with %s.") % [_name(int(r.seat)), amount, str(r.desc)])
			else:
				lines.append(tr("You win %s.") % amount if mine else tr("%s wins %s.") % [_name(int(r.seat)), amount])
		var me := _hero_seat()
		if (mode == "cash" or mode == "practice") and me >= 0 and int(t.seats[me].stack) <= 0:
			lines.append(tr("You're out of chips at this table."))
		elif _is_online() and not online.is_host() and not end_dialog.visible:
			lines.append(tr("Next hand in a moment..."))
		return "\n".join(lines.slice(0, 3))
	if t.phase == "idle":
		return "\n".join(lines)
	var ev := _event_text()
	if ev != "":
		lines.append(ev)
	if _is_online() and not online.opponent_here:
		lines.append(tr("%s disconnected — waiting...") % online.opponent_name())
	elif _hero_can_act():
		var l: Dictionary = t.legal()
		if t.phase == "draw":
			lines.append(tr("Tap the cards to swap, then draw."))
		elif int(l.to_call) > 0:
			lines.append(tr("Your turn: %s to call.") % View._chips(int(l.to_call)))
		elif t.current_bet > 0:
			lines.append(tr("Your turn: check or raise."))
		else:
			lines.append(tr("Your turn: check or bet."))
	elif t.to_act >= 0:
		lines.append(tr("%s's turn.") % _name(t.to_act))
	return "\n".join(lines.slice(maxi(0, lines.size() - 2)))

func _render_buttons() -> void:
	for b in [fold_btn, call_btn, raise_btn, leave_btn, next_btn]:
		b.visible = false
	size_row.visible = false
	if t.phase == "done" or t.phase == "idle":
		if end_dialog.visible:
			return
		var host_or_local: bool = not _is_online() or online.is_host()
		next_btn.visible = host_or_local and t.phase == "done"
		var me := _hero_seat()
		var busted: bool = me >= 0 and int(t.seats[me].stack) <= 0
		if (mode == "cash" or mode == "practice") and busted:
			var s: Array = STAKES[stakes]
			var amount := PRACTICE_STACK if mode == "practice" else mini(int(s[2]), chips)
			next_btn.text = tr("Rebuy %s") % View._chips(amount)
			next_btn.visible = mode == "practice" or amount >= int(s[1]) * 10
		else:
			next_btn.text = tr("Next hand ▶")
		leave_btn.visible = mode == "cash"
		return
	if not _hero_can_act():
		return
	var l: Dictionary = t.legal()
	if t.phase == "draw":
		call_btn.visible = true
		call_btn.text = tr("Stand pat") if discards.is_empty() else tr("Swap %d") % discards.size()
		return
	fold_btn.visible = not l.can_check
	call_btn.visible = true
	var me_stack: int = t.seats[t.to_act].stack
	if l.can_check:
		call_btn.text = tr(View.CHECK)
	elif int(l.to_call) >= me_stack:
		call_btn.text = tr("All in %s") % View._chips(int(l.to_call))
	else:
		call_btn.text = tr("Call %s") % View._chips(int(l.to_call))
	if l.can_raise:
		raise_btn.visible = true
		raise_to = clampi(raise_to, l.min_to, l.max_to)
		if raise_to >= int(l.all_in_to):
			raise_btn.text = tr("All in %s") % View._chips(raise_to)
		elif t.current_bet == 0:
			raise_btn.text = tr("Bet %s") % View._chips(raise_to)
		else:
			raise_btn.text = tr("Raise to %s") % View._chips(raise_to)
		size_row.visible = t.limit != "fl" and int(l.max_to) > int(l.min_to)
		if size_row.visible:
			(size_row.get_child(4) as Button).text = tr("All in") if t.limit == "nl" else tr("Max")

func _render_coach() -> void:
	coach_panel.visible = coach_on and not _is_online() and t.phase != "idle"
	if not coach_panel.visible:
		return
	var lines: Array = []
	if _hero_can_act():
		if coach_result.get("key", "") == _decision_key():
			var c: Dictionary = coach_result
			if t.phase == "draw":
				lines.append("🎓 " + str(c.hand))
				lines.append(str(c.why))
			else:
				var head := "🎓 %s · %s" % [str(c.hand), tr("Win ≈ %d%%") % roundi(float(c.eq) * 100)]
				if float(c.need) > 0.0:
					head += " · " + tr("Need %d%%") % roundi(float(c.need) * 100)
				if int(c.outs) > 0:
					head += " · " + tr("Outs %d") % int(c.outs)
				if str(c.tier) != "":
					head += " · " + tr(str(c.tier))
				lines.append(head)
				var adv := str(c.advice)
				lines.append(tr("Coach says: %s.") % tr(View.CHECK if adv == "Check" else adv) + " " + str(c.why))
		else:
			lines.append("🎓 " + tr("The coach is thinking..."))
	elif coach_note != "":
		lines.append(coach_note)
	else:
		lines.append("🎓 " + tr("The coach will help on your turn."))
	coach_label.text = "\n".join(lines)

# ---------- pass and play ----------

func _show_cover(seat: int) -> void:
	cover_seat = seat
	cover_label.text = tr("Pass the phone to %s") % _name(seat)
	cover.visible = true
	view.hide_viewer = true
	_save_game()

func _on_cover_ready() -> void:
	cover.visible = false
	viewer = cover_seat if cover_seat >= 0 else viewer
	discards = []
	coach_result = {}
	if _hero_can_act():
		_reset_raise()
		_request_coach()
	_render()

# ---------- online (heads-up) ----------

func _online_state() -> Dictionary:
	return {"t": t.to_dict(), "meta": meta}

func _on_online_started(p_my_player: int) -> void:
	my_player = p_my_player
	mode = "online"
	started = false
	_close_sheet()
	home.hide_home()
	_show_screen("table")
	end_dialog.visible = false
	result_recorded = false
	handled_hand = -1
	coach_on = false
	if online.is_host():
		_new_online_match()
	else:
		t = Table.new()
		viewer = 1
		_render()

## Host: a fresh match (the guest gets it with the first deal).
func _new_online_match() -> void:
	_new_table([Table.new_seat(online.my_name(), MATCH_STACK, 1), Table.new_seat(online.opponent_name(), MATCH_STACK, 2)],
		BLIND_LEVELS[0][0], BLIND_LEVELS[0][1])
	viewer = 0
	_deal()
	online.push_state()

func _adopt(st: Dictionary) -> void:
	if not st.has("t"):
		return
	var before_hand: int = t.hand_no
	t.from_dict(st.t)
	var m: Dictionary = st.get("meta", {})
	meta = {"hands": int(m.get("hands", 0)), "level": int(m.get("level", 0)), "out": [], "start": int(m.get("start", 2))}
	for v in m.get("out", []):
		meta.out.append(int(v))
	if t.hand_no < before_hand:
		handled_hand = -1  # a new match
	viewer = 0
	for i in t.seats.size():
		if int(t.seats[i].kind) == my_player:
			viewer = i
	if t.phase != "done":
		end_dialog.visible = false
	_after_change()

func _on_remote_move(p: Dictionary) -> void:
	if typeof(p.get("state")) == TYPE_DICTIONARY:
		_adopt(p.state)

func _on_remote_state(st: Dictionary) -> void:
	_adopt(st)

func _on_remote_new_game() -> void:
	end_dialog.visible = false
	result_recorded = false
	if online.is_host():
		_new_online_match()
	else:
		t = Table.new()
		handled_hand = -1
		_render()

func _send(payload: Dictionary) -> void:
	if _is_online():
		online.send_move(payload)

## "Play again" for online: the host deals the new match.
func _start_new_game() -> void:
	if not _is_online():
		_restart()
		return
	end_dialog.visible = false
	result_recorded = false
	online.new_game()
	if online.is_host():
		_new_online_match()
	else:
		t = Table.new()
		handled_hand = -1
		_render()

# ---------- Video Poker ----------

func _start_vp() -> void:
	mode = "vp"
	started = true
	_refill_if_broke()
	_show_screen("vp")
	var saved = SaveUtil.read(VP_SAVE_PATH)
	machine.open(chips, saved if saved != null else {})
	if note != "":
		machine.result_label.text = note
		note = ""

func _on_machine_chips(c: int) -> void:
	chips = c
	_save_chips()
	if info:
		info.high("Most chips", chips + _saved_table_chips())
	SaveUtil.write(VP_SAVE_PATH, machine.state())

func _on_machine_hand(win: int, hand_name: String) -> void:
	if info:
		info.add("Video poker hands")
		if win > 0:
			info.high("Biggest machine win", win)
		if hand_name == "Royal Flush":
			info.add("Royal flushes")
	SaveUtil.write(VP_SAVE_PATH, machine.state())
	if chips < machine.engine.coin and _refill_if_broke():
		machine.open(chips, machine.state())
		machine.result_label.text = note
		note = ""

# ---------- Training ----------

func _open_training() -> void:
	mode = "training"
	_show_screen("training")
	training.show_menu()

func _leave_training() -> void:
	mode = ""
	_show_screen("")
	home.show_home()

# ---------- pause / save / resume ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

## Pause menu "Restart" and the end screen's "Play again".
func _restart() -> void:
	end_dialog.visible = false
	match mode:
		"cash":
			var me := _hero_seat()
			if me >= 0 and t.phase in ["done", "idle"]:
				chips += int(t.seats[me].stack)
				t.seats[me].stack = 0
				_save_chips()
			SaveUtil.delete(SAVE_PATH)
			_sit_cash()
		"tourney":
			_start_tourney()
		"local":
			_start_local()
		"practice":
			_start_practice()
		"online":
			_start_new_game()

func _save_game() -> void:
	if mode == "vp":
		SaveUtil.write(VP_SAVE_PATH, machine.state())
		return
	if not started or mode not in ["cash", "tourney", "local"] or end_dialog.visible:
		return
	if t.seats.is_empty() or t.phase == "idle":
		return
	SaveUtil.write(SAVE_PATH, {"v": 2, "mode": mode, "t": t.to_dict(), "meta": meta, "viewer": viewer,
		"level": ai_level, "stakes": stakes, "buyin": buyin, "handled": handled_hand})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var td: Dictionary = d.get("t", {})
	var names := {"cash": "Cash game", "tourney": "Tournament", "local": "Pass and play"}
	return "%s · %s" % [tr(names.get(str(d.get("mode", "")), "Poker")), tr(VARIANT_SHORT.get(str(td.get("variant", "holdem")), "Poker"))]

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not d.has("t"):
		home.show_home()
		return
	mode = str(d.get("mode", "cash"))
	t = Table.new()
	t.from_dict(d.t)
	var m: Dictionary = d.get("meta", {})
	meta = {"hands": int(m.get("hands", 0)), "level": int(m.get("level", 0)), "out": [], "start": int(m.get("start", t.seats.size()))}
	for v in m.get("out", []):
		meta.out.append(int(v))
	viewer = int(d.get("viewer", 0))
	ai_level = clampi(int(d.get("level", 1)), 0, 2)
	stakes = clampi(int(d.get("stakes", 0)), 0, STAKES.size() - 1)
	buyin = int(d.get("buyin", 0))
	handled_hand = int(d.get("handled", -1))
	result_recorded = false
	discards = []
	coach_result = {}
	started = true
	end_dialog.visible = false
	cover.visible = false
	_show_screen("table")
	if t.phase == "idle":
		_deal()
		return
	_after_change()

# ---------- sounds ----------

func _action_sfx() -> void:
	var a := str(t.last_event.get("action", ""))
	if a == "check":
		_sfx("tap")
	elif a == "fold":
		_sfx("card_place")
	else:
		_chips_sfx()

## A short clack of chips, made in code (the app ships no sound files).
func _chips_sfx() -> void:
	var s = get_node_or_null("/root/Sfx")
	if s == null:
		return
	if not s.has_method("play_stream"):
		s.play("place")
		return
	if chip_stream == null:
		chip_stream = _make_chips()
	s.play_stream(chip_stream, -3.0, rng.randf_range(0.9, 1.1), "game")

static func _make_chips() -> AudioStreamWAV:
	var rate := 22050
	var total := int(rate * 0.22)
	var data := PackedByteArray()
	data.resize(total * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var clicks := [0.0, 0.045, 0.09, 0.12]
	for i in total:
		var tm := float(i) / rate
		var v := 0.0
		for k in clicks.size():
			var lt: float = tm - clicks[k]
			if lt >= 0.0 and lt < 0.05:
				var env := exp(-lt * 140.0)
				v += (sin(TAU * (3200.0 + k * 400.0) * lt) * 0.5 + r.randf_range(-0.5, 0.5)) * env * (0.55 - k * 0.08)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
