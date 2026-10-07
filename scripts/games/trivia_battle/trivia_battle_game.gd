extends Control

## Trivia Battle -- 2 to 4 players around one phone, each with their own panel
## of four answers turned to face them. Everyone sees the same question; the
## first right tap scores the point, a wrong tap locks you out of that
## question. Real multi-touch, so everyone can tap at once.

const TBEngine = preload("res://scripts/games/trivia_battle/trivia_battle_engine.gd")
const HELP = preload("res://scripts/games/trivia_battle/trivia_battle_help.gd")
const HomeKit = preload("res://scripts/games/trivia_battle/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const TOPIC_NAMES := ["Mixed", "Science", "Nature & Animals", "History", "Geography", "Arts & Culture", "Sports & Games"]
const TOPIC_IDS := ["mixed", "science", "nature", "history", "geography", "arts", "sports"]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Landing + pause menu
var engine: TBEngine
var bg: ColorRect
var skin: String = "classic"
var arena: Control
var end_dialog: ColorRect
var step_timer: Timer
var topic_pick: int = 0
var started: bool = false
var stage: String = ""        # ready, live, result
var banner: String = ""
var touch_seen: bool = false
var flash: Array = []
var time_left: float = 0.0

func _ready() -> void:
	preload("res://scripts/games/trivia_battle/trivia_battle_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = TBEngine.new()
	engine.load_bank()
	_build_ui()
	_calm_music()

## Calm background music from the hub's Music library (apps before v0.33 play none).
func _calm_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, 3, 2.0)

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
	title.text = tr("🥊 Trivia Battle")
	title.add_theme_font_size_override("font_size", 32)
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

	step_timer = Timer.new()
	step_timer.one_shot = true
	step_timer.timeout.connect(_on_step_timer)
	add_child(step_timer)

	end_dialog = UI.build_dialog(tr("Match over"), [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for n in [2, 3, 4]:
		modes.append({"text": "👥 %d Players" % n, "sub": "One phone", "multi": true, "row": "players", "action": _new_game.bind(n)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.MAGENTA,
		"subtitle": "Same question, one phone, first tap wins.",
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
	box.add_child(home.section("Topic"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var group := ButtonGroup.new()
	for i in TOPIC_NAMES.size():
		var b := HomeKit.neon_button(tr(TOPIC_NAMES[i]), HomeKit.BUTTON, 22, 62)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == topic_pick
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		home.call("_style_toggle", b, HomeKit.BUTTON)
		b.pressed.connect(_set_topic.bind(i))
		grid.add_child(b)
	box.add_child(grid)

func _set_topic(i: int) -> void:
	topic_pick = i

func _process(delta: float) -> void:
	var any := false
	for i in flash.size():
		if flash[i] > 0.0:
			flash[i] = maxf(0.0, flash[i] - delta)
			any = true
	if started and stage == "live":
		time_left = maxf(0.0, time_left - delta)
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
	return clampf(arena.size.y * 0.27, 230.0, 330.0)

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

func _body(size: Vector2) -> Rect2:
	return Rect2(-size.x / 2.0 + 8.0, -size.y / 2.0 + 44.0, size.x - 16.0, size.y - 52.0)

## Four answers stacked: long answers need the width.
func _option_rects(body: Rect2) -> Array:
	var out: Array = []
	var gap := 8.0
	var h: float = (body.size.y - gap * 3.0) / 4.0
	for i in 4:
		out.append(Rect2(body.position + Vector2(0, i * (h + gap)), Vector2(body.size.x, h)))
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
	if not started or stage != "live":
		return
	var zones := _zones()
	for p in zones.size():
		var z: Dictionary = zones[p]
		var rect: Rect2 = z.rect
		if not rect.has_point(pos):
			continue
		var local: Vector2 = (pos - rect.get_center()).rotated(-float(z.rot))
		var rects := _option_rects(_body(rect.size))
		for i in rects.size():
			if rects[i].has_point(local):
				_option_tap(p, i)
				break
		return

func _option_tap(p: int, i: int) -> void:
	var r := engine.tap_option(p, i)
	if r == "win":
		_sfx("pickup")
		if info:
			info.add("Questions won")
		banner = tr("Player %d scores!") % (p + 1) + "  " + engine.answer_text()
		_end_round()
	elif r == "wrong":
		_sfx("buzzer")
		flash[p] = 0.5
		if engine.phase == "done":
			banner = tr("Nobody got it — the answer: %s") % engine.answer_text()
			_end_round()
		arena.queue_redraw()

func _end_round() -> void:
	stage = "result"
	step_timer.start(2.2)
	arena.queue_redraw()

# ---------- game flow ----------

func _new_game(n: int) -> void:
	engine.new_game(n, TOPIC_IDS[topic_pick], TranslationServer.get_locale().begins_with("es"))
	flash = []
	for i in n:
		flash.append(0.0)
	started = true
	end_dialog.visible = false
	_next_round()

func _restart() -> void:
	_new_game(engine.players)

func _next_round() -> void:
	engine.new_round()
	stage = "ready"
	banner = tr("Question %d of %d") % [engine.index + 1, engine.total()]
	_sfx("tick")
	step_timer.start(1.1)
	arena.queue_redraw()

func _on_step_timer() -> void:
	match stage:
		"ready":
			engine.begin()
			stage = "live"
			banner = ""
			time_left = TBEngine.TIME_LIMIT
			step_timer.start(TBEngine.TIME_LIMIT)
		"live":
			engine.time_out()
			_sfx("lose")
			banner = tr("Time's up — the answer: %s") % engine.answer_text()
			_end_round()
		"result":
			engine.next_round()
			if engine.is_over():
				_end_match()
				return
			_next_round()
	arena.queue_redraw()

func _end_match() -> void:
	started = false
	stage = ""
	var w := engine.match_winner()
	var msg := tr("It's a tie!") if w < 0 else tr("Player %d wins!") % (w + 1)
	for i in engine.players:
		msg += "\n" + tr("Player %d: %d") % [i + 1, engine.scores[i]]
	if info:
		info.add("Matches played")
	_sfx("win")
	end_dialog.get_meta("message_label").text = msg
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

func _para(c: Control, box: Rect2, txt: String, size: int, col: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var h: float = font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, size).y
	c.draw_multiline_string(font, Vector2(box.position.x, box.get_center().y - h / 2.0 + font.get_ascent(size)), txt,
		HORIZONTAL_ALIGNMENT_CENTER, box.size.x, size, -1, col)

## The biggest size (down to `lo`) at which `txt` wrapped to `w` fits in `h`.
func _fit(txt: String, w: float, h: float, hi: int, lo: int = 16) -> int:
	var font: Font = ThemeDB.fallback_font
	var s := hi
	while s > lo:
		var longest := 0.0
		for word in txt.split(" ", false):
			longest = maxf(longest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x)
		if longest <= w and font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, w, s).y <= h:
			break
		s -= 2
	return s

func _box(c: Control, rect: Rect2, fill: Color, border: Color, radius: int = 14, bw: int = 3) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	c.draw_style_box(sb, rect)

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
	var W: float = arena.size.x
	var bh := _band_h()
	var band := Rect2(0, (arena.size.y - bh) / 2.0, W, bh)
	var half := Vector2(W - 24.0, bh / 2.0 - 8.0)
	arena.draw_set_transform(band.get_center() + Vector2(0, bh / 4.0), 0.0, Vector2.ONE)
	_draw_band(Rect2(-half / 2.0, half))
	arena.draw_set_transform(band.get_center() - Vector2(0, bh / 4.0), PI, Vector2.ONE)
	_draw_band(Rect2(-half / 2.0, half))
	arena.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_band(box: Rect2) -> void:
	if banner != "" and (stage == "ready" or stage == "result"):
		_para(arena, box, banner, 30, Color.WHITE)
		return
	if stage != "live":
		return
	var q: String = engine.question().text
	var bar := Rect2(box.position.x + 10.0, box.position.y, box.size.x - 20.0, 8.0)
	arena.draw_rect(bar, Color(1, 1, 1, 0.18))
	arena.draw_rect(Rect2(bar.position, Vector2(bar.size.x * time_left / TBEngine.TIME_LIMIT, bar.size.y)), HomeKit.GOLD)
	var body := Rect2(box.position + Vector2(0, 14), box.size - Vector2(0, 14))
	_para(arena, body, q, _fit(q, body.size.x, body.size.y, 32, 18), Color.WHITE)

func _draw_zone(p: int, size: Vector2) -> void:
	var pc := _player_color(p)
	var ink: Color = HomeKit.CLASSIC.ink if _is_classic() else Color.WHITE
	var whole := Rect2(-size / 2.0, size)
	_box(arena, whole, Color(pc, 0.2), pc, 18, 4)
	_text(arena, Vector2(-size.x / 2.0 + 70, -size.y / 2.0 + 22), tr("Player %d") % (p + 1), 26, Color.WHITE)
	_text(arena, Vector2(size.x / 2.0 - 40, -size.y / 2.0 + 22), str(engine.scores[p]), 30, pc)
	if stage != "live" and stage != "result":
		return
	var rects := _option_rects(_body(size))
	var locked: bool = engine.locked[p]
	var flashing: bool = flash[p] > 0.0
	for i in rects.size():
		var cell := Color(1, 1, 1, 0.1) if not _is_classic() else Color("f4efe4")
		if locked or flashing:
			cell = Color(0.75, 0.2, 0.2, 0.5)
		if stage == "result" and i == engine.correct[p]:
			cell = Color("ffcc33") if engine.winner == p else Color(0.3, 0.8, 0.4, 0.7)
		_box(arena, rects[i], cell, Color(pc, 0.9), 10, 3)
		var nm: String = str(engine.options[p][i])
		var box: Rect2 = rects[i].grow(-6.0)
		_para(arena, box, nm, _fit(nm, box.size.x, box.size.y, 26, 14), ink)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y * 0.4, 52.0)
	var mid := c.size / 2.0
	for i in 2:
		var r := Rect2(mid + Vector2((i - 1) * k * 1.9 + k * 0.2, -k * 0.55), Vector2(k * 1.6, k * 1.1))
		HomeKit.glow_rect(c, r, HomeKit.MAGENTA if i == 0 else HomeKit.CYAN, 3.0, 0.12)
		HomeKit.glow_text(c, r.get_center(), "?" if i == 0 else "!", int(k * 0.8), Color.WHITE)
	HomeKit.glow_text(c, mid + Vector2(0, -k * 0.05), "VS", int(k * 0.42), HomeKit.GOLD)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
