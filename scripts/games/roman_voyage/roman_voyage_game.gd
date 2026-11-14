extends Control

## Voyage of Aeneas: lead the last Trojans from fallen Troy to Italy, stop by
## stop through Virgil's Aeneid (public domain). Every stop is a choice; ships,
## crew, food, the gods' favor and Juno's wrath carry from one to the next.
## Original game; the story is the 2,000-year-old myth, the text is ours.
## Modes: Voyage (Easy / Normal / Hard) and the Daily Voyage (same seed for everyone).
##
## Landing menu style: S2 Center Ring (docs/MENU_STYLES.md): a ritual, temple-like
## look for a myth game, and not one of the last two games' styles
## (Hover Duel rail, Bridge Master slabs).

const E = preload("res://scripts/games/roman_voyage/roman_voyage_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const MenuStyles = preload("res://scripts/games/roman_voyage/menu_styles.gd")
const HomeKit = preload("res://scripts/games/roman_voyage/home_kit.gd")
const SoundLib = preload("res://scripts/games/roman_voyage/sound_lib.gd")
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/roman_voyage/roman_voyage_help.gd")
const SAVE_PATH := "user://roman_voyage_save.json"

const LEVELS := ["Easy", "Normal", "Hard"]
## Each god's emblem: Latin name in Roman capitals (U written V) and a colour.
const GODS := {
	"juno": ["IVNO", Color("b0306a")], "venus": ["VENVS", Color("e0708a")],
	"neptune": ["NEPTVNVS", Color("2a8ac0")], "jupiter": ["IVPPITER", Color("d8a531")],
	"apollo": ["APOLLO", Color("f0c040")], "mars": ["MARS", Color("c0392b")],
	"penates": ["PENATES", Color("a07850")], "harpy": ["HARPYIAE", Color("6a5a7a")],
	"cyclops": ["CYCLOPES", Color("8a5a3a")], "lar": ["MANES", Color("7a8a9a")],
	"iris": ["IRIS", Color("8a6ad0")], "sibyl": ["SIBYLLA", Color("c0a060")],
	"faunus": ["FAVNVS", Color("5a8a3a")], "circe": ["CIRCE", Color("7a3aa0")],
	"somnus": ["SOMNVS", Color("3a4a8a")],
}
const SKIN := {
	"classic": {"sky": [Color("f3d9a4"), Color("6fa8c8")], "sea": [Color("2a6f9a"), Color("123a5a")],
		"panel": Color("f5ecd8"), "ink": Color("2a1d10"), "gold": Color("a8781a"), "hull": Color("5a3418"),
		"sail": Color("efe4c8"), "storm": [Color("4a4a58"), Color("22252e")], "bg": Color("7a2a1a")},
	"voodoo": {"sky": [Color("1a0a2a"), Color("05121e")], "sea": [Color("06303a"), Color("020a10")],
		"panel": Color("0d0b14"), "ink": Color("e8f6ff"), "gold": Color("29e6ff"), "hull": Color("ff2bd6"),
		"sail": Color("b8ff3a"), "storm": [Color("1a0018"), Color("000000")], "bg": Color("05040a")},
}

var info = null
var home
var engine
var skin := "classic"
var level: int = 1
var daily := false
var started := false
var result_recorded := false
var showing_result := false
var before := {}
var result_god := "neptune"  # god of the stop whose result is shown
var result_place := ""  # English place name of the stop whose result is shown
var t := 0.0

var bg: ColorRect
var scene_view: Control
var stats_row: HBoxContainer
var stat_labels := {}
var place_label: Label
var body_label: Label
var choice_box: VBoxContainer
var result_box: VBoxContainer
var result_label: Label
var delta_label: Label
var fact_label: Label
var map_view: Control
var end_dialog: Control
var card_panel: PanelContainer
var sail_btn: Button

func _ready() -> void:
	preload("res://scripts/games/roman_voyage/roman_voyage_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = E.new()
	engine.reset(1, 1)
	_build_ui()
	_render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _process(delta: float) -> void:
	t += delta
	if scene_view and is_visible_in_tree():
		scene_view.queue_redraw()

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(72, 60)
	pause_btn.pressed.connect(_on_pause)
	top.add_child(pause_btn)
	stats_row = HBoxContainer.new()
	stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_theme_constant_override("separation", 2)
	top.add_child(stats_row)
	for k in [["ships", "⛵", "Ships"], ["crew", "👥", "Crew"], ["food", "🌾", "Food"], ["favor", "🌿", "Favor"], ["wrath", "⚡", "Wrath"]]:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", -4)
		var n := Label.new()
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_font_size_override("font_size", 24)
		v.add_child(n)
		var cap := Label.new()
		cap.text = tr(k[2])
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_font_size_override("font_size", 14)
		cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cap.clip_text = true
		v.add_child(cap)
		stats_row.add_child(v)
		stat_labels[k[0]] = [n, cap, k[1]]

	scene_view = Control.new()
	scene_view.custom_minimum_size = Vector2(0, 250)
	scene_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_view.draw.connect(_draw_scene)
	root.add_child(scene_view)

	card_panel = PanelContainer.new()
	card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(card_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_panel.add_child(scroll)
	var inner := MarginContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 14)
	scroll.add_child(inner)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	inner.add_child(col)

	place_label = Label.new()
	place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place_label.add_theme_font_size_override("font_size", 28)
	place_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(place_label)
	body_label = _wrap_label(21)
	col.add_child(body_label)
	choice_box = VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 8)
	col.add_child(choice_box)

	result_box = VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 10)
	col.add_child(result_box)
	result_label = _wrap_label(21)
	result_box.add_child(result_label)
	delta_label = _wrap_label(22)
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_box.add_child(delta_label)
	fact_label = _wrap_label(18)
	result_box.add_child(fact_label)
	var go := Button.new()
	go.text = tr("Sail on ▶")
	go.custom_minimum_size = Vector2(0, 64)
	go.pressed.connect(_sail_on)
	result_box.add_child(go)
	sail_btn = go

	map_view = Control.new()
	map_view.custom_minimum_size = Vector2(0, 52)
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.draw.connect(_draw_map)
	root.add_child(map_view)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Sail again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in LEVELS.size():
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard"][i], "row": "voyage",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_voyage.bind(i)})
	modes.append({"text": "📅 Daily Voyage", "sub": "Same seas for everyone today (Normal)", "action": _new_daily})
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S2 Center Ring; colours imperial purple + gold on night sea.
		"landing": "ring",
		"landing_style": MenuStyles,
		"title_colors": [Color("e8b84a"), Color("f5ecd8"), Color("b0306a")],
		"landing_colors": [Color("1a0f2a"), Color("0a2a40")],
		"menu_color": Color("e8b84a"),
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": Color("e8b84a"),
		"solo_heading": "Voyage",
		"subtitle": "Lead the last Trojans from burning Troy to Italy. The gods are watching.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [{"text": "🌹 Venus' gift", "how": "Your mother Venus sends one new ship, 15 crew and 5 food.", "action": _help_venus}],
		"board": "Best score",
	})
	add_child(home)
	if info:
		add_child(info)
	_apply_skin()

