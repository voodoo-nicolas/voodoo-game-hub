extends Control

## Bug Chain: chains of coloured beetles crawl along garden paths toward a
## pit. Slide the bug launcher along the bottom rail and fire bugs straight
## up into a chain: three or more of a colour touching pop. Gaps whose edges
## match pull back together for chain reactions. Rules: bug_chain_engine.gd;
## art: bug_chain_art.gd (all drawn in code).

const E = preload("res://scripts/games/bug_chain/bug_chain_engine.gd")
const Art = preload("res://scripts/games/bug_chain/bug_chain_art.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const HomeKit = preload("res://scripts/games/bug_chain/home_kit.gd")
const SoundLib = preload("res://scripts/games/bug_chain/sound_lib.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const VOODOO_PATH := "res://scripts/common/voodoo.gd"
const HELP := preload("res://scripts/games/bug_chain/bug_chain_help.gd")
const SAVE_PATH := "user://bug_chain_save.json"
const PREFS_PATH := "user://bug_chain_prefs.json"
const ART_DIR := "user://bug_chain_art/"
const ART_VERSION := 1

const DIFFS := ["Easy", "Normal", "Hard"]
const SHAPE_NAMES := {"meadow": "Meadow", "spiral": "Snail Shell", "zigzag": "Zigzag",
	"hook": "Horseshoe", "wave": "Creek", "twin": "Two Trails"}
const START_LIVES := 3
const MAX_LIVES := 5
const LIFE_EVERY := 25000
const RELOAD := 0.22
const POWER_ICONS := {E.P_BOMB: "💣", E.P_SLOW: "⏳", E.P_REVERSE: "⏪", E.P_RAINBOW: "🌈"}

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var prefs: Dictionary = {}
var skin := "classic"
var bugs: Array = []  # [colour][frame] textures for the current skin
var logo_bugs: Array = []  # Classic set for the Landing logo
var disc_tex: Texture2D
var dot_tex: Texture2D
var grass_tex: Texture2D
var voodoo_script = null

var mode := "campaign"  # "campaign" / "endless"
var diff := 1
var level := 1
var lives := START_LIVES
var next_life := LIFE_EVERY
var started := false
var over := false
var between := false  # level cleared / lost, waiting for the next one
var cur := 0
var nxt := 0
var shooter_x := 50.0
var reload := 0.0
var dragging := false
var drag_from := Vector2.ZERO
var drag_moved := 0.0
var key_dir := 0.0
var bits: Array = []  # [pos, vel, colour, life] in field units
var floats: Array = []  # [pos, text, colour, life]
var danger_t := 0.0
var flash := 0.0
var result_sent := false
var run_levels := 0
var run_chain := 0

var board: Control
var backdrop: Control
var score_label: Label
var info_label: Label
var end_dialog: Control
var _geo_key := ""
var _paths: Array = []  # screen-space points per track

func _ready() -> void:
	preload("res://scripts/games/bug_chain/bug_chain_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = E.new()
	var p = SaveUtil.read(PREFS_PATH)
	prefs = p if p is Dictionary else {}
	diff = clampi(int(prefs.get("diff", 1)), 0, 2)
	if ResourceLoader.exists(VOODOO_PATH):
		voodoo_script = load(VOODOO_PATH)
	disc_tex = Art.disc()
	dot_tex = Art.dot()
	# Made before the UI: the Landing logo draws once, so its textures must exist first.
	logo_bugs = _load_bugs(false)
	bugs = logo_bugs
	_build_ui()
	_play_music()
	_start_level(1)
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 16)
	top.add_theme_constant_override("margin_left", 12)
	top.add_theme_constant_override("margin_right", 12)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(72, 60)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 34)
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(score_label)
	var help_btn: Button = home_help_placeholder()
	bar.add_child(help_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 20)
	info_label.add_theme_constant_override("outline_size", 6)
	info_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(info_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(_on_board_resized)
	board.clip_contents = true
	var bm := MarginContainer.new()
	bm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm.add_theme_constant_override("margin_bottom", 10)
	bm.add_child(board)
	root.add_child(bm)
	# The board's backdrop sits behind everything (grass / dark), under the bars too.
	var back := Control.new()
	backdrop = back
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.draw.connect(_draw_backdrop.bind(back))
	back.resized.connect(back.queue_redraw)
	add_child(back)
	move_child(back, 0)

	end_dialog = UI.build_dialog("", [
		{"text": tr("▶ Next level"), "action": _on_dialog_main},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": Color("ff5a4a"),
		"subtitle": "Fire bugs into the crawling chain. Three of a colour pop. Keep them out of the pit!",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🌿 Campaign", "sub": "30 levels · 6 garden paths", "action": _new_campaign},
			{"text": "♾ Endless", "sub": "Wave after wave, faster and faster", "action": _new_endless},
		],
		"play": [
			{"text": "📋 Level Select", "sub": "Replay any level you have reached", "action": _open_level_select, "card": true},
		],
		"extra": _add_extra,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [
			{"text": "⏪ Push the chains back", "how": "Every chain crawls backwards for a few seconds.", "action": _help_reverse},
			{"text": "💣 Blast the front bugs", "how": "The 8 bugs nearest each pit pop.", "action": _help_blast},
		],
		"board": "Best score",
		"board_note": "Points from popping bugs, chain reactions and level bonuses, in one game.",
	})
	add_child(home)
	home.track_help_button(help_btn, "⏪")
	if info:
		add_child(info)

## A 💡-style button in the top bar that opens the first help (the kit counts it).
func home_help_placeholder() -> Button:
	var b := Button.new()
	b.text = "⏪"
	b.custom_minimum_size = Vector2(96, 60)
	b.pressed.connect(_on_help_button)
	return b

func _on_help_button() -> void:
	if home:
		home.try_help(_help_reverse)

func _add_extra(box: Control) -> void:
	box.add_child(home.section("Difficulty"))
	box.add_child(home.choice_row(DIFFS, diff, _pick_diff))

func _pick_diff(i: int) -> void:
	diff = i
	prefs["diff"] = i
	SaveUtil.write(PREFS_PATH, prefs)

func _on_board_resized() -> void:
	_geo_key = ""
	board.queue_redraw()

# ---------- art ----------

## Bug textures for a skin: built once, then kept as PNGs in user://.
func _load_bugs(voodoo: bool) -> Array:
	var out: Array = []
	var pal: Array = Art.VOODOO if voodoo else Art.CLASSIC
	DirAccess.make_dir_recursive_absolute(ART_DIR)
	for i in pal.size():
		var frames: Array = []
		for f in 2:
			var path := ART_DIR + "v%d_%s_%d_%d.png" % [ART_VERSION, "voodoo" if voodoo else "classic", i, f]
			var tex: Texture2D = null
			if FileAccess.file_exists(path):
				var img := Image.load_from_file(path)
				if img and img.get_width() == Art.SIZE:
					tex = ImageTexture.create_from_image(img)
			if tex == null:
				var made: ImageTexture = Art.bug(pal[i], i, f, voodoo)
				made.get_image().save_png(path)
				tex = made
			frames.append(tex)
		out.append(frames)
	return out

## Look (STANDARDS §9): "classic" = garden beetles on grass and a dirt path
## (default); "voodoo" = neon beetles on black, a skull for each pit.
func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	bugs = _load_bugs(skin == "voodoo")
	if skin == "classic" and grass_tex == null:
		grass_tex = Art.grass()
	if backdrop:
		backdrop.queue_redraw()
	var col := Color("fff4d6") if skin == "classic" else HomeKit.WHITE
	score_label.add_theme_color_override("font_color", col)
	info_label.add_theme_color_override("font_color", col.darkened(0.08))
	if board:
		board.queue_redraw()

func _voodoo() -> bool:
	return skin == "voodoo"

func _bug_color(c: int) -> Color:
	var pal: Array = Art.VOODOO if _voodoo() else Art.CLASSIC
	return pal[c % pal.size()] if c >= 0 else Color.WHITE

# ---------- game flow ----------

func _new_campaign() -> void:
	SaveUtil.delete(SAVE_PATH)
	_new_run("campaign", clampi(_reached(), 1, E.CAMPAIGN_LEVELS))

func _new_endless() -> void:
	SaveUtil.delete(SAVE_PATH)
	_new_run("endless", 1)

func _new_run(m: String, first: int) -> void:
	mode = m
	lives = START_LIVES
	engine.score = 0
	next_life = LIFE_EVERY
	result_sent = false
	run_levels = 0
	run_chain = 0
	over = false
	if info:
		info.add("Games played")
	_start_level(first)

func _restart() -> void:
	_new_run(mode, level if mode == "campaign" else 1)

func _start_level(n: int) -> void:
	level = n
	var spec: Dictionary = E.level_spec(n, diff)
	if mode == "endless":
		spec = _endless_spec(n)
	engine.setup(spec, rng)
	started = true
	between = false
	bits.clear()
	floats.clear()
	shooter_x = 50.0
	reload = 0.0
	cur = rng.randi_range(0, int(spec.colors) - 1)
	nxt = rng.randi_range(0, int(spec.colors) - 1)
	end_dialog.visible = false
	_geo_key = ""
	_update_labels()
	_float(Vector2(50, 60), tr("Level %d") % n if mode == "campaign" else tr("Wave %d") % n, Color.WHITE, 1.6)
	board.queue_redraw()

## Endless waves: random path, speed and colours climb with the wave.
func _endless_spec(n: int) -> Dictionary:
	var s: Dictionary = E.level_spec(mini(n + 4, 70), diff)
	s.n = n
	s.shape = E.SHAPES[rng.randi_range(0, E.SHAPES.size() - 1)]
	s.endless = true
	return s

func _reached() -> int:
	var r: Array = prefs.get("reached", [1, 1, 1])
	return int(r[diff]) if r.size() > diff else 1

func _set_reached(n: int) -> void:
	var r: Array = prefs.get("reached", [1, 1, 1]).duplicate()
	while r.size() < 3:
		r.append(1)
	r[diff] = maxi(int(r[diff]), mini(n, E.CAMPAIGN_LEVELS))
	prefs["reached"] = r
	SaveUtil.write(PREFS_PATH, prefs)

func _update_labels() -> void:
	score_label.text = _fmt(engine.score)
	var hearts := ""
	for i in lives:
		hearts += "❤"
	var where: String = tr(SHAPE_NAMES.get(engine.spec.get("shape", "meadow"), "Meadow"))
	var lvl_txt: String = (tr("Level %d") % level) if mode == "campaign" else (tr("Wave %d") % level)
	info_label.text = "%s · %s · %s · %s   %s" % [lvl_txt, where, tr(DIFFS[diff]), tr("%d bugs left") % engine.remaining(), hearts]

static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

# ---------- input ----------

func _to_units(p: Vector2) -> Vector2:
	return (p - _origin()) / _scale()

func _on_board_input(event: InputEvent) -> void:
	if not _playing():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var u := _to_units(event.position)
		if event.pressed:
			dragging = true
			drag_from = u
			drag_moved = 0.0
			if not _near_launcher(u):
				shooter_x = clampf(u.x, E.R, E.FIELD.x - E.R)
		elif dragging:
			dragging = false
			if _near_launcher(drag_from) and drag_moved < 3.0:
				_swap()
			else:
				_fire()
	elif event is InputEventMouseMotion and dragging:
		var u := _to_units(event.position)
		drag_moved += event.relative.length() / _scale()
		if drag_moved >= 3.0 or not _near_launcher(drag_from):
			shooter_x = clampf(u.x, E.R, E.FIELD.x - E.R)

func _near_launcher(u: Vector2) -> bool:
	return u.distance_to(Vector2(shooter_x, E.RAIL_Y)) < 7.0 or u.distance_to(_next_spot()) < 6.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not _playing() or not event is InputEventKey:
		return
	var k: InputEventKey = event
	if k.keycode in [KEY_LEFT, KEY_A]:
		key_dir = -1.0 if k.pressed else (0.0 if key_dir < 0 else key_dir)
	elif k.keycode in [KEY_RIGHT, KEY_D]:
		key_dir = 1.0 if k.pressed else (0.0 if key_dir > 0 else key_dir)
	elif k.pressed and not k.echo and k.keycode in [KEY_SPACE, KEY_UP, KEY_W]:
		_fire()
	elif k.pressed and not k.echo and k.keycode in [KEY_X, KEY_DOWN, KEY_S]:
		_swap()

func _playing() -> bool:
	return started and not over and not between and not engine.losing

func _swap() -> void:
	var t := cur
	cur = nxt
	nxt = t
	_sfx("toggle")
	board.queue_redraw()

func _fire() -> void:
	if reload > 0.0 or engine.shots.size() >= 2:
		return
	engine.fire(shooter_x, cur)
	reload = RELOAD
	SoundLib.play(self, "impact/soft_medium", -4.0)
	cur = nxt
	nxt = _pick_color()

func _pick_color() -> int:
	var present: Array = engine.colors_present()
	if present.is_empty():
		return rng.randi_range(0, int(engine.spec.colors) - 1)
	return present[rng.randi_range(0, present.size() - 1)]

## A colour that left the field is swapped for one still there.
func _refresh_colors() -> void:
	var present: Array = engine.colors_present()
	if present.is_empty():
		return
	if cur != E.RAINBOW and not present.has(cur):
		cur = _pick_color()
	if not present.has(nxt):
		nxt = _pick_color()

# ---------- frame ----------

func _process(delta: float) -> void:
	if not started:
		return
	delta = minf(delta, 0.05)
	reload = maxf(0.0, reload - delta)
	flash = maxf(0.0, flash - delta)
	if key_dir != 0.0 and _playing():
		shooter_x = clampf(shooter_x + key_dir * 70.0 * delta, E.R, E.FIELD.x - E.R)
	if not between and not over:
		var ev: Array = engine.update(delta)
		for e in ev:
			_on_event(e)
		if not ev.is_empty():
			_refresh_colors()
			_update_labels()
		if engine.in_danger():
			danger_t -= delta
			if danger_t <= 0.0:
				danger_t = lerpf(1.0, 0.35, clampf((engine.head_frac() - E.DANGER) / (1.0 - E.DANGER), 0.0, 1.0))
				_sfx("tick")
	for b in bits:
		b[0] += b[1] * delta
		b[1].y += 60.0 * delta
		b[3] -= delta
	bits = bits.filter(func(b): return b[3] > 0.0)
	for f in floats:
		f[0].y -= 6.0 * delta
		f[3] -= delta
	floats = floats.filter(func(f): return f[3] > 0.0)
	if engine.score >= next_life:
		next_life += LIFE_EVERY
		if lives < MAX_LIVES:
			lives += 1
			_float(Vector2(shooter_x, E.RAIL_Y - 14.0), tr("Extra life!"), Color("ff6b8a"), 1.6)
			SoundLib.play(self, "reward/coin_plingy")
			_update_labels()
	board.queue_redraw()

func _on_event(e: Array) -> void:
	match e[0]:
		"stick":
			SoundLib.play(self, "impact/wood_light", -6.0)
		"pop":
			var at: Vector2 = e[1]
			var count: int = e[2]
			var lvl: int = e[4]
			for i in mini(count * 3, 40):
				var v := Vector2(rng.randf_range(-28, 28), rng.randf_range(-40, -6))
				bits.append([at + Vector2(rng.randf_range(-4, 4), rng.randf_range(-3, 3)), v, e[3], rng.randf_range(0.4, 0.8)])
			SoundLib.play(self, "impact/glass_light", -2.0)
			var pts: int = count * 10 * (lvl + 1) + (50 * lvl if lvl > 0 else 0)
			_float(at, "+%d" % pts, Color("fff3b0"), 0.9)
			if lvl > 0:
				run_chain = maxi(run_chain, lvl + 1)
				_float(at + Vector2(0, -7), tr("Chain ×%d!") % (lvl + 1), Color("7dff3a") if _voodoo() else Color("ffe14a"), 1.2)
				SoundLib.play(self, "reward/coin_short")
				if lvl >= 2:
					SoundLib.play(self, "voice/combo", -4.0)
		"power":
			var at2: Vector2 = e[2]
			match e[1]:
				E.P_BOMB:
					flash = 0.25
					SoundLib.play(self, "scifi/explosion_crunch", -6.0)
					_float(at2, tr("Boom!"), Color("ffae2b"), 1.0)
				E.P_SLOW:
					SoundLib.play(self, "reward/powerup", -3.0)
					_float(at2, tr("Slow down!"), Color("7fd4ff"), 1.4)
				E.P_REVERSE:
					SoundLib.play(self, "reward/powerup", -3.0)
					_float(at2, tr("Back up!"), Color("b88cff"), 1.4)
				E.P_RAINBOW:
					SoundLib.play(self, "reward/powerup", -3.0)
					_float(at2, tr("Rainbow bug!"), Color("ff7ad9"), 1.4)
					cur = E.RAINBOW
		"pit":
			SoundLib.play(self, "scifi/slime", -4.0)
			_float(Vector2(50, 60), tr("Into the pit!"), Color("ff5a5a"), 1.6)
		"lost":
			_level_lost()
		"cleared":
			_level_cleared()

func _float(at: Vector2, text: String, col: Color, life: float) -> void:
	floats.append([at, text, col, life])

func _level_cleared() -> void:
	between = true
	run_levels += 1
	# Bonus: a flat 1000, more for lives in hand and for later levels.
	var bonus := 1000 + 250 * maxi(0, lives - 1) + 20 * level
	engine.score += bonus
	SoundLib.play(self, "jingles/win_succeeded", -4.0)
	var msg := (tr("Level %d cleared!") % level) if mode == "campaign" else (tr("Wave %d cleared!") % level)
	msg += "\n" + tr("Bonus: +%s") % _fmt(bonus) + "\n" + tr("Score: %s") % _fmt(engine.score)
	if info:
		info.add("Levels cleared")
		info.add("Bugs popped", engine.popped)
		info.high("Longest chain reaction", engine.best_chain + 1)
		info.high("Best score", engine.score)
	if mode == "campaign":
		_set_reached(level + 1)
		if info:
			info.high("Highest level", level)
		if level >= E.CAMPAIGN_LEVELS:
			_campaign_won()
			return
	else:
		if info:
			info.high("Most endless waves", level)
	_show_dialog(msg, "▶ Next level")
	_save_game()

func _campaign_won() -> void:
	over = true
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("You cleared all 30 levels!") + "\n" + tr("Score: %s") % _fmt(engine.score)
	if info:
		info.add("Campaigns won")
		if not result_sent:
			result_sent = true
			info.result("win")
		info.celebrate(tr("Garden saved!"))
	_show_dialog(msg, "♾ Play Endless")

func _level_lost() -> void:
	lives -= 1
	_update_labels()
	if lives <= 0:
		_game_over()
		return
	between = true
	SoundLib.play(self, "jingles/lose_failed", -8.0)
	_float(Vector2(50, 70), tr("Lives left: %d") % lives, Color("ff8a8a"), 1.6)
	var tw := create_tween()
	tw.tween_interval(1.7)
	tw.tween_callback(_retry_level)

func _retry_level() -> void:
	if over:
		return
	var s: int = engine.score
	_start_level(level)
	engine.score = s
	_update_labels()

func _game_over() -> void:
	over = true
	between = true
	SaveUtil.delete(SAVE_PATH)
	_sfx("lose")
	var msg := tr("Game over!") + "\n" + tr("Score: %s") % _fmt(engine.score)
	if info:
		info.add("Bugs popped", engine.popped)
		if not result_sent:
			result_sent = true
			info.result("loss")
		if info.high("Best score", engine.score):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	_show_dialog(msg, "Play Again")

func _show_dialog(msg: String, main_text: String) -> void:
	end_dialog.get_meta("message_label").text = msg
	var btns: Array = end_dialog.find_children("*", "Button", true, false)
	if not btns.is_empty():
		btns[0].text = tr(main_text)
	end_dialog.visible = true

func _on_dialog_main() -> void:
	end_dialog.visible = false
	if over:
		if level >= E.CAMPAIGN_LEVELS and mode == "campaign" and lives > 0:
			_new_run("endless", 1)
		else:
			_restart()
		return
	_start_level(level + 1)

# ---------- level select ----------

func _open_level_select() -> void:
	var parts: Array = home.card("📋 Level Select")
	var body: VBoxContainer = parts[1]
	var note := Label.new()
	note.text = tr("%s: you have reached level %d of %d.") % [tr(DIFFS[diff]), _reached(), E.CAMPAIGN_LEVELS]
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(note)
	for shape_i in E.SHAPES.size():
		var head := Label.new()
		head.text = tr(SHAPE_NAMES[E.SHAPES[shape_i]])
		head.add_theme_font_size_override("font_size", 24)
		body.add_child(head)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		body.add_child(row)
		for k in 5:
			var n := shape_i * 5 + k + 1
			var b := Button.new()
			b.text = str(n) if n <= _reached() else "🔒"
			b.disabled = n > _reached()
			b.custom_minimum_size = Vector2(0, 62)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(_pick_level.bind(n, parts[0]))
			row.add_child(b)
	home.show_card(parts[0])

func _pick_level(n: int, card: Control) -> void:
	home.close_card(card)
	SaveUtil.delete(SAVE_PATH)
	home.play_now(_new_run.bind("campaign", n))

# ---------- geometry ----------

func _scale() -> float:
	return minf(board.size.x / E.FIELD.x, board.size.y / E.FIELD_H)

func _origin() -> Vector2:
	var k := _scale()
	return Vector2((board.size.x - E.FIELD.x * k) / 2.0, board.size.y - E.FIELD_H * k)

func _next_spot() -> Vector2:
	var side := 9.0 if shooter_x < 80.0 else -9.0
	return Vector2(shooter_x + side, E.RAIL_Y + 3.0)

func _cache_paths() -> void:
	var key := "%s:%d:%s" % [str(board.size), engine.tracks.size(), engine.spec.get("shape", "")]
	if key == _geo_key:
		return
	_geo_key = key
	_paths.clear()
	var o := _origin()
	var k := _scale()
	for t in engine.tracks:
		var pts := PackedVector2Array()
		var src: PackedVector2Array = t.pts
		for i in range(0, src.size(), 3):
			pts.append(o + src[i] * k)
		pts.append(o + src[src.size() - 1] * k)
		_paths.append(pts)

# ---------- drawing ----------

func _draw_backdrop(c: Control) -> void:
	if _voodoo():
		c.draw_rect(Rect2(Vector2.ZERO, c.size), HomeKit.BG)
		c.draw_texture_rect(disc_tex, Rect2(c.size * Vector2(-0.3, 0.1), c.size * Vector2(1.6, 1.0)), false, Color(HomeKit.PURPLE, 0.12))
	else:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("3f7a2c"))
		if grass_tex:
			c.draw_texture_rect(grass_tex, Rect2(Vector2.ZERO, c.size), false)
		c.draw_rect(Rect2(0, 0, c.size.x, 120), Color(0, 0, 0, 0.18))

