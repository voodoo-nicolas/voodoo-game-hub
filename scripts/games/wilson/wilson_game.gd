extends Control

## Beached (codename wilson) in the hub: the Landing (Landing kit) and the island under it.
## Design: the owner's docs on Drive "viral game hub/wilson" (GDD, CRAFTING, QUESTS, DIALOGUE, KICKOFF);
## data: games/wilson/data/*.json; what was decided where the docs are silent: docs/wilson/DECISIONS.md.
##
## Layers: sky (wilson_skyview.gd, canvas layer -2) -> the island (wilson_world.gd, canvas layer -1 with
## the day/night CanvasModulate and the fire light) -> HUD (this node) -> the kit (Landing, pause).
## Time: the game clock is the real clock (+ the debug panel's offset and speed). `_process` advances the
## engine online; a gap of more than a few seconds (app closed, Landing or pause shown) is caught up
## offline (chill rules) and the journal shows what Johnny did while you were away.

const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + look, copied into this game's folder by `hub.py sync`.
const HomeKit = preload("res://scripts/games/wilson/home_kit.gd")
const HELP = preload("res://scripts/games/wilson/wilson_help.gd")
const Engine_ = preload("res://scripts/games/wilson/wilson_engine.gd")
const D = preload("res://scripts/games/wilson/wilson_data.gd")
const Quests = preload("res://scripts/games/wilson/wilson_quests.gd")
const Projects = preload("res://scripts/games/wilson/wilson_projects.gd")
const Pastimes = preload("res://scripts/games/wilson/wilson_pastimes.gd")
const Astro = preload("res://scripts/games/wilson/wilson_sky.gd")
const World = preload("res://scripts/games/wilson/wilson_world.gd")
const SkyView = preload("res://scripts/games/wilson/wilson_skyview.gd")
const Debug = preload("res://scripts/games/wilson/wilson_debug.gd")
const Slot = preload("res://scripts/games/wilson/wilson_slot.gd")
const Castaway = preload("res://scripts/games/wilson/wilson_castaway.gd")
const HUD_ART := "res://games/wilson/art/hud/"
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const SAVE_PATH := "user://wilson_save.json"
const DEBUG_PATH := "user://wilson_debug.json"
const ART := "res://games/wilson/art/landing_logo.webp"
const PAD_PATH := "res://scripts/common/pad/pad_controller.gd"  # APK-side: packs on older apps keep taps only
const PAD_SPEED := 170.0       # plate pixels a second at full stick
const PAD_REACH := 140.0       # how far A looks for something to use
const FOCUS_REACH := 110.0     # how close he must be for the glow
const ACCENT := Color("ffb35a")
## A gap longer than this between frames (real seconds) is caught up as "away".
const AWAY_GAP := 4.0

const ICONS := {"haul": "📦", "gather": "✋", "shake": "🌴", "chop": "🪓", "fish": "🎣", "seawater": "🥥",
	"craft": "🔨", "fuel": "🔥", "light": "🔥", "tally": "✏", "shore": "🌊", "inspect": "👂", "sleep": "💤", "nap": "😴", "pastime": "🧘"}
const BAR_COLORS := {"hp": Color("e0524a"), "food": Color("e8a23a"), "energy": Color("f2d43c"), "water": Color("4ab4e8")}
const BAR_ICONS := {"hp": "❤", "food": "🐟", "energy": "⚡", "water": "💧"}

var info = null  # GameInfo; null on apps without it
var home         # HomeKit
var engine = null
var started := false
var clock_offset := 0.0   # debug: seconds added to the real clock
var time_scale := 1.0     # debug: x1 / x60 / x3600
var _last_ms := 0

var _sky_layer: CanvasLayer
var _skyview
var _world_layer: CanvasLayer
var _tint: CanvasModulate
var _glow_layer: CanvasLayer
var _glow: Sprite2D
var world = null
var _hud: Control
var _bars := {}
var _mood: Label
var _clock: Label
var _quest: Label
var _queue_box: VBoxContainer
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_until := 0.0
var _bubble_queue: Array = []
var _toast: Label
var _toast_until := 0.0
var _sleep_row: Control = null
var _craft_btn: Button = null
var pad: Control = null          # the shared Pad (older apps do not have it: taps and the 💤 😴 buttons only)
var _pad_busy_said := false
var _bars_panel: PanelContainer
var _bar_rows := {}              # bar id -> its row (hidden until the opening introduces it)
var _hud_btns := {}              # journal / bag / craft / pause -> button
var _tut_card: PanelContainer = null
var _tut_card_label: Label
var _tut_vis := {}               # HUD part -> shown now (so the Pad is only touched on a change)
var _tut_walked := 0.0
var _tut_a := false
var _popup: PanelContainer = null
var _panel: PanelContainer = null
var _debug = null
var _clock_taps: Array = []
var _sync_timer := 0.0
var _stage_pos := Vector2.ZERO
var _stage_scale := 1.0
const CAM_ZOOM := 1.5
var _cam := Vector2.ZERO          # camera focus (plate pixels)
var _walk_kind := ""
var _combine_from := ""   # bag: an item picked with "🔗 Combine", waiting for the second one
var auto_pause := true    # tools/shot_wilson.gd turns this off (its window loses focus)

func _ready() -> void:
	Orientation.lock_landscape()
	preload("res://scripts/games/wilson/wilson_i18n.gd").install(self)
	_load_debug()
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme(ACCENT)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": ACCENT,
		"subtitle": "One island. One castaway. Zero rescue.",
		# "logo": _draw_home_logo,   (owner, 2026-11-09: the art already has the title, no small image over it)
		"art_only_title": true,
		"art": ART,
		"art_title": [0.0, 0.26],  # "Beached" is painted in the art (landing_logo.webp = landing + the owner's logo)
		"solo_heading": "🏝 Island",
		"modes": [{"text": "🏝 New island", "sub": "Day 1: wake up on the beach", "action": new_island}],
		"save_path": SAVE_PATH,
		"resume": _continue_game,
		"restart": new_island,
		"board": "Most days survived",
		"board_note": "Days on the island, counted from Day 1.",
		"quick_with_save": false,
		"helps": [{"text": "⏩ Hurry up", "how": "Finishes what the castaway is doing right now.", "action": _help_hurry}],
	})
	add_child(home)
	if info:
		add_child(info)
	# Must stay the last child so its tab sits above any dialog (the kit frees it).
	add_child(SettingsDrawer.new())

func _draw_home_logo(c: Control) -> void:
	var mid := c.size / 2.0
	var u := minf(c.size.x, c.size.y * 1.6) / 220.0
	HomeKit.glow_circle(c, mid + Vector2(40, -30) * u, 18.0 * u, ACCENT, 3.0, 0.1)
	HomeKit.glow_polyline(c, PackedVector2Array([mid + Vector2(-80, 30) * u, mid + Vector2(-30, 10) * u,
		mid + Vector2(30, 10) * u, mid + Vector2(80, 30) * u]), Color("4fc3ff"), 3.0, false)
	HomeKit.glow_polyline(c, PackedVector2Array([mid + Vector2(-10, 12) * u, mid + Vector2(-4, -40) * u,
		mid + Vector2(-30, -48) * u]), Color("6fdc6f"), 3.0, false)

# ================================================================ islands

## 🏝 New island (and ↺ Restart, and the debug reset): first pick the castaway's look (GDD / DIALOGUE:
## male or female, 8 sheets), then Day 1 on the beach, now. The old save stays until a look is picked.
func new_island() -> void:
	_pick_look(_new_island_look)

## New island, step 1 done (the look): now ask for the name, then start.
func _new_island_look(look_id: String) -> void:
	_ask_name(_start_island.bind(look_id), "")

## What the castaway is called on screen (the player's own words; "Castaway" until they type one).
func castaway_name() -> String:
	return engine.cname if engine and engine.cname != "" else tr("Castaway")

## A small card with a text box (16 characters). `done` gets the cleaned name ("" = skipped).
func _ask_name(done: Callable, current: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.name = "NamePicker"
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_BEGIN     # top of the screen: the phone keyboard covers the lower half
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	var l := Label.new()
	l.text = tr("What's your name?")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", ACCENT)
	col.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var edit := LineEdit.new()
	edit.max_length = 16
	edit.text = current
	edit.placeholder_text = tr("Your name")
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_font_size_override("font_size", 26)
	edit.custom_minimum_size = Vector2(300, 52)
	row.add_child(edit)
	var ok := Button.new()
	ok.text = tr("OK")
	ok.custom_minimum_size = Vector2(110, 52)
	ok.pressed.connect(_on_name_done.bind(card, edit, done, true))
	row.add_child(ok)
	var skip := Button.new()
	skip.text = tr("Skip")
	skip.custom_minimum_size = Vector2(110, 52)
	skip.pressed.connect(_on_name_done.bind(card, edit, done, false))
	row.add_child(skip)
	edit.text_submitted.connect(_on_name_submitted.bind(card, edit, done))
	add_child(card)
	if home:
		move_child(card, home.get_index())
	edit.grab_focus()

func _on_name_submitted(_t: String, card: Control, edit: LineEdit, done: Callable) -> void:
	_on_name_done(card, edit, done, true)

func _on_name_done(card: Control, edit: LineEdit, done: Callable, use: bool) -> void:
	var n: String = Engine_.clean_name(edit.text) if use else ""
	card.queue_free()
	done.call(n)

func _change_name(n: String) -> void:
	engine.cname = n
	_save_game()
	after_change()

func _start_island(name_text: String, look_id: String) -> void:
	SaveUtil.delete(SAVE_PATH)
	_set_clock_to_dawn()
	engine = Engine_.new()
	engine.reset(now(), _tz(), _default_hemisphere(), 0, look_id)
	engine.tut = 0      # the guided opening: the HUD builds up one part at a time
	engine.cname = name_text
	engine.checkin()
	engine.weather_auto = true
	engine._weather_tick()
	started = true
	_start_play()
	_bubble_queue.append(D.LINES.day1[0])
	_save_game()

## A new island starts just after sunrise, bright (owner, 2026-11-09): the game clock jumps to ~25 min after dawn.
func _set_clock_to_dawn() -> void:
	var probe = Engine_.new()
	probe.reset(now(), _tz(), _default_hemisphere(), 0, "male1")
	for i in 2:      # twice: sunrise moves a minute or two between days
		var rise: float = probe.sunrise_h(now())
		var delta := fposmod(rise + 0.4 - probe.hour(now()), 24.0) * 3600.0
		clock_offset += delta
	save_debug()

## A card with the 8 looks; `done` gets the look id.
func _pick_look(done: Callable) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.name = "LookPicker"
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	var l := Label.new()
	l.text = tr("Who washed up?")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", ACCENT)
	col.add_child(l)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var center := CenterContainer.new()
	center.add_child(grid)
	col.add_child(center)
	var vs := get_viewport_rect().size
	var h := clampf((vs.y - 180.0) / 2.0, 90.0, 240.0)
	for look_id in Castaway.LOOKS:
		var b := TextureButton.new()
		var path := "res://games/wilson/art/chars/%s_idle.webp" % look_id
		if ResourceLoader.exists(path):
			b.texture_normal = load(path)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(h * 0.55, h)
		b.pressed.connect(_on_look_picked.bind(card, look_id, done))
		grid.add_child(b)
	add_child(card)
	if home:
		move_child(card, home.get_index())

func _on_look_picked(card: Control, look_id: String, done: Callable) -> void:
	card.queue_free()
	done.call(look_id)

func _change_look(look_id: String) -> void:
	engine.look = look_id
	after_change()

func _continue_game() -> void:
	engine = Engine_.new()
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary) or not (d.get("engine") is Dictionary) or not engine.from_dict(d.engine):
		new_island()
		return
	started = true
	_start_play()
	catch_up(false)
	engine.checkin()
	_handle_events(engine.pop_events())
	if engine.journal.size() > 0:
		_bubble_queue.append(D.LINES.wake[randi() % D.LINES.wake.size()])

