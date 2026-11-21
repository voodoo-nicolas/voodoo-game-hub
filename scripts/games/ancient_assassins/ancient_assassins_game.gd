extends Control

## Ancient Assassins: turn-based throwing duels in 3D, over the shoulder (portrait).
## Your assassin stands on a rock island in the foreground; the rival waits on
## another island across the lagoon. Hold, drag to aim (up / down = elevation,
## sideways = direction), release: javelin, throwing axe or chakram fly in an arc
## that gravity bends and the crosswind pushes. Head ×2, body ×1, legs ×0.6.
## Six assassins, 8 Contracts, vs Computer (Easy-Expert), 2 Players on one
## phone, Online. A finishing blow plays in slow motion beside the victim.
##
## Landing menu style: S4 Monument (docs/MENU_STYLES.md) -- not used by the last
## 2 games (Arrow Pop and Block Escape use S10 Bento); the hero art is a render
## of the game (games/ancient_assassins/landing_bg.jpg, tools/shot_ancient_assassins.gd).
## Shared pieces: Landing kit, GameInfo, OnlineMatch, SoundLib, Music. Own 3D:
## aa_world.gd (arena, camera, effects) + aa_character.gd (the assassins, from
## Quaternius' CC0 base characters and animations); Kenney's CC0 Retro Fantasy
## Kit for columns and trees (STANDARDS §16: no shared 3D library exists yet).

