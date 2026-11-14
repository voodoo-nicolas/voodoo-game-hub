extends Control

## Wolf Pack: lead a wolf pack through a year in the wild. Top-down, portrait.
## Steer the lead wolf, the pack follows and joins the chase; big prey needs
## several wolves at once.
## Ways to play: 🌙 Story "The Long Winter" (8 chapters, one goal each),
## 🎯 Challenges (📅 Daily Hunt, same for everyone each day; 📆 Weekly Trial,
## a whole year on Hard with one goal), 🎮 Free Hunt (One Year Easy / Normal /
## Hard, Endless).
## Art: forest sprites + grass tile from the shared sprite library (CC0), wolves
## and prey drawn in code, weather (rain, pollen, leaves, snow) in a shader.
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
const SpriteLib = preload("res://scripts/games/wolf_pack/sprite_lib.gd")
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/wolf_pack/wolf_pack_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://wolf_pack_save.json"
const PROGRESS_PATH := "user://wolf_pack_progress.json"
const PAD_PATH := "res://scripts/common/pad/pad_controller.gd"

const LEVELS := ["Easy", "Normal", "Hard"]
const WOLF_SIZE := 1.45      # drawing scale of wolves next to the forest sprites
const PREY_SIZE := 1.35
const WOLF_COL := {"classic": [Color("4a4d55"), Color("a9adb6")], "voodoo": [Color("29e6ff"), Color("b8f6ff")]}
const PREY_COL := {"hare": Color("b89a72"), "deer": Color("b07a44"), "elk": Color("6e4a2c"), "bison": Color("3e2a1e")}
## Ground tint per season (multiplies the grass tile).
const TINT := [Color(1.0, 1.05, 0.9), Color(0.95, 1.0, 0.8), Color(1.35, 0.95, 0.55), Color(1, 1, 1)]
## Scenery: [sprite id, scale, seasons it shows in (bit mask), how many].
const SCENERY := [
	["forest/pine_tree", 2.6, 15, 70],
	["forest/oak_tree", 2.4, 7, 30],
	["forest/dead_tree", 2.4, 8, 18],
	["forest/boulder_lg", 2.4, 15, 22],
	["forest/boulder_sm", 2.2, 15, 26],
	["forest/fallen_log", 2.2, 15, 14],
	["forest/tree_stump", 2.2, 15, 12],
	["forest/large_bush", 2.2, 7, 26],
	["forest/small_bush", 2.2, 7, 26],
	["forest/berry_bush", 2.2, 2, 14],
	["forest/fern", 2.2, 3, 30],
	["forest/flower_red", 2.0, 3, 30],
	["forest/flower_yellow", 2.0, 3, 30],
	["forest/mushroom_cluster", 2.0, 4, 16],
]
const WEATHER_SHADER := """
shader_type canvas_item;
uniform int season = 0;
uniform float t = 0.0;
uniform vec2 cam = vec2(0.0);
uniform vec2 area = vec2(720.0, 1280.0);
uniform float amount = 1.0;
uniform bool neon = false;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 px = UV * area;
	vec2 c = UV - 0.5;
	float vig = smoothstep(0.3, 0.85, length(c * vec2(0.85, 1.0)));
	vec4 col = vec4(0.0, 0.01, 0.05, vig * (neon ? 0.7 : 0.5));
	vec3 pc = vec3(1.0);
	float speed = 1.0;
	float sway = 0.2;
	float density = 0.55;
	float size = 1.0;
	if (season == 0) { pc = vec3(0.75, 0.85, 1.0); speed = 9.0; sway = 0.0; density = 0.62; size = 0.6; }
	else if (season == 1) { pc = vec3(1.0, 0.95, 0.5); speed = -0.25; sway = 0.6; density = 0.82; size = 0.7; }
	else if (season == 2) { pc = vec3(0.95, 0.5, 0.15); speed = 1.2; sway = 0.9; density = 0.7; size = 1.3; }
	else { pc = vec3(1.0); speed = 1.6; sway = 0.4; density = 0.35; size = 1.2; }
	if (neon) { pc = mix(pc, vec3(0.2, 0.9, 1.0), 0.6); }
	for (int layer = 0; layer < 3; layer++) {
		float fl = float(layer);
		float scale = 46.0 + fl * 28.0;
		vec2 p = (px + cam * (0.25 + 0.2 * fl)) / scale;
		p.y -= t * speed * (0.6 + 0.3 * fl);
		p.x += sin(t * 0.8 + fl * 2.0 + p.y * 0.7) * sway;
		vec2 cell = floor(p);
		vec2 f = fract(p) - 0.5;
		float h = hash(cell + fl * 17.0);
		vec2 o = vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5;
		vec2 d2 = f - o * 0.6;
		if (season == 0) { d2.x *= 4.0; }  // rain: thin streaks
		float d = length(d2);
		float r = (0.025 + 0.03 * h) * size * (0.7 + 0.25 * fl);
		float a = smoothstep(r, r * 0.3, d) * step(density, h) * amount;
		if (season == 1) { a *= 0.5 + 0.5 * sin(t * 3.0 + h * 40.0); }
		col.rgb = mix(col.rgb, pc, a);
		col.a = max(col.a, a * (season == 0 ? 0.45 : 0.85));
	}
	COLOR = col;
}
"""

