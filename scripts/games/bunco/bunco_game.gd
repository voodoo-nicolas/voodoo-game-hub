extends Control

## Bunco -- six rounds, one per number. Roll three dice; every die showing the
## round's number scores, three of the number is a BUNCO. Keep rolling while
## you score; first to 21 wins the round. Against the computer or 2-4 players
## passing the phone.

const BuncoEngine = preload("res://scripts/games/bunco/bunco_engine.gd")
const HELP = preload("res://scripts/games/bunco/bunco_help.gd")
const HomeKit = preload("res://scripts/games/bunco/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://bunco_save.json"
const PIPS := {1: [[1, 1]], 2: [[0, 0], [2, 2]], 3: [[0, 0], [1, 1], [2, 2]], 4: [[0, 0], [2, 0], [0, 2], [2, 2]],
	5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]], 6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]]}

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Landing + pause menu
var engine: BuncoEngine
var bg: ColorRect
var skin: String = "classic"
var round_label: Label
var score_row: HBoxContainer
var table: Control
var message_label: Label
var roll_btn: Button
var end_dialog: ColorRect
var anim_timer: Timer
var cpu_timer: Timer
var playing: bool = false
var busy: bool = false
var anim_ticks: int = 0
var anim_faces: Array = [1, 1, 1]
var vs_cpu: bool = true
var shown_round: int = 1   # the round the dice on the table were rolled in

