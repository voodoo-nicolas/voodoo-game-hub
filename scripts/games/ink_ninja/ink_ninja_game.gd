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
const DIFF_NAMES := ["Easy", "Normal", "Hard"]
const PAUSE_AFTER := 1.8

## Two looks, both pure greyscale: Classic = black ink on paper, Voodoo = white ink on night.
const LOOKS := {
	"classic": {"paper": Color("ece6d8"), "paper2": Color("d8d0bf"), "ink": Color("111111"), "far": Color("b9b2a4"), "mid": Color("8e887d"), "near": Color("4a4743"), "moon": Color("f7f3ea")},
	"voodoo": {"paper": Color("08080a"), "paper2": Color("1a1a1d"), "ink": Color("f0f0f0"), "far": Color("2a2a2e"), "mid": Color("45454a"), "near": Color("707075"), "moon": Color("d9d9d9")},
}

var info = null
var home
var engine
var started := false
var skin := "classic"
var pal: Dictionary = LOOKS.classic
var move := 0.0
var key_l := false
var key_r := false
var q := {"jump": false, "slash": false, "throw": false, "dash": false}
var after := 0.0
var banner := ""
var anim_t := 0.0
var shake := 0.0
var splats: Array = []   # [pos, vel, life, size] flying drops
var stains: Array = []   # [world pos, size, alpha] ink left on the ground
var disc: Texture2D

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
	_build_ui()
	_hud_colors()
	engine.reset(1)
	_music("techno")

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

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	field = Control.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.clip_contents = true
	field.draw.connect(_draw_field)
	add_child(field)

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
	for spec in [["◀", "left"], ["▶", "right"], ["⤒", "jump"], ["⚔", "slash"], ["✴", "throw"], ["»", "dash"]]:
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
		"solo_heading": "Play",
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
	touch_pad.set_state("a", {"glyph": "jump", "sub": tr("Jump")})
	touch_pad.set_state("b", {"sub": tr("Slash")})
	touch_pad.set_state("x", {"sub": tr("Star")})
	touch_pad.set_state("y", {"sub": tr("Dash")})
	touch_pad.button_pressed.connect(_on_pad_button)

func _on_pad_button(id: String) -> void:
	match id:
		"a":
			q.jump = true
		"b":
			q.slash = true
		"x":
			q.throw = true
		"y":
			q.dash = true

func _hold(what: String, on: bool) -> void:
	match what:
		"left":
			key_l = on
		"right":
			key_r = on
		_:
			if on:
				q[what] = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				key_l = event.pressed
			KEY_RIGHT, KEY_D:
				key_r = event.pressed
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
			KEY_ESCAPE:
				if event.pressed and started:
					_on_pause()

# ---------- flow ----------

