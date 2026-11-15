extends Control

## Stonewater, M0 vertical slice (design: D:/Dev/Minigame Art/wolf/GAME_DESIGN_WOLFPACK.md).
## Landscape, 2D oblique with Y-sort. You lead a pack of 3 AI wolves (chaser, attacker,
## scout) across one large map (6144 x 4608 px, chunks streamed 3 x 3) and bring down two
## elk from a herd of 12: Sense shows which are weak, the command wheel (hold Howl) sends
## the pack, bite-and-hold finishes the kill. The old arcade Wolf Pack is in git history.
## Not in M0: story levels, territories, skills, den management, rival packs, collisions.
##
## Landing menu style: S1 Corner Ghost (docs/MENU_STYLES.md): the pack on a ridge at dusk,
## art kept visible. Skin: Classic only for v1 (design §10).

const E = preload("res://scripts/games/wolf_pack/wolf_pack_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const MenuStyles = preload("res://scripts/games/wolf_pack/menu_styles.gd")
const HomeKit = preload("res://scripts/games/wolf_pack/home_kit.gd")
const SoundLib = preload("res://scripts/games/wolf_pack/sound_lib.gd")
const SpriteLib = preload("res://scripts/games/wolf_pack/sprite_lib.gd")
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/wolf_pack/wolf_pack_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://wolf_pack_save.json"
const PAD_PATH := "res://scripts/common/pad/pad_controller.gd"

const WORLD_SCALE := 1.0
## Scenery per chunk: [sprite id, scale, count]. Ids are full literals on purpose (sprite_lib sync).
const SCENERY := [
	["forest/pine_tree", 2.6, 9],
	["forest/oak_tree", 2.4, 5],
	["forest/dead_tree", 2.4, 2],
	["forest/boulder_lg", 2.4, 3],
	["forest/boulder_sm", 2.2, 4],
	["forest/fallen_log", 2.2, 3],
	["forest/tree_stump", 2.2, 2],
	["forest/large_bush", 2.2, 4],
	["forest/small_bush", 2.2, 4],
	["forest/fern", 2.2, 5],
	["forest/flower_red", 2.0, 5],
	["forest/flower_yellow", 2.0, 5],
	["forest/mushroom_cluster", 2.0, 2],
]
const WHEEL := [
	["rally", "Rally"], ["hold", "Hold"], ["scout", "Scout ahead"],
	["drive", "Drive"], ["flank", "Flank"], ["strike", "Strike"],
]

var info = null
var home
var engine
var started := false
var result_recorded := false
var over_t: float = 0.0

var field: Control
var hud: Control
var end_dialog: Control
var grass_tex: Texture2D
var chunks := {}                     # Vector2i -> Array of [texture, pos, scale]
var cam := E.DEN
var zoom: float = 1.0
var puffs: Array = []                # [pos, age, colour]
var banner := ""
var banner_t: float = 0.0
var step_t: float = 0.0
var music_style := ""
var music_t: float = 0.0
var touch_pad: Control = null
var fog_tex: ImageTexture
var fog_t: float = 0.0
var wheel_open := false
var wheel_idle: float = 0.0
var howl_down: float = -1.0           # how long Howl has been held (-1 = not held)
var prev_howl := false
var prev_sense := false
var time_scale: float = 1.0
var shake: float = 0.0
var quote_i: int = 0
var quote_t: float = 0.0

func _ready() -> void:
	Orientation.lock_landscape()
	preload("res://scripts/games/wolf_pack/wolf_pack_i18n.gd").install(self)
	engine = E.new()
	engine.reset(1)
	quote_i = randi() % HELP.QUOTES.size()
	grass_tex = SpriteLib.texture("textures/floor_ground_grass")
	_build_ui()
	var m = get_node_or_null("/root/Music")
	if m and m.has_method("prepare"):
		m.prepare("calm", 0)

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
	field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	field.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
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
	pause_btn.offset_top = 28
	pause_btn.offset_bottom = 92
	pause_btn.pressed.connect(_on_pause)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	_add_pad()

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S1 Corner Ghost; colours: dusk and pine.
		"landing": "ghost",
		"landing_style": MenuStyles,
		"title_colors": [Color("eef3f8"), Color("a8c4e0"), Color("eef3f8"), Color("c9d8e8")],
		"landing_colors": [Color("0a1020"), Color("23324a")],
		"landing_stars": 90,
		"menu_color": Color("ffd98a"),
		"help": HELP,
		"info": info,
		"accent": Color("8fb4d8"),
		"solo_heading": "Hunt",
		"subtitle": _quote_line(quote_i),
		"logo": _draw_home_logo,
		"modes": [{"text": "🐺 First Hunt", "sub": "Slice: lead your pack, bring down two elk", "action": _new_game}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [{"text": "🍖 Meal", "how": "Fills the pack's hunger bar.", "action": _help_meal}],
		"board": "none",
	})
	add_child(home)
	if info:
		add_child(info)

