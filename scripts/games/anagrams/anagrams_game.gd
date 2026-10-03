extends Control

## Anagrams -- tap the letter tiles in order to spell the hidden word. The
## word checks itself once every tile is used.

const AnEngine = preload("res://scripts/games/anagrams/anagrams_engine.gd")
const HomeKit = preload("res://scripts/games/anagrams/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://anagrams_best.json"
const SAVE_PATH := "user://anagrams_save.json"
const COLOR_TILE := HomeKit.GOLD
const COLOR_USED := Color(0.35, 0.35, 0.42)
const COLOR_INK := Color.WHITE

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: AnEngine
var progress_label: Label
var answer_label: Label
var feedback_label: Label
var tiles_box: HBoxContainer
var end_dialog: ColorRect
var picked: Array = []      # indices into engine.letters, in order
var tiles: Array = []
var best: int = 0
var locked: int = 0         # letters fixed in place by hints
var feedback_timer: Timer

func _ready() -> void:
	preload("res://scripts/games/anagrams/anagrams_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = AnEngine.new()
	engine.load_words()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
	_build_ui()
	_start_new_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 22)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🔀 Anagrams")
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.93, 0.8))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.GOLD, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start_new_game)
	bar.add_child(restart_btn)

	progress_label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 26)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(progress_label)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer_top)

	answer_label = Label.new()
	answer_label.add_theme_font_size_override("font_size", 64)
	answer_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	answer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(answer_label)

	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 28)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.custom_minimum_size = Vector2(0, 40)
	root.add_child(feedback_label)

	tiles_box = HBoxContainer.new()
	tiles_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles_box.add_theme_constant_override("separation", 8)
	root.add_child(tiles_box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var rm := MarginContainer.new()
	rm.add_theme_constant_override("margin_bottom", 40)
	rm.add_child(row)
	root.add_child(rm)
	row.add_child(_button(tr("🔀 Shuffle"), _on_shuffle))
	row.add_child(_button(tr("Clear"), _on_clear))
	row.add_child(_button(tr("💡 Hint"), _on_hint))
	row.add_child(_button(tr("Skip"), _on_skip))

	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.wait_time = 1.4
	feedback_timer.timeout.connect(_clear_feedback)
	add_child(feedback_timer)

	end_dialog = UI.build_dialog(tr("Round Over"), [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/anagrams/anagrams_help.gd"))
	_build_home()
	if info:
		add_child(info)
		if best > 0:
			info.high("Best score", best)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.75)  # between the tiles and the buttons
	add_child(drawer)

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(128, 76)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	return b

func _start_new_game() -> void:
	engine.new_round(TranslationServer.get_locale().begins_with("es"))
	end_dialog.visible = false
	_new_word()

func _new_word() -> void:
	picked = []
	locked = 0
	for t in tiles:
		t.queue_free()
	tiles = []
	var n: int = engine.letters.size()
	var w: float = min(96.0, (get_viewport_rect().size.x - 40.0) / n - 8.0)
	for i in n:
		var b := Button.new()
		b.custom_minimum_size = Vector2(w, w * 1.15)
		b.add_theme_font_size_override("font_size", int(w * 0.55))
		b.add_theme_color_override("font_color", COLOR_INK)
		b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.65))
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_tile.bind(i))
		tiles_box.add_child(b)
		tiles.append(b)
	_render()

func _render() -> void:
	progress_label.text = tr("Word %d of %d   Score: %d   Best: %d") % [min(engine.index + 1, AnEngine.ROUND), AnEngine.ROUND, engine.score, best]
	var shown := ""
	for k in engine.target.length():
		shown += (engine.letters[picked[k]] if k < picked.size() else "_") + " "
	answer_label.text = shown.strip_edges()
	for i in tiles.size():
		var used: bool = picked.has(i)
		tiles[i].text = engine.letters[i]
		tiles[i].disabled = used
		var sb := HomeKit.neon_box(COLOR_USED if used else COLOR_TILE, "disabled" if used else "normal")
		sb.bg_color = Color(COLOR_USED, 0.15) if used else Color(COLOR_TILE, 0.16)
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			tiles[i].add_theme_stylebox_override(st, sb)

func _on_tile(i: int) -> void:
	if picked.has(i) or engine.is_over():
		return
	picked.append(i)
	_render()
	if picked.size() == engine.letters.size():
		_check()

func _guess() -> String:
	var s := ""
	for i in picked:
		s += engine.letters[i]
	return s