var info = null
var home
var engine
var skin := "classic"
var started := false
var result_recorded := false
var over_t: float = 0.0
var chapter: int = 0          # story chapter being played
var prog: Dictionary = {"story": 0, "stars": {}, "daily_day": -1, "daily_streak": 0, "weekly_week": -1}

var field: Control
var hud: Control
var weather: ColorRect
var end_dialog: Control
var next_btn: Button
var grass_tex: Texture2D
var scenery: Array = []      # [texture, world pos, scale, season mask]
var cam := Vector2(E.W / 2.0, E.H / 2.0)
var puffs: Array = []        # [pos, age, colour]
var banner := ""
var banner_t: float = 0.0
var step_t: float = 0.0
var music_t: float = 0.0
var music_style := ""
var reduce_fx := false
var touch_pad: Control = null
var finger := -1              # touch index steering without the Pad
var finger_pos := Vector2.ZERO

func _ready() -> void:
	Orientation.lock_portrait()
	preload("res://scripts/games/wolf_pack/wolf_pack_i18n.gd").install(self)
	engine = E.new()
	engine.reset("year", 1, 4242)
	_load_progress()
	_read_fx()
	_make_scenery()
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
	weather = ColorRect.new()
	weather.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = WEATHER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	weather.material = mat
	weather.visible = false
	add_child(weather)
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
		{"text": tr("Next chapter"), "action": _next_chapter},
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	next_btn = _find_button(end_dialog, tr("Next chapter"))
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
		"title_colors": [Color("eef3f8"), Color("a8c4e0"), Color("eef3f8"), Color("c9d8e8")],
		"landing_colors": [Color("060b18"), Color("1b2c44")],
		"landing_stars": 90,
		"menu_color": Color("ffd98a"),
		"help": HELP,
		"info": info,
		"accent": Color("8fb4d8"),
		"solo_heading": "Free Hunt",
		"subtitle": "Lead the pack, hunt together, live through the winter.",
		"logo": _draw_home_logo,
		"modes": modes,
		"play": [
			{"text": "🌙 Story", "sub": "The Long Winter · 8 chapters", "action": _open_story, "card": true},
			{"text": "🎯 Challenges", "sub": "Daily Hunt · Weekly Trial", "action": _open_challenges, "card": true},
		],
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

func _find_button(n: Node, text: String) -> Button:
	for ch in n.get_children():
		if ch is Button and ch.text == text:
			return ch
		var f := _find_button(ch, text)
		if f:
			return f
	return null

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

func _read_fx() -> void:
	var d = SaveUtil.read("user://fx.json")
	reduce_fx = d is Dictionary and bool(d.get("reduce", false))

# ---------- progress (story, daily, weekly) ----------

func _load_progress() -> void:
	var d = SaveUtil.read(PROGRESS_PATH)
	if d is Dictionary:
		for k in prog:
			if d.has(k):
				prog[k] = d[k]

func _save_progress() -> void:
	SaveUtil.write(PROGRESS_PATH, prog)

## Days since 1970-01-01 for today's local date (everyone gets the same Daily Hunt per date).
func _today() -> int:
	var d := Time.get_date_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 0, "minute": 0, "second": 0}) / 86400)

## Weeks start on Monday (1970-01-01 was a Thursday).
func _this_week() -> int:
	return floori((_today() + 3) / 7.0)

func _story_stars() -> int:
	var n := 0
	for k in prog.stars:
		n += int(prog.stars[k])
	return n

# ---------- menus ----------

func _open_story() -> void:
	var parts: Array = home.card("🌙 " + tr("The Long Winter"))
	var body: VBoxContainer = parts[1]
	body.add_child(_note(tr("Grey and Ash start a pack of their own. Stars: %d / %d") % [_story_stars(), E.STORY.size() * 3]))
	for n in E.STORY.size():
		var c: Dictionary = E.STORY[n]
		var open: bool = n <= int(prog.story)
		var st := int(prog.stars.get(str(n), 0))
		var btn := Button.new()
		var line := tr("Chapter %d") % (n + 1) + ": " + tr(c.title)
		btn.text = (line + "   " + "★".repeat(st) + "☆".repeat(3 - st)) if open else "🔒 " + line
		btn.disabled = not open
		btn.custom_minimum_size = Vector2(0, 62)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.pressed.connect(_open_chapter.bind(n, parts[0]))
		body.add_child(btn)
	home.show_card(parts[0])