func _add_pad() -> void:
	if not ResourceLoader.exists(PAD_PATH):
		return
	touch_pad = load(PAD_PATH).new()
	touch_pad.layout_override = "stick_4"
	touch_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(touch_pad)
	for part in ["pause", "info"]:
		touch_pad.set_hidden(part, true)
	touch_pad.set_state("a", {"glyph": "bolt", "sub": tr("Bite")})
	touch_pad.set_state("b", {"sub": tr("Sprint")})
	touch_pad.set_state("x", {"sub": tr("Sense")})
	touch_pad.set_state("y", {"sub": tr("Howl")})
	touch_pad.visible = false

# ---------- flow ----------

func _new_game() -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset(randi() % 100000 + 1)
	_begin()

func _restart() -> void:
	_new_game()

func _begin() -> void:
	started = true
	result_recorded = false
	over_t = 0.0
	puffs.clear()
	wheel_open = false
	howl_down = -1.0
	time_scale = 1.0
	end_dialog.visible = false
	cam = engine.hero.p
	zoom = 1.0
	music_style = ""
	music_t = 0.0
	chunks.clear()
	if touch_pad:
		touch_pad.release_all()
	quote_i = (quote_i + 1) % HELP.QUOTES.size()
	quote_t = 7.0
	_show_banner(tr("Bring down 2 elk. Sense shows the weak ones."), 4.0)

## "text" - Who. The quote is translated, the author's name is kept as it is.
func _quote_line(i: int) -> String:
	var q: Array = HELP.QUOTES[i % HELP.QUOTES.size()]
	return "\"%s\" - %s" % [tr(q[0]), tr(q[1])]

func _show_banner(t: String, secs: float = 2.2) -> void:
	banner = t
	banner_t = secs

# ---------- input ----------

func _pad_down(id: String) -> bool:
	return touch_pad != null and touch_pad.visible and touch_pad.is_down(id)

func _inputs() -> Dictionary:
	var mv := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	var sprint := Input.is_key_pressed(KEY_SHIFT)
	var bite := Input.is_key_pressed(KEY_SPACE)
	if touch_pad:
		var v: Vector2 = touch_pad.get_vector("move")
		if v.length() > 0.05:
			mv = v
		sprint = sprint or _pad_down("b")
		bite = bite or _pad_down("a")
	if wheel_open:
		mv = Vector2.ZERO
	return {"move": mv.limit_length(1.0), "sprint": sprint, "bite": bite}

## Sense and Howl are edge / hold buttons: read them once per frame.
func _buttons(delta: float) -> void:
	var sense_now := Input.is_key_pressed(KEY_E) or _pad_down("x")
	if sense_now and not prev_sense and not wheel_open:
		if engine.sense():
			SoundLib.play(self, "ui/select", -6.0)
			_show_banner(tr("Sense"), 1.0)
	prev_sense = sense_now
	var howl_now := Input.is_key_pressed(KEY_Q) or _pad_down("y")
	if howl_now:
		howl_down = maxf(howl_down, 0.0) + delta
		if howl_down > 0.3 and not wheel_open:
			wheel_open = true
			wheel_idle = 0.0
			SoundLib.play(self, "ui/click", -8.0)
	elif prev_howl:
		# A tap on Howl is a Rally (design §3); a hold opened the wheel.
		if howl_down >= 0.0 and howl_down <= 0.3 and not wheel_open:
			_command("rally")
		howl_down = -1.0
	prev_howl = howl_now
	if wheel_open and not howl_now:
		wheel_idle += delta
		if wheel_idle > 4.0:
			wheel_open = false

func _command(c: String) -> void:
	engine.set_command(c)
	wheel_open = false
	SoundLib.play(self, "ui/select", -6.0)
	for w in WHEEL:
		if w[0] == c:
			_show_banner(tr(w[1]), 1.4)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or not wheel_open:
		return
	var i: int = event.keycode - KEY_1
	if i >= 0 and i < WHEEL.size():
		_command(WHEEL[i][0])

## The wheel is chosen with a tap or click on a slice (a MouseButton only: phones send taps twice).
func _input(event: InputEvent) -> void:
	if not wheel_open or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	var s := _wheel_slice(local)
	if s >= 0:
		_command(WHEEL[s][0])
		get_viewport().set_input_as_handled()

func _wheel_centre() -> Vector2:
	return size / 2.0 + Vector2(0, -10)

func _wheel_radius() -> float:
	return clampf(minf(size.x, size.y) * 0.32, 130.0, 230.0)

func _wheel_slice(p: Vector2) -> int:
	var d := p - _wheel_centre()
	if d.length() < _wheel_radius() * 0.28 or d.length() > _wheel_radius() * 1.25:
		return -1
	var a: float = fposmod(d.angle() + PI / 2.0, TAU)
	return int(a / (TAU / WHEEL.size())) % WHEEL.size()

# ---------- loop ----------

