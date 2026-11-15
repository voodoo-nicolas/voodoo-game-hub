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
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/ink_ninja/ink_ninja_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://ink_ninja_save.json"
const Story = preload("res://scripts/games/ink_ninja/ink_ninja_story.gd")
const Goals = preload("res://scripts/games/ink_ninja/ink_ninja_goals.gd")
const Cutscene_ = preload("res://scripts/games/ink_ninja/cutscene.gd")
const PAPER_SHADER := preload("res://scripts/games/ink_ninja/ink_ninja_paper.gdshader")
const DIFF_NAMES := ["Easy", "Normal", "Hard"]
const PAUSE_AFTER := 1.8

## Two looks, both pure greyscale: Classic = black ink on paper, Voodoo = white ink on night.
## Owner round 3 (2026-11-15): a watercolour wash. Still black, white and grey, but with faint
## hues: a warm paper, blue-grey far hills, a slight blue for water, a faint red mark where a
## blow lands (`water`, `red`, `tint_far`, `tint_mid`, `haze` below).
const WASH := {
	"classic": {"paper": Color("efe8d8"), "paper2": Color("d6d4c8"), "far": Color("aeb6b9"), "mid": Color("858c86"), "moon": Color("f8efdc"), "fog": Color("eef0ee"),
		"water": Color(0.2, 0.45, 0.82, 0.62), "surf": Color(0.12, 0.35, 0.75, 0.9), "red": Color(0.8, 0.05, 0.04), "haze": Color("e4e7e8")},
	"voodoo": {"paper": Color("08090c"), "paper2": Color("181a1f"), "far": Color("262b33"), "mid": Color("3f4544"), "moon": Color("dcd6c8"), "fog": Color("566068"),
		"water": Color(0.1, 0.25, 0.6, 0.7), "surf": Color(0.35, 0.6, 0.95, 0.85), "red": Color(0.85, 0.1, 0.08), "haze": Color("3a4048")},
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
	"thrust": "New: Thrust lunges forward and runs your blade through a foe.  (Keyboard: L / Shift)",
}
var q := {"jump": false, "slash": false, "throw": false, "dash": false}
var after := 0.0
var banner := ""
var anim_t := 0.0
var shake := 0.0
var splats: Array = []   # [pos, vel, life, size] flying drops
var stains: Array = []   # [world pos, size, alpha] ink left on the ground
var disc: Texture2D
var pines_far: Texture2D
var pines_mid: Texture2D
var fog_tex: Texture2D
var smoke: Array = []   # smoke puffs (_puff)
var mist: Array = []    # drifting wisps: [x 0..1, world y, speed, width, phase]
var blot: Texture2D      # an irregular ink blot for splashes and stains
var goals                # Goals (daily + weekly objectives)
var card_text := []      # the chapter card on screen: [title, text, objective] (empty = none)
var card_t := 0.0
var prologue := false    # stage 1 of a new game shows the prologue first
var paper: ColorRect     # paper grain + vignette shader over the field
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
	disc = _make_disc()
	blot = _make_blot()
	goals = Goals.new()
	pines_far = _make_pines(11, 34, 140.0, 260.0)
	pines_mid = _make_pines(23, 22, 200.0, 340.0)
	fog_tex = _make_fog()
	for i in 7:
		mist.append([randf() * 1.6 - 0.3, randf_range(380.0, 560.0), randf_range(0.006, 0.02), randf_range(260.0, 520.0), randf() * TAU])
	goals.load_data(Goals.today_num(), Goals.week_num())
	_build_ui()
	_hud_colors()
	_paper_params()
	engine.reset(1)
	_music("calm", "asian")

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
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.clip_contents = true
	field.draw.connect(_draw_field)
	add_child(field)
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
	for spec in [["◀", "left"], ["▶", "right"], ["▼", "down"], ["⤒", "jump"], ["⚔", "slash"], ["»", "dash"], ["✴", "throw"], ["⛨", "block"]]:
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
		modes.append({"text": ["Easy", "Normal", "Hard"][i], "row": "diff",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_game.bind(i)})
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S1 Ghost; greys only, like the game.
		"landing": "ghost",
		"landing_style": MenuStyles,
		"title_font": "res://games/ink_ninja/title.ttf",
		"title_colors": [Color("f2f2f2"), Color("9a9a9a"), Color("d0d0d0")],
		"landing_colors": [Color("0a0a0a"), Color("2a2a2a")],
		"menu_color": Color("e0e0e0"),
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": Color("d8d8d8"),
		"solo_heading": "Story",
		"more": [["Objectives", Color("8a8a8a"), _show_goals]],
		"subtitle": "Ten stages of ink and steel. One ninja.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [
			{"text": "❤ Heal", "how": "Fills your hearts back up, right now.", "action": _help_heal},
			{"text": "✴ Stars", "how": "Gives you 5 more throwing stars.", "action": _help_stars},
		],
		"board": "Best score",
	})
	add_child(home)
	if info:
		add_child(info)