## The chapter's story page, its goal, and Start.
func _open_chapter(n: int, prev: Control) -> void:
	home.close_card(prev)
	var c: Dictionary = E.STORY[n]
	var parts: Array = home.card(tr("Chapter %d") % (n + 1) + ": " + tr(c.title))
	var body: VBoxContainer = parts[1]
	var txt := _note(tr(c.text))
	txt.add_theme_font_size_override("font_size", 24)
	body.add_child(txt)
	body.add_child(_note("🎯 " + _goal_text(c.goal, 1) + "\n" + tr("Season: %s · Pack: %d wolves") % [tr(E.SEASONS[c.season]), int(c.pack)]))
	body.add_child(_start_button(_start_story.bind(n), parts[0]))
	home.show_card(parts[0])

func _open_challenges() -> void:
	var parts: Array = home.card("🎯 " + tr("Challenges"))
	var body: VBoxContainer = parts[1]
	var dopt: Dictionary = E.daily_opts(_today())
	var done_today: bool = int(prog.daily_day) == _today()
	body.add_child(_heading("📅 " + tr("Daily Hunt")))
	body.add_child(_note(_goal_text(dopt.goal, 1) + " · " + tr(E.SEASONS[dopt.season]) + "\n" +
		(tr("✔ Done today! Streak: %d days") % int(prog.daily_streak) if done_today else tr("A new hunt every day, the same for everyone. Streak: %d days") % int(prog.daily_streak))))
	body.add_child(_start_button(_start_daily, parts[0]))
	var wopt: Dictionary = E.weekly_opts(_this_week())
	var done_week: bool = int(prog.weekly_week) == _this_week()
	body.add_child(_heading("📆 " + tr("Weekly Trial")))
	body.add_child(_note(_goal_text(wopt.goal, 4) + " · " + tr("a whole year on Hard") + "\n" +
		(tr("✔ Done this week!") if done_week else tr("A new trial every Monday."))))
	body.add_child(_start_button(_start_weekly, parts[0]))
	home.show_card(parts[0])

func _note(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _heading(t: String) -> Label:
	var l := _note(t)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color("ffd98a"))
	return l

func _start_button(action: Callable, c: Control) -> Button:
	var b: Button = HomeKit.neon_button("▶ " + tr("Start"), HomeKit.LIME, 28, 80)
	b.pressed.connect(_pick.bind(action, c))
	return b

func _pick(action: Callable, c: Control) -> void:
	home.close_card(c)
	home.play_now(action)

## "Catch 5 hares", "Eat 300 kg of meat"... seasons = how long the run lasts.
func _goal_text(g: Dictionary, seasons: int) -> String:
	var n := int(g.get("n", 0))
	match str(g.get("type", "")):
		"catch":
			if n == 1:
				return tr({"hare": "Catch a hare", "deer": "Bring down a deer", "elk": "Bring down an elk", "bison": "Bring down a bison"}[g.kind])
			return tr({"hare": "Catch %d hares", "deer": "Bring down %d deer", "elk": "Bring down %d elk", "bison": "Bring down %d bison"}[g.kind]) % n
		"meat":
			return tr("Eat %d kg of meat") % n
		"pack":
			return tr("Grow the pack to %d wolves") % n
		"survive":
			return (tr("End the year with %d wolves or more") if seasons >= 4 else tr("End the season with %d wolves or more")) % n
	return ""

# ---------- flow ----------

func _new_game(m: String, d: int) -> void:
	engine.reset(m, d, randi() % 1000000)
	SaveUtil.delete(SAVE_PATH)
	_begin()

func _start_story(n: int) -> void:
	chapter = n
	SaveUtil.delete(SAVE_PATH)
	engine.reset("story", 1, 900 + n * 31, E.story_opts(n))
	_begin()

func _start_daily() -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset("daily", 1, _today(), E.daily_opts(_today()))
	_begin()

func _start_weekly() -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset("weekly", 2, _this_week() * 101, E.weekly_opts(_this_week()))
	_begin()

func _restart() -> void:
	match engine.mode:
		"story":
			_start_story(chapter)
		"daily":
			_start_daily()
		"weekly":
			_start_weekly()
		_:
			_new_game(engine.mode, engine.diff)

func _next_chapter() -> void:
	_start_story(mini(chapter + 1, E.STORY.size() - 1))

