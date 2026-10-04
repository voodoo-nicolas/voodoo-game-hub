extends Control

## Home screen kit (Minigame standards #2 and #5): a game's own Home screen,
## its pause menu and the neon look, in one file.
##
## GENERATED: `python tools/hub.py sync` copies tools/templates/home_kit.gd to
## scripts/games/<id>/home_kit.gd for every game that uses it, so each pack
## carries its own copy (packs must run on any app version). Edit the
## template, never a copy -- `hub.py check` fails if a copy differs.
##
## The game designs its Home: its logo is drawn by the game's own code, and
## it picks the title colour, the subtitle and the ways to play. The kit
## draws the rest the same way everywhere: Resume, the play buttons, How to
## Play, 🏆 Leaderboard (Everyone / Friends), 📊 Statistics, 🏅 Achievements,
## 🔊 Sound and Back to Hub. Online games also get "📨 Invite a friend"
## (hosts and lists friends), and Home steps aside whenever the online lobby
## opens -- also when a friend's invite opened the game. The friends and
## achievements parts need app v0.25+ (Social, GameInfo.achievement_rows)
## and simply don't show on older apps.
##
##     const HomeKit = preload("res://scripts/games/<id>/home_kit.gd")
##     var home  # this kit
##     ...in _build_ui(), after the game's own screen and dialogs:
##     theme = HomeKit.neon_theme()          # neon buttons, bigger default text
##     home = HomeKit.new({
##         "help": preload("res://scripts/games/<id>/<id>_help.gd"),
##         "info": info,                     # GameInfo or null -- create it first, add it after
##         "accent": HomeKit.CYAN,
##         "subtitle": "One line that sells the game.",
##         "logo": _draw_home_logo,          # func(c: Control): draw inside c.size
##         "modes": [
##             {"text": "🤖 vs Computer", "sub": "You play X", "action": _new_vs_cpu},
##             {"text": "👥 2 Players", "sub": "One phone", "action": _new_two_player, "multi": true},
##             {"text": "🌐 Online", "sub": "Two phones", "action": online.open_lobby, "multi": true},
##         ],
##         "save_path": SAVE_PATH,           # Resume shows while this file exists
##         "resume": _load_saved_game,
##         "board": "Best score",            # the stat the 🏆 Leaderboard ranks
##         "board_note": "How the score is counted.",
##         "online": online,                 # OnlineMatch node, if any
##         "extra": _add_options,            # func(box): the game's own pickers above the modes
##         "more": [["📜 History", PURPLE, _show_history]],  # the game's own buttons under More
##     })
##     add_child(home)
##     if info: add_child(info)
##     add_child(SettingsDrawer.new())       # stays last
##
## While Home (or the pause menu) is up the scene tree is paused, so the game
## underneath -- even one that started itself in _ready() -- stands still;
## Home itself runs with PROCESS_MODE_ALWAYS. A play button hides Home,
## un-pauses and calls the mode's action, which starts a fresh game.
##
## Pause (standard #5): the game's own ⏸ button calls `home.pause()` (or
## use `home.pause_button()`). The menu saves (the game's `_save_game()`),
## and offers Continue, Restart (cfg "restart"), How to Play, Sound, the
## game's Home and the Hub. Going Home saves and reloads the scene, so it
## opens on Home with Resume -- no game has to unwind its own state.
##
## Strings given in cfg are English; the kit translates them.

const SOUND_OPTIONS_PATH := "res://scripts/common/sound_options.gd"
const HUB_SCENE := "res://scenes/hub/hub.tscn"
const LEADERBOARD_SIZE := 10

## ART_STYLE.md palette.
const BG := Color("070a14")
const PANEL := Color("0d1424")
const CYAN := Color("29e6ff")
const BLUE := Color("3a8cff")
const MAGENTA := Color("ff2bd6")
const PINK := Color("ff4f9a")
const LIME := Color("7dff3a")
const GOLD := Color("ffae2b")
const PURPLE := Color("9b4dff")
const WHITE := Color(0.95, 0.97, 1.0)
const DIM := Color(0.62, 0.66, 0.78)

