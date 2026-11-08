extends Control

## The Runner in the hub: the Landing (Landing kit) and the game under it. Design: the owner's doc v2
## docs/runner/GAME_DESIGN_THE_RUNNER_V2.md, hub brief docs/runner/BRIEF.md, choices docs/runner/DECISIONS.md.
##
## Screens (one at a time, under the HUD bar and the kit): character creation (the_runner_create.gd,
## a new run only), the sector map (the_runner_map.gd, the ship flies there, the Pad shows), the dock
## of a world (the_runner_dock.gd: market, shipyard, fixer, job board, crew, faction office, laundry,
## Kessel's collector), and over them an encounter card, a real-time battle (the_runner_battle_view.gd,
## the Pad steers), a story card or the ship computer (Menu, the_runner_computer.gd). Rules:
## the_runner_engine.gd. Landing -> play: 1 tap with a save (STANDARDS N6); a new run asks for a
## captain first (design doc v2 §2).
## Pause (⏸, the Pad's pause, Esc, Android back, the app losing focus) -> the kit's pause menu, which
## saves (N5). Nothing is built in _ready(): a run starts when a mode or ▶ Resume is picked.

const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + look, copied into this game's folder by `hub.py sync`.
const HomeKit = preload("res://scripts/games/the_runner/home_kit.gd")
const HELP = preload("res://scripts/games/the_runner/the_runner_help.gd")
const Engine_ = preload("res://scripts/games/the_runner/the_runner_engine.gd")
const D = preload("res://scripts/games/the_runner/the_runner_data.gd")
const UI = preload("res://scripts/games/the_runner/the_runner_ui.gd")
const MapView = preload("res://scripts/games/the_runner/the_runner_map.gd")
const DockView = preload("res://scripts/games/the_runner/the_runner_dock.gd")
const ComputerView = preload("res://scripts/games/the_runner/the_runner_computer.gd")
const CreateView = preload("res://scripts/games/the_runner/the_runner_create.gd")
const BattleView = preload("res://scripts/games/the_runner/the_runner_battle_view.gd")
const S = preload("res://scripts/games/the_runner/the_runner_spiral.gd")
const SoundLib = preload("res://scripts/games/the_runner/sound_lib.gd")
const SpriteLib = preload("res://scripts/games/the_runner/sprite_lib.gd")
## The app's shared on-screen controller; older apps don't have it (the game is all taps there).
const PAD_PATH := "res://scripts/common/pad/pad_controller.gd"
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const SAVE_PATH := "user://the_runner_save.json"
## Hints (owner 2026-11-01: 3 at most, +1 every 24 h, per game). Kept apart from the run's save, so a
## new run does not refill them.
const HINT_PATH := "user://the_runner_hints.json"
const HINT_MAX := 3
const HINT_REFILL := 86400
const ACCENT := Color("4fc3ff")
const ART := "res://games/the_runner/art/landing.webp"
## The status bar's height (canvas units): every screen starts under it.
const HUD_H := 54.0

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine = null
var started := false
var screen := ""                 # "map" / "dock" / "create"
var pad: Control = null
var map: Control = null
var dock: Control = null
var computer: Control = null
var battle: Control = null
var creator: Control = null
var _layer: Control = null       # the current screen lives here
var _hud: PanelContainer = null
var _hud_row: HBoxContainer = null
var _over: Control = null        # encounter or story card
var _card: PanelContainer = null # the map's course card / dock prompt
var _story_queue: Array = []
var _story_i := 0
var _hints := {"left": HINT_MAX, "stamp": 0}
var _won_reported := false

func _ready() -> void:
	Orientation.lock_landscape()
	preload("res://scripts/games/the_runner/the_runner_i18n.gd").install(self)
	_load_hints()
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme(ACCENT)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": ACCENT,
		"subtitle": "The Spiral is watching. Run the lanes.",
		"logo": _draw_home_logo,
		"art": ART,
		"art_title": [0.02, 0.2],
		"solo_heading": "🚀 Story",
		"modes": [{"text": "🚀 New run", "sub": "Make a captain, owe Mother Kessel", "action": _new_game}],
		"save_path": SAVE_PATH,
		"resume": _continue_game,
		"restart": _new_game,
		"board": "Best net worth",
		"board_note": "Your best net worth: clean credits, ship and cargo, 30% of dirty credits, minus debts.",
		# A new run deletes the save: no ⚡ Quick Play next to ▶ Resume.
		"quick_with_save": false,
	})
	add_child(home)
	if info:
		add_child(info)
	# Must stay the last child so its tab sits above any dialog (the kit frees it).
	add_child(SettingsDrawer.new())