func _begin() -> void:
	started = true
	result_recorded = false
	over_t = 0.0
	puffs.clear()
	finger = -1
	end_dialog.visible = false
	cam = engine.leader().p
	music_style = ""
	music_t = 0.0
	_read_fx()
	if touch_pad:
		touch_pad.release_all()
	if engine.goal.is_empty():
		_show_banner(tr(E.SEASONS[engine.season()]))
	else:
		_show_banner("🎯 " + _goal_text(engine.goal, engine.limit), 3.5)
	SoundLib.play(self, "ui/select", -8.0)

func _show_banner(t: String, secs: float = 2.2) -> void:
	banner = t
	banner_t = secs

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
		if event.pressed and finger == -1 and event.position.y > 150.0:
			finger = event.index
			finger_pos = event.position
		elif not event.pressed and event.index == finger:
			finger = -1
	elif event is InputEventScreenDrag and event.index == finger:
		finger_pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		finger = 0 if event.pressed and event.position.y > 150.0 else -1
		finger_pos = event.position
	elif event is InputEventMouseMotion and finger == 0 and not DisplayServer.is_touchscreen_available():
		finger_pos = event.position

# ---------- loop ----------

func _process(delta: float) -> void:
	var playing: bool = started and not engine.is_over()
	if touch_pad:
		touch_pad.visible = playing
	weather.visible = started or engine.is_over()
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
			step_t = 0.3
			SoundLib.play(self, "impact/footstep_snow" if engine.season() == 3 else "impact/footstep_grass", -20.0)
	cam = cam.lerp(L.p + L.v * 0.35, minf(1.0, delta * 3.0))
	var half := size / 2.0
	cam.x = clampf(cam.x, minf(half.x, E.W / 2.0), maxf(E.W - half.x, E.W / 2.0))
	cam.y = clampf(cam.y, minf(half.y, E.H / 2.0), maxf(E.H - half.y, E.H / 2.0))
	_update_music(delta)
	var mat := weather.material as ShaderMaterial
	mat.set_shader_parameter("season", engine.season())
	mat.set_shader_parameter("t", engine.time)
	mat.set_shader_parameter("cam", cam)
	mat.set_shader_parameter("area", size)
	mat.set_shader_parameter("amount", 0.0 if reduce_fx else 1.0)
	mat.set_shader_parameter("neon", skin == "voodoo")
	if engine.is_over():
		over_t += delta
		if over_t > 1.2 and not result_recorded:
			_game_over()
	field.queue_redraw()
	hud.queue_redraw()

## Calm music while roaming; lively while the pack chases an elk or a bison.
func _update_music(delta: float) -> void:
	music_t -= delta
	if music_t > 0.0:
		return
	music_t = 1.0
	var want := "calm"
	var L: Dictionary = engine.leader()
	for pr in engine.prey:
		if pr.kind in ["elk", "bison"] and pr.v.length() > 90.0 and pr.p.distance_to(L.p) < 320.0:
			want = "lively"
	if want != music_style:
		music_style = want
		_music("play", want, engine.season(), 2.5)

func _handle(evs: Array) -> void:
	for e in evs:
		match e[0]:
			"catch":
				puffs.append([e[2], 0.0, Color(1, 1, 1)])
				SoundLib.play(self, "impact/soft_heavy" if e[1] in ["elk", "bison"] else "impact/soft_medium", -6.0)
				if e[1] != "hare":
					SoundLib.play(self, "reward/coin_short", -10.0)
				var gp: Array = engine.goal_progress()
				var line := tr("+%d kg") % int(E.PREY[e[1]].kg)
				if not engine.goal.is_empty() and engine.goal.get("type", "") != "survive":
					line += "   🎯 %d/%d" % [mini(gp[0], gp[1]), gp[1]]
				_show_banner(line)
			"kick":
				puffs.append([e[1], 0.0, Color("ffcf7a")])
				SoundLib.play(self, "impact/punch_medium", -6.0)
				_vibrate(60)
			"pup":
				SoundLib.play(self, "reward/powerup", -6.0)
				_show_banner(tr("A pup joins the pack!"))
			"leave":
				SoundLib.play(self, "ui/wrong", -6.0)
				_show_banner(tr("Too hungry: a wolf left the pack"))
				_vibrate(120)
			"season":
				SoundLib.play(self, "ui/select", -8.0)
				_show_banner(tr(E.SEASONS[e[1]]))
				music_style = ""
				music_t = 0.0
			"goal":
				SoundLib.play(self, "reward/accomplished")
				_show_banner(tr("Goal reached!"))