# ---------- controls ----------

const PAD_PATH := "res://scripts/common/pad/pad_controller.gd"
var touch_pad: Control = null

func _add_pad() -> void:
	touch_pad = load(PAD_PATH).new()
	touch_pad.layout_override = "stick_4"
	touch_pad.prefs_override = {"skin": "mono"}   # greyscale like the game
	touch_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(touch_pad)
	for part in ["pause", "info"]:
		touch_pad.set_hidden(part, true)
	# Owner 2026-11-15: the four buttons are Swing, Thrust, Star and Block; jumping is on
	# the stick (push up) or the keyboard. Locked moves stay hidden until they unlock.
	touch_pad.set_state("a", {"sub": tr("Swing")})
	touch_pad.set_state("b", {"sub": tr("Thrust")})
	touch_pad.set_state("x", {"sub": tr("Star")})
	touch_pad.set_state("y", {"sub": tr("Block")})
	touch_pad.button_pressed.connect(_on_pad_button)

## Show only the buttons this stage allows; a newly unlocked one pops in.
func _pad_unlocks(reveal: bool) -> void:
	if not touch_pad:
		return
	for pair in [["y", "block"], ["x", "star"], ["b", "thrust"]]:
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
			KEY_L, KEY_SHIFT:
				if event.pressed:
					q.dash = true
			KEY_I, KEY_CTRL:
				key_b = event.pressed
			KEY_ESCAPE:
				if event.pressed and started:
					_on_pause()

# ---------- flow ----------

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
	# The chapter card stops play until any button / tap (or 6 s).
	var ch: Array = Story.CHAPTERS[engine.stage - 1]
	card_text = [tr("Chapter %d") % engine.stage + " · " + tr(ch[0]), (tr(Story.PROLOGUE) + "\n\n" if prologue else "") + tr(ch[1]), tr(ch[2])]
	card_t = 6.0 if not prologue else 9.0
	prologue = false
	SoundLib.play(self, "rpg/book_flip", -6.0)
	_music("calm", "asian")
	_pad_unlocks(engine.stage == 2 or engine.stage == 3 or engine.stage == 4)
	splats.clear()
	stains.clear()
	end_dialog.visible = false
	_update_hud()

func _update_hud() -> void:
	hud.text = "♥".repeat(maxi(0, engine.hp)) + "♡".repeat(maxi(0, Engine_.MAX_HP - engine.hp)) + "   " + tr("Stars %d") % engine.stars + "   " + tr("Lives %d") % engine.lives
	score_label.text = str(engine.score)

func _process(delta: float) -> void:
	anim_t += delta
	if touch_pad:
		touch_pad.visible = started and not end_dialog.visible and not cut_on
	if not started or cut_on:
		return
	delta = minf(delta, 0.05)
	shake = maxf(0.0, shake - delta * 30.0)
	_smoke_tick(delta)
	for s in splats:
		s[0] += s[1] * delta
		s[1].y += 1400.0 * delta
		s[2] -= delta
		var sg: float = engine.ground_y(s[0].x)
		if s[2] <= 0.0 and s[0].y > sg - 20 and s[0].y < sg + 40 and stains.size() < 160 and engine.water_depth(s[0].x) <= 0.0:
			stains.append([Vector2(s[0].x, sg + 2), s[3] * 1.4, 0.55, s[4]])
	splats = splats.filter(func(s): return s[2] > 0.0)
	if not card_text.is_empty():
		card_t -= delta
		var any: bool = q.jump or q.slash or q.throw or q.dash
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
	var ev: Array = engine.step(delta, m, q.jump, q.slash, q.throw, q.dash, dn, blk)
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

