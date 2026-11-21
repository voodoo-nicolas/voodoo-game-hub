extends Control

## Ink Ninja: a side-scrolling run-and-slash game painted in black ink on rice
## paper (sumi-e): only black, white and greys. Hits splash stylised ink, never blood
## (owner, 2026-11-14). 10 stages, each ending in a boss arena.
## Landscape. Controls: the shared Pad (stick + A jump, B slash, X star, Y dash);
## keyboard on PC. Older apps without the Pad get on-screen buttons.
## Landing menu style: S1 Ghost (docs/MENU_STYLES.md): faded ink title over mist suits
## the ink-wash look; the last two new games used rail and slabs.

const Engine_ = preload("res://scripts/games/ink_ninja/ink_ninja_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const MenuStyles = preload("res://scripts/games/ink_ninja/menu_styles.gd")
const HomeKit = preload("res://scripts/games/ink_ninja/home_kit.gd")
const SoundLib = preload("res://scripts/games/ink_ninja/sound_lib.gd")
const GameMusic = preload("res://scripts/games/ink_ninja/ink_ninja_music.gd")
## Ink Ninja's own music (owner 2026-11-20, res://games/ink_ninja/music/), never the hub's:
## the dojo theme on the Landing, the road tracks in turn, taiko drums on a boss stage's road,
## the samurai theme once the boss wakes (kawarayu: the calm cutscenes, cutscene.gd).
const MENU_TRACK := "dojo_menu"
const ROAD_TRACKS := ["treacherous_path", "asian_oriental1", "asian_oriental2", "jaoan"]
const FIGHT_TRACK := "taiko_drums"
const BOSS_TRACK := "samurai"
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/ink_ninja/ink_ninja_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://ink_ninja_save.json"
const Story = preload("res://scripts/games/ink_ninja/ink_ninja_story.gd")
const Goals = preload("res://scripts/games/ink_ninja/ink_ninja_goals.gd")
const Cutscene_ = preload("res://scripts/games/ink_ninja/cutscene.gd")
const PAPER_SHADER := preload("res://scripts/games/ink_ninja/ink_ninja_paper.gdshader")
const DARK_SHADER := preload("res://scripts/games/ink_ninja/ink_ninja_dark.gdshader")
const Scenery = preload("res://scripts/games/ink_ninja/ink_ninja_scenery.gd")
const Poses = preload("res://scripts/games/ink_ninja/ink_ninja_poses.gd")
## Owner art 2026-11-20: each act's boss is a set of painted poses (games/ink_ninja/art/boss,
## cut by tools/ink_ninja_art.py); the drawn bosses stay as the fallback.
const BOSS_IDS := ["warden", "tora", "dragon", "tsuru", "calligrapher", "shu"]
const BOSS_H := 175.0          # world height of a boss's body (the hero is 70)
const TRAIL_T := 0.16          # how long the silver / gold sword trail lingers
const HARD_UNLOCK_PATH := "user://ink_ninja_unlock.json"
## Owner's intro film (2026-11-20, D:/Dev/hub/ink ninja final1.mp4 as 720p Ogg Theora): plays every time
## the game is opened (from the app or the hub), before the Landing. A tap or Skip ends it. Not when the
## pause menu's 🏠 Home reloads the scene (that is the same visit).
const INTRO_PATH := "res://games/ink_ninja/intro.ogv"   # {"hard": true} once the story is beaten on Normal
const DIFF_NAMES := ["Easy", "Normal", "Hard"]
const PAUSE_AFTER := 1.8

## Two looks, both pure greyscale: Classic = black ink on paper, Voodoo = white ink on night.
## Owner round 3 (2026-11-15): a watercolour wash. Still black, white and grey, but with faint
## hues: a warm paper, blue-grey far hills, a slight blue for water, a faint red mark where a
## blow lands (`water`, `red`, `tint_far`, `tint_mid`, `haze` below).
const WASH := {
	"classic": {"paper": Color("efe8d8"), "paper2": Color("d6d4c8"), "far": Color("aeb6b9"), "mid": Color("858c86"), "moon": Color("f8efdc"), "fog": Color("eef0ee"),
		"water": Color(0.37, 0.5, 0.69, 0.6), "surf": Color(0.28, 0.42, 0.64, 0.9), "red": Color(0.8, 0.05, 0.04), "haze": Color("e4e7e8")},
	"voodoo": {"paper": Color("08090c"), "paper2": Color("181a1f"), "far": Color("262b33"), "mid": Color("3f4544"), "moon": Color("dcd6c8"), "fog": Color("566068"),
		"water": Color(0.13, 0.26, 0.6, 0.75), "surf": Color(0.4, 0.6, 0.9, 0.875), "red": Color(0.85, 0.1, 0.08), "haze": Color("3a4048")},
}
const LOOKS := {
	"classic": {"paper": Color("ece6d8"), "paper2": Color("d8d0bf"), "ink": Color("111111"), "far": Color("b9b2a4"), "mid": Color("8e887d"), "near": Color("4a4743"), "moon": Color("f7f3ea"), "fog": Color("f4f1ea"), "shadow": Color("2a2723"), "smoke": Color("8a857c")},
	"voodoo": {"paper": Color("08080a"), "paper2": Color("1a1a1d"), "ink": Color("f0f0f0"), "far": Color("2a2a2e"), "mid": Color("45454a"), "near": Color("707075"), "moon": Color("d9d9d9"), "fog": Color("5a5a60"), "shadow": Color("000000"), "smoke": Color("9a9aa0")},
}

var info = null
var home
var engine
var started := false
var skin := "classic"
var pal: Dictionary = LOOKS.classic.merged(WASH.classic, true)
var move := 0.0
var key_l := false
var key_r := false
var key_d := false
var key_b := false       # block held (keyboard I / Ctrl, old button)
var stick_up := false    # the stick was pushed up last frame (jump fires on the push)
## Tutorial lines (owner 2026-11-15: stage 1 teaches moving, crouching, jumping and the
## sword; stage 2 opens with block; stars and the thrust are announced when unlocked).
const TIPS := {
	"move": "Push the stick left or right to run.  (Keyboard: A / D)",
	"crouch": "Pull the stick down to crouch and creep under the beam.  (Keyboard: S)",
	"jump": "Push the stick up to jump; push again in the air to jump higher.  (Keyboard: W / Space)",
	"swing": "Press Swing to cut. Crouch and press Swing to jab low.  (Keyboard: J)",
	"block": "Hold Block to stop stars and blades in front of you.  (Keyboard: I / Ctrl)",
	"star": "New: Star throws a shuriken.  (Keyboard: K)",
	"bomb": "Press Bomb to drop a smoke bomb: foes in the cloud are blinded.  (Keyboard: B)",
	"rope": "The bridge is raised. Jump, then throw a Star at the rope knot.  (Keyboard: K)",
	"trap": "The spikes drop on a beat. Back off and let them chase you through.",
	"torch": "Night. Your torch lights the way: swing it at a dark lantern to light it.  (Keyboard: J)",
	"silver": "New: a silver sword. Every cut hits a quarter harder.",
	"gold": "New: a golden sword. Every cut hits a third harder.",
	"thrust": "New: Thrust lunges forward and runs your blade through a foe.  (Keyboard: L / Shift)",
}
var q := {"jump": false, "slash": false, "throw": false, "dash": false, "bomb": false}
var after := 0.0
var banner := ""
var anim_t := 0.0
var shake := 0.0
var splats: Array = []   # [pos, vel, life, size] flying drops
var stains: Array = []   # [world pos, size, alpha] ink left on the ground
var disc: Texture2D
var pines_far: Texture2D
var pines_mid: Texture2D
var pines_near: Texture2D
var fog_tex: Texture2D
var smoke: Array = []   # smoke puffs (_puff)
var mist: Array = []    # drifting wisps: [x 0..1, world y, speed, width, phase]
var motes: Array = []    # floating dust / embers: [screen x 0..1, screen y 0..1, rise speed, size, phase, depth, cool?]
const HEARTS_PATH := "user://ink_ninja_hearts.json"
const BAND := Color("8f3b36")   # the hero's red headband (owner 2026-11-15, matches the artwork)
var hearts: Array = []   # stages whose blood-red cherry tree has a heart carved in it (all 24 = achievement)
var toast := ""
var toast_t := 0.0
var band_hang := 0.0   # 1 = standing still: the headband tails hang
var band_rise := 0.0   # 1 = falling: the tails flutter upward
var flowers: Array = []  # cherry blossom textures (_make_flowers)
var blot: Texture2D      # an irregular ink blot for splashes and stains
var mount_tex: Texture2D # far mountain ridge (round 10 backgrounds)
var clouds: Array = []   # drifting cloud banks: [x 0..1.6, y, width, speed, phase]
var petals: Array = []   # falling blossom petals in front of the field: [x 0..1, y 0..1, fall, size, phase]
var sparks: Array = []   # impact streaks: [world pos, vel, life, max life, kind 0 steel / 1 ink / 2 gold]
var plate_sb: StyleBoxFlat   # the HUD plates
var hitstop := 0.0       # a short freeze when a blow lands
var flash := 0.0         # screen-edge flash (hurt = red, heal = gold)
var flash_col := Color(0.7, 0.05, 0.04)
var fade := 1.0          # paper fade between stages
var land_t := 0.0        # squash after landing
var jump_t := 0.0        # stretch after jumping
var score_shown := 0.0
var score_pop := 0.0
var boss_trail := 1.0
var boss_tex := {}        # loaded pose pictures ("<boss>_<pose>[_hard]" -> Texture2D or null)
var boss_hold := ""       # a pose held for a moment after the move ("cast" after a fan, "stagger" after losing a third)
var boss_hold_t := 0.0
var boss_third := 3       # thirds of health left (a lost third = a stagger)
var corpse := {}          # the beaten boss lying there: {x, y, face, act, t}
var rainbow: Array = []   # Hard: colour puffs round the boss [world pos, vel, life, max, hue, size]
var blade_trail: Array = []   # silver / gold sword: [hand, tip (world units from the hero's feet), age]
var hero_feet := Vector2.ZERO # screen feet of the hero this frame (the trail is kept relative to them)
var lock_dialog: Control
var intro: Control = null     # the intro film on screen (null = none)
var intro_then: Callable      # what runs when it ends or is skipped
var toast_col := Color(0.65, 0.08, 0.08)
var mood_col := Color(1, 0.86, 0.68)
var relife := false      # all lives were lost: they come back, the stage stays
var goals                # Goals (daily + weekly objectives)
var card_text := []      # the chapter card on screen: [title, text, objective] (empty = none)
var card_t := 0.0
var prologue := false    # stage 1 of a new game shows the prologue first
var paper: ColorRect     # paper grain + vignette shader over the field
var dark: ColorRect      # dusk / night wash with warm holes round the lights (ink_ninja_dark.gdshader)
var hud_layer: Control   # the HUD, above the dark wash
var scn                  # Scenery (houses, pagodas, statues, bridges...)
var extra_lives := 3     # the Landing helps, spent automatically when the last heart goes
var step_t := 0.0
var cutscene              # cutscene.gd (between-stage scenes, owner's storyboard 2026-11-15)
var cut_on := false
var cut_then: Callable    # what runs when the cutscene ends or is skipped
var cut_queue: Array = [] # scenes still to play in this slot
var all_scrolls := true   # every scroll of every stage so far was picked up (Ending B)

var field: Control
var hud: Label
var score_label: Label
var end_dialog: Control
var old_controls: Control

func _ready() -> void:
	preload("res://scripts/games/ink_ninja/ink_ninja_i18n.gd").install(self)
	Orientation.lock_landscape()
	engine = Engine_.new()
	engine.revive_cb = _auto_revive
	disc = _make_disc()
	scn = Scenery.new(self)
	blot = _make_blot()
	goals = Goals.new()
	pines_far = _make_pines(11, 34, 140.0, 260.0)
	pines_mid = _make_pines(23, 22, 200.0, 340.0)
	pines_near = _make_pines(37, 6, 280.0, 360.0)   # owner 2026-11-20: a dark near row
	fog_tex = _make_fog()
	mount_tex = _make_mountains()
	for i in 6:
		clouds.append([randf() * 1.6 - 0.2, randf_range(30.0, 250.0), randf_range(220.0, 420.0), randf_range(0.004, 0.012), randf() * TAU])
	for i in 26:
		petals.append([randf(), randf(), randf_range(0.03, 0.07), randf_range(5.0, 10.0), randf() * TAU])
	for i in 7:
		mist.append([randf() * 1.6 - 0.3, randf_range(380.0, 560.0), randf_range(0.006, 0.02), randf_range(260.0, 520.0), randf() * TAU])
	for i in 46:
		motes.append([randf(), randf(), randf_range(0.01, 0.045), randf_range(2.5, 7.0), randf() * TAU, randf_range(0.15, 0.9), randf() < 0.35])
	if FileAccess.file_exists(HEARTS_PATH):
		var hf := FileAccess.open(HEARTS_PATH, FileAccess.READ)
		var hd = JSON.parse_string(hf.get_as_text()) if hf else null
		if hd is Array:
			for v in hd:
				hearts.append(int(v))
	goals.load_data(Goals.today_num(), Goals.week_num())
	_build_ui()
	hud.visible = false   # round 10: the HUD is drawn on the field (hearts, stars, bombs, lives, score plates)
	score_label.visible = false
	_hud_colors()
	_paper_params()
	engine.reset(1)
	# Owner 2026-11-20: the intro film first, every time the game opens; the Landing music after it.
	var reload: bool = Time.get_ticks_msec() - int(get_tree().get_meta("ink_ninja_left", -100000)) < 2000
	if reload:
		# _music("calm", "asian")   # 🏠 Home reloaded the scene: no film again
		_menu_music()   # 🏠 Home reloaded the scene: no film again
	else:
		# _play_intro(_music.bind("calm", "asian"))
		_play_intro(_menu_music)

func _exit_tree() -> void:
	get_tree().set_meta("ink_ninja_left", Time.get_ticks_msec())   # tells a 🏠 Home reload from a fresh open

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

## A soft round brush dab, drawn with draw_texture_rect (cheap; draw_circle is not).
func _make_disc() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length() / (n / 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - d) * 6.0, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

## An irregular ink blot: a few overlapping dabs with a ragged edge (seeded, same every run).
func _make_blot() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var dabs: Array = [[Vector2(32, 32), 16.0]]
	for i in 7:
		var a := r.randf() * TAU
		dabs.append([Vector2(32, 32) + Vector2.RIGHT.rotated(a) * r.randf_range(8, 20), r.randf_range(4, 9)])
	for y in n:
		for x in n:
			var al := 0.0
			for d in dabs:
				var q2: float = (Vector2(x, y).distance_to(d[0]) - d[1]) / 2.0
				al = maxf(al, clampf(1.0 - q2, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, al * (0.85 + 0.15 * r.randf())))
	return ImageTexture.create_from_image(img)

## Paper grain and vignette for the current look.
func _paper_params() -> void:
	if paper == null:
		return
	var m: ShaderMaterial = paper.material
	# Colour grading per act (round 10): dawn, day, dusk, storm, night, blood dawn.
	var moods: Array = [Color(1.0, 0.86, 0.68, 0.12), Color(0.85, 0.93, 1.0, 0.07), Color(1.0, 0.55, 0.3, 0.15), Color(0.5, 0.6, 0.78, 0.17), Color(0.35, 0.35, 0.7, 0.2), Color(0.85, 0.2, 0.15, 0.15)]
	var mood: Color = moods[clampi(engine.act() - 1 if engine else 0, 0, 5)]
	if skin == "voodoo":
		mood = Color(mood.r * 0.5, mood.g * 0.55, mood.b * 0.9, mood.a * 0.7)
	m.set_shader_parameter("tint", mood)
	mood_col = mood
	if skin == "voodoo":
		m.set_shader_parameter("grain_col", Color(0.75, 0.75, 0.78))
		m.set_shader_parameter("edge_col", Color(0, 0, 0))
		m.set_shader_parameter("grain", 0.06)
		m.set_shader_parameter("edge", 0.6)
	else:
		m.set_shader_parameter("grain_col", Color(0.3, 0.27, 0.22))
		m.set_shader_parameter("edge_col", Color(0.12, 0.1, 0.08))
		m.set_shader_parameter("grain", 0.12)
		m.set_shader_parameter("edge", 0.4)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	field = Control.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)   # until _fit_field takes over (owner zoom 2026-11-20)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.clip_contents = true
	field.draw.connect(_draw_field)
	add_child(field)
	dark = ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dmat := ShaderMaterial.new()
	dmat.shader = DARK_SHADER
	dark.material = dmat
	field.add_child(dark)   # owner 2026-11-20: rides the field's zoom so the lantern holes stay put
	hud_layer = Control.new()
	hud_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.draw.connect(_draw_hud_layer)
	add_child(hud_layer)
	paper = ColorRect.new()
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PAPER_SHADER
	paper.material = mat
	add_child(paper)

	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_top", 16)
	top.add_theme_constant_override("margin_left", 24)
	top.add_theme_constant_override("margin_right", 24)
	add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 60)
	pause_btn.pressed.connect(_on_pause)
	HomeKit.style_button(pause_btn, Color("6a6a6a"))
	bar.add_child(pause_btn)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 24)
	hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(hud)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 34)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(score_label)

	# Fallback buttons for apps without the shared Pad.
	old_controls = HBoxContainer.new()
	old_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	old_controls.offset_top = -120
	old_controls.offset_bottom = -16
	old_controls.add_theme_constant_override("separation", 10)
	old_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(old_controls)
	for spec in [["◀", "left"], ["▶", "right"], ["▼", "down"], ["⤒", "jump"], ["⚔", "slash"], ["»", "dash"], ["✴", "throw"], ["●", "bomb"], ["⛨", "block"]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(110, 100)
		b.add_theme_font_size_override("font_size", 40)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("sfx", "")
		b.button_down.connect(_hold.bind(spec[1], true))
		b.button_up.connect(_hold.bind(spec[1], false))
		old_controls.add_child(b)
	if ResourceLoader.exists(PAD_PATH):
		old_controls.visible = false
		_add_pad()
	# Cutscenes sit over everything (pack code: no APK calls).
	cutscene = Cutscene_.new()
	add_child(cutscene)
	cutscene.finished.connect(_on_cutscene_done)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in DIFF_NAMES.size():
		# Owner 2026-11-20: Hard opens once the story is beaten on Normal (its bosses blaze with colour).
		modes.append({"text": ["Easy", "Normal", "Hard" if _hard_open() else "Hard 🔒"][i], "row": "diff",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_game.bind(i) if i < 2 else _try_hard})
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S1 Ghost; greys only, like the game.
		"landing": "ghost",
		"landing_style": MenuStyles,
		"title_font": "res://games/ink_ninja/title.ttf",
		"title_colors": [Color("050505")],   # all black (owner 2026-11-15), over a pale outline so it reads on the picture
		"title_outline": Color(0.96, 0.93, 0.86, 0.85),
		"title_scale": 0.78,
		"title_dx": 70.0,
		"landing_colors": [Color("0a0a0a"), Color("2a2a2a")],
		"menu_color": Color("e0e0e0"),
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": Color("d8d8d8"),
		"solo_heading": "Story",
		"more": [["Objectives", Color("8a8a8a"), _show_goals]],
		"subtitle": "Ink and steel. One ninja.",
		"art": "res://games/ink_ninja/landing_bg.jpg",   # owner picture 2026-11-15 (moon, pagoda, red-scarf ninja)
		"landing_art": true,
		"landing_art_alpha": 0.9,
		# "logo": _draw_home_logo,   # retired: the owner's Landing picture replaces the ensō drawing (2026-11-15)
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		# Owner 2026-11-16: the three helps are extra lives that work by themselves (no buttons):
		# see _auto_revive, which spends one from the kit's pool (HomeKit.helps_left / use_help).
		"board": "Best score",
	})
	add_child(home)
	if info:
		add_child(info)
	lock_dialog = UI.build_dialog("", [{"text": tr("OK"), "action": _go_home}], true)
	lock_dialog.get_meta("message_label").text = tr("Beat the story on Normal to unlock Hard.")
	add_child(lock_dialog)

# ---------- controls ----------

const PAD_PATH := "res://scripts/common/pad/pad_controller.gd"
const PAD_LAYOUTS_PATH := "res://scripts/common/pad/pad_layouts.gd"
var touch_pad: Control = null

func _add_pad() -> void:
	touch_pad = load(PAD_PATH).new()
	touch_pad.layout_override = "stick_4"
	# A fifth, smaller button for smoke bombs (owner 2026-11-16: crouch + Star was wrong).
	if ResourceLoader.exists(PAD_LAYOUTS_PATH) and "custom_layout" in touch_pad:
		var pl = load(PAD_LAYOUTS_PATH)
		touch_pad.custom_layout = pl.variant("stick_4", [], [{"type": "button", "id": "s", "side": "right", "off": [395, 120], "r": 44}], "ink_ninja")
	touch_pad.prefs_override = {"skin": "mono"}   # greyscale like the game
	touch_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(touch_pad)
	for part in ["pause", "info"]:
		touch_pad.set_hidden(part, true)
	# Owner 2026-11-15: the four buttons are Swing, Thrust, Star and Block; jumping is on
	# the stick (push up) or the keyboard. Locked moves stay hidden until they unlock.
	# Owner 2026-11-20 ("A won't swing after I jump / crouch / run" on a laptop): Windows ignores
	# touchpad taps while keys are held or just typed, so on a PC each button also names its key.
	var keys := {} if DisplayServer.is_touchscreen_available() else {"a": " (J)", "b": " (L)", "x": " (K)", "y": " (I)", "s": " (B)"}
	touch_pad.set_state("a", {"sub": tr("Swing") + keys.get("a", "")})
	touch_pad.set_state("b", {"sub": tr("Thrust") + keys.get("b", "")})
	touch_pad.set_state("x", {"sub": tr("Star") + keys.get("x", "")})
	touch_pad.set_state("y", {"sub": tr("Block") + keys.get("y", "")})
	touch_pad.set_state("s", {"sub": tr("Bomb") + keys.get("s", "")})
	touch_pad.button_pressed.connect(_on_pad_button)

## Show only the buttons this stage allows; a newly unlocked one pops in.
func _pad_unlocks(reveal: bool) -> void:
	if not touch_pad:
		return
	for pair in [["y", "block"], ["x", "star"], ["b", "thrust"], ["s", "bomb"]]:
		var ok: bool = engine.can(pair[1])
		if ok and reveal and int(Engine_.UNLOCK[pair[1]]) == engine.stage and touch_pad.has_method("reveal"):
			touch_pad.reveal(pair[0])
		else:
			touch_pad.set_hidden(pair[0], not ok)

