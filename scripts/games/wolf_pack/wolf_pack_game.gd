extends Control

## Wolf Pack: lead a wolf pack through a year in the wild. Top-down, portrait.
## Steer the lead wolf, the pack follows and joins the chase; big prey needs
## several wolves at once. Modes: One Year (Easy / Normal / Hard), Endless.
## Original game; everything is drawn in code (no art files).
##
## Landing menu style: S1 Corner Ghost (docs/MENU_STYLES.md): quiet and
## atmospheric (wolves under the moon), not one of the last two games'
## styles (Hover Duel rail, Bridge Master slabs).

const E = preload("res://scripts/games/wolf_pack/wolf_pack_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const MenuStyles = preload("res://scripts/games/wolf_pack/menu_styles.gd")
const HomeKit = preload("res://scripts/games/wolf_pack/home_kit.gd")
const SoundLib = preload("res://scripts/games/wolf_pack/sound_lib.gd")
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/wolf_pack/wolf_pack_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://wolf_pack_save.json"
const PAD_PATH := "res://scripts/common/pad/pad_controller.gd"

const LEVELS := ["Easy", "Normal", "Hard"]
## Ground tint per season, [classic, voodoo].
const GROUND := [
	[Color("7fae5a"), Color("1a2a3a")],
	[Color("5f9a3e"), Color("142a24")],
	[Color("b08a4a"), Color("2a1a30")],
	[Color("e6eef4"), Color("10182e")],
]
const WOLF_COL := {"classic": [Color("4a4d55"), Color("8a8e98")], "voodoo": [Color("29e6ff"), Color("b8f6ff")]}
const PREY_COL := {"hare": Color("b89a72"), "deer": Color("b07a44"), "elk": Color("6e4a2c"), "bison": Color("3e2a1e")}

var info = null
var home
var engine
var skin := "classic"
var started := false
var result_recorded := false
var over_t: float = 0.0

var field: Control
var hud: Control
var end_dialog: Control
var ground_tex: ImageTexture
var cam := Vector2(E.W / 2.0, E.H / 2.0)
var puffs: Array = []        # [pos, age, colour]
var banner := ""
var banner_t: float = 0.0
var step_t: float = 0.0
var touch_pad: Control = null
var finger := -1              # touch index steering without the Pad
var finger_pos := Vector2.ZERO

func _ready() -> void:
	Orientation.lock_portrait()
	preload("res://scripts/games/wolf_pack/wolf_pack_i18n.gd").install(self)
	engine = E.new()
	engine.reset("year", 1, 4242)
	_bake_ground()
	_build_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	field = Control.new()
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.draw.connect(_draw_field)
	add_child(field)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	add_child(hud)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	add_child(pause_btn)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_left = -96
	pause_btn.offset_right = -16
	pause_btn.offset_top = 30
	pause_btn.offset_bottom = 94
	pause_btn.pressed.connect(_on_pause)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	_add_pad()

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in LEVELS.size():
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard"][i], "row": "year",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_game.bind("year", i)})
	modes.append({"text": "♾ Endless", "sub": "No last season: how long can the pack last?", "action": _new_game.bind("endless", 1)})
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S1 Corner Ghost; colours: moonlight and pine.
		"landing": "ghost",
		"landing_style": MenuStyles,
		"title_colors": [Color("dfe8f2"), Color("8fb4d8")],
		"landing_colors": [Color("0a1020"), Color("1a2a3a")],
		"menu_color": Color("8fb4d8"),
		"help": HELP,
		"info": info,
		"accent": Color("8fb4d8"),
		"solo_heading": "One Year",
		"subtitle": "Lead the pack, hunt together, live through the winter.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [{"text": "🍖 Meal", "how": "Fills the pack's hunger bar.", "action": _help_meal}],
		"board": "Best score",
		"board_note": "Meat the pack ate in one game, in kg.",
	})
	add_child(home)
	if info:
		add_child(info)

func _add_pad() -> void:
	if not ResourceLoader.exists(PAD_PATH):
		return
	touch_pad = load(PAD_PATH).new()
	touch_pad.layout_override = "stick_1"
	touch_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(touch_pad)
	for part in ["pause", "info"]:
		touch_pad.set_hidden(part, true)
	touch_pad.set_state("a", {"glyph": "bolt", "sub": tr("Sprint")})
	touch_pad.visible = false