func _event(e: String) -> void:
	if e.begins_with("ink:") or e.begins_with("red:"):
		var p := e.split(":")
		_splash(Vector2(float(p[1]), float(p[2])), e.begins_with("red:"))
		return
	match e:
		"jump", "walljump":
			SoundLib.play(self, "rpg/cloth", -4.0, "game", 1.15)   # a cloth whip, not the arcade boing (owner 2026-11-15)
		"dash":
			SoundLib.play(self, "rpg/draw_knife", -3.0, "game", 0.85)
			_puff(Vector2(engine.px, engine.py - 10), 6, 18.0, 90.0)
		"slash":
			SoundLib.play(self, "rpg/draw_knife", -5.0, "game", 1.2)   # a blade whoosh (owner 2026-11-15)
		"jab":
			SoundLib.play(self, "rpg/knife_slice", -6.0, "game", 1.3)
		"block":
			SoundLib.play(self, "impact/metal_light", -4.0)
			_goal("parries")
		"throw":
			_sfx("shoot")
		"parry":
			SoundLib.play(self, "impact/metal_heavy", -6.0)
			_goal("parries")
			if info:
				info.add("Stars parried")
		"kill":
			SoundLib.play(self, "rpg/chop", -4.0)
			_goal("kills")
			if info:
				info.add("Ninjas defeated")
		"hit", "bosshit":
			SoundLib.play(self, "impact/punch_medium", -6.0)
		"checkpoint":
			SoundLib.play(self, "impact/bell_heavy", -10.0, "game", 1.4)
			_puff(Vector2(engine.px, engine.py - 60), 5, 14.0, 60.0)
			var lantern: int = engine.checkpoints.find(engine.checkpoint_x) + 1
			_cutscene_then(Cutscene_.for_slot("lantern:%d:%d" % [engine.stage, lantern]), _noop)
		"scroll":
			SoundLib.play(self, "rpg/book_flip", -4.0)
			_goal("scrolls")
		"starkill":
			_goal("star_kills")
		"combo5":
			SoundLib.play(self, "reward/coin_plingy", -6.0)
			_goal("combo5")
		"land":
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
			_sfx("lose")
			shake = 10.0
		"slam":
			shake = 14.0
			_puff(Vector2(engine.boss.x, engine.boss.y - 6), 14, 30.0, 220.0)
			SoundLib.play(self, "impact/wood_heavy", -4.0)
		"boss":
			banner = tr(engine.boss_name())
			after = -1.6
			SoundLib.play(self, "impact/bell_heavy", -4.0)
			_music("techno")
		"die":
			banner = tr("Fallen!") if engine.state == "dead" else tr("Game over!")
			after = PAUSE_AFTER
			SoundLib.play(self, "jingles/lose_failed", -6.0)
		"win":
			SoundLib.play(self, "jingles/win_victory", -4.0)
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
			if not engine.scrolls.is_empty():
				all_scrolls = false
			_goal("stages")
			if engine.hits_taken == 0:
				_goal("nohit")
			banner = tr("Stage cleared!")
			after = PAUSE_AFTER + 0.6
			if info:
				info.high("Highest stage", engine.stage)

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
func _splash(p: Vector2, red: bool = false) -> void:
	_puff(p, 3, 16.0, 60.0)
	for i in (10 if red else 16):
		var v := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(120, 520) + Vector2(0, -220)
		splats.append([p, v, randf_range(0.35, 0.8), randf_range(5.0, 14.0) * (0.8 if red else 1.0), red])
	var sx := p.x + randf_range(-30, 30)
	if stains.size() < 160 and engine.water_depth(sx) <= 0.0:
		stains.append([Vector2(sx, engine.ground_y(sx) + 2), randf_range(22, 40), 0.7, red])

