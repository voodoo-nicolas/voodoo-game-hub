extends Control

## Landing kit (docs/STANDARDS.md §1-§7; it grew out of the Home screen kit):
## a game's own Landing page, its setup screens, pause menu, game Options
## and the neon look, in one file.
##
## GENERATED: `python tools/hub.py sync` copies tools/templates/home_kit.gd to
## scripts/games/<id>/home_kit.gd for every game that uses it, so each pack
## carries its own copy (packs must run on any app version -- that is why the
## navigation lives here rather than APK-side; STANDARDS §1 N7). Edit the
## template, never a copy -- `hub.py check` fails if a copy differs.
##
## Navigation (STANDARDS §1):
## - The Landing page is the only screen with "← Hub" (N1). Every other screen
##   has 🏠 Home (back to the Landing) -- or ‹ Back when it was opened from the
##   pause menu (N2). Android back is one step up: a card closes, the pause
##   menu resumes, the game pauses, the Landing leaves to the hub (N4).
## - Landing (§3): the game's logo + title + subtitle, ▶ Resume (a save
##   exists), ⚡ Quick Play (the way you played last), then 🎮 Single player
##   and/or 👥 Multiplayer. Each opens a setup screen (§4/§5): the game's own
##   pickers (cfg "extra"), the ways to play (pick one -- tap it again or ▶
##   Start), remembered for Quick Play. A group with one way to play and no
##   pickers starts straight from the Landing (N6). Then ❓ How to Play,
##   🏆 Leaderboard, 🏅 Achievements (All / Earned / Locked), 📊 Statistics,
##   ⚙ Options and the game's own cfg "more" screens.
## - Pause menu (§6): ▶ Resume, ↺ Restart, ❓ How to Play, 🏆, 📊,
##   📸 Screenshot, ⚙ Options, 🏠 Home -- no Hub (N1). It saves first.
## - Options (§7): the app-wide settings (text size, sound, vibration, keep
##   screen on, game invites -- changing one changes it everywhere) and, per
##   game, 🔄 Rotate and the Look. Per-game choices: user://landing_<ID>.json.
## - Skins (§9): Classic (the game's traditional colours) is the default,
##   💀 Voodoo (neon on near-black, skulls) is opt-in -- the app-wide skull
##   mode flips the default. A game with skins defines `_set_skin(name)`
##   ("classic" / "voodoo"; re-skin in place, no reload) and may define
##   `_current_skin()` if it already kept its own choice. The kit calls
##   `_set_skin` once the game is built and whenever the player picks a look.
##   Older games with only `_set_voodoo(on)` keep working. `CLASSIC` holds
##   the shared traditional colours (felt, wood, paper...).
## - Learning hook (§15): if the help file has `FACTS` (English strings,
##   through es.json like the rest), the Landing ends with a "💡 Did you
##   know?" card showing one at random; a tap shows the next. Facts must be
##   checked -- wrong "educational" content is worse than none.
## - The old floating ⚙ SettingsDrawer is removed from every kit game: its
##   items are in the pause menu and Options now (§6). Games may still add it
##   (older copies of this kit used it); the kit frees it.
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
##         "art": "res://games/<id>/landing_bg.jpg",  # optional Landing background (STANDARDS §3/§10)
##         "modes": [
##             {"text": "🤖 vs Computer", "sub": "You play X", "action": _new_vs_cpu},
##             {"text": "👥 2 Players", "sub": "One phone", "action": _new_two_player, "multi": true},
##             {"text": "🌐 Online", "sub": "Two phones", "action": online.open_lobby, "multi": true},
##         ],
##         "save_path": SAVE_PATH,           # Resume shows while this file exists
##         "resume": _load_saved_game,
##         "board": "Best score",            # the stat the 🏆 Leaderboard ranks ("none": no board)
##         "board_note": "How the score is counted.",
##         "online": online,                 # OnlineMatch node, if any
##         "extra": _add_options,            # func(box): the game's own pickers, on the setup screens
##         "more": [["📜 History", PURPLE, _show_history]],  # the game's own buttons under More
##     })
##     add_child(home)
##     if info: add_child(info)
##
## Modes sharing a "row" value sit side by side (difficulty levels); "key"
## (optional, else "text") is what Quick Play remembers. "solo_heading" /
## "multi_heading" rename the two groups.
##
## While the Landing (or the pause menu) is up the scene tree is paused, so
## the game underneath -- even one that started itself in _ready() -- stands
## still; the kit runs with PROCESS_MODE_ALWAYS. Starting a mode hides the
## Landing, un-pauses and calls the mode's action, which starts a fresh game.
## The game's own ⏸ button calls `home.pause()` (or use `home.pause_button()`).
## Going 🏠 Home saves and reloads the scene, so it opens on the Landing with
## Resume -- no game has to unwind its own state.
##
## Strings given in cfg are English; the kit translates them.

const SOUND_OPTIONS_PATH := "res://scripts/common/sound_options.gd"
const VOODOO_PATH := "res://scripts/common/voodoo.gd"
const ORIENTATION_PATH := "res://scripts/common/orientation.gd"
const HUB_SCENE := "res://scenes/hub/hub.tscn"
const LEADERBOARD_SIZE := 10

## Traditional colours for Classic skins (reference/art/skins/CLASSIC.md).
const CLASSIC := {
	"felt": Color("1f6b3a"), "felt_dark": Color("17532c"),
	"wood_light": Color("f0d9b5"), "wood_dark": Color("b58863"), "wood_frame": Color("6b4423"),
	"paper": Color("f7f3e8"), "ink": Color("1d2433"), "pencil": Color("5b6478"),
	"red": Color("d62828"), "yellow": Color("f6c90e"), "blue": Color("1e5bd8"),
	"black_piece": Color("232323"), "white_piece": Color("f4efe4"), "red_piece": Color("c1272d"),
	"card_face": Color("fbf8ef"), "card_back": Color("1a3d9e"), "table": Color("12161f"),
}

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
## The kit's own buttons and cards (owner, 2026-10-06: "less rainbow" --
## one neon blue for every button, green to start or resume).
## The palette above stays for games' own drawing.
const BUTTON := Color("2aa8ff")
const GO := Color("2bff88")
const WHITE := Color(0.95, 0.97, 1.0)
const DIM := Color(0.62, 0.66, 0.78)