# ---------- flow ----------

func _new_game(m: String, d: int) -> void:
	engine.mode = m
	engine.diff = d
	_restart()

func _restart() -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset(engine.mode, engine.diff, randi() % 1000000)
	_begin()

func _begin() -> void:
	started = true
	result_recorded = false
	over_t = 0.0
	puffs.clear()
	finger = -1
	end_dialog.visible = false
	cam = engine.leader().p
	if touch_pad:
		touch_pad.release_all()
	_bake_ground()
	_show_banner(tr(E.SEASONS[engine.season()]))
	_music("play", "calm", engine.season())

func _show_banner(t: String) -> void:
	banner = t
	banner_t = 2.2

# ---------- input ----------

func _inputs() -> Dictionary:
	var mv := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	var sprint := Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SPACE)
	if touch_pad:
		var v: Vector2 = touch_pad.get_vector("move")
		if v.length() > 0.05:
			mv = v
		sprint = sprint or touch_pad.is_down("a")
	elif finger != -1:
		# No Pad (older app): run toward the finger; far away = sprint.
		var d := finger_pos - _w2s(engine.leader().p)
		if d.length() > 24.0:
			mv = d.normalized()
		sprint = d.length() > minf(size.x, size.y) * 0.4
	return {"move": mv.limit_length(1.0), "sprint": sprint}

func _input(event: InputEvent) -> void:
	if touch_pad or not started or home.is_home_visible() or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and event.position.y > 110.0:
			finger = event.index
			finger_pos = event.position
		elif not event.pressed and event.index == finger:
			finger = -1
	elif event is InputEventScreenDrag and event.index == finger:
		finger_pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		finger = 0 if event.pressed and event.position.y > 110.0 else -1
		finger_pos = event.position
	elif event is InputEventMouseMotion and finger == 0 and not DisplayServer.is_touchscreen_available():
		finger_pos = event.position

# ---------- loop ----------

func _process(delta: float) -> void:
	if touch_pad:
		touch_pad.visible = started and not engine.is_over()
	if not started and not engine.is_over():
		return
	delta = minf(delta, 0.05)
	_handle(engine.step(delta, _inputs()))
	banner_t = maxf(0.0, banner_t - delta)
	for p in puffs:
		p[1] += delta
	puffs = puffs.filter(func(p): return p[1] < 0.7)
	var L: Dictionary = engine.leader()
	if L.v.length() > 150.0:
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.32
			SoundLib.play(self, "impact/footstep_snow" if engine.season() == 3 else "impact/footstep_grass", -22.0)
	cam = cam.lerp(L.p + L.v * 0.35, minf(1.0, delta * 3.0))
	var half := size / 2.0
	cam.x = clampf(cam.x, minf(half.x, E.W / 2.0), maxf(E.W - half.x, E.W / 2.0))
	cam.y = clampf(cam.y, minf(half.y, E.H / 2.0), maxf(E.H - half.y, E.H / 2.0))
	if engine.is_over():
		over_t += delta
		if over_t > 1.2 and not result_recorded:
			_game_over()
	field.queue_redraw()
	hud.queue_redraw()

func _handle(evs: Array) -> void:
	for e in evs:
		match e[0]:
			"catch":
				puffs.append([e[2], 0.0, Color(1, 1, 1)])
				SoundLib.play(self, "impact/soft_heavy" if e[1] in ["elk", "bison"] else "impact/soft_medium", -6.0)
				_show_banner(tr("+%d kg") % int(E.PREY[e[1]].kg))
			"kick":
				puffs.append([e[1], 0.0, Color("ffcf7a")])
				SoundLib.play(self, "impact/punch_medium", -6.0)
				_vibrate(60)
			"pup":
				SoundLib.play(self, "reward/powerup", -6.0)
				_show_banner(tr("A pup joins the pack!"))
			"leave":
				_sfx("wrong")
				_show_banner(tr("Too hungry: a wolf left the pack"))
				_vibrate(120)
			"season":
				_bake_ground()
				_show_banner(tr(E.SEASONS[e[1]]))
				_music("play", "calm", e[1])

