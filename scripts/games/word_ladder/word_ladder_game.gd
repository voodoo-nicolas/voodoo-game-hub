extends Control

## Word Ladder -- change one letter at a time to get from the start word to
## the goal word. Tap a tile of the word on the bottom rung, pick the new
## letter, and the new word (it must be a real one) becomes the next rung.

const WLEngine = preload("res://scripts/games/word_ladder/word_ladder_engine.gd")
const HELP = preload("res://scripts/games/word_ladder/word_ladder_help.gd")
const HomeKit = preload("res://scripts/games/word_ladder/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://word_ladder_save.json"
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const GREEN := Color("4fa84a")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Landing + pause menu
var engine: WLEngine
var bg: ColorRect
var skin: String = "classic"
var info_label: Label
var feedback_label: Label
var scroll: ScrollContainer
var ladder_box: VBoxContainer
var picker: PanelContainer
var picker_grid: GridContainer
var action_row: HBoxContainer
var ladder_dialog: ColorRect
var end_dialog: ColorRect
var sel: int = -1             # tile of the bottom word being changed
var feedback_timer: Timer
var round_started: bool = false

func _ready() -> void:
	preload("res://scripts/games/word_ladder/word_ladder_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = WLEngine.new()
	engine.load_words()
	_build_ui()
	_chill_music()

## Calm background music from the hub's Music library (apps before v0.33 play none).
func _chill_music() -> void:
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
	title.text = tr("🪜 Word Ladder")
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

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	ladder_box = VBoxContainer.new()
	ladder_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ladder_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ladder_box.add_theme_constant_override("separation", 6)
	scroll.add_child(ladder_box)

	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 24)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size = Vector2(0, 34)
	root.add_child(feedback_label)

	picker = PanelContainer.new()
	picker.visible = false
	var pm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pm.add_theme_constant_override("margin_" + side, 8)
	picker.add_child(pm)
	picker_grid = GridContainer.new()
	picker_grid.columns = 9
	picker_grid.add_theme_constant_override("h_separation", 6)
	picker_grid.add_theme_constant_override("v_separation", 6)
	pm.add_child(picker_grid)
	var picker_margin := MarginContainer.new()
	picker_margin.add_theme_constant_override("margin_left", 16)
	picker_margin.add_theme_constant_override("margin_right", 16)
	picker_margin.add_child(picker)
	root.add_child(picker_margin)

	var row_margin := MarginContainer.new()
	row_margin.add_theme_constant_override("margin_bottom", 36)
	root.add_child(row_margin)
	action_row = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	row_margin.add_child(action_row)
	action_row.add_child(_button(tr("↩ Undo"), _on_undo))
	action_row.add_child(_button(tr("💡 Hint"), _on_hint))
	action_row.add_child(_button(tr("Skip"), _on_skip))

	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.wait_time = 1.8
	feedback_timer.timeout.connect(_clear_feedback)
	add_child(feedback_timer)

	ladder_dialog = UI.build_dialog(tr("Ladder solved!"), [
		{"text": tr("Continue"), "action": _next_ladder},
	], true)
	add_child(ladder_dialog)
	end_dialog = UI.build_dialog(tr("Round Over"), [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in 3:
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard"][i], "sub": ["3 letters", "4 letters", "5 letters"][i],
			"row": "lvl", "action": _new_game.bind(i)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Change one letter at a time. Every step a real word.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board_note": "Your best round: up to 100 points a ladder, less for extra steps and hints.",
	})
	add_child(home)
	if info:
		add_child(info)

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 72)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	return b

# ---------- looks ----------

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if ladder_box and engine and not engine.puzzles.is_empty():
		_render()

func _is_classic() -> bool:
	return skin == "classic"