const AaEngine = preload("res://scripts/games/ancient_assassins/ancient_assassins_engine.gd")
const AaWorld = preload("res://scripts/games/ancient_assassins/aa_world.gd")
const AaCharacter = preload("res://scripts/games/ancient_assassins/aa_character.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const MenuStyles = preload("res://scripts/games/ancient_assassins/menu_styles.gd")
const HomeKit = preload("res://scripts/games/ancient_assassins/home_kit.gd")
const SoundLib = preload("res://scripts/games/ancient_assassins/sound_lib.gd")
## Not preloaded: older apps don't have them (packs run on any app version).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"
const HELP := preload("res://scripts/games/ancient_assassins/ancient_assassins_help.gd")
const SAVE_PATH := "user://ancient_assassins_save.json"
const PROGRESS_PATH := "user://ancient_assassins_progress.json"
const LANDING_ART := "res://games/ancient_assassins/landing_bg.jpg"

const LEVELS := ["Easy", "Normal", "Hard", "Expert"]
## The six assassins (original characters; names are data, never translated).
## c1 = her colour (outfit), c2 = trim (bracers, headband), hair3d = hairstyle,
## skin3d = skin tint over the base texture.
const CHARS := [
	{"name": "Nefret", "c1": Color("e8b33a"), "c2": Color("2a5bd7"), "hair3d": "parted", "hair_col": Color("15100c"), "skin3d": Color(0.86, 0.68, 0.54), "circlet": true, "cape": false},
	{"name": "Thalia", "c1": Color("c8202f"), "c2": Color("d09040"), "hair3d": "long", "hair_col": Color("4a2c18"), "skin3d": Color(1.0, 0.9, 0.82), "circlet": false, "cape": true},
	{"name": "Sigrun", "c1": Color("7fc4f0"), "c2": Color("9a8a78"), "hair3d": "long", "hair_col": Color("e6c46c"), "skin3d": Color(1.08, 1.0, 0.95), "circlet": false, "cape": false},
	{"name": "Zahra", "c1": Color("18a89a"), "c2": Color("e0b040"), "hair3d": "long", "hair_col": Color("120c0e"), "skin3d": Color(0.9, 0.74, 0.6), "circlet": true, "cape": false},
	{"name": "Livia", "c1": Color("7a2ea0"), "c2": Color("f2ece0"), "hair3d": "buns", "hair_col": Color("7a3018"), "skin3d": Color(1.0, 0.88, 0.8), "circlet": false, "cape": true},
	{"name": "Amani", "c1": Color("ff8a1e"), "c2": Color("1fb36a"), "hair3d": "short", "hair_col": Color("100a08"), "skin3d": Color(0.45, 0.32, 0.25), "circlet": true, "cape": false},
]
## The 8 Contracts: place, computer level, distance (m), strongest crosswind (m/s²), map style, rival health.
const CONTRACTS := [
	{"place": "The Harbour", "level": 0, "dist": 22.0, "wind": 0.8, "style": 0, "hp": 70},
	{"place": "The Temple Steps", "level": 1, "dist": 23.0, "wind": 1.1, "style": 1, "hp": 80},
	{"place": "The Old Aqueduct", "level": 1, "dist": 24.0, "wind": 1.3, "style": 2, "hp": 90},
	{"place": "The Salt Road", "level": 2, "dist": 25.0, "wind": 1.5, "style": 1, "hp": 100},
	{"place": "The Lion Gate", "level": 2, "dist": 26.0, "wind": 1.7, "style": 0, "hp": 100},
	{"place": "The Sun Temple", "level": 2, "dist": 27.0, "wind": 1.9, "style": 2, "hp": 100},
	{"place": "The Royal Gardens", "level": 3, "dist": 28.0, "wind": 2.0, "style": 1, "hp": 100},
	{"place": "The Throne Hill", "level": 3, "dist": 30.0, "wind": 2.2, "style": 2, "hp": 100},
]
const WEAPON_ICONS := ["🗡", "🪓", "⭕"]
const GOLD := Color("ffc24a")
const P_BLUE := Color("2f8cff")
const P_RED := Color("ff3b3b")
## Drag sensitivity: degrees per pixel (the screen's width is ~720 px).
const YAW_PER_PX := 0.06
const PITCH_PER_PX := 0.09
const HOLD_MIN := 0.18     # a shorter touch is not a throw

var info = null      # GameInfo; null on apps without it
var home             # HomeKit
var online = null    # OnlineMatch; null on apps without it
var engine
var world            # AaWorld
var view3d: SubViewport
var skin := "classic"
var mode := "cpu"    # cpu, contract, 2p, online
var cpu_level := 1
var contract := 0
var my_char := 0
var my_seat := 0     # online: 0 = host, 1 = guest
var progress := {"stars": [0, 0, 0, 0, 0, 0, 0, 0], "char": 0}
var started := false
var result_recorded := false
var phase := "aim"   # aim, cpu, fly, settle, over, wait (online: the other phone)
var phase_t := 0.0
var cpu_plan: Dictionary = {}
var cpu_ready := false
var held: Dictionary = {}
var holding := false
var hold_t := 0.0
var drag_from := Vector2.ZERO
var aim_from := Vector2.ZERO     # (yaw, pitch) when the finger went down
var eagle := false
var turn_snap: Dictionary = {}
var pending_state = null
## Kill cam: a throw that will finish someone slows time and closes in.
var kill_target := -1
var tscale := 1.0
var slow_t := 0.0
var kill_zoom := 0.0
var hurt := [0.0, 0.0]
var throw_t := [9.0, 9.0]
var floats: Array = []    # [text, world pos, age, color]
var banner := ""
var banner_t := 0.0
var red_flash := 0.0
var shake := 0.0

var touch: Control
var hud: Control
var pause_btn: Button
var weapon_row: HBoxContainer
var weapon_btns: Array = []
var end_panel: Control
var end_label: Label
var end_next: Button
var results_chip: Button
var picker_view: SubViewport
var picker_char: Node3D

func _ready() -> void:
	preload("res://scripts/games/ancient_assassins/ancient_assassins_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = AaEngine.new()
	_load_progress()
	my_char = int(progress.get("char", 0))
	engine.reset(-1, {"chars": [my_char, (my_char + 1) % CHARS.size()]})
	_build_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	# The 3D arena fills the screen; the HUD floats on top.
	var vc := SubViewportContainer.new()
	vc.stretch = true
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vc)
	vc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view3d = SubViewport.new()
	view3d.own_world_3d = true
	view3d.msaa_3d = Viewport.MSAA_2X
	vc.add_child(view3d)
	world = AaWorld.new()
	view3d.add_child(world)
	world.setup(engine, _defs(), false)
	world.snap_camera(0)

	touch = Control.new()
	touch.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.gui_input.connect(_on_touch)
	add_child(touch)
	touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	pause_btn = HomeKit.neon_button("⏸", HomeKit.BUTTON, 26, 56)
	pause_btn.custom_minimum_size = Vector2(60, 56)
	pause_btn.position = Vector2(12, 30)
	pause_btn.pressed.connect(_on_pause)
	add_child(pause_btn)

	var wm := MarginContainer.new()
	wm.add_theme_constant_override("margin_bottom", 22)
	add_child(wm)
	wm.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	wm.grow_vertical = Control.GROW_DIRECTION_BEGIN
	wm.grow_horizontal = Control.GROW_DIRECTION_BOTH
	weapon_row = HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 12)
	wm.add_child(weapon_row)
	for w in AaEngine.WEAPONS.size():
		var b := HomeKit.neon_button("", GOLD, 24, 62)
		b.custom_minimum_size = Vector2(104, 62)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_weapon.bind(w))
		weapon_row.add_child(b)
		weapon_btns.append(b)

	_build_end_panel()

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("ancient_assassins", tr("Ancient Assassins"), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_on_remote_new_game)
		online.status_changed.connect(_update_ui)
		add_child(online)
	var modes: Array = [
		{"text": "📜 Contracts", "sub": "8 rivals, each tougher than the last", "key": "contract", "action": _start_contract},
	]
	for i in LEVELS.size():
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard", "👑 Expert"][i], "row": "cpu",
			"key": "cpu_%d" % i, "action": _new_vs_cpu.bind(i)})
	modes.append({"text": "👥 2 Players", "sub": "Take turns on one phone", "multi": true, "key": "2p", "action": _new_two_player})
	if online:
		modes.append({"text": "🌐 Online", "sub": "Fight a friend on another phone", "multi": true, "key": "online", "action": online.open_lobby})
	var cfg := {
		# Menu style (docs/MENU_STYLES.md): S4 Monument; sunlit gold + crimson.
		"landing": "monument",
		"landing_style": MenuStyles,
		"title_colors": [Color("ffc24a"), Color("e8452f")],
		"landing_colors": [Color("0d2a44"), Color("2f78d0")],
		"menu_color": GOLD,
		"help": HELP,
		"info": info,
		"accent": GOLD,
		"solo_heading": "Single player",
		"subtitle": "Hold, aim, release. Mind the wind.",
		"modes": modes,
		"extra": _add_char_picker,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [{"text": "🦅 Eagle Eye", "how": "Shows the whole flight of your throw this turn, wind included (not online).", "action": _help_eagle}],
		"board": "Wins",
		"board_note": "Fights won against the computer, Contracts included.",
		"online": online,
	}
	if ResourceLoader.exists(LANDING_ART):
		cfg["art"] = LANDING_ART
		cfg["landing_art"] = true          # the render is the hero art: barely dimmed
		cfg["landing_art_alpha"] = 0.92
	home = HomeKit.new(cfg)
	add_child(home)
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())  # older kits used it; the kit frees it