func _game_over(won: bool) -> void:
	started = false
	SaveUtil.delete(SAVE_PATH)
	var msg := (tr("You mastered the ink!") + "\n" + tr(Story.EPILOGUE) if won else tr("Game over!")) + "\n" + tr("Score: %d") % engine.score + "   ·   " + tr("Stage %d") % engine.stage
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
	var bands := 10
	for i in bands:
		c.draw_rect(Rect2(0, sz.y * i / bands, sz.x, sz.y / bands + 1), pal.paper.lerp(pal.paper2, float(i) / bands))
	# Misty pine forest (owner's references, 2026-11-14): far and mid pine layers fading into
	# fog, tall dark trunks in front, each scrolling slower than the ground.
	c.draw_texture_rect(disc, Rect2(Vector2(sz.x * 0.72, sz.y * 0.06) - Vector2(90, 90) * k, Vector2(180, 180) * k), false, Color(pal.moon, 0.55))
	_pine_layer(c, pines_far, cam * 0.12, k, 440.0, pal.far)
	_fog(c, k, 300.0, 470.0, 0.85)
	_pine_layer(c, pines_mid, cam * 0.3, k, 540.0, pal.mid)
	_fog(c, k, 420.0, 560.0, 0.7)
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
		var tower: bool = s.size.y >= 30.0
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
		c.draw_texture_rect(blot, Rect2(p - Vector2(st[1], st[1] * 0.3) * k, Vector2(st[1] * 2, st[1] * 0.6) * k), false, Color(pal.red, st[2] * 0.8) if st[3] else Color(pal.near, st[2]))
	# Arena gate.
	if engine.locked:
		var gx: float = o.x + engine.arena_x * k
		for i in 4:
			c.draw_line(Vector2(gx + (8 + i * 9) * k, 0), Vector2(gx + (8 + i * 9) * k, Engine_.GROUND * k), pal.near, 4.0 * k)
	for cpx in engine.checkpoints:
		_lantern(c, o + Vector2(cpx, engine.ground_y(cpx)) * k, k, engine.checkpoint_x >= cpx)
	for s in engine.scrolls:
		_scroll(c, o + s * k, k)
	for f in engine.foes:
		_shadow(c, o, f.x, f.y, k, 26.0)
	if not engine.boss.is_empty() and engine.boss.hp > 0:
		_shadow(c, o, engine.boss.x, engine.boss.y, k, 40.0)
	_shadow(c, o, engine.px, engine.py, k, 24.0)
	for f in engine.foes:
		_figure(c, o + Vector2(f.x, f.y) * k, k, f.face, f.kind, f.hit > 0.0, f.get("atk", 0.0) > 0.0, false, anim_t * 6.0 + f.id)
	if not engine.boss.is_empty() and engine.boss.hp > 0:
		var b: Dictionary = engine.boss
		var tele: bool = b.phase != "idle" and b.t > 0.0
		_figure(c, o + Vector2(b.x, b.y) * k, k * 1.5, b.face, "boss%d" % b.kind, b.hit > 0.0, tele, false, anim_t * 4.0)
	for s in engine.shots:
		_star(c, o + Vector2(s.x, s.y) * k, k, s.mine)
	if engine.hurt_t <= 0.0 or fmod(anim_t, 0.16) < 0.08:
		_ninja(c, o + Vector2(engine.px, engine.py) * k, k)
	for s in splats:
		var p: Vector2 = o + s[0] * k
		var r: float = s[3] * k
		c.draw_texture_rect(blot, Rect2(p - Vector2(r, r), Vector2(r, r) * 2), false, Color(pal.red, 0.95) if s[4] else pal.ink)
	_draw_water_front(c, o, k)
	_draw_breath(c, o, k)
	_draw_smoke(c, o, k)
	_draw_mist(c, sz, k)
	_draw_haze(c, o, sz, k)
	_hud_draw(c, sz, k)

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
	var grass := PackedVector2Array()
	var strata := PackedVector2Array()
	var stones := PackedVector2Array()
	x = x0
	while x <= x1:
		var gy: float = engine.ground_y(x)
		if engine.water_depth(x) <= 0.0:
			var h := 6.0 + fmod(absf(x) * 0.731, 7.0)
			var lean := fmod(absf(x) * 0.37, 6.0) - 3.0
			grass.append(o + Vector2(x, gy) * k)
			grass.append(o + Vector2(x + lean, gy - h) * k)
			grass.append(o + Vector2(x + 7, gy) * k)
			grass.append(o + Vector2(x + 7 + lean * 0.6, gy - h * 0.7) * k)
		for d in [22.0, 48.0, 84.0]:
			if fmod(absf(x) + d * 3.0, 60.0) < 40.0:
				var a := o + Vector2(x, engine.ground_y(x) + d) * k
				var b := o + Vector2(x + step, engine.ground_y(x + step) + d) * k
				strata.append(a)
				strata.append(b)
		var sh := fmod(absf(x) * 1.37, 97.0)
		if sh < 30.0:
			var sp := o + Vector2(x + sh * 0.5, gy + 30.0 + sh * 2.0) * k
			stones.append(sp)
			stones.append(sp + Vector2(6.0 + sh * 0.2, 0) * k)
		x += step
	c.draw_multiline(grass, pal.ink, 2.0 * k)
	c.draw_multiline(strata, Color(pal.near, 0.55), 2.0 * k)
	c.draw_multiline(stones, Color(pal.mid, 0.6), 4.0 * k)

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
		_poly(c, _water_poly(o, k, w), pal.water)