func _check() -> void:
	var g := _guess()
	var pts := engine.points_for_current()
	if engine.submit(g):
		_feedback(tr("✓ %s  +%d") % [g, pts], Color(0.5, 0.95, 0.5))
		_advance()
	else:
		_feedback(tr("✗ Not it — try again"), Color(1, 0.45, 0.45))
		picked = picked.slice(0, locked)
		_render()

func _advance() -> void:
	if engine.is_over():
		SaveUtil.delete(SAVE_PATH)
		if engine.score > best:
			best = engine.score
			SaveUtil.write(BEST_PATH, {"best": best})
		if info:
			info.add("Rounds played")
			info.best("Best score", best)
		end_dialog.get_meta("message_label").text = tr("Score: %d") % engine.score + "\n" + tr("Best: %d") % best
		end_dialog.visible = true
		_render()
		return
	_new_word()

func _feedback(text: String, col: Color) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", col)
	feedback_timer.start()

func _clear_feedback() -> void:
	feedback_label.text = ""

func _on_shuffle() -> void:
	# keep hinted letters where they are; reshuffle the rest
	var keep: Array = []
	for k in locked:
		keep.append(engine.letters[picked[k]])
	engine.letters.shuffle()
	picked = []
	for ch in keep:
		for i in engine.letters.size():
			if engine.letters[i] == ch and not picked.has(i):
				picked.append(i)
				break
	_render()

func _on_clear() -> void:
	picked = picked.slice(0, locked)
	_render()

func _on_hint() -> void:
	if engine.is_over() or locked >= engine.target.length() - 1:
		return
	engine.hints += 1
	locked += 1
	# rebuild: first `locked` letters of the answer, taken from the tiles
	picked = []
	for k in locked:
		var ch: String = engine.target[k]
		for i in engine.letters.size():
			if engine.letters[i] == ch and not picked.has(i):
				picked.append(i)
				break
	_render()

func _on_skip() -> void:
	if engine.is_over():
		return
	_feedback(tr("It was %s") % engine.target, Color(0.9, 0.8, 0.4))
	engine.skip()
	_advance()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/anagrams/anagrams_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/anagrams/anagrams_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Unscramble the letters. Ten words a round.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  New round", "sub": "10 words", "action": _new_round}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _start_new_game,
		"board_note": "Your best round: 10 points per letter, halved on hinted words.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var word := ["W", "O", "R", "D"]
	var k := minf(c.size.y * 0.42, 62.0)
	var o := Vector2(c.size.x / 2.0 - k * 2.2, c.size.y / 2.0 - k / 2.0)
	var tilt := [-0.12, 0.08, -0.05, 0.14]
	for i in 4:
		var ctr := o + Vector2(i * k * 1.12 + k / 2.0, k / 2.0 + (8 if i % 2 == 0 else -8))
		c.draw_set_transform(ctr, tilt[i], Vector2.ONE)
		HomeKit.glow_rect(c, Rect2(Vector2(-k / 2.0, -k / 2.0), Vector2(k, k)), COLOR_TILE, 2.5, 0.12)
		HomeKit.glow_text(c, Vector2.ZERO, ["R", "D", "W", "O"][i], int(k * 0.6), Color.WHITE)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if engine == null or engine.is_over() or engine.target == "":
		return
	SaveUtil.write(SAVE_PATH, {"queue": engine.queue, "target": engine.target, "letters": engine.letters,
		"index": engine.index, "score": engine.score, "hints": engine.hints, "spanish": engine.spanish, "locked": locked})

## From Home: a fresh round replaces any saved one.
func _new_round() -> void:
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Word %d of %d") % [int(d.get("index", 0)) + 1, AnEngine.ROUND]

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or str(d.get("target", "")) == "":
		_start_new_game()
		return
	engine.spanish = bool(d.get("spanish", false))
	engine.queue = Array(d.get("queue", []))
	engine.target = str(d.target)
	engine.letters = Array(d.get("letters", []))
	engine.index = int(d.get("index", 0))
	engine.score = int(d.get("score", 0))
	engine.hints = int(d.get("hints", 0))
	end_dialog.visible = false
	_new_word()
	locked = clampi(int(d.get("locked", 0)), 0, engine.target.length() - 1)
	for k in locked:
		var ch: String = engine.target[k]
		for i in engine.letters.size():
			if engine.letters[i] == ch and not picked.has(i):
				picked.append(i)
				break
	_render()