func _start_play() -> void:
	_clear_play()
	_sky_layer = CanvasLayer.new()
	_sky_layer.layer = -3
	add_child(_sky_layer)
	_skyview = SkyView.new()
	_sky_layer.add_child(_skyview)
	_world_layer = CanvasLayer.new()
	_world_layer.layer = -2
	add_child(_world_layer)
	_tint = CanvasModulate.new()
	_world_layer.add_child(_tint)
	world = World.new()
	_world_layer.add_child(world)
	world.setup(engine)
	_glow_layer = CanvasLayer.new()
	_glow_layer.layer = -1
	add_child(_glow_layer)
	_glow = Sprite2D.new()
	var g := GradientTexture2D.new()
	g.width = 256
	g.height = 256
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.35, Color(1, 1, 1, 0.45))
	g.gradient = grad
	_glow.texture = g
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.visible = false
	_glow_layer.add_child(_glow)
	_build_hud()
	move_child(_hud, home.get_index())
	_add_pad()
	_place_johnny_now()
	_last_ms = Time.get_ticks_msec()
	_music("calm")
	_layout()
	_refresh_hud()

func _clear_play() -> void:
	for n in [_sky_layer, _world_layer, _glow_layer, _hud, pad]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_sky_layer = null
	_world_layer = null
	_hud = null
	pad = null
	world = null
	_popup = null
	_panel = null
	_debug = null

# ================================================================ clock

func now() -> float:
	return Time.get_unix_time_from_system() + clock_offset

func _tz() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

## Southern hemisphere for countries there (GDD §4: "default by locale; Argentina = southern").
func _default_hemisphere() -> String:
	var loc := OS.get_locale()
	for c in ["_AR", "_CL", "_UY", "_PY", "_BO", "_PE", "_BR", "_AU", "_NZ", "_ZA"]:
		if loc.ends_with(c):
			return "south"
	return "north"

## Plays the island up to now as "away" (offline rules), then shows what happened.
func catch_up(show_away := true) -> void:
	if engine == null:
		return
	var before: int = engine.journal.size()
	engine.advance(now(), false)
	var evs: Array = engine.pop_events()
	var last_say := ""
	for e in evs:
		if e.type == "say":
			last_say = e.text
	if last_say != "":
		_bubble_queue = [last_say]
	after_change()
	_place_johnny_now()
	if show_away and engine.journal.size() > before:
		_show_away(engine.journal.slice(before))

func _process(dt: float) -> void:
	if not started or engine == null or world == null:
		return
	var ms := Time.get_ticks_msec()
	var gap := (ms - _last_ms) / 1000.0
	_last_ms = ms
	if gap > AWAY_GAP:
		catch_up(true)
	else:
		clock_offset += dt * (time_scale - 1.0)
		engine.advance(now(), true)
		_handle_events(engine.pop_events())
	_sync_timer -= dt
	if _sync_timer <= 0.0:
		_sync_timer = 0.5
		world.sync()
		_refresh_hud()
		if _debug and _debug.visible:
			_debug.refresh()
	_layout()
	_update_sky()
	_update_johnny()
	_pad_process(dt)
	_update_focus()
	_update_marks()
	_tut_pulse()
	_update_bubble()

func after_change() -> void:
	if world:
		world.sync()
	_refresh_hud()

# ================================================================ layout + sky

## The plate covers the screen (wide phones crop a little sky and foreground sea); on screens
## narrower than 1.6:1 it fits the width and the sky / sea fill above and below.
func _layout() -> void:
	var vs := get_viewport_rect().size
	var s := maxf(vs.x / D.W, vs.y / D.H)
	if vs.x / vs.y < 1.6:
		s = vs.x / D.W
	var pos := (vs - Vector2(D.W, D.H) * s) / 2.0
	if vs.x / vs.y >= 1.6:
		pos.y = minf(0.0, (vs.y - D.H * s) * 0.35)  # keep more of the beach than of the sky
	# 50 % bigger (owner, 2026-11-09): the camera follows the castaway, clamped to the plate
	s *= CAM_ZOOM
	var foc := Vector2(D.W, D.H) / 2.0
	if world.castaway:
		foc = world.castaway.position + Vector2(0, -40)
	_cam = _cam.lerp(foc, 0.15) if _cam != Vector2.ZERO else foc
	pos = vs / 2.0 - _cam * s
	pos.x = clampf(pos.x, minf(0.0, vs.x - D.W * s), 0.0)
	pos.y = clampf(pos.y, minf(0.0, vs.y - D.H * s), 0.0)
	_stage_pos = pos
	_stage_scale = s
	world.position = pos
	world.scale = Vector2(s, s)
	_skyview.stage_pos = pos
	_skyview.stage_scale = s

func _update_sky() -> void:
	var h: float = engine.hour()
	var dy: int = engine.doy()
	var sky := Astro.sky_at(h, dy, engine.hemisphere)
	var inten: float = sky.intensity
	_skyview.sky = sky
	_skyview.stars = Astro.star_alpha(h, dy, engine.hemisphere)
	_skyview.sun = Astro.sun_arc(h, dy, engine.hemisphere)
	_skyview.moon_phase = Astro.moon_phase(engine.t)
	_skyview.moon = Astro.moon_arc(h, _skyview.moon_phase)
	_skyview.south = engine.hemisphere == "south"
	var w: String = engine.weather
	_skyview.cloudiness = {"clear": 0.2, "cloudy": 0.6, "overcast": 0.9, "drizzle": 0.8, "rain": 0.95, "storm": 1.0, "fog": 0.7}.get(w, 0.35)
	# CanvasModulate: the keyframe's light tint, dimmed by its intensity (0.55 floor keeps night playable)
	var tint: Color = Color(sky.light_tint) * lerpf(0.55, 1.0, inten)
	if w in ["overcast", "rain", "storm", "fog"]:
		tint = tint.lerp(Color(0.62, 0.66, 0.72), 0.35)
	tint.a = 1.0
	var ecl: float = engine.eclipse_amount()
	if ecl > 0.0:
		tint = tint.lerp(Color(0.18, 0.2, 0.3), ecl)
		tint.a = 1.0
	_tint.color = tint
	var night := clampf((0.85 - inten) / 0.5, 0.0, 1.0)
	var wind: float = {"wind": 1.0, "storm": 1.0, "rain": 0.6, "drizzle": 0.4}.get(w, 0.25)
	world.tick(night, float(D.SEA.get(w, 0.4)), wind)
	world.set_wave_color(Color(0.16, 0.55, 0.62) * tint)
	# the campfire's light: additive glow above the tint (daynight.json fire_light colour)
	var f = world.fire
	if f:
		var en: float = f.glow_energy()
		_glow.visible = en > 0.01
		_glow.position = _stage_pos + (f.position + Vector2(0, -24)) * _stage_scale
		var r: float = f.glow_radius() * _stage_scale
		_glow.scale = Vector2(r / 128.0, r / 128.0 * 0.7)
		var fc := Color(D.json("daynight").get("fire_light", {}).get("color", "#ffb35a"))
		_glow.modulate = Color(fc.r, fc.g, fc.b, 1.0) * Color(1, 1, 1, en * 0.55)
	else:
		_glow.visible = false

# ================================================================ the Viral Pad (stick + A B X Y)
# Stick = walk (the three depth lanes blend into a free strip), A = use what is nearest (or the
# castaway's own menu), B = close / cancel, X = nap, Y = sleep, info pill = journal, pause pill = pause.
# Taps keep working. Apps without the Pad keep the 💤 😴 buttons.

func _add_pad() -> void:
	if not ResourceLoader.exists(PAD_PATH):
		return
	pad = load(PAD_PATH).new()
	pad.layout_override = "stick_4"
	# a smaller stick + buttons tucked into the corners: the big default ring covered the wreck pile
	# (owner, 2026-11-09: "I can't click on stuff behind the joystick"). Older Pads keep the default.
	var lay = load("res://scripts/common/pad/pad_layouts.gd") if ResourceLoader.exists("res://scripts/common/pad/pad_layouts.gd") else null
	if lay and "custom_layout" in pad and lay.has_method("variant"):
		pad.custom_layout = lay.variant("stick_4", ["move", "a"], [
			{"type": "stick", "id": "move", "side": "left", "off": [105, 100], "r": 78, "knob": 38},
			{"type": "face4", "side": "right", "off": [112, 108], "gap": 56, "r": 33, "ids": ["y", "x", "b", "a"]}], "beached")
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pad)
	move_child(pad, home.get_index())       # over the world and the HUD, under the kit
	pad.button_pressed.connect(_on_pad_button)
	pad.set_state("a", {"sub": tr("USE")})
	pad.set_state("b", {"sub": tr("BACK")})
	pad.set_state("x", {"sub": tr("BAG")})
	pad.set_state("y", {"sub": tr("JOBS")})
	pad.set_state("info", {"icon": "menu"})
	if _sleep_row:
		_sleep_row.visible = false