var cfg: Dictionary
var help: Script
var consts: Dictionary
var info = null
var accent: Color = CYAN

var home: Control
var resume_btn: Button
var info_overlay: Control
var stats_overlay: Control
var stats_box: VBoxContainer
var lb_overlay: Control
var lb_box: VBoxContainer
var lb_friends: bool = false  # 👥 Friends tab of the leaderboard (Social, app v0.25+)
var ach_overlay: Control
var ach_box: VBoxContainer
var pause_overlay: Control
var pause_grid: GridContainer
var _logo: Control
var _paused_by_me: bool = false

func _init(p_cfg: Dictionary = {}) -> void:
	cfg = p_cfg
	help = cfg.get("help")
	consts = help.get_script_constant_map() if help else {}
	info = cfg.get("info")
	accent = cfg.get("accent", CYAN)
	name = "HomeKit"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_home()
	_build_info_overlay()
	_build_stats_overlay()
	_build_leaderboard_overlay()
	_build_achievements_overlay()
	_build_pause_overlay()
	var online: Node = cfg.get("online")
	if online and "lobby" in online and online.lobby and online.lobby.has_signal("cancelled"):
		online.lobby.cancelled.connect(show_home)
	if cfg.get("start_hidden", false):
		home.visible = false
	else:
		show_home()
	# A killed app reopening mid-match goes straight back to the lobby's
	# "Rejoin game" (OnlineMatch opens it deferred): get out of its way.
	call_deferred("_check_rejoin")

func _exit_tree() -> void:
	_unpause()

func _notification(what: int) -> void:
	# Android's back gesture: from the game it pauses, from Home it leaves.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		if _any_overlay_open():
			_close_overlays()
		elif home.visible:
			go_hub()
		else:
			pause()

# ---------- public ----------

func is_home_visible() -> bool:
	return home != null and home.visible

func show_home() -> void:
	_close_overlays()
	pause_overlay.visible = false
	home.visible = true
	refresh()
	_pause_tree()
	_set_drawer_visible(false)

func hide_home() -> void:
	home.visible = false
	_close_overlays()
	_unpause()
	_set_drawer_visible(true)

## The pause menu (standard #5). Saves first, so leaving from here loses nothing.
func pause() -> void:
	if home.visible or pause_overlay.visible:
		return
	_save_game()
	# Two columns when the phone is sideways, so the menu fits the height.
	var view := get_viewport_rect().size
	pause_grid.columns = 2 if view.x > view.y else 1
	pause_overlay.visible = true
	_pause_tree()

func resume_play() -> void:
	pause_overlay.visible = false
	_close_overlays()
	_unpause()

## Back to this game's Home: save, then reload the scene (it opens on Home).
func go_home() -> void:
	_save_game()
	_unpause()
	get_tree().reload_current_scene()

func go_hub() -> void:
	_save_game()
	_unpause()
	get_tree().change_scene_to_file(HUB_SCENE)

## A ⏸ button for the game's top bar, already wired to pause().
func pause_button(text: String = "⏸") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(76, 64)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(pause)
	return b

## A section heading in the Home style, for a game's "extra" controls.
func section(text: String) -> Label:
	return _section(tr(text))

## A row of toggle buttons for a game's own option (cfg "extra"): `names`
## are English, `current` the chosen index; `on_pick` gets the new index.
func choice_row(names: Array, current: int, on_pick: Callable, color: Color = CYAN) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var group := ButtonGroup.new()
	for i in names.size():
		var b := neon_button(tr(str(names[i])), color, 24, 62)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == current
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var on := neon_box(color, "pressed")
		on.bg_color = Color(color, 0.45)
		on.set_border_width_all(3)
		b.add_theme_stylebox_override("pressed", on)
		b.pressed.connect(on_pick.bind(i))
		row.add_child(b)
	return row

## Re-reads the save and the stats (called every time Home shows).
func refresh() -> void:
	var path: String = cfg.get("save_path", "")
	var can_resume: bool = cfg.has("resume") and path != "" and FileAccess.file_exists(path)
	if cfg.has("can_resume"):
		can_resume = cfg.has("resume") and bool(cfg.can_resume.call())
	resume_btn.visible = can_resume
	if can_resume:
		var detail: String = str(cfg.resume_text.call()) if cfg.has("resume_text") else ""
		resume_btn.text = "▶  " + tr("Resume") + ("   ·   " + detail if detail != "" else "")
	_submit_board()