func _wrap_label(size: int) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _draw_home_logo(c: Control) -> void:
	# A temple front: pediment, four columns, steps, in gold.
	var s := minf(c.size.x, c.size.y)
	var o := c.size / 2.0
	var w := s * 0.8
	var gold := Color("e8b84a")
	var top := o.y - s * 0.32
	c.draw_colored_polygon(PackedVector2Array([Vector2(o.x - w / 2, top + s * 0.16), Vector2(o.x, top), Vector2(o.x + w / 2, top + s * 0.16)]), gold)
	c.draw_rect(Rect2(o.x - w / 2, top + s * 0.18, w, s * 0.05), gold)
	for i in 4:
		var x := o.x - w * 0.38 + i * w * 0.253
		c.draw_rect(Rect2(x - s * 0.035, top + s * 0.25, s * 0.07, s * 0.36), gold)
	c.draw_rect(Rect2(o.x - w / 2, top + s * 0.62, w, s * 0.05), gold)
	c.draw_rect(Rect2(o.x - w * 0.56, top + s * 0.68, w * 1.12, s * 0.05), gold)

# ---------- skins ----------

func _set_skin(s: String) -> void:
	skin = "voodoo" if s == "voodoo" else "classic"
	_apply_skin()

func _current_skin() -> String:
	return skin

