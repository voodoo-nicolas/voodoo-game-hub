extends Control

## Sudoku's Landing page (STANDARDS §3; custom visuals, the same buttons as
## the Landing kit): ← Hub (the only way to the hub, N1), Resume, a new puzzle
## per difficulty, How to Play, Leaderboard, Achievements, Statistics and
## Options, plus the cards they open (each with 🏠 Home, or ‹ Back when
## opened from the pause menu). sudoku_game.gd owns the game and answers the
## signals; this file only draws and asks.
##
## Shared pieces are load()ed, never preloaded (packs run on older apps):
## no Auth -> the Leaderboard says so; no Settings -> no Sound button.

signal play(difficulty: String)
signal resume
signal stats_requested
signal hub_requested

const HELP = preload("res://scripts/games/sudoku/sudoku_help.gd")
const SOUND_OPTIONS_PATH := "res://scripts/common/sound_options.gd"
const ORIENTATION_PATH := "res://scripts/common/orientation.gd"
const LEADERBOARD_SIZE := 10

const BG := Color(0.035, 0.043, 0.075)
const CYAN := Color("29e6ff")
const BLUE := Color("3a8cff")
const LIME := Color("7dff3a")
const GOLD := Color("ffae2b")
const PURPLE := Color("9b4dff")
const PINK := Color("ff4f9a")
const DIM := Color(0.62, 0.66, 0.78)
const LEVEL_COLORS := {"easy": LIME, "medium": CYAN, "hard": GOLD, "expert": PINK}

var difficulties: Array = []
var info = null  # the game's GameInfo, or null on old apps

var resume_btn: Button
var level_buttons: Dictionary = {}  # difficulty -> Button
var info_overlay: Control
var lb_overlay: Control
var lb_box: VBoxContainer
var _grid_logo: Control
var _fact_btn: Button
var _fact_i: int = 0

func setup(p_difficulties: Array, p_info) -> void:
	difficulties = p_difficulties
	info = p_info

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grid_bg := Control.new()
	grid_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_bg.draw.connect(_draw_backdrop.bind(grid_bg))
	add_child(grid_bg)
	grid_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var top := HBoxContainer.new()
	var hub_top := _neon_button(tr("← Hub"), DIM, 22, 58)
	hub_top.custom_minimum_size.x = 150
	hub_top.pressed.connect(func(): hub_requested.emit())
	top.add_child(hub_top)
	box.add_child(top)

	_grid_logo = Control.new()
	_grid_logo.custom_minimum_size = Vector2(0, 170)
	_grid_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_logo.draw.connect(_draw_logo)
	box.add_child(_grid_logo)

	var title := Label.new()
	title.text = tr("Sudoku").to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.85, 0.98, 1.0))
	title.add_theme_color_override("font_outline_color", Color(CYAN, 0.55))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)

	var sub := Label.new()
	sub.text = tr("Fill the grid. Every row, column and box: 1 to 9.")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", DIM)
	box.add_child(sub)

	box.add_child(_gap(6))
	resume_btn = _neon_button("", LIME, 28, 76)
	resume_btn.pressed.connect(func(): resume.emit())
	box.add_child(resume_btn)

	box.add_child(_section(tr("New puzzle")))
	var levels := GridContainer.new()
	levels.columns = 2
	levels.add_theme_constant_override("h_separation", 16)
	levels.add_theme_constant_override("v_separation", 16)
	box.add_child(levels)
	for d in difficulties:
		var b := _neon_button("", LEVEL_COLORS.get(d, CYAN), 26, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_level.bind(d))
		levels.add_child(b)
		level_buttons[d] = b

	box.add_child(_section(tr("More")))
	var more := GridContainer.new()
	more.columns = 2
	more.add_theme_constant_override("h_separation", 16)
	more.add_theme_constant_override("v_separation", 16)
	box.add_child(more)
	var items := [
		[tr("❓ How to Play"), BLUE, _show_info],
		[tr("🏆 Leaderboard"), GOLD, _show_leaderboard],
	]
	if info and info.has_method("achievement_rows"):
		items.append([tr("🏅 Achievements"), PINK, _show_achievements])
	if info:
		items.append([tr("📊 Statistics"), PURPLE, func(): stats_requested.emit()])
	items.append([tr("⚙ Options"), CYAN, _show_options])
	for it in items:
		var b := _neon_button(it[0], it[1], 23, 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(it[2])
		more.add_child(b)

	# Learning hook (STANDARDS §15): one checked fact from the help file; a
	# tap shows the next.
	var facts: Array = HELP.FACTS
	if not facts.is_empty():
		_fact_i = randi() % facts.size()
		_fact_btn = _neon_button("", GOLD, 20, 0)
		_fact_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_fact_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_fact_btn.pressed.connect(_next_fact)
		box.add_child(_gap(8))
		box.add_child(_fact_btn)
		_show_fact()

	_build_info_overlay()
	_build_leaderboard_overlay()
	refresh(null)

func _show_fact() -> void:
	var facts: Array = HELP.FACTS
	_fact_btn.text = tr("💡 Did you know?") + "
" + tr(str(facts[_fact_i % facts.size()]))

func _next_fact() -> void:
	_fact_i += 1
	_show_fact()

## Called whenever Home is shown: `save` is the saved game (or null), and
## every difficulty button shows that level's best time.
func refresh(save) -> void:
	resume_btn.visible = save != null
	if save != null:
		var d := str(save.get("difficulty", "medium"))
		resume_btn.text = "▶  " + tr("Resume") + "   ·   %s  %s" % [tr(d.capitalize()), _time(float(save.get("elapsed_seconds", 0.0)))]
	for d in level_buttons:
		var b: Button = level_buttons[d]
		var best = _stat("_best_time_" + d, null) if info else null
		var line2: String = (tr("Best time") + "  " + _time(float(best))) if best != null else tr("Not solved yet")
		b.text = tr(str(d).capitalize()) + "\n" + line2

func _on_level(d: String) -> void:
	play.emit(d)

# ---------- How to Play ----------

func _build_info_overlay() -> void:
	var parts := _overlay(tr("❓ How to Play"), BLUE)
	info_overlay = parts[0]
	var body: VBoxContainer = parts[1]
	_info_section(body, tr("🎯 Goal"), [HELP.GOAL], LIME)
	_info_section(body, tr("📋 How to Play"), HELP.HOW, CYAN)
	_info_section(body, tr("💡 Tips"), HELP.TIPS, GOLD)

func _info_section(body: VBoxContainer, heading: String, lines: Array, color: Color) -> void:
	var h := Label.new()
	h.text = heading
	h.add_theme_font_size_override("font_size", 28)
	h.add_theme_color_override("font_color", color)
	body.add_child(h)
	for line in lines:
		var l := Label.new()
		l.text = ("• " if lines.size() > 1 else "") + tr(line)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 23)
		l.add_theme_color_override("font_color", Color(0.88, 0.9, 0.96))
		body.add_child(l)
	body.add_child(_gap(8))