# ---------- Home ----------

func _build_home() -> void:
	home = Control.new()
	home.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(home)
	home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grid := Control.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.draw.connect(draw_grid.bind(grid))
	home.add_child(grid)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	home.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	if cfg.has("logo"):
		_logo = Control.new()
		_logo.custom_minimum_size = Vector2(0, cfg.get("logo_height", 190))
		_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_logo.draw.connect(_draw_logo)
		box.add_child(_logo)

	var title := Label.new()
	title.text = tr(cfg.get("title", consts.get("TITLE", ""))).to_upper()
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", _title_size(title.text))
	title.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.72))
	title.add_theme_color_override("font_outline_color", Color(accent, 0.6))
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)

	var sub_text: String = cfg.get("subtitle", consts.get("GOAL", ""))
	if sub_text != "":
		box.add_child(label(tr(sub_text), 24, DIM, true, true))

	box.add_child(gap(6))
	resume_btn = neon_button("", LIME, 30, 84)
	resume_btn.pressed.connect(_on_resume)
	box.add_child(resume_btn)

	# A game's own choices that go with every mode (board size, deck...):
	# cfg "extra" is func(box: VBoxContainer) that adds them.
	if cfg.has("extra"):
		cfg.extra.call(box)

	var modes: Array = cfg.get("modes", []).duplicate()
	if cfg.has("online"):
		var inv := _invite_mode()
		if not inv.is_empty():
			modes.append(inv)
	var solo := modes.filter(func(m): return not m.get("multi", false))
	var multi := modes.filter(func(m): return m.get("multi", false))
	if not solo.is_empty():
		box.add_child(_section(tr(str(cfg.get("solo_heading", "Single player" if not multi.is_empty() else "Play")))))
		_add_modes(box, solo, accent)
	if not multi.is_empty():
		box.add_child(_section(tr(str(cfg.get("multi_heading", "Multiplayer")))))
		_add_modes(box, multi, MAGENTA)

	box.add_child(_section(tr("More")))
	var more := GridContainer.new()
	more.columns = 2
	more.add_theme_constant_override("h_separation", 16)
	more.add_theme_constant_override("v_separation", 16)
	box.add_child(more)
	var items := [
		[tr("❓ How to Play"), BLUE, func(): info_overlay.visible = true],
		[tr("🏆 Leaderboard"), GOLD, _show_leaderboard],
		[tr("📊 Statistics"), PURPLE, _show_stats],
	]
	if info and info.has_method("achievement_rows"):
		items.append([tr("🏅 Achievements"), PINK, _show_achievements])
	if ResourceLoader.exists(SOUND_OPTIONS_PATH) and get_node_or_null("/root/Settings"):
		items.append([tr("🔊 Sound"), CYAN, _show_sound])
	# A game's own screens (cfg "more": [[English text, colour, callable], ...]).
	for it in cfg.get("more", []):
		items.append([tr(str(it[0])), it[1], it[2]])
	for it in items:
		var b := neon_button(it[0], it[1], 26, 74)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(it[2])
		more.add_child(b)

	box.add_child(gap(4))
	var hub := neon_button(tr("Back to Hub"), DIM, 26, 68)
	hub.pressed.connect(go_hub)
	box.add_child(hub)

## Modes sharing a "row" value sit side by side (difficulty levels).
func _add_modes(box: VBoxContainer, modes: Array, color: Color) -> void:
	var row: HBoxContainer = null
	var row_id = null
	for m in modes:
		var b := _mode_button(m, color)
		if m.has("row"):
			if row == null or m.row != row_id:
				row = HBoxContainer.new()
				row.add_theme_constant_override("separation", 14)
				box.add_child(row)
				row_id = m.row
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
		else:
			row = null
			row_id = null
			box.add_child(b)

