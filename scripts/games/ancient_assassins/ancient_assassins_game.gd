extends Control

## Ancient Assassins: turn-based throwing duels on the ruins of the old world.
## Hold anywhere, pull back like a slingshot, let go: javelin, throwing axe or
## chakram fly in an arc that gravity bends and the wind pushes. Head ×2,
## body ×1, legs ×0.6. Six assassins to play (all drawn in code), 8 Contracts,
## vs Computer (Easy-Expert), 2 Players on one phone, Online.
##
## Landing menu style: S4 Monument (docs/MENU_STYLES.md) -- not used by the last
## 2 games (Arrow Pop and Block Escape use S10 Bento); one heroine is the hero art.
## Palette: sunset gold / crimson (Classic), neon on black (Skull mode).
## Shared pieces: Landing kit, GameInfo, OnlineMatch, SoundLib (sword / impact /
## voice sets), Music. Own drawing: the field and the assassins (no library
## sprite fits a throwing pose; STANDARDS §16).

const AaEngine = preload("res://scripts/games/ancient_assassins/ancient_assassins_engine.gd")
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

const LEVELS := ["Easy", "Normal", "Hard", "Expert"]
## The six assassins (original characters). hair: 0 bob, 1 ponytail, 2 braid,
## 3 veil, 4 bun, 5 short with a circlet. Names are data (never translated).
const CHARS := [
	{"name": "Nefret", "from": "Egypt", "c1": Color("e8b33a"), "c2": Color("2a5bd7"), "skin": Color("b07850"), "hair": 0, "hair_col": Color("17110e"), "cape": false},
	{"name": "Thalia", "from": "Sparta", "c1": Color("c8202f"), "c2": Color("d09040"), "skin": Color("dba57c"), "hair": 1, "hair_col": Color("3a2416"), "cape": true},
	{"name": "Sigrun", "from": "the North", "c1": Color("7fc4f0"), "c2": Color("8a7a6a"), "skin": Color("f0c8a8"), "hair": 2, "hair_col": Color("e2bf62"), "cape": false},
	{"name": "Zahra", "from": "Persia", "c1": Color("18a89a"), "c2": Color("e0b040"), "skin": Color("c8926a"), "hair": 3, "hair_col": Color("140f12"), "cape": false},
	{"name": "Livia", "from": "Rome", "c1": Color("7a2ea0"), "c2": Color("f2ece0"), "skin": Color("e2b48e"), "hair": 4, "hair_col": Color("7a3018"), "cape": true},
	{"name": "Amani", "from": "Kush", "c1": Color("ff8a1e"), "c2": Color("1fb36a"), "skin": Color("6b4228"), "hair": 5, "hair_col": Color("120c0a"), "cape": false},
]
## The 8 Contracts: place, computer level, distance, strongest wind, map style, rival health.
const CONTRACTS := [
	{"place": "The Harbour", "level": 0, "dist": 950.0, "wind": 80.0, "style": 0, "hp": 70},
	{"place": "The Temple Steps", "level": 1, "dist": 1050.0, "wind": 120.0, "style": 2, "hp": 80},
	{"place": "The Old Aqueduct", "level": 1, "dist": 1100.0, "wind": 150.0, "style": 1, "hp": 90},
	{"place": "The Salt Road", "level": 2, "dist": 1150.0, "wind": 170.0, "style": 2, "hp": 100},
	{"place": "The Lion Gate", "level": 2, "dist": 1200.0, "wind": 190.0, "style": 0, "hp": 100},
	{"place": "The Sun Temple", "level": 2, "dist": 1250.0, "wind": 200.0, "style": 1, "hp": 100},
	{"place": "The Royal Gardens", "level": 3, "dist": 1250.0, "wind": 200.0, "style": 2, "hp": 100},
	{"place": "The Throne Hill", "level": 3, "dist": 1300.0, "wind": 220.0, "style": 1, "hp": 100},
]
const WEAPON_ICONS := ["🗡", "🪓", "⭕"]
const GOLD := Color("ffc24a")
const STEEL := Color("d4dae4")
const WOOD := Color("8a5a2a")
const BRONZE := Color("c98a3b")

var info = null      # GameInfo; null on apps without it
var home             # HomeKit
var online = null    # OnlineMatch; null on apps without it
var engine
var skin := "classic"
var mode := "cpu"    # cpu, contract, 2p, online
var cpu_level := 1
var contract := 0
var my_char := 0
var my_seat := 0     # online: 0 = host (left), 1 = guest (right)
var progress := {"stars": [0, 0, 0, 0, 0, 0, 0, 0], "char": 0}
var started := false
var result_recorded := false
var phase := "aim"   # aim, cpu, fly, settle, over, wait (online: the other phone)
var phase_t := 0.0
var cpu_plan: Dictionary = {}
var cpu_ready := false
var held: Dictionary = {}
var dragging := false
var drag_from := Vector2.ZERO
var eagle := false   # 🦅 help: the whole flight shows this turn
var turn_snap: Dictionary = {}
var pending_state = null

# Animation state.
var time := 0.0
var hurt := [0.0, 0.0]
var down := [0.0, 0.0]
var throw_t := [9.0, 9.0]
var pull := [0.0, 0.0]
var sparks: Array = []   # [pos, vel, life, color]
var floats: Array = []   # [text, pos, age, color]
var shake := 0.0
var banner := ""
var banner_t := 0.0
var clouds: Array = []   # [pos, size]
var ruins: Array = []    # far skyline: {"x", "kind", "w", "h"}
var stars_bg: Array = []

var field: Control
var pause_btn: Button
var weapon_btns: Array = []
var end_panel: Control
var end_label: Label
var end_next: Button
var results_chip: Button