func _defs() -> Array:
	return [CHARS[int(engine.fighters[0].char)], CHARS[int(engine.fighters[1].char)]]

func _build_end_panel() -> void:
	end_panel = ColorRect.new()
	(end_panel as ColorRect).color = Color(0, 0, 0, 0.45)
	end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	end_panel.visible = false
	# Has its own "👁 See field" + "📋 Results" (STANDARDS §6b): tell GameInfo's
	# safety net (APK 0.41.1+) not to add a second "See board".
	end_panel.set_meta("_tamed", true)
	add_child(end_panel)
	# Docked low, so the winner (front view, centre) stays in sight.
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	m.grow_vertical = Control.GROW_DIRECTION_BEGIN
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_bottom", 26)
	end_panel.add_child(m)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.panel_style())
	m.add_child(pc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	pc.add_child(box)
	end_label = Label.new()
	end_label.add_theme_font_size_override("font_size", 26)
	end_label.add_theme_color_override("font_color", GOLD)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_label)
	end_next = HomeKit.neon_button(tr("Play Again"), HomeKit.GO, 26, 62)
	end_next.pressed.connect(_on_end_next)
	box.add_child(end_next)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	box.add_child(r)
	var see := HomeKit.neon_button(tr("👁 See field"), HomeKit.BUTTON, 22, 56)
	see.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	see.pressed.connect(_see_field)
	r.add_child(see)
	var hb := HomeKit.neon_button(tr("🏠 Home"), HomeKit.BUTTON, 22, 56)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.pressed.connect(_go_home)
	r.add_child(hb)
	results_chip = HomeKit.neon_button(tr("📋 Results"), GOLD, 22, 56)
	results_chip.custom_minimum_size = Vector2(190, 56)
	add_child(results_chip)
	results_chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	results_chip.position.y -= 30
	results_chip.visible = false
	results_chip.pressed.connect(_show_results)

# ---------- setup: pick your assassin (a turning 3D preview) ----------

func _add_char_picker(box: VBoxContainer) -> void:
	box.add_child(home.section("Your assassin"))
	var vc := SubViewportContainer.new()
	vc.stretch = true
	vc.custom_minimum_size = Vector2(0, 300)
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vc)
	picker_view = SubViewport.new()
	picker_view.own_world_3d = true
	picker_view.transparent_bg = true
	picker_view.msaa_3d = Viewport.MSAA_2X
	vc.add_child(picker_view)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.85, 0.95)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e
	picker_view.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 25, 0)
	sun.light_energy = 1.2
	picker_view.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 3.1)
	cam.fov = 40
	picker_view.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0))
	_show_picker_char()
	# Two rows of three names (six don't fit across a phone).
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var group := ButtonGroup.new()
	for i in CHARS.size():
		var b := HomeKit.neon_button(str(CHARS[i].name), HomeKit.BUTTON, 22, 54)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == my_char
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if home.has_method("_style_toggle"):
			home._style_toggle(b, HomeKit.BUTTON)   # the kit's picked look, as its own choice rows
		b.pressed.connect(_pick_char.bind(i))
		grid.add_child(b)

func _show_picker_char() -> void:
	if picker_view == null or not is_instance_valid(picker_view):
		return
	if picker_char and is_instance_valid(picker_char):
		picker_char.queue_free()
	picker_char = AaCharacter.new()
	picker_view.add_child(picker_char)
	picker_char.build(CHARS[my_char], skin == "voodoo")
	picker_char.set_weapon(0, world.weapon_mesh)
	picker_char.play("ready", 0.0)

func _pick_char(i: int) -> void:
	my_char = i
	progress["char"] = i
	_save_progress()
	_show_picker_char()

func _update_ui() -> void:
	if engine.fighters.is_empty():
		return
	var mine := phase == "aim" and _my_turn()
	var f: Dictionary = engine.fighters[engine.turn]
	for w in weapon_btns.size():
		var b: Button = weapon_btns[w]
		var ammo: int = f.ammo[w]
		b.text = WEAPON_ICONS[w] + " " + ("∞" if ammo < 0 else str(ammo))
		b.disabled = not mine or ammo == 0
		b.modulate = Color(1, 1, 1, 1.0 if w == f.weapon else 0.55)
	weapon_row.modulate.a = 1.0 if mine else 0.35
	hud.queue_redraw()

# ---------- flow ----------

func _start_contract() -> void:
	mode = "contract"
	contract = _next_contract()
	_restart()

func _new_vs_cpu(level: int) -> void:
	mode = "cpu"
	cpu_level = level
	_restart()

func _new_two_player() -> void:
	mode = "2p"
	_restart()

func _next_contract() -> int:
	var st: Array = progress.stars
	for i in st.size():
		if int(st[i]) == 0:
			return i
	for i in st.size():
		if int(st[i]) < 3:
			return i
	return st.size() - 1

func _rival_char() -> int:
	return (my_char + 1 + (contract if mode == "contract" else 0)) % CHARS.size()

func _restart() -> void:
	if _is_online():
		online.new_game()
		if online.is_host():
			_online_reset()
		else:
			_wait_for_host()
		return
	SaveUtil.delete(SAVE_PATH)
	var opts := {"chars": [my_char, _rival_char()]}
	if mode == "contract":
		var c: Dictionary = CONTRACTS[contract]
		opts.merge({"dist": c.dist, "wind_max": c.wind, "style": c.style, "hp": [AaEngine.MAX_HP, c.hp]})
		cpu_level = int(c.level)
	engine.reset(-1, opts)
	_begin()
	if mode == "contract":
		_show_banner(tr("Contract %d of 8") % (contract + 1) + "\n" + tr(CONTRACTS[contract].place))