func _show_info() -> void:
	info_overlay.visible = true

# ---------- Leaderboard ----------

func _build_leaderboard_overlay() -> void:
	var parts := _overlay(tr("🏆 Leaderboard"), GOLD)
	lb_overlay = parts[0]
	lb_box = parts[1]

func _auth() -> Node:
	var a := get_node_or_null("/root/Auth")
	return a if a and a.has_method("fetch_leaderboard") else null

func _show_leaderboard() -> void:
	lb_overlay.visible = true
	_clear(lb_box)
	var a := _auth()
	if a == null:
		_note(lb_box, tr("Update the app to see the leaderboards."))
		return
	# Post our best first, in case it was set before signing in -- the
	# server keeps the higher one.
	var mine = _stat("Best score", null) if info else null
	if mine != null and a.is_logged_in():
		a.submit_score(HELP.ID, int(mine))
	_note(lb_box, tr("Loading..."))
	a.fetch_leaderboard(HELP.ID, LEADERBOARD_SIZE, _on_leaderboard)

func _on_leaderboard(rows: Variant) -> void:
	if not is_instance_valid(lb_box):
		return
	_clear(lb_box)
	var a := _auth()
	var mine = _stat("Best score", null) if info else null
	if mine != null:
		var you := Label.new()
		you.text = tr("Your best: %d") % int(mine)
		you.add_theme_font_size_override("font_size", 26)
		you.add_theme_color_override("font_color", LIME)
		lb_box.add_child(you)
		lb_box.add_child(_gap(6))
	if rows == null:
		_note(lb_box, tr("Couldn't load the leaderboard. Check your connection and try again."))
		return
	if rows.is_empty():
		_note(lb_box, tr("No scores yet — be the first!"))
	var me: String = str(a.user_id) if a and a.is_logged_in() else ""
	for i in rows.size():
		var r: Dictionary = rows[i]
		var medal: String = ["🥇", "🥈", "🥉"][i] if i < 3 else "%d." % (i + 1)
		var is_me: bool = me != "" and str(r.get("user_id", "")) == me
		lb_box.add_child(_lb_row(medal, str(r.get("display_name", "Player")), str(int(r.get("score", 0))), is_me))
	lb_box.add_child(_gap(10))
	if a and not a.is_logged_in():
		_note(lb_box, tr("Sign in (hub ⚙ Options) to put your best score on the board."))
	_note(lb_box, tr("Scores: points for each correct square, minus mistakes, plus a time bonus, times the difficulty (Expert ×3)."))