func _ready() -> void:
	preload("res://scripts/games/ancient_assassins/ancient_assassins_i18n.gd").install(self)
	Orientation.lock_landscape()
	engine = AaEngine.new()
	_load_progress()
	my_char = int(progress.get("char", 0))
	engine.reset(-1, {"chars": [my_char, (my_char + 1) % CHARS.size()]})
	_make_scenery()
	_build_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	field = Control.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.gui_input.connect(_on_field_input)
	field.resized.connect(field.queue_redraw)
	add_child(field)

	pause_btn = HomeKit.neon_button("⏸", HomeKit.BUTTON, 28, 60)
	pause_btn.custom_minimum_size = Vector2(68, 60)
	pause_btn.position = Vector2(44, 12)
	pause_btn.pressed.connect(_on_pause)
	add_child(pause_btn)

	var wm := MarginContainer.new()
	wm.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	wm.grow_vertical = Control.GROW_DIRECTION_BEGIN
	wm.add_theme_constant_override("margin_left", 44)
	wm.add_theme_constant_override("margin_bottom", 14)
	add_child(wm)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	wm.add_child(row)
	for w in AaEngine.WEAPONS.size():
		var b := HomeKit.neon_button("", GOLD, 24, 60)
		b.custom_minimum_size = Vector2(96, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_weapon.bind(w))
		row.add_child(b)
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
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S4 Monument; sunset gold + crimson.
		"landing": "monument",
		"landing_style": MenuStyles,
		"title_colors": [Color("ffc24a"), Color("e8452f")],
		"landing_colors": [Color("1a0d1f"), Color("5a2430")],
		"menu_color": GOLD,
		"help": HELP,
		"info": info,
		"accent": GOLD,
		"solo_heading": "Single player",
		"subtitle": "Hold, pull back, release. Mind the wind.",
		"logo": _draw_home_logo,
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
	})
	add_child(home)
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())  # older kits used it; the kit frees it

func _build_end_panel() -> void:
	end_panel = ColorRect.new()
	(end_panel as ColorRect).color = Color(0, 0, 0, 0.6)
	end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	end_panel.visible = false
	# Has its own "👁 See field" + "📋 Results" (STANDARDS §6b): tell GameInfo's
	# safety net (APK 0.41.1+) not to add a second "See board".
	end_panel.set_meta("_tamed", true)
	add_child(end_panel)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.add_child(cc)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.panel_style())
	cc.add_child(pc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	pc.add_child(box)
	end_label = Label.new()
	end_label.add_theme_font_size_override("font_size", 28)
	end_label.add_theme_color_override("font_color", GOLD)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_label.custom_minimum_size = Vector2(520, 0)
	box.add_child(end_label)
	end_next = HomeKit.neon_button(tr("Play Again"), HomeKit.GO, 26, 64)
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
	results_chip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	results_chip.position = Vector2(-90, 12)
	results_chip.custom_minimum_size = Vector2(180, 56)
	results_chip.visible = false
	results_chip.pressed.connect(_show_results)
	add_child(results_chip)

func _add_char_picker(box: VBoxContainer) -> void:
	box.add_child(home.section("Your assassin"))
	var names: Array = []
	for ch in CHARS:
		names.append(ch.name)
	box.add_child(home.choice_row(names, my_char, _pick_char))

func _pick_char(i: int) -> void:
	my_char = i
	progress["char"] = i
	_save_progress()

func _update_ui() -> void:
	var mine := phase == "aim" and _my_turn()
	if engine.fighters.is_empty():
		return
	var f: Dictionary = engine.fighters[engine.turn]
	for w in weapon_btns.size():
		var b: Button = weapon_btns[w]
		var ammo: int = f.ammo[w]
		b.text = WEAPON_ICONS[w] + " " + ("∞" if ammo < 0 else str(ammo))
		b.disabled = not mine or ammo == 0
		b.modulate = Color(1, 1, 1, 1.0 if w == f.weapon else 0.55)
	weapon_btns[0].get_parent().modulate.a = 1.0 if mine else 0.4
	field.queue_redraw()

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
	started = true
	result_recorded = false
	sparks.clear()
	floats.clear()
	held.clear()
	hurt = [0.0, 0.0]
	down = [0.0, 0.0]
	throw_t = [9.0, 9.0]
	pull = [0.0, 0.0]
	end_panel.visible = false
	results_chip.visible = false
	_make_scenery()
	_sound("voice/fight", -4.0)
	_music("play", "lively", 2)
	_start_turn()

func _is_online() -> bool:
	return online != null and online.is_online()

func _vs_cpu() -> bool:
	return mode == "cpu" or mode == "contract"

func _my_turn() -> bool:
	if _is_online():
		return engine.turn == my_seat and online.can_act(true)
	return mode == "2p" or engine.turn == 0

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
	dragging = false
	pull = [0.0, 0.0]
	turn_snap = engine.snapshot()
	if engine.is_over():
		_game_over()
		return
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
	_update_ui()

func _throw() -> void:
	held.clear()
	dragging = false
	var i: int = engine.turn
	var w: int = engine.fighters[i].weapon
	engine.throw()
	throw_t[i] = 0.0
	pull[i] = 0.0
	if w == 1:
		_sound("sword/swing_axe", -2.0)
	else:
		_sound("sword/swing_katana", -2.0)
	phase = "fly"
	_update_ui()

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	time += delta
	for c in clouds:
		c[0].x = fposmod(c[0].x + engine.wind * 0.12 * delta + 4.0 * delta, AaEngine.W + 400.0)
	if not started:
		field.queue_redraw()
		return
	banner_t = maxf(0.0, banner_t - delta)
	shake = maxf(0.0, shake - delta * 2.5)
	for i in 2:
		hurt[i] = maxf(0.0, hurt[i] - delta * 2.2)
		throw_t[i] += delta
		if engine.fighters[i].hp <= 0:
			down[i] = minf(1.0, down[i] + delta * 2.2)
	for s in sparks:
		s[0] += s[1] * delta
		s[1].y += 500.0 * delta
		s[2] -= delta
	sparks = sparks.filter(func(s): return s[2] > 0.0)
	for f in floats:
		f[2] += delta
	floats = floats.filter(func(f): return f[2] < 1.4)
	match phase:
		"aim":
			if _my_turn():
				_keys(delta)
		"cpu":
			_cpu_step(delta)
		"fly":
			for ev in engine.step(delta):
				_on_landed(ev)
			if engine.shot.is_empty():
				phase = "settle"
				phase_t = 0.8
		"settle":
			phase_t -= delta
			if phase_t <= 0.0:
				_after_throw()
	field.queue_redraw()

func _keys(delta: float) -> void:
	if held.is_empty():
		return
	var i: int = engine.turn
	var a: float = engine.angle_of(i)
	var p: float = engine.power_of(i)
	var dir: float = 1.0 if engine.fighters[i].facing > 0 else -1.0
	if held.has("up"):
		a += 40.0 * delta * dir
	if held.has("down"):
		a -= 40.0 * delta * dir
	if held.has("more"):
		p += 30.0 * delta
	if held.has("less"):
		p -= 30.0 * delta
	engine.set_aim(i, a, p)
	pull[i] = 1.0

func _on_landed(ev: Dictionary) -> void:
	var p: Vector2 = ev.p if ev.has("p") else Vector2.ZERO
	match ev.kind:
		"hit":
			var f: int = ev.f
			hurt[f] = 1.0
			shake = minf(1.0, shake + 0.5)
			var head: bool = ev.zone == "head"
			_sound("impact/punch_heavy", 0.0)
			if head:
				_sound("sword/clash_spear", -4.0)
			var txt := "−%d" % ev.dmg
			if head:
				txt = tr("HEADSHOT!") + "  " + txt
			floats.append([txt, p + Vector2(0, -30), 0.0, GOLD if head else Color.WHITE])
			_burst(p, 22 if head else 14, [GOLD, Color.WHITE])
			if head and info and f != engine.turn and _counts_for_me(engine.turn):
				info.add("Headshots")
		"stick":
			if ev.surface == "stone":
				_sound("sword/clash_spear", -6.0)
				_burst(p, 10, [STEEL, GOLD])
			else:
				_sound("impact/soft_medium", -2.0)
				_burst(p, 8, [Color("c9a26a"), Color("8a6a44")])

## Does a throw by fighter i count for this phone's stats? (not the computer's)
func _counts_for_me(i: int) -> bool:
	if _is_online():
		return i == my_seat
	return mode == "2p" or i == 0

func _burst(p: Vector2, n: int, cols: Array) -> void:
	for k in n:
		sparks.append([p, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 320.0) + Vector2(0, -120), randf_range(0.3, 0.8), cols[k % cols.size()]])

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
	if phase_t < 0.5:
		return
	if cpu_plan.is_empty():
		cpu_plan = engine.cpu_plan(i, cpu_level)
		engine.pick_weapon(i, cpu_plan.weapon)
		_update_ui()
		return
	if not cpu_ready:
		cpu_ready = engine.cpu_think(cpu_plan)  # one angle per frame: no freeze
		return
	# Swing the aim towards the plan while pulling back, then let go.
	var a: float = engine.angle_of(i)
	var p: float = engine.power_of(i)
	var da: float = angle_difference(deg_to_rad(a), deg_to_rad(cpu_plan.angle))
	var dp: float = cpu_plan.power - p
	engine.set_aim(i, a + clampf(rad_to_deg(da), -120.0 * delta, 120.0 * delta), p + clampf(dp, -90.0 * delta, 90.0 * delta))
	pull[i] = minf(1.0, pull[i] + delta * 2.0)
	if absf(rad_to_deg(da)) < 0.3 and absf(dp) < 0.3 and pull[i] >= 1.0:
		engine.set_aim(i, cpu_plan.angle, cpu_plan.power)
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
		return
	_restart()