func _draw_water_front(c: CanvasItem, o: Vector2, k: float) -> void:
	for w in engine.pools:
		var a: Vector2 = o + Vector2(w.x0, w.level) * k
		var bx: float = o.x + w.x1 * k
		if bx < 0 or a.x > field.size.x:
			continue
		_poly(c, _water_poly(o, k, w), Color(pal.water, pal.water.a * 0.55))
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
	var col: Color = pal.near
	c.draw_rect(Rect2(base + Vector2(-14, -10) * k, Vector2(28, 10) * k), col)
	c.draw_rect(Rect2(base + Vector2(-5, -46) * k, Vector2(10, 36) * k), col)
	c.draw_rect(Rect2(base + Vector2(-13, -66) * k, Vector2(26, 20) * k), col)
	_poly(c, PackedVector2Array([base + Vector2(-22, -66) * k, base + Vector2(22, -66) * k, base + Vector2(0, -84) * k]), col)
	if lit:
		var glow := 0.55 + 0.15 * sin(anim_t * 3.0)
		c.draw_texture_rect(disc, Rect2(base + Vector2(-30, -86) * k, Vector2(60, 60) * k), false, Color(1.0, 0.85, 0.55, glow * 0.45))
		c.draw_rect(Rect2(base + Vector2(-7, -62) * k, Vector2(14, 12) * k), Color(1.0, 0.82, 0.5, glow))
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
		for yy in int(th):
			var t := float(yy) / th
			var half := (2.0 + t * hw) * (0.5 + 0.5 * fmod(t * tiers, 1.0))
			var y := base - int(th) + yy
			for dx in [0, -w, w]:
				var x0: int = int(cx - half) + dx
				var x1: int = int(cx + half) + dx
				x0 = maxi(x0, 0)
				x1 = mini(x1, w)
				if x1 > x0 and y >= 0:
					img.fill_rect(Rect2i(x0, y, x1 - x0, 1), Color.WHITE)
	img.fill_rect(Rect2i(0, base, w, h - base), Color.WHITE)
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
func _ink_body(c: CanvasItem, j: Dictionary, k: float, f: int, col: Color, bulk: float, tails: bool, phase: float) -> void:
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
		for t in 2:
			var pts := []
			var start: Vector2 = j.head + Vector2(-f * 9, -5 + t * 3) * k
			for i in 7:
				pts.append(start + Vector2(-f * i * 13.0, sin(phase - i * 0.8 + t * 1.3) * i * 1.8 - i * 1.5 + t * i * 2.0) * k)
			_ribbon(c, pts, 6.0 * k, 1.0 * k, col)
		var sp := []
		var s0: Vector2 = j.hip + Vector2(-f * 8, -6) * k
		for i in 5:
			sp.append(s0 + Vector2(-f * i * 9.0, i * 3.0 + sin(phase * 0.8 - i) * i) * k)
		_ribbon(c, sp, 5.0 * k, 1.0 * k, col)