## A ship's outline and a ringed planet in the kit's glow style.
func _draw_home_logo(c: Control) -> void:
	var mid := c.size / 2.0
	var u := minf(c.size.x, c.size.y * 1.6) / 220.0
	HomeKit.glow_circle(c, mid + Vector2(30, -4) * u, 34.0 * u, Color("ffb547"), 3.0, 0.1)
	var ship := PackedVector2Array([Vector2(-70, 20), Vector2(-10, 0), Vector2(-70, -20), Vector2(-56, 0)])
	var pts := PackedVector2Array()
	for p in ship:
		pts.append(mid + p * u)
	HomeKit.glow_polyline(c, pts, ACCENT, 3.0, true)

# ================================================================ runs

## 🚀 New run (and ↺ Restart): character creation first; the save is deleted only when the new
## captain starts (‹ Back on its first page leaves the old run alone).
func _new_game(notice: String = "") -> void:
	_clear_play()
	started = false
	engine = null
	screen = "create"
	creator = CreateView.new()
	creator._note = notice
	add_child(creator)
	move_child(creator, home.get_index())
	creator.done.connect(_on_created)
	creator.cancelled.connect(_on_create_cancelled)

func _on_created(cap: Dictionary) -> void:
	SaveUtil.delete(SAVE_PATH)
	_close_creator()
	engine = Engine_.new()
	engine.reset(0, cap)
	started = true
	_won_reported = false
	_start_play()

func _on_create_cancelled() -> void:
	_close_creator()
	home.show_home()

func _close_creator() -> void:
	if creator != null and is_instance_valid(creator):
		creator.queue_free()
	creator = null

## ▶ Resume: the last autosave. A run from pack v1 (the old galaxy) can't carry over: it starts a
## new captain, and the records (🏆, 🏅, stats) stay (owner 2026-11-07).
func _continue_game() -> void:
	engine = Engine_.new()
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary) or not (d.get("engine") is Dictionary) or not engine.from_dict(d.engine):
		var old: bool = d is Dictionary and d.get("engine") is Dictionary and Engine_.save_version(d.engine) == 1
		_new_game(UI.tr_s("This run is from the old galaxy and can't continue in the Spiral. Your records, 🏆 and 🏅 are kept. Make a new captain.") if old else "")
		return
	started = true
	_won_reported = engine.flags.has("act1_done")
	_start_play()

func _start_play() -> void:
	_clear_play()
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	move_child(_layer, 0)
	_add_pad()
	_build_hud()
	if engine.loc == "":
		show_map()
	else:
		show_dock()
	_flush_story()
	if not engine.encounter.is_empty():
		show_encounter()
	_music("calm")

func _clear_play() -> void:
	for n in [_layer, _hud, pad, _over, computer, battle]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_layer = null
	_hud = null
	pad = null
	_over = null
	computer = null
	battle = null
	map = null
	dock = null
	_card = null

# ================================================================ the Pad

func _add_pad() -> void:
	if not ResourceLoader.exists(PAD_PATH):
		return
	pad = load(PAD_PATH).new()
	pad.layout_override = "stick_4"
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pad)
	pad.set_hidden("x", true)
	pad.set_hidden("y", true)
	pad.set_state("info", {"icon": "menu"})
	pad.button_pressed.connect(_on_pad)
	pad.visible = false

# To let the player pick a controller layout later, define here: func _pad() -> Control: return pad
# (the kit's Options then shows "Controls"); owner 2026-10-29: Options hidden for now.

func _on_pad(id: String) -> void:
	if home.is_home_visible() or home.pause_overlay.visible:
		return
	if battle != null and is_instance_valid(battle):
		match id:
			"pause": home.pause()
			"a": _battle_next_target()
			"b": battle._use("shields")
		return
	match id:
		"pause":
			home.pause()
		"info":
			open_computer()
		"a":
			_pad_a()
		"b":
			_pad_b()

func _battle_next_target() -> void:
	var sim = battle.sim
	if sim == null:
		return
	for k in range(1, sim.foes.size() + 1):
		var i: int = (sim.target + k) % sim.foes.size()
		if sim.foes[i].alive:
			sim.pick_target(i)
			return

## A: dock at the world in range, jump at the gate, else set course to the selected world.
func _pad_a() -> void:
	if map == null or screen != "map" or _over != null:
		return
	if map.near != "" and engine.loc == "":
		map.dock_here()
	elif map.at_gate:
		_on_gate(true)
	elif map.selected != "" and map.selected != engine.loc and engine.can_reach(map.selected):
		_set_course(map.selected)

## B: stop the autopilot, or close the course card.
func _pad_b() -> void:
	if map == null or screen != "map":
		return
	if map.target != "":
		map.stop()
	else:
		map.selected = ""
		_close_card()