func _process(delta: float) -> void:
	var playing: bool = started and not engine.is_over()
	if touch_pad:
		touch_pad.visible = playing
	if not started and not engine.is_over():
		return
	delta = minf(delta, 0.05)
	_buttons(delta)
	time_scale = lerpf(time_scale, 0.3 if wheel_open else 1.0, minf(1.0, delta * 10.0))
	var sd := delta * time_scale
	_handle(engine.step(sd, _inputs()))
	banner_t = maxf(0.0, banner_t - delta)
	quote_t = maxf(0.0, quote_t - delta)
	shake = maxf(0.0, shake - delta * 2.5)
	for p in puffs:
		p[1] += delta
	puffs = puffs.filter(func(p): return p[1] < 0.7)
	var h: Dictionary = engine.hero
	if h.v.length() > 150.0:
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.3 if h.v.length() < 300.0 else 0.2
			SoundLib.play(self, "impact/footstep_grass", -22.0)
	# Camera: look 120 px ahead, pull out to 0.8 during a chase.
	var chase := false
	for e in engine.herd:
		if e.alive and e.flee and e.p.distance_to(h.p) < 750.0:
			chase = true
	zoom = lerpf(zoom, 0.8 if chase else 1.0, minf(1.0, delta * 2.0))
	var look: Vector2 = (h.face as Vector2) * 120.0 * clampf(h.v.length() / 230.0, 0.0, 1.0)
	cam = cam.lerp(h.p + look, minf(1.0, delta * 4.0))
	var half := size / zoom / 2.0
	cam.x = clampf(cam.x, minf(half.x, E.W / 2.0), maxf(E.W - half.x, E.W / 2.0))
	cam.y = clampf(cam.y, minf(half.y, E.H / 2.0), maxf(E.H - half.y, E.H / 2.0))
	_stream_chunks()
	_update_music(delta, chase)
	fog_t -= delta
	if fog_t <= 0.0:
		fog_t = 0.5
		_update_fog()
	if engine.is_over():
		over_t += delta
		if over_t > 1.4 and not result_recorded:
			_game_over()
	field.queue_redraw()
	hud.queue_redraw()

func _update_music(delta: float, chase: bool) -> void:
	music_t -= delta
	if music_t > 0.0:
		return
	music_t = 1.0
	var want := "lively" if chase else "calm"
	if want != music_style:
		music_style = want
		_music("play", want, 0, 2.5)

func _handle(evs: Array) -> void:
	for e in evs:
		match e[0]:
			"bite":
				puffs.append([e[1], 0.0, Color("e8d8b0")])
				SoundLib.play(self, "impact/punch_medium", -8.0)
			"kick":
				puffs.append([e[1], 0.0, Color("ffcf7a")])
				SoundLib.play(self, "impact/punch_heavy", -6.0)
				_vibrate(60)
				shake = minf(1.0, shake + 0.5)
			"kill":
				puffs.append([e[1], 0.0, Color(1, 1, 1)])
				SoundLib.play(self, "impact/soft_heavy", -4.0)
				if info:
					info.add("Elk caught")
				_show_banner(tr("Elk down! The pack eats. %d / %d") % [engine.kills, engine.goal_kills])
			"fed":
				SoundLib.play(self, "reward/coin_short", -10.0)
			"alarm":
				SoundLib.play(self, "impact/soft_medium", -16.0)
			"down":
				SoundLib.play(self, "ui/wrong", -6.0)
				_show_banner(tr("You are down. You wake at the den."), 3.0)
				quote_i = (quote_i + 1) % HELP.QUOTES.size()
				quote_t = 6.0
				_vibrate(150)
			"heir":
				_show_banner(tr("The heir would take over here (not built yet)."), 3.0)
			"goal":
				SoundLib.play(self, "reward/accomplished")

func _game_over() -> void:
	result_recorded = true
	started = false
	SaveUtil.delete(SAVE_PATH)
	SoundLib.play(self, "jingles/win_succeeded")
	var msg := tr("The pack is fed. A good hunt!") + "\n" + tr("Time: %d:%02d") % [int(engine.time) / 60, int(engine.time) % 60]
	msg += "\n\n" + _quote_line(quote_i)
	if info:
		info.result("win")
		info.add("Games played")
		msg += "\n" + info.summary(["Elk caught", "Games played"])
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	_music("stop", "")

# ---------- map streaming ----------

## Keeps only the 3 x 3 chunks round the camera loaded (design §9). Scenery per chunk is
## generated from the map seed + chunk, so a chunk always looks the same when it comes back.
func _stream_chunks() -> void:
	var want: Array = E.chunks_around(E.chunk_of(cam))
	for c in chunks.keys():
		if not c in want:
			chunks.erase(c)
	for c in want:
		if not chunks.has(c):
			chunks[c] = _make_chunk(c)

func _make_chunk(c: Vector2i) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(c.x, c.y, 7))
	var out: Array = []
	for s in SCENERY:
		var tex: Texture2D = SpriteLib.texture(s[0])
		if tex == null:
			continue
		for i in int(s[2]):
			var p := Vector2(float(c.x) * E.CHUNK + r.randf() * E.CHUNK, float(c.y) * E.CHUNK + r.randf() * E.CHUNK)
			if p.distance_to(E.DEN) < 260.0 or p.distance_to(E.LANDMARK) < 140.0:
				continue
			out.append([tex, p, float(s[1])])
	out.sort_custom(func(a, b): return a[1].y < b[1].y)
	return out