func _begin() -> void:
	_reset_fx()
	_sound("voice/fight", -4.0)
	_music("play", "lively", 2)
	_start_turn()
	world.snap_camera(_view_seat())

## A fresh fight on screen: the arena and assassins rebuilt, effects cleared.
func _reset_fx() -> void:
	started = true
	result_recorded = false
	kill_target = -1
	tscale = 1.0
	slow_t = 0.0
	kill_zoom = 0.0
	floats.clear()
	held.clear()
	holding = false
	hurt = [0.0, 0.0]
	throw_t = [9.0, 9.0]
	end_panel.visible = false
	results_chip.visible = false
	world.rebuild(_defs())
	world.hide_projectile()

func _is_online() -> bool:
	return online != null and online.is_online()

func _vs_cpu() -> bool:
	return mode == "cpu" or mode == "contract"

func _my_turn() -> bool:
	if _is_online():
		return engine.turn == my_seat and online.can_act(true)
	return mode == "2p" or engine.turn == 0

## Whose shoulder the camera is over: this phone's player, or in 2 Players the
## one throwing.
func _view_seat() -> int:
	if _is_online():
		return my_seat
	if mode == "2p":
		if not engine.shot.is_empty():
			return int(engine.shot.owner)
		return engine.turn
	return 0

func _name(i: int) -> String:
	return str(CHARS[int(engine.fighters[i].char)].name)

func _who(i: int) -> String:
	if _is_online():
		return tr("You") if i == my_seat else online.opponent_name()
	if _vs_cpu():
		return tr("You") if i == 0 else tr("Computer")
	return tr("Player %d") % (i + 1)

func _start_turn() -> void:
	eagle = false
	holding = false
	turn_snap = engine.snapshot()
	if engine.is_over():
		_game_over()
		return
	for i in 2:
		world.chars[i].set_weapon(int(engine.fighters[i].weapon) if i == engine.turn else 0, world.weapon_mesh)
	if _is_online():
		phase = "aim" if engine.turn == my_seat else "wait"
		if phase == "aim":
			_show_banner(tr("Your turn"))
	elif _vs_cpu() and engine.turn == 1:
		phase = "cpu"
		phase_t = 0.0
		cpu_plan = {}
		cpu_ready = false
	else:
		phase = "aim"
		if mode == "2p":
			_show_banner(tr("%s's turn") % _who(engine.turn))
	_update_ui()

func _show_banner(text: String) -> void:
	banner = text
	banner_t = 1.8

func _on_weapon(w: int) -> void:
	if phase != "aim" or not _my_turn():
		return
	if engine.pick_weapon(engine.turn, w):
		_sound("sword/draw_rpg", -6.0)
		world.chars[engine.turn].set_weapon(w, world.weapon_mesh)
	_update_ui()

func _throw() -> void:
	held.clear()
	holding = false
	var i: int = engine.turn
	var w: int = engine.fighters[i].weapon
	if engine.fighters[i].ammo[w] == 0:
		w = 0
	kill_target = -1
	var r: Dictionary = engine.predict(i, engine.yaw_of(i), engine.angle_of(i), w)
	if r.f >= 0 and r.f != i:
		var dmg := int(roundf(float(AaEngine.WEAPONS[w].dmg) * float(AaEngine.ZONE_MULT[r.zone])))
		if dmg >= int(engine.fighters[r.f].hp):
			kill_target = r.f
	engine.throw()
	throw_t[i] = 0.0
	world.chars[i].play("throw", 0.08, true)
	world.chars[i].queue_after("idle")
	world.chars[i].set_weapon(-1, world.weapon_mesh)
	world.show_projectile(w)
	if w == 1:
		_sound("sword/swing_axe", -2.0)
	else:
		_sound("sword/swing_katana", -2.0)
	phase = "fly"
	_update_ui()

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_kill_cam(delta)
	var real := delta
	delta *= tscale
	if not started:
		world.tick(real, {"view": 0})
		return
	banner_t = maxf(0.0, banner_t - real)
	red_flash = maxf(0.0, red_flash - real * 1.5)
	shake = maxf(0.0, shake - real * 3.0)
	for i in 2:
		hurt[i] = maxf(0.0, hurt[i] - delta)
		throw_t[i] += delta
	for f in floats:
		f[2] += real
	floats = floats.filter(func(f): return f[2] < 1.4)
	if holding:
		hold_t += real
	match phase:
		"aim":
			if _my_turn():
				_keys(real)
		"cpu":
			_cpu_step(delta)
		"fly":
			var shot_v: Vector3 = engine.shot.v if not engine.shot.is_empty() else Vector3.ZERO
			var shot_w: int = engine.shot.w if not engine.shot.is_empty() else 0
			for ev in engine.step(delta):
				_on_landed(ev, shot_v, shot_w)
			if engine.shot.is_empty():
				world.hide_projectile()
				phase = "settle"
				phase_t = 0.9
		"settle":
			phase_t -= delta
			if phase_t <= 0.0:
				_after_throw()
	_animate()
	var aiming := -1
	if (phase == "aim" and _my_turn() and (holding or not held.is_empty() or eagle)) or (phase == "cpu" and cpu_ready):
		aiming = engine.turn
	world.view3d_shake = shake
	world.tick(real, {"view": _view_seat(), "aiming": aiming, "show_ribbon": phase == "aim" and aiming >= 0,
		"eagle": eagle, "kill": kill_target, "zoom": kill_zoom,
		"winner": engine.winner if phase == "over" and kill_zoom <= 0.01 else -1})
	hud.queue_redraw()