func _update_pad() -> void:
	if pad == null:
		return
	var fighting: bool = battle != null and is_instance_valid(battle)
	var on: bool = (screen == "map" and _over == null and (computer == null or not computer.visible)) or fighting
	pad.visible = on
	if fighting:
		pad.set_state("a", {"sub": UI.tr_s("Target").to_upper(), "enabled": true})
		pad.set_state("b", {"sub": UI.tr_s("Shield").to_upper(), "enabled": true})
	elif on and map != null:
		var a_word := ""
		if map.near != "" and engine.loc == "":
			a_word = "Dock"
		elif map.at_gate:
			a_word = "Jump"
		elif map.selected != "" and map.selected != engine.loc:
			a_word = "Go"
		pad.set_state("a", {"sub": UI.tr_s(a_word).to_upper(), "enabled": a_word != ""})
		pad.set_state("b", {"sub": UI.tr_s("Stop").to_upper() if map.target != "" else "", "enabled": map.target != ""})
	if _hud_row != null:
		for b in _hud_row.get_children():
			if b.has_meta("pill"):
				b.visible = not on       # the Pad has its own pause and menu while it shows

func _process(_dt: float) -> void:
	if engine == null:
		return
	_update_pad()

func _unhandled_input(event: InputEvent) -> void:
	if engine == null or home.is_home_visible():
		return
	if event.is_action_pressed("pad_info"):
		open_computer()
	elif event.is_action_pressed("pad_a") and pad == null:
		_pad_a()
	elif event.is_action_pressed("pad_b") and pad == null:
		_pad_b()

# ================================================================ HUD

func _build_hud() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = PanelContainer.new()
	var sb := UI.panel_box(0.85, 0)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_hud.add_theme_stylebox_override("panel", sb)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud.custom_minimum_size.y = HUD_H
	_hud.clip_contents = true
	add_child(_hud)
	move_child(_hud, _layer.get_index() + 1)
	_hud_row = UI.hbox(14)
	_hud.add_child(_hud_row)
	refresh_hud()

func refresh_hud() -> void:
	if _hud_row == null or engine == null:
		return
	for ch in _hud_row.get_children():
		ch.queue_free()
	var pause := UI.button("⏸", home.pause, UI.c("accent"), 22, 42)
	pause.custom_minimum_size.x = 54
	pause.set_meta("pill", true)
	_hud_row.add_child(pause)
	var menu := UI.button("☰ " + UI.tr_s("Menu"), open_computer, UI.c("accent"), 20, 42)
	menu.set_meta("pill", true)
	_hud_row.add_child(menu)
	var bits := [
		[UI.tr_s("Day %d") % engine.day, UI.c("dim")],
		[UI.clean_txt(engine.clean), UI.c("clean")],
		[UI.dirty_txt(engine.dirty), UI.c("dirty")],
		["⛽ %d/%d" % [int(engine.fuel), engine.tank()], UI.c("warn") if engine.fuel < 3.0 else UI.c("text")],
		["🛡 %d/%d" % [engine.hull, engine.max_hull()], UI.c("bad") if engine.hull < engine.max_hull() / 3 else UI.c("text")],
		["🔥 " + UI.tr_s(engine.heat_tier()), _heat_color(engine.heat_of())],
		["☀%d ☾%d" % [int(engine.bars.paragon), int(engine.bars.outlaw)], UI.c("dim")],
	]
	if engine.debt > 0:
		bits.append([UI.tr_s("Debt %s") % UI.num(engine.debt), UI.c("bad")])
	for b in bits:
		var l := UI.label(b[0], 20, b[1])
		_hud_row.add_child(l)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_row.add_child(sp)
	if screen == "map" and map != null:
		var ov := UI.button("🔭", _toggle_overview, UI.c("accent"), 20, 42)
		ov.custom_minimum_size.x = 54
		_hud_row.add_child(ov)
	var where := UI.world_name(engine.loc) if engine.loc != "" else UI.sector_name(engine.sector)
	_hud_row.add_child(UI.label("📍 " + where, 20, UI.c("accent")))

func _toggle_overview() -> void:
	if map != null:
		map.toggle_overview()

func _heat_color(h: float) -> Color:
	if h > 60.0:
		return UI.c("bad")
	if h > 20.0:
		return UI.c("warn")
	return UI.c("text")

func hud_height() -> float:
	return HUD_H if _hud != null and is_instance_valid(_hud) else 0.0

# ================================================================ screens

func _swap(view: Control) -> void:
	for ch in _layer.get_children():
		ch.queue_free()
	map = null
	dock = null
	_card = null
	_layer.add_child(view)

func show_map() -> void:
	screen = "map"
	map = MapView.new()
	map.engine = engine
	map.pad = pad
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m = map
	_swap(m)
	map = m
	map.world_tapped.connect(_on_world_tapped)
	map.arrived.connect(_on_arrived)
	map.encounter_opened.connect(show_encounter)
	map.near_changed.connect(_on_near)
	map.gate_changed.connect(_on_gate)
	if engine.loc != "":
		_on_world_tapped(engine.loc)
	refresh_hud()