## The biggest title size (up to 60) whose longest word fits the screen, so a
## long name ("Rompeladrillos") shrinks instead of breaking mid-word.
func _title_size(text: String) -> int:
	var avail: float = get_viewport_rect().size.x - 100.0
	var font := ThemeDB.fallback_font
	var longest := ""
	for w in text.split(" "):
		if w.length() > longest.length():
			longest = w
	var fs := 60
	while fs > 30 and font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 2
	return fs

func _mode_button(m: Dictionary, default_color: Color) -> Button:
	var text: String = tr(str(m.get("text", "")))
	if m.has("sub") and str(m.sub) != "":
		text += "\n" + tr(str(m.sub))
	var small: bool = m.has("row")
	var b := neon_button(text, m.get("color", default_color), 24 if small else 30, 100 if m.has("sub") else 84)
	b.pressed.connect(_on_mode.bind(m))
	return b

func _on_mode(m: Dictionary) -> void:
	hide_home()
	var action: Callable = m.get("action", Callable())
	if action.is_valid():
		action.call()
	_refit()

func _on_resume() -> void:
	hide_home()
	if cfg.has("resume"):
		cfg.resume.call()
	_refit()

## The app sizes each screen to fit when it opens -- while Home was showing.
## A game screen that only appears now (its own start box hidden until
## Play) is measured again, so nothing wider than the phone is cut off.
func _refit() -> void:
	var s = get_node_or_null("/root/Settings")
	if s and s.has_method("_fit_scene"):
		s.call_deferred("_fit_scene")

func _draw_logo() -> void:
	var f: Callable = cfg.get("logo", Callable())
	if f.is_valid():
		f.call(_logo)

func _check_rejoin() -> void:
	var online: Node = cfg.get("online")
	if online and "lobby" in online and online.lobby:
		# The lobby can also open by itself later: a friend's invite or the
		# hub's Multiplayer screen opens the game straight into online play.
		if not online.lobby.visibility_changed.is_connected(_on_lobby_shown):
			online.lobby.visibility_changed.connect(_on_lobby_shown)
		if online.lobby.visible:
			hide_home()

func _on_lobby_shown() -> void:
	var online: Node = cfg.get("online")
	if online and online.lobby.visible and home.visible:
		hide_home()

## "📨 Invite a friend" for online games, when the app has friends (v0.25+)
## and the player is signed in: hosts a room and lists friends to invite.
func _invite_mode() -> Dictionary:
	var online: Node = cfg.get("online")
	var social := get_node_or_null("/root/Social")
	if online == null or not ("lobby" in online) or online.lobby == null or not online.lobby.has_method("auto_start"):
		return {}
	if social == null or not bool(social.get("available")):
		return {}
	return {"text": "📨 Invite a friend", "sub": "Host a game and invite a friend", "multi": true,
		"color": PINK, "action": _invite_friend}

func _invite_friend() -> void:
	var online: Node = cfg.get("online")
	online.lobby.auto_start({"mode": "invite"})

# ---------- How to Play ----------

func _build_info_overlay() -> void:
	var parts := _overlay(tr("❓ How to Play"), BLUE)
	info_overlay = parts[0]
	var body: VBoxContainer = parts[1]
	if consts.has("GOAL"):
		_info_section(body, tr("🎯 Goal"), [consts.GOAL], LIME)
	if consts.has("HOW"):
		_info_section(body, tr("📋 How to Play"), consts.HOW, CYAN)
	if consts.has("TIPS"):
		_info_section(body, tr("💡 Tips"), consts.TIPS, GOLD)

func _info_section(body: VBoxContainer, heading: String, lines: Array, color: Color) -> void:
	body.add_child(label(heading, 30, color))
	for line in lines:
		body.add_child(label(("•  " if lines.size() > 1 else "") + tr(line), 25, WHITE, true, false))
	body.add_child(gap(8))

# ---------- Statistics ----------

func _build_stats_overlay() -> void:
	var parts := _overlay(tr("📊 Statistics"), PURPLE)
	stats_overlay = parts[0]
	stats_box = parts[1]