func _on_pad_button(id: String) -> void:
	match id:
		"a":
			q.slash = true
		"b":
			q.dash = true
		"x":
			q.throw = true
		"s":
			q.bomb = true

func _hold(what: String, on: bool) -> void:
	match what:
		"left":
			key_l = on
		"right":
			key_r = on
		"down":
			key_d = on
		"block":
			key_b = on
		_:
			if on:
				q[what] = true

func _unhandled_input(event: InputEvent) -> void:
	if cut_on:
		return
	if not card_text.is_empty() and event is InputEventMouseButton and event.pressed:
		q.slash = true   # a tap closes the chapter card
		return
	if started and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and after == 0.0:
		var kk: float = field.size.y / Engine_.H
		var wx: float = (event.position.x - field.position.x) / field.scale.x / kk + engine.cam_x()
		for t in engine.trees:
			if t.blood and absf(t.x - wx) < 110.0:
				if absf(t.x - engine.px) < 260.0:
					_carve_here()
				else:
					pass   # owner 2026-11-20: no telling (was a "Walk up to the red tree first" toast)
	# Owner test keys (2026-11-20, keyboard only): F9 = to the end of the stage (the gate or
	# the boss), F10 = 1500 units ahead to look at the scenery.
	# F11 (2026-11-21) = invincible on / off (no damage; a fall returns you to the lantern).
	if started and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		engine.god = not engine.god
		_toast(tr("Invincible: on") if engine.god else tr("Invincible: off"), Color(0.2, 0.2, 0.2))
		return
	if started and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F9, KEY_F10]:
		var to: float = engine.arena_x - 150.0 if event.keycode == KEY_F9 else minf(engine.px + 1500.0, engine.arena_x - 150.0)
		engine.px = to
		engine.py = engine.ground_y(to) - 200.0
		engine.vx = 0.0
		engine.vy = 0.0
		return
	if event is InputEventKey and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				key_l = event.pressed
			KEY_RIGHT, KEY_D:
				key_r = event.pressed
			KEY_DOWN, KEY_S:
				key_d = event.pressed
			KEY_SPACE, KEY_W, KEY_UP:
				if event.pressed:
					q.jump = true
			KEY_J:
				if event.pressed:
					q.slash = true
			KEY_K:
				if event.pressed:
					q.throw = true
			KEY_B:
				if event.pressed:
					q.bomb = true
			KEY_L, KEY_SHIFT:
				if event.pressed:
					q.dash = true
			KEY_I, KEY_CTRL:
				key_b = event.pressed
			KEY_ESCAPE:
				if event.pressed and started:
					_on_pause()

# ---------- flow ----------

## Hard is open once the story was beaten on Normal or Hard (HARD_UNLOCK_PATH).
func _hard_open() -> bool:
	var d = SaveUtil.read(HARD_UNLOCK_PATH)
	return d is Dictionary and bool(d.get("hard", false))

func _try_hard() -> void:
	if _hard_open():
		_new_game(2)
	else:
		lock_dialog.visible = true
		move_child(lock_dialog, -1)

func _new_game(d: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset(d)
	prologue = true
	all_scrolls = true
	_cutscene_then(Cutscene_.for_stage(1), _begin)

## Play a cutscene (if there is one), then `then`. Play state stays "started" so leaving
## mid-scene still saves the run.
func _cutscene_then(scenes: Array, then: Callable) -> void:
	cut_queue = []
	if cutscene != null:
		for sc in scenes:
			if cutscene.has_scene(sc):
				cut_queue.append(sc)
	if cut_queue.is_empty():
		then.call()
		return
	started = true
	cut_on = true
	cut_then = then
	card_text = []
	end_dialog.visible = false
	cutscene.play(cut_queue.pop_front())

func _on_cutscene_done(_scene: String) -> void:
	if not cut_queue.is_empty():
		cutscene.play(cut_queue.pop_front())   # the next scene of the same slot
		return
	cut_on = false
	if cut_then.is_valid():
		var c := cut_then
		cut_then = Callable()
		c.call()

func _noop() -> void:
	pass

func _restart() -> void:
	_new_game(engine.diff)

func _begin() -> void:
	started = true
	after = 0.0
	banner = ""
	fade = 1.0
	relife = false
	boss_trail = 1.0
	corpse = {}
	rainbow.clear()
	boss_hold_t = 0.0
	score_shown = float(engine.score)
	_paper_params()
	# The chapter card stops play until any button / tap (or 6 s).
	var ch: Array = Story.CHAPTERS[engine.stage - 1]
	card_text = [tr(ch[0]), (tr(Story.PROLOGUE) + "\n\n" if prologue else "") + tr(ch[1]), tr(ch[2])]
	card_t = 6.0 if not prologue else 9.0
	prologue = false
	SoundLib.play(self, "rpg/book_flip", -6.0)
	SoundLib.play(self, "sword/draw_katana_fast", -8.0)
	# _music("calm", "asian")
	GameMusic.play(self, FIGHT_TRACK if engine.boss_stage() else ROAD_TRACKS[posmod(engine.stage - 1, ROAD_TRACKS.size())])
	_pad_unlocks(engine.stage == 2 or engine.stage == 3 or engine.stage == 4)
	splats.clear()
	stains.clear()
	end_dialog.visible = false
	_update_hud()

func _update_hud() -> void:
	if float(engine.score) > score_shown + 1.0:
		score_pop = 1.0
	extra_lives = HomeKit.helps_left(HELP.ID)
	hud.text = "♥".repeat(maxi(0, engine.hp)) + "♡".repeat(maxi(0, Engine_.MAX_HP - engine.hp)) + "   " + tr("Stars %d") % engine.stars + "   " + tr("Lives %d") % extra_lives
	score_label.text = str(engine.score)

func _process(delta: float) -> void:
	anim_t += delta
	_fit_field(delta)
	var still: bool = engine.on_ground and absf(engine.vx) < 20.0 and not engine.crouch
	var falling: bool = not engine.on_ground and engine.vy > 40.0
	band_hang = move_toward(band_hang, 1.0 if still else 0.0, delta * 3.0)
	band_rise = move_toward(band_rise, 1.0 if falling else 0.0, delta * 6.0)
	if touch_pad:
		touch_pad.visible = started and not end_dialog.visible and not cut_on
	if not started or cut_on:
		return
	delta = minf(delta, 0.05)
	shake = maxf(0.0, shake - delta * 30.0)
	flash = maxf(0.0, flash - delta * 2.2)
	land_t = maxf(0.0, land_t - delta)
	jump_t = maxf(0.0, jump_t - delta)
	score_pop = maxf(0.0, score_pop - delta * 4.0)
	score_shown = move_toward(score_shown, float(engine.score), maxf(40.0, absf(engine.score - score_shown) * 6.0) * delta)
	var fade_to := 1.0 if (after > 0.0 and after < 0.45) else 0.0
	fade = move_toward(fade, fade_to, delta * (2.4 if fade_to > fade else 1.6))
	if paper and paper.material:
		paper.material.set_shader_parameter("flash", flash)
		paper.material.set_shader_parameter("flash_col", flash_col)
	if not engine.boss.is_empty() and engine.boss.hp > 0:
		var ratio := float(engine.boss.hp) / float(engine.boss.max)
		boss_trail = maxf(ratio, move_toward(boss_trail, ratio, delta * 0.35))
	else:
		boss_trail = 1.0
	toast_t = maxf(0.0, toast_t - delta)
	_smoke_tick(delta)
	_boss_fx_tick(delta)
	for s in splats:
		s[0] += s[1] * delta
		s[1].y += 1400.0 * delta
		s[2] -= delta
		var sg: float = engine.ground_y(s[0].x)
		if s[2] <= 0.0 and s[0].y > sg - 20 and s[0].y < sg + 40 and stains.size() < 420 and engine.water_depth(s[0].x) <= 0.0:
			stains.append([Vector2(s[0].x, sg + 3), s[3] * (2.0 if s[4] else 1.4) * 0.7, 0.9 if s[4] else 0.55, s[4]])
	splats = splats.filter(func(s): return s[2] > 0.0)
	if not card_text.is_empty():
		card_t -= delta
		var any: bool = q.jump or q.slash or q.throw or q.dash or q.bomb
		for k in q:
			q[k] = false
		if card_t <= 0.0 or (any and card_t < 5.5):
			card_text = []
			SoundLib.play(self, "rpg/draw_knife", -6.0)
		field.queue_redraw()
		return
	if after < 0.0:
		after = minf(0.0, after + delta)
		if after == 0.0:
			banner = ""
	elif after > 0.0:
		after -= delta
		if after <= 0.0:
			after = 0.0
			banner = ""
			_after_pause()
		field.queue_redraw()
		return
	if hitstop > 0.0:
		hitstop -= delta   # a blow landed: a heartbeat of stillness
		field.queue_redraw()
		return
	var m := 0.0
	var dn := key_d
	var blk := key_b
	if touch_pad:
		var pv: Vector2 = touch_pad.get_vector("move")
		m = pv.x
		dn = dn or pv.y > 0.55
		var up := pv.y < -0.6
		if up and not stick_up:
			q.jump = true   # jump = push the stick up
		stick_up = up
		blk = blk or touch_pad.is_down("y")
		if absf(m) < 0.25:
			m = 0.0
	m = clampf(m + (1.0 if key_r else 0.0) - (1.0 if key_l else 0.0), -1.0, 1.0)
	var ev: Array = engine.step(delta, m, q.jump, q.slash, q.throw, q.dash, dn, blk, q.bomb)
	if engine.on_ground and absf(engine.vx) > 120.0 and engine.dash_t <= 0.0:
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.28
			SoundLib.play(self, "impact/footstep_grass", -18.0)
	for k in q:
		q[k] = false
	for e in ev:
		_event(e)
	if not ev.is_empty():
		_update_hud()
	field.queue_redraw()

## Carve a heart in the blood-red cherry tree (owner 2026-11-15): tap it, or swing near it.
## Carving it on every one of the 24 stages is an achievement.
func _try_carve() -> void:
	if engine.heart_tree_near().is_empty():
		return
	_carve_here()

func _carve_here() -> void:
	if hearts.has(engine.stage):
		_toast(tr("A heart is already carved here"))
		return
	hearts.append(engine.stage)
	var hf := FileAccess.open(HEARTS_PATH, FileAccess.WRITE)
	if hf:
		hf.store_string(JSON.stringify(hearts))
	if info:
		info.high("Hearts carved", hearts.size())
	SoundLib.play(self, "rpg/knife_slice", -4.0)
	_puff(Vector2(engine.px, engine.py - 50), 6, 14.0, 70.0)
	_toast(tr("Heart carved!"))

func _toast(t: String, col: Color = Color(0.65, 0.08, 0.08)) -> void:
	toast = t
	toast_t = 2.5
	toast_col = col

func _event(e: String) -> void:
	if e.begins_with("ink:") or e.begins_with("red:"):
		var p := e.split(":")
		_splash(Vector2(float(p[1]), float(p[2])), e.begins_with("red:"), p.size() > 3)
		return
	if e.begins_with("foedrown:"):
		var dq := e.split(":")
		_puff(Vector2(float(dq[1]), float(dq[2])), 8, 16.0, 100.0)
		SoundLib.play(self, "impact/soft_medium", -6.0, "game", 0.6)
		return
	if e.begins_with("bamboo:"):
		var bq := e.split(":")
		var bpos := Vector2(float(bq[1]), float(bq[2]))
		SoundLib.play(self, "rpg/knife_slice", -8.0, "game", 0.8)
		_puff(bpos, 6, 12.0, 90.0)
		for i in 6:
			sparks.append([bpos, Vector2(randf_range(-160, 160), randf_range(-260, -60)), 0.5, 0.5, 1])
		return
	if engine.diff == 2 and not engine.boss.is_empty():
		_hard_fx(e)
	match e:
		"bosskill":
			var kb: Dictionary = engine.boss
			corpse = {"x": kb.x, "y": Engine_.GROUND, "face": kb.face, "act": engine.act(), "t": 0.0}
		"bossfan":
			boss_hold = "cast"
			boss_hold_t = 0.45
		"jump", "walljump":
			jump_t = 0.16
			_puff(Vector2(engine.px, engine.py - 2), 3, 10.0, 50.0)
			SoundLib.play(self, "rpg/cloth", -4.0, "game", 1.15)   # a cloth whip, not the arcade boing (owner 2026-11-15)
		"dash":
			SoundLib.play(self, "sword/swing_seax", -3.0)   # was rpg/draw_knife at 0.85 pitch
			_puff(Vector2(engine.px, engine.py - 10), 6, 18.0, 90.0)
		"slash", "slash_up", "slash_down":
			_try_carve()
			SoundLib.play(self, "sword/swing_katana", -5.0)   # was rpg/draw_knife, a blade whoosh (owner 2026-11-15); real katana swings now
		"jab":
			_try_carve()
			SoundLib.play(self, "sword/swing_dagger", -6.0)   # was rpg/knife_slice
		"block":
			SoundLib.play(self, "sword/clash", -4.0)   # was impact/metal_light
			_goal("parries")
		"throw":
			_sfx("shoot")
		"parry":
			SoundLib.play(self, "sword/clash_sabre", -4.0)   # was impact/metal_heavy
			_goal("parries")
			if info:
				info.add("Stars parried")
		"kill":
			hitstop = 0.08
			shake = maxf(shake, 5.0)
			SoundLib.play(self, "sword/attack", -3.0)   # was rpg/chop
			_goal("kills")
			if info:
				info.add("Ninjas defeated")
		"hit", "bosshit":
			hitstop = 0.05
			SoundLib.play(self, "impact/punch_medium", -6.0)
		"checkpoint":
			SoundLib.play(self, "impact/bell_heavy", -10.0, "game", 1.4)
			_puff(Vector2(engine.px, engine.py - 60), 5, 14.0, 60.0)
			var lantern: int = engine.checkpoints.find(engine.checkpoint_x) + 1
			_cutscene_then(Cutscene_.for_slot("lantern:%d:%d" % [engine.stage, lantern]), _noop)
		"scroll":
			SoundLib.play(self, "reward/coin_plingy", -8.0, "game", 1.3)   # a coin now (owner 2026-11-19), was rpg/book_flip
			_goal("scrolls")
		"starkill":
			_goal("star_kills")
		"combo5":
			SoundLib.play(self, "reward/coin_plingy", -6.0)
			_goal("combo5")
		"land":
			land_t = 0.2
			_puff(Vector2(engine.px, engine.py - 4), 4, 14.0, 70.0)
			SoundLib.play(self, "impact/soft_medium", -14.0)
		"splash":
			SoundLib.play(self, "impact/soft_medium", -6.0, "game", 0.6)
			_puff(Vector2(engine.px, engine.water_level(engine.px)), 6, 14.0, 120.0)
		"swim":
			SoundLib.play(self, "impact/soft_medium", -16.0, "game", 0.75)
		"breathe":
			_sfx("whoosh")
		"telegraph":
			SoundLib.play(self, "impact/bell_heavy", -16.0)
		"hurt":
			flash = 1.0
			flash_col = Color(0.7, 0.04, 0.03)
			hitstop = 0.07
			SoundLib.play(self, "creature/grunt", -1.0, "game", 1.25)   # a grunt when the hero is hit (owner 2026-11-15)
			SoundLib.play(self, "impact/punch_medium", -8.0)
			shake = 10.0
		"slam":
			shake = 14.0
			_puff(Vector2(engine.boss.x, engine.boss.y - 6), 14, 30.0, 220.0)
			SoundLib.play(self, "impact/wood_heavy", -4.0)
		"boss":
			boss_third = 3
			corpse = {}
			banner = tr(engine.boss_name())
			after = -1.6
			SoundLib.play(self, "impact/bell_heavy", -4.0)
			# _music("techno")
			GameMusic.play(self, BOSS_TRACK, "", 1.0)
		"pogo":
			hitstop = 0.05
			_puff(Vector2(engine.px, engine.py), 4, 12.0, 60.0)
			SoundLib.play(self, "impact/soft_medium", -8.0, "game", 1.3)
		"light":
			SoundLib.play(self, "impact/bell_heavy", -12.0, "game", 1.9)
			for i in 12:
				sparks.append([Vector2(engine.px + engine.facing * 60.0, engine.py - 50.0), Vector2(randf_range(-160, 160), randf_range(-300, -60)), 0.8, 0.8, 2])
		"secret":
			# Owner 2026-11-19: no "A secret!" text, no "You reached the top": just the find.
			# _heal_fx(tr("A secret!"))
			SoundLib.play(self, "reward/coin_plingy", -4.0, "game", 0.8)
			for i in 10:
				sparks.append([Vector2(engine.px, engine.py - 60.0), Vector2(randf_range(-140, 140), randf_range(-260, -60)), 0.7, 0.7, 2])
			if info:
				info.add("Secrets found")
		"pagoda":
			# _toast(tr("You reached the top"), Color(0.45, 0.3, 0.02))
			if info:
				info.add("Pagodas climbed")
		"trapslam":
			# shake = maxf(shake, 5.0)
			# Owner 2026-11-21 ("screen shaking every few seconds, level 5"): every spike board on the
			# stage shook the screen on its beat, even far off screen. Only a near one does now, softly.
			if _trap_near(300.0):
				shake = maxf(shake, 3.0)
			SoundLib.play(self, "impact/wood_heavy", -8.0, "game", 0.8)
		"trapkill":
			_toast(tr("Trapped!"), Color(0.2, 0.2, 0.2))
		"revive":
			flash = 1.0
			flash_col = Color(0.95, 0.78, 0.3)
			SoundLib.play(self, "reward/coin_plingy", -4.0, "game", 0.8)
			_toast(tr("An extra life: back on your feet"), Color(0.45, 0.3, 0.02))
			_update_hud()
		"heal":
			_heal_fx(tr("Scrolls restore a heart"))
		"torii":
			_heal_fx(tr("The gate blesses you: +1 heart"))
		"pick:star":
			_pick_fx(tr("+2 Stars"), 2)
		"pick:heart":
			_heal_fx(tr("+1 heart"))
		"pick:bomb":
			_pick_fx(tr("+1 smoke bomb"), 2)
		"bomb":
			SoundLib.play(self, "impact/soft_medium", -4.0, "game", 0.5)
			_sfx("whoosh")
			var bp: Vector2 = Vector2(engine.px + engine.facing * 70.0, engine.py - 20.0)
			_puff(bp, 12, 40.0, 160.0)
		"rope":
			SoundLib.play(self, "sword/clash", -6.0, "game", 1.3)
			SoundLib.play(self, "impact/wood_heavy", -4.0)
			shake = 9.0
			_toast(tr("The bridge falls into place"), Color(0.2, 0.2, 0.2))
			for br in engine.bridges:
				if br.cut and br.t < 0.1:
					_puff(Vector2(br.x0, br.y - 20.0), 12, 36.0, 200.0)
		"spiked":
			_toast(tr("Spikes!"))
		"die":
			banner = tr("Fallen!") if engine.state == "dead" else tr("Game over!")
			after = PAUSE_AFTER
			SoundLib.play(self, "jingles/lose_failed", -6.0)
		"win":
			SoundLib.play(self, "jingles/win_victory", -4.0)
			SoundLib.play(self, "sword/sheath_katana_slow", -6.0)
			if not engine.scrolls.is_empty():
				all_scrolls = false
			_goal("bosses")
			_goal("stages")
			if engine.hits_taken == 0:
				_goal("nohit")
			if engine.diff == 2:
				_goal("hard_bosses")
			banner = tr("%s defeated!") % tr(engine.boss_name())
			after = PAUSE_AFTER + 0.6
			if info:
				info.add("Bosses defeated")
				info.high("Highest stage", engine.stage)
		"clear":
			# A stage without a boss, cleared at its gate (24-stage campaign, owner 2026-11-15).
			SoundLib.play(self, "jingles/win_succeeded", -4.0)
			SoundLib.play(self, "sword/sheath_katana_fast", -6.0)
			if not engine.scrolls.is_empty():
				all_scrolls = false
			_goal("stages")
			if engine.hits_taken == 0:
				_goal("nohit")
			banner = tr("Stage cleared!")
			after = PAUSE_AFTER + 0.6
			if info:
				info.high("Highest stage", engine.stage)

func _heal_fx(t: String) -> void:
	flash = 0.8
	flash_col = Color(0.95, 0.78, 0.3)
	_toast(t, Color(0.45, 0.3, 0.02))
	SoundLib.play(self, "reward/coin_plingy", -6.0, "game", 1.2)
	for i in 10:
		sparks.append([Vector2(engine.px, engine.py - 30.0), Vector2(randf_range(-120, 120), randf_range(-320, -80)), 0.8, 0.8, 2])

func _pick_fx(t: String, n: int) -> void:
	_toast(t, Color(0.2, 0.2, 0.2))
	SoundLib.play(self, "reward/coin_plingy", -10.0, "game", 1.5)
	for i in n * 3:
		sparks.append([Vector2(engine.px, engine.py - 30.0), Vector2(randf_range(-200, 200), randf_range(-240, -40)), 0.5, 0.5, 2])

func _after_pause() -> void:
	match engine.state:
		"dead":
			engine.retry()
			_begin()
		"won":
			engine.next_stage()
			if engine.state == "cleared":
				var fin: Array = Cutscene_.for_slot("final")
				if all_scrolls:
					fin.append_array(Cutscene_.for_slot("final_all_scrolls"))
				_cutscene_then(fin, _game_over.bind(true))
			else:
				_save_game()
				_cutscene_then(Cutscene_.for_stage(engine.stage), _begin)
		"over":
			_game_over(false)

## red: a blow the hero landed (owner 2026-11-15: a slight red mark); otherwise grey ink.
func _splash(p: Vector2, red: bool = false, big: bool = false) -> void:
	_puff(p, 3, 16.0, 60.0)
	for i in (12 if big else (8 if red else 5)):
		var sa := randf() * TAU
		sparks.append([p, Vector2.RIGHT.rotated(sa) * randf_range(260.0, 720.0), randf_range(0.14, 0.3), 0.3, 0 if red else 1])
	for i in (22 if big else (10 if red else 16)):
		var v := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(120, 520) + Vector2(0, -220)
		splats.append([p, v, randf_range(0.35, 0.8), randf_range(5.0, 14.0) * (0.8 if red else 1.0), red])
	# A kill leaves a big pool plus spatter that stays for the whole stage (owner 2026-11-15).
	for n in (4 if big else 1):
		var sx := p.x + randf_range(-30, 30) * (2.0 if big else 1.0)
		if stains.size() < 420 and engine.water_depth(sx) <= 0.0:
			stains.append([Vector2(sx, engine.ground_y(sx) + 3), (randf_range(50, 85) if (big and n == 0) else (randf_range(26, 48) if big else randf_range(22, 40))) * 0.7, 0.9 if red else 0.7, red])   # owner: 30% smaller

func _game_over(won: bool) -> void:
	started = false
	SaveUtil.delete(SAVE_PATH)
	if won and engine.diff >= 1:
		SaveUtil.write(HARD_UNLOCK_PATH, {"hard": true})
	var msg := (tr("You mastered the ink!") + "\n" + tr(Story.EPILOGUE) if won else tr("Game over!")) + "\n" + tr("Score: %d") % engine.score
	if info:
		info.add("Games played")
		info.result("win" if won else "loss")
		info.high("Highest stage", engine.stage)
		info.high("Best score (%s)" % DIFF_NAMES[engine.diff], engine.score)
		if info.high("Best score", engine.score):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- drawing ----------

func _draw_field() -> void:
	var c := field
	var sz := c.size
	var k := sz.y / Engine_.H
	var cam: float = engine.cam_x()
	var sh := Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) * k
	# Paper with a soft wash toward the bottom.
	var bands := 14
	var sky_top: Color = pal.paper.lerp(pal.far, 0.6)   # a watercolour sky: tinted at the top, clear toward the horizon
	for i in bands:
		var bt := float(i) / bands
		var bc: Color = sky_top.lerp(pal.paper, smoothstep(0.0, 0.55, bt)) if bt < 0.55 else pal.paper.lerp(pal.paper2, (bt - 0.55) / 0.45)
		c.draw_rect(Rect2(0, sz.y * i / bands, sz.x, sz.y / bands + 1), bc)
	# Misty pine forest (owner's references, 2026-11-14): far and mid pine layers fading into
	# fog, tall dark trunks in front, each scrolling slower than the ground.
	_draw_sky(c, sz, k, cam)
	# Owner 2026-11-20: the pines a little darker, the nearer ones darkest (like his photo).
	#_pine_layer(c, pines_far, cam * 0.12, k, 440.0, pal.far)
	_pine_layer(c, pines_far, cam * 0.12, k, 440.0, Color(pal.far).lerp(pal.mid, 0.35))
	_fog(c, k, 300.0, 470.0, 0.8)
	#_pine_layer(c, pines_mid, cam * 0.3, k, 540.0, pal.mid)
	_pine_layer(c, pines_mid, cam * 0.3, k, 540.0, Color(pal.mid).lerp(pal.near, 0.4))
	_fog(c, k, 420.0, 560.0, 0.6)
	_pine_layer(c, pines_near, cam * 0.45, k, 600.0, Color(pal.near).lerp(pal.shadow, 0.35))
	_fog(c, k, 480.0, 600.0, 0.55)
	_trunks(c, cam * 0.62, k)
	_fog(c, k, 520.0, 600.0, 0.5)
	var o := Vector2(-cam * k, 0) + sh
	_draw_water_back(c, o, k)
	_draw_ground(c, o, sz, k)
	# Ledges, pillars and walls: solid ink with a dry-brush top edge.
	for s in engine.solids:
		var r := Rect2(o + s.position * k, s.size * k)
		if r.end.x < 0 or r.position.x > sz.x:
			continue
		if engine.roofs.has(s):
			continue   # roofs and bridge decks are drawn with their building
		var tower: bool = s.size.y >= 30.0
		if tower and s.size.y < 600.0:
			# Stand on the ground, never sink into it (owner 2026-11-15): cut the bottom at the earth.
			var gb: float = maxf(engine.ground_y(s.position.x), engine.ground_y(s.position.x + s.size.x))
			r.size.y = minf(r.size.y, o.y + (gb + 1.0) * k - r.position.y)
		if tower:
			# Towers, stumps and walls: grey stone blocks with ink mortar and an ink outline,
			# so they stand apart from the black earth (owner 2026-11-15).
			c.draw_rect(r, pal.near)
			var mortar := PackedVector2Array()
			var row := 0
			var by := r.position.y + 18.0 * k
			while by < minf(r.end.y, field.size.y):
				mortar.append(Vector2(r.position.x, by))
				mortar.append(Vector2(r.end.x, by))
				var bx := r.position.x + (12.0 if row % 2 == 0 else 26.0) * k
				while bx < r.end.x:
					mortar.append(Vector2(bx, by - 18.0 * k))
					mortar.append(Vector2(bx, by))
					bx += 28.0 * k
				by += 18.0 * k
				row += 1
			c.draw_multiline(mortar, pal.ink, 1.5 * k)
			c.draw_rect(r, pal.ink, false, 3.0 * k)
			continue
		c.draw_rect(r, pal.ink)
		if s.size.y < 30.0:
			# A ledge is a floating chunk of earth (owner's reference pictures): a ragged,
			# tapering underside hanging below the walkable top.
			var under := PackedVector2Array([r.position + Vector2(0, r.size.y)])
			var n := maxi(3, int(s.size.x / 30.0))
			for i in range(1, n):
				var t := float(i) / n
				var depth := (sin(t * PI) * 46.0 + fmod(s.position.x * 0.7 + i * 37.0, 14.0)) * k
				under.append(Vector2(r.position.x + r.size.x * t, r.end.y + depth))
			under.append(r.end)
			_poly(c, under, pal.ink)
		var y := r.position.y
		var x := r.position.x
		while x < r.end.x:
			var w := minf(18.0 * k, r.end.x - x)
			c.draw_line(Vector2(x, y - 2 * k), Vector2(x + w, y - (2 + fmod(x * 0.37, 3.0)) * k), pal.ink, 2.0 * k)
			x += w
	for st in stains:
		var p: Vector2 = o + st[0] * k
		c.draw_texture_rect(blot, Rect2(p - Vector2(st[1], st[1] * 0.3) * k, Vector2(st[1] * 2, st[1] * 0.6) * k), false, Color(pal.red, minf(st[2], 1.0)) if st[3] else Color(pal.near, st[2]))
	_draw_flora(c, o, sz, k)
	_draw_torii(c, o, sz, k, -1)
	_draw_trees(c, o, sz, k)
	_draw_structs(c, o, sz, k)
	# Arena gate.
	if engine.locked:
		var gx: float = o.x + engine.arena_x * k
		for i in 4:
			c.draw_line(Vector2(gx + (8 + i * 9) * k, 0), Vector2(gx + (8 + i * 9) * k, Engine_.GROUND * k), pal.near, 4.0 * k)
	for cpx in engine.checkpoints:
		_lantern(c, o + Vector2(cpx, engine.ground_y(cpx)) * k, k, engine.checkpoint_x >= cpx)
	for s in engine.scrolls:
		_scroll(c, o + s * k, k, s.x)
	_draw_props(c, o, sz, k)
	for f in engine.foes:
		_shadow(c, o, f.x, f.y, k, 26.0)
	if not engine.boss.is_empty() and engine.boss.hp > 0:
		_shadow(c, o, engine.boss.x, engine.boss.y, k, 40.0)
	_shadow(c, o, engine.px, engine.py, k, 24.0)
	for f in engine.foes:
		_figure(c, o + Vector2(f.x, f.y) * k, k, f.face, f.kind, f.hit > 0.0, f.get("atk", 0.0) > 0.0, absf(f.vx) > 30.0 and f.y >= engine.ground_y(f.x) - 2.0, f.x * 0.11 + f.id)
	if not engine.boss.is_empty() and engine.boss.hp > 0:
		var b: Dictionary = engine.boss
		var tele: bool = b.phase != "idle" and b.t > 0.0
		_draw_rainbow(c, o, k)
		_boss_art(c, o + Vector2(b.x, b.y) * k, k, b, tele)   # each act's own boss (was: _figure "boss%d" by move set)
	elif not corpse.is_empty():
		_draw_rainbow(c, o, k)
		var fa: float = clampf(1.0 - (corpse.t - 1.4) / 1.2, 0.0, 1.0)   # lies there, then dissolves into the paper
		_draw_pose(c, o + Vector2(corpse.x, corpse.y) * k, k, corpse.act, "dead", corpse.face, Color(1, 1, 1, fa))
	for s in engine.shots:
		if s.get("boss", false) and engine.diff == 2:
			_rainbow_shot(c, o + Vector2(s.x, s.y) * k, Vector2(s.vx, s.vy), k)
		else:
			_star(c, o + Vector2(s.x, s.y) * k, k, s.mine)
	if engine.hurt_t <= 0.0 or fmod(anim_t, 0.16) < 0.08:
		var sq := Vector2(1.0, 1.0)
		if land_t > 0.0:
			sq = Vector2(1.0 + 0.14 * land_t / 0.2, 1.0 - 0.16 * land_t / 0.2)
		elif jump_t > 0.0:
			sq = Vector2(1.0 - 0.08 * jump_t / 0.16, 1.0 + 0.12 * jump_t / 0.16)
		elif engine.on_ground and absf(engine.vx) < 20.0:
			sq.y = 1.0 + 0.014 * sin(anim_t * 2.4)   # breathing at rest
		var lean: float = clampf(engine.vx / Engine_.RUN, -1.2, 1.2) * 0.07
		c.draw_set_transform(o + Vector2(engine.px, engine.py) * k, lean, sq)
		_ninja(c, Vector2.ZERO, k)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_torii(c, o, sz, k, 1)   # the right half of each gate is in front of the hero
	for sp in sparks:
		var sa: float = sp[2] / sp[3]
		var sv: Vector2 = sp[1]
		var spp: Vector2 = o + sp[0] * k
		var scol: Color = [Color(1.0, 0.95, 0.85, sa), Color(pal.ink, sa), Color(1.0, 0.8, 0.3, sa)][sp[4]]
		c.draw_line(spp, spp - sv.normalized() * (6.0 + 22.0 * sa) * k, scol, (2.0 + 2.0 * sa) * k)
	for s in splats:
		var p: Vector2 = o + s[0] * k
		var r: float = s[3] * k
		c.draw_texture_rect(blot, Rect2(p - Vector2(r, r), Vector2(r, r) * 2), false, Color(pal.red, 0.95) if s[4] else pal.ink)
	_draw_water_front(c, o, k)
	_draw_breath(c, o, k)
	_draw_smoke(c, o, k)
	_draw_mist(c, sz, k)
	_draw_motes(c, sz, k)
	_draw_petals(c, sz, k)
	_draw_haze(c, o, sz, k)
	_update_dark(sz, k, o)
	hud_layer.queue_redraw()