## Where the castaway may stand: x limits blend between the three lanes (D.LANES) by depth.
static func pad_limits(y: float) -> Vector2:
	var l: Array = D.LANES
	y = clampf(y, float(l[0].y), float(l[2].y))
	var i := 0 if y <= float(l[1].y) else 1
	var f := (y - float(l[i].y)) / (float(l[i + 1].y) - float(l[i].y))
	return Vector2(lerpf(float(l[i].x0), float(l[i + 1].x0), f), lerpf(float(l[i].x1), float(l[i + 1].x1), f))

func _pad_process(dt: float) -> void:
	if pad == null or not is_instance_valid(pad) or world == null:
		return
	pad.visible = started and not _panel
	if _panel or home.is_home_visible():
		return
	var c = world.castaway
	# the face buttons (keyboard K L J I too: the Pad registers those actions)
	if Input.is_action_just_pressed("pad_a") and engine.tut_reached("a"):
		_tut_a = true
		_pad_use()
	if Input.is_action_just_pressed("pad_b") and engine.tut_reached("b"):
		_pad_back()
		if _tut_a:
			engine.tut_event("ab")
	if Input.is_action_just_pressed("pad_y") and engine.tut < 0:
		_pad_actions()
	if Input.is_action_just_pressed("pad_x") and engine.tut_reached("bag"):
		_close_popup()
		_open_bag()
	if Input.is_action_just_pressed("pad_info") and engine.tut_reached("journal"):
		_open_journal()
	var v := Input.get_vector("pad_move_left", "pad_move_right", "pad_move_up", "pad_move_down")
	if v.length() < 0.15:
		_pad_busy_said = false
		return
	if not engine.sleep.is_empty():
		engine.wake()
		after_change()
		_show_toast(tr("Woke up. Grumpily."))
		return
	if engine.busy():
		if not _pad_busy_said:
			_pad_busy_said = true
			_show_toast(tr("Busy. Tap an action in the list to cancel it."))
		return
	_close_popup()
	# Each axis on its own: walking right along a lane must never slide him up and left when the lane
	# narrows (owner, 2026-11-09: "facing the cave and walking right pushes you up and left").
	var step := v * PAD_SPEED * dt
	var np: Vector2 = c.position
	var lim0 := pad_limits(np.y)
	np.x = clampf(np.x + step.x, minf(lim0.x, np.x), maxf(lim0.y, np.x))     # never pushed back by the limit
	var ny := clampf(np.y + step.y, float(D.LANES[0].y), float(D.LANES[2].y))
	var lim1 := pad_limits(ny)
	if np.x >= lim1.x - 0.5 and np.x <= lim1.y + 0.5:
		np.y = ny
	elif absf(step.y) > 0.01 and absf(step.x) < 0.01:
		np.x = clampf(np.x, lim1.x, lim1.y)      # straight up / down at the edge: slide in along the new limit
		np.y = ny
	if engine.tut >= 0 and not _tut_vis.get("walked", false):
		_tut_walked += c.position.distance_to(np)
		if _tut_walked > 120.0:
			_tut_vis["walked"] = true
			engine.tut_event("walk")
	c.walking = false
	c.position = np
	c.pose = "walk"
	if absf(v.x) > 0.1:
		c.facing = 1.0 if v.x > 0.0 else -1.0

func _on_pad_button(id: String) -> void:
	if id == "pause":
		_pause()

## The nearest thing in reach, preferring what he is facing: {} when nothing is close.
func nearest_interactable(reach: float) -> Dictionary:
	var c = world.castaway
	var best := {}
	var bd := reach
	var goals := _objective_ids()
	for it in world.interactables():
		var d: float = c.position.distance_to(it.probe)
		var dx: float = it.probe.x - c.position.x
		if absf(dx) > 8.0 and signf(dx) != c.facing:
			d *= 1.5      # behind him counts for less
		if str(it.id) in goals:
			d *= 0.5      # the current quest target wins over a closer bystander (the barrel next to the dry fronds)
		if d < bd and str(world.hit(it.probe).type) != "":
			bd = d
			best = it
	return best

## What the current objective points at: ids from world.interactables(), plus "johnny" / "shallows",
## and "craft" when the answer is on the 🔨 button. The Day 1 checklist comes first.
func _objective_ids() -> Array:
	var ts: Dictionary = engine.tut_step()
	if not ts.is_empty():
		return ts.get("objective", [])
	var intro: Dictionary = engine.intro_step()
	if not intro.is_empty():
		match str(intro.key):
			"got:stone":
				return ["spot:stones"]
			"got:stick":
				return ["spot:sticks"]
			"got:frond":
				return ["spot:fronds"]
			"made:frond_bed":
				return ["craft"]
		return []
	match engine.quest:
		"T01":
			return ["johnny"]
		"T02":
			return ["debris:crate"]
		"T03", "T05", "T09":
			return ["craft"]
		"T04":
			return ["shallows"]
		"T06", "T07":
			return ["palm:A", "palm:B"]
		"T08":
			return ["palm:C"]
		"T10":
			return ["shore"]
		"T12":
			return ["structure:crafting_stump"]
	return []

func _update_marks() -> void:
	if world == null:
		return
	var ids := _objective_ids()
	var rects: Array = []
	var craft := false
	for id in ids:
		match str(id):
			"craft":
				craft = true
			"johnny":
				var cp: Vector2 = world.castaway.position
				rects.append(Rect2(cp + Vector2(-26, -100), Vector2(52, 104)))
			"shallows":
				rects.append(Rect2(D.SHALLOWS.pos + Vector2(-120, -40), Vector2(240, 70)))
			_:
				for it in world.interactables():
					if it.id == id:
						rects.append(it.rect)
	world.set_marks(rects if not _panel else [])
	if _craft_btn and is_instance_valid(_craft_btn):
		_craft_btn.modulate = Color(0.7, 1.0, 0.8).lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)) if craft else Color.WHITE

## Every frame: the glowing outline on what he is facing (not while busy, asleep or in a menu).
func _update_focus() -> void:
	if world == null:
		return
	if not engine.sleep.is_empty() or engine.busy() or _panel or _popup or world.castaway.walking:
		world.set_focus(Rect2())
		return
	var it := nearest_interactable(FOCUS_REACH)
	world.set_focus(it.rect if not it.is_empty() else Rect2())

## A: the nearest thing within reach is "tapped" (its menu opens, or the haul / shore starts); if
## nothing is near, the castaway's own menu.
func _pad_use() -> void:
	if _popup:
		_close_popup()
		return
	var c = world.castaway
	var best := nearest_interactable(PAD_REACH)
	if best.is_empty():
		if c.position.y > 515.0:
			_on_tap(Vector2(c.position.x, 610.0), _stage_pos + Vector2(c.position.x, 560.0) * _stage_scale)
		else:
			_show_toast(tr("Nothing close. Walk up to something."))
		return
	# A just does the thing: gather a pile, shake a palm (no list)
	var bid := str(best.id)
	if bid.begins_with("spot:"):
		_try("gather", bid.substr(5))
		return
	if bid.begins_with("palm:"):
		_try("shake", bid.substr(5))
		return
	_on_tap(best.probe, _stage_pos + (best.probe + Vector2(0, -30)) * _stage_scale)

## X: the action menu (sleep, nap, craft, bag, odd jobs, pastimes).
func _pad_actions() -> void:
	if _popup:
		_close_popup()
		return
	var c = world.castaway
	_johnny_menu(_stage_pos + (c.position + Vector2(0, -60)) * _stage_scale)

## B: close a menu, else cancel the action in progress.
func _pad_back() -> void:
	if _popup:
		_close_popup()
	elif engine.busy():
		engine.cancel(0)
		after_change()

# ================================================================ Johnny on screen

## Where `kind` on `target` happens (plate pixels).
func _stand_spot(kind: String, target: String) -> Vector2:
	match kind:
		"haul":
			return D.DEBRIS[target].stand
		"gather":
			return D.SPOTS[target].stand
		"shake", "chop":
			return D.PALM_STAND[target]
		"fish", "seawater":
			return D.SHALLOWS.stand
		"fuel", "light":
			return D.CAMP.campfire.stand
		"tally":
			return D.CAMP.crafting_stump.stand
		"shore":
			return D.SHORE.stand
		"inspect":
			return D.CAVE.stand
		"pastime":
			var st = Pastimes.get_pastime(target).get("stand", null)
			return st if st != null else (world.castaway.position if world else D.START_POS)
		"craft":
			var r := D.recipe(target)
			var st: String = str(r.get("station", "hands"))
			if r.get("out_type", "") == "structure" and D.CAMP.has(r.out):
				return D.CAMP[r.out].stand
			if D.STATION_STRUCTURE.has(st) and D.CAMP.has(D.STATION_STRUCTURE[st]):
				return D.CAMP[D.STATION_STRUCTURE[st]].stand
			if D.STATIONS.has(st):
				return D.STATIONS[st]
	return world.castaway.position if world else D.START_POS

func _bed_spot(bed: String) -> Vector2:
	match bed:
		"hammock":
			return D.CAMP.hammock.pos + Vector2(0, -6)
		"shade":
			if engine.structures.has("hammock"):
				return D.CAMP.hammock.pos + Vector2(0, -6)
			return Vector2(470, 440)
		"frond_bed":
			return D.CAMP.frond_bed.pos + Vector2(0, -4)
		"frond_shelter", "tent", "tent_mattress":
			return D.CAMP.frond_shelter.pos + Vector2(10, 4)
		"treehouse":
			return D.CAMP.treehouse.pos + Vector2(0, -4)
	return world.castaway.position if world else D.START_POS