func _update_fog() -> void:
	var img := Image.create(E.FOG_W, E.FOG_H, false, Image.FORMAT_RGBA8)
	for y in E.FOG_H:
		for x in E.FOG_W:
			var seen: bool = engine.revealed[y * E.FOG_W + x] == 1
			img.set_pixel(x, y, Color(0.16, 0.3, 0.14) if seen else Color(0.03, 0.04, 0.06))
	for r in E.MUD:
		var rr: Rect2 = r
		for y in range(int(rr.position.y / 32.0), int(rr.end.y / 32.0)):
			for x in range(int(rr.position.x / 32.0), int(rr.end.x / 32.0)):
				if x < E.FOG_W and y < E.FOG_H and engine.revealed[y * E.FOG_W + x] == 1:
					img.set_pixel(x, y, Color(0.35, 0.26, 0.15))
	fog_tex = ImageTexture.create_from_image(img)

# ---------- drawing ----------

func _w2s(p: Vector2) -> Vector2:
	return (p - cam) * zoom + size / 2.0

func _draw_field() -> void:
	var c := field
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 8.0
	c.draw_set_transform(off)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.08))
	var origin := _w2s(Vector2.ZERO)
	if grass_tex:
		c.draw_set_transform(origin + off, 0.0, Vector2(2, 2) * zoom)
		c.draw_texture_rect(grass_tex, Rect2(Vector2.ZERO, Vector2(E.W, E.H) / 2.0), true, Color(0.95, 1.02, 0.88))
		c.draw_set_transform(off)
	# Mud: slows everybody. Brown with a dashed edge, so it isn't colour alone.
	for r in E.MUD:
		var rr: Rect2 = r
		var a := _w2s(rr.position)
		var sz := rr.size * zoom
		c.draw_rect(Rect2(a, sz), Color(0.3, 0.22, 0.12, 0.75))
		var dash := 22.0 * zoom
		var x := 0.0
		while x < sz.x:
			c.draw_line(a + Vector2(x, 0), a + Vector2(minf(x + dash * 0.6, sz.x), 0), Color(0.15, 0.1, 0.05), 3.0)
			c.draw_line(a + Vector2(x, sz.y), a + Vector2(minf(x + dash * 0.6, sz.x), sz.y), Color(0.15, 0.1, 0.05), 3.0)
			x += dash
	_draw_den(c)
	_draw_landmark(c)
	# Sense: scent trails behind every elk (age fades them).
	if engine.sense_t > 0.0 or engine.trails.size() > 0:
		for t in engine.trails:
			var q := _w2s(t[1])
			var al: float = clampf(1.0 - t[2] / 6.0, 0.0, 1.0) * (1.0 if engine.sense_t > 0.0 else 0.4)
			c.draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), Color(1, 0.85, 0.4, 0.5 * al))
	# Y-sorted pass: tall scenery, animals and wolves by their feet.
	var view := Rect2(cam - size / zoom / 2.0 - Vector2(200, 300), size / zoom + Vector2(400, 600))
	var items: Array = []
	for ch in chunks.values():
		for s in ch:
			if view.has_point(s[1]):
				items.append([s[1].y, 0, s])
	for e in engine.herd:
		if e.alive and view.has_point(e.p):
			items.append([e.p.y, 1, e])
	for w in engine.pack:
		if view.has_point(w.p):
			items.append([w.p.y, 2, w])
	items.append([engine.hero.p.y, 3, engine.hero])
	items.sort_custom(func(a, b): return a[0] < b[0])
	var hs := _w2s(engine.hero.p)
	for it in items:
		match it[1]:
			0:
				_draw_scenery(c, it[2], hs)
			1:
				_draw_elk(c, it[2])
			2:
				_draw_wolf(c, _w2s(it[2].p), it[2].v, engine.time + it[2].p.x * 0.01, 1.3 * zoom, it[2].role, false)
			3:
				if it[2].down_t <= 0.0:
					_draw_wolf(c, _w2s(it[2].p), it[2].v, engine.time, 1.55 * zoom * (E.STAGES[engine.stage].scale), "leader", true)
				else:
					_draw_wolf(c, _w2s(it[2].p), Vector2.ZERO, 0.0, 1.55 * zoom, "leader", true)
	if engine.target_id != -1 and engine.command in ["drive", "flank", "strike"]:
		var tg: Dictionary = engine.elk(engine.target_id)
		if not tg.is_empty() and tg.alive:
			_draw_target(c, _w2s(tg.p))
	for p in puffs:
		var a2: float = 1.0 - p[1] / 0.7
		var sz2: float = (14.0 + p[1] * 50.0) * zoom
		var q2 := _w2s(p[0])
		c.draw_rect(Rect2(q2 - Vector2(sz2, sz2) / 2.0, Vector2(sz2, sz2)), Color(p[2], 0.4 * a2))
	c.draw_set_transform(Vector2.ZERO)
	# A soft edge darkening, and darker while Sense is on.
	if engine.sense_t > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.12, 0.28))

func _draw_scenery(c: CanvasItem, s: Array, hero_screen: Vector2) -> void:
	var tex: Texture2D = s[0]
	var sz: Vector2 = tex.get_size() * float(s[2]) * zoom
	var p := _w2s(s[1])
	var rect := Rect2(p - Vector2(sz.x / 2.0, sz.y), sz)
	var a := 1.0
	# Tall things fade when the hero stands behind them (design §2).
	if tex.get_height() > 40 and rect.has_point(hero_screen) and s[1].y > engine.hero.p.y:
		a = 0.4
	c.draw_texture_rect(tex, rect, false, Color(1, 1, 1, a))