func _new_game(d: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset(d)
	_begin()

func _restart() -> void:
	_new_game(engine.diff)

func _begin() -> void:
	started = true
	after = 0.0
	banner = tr("Stage %d") % engine.stage
	after = -1.2   # negative = a short title card that does not stop play
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
		touch_pad.visible = started and not end_dialog.visible
	if not started:
		return
	delta = minf(delta, 0.05)
	shake = maxf(0.0, shake - delta * 30.0)
	for s in splats:
		s[0] += s[1] * delta
		s[1].y += 1400.0 * delta
		s[2] -= delta
		if s[2] <= 0.0 and s[0].y > Engine_.GROUND - 20 and s[0].y < Engine_.GROUND + 40 and stains.size() < 160:
			stains.append([Vector2(s[0].x, Engine_.GROUND + 2), s[3] * 1.4, 0.55])
	splats = splats.filter(func(s): return s[2] > 0.0)
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
	if touch_pad:
		m = touch_pad.get_vector("move").x
		if absf(m) < 0.25:
			m = 0.0
	m = clampf(m + (1.0 if key_r else 0.0) - (1.0 if key_l else 0.0), -1.0, 1.0)
	var ev: Array = engine.step(delta, m, q.jump, q.slash, q.throw, q.dash)
	for k in q:
		q[k] = false
	for e in ev:
		_event(e)
	if not ev.is_empty():
		_update_hud()
	field.queue_redraw()

func _event(e: String) -> void:
	if e.begins_with("ink:"):
		var p := e.split(":")
		_splash(Vector2(float(p[1]), float(p[2])))
		return
	match e:
		"jump", "walljump":
			_sfx("jump")
		"dash":
			_sfx("whoosh")
		"slash":
			SoundLib.play(self, "impact/metal_light", -12.0)
		"throw":
			_sfx("shoot")
		"parry":
			SoundLib.play(self, "impact/metal_heavy", -6.0)
			if info:
				info.add("Stars parried")
		"kill":
			SoundLib.play(self, "impact/punch_heavy", -6.0)
			if info:
				info.add("Ninjas defeated")
		"hit", "bosshit":
			SoundLib.play(self, "impact/punch_medium", -6.0)
		"scroll":
			_sfx("pickup")
		"hurt":
			_sfx("lose")
			shake = 10.0
		"slam":
			shake = 14.0
			SoundLib.play(self, "impact/wood_heavy", -4.0)
		"boss":
			banner = tr(engine.boss_name())
			after = -1.6
		"die":
			banner = tr("Fallen!") if engine.state == "dead" else tr("Game over!")
			after = PAUSE_AFTER
		"win":
			_sfx("win")
			banner = tr("%s defeated!") % tr(engine.boss_name())
			after = PAUSE_AFTER + 0.6
			if info:
				info.add("Bosses defeated")
				info.high("Highest stage", engine.stage)

func _after_pause() -> void:
	match engine.state:
		"dead":
			engine.retry()
			_begin()
		"won":
			engine.next_stage()
			if engine.state == "cleared":
				_game_over(true)
			else:
				_begin()
		"over":
			_game_over(false)

func _splash(p: Vector2) -> void:
	for i in 16:
		var v := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(120, 520) + Vector2(0, -220)
		splats.append([p, v, randf_range(0.35, 0.8), randf_range(5.0, 14.0)])
	if stains.size() < 160:
		stains.append([Vector2(p.x + randf_range(-30, 30), Engine_.GROUND + 2), randf_range(22, 40), 0.7])

func _game_over(won: bool) -> void:
	started = false
	SaveUtil.delete(SAVE_PATH)
	var msg := (tr("You mastered the ink!") if won else tr("Game over!")) + "\n" + tr("Score: %d") % engine.score + "   ·   " + tr("Stage %d") % engine.stage
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
	c.draw_texture_rect(disc, Rect2(Vector2(sz.x * 0.78, sz.y * 0.08) - Vector2(70, 70) * k, Vector2(140, 140) * k), false, pal.moon)
	# Three mountain layers, scrolling slower than the ground.
	_ridge(c, cam * 0.15, k, 330.0, 140.0, pal.far, 3)
	_ridge(c, cam * 0.35, k, 420.0, 110.0, pal.mid, 7)
	_bamboo(c, cam * 0.6, k)
	var o := Vector2(-cam * k, 0) + sh
	# Ground and ledges: solid ink with a dry-brush top edge.
	for s in engine.solids:
		var r := Rect2(o + s.position * k, s.size * k)
		if r.end.x < 0 or r.position.x > sz.x:
			continue
		c.draw_rect(r, pal.ink)
		var y := r.position.y
		var x := r.position.x
		while x < r.end.x:
			var w := minf(18.0 * k, r.end.x - x)
			c.draw_line(Vector2(x, y - 2 * k), Vector2(x + w, y - (2 + fmod(x * 0.37, 3.0)) * k), pal.ink, 2.0 * k)
			x += w
	for st in stains:
		var p: Vector2 = o + st[0] * k
		c.draw_texture_rect(disc, Rect2(p - Vector2(st[1], st[1] * 0.25) * k, Vector2(st[1] * 2, st[1] * 0.5) * k), false, Color(pal.near, st[2]))
	# Arena gate.
	if engine.locked:
		var gx: float = o.x + engine.arena_x * k
		for i in 4:
			c.draw_line(Vector2(gx + (8 + i * 9) * k, 0), Vector2(gx + (8 + i * 9) * k, Engine_.GROUND * k), pal.near, 4.0 * k)
	for s in engine.scrolls:
		_scroll(c, o + s * k, k)
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
		c.draw_texture_rect(disc, Rect2(p - Vector2(r, r), Vector2(r, r) * 2), false, pal.ink)
	_hud_draw(c, sz, k)

func _ridge(c: CanvasItem, off: float, k: float, base: float, amp: float, col: Color, seed_: int) -> void:
	var sz := field.size
	var pts := PackedVector2Array()
	var step := 60.0
	var x0 := -fmod(off, step)
	var i0 := int(floor(off / step))
	var n := int(sz.x / (step * k)) + 3
	for i in n:
		var wx := float(i0 + i)
		var h := sin(wx * 0.37 + seed_) * 0.5 + sin(wx * 0.11 + seed_ * 2.0) * 0.5
		pts.append(Vector2((x0 + i * step) * k, (base - h * amp) * k))
	pts.append(Vector2(pts[pts.size() - 1].x, sz.y))
	pts.append(Vector2(pts[0].x, sz.y))
	c.draw_colored_polygon(pts, col)

func _bamboo(c: CanvasItem, off: float, k: float) -> void:
	var sz := field.size
	var gap := 170.0
	var i0 := int(floor(off / gap))
	for i in int(sz.x / (gap * k)) + 2:
		var wx := float(i0 + i)
		var x := (wx * gap - off + sin(wx * 3.1) * 50.0) * k
		var top := (120.0 + absf(sin(wx * 1.7)) * 120.0) * k
		var col := Color(pal.near, 0.55)
		c.draw_line(Vector2(x, top), Vector2(x, Engine_.GROUND * k), col, 7.0 * k)
		var y := top + 40 * k
		while y < Engine_.GROUND * k:
			c.draw_line(Vector2(x - 5 * k, y), Vector2(x + 5 * k, y), pal.paper2, 2.0 * k)
			y += 70 * k
		c.draw_line(Vector2(x, top + 30 * k), Vector2(x + 40 * k, top + 10 * k), col, 3.0 * k)
		c.draw_line(Vector2(x, top + 60 * k), Vector2(x - 36 * k, top + 44 * k), col, 3.0 * k)

## The hero: an ink stroke figure with a pale scarf trailing behind.
func _ninja(c: CanvasItem, feet: Vector2, k: float) -> void:
	var f: int = engine.facing
	var ink: Color = pal.ink
	var legs := sin(engine.run_t * 16.0) * 10.0 if engine.on_ground else 6.0
	var hip := feet + Vector2(0, -30) * k
	var neck := feet + Vector2(0, -56) * k
	var head := feet + Vector2(0, -66) * k
	var lean := 6.0 * f if absf(engine.vx) > 50 else 0.0
	neck.x += lean * k
	head.x += lean * k
	if engine.dash_t > 0.0:
		for i in 4:
			c.draw_line(hip - Vector2(f * (30 + i * 22), i * 6 - 10) * k, hip - Vector2(f * (60 + i * 22), i * 6 - 10) * k, Color(pal.mid, 0.6), 3.0 * k)
	c.draw_line(hip, feet + Vector2(legs, 0) * k, ink, 6.0 * k)
	c.draw_line(hip, feet + Vector2(-legs, 0) * k, ink, 6.0 * k)
	c.draw_line(hip, neck, ink, 11.0 * k)
	c.draw_texture_rect(disc, Rect2(head - Vector2(10, 10) * k, Vector2(20, 20) * k), false, ink)
	# Headband tails and scarf: a pale band so the hero reads against ink.
	var wave := sin(anim_t * 12.0) * 5.0
	var tail0 := head + Vector2(-f * 8, -3) * k
	c.draw_line(tail0, tail0 + Vector2(-f * 22, -6 + wave) * k, pal.mid, 3.0 * k)
	c.draw_line(tail0 + Vector2(-f * 22, -6 + wave) * k, tail0 + Vector2(-f * 40, wave * 1.5) * k, pal.mid, 2.0 * k)
	c.draw_line(head + Vector2(-9, -2) * k, head + Vector2(9, -2) * k, pal.mid, 3.0 * k)
	c.draw_line(head + Vector2(f * 3, 0) * k, head + Vector2(f * 8, 0) * k, pal.paper, 2.0 * k)   # eye slit
	# Arms and sword.
	var hand := neck + Vector2(f * 16, 10) * k
	if engine.slash_t > 0.0:
		var t: float = 1.0 - engine.slash_t / Engine_.SLASH_T
		var a := lerpf(-1.3, 1.1, t)
		hand = neck + Vector2(f * 18, 0).rotated(a * f) * k
		c.draw_line(neck, hand, ink, 5.0 * k)
		var tip := hand + Vector2(f * 70, 0).rotated(a * f) * k
		c.draw_line(hand, tip, ink, 3.0 * k)
		# The cut: a crescent of grey brush strokes.
		for i in 5:
			var aa := lerpf(-1.3, a, float(i) / 4.0)
			var p1 := neck + Vector2(f * 60, 0).rotated(aa * f) * k
			var p2 := neck + Vector2(f * 92, 0).rotated(aa * f) * k
			c.draw_line(p1, p2, Color(pal.mid, 0.25 + i * 0.12), (3 + i) * k)
	else:
		c.draw_line(neck, hand, ink, 5.0 * k)
		c.draw_line(neck + Vector2(-f * 4, 2) * k, neck + Vector2(-f * 34, -30) * k, ink, 3.0 * k)   # sword on the back
	c.draw_line(neck, neck + Vector2(-f * 12, 18) * k, ink, 5.0 * k)

## Foes and bosses: the same ink figure, bigger or bulkier, with a grey sash.
func _figure(c: CanvasItem, feet: Vector2, k: float, f: int, kind: String, flash: bool, windup: bool, _x: bool, t: float) -> void:
	var ink: Color = pal.mid if flash else pal.near.lerp(pal.ink, 0.5)
	var bulk := 1.4 if kind == "brute" or kind == "boss0" or kind == "boss3" else 1.0
	var hip := feet + Vector2(0, -30) * k
	var neck := feet + Vector2(0, -56) * k
	var head := feet + Vector2(0, -66) * k
	var legs := sin(t) * 8.0
	c.draw_line(hip, feet + Vector2(legs, 0) * k, ink, 6.0 * k * bulk)
	c.draw_line(hip, feet + Vector2(-legs, 0) * k, ink, 6.0 * k * bulk)
	c.draw_line(hip, neck, ink, 12.0 * k * bulk)
	c.draw_texture_rect(disc, Rect2(head - Vector2(10, 10) * k * bulk, Vector2(20, 20) * k * bulk), false, ink)
	c.draw_line(hip + Vector2(-8, -4) * k, hip + Vector2(8, -4) * k, pal.far, 4.0 * k)
	match kind:
		"boss0":   # Iron Monk: wide straw hat and a staff
			c.draw_colored_polygon(PackedVector2Array([head + Vector2(-26, 2) * k, head + Vector2(0, -16) * k, head + Vector2(26, 2) * k]), ink)
			c.draw_line(neck + Vector2(f * 16, -40) * k, neck + Vector2(f * 16, 56) * k, ink, 4.0 * k)
		"boss1":   # Twin Blade: two swords
			for s in [-1, 1]:
				c.draw_line(neck + Vector2(f * 14, 8) * k, neck + Vector2(f * 14, 8) * k + Vector2(f * 56, -20 * s).rotated(-0.6 if windup else 0.0) * k, ink, 3.0 * k)
		"boss2":   # Paper Crane: wide sleeves like wings
			var w := 1.0 + 0.3 * sin(t * 2.0)
			c.draw_colored_polygon(PackedVector2Array([neck, neck + Vector2(-50, 30 * w) * k, neck + Vector2(-20, 34) * k]), Color(ink, 0.7))
			c.draw_colored_polygon(PackedVector2Array([neck, neck + Vector2(50, 30 * w) * k, neck + Vector2(20, 34) * k]), Color(ink, 0.7))
		"boss3":   # Shadow Daimyo: helmet crest and long blade
			c.draw_line(head + Vector2(-14, -10) * k, head + Vector2(-22, -30) * k, ink, 3.0 * k)
			c.draw_line(head + Vector2(14, -10) * k, head + Vector2(22, -30) * k, ink, 3.0 * k)
			c.draw_line(neck + Vector2(f * 14, 6) * k, neck + Vector2(f * 90, -10) * k, ink, 4.0 * k)
		"thrower":
			c.draw_line(neck, neck + Vector2(f * 18, -14) * k, ink, 5.0 * k)
		_:
			var up := -1.4 if windup else 0.2
			var hand := neck + Vector2(f * 18, 8) * k
			c.draw_line(neck, hand, ink, 5.0 * k)
			c.draw_line(hand, hand + Vector2(f * 46, 0).rotated(up * f) * k, ink, 3.0 * k)
	if windup:
		# Telegraph: a pale flash over the head ("!" without colour).
		c.draw_string(ThemeDB.fallback_font, head + Vector2(-8, -30) * k, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(34 * k), pal.ink)

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
		c.draw_rect(Rect2(bx, by, w * float(engine.boss.hp) / float(engine.boss.max), 14 * k), pal.ink)
		c.draw_string(font, Vector2(bx, by - 8 * k), tr(engine.boss_name()), HORIZONTAL_ALIGNMENT_CENTER, w, int(22 * k), pal.ink)
	if banner != "":
		var fs := int(64 * k)
		var tp := Vector2(0, sz.y * 0.42)
		c.draw_string_outline(font, tp, banner, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, int(10 * k), pal.paper)
		c.draw_string(font, tp, banner, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, pal.ink)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 170.0, 1.3)
	var o := c.size / 2.0
	var save := pal
	pal = LOOKS.voodoo
	if disc == null:
		disc = _make_disc()
	c.draw_texture_rect(disc, Rect2(o + Vector2(20, -80) * k - Vector2(70, 70) * k, Vector2(140, 140) * k), false, Color(1, 1, 1, 0.85))
	c.draw_line(o + Vector2(-170, 60) * k, o + Vector2(170, 60) * k, Color(0.9, 0.9, 0.9), 5.0 * k)
	var ink := Color(0.05, 0.05, 0.05)
	var feet := o + Vector2(0, 60) * k
	var neck := feet + Vector2(0, -84) * k
	c.draw_line(feet + Vector2(-20, 0) * k, feet + Vector2(0, -45) * k, ink, 9 * k)
	c.draw_line(feet + Vector2(26, -6) * k, feet + Vector2(0, -45) * k, ink, 9 * k)
	c.draw_line(feet + Vector2(0, -45) * k, neck, ink, 16 * k)
	c.draw_texture_rect(disc, Rect2(neck + Vector2(-15, -30) * k, Vector2(30, 30) * k), false, ink)
	c.draw_line(neck, neck + Vector2(70, -70) * k, ink, 5 * k)
	c.draw_line(neck + Vector2(-8, -16) * k, neck + Vector2(-60, -6) * k, Color(0.6, 0.6, 0.6), 4 * k)
	pal = save

# ---------- skins ----------

func _set_skin(name: String) -> void:
	skin = name if LOOKS.has(name) else "classic"
	pal = LOOKS[skin]
	_hud_colors()
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
	SaveUtil.write(SAVE_PATH, {"score": engine.score, "stage": st, "lives": maxi(1, engine.lives), "stars": engine.stars, "diff": engine.diff})

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
	engine.build_stage()
	_begin()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

func _music(style: String) -> void:
	var m = get_node_or_null("/root/Music")
	if m:
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