func _place_johnny_now() -> void:
	if world == null:
		return
	var c = world.castaway
	c.walking = false
	if not engine.sleep.is_empty():
		c.position = _bed_spot(str(engine.sleep.bed)) if engine.sleep.bed != "sand" else World.walk_point(c.position)
	elif not engine.active().is_empty():
		c.position = _stand_spot(engine.active().kind, engine.active().target)

func _update_johnny() -> void:
	var c = world.castaway
	c.mood = engine.mood
	if not engine.sleep.is_empty():
		c.walking = false
		var kind := str(engine.sleep.kind)
		if kind in ["collapse", "faint"]:
			c.pose = "collapse"
		elif world.in_hammock():
			c.pose = "hammock"
			c.position = D.CAMP.hammock.pos + Vector2(0, 2)
			return
		else:
			c.pose = "sleep"
		if engine.sleep.bed != "sand":
			c.position = _bed_spot(str(engine.sleep.bed))
		return
	var a: Dictionary = engine.active()
	if a.is_empty():
		if not c.walking:
			c.pose = "idle"
		return
	var spot := _stand_spot(a.kind, a.target)
	if c.position.distance_to(spot) > 3.0:
		if not c.walking or c.target.distance_to(spot) > 3.0:
			c.walk_to(spot)
		c.pose = "walk"
		return
	if a.kind == "pastime":
		c.pose = str(Pastimes.get_pastime(a.target).get("pose", "sit"))
		return
	c.pose = {"chop": "chop", "fish": "fish", "shake": "wave", "inspect": "idle", "empty_trap": "work"}.get(a.kind, "work")

func _handle_events(evs: Array) -> void:
	for e in evs:
		match str(e.type):
			"say":
				if _bubble_queue.size() < 3:
					_bubble_queue.append(e.text)
			"quest":
				var q := D.quest(str(e.id))
				_show_toast("📜 " + tr("Quest done: %s") % D.quest_name(q))
				_sfx("win")
				world.castaway.play_once("wave", 2.0)
				after_change()
			"side":
				_show_toast("🎯 " + tr("Quest done: %s") % Quests.quest_name(Quests.get_quest(str(e.id))))
				_sfx("win")
			"tut":
				_sfx("record")
				after_change()
			"tut_done":
				_show_toast("🏝 " + tr("You can take it from here."))
				_sfx("win")
				after_change()
			"intro_done":
				_show_toast("🛏 " + tr("Day 1 sorted. Sleep well."))
				_sfx("win")
			"daily":
				_show_toast("☀ " + tr("Daily done: %s.") % tr(str(Quests.daily(str(e.id)).en)))
				_sfx("win")
			"project_done":
				_show_toast("🏗 " + tr("Finished building: %s.") % Projects.project_name(Projects.get_project(str(e.id))))
				_sfx("win")
				after_change()
			"note":
				_show_note(format_entry(e) if e.has("args") else str(e.text))
			"streak":
				_show_toast("🔥 " + tr("Streak: day %d") % int(e.count) + ("  ·  " + tr("+1 shore roll") if e.bonus else "") + ("  ·  " + tr("grace tide") if e.graced else ""))
				_sfx("win")
			"pastime":
				after_change()
			"shore":
				_show_toast("🌊 " + tr("Something washed ashore."))
				after_change()
			"wake", "sleep", "start":
				after_change()
			"fail", "broke":
				world.castaway.play_once("facepalm", 2.0)
				after_change()
			"eat", "drink":
				world.castaway.play_once(str(e.type), 1.8)
			"discover":
				_show_toast("💡 " + tr("New recipe: %s") % _name(str(D.recipe(str(e.id)).get("out", ""))))
				world.castaway.play_once("shrug", 2.0)
				_sfx("record")
			"low":
				_sfx("notify")

func _update_bubble() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if t > _bubble_until and not _bubble_queue.is_empty():
		_bubble_label.text = tr(str(_bubble_queue.pop_front()))
		_bubble_until = t + 4.2
	_bubble.visible = t < _bubble_until
	if _bubble.visible:
		var head: Vector2 = world.castaway.head_global()
		var sp := _stage_pos + head * _stage_scale
		_bubble.reset_size()
		var vs := get_viewport_rect().size
		_bubble.position = Vector2(clampf(sp.x - _bubble.size.x / 2.0, 8.0, vs.x - _bubble.size.x - 8.0),
			clampf(sp.y - _bubble.size.y - 14.0, 70.0, vs.y - _bubble.size.y))
	if _toast.visible and t > _toast_until:
		_toast.visible = false

# ================================================================ input

func _unhandled_input(event: InputEvent) -> void:
	if not started or engine == null or world == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			_toggle_debug()
			get_viewport().set_input_as_handled()
			return
		var dir := {KEY_LEFT: Vector2(-80, 0), KEY_RIGHT: Vector2(80, 0), KEY_UP: Vector2(0, -50), KEY_DOWN: Vector2(0, 50)}
		if dir.has(event.keycode):
			_walk_to(world.castaway.position + dir[event.keycode])
			get_viewport().set_input_as_handled()
		return
	# phones send each tap as a touch and an emulated mouse click: take the mouse one only
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	get_viewport().set_input_as_handled()
	if _popup:
		_close_popup()
		return
	if _panel:
		return
	if engine.tut >= 0 and engine.tut < 2:      # walking and the buttons are learned with the stick and A / B
		_show_toast(tr("Use the stick to walk."))
		return
	var p: Vector2 = (event.position - _stage_pos) / _stage_scale
	_on_tap(p, event.position)

func _on_tap(p: Vector2, screen: Vector2) -> void:
	var h: Dictionary = world.hit(p)
	match str(h.type):
		"johnny":
			engine.tap_johnny()
			_handle_events(engine.pop_events())
			_johnny_menu(screen)
		"debris":
			_try("haul", h.id)
		"spot":
			_spot_menu(str(h.id), screen)
		"palm":
			_palm_menu(str(h.id), screen)
		"structure":
			_structure_menu(str(h.id), screen)
		"shore":
			_try("shore", "")
		"cave":
			_try("inspect", "")
		"shallows":
			_shallows_menu(screen)
		_:
			_walk_to(p)

func _walk_to(p: Vector2) -> void:
	if engine.busy():
		_show_toast(tr("Busy. Tap an action in the list to cancel it."))
		return
	world.castaway.walk_to(World.walk_point(p))

## Queues an action, or says why not.
func _try(kind: String, target: String, extra: Dictionary = {}) -> void:
	_close_popup()
	var why: String = engine.enqueue(kind, target, extra)
	if why != "":
		_show_toast(tr(why))
		_sfx("invalid")
	_handle_events(engine.pop_events())
	after_change()

# ================================================================ context menus

func _option_text(kind: String, target: String) -> String:
	var mins: float = engine.duration_of(kind, target) / 60.0
	var en: float = engine.energy_cost(kind, target)
	var icon: String = ICONS.get(kind, "•")
	if kind == "pastime":
		icon = str(Pastimes.get_pastime(target).get("icon", icon))
	var s := "%s %s  ·  %s" % [icon, action_label(kind, target), _mins_text(mins)]
	if en >= 0.95:
		s += "  ·  ⚡%d" % int(round(en))
	return s

## A running countdown: 1:34 for a minute or more, "45 s" under it.
func _countdown_text(secs: float) -> String:
	var n := int(ceil(maxf(0.0, secs)))
	if n >= 60:
		return "%d:%02d" % [n / 60, n % 60]
	return tr("%d s") % n

func _mins_text(m: float) -> String:
	if m < 0.99:
		return tr("%d s") % int(round(m * 60.0))
	if m >= 60.0:
		return tr("%d h %02d min") % [int(m / 60.0), int(m) % 60]
	return tr("%d min") % int(ceil(m))

func action_label(kind: String, target: String) -> String:
	match kind:
		"haul":
			return tr("Salvage the %s") % tr(D.DEBRIS_NAMES.get(target, target))
		"gather":
			return tr("Gather: %s") % D.item_name(str(D.SPOTS[target].item))
		"shake":
			return tr("Shake palm %s") % target
		"chop":
			return tr("Chop palm %s") % target
		"fish":
			return tr("Fish")
		"seawater":
			return tr("Scoop seawater")
		"craft":
			var r := D.recipe(target)
			return (tr("Build: %s") if r.get("out_type", "") == "structure" else tr("Make: %s")) % _name(str(r.get("out", target)))
		"fuel":
			return tr("Feed the fire: %s") % D.item_name(target)
		"light":
			return tr("Relight the fire")
		"tally":
			return tr("Scratch a tally mark")
		"shore":
			return tr("Haul in the shore delivery")
		"inspect":
			return tr("Listen at the big rock")
		"sleep":
			return tr("Sleep: %s") % _name(target)
		"nap":
			return tr("Power nap")
		"pastime":
			return tr(str(Pastimes.get_pastime(target).get("en", target)))
	return kind

func _name(id: String) -> String:
	if id == "sand":
		return tr("bare sand")
	if id == "tent_mattress":
		return tr("Tent + frond mattress")
	if D.STRUCTURE_NAMES.has(id):
		return tr(D.STRUCTURE_NAMES[id])
	return D.item_name(id)

func _popup_at(screen: Vector2, title: String, options: Array) -> void:
	_close_popup()
	_popup = PanelContainer.new()
	_popup.add_theme_stylebox_override("panel", _card_style())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	if options.size() > 7:
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(430, minf(float(options.size()) * 52.0, get_viewport_rect().size.y * 0.55))
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_popup.add_child(sc)
		sc.add_child(col)
	else:
		_popup.add_child(col)
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", ACCENT)
	col.add_child(l)
	for o in options:
		var b := Button.new()
		b.text = o[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 46)
		if o.size() > 2 and o[2] != "":
			b.disabled = true
			b.tooltip_text = tr(o[2])
			b.text += "  —  " + tr(o[2])
		b.pressed.connect(o[1])
		col.add_child(b)
	_hud.add_child(_popup)
	_popup.reset_size()
	var vs := get_viewport_rect().size
	_popup.position = Vector2(clampf(screen.x - _popup.size.x / 2.0, 8.0, vs.x - _popup.size.x - 8.0),
		clampf(screen.y - _popup.size.y - 20.0, 70.0, vs.y - _popup.size.y - 8.0))

func _opt(kind: String, target: String, extra: Dictionary = {}) -> Array:
	return [_option_text(kind, target), _try.bind(kind, target, extra), engine.action_block(kind, target, extra)]