func _game_over() -> void:
	result_recorded = true
	started = false
	SaveUtil.delete(SAVE_PATH)
	next_btn.visible = false
	var msg := ""
	var won: bool = engine.won
	if won:
		SoundLib.play(self, "jingles/win_succeeded")
	else:
		SoundLib.play(self, "jingles/lose_failed")
	match engine.mode:
		"story":
			if won:
				var st := _stars()
				msg = tr("Chapter %d done!") % (chapter + 1) + "\n" + "★".repeat(st) + "☆".repeat(3 - st)
				prog.stars[str(chapter)] = maxi(int(prog.stars.get(str(chapter), 0)), st)
				prog.story = maxi(int(prog.story), mini(chapter + 1, E.STORY.size() - 1))
				if chapter + 1 >= E.STORY.size():
					prog["done"] = true
					msg += "\n" + tr("The valley is yours. The story is complete!")
				else:
					next_btn.visible = true
				if info:
					info.high("Story stars", _story_stars())
					info.high("Story chapters done", int(prog.story) + (1 if prog.get("done", false) else 0))
			else:
				msg = _fail_text()
		"daily":
			if won:
				var today := _today()
				if int(prog.daily_day) != today:
					prog.daily_streak = int(prog.daily_streak) + 1 if int(prog.daily_day) == today - 1 else 1
					prog.daily_day = today
					if info:
						info.add("Daily hunts won")
						info.high("Best daily streak", int(prog.daily_streak))
				msg = tr("Daily Hunt done! Streak: %d days") % int(prog.daily_streak)
			else:
				msg = _fail_text()
		"weekly":
			if won:
				if int(prog.weekly_week) != _this_week():
					prog.weekly_week = _this_week()
					if info:
						info.add("Weekly trials won")
				msg = tr("Weekly Trial done!")
			else:
				msg = _fail_text()
		_:
			if won:
				var n: int = engine.pack_size()
				var stars := 3 if n >= 8 else (2 if n >= 5 else 1)
				msg = tr("The pack lived through the year!") + "\n" + "★".repeat(stars) + "☆".repeat(3 - stars)
			else:
				msg = tr("The leader starved. The hunt is over.")
	_save_progress()
	msg += "\n" + tr("Meat: %d kg · Pack: %d wolves") % [engine.meat, engine.pack_size()]
	if info:
		info.result("win" if won else "loss")
		info.high("Best score", engine.meat)
		info.add("Games played")
		info.high("Biggest pack", engine.biggest)
		if engine.mode in ["year", "endless"]:
			var years: int = 1 if won else engine.year()
			if years > 0:
				info.high("Years survived", years)
		for k in [["hare", "Hares caught"], ["deer", "Deer caught"], ["elk", "Elk caught"], ["bison", "Bison caught"]]:
			if engine.kills[k[0]] > 0:
				info.add(k[1], engine.kills[k[0]])
		msg += "\n" + info.summary(["Best score", "Biggest pack"])
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	_music("stop", "")

func _fail_text() -> String:
	if engine.hunger <= 0.0:
		return tr("The leader starved. The hunt is over.")
	var gp: Array = engine.goal_progress()
	return tr("Time is up: %d / %d. Try again!") % [gp[0], gp[1]]

## Story stars: time to spare (or, for survive goals, wolves to spare).
func _stars() -> int:
	if engine.goal.get("type", "") == "survive":
		var extra: int = engine.pack_size() - int(engine.goal.n)
		return 3 if extra >= 2 else (2 if extra >= 1 else 1)
	var left: float = engine.time_left() / E.SEASON_LEN
	return 3 if left >= 0.4 else (2 if left >= 0.15 else 1)

# ---------- scenery ----------

func _make_scenery() -> void:
	grass_tex = SpriteLib.texture("textures/floor_ground_grass")
	scenery.clear()
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for s in SCENERY:
		var tex: Texture2D = SpriteLib.texture(s[0])
		if tex == null:
			continue
		for i in int(s[3]):
			scenery.append([tex, Vector2(r.randf_range(40, E.W - 40), r.randf_range(40, E.H - 40)), float(s[1]), int(s[2])])
	# Back to front, so lower things draw over higher ones.
	scenery.sort_custom(func(a, b): return a[1].y < b[1].y)

# ---------- drawing ----------

func _w2s(p: Vector2) -> Vector2:
	return p - cam + size / 2.0