var cfg: Dictionary
var help: Script
var consts: Dictionary
var info = null
var accent: Color = CYAN

var home: Control
var resume_btn: Button
var quick_btn: Button
var info_overlay: Control
var stats_overlay: Control
var stats_box: VBoxContainer
var lb_overlay: Control
var lb_box: VBoxContainer
var lb_friends: bool = false  # 👥 Friends tab of the leaderboard (Social, app v0.25+)
var ach_overlay: Control
var ach_box: VBoxContainer
var ach_filter: int = 0  # 0 all, 1 earned, 2 locked
var pause_overlay: Control
var pause_grid: GridContainer
var _toast: Label
var _logo: Control
var _paused_by_me: bool = false
var _more: GridContainer
var _fact_label: Label
var _fact_i: int = 0
var _home_margin: MarginContainer
## The ways to play, split the way the Landing shows them.
var _solo: Array = []
var _multi: Array = []
## Per-game choices (user://landing_<ID>.json): "last" = Quick Play's mode
## key, "skin" = "classic" / "voodoo".
var _prefs: Dictionary = {}
var _drawer_checked_twice := false
## Drag-anywhere scrolling for the Landing: its buttons swallow presses, so
## without this a sideways phone (where it is taller than the screen) could
## only scroll from the thin scrollbar and the buttons below stayed out of reach.
var _drag: _DragScroll

## A small copy of scripts/common/drag_scroll.gd (the kit can't rely on the
## app having it). `moved` is true once a press travels past THRESHOLD, until
## the next press; the kit's buttons ignore the release that ends a drag.
class _DragScroll extends Node:
	const THRESHOLD := 14.0
	var moved := false
	var _tracking := false
	var _start := Vector2.ZERO
	var _start_scroll := 0

	func _input(event: InputEvent) -> void:
		var scroll := get_parent() as ScrollContainer
		if scroll == null or not scroll.is_visible_in_tree():
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				moved = false
				_tracking = scroll.get_global_rect().has_point(event.position)
				_start = event.position
				_start_scroll = scroll.scroll_vertical
			else:
				_tracking = false
		elif event is InputEventMouseMotion and _tracking and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			var dy: float = event.position.y - _start.y
			if not moved and absf(dy) > THRESHOLD:
				moved = true
			if moved:
				scroll.scroll_vertical = _start_scroll - int(dy)

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
	_load_prefs()
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
	# The game adds the old floating drawer after us, and builds its pieces
	# from the app-wide skull mode: both are sorted out once it's all there.
	call_deferred("_remove_drawer")
	call_deferred("_apply_skin_pref")

func _exit_tree() -> void:
	_unpause()

func _notification(what: int) -> void:
	# Android's back gesture: one step up (STANDARDS N4).
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		if _any_overlay_open():
			_close_top_overlay()
		elif pause_overlay.visible:
			resume_play()
		elif home.visible:
			go_hub()
		else:
			pause()
	# The app went to the background mid-game (standard #5): pause, which
	# also saves, so the player comes back to the menu instead of a game that
	# ran on (or ended) without them. Not while the online lobby is up.
	elif what == NOTIFICATION_APPLICATION_PAUSED and is_inside_tree() and home:
		var online: Node = cfg.get("online")
		var lobby_up: bool = online != null and "lobby" in online and online.lobby is CanvasItem and online.lobby.visible
		if not lobby_up:
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
	_remove_drawer()

func hide_home() -> void:
	home.visible = false
	_close_overlays()
	_unpause()

## The pause menu (standard #5). Saves first, so leaving from here loses nothing.
func pause() -> void:
	if home.visible or pause_overlay.visible:
		return
	_save_game()
	_fit_pause_layout()
	_toast.visible = false
	pause_overlay.visible = true
	_pause_tree()

func resume_play() -> void:
	pause_overlay.visible = false
	_close_overlays()
	_unpause()

## Back to this game's Landing: save, then reload the scene (it opens there).
func go_home() -> void:
	_save_game()
	_unpause()
	get_tree().reload_current_scene()

func go_hub() -> void:
	_save_game()
	_unpause()
	get_tree().change_scene_to_file(HUB_SCENE)

## Starts one of cfg "modes" as if picked on its setup screen (also used by
## tools/crawl.gd).
func start_mode(m: Dictionary) -> void:
	_prefs["last"] = _mode_key(m)
	_save_prefs()
	hide_home()
	var action: Callable = m.get("action", Callable())
	if action.is_valid():
		action.call()
	_refit()

## A ⏸ button for the game's top bar, already wired to pause().
func pause_button(text: String = "⏸") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(76, 64)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(pause)
	return b

## A section heading in the kit's style, for a game's "extra" controls.
func section(text: String) -> Label:
	return _section(tr(text))

## A row of toggle buttons for a game's own option (cfg "extra"): `names`
## are English, `current` the chosen index; `on_pick` gets the new index.
## Every row is the kit's one button colour; `_color` is kept for older callers.
func choice_row(names: Array, current: int, on_pick: Callable, _color: Color = CYAN) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var group := ButtonGroup.new()
	for i in names.size():
		var b := neon_button(tr(str(names[i])), BUTTON, 24, 62)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == current
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_toggle(b, BUTTON)
		b.pressed.connect(on_pick.bind(i))
		row.add_child(b)
	return row