func _game_over() -> void:
	result_recorded = true
	started = false
	SaveUtil.delete(SAVE_PATH)
	var msg := ""
	if engine.won:
		msg = tr("The pack lived through the year!")
		var n: int = engine.pack_size()
		var stars := 3 if n >= 8 else (2 if n >= 5 else 1)
		msg += "\n" + "★".repeat(stars) + "☆".repeat(3 - stars)
		SoundLib.play(self, "jingles/win_succeeded")
	else:
		msg = tr("The leader starved. The hunt is over.")
		SoundLib.play(self, "jingles/lose_failed")
	msg += "\n" + tr("Meat: %d kg · Pack: %d wolves") % [engine.meat, engine.pack_size()]
	if info:
		info.result("win" if engine.won else "loss")
		info.high("Best score", engine.meat)
		info.add("Games played")
		info.high("Biggest pack", engine.biggest)
		var years: int = 1 if engine.won else engine.year()
		if years > 0:
			info.high("Years survived", years)
		for k in [["hare", "Hares caught"], ["deer", "Deer caught"], ["elk", "Elk caught"], ["bison", "Bison caught"]]:
			if engine.kills[k[0]] > 0:
				info.add(k[1], engine.kills[k[0]])
		msg += "\n" + info.summary(["Best score", "Biggest pack"])
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	_music("stop", "")

# ---------- ground picture ----------

## A grey speckled ground with trees and rocks, tinted by season when drawn.
func _bake_ground() -> void:
	var gw := int(E.W / 8.0)
	var gh := int(E.H / 8.0)
	var img := Image.create(gw, gh, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var base: Color = GROUND[engine.season()][1 if skin == "voodoo" else 0]
	var tree := Color("2f5a34") if skin == "classic" else Color("3a2a6a")
	if engine.season() == 2 and skin == "classic":
		tree = Color("8a4a1e")
	for y in gh:
		for x in gw:
			var n := sin(x * 0.07) * cos(y * 0.05) * 0.06 + r.randf() * 0.07
			img.set_pixel(x, y, base.darkened(n))
	# Trees (dark round crowns) and the odd rock.
	for i in 260:
		var cx := r.randi_range(0, gw - 1)
		var cy := r.randi_range(0, gh - 1)
		var rad := r.randi_range(2, 5)
		var col := tree.darkened(r.randf() * 0.2)
		if engine.season() == 3 and skin == "classic":
			col = col.lerp(Color.WHITE, 0.35)
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if dx * dx + dy * dy <= rad * rad and cx + dx >= 0 and cx + dx < gw and cy + dy >= 0 and cy + dy < gh:
					img.set_pixel(cx + dx, cy + dy, col)
	for i in 40:
		var cx := r.randi_range(0, gw - 3)
		var cy := r.randi_range(0, gh - 3)
		for dy in 2:
			for dx in 3:
				img.set_pixel(cx + dx, cy + dy, Color("8a8a86") if skin == "classic" else Color("9b4dff"))
	ground_tex = ImageTexture.create_from_image(img)

# ---------- drawing ----------

func _w2s(p: Vector2) -> Vector2:
	return p - cam + size / 2.0

func _draw_field() -> void:
	var c := field
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.08))
	if ground_tex:
		c.draw_texture_rect(ground_tex, Rect2(_w2s(Vector2.ZERO), Vector2(E.W, E.H)), false)
	var t: float = engine.time
	var view := Rect2(cam - size / 2.0 - Vector2(80, 80), size + Vector2(160, 160))
	for pr in engine.prey:
		if view.has_point(pr.p):
			_draw_prey(c, pr, t)
	for i in range(engine.wolves.size() - 1, -1, -1):
		var w: Dictionary = engine.wolves[i]
		if view.has_point(w.p):
			_draw_wolf(c, _w2s(w.p), w.v, t + i * 0.37, i == 0, 1.0)
	for p in puffs:
		var a: float = 1.0 - p[1] / 0.7
		var s: float = 18.0 + p[1] * 60.0
		var q := _w2s(p[0])
		c.draw_rect(Rect2(q - Vector2(s, s) / 2.0, Vector2(s, s)), Color(p[2], 0.35 * a))
	# Night falls in winter (classic): a cold veil.
	if engine.season() == 3 and skin == "classic":
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.3, 0.5, 0.12))