## A katana: ink outline with a pale edge so it reads on dark ground too.
func _katana(c: CanvasItem, hand: Vector2, tip: Vector2, k: float) -> void:
	c.draw_line(hand, tip, pal.ink, 4.0 * k)
	c.draw_line(hand.lerp(tip, 0.12), tip, pal.moon, 1.5 * k)
	var n := (tip - hand).normalized().orthogonal() * 6.0 * k
	c.draw_line(hand.lerp(tip, 0.1) - n, hand.lerp(tip, 0.1) + n, pal.ink, 3.0 * k)   # guard

## The hero: brush-stroke ninja, long headband tails, katana held ready; a slash leaves a
## sweeping ink crescent (owner's references).
func _ninja(c: CanvasItem, feet: Vector2, k: float) -> void:
	var f: int = engine.facing
	var ink: Color = pal.ink
	var running: bool = engine.on_ground and absf(engine.vx) > 40.0
	var j := _pose(feet, k, f, engine.run_t * 14.0, running, engine.crouch, not engine.on_ground)
	if engine.dash_t > 0.0:
		for i in 4:
			c.draw_line(j.hip - Vector2(f * (30 + i * 22), i * 7 - 10) * k, j.hip - Vector2(f * (70 + i * 22), i * 7 - 10) * k, Color(pal.mid, 0.6), (5 - i) * k)
	_ink_body(c, j, k, f, ink, 1.0, true, anim_t * 10.0 + (engine.vx * 0.01))
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
		_katana(c, hand, tip, k)
		for i in 3:
			var yy := (i - 1) * 7.0 * k
			c.draw_line(tip + Vector2(-f * (20 + i * 12) * k, yy), tip + Vector2(-f * (70 + i * 16) * k, yy), Color(ink, 0.35 * reach), 2.0 * k)
	elif engine.slash_t > 0.0:
		var t: float = 1.0 - engine.slash_t / Engine_.SLASH_T
		var a := lerpf(-1.4, 1.2, t)
		var hand := neck + Vector2(f * 20, 4).rotated(a * f) * k
		_brush(c, neck, hand, 6.0 * k, ink)
		_katana(c, hand, hand + Vector2(f * 74, 0).rotated(a * f) * k, k)
		# The cut: a thick crescent that sweeps after the blade and thins at its tail.
		var pts := []
		for i in 12:
			var aa := lerpf(-1.4, a, float(i) / 11.0)
			pts.append(neck + Vector2(f * 84, 0).rotated(aa * f) * k)
		_ribbon(c, pts, 1.0 * k, 16.0 * k, Color(ink, 0.85))
	elif engine.blocking:
		# Guard: blade upright in front of the face.
		var hand := neck + Vector2(f * 22, 6) * k
		_brush(c, neck, hand, 6.0 * k, ink)
		_katana(c, hand + Vector2(0, 24) * k, hand + Vector2(f * 6, -58) * k, k)
	else:
		# At rest and running the sword trails at the side, point behind (owner 2026-11-15).
		var hand: Vector2 = j.hip + Vector2(f * 6, -6) * k
		_brush(c, neck, hand, 6.0 * k, ink)
		var tip: Vector2 = hand + (Vector2(-f * 62, 14) if not engine.crouch else Vector2(-f * 64, 2)) * k
		_katana(c, hand, tip, k)

## Foes and bosses: the same brush figure in a lighter ink, bulkier for brutes and bosses.
func _figure(c: CanvasItem, feet: Vector2, k: float, f: int, kind: String, flash: bool, windup: bool, _x: bool, t: float) -> void:
	var ink: Color = pal.mid if flash else pal.near.lerp(pal.ink, 0.45)
	var bulk := 1.35 if kind == "brute" or kind == "boss0" or kind == "boss3" else 1.0
	var j := _pose(feet, k, f, t, true, false, false)
	_ink_body(c, j, k, f, ink, bulk, kind.begins_with("boss") or kind == "blade", t * 1.3)
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
	for m in mist:
		m[0] += m[2] * delta
		if m[0] > 1.3:
			m[0] -= 1.6

func _draw_smoke(c: CanvasItem, o: Vector2, k: float) -> void:
	for s in smoke:
		var t: float = 1.0 - s[2] / s[3]
		var r: float = s[4] * (0.6 + t * 1.2) * k
		c.draw_texture_rect(disc, Rect2(o + s[0] * k - Vector2(r, r), Vector2(r, r) * 2), false, Color(pal.smoke, 0.45 * (1.0 - t)))