## Owner 2026-11-20: on a wide landscape phone the world looked tiny. The field is zoomed in
## (up to 1.4x) as far as the screen width still shows the whole boss arena (VIEW_W); the
## extra height is cut mostly from the sky and follows the hero up a pagoda.
var view_y := 0.0
var zoom := 0.0
func _fit_field(delta: float) -> void:
	if field == null:
		return
	var vs := size
	if vs.y < 1.0 or vs.x < 1.0:
		return
	#var z := clampf(vs.x / vs.y * Engine_.H / Engine_.VIEW_W, 1.0, 1.4)
	# Owner 2026-11-20: portrait phones look right; landscape phones need about the same
	# world scale, so a touch screen in landscape shows ~380 units of height (ground low on
	# screen). The boss arena eases back out so its whole width (VIEW_W) fits.
	var fit := vs.x / vs.y * Engine_.H / Engine_.VIEW_W
	var zt := clampf(fit, 1.0, 1.4)
	if DisplayServer.is_touchscreen_available() and vs.x > vs.y:
		zt = 1.9
	if engine.locked:
		zt = clampf(fit, 1.0, zt)
	zoom = zt if delta <= 0.0 or zoom <= 0.0 else lerpf(zoom, zt, minf(1.0, delta * 2.0))
	var z := zoom
	var extra := vs.y * (z - 1.0)
	var k := vs.y / Engine_.H
	var want := vs.y * 0.84 - Engine_.GROUND * k * z   # the ground line at 84 % of the screen
	want = maxf(want, vs.y * 0.2 - (engine.py - 70.0) * k * z)   # keep the hero's head in view
	want = clampf(want, -extra, 0.0)
	view_y = want if delta <= 0.0 or absf(view_y - want) > extra + 1.0 else lerpf(view_y, want, minf(1.0, delta * 4.0))
	field.set_anchors_preset(Control.PRESET_TOP_LEFT)
	field.scale = Vector2(z, z)
	# Zoomed in, the hero would stand right of centre (the camera keeps him at 0.38 x VIEW_W):
	# slide the field left so he stays at 38 % of what is visible, with room to see ahead.
	var visw := vs.x / z / k
	var off := clampf(engine.px - engine.cam_x() - visw * 0.38, 0.0, Engine_.VIEW_W * 0.38)
	field.size = Vector2(vs.x / z + off * k, vs.y)
	field.position = Vector2(-off * k * z, view_y)
	if dark:
		dark.position = Vector2.ZERO
		dark.size = field.size

func _draw_hud_layer() -> void:
	var sz := hud_layer.size
	var k := sz.y / Engine_.H
	_hud_draw(hud_layer, sz, k)
	if fade > 0.01:
		hud_layer.draw_rect(Rect2(Vector2.ZERO, sz), Color(pal.paper, fade))

## The dusk / night wash with warm holes round the lit lanterns and the hero's torch.
func _update_dark(sz: Vector2, k: float, o: Vector2) -> void:
	if dark == null or dark.material == null:
		return
	var m: ShaderMaterial = dark.material
	# Owner 2026-11-20: the three night stages run back to back and get darker: sunset, dusk, pitch black.
	var nl_lv: int = engine.night_level()
	var dim: float = [0.2 if skin == "classic" else 0.12, 0.5, 0.75, 0.97][nl_lv]
	var arr := PackedVector4Array()
	if engine.night:
		arr.append(Vector4((o.x + engine.px * k) / sz.x, (o.y + (engine.py - 40.0) * k) / sz.y, 0.3 + 0.012 * sin(anim_t * 11.0), 0.9))   # the torch
	var rad := 0.4 if engine.night else 0.33
	for cpx in engine.checkpoints:
		if engine.checkpoint_x >= cpx and arr.size() < 12:
			var lx: float = o.x + cpx * k
			if lx > -400.0 * k and lx < sz.x + 400.0 * k:
				arr.append(Vector4(lx / sz.x, (o.y + (engine.ground_y(cpx) - 60.0) * k) / sz.y, rad + 0.01 * sin(anim_t * 3.0), 1.0))
	for nl in engine.night_lanterns:
		if nl.lit and arr.size() < 12:
			var nx: float = o.x + nl.x * k
			if nx > -400.0 * k and nx < sz.x + 400.0 * k:
				arr.append(Vector4(nx / sz.x, (o.y + (engine.ground_y(nl.x) - 60.0) * k) / sz.y, 0.42 + 0.01 * sin(anim_t * 3.0 + nl.x), 1.0))
	var n := arr.size()
	while arr.size() < 12:
		arr.append(Vector4(0, 0, 0.001, 0))
	m.set_shader_parameter("lights", arr)
	m.set_shader_parameter("count", n)
	m.set_shader_parameter("dim", dim)
	m.set_shader_parameter("aspect", sz.x / maxf(1.0, sz.y))
	var shades: Array = [Color(0.05, 0.05, 0.14), Color(0.45, 0.16, 0.06), Color(0.14, 0.06, 0.2), Color(0.0, 0.0, 0.02)]
	m.set_shader_parameter("shade", shades[nl_lv] if skin == "classic" else Color(0.0, 0.0, 0.03))

## Round 10 sky: a glowing moon with halo rings, soft god rays, slow cloud banks and a far
## mountain ridge between the moon and the pines (all parallax, all cheap textures).
func _draw_sky(c: CanvasItem, sz: Vector2, k: float, cam: float) -> void:
	var ms := 1.45 if engine.night else 1.0   # the night moon is big and bright
	var mp := Vector2(sz.x * 0.72, sz.y * (0.16 if engine.night else 0.13))
	var pulse := 0.9 + 0.1 * sin(anim_t * 0.5)
	if engine.night_level() >= 2:   # no stars yet at sunset
		for i in 70:
			var sx := fposmod(i * 0.6180339 * 7.0, 1.0) * sz.x
			var sy := fposmod(i * 0.7548776 * 3.0, 1.0) * sz.y * 0.55
			var tw := 0.4 + 0.6 * absf(sin(anim_t * (0.8 + fmod(i, 5) * 0.3) + i))
			var sr := (1.5 + fmod(i, 3)) * k
			c.draw_texture_rect(disc, Rect2(Vector2(sx - sr, sy - sr), Vector2(sr, sr) * 2.0), false, Color(1.0, 0.97, 0.88, 0.8 * tw))
	c.draw_texture_rect(disc, Rect2(mp - Vector2(380, 380) * k * ms, Vector2(760, 760) * k * ms), false, Color(pal.moon, 0.16 * pulse))
	c.draw_texture_rect(disc, Rect2(mp - Vector2(210, 210) * k * ms, Vector2(420, 420) * k * ms), false, Color(pal.moon, 0.2 * pulse))
	c.draw_texture_rect(disc, Rect2(mp - Vector2(104, 104) * k * ms, Vector2(208, 208) * k * ms), false, Color(pal.near, 0.16))   # an ink-wash ring so the moon reads on pale paper
	c.draw_texture_rect(disc, Rect2(mp - Vector2(90, 90) * k * ms, Vector2(180, 180) * k * ms), false, Color(pal.moon, 0.95))
	c.draw_texture_rect(disc, Rect2(mp - Vector2(60, 60) * k * ms + Vector2(14, 8) * k * ms, Vector2(70, 70) * k * ms), false, Color(pal.far, 0.18))   # a crater smudge
	for i in 4:
		var sh := 0.5 + 0.5 * sin(anim_t * 0.4 + i * 1.7)
		var a0 := 1.9 + i * 0.22
		var d := Vector2(cos(a0), sin(a0))
		var perp := d.orthogonal() * (26.0 + i * 8.0) * k
		var far := mp + d * sz.y * 1.2
		_poly(c, PackedVector2Array([mp - perp * 0.2, mp + perp * 0.2, far + perp * 1.6, far - perp * 1.6]), Color(pal.moon, 0.035 + 0.03 * sh))
	# Horizon glow in the act's mood colour (dawn gold, dusk orange, storm blue...).
	c.draw_texture_rect(disc, Rect2(Vector2(sz.x * 0.5 - sz.x * 0.8, 470.0 * k - 150.0 * k), Vector2(sz.x * 1.6, 300.0 * k)), false, Color(mood_col.r, mood_col.g, mood_col.b, 0.42))
	var mw2 := 1024.0 * k * 1.9
	var mx2 := -fmod(cam * 0.025 * k + 300.0 * k, mw2)
	var mtop2 := 330.0 * k - 300.0 * k * 1.9 + 60.0 * k
	while mx2 < sz.x:
		c.draw_texture_rect(mount_tex, Rect2(mx2, mtop2, mw2 + 1.0, 300.0 * k * 1.9), false, Color(pal.far.lerp(pal.paper, 0.6), 0.55))
		mx2 += mw2
	# The palace on the far horizon: small at the first stage, towering by the last (owner 2026-11-16).
	var prog: float = clampf((float(engine.stage - 1) + engine.progress()) / float(Engine_.STAGES - 1), 0.0, 1.0)
	scn.palace(c, sz.x * lerpf(0.82, 0.5, prog), 405.0 * k + 70.0 * k * prog, lerpf(55.0, 440.0, pow(prog, 1.5)) * k, Color(pal.far.lerp(pal.paper, 0.1), 0.88), clampf((prog - 0.55) / 0.4, 0.0, 1.0))
	var mw := 1024.0 * k * 1.3
	var mx := -fmod(cam * 0.05 * k, mw)
	var mtop := 395.0 * k - 300.0 * k * 1.3 + 40.0 * k
	while mx < sz.x:
		c.draw_texture_rect(mount_tex, Rect2(mx, mtop, mw + 1.0, 300.0 * k * 1.3), false, Color(pal.far.lerp(pal.paper, 0.35), 0.8))
		mx += mw
	c.draw_rect(Rect2(0, mtop + 300.0 * k * 1.3 - 1.0, sz.x, 400.0 * k), Color(pal.far.lerp(pal.paper, 0.35), 0.8))
	for cl in clouds:
		var cx: float = fposmod(cl[0] * sz.x - cam * 0.04 * k, sz.x * 1.8) - sz.x * 0.3
		var w: float = cl[2] * k
		var cy: float = cl[1] * k + sin(anim_t * 0.2 + cl[4]) * 4.0 * k
		c.draw_texture_rect(disc, Rect2(Vector2(cx - w, cy - w * 0.12), Vector2(w * 2.0, w * 0.24)), false, Color(pal.fog, 0.3))
		c.draw_texture_rect(disc, Rect2(Vector2(cx - w * 0.6, cy - w * 0.2), Vector2(w * 1.2, w * 0.3)), false, Color(pal.fog, 0.22))

## Foreground blossom petals drifting across the screen.
func _draw_petals(c: CanvasItem, sz: Vector2, k: float) -> void:
	var col := Color(0.93, 0.62, 0.68, 0.75) if skin == "classic" else Color(0.75, 0.78, 0.9, 0.55)
	for pe in petals:
		var x: float = pe[0] * sz.x + sin(anim_t * 1.3 + pe[4]) * 22.0 * k
		var y: float = pe[1] * sz.y
		var w: float = pe[3] * k * (0.6 + 0.4 * absf(sin(anim_t * 2.0 + pe[4])))
		c.draw_texture_rect(disc, Rect2(Vector2(x - w, y - w * 0.5), Vector2(w * 2.0, w)), false, col)