## Each assassin's animation from the state of play.
func _animate() -> void:
	for i in 2:
		var c = world.chars[i]
		var f: Dictionary = engine.fighters[i]
		if int(f.hp) <= 0:
			c.play("death", 0.15)
		elif phase == "over" and engine.winner == i:
			c.play("win", 0.4)
		elif hurt[i] > 0.0 or throw_t[i] < 0.5:
			pass   # hit / throw clips play out
		elif engine.turn == i and ((phase == "aim" and _my_turn() and holding) or (phase == "cpu" and cpu_ready)):
			c.play("aim", 0.2)
		elif engine.turn == i and phase in ["aim", "cpu"]:
			c.play("ready", 0.3)
		else:
			c.play("idle", 0.4)

func _keys(delta: float) -> void:
	if held.is_empty():
		return
	var i: int = engine.turn
	var y: float = engine.yaw_of(i)
	var p: float = engine.angle_of(i)
	if held.has("up"):
		p += 15.0 * delta
	if held.has("down"):
		p -= 15.0 * delta
	if held.has("right"):
		y += 10.0 * delta
	if held.has("left"):
		y -= 10.0 * delta
	engine.set_aim(i, y, p)

func _on_landed(ev: Dictionary, v: Vector3, w: int) -> void:
	var p: Vector3 = ev.p if ev.has("p") else Vector3.ZERO
	match ev.kind:
		"hit":
			var f: int = ev.f
			hurt[f] = 0.45
			var head: bool = ev.zone == "head"
			world.chars[f].flash()
			world.chars[f].play("hit_head" if head else "hit", 0.05, true)
			if int(engine.fighters[f].hp) > 0:
				world.chars[f].queue_after("idle")
			world.burst(p, "hit_head" if head else "hit")
			_sound("impact/punch_heavy", 0.0)
			if head:
				_sound("sword/clash_spear", -4.0)
			var txt := "−%d" % ev.dmg
			if head:
				txt = tr("HEADSHOT!") + "  " + txt
			floats.append([txt, p + Vector3(0, 0.4, 0), 0.0, GOLD if head else Color.WHITE])
			if f == _view_seat():
				red_flash = 1.0
				shake = 1.0
			if f == kill_target and int(engine.fighters[f].hp) <= 0:
				slow_t = 1.3
				_show_banner(tr("Finishing blow!"))
				_sound("sword/clash_spear", 0.0)
			if head and info and f != engine.turn and _counts_for_me(engine.turn):
				info.add("Headshots")
		"stick":
			world.burst(p, ev.surface)
			world.leave_stuck(p, v, w, ev.surface)
			match ev.surface:
				"stone":
					_sound("sword/clash_spear", -6.0)
				"water":
					_sound("impact/soft_heavy", -4.0)
				_:
					_sound("impact/soft_medium", -2.0)

## The kill cam (real time): near the finishing blow and a moment after it,
## time runs at a fifth and the camera moves beside the victim.
func _kill_cam(delta: float) -> void:
	var want := false
	if kill_target >= 0 and phase in ["fly", "settle", "over"] and not engine.fighters.is_empty():
		var head: Vector3 = engine.feet(kill_target) + Vector3(0, 1.4, 0)
		if not engine.shot.is_empty() and (engine.shot.p as Vector3).distance_to(head) < 9.0:
			want = true
		elif engine.shot.is_empty() and slow_t > 0.0:
			slow_t -= delta
			want = true
	tscale = move_toward(tscale, 0.2 if want else 1.0, delta * 4.0)
	kill_zoom = move_toward(kill_zoom, 1.0 if want else 0.0, delta * (3.0 if want else 1.2))

## Does a throw by fighter i count for this phone's stats? (not the computer's)
func _counts_for_me(i: int) -> bool:
	if _is_online():
		return i == my_seat
	return mode == "2p" or i == 0

func _after_throw() -> void:
	engine.settle()
	if pending_state != null:
		var st = pending_state
		pending_state = null
		_apply_state(st)
	else:
		_start_turn()
	if _is_online() and online.is_host():
		online.push_state()  # the host's copy is the one that counts

func _cpu_step(delta: float) -> void:
	phase_t += delta
	var i: int = engine.turn
	if phase_t < 0.6:
		return
	if cpu_plan.is_empty():
		cpu_plan = engine.cpu_plan(i, cpu_level)
		engine.pick_weapon(i, cpu_plan.weapon)
		world.chars[i].set_weapon(int(cpu_plan.weapon), world.weapon_mesh)
		_update_ui()
		return
	if not cpu_ready:
		cpu_ready = engine.cpu_think(cpu_plan)  # a slice per frame: no freeze
		return
	# Swing the aim towards the plan, hold a moment, let go.
	var y: float = engine.yaw_of(i)
	var p: float = engine.angle_of(i)
	var dy: float = cpu_plan.yaw - y
	var dp: float = cpu_plan.pitch - p
	engine.set_aim(i, y + clampf(dy, -30.0 * delta, 30.0 * delta), p + clampf(dp, -40.0 * delta, 40.0 * delta))
	if absf(dy) < 0.15 and absf(dp) < 0.15 and phase_t > 2.2:
		engine.set_aim(i, cpu_plan.yaw, cpu_plan.pitch)
		_throw()