func _show_stats() -> void:
	_clear(stats_box)
	var stats: Dictionary = info.stats if info and "stats" in info else {}
	var keys: Array = []
	for k in consts.get("STATS", []):
		keys.append(k)
	for k in stats:
		if not str(k).begins_with("_") and not keys.has(k):
			keys.append(k)
	var rows := 0
	for k in keys:
		if not stats.has(k):
			continue
		stats_box.add_child(_row(_stat_label(k), _stat_value(k, stats[k]), WHITE, PURPLE))
		rows += 1
	var w := int(stats.get("Wins", 0))
	var played := w + int(stats.get("Losses", 0)) + int(stats.get("Draws", 0))
	if played > 0:
		stats_box.add_child(_row(tr("Win rate"), "%d%%" % roundi(100.0 * w / played), WHITE, PURPLE))
		rows += 1
	if rows == 0:
		stats_box.add_child(label(tr("Play a game and your records will show up here.") if info
			else tr("Update the app to keep statistics."), 24, DIM, true))
	stats_overlay.visible = true

func _stat_label(key: String) -> String:
	return info._label(key) if info and info.has_method("_label") else tr(key)

func _stat_value(key: String, v: Variant) -> String:
	if "time" in key.to_lower():
		var t := int(round(float(v)))
		return "%d:%02d" % [int(t / 60), t % 60]
	return str(int(round(float(v))))

# ---------- Achievements (GameInfo, app v0.25+) ----------

func _build_achievements_overlay() -> void:
	var parts := _overlay(tr("🏅 Achievements"), PINK)
	ach_overlay = parts[0]
	ach_box = parts[1]

func _show_achievements() -> void:
	_clear(ach_box)
	var rows: Array = info.achievement_rows()
	var have := rows.filter(func(r): return r.unlocked).size()
	ach_box.add_child(label(tr("%d of %d unlocked") % [have, rows.size()], 30, PINK, true, true))
	ach_box.add_child(gap(4))
	for r in rows:
		ach_box.add_child(_badge(r))
	ach_overlay.visible = true