func _ready() -> void:
	preload("res://scripts/games/bunco/bunco_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = BuncoEngine.new()
	engine.new_game(2, [false, true])
	_build_ui()
	_lively_music()

## Lively background music from the hub's Music library (apps before v0.33 play none).
func _lively_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("lively", self, 3, 2.0)

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
	title.text = tr("🎲 Bunco")
	title.add_theme_font_size_override("font_size", 34)
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
	round_label.add_theme_font_size_override("font_size", 30)
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
	roll_btn = Button.new()
	roll_btn.text = tr("🎲 Roll")
	roll_btn.custom_minimum_size = Vector2(0, 96)
	roll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_btn.add_theme_font_size_override("font_size", 34)
	roll_btn.set_meta("sfx", "")
	roll_btn.pressed.connect(_on_roll)
	bm.add_child(roll_btn)

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
	var modes: Array = [{"text": "🤖 vs Computer", "sub": "6 rounds", "action": _new_vs_cpu}]
	for n in [2, 3, 4]:
		modes.append({"text": "👥 %d Players" % n, "sub": "One phone", "multi": true, "row": "players", "action": _new_local.bind(n)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Six rounds, six numbers. Roll a Bunco!",
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

# ---------- rendering ----------

func _render() -> void:
	round_label.text = tr("Round %d of %d — roll %ds") % [engine.round_no, BuncoEngine.ROUNDS, engine.round_no]
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
		l.text = "%s\n%d/%d   ★ %d" % [_name_of(i), engine.round_points[i], BuncoEngine.ROUND_GOAL, engine.wins[i]]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", HomeKit.CLASSIC.ink if _is_classic() else Color.WHITE)
		p.add_child(l)
		score_row.add_child(p)
	roll_btn.disabled = not (_human_turn() and not busy and not engine.over and playing)
	table.queue_redraw()

func _die_size() -> float:
	return minf(130.0, (table.size.x - 80.0) / 3.0 - 20.0)

func _draw_die(r: Rect2, v: int, hit: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(r.size.x * 0.18))
	var pip: Color
	if _is_classic():
		sb.bg_color = Color("ffe28a") if hit else Color("f4efe4")
		sb.border_color = Color("c9961a") if hit else Color("b9b3a3")
		sb.set_border_width_all(5 if hit else 3)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 5
		sb.shadow_offset = Vector2(2, 3)
		pip = HomeKit.CLASSIC.ink
	else:
		var col := HomeKit.GOLD if hit else HomeKit.CYAN
		sb.bg_color = Color(col, 0.2 if hit else 0.1)
		sb.border_color = col
		sb.set_border_width_all(5 if hit else 3)
		sb.shadow_color = Color(col, 0.45)
		sb.shadow_size = 9 if hit else 5
		pip = Color.WHITE
	table.draw_style_box(sb, r)
	for sp in PIPS[clampi(v, 1, 6)]:
		table.draw_circle(r.position + Vector2(0.22 + sp[0] * 0.28, 0.22 + sp[1] * 0.28) * r.size.x, r.size.x * 0.085, pip)

func _draw_table() -> void:
	if engine == null:
		return
	var s := _die_size()
	var total: float = 3.0 * s + 2.0 * 22.0
	var y: float = table.size.y * 0.5 - s * 0.5
	var faces: Array = anim_faces if busy else engine.dice
	for i in 3:
		var hit: bool = not busy and playing and int(faces[i]) == shown_round
		_draw_die(Rect2(Vector2((table.size.x - total) / 2.0 + i * (s + 22.0), y), Vector2(s, s)), int(faces[i]), hit)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y * 0.42, 54.0)
	var mid := c.size / 2.0
	for i in 3:
		var r := Rect2(mid + Vector2((i - 1.5) * k * 1.25, -k * 0.5), Vector2(k, k))
		HomeKit.glow_rect(c, r, HomeKit.GOLD, 3.0, 0.15)
		for sp in PIPS[3]:
			HomeKit.glow_circle(c, r.position + Vector2(0.22 + sp[0] * 0.28, 0.22 + sp[1] * 0.28) * k, k * 0.085, Color.WHITE, 2.0, 1.0)

# ---------- play ----------

func _on_roll() -> void:
	if busy or engine.over or not playing or not _human_turn():
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
	anim_faces = [randi_range(1, 6), randi_range(1, 6), randi_range(1, 6)]
	if anim_ticks > 0:
		table.queue_redraw()
		return
	anim_timer.stop()
	busy = false
	var who := engine.turn
	var rnd := engine.round_no
	var kind := engine.roll()
	shown_round = rnd
	_sfx("dice_land")
	var round_won := engine.round_winner >= 0
	match kind:
		"bunco":
			_sfx("win")
			message_label.text = tr("BUNCO! %s wins round %d!") % [_name_of(who), rnd]
			if info and not engine.is_cpu[who]:
				info.add("Buncos")
		"triple":
			_sfx("powerup")
			message_label.text = tr("Three of a kind! %s scores +%d.") % [_name_of(who), engine.last_points]
		"hits":
			_sfx("pickup")
			message_label.text = tr("%s scores +%d — roll again!") % [_name_of(who), engine.last_points]
		_:
			_sfx("buzzer")
			message_label.text = tr("%s missed — the dice pass.") % _name_of(who)
	if round_won and kind != "bunco":
		message_label.text = tr("%s reaches 21 and wins round %d!") % [_name_of(who), rnd]
	_render()
	_after_step()

func _after_step() -> void:
	_save_game()
	if engine.over:
		_game_over()
		return
	if bool(engine.is_cpu[engine.turn]):
		cpu_timer.start(1.0)

func _cpu_step() -> void:
	if not playing or engine.over or not bool(engine.is_cpu[engine.turn]) or busy:
		return
	_start_roll()

func _game_over() -> void:
	playing = false
	SaveUtil.delete(SAVE_PATH)
	var w := engine.winner()
	var msg := (tr("It's a tie!") if w < 0 else tr("%s wins!") % _name_of(w)) + "\n"
	for i in engine.players:
		msg += "\n" + tr("%s: %d rounds, %d points") % [_name_of(i), engine.wins[i], engine.total_points[i]]
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

func _setup(n: int, cpu: Array) -> void:
	SaveUtil.delete(SAVE_PATH)
	vs_cpu = cpu.has(true)
	engine.new_game(n, cpu)
	_begin()

func _new_vs_cpu() -> void:
	_setup(2, [false, true])

func _new_local(n: int) -> void:
	_setup(n, [])

func _restart() -> void:
	_setup(engine.players, engine.is_cpu.duplicate())

func _begin() -> void:
	playing = true
	busy = false
	anim_timer.stop()
	cpu_timer.stop()
	end_dialog.visible = false
	shown_round = engine.round_no
	message_label.text = tr("%s: roll to start.") % _name_of(engine.turn)
	_render()
	_save_game()
	if bool(engine.is_cpu[engine.turn]):
		cpu_timer.start(0.8)

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
	return "" if d == null else tr("Round %d of %d") % [int(d.get("round", 1)), BuncoEngine.ROUNDS]

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not engine.from_dict(d) or engine.over:
		_new_vs_cpu()
		return
	vs_cpu = engine.is_cpu.has(true)
	_begin()
	message_label.text = tr("%s: your turn.") % _name_of(engine.turn)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