## Spike traps, their remote switches, rope-tied gates, pickups and smoke bombs (round 10).
func _draw_props(c: CanvasItem, o: Vector2, sz: Vector2, k: float) -> void:
	var wood := Color(0.36, 0.25, 0.17)
	for br in engine.bridges:
		var bx0: float = o.x + br.x0 * k
		if bx0 < -900.0 * k or bx0 > sz.x + 300.0 * k:
			continue
		scn.drawbridge(c, o, k, br)
	for t in engine.traps:
		var tx: float = o.x + t.x * k
		if tx < -300.0 * k or tx > sz.x + 300.0 * k:
			continue
		scn.spike_trap(c, o, k, t)
	for sc in engine.secrets:
		if sc.got:
			continue
		var sp2: Vector2 = o + Vector2(sc.x, sc.y) * k
		if sp2.x < -40.0 or sp2.x > sz.x + 40.0:
			continue
		var tw := 0.5 + 0.5 * sin(anim_t * 3.0 + sc.x)
		c.draw_texture_rect(disc, Rect2(sp2 - Vector2(30, 30) * k, Vector2(60, 60) * k), false, Color(0.6, 1.0, 0.75, 0.1 + 0.16 * tw))
		_magatama(c, sp2, k, sc.x)
	for nl in engine.night_lanterns:
		var nlx: float = o.x + nl.x * k
		if nlx < -80.0 * k or nlx > sz.x + 80.0 * k:
			continue
		_lantern(c, Vector2(nlx, o.y + engine.ground_y(nl.x) * k), k, nl.lit)
	for d in engine.drops:
		var dp: Vector2 = o + Vector2(d.x, d.y + sin(anim_t * 4.0 + d.x) * 4.0) * k
		if dp.x < -40.0 or dp.x > sz.x + 40.0:
			continue
		var gcol := Color(1.0, 0.85, 0.4, 0.3 + 0.12 * sin(anim_t * 6.0))
		c.draw_texture_rect(disc, Rect2(dp - Vector2(26, 26) * k, Vector2(52, 52) * k), false, gcol)
		match d.kind:
			"star":
				_star(c, dp, k * 0.9, true)
			"heart":
				_heart(c, dp, 11.0 * k, pal.red)
			_:
				c.draw_texture_rect(disc, Rect2(dp - Vector2(10, 10) * k, Vector2(20, 20) * k), false, pal.ink)
				c.draw_line(dp + Vector2(4, -9) * k, dp + Vector2(10, -16) * k, pal.near, 2.0 * k)
				c.draw_texture_rect(disc, Rect2(dp + Vector2(6, -20) * k, Vector2(8, 8) * k), false, Color(1.0, 0.6, 0.2))
	for sm in engine.smokes:
		var sx: float = o.x + sm.x * k
		if sx < -200.0 * k or sx > sz.x + 200.0 * k:
			continue
		var grow := minf(1.0, (4.5 - sm.t) * 3.0)
		var fadeo := minf(1.0, sm.t)
		for i in 9:
			var an := i * 2.4 + anim_t * 0.4
			var rr2 := (60.0 + (i % 3) * 22.0) * grow * k
			var cp := Vector2(sx + cos(an) * 60.0 * grow * k, o.y + (sm.y - 50.0) * k + sin(an * 1.3) * 34.0 * k - float(i) * 3.0 * k)
			c.draw_texture_rect(disc, Rect2(cp - Vector2(rr2, rr2), Vector2(rr2, rr2) * 2.0), false, Color(pal.smoke, 0.5 * fadeo))

func _heart(c: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	var r := s * 0.58
	c.draw_texture_rect(disc, Rect2(p + Vector2(-s * 0.5 - r, -s * 0.3 - r), Vector2(r, r) * 2.0), false, col)
	c.draw_texture_rect(disc, Rect2(p + Vector2(s * 0.5 - r, -s * 0.3 - r), Vector2(r, r) * 2.0), false, col)
	_poly(c, PackedVector2Array([p + Vector2(-s * 1.04, -s * 0.12), p + Vector2(s * 1.04, -s * 0.12), p + Vector2(0, s * 1.05)]), col)

## Torii gates (owner 2026-11-15): scenery you walk through, a faint brown with a faint red top beam.
## Round 8: wider, like the owner's reference (the top beam is 1.5x the height, tips curled up).
## Round 10: the first pass heals one heart and lights the incense.
func _draw_torii(c: CanvasItem, o: Vector2, sz: Vector2, k: float, half: int) -> void:
	var wood := Color(0.36, 0.24, 0.16, 0.6)
	var redtop := Color(0.72, 0.16, 0.12, 0.6)
	for tx in engine.torii:
		var x: float = o.x + tx * k
		if x < -150.0 * k or x > sz.x + 150.0 * k:
			continue
		var gl: float = engine.ground_y(tx - 78.0)
		var gr: float = engine.ground_y(tx + 78.0)
		var top: float = minf(gl, gr) - 165.0
		var tp := o.y + top * k
		var lb := Vector2(x - 78.0 * k, o.y + (gl + 3.0) * k)
		var rb := Vector2(x + 78.0 * k, o.y + (gr + 3.0) * k)
		# Owner 2026-11-16: you run through the gate: its left half is behind the hero (half -1),
		# its right half in front of him (half +1).
		if half < 0:
			_poly(c, PackedVector2Array([lb + Vector2(-8.0 * k, 0), lb + Vector2(8.0 * k, 0), Vector2(x - 70.0 * k, tp + 14.0 * k), Vector2(x - 82.0 * k, tp + 14.0 * k)]), wood)
			c.draw_line(Vector2(x - 100.0 * k, tp + 46.0 * k), Vector2(x, tp + 46.0 * k), wood, 9.0 * k)   # nuki, the lower beam
			c.draw_line(Vector2(x - 96.0 * k, tp + 22.0 * k), Vector2(x, tp + 22.0 * k), wood, 8.0 * k)   # shimaki
		else:
			_poly(c, PackedVector2Array([rb + Vector2(-8.0 * k, 0), rb + Vector2(8.0 * k, 0), Vector2(x + 82.0 * k, tp + 14.0 * k), Vector2(x + 70.0 * k, tp + 14.0 * k)]), wood)
			c.draw_line(Vector2(x, tp + 46.0 * k), Vector2(x + 100.0 * k, tp + 46.0 * k), wood, 9.0 * k)
			c.draw_line(Vector2(x, tp + 22.0 * k), Vector2(x + 96.0 * k, tp + 22.0 * k), wood, 8.0 * k)
			c.draw_rect(Rect2(Vector2(x - 8.0 * k, tp + 24.0 * k), Vector2(16.0 * k, 22.0 * k)), Color(wood, 0.8))   # the name plaque
		# Kasagi: the curved red top beam, tips curled up (half of it per pass).
		var upper := PackedVector2Array()
		var lower := PackedVector2Array()
		for i in range(0 if half < 0 else 5, (5 if half < 0 else 10) + 1):
			var f := i / 10.0 * 2.0 - 1.0
			var cv := f * f * 16.0
			upper.append(Vector2(x + f * 118.0 * k, tp - (4.0 + cv) * k))
			lower.append(Vector2(x + f * 106.0 * k, tp + (15.0 - cv * 0.55) * k))
		lower.reverse()
		_poly(c, upper + lower, redtop)
		if half < 0:
			# Incense at the left pillar: unlit until the gate has blessed you, then glowing with rising smoke.
			var ib := Vector2(x - 112.0 * k, o.y + (engine.ground_y(tx - 112.0) + 2.0) * k)
			c.draw_rect(Rect2(ib + Vector2(-9, -8) * k, Vector2(18, 8) * k), Color(0.3, 0.3, 0.3, 0.8))
			c.draw_line(ib + Vector2(0, -8) * k, ib + Vector2(0, -34) * k, Color(0.5, 0.35, 0.2), 2.0 * k)
			if engine.torii_used.has(tx):
				var tip := ib + Vector2(0, -34) * k
				c.draw_texture_rect(disc, Rect2(tip - Vector2(10, 10) * k, Vector2(20, 20) * k), false, Color(1.0, 0.55, 0.2, 0.5 + 0.3 * sin(anim_t * 6.0)))
				var wisp := PackedVector2Array()
				for i in 12:
					wisp.append(tip + Vector2(sin(anim_t * 1.6 + i * 0.55) * (4.0 + i * 1.4), -i * 7.0) * k)
				c.draw_polyline(wisp, Color(pal.smoke, 0.5), 2.2 * k)

## Houses, pagodas, shrines, statues and ruins (engine.structs), river bridges and the boss hall.
func _draw_structs(c: CanvasItem, o: Vector2, sz: Vector2, k: float) -> void:
	for ab in engine.arch_bridges:
		var ax0: float = o.x + ab.x0 * k
		var ax1: float = o.x + ab.x1 * k
		if ax1 < 0.0 or ax0 > sz.x:
			continue
		scn.arch_bridge(c, ax0, ax1, o.y + ab.y * k, k)
	for st in engine.structs:
		var X: float = o.x + st.x * k
		if X < -420.0 * k or X > sz.x + 420.0 * k:
			continue
		var Y: float = o.y + (st.y + 3.0) * k
		match st.kind:
			"house":
				scn.house(c, X, Y, st.w, k, st.seed)
			"pagoda":
				scn.pagoda(c, X, Y, st.w, st.tiers, k, false, true, st.seed % 2 == 0)
			"ruin_pagoda":
				scn.pagoda(c, X, Y, st.w, st.tiers, k, true)
			"shrine":
				if not scn.art(c, "shrine", X, Y, 300.0, k):
					scn.shrine(c, X, Y, k, st.seed)
			"akita":
				# Owner 2026-11-20: no more drawn statues. Its own picture (art/akita.png) when the
				# owner adds one, else the owner's komainu picture; the drawn Akita is the last fallback.
				if not _prop(c, o, "akita" if _art_ok("akita") else "komainu_l", st.x, 220.0, k, st.seed % 2 == 1, st.seed):
					scn.akita(c, X, Y, k, 1 if st.seed % 2 == 0 else -1)
			# Owner artwork 2026-11-19 (games/ink_ninja/art, colours muted); the drawn versions
			# stay as the fallback when a picture is missing.
			"komainu":
				# Owner 2026-11-20: the pair stands apart, not shoulder to shoulder; two painted pairs (st.art).
				var gap: float = 230.0 + (st.seed % 3) * 45.0
				var pair: Array = st.get("art", ["komainu_l", "komainu_r"])
				if not (_prop(c, o, pair[0], st.x - gap, 230.0, k, false, st.seed) and _prop(c, o, pair[1], st.x + gap, 230.0, k, false, st.seed + 7)):
					scn.komainu(c, X - 100.0 * k, Y, k, 1)
					scn.komainu(c, X + 100.0 * k, Y, k, -1)
			"dragon":
				var df := 1 if st.seed % 2 == 0 else -1
				if not scn.art(c, "dragon", X + df * 21.0 * k, Y, Engine_.DRAGON_H, k, df < 0):
					scn.dragon(c, X, Y, k, df)
			"kitsune":
				_prop(c, o, "kitsune", st.x, 290.0, k, st.seed % 2 == 1, st.seed)
			"jizo":
				_prop(c, o, "jizo", st.x, 170.0, k, false, st.seed)
			"lantern":
				#scn.art(c, "lantern", X, Y, 250.0, k)
				_prop(c, o, "lantern", st.x, 150.0, k, false, st.seed)   # owner 2026-11-20: smaller
			"bell":
				_prop(c, o, "bell", st.x, 380.0, k, false, st.seed)
			"gate":
				_prop(c, o, "gate", st.x, 330.0, k, false, st.seed)
			"nio":
				_prop(c, o, _art1(st, "nio"), st.x, 380.0, k, st.seed % 2 == 1, st.seed)
			# Owner artwork 2026-11-20 (artwork/2): lions on rocks, a bonsai table, three more dragons.
			"lion":
				_prop(c, o, _art1(st, "lion_a"), st.x, 300.0, k, st.seed % 2 == 1, st.seed)
			"bonsai":
				_prop(c, o, "bonsai", st.x, 230.0, k, st.seed % 2 == 1, st.seed)
			"dragon2":
				var dn := _art1(st, "dragon_rock")
				_prop(c, o, dn, st.x, {"dragon_rock": 380.0, "dragon_coil": 420.0, "dragon_snake": 270.0}.get(dn, 340.0), k, st.seed % 2 == 1, st.seed)
			"ruin_house":
				_prop(c, o, "ruin_house", st.x, 260.0, k, st.seed % 2 == 1, st.seed)
			"ruin_stones":
				_prop(c, o, "ruin_stones", st.x, 240.0, k, false, st.seed)
			"warriors":
				# Owner 2026-11-20: art/warrior.png when added (a row of three), else the owner's nio picture.
				#if _art_ok("warrior"):
				#	for j in 3:
				#		_prop(c, o, "warrior", st.x + (j - 1) * 120.0, 300.0 - j % 2 * 20.0, k, j == 2, st.seed + j)
				# Owner art 2026-11-20: three different warriors (front, side, other side) in a row.
				if _art_ok("warrior"):
					var ws: Array = st.get("art", ["warrior", "warrior", "warrior"])
					for j in ws.size():
						_prop(c, o, ws[j], st.x + (j - 1) * 130.0, 300.0 - j % 2 * 20.0, k, false, st.seed + j)
				elif not _prop(c, o, "nio", st.x, 380.0, k, st.seed % 2 == 1, st.seed):
					scn.warriors(c, X, Y, k, st.seed, st.ruin)
			"ruin_arch":
				scn.ruin_arch(c, X, Y, k, st.seed)
			"ruin_wall":
				scn.ruin_wall(c, X, Y, st.w, k, st.seed)
	if engine.boss_stage():
		_boss_hall(c, o, sz, k)

## The picture this statue was given by the engine (st.art), else `fallback`.
func _art1(st: Dictionary, fallback: String) -> String:
	var a: Array = st.get("art", [])
	return str(a[0]) if not a.is_empty() and str(a[0]) != "" else fallback

## True when picture `name` exists in games/ink_ninja/art.
func _art_ok(name: String) -> bool:
	return ResourceLoader.exists("res://games/ink_ninja/art/%s.png" % name)

## Owner 2026-11-20: each statue looks its own: size 80-125 %, a soft contact shadow,
## some deeper in the mist (a fog-coloured copy over it), some half behind a trunk.
## `wx` is the world x; stands on the ground there. False when the picture is missing.
func _prop(c: CanvasItem, o: Vector2, name: String, wx: float, h: float, k: float, flip: bool, seed_: int) -> bool:
	var X: float = o.x + wx * k
	var Y: float = o.y + (engine.ground_y(wx) + 3.0) * k
	var r := absi(seed_ * 2654435761) % 1000
	var sc := 0.8 + (r % 10) * 0.05
	var hh := h * sc
	var w := hh * 0.9 * k
	c.draw_texture_rect(disc, Rect2(X - w * 0.6, Y - 12.0 * k, w * 1.2, 26.0 * k), false, Color(pal.shadow, 0.28))
	if not scn.art(c, name, X, Y, hh, k, flip):
		return false
	var mist := float((r / 10) % 4) * 0.12   # 0, .12, .24, .36
	if mist > 0.0:
		scn.art(c, name, X, Y, hh, k, flip, Color(pal.fog, mist))
	c.draw_texture_rect(fog_tex, Rect2(X - w * 0.7, Y - hh * k * 0.35, w * 1.4, hh * k * 0.35 + 6.0 * k), false, Color(pal.fog, 0.35))   # ground mist round its feet
	if (r / 40) % 3 == 0:
		# a pine trunk in front, part of it hidden
		var tx := X + (float(r % 7) - 3.0) / 3.0 * w * 0.35
		var tw := (12.0 + r % 9) * k
		c.draw_line(Vector2(tx, Y + 8.0 * k), Vector2(tx + 6.0 * k, -10.0), pal.near, tw)
		var by := Y - hh * k * (0.45 + (r % 5) * 0.08)
		var sd := 1.0 if r % 2 == 0 else -1.0
		c.draw_line(Vector2(tx, by), Vector2(tx + sd * 50.0 * k, by - 20.0 * k), pal.near, 3.0 * k)
	return true

## Owner 2026-11-16: each boss waits inside a pagoda. It stands behind the arena.
func _boss_hall(c: CanvasItem, o: Vector2, sz: Vector2, k: float) -> void:
	var X: float = o.x + (engine.arena_x + Engine_.VIEW_W * 0.7) * k
	if X < -700.0 * k or X > sz.x + 700.0 * k:
		return
	var Y: float = o.y + (Engine_.GROUND + 3.0) * k
	scn.pagoda(c, X, Y, 560.0, 4, k, false)
	for sd in [-1, 1]:
		var px: float = X + sd * 420.0 * k
		c.draw_line(Vector2(px, Y), Vector2(px, Y - 340.0 * k), pal.ink, 5.0 * k)
		var cloth := Rect2(px - 16.0 * k, Y - 330.0 * k, 32.0 * k, 130.0 * k)
		c.draw_rect(cloth, SHU_RED)
		_seal(c, cloth.get_center(), 18.0 * k)

## A cherry blossom: five soft petals, a paler rim and a dark heart (like the owner's two
## cherry references). White so it takes any tint; three turns so a branch is not a stamp.
func _make_flowers() -> Array:
	var out := []
	for turn in 3:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var rot := turn * 0.7
		for y in n:
			for x in n:
				var v := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5)
				var d := v.length() / (n / 2.0)
				var th := v.angle() + rot
				var edge := 0.62 + 0.38 * pow(absf(cos(2.5 * th)), 0.55)   # five rounded petals
				var al := clampf((edge - d) * 14.0, 0.0, 1.0)
				var shade := 1.0
				if d > edge - 0.12:
					shade = 0.8   # the outline the owner asked for
				if d < 0.2:
					shade = 0.28 + d * 1.6   # dark centre
				elif absf(sin(2.5 * th)) < 0.05 and d < 0.55:
					shade *= 0.88   # a faint vein
				img.set_pixel(x, y, Color(shade, shade, shade, al))
		out.append(ImageTexture.create_from_image(img))
	return out

## Cherry trees (owner 2026-11-15): a dark brush trunk and branches under clouds of pink
## blossom; one tree per stage has blood-red leaves, with a carved heart once visited.
## Round 8: thinner, more delicate branches with twigs, and real five-petal blossoms.
func _draw_trees(c: CanvasItem, o: Vector2, sz: Vector2, k: float) -> void:
	if flowers.is_empty():
		flowers = _make_flowers()
	var r := RandomNumberGenerator.new()
	for t in engine.trees:
		if o.x + t.x * k < -260.0 * k or o.x + t.x * k > sz.x + 260.0 * k:
			continue
		var base: Vector2 = o + Vector2(t.x, engine.ground_y(t.x) + 4.0) * k
		var h: float = t.h
		var lean := float(t.s % 7) - 3.0
		var trunk := []
		for i in 8:
			var f := i / 7.0
			trunk.append(base + Vector2(sin(f * 2.2 + lean) * 16.0 * f + lean * f * 3.0, -h * 0.62 * f) * k)
		_ribbon(c, trunk, 15.0 * k, 5.0 * k, pal.ink)
		var blood: bool = t.blood
		var leaf: Color = Color(0.7, 0.04, 0.06) if blood else Color(0.96, 0.62, 0.73)
		var leaf2: Color = Color(0.48, 0.02, 0.05) if blood else Color(1.0, 0.82, 0.88)
		r.seed = t.s
		var twigs := PackedVector2Array()
		var spots := []   # where blossom sits
		for b in 5:
			var st: Vector2 = trunk[2 + b] if b < 4 else trunk[7]
			var dir := -1.0 if b % 2 == 0 else 1.0
			var en: Vector2 = st + Vector2(dir * r.randf_range(55.0, 110.0), -r.randf_range(28.0, 80.0)) * k
			var mid: Vector2 = st.lerp(en, 0.5) + Vector2(0, 9.0 * k)
			_ribbon(c, [st, mid, en], 5.0 * k, 1.4 * k, pal.ink)
			# Twigs: little zig-zags off the branch, blossom along them.
			for q in 4:
				var f := 0.35 + q * 0.2
				var bp: Vector2 = st.lerp(mid, f * 2.0) if f < 0.5 else mid.lerp(en, (f - 0.5) * 2.0)
				var tdir := Vector2(dir * r.randf_range(0.4, 1.0), -r.randf_range(0.3, 1.0)).normalized()
				var p1: Vector2 = bp + tdir * r.randf_range(14.0, 26.0) * k
				var p2: Vector2 = p1 + tdir.rotated(r.randf_range(-0.7, 0.7)) * r.randf_range(10.0, 20.0) * k
				twigs.append(bp)
				twigs.append(p1)
				twigs.append(p1)
				twigs.append(p2)
				spots.append(p1)
				spots.append(p2)
			spots.append(en)
		# The trunk carries on as a fine leader with a crown of blossom (no blunt cut-off top).
		var tt: Vector2 = trunk[7]
		var lead := [tt, tt + Vector2(lean * 1.5, -26.0) * k, tt + Vector2(lean * 3.0 + 4.0, -52.0) * k]
		_ribbon(c, lead, 5.0 * k, 0.8 * k, pal.ink)
		for cp in [lead[1], lead[2], tt + Vector2(-24, -34) * k, tt + Vector2(26, -38) * k, tt + Vector2(lean * 3.0, -68.0) * k]:
			twigs.append(lead[1] if cp != lead[1] else tt)
			twigs.append(cp)
			spots.append(cp)
		c.draw_multiline(twigs, pal.ink, 1.5 * k)
		for sp in spots:
			c.draw_texture_rect(disc, Rect2(sp - Vector2(26, 20) * k, Vector2(52, 40) * k), false, Color(leaf, 0.12))
		for i in spots.size():
			var n_f := 2 if i % 3 == 0 else 1
			for j in n_f:
				var off := Vector2(r.randf_range(-12.0, 12.0), r.randf_range(-10.0, 9.0))
				off += Vector2(sin(anim_t * 1.1 + i), cos(anim_t * 0.9 + i * 1.7)) * 1.5
				var fs := r.randf_range(6.5, 10.5) * k
				var fp: Vector2 = spots[i] + off * k
				c.draw_texture_rect(flowers[(i + j) % 3], Rect2(fp - Vector2(fs, fs), Vector2(fs, fs) * 2), false, leaf if (i + j) % 3 != 0 else leaf2)
		for i in 7:   # fallen petals
			var px2 := base.x + r.randf_range(-80.0, 80.0) * k
			c.draw_texture_rect(flowers[i % 3], Rect2(Vector2(px2, base.y - 4.0 * k), Vector2(6, 6) * k), false, Color(leaf, 0.85))
		if blood and hearts.has(engine.stage):
			# The carved heart: a pale notch sized to the trunk, set on the trunk's own line.
			var ti := (0.2 / 0.62) * 7.0
			var hc: Vector2 = (trunk[int(ti)] as Vector2).lerp(trunk[int(ti) + 1], ti - int(ti))
			var hp := PackedVector2Array()
			for i in 24:
				var a := i / 24.0 * TAU
				hp.append(hc + Vector2(16.0 * pow(sin(a), 3.0), -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))) * 0.26 * k)
			_poly(c, hp, pal.paper)