## Re-reads the save and the stats (called every time the Landing shows).
func refresh() -> void:
	var path: String = cfg.get("save_path", "")
	var can_resume: bool = cfg.has("resume") and path != "" and FileAccess.file_exists(path)
	if cfg.has("can_resume"):
		can_resume = cfg.has("resume") and bool(cfg.can_resume.call())
	resume_btn.visible = can_resume
	if can_resume:
		var detail: String = str(cfg.resume_text.call()) if cfg.has("resume_text") else ""
		resume_btn.text = "▶  " + tr("Resume") + ("   ·   " + detail if detail != "" else "")
	var last := _last_mode()
	# Quick Play only when there's a choice to skip (one way to play is
	# already one tap on the Landing).
	quick_btn.visible = not last.is_empty() and _solo.size() + _multi.size() > 1
	if quick_btn.visible:
		quick_btn.text = "⚡  " + tr("Quick Play") + "\n" + tr(str(last.get("text", ""))).strip_edges()
	_submit_board()

# ---------- Landing ----------

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
	var art_path: String = cfg.get("art", "")
	if art_path != "" and ResourceLoader.exists(art_path):
		_add_art(home, load(art_path))
	elif bg_texture(str(consts.get("ID", ""))) != null:
		# No art of its own: the shared felt (card games) or leather (the rest).
		_add_art(home, bg_texture(str(consts.get("ID", ""))))
	else:
		var grid := Control.new()
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.draw.connect(draw_grid.bind(grid))
		home.add_child(grid)
		grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	home.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drag = _DragScroll.new()
	scroll.add_child(_drag)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)
	_home_margin = margin
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	# ← Hub: the only way from a game to the hub (N1).
	var top := HBoxContainer.new()
	var hub := neon_button(tr("← Hub"), BUTTON, 24, 60)
	hub.custom_minimum_size.x = 150
	hub.pressed.connect(_on_hub_pressed)
	top.add_child(hub)
	box.add_child(top)

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
		var sub := label(tr(sub_text), 24, DIM, true, true)
		if cfg.has("art"):  # readable over the picture
			sub.add_theme_color_override("font_color", WHITE)
			sub.add_theme_color_override("font_outline_color", Color(BG, 0.9))
			sub.add_theme_constant_override("outline_size", 8)
		box.add_child(sub)

	box.add_child(gap(6))
	resume_btn = neon_button("", GO, 30, 84)
	resume_btn.pressed.connect(_on_resume)
	box.add_child(resume_btn)
	quick_btn = neon_button("", BUTTON, 26, 92)
	quick_btn.pressed.connect(_on_quick)
	box.add_child(quick_btn)

	var modes: Array = cfg.get("modes", []).duplicate()
	if cfg.has("online"):
		var inv := _invite_mode()
		if not inv.is_empty():
			modes.append(inv)
	_solo = modes.filter(func(m): return not m.get("multi", false))
	_multi = modes.filter(func(m): return m.get("multi", false))
	var both: bool = not _solo.is_empty() and not _multi.is_empty()
	if not _solo.is_empty():
		box.add_child(_group_button(_solo, false, both))
	if not _multi.is_empty():
		box.add_child(_group_button(_multi, true, both))

	box.add_child(_section(tr("More")))
	var more := GridContainer.new()
	_more = more
	more.columns = 2
	more.add_theme_constant_override("h_separation", 16)
	more.add_theme_constant_override("v_separation", 16)
	box.add_child(more)
	var items := [[tr("❓ How to Play"), BUTTON, _show_overlay.bind(null, "info")]]
	if _board_key() != "none":
		items.append([tr("🏆 Leaderboard"), BUTTON, _show_leaderboard])
	if info and info.has_method("achievement_rows"):
		items.append([tr("🏅 Achievements"), BUTTON, _show_achievements])
	items.append([tr("📊 Statistics"), BUTTON, _show_stats])
	items.append([tr("⚙ Options"), BUTTON, _show_options])
	# A game's own screens (cfg "more": [[English text, colour, callable], ...]).
	for it in cfg.get("more", []):
		items.append([tr(str(it[0])), it[1], it[2]])
	for it in items:
		var b := neon_button(it[0], BUTTON, 26, 74)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_more.bind(it[2]))
		more.add_child(b)
	_add_fact_card(box)
	get_viewport().size_changed.connect(_fit_home_layout)
	_fit_home_layout()

## §15: one optional "Did you know?" on the Landing, never in the way of play.
func _add_fact_card(box: Control) -> void:
	var facts: Array = consts.get("FACTS", [])
	if facts.is_empty():
		return
	box.add_child(gap(4))
	var panel := PanelContainer.new()
	var sb := neon_box(BUTTON)
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.gui_input.connect(_on_fact_input)
	box.add_child(panel)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var head := label(tr("💡 Did you know?"), 22, BUTTON)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_fact_label = label("", 22, WHITE, true)
	_fact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_fact_label)
	_fact_i = randi() % facts.size()
	_show_fact()

func _show_fact() -> void:
	var facts: Array = consts.get("FACTS", [])
	_fact_label.text = tr(str(facts[_fact_i % facts.size()]))

func _on_fact_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not _dragged():
		_fact_i += 1
		_show_fact()

## The Landing's button for a group of modes: one way to play with no pickers
## starts straight away (N6); otherwise it opens that group's setup screen.
func _group_button(modes: Array, multi: bool, both: bool) -> Button:
	var color: Color = BUTTON
	if modes.size() == 1 and not cfg.has("extra"):
		return _mode_button(modes[0], color)
	var heading := str(cfg.get("multi_heading" if multi else "solo_heading", ""))
	var text: String
	if heading != "":
		text = tr(heading)
	elif not both:
		text = "▶  " + tr("Play")
	else:
		text = tr("👥 Multiplayer") if multi else tr("🎮 Single player")
	var sub: String = tr("%d ways to play") % modes.size() if modes.size() > 1 else tr(str(modes[0].get("text", ""))).strip_edges()
	var b := neon_button(text + "\n" + sub, color, 30, 100)
	b.pressed.connect(_on_group.bind(multi))
	return b