## A wolf from above, all thick lines: body, head, ears, tail, legs.
func _draw_wolf(c: CanvasItem, p: Vector2, v: Vector2, t: float, lead: bool, k: float) -> void:
	var cols: Array = WOLF_COL[skin]
	var d: Vector2 = v.normalized() if v.length() > 8.0 else Vector2.UP
	var sd := d.orthogonal()
	var run := sin(t * 14.0) * clampf(v.length() / 200.0, 0.0, 1.0)
	var body: Color = cols[0]
	var light: Color = cols[1]
	c.draw_line(p + Vector2(4, 6) * k - d * 16.0 * k, p + Vector2(4, 6) * k + d * 14.0 * k, Color(0, 0, 0, 0.25), 13.0 * k)
	for s in [-1.0, 1.0]:
		c.draw_line(p + d * 8.0 * k + sd * s * 5.0 * k, p + d * (14.0 + run * 5.0 * s) * k + sd * s * 8.0 * k, body.darkened(0.3), 3.0 * k)
		c.draw_line(p - d * 9.0 * k + sd * s * 5.0 * k, p - d * (14.0 + run * 5.0 * s) * k + sd * s * 8.0 * k, body.darkened(0.3), 3.0 * k)
	c.draw_line(p - d * 16.0 * k, p + d * 12.0 * k, body, 12.0 * k)
	c.draw_line(p - d * 8.0 * k, p + d * 6.0 * k, light, 5.0 * k)
	c.draw_line(p - d * 16.0 * k, p - d * 30.0 * k + sd * run * 6.0 * k, body, 5.0 * k)
	c.draw_line(p - d * 26.0 * k + sd * run * 5.0 * k, p - d * 31.0 * k + sd * run * 6.0 * k, light, 4.0 * k)
	var head := p + d * 18.0 * k
	c.draw_line(head - d * 4.0 * k, head + d * 8.0 * k, body, 10.0 * k)
	c.draw_line(head + d * 6.0 * k, head + d * 13.0 * k, light, 5.0 * k)
	for s in [-1.0, 1.0]:
		c.draw_line(head - d * 3.0 * k + sd * s * 3.0 * k, head - d * 7.0 * k + sd * s * 6.0 * k, body.darkened(0.2), 3.0 * k)
	if lead:
		c.draw_rect(Rect2(p - Vector2(22, 22) * k + Vector2(0, -26) * k, Vector2(44, 4) * k), Color("ffd24a") if skin == "classic" else Color("ff2bd6"))