func _see_field() -> void:
	end_panel.visible = false
	results_chip.visible = true

func _show_results() -> void:
	results_chip.visible = false
	end_panel.visible = true

# ---------- input: hold, pull back, release ----------

func _on_field_input(event: InputEvent) -> void:
	if phase != "aim" or not _my_turn() or not started:
		return
	var i: int = engine.turn
	var g := _geom()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_from = event.position
			pull[i] = 0.0
		elif dragging:
			dragging = false
			var d: Vector2 = (drag_from - event.position) / g.k
			if d.length() >= 25.0:
				_aim_from_pull(i, d)
				if _is_online():
					online.send_move({"a": engine.aim[i][0], "p": engine.aim[i][1], "w": engine.fighters[i].weapon})
				_throw()
			else:
				pull[i] = 0.0
	elif event is InputEventMouseMotion and dragging:
		var d: Vector2 = (drag_from - event.position) / g.k
		if d.length() >= 8.0:
			_aim_from_pull(i, d)

## Pulling back by d (world units) throws the opposite way of the finger.
func _aim_from_pull(i: int, d: Vector2) -> void:
	engine.set_aim(i, rad_to_deg(atan2(-d.y, d.x)), d.length() / 2.4)
	pull[i] = clampf(d.length() / 240.0, 0.0, 1.0)
	field.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var map := {KEY_UP: "up", KEY_DOWN: "down", KEY_RIGHT: "more", KEY_LEFT: "less"}
	if map.has(event.keycode):
		if event.pressed:
			held[map[event.keycode]] = true
		else:
			held.erase(map[event.keycode])
	elif event.pressed and not event.echo and phase == "aim" and _my_turn() and started:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			var i: int = engine.turn
			if _is_online():
				online.send_move({"a": engine.aim[i][0], "p": engine.aim[i][1], "w": engine.fighters[i].weapon})
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
			if phase == "aim" or phase == "wait":
				turn_snap = engine.snapshot()
			online.push_state()
		return
	if not p.has("a") or engine.is_over() or engine.turn == my_seat:
		return
	if phase != "wait" and phase != "aim":
		return
	var i: int = engine.turn
	engine.pick_weapon(i, int(p.get("w", 0)))
	engine.aim[i] = [int(p.a), clampi(int(p.p), 100, 1000)]
	engine.set_aim(i, engine.angle_of(i), engine.power_of(i))
	_throw()

func _on_remote_state(st: Dictionary) -> void:
	if phase == "fly" or phase == "settle":
		pending_state = st  # after this throw lands
		return
	_apply_state(st)

func _apply_state(st: Dictionary) -> void:
	var keep: Array = engine.stuck
	var same: bool = engine.seed_ == int(st.get("seed", -1))
	if not engine.from_dict(st):
		return
	if same:
		engine.stuck = keep
	else:
		_begin_quiet()
	_start_turn()

## A new fight arrived from the host: reset the animations, no "fight!" twice.
func _begin_quiet() -> void:
	started = true
	result_recorded = false
	hurt = [0.0, 0.0]
	down = [0.0, 0.0]
	end_panel.visible = false
	results_chip.visible = false
	_make_scenery()
	_sound("voice/fight", -4.0)

# ---------- pause / save ----------

func _on_pause() -> void:
	held.clear()
	dragging = false
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.is_over() or _is_online() or phase == "over":
		return
	SaveUtil.write(SAVE_PATH, {"engine": engine.to_dict(), "mode": mode, "level": cpu_level, "contract": contract})

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
	if d == null or not d.has("engine") or not engine.from_dict(d.engine):
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
	if field:
		field.queue_redraw()

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

# ---------- drawing ----------

func _make_scenery() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = engine.seed_ + 99
	clouds = []
	for i in 7:
		clouds.append([Vector2(r.randf() * (AaEngine.W + 400.0) - 200.0, r.randf_range(60.0, 260.0)), r.randf_range(50.0, 120.0)])
	ruins = []
	var x := -40.0
	while x < AaEngine.W + 40.0:
		var kind := r.randi() % 4
		var w := r.randf_range(60.0, 180.0)
		ruins.append({"x": x, "kind": kind, "w": w, "h": r.randf_range(70.0, 190.0)})
		x += w + r.randf_range(20.0, 120.0)
	stars_bg = []
	for i in 80:
		stars_bg.append([Vector2(r.randf() * AaEngine.W, r.randf() * 520.0), r.randf_range(0.6, 1.8)])