func _draw_den(c: CanvasItem) -> void:
	var p := _w2s(E.DEN)
	var k := zoom
	c.draw_circle(p, 170.0 * k, Color(0.25, 0.2, 0.12, 0.35))
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-70, 20) * k, p + Vector2(-50, -40) * k, p + Vector2(0, -62) * k,
		p + Vector2(50, -40) * k, p + Vector2(70, 20) * k]), Color(0.32, 0.27, 0.2))
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-26, 20) * k, p + Vector2(-20, -16) * k, p + Vector2(20, -16) * k, p + Vector2(26, 20) * k]), Color(0.06, 0.05, 0.05))
	c.draw_string(ThemeDB.fallback_font, p + Vector2(-70, 52) * k, tr("Den"), HORIZONTAL_ALIGNMENT_CENTER, 140.0 * k, int(22.0 * k), Color(1, 1, 1, 0.85))

func _draw_landmark(c: CanvasItem) -> void:
	var p := _w2s(E.LANDMARK)
	var k := zoom
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-90, 30) * k, p + Vector2(-50, -90) * k, p + Vector2(-10, -50) * k,
		p + Vector2(30, -150) * k, p + Vector2(90, 30) * k]), Color(0.45, 0.45, 0.43))
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(30, -150) * k, p + Vector2(60, -60) * k, p + Vector2(90, 30) * k, p + Vector2(40, 30) * k]), Color(0.33, 0.33, 0.32))
	c.draw_string(ThemeDB.fallback_font, p + Vector2(-90, 62) * k, tr("Howl Point"), HORIZONTAL_ALIGNMENT_CENTER, 180.0 * k, int(22.0 * k), Color(1, 1, 1, 0.85))

## A wolf from above: body, head, ears, tail, legs. role marks packmates with a shape.
func _draw_wolf(c: CanvasItem, p: Vector2, v: Vector2, t: float, k: float, role: String, hero: bool) -> void:
	var d: Vector2 = v.normalized() if v.length() > 8.0 else Vector2.RIGHT
	if not hero and v.length() <= 8.0:
		d = (engine.hero.face as Vector2)
	var sd := d.orthogonal()
	var run := sin(t * 14.0) * clampf(v.length() / 200.0, 0.0, 1.0)
	var body: Color = Color("55585f") if hero else {"chaser": Color("8a6e50"), "attacker": Color("3e4047"), "scout": Color("9a9ca4")}.get(role, Color("55585f"))
	var light := Color("c4c7cf")
	c.draw_line(p + Vector2(4, 6) * k - d * 16.0 * k, p + Vector2(4, 6) * k + d * 14.0 * k, Color(0, 0, 0, 0.28), 13.0 * k)
	for s in [-1.0, 1.0]:
		c.draw_line(p + d * 8.0 * k + sd * s * 5.0 * k, p + d * (14.0 + run * 5.0 * s) * k + sd * s * 8.0 * k, body.darkened(0.3), 3.0 * k)
		c.draw_line(p - d * 9.0 * k + sd * s * 5.0 * k, p - d * (14.0 + run * 5.0 * s) * k + sd * s * 8.0 * k, body.darkened(0.3), 3.0 * k)
	c.draw_line(p - d * 16.0 * k, p + d * 12.0 * k, body, 12.0 * k)
	c.draw_line(p - d * 8.0 * k, p + d * 6.0 * k, light, 5.0 * k)
	c.draw_line(p - d * 16.0 * k, p - d * 30.0 * k + sd * run * 6.0 * k, body, 5.0 * k)
	var head := p + d * 18.0 * k
	c.draw_line(head - d * 4.0 * k, head + d * 8.0 * k, body, 10.0 * k)
	c.draw_line(head + d * 6.0 * k, head + d * 13.0 * k, light, 5.0 * k)
	for s in [-1.0, 1.0]:
		c.draw_line(head - d * 3.0 * k + sd * s * 3.0 * k, head - d * 7.0 * k + sd * s * 6.0 * k, body.darkened(0.2), 3.0 * k)
	# Role mark above the head: hero chevron, chaser triangle, attacker diamond, scout ring.
	var m := p + Vector2(0, -34) * k
	var gold := Color("ffd24a")
	var r := 6.0 * k
	match role:
		"leader":
			c.draw_polyline(PackedVector2Array([m + Vector2(-r, -r * 0.5), m + Vector2(0, r * 0.5), m + Vector2(r, -r * 0.5)]), gold, 3.0 * k)
		"chaser":
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-r, r), m + Vector2(r, r), m + Vector2(0, -r)]), Color("e8b070"))
		"attacker":
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -r), m + Vector2(r, 0), m + Vector2(0, r), m + Vector2(-r, 0)]), Color("e07a6a"))
		"scout":
			c.draw_arc(m, r, 0, TAU, 12, Color("8ad8ff"), 3.0 * k)