func _close_popup() -> void:
	if _popup and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null

func _johnny_menu(screen: Vector2) -> void:
	if not engine.sleep.is_empty():
		engine.wake()
		after_change()
		_show_toast(tr("Woke up. Grumpily."))
		return
	var bed: String = engine.best_bed()
	var opts := [
		_opt("sleep", bed, {"hours": engine.sleep_hours_for(bed)}),
		_opt("nap", ""),
		[tr("🎒 Bag"), _open_bag, ""],
		[tr("🔨 Craft"), _open_craft, ""],
		[tr("⚡ Odd jobs"), _pastimes_menu.bind("quick"), ""],
		[tr("🧘 Pastimes"), _pastimes_menu.bind("long"), ""],
	]
	opts[0][0] = "💤 %s  ·  %s" % [action_label("sleep", bed), _mins_text(engine.sleep_hours_for(bed) * 60.0)]
	if engine.tut >= 0:       # the opening: no odd jobs yet, just the bag / craft once they have appeared
		opts = []
		if engine.tut_reached("bag"):
			opts.append([tr("🎒 Bag"), _open_bag, ""])
		if engine.tut_reached("craft"):
			opts.append([tr("🔨 Craft"), _open_craft, ""])
	_popup_at(screen, "%s  ·  %s" % [castaway_name(), _mood_text()], opts)

## 🧘 Pastimes: small things for the mood (wilson_pastimes.gd). Greyed out ones say why.
func _pastimes_menu(group: String = "long") -> void:
	var opts := []
	if group == "quick":
		for sid in ["stones", "shells", "sticks", "fronds", "dry_fronds", "seaweed"]:
			if int(engine.stats.get("got:" + str(D.SPOTS[sid].item), 0)) <= 0:
				continue      # only things he has already picked up: the list grows as he finds more
			var o: Array = _opt("gather", sid)
			o[0] = o[0].replace(ICONS["gather"] + " " + action_label("gather", sid), "✋ " + tr("Collect: %s") % D.item_name(str(D.SPOTS[sid].item)) + " (%d)" % int(engine.spots[sid]))
			opts.append(o)
	for p in Pastimes.group_list(group):
		var why: String = engine.action_block("pastime", str(p.id))
		if why.begins_with("Needs") or why in ["Nothing to tidy yet.", "The fire is not lit.", "You have no coconut friend yet.", "Coco is already your friend."]:
			continue   # not even possible yet: it is not listed (the menu stays short)
		opts.append(_opt("pastime", str(p.id)))
	var c = world.castaway
	_popup_at(_stage_pos + (c.position + Vector2(0, -60)) * _stage_scale, tr("Odd jobs") if group == "quick" else tr("Pastimes"), opts)

func _spot_menu(id: String, screen: Vector2) -> void:
	var s: Dictionary = D.SPOTS[id]
	_popup_at(screen, "%s (%d)" % [D.item_name(str(s.item)), int(engine.spots[id])], [_opt("gather", id)])

func _palm_menu(id: String, screen: Vector2) -> void:
	var opts := [_opt("shake", id)]
	if D.PALMS[id].choppable:
		opts.append(_opt("chop", id))
	if id in ["A", "B"]:
		opts.append(_opt("nap", ""))
		if not engine.structures.has("hammock") and not engine.craft_list().filter(func(r): return r.id == "hammock").is_empty():
			opts.append(_opt("craft", "hammock"))
	var p: Dictionary = engine.palms[id]
	var title := tr("Palm %s") % id
	if float(p.felled) > 0.0:
		title += "  ·  " + tr("stump (regrows in a week)")
	else:
		title += "  ·  🥥 %d" % int(floor(float(p.coco)))
	_popup_at(screen, title, opts)

func _shallows_menu(screen: Vector2) -> void:
	var opts := [_opt("fish", ""), _opt("seawater", "")]
	if not engine.structures.has("fish_trap"):
		var r := D.recipe("fish_trap")
		if engine.recipe_unlocked(r):
			opts.append(_opt("craft", "fish_trap"))
	_popup_at(screen, tr("The shallows"), opts)

func _structure_menu(id: String, screen: Vector2) -> void:
	var opts := []
	match id:
		"campfire":
			for f in ["stick", "driftwood", "dry_frond", "trunk", "plank"]:
				if engine.count(f) > 0:
					opts.append(_opt("fuel", f))
			if engine.fire_state() != "lit":
				opts.append(_opt("light", ""))
			for rid in ["cook_fish", "cook_big_fish", "charcoal", "salt"]:
				if engine.recipe_unlocked(D.recipe(rid)):
					opts.append(_opt("craft", rid))
		"crafting_stump":
			opts.append(_opt("tally", ""))
			for r in engine.craft_list():
				if r.get("station", "") == "stump":
					opts.append(_opt("craft", str(r.id)))
		"rain_catcher", "water_still":
			var w := int(floor(float(engine.structures[id].get("water", 0.0))))
			opts.append(["💧 %s  (%d/%d)" % [tr("Drink fresh water"), w, D.WATER_MAX], _drink_from.bind(id), engine.drink_from_block(id)])
		"fish_trap":
			opts.append(_opt("empty_trap", ""))
		"kiln":
			for r in engine.craft_list():
				if r.get("station", "") == "kiln":
					opts.append(_opt("craft", str(r.id)))
		"garden_plot":
			_show_toast(tr("Garden plot: no seeds yet. Bottles will bring some."))
			return
		"canopy":
			opts.append(_opt("nap", ""))
		"hammock", "frond_bed", "frond_shelter", "tent", "treehouse":
			var bed := id
			if id in ["tent", "frond_bed"] and engine.bed_available("tent_mattress"):
				bed = "tent_mattress"
			opts.append([("💤 %s  ·  %s" % [action_label("sleep", bed), _mins_text(engine.sleep_hours_for(bed) * 60.0)]),
				_try.bind("sleep", bed, {"hours": engine.sleep_hours_for(bed)}), engine.action_block("sleep", bed)])
			if id in ["hammock", "frond_shelter", "tent"]:
				opts.append(_opt("nap", ""))
		"drying_rack":
			opts.append(_opt("craft", "dry_fish"))
	if opts.is_empty():
		for pr in Projects.LIST:
			if pr.key == id:
				_show_toast("%s: %s" % [Projects.project_name(pr), tr(str(pr.effect))])
				return
		_show_toast(_name(id))
		return
	var pj := ""
	for pr in Projects.LIST:
		if pr.key == id:
			pj = Projects.project_name(pr)
	var title := pj if pj != "" else _name(id)
	if id == "campfire":
		title += "  ·  " + tr({"lit": "burning nicely", "embers": "embers (rain)", "dead": "out cold"}.get(engine.fire_state(), ""))
	_popup_at(screen, title, opts)

# ================================================================ HUD

func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.05, 0.9)
	sb.border_color = Color(1.0, 0.7, 0.35, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	return sb

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_hud.add_child(margin)
	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	# bars
	var bars_panel := PanelContainer.new()
	bars_panel.add_theme_stylebox_override("panel", _card_style())
	top.add_child(bars_panel)
	_bars_panel = bars_panel
	var bars_row := HBoxContainer.new()
	bars_panel.add_child(bars_row)
	var bars_col := VBoxContainer.new()
	bars_col.add_theme_constant_override("separation", 3)
	bars_row.add_child(bars_col)
	for k in ["hp", "food", "energy", "water"]:
		var r := HBoxContainer.new()
		bars_col.add_child(r)
		_bar_rows[k] = r
		var hud_icon: String = HUD_ART + {"hp": "heart", "food": "food", "energy": "energy", "water": "water"}[k] + ".webp"
		if ResourceLoader.exists(hud_icon):
			var ti := TextureRect.new()
			ti.texture = load(hud_icon)
			ti.custom_minimum_size = Vector2(28, 22 if k == "water" else 26)
			ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r.add_child(ti)
		else:
			var ic := Label.new()
			ic.text = BAR_ICONS[k]
			ic.add_theme_font_size_override("font_size", 16 if k == "water" else 20)
			ic.custom_minimum_size = Vector2(28, 0)
			r.add_child(ic)
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.max_value = 100
		pb.custom_minimum_size = Vector2(150, 8 if k == "water" else 16)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fg := StyleBoxFlat.new()
		fg.bg_color = BAR_COLORS[k]
		fg.set_corner_radius_all(4)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.45)
		bg.set_corner_radius_all(4)
		pb.add_theme_stylebox_override("fill", fg)
		pb.add_theme_stylebox_override("background", bg)
		r.add_child(pb)
		_bars[k] = pb
	_mood = Label.new()
	_mood.add_theme_font_size_override("font_size", 40)
	_mood.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bars_row.add_child(_mood)
	# clock + quest
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(mid)
	_clock = Label.new()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_theme_font_size_override("font_size", 26)
	_clock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_clock.add_theme_constant_override("outline_size", 6)
	_clock.mouse_filter = Control.MOUSE_FILTER_STOP
	_clock.gui_input.connect(_on_clock_input)
	mid.add_child(_clock)
	_quest = Label.new()
	_quest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest.add_theme_font_size_override("font_size", 19)
	_quest.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_quest.add_theme_constant_override("outline_size", 6)
	_quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_quest)
	# buttons
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	btns.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(btns)
	for b in [["📓", _open_journal, "scroll"], ["🎒", _open_bag, "backpack"], ["🔨", _open_craft, ""], ["⏸", _pause, ""]]:
		var btn := Button.new()
		btn.text = b[0]
		var ip: String = HUD_ART + str(b[2]) + ".webp"
		if b[2] != "" and ResourceLoader.exists(ip):
			btn.text = ""
			btn.icon = load(ip)
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.custom_minimum_size = Vector2(60, 56)
		btn.add_theme_font_size_override("font_size", 26)
		btn.pressed.connect(b[1])
		btns.add_child(btn)
		_hud_btns[{"📓": "journal", "🎒": "bag", "🔨": "craft", "⏸": "pause"}[b[0]]] = btn
		if b[0] == "🔨":
			_craft_btn = btn
	# queue (left, under the bars)
	_queue_box = VBoxContainer.new()
	_queue_box.add_theme_constant_override("separation", 4)
	_queue_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root.add_child(_queue_box)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)
	var bottom := HBoxContainer.new()
	_sleep_row = bottom
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	for b in [["💤", _sleep_now], ["😴", _nap_now]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(64, 60)
		btn.add_theme_font_size_override("font_size", 28)
		btn.pressed.connect(b[1])
		bottom.add_child(btn)
	_bubble = PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(1, 1, 0.97, 0.95)
	bsb.border_color = Color(0.2, 0.15, 0.1)
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(16)
	bsb.set_content_margin_all(10)
	_bubble.add_theme_stylebox_override("panel", bsb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_label = Label.new()
	_bubble_label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08))
	_bubble_label.add_theme_font_size_override("font_size", 20)
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(240, 0)
	_bubble.add_child(_bubble_label)
	_bubble.visible = false
	_hud.add_child(_bubble)
	_tut_card = PanelContainer.new()
	_tut_card.add_theme_stylebox_override("panel", _card_style())
	_tut_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tut_card.offset_left = -270
	_tut_card.offset_right = 270
	_tut_card.offset_top = -150
	_tut_card.offset_bottom = -20
	_tut_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 8)
	_tut_card.add_child(tcol)
	_tut_card_label = Label.new()
	_tut_card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tut_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tut_card_label.add_theme_font_size_override("font_size", 20)
	tcol.add_child(_tut_card_label)
	var tok := Button.new()
	tok.text = tr("Got it")
	tok.custom_minimum_size = Vector2(140, 48)
	tok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tok.pressed.connect(_on_tut_ack)
	tcol.add_child(tok)
	_tut_card.visible = false
	_hud.add_child(_tut_card)
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_top = -120
	_toast.offset_bottom = -80
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_hud.add_child(_toast)