func show_dock() -> void:
	screen = "dock"
	var d = DockView.new()
	d.game = self
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_swap(d)
	dock = d
	refresh_hud()

## The dock asks to leave: back to the map, the ship over its world.
func launch() -> void:
	_sfx_lib("scifi/thruster_fire")
	show_map()

func refresh() -> void:
	refresh_hud()
	if dock != null and is_instance_valid(dock):
		dock.rebuild()
	if computer != null and is_instance_valid(computer) and computer.visible:
		computer.rebuild()
	_report_stats()

# ---------------------------------------------------------------- the map's cards

func _close_card() -> void:
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	_card = null

## A card in the top-right corner, as tall as what it says (the worlds stay visible around it).
func _side_card() -> VBoxContainer:
	_close_card()
	_card = UI.panel(0.94)
	_card.anchor_left = 1.0
	_card.anchor_right = 1.0
	_card.anchor_top = 0.0
	_card.anchor_bottom = 0.0
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_card.offset_left = -380
	_card.offset_right = -10
	_card.offset_top = hud_height() + 10
	_layer.add_child(_card)
	var box := UI.vbox(6)
	_card.add_child(box)
	return box

func _on_world_tapped(w: String) -> void:
	if w == "":
		_close_card()
		return
	var wd: Dictionary = D.WORLDS[w]
	var box := _side_card()
	box.add_child(UI.label(UI.world_name(w), 28, UI.c("accent")))
	box.add_child(UI.label(UI.tr_s(wd.desc), 18, UI.c("dim"), true))
	var fac := UI.faction_name(wd.faction)
	var rep_txt: String = "" if wd.faction == "none" else " (%d%%)" % engine.rep_pct(wd.faction)
	box.add_child(UI.label(UI.tr_s("Held by: %s") % (fac + rep_txt), 18))
	if engine.port_closed(w):
		box.add_child(UI.label(UI.tr_s("Hostile: their ships attack on sight."), 18, UI.c("bad")))
	box.add_child(UI.label(UI.tr_s("Law level: %d of 5") % engine.law_at(w), 18, UI.c("warn") if engine.law_at(w) >= 4 else UI.c("text")))
	var notes := []
	if wd.black:
		notes.append(UI.tr_s("Black market") if engine.flags.has("black_market") else UI.tr_s("Black market (closed to you)"))
	if wd.blind:
		notes.append(UI.tr_s("Blind spot: the Ledger can't see here"))
	if engine.events.has(w):
		for e in D.EVENTS:
			if e.id == engine.events[w].id:
				notes.append("⚠ " + UI.tr_s(e.name))
	for n in notes:
		box.add_child(UI.label("• " + n, 18, UI.c("text"), true))
	if w == engine.loc:
		box.add_child(UI.label(UI.tr_s("You are docked here."), 18, UI.c("go")))
		box.add_child(UI.button("⚓ " + UI.tr_s("Back to port"), show_dock, UI.c("go"), 22, 56))
		box.add_child(UI.label(UI.tr_s("Tap another world to plot a course, or fly with the stick."), 16, UI.c("dim"), true))
		return
	var dist: float = engine.ship_pos.distance_to(engine.pos_of(w))
	var need: float = engine.fuel_for(dist)
	box.add_child(UI.label(UI.tr_s("Fuel: %d of %d") % [int(ceil(need)), int(engine.fuel)], 18, UI.c("bad") if need > engine.fuel else UI.c("text")))
	var days: int = engine._days_for(dist)
	box.add_child(UI.label((UI.tr_s("About 1 day") if days == 1 else UI.tr_s("About %d days") % days) + " · " + UI.tr_s("%d s of flight") % int(ceil(engine.flight_seconds(dist))), 18))
	if engine.can_sniff():
		box.add_child(UI.label(UI.tr_s("Patrol scan chance: %d%%") % int(engine.scan_chance(w) * 100), 18, UI.c("warn")))
	if engine.seen_prices.has(w):
		box.add_child(UI.label(UI.tr_s("Prices seen on day %d") % int(engine.seen_prices[w].get("_day", 0)), 16, UI.c("dim")))
	var go := UI.button("🚀 " + UI.tr_s("Set course"), _set_course.bind(w), UI.c("go"), 22, 56)
	go.disabled = need > engine.fuel + 0.001
	box.add_child(go)
	if go.disabled:
		box.add_child(UI.label(UI.tr_s("Not enough fuel. Refuel at a port."), 16, UI.c("bad"), true))

func _set_course(w: String) -> void:
	_close_card()
	if engine.loc != "":
		_sfx_lib("scifi/thruster_fire")
	map.set_course(w)
	refresh_hud()

func _on_near(w: String) -> void:
	if map == null or map.target != "":
		return
	if w == "":
		_close_card()
		return
	var box := _side_card()
	box.add_child(UI.label(UI.world_name(w), 26, UI.c("accent")))
	box.add_child(UI.button("⚓ " + UI.tr_s("Dock here"), map.dock_here, UI.c("go"), 22, 56))