func _draw_prey(c: CanvasItem, pr: Dictionary, t: float) -> void:
	var k: Dictionary = E.PREY[pr.kind]
	var p := _w2s(pr.p)
	var d: Vector2 = pr.v.normalized() if pr.v.length() > 5.0 else Vector2.RIGHT.rotated(pr.wander)
	var sd := d.orthogonal()
	var r: float = k.r
	var col: Color = PREY_COL[pr.kind]
	if skin == "voodoo":
		col = Color(col.r * 0.6 + 0.3, col.g * 0.4 + 0.1, col.b * 0.5 + 0.35)
	var run := sin(t * 16.0 + pr.p.x) * clampf(pr.v.length() / 200.0, 0.0, 1.0)
	c.draw_line(p + Vector2(4, 6) - d * r, p + Vector2(4, 6) + d * r, Color(0, 0, 0, 0.25), r * 0.9)
	for s in [-1.0, 1.0]:
		c.draw_line(p + d * r * 0.5 + sd * s * r * 0.3, p + d * r * (0.8 + run * 0.3 * s) + sd * s * r * 0.55, col.darkened(0.35), maxf(2.0, r * 0.18))
		c.draw_line(p - d * r * 0.5 + sd * s * r * 0.3, p - d * r * (0.8 + run * 0.3 * s) + sd * s * r * 0.55, col.darkened(0.35), maxf(2.0, r * 0.18))
	c.draw_line(p - d * r, p + d * r * 0.8, col, r * 0.85)
	if pr.kind == "bison":
		c.draw_line(p + d * r * 0.1, p + d * r * 0.6, col.darkened(0.3), r * 1.1)   # the hump
	var head := p + d * r * 1.05
	c.draw_line(head - d * r * 0.2, head + d * r * 0.35, col.lightened(0.1), r * 0.5)
	match pr.kind:
		"hare":
			for s in [-1.0, 1.0]:
				c.draw_line(head - d * 2.0 + sd * s * 2.0, head - d * 12.0 + sd * s * 4.0, col.lightened(0.2), 3.0)
			c.draw_rect(Rect2(p - d * r * 1.1 - Vector2(3, 3), Vector2(6, 6)), Color(0.95, 0.95, 0.95))
		"deer", "elk":
			var antler := Color("e8dcc0")
			var a := 0.6 if pr.kind == "deer" else 1.0
			for s in [-1.0, 1.0]:
				var base: Vector2 = head + sd * s * 3.0
				var tip: Vector2 = base + (sd * s * 0.9 - d * 0.4) * r * a
				c.draw_line(base, tip, antler, 2.5)
				c.draw_line(base + (tip - base) * 0.5, base + (tip - base) * 0.5 + d * r * 0.35 * a, antler, 2.0)
		"bison":
			for s in [-1.0, 1.0]:
				c.draw_line(head + sd * s * r * 0.25, head + sd * s * r * 0.45 + d * 4.0, Color("d8d0c0"), 3.0)
	# Hold meter: how close the pack is to bringing it down, and how many wolves it needs.
	if pr.hold > 0.0 and float(k.hold) > 0.0:
		var f: float = clampf(pr.hold / float(k.hold), 0.0, 1.0)
		c.draw_rect(Rect2(p + Vector2(-r, -r - 16), Vector2(r * 2.0, 6)), Color(0, 0, 0, 0.5))
		c.draw_rect(Rect2(p + Vector2(-r, -r - 16), Vector2(r * 2.0 * f, 6)), Color("ffd24a"))
	var L: Dictionary = engine.leader()
	if int(k.need) > 1 and L.p.distance_to(pr.p) < 300.0:
		c.draw_string(ThemeDB.fallback_font, p + Vector2(-30, -r - 20), "🐺×%d" % int(k.need), HORIZONTAL_ALIGNMENT_CENTER, 60, 16,
			Color("ffd24a") if engine.pack_size() >= int(k.need) else Color("ff6a5a"))

func _draw_hud() -> void:
	if not started and not engine.is_over():
		return
	var c := hud
	var font := ThemeDB.fallback_font
	var x := 16.0
	var y := 30.0
	var bw := clampf(size.x - 140.0, 160.0, 460.0)
	c.draw_rect(Rect2(x - 6, y - 6, bw + 12, 104), Color(0, 0, 0, 0.55))
	var head_text := tr(E.SEASONS[engine.season()])
	if engine.mode == "endless":
		head_text += " · " + tr("Year %d") % (engine.year() + 1)
	head_text += "  %d s" % int(ceil(engine.season_left()))
	c.draw_string(font, Vector2(x, y + 18), head_text, HORIZONTAL_ALIGNMENT_LEFT, bw * 0.6, 20, Color(0.95, 0.95, 0.95))
	c.draw_string(font, Vector2(x, y + 18), "🐺 %d   %d kg" % [engine.pack_size(), engine.meat], HORIZONTAL_ALIGNMENT_RIGHT, bw, 20, Color("ffd24a"))
	# Hunger bar.
	var f: float = engine.hunger / 100.0
	c.draw_string(font, Vector2(x, y + 46), tr("Hunger"), HORIZONTAL_ALIGNMENT_LEFT, 100, 16, Color(0.85, 0.85, 0.85))
	c.draw_rect(Rect2(x + 90, y + 34, bw - 90, 14), Color(1, 1, 1, 0.15))
	var hc := Color("5be36a") if f > 0.5 else (Color("ffb02e") if f > 0.25 else Color("ff4a3a"))
	c.draw_rect(Rect2(x + 90, y + 34, (bw - 90) * f, 14), hc)
	# Pup progress.
	c.draw_string(font, Vector2(x, y + 70), tr("Pups"), HORIZONTAL_ALIGNMENT_LEFT, 100, 16, Color(0.85, 0.85, 0.85))
	c.draw_rect(Rect2(x + 90, y + 60, bw - 90, 8), Color(1, 1, 1, 0.15))
	c.draw_rect(Rect2(x + 90, y + 60, (bw - 90) * clampf(engine.spare / E.GROW_AT, 0.0, 1.0), 8), Color("8fb4d8"))
	# Sprint.
	c.draw_string(font, Vector2(x, y + 92), tr("Sprint"), HORIZONTAL_ALIGNMENT_LEFT, 100, 16, Color(0.85, 0.85, 0.85))
	c.draw_rect(Rect2(x + 90, y + 82, bw - 90, 8), Color(1, 1, 1, 0.15))
	c.draw_rect(Rect2(x + 90, y + 82, (bw - 90) * engine.stamina, 8), Color("ffd24a"))
	if not touch_pad and finger != -1:
		c.draw_arc(finger_pos, 30, 0, TAU, 24, Color(1, 1, 1, 0.5), 2.0)
	if banner_t > 0.0 and banner != "":
		var a := clampf(banner_t, 0.0, 1.0)
		c.draw_string(font, Vector2(0, size.y * 0.3), banner, HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color(1, 1, 1, a))