func _geom() -> Dictionary:
	var k: float = minf(field.size.x / AaEngine.W, field.size.y / AaEngine.H)
	var o := Vector2((field.size.x - AaEngine.W * k) / 2.0, field.size.y - AaEngine.H * k)
	if shake > 0.0:
		o += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 7.0
	return {"k": k, "o": o}

func _voodoo() -> bool:
	return skin == "voodoo"

func _draw_field() -> void:
	var g := _geom()
	var k: float = g.k
	var o: Vector2 = g.o
	var c := field
	_draw_sky(c, o, k)
	_draw_ground(c, o, k)
	_draw_flag(c, o, k)
	for s in engine.stuck:
		if int(s.f) < 0:
			_draw_weapon(c, o + (s.p as Vector2) * k, float(s.a), int(s.w), k, true)
	for i in engine.fighters.size():
		var f: Dictionary = engine.fighters[i]
		var st := {"hurt": hurt[i], "down": down[i], "weapon": int(f.weapon), "aiming": false, "pull": pull[i],
			"throw_t": throw_t[i], "angle": engine.angle_of(i), "wind": engine.wind / AaEngine.WIND_MAX}
		var aiming: bool = engine.turn == i and (phase == "aim" or phase == "cpu") and not engine.is_over()
		st.aiming = aiming or throw_t[i] < 0.35
		st.hold = aiming
		_draw_assassin(c, o + Vector2(f.x, f.y) * k, k, int(f.char), int(f.facing), st)
	_draw_aim(c, o, k)
	if not engine.shot.is_empty():
		var s: Dictionary = engine.shot
		var pts := PackedVector2Array()
		for p in s.trail:
			pts.append(o + p * k)
		pts.append(o + s.p * k)
		if pts.size() > 1:
			c.draw_polyline(pts, Color(1, 1, 1, 0.22), 2.0, true)
		var sp: Vector2 = o + s.p * k
		if sp.y < 4.0:
			var col := HomeKit.CYAN if _voodoo() else GOLD
			c.draw_colored_polygon(PackedVector2Array([Vector2(sp.x - 10, 22), Vector2(sp.x, 6), Vector2(sp.x + 10, 22)]), col)
		else:
			var ang: float = (s.v as Vector2).angle() if s.w == 0 else float(s.spin) * (1.0 if (s.v as Vector2).x >= 0 else -1.0)
			_draw_weapon(c, sp, ang, int(s.w), k, false)
	for s in sparks:
		var p: Vector2 = o + s[0] * k
		c.draw_line(p, p - s[1] * 0.03 * k, Color(s[3], clampf(s[2] * 2.0, 0.0, 1.0)), 2.0)
	var font := ThemeDB.fallback_font
	for f in floats:
		var t: float = f[2] / 1.4
		var p: Vector2 = o + (f[1] as Vector2) * k + Vector2(0, -60.0 * t)
		_outlined(c, font, p, f[0], int(clampf(34 * k, 20, 34)), Color(f[3], 1.0 - t * t))
	_draw_hud(c, o, k)

func _outlined(c: CanvasItem, font: Font, center: Vector2, text: String, fs: int, col: Color) -> void:
	var w := 600.0
	var pos := center - Vector2(w / 2.0, -fs / 3.0)
	c.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 6, Color(0, 0, 0, col.a * 0.8))
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)

