extends Control

## Word Chain -- say a word that starts with the last letter of the one before.
## Against the computer or with two players on one phone. A word can't be
## used twice, and the clock is running.

const WCEngine = preload("res://scripts/games/word_chain/word_chain_engine.gd")
const HELP = preload("res://scripts/games/word_chain/word_chain_help.gd")
const HomeKit = preload("res://scripts/games/word_chain/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://word_chain_save.json"

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Landing + pause menu
var engine: WCEngine
var bg: ColorRect
var skin: String = "classic"
var status_label: Label
var time_bar: ProgressBar
var time_label: Label
var scroll: ScrollContainer
var chain_box: VBoxContainer
var prompt_label: Label
var typed_label: Label
var feedback_label: Label
var keyboard: VBoxContainer
var end_dialog: ColorRect
var feedback_timer: Timer
var cpu_timer: Timer
var keys: Array = []
var typed: String = ""
var time_left: float = 0.0
var playing: bool = false
var thinking: bool = false

func _ready() -> void:
	preload("res://scripts/games/word_chain/word_chain_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = WCEngine.new()
	engine.load_words()
	_build_ui()
	_chill_music()

## Calm background music from the hub's Music library (apps before v0.33 play none).
func _chill_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, 3, 2.0)

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
	pause_btn.pressed.connect(_on_pause_home)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("🔗 Word Chain")
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

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 24)
	tm.add_theme_constant_override("margin_right", 24)
	root.add_child(tm)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 10)
	tm.add_child(trow)
	time_bar = ProgressBar.new()
	time_bar.show_percentage = false
	time_bar.custom_minimum_size = Vector2(0, 18)
	time_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(time_bar)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 24)
	time_label.custom_minimum_size = Vector2(60, 0)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trow.add_child(time_label)

	var sm := MarginContainer.new()
	sm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sm.add_theme_constant_override("margin_left", 24)
	sm.add_theme_constant_override("margin_right", 24)
	root.add_child(sm)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sm.add_child(scroll)
	chain_box = VBoxContainer.new()
	chain_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chain_box.add_theme_constant_override("separation", 6)
	scroll.add_child(chain_box)

	prompt_label = Label.new()
	prompt_label.add_theme_font_size_override("font_size", 26)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt_label)
	typed_label = Label.new()
	typed_label.add_theme_font_size_override("font_size", 54)
	typed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	typed_label.custom_minimum_size = Vector2(0, 64)
	root.add_child(typed_label)
	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 24)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.custom_minimum_size = Vector2(0, 32)
	root.add_child(feedback_label)

	var km := MarginContainer.new()
	km.add_theme_constant_override("margin_left", 8)
	km.add_theme_constant_override("margin_right", 8)
	root.add_child(km)
	keyboard = VBoxContainer.new()
	keyboard.add_theme_constant_override("separation", 6)
	km.add_child(keyboard)
	_build_keyboard()

	var row_margin := MarginContainer.new()
	row_margin.add_theme_constant_override("margin_bottom", 30)
	root.add_child(row_margin)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	row_margin.add_child(actions)
	actions.add_child(_button(tr("⌫"), _on_back, 100))
	actions.add_child(_button(tr("✔ Enter"), _on_enter, 200))
	actions.add_child(_button(tr("Give up"), _on_give_up, 160))

	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.wait_time = 2.0
	feedback_timer.timeout.connect(_clear_feedback)
	add_child(feedback_timer)
	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.timeout.connect(_on_cpu_timer)
	add_child(cpu_timer)

	end_dialog = UI.build_dialog(tr("Chain broken"), [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in 3:
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard"][i], "sub": ["40 seconds", "30 seconds", "20 seconds"][i],
			"row": "lvl", "action": _new_game.bind("cpu", i)})
	modes.append({"text": "👥 2 Players", "sub": "One phone", "multi": true, "action": _new_game.bind("two", 1)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.LIME,
		"subtitle": "Start your word where the last one ended.",
		"logo": _draw_home_logo,
		"modes": modes,
		"solo_heading": "Against the computer",
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

func _button(text: String, action: Callable, w: float = 150.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 72)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	return b

func _build_keyboard() -> void:
	var kw: float = clampf((get_viewport_rect().size.x - 16.0) / 10.0 - 6.0, 30.0, 64.0)
	for r in ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 5)
		for ch in r:
			var b := Button.new()
			b.text = ch
			b.custom_minimum_size = Vector2(kw, kw * 1.2)
			b.add_theme_font_size_override("font_size", int(kw * 0.5))
			b.focus_mode = Control.FOCUS_NONE
			b.set_meta("sfx", "key")
			b.pressed.connect(_on_key.bind(ch.to_lower()))
			row.add_child(b)
			keys.append(b)
		keyboard.add_child(row)

func _process(delta: float) -> void:
	if not playing or thinking or engine.is_over():
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_sfx("buzzer")
		engine.lose_turn("timeout")
		_end_game()
		return
	_update_time()

# ---------- looks ----------

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if engine and not engine.chain.is_empty():
		_render()

func _is_classic() -> bool:
	return skin == "classic"

func _who_color(who: int) -> Color:
	if _is_classic():
		return HomeKit.CLASSIC.blue.lightened(0.45) if who == 0 else Color("f6c6a0")
	return HomeKit.CYAN if who == 0 else HomeKit.PINK

func _who_name(who: int) -> String:
	if engine.mode == "two":
		return tr("Player %d") % (who + 1)
	return tr("You") if who == 0 else tr("Computer")

func _row_style(who: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var c := _who_color(who)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if _is_classic():
		sb.bg_color = Color("f4efe4")
		sb.border_color = c.darkened(0.3)
	else:
		sb.bg_color = Color(c, 0.14)
		sb.border_color = c
	return sb

func _render() -> void:
	for c in chain_box.get_children():
		chain_box.remove_child(c)
		c.queue_free()
	for e in engine.chain:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _row_style(e.who))
		p.size_flags_horizontal = Control.SIZE_SHRINK_END if e.who == 0 else Control.SIZE_SHRINK_BEGIN
		var l := Label.new()
		l.text = "%s  %s" % [_who_name(e.who), str(e.word).to_upper()]
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", HomeKit.CLASSIC.ink if _is_classic() else Color.WHITE)
		p.add_child(l)
		chain_box.add_child(p)
	scroll.call_deferred("set", "scroll_vertical", 100000)
	if engine.mode == "two":
		status_label.text = tr("%d words in the chain") % engine.chain.size()
	else:
		status_label.text = tr("You %d   Computer %d") % [engine.words_by(0), engine.words_by(1)]
	if thinking:
		prompt_label.text = tr("Computer is thinking…")
	else:
		prompt_label.text = tr("%s: a word starting with %s") % [_who_name(engine.turn), engine.need.to_upper()]
	var shown := ""
	for i in typed.length():
		shown += typed[i].to_upper() + " "
	typed_label.text = shown.strip_edges()
	typed_label.add_theme_color_override("font_color", _who_color(engine.turn))
	_update_time()
	for k in keys:
		k.disabled = thinking or engine.is_over()

func _update_time() -> void:
	var lim: float = float(engine.time_limit())
	time_bar.max_value = lim
	time_bar.value = time_left if not thinking else lim
	time_label.text = "%d" % ceili(time_left if not thinking else lim)

# ---------- play ----------

func _start_turn() -> void:
	typed = engine.need
	time_left = float(engine.time_limit())
	thinking = engine.mode == "cpu" and engine.turn == 1
	_clear_feedback()
	_render()
	if thinking:
		cpu_timer.start(randf_range(0.7, 1.6))

func _on_key(ch: String) -> void:
	if thinking or engine.is_over() or not playing:
		return
	if typed.length() < 12:
		typed += ch
		_render()

func _on_back() -> void:
	if thinking or engine.is_over() or not playing:
		return
	if typed.length() > 1:
		typed = typed.substr(0, typed.length() - 1)
		_sfx("back")
		_render()

func _on_enter() -> void:
	if thinking or engine.is_over() or not playing:
		return
	match engine.check(typed):
		"ok":
			engine.play(typed)
			_sfx("place")
			_save_game()
			_start_turn()
		"short":
			_sfx("invalid")
			_feedback(tr("Use at least 3 letters"), Color(1, 0.7, 0.35))
		"used":
			_sfx("letter_wrong")
			_feedback(tr("%s was already used") % typed.to_upper(), Color(1, 0.7, 0.35))
		"not_word":
			_sfx("letter_wrong")
			_feedback(tr("%s isn't in the word list") % typed.to_upper(), Color(1, 0.45, 0.45))
		_:
			pass

func _on_cpu_timer() -> void:
	if not playing or engine.is_over():
		return
	var w := engine.cpu_pick()
	if w == "":
		engine.lose_turn("stumped")
		_end_game()
		return
	engine.play(w)
	_sfx("slide")
	_save_game()
	_start_turn()

func _on_give_up() -> void:
	if engine.is_over() or not playing or thinking:
		return
	engine.lose_turn("gave_up")
	_end_game()

func _end_game() -> void:
	playing = false
	thinking = false
	cpu_timer.stop()
	SaveUtil.delete(SAVE_PATH)
	var msg := ""
	if engine.mode == "two":
		msg = tr("%s wins!") % _who_name(engine.winner)
		if info:
			info.add("Two-player games")
	else:
		if engine.winner == 0:
			msg = tr("You win! The computer is out of words.")
			if info:
				info.result("win")
		else:
			msg = tr("The computer wins.")
			if info:
				info.result("loss")
		if info:
			info.add("Words played", engine.words_by(0))
	match engine.reason:
		"timeout":
			msg += "\n" + tr("%s ran out of time.") % _who_name(1 - engine.winner)
		"gave_up":
			msg += "\n" + tr("%s gave up.") % _who_name(1 - engine.winner)
	msg += "\n" + tr("Chain length: %d") % engine.chain.size()
	if info:
		info.high("Longest chain", engine.chain.size())
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	_render()

func _feedback(text: String, col: Color) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", col)
	feedback_timer.start()

func _clear_feedback() -> void:
	feedback_label.text = ""

# ---------- Landing (home_kit.gd) ----------

func _new_game(mode: String, level: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.new_game(mode, level)
	_begin_play()

func _restart() -> void:
	_new_game(engine.mode, engine.level)

func _begin_play() -> void:
	playing = true
	end_dialog.visible = false
	_start_turn()

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y * 0.5, 56.0)
	var mid := c.size / 2.0
	var words := ["CAT", "TIGER", "RAT"]
	var lens := [3, 5, 3]
	var x := mid.x - k * 3.1
	for i in 3:
		var w: float = k * 0.62 * lens[i] + k * 0.2
		HomeKit.glow_rect(c, Rect2(Vector2(x, mid.y - k * 0.4), Vector2(w, k * 0.8)), HomeKit.LIME if i != 1 else HomeKit.CYAN, 2.5, 0.12)
		HomeKit.glow_text(c, Vector2(x + w / 2.0, mid.y), words[i], int(k * 0.5), Color.WHITE)
		if i < 2:
			HomeKit.glow_line(c, Vector2(x + w, mid.y), Vector2(x + w + k * 0.35, mid.y), HomeKit.GOLD, 3.0)
		x += w + k * 0.35

# ---------- save / resume ----------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if engine == null or not playing or engine.is_over() or engine.chain.is_empty():
		return
	SaveUtil.write(SAVE_PATH, engine.to_dict())

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("%d words in the chain") % Array(d.get("chain", [])).size()

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not engine.from_dict(d) or engine.is_over():
		_new_game("cpu", 1)
		return
	_begin_play()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