func _apply_skin() -> void:
	var k: Dictionary = SKIN[skin]
	bg.color = k.bg
	var sb := StyleBoxFlat.new()
	sb.bg_color = k.panel
	sb.border_color = k.gold
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	card_panel.add_theme_stylebox_override("panel", sb)
	for l in [body_label, result_label, delta_label]:
		l.add_theme_color_override("font_color", k.ink)
	fact_label.add_theme_color_override("font_color", k.ink.lerp(k.gold, 0.45))
	place_label.add_theme_color_override("font_color", k.gold)
	for key in stat_labels:
		stat_labels[key][0].add_theme_color_override("font_color", Color("f5ecd8") if skin == "classic" else Color("29e6ff"))
		stat_labels[key][1].add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	if sail_btn:
		_style_button(sail_btn)
	for b in choice_box.get_children():
		_style_button(b)
	if scene_view:
		scene_view.queue_redraw()
		map_view.queue_redraw()

## Choice buttons on the parchment card: terracotta with cream text (Classic),
## dark with a neon edge (Voodoo). Contrast >= 4.5:1 in both.
func _style_button(b: Button) -> void:
	var classic := skin == "classic"
	var fill := Color("8a2e1a") if classic else Color("12101c")
	var edge := Color("a8781a") if classic else Color("29e6ff")
	var text := Color("fbf3e0") if classic else Color("e8f6ff")
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		if state == "hover" or state == "pressed":
			sb.bg_color = fill.lightened(0.12)
		if state == "disabled":
			sb.bg_color = Color(fill, 0.45)
		if state == "focus":
			sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = edge
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override(state, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, text)
	b.add_theme_color_override("font_disabled_color", Color(text, 0.6))
	b.add_theme_font_size_override("font_size", 21)

# ---------- flow ----------

func _new_voyage(lv: int) -> void:
	level = lv
	daily = false
	_restart()

func _new_daily() -> void:
	level = 1
	daily = true
	_restart()

func _restart() -> void:
	SaveUtil.delete(SAVE_PATH)
	var seed_value := randi()
	if daily:
		var d := Time.get_date_dict_from_system()
		seed_value = int(d.year) * 10000 + int(d.month) * 100 + int(d.day)
	engine.reset(level, seed_value)
	started = true
	result_recorded = false
	showing_result = false
	end_dialog.visible = false
	_render()
	_music()

func _pick(i: int) -> void:
	if showing_result or engine.over:
		return
	before = {"ships": engine.ships, "crew": engine.crew, "food": engine.food, "favor": engine.favor, "wrath": engine.wrath}
	var ev: Dictionary = engine.event()
	if not engine.pick(i):
		return
	showing_result = true
	result_place = str(ev.get("place", "Open sea"))
	result_god = str(ev.get("god", "neptune"))
	var lost_ship: bool = engine.ships < int(before.ships)
	if lost_ship:
		SoundLib.play(self, "impact/wood_heavy")
	elif engine.favor > int(before.favor):
		SoundLib.play(self, "impact/bell_heavy", -8.0)
	else:
		SoundLib.play(self, "rpg/book_close", -4.0)
	if info and ev.has("fact"):
		info.add("Myths met")
	var txt := tr(engine.last_res)
	if engine.starved:
		txt += "\n" + tr("Food ran out on the way: some men desert.")
	result_label.text = txt
	delta_label.text = _delta_text()
	fact_label.text = ("📜 " + tr(ev.fact)) if ev.has("fact") else ""
	fact_label.visible = ev.has("fact")
	_render()
	_save_game()

func _delta_text() -> String:
	var parts: Array = []
	for k in [["ships", "⛵"], ["crew", "👥"], ["food", "🌾"], ["favor", "🌿"], ["wrath", "⚡"]]:
		var d: int = int(engine.get(k[0])) - int(before[k[0]])
		if d != 0:
			parts.append("%s%d %s" % ["+" if d > 0 else "−", absi(d), k[1]])
	return "   ".join(parts) if parts.size() else tr("No change")

func _sail_on() -> void:
	showing_result = false
	if engine.over:
		_finish()
		return
	_render()
	_save_game()

