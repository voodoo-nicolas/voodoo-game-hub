extends Control

## Ship, Captain, Crew -- five dice, three rolls. Find a 6 (ship), a 5
## (captain) and a 4 (crew) in that order; the two dice left are your cargo.
## Tap a cargo die to keep it and roll again for a better haul. Against the
## computer at three levels, or 2-4 players passing the phone.

const SCCEngine = preload("res://scripts/games/ship_captain_crew/ship_captain_crew_engine.gd")
const HELP = preload("res://scripts/games/ship_captain_crew/ship_captain_crew_help.gd")
const HomeKit = preload("res://scripts/games/ship_captain_crew/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://ship_captain_crew_save.json"
const PIPS := {1: [[1, 1]], 2: [[0, 0], [2, 2]], 3: [[0, 0], [1, 1], [2, 2]], 4: [[0, 0], [2, 0], [0, 2], [2, 2]],
	5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]], 6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]]}

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Landing + pause menu
var engine: SCCEngine
var bg: ColorRect
var skin: String = "classic"
var round_label: Label
var score_row: HBoxContainer
var table: Control
var message_label: Label
var roll_btn: Button
var done_btn: Button
var end_dialog: ColorRect
var anim_timer: Timer
var cpu_timer: Timer
var playing: bool = false
var busy: bool = false
var anim_ticks: int = 0
var anim_faces: Array = []
var vs_cpu: bool = true