func _badge(r: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PINK, 0.12) if r.unlocked else Color(1, 1, 1, 0.03)
	sb.border_color = Color(PINK, 0.8) if r.unlocked else Color(1, 1, 1, 0.1)
	sb.set_border_width_all(2 if r.unlocked else 1)
	sb.set_corner_radius_all(12)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 12)
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var icon := label(str(r.icon) if r.unlocked else "🔒", 40, WHITE)
	icon.custom_minimum_size = Vector2(58, 0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.modulate.a = 1.0 if r.unlocked else 0.55
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(label(str(r.title), 27, GOLD if r.unlocked else WHITE, true))
	col.add_child(label(str(r.desc), 22, DIM, true))
	if not r.unlocked and float(r.progress) > 0.0:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.value = 100.0 * float(r.progress)
		var fill := StyleBoxFlat.new()
		fill.bg_color = PINK
		fill.set_corner_radius_all(5)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(1, 1, 1, 0.08)
		back.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", back)
		col.add_child(bar)
	if r.unlocked:
		row.add_child(label("✓", 32, LIME))
	return panel

# ---------- Leaderboard ----------

func _build_leaderboard_overlay() -> void:
	var parts := _overlay(tr("🏆 Leaderboard"), GOLD)
	lb_overlay = parts[0]
	lb_box = parts[1]

func _auth() -> Node:
	var a := get_node_or_null("/root/Auth")
	return a if a and a.has_method("fetch_leaderboard") else null

## The stat the board ranks: cfg "board", else "Best score" when the game
## keeps one, else wins.
func _board_key() -> String:
	if cfg.has("board"):
		return str(cfg.board)
	return "Best score" if consts.get("STATS", []).has("Best score") else "Wins"

func _my_board_value() -> Variant:
	if info == null or not ("stats" in info):
		return null
	var v = info.stats.get(_board_key())
	return null if v == null else int(v)

## Posts our number (the server keeps the higher one), so a best set while
## signed out still reaches the board.
func _submit_board() -> void:
	var a := _auth()
	var mine = _my_board_value()
	if a and mine != null and int(mine) > 0 and a.is_logged_in() and a.has_method("submit_score"):
		a.submit_score(str(consts.get("ID", "")), int(mine))

func _show_leaderboard() -> void:
	lb_overlay.visible = true
	_clear(lb_box)
	var a := _auth()
	if a == null:
		lb_box.add_child(label(tr("Update the app to see the leaderboards."), 24, DIM, true))
		return
	_submit_board()
	lb_box.add_child(label(tr("Loading..."), 24, DIM))
	var social := get_node_or_null("/root/Social")
	if lb_friends and social and a.has_method("fetch_leaderboard_for"):
		a.fetch_leaderboard_for(str(consts.get("ID", "")), social.friend_ids(), _on_leaderboard)
	else:
		a.fetch_leaderboard(str(consts.get("ID", "")), LEADERBOARD_SIZE, _on_leaderboard)

## Everyone / Friends, when the app has friends (v0.25+).
func _board_tabs() -> Control:
	var social := get_node_or_null("/root/Social")
	if social == null or not bool(social.get("available")):
		return null
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for i in 2:
		var b := neon_button(tr(["🌍 Everyone", "👥 Friends"][i]), GOLD, 24, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if (i == 1) == lb_friends:
			var on := neon_box(GOLD, "pressed")
			on.bg_color = Color(GOLD, 0.4)
			on.set_border_width_all(3)
			for st in ["normal", "hover", "focus"]:
				b.add_theme_stylebox_override(st, on)
		b.pressed.connect(_set_board_scope.bind(i == 1))
		row.add_child(b)
	return row

func _set_board_scope(friends: bool) -> void:
	lb_friends = friends
	_show_leaderboard()

func _on_leaderboard(rows: Variant) -> void:
	if not is_instance_valid(lb_box):
		return
	_clear(lb_box)
	var a := _auth()
	var tabs := _board_tabs()
	if tabs:
		lb_box.add_child(tabs)
	lb_box.add_child(label(_stat_label(_board_key()), 30, GOLD))
	var mine = _my_board_value()
	if mine != null:
		lb_box.add_child(label(tr("You: %s") % _stat_value(_board_key(), mine), 27, LIME))
	lb_box.add_child(gap(6))
	if rows == null:
		lb_box.add_child(label(tr("Couldn't load the leaderboard. Check your connection and try again."), 24, DIM, true))
		return
	if rows.is_empty():
		lb_box.add_child(label(tr("No friends on this board yet.") if lb_friends else tr("No scores yet — be the first!"), 24, DIM, true))
	var me: String = str(a.user_id) if a and a.is_logged_in() else ""
	for i in rows.size():
		var r: Dictionary = rows[i]
		var medal: String = ["🥇", "🥈", "🥉"][i] if i < 3 else "%d." % (i + 1)
		var is_me: bool = me != "" and str(r.get("user_id", "")) == me
		lb_box.add_child(_row("%s  %s" % [medal, str(r.get("display_name", "Player"))],
			_stat_value(_board_key(), r.get("score", 0)), LIME if is_me else WHITE, GOLD, is_me))
	lb_box.add_child(gap(10))
	if a and not a.is_logged_in():
		lb_box.add_child(label(tr("Sign in (hub ⚙ Options) to put your best score on the board."), 23, DIM, true))
	if cfg.has("board_note"):
		lb_box.add_child(label(tr(str(cfg.board_note)), 23, DIM, true))

# ---------- Sound ----------

func _show_sound() -> void:
	var settings = get_node_or_null("/root/Settings")
	if settings == null:
		return
	var parts := _overlay(tr("🔊 Sound"), CYAN, true)
	parts[1].add_child(load(SOUND_OPTIONS_PATH).new(settings.DARK if "DARK" in settings else settings.palette(), false))
	parts[0].visible = true

# ---------- Pause ----------

func _build_pause_overlay() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(BG, 0.94)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.visible = false
	pause_overlay.add_to_group("modal_overlay")
	add_child(pause_overlay)
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	pause_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var title := label(tr("Paused").to_upper(), 56, accent.lerp(Color.WHITE, 0.72))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(accent, 0.6))
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)
	box.add_child(gap(8))
	pause_grid = GridContainer.new()
	pause_grid.add_theme_constant_override("h_separation", 16)
	pause_grid.add_theme_constant_override("v_separation", 16)
	box.add_child(pause_grid)
	var specs := [[tr("▶  Continue"), LIME, resume_play]]
	if cfg.has("restart"):
		specs.append([tr("↺  Restart"), GOLD, _on_restart])
	specs.append([tr("❓ How to Play"), BLUE, func(): info_overlay.visible = true])
	if ResourceLoader.exists(SOUND_OPTIONS_PATH) and get_node_or_null("/root/Settings"):
		specs.append([tr("🔊 Sound"), CYAN, _show_sound])
	specs.append([tr("🏠 %s Home") % tr(cfg.get("title", consts.get("TITLE", ""))), PURPLE, go_home])
	specs.append([tr("Back to Hub"), DIM, go_hub])
	for s in specs:
		var b := neon_button(s[0], s[1], 30, 80)
		b.custom_minimum_size.x = 440
		b.pressed.connect(s[2])
		pause_grid.add_child(b)