func _game_over() -> void:
	phase = "over"
	started = true
	if not _is_online():
		SaveUtil.delete(SAVE_PATH)
	if result_recorded:
		return
	result_recorded = true
	var w: int = engine.winner
	var msg := ""
	end_next.text = tr("Play Again")
	if _is_online():
		var won: bool = w == my_seat
		msg = online.result_text(won)
		if info:
			info.result("win" if won else "loss", true)
			msg += "\n" + info.summary(["Online wins", "Online losses"])
		_sound("voice/you_win" if won else "voice/you_lose")
	elif _vs_cpu():
		var won: bool = w == 0
		var hp: int = engine.fighters[0].hp
		msg = tr("You win!") if won else tr("The computer wins!")
		if mode == "contract":
			msg = tr("Contract %d of 8") % (contract + 1) + " · " + tr(CONTRACTS[contract].place) + "\n" + msg
			if won:
				var stars := 1 + (1 if hp >= 50 else 0) + (1 if hp >= AaEngine.MAX_HP else 0)
				progress.stars[contract] = maxi(int(progress.stars[contract]), stars)
				_save_progress()
				msg += "\n" + "★".repeat(stars) + "☆".repeat(3 - stars)
				if contract < CONTRACTS.size() - 1:
					end_next.text = tr("Next contract")
		if info:
			info.result("win" if won else "loss")
			if won:
				info.add("Wins (%s)" % LEVELS[cpu_level])
				if hp >= AaEngine.MAX_HP:
					info.add("Flawless wins")
			if mode == "contract":
				var done := 0
				var total := 0
				for s in progress.stars:
					done += 1 if int(s) > 0 else 0
					total += int(s)
				info.high("Contracts completed", done)
				info.high("Contract stars", total)
			msg += "\n" + info.summary(["Wins", "Losses", "Best streak"])
		if won and hp >= AaEngine.MAX_HP:
			_sound("voice/flawless_victory")
		else:
			_sound("voice/you_win" if won else "voice/you_lose")
	else:
		msg = tr("%s wins!") % (_who(w) + " (" + _name(w) + ")")
		_sound("voice/winner")
		if info:
			info.add("2-player games")
			info.celebrate(msg)
	end_label.text = msg
	end_panel.visible = true
	results_chip.visible = false
	_update_ui()

func _on_end_next() -> void:
	if mode == "contract" and engine.winner == 0 and contract < CONTRACTS.size() - 1:
		contract += 1
	_restart()

func _see_field() -> void:
	end_panel.visible = false
	results_chip.visible = true

func _show_results() -> void:
	results_chip.visible = false
	end_panel.visible = true

# ---------- input: hold, drag to aim, release ----------

func _on_touch(event: InputEvent) -> void:
	if phase != "aim" or not _my_turn() or not started:
		return
	var i: int = engine.turn
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			holding = true
			hold_t = 0.0
			drag_from = event.position
			aim_from = Vector2(engine.yaw_of(i), engine.angle_of(i))
			world.chars[i].play("aim_in", 0.1, true)
			world.chars[i].queue_after("aim")
		elif holding:
			holding = false
			if hold_t >= HOLD_MIN:
				if _is_online():
					online.send_move({"y": engine.aim[i][0], "p": engine.aim[i][1], "w": engine.fighters[i].weapon})
				_throw()
	elif event is InputEventMouseMotion and holding:
		var d: Vector2 = event.position - drag_from
		var k := 720.0 / maxf(size.x, 1.0)
		engine.set_aim(i, aim_from.x + d.x * k * YAW_PER_PX, aim_from.y - d.y * k * PITCH_PER_PX)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var map := {KEY_UP: "up", KEY_DOWN: "down", KEY_RIGHT: "right", KEY_LEFT: "left"}
	if map.has(event.keycode):
		if event.pressed:
			held[map[event.keycode]] = true
		else:
			held.erase(map[event.keycode])
	elif event.pressed and not event.echo and phase == "aim" and _my_turn() and started:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			var i: int = engine.turn
			if _is_online():
				online.send_move({"y": engine.aim[i][0], "p": engine.aim[i][1], "w": engine.fighters[i].weapon})
			_throw()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_3:
			_on_weapon(event.keycode - KEY_1)

# ---------- online ----------

func _online_state() -> Dictionary:
	return turn_snap

func _on_online_started(my_player: int) -> void:
	mode = "online"
	my_seat = 0 if my_player == 1 else 1
	home.hide_home()  # an online fight never touches the local save
	if online.is_host():
		_online_reset()
	else:
		_wait_for_host()
		online.send_move({"char": my_char})

func _online_reset() -> void:
	engine.reset(-1, {"chars": [my_char, (my_char + 1) % CHARS.size()]})
	_begin()
	online.push_state()

func _wait_for_host() -> void:
	started = true
	phase = "wait"
	end_panel.visible = false
	results_chip.visible = false
	_show_banner(tr("Waiting for the other player..."))
	_update_ui()

func _on_remote_new_game() -> void:
	if online.is_host():
		_online_reset()
	else:
		_wait_for_host()

func _on_remote_move(p: Dictionary) -> void:
	if p.has("char"):
		if online.is_host():
			var c := clampi(int(p.char), 0, CHARS.size() - 1)
			if c == my_char:
				c = (c + 1) % CHARS.size()
			engine.fighters[1].char = c
			world.rebuild(_defs())
			if phase == "aim" or phase == "wait":
				turn_snap = engine.snapshot()
			online.push_state()
		return
	if not p.has("y") or engine.is_over() or engine.turn == my_seat:
		return
	if phase != "wait" and phase != "aim":
		return
	var i: int = engine.turn
	engine.pick_weapon(i, int(p.get("w", 0)))
	engine.aim[i] = [clampi(int(p.y), -350, 350), clampi(int(p.p), -100, 800)]
	_throw()