## The sector's gate: jump to another sector (Veil Expanse and Ember Drift open after Act I).
func _on_gate(at: bool) -> void:
	if map == null or map.target != "":
		return
	if not at:
		_close_card()
		return
	var box := _side_card()
	box.add_child(UI.label("⟁ " + UI.tr_s("Gate"), 26, UI.c("accent")))
	box.add_child(UI.label(UI.tr_s("A jump costs %d fuel and a day.") % int(engine.JUMP_FUEL), 17, UI.c("dim"), true))
	for s in D.SECTOR_ORDER:
		if s == engine.sector:
			continue
		var b := UI.button("→ " + UI.sector_name(s), _jump.bind(s), UI.c("go"), 20, 50)
		b.disabled = not engine.sector_open(s) or engine.fuel < engine.JUMP_FUEL
		box.add_child(b)
		if not engine.sector_open(s):
			box.add_child(UI.label(UI.tr_s("Act III, a later update.") if s == "hollow_deep" else UI.tr_s("Opens after Act I (Ghost in the Net)."), 15, UI.c("dim"), true))

func _jump(s: String) -> void:
	if not engine.jump(s):
		return
	_sfx_lib("scifi/space_engine_large")
	_close_card()
	map.reload()
	refresh()
	_save_game()

func _on_arrived(w: String) -> void:
	_close_card()
	var enc: Dictionary = engine.arrive(w)
	_sfx_lib("scifi/door_open")
	if info:
		info.add("Runs")
	var done: Array = engine.auto_complete()
	_after_missions(done)
	show_dock()
	_flush_story()
	if not enc.is_empty() or not engine.encounter.is_empty():
		show_encounter()
	refresh()

func _after_missions(done: Array) -> void:
	for id in done:
		_sfx("win")
		if info:
			if id == "N02":
				info.add("Debt paid")
			elif id == "N03":
				info.add("Runner")
			elif id == "N12":
				info.add("Act I")
	if engine.flags.has("act1_done") and not _won_reported and info:
		_won_reported = true
		info.result("win")

# ================================================================ encounters

const ENC_ART := {"inspect": "", "scan_pass": "", "scan_clean": "", "scan_blind": "", "scan_lucky": "", "pirates": "sky_dragon",
	"battle": "sky_dragon", "battle_offer": "", "derelict": "world_asteroid", "salvage_site": "", "distress": "sky_milkyway",
	"pod": "sky_milkyway", "bargain": "sky_ridge", "no_fuel": "sky_ridge", "sun": "system_star", "black_hole": "hazard_blackholes",
	"meteors": "hazard_meteors", "flare": "system_star", "tip": "sky_ridge"}
const ENC_TITLE := {"inspect": "Patrol inspection", "scan_pass": "Patrol scan", "scan_clean": "Patrol scan",
	"scan_blind": "Patrol scan", "scan_lucky": "Patrol scan", "pirates": "Raiders", "battle": "Combat",
	"battle_offer": "Ships ahead", "derelict": "A derelict", "salvage_site": "The wreck field", "distress": "Distress beacon",
	"pod": "A cargo pod", "bargain": "A Faustian bargain", "no_fuel": "Out of fuel", "sun": "Stellar heat",
	"black_hole": "A black hole", "meteors": "Meteor shower", "flare": "Solar flare", "tip": "An informant"}
const ENC_TEXT := {
	"inspect": "The scan found something. An officer is coming aboard.",
	"scan_pass": "A patrol sweeps your ship. The hidden hold stays hidden.",
	"scan_clean": "A patrol sweeps your ship. Nothing to find.",
	"scan_blind": "A patrol sweeps your ship, but the solar flare blinds their scanners.",
	"scan_lucky": "The scan should have found your cargo. A glitch in their scanner says otherwise. Lucky.",
	"pirates": "Raiders block your path and hail you: pay, or else.",
	"battle_offer": "Weapons are powering up out there.",
	"derelict": "A dead freighter drifts past, its hold torn open.",
	"salvage_site": "Wrecks drift all around the port. Some still hold cargo.",
	"distress": "A beacon: a small ship with a dead engine asks for help.",
	"pod": "A sealed cargo pod tumbles past. Someone dumped it in a hurry.",
	"bargain": "A smooth voice offers you credits for nothing. Well, for a little bad luck.",
	"no_fuel": "The tank is dry. The ship drifts.",
	"sun": "You flew too close to the star.",
	"black_hole": "A black hole between the orbits.",
	"meteors": "You fly straight into a meteor shower.",
	"flare": "A solar flare washes over the sector. For a while, no scanner works: your next scan sees nothing.",
	"tip": "A voice on a private channel has something to sell, free this time.",
}