func _vgrad(c: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	c.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

func _draw_sky(c: CanvasItem, o: Vector2, k: float) -> void:
	var sz := field.size
	var hz: float = o.y + 640.0 * k   # horizon line
	if _voodoo():
		c.draw_rect(Rect2(Vector2.ZERO, sz), Color("07040c"))
		for s in stars_bg:
			c.draw_circle(o + s[0] * k, s[1], Color(1, 1, 1, 0.35 + 0.25 * sin(time * 2.0 + s[0].x)))
		# A skull moon.
		var m := o + Vector2(1180, 180) * k
		var r := 58.0 * k
		HomeKit.glow_circle(c, m, r, HomeKit.MAGENTA, 2.0, 0.08)
		c.draw_circle(m + Vector2(-20, -6) * k, 12.0 * k, Color(HomeKit.MAGENTA, 0.8))
		c.draw_circle(m + Vector2(20, -6) * k, 12.0 * k, Color(HomeKit.MAGENTA, 0.8))
		c.draw_colored_polygon(PackedVector2Array([m + Vector2(0, 8) * k, m + Vector2(-6, 20) * k, m + Vector2(6, 20) * k]), Color(HomeKit.MAGENTA, 0.8))
		for t in 5:
			c.draw_line(m + Vector2(-20 + t * 10, 34) * k, m + Vector2(-20 + t * 10, 46) * k, Color(HomeKit.MAGENTA, 0.8), 2.0)
	else:
		_vgrad(c, Rect2(0, 0, sz.x, hz * 0.45), Color("2a1640"), Color("7a2f52"))
		_vgrad(c, Rect2(0, hz * 0.45, sz.x, hz * 0.4), Color("7a2f52"), Color("e2683a"))
		_vgrad(c, Rect2(0, hz * 0.85, sz.x, sz.y - hz * 0.85), Color("e2683a"), Color("ffc46a"))
		var sun := o + Vector2(1120, 560) * k
		for ring in 4:
			c.draw_circle(sun, (110.0 + ring * 40.0) * k, Color(1.0, 0.8, 0.45, 0.06))
		c.draw_circle(sun, 92.0 * k, Color("ffd98a"))
	# Clouds drift with the wind.
	for cl in clouds:
		var p: Vector2 = o + (cl[0] as Vector2 - Vector2(200, 0)) * k
		var s: float = cl[1] * k
		var col := Color(0.6, 0.3, 0.9, 0.12) if _voodoo() else Color(1.0, 0.75, 0.7, 0.28)
		c.draw_circle(p, s * 0.45, col)
		c.draw_circle(p + Vector2(s * 0.45, s * 0.1), s * 0.35, col)
		c.draw_circle(p + Vector2(-s * 0.45, s * 0.12), s * 0.3, col)
	# Far skyline of ruins.
	var far := Color(0.35, 0.1, 0.55, 0.5) if _voodoo() else Color("5a2238")
	far.a = 0.55 if not _voodoo() else far.a
	var base: float = 640.0
	for r in ruins:
		var x0: float = r.x
		var w: float = r.w
		var h: float = r.h
		match int(r.kind):
			0:  # a row of columns with a beam
				var n := maxi(2, int(w / 32.0))
				for j in n:
					var cx := x0 + j * w / (n - 1)
					c.draw_rect(Rect2(o + Vector2(cx - 6, base - h) * k, Vector2(12, h) * k), far)
				c.draw_rect(Rect2(o + Vector2(x0 - 10, base - h - 12) * k, Vector2(w + 20, 12) * k), far)
			1:  # a temple front
				c.draw_rect(Rect2(o + Vector2(x0, base - h * 0.7) * k, Vector2(w, h * 0.7) * k), far)
				c.draw_colored_polygon(PackedVector2Array([o + Vector2(x0 - 8, base - h * 0.7) * k, o + Vector2(x0 + w / 2.0, base - h) * k, o + Vector2(x0 + w + 8, base - h * 0.7) * k]), far)
			2:  # a broken arch
				c.draw_rect(Rect2(o + Vector2(x0, base - h) * k, Vector2(18, h) * k), far)
				c.draw_rect(Rect2(o + Vector2(x0 + w - 18, base - h * 0.6) * k, Vector2(18, h * 0.6) * k), far)
				c.draw_arc(o + Vector2(x0 + w / 2.0, base - h * 0.7) * k, (w / 2.0 - 9.0) * k, PI, PI * 1.55, 12, far, 14.0 * k)
			_:  # a step pyramid
				for st in 4:
					var sw := w * (1.0 - st * 0.2)
					c.draw_rect(Rect2(o + Vector2(x0 + (w - sw) / 2.0, base - h * (st + 1) / 4.0) * k, Vector2(sw, h / 4.0 + 1) * k), far)
	c.draw_rect(Rect2(0, o.y + base * k, field.size.x, field.size.y), far)

func _draw_ground(c: CanvasItem, o: Vector2, k: float) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, o.y + engine.ground[0] * k))
	for i in AaEngine.COLS:
		pts.append(o + Vector2(i * AaEngine.STEP, engine.ground[i]) * k)
	pts.append(Vector2(field.size.x, o.y + engine.ground[AaEngine.COLS - 1] * k))
	var fill := pts.duplicate()
	fill.append(Vector2(field.size.x, field.size.y + 10))
	fill.append(Vector2(0, field.size.y + 10))
	var rim: Color
	if _voodoo():
		c.draw_colored_polygon(fill, Color("0c0814"))
		rim = HomeKit.MAGENTA
	else:
		c.draw_colored_polygon(fill, Color("3b2420"))
		rim = Color("f0a060")
	# Stone courses under the surface.
	for layer in [26.0, 60.0, 104.0]:
		var lp := PackedVector2Array()
		for p in pts:
			lp.append(p + Vector2(0, layer * k))
		c.draw_polyline(lp, Color(rim, 0.12), 1.5, true)
	if _voodoo():
		HomeKit.glow_polyline(c, pts, rim, 2.0)
	else:
		c.draw_polyline(pts, rim, 3.0 * maxf(k, 0.6), true)
	for pl in engine.pillars:
		var gy: float = engine.ground_at(pl.x)
		var r := Rect2(o + Vector2(pl.x - pl.w / 2.0, pl.top) * k, Vector2(pl.w, gy - pl.top + 4.0) * k)
		var cap := Rect2(o + Vector2(pl.x - pl.w / 2.0 - 7.0, pl.top - 10.0) * k, Vector2(pl.w + 14.0, 12.0) * k)
		if _voodoo():
			c.draw_rect(r, Color("0c0814"))
			HomeKit.glow_polyline(c, PackedVector2Array([r.position + Vector2(0, r.size.y), r.position, Vector2(r.end.x, r.position.y), r.end]), HomeKit.CYAN, 2.0)
			c.draw_rect(cap, Color(HomeKit.CYAN, 0.35))
		else:
			c.draw_rect(r, Color("c9a77a"))
			c.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.62, 0), Vector2(r.size.x * 0.38, r.size.y)), Color("8e6c4c"))
			for j in 3:
				var fx: float = r.position.x + r.size.x * (0.22 + j * 0.22)
				c.draw_line(Vector2(fx, r.position.y + 4), Vector2(fx, r.end.y), Color("7a5a3e", 0.7), 1.5)
			c.draw_rect(cap, Color("d8b88a"))
			# A broken top.
			c.draw_colored_polygon(PackedVector2Array([cap.position, cap.position + Vector2(cap.size.x * 0.4, -8 * k), cap.position + Vector2(cap.size.x * 0.7, 0)]), Color("d8b88a"))

## A pennant in the middle of the field: it points where the wind blows.
func _draw_flag(c: CanvasItem, o: Vector2, k: float) -> void:
	var x := AaEngine.W / 2.0
	for pl in engine.pillars:
		if absf(pl.x - x) < 60.0:
			x = pl.x - 90.0
	var foot := o + Vector2(x, engine.ground_at(x)) * k
	var top := foot + Vector2(0, -110) * k
	var pole := HomeKit.CYAN if _voodoo() else Color("2a1a14")
	c.draw_line(foot, top, pole, 3.0 * maxf(k, 0.6))
	var wv: float = engine.wind / AaEngine.WIND_MAX
	var dir := 1.0 if wv >= 0.0 else -1.0
	var len := (18.0 + 46.0 * absf(wv)) * k
	var droop := (1.0 - absf(wv)) * 26.0 * k
	var wave := sin(time * (4.0 + 8.0 * absf(wv))) * 4.0 * k
	var col := HomeKit.MAGENTA if _voodoo() else Color("d42a2a")
	c.draw_colored_polygon(PackedVector2Array([top, top + Vector2(dir * len, droop + wave), top + Vector2(0, 22 * k)]), col)