func _on_remote_state(st: Dictionary) -> void:
	if phase == "fly" or phase == "settle":
		pending_state = st  # after this throw lands
		return
	_apply_state(st)

func _apply_state(st: Dictionary) -> void:
	var same: bool = engine.seed_ == int(st.get("seed", -1))
	var chars_before := [int(engine.fighters[0].char), int(engine.fighters[1].char)] if engine.fighters.size() == 2 else []
	if not engine.from_dict(st):
		return
	if not same:
		_reset_fx()
		_sound("voice/fight", -4.0)
		world.snap_camera(_view_seat())
	elif chars_before != [int(engine.fighters[0].char), int(engine.fighters[1].char)]:
		world.rebuild(_defs())
	_start_turn()

# ---------- pause / save ----------

func _on_pause() -> void:
	held.clear()
	holding = false
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.is_over() or _is_online() or phase == "over":
		return
	SaveUtil.write(SAVE_PATH, {"engine": engine.to_dict(), "mode": mode, "level": cpu_level, "contract": contract, "v": 2})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	match str(d.get("mode", "cpu")):
		"2p":
			return tr("2 Players")
		"contract":
			return tr("Contract %d of 8") % (int(d.get("contract", 0)) + 1)
	return tr("vs Computer") + " (" + tr(LEVELS[clampi(int(d.get("level", 1)), 0, 3)]) + ")"

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	# Saves from the 2D version (no "v": 2) can't be resumed: a new fight instead.
	if d == null or int(d.get("v", 1)) < 2 or not d.has("engine") or not engine.from_dict(d.engine):
		_new_vs_cpu(1)
		return
	mode = str(d.get("mode", "cpu"))
	if mode == "online":
		mode = "cpu"
	cpu_level = clampi(int(d.get("level", 1)), 0, 3)
	contract = clampi(int(d.get("contract", 0)), 0, CONTRACTS.size() - 1)
	_begin()

func _load_progress() -> void:
	var d = SaveUtil.read(PROGRESS_PATH)
	if d is Dictionary and d.get("stars") is Array and (d.stars as Array).size() == CONTRACTS.size():
		var st: Array = []
		for s in d.stars:
			st.append(clampi(int(s), 0, 3))
		progress = {"stars": st, "char": clampi(int(d.get("char", 0)), 0, CHARS.size() - 1)}

func _save_progress() -> void:
	SaveUtil.write(PROGRESS_PATH, progress)

# ---------- helps (STANDARDS §17) ----------

## 🦅 Eagle Eye: the whole flight of this turn's throw, wind included.
func _help_eagle() -> bool:
	if not started or _is_online() or phase != "aim" or not _my_turn() or eagle:
		return false
	eagle = true
	return true

# ---------- skins ----------

func _set_skin(name: String) -> void:
	skin = name
	if world:
		world.set_skull(name == "voodoo")
	_show_picker_char()

func _current_skin() -> String:
	return skin

# ---------- sound / music ----------

func _sound(id: String, db: float = 0.0) -> void:
	# Ids are full literals at every call site (hub.py sync packs exactly those).
	SoundLib.play(self, id, db)

func _music(what: String, style: String, index: int = 0, fade: float = 1.5) -> void:
	var m = get_node_or_null("/root/Music")
	if m == null:
		return
	if what == "play":
		m.play(style, self, index, fade)
	elif m.has_method("stop"):
		m.stop(fade)

# ---------- the HUD ----------

func _outlined(c: CanvasItem, center: Vector2, text: String, fs: int, col: Color, w: float = 640.0) -> void:
	var font := ThemeDB.fallback_font
	var pos := center - Vector2(w / 2.0, -fs / 3.0)
	c.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 6, Color(0, 0, 0, col.a * 0.75))
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)