func _draw_elk(c: CanvasItem, e: Dictionary) -> void:
	var p := _w2s(e.p)
	var k := zoom * 1.5
	var d: Vector2 = (e.v as Vector2).normalized() if e.v.length() > 5.0 else Vector2.RIGHT.rotated(e.wander)
	var sd := d.orthogonal()
	var run := sin(engine.time * 16.0 + e.p.x) * clampf(e.v.length() / 200.0, 0.0, 1.0)
	var col := Color("7a5231") if not e.weak else Color("8d6b48")
	c.draw_line(p + Vector2(5, 8) * k - d * 22.0 * k, p + Vector2(5, 8) * k + d * 20.0 * k, Color(0, 0, 0, 0.28), 14.0 * k)
	for s in [-1.0, 1.0]:
		c.draw_line(p + d * 10.0 * k + sd * s * 5.0 * k, p + d * (18.0 + run * 6.0 * s) * k + sd * s * 8.0 * k, col.darkened(0.35), 3.0 * k)
		c.draw_line(p - d * 12.0 * k + sd * s * 5.0 * k, p - d * (18.0 + run * 6.0 * s) * k + sd * s * 8.0 * k, col.darkened(0.35), 3.0 * k)
	c.draw_line(p - d * 22.0 * k, p + d * 16.0 * k, col, 14.0 * k)
	var head := p + d * 26.0 * k
	c.draw_line(p + d * 14.0 * k, head, col.lightened(0.05), 8.0 * k)
	c.draw_line(head, head + d * 8.0 * k, col.lightened(0.15), 6.0 * k)
	var antler := Color("e8dcc0")
	for s in [-1.0, 1.0]:
		var base: Vector2 = head - d * 2.0 * k + sd * s * 3.0 * k
		var tip: Vector2 = base + (sd * s * 0.8 - d * 0.5) * 20.0 * k
		c.draw_line(base, tip, antler, 2.5 * k)
		c.draw_line(base + (tip - base) * 0.5, base + (tip - base) * 0.5 + d * 8.0 * k, antler, 2.0 * k)
	# Weak target marker (Sense): a diamond with an exclamation. Strong ones: a small ring.
	var above := p + Vector2(0, -38) * k
	if engine.sense_t > 0.0:
		if e.weak:
			var r := 9.0 * k
			c.draw_colored_polygon(PackedVector2Array([above + Vector2(0, -r), above + Vector2(r, 0), above + Vector2(0, r), above + Vector2(-r, 0)]), Color("ffd24a"))
			c.draw_line(above + Vector2(0, -r * 0.55), above + Vector2(0, r * 0.1), Color(0.1, 0.1, 0.1), 2.5 * k)
			c.draw_rect(Rect2(above + Vector2(-1.3, r * 0.35) * 1.0, Vector2(2.6, 2.6) * k), Color(0.1, 0.1, 0.1))
		else:
			c.draw_arc(above, 6.0 * k, 0, TAU, 12, Color(1, 1, 1, 0.8), 2.0 * k)
		_stam_bar(c, p + Vector2(-22, -26) * k, 44.0 * k, e.stam / e.max_stam, e.stam <= e.max_stam * E.TIRED_AT)
	elif e.flee:
		_stam_bar(c, p + Vector2(-22, -26) * k, 44.0 * k, e.stam / e.max_stam, e.stam <= e.max_stam * E.TIRED_AT)
	if e.id == engine.hold_id:
		c.draw_rect(Rect2(p + Vector2(-30, 28) * k, Vector2(60, 7) * k), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(p + Vector2(-30, 28) * k, Vector2(60 * engine.hold_progress, 7) * k), Color("ff8a4a"))

## Stamina bar over an elk; a notch marks the "tired enough to bite" line (a mark, not just a colour).
func _stam_bar(c: CanvasItem, at: Vector2, w: float, f: float, tired: bool) -> void:
	c.draw_rect(Rect2(at, Vector2(w, 5)), Color(0, 0, 0, 0.55))
	c.draw_rect(Rect2(at, Vector2(w * clampf(f, 0.0, 1.0), 5)), Color("ff8a4a") if tired else Color("8fd8ff"))
	c.draw_line(at + Vector2(w * E.TIRED_AT, -2), at + Vector2(w * E.TIRED_AT, 7), Color.WHITE, 1.5)

func _draw_target(c: CanvasItem, p: Vector2) -> void:
	var r := 34.0 * zoom + sin(engine.time * 6.0) * 3.0
	var col := Color("ffd24a")
	for i in 4:
		var a: float = i * PI / 2.0 + engine.time * 0.8
		c.draw_line(p + Vector2.RIGHT.rotated(a) * r, p + Vector2.RIGHT.rotated(a) * (r + 10.0), col, 3.0)

