extends Control

## Arrow Cube (working title) -- arrows drawn on a 3D shape. Tap one: it slides out the way it
## points if nothing is in its way. Clear the shape. 500 levels, then Endless. No timer.
## Rules + generator: arrow_cube_engine.gd. 3D view: arrow_cube_world.gd (in a SubViewport).
## Design: GAME_DESIGN_ARROW_CUBE.md.
##
## Landing menu style: S2 Center Ring (docs/MENU_STYLES.md) -- the last two games added use
## "stickers" (mini_golf_3d) and S3 rail (hesperia).

const MenuStyles = preload("res://scripts/games/arrow_cube/menu_styles.gd")
const E = preload("res://scripts/games/arrow_cube/arrow_cube_engine.gd")
const World = preload("res://scripts/games/arrow_cube/arrow_cube_world.gd")
const HELP = preload("res://scripts/games/arrow_cube/arrow_cube_help.gd")
const HomeKit = preload("res://scripts/games/arrow_cube/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const I18N_PATH := "res://scripts/games/arrow_cube/arrow_cube_i18n.gd"
## Levels baked by tools/arrow_cube_bake.gd. A missing level (or a stale file) is generated
## from the same seed at runtime, so the game works without the file.
const LEVELS_PATH := "res://games/arrow_cube/levels.json"

const SAVE_PATH := "user://arrow_cube_save.json"
const PROGRESS_PATH := "user://arrow_cube_progress.json"
const CLOUD_SAVE := "res://scripts/common/cloud_save.gd"  # [NEW 2026-11-24] STANDARDS §18; APK-side, load() guarded
var cloud: Node = null

## Levels where a new piece first shows up -> the one line that explains it.
const INTROS := {
	25: "New: blue edges. An arrow bends over them and goes on along the next face.",
	45: "New: two-way lines. Tap near the end you want it to leave from.",
	80: "New: red stops. An arrow slides onto the stop and waits there; the stop is used up.",
	120: "New: forks. Every head needs a clear way out, then the whole fork flies.",
}

var info = null
var home
var engine: E
var world: World
var view: SubViewport
var title_label: Label
var hearts_label: Label
var feedback_label: Label
var undo_btn: Button
var safe_btn: Button
var remove_btn: Button
var end_dialog: ColorRect
var fail_dialog: ColorRect
var feedback_timer: Timer
var my_buttons: Array = []
var skin: String = "classic"

var mode: String = "levels"   # levels | endless
var level: int = 1
var helps_used: int = 0
var playing: bool = false
var remove_mode: bool = false
var progress: Dictionary = {}
var _baked: Array = []
var _baked_loaded: bool = false

func _ready() -> void:
	if ResourceLoader.exists(I18N_PATH):
		load(I18N_PATH).install(self)
	Orientation.lock_portrait()
	engine = E.new()
	_load_progress()
	if ResourceLoader.exists(CLOUD_SAVE):
		cloud = load(CLOUD_SAVE).new()
		cloud.setup("arrow_cube", PROGRESS_PATH, _progress_score, _load_progress)
		add_child(cloud)
	_build_ui()
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, 1, 2.0)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()

	var vc := SubViewportContainer.new()
	vc.stretch = true
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vc)
	vc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = SubViewport.new()
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	vc.add_child(view)
	world = World.new()
	view.add_child(world)
	world.tapped.connect(_on_arrow_tapped)
	world.tapped_empty.connect(_on_empty_tap)

	var touch := Control.new()
	touch.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.gui_input.connect(world.handle_input)
	add_child(touch)
	touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bar)
	var pause_btn := _button("⏸", _on_pause, false)
	pause_btn.custom_minimum_size = Vector2(76, 64)
	bar.add_child(pause_btn)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	bar.add_child(title_label)
	hearts_label = Label.new()
	hearts_label.add_theme_font_size_override("font_size", 30)
	hearts_label.custom_minimum_size = Vector2(120, 0)
	hearts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(hearts_label)

	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 23)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size = Vector2(0, 70)
	root.add_child(feedback_label)

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gap)

	var row_margin := MarginContainer.new()
	row_margin.add_theme_constant_override("margin_bottom", 30)
	row_margin.add_theme_constant_override("margin_left", 12)
	row_margin.add_theme_constant_override("margin_right", 12)
	row_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row_margin)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_margin.add_child(actions)
	undo_btn = _button(tr("↶ Undo"), _on_undo)
	actions.add_child(undo_btn)
	safe_btn = _button(tr("👁 Safe"), _on_safe)
	actions.add_child(safe_btn)
	remove_btn = _button(tr("✂ Remove"), _on_remove)
	actions.add_child(remove_btn)
	actions.add_child(_button("⟲", world.reset_view, false))

	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.timeout.connect(_clear_feedback)
	add_child(feedback_timer)

	end_dialog = UI.build_dialog(tr("Cleared!"), [
		{"text": tr("Next level"), "action": _next_level},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)
	fail_dialog = UI.build_dialog(tr("Out of hearts"), [
		{"text": tr("↺ Try again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(fail_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S2 Center Ring; colours: ice cyan on deep blue.
		"landing": "ring",
		"landing_style": MenuStyles,
		"title_colors": [Color("e9f6ff"), Color("27e0d0"), Color("38b6ff")],
		"landing_colors": [Color("07102a"), Color("16245a")],
		"menu_color": Color("27e0d0"),
		"help": HELP,
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Turn the shape. Find the arrow with a clear way out.",
		"logo": _draw_home_logo,
		"modes": [
			# {"text": "▶ Levels", "sub": "500 levels · collect stars", "color": HomeKit.CYAN, "action": _start_levels},
			# [CHANGED 2026-11-24, owner] never state the level count (STANDARDS §18)
			{"text": "▶ Levels", "sub": "Collect stars", "color": HomeKit.CYAN, "action": _start_levels},
			{"text": "📋 Level Select", "sub": "Replay any level you have reached", "action": _open_level_select, "card": true},
			{"text": "♾ Endless", "sub": "New shapes forever · after level 500", "color": HomeKit.PURPLE, "action": _start_endless},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [
			{"text": "👁 Safe", "how": "Lights up every arrow that can leave right now.", "action": _safe_now},
			{"text": "✂ Remove", "how": "Pick any arrow and it's gone, even a stuck one.", "action": _remove_now},
		],
		"board": "Levels cleared",
		"board_note": "Levels cleared in Levels mode.",
	})
	add_child(home)
	home.track_help_button(safe_btn, tr("👁 Safe"))
	home.track_help_button(remove_btn, tr("✂ Remove"))
	if info:
		add_child(info)
	_set_skin(skin)

func _button(text: String, action: Callable, wide: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(72, 72)
	if wide:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	my_buttons.append(b)
	return b

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

# ---------- looks ----------

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if world:
		world.set_skin(skin)
	var ink := Color("1f2a3a") if skin == "classic" else Color.WHITE
	if title_label:
		title_label.add_theme_color_override("font_color", ink)
	for b in my_buttons:
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			if skin == "classic":
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color("2f74d0").darkened(0.15 if st == "pressed" else 0.0).lightened(0.08 if st == "hover" else 0.0)
				if st == "disabled":
					sb.bg_color = Color("8fa9cc")
				sb.set_corner_radius_all(18)
				sb.border_color = Color("1d4f96")
				sb.set_border_width_all(2)
				b.add_theme_stylebox_override(st, sb)
			else:
				b.remove_theme_stylebox_override(st)
		for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			if skin == "classic":
				b.add_theme_color_override(fc, Color.WHITE)
			else:
				b.remove_theme_color_override(fc)
		if skin == "classic":
			b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.7))
		else:
			b.remove_theme_color_override("font_disabled_color")
	if hearts_label:
		_update_hud()

func _ink_soft() -> Color:
	return Color("2c5d8f") if skin == "classic" else Color(0.95, 0.88, 0.6)

## An isometric cube with two arrows on it (one bends over the edge).
func _draw_home_logo(c: Control) -> void:
	var s := minf(c.size.y * 0.36, 70.0)
	var o := c.size / 2.0 + Vector2(0, s * 0.5)        # bottom-front corner
	var up := Vector2(0, -s)
	var r := Vector2(s * 0.866, -s * 0.5)               # along the right face
	var l := Vector2(-s * 0.866, -s * 0.5)              # along the left face
	var top := PackedVector2Array([o + up, o + up + r, o + up + r + l, o + up + l])
	var left := PackedVector2Array([o, o + l, o + l + up, o + up])
	var right := PackedVector2Array([o, o + r, o + r + up, o + up])
	c.draw_colored_polygon(top, Color("2a3a86"))
	c.draw_colored_polygon(left, Color("16245a"))
	c.draw_colored_polygon(right, Color("1d2f70"))
	for poly in [top, left, right]:
		var pts: PackedVector2Array = poly.duplicate()
		pts.append(poly[0])
		c.draw_polyline(pts, Color(HomeKit.CYAN, 0.7), 2.0, true)
	# pink: across the top face; gold: along the top, over the edge, down the right face
	var a0 := o + up + l * 0.75 + r * 0.25
	var a1 := o + up + l * 0.75 + r * 0.8
	c.draw_line(a0, a1, HomeKit.PINK, 5.0, true)
	_logo_head(c, a1, r.normalized(), HomeKit.PINK)
	var b0 := o + up + l * 0.3 + r * 0.2
	var b1 := o + up + r * 0.2
	var b2 := b1 - up * 0.65
	c.draw_polyline(PackedVector2Array([b0, b1, b2]), HomeKit.GOLD, 5.0, true)
	_logo_head(c, b2, Vector2.DOWN, HomeKit.GOLD)

func _logo_head(c: Control, tip: Vector2, d: Vector2, col: Color) -> void:
	var side := Vector2(-d.y, d.x) * 9.0
	c.draw_colored_polygon(PackedVector2Array([tip + d * 6.0, tip - d * 10.0 + side, tip - d * 10.0 - side]), col)

# ---------- levels ----------

func _level_data(lv: int) -> Dictionary:
	if not _baked_loaded:
		_baked_loaded = true
		if FileAccess.file_exists(LEVELS_PATH):
			var d = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH))
			if d is Dictionary and int(d.get("gen", 0)) == E.GEN_VERSION and d.get("levels") is Array:
				_baked = d.levels
	if lv >= 1 and lv <= _baked.size() and _baked[lv - 1] is Dictionary:
		return _baked[lv - 1]
	return {}

func _load_level(lv: int) -> void:
	var d := _level_data(lv)
	if d.is_empty() or not engine.load_dict(d):
		engine.load_level(lv)
	engine.level_no = lv

func _start_levels() -> void:
	mode = "levels"
	_start_level(clampi(int(progress.get("next", 1)), 1, E.LEVEL_COUNT))

func _endless_open() -> bool:
	return progress.stars.has(str(E.LEVEL_COUNT))

func _start_endless() -> void:
	if not _endless_open():
		_start_levels()
		_feedback(tr("Endless opens after level %d. Here's your next level.") % E.LEVEL_COUNT, _ink_soft(), 4.0)
		return
	mode = "endless"
	_start_level(E.LEVEL_COUNT + int(progress.get("endless", 0)) + 1)

func _start_level(lv: int) -> void:
	level = lv
	SaveUtil.delete(SAVE_PATH)
	_load_level(lv)
	helps_used = 0
	_begin_play()
	_clear_feedback()
	if lv == 1 and int(progress.stars.get("1", 0)) == 0:
		_feedback(tr("Tap an arrow with a clear way out. Drag to turn the shape."), _ink_soft(), 0.0)
	elif INTROS.has(lv) and mode == "levels":
		_feedback(tr(INTROS[lv]), _ink_soft(), 7.0)

func _begin_play() -> void:
	playing = true
	remove_mode = false
	end_dialog.visible = false
	fail_dialog.visible = false
	world.interactive = true
	world.show_level(engine)
	_update_hud()
	_save_game()

func _restart() -> void:
	_start_level(level)

func _next_level() -> void:
	if mode == "levels" and level >= E.LEVEL_COUNT:
		_start_endless()
	else:
		_start_level(level + 1)

func _update_hud() -> void:
	if mode == "endless":
		title_label.text = tr("Endless %d") % (level - E.LEVEL_COUNT)
	else:
		title_label.text = tr("Level %d") % level
	hearts_label.text = "♥".repeat(engine.hearts) + "♡".repeat(E.MAX_HEARTS - engine.hearts)
	hearts_label.add_theme_color_override("font_color", Color("e03131") if skin == "classic" else Color("ff4f4f"))
	undo_btn.disabled = engine.history.is_empty()

# ---------- play ----------

func _on_arrow_tapped(id: int, head: int) -> void:
	if not playing:
		return
	world.clear_highlight()
	var a := engine.arrow_by_id(id)
	if a.is_empty():
		return
	if remove_mode:
		remove_mode = false
		if engine.pluck(id):
			world.fly_away(id, int(a.heads[0].dir))
			_sfx("powerup")
			_clear_feedback()
			_after_move()
		return
	var r := engine.tap(id, head)
	if not r.moved:
		var path: Array = []
		for p in r.paths:
			path += p
		world.bump(id, int(a.heads[clampi(head, 0, a.heads.size() - 1)].dir), path)
		_sfx("invalid")
		_buzz(40)
		_update_hud()
		_save_game()
		if engine.lost():
			_on_lost()
		return
	if r.result == "exit":
		world.fly_away(id, int(r.get("dir", a.heads[0].dir)))
		_sfx("place")
		_buzz(12)
		if info:
			info.add("Arrows cleared")
	else:
		world.refresh_arrow(id)
		_sfx("tick")
	_after_move()

func _on_empty_tap() -> void:
	if remove_mode:
		_feedback(tr("Tap the arrow you want gone."), _ink_soft(), 0.0)

func _after_move() -> void:
	world.sync_arrows()
	_update_hud()
	if engine.won():
		_on_won()
		return
	_save_game()
	if not engine.any_move():
		_feedback(tr("No arrow can move. Undo ↶ a step, or use a help."), _ink_soft(), 0.0)
	elif feedback_timer.is_stopped() and not remove_mode and level != 1:
		_clear_feedback()

func _on_undo() -> void:
	if playing and engine.undo():
		_sfx("back")
		world.clear_highlight()
		world.sync_arrows()
		_clear_feedback()
		_update_hud()
		_save_game()

func _on_safe() -> void:
	home.try_help(_safe_now)

func _on_remove() -> void:
	home.try_help(_remove_now)

## 👁 help (STANDARDS §17): every arrow that can leave now glows; if none can, the solver's
## next move glows. Nothing is moved.
func _safe_now() -> bool:
	if not playing or engine.won():
		return false
	var ids := engine.free_arrows()
	if ids.is_empty():
		var m := engine.solve_first(3000)
		if m.is_empty() or int(m[0]) < 0:
			return false
		ids = [int(m[0])]
	world.set_highlight(ids, world.col("safe"))
	helps_used += 1
	_sfx("powerup")
	_save_game()
	return true

## ✂ help: the next arrow tapped is removed.
func _remove_now() -> bool:
	if not playing or engine.won():
		return false
	remove_mode = true
	helps_used += 1
	_feedback(tr("Tap the arrow you want gone."), _ink_soft(), 0.0)
	return true

# ---------- end of level ----------

## 3 = no bump, no help; 2 = one bump or one help; 1 = cleared.
func _stars() -> int:
	if engine.bumps == 0 and helps_used == 0:
		return 3
	if engine.bumps + helps_used <= 1:
		return 2
	return 1

func _on_won() -> void:
	playing = false
	world.interactive = false
	world.celebrate()
	_sfx("win")
	SaveUtil.delete(SAVE_PATH)
	var stars := _stars()
	var note := "★".repeat(stars) + "☆".repeat(3 - stars)
	if mode == "levels":
		var key := str(level)
		progress.stars[key] = maxi(int(progress.stars.get(key, 0)), stars)
		progress.next = maxi(int(progress.next), mini(level + 1, E.LEVEL_COUNT))
	else:
		progress.endless = maxi(int(progress.get("endless", 0)), level - E.LEVEL_COUNT)
		note = tr("Endless %d cleared") % (level - E.LEVEL_COUNT)
	_save_progress()
	if info:
		info.add("Wins")
		if mode == "levels":
			info.high("Levels cleared", progress.stars.size())
			info.high("Highest level", level)
			info.high("Total stars", _total_stars())
			info.high("3-star levels", _count_stars(3))
		else:
			info.high("Endless cleared", int(progress.endless))
		info.celebrate(tr("Cleared!"))
	end_dialog.get_meta("message_label").text = note
	await get_tree().create_timer(0.9, false).timeout
	if not playing:
		end_dialog.visible = true

func _on_lost() -> void:
	playing = false
	world.interactive = false
	SaveUtil.delete(SAVE_PATH)
	if info:
		info.add("Losses")
	fail_dialog.get_meta("message_label").text = tr("Every bump cost a heart. Try the level again.")
	fail_dialog.visible = true

func _total_stars() -> int:
	var t := 0
	for k in progress.stars:
		t += int(progress.stars[k])
	return t

func _count_stars(at_least: int) -> int:
	var t := 0
	for k in progress.stars:
		if int(progress.stars[k]) >= at_least:
			t += 1
	return t

# ---------- feedback ----------

## `secs` 0 keeps the text until something replaces it.
func _feedback(text: String, c: Color, secs: float = 3.0) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", c)
	feedback_timer.stop()
	if secs > 0.0:
		feedback_timer.start(secs)

func _clear_feedback() -> void:
	feedback_label.text = ""

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

func _buzz(ms: int) -> void:
	var st = get_node_or_null("/root/Settings")
	if st and st.has_method("buzz"):
		st.buzz(ms)

# ---------- save / progress ----------

func _load_progress() -> void:
	var d = SaveUtil.read(PROGRESS_PATH)
	progress = d if d is Dictionary else {}
	if not progress.get("stars") is Dictionary:
		progress.stars = {}
	if not progress.has("next"):
		progress.next = 1

func _save_progress() -> void:
	SaveUtil.write(PROGRESS_PATH, progress)
	if cloud:
		cloud.saved()
		cloud.report_completion(_cloud_cleared(), E.LEVEL_COUNT)

func _cloud_cleared() -> int:
	var n := 0
	for k in progress.stars:
		if int(progress.stars[k]) > 0 and int(k) <= E.LEVEL_COUNT:
			n += 1
	return n

## Cloud vs device (STANDARDS §18): the copy with more levels cleared (Endless too), then stars.
func _progress_score(d: Dictionary) -> int:
	var st = d.get("stars", {})
	var n := 0
	if st is Dictionary:
		for k in st:
			if int(st[k]) > 0:
				n += 4 + int(st[k])
	return n + int(d.get("endless", 0)) * 4

# ---------- level select [NEW 2026-11-24, owner: replay without losing progress] ----------

func _open_level_select() -> void:
	var parts: Array = home.card("📋 Level Select")
	var body: VBoxContainer = parts[1]
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for n in range(1, clampi(int(progress.get("next", 1)), 1, E.LEVEL_COUNT) + 1):
		var b := Button.new()
		var st := int(progress.stars.get(str(n), 0))
		b.text = str(n) if st == 0 else "%d
%s" % [n, "★".repeat(st)]
		b.custom_minimum_size = Vector2(0, 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick_level.bind(n, parts[0]))
		grid.add_child(b)
	home.show_card(parts[0])

func _pick_level(n: int, card: Control) -> void:
	home.close_card(card)
	SaveUtil.delete(SAVE_PATH)
	home.play_now(_start_level.bind(n))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if engine == null or not playing or engine.won():
		return
	var d := engine.to_save()
	d["mode"] = mode
	d["helps"] = helps_used
	SaveUtil.write(SAVE_PATH, d)

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if not d is Dictionary:
		return ""
	var lv := int(d.get("level", 1))
	if str(d.get("mode", "levels")) == "endless":
		return tr("Endless %d") % (lv - E.LEVEL_COUNT)
	return tr("Level %d") % lv

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if not d is Dictionary or not engine.from_save(d):
		_start_levels()
		return
	mode = str(d.get("mode", "levels"))
	level = engine.level_no
	helps_used = int(d.get("helps", 0))
	_begin_play()