func _lb_row(medal: String, who: String, score: String, is_me: bool) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GOLD, 0.14) if is_me else Color(1, 1, 1, 0.04)
	sb.border_color = Color(GOLD, 0.8) if is_me else Color(1, 1, 1, 0.08)
	sb.set_border_width_all(2 if is_me else 1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	for spec in [[medal, 0, false], [who, 1, true], [score, 2, false]]:
		var l := Label.new()
		l.text = spec[0]
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", GOLD if spec[1] == 2 else Color(0.92, 0.94, 1.0))
		if spec[1] == 0:
			l.custom_minimum_size = Vector2(52, 0)
		if spec[2]:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
		row.add_child(l)
	return panel

# ---------- Sound ----------

func _show_sound() -> void:
	var settings = get_node_or_null("/root/Settings")
	if settings == null:
		return
	var parts := _overlay(tr("🔊 Sound"), CYAN, true)
	parts[1].add_child(load(SOUND_OPTIONS_PATH).new(settings.DARK, true))
	parts[0].visible = true

## ⚙ Options (STANDARDS §7): 🔄 Rotate, then the app-wide settings (the same
## values as the hub's Options). `parent` = where the card goes (the game
## puts it over its pause menu, with ‹ Back).
func _show_options(parent: Node = null, from_pause: bool = false) -> void:
	var parts := _overlay(tr("⚙ Options"), CYAN, true, parent, from_pause)
	var body: VBoxContainer = parts[1]
	if ResourceLoader.exists(ORIENTATION_PATH):
		body.add_child(_section(tr("Screen")))
		var rot := _neon_button(tr("🔄 Rotate Screen"), BLUE, 24, 64)
		rot.pressed.connect(_rotate)
		body.add_child(rot)
	var g := get_parent()
	if g and g.has_method("_set_skin"):
		body.add_child(_section(tr("Look")))
		body.add_child(_choice(["Classic", "💀 Voodoo"], 1 if str(g.skin) == "voodoo" else 0,
			func(i): g._set_skin("voodoo" if i == 1 else "classic"), PURPLE))
	var s := get_node_or_null("/root/Settings")
	if s:
		_note(body, tr("These settings are app-wide: they change every game."))
		if s.has_method("set_text_size") and "TEXT_SIZE_NAMES" in s:
			body.add_child(_section(tr("Text & button size")))
			body.add_child(_choice(s.TEXT_SIZE_NAMES, int(s.text_size), func(i): s.set_text_size(i), GOLD))
		if s.has_method("set_vibrate"):
			body.add_child(_section(tr("Vibration")))
			body.add_child(_choice(["On", "Off"], 0 if s.vibrate else 1, func(i): s.set_vibrate(i == 0), LIME))
		if s.has_method("set_keep_awake"):
			body.add_child(_section(tr("Keep screen on")))
			body.add_child(_choice(["On", "Off"], 0 if s.keep_awake else 1, func(i): s.set_keep_awake(i == 0), LIME))
		if s.has_method("set_invites") and "INVITE_MODES" in s:
			body.add_child(_section(tr("🔔 Game invites")))
			body.add_child(_choice(s.INVITE_MODE_NAMES, maxi(0, s.INVITE_MODES.find(s.invites)),
				func(i): s.set_invites(str(s.INVITE_MODES[i])), PINK))
		if ResourceLoader.exists(SOUND_OPTIONS_PATH):
			body.add_child(_section(tr("🔊 Sound")))
			body.add_child(load(SOUND_OPTIONS_PATH).new(s.DARK, true))
	parts[0].visible = true

## Saves (through the game), then reloads the scene turned the other way.
func _rotate() -> void:
	var g := get_parent()
	if g and g.has_method("_save_game"):
		g._save_game()
	get_tree().paused = false
	var view := get_viewport_rect().size
	load(ORIENTATION_PATH).override_next(view.x <= view.y)
	get_tree().reload_current_scene()

## A row of toggle buttons; `on_pick(index)`.
func _choice(names: Array, current: int, on_pick: Callable, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	for i in names.size():
		var b := _neon_button(tr(str(names[i])), color, 22, 56)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == current
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var on := StyleBoxFlat.new()
		on.bg_color = Color(color, 0.45)
		on.border_color = color
		on.set_border_width_all(3)
		on.set_corner_radius_all(14)
		b.add_theme_stylebox_override("pressed", on)
		b.pressed.connect(on_pick.bind(i))
		row.add_child(b)
	return row

## 🏅 Achievements (GameInfo, app v0.25+): earned first, then the rest.
func _show_achievements() -> void:
	var parts := _overlay(tr("🏅 Achievements"), PINK, true)
	var body: VBoxContainer = parts[1]
	var rows: Array = info.achievement_rows()
	var have := rows.filter(func(r): return r.unlocked).size()
	_note(body, tr("%d of %d unlocked") % [have, rows.size()])
	var sorted := rows.filter(func(r): return r.unlocked) + rows.filter(func(r): return not r.unlocked)
	for r in sorted:
		var l := Label.new()
		l.text = "%s  %s\n      %s" % [str(r.icon) if r.unlocked else "🔒", str(r.title), str(r.desc)]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 23)
		l.add_theme_color_override("font_color", GOLD if r.unlocked else DIM)
		body.add_child(l)
	parts[0].visible = true

# ---------- building blocks ----------

## A full-screen card with a title, a scrolling body and a Close button.
## Returns [overlay, body]. `temporary` overlays free themselves on close.
func _overlay(title_text: String, color: Color, temporary: bool = false, parent: Node = null, from_pause: bool = false) -> Array:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.025, 0.05, 1.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.add_to_group("modal_overlay")
	(parent if parent else self).add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	overlay.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	title.add_theme_color_override("font_outline_color", Color(color, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	# 🏠 Home back to this Landing, or ‹ Back to the pause menu (N2).
	var close := _neon_button(("‹  " + tr("Back")) if from_pause else tr("🏠 Home"), color, 26, 62)
	if temporary:
		close.pressed.connect(overlay.queue_free)
	else:
		close.pressed.connect(overlay.hide)
	col.add_child(close)
	return [overlay, body]

func _neon_button(text: String, color: Color, font_size: int, height: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", color)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(color, 0.22 if state == "pressed" else 0.08)
		sb.border_color = Color(color, 1.0 if state != "normal" else 0.85)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.shadow_color = Color(color, 0.35 if state == "pressed" else 0.22)
		sb.shadow_size = 10
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		b.add_theme_stylebox_override(state, sb)
	return b

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", DIM)
	return l

func _note(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", DIM)
	parent.add_child(l)

## A GameInfo stat, read from its dictionary (get_stat() is v0.21+).
func _stat(key: String, default: Variant = 0) -> Variant:
	return info.stats.get(key, default) if info and "stats" in info else default

func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

static func _time(s: float) -> String:
	var t := int(round(s))
	return "%d:%02d" % [int(t / 60), t % 60]

# ---------- drawing ----------

## Faint 1 px grid behind everything (ART_STYLE rule 1).
func _draw_backdrop(c: Control) -> void:
	var step := 48.0
	var col := Color(BLUE, 0.07)
	var x := fmod(c.size.x / 2.0, step)
	while x < c.size.x:
		c.draw_line(Vector2(x, 0), Vector2(x, c.size.y), col, 1.0)
		x += step
	var y := 0.0
	while y < c.size.y:
		c.draw_line(Vector2(0, y), Vector2(c.size.x, y), col, 1.0)
		y += step

## A glowing 3x3 box with a few digits: the game's logo.
func _draw_logo() -> void:
	var s := minf(_grid_logo.size.y, 170.0)
	var origin := Vector2((_grid_logo.size.x - s) / 2.0, (_grid_logo.size.y - s) / 2.0)
	var cell := s / 3.0
	var rect := Rect2(origin, Vector2(s, s))
	# glow: the same outline, wider and fainter
	for g in [[14.0, 0.08], [7.0, 0.25], [3.0, 1.0]]:
		_grid_logo.draw_rect(rect, Color(CYAN, g[1]), false, g[0])
	for i in [1, 2]:
		var x: float = origin.x + cell * i
		var y: float = origin.y + cell * i
		for g in [[6.0, 0.15], [2.0, 0.7]]:
			_grid_logo.draw_line(Vector2(x, origin.y), Vector2(x, origin.y + s), Color(CYAN, g[1]), g[0])
			_grid_logo.draw_line(Vector2(origin.x, y), Vector2(origin.x + s, y), Color(CYAN, g[1]), g[0])
	var font := get_theme_default_font()
	var fs := int(cell * 0.6)
	var digits := {0: ["5", Color.WHITE], 2: ["3", Color.WHITE], 4: ["7", CYAN], 6: ["9", LIME], 8: ["1", Color.WHITE], 5: ["2", GOLD]}
	for idx in digits:
		var text: String = digits[idx][0]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var centre := origin + Vector2((idx % 3 + 0.5) * cell, (int(idx / 3) + 0.5) * cell)
		var pos := Vector2(centre.x - w / 2.0, centre.y - font.get_height(fs) / 2.0 + font.get_ascent(fs))
		var col: Color = digits[idx][1]
		_grid_logo.draw_string(font, pos + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, 0.25))
		_grid_logo.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