func _draw_aim(c: CanvasItem, o: Vector2, k: float) -> void:
	if not ((phase == "aim" and _my_turn()) or phase == "cpu") or engine.is_over():
		return
	var i: int = engine.turn
	if phase == "aim" and not dragging and held.is_empty() and not eagle:
		# A hint above the one whose turn it is.
		var f: Dictionary = engine.fighters[i]
		var p := o + Vector2(f.x, f.y - 150) * k + Vector2(0, sin(time * 4.0) * 5.0)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -12), p + Vector2(9, -12), p]), GOLD)
		return
	var w: int = engine.fighters[i].weapon
	var col := HomeKit.CYAN if _voodoo() else Color(1, 1, 1)
	if eagle and phase == "aim":
		var pts: PackedVector2Array = engine.path(i, w)
		for j in range(0, pts.size(), 2):
			c.draw_circle(o + pts[j] * k, 3.0 * maxf(k, 0.6), Color(GOLD, 0.85))
	if phase == "cpu":
		return
	# The first stretch of the arc, without the wind.
	var wpn: Dictionary = AaEngine.WEAPONS[w]
	var a := deg_to_rad(engine.angle_of(i))
	var v: Vector2 = Vector2(cos(a), -sin(a)) * engine.power_of(i) * float(wpn.speed)
	var h: Vector2 = engine.hand(i)
	for j in 12:
		var t := 0.03 + j * 0.03
		var p: Vector2 = h + v * t + Vector2(0, 0.5 * float(wpn.g) * t * t)
		c.draw_circle(o + p * k, (4.0 - j * 0.2) * maxf(k, 0.6), Color(col, 0.9 - j * 0.06))
	var font := ThemeDB.fallback_font
	var f: Dictionary = engine.fighters[i]
	var lp := o + Vector2(f.x, f.y - 170) * k
	_outlined(c, font, lp, "%d°  ·  %d%%" % [int(roundf(engine.angle_of(i))) if f.facing > 0 else int(roundf(180.0 - engine.angle_of(i))), int(roundf(engine.power_of(i)))], int(clampf(26 * k, 16, 26)), col)

func _draw_hud(c: CanvasItem, o: Vector2, k: float) -> void:
	var font := ThemeDB.fallback_font
	var sz := field.size
	var fs := int(clampf(24 * k / 0.8, 16, 26))
	for i in engine.fighters.size():
		var f: Dictionary = engine.fighters[i]
		var ch: Dictionary = CHARS[int(f.char)]
		var bw := minf(300.0, sz.x * 0.26)
		var x := 124.0 if i == 0 else sz.x - 124.0 - bw
		var y := 16.0
		var col: Color = ch.c1
		if _voodoo():
			col = col.lightened(0.25)
		var ttl := _who(i) + " · " + str(ch.name)
		c.draw_string_outline(font, Vector2(x, y + fs), ttl, HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT, bw, fs, 5, Color(0, 0, 0, 0.7))
		c.draw_string(font, Vector2(x, y + fs), ttl, HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT, bw, fs, Color.WHITE)
		var br := Rect2(x, y + fs + 8, bw, 14)
		c.draw_rect(br, Color(0, 0, 0, 0.55))
		var frac := clampf(float(f.hp) / AaEngine.MAX_HP, 0.0, 1.0)
		var fill := Rect2(br.position, Vector2(bw * frac, 14)) if i == 0 else Rect2(Vector2(br.end.x - bw * frac, br.position.y), Vector2(bw * frac, 14))
		c.draw_rect(fill, col if f.hp > 30 else Color("ff4040"))
		c.draw_rect(br, Color(1, 1, 1, 0.5), false, 1.5)
		var hpt := str(f.hp)
		c.draw_string(font, Vector2(x, br.end.y + fs), hpt, HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT, bw, fs - 4, Color(1, 1, 1, 0.85))
	# Wind, top middle: an arrow and its strength.
	var mid := sz.x / 2.0
	var wv: float = engine.wind / AaEngine.WIND_MAX
	var wy := 30.0
	var wcol := HomeKit.LIME if _voodoo() else Color.WHITE
	c.draw_string_outline(font, Vector2(mid - 100, wy), tr("Wind"), HORIZONTAL_ALIGNMENT_CENTER, 200, fs - 4, 5, Color(0, 0, 0, 0.7))
	c.draw_string(font, Vector2(mid - 100, wy), tr("Wind"), HORIZONTAL_ALIGNMENT_CENTER, 200, fs - 4, wcol)
	var strength := int(roundf(absf(engine.wind) / 10.0))
	if strength == 0:
		c.draw_string(font, Vector2(mid - 100, wy + 34), tr("calm"), HORIZONTAL_ALIGNMENT_CENTER, 200, fs, wcol)
	else:
		var l := 18.0 + 70.0 * absf(wv)
		var d := signf(wv)
		var ay := wy + 22.0
		c.draw_line(Vector2(mid - d * l, ay), Vector2(mid + d * l, ay), Color(0, 0, 0, 0.6), 8.0)
		c.draw_line(Vector2(mid - d * l, ay), Vector2(mid + d * l, ay), wcol, 4.0)
		var tip := Vector2(mid + d * l, ay)
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(d * 8, 0), tip + Vector2(-d * 8, -9), tip + Vector2(-d * 8, 9)]), wcol)
		c.draw_string_outline(font, Vector2(mid - 100, ay + 34), str(strength), HORIZONTAL_ALIGNMENT_CENTER, 200, fs, 5, Color(0, 0, 0, 0.7))
		c.draw_string(font, Vector2(mid - 100, ay + 34), str(strength), HORIZONTAL_ALIGNMENT_CENTER, 200, fs, wcol)
	# Weapon in hand, by the weapon buttons.
	if not engine.fighters.is_empty() and not engine.is_over():
		var f: Dictionary = engine.fighters[engine.turn]
		var nm := tr(str(AaEngine.WEAPONS[int(f.weapon)].name))
		c.draw_string_outline(font, Vector2(48, sz.y - 88), nm, HORIZONTAL_ALIGNMENT_LEFT, 320, fs - 2, 5, Color(0, 0, 0, 0.7))
		c.draw_string(font, Vector2(48, sz.y - 88), nm, HORIZONTAL_ALIGNMENT_LEFT, 320, fs - 2, GOLD)
	if _is_online() and not engine.is_over():
		var st: String = online.status_text(engine.turn == my_seat, _name(engine.turn))
		_outlined(c, font, Vector2(mid, sz.y - 30), st, fs - 2, Color.WHITE)
	if banner_t > 0.0 and banner != "":
		var a := clampf(banner_t * 2.0, 0.0, 1.0)
		var lines := banner.split("\n")
		for j in lines.size():
			_outlined(c, font, Vector2(mid, sz.y * 0.36 + j * 52), lines[j], 44 if j == 0 else 30, Color(GOLD, a))

# ---------- the assassins ----------