## Sideways phones: a shorter logo, tighter margins and three buttons per row
## under More, so the play buttons are on screen without scrolling far.
## The game's Landing art (cfg "art", its own media in res://games/<id>/):
## fills the screen, cropped not stretched, under a veil that darkens toward
## the bottom so the buttons stay readable.
func _add_art(parent: Control, tex: Texture2D) -> void:
	var art := TextureRect.new()
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.set_color(0, Color(BG, 0.15))
	grad.set_color(1, Color(BG, 0.78))
	grad.add_point(0.35, Color(BG, 0.4))
	var fill := GradientTexture2D.new()
	fill.gradient = grad
	fill.fill_from = Vector2(0, 0)
	fill.fill_to = Vector2(0, 1)
	fill.width = 4
	fill.height = 256
	var veil := TextureRect.new()
	veil.texture = fill
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _fit_home_layout() -> void:
	var view := get_viewport_rect().size
	var wide: bool = view.x > view.y
	if _logo:
		var h: float = cfg.get("logo_height", 190)
		_logo.custom_minimum_size.y = minf(h, 110.0) if wide else h
	if _more:
		_more.columns = 3 if wide else 2
	if _home_margin:
		_home_margin.add_theme_constant_override("margin_top", 10 if wide else 24)
		_home_margin.add_theme_constant_override("margin_bottom", 20 if wide else 40)

func _dragged() -> bool:
	return _drag != null and _drag.moved

func _on_more(action: Callable) -> void:
	if not _dragged():
		action.call()

func _on_hub_pressed() -> void:
	if not _dragged():
		go_hub()

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

func _mode_text(m: Dictionary) -> String:
	var text: String = tr(str(m.get("text", "")))
	if m.has("sub") and str(m.sub) != "":
		text += "\n" + tr(str(m.sub))
	return text

func _mode_button(m: Dictionary, _default_color: Color) -> Button:
	var small: bool = m.has("row")
	var b := neon_button(_mode_text(m), BUTTON, 24 if small else 30, 100 if m.has("sub") else 84)
	b.pressed.connect(_on_mode.bind(m))
	return b

func _on_mode(m: Dictionary) -> void:
	if _dragged():
		return
	start_mode(m)

func _on_resume() -> void:
	if _dragged():
		return
	hide_home()
	if cfg.has("resume"):
		cfg.resume.call()
	_refit()

func _on_quick() -> void:
	if _dragged():
		return
	var last := _last_mode()
	if not last.is_empty():
		start_mode(last)

func _on_group(multi: bool) -> void:
	if not _dragged():
		_open_setup(multi)

func _mode_key(m: Dictionary) -> String:
	return str(m.get("key", m.get("text", "")))

## The mode Quick Play would start, or {} if none (or it no longer exists).
func _last_mode() -> Dictionary:
	var key := str(_prefs.get("last", ""))
	if key == "":
		return {}
	for m in _solo + _multi:
		if _mode_key(m) == key:
			return m
	return {}

## The app sizes each screen to fit when it opens -- while the Landing was
## showing. A game screen that only appears now is measured again, so
## nothing wider than the phone is cut off.
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
		"color": BUTTON, "action": _invite_friend}

func _invite_friend() -> void:
	var online: Node = cfg.get("online")
	online.lobby.auto_start({"mode": "invite"})

# ---------- setup screens (STANDARDS §4 / §5) ----------

## Single player or Multiplayer setup: the game's own pickers, then its ways
## to play. The last one played starts out picked; tapping the picked one
## again (or ▶ Start) starts it. Built fresh each time, so pickers show the
## current choice.
func _open_setup(multi: bool) -> void:
	var modes: Array = _multi if multi else _solo
	var color: Color = BUTTON
	var heading := str(cfg.get("multi_heading" if multi else "solo_heading", ""))
	var title_text: String = tr(heading) if heading != "" else (tr("👥 Multiplayer") if multi else tr("🎮 Single player"))
	var parts := _overlay(title_text, color, true)
	var body: VBoxContainer = parts[1]
	var col: VBoxContainer = parts[2]
	if cfg.has("extra"):
		cfg.extra.call(body)
	body.add_child(_section(tr("Choose how to play")))
	var last := _last_mode()
	var chosen := {"m": last if modes.has(last) else modes[0]}
	var group := ButtonGroup.new()
	var row: HBoxContainer = null
	var row_id = null
	for m in modes:
		var b := neon_button(_mode_text(m), BUTTON, 24 if m.has("row") else 28, 96 if m.has("sub") else 80)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = m == chosen.m
		_style_toggle(b, BUTTON)
		b.pressed.connect(_on_setup_pick.bind(m, chosen))
		if m.has("row"):
			if row == null or m.row != row_id:
				row = HBoxContainer.new()
				row.add_theme_constant_override("separation", 14)
				body.add_child(row)
				row_id = m.row
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
		else:
			row = null
			row_id = null
			body.add_child(b)
	var start := neon_button("▶  " + tr("Start"), GO, 32, 90)
	start.pressed.connect(_on_setup_start.bind(chosen))
	col.add_child(start)
	_show_overlay(parts[0])

func _on_setup_pick(m: Dictionary, chosen: Dictionary) -> void:
	if chosen.m == m:
		start_mode(m)
	else:
		chosen.m = m

func _on_setup_start(chosen: Dictionary) -> void:
	start_mode(chosen.m)

# ---------- How to Play ----------

func _build_info_overlay() -> void:
	var parts := _overlay(tr("❓ How to Play"), BUTTON)
	info_overlay = parts[0]
	var body: VBoxContainer = parts[1]
	if consts.has("GOAL"):
		_info_section(body, tr("🎯 Goal"), [consts.GOAL], GO)
	if consts.has("HOW"):
		_info_section(body, tr("📋 How to Play"), consts.HOW, BUTTON)
	if consts.has("TIPS"):
		_info_section(body, tr("💡 Tips"), consts.TIPS, BUTTON)