func _finish() -> void:
	SaveUtil.delete(SAVE_PATH)
	started = false
	var msg := ""
	if engine.won:
		var sc: int = engine.score()
		msg = tr("You reached Italy with %d ships and %d men.") % [engine.ships, engine.crew] + "\n" + tr("Score: %d") % sc
		SoundLib.play(self, "jingles/win_victory", -4.0)
	elif engine.lost_reason == "ships":
		msg = tr("Your last ship sinks. Troy's story ends at sea.")
		SoundLib.play(self, "jingles/lose_failed", -4.0)
	else:
		msg = tr("No one is left to row. Troy's story ends at sea.")
		SoundLib.play(self, "jingles/lose_failed", -4.0)
	if info and not result_recorded:
		result_recorded = true
		info.result("win" if engine.won else "loss")
		if engine.won:
			info.high("Best score", engine.score())
			info.high("Most ships at the Tiber", engine.ships)
			info.add("Voyages won (%s)" % LEVELS[engine.diff])
			if daily:
				info.add("Daily voyages won")
			if engine.flags.has("underworld"):
				info.add("Underworld visits")
		msg += "\n\n" + info.summary(["Wins", "Losses", "Best score"])
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	_music(true)

# ---------- rendering ----------

func _render() -> void:
	for key in stat_labels:
		var v: int = int(engine.get(key))
		stat_labels[key][0].text = "%s%d" % [stat_labels[key][2], v]
	var ev: Dictionary = engine.event()
	var place: String = tr(ev.place) if ev.has("place") else tr("Open sea")
	if showing_result:
		place = tr(result_place)
	place_label.text = place.to_upper()
	body_label.text = tr(ev.text)
	body_label.visible = not showing_result
	choice_box.visible = not showing_result
	result_box.visible = showing_result
	for ch in choice_box.get_children():
		ch.queue_free()
	if not showing_result:
		for c in engine.choices():
			var b := Button.new()
			var text: String = tr(c.choice.text)
			if c.choice.has("need"):
				text += "  (" + tr("costs %d 🌿") % int(c.choice.need.favor) + ")"
			b.text = text
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size = Vector2(0, 60)
			b.disabled = not c.ok
			b.pressed.connect(_pick.bind(c.index))
			_style_button(b)
			choice_box.add_child(b)
	scene_view.queue_redraw()
	map_view.queue_redraw()