func _pal(ch: int) -> Dictionary:
	var d: Dictionary = CHARS[ch]
	if _voodoo():
		return {"skin": Color("1d1428"), "c1": (d.c1 as Color).lightened(0.15), "c2": (d.c2 as Color).lightened(0.3),
			"hair": Color("2c2040"), "dark": (d.c1 as Color).lightened(0.4), "lips": HomeKit.MAGENTA, "glow": true, "cape": d.cape, "style": d.hair}
	return {"skin": d.skin, "c1": d.c1, "c2": d.c2, "hair": d.hair_col, "dark": Color("1a0f0c"), "lips": Color("b02a3a"),
		"glow": false, "cape": d.cape, "style": d.hair}

func _limb(c: CanvasItem, a: Vector2, b: Vector2, wa: float, wb: float, col: Color) -> void:
	var n := (b - a).orthogonal().normalized()
	c.draw_colored_polygon(PackedVector2Array([a + n * wa / 2.0, b + n * wb / 2.0, b - n * wb / 2.0, a - n * wa / 2.0]), col)
	c.draw_circle(b, wb / 2.0, col)
	c.draw_circle(a, wa / 2.0, col)

## One assassin, feet at `feet`, `k` world-to-screen scale, facing 1 (right) or -1.
## st: aiming, hold (weapon in hand), pull 0..1, throw_t (s since the throw),
## angle (deg, world), weapon, hurt 0..1, down 0..1, wind -1..1.
## Drawn in local units (about 120 tall, facing right, y up = negative).
func _draw_assassin(c: CanvasItem, feet: Vector2, k: float, ch: int, facing: int, st: Dictionary) -> void:
	var pal := _pal(ch)
	var dn: float = st.get("down", 0.0)
	var rot := -facing * (float(st.get("hurt", 0.0)) * 0.2 + dn * 1.5)
	c.draw_set_transform(feet + Vector2(-facing * dn * 10.0 * k, 0), rot, Vector2(k * facing, k))
	var sk: Color = pal.skin
	var c1: Color = pal.c1
	var c2: Color = pal.c2
	var t := time + ch * 1.7
	var wl: float = float(st.get("wind", 0.0)) * facing   # wind along "forward"
	var breathe := sin(t * 2.2) * 0.8
	# Cape, behind everything.
	if pal.cape:
		var fl := sin(t * 5.0) * 3.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(-9, -92), Vector2(-2, -92), Vector2(-12 + wl * 12, -40 + fl),
			Vector2(-30 + wl * 26, -46 + fl * 1.6)]), c1.darkened(0.25))
	_hair_back(c, pal, t, wl)
	# Aim, in local terms.
	var aiming: bool = st.get("aiming", false)
	var ang := deg_to_rad(float(st.get("angle", 45.0)))
	var d := Vector2(cos(ang) * facing, -sin(ang)).normalized()
	var p: float = st.get("pull", 0.0)
	var tt: float = st.get("throw_t", 9.0)
	var bsh := Vector2(-3, -90 + breathe)
	var fsh := Vector2(3, -90 + breathe)
	var bhand: Vector2
	var fhand: Vector2
	if aiming:
		var back := bsh - d * (10.0 + 14.0 * p) + Vector2(0, -10)
		if tt < 0.35:
			bhand = back.lerp(bsh + d * 26.0, clampf(tt / 0.15, 0.0, 1.0))
		else:
			bhand = back
		fhand = fsh + d * 26.0
	else:
		bhand = Vector2(-12, -64)
		fhand = Vector2(10, -66)
	# Back leg and back (throwing) arm.
	var shade := sk.darkened(0.15)
	_limb(c, Vector2(-5, -54), Vector2(-10, -28), 11, 8, shade)
	_limb(c, Vector2(-10, -28), Vector2(-15, -3), 8, 5, shade)
	c.draw_line(Vector2(-20, -1), Vector2(-9, -1), pal.dark, 3.0)
	var belbow := (bsh + bhand) / 2.0 + Vector2(-3, 5)
	_limb(c, bsh, belbow, 6.5, 5.5, shade)
	_limb(c, belbow, bhand, 5.5, 4.0, shade)
	c.draw_line(belbow.lerp(bhand, 0.35), belbow.lerp(bhand, 0.7), c2, 4.5)
	if st.get("hold", false) or not aiming:
		var wd := d if aiming else Vector2(0, -1)
		_draw_weapon(c, bhand + wd * (30.0 if int(st.weapon) == 0 else 6.0), wd.angle(), int(st.weapon), 1.0, false, true)
	# Front leg.
	_limb(c, Vector2(5, -54), Vector2(12, -28), 11, 8, sk)
	_limb(c, Vector2(12, -28), Vector2(16, -3), 8, 5, sk)
	c.draw_line(Vector2(10, -1), Vector2(22, -1), pal.dark, 3.0)
	c.draw_line(Vector2(13, -10), Vector2(18, -14), c2, 1.6)
	c.draw_line(Vector2(13, -17), Vector2(18, -21), c2, 1.6)
	# Torso: bare waist, wrap top, short pleated skirt, belt.
	var torso := PackedVector2Array([Vector2(-10, -60), Vector2(10, -60), Vector2(8, -73), Vector2(11, -85 + breathe),
		Vector2(12, -93 + breathe), Vector2(-12, -93 + breathe), Vector2(-11, -85 + breathe), Vector2(-8, -73)])
	c.draw_colored_polygon(torso, sk)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-13, -63), Vector2(13, -63), Vector2(19, -40), Vector2(-19, -40)]), c1)
	for x in [-9.0, -3.0, 3.0, 9.0]:
		c.draw_line(Vector2(x * 0.95, -62), Vector2(x * 1.35, -40), c1.darkened(0.35), 1.2)
	c.draw_rect(Rect2(-12, -66, 24, 4), c2)
	var top := PackedVector2Array([Vector2(-11, -79 + breathe), Vector2(8, -79 + breathe), Vector2(13, -84 + breathe),
		Vector2(12, -91 + breathe), Vector2(-12, -91 + breathe)])
	c.draw_colored_polygon(top, c1)
	c.draw_line(Vector2(-11, -81 + breathe), Vector2(12, -81 + breathe), c2, 1.5)
	c.draw_line(Vector2(-6, -90 + breathe), Vector2(-2, -96), c1, 2.0)
	# Neck and head.
	c.draw_rect(Rect2(-3, -101, 6, 10), sk)
	var hc := Vector2(1, -108)
	c.draw_circle(hc, 9.0, sk)
	c.draw_colored_polygon(PackedVector2Array([Vector2(8, -112), Vector2(11.5, -107), Vector2(8, -105.5)]), sk)
	c.draw_line(Vector2(4, -110), Vector2(8, -110.5), pal.dark, 1.5)
	c.draw_line(Vector2(8, -110.5), Vector2(10.5, -112), pal.dark, 1.0)
	c.draw_circle(Vector2(8.3, -103.6), 1.3, pal.lips)
	_hair_front(c, pal, hc)
	# Front arm, reaching along the aim.
	var felbow := (fsh + fhand) / 2.0 + (Vector2(0, 4) if aiming else Vector2(4, 0))
	_limb(c, fsh, felbow, 6.5, 5.5, sk)
	_limb(c, felbow, fhand, 5.5, 4.0, sk)
	c.draw_line(felbow.lerp(fhand, 0.35), felbow.lerp(fhand, 0.7), c2, 4.5)
	if pal.glow:
		HomeKit.glow_polyline(c, torso, c1, 1.5, true)
		HomeKit.glow_circle(c, hc, 9.5, c1, 1.5)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _hair_back(c: CanvasItem, pal: Dictionary, t: float, wl: float) -> void:
	var hr: Color = pal.hair
	match int(pal.style):
		0:  # bob
			c.draw_colored_polygon(PackedVector2Array([Vector2(-10, -116), Vector2(-12, -99), Vector2(-3, -98), Vector2(2, -106)]), hr)
		1:  # ponytail, flying in the wind
			var pts := PackedVector2Array()
			for i in 7:
				var f := i / 6.0
				pts.append(Vector2(-7 - 24 * f + wl * 10 * f, -114 + 18 * f * (1.0 - absf(wl) * 0.6) + sin(t * 6.0 - i) * 2.0 * f))
			c.draw_polyline(pts, hr, 7.0)
			c.draw_polyline(pts.slice(3), hr, 4.0)
		2:  # long braid
			for i in 8:
				var f := i / 7.0
				c.draw_circle(Vector2(-8 - 4 * f + wl * 8 * f + sin(t * 3.0 - i * 0.5) * f, -110 + 34 * f), 3.6 - f, hr)
		3:  # veil
			var fl := sin(t * 4.0) * 3.0
			c.draw_colored_polygon(PackedVector2Array([Vector2(-4, -118), Vector2(-9, -100), Vector2(-24 + wl * 16, -82 + fl),
				Vector2(-38 + wl * 26, -96 + fl * 1.4)]), Color(pal.c1, 0.85))
			c.draw_colored_polygon(PackedVector2Array([Vector2(-10, -114), Vector2(-12, -96), Vector2(-4, -98)]), hr)
		4:  # bun
			c.draw_circle(Vector2(-8, -117), 5.5, hr)
			c.draw_line(Vector2(-14, -121), Vector2(-2, -113), pal.c2, 1.5)