func _on_restart() -> void:
	resume_play()
	cfg.restart.call()

# ---------- pausing ----------

func _pause_tree() -> void:
	if not is_inside_tree():
		return
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_me = true

func _unpause() -> void:
	if _paused_by_me and is_inside_tree():
		get_tree().paused = false
	_paused_by_me = false

func _save_game() -> void:
	var g := get_parent()
	if g and g.has_method("_save_game"):
		g._save_game()

func _set_drawer_visible(on: bool) -> void:
	var g := get_parent()
	if g == null:
		return
	for c in g.get_children():
		if c != self and c.get_script() and str(c.get_script().resource_path).ends_with("settings_drawer.gd"):
			c.visible = on
	if not on:
		# The drawer is added after us; hide it once it's there.
		call_deferred("_hide_drawer_late")

func _hide_drawer_late() -> void:
	if home.visible:
		var g := get_parent()
		if g:
			for c in g.get_children():
				if c != self and c.get_script() and str(c.get_script().resource_path).ends_with("settings_drawer.gd"):
					c.visible = false

func _any_overlay_open() -> bool:
	for o in [info_overlay, stats_overlay, lb_overlay, ach_overlay]:
		if o and o.visible:
			return true
	return false

func _close_overlays() -> void:
	for o in [info_overlay, stats_overlay, lb_overlay, ach_overlay]:
		if o:
			o.visible = false

# ---------- building blocks ----------