## Black and grey scenery between the cherry trees (owner 2026-11-15): bamboo, bushes, tall grass.
## Each thing is one or two batched line calls plus a few textured blobs.
func _draw_flora(c: CanvasItem, o: Vector2, sz: Vector2, k: float) -> void:
	var r := RandomNumberGenerator.new()
	for fl in engine.flora:
		var fx: float = o.x + fl.x * k
		if fx < -120.0 * k or fx > sz.x + 120.0 * k:
			continue
		var base := Vector2(fx, o.y + (engine.ground_y(fl.x) + 3.0) * k)
		var hm: float = fl.h
		r.seed = fl.s
		if fl.get("cut", false):
			for q in 3:
				var sx := base + Vector2((q - 1) * 12.0, 0) * k
				c.draw_line(sx, sx + Vector2(0, -(16.0 + q * 6.0)) * k, pal.ink.lerp(pal.mid, 0.2), 4.0 * k)
			continue
		match fl.kind:
			"bamboo":
				var stalk := PackedVector2Array()
				var leaves := PackedVector2Array()
				var nodes := PackedVector2Array()
				for q in r.randi_range(3, 5):
					var bx := base + Vector2(r.randf_range(-22.0, 22.0), 0) * k
					var th := r.randf_range(150.0, 250.0) * hm
					var lean := r.randf_range(-0.12, 0.12)
					var prev := bx
					var segs := 7
					for sg in segs:
						var f := (sg + 1) / float(segs)
						var cur := bx + Vector2(lean * th * f + sin(anim_t * 0.8 + fl.x * 0.01 + q) * 3.0 * f, -th * f) * k
						stalk.append(prev)
						stalk.append(cur)
						nodes.append(cur + Vector2(-3.5, 0) * k)
						nodes.append(cur + Vector2(3.5, 0) * k)
						if sg >= 2:   # sprigs of narrow leaves, drooping from the upper nodes
							for lf in 3:
								var d := -1.0 if lf % 2 == 0 else 1.0
								var ang := d * r.randf_range(0.3, 1.1)
								var ln := r.randf_range(16.0, 30.0) * k
								var tip := cur + Vector2(sin(ang), -cos(ang) * 0.35 + 0.55) * ln
								leaves.append(cur)
								leaves.append(tip)
						prev = cur
				c.draw_multiline(stalk, pal.ink.lerp(pal.mid, 0.2), 3.2 * k)
				c.draw_multiline(nodes, pal.ink, 2.2 * k)
				c.draw_multiline(leaves, pal.ink.lerp(pal.near, 0.3), 2.6 * k)
			"bush":
				var col: Color = pal.near.lerp(pal.ink, 0.45)
				for i in 9:
					var p := base + Vector2(r.randf_range(-34.0, 34.0) * hm, -r.randf_range(8.0, 34.0) * hm) * k
					var rad := r.randf_range(14.0, 24.0) * hm * k
					c.draw_texture_rect(disc, Rect2(p - Vector2(rad, rad * 0.85), Vector2(rad, rad * 0.85) * 2), false, Color(col, 0.9))
				var spikes := PackedVector2Array()
				for i in 14:
					var p := base + Vector2(r.randf_range(-40.0, 40.0) * hm, -r.randf_range(10.0, 40.0) * hm) * k
					spikes.append(p)
					spikes.append(p + Vector2(r.randf_range(-12.0, 12.0), -r.randf_range(8.0, 18.0)) * k)
				c.draw_multiline(spikes, col, 2.0 * k)
			_:
				var blades := PackedVector2Array()
				for i in 16:
					var bx := base + Vector2(r.randf_range(-18.0, 18.0), 0) * k
					var bl := r.randf_range(34.0, 78.0) * hm
					var bend := r.randf_range(-26.0, 26.0) + sin(anim_t * 1.2 + i + fl.x * 0.02) * 3.0
					var m := bx + Vector2(bend * 0.35, -bl * 0.55) * k
					blades.append(bx)
					blades.append(m)
					blades.append(m)
					blades.append(bx + Vector2(bend, -bl) * k)
				c.draw_multiline(blades, pal.ink.lerp(pal.mid, 0.35), 2.0 * k)

## The rolling ground (owner 2026-11-15): one ink polygon along the height field, with a
## dry-brush rim in short strokes (one draw_multiline call).
func _draw_ground(c: CanvasItem, o: Vector2, sz: Vector2, k: float) -> void:
	var cam: float = engine.cam_x()
	var step := Engine_.SEG
	var x0 := floorf(cam / step) * step - step
	var x1 := cam + sz.x / k + step
	var pts := PackedVector2Array()
	var rim := PackedVector2Array()
	var x := x0
	var prev := Vector2.ZERO
	while x <= x1:
		var p := o + Vector2(x, engine.ground_y(x)) * k
		pts.append(p)
		if x > x0:
			rim.append(prev + Vector2(0, -2.0 * k))
			rim.append(p + Vector2(0, -(2.0 + fmod(x * 0.37, 3.0)) * k))
		prev = p
		x += step
	pts.append(Vector2(pts[pts.size() - 1].x, sz.y + 4))
	pts.append(Vector2(pts[0].x, sz.y + 4))
	c.draw_colored_polygon(pts, pal.ink)
	c.draw_multiline(rim, pal.ink, 2.0 * k)
	# Texture (owner 2026-11-15): grass tufts on the rim, soil strata and stones below,
	# in lighter ink so the land reads apart from towers and figures. One multiline each.
	# Grass in three layers and tones (owner 2026-11-15: more depth and colour variation, blacks
	# and greys): tall pale blades behind, mid grey in the middle, short near-black in front.
	var grass: Array = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
	var strata := PackedVector2Array()
	var strata2 := PackedVector2Array()
	var stones := PackedVector2Array()
	var stones2 := PackedVector2Array()
	var sway := sin(anim_t * 1.3) * 1.5
	x = x0
	while x <= x1:
		var gy: float = engine.ground_y(x)
		if engine.water_depth(x) <= 0.0:
			for L in 3:
				var hx := absf(x) + L * 131.0
				var h := (14.0 - L * 4.0) + fmod(hx * 0.731, 9.0 - L * 2.0)
				var lean := fmod(hx * 0.37, 8.0) - 4.0 + sway * (1.0 - L * 0.3)
				var off := fmod(hx * 0.53, float(Engine_.SEG))
				grass[L].append(o + Vector2(x + off, gy + 1.0 + L) * k)
				grass[L].append(o + Vector2(x + off + lean, gy - h) * k)
				grass[L].append(o + Vector2(x + off + 5.0, gy + 1.0 + L) * k)
				grass[L].append(o + Vector2(x + off + 5.0 + lean * 0.6, gy - h * 0.7) * k)
		for d in [22.0, 48.0, 84.0]:
			if fmod(absf(x) + d * 3.0, 60.0) < 40.0:
				var a := o + Vector2(x, engine.ground_y(x) + d) * k
				var b := o + Vector2(x + step, engine.ground_y(x + step) + d) * k
				(strata if d < 60.0 else strata2).append(a)
				(strata if d < 60.0 else strata2).append(b)
		var sh := fmod(absf(x) * 1.37, 97.0)
		if sh < 30.0:
			var sp := o + Vector2(x + sh * 0.5, gy + 30.0 + sh * 2.0) * k
			stones.append(sp)
			stones.append(sp + Vector2(6.0 + sh * 0.2, 0) * k)
		elif sh > 80.0:
			var sp2 := o + Vector2(x + sh * 0.3, gy + 18.0 + (sh - 80.0) * 3.0) * k
			stones2.append(sp2)
			stones2.append(sp2 + Vector2(10.0, 0) * k)
		x += step
	c.draw_multiline(strata, Color(pal.near, 0.55), 2.0 * k)
	c.draw_multiline(strata2, Color(pal.mid, 0.4), 3.0 * k)
	c.draw_multiline(stones, Color(pal.mid, 0.6), 4.0 * k)
	c.draw_multiline(stones2, Color(pal.far, 0.5), 5.0 * k)
	c.draw_multiline(grass[0], Color(pal.mid, 0.85), 2.0 * k)
	c.draw_multiline(grass[1], Color(pal.near, 0.95), 2.2 * k)
	c.draw_multiline(grass[2], pal.ink.lerp(pal.near, 0.15), 2.4 * k)
	# A lighter highlight along the rim lifts the edge off the black earth.
	c.draw_multiline(rim, Color(pal.mid, 0.55), 1.2 * k)