func _draw_hud() -> void:
	if not started and not engine.is_over():
		return
	var c := hud
	var font := ThemeDB.fallback_font
	var x := 20.0
	var y := 32.0
	var bw := 250.0
	var h: Dictionary = engine.hero
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.08, 0.62)
	sb.set_corner_radius_all(12)
	c.draw_style_box(sb, Rect2(x - 10, y - 10, bw + 20, 118))
	_bar(c, x, y, bw, tr("Health"), h.hp / h.max_hp, Color("e86a5a"))
	_bar(c, x, y + 32, bw, tr("Stamina"), h.stam / h.max_stam, Color("ffd24a"))
	var hf: float = engine.hunger / 100.0
	_bar(c, x, y + 64, bw, tr("Pack hunger"), hf, Color("5be36a") if hf > 0.3 else Color("ff4a3a"))
	# Goal, top centre.
	var goal := tr("Bring down elk: %d / %d") % [engine.kills, engine.goal_kills]
	c.draw_string_outline(font, Vector2(0, y + 18), "🎯 " + goal, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, 8, Color(0.02, 0.04, 0.1, 0.9))
	c.draw_string(font, Vector2(0, y + 18), "🎯 " + goal, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color("ffd98a"))
	# Current command and Sense state, bottom centre.
	var cmd_name := ""
	for w in WHEEL:
		if w[0] == engine.command:
			cmd_name = tr(w[1])
	var sense_txt := tr("Sense ready") if engine.sense_cd <= 0.0 else tr("Sense %ds") % int(ceil(engine.sense_cd))
	var line := tr("Command: %s") % cmd_name + "   ·   " + sense_txt
	c.draw_string_outline(font, Vector2(0, size.y - 28), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, 8, Color(0.02, 0.04, 0.1, 0.9))
	c.draw_string(font, Vector2(0, size.y - 28), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1, 1, 1, 0.95))
	_draw_minimap(c, Vector2(x - 10, y + 120))
	if engine.hold_id != -1:
		var bx := size.x / 2.0 - 130.0
		c.draw_rect(Rect2(bx, size.y - 70, 260, 14), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(bx, size.y - 70, 260.0 * clampf(engine.hold_progress, 0.0, 1.0), 14), Color("ff8a4a"))
		c.draw_string(font, Vector2(bx, size.y - 76), tr("Holding the bite"), HORIZONTAL_ALIGNMENT_CENTER, 260, 18, Color.WHITE)
	if quote_t > 0.0 and not wheel_open:
		var qa := clampf(quote_t, 0.0, 1.0)
		var ql := _quote_line(quote_i)
		c.draw_string_outline(font, Vector2(120, size.y - 120), ql, HORIZONTAL_ALIGNMENT_CENTER, size.x - 240, 22, 10, Color(0.02, 0.04, 0.1, 0.9 * qa))
		c.draw_string(font, Vector2(120, size.y - 120), ql, HORIZONTAL_ALIGNMENT_CENTER, size.x - 240, 22, Color(1, 0.95, 0.8, qa))
	if wheel_open:
		_draw_wheel(c)
	if banner_t > 0.0 and banner != "":
		var a := clampf(banner_t, 0.0, 1.0)
		var by := size.y * 0.3
		c.draw_string_outline(font, Vector2(24, by), banner, HORIZONTAL_ALIGNMENT_CENTER, size.x - 48, 30, 12, Color(0.02, 0.04, 0.1, 0.9 * a))
		c.draw_string(font, Vector2(24, by), banner, HORIZONTAL_ALIGNMENT_CENTER, size.x - 48, 30, Color(1, 1, 1, a))

func _bar(c: CanvasItem, x: float, y: float, bw: float, label: String, f: float, col: Color) -> void:
	c.draw_string(ThemeDB.fallback_font, Vector2(x, y + 14), label, HORIZONTAL_ALIGNMENT_LEFT, 100, 16, Color(0.9, 0.9, 0.9))
	c.draw_rect(Rect2(x + 104, y + 2, bw - 104, 14), Color(1, 1, 1, 0.14))
	c.draw_rect(Rect2(x + 104, y + 2, (bw - 104) * clampf(f, 0.0, 1.0), 14), col)

func _draw_minimap(c: CanvasItem, at: Vector2) -> void:
	var w := 220.0
	var hgt := w * E.H / E.W
	c.draw_rect(Rect2(at - Vector2(3, 3), Vector2(w + 6, hgt + 6)), Color(0, 0, 0, 0.65))
	if fog_tex:
		c.draw_texture_rect(fog_tex, Rect2(at, Vector2(w, hgt)), false)
	var sc := w / E.W
	# The landmark is visible from the start (design §8); the den too.
	var lm := at + E.LANDMARK * sc
	c.draw_colored_polygon(PackedVector2Array([lm + Vector2(0, -7), lm + Vector2(6, 5), lm + Vector2(-6, 5)]), Color.WHITE)
	var dn := at + E.DEN * sc
	c.draw_rect(Rect2(dn - Vector2(4, 4), Vector2(8, 8)), Color("ffd24a"))
	for e in engine.herd:
		if e.alive and e.p.distance_to(engine.hero.p) < 800.0:
			c.draw_circle(at + e.p * sc, 2.5, Color("ff9a4a"))
	for wl in engine.pack:
		c.draw_circle(at + wl.p * sc, 2.5, Color("8ad8ff"))
	c.draw_circle(at + engine.hero.p * sc, 4.0, Color("ffd24a"))