## kind: "start", "step", "current", "goal"; changed = this letter differs from the rung above.
func _tile_style(kind: String, changed: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	if _is_classic():
		var fill := Color("f4efe4")
		match kind:
			"start":
				fill = Color("cfe0ff")
			"goal":
				fill = Color("a9dba3")
			"current":
				fill = Color("fff3c4")
		if changed:
			fill = HomeKit.CLASSIC.yellow
		sb.bg_color = fill
		sb.border_color = Color("8a8473")
		sb.set_border_width_all(3)
		sb.shadow_color = Color(0, 0, 0, 0.3)
		sb.shadow_size = 3
		sb.shadow_offset = Vector2(1, 2)
	else:
		var c := HomeKit.CYAN
		match kind:
			"start":
				c = HomeKit.GOLD
			"goal":
				c = HomeKit.LIME
			"current":
				c = HomeKit.PINK
		if changed:
			c = HomeKit.GOLD
		sb.bg_color = Color(c, 0.16)
		sb.border_color = c
		sb.set_border_width_all(3)
		sb.shadow_color = Color(c, 0.35)
		sb.shadow_size = 6
	return sb

func _ink() -> Color:
	return HomeKit.CLASSIC.ink if _is_classic() else Color.WHITE

func _tile_size() -> float:
	var n: int = WLEngine.LEVELS[engine.level].len
	var w: float = get_viewport_rect().size.x - 60.0
	return clampf(w / n - 8.0, 44.0, 92.0)

func _tile(ch: String, kind: String, changed: bool, idx: int) -> Control:
	var k := _tile_size()
	if kind == "current":
		var b := Button.new()
		b.text = ch
		b.custom_minimum_size = Vector2(k, k * 1.1)
		b.add_theme_font_size_override("font_size", int(k * 0.55))
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("sfx", "key")
		var sb := _tile_style("current", idx == sel)
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			b.add_theme_color_override(cn, _ink())
		b.pressed.connect(_on_tile.bind(idx))
		return b
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(k * 0.8, k * 0.9)
	p.add_theme_stylebox_override("panel", _tile_style(kind, changed))
	var l := Label.new()
	l.text = ch
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(k * 0.45))
	l.add_theme_color_override("font_color", _ink())
	p.add_child(l)
	return p