## Water filling a dip: a polygon from the surface down along the dip's bed (drawn
## twice: behind the ground for the body, and as a pale veil in front of the figures so
## a swimmer looks under it).
func _water_poly(o: Vector2, k: float, w: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(o + Vector2(w.x0, w.level) * k)
	var x: float = w.x0
	while x < w.x1:
		pts.append(o + Vector2(x, maxf(w.level, engine.ground_y(x)) + 2.0) * k)
		x += Engine_.SEG * 0.5
	pts.append(o + Vector2(w.x1, w.level) * k)
	return pts

func _draw_water_back(c: CanvasItem, o: Vector2, k: float) -> void:
	for w in engine.pools:
		if (o.x + w.x1 * k) < 0 or (o.x + w.x0 * k) > field.size.x:
			continue
		_poly(c, _water_poly(o, k, w), Color(pal.water).darkened(0.4) if w.get("deadly", false) else pal.water)

func _draw_water_front(c: CanvasItem, o: Vector2, k: float) -> void:
	for w in engine.pools:
		var a: Vector2 = o + Vector2(w.x0, w.level) * k
		var bx: float = o.x + w.x1 * k
		if bx < 0 or a.x > field.size.x:
			continue
		_poly(c, _water_poly(o, k, w), Color(Color(pal.water).darkened(0.4) if w.get("deadly", false) else pal.water, pal.water.a * 0.55))
		var lines := PackedVector2Array()
		var x: float = a.x
		while x < bx - 1.0:
			var nx := minf(x + 14.0 * k, bx)
			lines.append(Vector2(x, a.y + sin(x * 0.05 + anim_t * 2.0) * 1.5 * k))
			lines.append(Vector2(nx, a.y + sin(nx * 0.05 + anim_t * 2.0) * 1.5 * k))
			x = nx
		c.draw_multiline(lines, pal.surf, 2.0 * k)

## Breath bubbles over the hero's head while under water: one per second left.
func _draw_breath(c: CanvasItem, o: Vector2, k: float) -> void:
	if engine.air >= Engine_.AIR:
		return
	var n := int(ceil(maxf(0.0, engine.air)))
	var head: Vector2 = o + Vector2(engine.px, engine.py - engine.height() - 26) * k
	for i in int(Engine_.AIR):
		var p := head + Vector2((i - Engine_.AIR / 2.0 + 0.5) * 14.0, 0) * k
		var col: Color = pal.surf if i < n else Color(pal.near, 0.35)
		c.draw_texture_rect(disc, Rect2(p - Vector2(5, 5) * k, Vector2(10, 10) * k), false, col)
	if engine.air <= 0.0 and fmod(anim_t, 0.5) < 0.25:
		c.draw_texture_rect(disc, Rect2(head - Vector2(60, 12) * k, Vector2(120, 24) * k), false, Color(pal.red, 0.25))

## Before the boss gate (owner 2026-11-15): a haze thickens over the last stretch, and
## the dips fill with a deeper, thicker fog.
func _draw_haze(c: CanvasItem, o: Vector2, sz: Vector2, k: float) -> void:
	var f := clampf((engine.px - (engine.arena_x - 1700.0)) / 900.0, 0.0, 1.0)
	if engine.locked:
		f = 0.35
	if f <= 0.0:
		return
	c.draw_texture_rect(fog_tex, Rect2(0, sz.y * 0.15, sz.x, sz.y * 0.85), false, Color(pal.haze, 0.7 * f))
	for d in engine.dips:
		var a: Vector2 = o + Vector2(d.x0 - 60.0, d.level - 90.0) * k
		var b: Vector2 = o + Vector2(d.x1 + 60.0, Engine_.LOWEST + 20) * k
		if b.x < 0 or a.x > sz.x:
			continue
		# Soft overlapping blobs (no hard edges), thickest down in the hollow.
		var drift := sin(anim_t * 0.4 + d.x0) * 20.0 * k
		var w := b.x - a.x
		for m in 4:
			var cy: float = o.y + (d.level - 10.0 - m * 26.0) * k
			var ww := w * (0.75 - m * 0.12)
			var cx := (a.x + b.x) / 2.0 + drift * (1.0 - m)
			c.draw_texture_rect(disc, Rect2(Vector2(cx - ww / 2.0, cy - 50.0 * k), Vector2(ww, 100.0 * k)), false, Color(pal.haze, (0.95 - m * 0.2) * f))

## A stone lantern checkpoint: a warm glow once you have passed it.
func _lantern(c: CanvasItem, base: Vector2, k: float, lit: bool) -> void:
	# Owner 2026-11-20: checkpoint and night lanterns are the owner's stone lantern picture
	# (small); the drawn one below stays as the fallback.
	var lh := 118.0
	if scn.art(c, "lantern", base.x, base.y, lh, k, false, Color.WHITE if lit else Color(0.62, 0.62, 0.66)):
		var wy := base + Vector2(0, -lh * 0.62) * k   # the window
		if lit:
			var gl := 0.55 + 0.15 * sin(anim_t * 3.0)
			c.draw_texture_rect(disc, Rect2(wy - Vector2(110, 110) * k, Vector2(220, 220) * k), false, Color(1.0, 0.72, 0.22, gl * 0.28))
			c.draw_texture_rect(disc, Rect2(wy - Vector2(40, 40) * k, Vector2(80, 80) * k), false, Color(1.0, 0.72, 0.22, gl * 0.6))
		return
	var col: Color = pal.near
	c.draw_rect(Rect2(base + Vector2(-14, -10) * k, Vector2(28, 10) * k), col)
	c.draw_rect(Rect2(base + Vector2(-5, -46) * k, Vector2(10, 36) * k), col)
	c.draw_rect(Rect2(base + Vector2(-13, -66) * k, Vector2(26, 20) * k), col)
	_poly(c, PackedVector2Array([base + Vector2(-22, -66) * k, base + Vector2(22, -66) * k, base + Vector2(0, -84) * k]), col)
	if lit:
		var glow := 0.55 + 0.15 * sin(anim_t * 3.0)
		c.draw_texture_rect(disc, Rect2(base + Vector2(-110, -170) * k, Vector2(220, 220) * k), false, Color(1.0, 0.72, 0.22, glow * 0.28))
		c.draw_texture_rect(disc, Rect2(base + Vector2(-56, -112) * k, Vector2(112, 112) * k), false, Color(1.0, 0.72, 0.22, glow * 0.6))
		c.draw_rect(Rect2(base + Vector2(-7, -62) * k, Vector2(14, 12) * k), Color(1.0, 0.76, 0.2, glow))
	else:
		c.draw_rect(Rect2(base + Vector2(-7, -62) * k, Vector2(14, 12) * k), pal.paper2)

## A strip of pine silhouettes (white, tinted when drawn), 1024 x 400, the forest floor
## solid along the bottom. Built row by row with fill_rect (fast), tiers give jagged branches.
func _make_pines(seed_: int, count: int, hmin: float, hmax: float) -> Texture2D:
	var w := 1024
	var h := 400
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	var base := h - 36
	for i in count:
		var cx := r.randi_range(0, w - 1)
		var th := r.randf_range(hmin, hmax)
		var hw := th * r.randf_range(0.16, 0.22)
		var tiers := r.randf_range(7.0, 11.0)
		# Owner 2026-11-20 (photo of misty firs): drooping tiers with ragged, feathered
		# edges, like many thin needles from a dry brush. Solid core, broken see-through rim.
		for yy in int(th):
			var t := float(yy) / th
			var tier := fmod(t * tiers, 1.0)
			var prof := 0.5 + 0.5 * pow(tier, 0.7)
			var y := base - int(th) + yy
			if y < 0:
				continue
			for sd in [-1, 1]:
				var half: float = (1.5 + t * hw) * prof * r.randf_range(0.75, 1.2)
				var core := half * 0.55
				_pine_span(img, w, cx, cx + sd * core, y, 1.0)
				var px := core
				while px < half:
					var seg := r.randf_range(1.5, 4.5)
					if r.randf() < 0.68:
						_pine_span(img, w, cx + sd * px, cx + sd * minf(px + seg, half), y, r.randf_range(0.45, 1.0))
					px += seg + r.randf_range(0.0, 2.0)
				# a needle tip hanging below the tier's edge
				if tier > 0.85 and r.randf() < 0.5:
					var nx: float = cx + sd * half * r.randf_range(0.6, 1.0)
					for d in r.randi_range(2, 5):
						if y + d < base:
							_pine_span(img, w, nx, nx + sd, y + d, 0.7)
		_pine_span(img, w, cx - 1.5, cx + 1.5, base - int(th) - 6, 1.0)   # the leader
	img.fill_rect(Rect2i(0, base, w, h - base), Color.WHITE)
	return ImageTexture.create_from_image(img)

## One row of a pine texture from x0 to x1 (any order), wrapping round the tile edges.
func _pine_span(img: Image, w: int, x0: float, x1: float, y: int, a: float) -> void:
	var lo := int(minf(x0, x1))
	var hi := int(ceil(maxf(x0, x1)))
	if hi <= lo:
		hi = lo + 1
	for dx in [0, -w, w]:
		var l: int = maxi(lo + dx, 0)
		var rr: int = mini(hi + dx, w)
		if rr > l:
			if a >= 1.0:
				img.fill_rect(Rect2i(l, y, rr - l, 1), Color.WHITE)
			else:
				for xx in range(l, rr):
					if img.get_pixel(xx, y).a < a:
						img.set_pixel(xx, y, Color(1, 1, 1, a))

## A tileable far mountain ridge: two sine ridges whose frequencies divide the width.
func _make_mountains() -> Texture2D:
	var w := 1024
	var h := 300
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		var t := float(x) / w * TAU
		var top := 150.0 - (46.0 * sin(t * 2.0 + 0.6) + 30.0 * sin(t * 5.0 + 2.1) + 14.0 * sin(t * 11.0) + 7.0 * sin(t * 23.0 + 1.0))
		for y in range(maxi(0, int(top)), h):
			var a := clampf((y - top) / 3.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

## A vertical alpha ramp (clear at the top, solid at the bottom) for fog bands.
func _make_fog() -> Texture2D:
	var img := Image.create(1, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var t := float(y) / 63.0
		img.set_pixel(0, y, Color(1, 1, 1, t * t * (3.0 - 2.0 * t)))
	return ImageTexture.create_from_image(img)

func _pine_layer(c: CanvasItem, tex: Texture2D, off: float, k: float, base: float, col: Color) -> void:
	var sz := field.size
	var tw := 1024.0 * k * 1.1
	var th := 400.0 * k * 1.1
	var x := -fmod(off * k, tw)
	var top := base * k - th + 36.0 * k * 1.1
	while x < sz.x:
		c.draw_texture_rect(tex, Rect2(x, top, tw + 1.0, th), false, col)
		x += tw
	c.draw_rect(Rect2(0, top + th - 1.0, sz.x, sz.y), col)

## Mist between two heights (world units), thicker toward the bottom.
func _fog(c: CanvasItem, k: float, y0: float, y1: float, a: float) -> void:
	c.draw_texture_rect(fog_tex, Rect2(0, y0 * k, field.size.x, (y1 - y0) * k), false, Color(pal.fog, a))

## Tall straight trunks rising out of the top of the screen, a few bare branch strokes.
func _trunks(c: CanvasItem, off: float, k: float) -> void:
	var sz := field.size
	var gap := 210.0
	var i0 := int(floor(off / gap))
	for i in int(sz.x / (gap * k)) + 3:
		var wx := float(i0 + i)
		var x := (wx * gap - off + sin(wx * 3.1) * 70.0) * k
		var wd := (9.0 + absf(sin(wx * 1.3)) * 10.0) * k
		var lean := sin(wx * 2.3) * 14.0 * k
		var col := Color(pal.near, 0.85)
		var top := Vector2(x + lean, -10)
		var bot := Vector2(x, Engine_.GROUND * k)
		c.draw_line(top, bot, col, wd)
		c.draw_line(top + Vector2(wd * 0.25, 0), bot + Vector2(wd * 0.25, 0), Color(pal.mid, 0.35), wd * 0.25)   # dry-brush streak
		for b in 3:
			var by := (90.0 + b * 95.0 + absf(sin(wx * 5.0 + b)) * 40.0) * k
			var bp := top.lerp(bot, by / bot.y)
			var s := 1.0 if int(wx + b) % 2 == 0 else -1.0
			c.draw_line(bp, bp + Vector2(s * 46, -18) * k, col, 3.0 * k)
			c.draw_line(bp + Vector2(s * 30, -12) * k, bp + Vector2(s * 52, -6) * k, col, 2.0 * k)

## One brush stroke: a solid core plus rough offset edges and a grey dry-brush streak.
func _brush(c: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	c.draw_line(a, b, col, w)
	var n := (b - a).normalized().orthogonal() * w * 0.35
	c.draw_line(a + n, b + n * 0.6, col, w * 0.55)
	c.draw_line(a - n * 0.5, b - n, col, w * 0.4)
	c.draw_line(a.lerp(b, 0.15) + n * 0.2, a.lerp(b, 0.8) + n * 0.2, Color(pal.mid, 0.55), maxf(1.0, w * 0.12))

## A tapered ribbon through points (headband tails, sash, the sword's crescent): one polygon.
func _ribbon(c: CanvasItem, pts: Array, w0: float, w1: float, col: Color) -> void:
	if pts.size() < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in pts.size():
		var p: Vector2 = pts[i]
		var d: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized().orthogonal()
		var w := lerpf(w0, w1, float(i) / (pts.size() - 1)) * 0.5
		left.append(p + d * w)
		right.append(p - d * w)
	right.reverse()
	_poly(c, left + right, col)

## Joints of an ink figure (feet at `feet`, 70 units tall standing). pose: run phase,
## crouch, air. Returns hip, neck, head, knees, feet.
func _pose(feet: Vector2, k: float, f: int, ph: float, running: bool, crouch: bool, air: bool) -> Dictionary:
	var drop := 18.0 if crouch else 0.0
	var lean := (9.0 if running else 0.0) + (8.0 if crouch else 0.0)
	var hip := feet + Vector2(-f * 2, -30 + drop) * k
	var neck := hip + Vector2(f * lean, -26 + drop * 0.2) * k
	var head := neck + Vector2(f * 3, -11) * k
	var fa: Vector2
	var fb: Vector2
	var ka: Vector2
	var kb: Vector2
	if crouch:
		fa = feet + Vector2(f * 24, 0) * k
		fb = feet + Vector2(-f * 22, 0) * k
		ka = hip + Vector2(f * 24, -4) * k
		kb = hip + Vector2(-f * 6, 12) * k
	elif air:
		fa = feet + Vector2(f * 16, -12) * k
		fb = feet + Vector2(-f * 14, -2) * k
		ka = hip + Vector2(f * 18, 4) * k
		kb = hip + Vector2(-f * 2, 14) * k
	else:
		var s := sin(ph) if running else 0.0
		var lift := maxf(0.0, cos(ph)) * 8.0 if running else 0.0
		fa = feet + Vector2(f * (s * 18 + 10), -lift) * k
		fb = feet + Vector2(f * (-s * 18 - 10), -(8.0 - lift if running else 0.0)) * k
		ka = hip.lerp(fa, 0.5) + Vector2(f * 6, -3) * k
		kb = hip.lerp(fb, 0.5) + Vector2(f * 6, -3) * k
	return {"hip": hip, "neck": neck, "head": head, "fa": fa, "fb": fb, "ka": ka, "kb": kb}

## Body, legs, head and flowing headband for any ink figure.
func _ink_body(c: CanvasItem, j: Dictionary, k: float, f: int, col: Color, bulk: float, tails: bool, phase: float, tl: float = 1.0, band: Color = Color(0, 0, 0, 0), hang: float = 0.0, rise: float = 0.0) -> void:
	_brush(c, j.hip, j.kb, 8.0 * k * bulk, col)
	_brush(c, j.kb, j.fb, 7.0 * k * bulk, col)
	_brush(c, j.hip, j.ka, 8.0 * k * bulk, col)
	_brush(c, j.ka, j.fa, 7.0 * k * bulk, col)
	# Baggy trousers: a wedge from the hip over the knees.
	_poly(c, PackedVector2Array([j.hip + Vector2(-9, -4) * k * bulk, j.hip + Vector2(9, -4) * k * bulk, j.ka, j.kb]), col)
	_brush(c, j.hip, j.neck, 15.0 * k * bulk, col)
	c.draw_texture_rect(disc, Rect2(j.head - Vector2(12, 12) * k * bulk, Vector2(24, 24) * k * bulk), false, col)
	# Eye slit: a pale cut in the mask.
	c.draw_line(j.head + Vector2(f * 2, -1) * k, j.head + Vector2(f * 10, -1) * k, pal.paper, 2.5 * k)
	# Sash knot at the hip with a short tail.
	c.draw_line(j.hip + Vector2(-10, -6) * k, j.hip + Vector2(10, -6) * k, pal.mid, 4.0 * k)
	if tails:
		# Headband across the brow (so a bare head never reads as a cap), tails flow behind.
		var bc: Color = band if band.a > 0.0 else col
		if tl < 1.0 or band.a > 0.0:
			c.draw_line(j.head + Vector2(-f * 11, -5) * k, j.head + Vector2(f * 11, -5) * k, band if band.a > 0.0 else pal.mid, 4.0 * k)
		for t in 2:
			var pts := []
			var start: Vector2 = j.head + Vector2(-f * 9, -5 + t * 3) * k
			for i in maxi(3, int(ceil(7.0 * tl))):
				var fl := Vector2(-f * 13.0, sin(phase - i * 0.8 + t * 1.3) * 1.8 - 1.5 + t * 2.0)   # flowing behind
				fl = fl.lerp(Vector2(-f * 2.5, 11.0 + t * 1.5), hang)   # at rest: hangs down
				fl = fl.lerp(Vector2(-f * 6.0, -9.0 + sin(phase * 0.7 - i + t) * 3.0), rise)   # falling: flutters up
				pts.append(start + fl * i * k)
			_ribbon(c, pts, 6.0 * k, 1.0 * k, bc)
		var sp := []
		var s0: Vector2 = j.hip + Vector2(-f * 8, -6) * k
		for i in maxi(3, int(5 * maxf(tl, 0.7))):
			sp.append(s0 + Vector2(-f * i * 9.0, i * 3.0 + sin(phase * 0.8 - i) * i) * k)
		_ribbon(c, sp, 5.0 * k, 1.0 * k, bc if band.a > 0.0 else col)

## A katana: ink outline with a pale edge so it reads on dark ground too.
## Owner 2026-11-16: at night the hero swings a torch, and that is how he lights lanterns.
func _torch(c: CanvasItem, hand: Vector2, tip: Vector2, k: float) -> void:
	c.draw_line(hand, tip, Color(0.36, 0.25, 0.17), 5.0 * k)
	c.draw_line(hand.lerp(tip, 0.7), tip, Color(0.15, 0.1, 0.07), 8.0 * k)
	var fl := 1.0 + 0.16 * sin(anim_t * 23.0) + 0.08 * sin(anim_t * 37.0)
	c.draw_texture_rect(disc, Rect2(tip - Vector2(70, 70) * k, Vector2(140, 140) * k), false, Color(1.0, 0.6, 0.2, 0.22 * fl))
	c.draw_texture_rect(disc, Rect2(tip + Vector2(-13, -30) * k * fl, Vector2(26, 36) * k * fl), false, Color(1.0, 0.55, 0.12, 0.9))
	c.draw_texture_rect(disc, Rect2(tip + Vector2(-7, -22) * k * fl, Vector2(14, 22) * k * fl), false, Color(1.0, 0.92, 0.55, 0.95))

func _katana(c: CanvasItem, hand: Vector2, tip: Vector2, k: float, torch: bool = false) -> void:
	if torch and engine.night:
		_torch(c, hand, tip, k)
		return
	if engine.blade() > 0:
		_blade_trail(c, hand, tip, k)
	c.draw_line(hand, tip, pal.ink, 4.0 * k)
	if engine.gold():   # owner 2026-11-20: Hard mode's golden sword (third boss), warm glint
		c.draw_line(hand.lerp(tip, 0.12), tip, Color(1.0, 0.8, 0.3), 2.8 * k)
		var gg: Vector2 = hand.lerp(tip, 0.2 + 0.75 * fposmod(anim_t * 0.6, 1.0))
		c.draw_texture_rect(disc, Rect2(gg - Vector2(5, 5) * k, Vector2(10, 10) * k), false, Color(1, 0.95, 0.7, 0.95))
	elif engine.silver():   # owner 2026-11-20: the shiny silver sword, with a travelling glint
		c.draw_line(hand.lerp(tip, 0.12), tip, Color(0.86, 0.9, 0.96), 2.6 * k)
		var gl: Vector2 = hand.lerp(tip, 0.2 + 0.75 * fposmod(anim_t * 0.6, 1.0))
		c.draw_texture_rect(disc, Rect2(gl - Vector2(5, 5) * k, Vector2(10, 10) * k), false, Color(1, 1, 1, 0.9))
	else:
		c.draw_line(hand.lerp(tip, 0.12), tip, pal.moon, 1.5 * k)
	var n := (tip - hand).normalized().orthogonal() * 6.0 * k
	c.draw_line(hand.lerp(tip, 0.1) - n, hand.lerp(tip, 0.1) + n, pal.ink, 3.0 * k)   # guard

## The hero: brush-stroke ninja, long headband tails, katana held ready; a slash leaves a
## sweeping ink crescent (owner's references).
func _ninja(c: CanvasItem, feet: Vector2, k: float) -> void:
	hero_feet = feet
	var f: int = engine.facing
	var ink: Color = pal.ink
	var running: bool = engine.on_ground and absf(engine.vx) > 40.0
	var j := _pose(feet, k, f, engine.run_t * 14.0, running, engine.crouch, not engine.on_ground)
	if engine.dash_t > 0.0:
		for i in 4:
			c.draw_line(j.hip - Vector2(f * (30 + i * 22), i * 7 - 10) * k, j.hip - Vector2(f * (70 + i * 22), i * 7 - 10) * k, Color(pal.mid, 0.6), (5 - i) * k)
	_ink_body(c, j, k, f, ink, 1.0, true, anim_t * 10.0 + (engine.vx * 0.01), 1.0, BAND, band_hang, band_rise)
	var neck: Vector2 = j.neck
	var jabbing: bool = engine.slash_t > 0.0 and engine.jab
	if engine.dash_t > 0.0 or jabbing:
		# Thrust / crouching jab (owner 2026-11-15): arm straight out, blade level, point first.
		var reach := 1.0
		if jabbing:
			var t0: float = 1.0 - engine.slash_t / Engine_.SLASH_T
			reach = sin(minf(t0 * 1.6, 1.0) * PI * 0.5)
		var hand := neck + Vector2(f * (8 + 22 * reach), 10) * k
		_brush(c, neck, hand, 6.0 * k, ink)
		var tip := hand + Vector2(f * (60 + 30 * reach), 2) * k
		_katana(c, hand, tip, k, true)
		for i in 3:
			var yy := (i - 1) * 7.0 * k
			c.draw_line(tip + Vector2(-f * (20 + i * 12) * k, yy), tip + Vector2(-f * (70 + i * 16) * k, yy), Color(ink, 0.35 * reach), 2.0 * k)
	elif engine.slash_t > 0.0:
		var t: float = 1.0 - engine.slash_t / Engine_.SLASH_T
		# Three cuts in a combo (owner 2026-11-15): a chop down, a rising diagonal, a long sideways sweep.
		var sw: int = engine.swing
		var a0: float = [-1.4, 1.35, 0.4][sw]
		var a1: float = [1.2, -1.45, -0.4][sw]
		if engine.air_dir == 1:
			a0 = -0.2   # a cut straight up
			a1 = -1.75
		elif engine.air_dir == 2:
			a0 = 0.2    # a plunging cut down
			a1 = 1.75
		var te := 1.0 - pow(1.0 - t, 2.2)   # fast start, soft finish
		var a := lerpf(a0, a1, te)
		var rl := 1.25 if sw == 2 else 1.0
		var hand := neck + Vector2(f * 20, 4).rotated(a * f) * k
		_brush(c, neck, hand, 6.0 * k, ink)
		_katana(c, hand, hand + Vector2(f * 74 * rl, 0).rotated(a * f) * k, k, true)
		# The cut: a thick crescent that sweeps after the blade and thins at its tail.
		var pts := []
		for i in 12:
			var aa := lerpf(a0, a, float(i) / 11.0)
			pts.append(neck + Vector2(f * 84 * rl, 0).rotated(aa * f) * k)
		_ribbon(c, pts, 1.0 * k, (16.0 if sw != 2 else 11.0) * k, Color(ink, 0.85))
		_ribbon(c, pts, 0.5 * k, 5.0 * k, Color(pal.moon, 0.7 * (1.0 - t)))
	elif engine.blocking:
		# Guard: blade upright in front of the face.
		var hand := neck + Vector2(f * 22, 6) * k
		_brush(c, neck, hand, 6.0 * k, ink)
		_katana(c, hand + Vector2(0, 24) * k, hand + Vector2(f * 6, -58) * k, k, true)
	else:
		# At rest and running the sword trails at the side, point behind (owner 2026-11-15).
		var hand: Vector2 = j.hip + Vector2(f * 6, -6) * k
		_brush(c, neck, hand, 6.0 * k, ink)
		var tip: Vector2 = hand + (Vector2(-f * 62, 14) if not engine.crouch else Vector2(-f * 64, 2)) * k
		if engine.night:
			tip = hand + Vector2(f * 14, -54) * k   # the torch is held up
		_katana(c, hand, tip, k, true)

## Foes and bosses: the same brush figure in a lighter ink, bulkier for brutes and bosses.
func _figure(c: CanvasItem, feet: Vector2, k: float, f: int, kind: String, flash: bool, windup: bool, moving: bool, t: float) -> void:
	var ink: Color = pal.mid if flash else pal.near.lerp(pal.ink, 0.45)
	var bulk := 1.35 if kind == "brute" or kind == "boss0" or kind == "boss3" else 1.0
	var j := _pose(feet, k, f, t * 1.0, moving, false, false)   # legs stride only while the foe really moves (phase = distance walked)
	var tl := 1.0 if kind.begins_with("boss") else (0.5 if kind == "blade" or kind == "thrower" else 0.0)
	_ink_body(c, j, k, f, ink, bulk, tl > 0.0, anim_t * 6.0 + t, tl)
	var neck: Vector2 = j.neck
	var head: Vector2 = j.head
	match kind:
		"boss0":   # Iron Monk: wide straw hat and a staff
			_poly(c, PackedVector2Array([head + Vector2(-28, 2) * k, head + Vector2(0, -18) * k, head + Vector2(28, 2) * k]), ink)
			_brush(c, neck + Vector2(f * 16, -44) * k, neck + Vector2(f * 16, 60) * k, 5.0 * k, ink)
		"boss1":   # Twin Blade: two swords
			for s in [-1, 1]:
				var h2 := neck + Vector2(f * 14, 8) * k
				_katana(c, h2, h2 + Vector2(f * 56, -20 * s).rotated(-0.6 if windup else 0.0) * k, k)
		"boss2":   # Paper Crane: wide sleeves like wings
			var w := 1.0 + 0.3 * sin(t * 2.0)
			_poly(c, PackedVector2Array([neck, neck + Vector2(-54, 30 * w) * k, neck + Vector2(-20, 34) * k]), Color(ink, 0.75))
			_poly(c, PackedVector2Array([neck, neck + Vector2(54, 30 * w) * k, neck + Vector2(20, 34) * k]), Color(ink, 0.75))
		"boss3":   # Shadow Daimyo: helmet crest and a long blade
			_brush(c, head + Vector2(-14, -10) * k, head + Vector2(-24, -32) * k, 3.0 * k, ink)
			_brush(c, head + Vector2(14, -10) * k, head + Vector2(24, -32) * k, 3.0 * k, ink)
			_katana(c, neck + Vector2(f * 14, 6) * k, neck + Vector2(f * 96, -12) * k, k)
		"thrower":
			_brush(c, neck, neck + Vector2(f * 18, -16) * k, 5.0 * k, ink)
		_:
			var up := -1.4 if windup else 0.3
			var hand := neck + Vector2(f * 18, 8) * k
			_brush(c, neck, hand, 5.0 * k, ink)
			_katana(c, hand, hand + Vector2(f * 50, 0).rotated(up * f) * k, k)
	if windup:
		c.draw_string(ThemeDB.fallback_font, head + Vector2(-8, -30) * k, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(34 * k), pal.ink)

## The six act bosses (story bible, owner 2026-11-15), each in its own shape, matching
## the cutscenes: 1 Gate Warden (stone lion-dog), 2 Tora (tiger), 3 the Dragon, 4 Tsuru
## (crane), 5 the Calligrapher (monk with Hakuu's brush), 6 Lord Shu's Hand. Each wears
## Lord Shu's red seal: SHU_RED is the bible's seal red (a3201a), the crane's crown the one
## other red. The hit box and attacks stay the engine's (boss_box, BOSS_KIND move sets).
const SHU_RED := Color("a3201a")

func _boss_art(c: CanvasItem, feet: Vector2, k: float, b: Dictionary, tele: bool) -> void:
	# if _draw_pose(c, feet, k, engine.act(), _boss_pose(b), b.face, Color(1.0, 0.62, 0.55) if b.hit > 0.0 else Color.WHITE):
	# Owner 2026-11-21 "his skin colour changes": the red hit tint dyed the painted skin. A hit is a
	# brief lighter flash now (the hit pose already shows the blow).
	if _draw_pose(c, feet, k, engine.act(), _boss_pose(b), b.face, Color(1.18, 1.18, 1.18) if b.hit > 0.0 else Color.WHITE):
		if tele:
			c.draw_string(ThemeDB.fallback_font, feet + Vector2(-8, -BOSS_H - 40) * k, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(42 * k), pal.ink)
		return
	var act: int = engine.act()
	var f: int = b.face
	var flash: bool = b.hit > 0.0
	var ink: Color = pal.mid if flash else pal.near.lerp(pal.ink, 0.8)   # darker than the foes: bosses read through the mist
	var t := anim_t * 4.0
	var air: bool = b.y < Engine_.GROUND - 2.0
	var moving: bool = absf(b.vx) > 20.0
	var top := feet + Vector2(0, -110) * k   # where the "!" goes
	match act:
		1:
			top = _boss_warden(c, feet, k, f, ink, t, moving)
		2:
			top = _boss_tora(c, feet, k, f, ink, t, moving, air)
		3:
			top = _boss_dragon(c, feet, k, f, ink, t)
		4:
			top = _boss_tsuru(c, feet, k, f, ink, t, air)
		5:
			top = _boss_calligrapher(c, feet, k, f, ink, t, tele)
		_:
			top = _boss_hand(c, feet, k, f, ink, t, air)
	if tele:
		c.draw_string(ThemeDB.fallback_font, top + Vector2(-8, -10) * k, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(42 * k), pal.ink)

func _ell(c: CanvasItem, ctr: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(ctr + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	c.draw_colored_polygon(pts, col)

## Lord Shu's seal: a small red square with a pale carved mark.
func _seal(c: CanvasItem, p: Vector2, s: float) -> void:
	c.draw_rect(Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), SHU_RED)
	c.draw_line(p + Vector2(-s * 0.25, -s * 0.2), p + Vector2(s * 0.25, -s * 0.2), pal.paper, maxf(1.0, s * 0.1))
	c.draw_line(p + Vector2(0, -s * 0.3), p + Vector2(0, s * 0.3), pal.paper, maxf(1.0, s * 0.1))

## Quadratic points (for curved shapes).
func _q(p0: Vector2, cc: Vector2, p1: Vector2, n := 6) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in range(1, n + 1):
		var u := float(i) / n
		o.append(p0.lerp(cc, u).lerp(cc.lerp(p1, u), u))
	return o

## 1 Gate Warden: a stone lion-dog, heavy and low, a curled mane, the seal on its brow.
func _boss_warden(c: CanvasItem, feet: Vector2, k: float, f: int, ink: Color, t: float, moving: bool) -> Vector2:
	var stone: Color = ink.lerp(pal.mid, 0.25)
	var step := sin(t * 1.5) * 6.0 if moving else 0.0
	for lx in [-44.0, -24.0, 26.0, 46.0]:   # four thick legs
		var sw := step if lx * f > 0 else -step
		c.draw_rect(Rect2(feet + Vector2(lx * f - 9 + sw, -40) * k, Vector2(18, 40) * k), stone)
	var body := PackedVector2Array([feet + Vector2(-70 * f, -36) * k])
	body.append_array(_q(feet + Vector2(-70 * f, -36) * k, feet + Vector2(-74 * f, -96) * k, feet + Vector2(-20 * f, -92) * k))
	body.append_array(_q(feet + Vector2(-20 * f, -92) * k, feet + Vector2(40 * f, -110) * k, feet + Vector2(66 * f, -60) * k))
	body.append(feet + Vector2(60 * f, -36) * k)
	_poly(c, body, stone)
	# Mane: overlapping curls around the head.
	var head := feet + Vector2(58 * f, -96) * k
	for i in 7:
		var a := -2.6 + i * 0.55
		_ell(c, head + Vector2(cos(a) * 30 * f, sin(a) * 26) * k, 13 * k, 13 * k, ink)
	_ell(c, head, 26 * k, 22 * k, stone)
	c.draw_line(head + Vector2(6 * f, -6) * k, head + Vector2(18 * f, -6) * k, pal.paper, 3.0 * k)   # stone eye
	c.draw_line(head + Vector2(4 * f, 10) * k, head + Vector2(24 * f, 12) * k, ink, 3.0 * k)   # mouth
	# Tail: a stone flame curling up.
	_brush(c, feet + Vector2(-68 * f, -70) * k, feet + Vector2(-92 * f, -112) * k, 9.0 * k, ink)
	_seal(c, head + Vector2(4 * f, -18) * k, 12 * k)
	return head + Vector2(0, -40) * k

## 2 Tora: a long low tiger, pale stripes cut through the ink, the seal on its flank.
func _boss_tora(c: CanvasItem, feet: Vector2, k: float, f: int, ink: Color, t: float, moving: bool, air: bool) -> Vector2:
	var run := sin(t * 3.0) * (14.0 if moving else 2.0)
	var tuck := 14.0 if air else 0.0
	for i in 4:   # legs
		var lx: float = [-50.0, -30.0, 34.0, 54.0][i]
		var sw := run if i % 2 == 0 else -run
		_brush(c, feet + Vector2(lx * f, -36) * k, feet + Vector2((lx + sw) * f, -tuck) * k, 9.0 * k, ink)
	_ell(c, feet + Vector2(0, -52) * k, 78 * k, 26 * k, ink)
	var head := feet + Vector2(78 * f, -66) * k
	_ell(c, head, 24 * k, 20 * k, ink)
	_poly(c, PackedVector2Array([head + Vector2(-10 * f, -16) * k, head + Vector2(-4 * f, -30) * k, head + Vector2(4 * f, -16) * k]), ink)   # ear
	c.draw_line(head + Vector2(8 * f, -4) * k, head + Vector2(18 * f, -6) * k, pal.paper, 3.0 * k)
	for i in 6:   # stripes: paper strokes across the back
		var sx := -56.0 + i * 20.0
		_brush(c, feet + Vector2(sx * f, -76) * k, feet + Vector2((sx + 6) * f, -40) * k, 4.0 * k, Color(pal.paper, 0.6))
	var tail := PackedVector2Array([feet + Vector2(-76 * f, -58) * k])
	tail.append_array(_q(tail[0], feet + Vector2(-120 * f, -60 + sin(t) * 10) * k, feet + Vector2(-110 * f, -104) * k))
	c.draw_polyline(tail, ink, 6.0 * k)
	_seal(c, feet + Vector2(-16 * f, -56) * k, 13 * k)
	return head + Vector2(0, -36) * k

## 3 The Dragon: the carp that climbed the falls: a long coiling body rising behind the
## head, whiskers, a crest, the seal on its brow.
func _boss_dragon(c: CanvasItem, feet: Vector2, k: float, f: int, ink: Color, t: float) -> Vector2:
	var pts := PackedVector2Array()
	for i in 11:
		var u := float(i) / 10.0
		pts.append(feet + Vector2((40 - u * 190) * f, -40 - u * 70 + sin(t * 0.8 + u * 7.0) * 26) * k)
	for i in pts.size() - 1:   # body: thick to thin, scales as pale ticks
		var w := lerpf(30.0, 8.0, float(i) / pts.size())
		_brush(c, pts[i], pts[i + 1], w * k, ink)
		if i % 2 == 0:
			c.draw_line(pts[i] + Vector2(0, -w * 0.3) * k, pts[i] + Vector2(-6 * f, -w * 0.1) * k, Color(pal.paper, 0.45), 2.0 * k)
	for i in [3, 6]:   # crest spikes along the back
		_poly(c, PackedVector2Array([pts[i] + Vector2(-8, -12) * k, pts[i] + Vector2(-2 * f, -34) * k, pts[i] + Vector2(8, -12) * k]), ink)
	_brush(c, pts[2], pts[2] + Vector2(10 * f, 40) * k, 6.0 * k, ink)   # a claw to the ground
	var head := pts[0] + Vector2(30 * f, -10) * k
	_ell(c, head, 36 * k, 18 * k, ink, -0.2 * f)
	_poly(c, PackedVector2Array([head + Vector2(-10 * f, -12) * k, head + Vector2(-30 * f, -42) * k, head + Vector2(4 * f, -16) * k]), ink)   # horn
	for s in [-1.0, 1.0]:   # whiskers
		c.draw_polyline(PackedVector2Array([head + Vector2(26 * f, 4) * k] + Array(_q(head + Vector2(26 * f, 4) * k, head + Vector2(70 * f, s * 24 + sin(t * 2) * 8) * k, head + Vector2(100 * f, s * 8) * k))), ink, 2.0 * k)
	c.draw_line(head + Vector2(8 * f, -4) * k, head + Vector2(20 * f, -6) * k, pal.paper, 3.0 * k)
	_seal(c, head + Vector2(-2 * f, -10) * k, 11 * k)
	return head + Vector2(0, -50) * k

## 4 Tsuru, Sealed: a tall crane, wings half open, the red crown (its own) and Lord Shu's
## seal on its chest.
func _boss_tsuru(c: CanvasItem, feet: Vector2, k: float, f: int, ink: Color, t: float, air: bool) -> Vector2:
	var flap := sin(t * (3.0 if air else 0.8)) * (1.0 if air else 0.3)
	if not air:
		c.draw_line(feet + Vector2(-6 * f, -60) * k, feet + Vector2(-10 * f, 0) * k, ink, 3.5 * k)
		c.draw_line(feet + Vector2(6 * f, -60) * k, feet + Vector2(12 * f, 0) * k, ink, 3.5 * k)
	else:
		c.draw_line(feet + Vector2(-4 * f, -60) * k, feet + Vector2(-40 * f, -50) * k, ink, 3.5 * k)
	var body := feet + Vector2(0, -78) * k
	for sd in [-1.0, 1.0]:   # wings
		var tip := body + Vector2(-70 * f, (-50 - 30 * flap) * sd * 0.6 - 20) * k
		var wing := PackedVector2Array([body + Vector2(10 * f, -4) * k])
		wing.append_array(_q(wing[0], body + Vector2(-30 * f, -50 * sd * 0.5 - 20) * k, tip))
		wing.append_array(_q(tip, body + Vector2(-40 * f, 0) * k, body + Vector2(-20 * f, 10) * k))
		_poly(c, wing, Color(ink, 0.85))
	_ell(c, body, 40 * k, 22 * k, ink, -0.3 * f)
	var neck := PackedVector2Array([body + Vector2(28 * f, -10) * k])
	neck.append_array(_q(neck[0], body + Vector2(46 * f, -60) * k, body + Vector2(34 * f, -100) * k))
	c.draw_polyline(neck, ink, 6.0 * k)
	var head := body + Vector2(34 * f, -104) * k
	_ell(c, head, 9 * k, 8 * k, ink)
	c.draw_line(head + Vector2(6 * f, 0) * k, head + Vector2(46 * f, 6) * k, ink, 3.0 * k)   # beak
	_ell(c, head + Vector2(-1 * f, -7) * k, 4.5 * k, 4.5 * k, SHU_RED)   # the crown: the crane's own red
	_seal(c, body + Vector2(14 * f, -4) * k, 13 * k)
	return head + Vector2(0, -24) * k

## 5 The Calligrapher: a robed monk with Hakuu's giant brush, its tip loaded with ink; the
## seal on the brush hand. On a telegraph he raises the brush to paint.
func _boss_calligrapher(c: CanvasItem, feet: Vector2, k: float, f: int, ink: Color, t: float, tele: bool) -> Vector2:
	var robe := PackedVector2Array([feet + Vector2(-46, 0) * k])
	robe.append_array(_q(robe[0], feet + Vector2(-44, -80) * k, feet + Vector2(0, -96) * k))
	robe.append_array(_q(feet + Vector2(0, -96) * k, feet + Vector2(44, -80) * k, feet + Vector2(46, 0) * k))
	_poly(c, robe, ink)
	c.draw_line(feet + Vector2(-30, -50) * k, feet + Vector2(30, -54) * k, pal.mid, 3.0 * k)   # sash
	var head := feet + Vector2(4 * f, -112) * k
	_ell(c, head, 17 * k, 17 * k, ink)
	c.draw_line(head + Vector2(2 * f, -2) * k, head + Vector2(12 * f, -2) * k, pal.paper, 2.5 * k)
	var hand := feet + Vector2(34 * f, -64) * k
	var ang := (-1.9 if tele else -0.9) + sin(t * 0.7) * 0.15
	var tip := hand + Vector2(f * 140, 0).rotated(ang * f) * k
	var tail := hand - (tip - hand) * 0.3
	c.draw_line(tail, tip, Color("6a5a40"), 7.0 * k)   # the brush's bamboo handle
	_ell(c, tip + (tip - hand).normalized() * 12 * k, 12 * k, 22 * k, ink, (tip - hand).angle() + PI / 2)
	_brush(c, feet + Vector2(0, -80) * k, hand, 9.0 * k, ink)   # arm
	_seal(c, hand, 12 * k)
	return head + Vector2(0, -30) * k

## 6 Lord Shu's Hand: a giant hand reaching down from above the frame, fingers spread
## over the ground, the red signet ring. Its knuckles are the hit box.
func _boss_hand(c: CanvasItem, feet: Vector2, k: float, f: int, ink: Color, t: float, air: bool) -> Vector2:
	var dark: Color = Color("211d1a") if pal.ink.v < 0.5 else ink
	if bool(engine.boss.get("hit", 0.0) > 0.0):
		dark = pal.mid
	var palm := feet + Vector2(0, -70) * k
	var arm := PackedVector2Array([palm + Vector2(-60, -900) * k, palm + Vector2(-58, -20) * k])
	arm.append_array(_q(palm + Vector2(-58, -20) * k, palm + Vector2(-50, 40) * k, palm + Vector2(0, 46) * k))
	arm.append_array(_q(palm + Vector2(0, 46) * k, palm + Vector2(56, 40) * k, palm + Vector2(64, -20) * k))
	arm.append(palm + Vector2(68, -900) * k)
	_poly(c, arm, dark)
	var curl := 0.0 if air else 10.0 + sin(t) * 4.0
	for i in 4:   # fingers reaching to the ground
		var fx := -44.0 + i * 30.0
		_ell(c, palm + Vector2(fx, 50 + curl * 0.5) * k, 12 * k, 30 * k, dark)
	_ell(c, palm + Vector2(f * 70, 20) * k, 12 * k, 26 * k, dark, 0.6 * f)   # thumb
	_ell(c, palm + Vector2(-14, 34) * k, 11 * k, 7 * k, SHU_RED)   # the signet ring
	_seal(c, palm + Vector2(0, -10) * k, 16 * k)
	return palm + Vector2(0, -60) * k

## A soft shadow on the ground under a figure: smaller and fainter the higher it is.
func _shadow(c: CanvasItem, o: Vector2, x: float, y: float, k: float, w: float) -> void:
	var gy: float = engine.ground_y(x)
	for s in engine.solids:
		if x > s.position.x and x < s.end.x and s.position.y >= y - 1.0 and s.position.y < gy:
			gy = s.position.y   # a ledge under the feet
	var hgt := clampf((gy - y) / 300.0, 0.0, 1.0)
	var ww := w * (1.0 - hgt * 0.6)
	var p := o + Vector2(x, gy) * k
	c.draw_texture_rect(disc, Rect2(p - Vector2(ww, ww * 0.18) * k, Vector2(ww * 2, ww * 0.36) * k), false, Color(pal.shadow, 0.55 * (1.0 - hgt)))

## Smoke puffs: soft grey discs that grow, drift up and fade. [world pos, vel, life, max life, size]
func _puff(p: Vector2, n: int, size: float, spread: float) -> void:
	for i in n:
		if smoke.size() >= 90:
			return
		var v := Vector2(randf_range(-spread, spread), randf_range(-60, -10))
		var life := randf_range(0.5, 1.0)
		smoke.append([p + Vector2(randf_range(-10, 10), randf_range(-6, 6)), v, life, life, size * randf_range(0.7, 1.3)])

func _smoke_tick(delta: float) -> void:
	for s in smoke:
		s[0] += s[1] * delta
		s[1] *= 1.0 - 1.5 * delta
		s[2] -= delta
	smoke = smoke.filter(func(s): return s[2] > 0.0)
	for mo in motes:
		mo[1] -= mo[2] * delta
		if mo[1] < -0.05:
			mo[1] += 1.1
			mo[0] = randf()
	for m in mist:
		m[0] += m[2] * delta
		if m[0] > 1.3:
			m[0] -= 1.6
	for cl in clouds:
		cl[0] += cl[3] * delta
		if cl[0] > 1.4:
			cl[0] -= 1.8
	for pe in petals:
		pe[1] += pe[2] * delta
		pe[0] += (0.012 + 0.01 * sin(anim_t * 0.9 + pe[4])) * delta
		if pe[1] > 1.05:
			pe[1] -= 1.15
			pe[0] = randf()
		if pe[0] > 1.05:
			pe[0] -= 1.1
	for sp in sparks:
		sp[0] += sp[1] * delta
		sp[1] *= 1.0 - 5.0 * delta
		sp[2] -= delta
	sparks = sparks.filter(func(sp): return sp[2] > 0.0)

func _draw_smoke(c: CanvasItem, o: Vector2, k: float) -> void:
	for s in smoke:
		var t: float = 1.0 - s[2] / s[3]
		var r: float = s[4] * (0.6 + t * 1.2) * k
		c.draw_texture_rect(disc, Rect2(o + s[0] * k - Vector2(r, r), Vector2(r, r) * 2), false, Color(pal.smoke, 0.45 * (1.0 - t)))

## Mist wisps drifting across the field in front of everything (screen space, slow).
## Floating particles (owner 2026-11-15): soft glowing motes drifting up in front of the land,
## parallax with the camera. Warm embers and a few cool blue-white ones.
func _draw_motes(c: CanvasItem, sz: Vector2, k: float) -> void:
	var cam: float = engine.cam_x()
	for mo in motes:
		var x := fposmod(mo[0] * sz.x - cam * k * mo[5] * 0.5 + sin(anim_t * 0.6 + mo[4]) * 14.0 * k, sz.x)
		var y: float = mo[1] * sz.y
		var r: float = mo[3] * k * (0.8 + 0.3 * sin(anim_t * 1.7 + mo[4]))
		var tw := 0.55 + 0.45 * sin(anim_t * 2.1 + mo[4] * 2.0)
		var col := Color(0.45, 0.75, 1.0, 0.55 * tw) if mo[6] else Color(1.0, 0.7, 0.28, 0.7 * tw)
		c.draw_texture_rect(disc, Rect2(Vector2(x - r * 2.2, y - r * 2.2), Vector2(r, r) * 4.4), false, Color(col, col.a * 0.25))
		c.draw_texture_rect(disc, Rect2(Vector2(x - r, y - r), Vector2(r, r) * 2), false, col)

func _draw_mist(c: CanvasItem, sz: Vector2, k: float) -> void:
	for m in mist:
		var x: float = m[0] * sz.x
		var y: float = m[1] * k
		var w: float = m[3] * k
		var breathe := 0.75 + 0.25 * sin(anim_t * 0.5 + m[4])
		c.draw_texture_rect(disc, Rect2(Vector2(x - w, y - w * 0.16), Vector2(w * 2, w * 0.32)), false, Color(pal.fog, 0.22 * breathe))

## draw_colored_polygon, skipped when the shape folds over itself (Godot cannot
## triangulate it and prints an error every frame).
func _poly(c: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	c.draw_colored_polygon(pts, col)

func _star(c: CanvasItem, p: Vector2, k: float, mine: bool) -> void:
	var a := anim_t * 20.0
	var col: Color = pal.ink if mine else pal.near
	for i in 2:
		var d := Vector2(10, 0).rotated(a + i * PI / 2) * k
		c.draw_line(p - d, p + d, col, 3.5 * k)

## The pickup (engine.scrolls; owner 2026-11-19: the paper scrolls looked like envelopes):
## a gold koban coin, a turning oval with stamped bands. Texture rects only (cheap).
## The old paper look, kept as the owner asked never to delete:
#	var r := Rect2(p + Vector2(-14, -9 + bob / k) * k, Vector2(28, 18) * k)
#	c.draw_rect(r, pal.moon)
#	c.draw_rect(r, pal.ink, false, 2.0 * k)
#	c.draw_line(r.position + Vector2(6, 6) * k, r.position + Vector2(22, 6) * k, pal.mid, 2.0 * k)
#	c.draw_line(r.position + Vector2(6, 11) * k, r.position + Vector2(18, 11) * k, pal.mid, 2.0 * k)
## wx: the coin's world x, so its bob / turn phase stays put while the camera scrolls (owner
## 2026-11-21: coins "shake" when you run; the phase used the screen x, which moves every frame).
## True when a spike board that is down sits within `d` units of the hero.
func _trap_near(d: float) -> bool:
	for t in engine.traps:
		if t.state == "down" and absf(t.x - engine.px) < d:
			return true
	return false

func _scroll(c: CanvasItem, p: Vector2, k: float, wx: float = 0.0) -> void:
	# var bob := sin(anim_t * 3.0 + p.x) * 4.0 * k
	var bob := sin(anim_t * 3.0 + wx) * 4.0 * k
	var ctr := p + Vector2(0, bob)
	# var turn := absf(cos(anim_t * 2.2 + p.x * 0.01))
	var turn := absf(cos(anim_t * 2.2 + wx * 0.01))
	var hw := maxf(3.0, 13.0 * turn) * k
	var hh := 18.0 * k
	c.draw_texture_rect(disc, Rect2(ctr - Vector2(hw + 2.0 * k, hh + 2.0 * k), Vector2(hw + 2.0 * k, hh + 2.0 * k) * 2.0), false, Color(0.42, 0.28, 0.02))
	c.draw_texture_rect(disc, Rect2(ctr - Vector2(hw, hh), Vector2(hw, hh) * 2.0), false, Color(0.95, 0.76, 0.24))
	c.draw_texture_rect(disc, Rect2(ctr - Vector2(hw * 0.55, hh * 0.7) + Vector2(-hw * 0.2, -hh * 0.15), Vector2(hw * 0.55, hh * 0.5)), false, Color(1.0, 0.95, 0.7, 0.7))
	if turn > 0.35:
		for i in 4:
			var ly := ctr.y + (-9.0 + i * 6.0) * k
			c.draw_line(Vector2(ctr.x - hw * 0.55, ly), Vector2(ctr.x + hw * 0.55, ly), Color(0.6, 0.42, 0.06, 0.8), 1.5 * k)

## A hidden treasure (engine.secrets): a jade magatama with a soft glow (owner 2026-11-19).
func _magatama(c: CanvasItem, p: Vector2, k: float, wx: float = 0.0) -> void:
	# var bob := sin(anim_t * 2.4 + p.x) * 5.0 * k
	var bob := sin(anim_t * 2.4 + wx) * 5.0 * k   # world x: steady while the camera scrolls
	var ctr := p + Vector2(0, bob)
	var jade := Color(0.3, 0.75, 0.55)
	c.draw_texture_rect(disc, Rect2(ctr - Vector2(15, 15) * k, Vector2(30, 30) * k), false, jade.darkened(0.45))
	c.draw_texture_rect(disc, Rect2(ctr - Vector2(13, 13) * k, Vector2(26, 26) * k), false, jade)
	# the comma tail curling down and back
	for i in 6:
		var a := 0.3 + i * 0.32
		var r := (11.0 - i * 1.4) * k
		var q := ctr + Vector2(cos(a) * 12.0, sin(a) * 12.0 + 6.0) * k
		c.draw_texture_rect(disc, Rect2(q - Vector2(r, r) * 0.5, Vector2(r, r)), false, jade)
	c.draw_texture_rect(disc, Rect2(ctr - Vector2(4, 4) * k, Vector2(8, 8) * k), false, jade.darkened(0.55))   # the hole
	c.draw_texture_rect(disc, Rect2(ctr + Vector2(-9, -10) * k, Vector2(8, 6) * k), false, Color(1, 1, 1, 0.6))

func _hud_draw(c: CanvasItem, sz: Vector2, k: float) -> void:
	var font := ThemeDB.fallback_font
	var u := clampf(k, 0.8, 1.5)
	if plate_sb == null:
		plate_sb = StyleBoxFlat.new()
		plate_sb.bg_color = Color(pal.paper, 0.78)
		plate_sb.border_color = Color(pal.ink, 0.85)
		plate_sb.set_border_width_all(2)
		plate_sb.set_corner_radius_all(16)
		plate_sb.shadow_color = Color(0, 0, 0, 0.28)
		plate_sb.shadow_size = 7
		plate_sb.shadow_offset = Vector2(0, 3)
	# Status plate: hearts, stars, smoke bombs, lives (beside the pause button).
	var hx := 112.0
	var cy := 46.0
	var usable: bool = engine.can("star")   # owner 2026-11-16: nothing is shown that cannot be used yet
	var pw := (5 * 30.0 + (3 if usable else 1) * 82.0 + 20.0) * u
	c.draw_style_box(plate_sb, Rect2(hx, 16.0, pw, 60.0))
	for i in Engine_.MAX_HP:
		var hp_pos := Vector2(hx + (24.0 + i * 30.0) * u, cy)
		var full: bool = i < engine.hp
		var beat := 1.0 + (0.16 * sin(anim_t * 9.0) if engine.hp == 1 and full else 0.0)
		if full:
			_heart(c, hp_pos + Vector2(0, -2.0 * u), 10.0 * u * beat, Color(pal.red).lightened(0.05))
			_heart(c, hp_pos + Vector2(-3.0, -5.0) * u, 3.5 * u, Color(1, 1, 1, 0.35))   # glint
		else:
			_heart(c, hp_pos + Vector2(0, -2.0 * u), 9.0 * u, Color(pal.ink, 0.22))
	var sx0 := hx + (5 * 30.0 + 30.0) * u
	var bx0 := sx0 + 82.0 * u
	if usable:
		_star(c, Vector2(sx0, cy), u * 0.95, true)
		c.draw_string(font, Vector2(sx0 + 14.0 * u, cy + 8.0 * u), str(engine.stars), HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * u), pal.ink)
		c.draw_texture_rect(disc, Rect2(Vector2(bx0 - 10.0 * u, cy - 8.0 * u), Vector2(20, 20) * u), false, pal.ink)
		c.draw_line(Vector2(bx0 + 4.0 * u, cy - 7.0 * u), Vector2(bx0 + 10.0 * u, cy - 15.0 * u), pal.near, 2.0 * u)
		c.draw_texture_rect(disc, Rect2(Vector2(bx0 + 6.0 * u, cy - 19.0 * u), Vector2(8, 8) * u), false, Color(1.0, 0.6, 0.2, 0.7 + 0.3 * sin(anim_t * 8.0)))
		c.draw_string(font, Vector2(bx0 + 16.0 * u, cy + 8.0 * u), str(engine.bombs), HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * u), pal.ink)
	var lx0 := (bx0 + 82.0 * u) if usable else sx0
	c.draw_texture_rect(disc, Rect2(Vector2(lx0 - 10.0 * u, cy - 10.0 * u), Vector2(20, 20) * u), false, pal.ink)
	c.draw_rect(Rect2(Vector2(lx0 - 10.0 * u, cy - 5.0 * u), Vector2(20.0 * u, 4.0 * u)), BAND)
	c.draw_string(font, Vector2(lx0 + 16.0 * u, cy + 8.0 * u), str(extra_lives), HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * u), pal.ink)
	# Score plate (top right), the number rolls up and pops.
	var sw := 190.0 * u
	var sbx := sz.x - 24.0 - sw
	c.draw_style_box(plate_sb, Rect2(sbx, 16.0, sw, 60.0))
	var pop := score_pop
	c.draw_string(font, Vector2(sbx, cy + 12.0 * u), str(int(score_shown)), HORIZONTAL_ALIGNMENT_CENTER, sw, int((32.0 + 8.0 * pop) * u), pal.ink)
	if engine.combo >= 2 and engine.combo_t > 0.0:
		var cb := "x%d" % engine.combo
		c.draw_string_outline(font, Vector2(sbx, 104.0 * u), cb, HORIZONTAL_ALIGNMENT_RIGHT, sw, int(30 * u), int(6 * u), pal.paper)
		c.draw_string(font, Vector2(sbx, 104.0 * u), cb, HORIZONTAL_ALIGNMENT_RIGHT, sw, int(30 * u), pal.red)
	# Stage progress: a brush track with lantern marks, the gate and the ninja's dot.
	var y := 96.0 * k
	var x0 := sz.x * 0.3
	var x1 := sz.x * 0.7
	c.draw_line(Vector2(x0, y), Vector2(x1, y), Color(pal.far, 0.85), 7.0 * u)
	var px := lerpf(x0, x1, engine.progress())
	c.draw_line(Vector2(x0, y), Vector2(px, y), Color(pal.ink, 0.95), 5.0 * u)
	for ci in 4:
		var lxp := lerpf(x0, x1, float(ci + 1) / 5.0)
		var lit: bool = engine.checkpoint_x >= engine.checkpoints[ci] if ci < engine.checkpoints.size() else false
		c.draw_texture_rect(disc, Rect2(Vector2(lxp - 6.0 * u, y - 6.0 * u), Vector2(12, 12) * u), false, Color(1.0, 0.8, 0.3) if lit else Color(pal.ink, 0.5))
	c.draw_rect(Rect2(Vector2(x1 - 2.0 * u, y - 12.0 * u), Vector2(4.0 * u, 24.0 * u)), Color(0.72, 0.16, 0.12))
	c.draw_texture_rect(disc, Rect2(Vector2(px, y) - Vector2(12, 12) * u, Vector2(24, 24) * u), false, Color(pal.paper, 0.9))
	c.draw_texture_rect(disc, Rect2(Vector2(px, y) - Vector2(8, 8) * u, Vector2(16, 16) * u), false, pal.ink)
	if not engine.boss.is_empty() and engine.boss.hp > 0:
		var w := sz.x * 0.5
		var bx := (sz.x - w) / 2.0
		var by := sz.y - 46.0 * u
		var ratio := float(engine.boss.hp) / float(engine.boss.max)
		c.draw_style_box(plate_sb, Rect2(bx - 18.0 * u, by - 42.0 * u, w + 36.0 * u, 64.0 * u))
		c.draw_string(font, Vector2(bx, by - 18 * u), tr(engine.boss_name()), HORIZONTAL_ALIGNMENT_CENTER, w, int(22 * u), pal.ink)
		c.draw_rect(Rect2(bx, by - 6.0 * u, w, 14 * u), Color(pal.far, 0.7))
		c.draw_rect(Rect2(bx, by - 6.0 * u, w * boss_trail, 14 * u), Color(pal.red, 0.65))
		c.draw_rect(Rect2(bx, by - 6.0 * u, w * ratio, 14 * u), pal.ink)
		c.draw_rect(Rect2(bx, by - 6.0 * u, w * ratio, 4 * u), Color(1, 1, 1, 0.18))
		c.draw_rect(Rect2(bx, by - 6.0 * u, w, 14 * u), Color(pal.ink, 0.8), false, 2.0 * u)
	if banner != "":
		var fs := int(64 * k)
		var tp := Vector2(0, sz.y * 0.42)
		c.draw_rect(Rect2(0, tp.y - fs * 0.95, sz.x, fs * 1.35), Color(pal.paper, 0.55))
		c.draw_rect(Rect2(0, tp.y - fs * 0.95, sz.x, 3.0 * k), Color(pal.ink, 0.7))
		c.draw_rect(Rect2(0, tp.y + fs * 0.4, sz.x, 3.0 * k), Color(pal.ink, 0.7))
		c.draw_string_outline(font, tp, banner, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, int(10 * k), pal.paper)
		c.draw_string(font, tp, banner, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, pal.ink)
	# Story objective under the progress line.
	var obj: String = tr("Defeat %s") % tr(engine.boss_name()) if engine.locked else tr(Story.CHAPTERS[engine.stage - 1][2])
	c.draw_string_outline(font, Vector2(x0, y + 26 * u), "▸ " + obj, HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, int(18 * u), int(5 * u), pal.paper)
	c.draw_string(font, Vector2(x0, y + 26 * u), "▸ " + obj, HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, int(18 * u), pal.ink)
	var tip: String = engine.tip()
	if tip != "" and card_text.is_empty():
		var ty := y + 66 * k
		var tw := sz.x * 0.62
		c.draw_rect(Rect2((sz.x - tw) / 2.0, ty - 26 * k, tw, 38 * k), Color(pal.paper, 0.75))
		c.draw_string(font, Vector2((sz.x - tw) / 2.0, ty), tr(TIPS[tip]), HORIZONTAL_ALIGNMENT_CENTER, tw, int(19 * k), pal.ink)
	#var near_tree: bool = not engine.heart_tree_near().is_empty() and not hearts.has(engine.stage)
	# Owner 2026-11-20: no hint at the red tree any more (finding the carving is part of the secret).
	#var note := toast if toast_t > 0.0 else (tr("Tap the red tree (or swing) to carve a heart") if near_tree and tip == "" else "")
	var note := toast if toast_t > 0.0 else ""
	if note != "" and card_text.is_empty():
		var nw := sz.x * 0.62
		var ny := sz.y * 0.3
		c.draw_rect(Rect2((sz.x - nw) / 2.0, ny - 26 * k, nw, 38 * k), Color(pal.paper, 0.8))
		c.draw_string(font, Vector2((sz.x - nw) / 2.0, ny), note, HORIZONTAL_ALIGNMENT_CENTER, nw, int(20 * k), toast_col if toast_t > 0.0 else Color(0.65, 0.08, 0.08))
	if not card_text.is_empty():
		_draw_card(c, sz, k)

## Landing hero: an ensō (one-stroke brush circle) with a pale ninja mid-leap and
## a few ink drops, so it reads on the dark Landing.
func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 170.0, 1.3)
	var o := c.size / 2.0
	if disc == null:
		disc = _make_disc()
	if blot == null:
		blot = _make_blot()
	# Ensō: one tapered brush ribbon (a single polygon) that thins out and leaves a gap.
	var n := 120
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in n + 1:
		var f := float(i) / n
		var a := -2.2 + f * TAU * 0.9
		var r := 92.0 * k + sin(f * 9.0) * 1.5 * k
		var w := lerpf(9.0, 0.8, f * f) * k
		outer.append(o + Vector2.RIGHT.rotated(a) * (r + w))
		inner.append(o + Vector2.RIGHT.rotated(a) * (r - w))
	inner.reverse()
	c.draw_colored_polygon(outer + inner, Color(0.82, 0.82, 0.82, 0.9))
	var pale := Color(0.93, 0.93, 0.93)
	var hip := o + Vector2(-6, 18) * k
	var neck := o + Vector2(10, -22) * k
	c.draw_line(hip, hip + Vector2(-38, 26) * k, pale, 8 * k)
	c.draw_line(hip, hip + Vector2(26, 34) * k, pale, 8 * k)
	c.draw_line(hip, neck, pale, 14 * k)
	c.draw_texture_rect(disc, Rect2(neck + Vector2(-2, -32) * k, Vector2(26, 26) * k), false, pale)
	c.draw_line(neck + Vector2(4, -20) * k, neck + Vector2(-36, -30) * k, Color(0.6, 0.6, 0.6), 4 * k)   # headband tail
	c.draw_line(neck, neck + Vector2(34, -10) * k, pale, 6 * k)
	c.draw_line(neck + Vector2(34, -10) * k, neck + Vector2(110, -64) * k, pale, 4 * k)   # sword
	c.draw_line(neck, neck + Vector2(-26, 14) * k, pale, 6 * k)
	for d in [[Vector2(70, -40), 10.0], [Vector2(96, -14), 6.0], [Vector2(-80, 50), 8.0], [Vector2(-60, -70), 5.0]]:
		c.draw_texture_rect(blot, Rect2(o + d[0] * k - Vector2(d[1], d[1]) * k, Vector2(d[1], d[1]) * 2 * k), false, Color(0.75, 0.75, 0.75))

# ---------- objectives (daily, weekly, story) ----------

func _goal(key: String) -> void:
	if goals == null:
		return
	goals.roll(Goals.today_num(), Goals.week_num())
	for done in goals.count(key):
		var txt := tr("Daily objective complete!") if done == "daily" else tr("Weekly objective complete!")
		SoundLib.play(self, "reward/accomplished", -2.0)
		engine.score += 1000 if done == "daily" else 5000
		_update_hud()
		if info:
			info.add("Daily objectives" if done == "daily" else "Weekly objectives")
			info.celebrate(txt)

func _goal_line(g: Array, n: int, done: bool) -> String:
	var t: String = tr(g[2]) % int(g[1])
	return ("✓ " if done else "") + t + "  (%d / %d)" % [mini(n, int(g[1])), int(g[1])]

## The Objectives card (Landing → More): today's goal, this week's, the story chapter.
func _show_goals() -> Control:
	goals.roll(Goals.today_num(), Goals.week_num())
	var parts: Array = home.card(tr("Objectives"))
	var body: Control = parts[1]
	var d: Dictionary = goals.data
	var ch: Array = Story.CHAPTERS[_story_stage() - 1]
	var rows := [
		[tr("Today"), _goal_line(goals.daily(), int(d.d_n), bool(d.d_done)), tr("Reward: %d points") % 1000, tr("A new one tomorrow")],
		[tr("This week"), _goal_line(goals.weekly(), int(d.w_n), bool(d.w_done)), tr("Reward: %d points") % 5000, tr("A new one every Monday")],
		[tr("Story"), tr(ch[0]), tr(ch[2]), tr("One stolen brush")],
	]
	for r in rows:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		for i in r.size():
			var l := Label.new()
			l.text = r[i]
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_font_size_override("font_size", [30, 26, 22, 18][i])
			l.add_theme_color_override("font_color", [Color(1, 1, 1), Color(0.9, 0.9, 0.9), Color(0.7, 0.7, 0.7), Color(0.55, 0.55, 0.55)][i])
			box.add_child(l)
		body.add_child(box)
		body.add_child(HSeparator.new())
	home.show_card(parts[0])
	return parts[0]

## The chapter the player is on: the running stage, else the saved one, else 1.
func _story_stage() -> int:
	if started:
		return engine.stage
	var sv = SaveUtil.read(SAVE_PATH)
	return 1 if sv == null else clampi(int(sv.get("stage", 1)), 1, Engine_.STAGES)

## The chapter card: a paper sheet with the title, the story lines and the objective.
func _draw_card(c: CanvasItem, sz: Vector2, k: float) -> void:
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(pal.paper, 0.75))
	var w := minf(sz.x * 0.7, 900.0 * k)
	var r := Rect2((sz.x - w) / 2.0, sz.y * 0.18, w, sz.y * 0.6)
	c.draw_rect(r, pal.moon)
	c.draw_rect(r, pal.ink, false, 3.0 * k)
	c.draw_line(r.position + Vector2(30, 92) * k, Vector2(r.end.x - 30 * k, r.position.y + 92 * k), pal.mid, 2.0 * k)
	c.draw_string(font, r.position + Vector2(0, 64 * k), card_text[0], HORIZONTAL_ALIGNMENT_CENTER, w, int(40 * k), pal.ink)
	c.draw_multiline_string(font, r.position + Vector2(40, 140) * k, card_text[1], HORIZONTAL_ALIGNMENT_LEFT, w - 80 * k, int(24 * k), -1, pal.near)
	c.draw_string(font, Vector2(r.position.x, r.end.y - 70 * k), "▸ " + card_text[2], HORIZONTAL_ALIGNMENT_CENTER, w, int(28 * k), pal.ink)
	if card_t < 5.5 and fmod(anim_t, 1.0) < 0.7:
		c.draw_string(font, Vector2(r.position.x, r.end.y - 24 * k), tr("Press any button"), HORIZONTAL_ALIGNMENT_CENTER, w, int(18 * k), pal.mid)

# ---------- skins ----------

func _set_skin(name: String) -> void:
	skin = name if LOOKS.has(name) else "classic"
	pal = LOOKS[skin].merged(WASH[skin], true)
	plate_sb = null
	_hud_colors()
	_paper_params()
	if field:
		field.queue_redraw()

func _hud_colors() -> void:
	for l in [hud, score_label]:
		if l:
			l.add_theme_color_override("font_color", pal.ink)
			l.add_theme_color_override("font_outline_color", pal.paper)
			l.add_theme_constant_override("outline_size", 6)

func _current_skin() -> String:
	return skin

# ---------- pause / save ----------

func _on_pause() -> void:
	key_l = false
	key_r = false
	key_d = false
	home.pause()

func _go_home() -> void:
	home.go_home()

## Stage, score, lives, stars; Resume restarts the stage.
func _save_game() -> void:
	if not started or engine.state == "over" or engine.state == "cleared":
		return
	var st: int = engine.stage
	if engine.state == "won":
		st = mini(Engine_.STAGES, st + 1)
	SaveUtil.write(SAVE_PATH, {"score": engine.score, "stage": st, "lives": maxi(1, engine.lives), "stars": engine.stars, "diff": engine.diff, "cp": engine.checkpoint_x if engine.state != "won" else 0.0, "all_scrolls": all_scrolls})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Score: %d") % int(d.get("score", 0))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_new_game(1)
		return
	engine.reset(int(d.get("diff", 1)))
	engine.score = int(d.get("score", 0))
	engine.stage = clampi(int(d.get("stage", 1)), 1, Engine_.STAGES)
	engine.lives = clampi(int(d.get("lives", 3)), 1, 3)
	engine.stars = maxi(0, int(d.get("stars", Engine_.START_STARS)))
	all_scrolls = bool(d.get("all_scrolls", false))
	engine.build_stage()
	if float(d.get("cp", 0.0)) > 200.0:
		engine.restart_at(float(d.get("cp", 0.0)))
	_begin()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

## The Landing's dojo theme (after the intro film).
func _menu_music() -> void:
	GameMusic.play(self, MENU_TRACK)

## genre: a Music Drop genre to prefer (owner 2026-11-15: calm Asian music on the road);
## apps whose Music has no library ignore it.
func _music(style: String, genre: String = "") -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		if genre != "" and "library" in m:
			m.play(style, self, 0, 1.5, genre)
		else:
			m.play(style, self, 0, 1.5)

# ---------- helps (STANDARDS §17) ----------

## A spare life (owner 2026-11-16): when the last heart goes, one of the Landing's three helps
## is spent automatically and the hero gets up again. No button, no choice.
func _auto_revive() -> bool:
	if not started or HomeKit.helps_left(HELP.ID) <= 0:
		return false
	HomeKit.use_help(HELP.ID)
	extra_lives = HomeKit.helps_left(HELP.ID)
	if home:
		home.refresh_helps()
	return true

# ---------- painted bosses, Hard colour, sword trail (owner 2026-11-20) ----------

## The pose for the boss's move: wind-up (the telegraph), strike, in the air, casting, hit.
func _boss_pose(b: Dictionary) -> String:
	if b.hit > 0.0:
		return "hit"
	match b.phase:
		"charge":
			return "wind" if b.t > 0.0 else "strike"
		"leap":
			return "wind" if b.t > 0.0 and b.y >= Engine_.GROUND - 2.0 else "air"
		"fan":
			return "cast"
	if boss_hold_t > 0.0:
		return boss_hold
	return "idle"

## Draws pose `pose` of act `act`'s boss standing on `feet`. Hard mode uses the colour
## version when there is one. False when the picture is missing (the drawn boss is used).
func _draw_pose(c: CanvasItem, feet: Vector2, k: float, act: int, pose: String, face: int, mod: Color) -> bool:
	var id: String = BOSS_IDS[clampi(act, 1, 6) - 1]
	var d: Dictionary = Poses.POSES.get(id, {})
	if not d.has(pose):
		return false
	var e: Array = d[pose]
	var hard: bool = engine.diff == 2 and bool(e[3])
	var key := "%s_%s%s" % [id, pose, "_hard" if hard else ""]
	if not boss_tex.has(key):
		var path := "res://games/ink_ninja/art/boss/%s.png" % key
		boss_tex[key] = load(path) if ResourceLoader.exists(path) else null
	var t: Texture2D = boss_tex[key]
	if t == null:
		return false
	var s: float = BOSS_H / Poses.FIG_PX * k
	var ax: float = e[0]
	var ay: float = e[1]
	if hard and e.size() > 4:
		ax = e[4]   # the owner's own colour picture: its own feet point
		ay = e[5]
	var bob := 1.0 + (0.015 * sin(anim_t * 2.6) if pose == "idle" else 0.0)
	var sz := Vector2(t.get_width() * s, t.get_height() * s * bob)
	var r := Rect2(feet - Vector2(ax * s, ay * s * bob), sz)
	if face != int(e[2]):
		r.position.x = feet.x + ax * s
		r.size.x = -sz.x
	# A soft paper halo behind the body, and the picture a shade darker, so the boss reads
	# through the mist and against the pagoda.
	var hw := BOSS_H * 0.75 * k
	c.draw_texture_rect(disc, Rect2(feet + Vector2(-hw, -BOSS_H * 1.15 * k), Vector2(hw * 2.0, BOSS_H * 1.25 * k)), false, Color(pal.paper, 0.35 * mod.a))
	c.draw_texture_rect(t, r, false, Color(mod.r * 0.82, mod.g * 0.82, mod.b * 0.82, mod.a))
	return true

func _boss_fx_tick(delta: float) -> void:
	boss_hold_t = maxf(0.0, boss_hold_t - delta)
	if not corpse.is_empty():
		corpse.t += delta
	for r in rainbow:
		r[0] += r[1] * delta
		r[1] *= maxf(0.0, 1.0 - 1.8 * delta)
		r[2] -= delta
	rainbow = rainbow.filter(_alive)
	for bt in blade_trail:
		bt[2] += delta
	blade_trail = blade_trail.filter(_trail_alive)
	var b: Dictionary = engine.boss
	if b.is_empty() or b.hp <= 0:
		return
	var third := clampi(int(ceil(float(b.hp) / float(b.max) * 3.0)), 0, 3)
	if third < boss_third:
		boss_hold = "stagger"
		boss_hold_t = 0.7
	boss_third = third
	if engine.diff == 2 and rainbow.size() < 240:
		# Hard: colour wisps always rise round the boss; a charge leaves a stream behind it.
		var charging: bool = b.phase == "charge" and b.t <= 0.0
		for i in (3 if charging else 1):
			_rainbow_puff(Vector2(b.x + randf_range(-70, 70), b.y - randf_range(0, 150)),
				Vector2(-b.vx * 0.3 + randf_range(-40, 40), randf_range(-90, -20)), randf_range(0.6, 1.2), randf_range(14, 30))

func _alive(r: Array) -> bool:
	return r[2] > 0.0

func _trail_alive(t: Array) -> bool:
	return t[2] < TRAIL_T

func _rainbow_puff(p: Vector2, v: Vector2, life: float, size: float) -> void:
	rainbow.append([p, v, life, life, fposmod(anim_t * 0.35 + randf() * 0.35, 1.0), size])

## Hard mode: each boss move bursts in vivid colour (owner 2026-11-20, his 5hard / 6hard pictures).
func _hard_fx(e: String) -> void:
	var b: Dictionary = engine.boss
	match e:
		"bosshit":
			for i in 10:
				_rainbow_puff(Vector2(b.x, b.y - 80.0), Vector2.RIGHT.rotated(randf() * TAU) * randf_range(120, 380), randf_range(0.3, 0.6), randf_range(8, 16))
		"bossfan":
			for i in 26:
				_rainbow_puff(Vector2(b.x + b.face * 40.0, b.y - 80.0), Vector2(b.face * randf_range(60, 420), randf_range(-260, 160)), randf_range(0.5, 1.0), randf_range(12, 26))
		"bossland":
			for i in 40:
				var sd := -1.0 if i % 2 == 0 else 1.0
				_rainbow_puff(Vector2(b.x, b.y - 8.0), Vector2(sd * randf_range(150, 640), randf_range(-140, -10)), randf_range(0.5, 1.0), randf_range(14, 30))
		"bosskill":
			for i in 90:
				_rainbow_puff(Vector2(b.x + randf_range(-40, 40), b.y - randf_range(20, 140)), Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80, 520), randf_range(0.8, 1.8), randf_range(14, 34))