func _draw_board() -> void:
	if engine.tracks.is_empty() or bugs.is_empty() or _scale() < 0.5:
		return  # not laid out yet
	_cache_paths()
	var k := _scale()
	var o := _origin()
	var vd := _voodoo()
	# Paths.
	for pts in _paths:
		if vd:
			board.draw_polyline(pts, Color(HomeKit.PURPLE, 0.35), E.D * 1.5 * k, true)
			board.draw_polyline(pts, Color("120b22"), E.D * 1.15 * k, true)
			board.draw_polyline(pts, Color(HomeKit.PURPLE, 0.5), maxf(1.5, 0.25 * k), true)
		else:
			board.draw_polyline(pts, Color("5a3d22"), E.D * 1.45 * k, true)
			board.draw_polyline(pts, Color("9a7247"), E.D * 1.2 * k, true)
			board.draw_polyline(pts, Color("b48a5a", 0.55), E.D * 0.45 * k, true)
	# Pits.
	var danger: bool = engine.in_danger()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
	for t in engine.tracks:
		var end: Vector2 = o + E.pos_at(t, t.len) * k
		var rr := E.R * 1.9 * k
		if danger:
			board.draw_texture_rect(disc_tex, Rect2(end - Vector2.ONE * rr * 2.6, Vector2.ONE * rr * 5.2), false, Color(1, 0.15, 0.1, 0.35 + 0.35 * pulse))
		if vd and voodoo_script:
			board.draw_texture_rect(disc_tex, Rect2(end - Vector2.ONE * rr * 1.8, Vector2.ONE * rr * 3.6), false, Color(HomeKit.MAGENTA, 0.35))
			voodoo_script.draw_skull(board, end, rr * 1.9, Color("e9e2cf"), Color("0b0710"), HomeKit.MAGENTA)
		else:
			board.draw_circle(end, rr * 1.2, Color("4a2f18"))
			board.draw_circle(end, rr, Color("140c06"))
			board.draw_circle(end + Vector2(0, rr * 0.15), rr * 0.7, Color("000000"))
	# Bugs.
	var half: float = E.R * k * (Art.SIZE / 2.0) / 19.5
	var marks: Array = []
	for t in engine.tracks:
		for b in t.balls:
			if b.vs < -E.R:
				continue
			var p: Vector2 = o + E.pos_at(t, b.vs) * k
			if b.fly > 0.0 and b.has("from"):
				p = p.lerp(o + b.from * k, b.fly / 0.12)
			var ang: float = E.tangent_at(t, maxf(b.vs, 0.0)).angle()
			if engine.losing:
				ang += b.vs * 0.3
			var frame: int = int(b.vs / 2.2) & 1
			if b.p != E.P_NONE:
				board.draw_texture_rect(disc_tex, Rect2(p - Vector2.ONE * half * 1.25, Vector2.ONE * half * 2.5), false, Color(1, 1, 0.7, 0.35 + 0.3 * pulse))
				marks.append([p, b.p])
			board.draw_set_transform(p, ang, Vector2.ONE)
			board.draw_texture_rect(bugs[b.c % bugs.size()][frame], Rect2(-half, -half, half * 2.0, half * 2.0), false)
	board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font := ThemeDB.fallback_font
	for m in marks:
		var fs := int(half * 0.95)
		board.draw_string(font, m[0] + Vector2(-half, fs * 0.35), POWER_ICONS.get(m[1], ""), HORIZONTAL_ALIGNMENT_CENTER, half * 2.0, fs)
	# Shots in flight.
	for sh in engine.shots:
		_draw_bug(o + sh.p * k, half, sh.c, -PI / 2.0, int(sh.p.y / 3.0) & 1)
	# Aim guide, launcher, next bug.
	_draw_launcher(o, k, half)
	# Particles and floating text.
	for b in bits:
		var col := _bug_color(b[2]) if b[2] >= 0 else Color("ffd27a")
		var r := E.R * 0.55 * k * clampf(b[3] * 2.0, 0.2, 1.0)
		board.draw_texture_rect(disc_tex, Rect2(o + b[0] * k - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, Color(col, clampf(b[3] * 2.0, 0.0, 1.0)))
	for f in floats:
		var fs2 := int(5.2 * k)
		var a := clampf(f[3] * 2.0, 0.0, 1.0)
		board.draw_string_outline(font, o + f[0] * k + Vector2(-60 * k, 0), f[1], HORIZONTAL_ALIGNMENT_CENTER, 120 * k, fs2, maxi(4, int(k)), Color(0, 0, 0, 0.7 * a))
		board.draw_string(font, o + f[0] * k + Vector2(-60 * k, 0), f[1], HORIZONTAL_ALIGNMENT_CENTER, 120 * k, fs2, Color(f[2], a))
	if flash > 0.0:
		board.draw_rect(Rect2(Vector2.ZERO, board.size), Color(1, 0.9, 0.6, flash))
	# Power timers.
	var tip := ""
	if engine.slow_t > 0.0:
		tip = "⏳ %d" % ceili(engine.slow_t)
	if engine.reverse_t > 0.0:
		tip = "⏪ %d" % ceili(engine.reverse_t)
	if tip != "":
		board.draw_string(font, o + Vector2(2, 6) * k, tip, HORIZONTAL_ALIGNMENT_LEFT, -1, int(5 * k), Color.WHITE)

func _draw_bug(p: Vector2, half: float, c: int, ang: float, frame: int) -> void:
	if c == E.RAINBOW:
		var hue := fmod(Time.get_ticks_msec() / 900.0, 1.0)
		board.draw_texture_rect(disc_tex, Rect2(p - Vector2.ONE * half * 1.2, Vector2.ONE * half * 2.4), false, Color.from_hsv(hue, 0.8, 1.0, 0.8))
		board.draw_set_transform(p, ang, Vector2.ONE)
		board.draw_texture_rect(bugs[int(hue * 6.0) % bugs.size()][frame], Rect2(-half, -half, half * 2.0, half * 2.0), false, Color(1, 1, 1, 0.85))
	else:
		board.draw_set_transform(p, ang, Vector2.ONE)
		board.draw_texture_rect(bugs[c % bugs.size()][frame], Rect2(-half, -half, half * 2.0, half * 2.0), false)
	board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_launcher(o: Vector2, k: float, half: float) -> void:
	var vd := _voodoo()
	var rail_y := o.y + E.RAIL_Y * k
	var rail_col := Color(HomeKit.CYAN, 0.6) if vd else Color("6b4a2a")
	board.draw_line(Vector2(o.x, rail_y + 4.5 * k), Vector2(o.x + E.FIELD.x * k, rail_y + 4.5 * k), rail_col, maxf(2.0, 1.2 * k))
	var sp := Vector2(o.x + shooter_x * k, rail_y)
	if _playing() and engine.shots.size() < 2:
		# Dotted line straight up to the first bug it would meet.
		var stop_y := -10.0
		for t in engine.tracks:
			for b in t.balls:
				if b.s < 0.0:
					continue
				var bp: Vector2 = E.pos_at(t, b.vs)
				if absf(bp.x - shooter_x) < E.D * 0.85 and bp.y > stop_y and bp.y < E.RAIL_Y:
					stop_y = bp.y
		var col := _bug_color(cur) if cur >= 0 else Color.WHITE
		var y := E.RAIL_Y - 9.0
		while y > stop_y + 3.0:
			var r := 0.55 * k
			board.draw_texture_rect(dot_tex, Rect2(Vector2(sp.x, o.y + y * k) - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, Color(col, 0.55))
			y -= 3.2
	# The launcher: a leaf pad (Classic) or a glowing skull plate (Voodoo).
	var w := 9.0 * k
	var h := 4.0 * k
	var base := PackedVector2Array([sp + Vector2(-w, h), sp + Vector2(-w * 0.7, -h * 0.6), sp + Vector2(0, -h * 1.2),
		sp + Vector2(w * 0.7, -h * 0.6), sp + Vector2(w, h)])
	if vd:
		board.draw_texture_rect(disc_tex, Rect2(sp - Vector2(w * 1.6, w * 1.2), Vector2(w * 3.2, w * 2.4)), false, Color(HomeKit.CYAN, 0.25))
		board.draw_colored_polygon(base, Color("0f1830"))
		board.draw_polyline(base, HomeKit.CYAN, maxf(2.0, 0.4 * k), true)
	else:
		board.draw_colored_polygon(base, Color("2f7d2a"))
		board.draw_polyline(base, Color("1d4f1a"), maxf(2.0, 0.35 * k), true)
		board.draw_line(sp + Vector2(0, -h * 1.1), sp + Vector2(0, h), Color("1d4f1a"), maxf(1.5, 0.3 * k))
	if _playing() or between:
		_draw_bug(sp + Vector2(0, -h * 0.9), half, cur, -PI / 2.0, 0)
		var ns := o + _next_spot() * k
		_draw_bug(ns, half * 0.7, nxt, -PI / 2.0, 0)

func _draw_home_logo(c: Control) -> void:
	if logo_bugs.is_empty():
		return
	var r := minf(c.size.y / 3.2, 60.0)
	var mid := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	var pts: Array = []
	for i in 7:
		var a := lerpf(PI * 1.1, PI * 1.9, i / 6.0)
		pts.append([mid + Vector2(cos(a) * r * 3.2, sin(a) * r * 1.2 + r * 1.4), a + PI / 2.0])
	var order := [0, 0, 2, 1, 1, 3, 4]
	for i in pts.size():
		var half := r * 0.62
		c.draw_set_transform(pts[i][0], pts[i][1], Vector2.ONE)
		c.draw_texture_rect(logo_bugs[order[i] % logo_bugs.size()][i & 1], Rect2(-half, -half, half * 2.0, half * 2.0), false)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or over:
		return
	var d := {"mode": mode, "diff": diff, "level": level, "lives": lives, "next_life": next_life,
		"cur": cur, "nxt": nxt, "between": between, "run_levels": run_levels, "run_chain": run_chain}
	if between:
		d["score"] = engine.score
	else:
		d["engine"] = engine.to_dict()
	SaveUtil.write(SAVE_PATH, d)

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if not d is Dictionary:
		return ""
	var lv := int(d.get("level", 1))
	var t: String = (tr("Level %d") % lv) if d.get("mode", "campaign") == "campaign" else (tr("Wave %d") % lv)
	var sc: int = int(d.get("score", d.get("engine", {}).get("score", 0)))
	return t + "   ·   " + tr("Score: %s") % _fmt(sc)

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if not d is Dictionary:
		_new_campaign()
		return
	mode = "endless" if d.get("mode", "") == "endless" else "campaign"
	diff = clampi(int(d.get("diff", 1)), 0, 2)
	lives = clampi(int(d.get("lives", START_LIVES)), 1, MAX_LIVES)
	next_life = int(d.get("next_life", LIFE_EVERY))
	run_levels = int(d.get("run_levels", 0))
	run_chain = int(d.get("run_chain", 0))
	result_sent = false
	over = false
	var lv := maxi(1, int(d.get("level", 1)))
	if bool(d.get("between", false)) or not d.get("engine") is Dictionary:
		# Saved between levels: carry on with the next one.
		_start_level(lv + 1 if bool(d.get("between", false)) else lv)
		engine.score = int(d.get("score", 0))
	else:
		_start_level(lv)
		if not engine.from_dict(d.engine, rng):
			_start_level(lv)
		cur = int(d.get("cur", 0))
		nxt = int(d.get("nxt", 0))
		_refresh_colors()
	_geo_key = ""
	_update_labels()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

## Music from the hub's shared library (apps before v0.33 play none).
func _play_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("lively", self, -1, 2.0)

# ---------- helps (STANDARDS §17) ----------

## ⏪ help: every chain crawls backwards for a few seconds.
func _help_reverse() -> bool:
	if not _playing() or engine.ball_count() == 0:
		return false
	engine.reverse_t = E.REVERSE_TIME
	_float(Vector2(50, 60), tr("Back up!"), Color("b88cff"), 1.4)
	SoundLib.play(self, "reward/powerup", -3.0)
	return true

## 💣 help: the 8 bugs nearest each pit pop.
func _help_blast() -> bool:
	if not _playing() or engine.ball_count() == 0:
		return false
	var n: int = engine.clear_front(8)
	flash = 0.25
	SoundLib.play(self, "scifi/explosion_crunch", -6.0)
	_float(Vector2(50, 60), tr("Boom!"), Color("ffae2b"), 1.0)
	_update_labels()
	return n > 0