func _enemy_sprite(enemy: String) -> Texture2D:
	return SpriteLib.texture(str(D.ENEMIES[enemy].sprite)) if D.ENEMIES.has(enemy) else null

func show_encounter() -> void:
	if engine.encounter.is_empty():
		return
	_close_over()
	var kind := str(engine.encounter.kind)
	if kind == "battle":
		show_battle()
		return
	var art_id: String = ENC_ART.get(kind, "")
	if art_id == "":
		art_id = str(D.WORLDS[engine.loc].view) if engine.loc != "" else "sky_milkyway"
	if kind == "battle_offer" or kind == "pirates":
		_music("techno")
	if kind.begins_with("scan") or kind == "inspect":
		_sfx_lib("scifi/force_field")
	_over = Control.new()
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_over)
	move_child(_over, _hud.get_index())          # under the status bar, over the screen
	_over.add_child(UI.backdrop(art_id))
	var shade := ColorRect.new()
	shade.color = UI.c("shade")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.add_child(shade)
	var p := UI.panel(0.95)
	p.anchor_left = 0.18
	p.anchor_right = 0.82
	p.anchor_top = 0.0
	p.anchor_bottom = 0.0
	p.offset_top = hud_height() + 24
	_over.add_child(p)
	var box := UI.vbox(8)
	p.add_child(box)
	_fill_encounter(box)
	_update_pad()

func _fill_encounter(box: VBoxContainer) -> void:
	var e: Dictionary = engine.encounter
	var kind := str(e.kind)
	box.add_child(UI.label(UI.tr_s(ENC_TITLE.get(kind, "")), 28, UI.c("accent")))
	if kind == "pirates" or kind == "battle_offer":
		var ed: Dictionary = D.ENEMIES[e.enemy]
		var head := UI.hbox(12)
		var tex: Texture2D = _enemy_sprite(str(e.enemy))
		if tex:
			var pic := TextureRect.new()
			pic.texture = tex
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.custom_minimum_size = Vector2(56, 56)
			head.add_child(pic)
		head.add_child(UI.label(UI.tr_s(ed.name), 22, UI.c("bad")))
		box.add_child(head)
		if str(e.get("why", "")) != "":
			box.add_child(UI.label(UI.tr_s(e.why), 18, UI.c("dim"), true))
		box.add_child(UI.label(UI.tr_s("%d ships · %d guns each · hull %d") % [int(ed.ships), int(ed.guns), int(ed.hull)], 17, UI.c("text")))
		box.add_child(UI.meter(UI.tr_s("Your hull"), engine.hull, engine.max_hull(), UI.c("go")))
		if e.get("duel", false):
			box.add_child(UI.label(UI.tr_s("A duel: nobody dies, it ends at the first broken hull."), 16, UI.c("warn"), true))
	box.add_child(UI.label(UI.tr_s(ENC_TEXT.get(kind, "")), 20, UI.c("text"), true))
	if kind == "inspect":
		box.add_child(UI.label(UI.tr_s("Contraband aboard: %d crates") % engine.contraband_aboard(), 18, UI.c("warn")))
	if kind == "bargain":
		var c := str(e.curse)
		box.add_child(UI.label(UI.tr_s("The price: %s (%s) for %d days.") % [UI.perk_name(c), UI.perk_desc(c), S.CURSE_DAYS], 18, UI.c("bad"), true))
	if kind in ["sun", "black_hole"] and str(e.get("hazard", "")) != "":
		box.add_child(UI.label(UI.tr_s(str(e.hazard)), 18, UI.c("warn")))
	for line in e.get("log", []):
		box.add_child(UI.label(UI.msg(line), 20, UI.c("warn"), true))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	box.add_child(row)
	for o in engine.options():
		var b := UI.button(UI.msg(o[1]), _choose.bind(o[0]), UI.c("go") if o[0] in ["ok", "fight", "salvage", "take", "help", "tow"] else UI.c("accent"), 22, 54, true)
		b.custom_minimum_size.x = 200
		b.disabled = not o[2]
		row.add_child(b)

func _choose(opt: String) -> void:
	var kind := str(engine.encounter.get("kind", ""))
	var won_before: int = engine.stats.fights_won
	var passed_before: int = engine.stats.scans_passed
	var lines: Array = engine.choose(opt)
	if engine.stats.fights_won > won_before:
		_sfx_lib("scifi/explosion_crunch")
		if info:
			info.add("Fights won")
	if engine.stats.scans_passed > passed_before and info:
		info.add("Scans passed")
	if not engine.encounter.is_empty():
		if str(engine.encounter.kind) == "battle" and not lines.is_empty():
			_show_result(lines, show_battle)   # "Weapons hot." then the fight
			return
		show_encounter()   # the battle starts, the inspection goes on, or a trap sprang
		return
	if kind.begins_with("scan_") and lines.is_empty():
		_after_encounter()
		return
	_show_result(lines)