## "🌊 low" / "🌊 high" / rising or falling, from the tide cycle (GDD section 4).
func _tide_text() -> String:
	var lv: float = engine.tide_level()
	var rising: bool = engine.tide_level(engine.t + 300.0) > lv
	if engine.is_low_tide():
		return "🌊 " + tr("Low tide")
	if lv > 0.8:
		return "🌊 " + tr("High tide")
	return "🌊 " + tr("Tide rising") if rising else "🌊 " + tr("Tide falling")

func _refresh_hud() -> void:
	if _hud == null or engine == null:
		return
	for k in _bars:
		_bars[k].value = engine.bars[k]
		var low: bool = engine.bars[k] < D.LOW_BAR
		_bars[k].modulate = Color(1, 1, 1, 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 250.0))) if low else Color.WHITE
	_mood.text = _mood_face()
	var h: float = engine.hour()
	var icon := "☀" if engine.is_day() else "🌙"
	_clock.text = "%s %s %d" % [icon, tr("Day"), engine.day_number()]
	if engine.knows_time():
		_clock.text += "  ·  %02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]
	if engine.knows_tide():
		_clock.text += "  ·  " + _tide_text()
	if time_scale != 1.0:
		_clock.text += "  (x%d)" % int(time_scale)
	var intro: Dictionary = engine.intro_step()
	var ts: Dictionary = engine.tut_step()
	if not ts.is_empty():
		_quest.text = "📜 " + tr(str(ts.short))
		if int(ts.need) > 1:
			_quest.text += "  %d/%d" % [int(ts.have), int(ts.need)]
	elif not intro.is_empty():
		_quest.text = "🎒 %s  %d/%d" % [tr(str(intro.hint)), mini(int(intro.have), int(intro.need)), int(intro.need)]
	elif engine.quest != "":
		_quest.text = "📜 " + tr(str(D.QUEST_SHORT.get(engine.quest, D.quest_name(D.quest(engine.quest)))))
	else:
		_quest.text = "📜 " + tr("Tutorial done. The island is yours. Sadly.")
	_refresh_queue()
	_apply_tut()

## The opening shows the HUD one part at a time: stick, then A + B, the bag, the craft button, each bar,
## the clock, the journal. Everything is shown once the opening is over (and for old saves).
func _apply_tut() -> void:
	if _hud == null or engine == null:
		return
	var rows := {"hp": "hp", "food": "food", "energy": "energy", "water": "water"}
	var vis := {}
	for k in rows:
		vis[k] = engine.tut_reached(k)
	for k in ["a", "b", "bag", "craft", "mood", "clock", "journal", "pause"]:
		vis[k] = engine.tut_reached(k)
	vis["jobs"] = engine.tut < 0
	for k in rows:
		_bar_rows[k].visible = vis[k]
	_bars_panel.visible = vis.hp or vis.food or vis.energy or vis.water or vis.mood
	_mood.visible = vis.mood
	_clock.visible = vis.clock
	for k in _hud_btns:
		_hud_btns[k].visible = vis[k]
	if _sleep_row and pad == null:
		_sleep_row.visible = engine.tut < 0
	if pad != null and is_instance_valid(pad):
		var pad_ids := {"a": "a", "b": "b", "x": "bag", "y": "jobs", "info": "journal", "pause": "pause"}
		for pid in pad_ids:
			var show: bool = vis[pad_ids[pid]]
			if _tut_vis.get(pid, null) == show:
				continue
			_tut_vis[pid] = show
			if show:
				pad.reveal(pid, engine.tut >= 0)
			else:
				pad.set_hidden(pid, true)
	var ts: Dictionary = engine.tut_step()
	var card: bool = not ts.is_empty() and ts.get("card", false)
	_tut_card.visible = card and not _panel
	if card:
		_tut_card_label.text = tr(str(ts.long))

func _on_tut_ack() -> void:
	engine.tut_ack()
	after_change()

## The HUD part the current step is about pulses (a soft glow, not a box).
func _tut_pulse() -> void:
	if engine == null:
		return
	if engine.tut < 0:
		if not _tut_vis.get("reset", false):
			_tut_vis["reset"] = true
			for key in _bar_rows:
				_bar_rows[key].modulate = Color.WHITE
			for key in _hud_btns:
				_hud_btns[key].modulate = Color.WHITE
			_clock.modulate = Color.WHITE
			_mood.modulate = Color.WHITE
		return
	_tut_vis["reset"] = false
	var k := 0.78 + 0.22 * sin(Time.get_ticks_msec() * 0.008)
	var id := str(engine.tut_step().get("id", ""))
	var glow := Color(1.25, 1.1, 0.7)
	for key in _bar_rows:
		_bar_rows[key].modulate = glow.lerp(Color.WHITE, k) if key == id else Color.WHITE
	_clock.modulate = glow.lerp(Color.WHITE, k) if id == "clock" else Color.WHITE
	_mood.modulate = glow.lerp(Color.WHITE, k) if id == "mood" else Color.WHITE
	for key in _hud_btns:
		var on: bool = key == id or (key == "craft" and id in ["spark", "fire"])
		if key != "craft" or not on:
			_hud_btns[key].modulate = glow.lerp(Color.WHITE, k) if on else Color.WHITE

func _mood_face() -> String:
	var m: float = engine.mood
	if m > 75.0:
		return "😄"
	if m > 55.0:
		return "🙂"
	if m > 35.0:
		return "😐"
	if m > 15.0:
		return "😟"
	return "😫"

func _mood_text() -> String:
	var parts := [_mood_face()]
	if engine.has_buff("rested"):
		parts.append(tr("Rested"))
	if engine.has_buff("sandy"):
		parts.append(tr("Sandy"))
	if engine.has_buff("nausea"):
		parts.append(tr("Queasy"))
	return "  ".join(parts)

func _refresh_queue() -> void:
	for c in _queue_box.get_children():
		c.queue_free()
	if not engine.sleep.is_empty():
		var s: Dictionary = engine.sleep
		var left_s := maxf(0.0, float(s.until) - engine.t)
		var kind: String = {"nap": "😴 " + tr("Power nap"), "collapse": "😵 " + tr("Collapsed"), "faint": "😵 " + tr("Fainted")}.get(str(s.kind), "💤 " + action_label("sleep", str(s.bed)))
		var b := Button.new()
		b.text = "%s  ·  %s  ✕" % [kind, _countdown_text(left_s)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_wake_now)
		_queue_box.add_child(b)
	var i := 0
	var at: float = engine.t
	for q in engine.queue:
		var b := Button.new()
		var label := "%s %s" % [ICONS.get(q.kind, "•"), action_label(q.kind, q.target)]
		if float(q.start) > 0.0:
			label += "  ·  %s" % _countdown_text(float(q.end) - at)
		else:
			label += "  ·  " + tr("waiting its turn")
		b.text = label + "  ✕"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 18)
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(_cancel.bind(i))
		_queue_box.add_child(b)
		i += 1

func _cancel(i: int) -> void:
	engine.cancel(i)
	after_change()

func _wake_now() -> void:
	engine.wake()
	after_change()

func _sleep_now() -> void:
	var bed: String = engine.best_bed()
	_try("sleep", bed, {"hours": engine.sleep_hours_for(bed)})

func _nap_now() -> void:
	_try("nap", "")

func _pause() -> void:
	if home:
		home.pause()

func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.visible = true
	_toast_until = Time.get_ticks_msec() / 1000.0 + 3.0

func _on_clock_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		var t := Time.get_ticks_msec()
		_clock_taps.append(t)
		_clock_taps = _clock_taps.filter(func(x): return t - x < 2500)
		if _clock_taps.size() >= 5:
			_clock_taps.clear()
			_toggle_debug()

# ================================================================ panels (bag, craft, journal)

func _open_panel(title: String) -> VBoxContainer:
	_close_popup()
	_close_panel()
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _card_style())
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vs := get_viewport_rect().size
	_panel.position = Vector2(vs.x * 0.12, 70)
	_panel.size = Vector2(vs.x * 0.76, vs.y - 90)
	var col := VBoxContainer.new()
	_panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", ACCENT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var x := Button.new()
	x.text = "✕"
	x.custom_minimum_size = Vector2(56, 50)
	x.pressed.connect(_close_panel_x)
	head.add_child(x)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	_hud.add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(vs.x * 0.12, 70)
	_panel.size = Vector2(vs.x * 0.76, vs.y - 90)
	return body

func _close_panel_x() -> void:
	_combine_from = ""
	_close_panel()

func _close_panel() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null

