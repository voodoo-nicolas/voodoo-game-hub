extends Control

## Fortune Ball -- ask a yes-or-no question, shake the phone (or flick / tap
## the ball), and an answer floats up in its window. Classic or spooky
## answers. Nothing to save: every question is fresh.
## Our own look, not the famous toy's (black ball, white "8" disc, blue
## triangle die): a violet crystal ball with an eye sigil that turns away to a
## hexagon window (docs/ip-audit-2026-10-06.md).

const FBEngine = preload("res://scripts/games/fortune_ball/fortune_ball_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## Home screen + pause menu + neon look, copied into this game's folder by
## `hub.py sync` (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/fortune_ball/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const TONE_COLORS := {"yes": HomeKit.LIME, "maybe": HomeKit.GOLD, "no": HomeKit.PINK}
## Per deck: the ball's rim and the colour of the answer die.
const DECK_LOOK := {
	"classic": {"rim": HomeKit.BLUE, "die": Color(0.07, 0.14, 0.5)},
	"spooky": {"rim": HomeKit.MAGENTA, "die": Color(0.26, 0.05, 0.36)},
}
const SPRING := 160.0      # how hard the ball springs back to its place
const DAMP := 9.0
const FACE_SPEED := 4.0    # the "8" turning away, per second
const REVEAL_TIME := 0.9   # the answer floating up

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine: FBEngine
var board: Control
var deck_label: Label
var hint_label: Label
var shake_btn: Button

var offset := Vector2.ZERO   # the ball's wobble away from its place
var vel := Vector2.ZERO
var face_t := 0.0            # 0 = the "8" faces you, 1 = the answer window
var reveal_t := 0.0          # 0..1 the answer floating up
var time := 0.0
var slosh_t := 0.0
var has_sensor := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _press_ms := 0
var _moved := false
var _last_v := Vector2.ZERO
var _last_us := 0
var _slosh: AudioStreamWAV
var _chime: AudioStreamWAV

func _ready() -> void:
	preload("res://scripts/games/fortune_ball/fortune_ball_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = FBEngine.new()
	engine.load_answers()
	_slosh = _make_slosh()
	_chime = _make_chime()
	_build_ui()
	_start("classic")

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_margin.add_child(top_bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.add_theme_font_size_override("font_size", 30)
	pause_btn.pressed.connect(_on_pause)
	top_bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("🧿 Fortune Ball")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76, 0)
	top_bar.add_child(spacer)

	deck_label = Label.new()
	deck_label.add_theme_font_size_override("font_size", 24)
	deck_label.add_theme_color_override("font_color", HomeKit.DIM)
	deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(deck_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	root.add_child(board)

	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 26)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint_label.custom_minimum_size = Vector2(0, 76)
	var hint_m := MarginContainer.new()  # side room for the floating ⚙ tab
	hint_m.add_theme_constant_override("margin_left", 48)
	hint_m.add_theme_constant_override("margin_right", 48)
	hint_m.add_child(hint_label)
	root.add_child(hint_m)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 36)
	bm.add_theme_constant_override("margin_left", 60)
	bm.add_theme_constant_override("margin_right", 60)
	root.add_child(bm)
	shake_btn = Button.new()
	shake_btn.text = tr("🧿 Shake")
	shake_btn.custom_minimum_size = Vector2(0, 90)
	shake_btn.add_theme_font_size_override("font_size", 32)
	shake_btn.set_meta("sfx", "")  # the ball sloshes instead of a tap
	shake_btn.pressed.connect(_on_shake_pressed)
	bm.add_child(shake_btn)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/fortune_ball/fortune_ball_help.gd"))
	home = HomeKit.new({
		"help": preload("res://scripts/games/fortune_ball/fortune_ball_help.gd"),
		"info": info,
		"accent": HomeKit.PURPLE,
		"subtitle": "Ask it anything. Shake it. Believe it… or don't.",
		"logo": _draw_home_logo,
		"solo_heading": "Pick the ball's voice",
		"modes": [
			{"text": "🧿  Classic answers", "sub": "Yes, no, maybe — the fortune-teller way", "color": HomeKit.CYAN, "action": _start.bind("classic")},
			{"text": "💀  Spooky answers", "sub": "The spirits, the bones and the skull reply", "color": HomeKit.MAGENTA, "action": _start.bind("spooky")},
		],
		"restart": _restart,
		"board": "Questions asked",
		"board_note": "Questions asked, all time.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.12)  # beside the deck name, clear of the ball
	add_child(drawer)

func _on_pause() -> void:
	home.pause()

func _restart() -> void:
	_start(engine.deck)

func _start(deck: String) -> void:
	engine.start(deck, "es" if TranslationServer.get_locale().begins_with("es") else "en")
	face_t = 0.0
	reveal_t = 0.0
	offset = Vector2.ZERO
	vel = Vector2.ZERO
	deck_label.text = tr("Spooky answers") if deck == "spooky" else tr("Classic answers")
	_update_hint()
	board.queue_redraw()

func _update_hint() -> void:
	match engine.state:
		FBEngine.SHAKING:
			hint_label.text = tr("Shaking…")
		FBEngine.SETTLING:
			hint_label.text = tr("The answer is rising…")
		FBEngine.SHOWN:
			hint_label.text = tr("Shake again for another answer")
		_:
			if has_sensor:
				hint_label.text = tr("Ask a yes-or-no question, then shake your phone")
			else:
				hint_label.text = tr("Ask a yes-or-no question, then tap or shake the ball")

func _on_shake_pressed() -> void:
	engine.poke()

# ---------- the frame ----------

func _process(delta: float) -> void:
	time += delta
	var a: Vector3 = Input.get_accelerometer()
	if a.length() > 2.0 and not has_sensor:
		has_sensor = true
		_update_hint()
	var before := engine.state
	if has_sensor:
		var prev := engine._last_accel
		engine.feed_accel(a)
		# The ball swings with the phone's jolts.
		vel += Vector2(prev.x - a.x, a.y - prev.y) * 26.0
	match engine.step(delta):
		"shake":
			_sfx_slosh()
		"reveal":
			_on_reveal()
	if engine.state != before:
		_update_hint()
	# While shaking, the ball rattles about on its own too.
	if engine.state == FBEngine.SHAKING:
		var ang := randf() * TAU
		vel += Vector2.from_angle(ang) * engine.energy * 2600.0 * delta
		slosh_t -= delta
		if slosh_t <= 0.0:
			_sfx_slosh()
	if not _dragging:
		vel += (-SPRING * offset - DAMP * vel) * delta
		offset += vel * delta
	var lim := _radius() * 0.16
	if offset.length() > lim:
		offset = offset.limit_length(lim)
		vel *= 0.5
	# The "8" turns away as soon as it is shaken; the answer rises once settled.
	if engine.state != FBEngine.IDLE:
		face_t = minf(1.0, face_t + delta * FACE_SPEED)
	if engine.state == FBEngine.SHOWN:
		reveal_t = minf(1.0, reveal_t + delta / REVEAL_TIME)
	else:
		reveal_t = maxf(0.0, reveal_t - delta * 5.0)
	board.queue_redraw()

func _on_reveal() -> void:
	reveal_t = 0.0
	_play(_chime, -4.0)
	_buzz(45)
	if info:
		info.add("Questions asked")
		if engine.tone == "yes":
			info.add("Yes answers")
		elif engine.tone == "no":
			info.add("No answers")

# ---------- input: flick, drag or tap the ball ----------

func _on_board_input(event: InputEvent) -> void:
	# Mouse only: a phone also sends each touch as an emulated mouse event.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.distance_to(_ball_center()) <= _radius() * 1.1:
				_dragging = true
				_moved = false
				_press_pos = event.position
				_press_ms = Time.get_ticks_msec()
				_last_v = Vector2.ZERO
				_last_us = Time.get_ticks_usec()
		elif _dragging:
			_dragging = false
			if not _moved and Time.get_ticks_msec() - _press_ms < 400:
				engine.poke()
	elif event is InputEventMouseMotion and _dragging:
		if event.position.distance_to(_press_pos) > 12.0:
			_moved = true
		var now := Time.get_ticks_usec()
		var dt := maxf((now - _last_us) / 1000000.0, 0.004)
		_last_us = now
		var v: Vector2 = event.relative / dt
		engine.feed_flick((v - _last_v).length())
		_last_v = v
		offset += event.relative * 0.6
		vel = Vector2.ZERO

# ---------- drawing ----------

func _radius() -> float:
	return minf(board.size.x * 0.4, board.size.y * 0.4)

func _ball_rest() -> Vector2:
	return Vector2(board.size.x / 2.0, board.size.y * 0.47)

func _ball_center() -> Vector2:
	return _ball_rest() + offset

func _draw_board() -> void:
	var r := _radius()
	if r < 10.0:
		return
	var look: Dictionary = DECK_LOOK.get(engine.deck, DECK_LOOK["classic"])
	var rim: Color = look["rim"]
	var rest := _ball_rest()
	# A glow on the floor beneath it.
	board.draw_set_transform(rest + Vector2(offset.x, r * 1.08), 0.0, Vector2(1.0, 0.16))
	board.draw_circle(Vector2.ZERO, r * 0.95, Color(rim, 0.10))
	board.draw_circle(Vector2.ZERO, r * 0.7, Color(0, 0, 0, 0.55))
	board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var c := _ball_center()
	_draw_ball(board, c, r, rim)
	# The face: the "8" turns up and away, then the window turns into view.
	var tilt := clampf(offset.x / r, -0.3, 0.3)
	if face_t < 0.5:
		var k := 1.0 - face_t * 2.0
		board.draw_set_transform(c + Vector2(0, -r * 0.55 * (1.0 - k)), tilt, Vector2(1.0, maxf(k, 0.01)))
		_draw_eight(board, r * 0.42)
	else:
		var k := (face_t - 0.5) * 2.0
		board.draw_set_transform(c + Vector2(0, r * 0.55 * (1.0 - k)), tilt, Vector2(1.0, maxf(k, 0.01)))
		_draw_window(board, r * 0.52, look["die"])
	board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The crystal ball: deep violet glass, mist swirling inside, light coming
## from the top left, neon rim.
static func _draw_ball(c: CanvasItem, ctr: Vector2, r: float, rim: Color) -> void:
	for i in 3:
		c.draw_circle(ctr, r * (1.03 + 0.05 * i), Color(rim, 0.05))
	c.draw_circle(ctr, r, Color(0.07, 0.03, 0.14))
	for i in 12:
		var t := float(i) / 12.0
		c.draw_circle(ctr + Vector2(-r * 0.3, -r * 0.34) * t, r * (1.0 - 0.88 * t), Color(0.45, 0.3, 0.75, 0.06))
	for i in 5:
		c.draw_arc(ctr + Vector2(0, r * 0.15), r * (0.35 + 0.1 * i), PI * (0.1 + 0.15 * i), PI * (0.75 + 0.1 * i), 24,
				Color(rim, 0.06), r * 0.05, true)
	HomeKit.glow_circle(c, ctr, r, rim, 2.5)
	c.draw_set_transform(ctr + Vector2(-r * 0.4, -r * 0.52), -0.6, Vector2(1.0, 0.5))
	c.draw_circle(Vector2.ZERO, r * 0.24, Color(1, 1, 1, 0.07))
	c.draw_circle(Vector2.ZERO, r * 0.13, Color(1, 1, 1, 0.16))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The eye sigil, drawn around (0, 0) (the caller sets the transform): a
## glowing all-seeing eye with rays, the ball's resting face.
static func _draw_eight(c: CanvasItem, rd: float) -> void:
	c.draw_circle(Vector2.ZERO, rd * 1.12, Color(HomeKit.GOLD, 0.08))
	var lid := PackedVector2Array()
	for k in 17:
		var a := PI * k / 16.0
		lid.append(Vector2(-cos(a) * rd, -sin(a) * rd * 0.55))
	for k in range(1, 16):
		var a := PI * k / 16.0
		lid.append(Vector2(cos(a) * rd, sin(a) * rd * 0.55))
	c.draw_colored_polygon(lid, Color(0.95, 0.9, 1.0))
	c.draw_polyline(lid + PackedVector2Array([lid[0]]), HomeKit.GOLD, 2.0, true)
	c.draw_circle(Vector2.ZERO, rd * 0.36, Color(0.35, 0.12, 0.6))
	c.draw_circle(Vector2.ZERO, rd * 0.16, Color(0.02, 0.01, 0.05))
	c.draw_circle(Vector2(-rd * 0.1, -rd * 0.1), rd * 0.06, Color(1, 1, 1, 0.9))
	for k in 7:
		var a := PI * (1.15 + 0.7 * k / 6.0)
		c.draw_line(Vector2.RIGHT.rotated(a) * rd * 0.72, Vector2.RIGHT.rotated(a) * rd * 1.02, Color(HomeKit.GOLD, 0.8), 2.0, true)

## The dark window with the answer die floating in it, around (0, 0).
func _draw_window(c: CanvasItem, rw: float, die: Color) -> void:
	c.draw_circle(Vector2.ZERO, rw, Color(0.005, 0.01, 0.05))
	for i in 6:
		c.draw_circle(Vector2.ZERO, rw * (1.0 - 0.12 * i), Color(die, 0.06))
	# Bubbles while the liquid is stirred up.
	if engine.is_shaking():
		for i in 7:
			var p := Vector2(sin(time * 2.3 + i * 1.7), cos(time * 1.9 + i * 2.6)) * rw * 0.62
			c.draw_circle(p, rw * (0.04 + 0.02 * (i % 3)), Color(0.7, 0.8, 1.0, 0.18))
	if reveal_t > 0.0 and engine.answer != "":
		var e := ease(reveal_t, 0.4)  # fast in, slow settle
		var rt := rw * 0.9 * (0.55 + 0.45 * e)
		var bob := Vector2(0, sin(time * 1.6) * rw * 0.02 + (1.0 - e) * rw * 0.25)
		_draw_die(c, bob, rt, die, TONE_COLORS.get(engine.tone, HomeKit.GOLD), e, engine.answer)
	HomeKit.glow_circle(c, Vector2.ZERO, rw, Color(0.5, 0.55, 0.9, 0.7), 2.0)

## A hexagon tablet floating in the mist with the answer inside.
static func _draw_die(c: CanvasItem, ctr: Vector2, rt: float, die: Color, tone: Color, alpha: float, text: String) -> void:
	var pts := PackedVector2Array()
	for k in 6:
		pts.append(ctr + Vector2.RIGHT.rotated(TAU * k / 6.0) * rt * 0.9)
	c.draw_colored_polygon(pts, Color(die, 0.92 * alpha))
	HomeKit.glow_polyline(c, pts + PackedVector2Array([pts[0]]), Color(tone, alpha), 2.0, true)
	var font: Font = ThemeDB.fallback_font
	var width := rt * 1.3  # inside the hexagon around its middle
	var fs := int(rt * 0.26)
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, fs)
	while fs > 10 and (size.y > rt * 0.9 or size.x > width + 1.0):
		fs -= 1
		size = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, fs)
	var top := ctr.y - size.y / 2.0
	var pos := Vector2(ctr.x - width / 2.0, top + font.get_ascent(fs))
	c.draw_multiline_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, -1, maxi(3, fs / 5), Color(tone, 0.35 * alpha))
	c.draw_multiline_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, -1, Color(1, 1, 1, alpha))