func _draw_hud() -> void:
	var c := hud
	var sz := hud.size
	var font := ThemeDB.fallback_font
	var skull := skin == "voodoo"
	# A dark backing so ⏸ reads against the sky.
	var pb := Rect2(pause_btn.position - Vector2(4, 4), pause_btn.size + Vector2(8, 8))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.set_corner_radius_all(12)
	c.draw_style_box(sb, pb)
	if red_flash > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 0, 0, red_flash * 0.25))
	if not started or engine.fighters.is_empty():
		return
	# Health bars: this phone's player (or player 1) left in blue, the rival right in red.
	var left := _view_seat() if mode != "2p" else 0
	var top := 34.0
	var x0 := 84.0
	var gap := 12.0
	var bw := (sz.x - x0 - 14.0 - gap) / 2.0
	for k in 2:
		var i := left if k == 0 else 1 - left
		var f: Dictionary = engine.fighters[i]
		var x := x0 if k == 0 else x0 + bw + gap
		var col: Color = (P_BLUE if k == 0 else P_RED) if not skull else (HomeKit.CYAN if k == 0 else HomeKit.MAGENTA)
		var r := Rect2(x, top, bw, 26)
		c.draw_rect(r, Color(0, 0, 0, 0.45))
		var frac := clampf(float(f.hp) / AaEngine.MAX_HP, 0.0, 1.0)
		var fill := Rect2(r.position, Vector2(bw * frac, 26)) if k == 0 else Rect2(Vector2(r.end.x - bw * frac, top), Vector2(bw * frac, 26))
		c.draw_rect(fill, col)
		c.draw_rect(r, Color(1, 1, 1, 0.7), false, 2.0)
		var label := _who(i).to_upper() if mode != "2p" else _name(i).to_upper()
		c.draw_string_outline(font, Vector2(x + 4, top + 50), label + ("" if mode == "2p" else " · " + _name(i)), HORIZONTAL_ALIGNMENT_LEFT if k == 0 else HORIZONTAL_ALIGNMENT_RIGHT, bw - 8, 18, 5, Color(0, 0, 0, 0.6))
		c.draw_string(font, Vector2(x + 4, top + 50), label + ("" if mode == "2p" else " · " + _name(i)), HORIZONTAL_ALIGNMENT_LEFT if k == 0 else HORIZONTAL_ALIGNMENT_RIGHT, bw - 8, 18, Color.WHITE)
		if engine.turn == i and not engine.is_over():
			var mx := r.position.x + 12 if k == 0 else r.end.x - 12
			c.draw_circle(Vector2(mx, r.get_center().y), 6, Color.WHITE)
	# Wind, under the bars: an arrow and its strength.
	var wy := top + 84.0
	var wv: float = engine.wind / AaEngine.WIND_MAX
	var mid := sz.x / 2.0
	var wcol := Color.WHITE if not skull else HomeKit.LIME
	_outlined(c, Vector2(mid, wy - 8), tr("Wind"), 18, wcol)
	var strength := snappedf(absf(engine.wind) * 10.0, 1.0)
	if strength < 1.0:
		_outlined(c, Vector2(mid, wy + 18), tr("calm"), 22, wcol)
	else:
		var l := 20.0 + 60.0 * absf(wv)
		var d := signf(wv)
		var ay := wy + 16.0
		c.draw_line(Vector2(mid - d * l, ay), Vector2(mid + d * l, ay), Color(0, 0, 0, 0.55), 9.0)
		c.draw_line(Vector2(mid - d * l, ay), Vector2(mid + d * l, ay), wcol, 4.0)
		var tip := Vector2(mid + d * l, ay)
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(d * 10, 0), tip + Vector2(-d * 8, -10), tip + Vector2(-d * 8, 10)]), wcol)
		_outlined(c, Vector2(mid, ay + 26), str(int(strength)), 22, wcol)
	# The elevation ruler, left edge.
	var ri: int = engine.turn
	var show_ruler: bool = phase in ["aim", "cpu", "fly"] and not engine.is_over()
	if show_ruler:
		var ry0 := sz.y * 0.26
		var ry1 := sz.y * 0.70
		var rx := 16.0
		c.draw_rect(Rect2(rx, ry0, 34, ry1 - ry0), Color(1, 1, 1, 0.16))
		var lo := -10.0
		var hi := 70.0
		var deg := lo
		while deg <= hi:
			var y := lerpf(ry1, ry0, (deg - lo) / (hi - lo))
			var big := int(deg) % 10 == 0
			c.draw_line(Vector2(rx, y), Vector2(rx + (24 if big else 12), y), Color(1, 1, 1, 0.85), 2.0 if big else 1.0)
			deg += 5.0
		var a: float = engine.angle_of(ri)
		var my := lerpf(ry1, ry0, (clampf(a, lo, hi) - lo) / (hi - lo))
		var tag := Rect2(rx + 26, my - 15, 64, 30)
		c.draw_rect(tag, GOLD if not skull else HomeKit.CYAN)
		c.draw_colored_polygon(PackedVector2Array([Vector2(rx + 18, my), Vector2(rx + 27, my - 9), Vector2(rx + 27, my + 9)]), GOLD if not skull else HomeKit.CYAN)
		c.draw_string(font, Vector2(tag.position.x, my + 8), "%d°" % int(roundf(a)), HORIZONTAL_ALIGNMENT_CENTER, 64, 20, Color(0.1, 0.06, 0.02))
		var yw: float = engine.yaw_of(ri)
		if absf(yw) >= 0.5:
			c.draw_string_outline(font, Vector2(rx, ry1 + 30), ("◀ %d°" if yw < 0 else "%d° ▶") % int(roundf(absf(yw))), HORIZONTAL_ALIGNMENT_LEFT, 120, 18, 5, Color(0, 0, 0, 0.6))
			c.draw_string(font, Vector2(rx, ry1 + 30), ("◀ %d°" if yw < 0 else "%d° ▶") % int(roundf(absf(yw))), HORIZONTAL_ALIGNMENT_LEFT, 120, 18, Color.WHITE)
	# Weapon in hand + what to do.
	if phase == "aim" and _my_turn():
		var f: Dictionary = engine.fighters[engine.turn]
		_outlined(c, Vector2(mid, sz.y - 112), tr(str(AaEngine.WEAPONS[int(f.weapon)].name)), 22, GOLD)
		if not holding and held.is_empty():
			_outlined(c, Vector2(mid, sz.y * 0.8), tr("Hold, drag to aim, let go to throw"), 22, Color(1, 1, 1, 0.65 + 0.35 * sin(Time.get_ticks_msec() / 300.0)))
	if _is_online() and not engine.is_over():
		_outlined(c, Vector2(mid, sz.y - 140), online.status_text(engine.turn == my_seat, _name(engine.turn)), 20, Color.WHITE)
	# Floating hit numbers over the 3D scene.
	for fl in floats:
		var sp = world.screen_of(fl[1])
		if sp == null:
			continue
		var t: float = fl[2] / 1.4
		_outlined(c, (sp as Vector2) + Vector2(0, -50.0 * t), fl[0], 30, Color(fl[3], 1.0 - t * t))
	if banner_t > 0.0 and banner != "":
		var a := clampf(banner_t * 2.0, 0.0, 1.0)
		var lines := banner.split("\n")
		for j in lines.size():
			_outlined(c, Vector2(mid, sz.y * 0.34 + j * 50), lines[j], 40 if j == 0 else 28, Color(GOLD, a))