## What happened, then Continue (`next`: what Continue does; default: back to the game).
func _show_result(lines: Array, next: Callable = Callable()) -> void:
	_close_over()
	_over = Control.new()
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_over)
	move_child(_over, _hud.get_index())
	var shade := ColorRect.new()
	shade.color = UI.c("shade")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.add_child(shade)
	var p := UI.panel(0.96)
	p.anchor_left = 0.22
	p.anchor_right = 0.78
	p.anchor_top = 0.0
	p.anchor_bottom = 0.0
	p.offset_top = hud_height() + 60
	_over.add_child(p)
	var box := UI.vbox(10)
	p.add_child(box)
	for line in lines:
		box.add_child(UI.label(UI.msg(line), 22, UI.c("text"), true))
	if lines.is_empty():
		box.add_child(UI.label(UI.tr_s("Nothing happens."), 22))
	box.add_child(UI.button(UI.tr_s("Continue"), next if next.is_valid() else _after_encounter, UI.c("go"), 22, 56))
	refresh_hud()

# ================================================================ battles (real time)

func show_battle() -> void:
	_close_over()
	if battle != null and is_instance_valid(battle):
		return
	var e: Dictionary = engine.encounter
	var art := "sky_dragon"
	if engine.loc != "":
		art = str(D.WORLDS[engine.loc].view)
	elif str(e.get("enemy", "")) in ["pirate", "raider_base", "mine_layer"]:
		art = "hazard_meteors"
	battle = BattleView.new()
	battle.game = self
	battle.engine = engine
	battle.pad = pad
	battle.art_id = art
	add_child(battle)
	move_child(battle, _hud.get_index())
	battle.finished.connect(_on_battle_end)
	battle.start()
	_music("techno")
	_sfx_lib("scifi/force_field")
	_update_pad()

func _on_battle_end(outcome: String, binfo: Dictionary) -> void:
	var lines: Array = engine.end_battle(outcome, binfo)
	if info:
		if outcome in ["won", "boarded"]:
			info.add("Fights won")
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
	battle = null
	_show_result(lines)
	_update_pad()

func _after_encounter() -> void:
	_close_over()
	_music("calm")
	if engine.tow_to != "":
		var w: String = engine.tow_to
		engine.tow_to = ""
		engine.loc = ""
		engine.ship_pos = engine.pos_of(w)
		engine.trip_px = maxf(engine.trip_px, 1.0)
		_on_arrived(w)
		return
	var done: Array = engine.auto_complete()
	_after_missions(done)
	_flush_story()
	if dock != null and is_instance_valid(dock):
		dock.page = ""
	refresh()
	_save_game()

func _close_over() -> void:
	if _over != null and is_instance_valid(_over):
		_over.queue_free()
	_over = null

# ================================================================ story cards

func _flush_story() -> void:
	if engine.pending_story.is_empty() or _story_queue.size() > 0:
		return
	for id in engine.pending_story:
		if D.STORY.has(id):
			_story_queue.append_array(D.STORY[id])
	engine.pending_story = []
	_story_i = 0
	if not _story_queue.is_empty():
		_show_story_card()

func _show_story_card() -> void:
	if _story_i >= _story_queue.size():
		_story_queue = []
		if computer != null and is_instance_valid(computer):
			computer.visible = false
		_story_layer_close()
		if not engine.encounter.is_empty():
			show_encounter()
		_update_pad()
		return
	var card: Array = _story_queue[_story_i]
	_story_layer_close()
	var s := Control.new()
	s.name = "Story"
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(s)
	move_child(s, home.get_index())
	s.add_child(UI.backdrop(str(card[0])))
	var p := UI.panel(0.9)
	p.anchor_left = 0.08
	p.anchor_right = 0.92
	p.anchor_top = 0.66
	p.anchor_bottom = 1.0
	p.offset_bottom = -16
	s.add_child(p)
	var box := UI.vbox(8)
	p.add_child(box)
	box.add_child(UI.label(UI.tr_s(str(card[1])), 28, UI.c("accent")))
	var line := UI.tr_s(str(card[2]))
	if line.contains("%s"):
		line = line % str(engine.captain.name)
	box.add_child(UI.label(line, 22, UI.c("text"), true))
	var row := UI.hbox(10)
	box.add_child(row)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	if _story_i == 0 and _story_queue.size() > 1:
		row.add_child(UI.button(UI.tr_s("Skip"), _skip_story, UI.c("dim"), 20, 48))
	row.add_child(UI.button(UI.tr_s("Continue") + "  ▶", _next_story, UI.c("go"), 22, 48))
	if pad != null:
		pad.visible = false

func _story_layer_close() -> void:
	var old := get_node_or_null("Story")
	if old:
		old.name = "StoryOld"
		old.queue_free()