func _draw_field() -> void:
	var c := field
	var sea: int = engine.season()
	var neon := skin == "voodoo"
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.08))
	var origin := _w2s(Vector2.ZERO)
	if grass_tex:
		var tint: Color = TINT[sea]
		if neon:
			tint = Color(0.32, 0.28, 0.6)
		c.draw_set_transform(origin, 0.0, Vector2(2, 2))
		c.draw_texture_rect(grass_tex, Rect2(Vector2.ZERO, Vector2(E.W, E.H) / 2.0), true, tint)
		c.draw_set_transform(Vector2.ZERO)
	else:
		c.draw_rect(Rect2(origin, Vector2(E.W, E.H)), Color("5f9a3e"))
	if sea == 3 and not neon:
		c.draw_rect(Rect2(origin, Vector2(E.W, E.H)), Color(0.93, 0.96, 1.0, 0.82))
	var view := Rect2(cam - size / 2.0 - Vector2(140, 200), size + Vector2(280, 400))
	var bit := 1 << sea
	var snow := sea == 3 and not neon
	var smod := Color(0.85, 0.9, 1.05) if snow else (Color(0.5, 0.45, 0.9) if neon else Color.WHITE)
	if sea == 2 and not neon:
		smod = Color(1.45, 0.8, 0.4)
	# Ground cover first (flat things), then animals, then the tall things over them.
	var t: float = engine.time
	for s in scenery:
		if s[3] & bit and view.has_point(s[1]) and (s[0] as Texture2D).get_height() <= 20:
			_draw_sprite(c, s, smod)
	for pr in engine.prey:
		if view.has_point(pr.p):
			_draw_prey(c, pr, t)
	for i in range(engine.wolves.size() - 1, -1, -1):
		var w: Dictionary = engine.wolves[i]
		if view.has_point(w.p):
			_draw_wolf(c, _w2s(w.p), w.v, t + i * 0.37, i == 0, WOLF_SIZE)
	for s in scenery:
		if s[3] & bit and view.has_point(s[1]) and (s[0] as Texture2D).get_height() > 20:
			_draw_sprite(c, s, smod)
			if snow and (s[0] as Texture2D).get_height() > 40:
				# Snow on the crown.
				var sz: Vector2 = (s[0] as Texture2D).get_size() * float(s[2])
				var top := _w2s(s[1]) - Vector2(sz.x * 0.25, sz.y * 0.95)
				c.draw_rect(Rect2(top, Vector2(sz.x * 0.5, 6)), Color(1, 1, 1, 0.9))
	for p in puffs:
		var a: float = 1.0 - p[1] / 0.7
		var sz2: float = 18.0 + p[1] * 60.0
		var q := _w2s(p[0])
		c.draw_rect(Rect2(q - Vector2(sz2, sz2) / 2.0, Vector2(sz2, sz2)), Color(p[2], 0.35 * a))

## A scenery sprite stands on its point (bottom centre).
func _draw_sprite(c: CanvasItem, s: Array, mod: Color) -> void:
	var tex: Texture2D = s[0]
	var sz: Vector2 = tex.get_size() * float(s[2])
	var p := _w2s(s[1])
	c.draw_texture_rect(tex, Rect2(p - Vector2(sz.x / 2.0, sz.y), sz), false, mod)

## A wolf from above, all thick lines: body, head, ears, tail, legs.
func _draw_wolf(c: CanvasItem, p: Vector2, v: Vector2, t: float, lead: bool, k: float) -> void:
	var cols: Array = WOLF_COL[skin]
	var d: Vector2 = v.normalized() if v.length() > 8.0 else Vector2.UP
	var sd := d.orthogonal()
	var run := sin(t * 14.0) * clampf(v.length() / 200.0, 0.0, 1.0)
	var body: Color = cols[0]
	var light: Color = cols[1]
	if engine.season() == 3 and skin == "classic":
		body = body.darkened(0.15)   # stands out on snow
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
		# The leader's mark: a small gold chevron above it.
		var m := p + Vector2(0, -30) * k
		var gold := Color("ffd24a") if skin == "classic" else Color("ff2bd6")
		c.draw_line(m + Vector2(-8, -5) * k, m, gold, 4.0 * k)
		c.draw_line(m, m + Vector2(8, -5) * k, gold, 4.0 * k)

func _draw_prey(c: CanvasItem, pr: Dictionary, t: float) -> void:
	var k: Dictionary = E.PREY[pr.kind]
	var p := _w2s(pr.p)
	var d: Vector2 = pr.v.normalized() if pr.v.length() > 5.0 else Vector2.RIGHT.rotated(pr.wander)
	var sd := d.orthogonal()
	var r: float = k.r * PREY_SIZE
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
	# Hold meter: how close the pack is to bringing it down.
	if pr.hold > 0.0 and float(k.hold) > 0.0:
		var f: float = clampf(pr.hold / float(k.hold), 0.0, 1.0)
		c.draw_rect(Rect2(p + Vector2(-r, -r - 16), Vector2(r * 2.0, 6)), Color(0, 0, 0, 0.5))
		c.draw_rect(Rect2(p + Vector2(-r, -r - 16), Vector2(r * 2.0 * f, 6)), Color("ffd24a"))
	var L: Dictionary = engine.leader()
	if int(k.need) > 1 and L.p.distance_to(pr.p) < 300.0:
		var tag := "🐺×%d" % int(k.need)
		var tc := Color("ffd24a") if engine.pack_size() >= int(k.need) else Color("ff6a5a")
		c.draw_string_outline(ThemeDB.fallback_font, p + Vector2(-40, -r - 22), tag, HORIZONTAL_ALIGNMENT_CENTER, 80, 18, 4, Color(0, 0, 0, 0.7))
		c.draw_string(ThemeDB.fallback_font, p + Vector2(-40, -r - 22), tag, HORIZONTAL_ALIGNMENT_CENTER, 80, 18, tc)