## A full-screen card with a title, a scrolling body and a Close button.
## Returns [overlay, body]. `temporary` overlays free themselves on close.
func _overlay(title_text: String, color: Color, temporary: bool = false) -> Array:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.025, 0.05, 0.97)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.add_to_group("modal_overlay")
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 32)
	overlay.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)
	var title := label(title_text, 44, WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(color, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var close := neon_button(tr("Close"), color, 30, 76)
	if temporary:
		close.pressed.connect(overlay.queue_free)
	else:
		close.pressed.connect(overlay.hide)
	col.add_child(close)
	return [overlay, body]

func _row(left: String, right: String, color: Color, edge: Color, strong: bool = false) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(edge, 0.14) if strong else Color(1, 1, 1, 0.04)
	sb.border_color = Color(edge, 0.8) if strong else Color(1, 1, 1, 0.08)
	sb.set_border_width_all(2 if strong else 1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var l := label(left, 26, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	row.add_child(l)
	row.add_child(label(right, 26, edge.lerp(Color.WHITE, 0.3)))
	return panel

func _section(text: String) -> Label:
	var l := label(text.to_upper(), 22, DIM)
	l.add_theme_constant_override("outline_size", 0)
	return l

func _clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

# ---------- shared look (static: games use these for their own screens) ----------

static func label(text: String, font_size: int, color: Color, wrap: bool = false, center: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## A glowing outline button (ART_STYLE rule 2).
static func neon_button(text: String, color: Color, font_size: int = 28, height: float = 72) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", font_size)
	# Wraps instead of widening the screen on narrow phones / long Spanish text.
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_button(b, color)
	return b

## Gives an existing button the neon look in `color`.
static func style_button(b: Button, color: Color) -> void:
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", color.lerp(Color.WHITE, 0.4))
	b.add_theme_color_override("font_focus_color", WHITE)
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.6))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, neon_box(color, state))

static func neon_box(color: Color, state: String = "normal") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var on := state == "pressed"
	sb.bg_color = Color(color, 0.24 if on else (0.03 if state == "disabled" else 0.09))
	sb.border_color = Color(color, 0.3 if state == "disabled" else (1.0 if state != "normal" else 0.85))
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(color, 0.0 if state == "disabled" else (0.38 if on else 0.22))
	sb.shadow_size = 9
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

## The neon look for a whole game screen: set it as the game root's `theme`.
## Buttons without their own styles get the glowing outline, and text that
## never set a size is drawn at 26 instead of Godot's 16.
static func neon_theme(color: Color = CYAN) -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(state, "Button", neon_box(color, state))
	t.set_color("font_color", "Button", WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", color.lerp(Color.WHITE, 0.4))
	t.set_color("font_focus_color", "Button", WHITE)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.6))
	t.set_color("font_color", "Label", WHITE)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(PANEL, 0.97)
	panel.border_color = Color(PURPLE, 0.7)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(18)
	panel.shadow_color = Color(PURPLE, 0.25)
	panel.shadow_size = 14
	for side in ["left", "right"]:
		panel.set("content_margin_" + side, 28)
	for side in ["top", "bottom"]:
		panel.set("content_margin_" + side, 24)
	t.set_stylebox("panel", "PanelContainer", panel)
	return t

## Faint 1 px grid behind everything (ART_STYLE rule 1). Connect a full-rect
## Control's draw signal to it: `c.draw.connect(HomeKit.draw_grid.bind(c))`.
static func draw_grid(c: Control) -> void:
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

## A near-black backdrop with the faint grid, as a game's first child.
static func backdrop() -> Control:
	var root := ColorRect.new()
	root.color = BG
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grid := Control.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.draw.connect(draw_grid.bind(grid))
	root.add_child(grid)
	return root

# ---------- glow drawing helpers, for logos and boards ----------

## The same stroke drawn three times, wider and fainter (ART_STYLE rule 2).
static func glow_line(c: CanvasItem, a: Vector2, b: Vector2, color: Color, w: float = 3.0) -> void:
	for g in [[w * 4.5, 0.08], [w * 2.3, 0.25], [w, 1.0]]:
		c.draw_line(a, b, Color(color, color.a * g[1]), g[0], true)

static func glow_polyline(c: CanvasItem, pts: PackedVector2Array, color: Color, w: float = 3.0, closed: bool = false) -> void:
	if closed and pts.size() > 0:
		pts = pts.duplicate()
		pts.append(pts[0])
	for g in [[w * 4.5, 0.08], [w * 2.3, 0.25], [w, 1.0]]:
		c.draw_polyline(pts, Color(color, color.a * g[1]), g[0], true)

static func glow_rect(c: CanvasItem, r: Rect2, color: Color, w: float = 3.0, fill_alpha: float = 0.0) -> void:
	if fill_alpha > 0.0:
		c.draw_rect(r, Color(color, fill_alpha))
	for g in [[w * 4.5, 0.08], [w * 2.3, 0.25], [w, 1.0]]:
		c.draw_rect(r, Color(color, color.a * g[1]), false, g[0])

static func glow_circle(c: CanvasItem, center: Vector2, radius: float, color: Color, w: float = 3.0, fill_alpha: float = 0.0) -> void:
	if fill_alpha > 0.0:
		c.draw_circle(center, radius, Color(color, fill_alpha))
	for g in [[w * 4.5, 0.08], [w * 2.3, 0.25], [w, 1.0]]:
		c.draw_arc(center, radius, 0.0, TAU, 48, Color(color, color.a * g[1]), g[0], true)

static func glow_text(c: CanvasItem, center: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(center.x - w / 2.0, center.y - font.get_height(font_size) / 2.0 + font.get_ascent(font_size))
	c.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(4, font_size / 6), Color(color, 0.25))
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color.lerp(Color.WHITE, 0.35))