func _draw_scene() -> void:
	var c := scene_view
	var w := c.size.x
	var h := c.size.y
	var k: Dictionary = SKIN[skin]
	var ev: Dictionary = engine.event()
	var stormy: bool = ev.get("storm", false) and not showing_result
	var sky: Array = k.storm if stormy else k.sky
	var horizon := h * 0.58
	# Sky gradient in bands (draw_rect is cheap).
	for i in 12:
		c.draw_rect(Rect2(0, horizon * i / 12.0, w, horizon / 12.0 + 1), (sky[0] as Color).lerp(sky[1], i / 11.0))
	var sea: Array = k.sea
	for i in 8:
		c.draw_rect(Rect2(0, horizon + (h - horizon) * i / 8.0, w, (h - horizon) / 8.0 + 1), (sea[0] as Color).lerp(sea[1], i / 7.0))
	# Wave lines.
	var wl := PackedVector2Array()
	for row in 4:
		var y := horizon + 10 + row * (h - horizon) / 4.0
		for x in range(0, int(w), 24):
			var yy := y + sin(t * 1.5 + x * 0.05 + row) * 3.0
			wl.append(Vector2(x, yy))
			wl.append(Vector2(x + 14, yy - 2))
	c.draw_multiline(wl, Color(1, 1, 1, 0.25), 2.0)
	if stormy and fmod(t, 3.0) < 0.12:
		c.draw_rect(Rect2(0, 0, w, horizon), Color(1, 1, 1, 0.35))
		var bolt := PackedVector2Array([Vector2(w * 0.3, 0), Vector2(w * 0.27, horizon * 0.4), Vector2(w * 0.33, horizon * 0.45), Vector2(w * 0.28, horizon)])
		c.draw_polyline(bolt, Color(1, 1, 0.8), 3.0)
	# The fleet: one little ship per ship left (up to 10), bobbing.
	var n: int = mini(engine.ships, 10)
	for i in n:
		var col := i % 5
		var row := i / 5
		var sx := w * 0.1 + col * w * 0.12 + row * w * 0.06
		var sy := horizon + 30 + row * 40 + sin(t * 2.0 + i) * 3.0
		_ship(c, Vector2(sx, sy), 1.0 - row * 0.15, k)
	# The god of this stop: a round emblem with the Latin name.
	var g: Array = GODS.get(result_god if showing_result else ev.get("god", "neptune"), GODS.neptune)
	var center := Vector2(w * 0.8, h * 0.34)
	var r := minf(h * 0.26, w * 0.13)
	c.draw_circle(center, r + 4, k.gold)
	c.draw_circle(center, r, g[1])
	var font := get_theme_default_font()
	var fs := int(r * 0.42)
	var name_str: String = g[0]
	var tw := font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > r * 1.8:
		fs = int(fs * r * 1.8 / tw)
		tw = font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string(font, center + Vector2(-tw / 2.0, fs * 0.35), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _ship(c: Control, p: Vector2, s: float, k: Dictionary) -> void:
	s *= 1.7 if c == scene_view else 1.0
	var hull := PackedVector2Array([p + Vector2(-16, 0) * s, p + Vector2(16, 0) * s, p + Vector2(11, 7) * s, p + Vector2(-11, 7) * s])
	c.draw_colored_polygon(hull, k.hull)
	c.draw_line(p, p + Vector2(0, -22) * s, k.hull, 2.0)
	c.draw_rect(Rect2(p + Vector2(-9, -20) * s, Vector2(18, 14) * s), k.sail)

func _draw_map() -> void:
	var c := map_view
	var w := c.size.x
	var y := c.size.y * 0.4
	var k: Dictionary = SKIN[skin]
	var n := E.STOPS.size()
	var x0 := 16.0
	var x1 := w - 16.0
	c.draw_line(Vector2(x0, y), Vector2(x1, y), Color(k.gold, 0.6), 2.0)
	for i in n:
		var x := x0 + (x1 - x0) * i / float(n - 1)
		var done: bool = i < engine.stop
		c.draw_rect(Rect2(x - 5, y - 5, 10, 10), k.gold if done else Color(1, 1, 1, 0.35))
	var px: float = x0 + (x1 - x0) * float(engine.progress())
	_ship(c, Vector2(px, y - 4), 0.7, k)
	var font := get_theme_default_font()
	c.draw_string(font, Vector2(x0, c.size.y - 2), tr("Troy"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.8))
	var it := tr("Italy")
	var iw := font.get_string_size(it, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	c.draw_string(font, Vector2(x1 - iw, c.size.y - 2), it, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.8))

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.over:
		return
	SaveUtil.write(SAVE_PATH, {"engine": engine.to_dict(), "daily": daily, "showing": showing_result,
		"result": result_label.text, "delta": delta_label.text, "fact": fact_label.text, "place": result_place})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not d.has("engine"):
		return ""
	var e: Dictionary = d.engine
	var lv := clampi(int(e.get("diff", 1)), 0, 2)
	var head := tr("Daily Voyage") if bool(d.get("daily", false)) else tr("Voyage") + " (" + tr(LEVELS[lv]) + ")"
	var st: Dictionary = E.STOPS[clampi(int(e.get("stop", 0)), 0, E.STOPS.size() - 1)]
	return head + " · " + tr(st.place)

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not d.has("engine"):
		_new_voyage(1)
		return
	engine.from_dict(d.engine)
	level = engine.diff
	daily = bool(d.get("daily", false))
	started = true
	result_recorded = false
	end_dialog.visible = false
	showing_result = bool(d.get("showing", false))
	if showing_result:
		result_place = str(d.get("place", "Open sea"))
		result_label.text = str(d.get("result", ""))
		delta_label.text = str(d.get("delta", ""))
		fact_label.text = str(d.get("fact", ""))
		fact_label.visible = fact_label.text != ""
	_render()
	_music()

# ---------- sound / helps ----------

func _help_venus() -> bool:
	if not started or engine.over:
		return false
	if not engine.venus_help():
		return false
	SoundLib.play(self, "impact/bell_heavy", -6.0)
	_render()
	_save_game()
	return true

func _music(stop: bool = false) -> void:
	var m = get_node_or_null("/root/Music")
	if m == null:
		return
	if stop:
		if m.has_method("stop"):
			m.stop(1.5)
		return
	m.play("calm", self, randi() % 4, 1.5)