func _open_bag() -> void:
	engine.tut_event("bag")
	var body := _open_panel("🎒 " + tr("Bag") + "  (%d/%d)" % [engine.slots.size(), engine.capacity()])
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	if _combine_from != "":
		hint.text = "🔗 " + tr("Combine %s with... tap a second item.") % D.item_name(_combine_from)
		hint.add_theme_color_override("font_color", ACCENT)
	else:
		hint.text = tr("Tap an item to use it. Drag one onto another to combine them and find new recipes.")
	body.add_child(hint)
	if engine.slots.is_empty():
		var l := Label.new()
		l.text = tr("Empty. Like my prospects.")
		body.add_child(l)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for s in engine.slots:
		var b := Slot.new()
		var id: String = s.id
		b.setup(id, "%s  ×%d%s" % [D.item_name(id), int(s.n), _slot_note(s)])
		b.custom_minimum_size = Vector2(250, 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id == _combine_from:
			b.modulate = Color(1.0, 0.85, 0.5)
		b.pressed.connect(_item_menu.bind(id))
		b.combined.connect(_combine)
		grid.add_child(b)
	if not engine.ground.is_empty():
		var l := Label.new()
		l.text = tr("On the sand (no room in the bag):")
		body.add_child(l)
		for id in engine.ground:
			var g := Label.new()
			g.text = "  %s ×%d" % [D.item_name(id), int(engine.ground[id])]
			body.add_child(g)

## Tool uses left / when food spoils, shown on its slot.
func _slot_note(s: Dictionary) -> String:
	var nl := "
"
	if D.TOOL_USES.has(str(s.id)):
		var uses_text := tr("%d uses") % int(s.get("dur", D.TOOL_USES[s.id]))
		return nl + uses_text
	var sp := float(s.get("spoil", 0.0))
	if sp > 0.0:
		var spoil_text := tr("spoils in %d h") % maxi(0, int(ceil((sp - engine.t) / 3600.0)))
		return nl + spoil_text
	return ""

## Tapping a slot: the second pick of a combine, or the item's card.
func _item_menu(id: String) -> void:
	if _combine_from != "":
		var a := _combine_from
		_combine_from = ""
		_combine(a, id)
		return
	var body := _open_panel(D.item_name(id))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	var tex := Slot.icon_of(id)
	if tex:
		var tr_ := TextureRect.new()
		tr_.texture = tex
		tr_.custom_minimum_size = Vector2(110, 110)
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr_)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	var info_l := Label.new()
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var uses := []
	for r in engine.craft_list():
		for pair in engine.recipe_parts(r):
			if str(pair[0]) == id and not _name(str(r.out)) in uses:
				uses.append(_name(str(r.out)))
	info_l.text = (tr("Used in: %s") % ", ".join(uses)) if not uses.is_empty() else tr("No known recipe uses it. Yet.")
	col.add_child(info_l)
	var f: Dictionary = D.FOOD.get(id, {})
	if not f.is_empty():
		var b := Button.new()
		b.text = ("🥥 " + tr("Drink ")) if f.verb == "drink" else ("🍴 " + tr("Eat"))
		b.pressed.connect(_use_item.bind(id))
		col.add_child(b)
	if id in ["bottle_note", "seawater"]:
		var b := Button.new()
		b.text = ("🍾 " + tr("Open")) if id == "bottle_note" else ("🥤 " + tr("Drink "))
		b.pressed.connect(_use_item.bind(id))
		col.add_child(b)
	if engine.structures.has("campfire") and D.FUEL_H.has(id):
		var b := Button.new()
		b.text = _option_text("fuel", id)
		b.pressed.connect(_fuel_from_bag.bind(id))
		col.add_child(b)
	var c := Button.new()
	c.text = "🔗 " + tr("Combine with...")
	c.pressed.connect(_start_combine.bind(id))
	col.add_child(c)
	var back := Button.new()
	back.text = "‹ " + tr("Bag")
	back.pressed.connect(_open_bag)
	col.add_child(back)

func _start_combine(id: String) -> void:
	_combine_from = id
	_open_bag()

func _fuel_from_bag(id: String) -> void:
	_try("fuel", id)
	_open_bag()

## Drag A onto B (or the two-tap combine): finds and queues a recipe that uses both.
func _combine(a: String, b: String) -> void:
	_combine_from = ""
	var res: Dictionary = engine.combine(a, b)
	_handle_events(engine.pop_events())
	if not res.ok:
		_show_toast(tr(str(res.text)))
		_sfx("invalid")
	elif not res.queued:
		var r := D.recipe(str(res.recipe))
		_show_toast("%s: %s" % [_name(str(r.out)), tr(str(res.text))])
	else:
		_show_toast("🔨 " + action_label("craft", str(res.recipe)))
	after_change()
	_open_bag()

func _use_item(id: String) -> void:
	var why: String = engine.consume(id)
	if why != "":
		_show_toast(tr(why))
	_handle_events(engine.pop_events())
	after_change()
	_open_bag()

func _drink_from(sid: String) -> void:
	_close_popup()
	var why: String = engine.drink_from(sid)
	if why != "":
		_show_toast(tr(why))
	_handle_events(engine.pop_events())
	after_change()

func _open_craft() -> void:
	var body := _open_panel("🔨 " + tr("Craft"))
	var list: Array = engine.craft_visible_list()
	list.sort_custom(func(a, b): return [0 if engine.craft_block(str(a.id)) == "" else 1, int(a.tier), str(a.id)] < [0 if engine.craft_block(str(b.id)) == "" else 1, int(b.tier), str(b.id)])
	for r in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		body.add_child(row)
		var ic := TextureRect.new()
		ic.texture = Slot.icon_of(str(r.out))
		ic.custom_minimum_size = Vector2(48, 48)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ic)
		var info_l := Label.new()
		info_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var ins := []
		for pair in r.get("in", []):
			var have: int = engine.count(str(pair[0]))
			ins.append("%s %d/%d" % [D.item_name(str(pair[0])), mini(have, int(pair[1])), int(pair[1])])
		for key in ["tool", "needs"]:
			if str(r.get(key, "")) != "":
				ins.append("🔧 " + D.item_name(str(r[key])))
		var out_name := _name(str(r.out))
		if int(r.get("qty", 1)) > 1:
			out_name += " ×%d" % int(r.qty)
		info_l.text = "%s\n%s" % [out_name, ", ".join(ins) if not ins.is_empty() else tr("no materials")]
		row.add_child(info_l)
		var b := Button.new()
		var why: String = engine.craft_block(str(r.id))
		b.text = "%s · ⚡%d" % [_mins_text(engine.duration_of("craft", str(r.id)) / 60.0), int(r.en)] if why == "" else tr(why)
		b.disabled = why != ""
		b.custom_minimum_size = Vector2(220, 50)
		b.pressed.connect(_craft_from_panel.bind(str(r.id)))
		row.add_child(b)
	if list.is_empty():
		var none := Label.new()
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.text = tr("Nothing to make yet. Gather, salvage or search for something and ideas will appear here.")
		body.add_child(none)
	# Grand Projects: only the ones you hold a material for (or pinned / building / built)
	var shown := 0
	for pr in Projects.LIST:
		if engine.project_visible(pr):
			if shown == 0:
				var ph := Label.new()
				ph.text = "\n🏗 " + tr("Grand Projects")
				ph.add_theme_color_override("font_color", ACCENT)
				body.add_child(ph)
			_project_card(body, pr)
			shown += 1
	var more := Label.new()
	more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	more.add_theme_font_size_override("font_size", 16)
	more.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	more.text = "\n" + tr("More ideas show up as you find materials. Drag two materials together in the bag to discover recipes.")
	body.add_child(more)

func _craft_from_panel(rid: String) -> void:
	_try("craft", rid)
	_open_craft()

func _project_card(body: VBoxContainer, p: Dictionary) -> void:
	var id: String = p.id
	var built: bool = engine.structures.has(p.key)
	var building: bool = engine.projects.has(id)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	body.add_child(HSeparator.new())
	body.add_child(box)
	var head := Label.new()
	head.add_theme_font_size_override("font_size", 22)
	var mark := "✔ " if built else ("🔨 " if building else ("📌 " if id == engine.pinned else ""))
	head.text = mark + Projects.project_name(p)
	head.add_theme_color_override("font_color", ACCENT if not built else Color(0.6, 0.9, 0.6))
	box.add_child(head)
	var fx := Label.new()
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.add_theme_font_size_override("font_size", 17)
	fx.text = tr(str(p.effect))
	box.add_child(fx)
	if built:
		return
	if building:
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(0, 22)
		pb.value = engine.project_progress(id) * 100.0
		box.add_child(pb)
		var left := Label.new()
		var mins := int(round((float(engine.projects[id].done) - engine.t) / 60.0))
		left.text = tr("Ready in %d h %02d min.") % [mins / 60, mins % 60]
		box.add_child(left)
		return
	var miss: Array = engine.project_missing(id)
	var mats := []
	for m in p.mats:
		mats.append("%s %d/%d" % [D.item_name(str(m[0])), mini(engine.count(str(m[0])), int(m[1])), int(m[1])])
	var ml := Label.new()
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.add_theme_font_size_override("font_size", 17)
	ml.text = "  ·  ".join(mats) + "\n" + tr("Takes %d days to build.") % int(p.days)
	box.add_child(ml)
	if id == engine.pinned and not miss.is_empty():
		for m in miss:
			var hl := Label.new()
			hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hl.add_theme_font_size_override("font_size", 16)
			hl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
			hl.text = "• %s ×%d: %s" % [D.item_name(str(m[0])), int(m[2]) - int(m[1]), tr(Projects.source_hint(str(D.item(str(m[0])).get("r", "C"))))]
			box.add_child(hl)
	var row := HBoxContainer.new()
	box.add_child(row)
	var why: String = engine.project_block(id)
	var go := Button.new()
	go.text = "🏗 " + tr("Build")
	go.disabled = why != ""
	go.custom_minimum_size = Vector2(120, 48)
	go.pressed.connect(_on_project_build.bind(id))
	row.add_child(go)
	var pin := Button.new()
	pin.text = ("📌 " + tr("Unpin")) if id == engine.pinned else ("📌 " + tr("Pin"))
	pin.custom_minimum_size = Vector2(120, 48)
	pin.pressed.connect(_on_project_pin.bind(id))
	row.add_child(pin)
	if why != "" and why != "Missing materials.":
		var wl := Label.new()
		wl.text = tr(why) if not why.contains("%s") else why
		wl.add_theme_font_size_override("font_size", 16)
		row.add_child(wl)