func _word_row(word: String, prev: String, kind: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for i in word.length():
		var changed := prev != "" and prev[i] != word[i]
		row.add_child(_tile(word[i].to_upper(), kind, changed, i))
	return row

# ---------- play ----------

func _render() -> void:
	for c in ladder_box.get_children():
		ladder_box.remove_child(c)
		c.queue_free()
	if engine.is_over():
		return
	var p: Dictionary = engine.current()
	info_label.text = tr("Ladder %d of %d   Par %d   Score %d") % [engine.index + 1, WLEngine.ROUND, engine.par(), engine.score]
	var solved: bool = engine.solved()
	for i in engine.chain.size():
		var w: String = engine.chain[i]
		var prev: String = engine.chain[i - 1] if i > 0 else ""
		var last: bool = i == engine.chain.size() - 1
		var kind := "step"
		if last and solved:
			kind = "goal"
		elif last:
			kind = "current"
		elif i == 0:
			kind = "start"
		var row := _word_row(w, prev, kind)
		ladder_box.add_child(row)
	if not solved:
		var dots := Label.new()
		dots.text = "⋮"
		dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dots.add_theme_font_size_override("font_size", 30)
		ladder_box.add_child(dots)
		ladder_box.add_child(_word_row(p.end, "", "goal"))
	_update_picker()
	var sc: ScrollContainer = scroll
	sc.call_deferred("set", "scroll_vertical", 100000)

func _update_picker() -> void:
	for c in picker_grid.get_children():
		picker_grid.remove_child(c)
		c.queue_free()
	var show := sel >= 0 and not engine.solved() and not engine.is_over()
	picker.visible = show
	if not show:
		return
	var cur: String = engine.chain.back()
	var k: float = clampf((get_viewport_rect().size.x - 32.0 - 16.0 - 8.0 * 6.0) / 9.0, 36.0, 64.0)
	for ch in LETTERS:
		var b := Button.new()
		b.text = ch
		b.custom_minimum_size = Vector2(k, k)
		b.add_theme_font_size_override("font_size", int(k * 0.5))
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = ch.to_lower() == cur[sel]
		b.set_meta("sfx", "key")
		b.pressed.connect(_on_letter.bind(ch))
		picker_grid.add_child(b)

func _on_tile(i: int) -> void:
	if engine.solved() or engine.is_over():
		return
	sel = -1 if sel == i else i
	_render()

func _on_letter(ch: String) -> void:
	if sel < 0 or engine.solved() or engine.is_over():
		return
	var cur: String = engine.chain.back()
	var w := cur.substr(0, sel) + ch.to_lower() + cur.substr(sel + 1)
	match engine.try_step(w):
		"ok":
			_sfx("letter_right")
			sel = -1
			_clear_feedback()
			_render()
			_save_game()
			if engine.solved():
				_on_solved()
		"not_word":
			_sfx("letter_wrong")
			_feedback(tr("✗ %s isn't a word in the list") % w.to_upper(), Color(1, 0.45, 0.45))
		"used":
			_sfx("letter_wrong")
			_feedback(tr("You already used %s") % w.to_upper(), Color(1, 0.7, 0.35))

func _on_solved() -> void:
	var pts := engine.points_now()
	if info:
		info.add("Ladders solved")
		if engine.is_perfect():
			info.add("Perfect ladders")
	_sfx("powerup")
	var msg: String = tr("%d steps (par %d)") % [engine.steps(), engine.par()] + "\n" + tr("+%d points") % pts
	if engine.is_perfect():
		msg += "\n" + tr("Perfect — the shortest ladder!")
	ladder_dialog.get_meta("message_label").text = msg
	ladder_dialog.visible = true

func _next_ladder() -> void:
	engine.finish_ladder()
	sel = -1
	if engine.is_over():
		_round_over()
	else:
		_render()
		_save_game()

func _round_over() -> void:
	SaveUtil.delete(SAVE_PATH)
	round_started = false
	var level_name: String = ["Easy", "Normal", "Hard"][engine.level]
	if info:
		info.add("Rounds played")
		info.best("Best score", engine.score)
		info.best("Best score (%s)" % level_name, engine.score)
	end_dialog.get_meta("message_label").text = tr("Score: %d") % engine.score
	end_dialog.visible = true
	_render()

func _on_undo() -> void:
	if engine.undo():
		sel = -1
		_sfx("back")
		_render()
		_save_game()

func _on_hint() -> void:
	if engine.is_over() or engine.solved():
		return
	var w := engine.hint()
	if w == "":
		return
	sel = -1
	_sfx("powerup")
	_feedback(tr("💡 Try %s") % w.to_upper(), Color(0.9, 0.8, 0.4))
	_render()
	_save_game()
	if engine.solved():
		_on_solved()

func _on_skip() -> void:
	if engine.is_over() or engine.solved():
		return
	var p: Dictionary = engine.current()
	var pth: Array = engine.path(p.start, p.end)
	var words: Array = []
	for w in pth:
		words.append(str(w).to_upper())
	_feedback(" → ".join(words), Color(0.9, 0.8, 0.4), 6.0)
	engine.skip()
	sel = -1
	if engine.is_over():
		_round_over()
	else:
		_render()
		_save_game()

func _feedback(text: String, col: Color, secs: float = 1.8) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", col)
	feedback_timer.start(secs)

func _clear_feedback() -> void:
	feedback_label.text = ""

# ---------- Landing (home_kit.gd) ----------

func _new_game(level: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.new_round(level)
	_begin_play()

func _restart() -> void:
	_new_game(engine.level)

func _begin_play() -> void:
	sel = -1
	round_started = true
	ladder_dialog.visible = false
	end_dialog.visible = false
	_clear_feedback()
	_render()
	_save_game()

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y * 0.42, 56.0)
	var mid := c.size / 2.0
	var half := k * 1.9
	var top := mid.y - k * 1.5
	var bottom := mid.y + k * 1.5
	HomeKit.glow_line(c, Vector2(mid.x - half, top), Vector2(mid.x - half, bottom), HomeKit.GOLD, 3.0)
	HomeKit.glow_line(c, Vector2(mid.x + half, top), Vector2(mid.x + half, bottom), HomeKit.GOLD, 3.0)
	var words := ["CAT", "COT", "COG", "DOG"]
	for i in 4:
		var y := top + k * (0.25 + i * 0.83)
		HomeKit.glow_line(c, Vector2(mid.x - half, y), Vector2(mid.x + half, y), HomeKit.GOLD, 2.0)
		HomeKit.glow_text(c, Vector2(mid.x, y - k * 0.28), words[i], int(k * 0.5), Color.WHITE)

# ---------- save / resume ----------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if engine == null or not round_started or engine.is_over():
		return
	SaveUtil.write(SAVE_PATH, engine.to_dict())

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Ladder %d of %d") % [int(d.get("index", 0)) + 1, WLEngine.ROUND]

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not engine.from_dict(d):
		_new_game(0)
		return
	if engine.solved():
		engine.finish_ladder()
	if engine.is_over():
		_new_game(engine.level)
		return
	_begin_play()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