func _info_section(body: VBoxContainer, heading: String, lines: Array, color: Color) -> void:
	body.add_child(label(heading, 30, color))
	for line in lines:
		body.add_child(label(("•  " if lines.size() > 1 else "") + tr(line), 25, WHITE, true, false))
	body.add_child(gap(8))

# ---------- Statistics ----------

func _build_stats_overlay() -> void:
	var parts := _overlay(tr("📊 Statistics"), BUTTON)
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
		stats_box.add_child(_row(_stat_label(k), _stat_value(k, stats[k]), WHITE, BUTTON))
		rows += 1
	var w := int(stats.get("Wins", 0))
	var played := w + int(stats.get("Losses", 0)) + int(stats.get("Draws", 0))
	if played > 0:
		stats_box.add_child(_row(tr("Win rate"), "%d%%" % roundi(100.0 * w / played), WHITE, BUTTON))
		rows += 1
	if rows == 0:
		stats_box.add_child(label(tr("Play a game and your records will show up here.") if info
			else tr("Update the app to keep statistics."), 24, DIM, true))
	_show_overlay(stats_overlay)

func _stat_label(key: String) -> String:
	return info._label(key) if info and info.has_method("_label") else tr(key)

func _stat_value(key: String, v: Variant) -> String:
	if "time" in key.to_lower():
		var t := int(round(float(v)))
		return "%d:%02d" % [int(t / 60), t % 60]
	return str(int(round(float(v))))

# ---------- Achievements (GameInfo, app v0.25+) ----------

func _build_achievements_overlay() -> void:
	var parts := _overlay(tr("🏅 Achievements"), BUTTON)
	ach_overlay = parts[0]
	ach_box = parts[1]

## All / Earned / Locked (STANDARDS §3b), progress bars on locked counters.
func _show_achievements() -> void:
	_clear(ach_box)
	var rows: Array = info.achievement_rows()
	var have := rows.filter(func(r): return r.unlocked).size()
	ach_box.add_child(label(tr("%d of %d unlocked") % [have, rows.size()], 30, BUTTON, true, true))
	ach_box.add_child(choice_row(["All", "Earned", "Locked"], ach_filter, _on_ach_filter, BUTTON))
	ach_box.add_child(gap(4))
	var shown := 0
	for r in rows:
		if (ach_filter == 1 and not r.unlocked) or (ach_filter == 2 and r.unlocked):
			continue
		ach_box.add_child(_badge(r))
		shown += 1
	if shown == 0:
		ach_box.add_child(label(tr("None yet — keep playing!") if ach_filter == 1 else tr("All unlocked!"), 24, DIM, true, true))
	_show_overlay(ach_overlay)

func _on_ach_filter(i: int) -> void:
	ach_filter = i
	_show_achievements()

func _badge(r: Dictionary) -> Control:
	var secret: bool = bool(r.get("hidden", false)) and not r.unlocked
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BUTTON, 0.12) if r.unlocked else Color(1, 1, 1, 0.03)
	sb.border_color = Color(BUTTON, 0.8) if r.unlocked else Color(1, 1, 1, 0.1)
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
	col.add_child(label("???" if secret else str(r.title), 27, BUTTON if r.unlocked else WHITE, true))
	col.add_child(label(tr("Keep playing to find out.") if secret else str(r.desc), 22, DIM, true))
	if not r.unlocked and not secret and float(r.progress) > 0.0:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.value = 100.0 * float(r.progress)
		var fill := StyleBoxFlat.new()
		fill.bg_color = BUTTON
		fill.set_corner_radius_all(5)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(1, 1, 1, 0.08)
		back.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", back)
		col.add_child(bar)
	if r.unlocked:
		row.add_child(label("✓", 32, GO))
	return panel

# ---------- Leaderboard ----------

func _build_leaderboard_overlay() -> void:
	var parts := _overlay(tr("🏆 Leaderboard"), BUTTON)
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
	if _board_key() == "none":
		return
	var a := _auth()
	var mine = _my_board_value()
	if a and mine != null and int(mine) > 0 and a.is_logged_in() and a.has_method("submit_score"):
		a.submit_score(str(consts.get("ID", "")), int(mine))

func _show_leaderboard() -> void:
	_show_overlay(lb_overlay)
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
		var b := neon_button(tr(["🌍 Everyone", "👥 Friends"][i]), BUTTON, 24, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if (i == 1) == lb_friends:
			var on := neon_box(BUTTON, "pressed")
			on.bg_color = Color(BUTTON, 0.4)
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
	# The reply can land after the game was closed (removed, not yet freed).
	if not is_instance_valid(lb_box) or not is_inside_tree() or _auth() == null:
		return
	_clear(lb_box)
	var a := _auth()
	var tabs := _board_tabs()
	if tabs:
		lb_box.add_child(tabs)
	lb_box.add_child(label(_stat_label(_board_key()), 30, BUTTON))
	var mine = _my_board_value()
	if mine != null:
		lb_box.add_child(label(tr("You: %s") % _stat_value(_board_key(), mine), 27, GO))
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
			_stat_value(_board_key(), r.get("score", 0)), GO if is_me else WHITE, BUTTON, is_me))
	lb_box.add_child(gap(10))
	if a and not a.is_logged_in():
		lb_box.add_child(label(tr("Sign in (hub ⚙ Options) to put your best score on the board."), 23, DIM, true))
	if cfg.has("board_note"):
		lb_box.add_child(label(tr(str(cfg.board_note)), 23, DIM, true))

# ---------- Options (STANDARDS §7) ----------