func _draw_home_logo(c: Control) -> void:
	var r := minf(c.size.y * 0.44, 90.0)
	var ctr := c.size / 2.0
	_draw_ball(c, ctr, r, HomeKit.PURPLE)
	c.draw_set_transform(ctr + Vector2(r * 0.05, -r * 0.08), 0.15, Vector2.ONE)
	_draw_eight(c, r * 0.42)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------- sound and touch feedback ----------

func _sfx_slosh() -> void:
	slosh_t = randf_range(0.16, 0.28)
	_play(_slosh, -8.0, randf_range(0.8, 1.25))

## Plays one of this pack's own sounds (silent on apps from before v0.23).
func _play(stream: AudioStream, db: float = 0.0, pitch: float = 1.0) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s and s.has_method("play_stream"):
		s.play_stream(stream, db, pitch)

## A short buzz, when the player has vibration on (Settings, app v0.21+).
func _buzz(ms: int) -> void:
	var st = get_node_or_null("/root/Settings")
	if st and st.has_method("buzz"):
		st.buzz(ms)

## Liquid sloshing: noise through a lowpass that opens and closes.
static func _make_slosh() -> AudioStreamWAV:
	var rate := 22050
	var length := 0.22
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for k in n:
		var t := float(k) / rate
		var cut := 0.04 + 0.1 * sin(PI * t / length)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * cut
		var env := sin(PI * t / length)
		data.encode_s16(k * 2, int(clampf(lp * env * 2.2, -1.0, 1.0) * 32767.0))
	return _wav(data, rate)

## The answer rising: three soft bell notes going up, with a shimmer.
static func _make_chime() -> AudioStreamWAV:
	var rate := 22050
	var length := 1.1
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var notes := [[523.25, 0.0], [659.25, 0.12], [987.77, 0.24]]
	for k in n:
		var t := float(k) / rate
		var v := 0.0
		for nt in notes:
			var u: float = t - nt[1]
			if u > 0.0:
				var f: float = nt[0] * (1.0 + 0.004 * sin(TAU * 5.0 * u))
				v += (sin(TAU * f * u) + 0.25 * sin(TAU * f * 2.0 * u)) * exp(-u * 3.2) * minf(1.0, u / 0.01)
		data.encode_s16(k * 2, int(clampf(v * 0.28, -1.0, 1.0) * 32767.0))
	return _wav(data, rate)

static func _wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