func _hair_front(c: CanvasItem, pal: Dictionary, hc: Vector2) -> void:
	var hr: Color = pal.hair
	var cap := PackedVector2Array()
	for i in 9:
		var a := PI * (0.92 + i * 1.12 / 8.0)
		cap.append(hc + Vector2(cos(a), sin(a)) * 10.5)
	cap.append(hc + Vector2(6, -3))
	cap.append(hc + Vector2(-2, -4))
	cap.append(hc + Vector2(-9, 4))
	c.draw_colored_polygon(cap, hr)
	match int(pal.style):
		0:
			c.draw_line(hc + Vector2(-9, -4), hc + Vector2(9, -5), pal.c2, 2.0)
			c.draw_circle(hc + Vector2(8, -5), 1.8, Color("e8b33a"))
		5:
			c.draw_arc(hc, 10.5, PI * 1.05, PI * 1.95, 8, Color("e8b33a"), 2.0)
			c.draw_circle(hc + Vector2(4, -9.5), 1.8, pal.c2)

## A weapon with its tip (javelin), head (axe) or middle (chakram) at p,
## pointing along `ang` (radians, screen). k = scale; `stuck` buries the tip.
func _draw_weapon(c: CanvasItem, p: Vector2, ang: float, w: int, k: float, stuck: bool, local: bool = false) -> void:
	var dir := Vector2.RIGHT.rotated(ang)
	var s := k
	var steel := HomeKit.CYAN if (_voodoo() and not local) else STEEL
	match w:
		0:
			var tip := p + dir * (8.0 * s if stuck else 0.0)
			var tail := tip - dir * 54.0 * s
			c.draw_line(tail, tip - dir * 8.0 * s, WOOD if not _voodoo() else Color("c08a50"), 2.4 * maxf(s, 0.5))
			var n := dir.orthogonal()
			c.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 10.0 * s + n * 3.0 * s, tip - dir * 10.0 * s - n * 3.0 * s]), BRONZE if not _voodoo() else steel)
			c.draw_line(tail + dir * 14.0 * s, tail + dir * 20.0 * s, Color("d04030"), 3.0 * maxf(s, 0.5))
		1:
			var hd := p
			var hand := hd - dir * 22.0 * s
			c.draw_line(hand, hd, WOOD, 3.0 * maxf(s, 0.5))
			var n := dir.orthogonal()
			c.draw_colored_polygon(PackedVector2Array([hd - dir * 2.0 * s, hd + n * 9.0 * s + dir * 3.0 * s, hd + n * 7.0 * s - dir * 6.0 * s,
				hd + dir * 2.0 * s]), steel)
		_:
			c.draw_arc(p, 7.5 * s, 0.0, TAU, 18, steel, 2.6 * maxf(s, 0.5))
			c.draw_arc(p, 5.0 * s, 0.0, TAU, 14, GOLD, 1.2 * maxf(s, 0.5))
			for j in 4:
				var a := ang + j * PI / 2.0
				c.draw_line(p + Vector2.RIGHT.rotated(a) * 7.0 * s, p + Vector2.RIGHT.rotated(a + 0.4) * 10.0 * s, steel, 1.5)

func _draw_home_logo(c: Control) -> void:
	var sz := c.size
	var k := sz.y / 135.0
	# Sunset disc behind her.
	var sun := Vector2(sz.x * 0.58, sz.y * 0.42)
	for ring in 3:
		c.draw_circle(sun, sz.y * (0.36 + ring * 0.07), Color(1.0, 0.6, 0.3, 0.07))
	c.draw_circle(sun, sz.y * 0.34, Color(1.0, 0.72, 0.35, 0.85) if not _voodoo() else Color(HomeKit.MAGENTA, 0.25))
	_draw_assassin(c, Vector2(sz.x * 0.52, sz.y * 0.99), k, my_char, 1,
		{"aiming": true, "hold": true, "pull": 1.0, "throw_t": 9.0, "angle": 38.0, "weapon": 0, "wind": -0.4})