func _draw_hud() -> void:
	if not started and not engine.is_over():
		return
	var c := hud
	var font := ThemeDB.fallback_font
	var x := 16.0
	var y := 30.0
	var bw := clampf(size.x - 140.0, 160.0, 460.0)
	var has_goal: bool = not engine.goal.is_empty()
	var box_h := 130.0 if has_goal else 104.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.08, 0.62)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	c.draw_style_box(sb, Rect2(x - 8, y - 8, bw + 16, box_h + 6))
	var head_text := tr(E.SEASONS[engine.season()])
	if engine.mode == "endless":
		head_text += " · " + tr("Year %d") % (engine.year() + 1)
	var tl: float = engine.time_left() if engine.time_left() >= 0.0 else engine.season_left()
	head_text += "  %d:%02d" % [int(tl) / 60, int(tl) % 60]
	c.draw_string(font, Vector2(x, y + 18), head_text, HORIZONTAL_ALIGNMENT_LEFT, bw * 0.62, 20, Color(0.95, 0.95, 0.95))
	c.draw_string(font, Vector2(x, y + 18), "🐺 %d   %d kg" % [engine.pack_size(), engine.meat], HORIZONTAL_ALIGNMENT_RIGHT, bw, 20, Color("ffd24a"))
	var f: float = engine.hunger / 100.0
	var hc := Color("5be36a") if f > 0.5 else (Color("ffb02e") if f > 0.25 else Color("ff4a3a"))
	_bar(c, x, y + 30, bw, tr("Hunger"), f, hc, 14.0)
	_bar(c, x, y + 56, bw, tr("Pups"), clampf(engine.spare / E.GROW_AT, 0.0, 1.0), Color("8fb4d8"), 9.0)
	_bar(c, x, y + 78, bw, tr("Sprint"), engine.stamina, Color("ffd24a"), 9.0)
	if has_goal:
		var gp: Array = engine.goal_progress()
		var done: bool = gp[0] >= gp[1]
		c.draw_string(font, Vector2(x, y + 120), "🎯 " + _goal_text(engine.goal, engine.limit), HORIZONTAL_ALIGNMENT_LEFT, bw - 70, 18, Color("ffd98a"))
		c.draw_string(font, Vector2(x, y + 120), "%d/%d" % [mini(gp[0], gp[1]) if not done else gp[0], gp[1]], HORIZONTAL_ALIGNMENT_RIGHT, bw, 18, Color("5be36a") if done else Color.WHITE)
	if not touch_pad and finger != -1:
		c.draw_arc(finger_pos, 30, 0, TAU, 24, Color(1, 1, 1, 0.5), 2.0)
	if banner_t > 0.0 and banner != "":
		var a := clampf(banner_t, 0.0, 1.0)
		var by := size.y * 0.32
		c.draw_string_outline(font, Vector2(16, by), banner, HORIZONTAL_ALIGNMENT_CENTER, size.x - 32, 32, 12, Color(0.02, 0.04, 0.1, 0.9 * a))
		c.draw_string(font, Vector2(16, by), banner, HORIZONTAL_ALIGNMENT_CENTER, size.x - 32, 32, Color(1, 1, 1, a))

func _bar(c: CanvasItem, x: float, y: float, bw: float, label: String, f: float, col: Color, h: float) -> void:
	c.draw_string(ThemeDB.fallback_font, Vector2(x, y + h), label, HORIZONTAL_ALIGNMENT_LEFT, 88, 16, Color(0.85, 0.85, 0.85))
	c.draw_rect(Rect2(x + 90, y + 2, bw - 90, h), Color(1, 1, 1, 0.13))
	c.draw_rect(Rect2(x + 90, y + 2, (bw - 90) * clampf(f, 0.0, 1.0), h), col)