## Mist wisps drifting across the field in front of everything (screen space, slow).
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

func _scroll(c: CanvasItem, p: Vector2, k: float) -> void:
	var bob := sin(anim_t * 3.0 + p.x) * 4.0 * k
	var r := Rect2(p + Vector2(-14, -9 + bob / k) * k, Vector2(28, 18) * k)
	c.draw_rect(r, pal.moon)
	c.draw_rect(r, pal.ink, false, 2.0 * k)
	c.draw_line(r.position + Vector2(6, 6) * k, r.position + Vector2(22, 6) * k, pal.mid, 2.0 * k)
	c.draw_line(r.position + Vector2(6, 11) * k, r.position + Vector2(18, 11) * k, pal.mid, 2.0 * k)

func _hud_draw(c: CanvasItem, sz: Vector2, k: float) -> void:
	var font := ThemeDB.fallback_font
	# Stage progress: a brush line with the ninja's dot.
	var y := 96.0 * k
	var x0 := sz.x * 0.3
	var x1 := sz.x * 0.7
	c.draw_line(Vector2(x0, y), Vector2(x1, y), Color(pal.mid, 0.6), 3.0 * k)
	var px := lerpf(x0, x1, engine.progress())
	c.draw_texture_rect(disc, Rect2(Vector2(px, y) - Vector2(7, 7) * k, Vector2(14, 14) * k), false, pal.ink)
	c.draw_string(font, Vector2(x0, y - 10 * k), tr("Stage %d") % engine.stage, HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, int(20 * k), pal.near)
	if not engine.boss.is_empty() and engine.boss.hp > 0:
		var w := sz.x * 0.5
		var bx := (sz.x - w) / 2.0
		var by := sz.y - 50.0 * k
		c.draw_rect(Rect2(bx, by, w, 14 * k), Color(pal.far, 0.8))
		c.draw_rect(Rect2(bx, by, w * float(engine.boss.hp) / float(engine.boss.max), 14 * k), pal.paper)   # on the ink ground: paper colour
		c.draw_string(font, Vector2(bx, by - 8 * k), tr(engine.boss_name()), HORIZONTAL_ALIGNMENT_CENTER, w, int(22 * k), pal.paper)
	if banner != "":
		var fs := int(64 * k)
		var tp := Vector2(0, sz.y * 0.42)
		c.draw_string_outline(font, tp, banner, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, int(10 * k), pal.paper)
		c.draw_string(font, tp, banner, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, pal.ink)
	# Story objective under the progress line.
	var obj: String = tr("Defeat %s") % tr(engine.boss_name()) if engine.locked else tr(Story.CHAPTERS[engine.stage - 1][2])
	c.draw_string(font, Vector2(x0, y + 26 * k), "▸ " + obj, HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, int(18 * k), pal.near)
	var tip: String = engine.tip()
	if tip != "" and card_text.is_empty():
		var ty := y + 66 * k
		var tw := sz.x * 0.62
		c.draw_rect(Rect2((sz.x - tw) / 2.0, ty - 26 * k, tw, 38 * k), Color(pal.paper, 0.75))
		c.draw_string(font, Vector2((sz.x - tw) / 2.0, ty), tr(TIPS[tip]), HORIZONTAL_ALIGNMENT_CENTER, tw, int(19 * k), pal.ink)
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
		[tr("Story"), tr("Chapter %d") % _story_stage() + " · " + tr(ch[0]), tr(ch[2]), tr("Ten chapters, one stolen brush")],
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
	return "" if d == null else tr("Score: %d") % int(d.get("score", 0)) + "   ·   " + tr("Stage %d") % int(d.get("stage", 1))

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

func _help_heal() -> bool:
	if not started or engine.state != "play" or engine.hp >= Engine_.MAX_HP:
		return false
	engine.hp = Engine_.MAX_HP
	_update_hud()
	_sfx("powerup")
	return true

func _help_stars() -> bool:
	if not started or engine.state != "play":
		return false
	engine.stars += 5
	_update_hud()
	_sfx("powerup")
	return true