func _ready() -> void:
	preload("res://scripts/games/ship_captain_crew/ship_captain_crew_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = SCCEngine.new()
	engine.new_game(2, [false, true], 1)
	_build_ui()
	_calm_music()

## Calm background music from the hub's Music library (apps before v0.33 play none).
func _calm_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, 1, 2.0)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
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
	pause_btn.pressed.connect(_on_pause_home)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("⛵ Ship, Captain, Crew")
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	round_label = Label.new()
	round_label.add_theme_font_size_override("font_size", 26)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(round_label)

	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left", 12)
	sm.add_theme_constant_override("margin_right", 12)
	root.add_child(sm)
	score_row = HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 8)
	sm.add_child(score_row)

	table = Control.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.draw.connect(_draw_table)
	table.gui_input.connect(_on_table_input)
	root.add_child(table)

	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 26)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(0, 70)
	root.add_child(message_label)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 36)
	bm.add_theme_constant_override("margin_left", 16)
	bm.add_theme_constant_override("margin_right", 16)
	root.add_child(bm)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bm.add_child(row)
	roll_btn = Button.new()
	roll_btn.custom_minimum_size = Vector2(0, 96)
	roll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_btn.add_theme_font_size_override("font_size", 30)
	roll_btn.set_meta("sfx", "")
	roll_btn.pressed.connect(_on_roll)
	row.add_child(roll_btn)
	done_btn = Button.new()
	done_btn.text = tr("✔ Done")
	done_btn.custom_minimum_size = Vector2(0, 96)
	done_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done_btn.add_theme_font_size_override("font_size", 30)
	done_btn.pressed.connect(_on_done)
	row.add_child(done_btn)

	anim_timer = Timer.new()
	anim_timer.wait_time = 0.07
	anim_timer.timeout.connect(_on_anim_tick)
	add_child(anim_timer)
	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.timeout.connect(_cpu_step)
	add_child(cpu_timer)

	end_dialog = UI.build_dialog(tr("Game over"), [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in 3:
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard"][i], "sub": "vs Computer", "row": "lvl", "action": _new_vs_cpu.bind(i)})
	for n in [2, 3, 4]:
		modes.append({"text": "👥 %d Players" % n, "sub": "One phone", "multi": true, "row": "players", "action": _new_local.bind(n)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Find a 6, a 5 and a 4, then fill the hold with cargo.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Wins",
		"board_note": "Games won against the computer.",
	})
	add_child(home)
	if info:
		add_child(info)

# ---------- looks ----------

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if playing:
		_render()

func _is_classic() -> bool:
	return skin == "classic"

func _name_of(i: int) -> String:
	if vs_cpu:
		return tr("You") if i == 0 else tr("Computer")
	return tr("Player %d") % (i + 1)

func _player_color(i: int) -> Color:
	if _is_classic():
		return [HomeKit.CLASSIC.red, HomeKit.CLASSIC.blue, HomeKit.CLASSIC.yellow, Color("3fa34d")][i]
	return [HomeKit.PINK, HomeKit.CYAN, HomeKit.GOLD, HomeKit.LIME][i]

func _human_turn() -> bool:
	return not bool(engine.is_cpu[engine.turn])

func _role_color(role: String) -> Color:
	match role:
		"ship":
			return Color("3b82f6") if _is_classic() else HomeKit.CYAN
		"captain":
			return Color("e0a21b") if _is_classic() else HomeKit.GOLD
		_:
			return Color("2f9e55") if _is_classic() else HomeKit.LIME

# ---------- rendering ----------

func _render() -> void:
	round_label.text = tr("Round %d of %d") % [mini(engine.round_no, SCCEngine.ROUNDS), SCCEngine.ROUNDS]
	for c in score_row.get_children():
		score_row.remove_child(c)
		c.queue_free()
	for i in engine.players:
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		var col := _player_color(i)
		var active: bool = i == engine.turn and not engine.over
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(4 if active else 2)
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		if _is_classic():
			sb.bg_color = Color("f4efe4") if active else Color("cfc9b8")
			sb.border_color = col
		else:
			sb.bg_color = Color(col, 0.25 if active else 0.1)
			sb.border_color = col if active else Color(col, 0.5)
		p.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = "%s\n%d" % [_name_of(i), engine.scores[i]]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", HomeKit.CLASSIC.ink if _is_classic() else Color.WHITE)
		p.add_child(l)
		score_row.add_child(p)
	var mine := _human_turn() and not busy and not engine.over and playing
	roll_btn.disabled = not (mine and engine.rolls_left > 0)
	roll_btn.text = tr("🎲 Roll (%d left)") % engine.rolls_left
	done_btn.disabled = not (mine and engine.can_stop())
	table.queue_redraw()

func _die_size() -> float:
	return minf(104.0, (table.size.x - 40.0) / float(SCCEngine.DICE) - 12.0)

func _die_rect(i: int, s: float) -> Rect2:
	var total: float = SCCEngine.DICE * s + (SCCEngine.DICE - 1) * 12.0
	return Rect2(Vector2((table.size.x - total) / 2.0 + i * (s + 12.0), table.size.y * 0.42 - s * 0.5), Vector2(s, s))

func _draw_die(r: Rect2, v: int, role: String, held: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(r.size.x * 0.18))
	var pip: Color
	var accent := _role_color(role) if role != "" else (HomeKit.GOLD if held else HomeKit.CYAN)
	if _is_classic():
		sb.bg_color = Color("f4efe4")
		sb.border_color = accent if (role != "" or held) else Color("b9b3a3")
		sb.set_border_width_all(6 if (role != "" or held) else 3)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 5
		sb.shadow_offset = Vector2(2, 3)
		pip = HomeKit.CLASSIC.ink
	else:
		sb.bg_color = Color(accent, 0.22 if (role != "" or held) else 0.1)
		sb.border_color = accent
		sb.set_border_width_all(5 if (role != "" or held) else 3)
		sb.shadow_color = Color(accent, 0.4)
		sb.shadow_size = 8
		pip = Color.WHITE
	table.draw_style_box(sb, r)
	if v <= 0:
		return
	for sp in PIPS[clampi(v, 1, 6)]:
		table.draw_circle(r.position + Vector2(0.22 + sp[0] * 0.28, 0.22 + sp[1] * 0.28) * r.size.x, r.size.x * 0.085, pip)

func _draw_table() -> void:
	if engine == null or engine.dice.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var s := _die_size()
	for i in SCCEngine.DICE:
		var r := _die_rect(i, s)
		var v: int = int(engine.dice[i])
		if busy and not engine.locked[i] and not engine.hold[i]:
			v = int(anim_faces[i]) if i < anim_faces.size() else v
		_draw_die(r, v, str(engine.role[i]), bool(engine.hold[i]))
		var label := ""
		match str(engine.role[i]):
			"ship":
				label = tr("Ship")
			"captain":
				label = tr("Captain")
			"crew":
				label = tr("Crew ").strip_edges()
			_:
				if engine.has_crew() and v > 0:
					label = tr("Kept") if engine.hold[i] else tr("Cargo")
		if label != "":
			table.draw_string(font, Vector2(r.position.x - 10, r.end.y + 30), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 20, 20, Color(1, 1, 1, 0.8))
	if engine.has_crew():
		table.draw_string(font, Vector2(0, table.size.y * 0.42 + s * 0.5 + 100), tr("Cargo: %d") % engine.cargo(), HORIZONTAL_ALIGNMENT_CENTER, table.size.x, 44, Color.WHITE)

func _on_table_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if busy or not playing or engine.over or not _human_turn():
		return
	var s := _die_size()
	for i in SCCEngine.DICE:
		if _die_rect(i, s).grow(6.0).has_point(event.position):
			if engine.toggle_hold(i):
				_sfx("tick")
				_render()
			return

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y * 0.4, 46.0)
	var mid := c.size / 2.0
	var vals := [6, 5, 4]
	var cols := [HomeKit.CYAN, HomeKit.GOLD, HomeKit.LIME]
	for i in 3:
		var r := Rect2(mid + Vector2((i - 1.5) * k * 1.3, -k * 0.5), Vector2(k, k))
		HomeKit.glow_rect(c, r, cols[i], 3.0, 0.15)
		for sp in PIPS[vals[i]]:
			HomeKit.glow_circle(c, r.position + Vector2(0.22 + sp[0] * 0.28, 0.22 + sp[1] * 0.28) * k, k * 0.085, Color.WHITE, 2.0, 1.0)

# ---------- play ----------

func _on_roll() -> void:
	if busy or engine.over or not playing or not _human_turn() or engine.rolls_left <= 0:
		return
	_start_roll()

func _start_roll() -> void:
	busy = true
	anim_ticks = 9
	_sfx("dice_roll")
	_render()
	anim_timer.start()

func _on_anim_tick() -> void:
	anim_ticks -= 1
	anim_faces = []
	for i in SCCEngine.DICE:
		anim_faces.append(randi_range(1, 6))
	if anim_ticks > 0:
		table.queue_redraw()
		return
	anim_timer.stop()
	busy = false
	var had_crew := engine.has_crew()
	engine.roll()
	_sfx("dice_land")
	if engine.has_crew() and not had_crew:
		_sfx("powerup")
		message_label.text = tr("The crew is aboard! Cargo: %d.") % engine.cargo()
		if info and _human_turn():
			info.add("Crews found")
	elif engine.has_crew():
		message_label.text = tr("Cargo: %d.") % engine.cargo()
	elif engine.has("captain"):
		message_label.text = tr("You have the ship and the captain. Now find a 4 for the crew.")
	elif engine.has("ship"):
		message_label.text = tr("You have the ship. Now find a 5 for the captain.")
	else:
		message_label.text = tr("Find a 6 for the ship first.")
	_render()
	_after_step()

func _after_step() -> void:
	_save_game()
	if engine.turn_done():
		# Out of rolls: the turn banks by itself after a moment.
		cpu_timer.start(1.4)
		return
	if bool(engine.is_cpu[engine.turn]):
		cpu_timer.start(1.0)

func _on_done() -> void:
	if busy or not playing or engine.over or not _human_turn() or not engine.can_stop():
		return
	_finish_turn()

func _finish_turn() -> void:
	var who := engine.turn
	var cpu: bool = bool(engine.is_cpu[who])
	var pts := engine.end_turn()
	if info and not cpu:
		info.high("Best turn", pts)
	if pts > 0:
		_sfx("pickup")
		message_label.text = tr("%s banks %d.") % [_name_of(who), pts]
	else:
		_sfx("buzzer")
		message_label.text = tr("%s found no crew — 0 points.") % _name_of(who)
	_save_game()
	if engine.over:
		_game_over()
		return
	_render()
	if bool(engine.is_cpu[engine.turn]):
		cpu_timer.start(1.4)

func _cpu_step() -> void:
	if not playing or engine.over or busy:
		return
	if engine.turn_done():
		_finish_turn()
		return
	if not bool(engine.is_cpu[engine.turn]):
		return
	var act := engine.cpu_decide()
	if act == "roll" and engine.rolls_left > 0:
		_render()
		_start_roll()
	else:
		_finish_turn()

func _game_over() -> void:
	playing = false
	SaveUtil.delete(SAVE_PATH)
	var w := engine.winner()
	var msg := (tr("It's a tie!") if w < 0 else tr("%s wins!") % _name_of(w)) + "\n"
	for i in engine.players:
		msg += "\n%s: %d" % [_name_of(i), engine.scores[i]]
	if vs_cpu:
		if info:
			if w == 0:
				info.result("win")
			elif w == 1:
				info.result("loss")
			else:
				info.result("draw")
	elif info:
		info.add("Two-player games")
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	_render()

# ---------- Landing (home_kit.gd) ----------

func _setup(n: int, cpu: Array, lvl: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	vs_cpu = cpu.has(true)
	engine.new_game(n, cpu, lvl)
	_begin()

func _new_vs_cpu(level: int) -> void:
	_setup(2, [false, true], level)

func _new_local(n: int) -> void:
	_setup(n, [], 1)

func _restart() -> void:
	_setup(engine.players, engine.is_cpu.duplicate(), engine.level)

func _begin() -> void:
	playing = true
	busy = false
	anim_timer.stop()
	cpu_timer.stop()
	end_dialog.visible = false
	message_label.text = tr("%s: roll the dice!") % _name_of(engine.turn)
	_render()
	_save_game()
	if bool(engine.is_cpu[engine.turn]):
		cpu_timer.start(0.9)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

# ---------- save / resume ----------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if engine == null or not playing or engine.over:
		return
	SaveUtil.write(SAVE_PATH, engine.to_dict())

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Round %d of %d") % [int(d.get("round", 1)), SCCEngine.ROUNDS]

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not engine.from_dict(d) or engine.over:
		_new_vs_cpu(1)
		return
	vs_cpu = engine.is_cpu.has(true)
	_begin()
	message_label.text = tr("%s: your turn.") % _name_of(engine.turn)
	if engine.turn_done():
		cpu_timer.start(1.0)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