## This game's choices first, then the app-wide settings (the same values as
## the hub's Options: changing one here changes it everywhere).
func _show_options() -> void:
	var parts := _overlay(tr("⚙ Options"), BUTTON, true)
	var body: VBoxContainer = parts[1]
	if _has_skins():
		body.add_child(_section(tr("Look")))
		body.add_child(choice_row(["Classic", "💀 Voodoo"], 1 if skin_name() == "voodoo" else 0, _on_skin_pick, BUTTON))
		body.add_child(label(tr("Classic: the game's traditional colours. Voodoo: neon on black, with skulls."), 22, DIM, true))
	if ResourceLoader.exists(ORIENTATION_PATH):
		body.add_child(_section(tr("Screen")))
		var rot := neon_button(tr("🔄 Rotate Screen"), BUTTON, 26, 70)
		rot.pressed.connect(_rotate)
		body.add_child(rot)
	var last := _last_mode()
	if not last.is_empty():
		body.add_child(_section(tr("Quick Play")))
		body.add_child(label(tr(str(last.get("text", ""))).strip_edges(), 25, WHITE, true))
		body.add_child(label(tr("Whatever you start from a setup screen becomes Quick Play."), 22, DIM, true))
	var s := get_node_or_null("/root/Settings")
	if s:
		body.add_child(gap(6))
		body.add_child(label(tr("These settings are app-wide: they change every game."), 22, DIM, true))
		if s.has_method("set_text_size") and "TEXT_SIZE_NAMES" in s:
			body.add_child(_section(tr("Text & button size")))
			body.add_child(choice_row(s.TEXT_SIZE_NAMES, int(s.text_size), _on_text_size, BUTTON))
		if s.has_method("set_vibrate"):
			body.add_child(_section(tr("Vibration")))
			body.add_child(choice_row(["On", "Off"], 0 if s.vibrate else 1, _on_vibrate, GO))
		if s.has_method("set_keep_awake"):
			body.add_child(_section(tr("Keep screen on")))
			body.add_child(choice_row(["On", "Off"], 0 if s.keep_awake else 1, _on_keep_awake, GO))
		if s.has_method("set_invites") and "INVITE_MODES" in s:
			body.add_child(_section(tr("🔔 Game invites")))
			body.add_child(choice_row(s.INVITE_MODE_NAMES, maxi(0, s.INVITE_MODES.find(s.invites)), _on_invites, BUTTON))
		if ResourceLoader.exists(SOUND_OPTIONS_PATH):
			body.add_child(_section(tr("🔊 Sound")))
			body.add_child(load(SOUND_OPTIONS_PATH).new(s.DARK if "DARK" in s else s.palette(), false))
	_show_overlay(parts[0])

## "classic" or "voodoo" for this game: the player's pick in Options, else
## the game's own older choice, else the app-wide skull mode (off = Classic).
func skin_name() -> String:
	if _prefs.has("skin"):
		return str(_prefs.skin)
	var g := get_parent()
	if g and g.has_method("_current_skin"):
		return str(g._current_skin())
	return "voodoo" if ResourceLoader.exists(VOODOO_PATH) and load(VOODOO_PATH).is_on() else "classic"

func _has_skins() -> bool:
	var g := get_parent()
	return g != null and (bool(cfg.get("retro", false)) or g.has_method("_set_skin") or (g.has_method("_set_voodoo") and ResourceLoader.exists(VOODOO_PATH)))

func _skin_on() -> bool:
	return skin_name() == "voodoo"

func _on_skin_pick(i: int) -> void:
	_prefs["skin"] = "voodoo" if i == 1 else "classic"
	_save_prefs()
	_push_skin()

func _push_skin() -> void:
	var g := get_parent()
	if g == null:
		return
	if g.has_method("_set_skin"):
		g._set_skin(skin_name())
	elif cfg.get("retro", false):
		_set_retro(skin_name() != "voodoo")
	elif g.has_method("_set_voodoo"):
		g._set_voodoo(skin_name() == "voodoo")

## Once the game has built itself: games with skins get theirs; older
## skull-mode games only when this game's pick differs from the app-wide one.
func _apply_skin_pref() -> void:
	var g := get_parent()
	if g == null:
		return
	if g.has_method("_set_skin"):
		g._set_skin(skin_name())
	elif cfg.get("retro", false):
		_set_retro(skin_name() != "voodoo")
	elif _prefs.has("skin") and g.has_method("_set_voodoo") and ResourceLoader.exists(VOODOO_PATH):
		var want: bool = str(_prefs.skin) == "voodoo"
		if want != bool(load(VOODOO_PATH).is_on()):
			g._set_voodoo(want)

## Classic for neon-native games (arcade, party, quiz): a screen filter, no
## game code. Faint glow halos and tinted glass fall to the dark background,
## and every saturated colour snaps to a flat retro-arcade primary. Games
## opt in with `"retro": true` in the config; Voodoo = the plain neon look.
const RETRO_SHADER := """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
vec3 snap(float h) {
	if (h < 0.035 || h >= 0.96) return vec3(0.84, 0.16, 0.16);
	if (h < 0.11) return vec3(0.94, 0.54, 0.11);
	if (h < 0.19) return vec3(0.96, 0.79, 0.05);
	if (h < 0.45) return vec3(0.16, 0.62, 0.29);
	if (h < 0.58) return vec3(0.12, 0.66, 0.74);
	if (h < 0.72) return vec3(0.12, 0.36, 0.85);
	if (h < 0.86) return vec3(0.48, 0.25, 0.69);
	return vec3(0.88, 0.27, 0.48);
}
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	float a = smoothstep(0.14, 0.34, mx);
	vec3 base = vec3(0.04, 0.05, 0.09);
	if (d < 0.2 * mx || d < 0.06) {
		COLOR = vec4(mix(base, c, a), 1.0);
	} else {
		float h;
		if (mx == c.r) h = mod((c.g - c.b) / d, 6.0) / 6.0;
		else if (mx == c.g) h = ((c.b - c.r) / d + 2.0) / 6.0;
		else h = ((c.r - c.g) / d + 4.0) / 6.0;
		COLOR = vec4(mix(base, snap(fract(h)), a), 1.0);
	}
}
"""