func _on_project_build(id: String) -> void:
	var why: String = engine.start_project(id)
	if why != "":
		_show_toast(tr(why))
	else:
		_sfx("win")
		_show_toast("🏗 " + tr("Building: %s") % Projects.project_name(Projects.get_project(id)))
	_handle_events(engine.pop_events())
	after_change()
	_open_craft()

func _on_project_pin(id: String) -> void:
	engine.pinned = "" if engine.pinned == id else id
	_save_game()
	_open_craft()

func _open_journal() -> void:
	engine.tut_event("journal")
	var body := _open_panel("📓 " + tr("%s's journal") % castaway_name())
	var sk := Label.new()
	sk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sk.add_theme_color_override("font_color", ACCENT)
	var parts := []
	for k in D.SKILLS:
		parts.append("%s %d" % [tr(D.SKILL_NAMES[k]), engine.skill_level(k)])
	sk.text = "📈 " + "  ·  ".join(parts)
	body.add_child(sk)
	body.add_child(_sea_report())
	body.add_child(_streak_label())
	var dh := Label.new()
	dh.text = "☀ " + tr("Today") + "  %d/%d" % [engine.dq_done.size(), engine.dq.size()]
	dh.add_theme_color_override("font_color", ACCENT)
	body.add_child(dh)
	for id in engine.dq:
		var dq_: Dictionary = Quests.daily(str(id))
		if dq_.is_empty():
			continue
		var dl := Label.new()
		if id in engine.dq_done:
			dl.text = "✔ %s" % tr(str(dq_.en))
			dl.modulate = Color(1, 1, 1, 0.6)
		else:
			dl.text = "• %s (%d/%d)" % [tr(str(dq_.en)), mini(int(engine.dstats.get(dq_.stat, 0)), int(dq_.need)), int(dq_.need)]
		body.add_child(dl)
	var sh := Label.new()
	sh.text = "📜 " + tr("Story quests")
	sh.add_theme_color_override("font_color", ACCENT)
	body.add_child(sh)
	if engine.tut >= 0:
		for i in mini(engine.tut + 1, D.TUT.size()):
			var st: Dictionary = D.TUT[i]
			var tl := Label.new()
			tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tl.text = ("• %s: %s" if i == engine.tut else "✔ %s: %s") % [tr(str(st.short)), tr(str(st.long))]
			if i < engine.tut:
				tl.modulate = Color(1, 1, 1, 0.6)
			body.add_child(tl)
	else:
		for tq in D.quests():
			var tl2 := Label.new()
			tl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var short_q := tr(str(D.QUEST_SHORT.get(tq.id, D.quest_name(tq))))
			if tq.id in engine.quests_done:
				tl2.text = "✔ " + short_q
				tl2.modulate = Color(1, 1, 1, 0.6)
			else:
				tl2.text = "• %s: %s" % [short_q, tr(D.QUEST_HINTS.get(tq.id, ""))]
			body.add_child(tl2)
	var qh := Label.new()
	qh.text = "🎯 " + tr("Side quests") + "  %d/%d" % [engine.side_done.size(), Quests.LIST.size()]
	qh.add_theme_color_override("font_color", ACCENT)
	body.add_child(qh)
	for q in Quests.LIST:
		var ql := Label.new()
		ql.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if q.id in engine.side_done:
			ql.text = "✔ %s" % Quests.quest_name(q)
			ql.modulate = Color(1, 1, 1, 0.6)
		else:
			ql.text = "• %s: %s (%d/%d)" % [Quests.quest_name(q), tr(str(q.goal)), mini(int(engine.stats.get(q.stat, 0)), int(q.need)), int(q.need)]
		body.add_child(ql)
	var n: int = engine.journal.size()
	for i in range(n - 1, maxi(-1, n - 80), -1):
		body.add_child(_journal_line(engine.journal[i]))
	if not engine.quests_done.is_empty():
		var l := Label.new()
		l.text = "\n" + tr("Quests done:") + " " + ", ".join(engine.quests_done)
		body.add_child(l)

## 🔥 The 30-day calendar: filled days so far this lap, the best streak.
func _streak_label() -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cnt: int = int(engine.streak.count)
	var lap := 30
	var filled := (cnt - 1) % lap + 1 if cnt > 0 else 0
	var cells := ""
	for i in lap:
		cells += "●" if i < filled else "○"
		if i % 10 == 9 and i < lap - 1:
			cells += "\n"
	l.text = "🔥 %s: %d  ·  %s %d\n%s" % [tr("Streak"), cnt, tr("best"), int(engine.streak.best), cells]
	l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	return l

## Tides and (with a barometer) the weather ahead, for the journal panel.
func _sea_report() -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines := []
	if engine.knows_tide():
		lines.append(_tide_text())
	if engine.structures.has("shellphone"):
		var rise: float = engine.sunrise_h()
		var sset: float = engine.sunset_h()
		lines.append("📱 %s %d%%  ·  %s %02d:%02d  ·  %s %02d:%02d" % [tr("Moon"), int(round(Astro.moon_phase(engine.t) * 100.0)), tr("sunrise"), int(rise), int(fmod(rise, 1.0) * 60.0), tr("sunset"), int(sset), int(fmod(sset, 1.0) * 60.0)])
	var nl: float = engine.next_low_tide()
	if engine.knows_tide() and not engine.is_low_tide() and nl > engine.t:
		var mins := int(round((nl - engine.t) / 60.0))
		lines.append(tr("Next low tide in %d h %02d min.") % [mins / 60, mins % 60])
	var hrs: int = engine.forecast_hours()
	if hrs <= 0:
		lines.append(tr("Make a barometer to see the weather ahead."))
	else:
		var fc: Array = engine.forecast()
		if fc.is_empty():
			lines.append(tr("Forecast (%d h): the same weather.") % hrs)
		for f in fc:
			lines.append("%s  %s %s" % [tr("Forecast, in %d h") % int(round((float(f.t) - engine.t) / 3600.0)), D.WEATHER_ICON.get(f.weather, ""), tr(D.WEATHER_NAMES.get(f.weather, ""))])
	l.text = "\n".join(lines)
	l.visible = not lines.is_empty()
	return l

func _journal_line(e: Dictionary) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var d := Time.get_datetime_dict_from_unix_time(int(float(e.t) + engine.tz))
	var day: int = int(floor((float(e.t) + engine.tz) / 86400.0)) - engine.start_day + 1
	if engine.knows_time():
		l.text = "%s %d, %02d:%02d  %s" % [tr("Day"), day, d.hour, d.minute, format_entry(e)]
	else:
		l.text = "%s %d  %s" % [tr("Day"), day, format_entry(e)]
	if e.get("away", false):
		l.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	return l

## Journal text in the player's language: "@id" item names, "%id" debris names, "#..."/"~..." sentences.
func format_entry(e: Dictionary) -> String:
	var args := []
	for a in e.get("args", []):
		if a is String and a.begins_with("@"):
			args.append(_name(a.substr(1)))
		elif a is String and a.begins_with("%"):
			args.append(tr(D.DEBRIS_NAMES.get(a.substr(1), a.substr(1))))
		elif a is String and (a.begins_with("#") or a.begins_with("~")):
			args.append(tr(a.substr(1)))
		elif a is float and absf(a - round(a)) < 0.001 and str(e.text).contains("%d"):
			args.append(int(a))
		else:
			args.append(a)
	var text := tr(str(e.text))
	if args.is_empty():
		return text
	return text % args

func _show_away(entries: Array) -> void:
	var body := _open_panel("🌅 " + tr("While you were away"))
	for e in entries.slice(maxi(0, entries.size() - 40)):
		body.add_child(_journal_line(e))

func _show_note(text: String) -> void:
	var body := _open_panel("🍾 " + tr("Message in a bottle"))
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 26)
	l.text = "\"%s\"" % tr(text)
	body.add_child(l)

# ================================================================ debug, helps

func _toggle_debug() -> void:
	if engine == null:
		return
	if _debug == null or not is_instance_valid(_debug):
		_debug = Debug.new()
		_hud.add_child(_debug)
		_debug.setup(self)
		var vs := get_viewport_rect().size
		var w := minf(560.0, vs.x - 40.0)
		_debug.position = Vector2(vs.x - w - 12.0, 70)
		_debug.size = Vector2(w, vs.y - 90)
		_debug.visible = false
	_debug.visible = not _debug.visible
	_debug.refresh()

func hurry() -> void:
	var a: Dictionary = engine.active()
	if not a.is_empty():
		a.end = engine.t
	elif not engine.sleep.is_empty():
		engine.sleep.until = engine.t
	engine.advance(engine.t + 0.01, true)
	_handle_events(engine.pop_events())
	after_change()

## ⏩ Hurry up (STANDARDS §17 help): finishes the current action right away.
func _help_hurry() -> bool:
	if engine == null or (engine.active().is_empty() and engine.sleep.is_empty()):
		return false
	hurry()
	return true

func save_debug() -> void:
	SaveUtil.write(DEBUG_PATH, {"offset": clock_offset, "scale": time_scale})

func _load_debug() -> void:
	var d = SaveUtil.read(DEBUG_PATH)
	if d is Dictionary:
		clock_offset = float(d.get("offset", 0.0))
		time_scale = float(d.get("scale", 1.0))

# ================================================================ kit hooks, sound, save

func _music(style: String) -> void:
	var m = get_node_or_null("/root/Music")
	if m and m.has_method("play"):
		m.play(style, self)

func _sfx(name: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s and s.has_method("play"):
		s.play(name)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if started and auto_pause and home != null and not home.is_home_visible():
			home.pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

## Called by the kit on pause / 🏠 Home / app suspend (STANDARDS N5).
func _save_game() -> void:
	if not started or engine == null:
		return
	SaveUtil.write(SAVE_PATH, {"engine": engine.to_dict()})
	save_debug()
	if info:
		info.high("Most days survived", engine.day_number())