## Landing art: a big moon over a pine forest, three wolves howling on a rock.
func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 300.0, c.size.x / 360.0)
	var o := c.size / 2.0
	var moon := Color("f4f1de") if skin == "classic" else Color("29e6ff")
	var mc := o + Vector2(70, -55) * k
	for i in 4:
		c.draw_circle(mc, (64.0 + i * 16.0) * k, Color(moon, 0.06))
	c.draw_circle(mc, 58.0 * k, moon)
	c.draw_circle(mc + Vector2(-16, -12) * k, 9.0 * k, Color(moon.darkened(0.08)))
	c.draw_circle(mc + Vector2(14, 16) * k, 6.0 * k, Color(moon.darkened(0.08)))
	var far := Color("142238") if skin == "classic" else Color("1a1040")
	var near := Color("070c18")
	# Far pines, then near pines.
	for i in 13:
		_pine(c, o + Vector2(-190 + i * 32, 95 + (i % 3) * 6) * k, (50.0 + (i * 37 % 5) * 9.0) * k, far)
	for i in 7:
		_pine(c, o + Vector2(-200 + i * 66 + (i % 2) * 18, 128) * k, (70.0 + (i * 53 % 4) * 12.0) * k, near)
	# The rock, rising in front of the moon, with the howlers on top against it.
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(-40, 132) * k, o + Vector2(0, 40) * k, o + Vector2(30, 8) * k,
		o + Vector2(70, 2) * k, o + Vector2(118, 10) * k, o + Vector2(150, 60) * k, o + Vector2(190, 132) * k]), near)
	_howler(c, o + Vector2(14, 26) * k, k * 1.1, near, false)
	_howler(c, o + Vector2(74, 6) * k, k * 1.4, near, false)
	_howler(c, o + Vector2(140, 34) * k, k * 1.05, near, true)
	c.draw_rect(Rect2(o + Vector2(-220, 128) * k, Vector2(440, 40) * k), near)

func _pine(c: CanvasItem, base: Vector2, h: float, col: Color) -> void:
	for j in 3:
		var w := h * (0.42 - j * 0.1)
		var y0 := base.y - h * (0.15 + j * 0.27)
		c.draw_colored_polygon(PackedVector2Array([Vector2(base.x - w, y0), Vector2(base.x, y0 - h * 0.42), Vector2(base.x + w, y0)]), col)
	c.draw_rect(Rect2(base.x - h * 0.04, base.y - h * 0.18, h * 0.08, h * 0.18), col)

## A sitting wolf, side view, muzzle up to the moon (flip = facing left).
func _howler(c: CanvasItem, p: Vector2, k: float, col: Color, flip: bool) -> void:
	var sx := -1.0 if flip else 1.0
	var parts := [
		[Vector2(-18, -6), Vector2(-4, -40), Vector2(8, -44), Vector2(12, -28), Vector2(8, 0), Vector2(-20, 0)],   # body
		[Vector2(-2, -40), Vector2(8, -46), Vector2(20, -70), Vector2(11, -73)],                                    # neck
		[Vector2(10, -72), Vector2(20, -70), Vector2(31, -88), Vector2(27, -90), Vector2(13, -81)],                 # head
		[Vector2(10, -75), Vector2(6, -87), Vector2(15, -79)],                                                       # ear
		[Vector2(-18, -3), Vector2(-36, -1), Vector2(-40, 3), Vector2(-16, 3)],                                     # tail
		[Vector2(3, -24), Vector2(9, -24), Vector2(10, 0), Vector2(4, 0)],                                           # front leg
	]
	c.draw_circle(p + Vector2(-10 * sx, -12) * k, 13.0 * k, col)
	for part in parts:
		var pts := PackedVector2Array()
		for q in part:
			pts.append(p + Vector2(q.x * sx, q.y) * k)
		c.draw_colored_polygon(pts, col)

# ---------- skins ----------

func _set_skin(s: String) -> void:
	skin = "voodoo" if s == "voodoo" else "classic"
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
	SaveUtil.write(SAVE_PATH, {"engine": engine.to_dict(), "chapter": chapter})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary) or not d.has("engine"):
		return ""
	var e: Dictionary = d.engine
	var t := ""
	match str(e.get("mode", "year")):
		"endless":
			t = tr("Endless")
		"story":
			t = tr("Chapter %d") % (int(d.get("chapter", 0)) + 1)
		"daily":
			t = tr("Daily Hunt")
		"weekly":
			t = tr("Weekly Trial")
		_:
			t = tr("One Year") + " (" + tr(LEVELS[clampi(int(e.get("diff", 1)), 0, 2)]) + ")"
	return t + " · " + tr(E.SEASONS[int(float(e.get("time", 0.0)) / E.SEASON_LEN) % 4])

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary) or not d.has("engine"):
		_new_game("year", 1)
		return
	chapter = int(d.get("chapter", 0))
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
