extends Control

## Who Am I? -- five clues about a secret animal, food, thing or job, from
## vague to obvious. Everybody has their own panel with four names, turned to
## face them; tap the right one first. The sooner you get it, the more it is
## worth. Alone or with 2-4 players around one phone (real multi-touch).

const WAEngine = preload("res://scripts/games/who_am_i/who_am_i_engine.gd")
const HELP = preload("res://scripts/games/who_am_i/who_am_i_help.gd")
const HomeKit = preload("res://scripts/games/who_am_i/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const PACE_NAMES := ["Relaxed", "Normal", "Fast"]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Landing + pause menu
var engine: WAEngine
var bg: ColorRect
var skin: String = "classic"
var arena: Control
var end_dialog: ColorRect
var step_timer: Timer
var pace_pick: int = 1
var started: bool = false
var stage: String = ""        # ready, live, result
var banner: String = ""
var touch_seen: bool = false
var flash: Array = []

func _ready() -> void:
	preload("res://scripts/games/who_am_i/who_am_i_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = WAEngine.new()
	engine.load_items()
	_build_ui()
	_calm_music()

## Calm background music from the hub's Music library (apps before v0.33 play none).
func _calm_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, 0, 2.0)

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
	title.text = tr("🕵️ Who Am I?")
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
	var modes: Array = [{"text": "🧑 Play alone", "sub": "8 secrets", "action": _new_game.bind(1)}]
	for n in [2, 3, 4]:
		modes.append({"text": "👥 %d Players" % n, "sub": "One phone", "multi": true, "row": "players", "action": _new_game.bind(n)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.LIME,
		"subtitle": "Five clues. The sooner you guess, the more it's worth.",
		"logo": _draw_home_logo,
		"modes": modes,
		"extra": _add_options,
		"restart": _restart,
		"board_note": "Your best score in one solo round (up to 40).",
	})
	add_child(home)
	if info:
		add_child(info)

func _add_options(box: VBoxContainer) -> void:
	box.add_child(home.section("Clue speed"))
	box.add_child(home.choice_row(PACE_NAMES, pace_pick, _set_pace))

func _set_pace(i: int) -> void:
	pace_pick = i

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
	return clampf(arena.size.y * 0.22, 170.0, 260.0)

## Zones: rect in arena coordinates and the turn (0 or PI) that makes it face the player.
func _zones() -> Array:
	var W: float = arena.size.x
	var H: float = arena.size.y
	var out: Array = []
	if engine.players == 1:
		var zh1: float = H - _band_h()
		return [{"rect": Rect2(4, H - zh1 + 4, W - 8, zh1 - 8), "rot": 0.0}]
	var zh: float = (H - _band_h()) / 2.0
	var bottom_y: float = H - zh
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
	return Rect2(-size.x / 2.0 + 10.0, -size.y / 2.0 + 48.0, size.x - 20.0, size.y - 58.0)

func _option_rects(body: Rect2) -> Array:
	var out: Array = []
	var gap := 10.0
	var w: float = (body.size.x - gap) / 2.0
	var h: float = (body.size.y - gap) / 2.0
	for i in 4:
		out.append(Rect2(body.position + Vector2((i % 2) * (w + gap), (i / 2) * (h + gap)), Vector2(w, h)))
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
	var pts := engine.points_now()
	var r := engine.tap_option(p, i)
	if r == "win":
		_sfx("pickup")
		if info:
			info.add("Secrets guessed")
			if pts == WAEngine.CLUES:
				info.add("Guessed on the first clue")
		if engine.players > 1:
			banner = tr("Player %d scores %d!") % [p + 1, pts] + "  " + engine.name_of()
		else:
			banner = tr("Correct! +%d") % pts + "  " + engine.name_of()
		_end_round()
	elif r == "wrong":
		_sfx("buzzer")
		flash[p] = 0.5
		if engine.phase == "done":
			banner = tr("It was: %s") % engine.name_of()
			_end_round()
		arena.queue_redraw()

func _end_round() -> void:
	stage = "result"
	step_timer.start(2.3)
	arena.queue_redraw()

# ---------- game flow ----------

func _new_game(n: int) -> void:
	engine.new_game(n, pace_pick, TranslationServer.get_locale().begins_with("es"))
	flash = []
	for i in n:
		flash.append(0.0)
	started = true
	end_dialog.visible = false
	_next_round()

func _restart() -> void:
	pace_pick = engine.pace
	_new_game(engine.players)

func _next_round() -> void:
	engine.new_round()
	stage = "ready"
	banner = tr("Round %d of %d") % [engine.index + 1, engine.total_rounds()]
	_sfx("tick")
	step_timer.start(1.2)
	arena.queue_redraw()

func _on_step_timer() -> void:
	match stage:
		"ready":
			engine.begin()
			stage = "live"
			banner = ""
			step_timer.start(WAEngine.PACES[engine.pace])
		"live":
			if engine.reveal():
				_sfx("tick")
				step_timer.start(WAEngine.PACES[engine.pace])
			else:
				engine.give_up_round()
				_sfx("lose")
				banner = tr("Nobody got it — it was: %s") % engine.name_of()
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
	var msg := ""
	if engine.players == 1:
		msg = tr("Score: %d") % engine.scores[0]
		if info:
			info.best("Best score", engine.scores[0])
			info.best("Best score (%s)" % PACE_NAMES[engine.pace], engine.scores[0])
	else:
		var w := engine.match_winner()
		msg = tr("It's a tie!") if w < 0 else tr("Player %d wins!") % (w + 1)
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

## Wrapped, centred text in a box; returns nothing. The box's middle is the text's middle.
func _para(c: Control, box: Rect2, txt: String, size: int, col: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var h: float = font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, size).y
	c.draw_multiline_string(font, Vector2(box.position.x, box.get_center().y - h / 2.0 + font.get_ascent(size)), txt,
		HORIZONTAL_ALIGNMENT_CENTER, box.size.x, size, -1, col)

## The biggest font size (down to `lo`) at which the longest word of `txt` fits `w`.
func _fit(txt: String, w: float, hi: int, lo: int = 16) -> int:
	var font: Font = ThemeDB.fallback_font
	var s := hi
	while s > lo:
		var longest := 0.0
		for word in txt.split(" ", false):
			longest = maxf(longest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x)
		if longest <= w:
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
	if engine.players == 1:
		_draw_band(Rect2(0, 0, W, bh).grow(-6.0))
	else:
		var band := Rect2(0, (arena.size.y - bh) / 2.0, W, bh)
		var half := Vector2(W - 20.0, bh / 2.0 - 6.0)
		arena.draw_set_transform(band.get_center() + Vector2(0, bh / 4.0), 0.0, Vector2.ONE)
		_draw_band(Rect2(-half / 2.0, half))
		arena.draw_set_transform(band.get_center() - Vector2(0, bh / 4.0), PI, Vector2.ONE)
		_draw_band(Rect2(-half / 2.0, half))
		arena.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The clues (or the round message) inside `box`.
func _draw_band(box: Rect2) -> void:
	var dim := Color(1, 1, 1, 0.55)
	if banner != "" and (stage == "ready" or stage == "result"):
		_para(arena, box, banner, 34, Color.WHITE)
		return
	if stage != "live":
		return
	var head := tr("Clue %d of %d") % [engine.clue, WAEngine.CLUES] + "   " + tr("%d points") % engine.points_now()
	_text(arena, box.position + Vector2(box.size.x / 2.0, 14.0), head, 22, HomeKit.GOLD)
	var shown: Array = engine.clues_shown()
	var cur: String = shown[shown.size() - 1]
	var body := Rect2(box.position + Vector2(0, 32), box.size - Vector2(0, 32))
	if shown.size() > 1:
		var prev_box := Rect2(body.position, Vector2(body.size.x, body.size.y * 0.3))
		_para(arena, prev_box, str(shown[shown.size() - 2]), 22, dim)
		body = Rect2(body.position + Vector2(0, body.size.y * 0.3), Vector2(body.size.x, body.size.y * 0.7))
	_para(arena, body, cur, 32, Color.WHITE)

func _draw_zone(p: int, size: Vector2) -> void:
	var pc := _player_color(p)
	var ink: Color = HomeKit.CLASSIC.ink if _is_classic() else Color.WHITE
	var whole := Rect2(-size / 2.0, size)
	_box(arena, whole, Color(pc, 0.2), pc, 18, 4)
	if engine.players > 1:
		_text(arena, Vector2(-size.x / 2.0 + 70, -size.y / 2.0 + 24), tr("Player %d") % (p + 1), 28, Color.WHITE)
	else:
		_text(arena, Vector2(0, -size.y / 2.0 + 24), tr("Pick the secret"), 28, Color.WHITE)
	_text(arena, Vector2(size.x / 2.0 - 40, -size.y / 2.0 + 24), str(engine.scores[p]), 30, pc)
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
		_box(arena, rects[i], cell, Color(pc, 0.9), 12, 3)
		var nm: String = str(engine.options[p][i])
		var box: Rect2 = rects[i].grow(-6.0)
		_para(arena, box, nm, _fit(nm, box.size.x, int(clampf(rects[i].size.y * 0.3, 20.0, 34.0))), ink)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y * 0.5, 64.0)
	var mid := c.size / 2.0
	HomeKit.glow_circle(c, mid, k * 0.78, HomeKit.LIME, 3.0, 0.1)
	HomeKit.glow_text(c, mid, "?", int(k * 1.1), Color.WHITE)
	for i in 3:
		var x := mid.x + (i - 1) * k * 1.9
		if i != 1:
			HomeKit.glow_rect(c, Rect2(Vector2(x - k * 0.55, mid.y - k * 0.3), Vector2(k * 1.1, k * 0.6)), HomeKit.CYAN, 2.0, 0.1)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