func _set_retro(on: bool) -> void:
	var g := get_parent()
	if g == null:
		return
	var filt := g.get_node_or_null("RetroFilter")
	var bd: Node = g.get_child(0) if g.get_child_count() > 0 else null
	if bd is ColorRect and bd.get_child_count() > 0 and bd.get_child(0) is Control:
		bd.get_child(0).visible = not on  # the faint grid
	if not on:
		if filt:
			filt.queue_free()
		return
	if filt:
		return
	# Drawn over the game but under the kit (moved to the top), so Home, the
	# setup screens, the pause menu and Options keep their own look: over
	# them the filter turned glowing buttons into flat blocks and wiped out
	# a picked button's text (owner, 2026-10-06).
	var rect := ColorRect.new()
	rect.name = "RetroFilter"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = RETRO_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	g.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.move_child(self, -1)

## Saves, then reloads the scene turned the other way (the scene's own
## orientation lock rotates once instead of undoing it).
func _rotate() -> void:
	_save_game()
	_unpause()
	var view := get_viewport_rect().size
	load(ORIENTATION_PATH).override_next(view.x <= view.y)
	get_tree().reload_current_scene()

func _on_text_size(i: int) -> void:
	var s := get_node_or_null("/root/Settings")
	if s:
		s.set_text_size(i)

func _on_vibrate(i: int) -> void:
	var s := get_node_or_null("/root/Settings")
	if s:
		s.set_vibrate(i == 0)

func _on_keep_awake(i: int) -> void:
	var s := get_node_or_null("/root/Settings")
	if s:
		s.set_keep_awake(i == 0)

func _on_invites(i: int) -> void:
	var s := get_node_or_null("/root/Settings")
	if s:
		s.set_invites(str(s.INVITE_MODES[i]))

## The sound card on its own (kept for games that open it themselves).
func _show_sound() -> void:
	var settings = get_node_or_null("/root/Settings")
	if settings == null or not ResourceLoader.exists(SOUND_OPTIONS_PATH):
		return
	var parts := _overlay(tr("🔊 Sound"), BUTTON, true)
	parts[1].add_child(load(SOUND_OPTIONS_PATH).new(settings.DARK if "DARK" in settings else settings.palette(), false))
	_show_overlay(parts[0])

# ---------- per-game choices ----------

func _prefs_path() -> String:
	return "user://landing_%s.json" % str(consts.get("ID", "game"))

func _load_prefs() -> void:
	var text := FileAccess.get_file_as_string(_prefs_path())
	var parsed = JSON.parse_string(text) if text != "" else null
	_prefs = parsed if parsed is Dictionary else {}

func _save_prefs() -> void:
	var f := FileAccess.open(_prefs_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_prefs))

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
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := label(tr("Paused").to_upper(), 52, accent.lerp(Color.WHITE, 0.72))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(accent, 0.6))
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)
	box.add_child(gap(4))
	pause_grid = GridContainer.new()
	pause_grid.add_theme_constant_override("h_separation", 16)
	pause_grid.add_theme_constant_override("v_separation", 14)
	box.add_child(pause_grid)
	var specs := [[tr("▶  Resume"), GO, resume_play]]
	if cfg.has("restart"):
		specs.append([tr("↺  Restart"), BUTTON, _on_restart])
	specs.append([tr("❓ How to Play"), BUTTON, _show_overlay.bind(null, "info")])
	if _board_key() != "none":
		specs.append([tr("🏆 Leaderboard"), BUTTON, _show_leaderboard])
	specs.append([tr("📊 Statistics"), BUTTON, _show_stats])
	specs.append([tr("📸 Screenshot"), BUTTON, _screenshot])
	specs.append([tr("⚙ Options"), BUTTON, _show_options])
	specs.append([tr("🏠 %s Home") % tr(cfg.get("title", consts.get("TITLE", ""))), BUTTON, go_home])
	for s in specs:
		var b := neon_button(s[0], s[1], 28, 74)
		b.pressed.connect(s[2])
		pause_grid.add_child(b)
	_toast = label("", 24, GO, true, true)
	_toast.visible = false
	box.add_child(_toast)

## One column on a tall phone, two when it's sideways or short.
func _fit_pause_layout() -> void:
	var view := get_viewport_rect().size
	var two: bool = view.x > view.y or view.y < 1000.0
	pause_grid.columns = 2 if two else 1
	var w: float = minf(440.0, (view.x - 90.0) / 2.0) if two else minf(440.0, view.x - 80.0)
	for b in pause_grid.get_children():
		b.custom_minimum_size.x = w

func _on_restart() -> void:
	resume_play()
	cfg.restart.call()

## 📸 (STANDARDS §6): the game as it is under the menu, saved to the app's
## folder and, where Android allows it, the phone's Pictures.
func _screenshot() -> void:
	pause_overlay.visible = false
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var img: Image = get_viewport().get_texture().get_image()
	pause_overlay.visible = true
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var stamp: int = int(Time.get_unix_time_from_system())
	img.save_png("user://screenshots/%s_%d.png" % [str(consts.get("ID", "game")), stamp])
	var pictures: String = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures != "":
		img.save_png(pictures.path_join("viral_%s_%d.png" % [str(consts.get("ID", "game")), stamp]))
	_toast.text = tr("Screenshot saved!")
	_toast.visible = true
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_callback(_toast.hide)

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