## Landing art: a big moon and three wolves howling on a ridge.
func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 260.0, c.size.x / 360.0)
	var o := c.size / 2.0
	var moon := Color("f2f0dc") if skin == "classic" else Color("29e6ff")
	c.draw_circle(o + Vector2(60, -30) * k, 70.0 * k, Color(moon, 0.18))
	c.draw_circle(o + Vector2(60, -30) * k, 55.0 * k, moon)
	var dark := Color("0a1020")
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(-180, 120) * k, o + Vector2(-120, 40) * k, o + Vector2(-40, 60) * k,
		o + Vector2(40, 30) * k, o + Vector2(180, 80) * k, o + Vector2(180, 120) * k]), dark)
	for wv in [[Vector2(-110, 44), 1.0], [Vector2(-60, 54), 0.8], [Vector2(20, 34), 0.9]]:
		_howler(c, o + wv[0] * k, k * wv[1], dark)

## A sitting wolf, side view, nose to the sky.
func _howler(c: CanvasItem, p: Vector2, k: float, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-16, 0) * k, p + Vector2(-14, -26) * k, p + Vector2(-4, -44) * k,
		p + Vector2(2, -60) * k, p + Vector2(10, -74) * k, p + Vector2(14, -66) * k, p + Vector2(12, -56) * k,
		p + Vector2(8, -40) * k, p + Vector2(12, -20) * k, p + Vector2(14, 0) * k]), col)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -62) * k, p + Vector2(-2, -72) * k, p + Vector2(4, -66) * k]), col)
	c.draw_line(p + Vector2(-14, -2) * k, p + Vector2(-30, -6) * k, col, 6.0 * k)

# ---------- skins ----------

func _set_skin(s: String) -> void:
	skin = "voodoo" if s == "voodoo" else "classic"
	_bake_ground()
	field.queue_redraw()
	hud.queue_redraw()

func _current_skin() -> String:
	return skin

# ---------- pause / save ----------

func _on_pause() -> void:
	finger = -1
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.is_over():
		return
	SaveUtil.write(SAVE_PATH, {"engine": engine.to_dict()})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary) or not d.has("engine"):
		return ""
	var e: Dictionary = d.engine
	var t := tr("Endless") if str(e.get("mode", "year")) == "endless" else tr("One Year") + " (" + tr(LEVELS[clampi(int(e.get("diff", 1)), 0, 2)]) + ")"
	return t + " · " + tr(E.SEASONS[int(float(e.get("time", 0.0)) / E.SEASON_LEN) % 4])

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary) or not d.has("engine"):
		_new_game("year", 1)
		return
	engine.from_dict(d.engine)
	_begin()

# ---------- sound / helps ----------

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

func _vibrate(ms: int) -> void:
	var st = get_node_or_null("/root/Settings")
	if st and st.has_method("buzz"):
		st.buzz(ms)

func _music(what: String, style: String, index: int = 0, fade: float = 1.5) -> void:
	var m = get_node_or_null("/root/Music")
	if m == null:
		return
	match what:
		"play":
			m.play(style, self, index, fade)
		"stop":
			if m.has_method("stop"):
				m.stop(fade)

## 🍖 help: the pack's hunger back to full.
func _help_meal() -> bool:
	if not started or engine.is_over():
		return false
	if engine.feed():
		SoundLib.play(self, "reward/powerup")
		return true
	return false