func _draw_wheel(c: CanvasItem) -> void:
	var ctr := _wheel_centre()
	var rad := _wheel_radius()
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.1, 0.45))
	var mouse := get_local_mouse_position()
	var hover := _wheel_slice(mouse)
	var n := WHEEL.size()
	for i in n:
		var a0 := -PI / 2.0 + TAU * float(i) / n
		var a1 := a0 + TAU / n
		var pts := PackedVector2Array()
		for j in 11:
			pts.append(ctr + Vector2.RIGHT.rotated(lerpf(a0, a1, j / 10.0)) * rad)
		for j in range(10, -1, -1):
			pts.append(ctr + Vector2.RIGHT.rotated(lerpf(a0, a1, j / 10.0)) * rad * 0.3)
		var on: bool = WHEEL[i][0] == engine.command
		var col := Color(0.12, 0.2, 0.32, 0.92)
		if i == hover:
			col = Color(0.3, 0.45, 0.65, 0.95)
		elif on:
			col = Color(0.4, 0.34, 0.12, 0.95)
		c.draw_colored_polygon(pts, col)
		c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.35), 2.0)
		var mid := ctr + Vector2.RIGHT.rotated((a0 + a1) / 2.0) * rad * 0.65
		c.draw_string(font, mid + Vector2(-70, 8), "%d  %s" % [i + 1, tr(WHEEL[i][1])], HORIZONTAL_ALIGNMENT_CENTER, 140, 20, Color.WHITE)
	c.draw_string(font, ctr + Vector2(-60, 6), tr("Command"), HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(1, 1, 1, 0.85))

## Landing art: a big moon over a pine forest, three wolves howling on a rock.
func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 420.0, c.size.x / 520.0)
	var o := c.size / 2.0
	var moon := Color("f4f1de")
	var mc := o + Vector2(70, -55) * k
	for i in 4:
		c.draw_circle(mc, (64.0 + i * 16.0) * k, Color(moon, 0.06))
	c.draw_circle(mc, 58.0 * k, moon)
	c.draw_circle(mc + Vector2(-16, -12) * k, 9.0 * k, Color(moon.darkened(0.08)))
	c.draw_circle(mc + Vector2(14, 16) * k, 6.0 * k, Color(moon.darkened(0.08)))
	var far := Color("142238")
	var near := Color("070c18")
	for i in 13:
		_pine(c, o + Vector2(-190 + i * 32, 95 + (i % 3) * 6) * k, (50.0 + (i * 37 % 5) * 9.0) * k, far)
	for i in 7:
		_pine(c, o + Vector2(-200 + i * 66 + (i % 2) * 18, 128) * k, (70.0 + (i * 53 % 4) * 12.0) * k, near)
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(-40, 132) * k, o + Vector2(0, 40) * k, o + Vector2(30, 8) * k,
		o + Vector2(70, 2) * k, o + Vector2(118, 10) * k, o + Vector2(150, 60) * k, o + Vector2(190, 132) * k]), near)
	_howler(c, o + Vector2(-4, 34) * k, k * 0.85, near, false)
	_howler(c, o + Vector2(74, 8) * k, k * 1.05, near, false)
	_howler(c, o + Vector2(150, 40) * k, k * 0.8, near, true)
	c.draw_rect(Rect2(o + Vector2(-220, 128) * k, Vector2(440, 40) * k), near)

func _pine(c: CanvasItem, base: Vector2, h: float, col: Color) -> void:
	for j in 3:
		var w := h * (0.42 - j * 0.1)
		var y0 := base.y - h * (0.15 + j * 0.27)
		c.draw_colored_polygon(PackedVector2Array([Vector2(base.x - w, y0), Vector2(base.x, y0 - h * 0.42), Vector2(base.x + w, y0)]), col)
	c.draw_rect(Rect2(base.x - h * 0.04, base.y - h * 0.18, h * 0.08, h * 0.18), col)

func _howler(c: CanvasItem, p: Vector2, k: float, col: Color, flip: bool) -> void:
	var sx := -1.0 if flip else 1.0
	var parts := [
		[Vector2(-18, -6), Vector2(-4, -40), Vector2(8, -44), Vector2(12, -28), Vector2(8, 0), Vector2(-20, 0)],
		[Vector2(-2, -40), Vector2(8, -46), Vector2(20, -70), Vector2(11, -73)],
		[Vector2(10, -72), Vector2(20, -70), Vector2(31, -88), Vector2(27, -90), Vector2(13, -81)],
		[Vector2(10, -75), Vector2(6, -87), Vector2(15, -79)],
		[Vector2(-18, -3), Vector2(-36, -1), Vector2(-40, 3), Vector2(-16, 3)],
		[Vector2(3, -24), Vector2(9, -24), Vector2(10, 0), Vector2(4, 0)],
	]
	c.draw_circle(p + Vector2(-10 * sx, -12) * k, 13.0 * k, col)
	for part in parts:
		var pts := PackedVector2Array()
		for q in part:
			pts.append(p + Vector2(q.x * sx, q.y) * k)
		c.draw_colored_polygon(pts, col)

# ---------- skins ----------

## Classic only for v1 (design §10): a Voodoo "Spirit Hunt" visual mode is a separate art pass.
func _set_skin(_s: String) -> void:
	pass

func _current_skin() -> String:
	return "classic"

# ---------- pause / save ----------

func _on_pause() -> void:
	wheel_open = false
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
	return tr("First Hunt") + " · " + tr("Elk: %d / %d") % [int(e.get("kills", 0)), 2]

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary) or not d.has("engine"):
		_new_game()
		return
	engine.from_dict(d.engine)
	_begin()

# ---------- sound / helps ----------

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