## The floating ⚙ drawer is retired (STANDARDS §6): its items are in the
## pause menu and Options. Games still add it (and older apps need it for
## packs that don't have this kit yet), so the kit frees it here.
func _remove_drawer() -> void:
	var g := get_parent()
	if g == null:
		return
	for c in g.get_children():
		if c != self and c.get_script() and str(c.get_script().resource_path).ends_with("settings_drawer.gd"):
			c.queue_free()
	# GameInfo adds a floating "?" tab when it finds no drawer; How to Play is
	# on the Landing and in the pause menu here, so it goes too. Checked again
	# a frame later, since GameInfo builds it deferred as well.
	if info and "tab_button" in info and is_instance_valid(info.tab_button):
		info.tab_button.queue_free()
	if not _drawer_checked_twice:
		_drawer_checked_twice = true
		call_deferred("_remove_drawer")

# ---------- cards over the Landing / pause menu ----------

func _fixed_overlays() -> Array:
	return [info_overlay, stats_overlay, lb_overlay, ach_overlay]

func _open_overlays() -> Array:
	var out: Array = []
	for c in get_children():
		if c is ColorRect and c != pause_overlay and c.has_meta("nav") and c.visible and not c.is_queued_for_deletion():
			out.append(c)
	return out

func _any_overlay_open() -> bool:
	return not _open_overlays().is_empty()

func _close_top_overlay() -> void:
	var open := _open_overlays()
	if not open.is_empty():
		_close_overlay(open[-1])

func _close_overlays() -> void:
	for o in _open_overlays():
		_close_overlay(o)

func _close_overlay(o: Control) -> void:
	if o.get_meta("temporary", false):
		o.queue_free()
	else:
		o.hide()

## Shows a card on top, its corner button reading 🏠 Home over the Landing
## (N2) or ‹ Back over the pause menu. `which` = "info" for How to Play
## (so it can be bound before the card exists).
func _show_overlay(o: Control, which: String = "") -> void:
	if which == "info":
		o = info_overlay
	if o == null:
		return
	var nav: Button = o.get_meta("nav")
	nav.text = ("‹  " + tr("Back")) if pause_overlay.visible else tr("🏠 Home")
	move_child(o, get_child_count() - 1)
	o.visible = true

# ---------- building blocks ----------

## A full-screen card: a top bar (🏠 Home / ‹ Back + title), a scrolling
## body, and room under it for a fixed button. Returns [overlay, body,
## column]. `temporary` cards free themselves when closed.
func _overlay(title_text: String, color: Color, temporary: bool = false) -> Array:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.025, 0.05, 1.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.add_to_group("modal_overlay")
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 28)
	overlay.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	col.add_child(bar)
	var nav := neon_button(tr("🏠 Home"), BUTTON, 22, 58)
	nav.custom_minimum_size.x = 150
	nav.pressed.connect(_close_overlay.bind(overlay))
	bar.add_child(nav)
	var title := label(title_text, 38, WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_outline_color", Color(color, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	bar.add_child(title)
	var balance := Control.new()
	balance.custom_minimum_size.x = 150
	bar.add_child(balance)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	overlay.set_meta("nav", nav)
	overlay.set_meta("temporary", temporary)
	return [overlay, body, col]

## The picked look for a toggle button (setup screens, choice rows).
func _style_toggle(b: Button, color: Color) -> void:
	var on := neon_box(color, "pressed")
	on.bg_color = Color(color, 0.45)
	on.set_border_width_all(3)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)

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
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
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
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", WHITE)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.6))
	t.set_color("font_color", "Label", WHITE)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(PANEL, 0.97)
	panel.border_color = Color(BUTTON, 0.7)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(18)
	panel.shadow_color = Color(BUTTON, 0.25)
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
	var col := Color(BUTTON, 0.07)
	var x := fmod(c.size.x / 2.0, step)
	while x < c.size.x:
		c.draw_line(Vector2(x, 0), Vector2(x, c.size.y), col, 1.0)
		x += step
	var y := 0.0
	while y < c.size.y:
		c.draw_line(Vector2(0, y), Vector2(c.size.x, y), col, 1.0)
		y += step

## Card games (STANDARDS §9): the shared green felt behind Landing and play.
## Every other game without its own art gets the shared dark leather --
## except the arcade games, which keep backgrounds of their own (owner,
## 2026-10-07: "they all need their OWN backgrounds"). OWN_BG_GAMES is the
## manifest's Arcade category; `hub.py check` keeps the two in step.
const FELT_GAMES := ["solitaire", "blackjack", "war", "crazy_eights", "go_fish", "gin_rummy",
	"spider", "freecell", "pyramid", "speed", "memory", "tri_peaks", "hearts", "video_poker",
	"sevens", "rummy", "spades"]
const OWN_BG_GAMES := ["geometry_wars", "snake", "block_drop", "paddle_ball", "brick_breaker",
	"bird_hop", "alien_attack", "frog_crossing", "gem_match", "simon", "whack_a_mole",
	"reaction_test", "bubble_pop", "rock_blaster", "city_defense", "maze_muncher", "moon_lander",
	"stack_tower", "sky_hop", "air_hockey", "barrel_climb", "cannon_duel", "crypt_crawler",
	"star_runner", "sky_raider", "mini_golf", "pool"]
const BG_DIR := "res://media/hub/backgrounds/"  # in the APK (v0.34+); older apps: no texture

## The scene's game id, from res://scenes/games/<id>/<id>.tscn ("" if unknown).
static func _scene_game_id() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return ""
	var parts: PackedStringArray = tree.current_scene.scene_file_path.split("/")
	return parts[parts.size() - 2] if parts.size() >= 2 else ""

## The shared texture for this game (`id` "" = the running scene's), or null
## for an arcade game (its own background) or on an app that doesn't have it yet.
static func bg_texture(id: String = "") -> Texture2D:
	if id == "":
		id = _scene_game_id()
	if id in OWN_BG_GAMES:
		return null
	var path: String = BG_DIR + ("felt.jpg" if id in FELT_GAMES else "leather.jpg")
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

## The play-screen backdrop, as a game's first child. Child 0 is the faint
## grid (games hide it for Classic); the shared texture, when the app has
## it, covers it and stays in both skins.
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
	var tex := bg_texture()
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(pic)
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