func _next_story() -> void:
	_story_i += 1
	_show_story_card()

func _skip_story() -> void:
	_story_i = _story_queue.size()
	_show_story_card()

# ================================================================ the ship computer (Menu)

func open_computer() -> void:
	if engine == null or home.is_home_visible() or get_node_or_null("Story") != null:
		return
	if computer == null or not is_instance_valid(computer):
		computer = ComputerView.new()
		computer.game = self
		computer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(computer)
		move_child(computer, _hud.get_index())   # under the status bar
	computer.visible = true
	computer.rebuild()
	_sfx("tap")
	_update_pad()

func close_computer() -> void:
	if computer != null and is_instance_valid(computer):
		computer.visible = false
	refresh()

# ================================================================ hints

func _load_hints() -> void:
	var d = SaveUtil.read(HINT_PATH)
	if d is Dictionary:
		_hints = {"left": int(d.get("left", HINT_MAX)), "stamp": int(d.get("stamp", 0))}
	_tick_hints()

func _tick_hints() -> void:
	var now := int(Time.get_unix_time_from_system())
	if int(_hints.left) >= HINT_MAX:
		_hints.left = HINT_MAX
		_hints.stamp = now
		return
	if int(_hints.stamp) <= 0 or int(_hints.stamp) > now:
		_hints.stamp = now
	var gained: int = (now - int(_hints.stamp)) / HINT_REFILL
	if gained > 0:
		_hints.left = mini(HINT_MAX, int(_hints.left) + gained)
		_hints.stamp = now if int(_hints.left) >= HINT_MAX else int(_hints.stamp) + gained * HINT_REFILL

func hints_left() -> int:
	_tick_hints()
	return int(_hints.left)

## Seconds until the next hint comes back (0 when full).
func hint_wait() -> int:
	_tick_hints()
	if int(_hints.left) >= HINT_MAX:
		return 0
	return maxi(0, int(_hints.stamp) + HINT_REFILL - int(Time.get_unix_time_from_system()))

func use_hint() -> bool:
	_tick_hints()
	if int(_hints.left) <= 0:
		return false
	if int(_hints.left) >= HINT_MAX:
		_hints.stamp = int(Time.get_unix_time_from_system())
	_hints.left = int(_hints.left) - 1
	SaveUtil.write(HINT_PATH, _hints)
	return true

# ================================================================ stats, sounds, music, save

func _report_stats() -> void:
	if info == null or engine == null:
		return
	var nw: int = engine.net_worth()
	if nw > int(engine.stats.best_net):
		engine.stats.best_net = nw
	if nw > 0:
		info.high("Best net worth", nw)
	info.high("Most contracts done", engine.stats.contracts)
	info.high("Skills learned", engine.skills.size())
	info.high("Laundered", engine.stats.laundered)
	info.high("Most quests done", engine.stats.quests)
	info.high("Highest Paragon", int(engine.bars.paragon))
	info.high("Highest Outlaw", int(engine.bars.outlaw))
	info.high("Most crew aboard", engine.crew.size())
	info.high("Most endings reached", int(engine.stats.get("endings", 0)))
	var best_rep := 0
	for f in S.FACTION_ORDER:
		best_rep = maxi(best_rep, engine.rep_pct(f))
	info.high("Best faction rep", best_rep)
	if engine.ship == "runner":
		info.high("Highest hull tier", engine.tier)

func _sfx(name: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s and s.has_method("play"):
		s.play(name)

func _sfx_lib(id: String) -> void:
	SoundLib.play(self, id)

func trade_sound() -> void:
	SoundLib.play(self, "rpg/handle_coins")

func _music(style: String) -> void:
	var m = get_node_or_null("/root/Music")
	if m and m.has_method("play"):
		m.play(style, self)

func _notification(what: int) -> void:
	# The window or app lost focus mid-run: the pause menu (it saves too).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if started and home != null and not home.is_home_visible():
			home.pause()

## Called by the kit on pause / 🏠 Home / app suspend (STANDARDS N5). A run not started yet never
## writes (the Landing must not overwrite a save).
func _save_game() -> void:
	if not started or engine == null:
		return
	SaveUtil.write(SAVE_PATH, {"engine": engine.to_dict(), "screen": screen})
	_report_stats()

# ================================================================ skins

func _set_skin(name: String) -> void:
	UI.set_skin(name)
	if creator != null and is_instance_valid(creator):
		creator.rebuild()
	if engine == null or (battle != null and is_instance_valid(battle)):
		return
	_build_hud()
	if screen == "map":
		var sel: String = map.selected if map != null else ""
		var tgt: String = map.target if map != null else ""
		show_map()
		map.selected = sel
		map.target = tgt
	else:
		show_dock()
	if not engine.encounter.is_empty():
		show_encounter()
	if computer != null and is_instance_valid(computer) and computer.visible:
		computer.rebuild()
