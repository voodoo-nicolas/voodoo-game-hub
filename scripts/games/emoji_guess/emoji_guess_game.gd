extends Control

## Emoji Guess -- the emoji spell a word or phrase. Type it on the keyboard
## (spaces and accents don't matter). Alone, or 2-4 players taking turns.

const EGEngine = preload("res://scripts/games/emoji_guess/emoji_guess_engine.gd")
const HELP = preload("res://scripts/games/emoji_guess/emoji_guess_help.gd")
const HomeKit = preload("res://scripts/games/emoji_guess/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://emoji_guess_save.json"
const LEVEL_NAMES := ["Easy", "Normal", "Hard"]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Landing + pause menu
var engine: EGEngine
var bg: ColorRect
var skin: String = "classic"
var status_label: Label
var turn_label: Label
var card: PanelContainer
var emoji_label: Label
var hint_label: Label
var slots_label: Label
var feedback_label: Label
var keyboard: VBoxContainer
var end_dialog: ColorRect
var feedback_timer: Timer
var keys: Array = []
var typed: String = ""
var tier_pick: int = 0
var playing: bool = false

func _ready() -> void:
	preload("res://scripts/games/emoji_guess/emoji_guess_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = EGEngine.new()
	engine.load_data()
	_build_ui()
	_lively_music()

## Lively background music from the hub's Music library (apps before v0.33 play none).
func _lively_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("lively", self, 1, 2.0)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)

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
	pause_btn.add_theme_font_size_override("font_size", 30)
	pause_btn.pressed.connect(_on_pause_home)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("🤔 Emoji Guess")
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
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 26)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(turn_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 30)
	cm.add_theme_constant_override("margin_right", 30)
	root.add_child(cm)
	card = PanelContainer.new()
	cm.add_child(card)
	emoji_label = Label.new()
	emoji_label.add_theme_font_size_override("font_size", 96)
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_label.custom_minimum_size = Vector2(0, 150)
	card.add_child(emoji_label)

	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 24)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_label)
	slots_label = Label.new()
	slots_label.add_theme_font_size_override("font_size", 38)
	slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slots_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slots_label.custom_minimum_size = Vector2(0, 100)
	root.add_child(slots_label)
	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 24)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.custom_minimum_size = Vector2(0, 30)
	root.add_child(feedback_label)

	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer2)

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
	actions.add_theme_constant_override("separation", 10)
	row_margin.add_child(actions)
	actions.add_child(_button(tr("⌫"), _on_back, 86))
	actions.add_child(_button(tr("✔ Enter"), _on_enter, 150))
	actions.add_child(_button(tr("💡 Hint"), _on_hint, 130))
	actions.add_child(_button(tr("Skip"), _on_skip, 110))

	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.wait_time = 2.0
	feedback_timer.timeout.connect(_clear_feedback)
	add_child(feedback_timer)

	end_dialog = UI.build_dialog(tr("Round Over"), [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = [{"text": "🧑 Play alone", "sub": "8 puzzles", "action": _new_game.bind(1)}]
	for n in [2, 3, 4]:
		modes.append({"text": "👥 %d Players" % n, "sub": "Take turns", "multi": true, "row": "players", "action": _new_game.bind(n)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Guess the word or phrase hidden in the emoji.",
		"logo": _draw_home_logo,
		"modes": modes,
		"extra": _add_options,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board_note": "Your best score in one solo round.",
	})
	add_child(home)
	if info:
		add_child(info)

func _add_options(box: VBoxContainer) -> void:
	box.add_child(home.section("Difficulty"))
	box.add_child(home.choice_row(LEVEL_NAMES, tier_pick, _set_tier))

func _set_tier(i: int) -> void:
	tier_pick = i

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

# ---------- looks ----------

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	_style_card()
	if playing:
		_render()

func _is_classic() -> bool:
	return skin == "classic"

func _style_card() -> void:
	if card == null:
		return
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(4)
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if _is_classic():
		sb.bg_color = Color("f4efe4")
		sb.border_color = Color("8a8473")
	else:
		sb.bg_color = Color(HomeKit.GOLD, 0.12)
		sb.border_color = HomeKit.GOLD
		sb.shadow_color = Color(HomeKit.GOLD, 0.35)
		sb.shadow_size = 8
	card.add_theme_stylebox_override("panel", sb)

func _ink() -> Color:
	return HomeKit.CLASSIC.ink if _is_classic() else Color.WHITE

# ---------- play ----------

func _slot_text() -> String:
	var shown := ""
	var at := 0
	var words: Array = []
	for n in engine.pattern():
		var w := ""
		for i in n:
			w += (typed[at].to_upper() if at < typed.length() else "_") + " "
			at += 1
		words.append(w.strip_edges())
	shown = "   ".join(words)
	if typed.length() > at:
		shown += " " + typed.substr(at).to_upper()
	return shown

func _render() -> void:
	if engine.is_over() or engine.queue.is_empty():
		return
	_style_card()
	status_label.text = tr("Puzzle %d of %d") % [engine.index + 1, engine.total()]
	if engine.players > 1:
		var parts: Array = []
		for i in engine.players:
			parts.append("%d: %d" % [i + 1, engine.scores[i]])
		turn_label.text = tr("Player %d's turn") % (engine.current + 1) + "    " + "  ".join(parts)
	else:
		turn_label.text = tr("Score: %d") % engine.scores[0]
	emoji_label.text = engine.emoji()
	emoji_label.add_theme_color_override("font_color", _ink())
	hint_label.text = tr("Hint: %s") % str(engine.category())
	slots_label.text = _slot_text()
	slots_label.add_theme_color_override("font_color", HomeKit.GOLD if not _is_classic() else Color.WHITE)

func _on_key(ch: String) -> void:
	if not playing or engine.is_over():
		return
	if typed.length() < 28:
		typed += ch
		_render()
		if engine.check(typed):
			_solved()

func _on_back() -> void:
	if not playing or engine.is_over():
		return
	if typed.length() > engine.prefix().length():
		typed = typed.substr(0, typed.length() - 1)
		_sfx("back")
		_render()

func _on_enter() -> void:
	if not playing or engine.is_over() or typed == "":
		return
	if engine.check(typed):
		_solved()
	else:
		_sfx("letter_wrong")
		_feedback(tr("Not quite — try again"), Color(1, 0.45, 0.45))

func _on_hint() -> void:
	if not playing or engine.is_over():
		return
	typed = engine.hint()
	_sfx("powerup")
	_render()

func _on_skip() -> void:
	if not playing or engine.is_over():
		return
	_feedback(tr("It was: %s") % str(engine.puzzle().a[0]).to_upper(), Color(0.9, 0.8, 0.4))
	engine.skip()
	_after_puzzle()

func _solved() -> void:
	_sfx("letter_right")
	if info:
		info.add("Puzzles solved")
		if engine.hints == 0:
			info.add("Solved without hints")
	var pts := engine.solve_current()
	_feedback("✓ +%d" % pts, Color(0.5, 0.95, 0.5))
	_after_puzzle()

func _after_puzzle() -> void:
	typed = ""
	if engine.is_over():
		_round_over()
	else:
		typed = engine.prefix()
		_render()
		_save_game()

func _round_over() -> void:
	playing = false
	SaveUtil.delete(SAVE_PATH)
	var msg := ""
	if engine.players == 1:
		msg = tr("Score: %d") % engine.scores[0]
		if info:
			info.best("Best score", engine.scores[0])
			info.best("Best score (%s)" % LEVEL_NAMES[engine.tier], engine.scores[0])
	else:
		var w := engine.winner()
		msg = tr("It's a tie!") if w < 0 else tr("Player %d wins!") % (w + 1)
		for i in engine.players:
			msg += "\n" + tr("Player %d: %d") % [i + 1, engine.scores[i]]
	if info:
		info.add("Rounds played")
	_sfx("win")
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

func _feedback(text: String, col: Color) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", col)
	feedback_timer.start()

func _clear_feedback() -> void:
	feedback_label.text = ""

# ---------- Landing (home_kit.gd) ----------

func _new_game(players: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.new_game(tier_pick, players, TranslationServer.get_locale().begins_with("es"))
	_begin_play()

func _restart() -> void:
	tier_pick = engine.tier
	_new_game(engine.players)

func _begin_play() -> void:
	playing = true
	typed = engine.prefix()
	end_dialog.visible = false
	_clear_feedback()
	_render()
	_save_game()

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y * 0.5, 64.0)
	var mid := c.size / 2.0
	HomeKit.glow_rect(c, Rect2(mid - Vector2(k * 1.9, k * 0.7), Vector2(k * 3.8, k * 1.4)), HomeKit.GOLD, 3.0, 0.1)
	HomeKit.glow_text(c, mid + Vector2(-k * 0.9, 0), "🍎", int(k * 0.9), Color.WHITE)
	HomeKit.glow_text(c, mid + Vector2(0, 0), "+", int(k * 0.7), HomeKit.GOLD)
	HomeKit.glow_text(c, mid + Vector2(k * 0.9, 0), "🥧", int(k * 0.9), Color.WHITE)

# ---------- save / resume ----------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if engine == null or not playing or engine.is_over() or engine.queue.is_empty():
		return
	var d := engine.to_dict()
	d["typed"] = typed
	SaveUtil.write(SAVE_PATH, d)

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Puzzle %d of %d") % [int(d.get("index", 0)) + 1, Array(d.get("queue", [])).size()]

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not engine.from_dict(d) or engine.is_over():
		_new_game(1)
		return
	_begin_play()
	typed = str(d.get("typed", engine.prefix()))
	_render()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
