extends Control

## Fastest Finger -- 2 to 4 players around one phone, each with their own panel
## turned to face them. Every round is a Reaction pad, a Math sum or an Odd one
## out; the first correct tap scores. First to 5 points wins. Real multi-touch,
## so everyone can tap at once.

const FFEngine = preload("res://scripts/games/fastest_finger/fastest_finger_engine.gd")
const HELP = preload("res://scripts/games/fastest_finger/fastest_finger_help.gd")
const HomeKit = preload("res://scripts/games/fastest_finger/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const CHALLENGES := ["Reaction", "Math", "Odd one out", "Mixed"]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Landing + pause menu
var engine: FFEngine
var bg: ColorRect
var skin: String = "classic"
var arena: Control
var end_dialog: ColorRect
var phase_timer: Timer
var challenge_pick: int = 3
var started: bool = false
var stage: String = ""        # ready, wait, live, result
var banner: String = ""
var go_ms: int = 0
var touch_seen: bool = false
var flash: Array = []         # per player: seconds of "wrong tap" flash left
var last_winner: int = -1

func _ready() -> void:
	preload("res://scripts/games/fastest_finger/fastest_finger_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = FFEngine.new()
	_build_ui()
	_lively_music()

## Lively background music from the hub's Music library (apps before v0.33 play none).
func _lively_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("lively", self, 0, 2.0)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.add_theme_font_size_override("font_size", 30)
	pause_btn.pressed.connect(_on_pause_home)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("👆 Fastest Finger")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	var am := MarginContainer.new()
	am.size_flags_vertical = Control.SIZE_EXPAND_FILL
	am.add_theme_constant_override("margin_left", 8)
	am.add_theme_constant_override("margin_right", 8)
	am.add_theme_constant_override("margin_bottom", 12)
	root.add_child(am)
	arena = Control.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.mouse_filter = Control.MOUSE_FILTER_STOP
	arena.draw.connect(_draw_arena)
	arena.gui_input.connect(_on_arena_input)
	am.add_child(arena)

	phase_timer = Timer.new()
	phase_timer.one_shot = true
	phase_timer.timeout.connect(_on_phase_timer)
	add_child(phase_timer)

	end_dialog = UI.build_dialog(tr("Match over"), [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for n in [2, 3, 4]:
		modes.append({"text": "👥 %d Players" % n, "sub": "One phone", "multi": true, "row": "players",
			"action": _new_game.bind(n)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "First finger on the right answer wins the point.",
		"logo": _draw_home_logo,
		"modes": modes,
		"multi_heading": "Players",
		"extra": _add_options,
		"restart": _restart,
		"board": "none",
	})
	add_child(home)
	if info:
		add_child(info)

func _add_options(box: VBoxContainer) -> void:
	box.add_child(home.section("Challenge"))
	box.add_child(home.choice_row(CHALLENGES, challenge_pick, _set_challenge))

func _set_challenge(i: int) -> void:
	challenge_pick = i

func _process(delta: float) -> void:
	var any := false
	for i in flash.size():
		if flash[i] > 0.0:
			flash[i] = maxf(0.0, flash[i] - delta)
			any = true
	if any:
		arena.queue_redraw()

# ---------- looks ----------

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if arena:
		arena.queue_redraw()

func _is_classic() -> bool:
	return skin == "classic"

func _player_color(i: int) -> Color:
	if _is_classic():
		return [HomeKit.CLASSIC.red, HomeKit.CLASSIC.blue, HomeKit.CLASSIC.yellow, Color("3fa34d")][i]
	return [HomeKit.PINK, HomeKit.CYAN, HomeKit.GOLD, HomeKit.LIME][i]

# ---------- layout / hit testing ----------

func _band_h() -> float:
	return clampf(arena.size.y * 0.15, 90.0, 140.0)

## Each player's zone: rect in arena coordinates and the turn (0 or PI) that makes it face them.
func _zones() -> Array:
	var W: float = arena.size.x
	var H: float = arena.size.y
	var zh: float = (H - _band_h()) / 2.0
	var bottom_y: float = H - zh
	var out: Array = []
	match engine.players:
		2:
			out = [{"rect": Rect2(0, bottom_y, W, zh), "rot": 0.0}, {"rect": Rect2(0, 0, W, zh), "rot": PI}]
		3:
			out = [{"rect": Rect2(0, bottom_y, W / 2.0, zh), "rot": 0.0}, {"rect": Rect2(W / 2.0, bottom_y, W / 2.0, zh), "rot": 0.0},
				{"rect": Rect2(0, 0, W, zh), "rot": PI}]
		_:
			out = [{"rect": Rect2(0, bottom_y, W / 2.0, zh), "rot": 0.0}, {"rect": Rect2(W / 2.0, bottom_y, W / 2.0, zh), "rot": 0.0},
				{"rect": Rect2(W / 2.0, 0, W / 2.0, zh), "rot": PI}, {"rect": Rect2(0, 0, W / 2.0, zh), "rot": PI}]
	for z in out:
		z["rect"] = z.rect.grow(-4.0)
	return out

## The play area inside a zone, in the zone's own (turned) coordinates around its centre.
func _body(size: Vector2) -> Rect2:
	return Rect2(-size.x / 2.0 + 10.0, -size.y / 2.0 + 48.0, size.x - 20.0, size.y - 58.0)

func _option_rects(body: Rect2, n: int) -> Array:
	var out: Array = []
	var gap := 10.0
	if n == 3:
		var w: float = (body.size.x - gap * 2.0) / 3.0
		for i in 3:
			out.append(Rect2(body.position + Vector2(i * (w + gap), 0), Vector2(w, body.size.y)))
	else:
		var w2: float = (body.size.x - gap) / 2.0
		var h2: float = (body.size.y - gap) / 2.0
		for i in 4:
			out.append(Rect2(body.position + Vector2((i % 2) * (w2 + gap), (i / 2) * (h2 + gap)), Vector2(w2, h2)))
	return out

func _on_arena_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_seen = true
		if event.pressed:
			_on_tap(event.position)
	elif event is InputEventMouseButton and not touch_seen:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_tap(event.position)

func _on_tap(pos: Vector2) -> void:
	if not started or stage == "result" or stage == "ready":
		return
	var zones := _zones()
	for p in zones.size():
		var z: Dictionary = zones[p]
		var rect: Rect2 = z.rect
		if not rect.has_point(pos):
			continue
		var local: Vector2 = (pos - rect.get_center()).rotated(-float(z.rot))
		var body := _body(rect.size)
		if engine.kind == "reaction":
			if body.has_point(local):
				_pad_tap(p)
		else:
			var rects := _option_rects(body, engine.options[p].size())
			for i in rects.size():
				if rects[i].has_point(local):
					_option_tap(p, i)
					break
		return

func _pad_tap(p: int) -> void:
	var r := engine.tap_pad(p)
	if r == "win":
		_round_won(p, int(Time.get_ticks_msec() - go_ms))
	elif r == "early":
		_wrong(p)

func _option_tap(p: int, i: int) -> void:
	var r := engine.tap_option(p, i)
	if r == "win":
		_round_won(p, -1)
	elif r == "wrong":
		_wrong(p)

func _wrong(p: int) -> void:
	_sfx("buzzer")
	flash[p] = 0.5
	if engine.round_over():
		banner = tr("Nobody scored")
		_finish_round()
	arena.queue_redraw()

func _round_won(p: int, ms: int) -> void:
	last_winner = p
	_sfx("pickup")
	banner = tr("Player %d scores!") % (p + 1)
	if ms >= 0:
		banner += "  %d ms" % ms
		if info:
			info.low("Fastest reaction (ms)", ms)
	_finish_round()

func _finish_round() -> void:
	stage = "result"
	phase_timer.start(1.7)
	arena.queue_redraw()

# ---------- game flow ----------

func _new_game(n: int) -> void:
	engine.new_game(n, challenge_pick)
	flash = []
	for i in n:
		flash.append(0.0)
	started = true
	end_dialog.visible = false
	last_winner = -1
	_next_round()

func _restart() -> void:
	_new_game(engine.players if engine.players >= 2 else 2)

func _next_round() -> void:
	engine.new_round()
	stage = "ready"
	banner = tr("Round %d") % engine.round_no
	_sfx("tick")
	phase_timer.start(1.0)
	arena.queue_redraw()

func _on_phase_timer() -> void:
	match stage:
		"ready":
			engine.begin_wait()
			if engine.kind == "reaction":
				stage = "wait"
				banner = tr("Wait for it…")
				phase_timer.start(randf_range(1.5, 4.0))
			else:
				stage = "live"
				banner = engine.question if engine.kind == "math" else tr("Find the odd one!")
				go_ms = Time.get_ticks_msec()
		"wait":
			engine.go()
			stage = "live"
			banner = tr("GO!")
			go_ms = Time.get_ticks_msec()
			_sfx("whoosh")
		"result":
			var w := engine.match_winner()
			if w >= 0:
				_end_match(w)
				return
			_next_round()
	arena.queue_redraw()

func _end_match(w: int) -> void:
	started = false
	stage = ""
	_sfx("win")
	if info:
		info.add("Matches played")
		info.add("Rounds played", engine.round_no)
	var parts: Array = []
	for i in engine.players:
		parts.append(tr("Player %d: %d") % [i + 1, engine.scores[i]])
	end_dialog.get_meta("message_label").text = tr("Player %d wins!") % (w + 1) + "\n" + "   ".join(parts)
	end_dialog.visible = true
	banner = ""
	arena.queue_redraw()

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

# ---------- drawing ----------

func _text(c: Control, center: Vector2, txt: String, size: int, col: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(font, Vector2(center.x - w / 2.0, center.y + size * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _box(c: Control, rect: Rect2, fill: Color, border: Color, radius: int = 14, bw: int = 3) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	c.draw_style_box(sb, rect)

func _shape(c: Control, id: int, ctr: Vector2, r: float, col: Color) -> void:
	match id:
		0:
			c.draw_circle(ctr, r, col)
		1:
			c.draw_rect(Rect2(ctr - Vector2(r, r) * 0.86, Vector2(r, r) * 1.72), col)
		2:
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -r), ctr + Vector2(r * 0.95, r * 0.75), ctr + Vector2(-r * 0.95, r * 0.75)]), col)
		3:
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -r), ctr + Vector2(r * 0.8, 0), ctr + Vector2(0, r), ctr + Vector2(-r * 0.8, 0)]), col)
		4:
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(ctr + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
			c.draw_colored_polygon(pts, col)
		_:
			var hex := PackedVector2Array()
			for i in 6:
				var a2 := i * PI / 3.0
				hex.append(ctr + Vector2(cos(a2), sin(a2)) * r)
			c.draw_colored_polygon(hex, col)

func _draw_arena() -> void:
	if engine == null or arena == null:
		return
	if not started and stage == "":
		return
	var zones := _zones()
	for p in zones.size():
		var z: Dictionary = zones[p]
		var rect: Rect2 = z.rect
		arena.draw_set_transform(rect.get_center(), float(z.rot), Vector2.ONE)
		_draw_zone(p, rect.size)
	arena.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The shared band in the middle, read from both sides.
	var W: float = arena.size.x
	var band := Rect2(0, (arena.size.y - _band_h()) / 2.0, W, _band_h())
	var fs: int = int(clampf(band.size.y * 0.3, 26.0, 46.0))
	var col := Color.WHITE
	_text(arena, band.get_center() + Vector2(0, band.size.y * 0.22), banner, fs, col)
	arena.draw_set_transform(band.get_center() - Vector2(0, band.size.y * 0.22), PI, Vector2.ONE)
	_text(arena, Vector2.ZERO, banner, fs, col)
	arena.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_zone(p: int, size: Vector2) -> void:
	var pc := _player_color(p)
	var ink: Color = HomeKit.CLASSIC.ink if _is_classic() else Color.WHITE
	var whole := Rect2(-size / 2.0, size)
	var fill := Color(pc, 0.18) if not _is_classic() else Color(pc, 0.22)
	_box(arena, whole, fill, pc, 18, 4)
	# name + score pips
	_text(arena, Vector2(-size.x / 2.0 + 70, -size.y / 2.0 + 24), tr("Player %d") % (p + 1), 28, Color.WHITE)
	var pips: int = FFEngine.TARGET
	for i in pips:
		var ctr := Vector2(size.x / 2.0 - 22.0 - (pips - 1 - i) * 26.0, -size.y / 2.0 + 24.0)
		if i < engine.scores[p]:
			arena.draw_circle(ctr, 9.0, pc)
		else:
			arena.draw_arc(ctr, 9.0, 0.0, TAU, 20, Color(pc, 0.7), 2.0)
	if stage == "" or engine.phase == "ready" and engine.kind != "reaction":
		return
	var body := _body(size)
	var locked: bool = engine.locked[p]
	var flashing: bool = flash[p] > 0.0
	if engine.kind == "reaction":
		var pad := Color("30384f") if not _is_classic() else Color("8d97ab")
		var label := tr("Wait").to_upper()
		if engine.phase == "live":
			pad = Color("2bd96b")
			label = tr("TAP!")
		if locked:
			pad = Color("c0392b")
			label = tr("TOO EARLY")
		if engine.phase == "done" and engine.winner == p:
			pad = Color("ffcc33")
			label = "✔"
		_box(arena, body, pad, Color.WHITE if engine.phase == "live" and not locked else Color(1, 1, 1, 0.4), 18, 3)
		_text(arena, body.get_center(), label, int(clampf(body.size.y * 0.3, 26.0, 60.0)), Color.WHITE)
		return
	var rects := _option_rects(body, engine.options[p].size())
	for i in rects.size():
		var cell := Color(1, 1, 1, 0.1) if not _is_classic() else Color("f4efe4")
		if locked or flashing:
			cell = Color(0.75, 0.2, 0.2, 0.5)
		if engine.phase == "done" and engine.winner == p and i == engine.correct[p]:
			cell = Color("ffcc33")
		_box(arena, rects[i], cell, Color(pc, 0.9), 12, 3)
		if engine.kind == "math":
			_text(arena, rects[i].get_center(), str(engine.options[p][i]), int(clampf(rects[i].size.y * 0.5, 24.0, 56.0)), ink if _is_classic() else Color.WHITE)
		else:
			var r: float = minf(rects[i].size.x, rects[i].size.y) * 0.32
			_shape(arena, int(engine.options[p][i]), rects[i].get_center(), r, Color("e8505b") if _is_classic() else HomeKit.LIME)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y * 0.42, 56.0)
	var mid := c.size / 2.0
	for i in 3:
		var ctr := mid + Vector2((i - 1) * k * 1.5, 0)
		var col: Color = [HomeKit.PINK, HomeKit.GOLD, HomeKit.CYAN][i]
		HomeKit.glow_circle(c, ctr, k * 0.6, col, 3.0, 0.12 + (0.25 if i == 1 else 0.0))
	HomeKit.glow_text(c, mid, "GO", int(k * 0.7), Color.WHITE)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