func _draw_rainbow(c: CanvasItem, o: Vector2, k: float) -> void:
	for r in rainbow:
		var t: float = 1.0 - r[2] / r[3]
		var rad: float = r[5] * (0.6 + t * 1.1) * k
		var col := Color.from_hsv(fposmod(r[4] + t * 0.15, 1.0), 0.9, 1.0, 0.8 * (1.0 - t))
		c.draw_texture_rect(disc, Rect2(o + r[0] * k - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false, col)

## Hard mode boss shot: a glowing colour orb with a short tail.
func _rainbow_shot(c: CanvasItem, p: Vector2, v: Vector2, k: float) -> void:
	var dir := v.normalized()
	var hue := fposmod(anim_t * 1.2 + p.x * 0.002, 1.0)
	for i in range(4, 0, -1):
		var q := p - dir * i * 12.0 * k
		var rr := (14.0 - i * 2.0) * k
		c.draw_texture_rect(disc, Rect2(q - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color.from_hsv(fposmod(hue + i * 0.12, 1.0), 0.95, 1.0, 0.5 - i * 0.08))
	c.draw_texture_rect(disc, Rect2(p - Vector2(16, 16) * k, Vector2(32, 32) * k), false, Color.from_hsv(hue, 0.9, 1.0, 0.95))
	c.draw_texture_rect(disc, Rect2(p - Vector2(6, 6) * k, Vector2(12, 12) * k), false, Color(1, 1, 1, 0.95))

## Owner 2026-11-20: the silver and golden swords leave a soft trail. Kept relative to the
## hero's feet (it follows the swing, not the run): a few faint blade sweeps and a glowing
## tip line, all plain lines (cheap).
func _blade_trail(c: CanvasItem, hand: Vector2, tip: Vector2, k: float) -> void:
	if k <= 0.0:
		return
	if blade_trail.is_empty() or blade_trail[-1][2] > 0.0:
		blade_trail.append([(hand - hero_feet) / k, (tip - hero_feet) / k, 0.0])
	var col := Color(1.0, 0.8, 0.32) if engine.gold() else Color(0.85, 0.92, 1.0)
	for i in range(1, blade_trail.size()):
		var a0: Array = blade_trail[i - 1]
		var a1: Array = blade_trail[i]
		var fade: float = 1.0 - a1[2] / TRAIL_T
		var t0: Vector2 = hero_feet + a0[1] * k
		var t1: Vector2 = hero_feet + a1[1] * k
		if t0.distance_to(t1) < 1.5 * k:
			continue
		var m1: Vector2 = hero_feet + (a1[0] as Vector2).lerp(a1[1], 0.45) * k
		c.draw_line(m1, t1, Color(col, 0.16 * fade), 6.0 * k)
		c.draw_line(t0, t1, Color(col, 0.22 * fade), 12.0 * k)
		c.draw_line(t0, t1, Color(col, 0.55 * fade), 4.0 * k)

# ---------- intro film (owner 2026-11-20) ----------

## Plays the intro film full screen over the Landing (16:9, black bars), then `then`. Missing film = straight on.
func _play_intro(then: Callable) -> void:
	var stream = load(INTRO_PATH) if ResourceLoader.exists(INTRO_PATH) else null
	if stream == null or not ClassDB.class_exists("VideoStreamPlayer"):
		then.call()
		return
	intro_then = then
	var m = get_node_or_null("/root/Music")   # the hub's music stops; the Landing's starts after the film
	if m and m.has_method("stop"):
		m.stop(0.4)
	intro = ColorRect.new()
	(intro as ColorRect).color = Color.BLACK
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro.mouse_filter = Control.MOUSE_FILTER_STOP
	intro.process_mode = Node.PROCESS_MODE_ALWAYS   # the Landing pauses the tree: the film must keep playing
	intro.gui_input.connect(_on_intro_input)
	var ar := AspectRatioContainer.new()
	ar.ratio = 16.0 / 9.0
	ar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro.add_child(ar)
	var vp := VideoStreamPlayer.new()
	vp.stream = stream
	vp.expand = true
	vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.finished.connect(_intro_done)
	ar.add_child(vp)
	var skip := Button.new()
	skip.text = tr("Skip") + "  ›"
	skip.add_theme_font_size_override("font_size", 26)
	skip.modulate = Color(1, 1, 1, 0.75)
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.position -= Vector2(170, 90)
	skip.pressed.connect(_intro_done)
	intro.add_child(skip)
	add_child(intro)
	vp.play()

## Phones send a tap twice (touch + emulated mouse): only the mouse press ends the film.
func _on_intro_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_intro_done()

func _intro_done() -> void:
	if intro == null:
		return
	intro.queue_free()
	intro = null
	var c := intro_then
	intro_then = Callable()
	if c.is_valid():
		c.call()
