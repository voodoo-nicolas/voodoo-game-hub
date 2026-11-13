extends Control

## Tarot -- sit with the fortune teller: a Card of the Day, a three-card or a
## five-card reading from the 22 Major Arcana, and a collection to complete.
## Cards are drawn in code (no copied deck art): Classic = cream cards with a
## gold rim and a violet back, Voodoo = neon on black with a skull back.
## For fun only. Nothing to save mid-reading: only the collection is kept
## (tarot_engine.gd, user://tarot_progress.json).

const TarotEngine = preload("res://scripts/games/tarot/tarot_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SoundLib = preload("res://scripts/games/tarot/sound_lib.gd")
## Home screen + pause menu + neon look, copied into this game's folder by
## `hub.py sync` (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/tarot/home_kit.gd")
const LandingStyles = preload("res://scripts/games/tarot/landing_styles.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const ASPECT := 0.62          # card width / height
const LABEL_H := 30.0         # room under each card for its position name
const FLIP_SPEED := 3.2       # flips per second
const DEAL_SPEED := 1.1       # the deal, per second
const ROMAN := ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII",
	"XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI"]
const SKINS := {
	"classic": {"face": Color("f3e6c8"), "ink": Color("2b1a3d"), "rim": Color("c9a227"),
		"back": Color("2e1a5e"), "back_ink": Color("e0bf4d"), "glyph": "✦", "accent": Color("e0bf4d")},
	"voodoo": {"face": Color("0d1424"), "ink": Color("e8f6ff"), "rim": Color("ff2bd6"),
		"back": Color("0a0f1f"), "back_ink": Color("29e6ff"), "glyph": "💀", "accent": Color("29e6ff")},
}

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var skin := "classic"
var spread := "three"        # "daily" is a one-card spread seeded by the date
var mode := "three"
var drawn: Array = []        # [{id, rev}]
var flip: Array = []         # 0 = back .. 1 = face, per card
var flip_to: Array = []
var deal := 0.0              # 0..1 the cards leaving the pile
var sel := -1
var finished := false
var first_today := true
var _booting := false

var board: Control
var head_label: Label
var name_label: Label
var text_label: Label
var teller_label: Label
var again_btn: Button
var _rects: Array = []       # current target rect per card

func _ready() -> void:
	preload("res://scripts/games/tarot/tarot_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = TarotEngine.new()
	engine.load_data()
	engine.load_progress()
	_build_ui()
	_booting = true   # the first deal happens under the Landing: no sound yet
	_start("three")
	_booting = false
	_music()

func _music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
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
	title.text = tr("🃏 Tarot of Destiny")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76, 0)
	top_bar.add_child(spacer)

	head_label = Label.new()
	head_label.add_theme_font_size_override("font_size", 24)
	head_label.add_theme_color_override("font_color", HomeKit.DIM)
	head_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(head_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	# The teller's panel: what the selected card says, then the sum-up.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 210)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left", 20)
	sm.add_theme_constant_override("margin_right", 20)
	sm.add_child(scroll)
	root.add_child(sm)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	scroll.add_child(col)
	name_label = _wrap_label(30)
	col.add_child(name_label)
	text_label = _wrap_label(26)
	col.add_child(text_label)
	teller_label = _wrap_label(26)
	col.add_child(teller_label)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 30)
	bm.add_theme_constant_override("margin_left", 60)
	bm.add_theme_constant_override("margin_right", 60)
	root.add_child(bm)
	again_btn = Button.new()
	again_btn.text = tr("🔮 Another reading")
	again_btn.custom_minimum_size = Vector2(0, 84)
	again_btn.add_theme_font_size_override("font_size", 30)
	again_btn.pressed.connect(_again)
	bm.add_child(again_btn)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/tarot/tarot_help.gd"))
	home = HomeKit.new({
		"help": preload("res://scripts/games/tarot/tarot_help.gd"),
		"info": info,
		"accent": HomeKit.PURPLE,
		"art": "res://games/tarot/landing_bg.jpg",
		"art_title": [0.116, 0.157],   # the painted title (tools/tarot_art.py)
		# Round floating Landing (docs/claude/landing-styles.md); "art" above is the stack's fallback.
		"landing": "orbs",
		"landing_style": LandingStyles,
		"landing_title_art": "res://games/tarot/landing_title.webp",
		"landing_art": {"portrait": "res://games/tarot/landing_portrait.jpg", "wide": "res://games/tarot/landing_wide.jpg"},
		"orb_color": Color("e0bf4d"),
		"subtitle": "Pull a card. Hear your fortune.",
		"logo": _draw_home_logo,
		"solo_heading": "Choose your reading",
		"modes": [
			{"text": "🌙  Card of the Day", "sub": "One card, the same all day", "orb": "1", "orb_name": "Today", "action": _start.bind("daily")},
			{"text": "🔮  Three cards", "sub": "Past, present and future", "orb": "3", "orb_name": "Three", "action": _start.bind("three")},
			{"text": "⭐  Five cards", "sub": "You, the challenge, the past, the future and the outcome", "orb": "5", "orb_name": "Five", "action": _start.bind("five")},
			{"text": "🧿  Celtic Cross", "sub": "Ten cards: the full story", "orb": "10", "orb_name": "Celtic", "action": _start.bind("celtic")},
		],
		"restart": _restart,
		"board": "Readings given",
		"board_note": "Readings given, all time.",
		"more": [["📖 Collection", HomeKit.PURPLE, _show_collection]],
	})
	add_child(home)
	if info:
		add_child(info)

func _wrap_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _draw_home_logo(c: Control) -> void:
	var col: Color = HomeKit.PURPLE
	var ctr := c.size / 2.0
	var h := c.size.y * 0.82
	var w := h * ASPECT
	for k in [-1, 0, 1]:
		var p := ctr + Vector2(k * w * 0.8, absf(k) * h * 0.04)
		var r := Rect2(p - Vector2(w, h) / 2.0, Vector2(w, h))
		HomeKit.glow_rect(c, r, col, 3.0, 0.18)
		HomeKit.glow_text(c, p, "🌙" if k < 0 else ("🔮" if k == 0 else "⭐"), int(h * 0.36), col)

func _on_pause() -> void:
	home.pause()

func _restart() -> void:
	_start(mode)

func _again() -> void:
	_start(mode)

func _set_skin(s: String) -> void:
	skin = s if SKINS.has(s) else "classic"
	if board:
		board.queue_redraw()
	_refresh_text()

func _current_skin() -> String:
	return skin

func _lang() -> String:
	return "es" if TranslationServer.get_locale().begins_with("es") else "en"

# ---- readings ----

func _start(m: String) -> void:
	mode = m
	spread = "one" if m == "daily" else m
	engine.lang = _lang()
	var day := TarotEngine.today()
	drawn = engine.draw(spread, day if m == "daily" else -1)
	flip = []
	flip_to = []
	for i in drawn.size():
		flip.append(0.0)
		flip_to.append(0.0)
	deal = 0.0
	sel = -1
	finished = false
	first_today = true
	if m == "daily":
		first_today = engine.daily_day != day
	again_btn.visible = false
	if not _booting:
		_sfx("casino/card_fan")
	set_process(true)
	_refresh_text()
	board.queue_redraw()

func _on_board_input(ev: InputEvent) -> void:
	# Phones send every tap twice; single taps handle MouseButton only.
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	if deal < 1.0:
		return
	for k in _rects.size():
		var i: int = _rects.size() - 1 - k   # the card drawn last is on top
		if _rects[i].grow(6 if spread != "celtic" else 0).has_point(ev.position):
			_tap_card(i)
			return

func _tap_card(i: int) -> void:
	sel = i
	if flip_to[i] < 1.0:
		flip_to[i] = 1.0
		_sfx("casino/card_place")
		set_process(true)
	_refresh_text()
	board.queue_redraw()

func _all_revealed() -> bool:
	for f in flip:
		if f < 1.0:
			return false
	return true

func _finish() -> void:
	finished = true
	var fresh: Array = engine.record(drawn, first_today)
	if mode == "daily":
		engine.touch_daily(TarotEngine.today())
	engine.save()
	if info:
		if first_today:
			info.add("Readings given")
		info.high("Cards discovered", engine.discovered())
		if mode == "daily":
			info.high("Daily streak", engine.daily_streak)
	_sfx("impact/bell_heavy")
	var t: String = engine.summary(drawn)
	if not fresh.is_empty():
		t += "\n" + tr("✨ New in your collection!")
	if mode == "daily":
		t += "\n" + tr("Daily streak: %d") % engine.daily_streak
	teller_label.text = t
	again_btn.visible = mode != "daily"
	_refresh_text()

func _refresh_text() -> void:
	if not name_label:
		return
	var acc: Color = SKINS[skin]["accent"]
	name_label.add_theme_color_override("font_color", acc)
	teller_label.add_theme_color_override("font_color", acc)
	head_label.text = _head_text()
	if sel < 0 or sel >= drawn.size() or flip_to[sel] < 1.0:
		name_label.text = ""
		text_label.text = tr("Think of your question, then tap a card to turn it over.") if not finished else ""
	else:
		var c: Dictionary = drawn[sel]
		var pos: String = engine.position_name(spread, sel)
		var nm: String = engine.name_of(int(c["id"]))
		if c["rev"]:
			nm += " · " + tr("Reversed")
		name_label.text = ("%s: %s" % [pos, nm]) if spread != "one" else nm
		text_label.text = engine.meaning(int(c["id"]), c["rev"])
	if not finished:
		teller_label.text = ""

func _head_text() -> String:
	match mode:
		"daily":
			return tr("Your Card of the Day")
		"three":
			return tr("Three-card reading")
		"celtic":
			return tr("Celtic Cross reading")
		_:
			return tr("Five-card reading")

func _process(delta: float) -> void:
	var busy := false
	if deal < 1.0:
		deal = minf(1.0, deal + delta * DEAL_SPEED)
		busy = true
	for i in flip.size():
		if flip[i] != flip_to[i]:
			flip[i] = move_toward(flip[i], flip_to[i], delta * FLIP_SPEED)
			busy = true
	board.queue_redraw()
	if not finished and not drawn.is_empty() and _all_revealed():
		_finish()
	if not busy:
		set_process(false)

# ---- drawing ----

func _layout() -> Array:
	var sz := board.size
	var m := 10.0
	var g := 12.0
	var n := drawn.size()
	var out: Array = []
	if n == 1:
		var h := minf(sz.y - 2 * m - LABEL_H, (sz.x - 2 * m) * 0.7 / ASPECT)
		var w := h * ASPECT
		out.append(Rect2(Vector2((sz.x - w) / 2.0, (sz.y - LABEL_H - h) / 2.0), Vector2(w, h)))
	elif n == 3:
		var w := (sz.x - 2 * m - 2 * g) / 3.0
		var h := w / ASPECT
		if h > sz.y - 2 * m - LABEL_H:
			h = sz.y - 2 * m - LABEL_H
			w = h * ASPECT
		var x0 := (sz.x - (3 * w + 2 * g)) / 2.0
		var y0 := (sz.y - LABEL_H - h) / 2.0
		for i in 3:
			out.append(Rect2(Vector2(x0 + i * (w + g), y0), Vector2(w, h)))
	elif n == 10:
		# Celtic Cross: the cross (5 columns x 3 rows, left) and the staff of
		# four (right, 2 x 2). No labels under the cards: a number sits on each.
		var w := minf((sz.x - 2 * m - 4 * g) / 5.0, (sz.y - 2 * m - 2 * g) / 3.0 * ASPECT)
		var h := w / ASPECT
		var x0 := (sz.x - (5 * w + 4 * g)) / 2.0
		var y0 := (sz.y - (3 * h + 2 * g)) / 2.0
		var cx := x0 + w + g
		var cy := y0 + h + g
		var slots := [Vector2(cx, cy), Vector2(cx + w * 0.17, cy + h * 0.1),
			Vector2(cx, cy + h + g), Vector2(x0, cy), Vector2(cx, y0), Vector2(cx + w + g, cy),
			Vector2(x0 + 3 * (w + g), cy + (h + g) / 2.0), Vector2(x0 + 4 * (w + g), cy + (h + g) / 2.0),
			Vector2(x0 + 3 * (w + g), cy - (h + g) / 2.0), Vector2(x0 + 4 * (w + g), cy - (h + g) / 2.0)]
		for i in 10:
			out.append(Rect2(slots[i], Vector2(w, h)))
	else:
		# 3 + 2: Past, You, Future on top; Challenge and Outcome under.
		var hmax := (sz.y - 2 * m - 2 * LABEL_H - g) / 2.0
		var w := minf((sz.x - 2 * m - 2 * g) / 3.0, hmax * ASPECT)
		var h := w / ASPECT
		var x0 := (sz.x - (3 * w + 2 * g)) / 2.0
		var y0 := (sz.y - (2 * h + 2 * LABEL_H + g)) / 2.0
		var y1 := y0 + h + LABEL_H + g
		var slots := {2: Vector2(x0, y0), 0: Vector2(x0 + w + g, y0), 3: Vector2(x0 + 2 * (w + g), y0),
			1: Vector2(x0 + (w + g) * 0.5, y1), 4: Vector2(x0 + (w + g) * 1.5, y1)}
		for i in 5:
			out.append(Rect2(slots[i], Vector2(w, h)))
	return out

func _draw_board() -> void:
	_rects = _layout()
	var sz := board.size
	var pile := Vector2(sz.x / 2.0, sz.y / 2.0)
	var n := drawn.size()
	for i in n:
		var r: Rect2 = _rects[i]
		var t := clampf(deal * (n + 1.5) - float(i) * 0.7, 0.0, 1.0)
		t = 1.0 - pow(1.0 - t, 3.0)
		var ctr := pile.lerp(r.get_center(), t)
		_draw_card(i, ctr, r.size, flip[i])
		if t >= 1.0:
			var pos: String = engine.position_name(spread, i)
			if spread == "celtic":
				# A number on the card's corner; the name shows when it is tapped.
				board.draw_circle(r.position + Vector2(13, 13), 13, Color(0, 0, 0, 0.7))
				_text(r.position + Vector2(13, 13), str(i + 1), 17, Color.WHITE)
			elif pos != "":
				_text(Vector2(r.get_center().x, r.end.y + LABEL_H * 0.55), pos, 22, HomeKit.DIM)
		if sel == i and t >= 1.0:
			board.draw_rect(r.grow(5), Color(SKINS[skin]["accent"], 0.9), false, 3.0)

func _text(center: Vector2, s: String, size: int, color: Color, max_w: float = 100000.0) -> void:
	var font := ThemeDB.fallback_font
	while size > 10 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
		size -= 1
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(center.x - w / 2.0, center.y - font.get_height(size) / 2.0 + font.get_ascent(size))
	board.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_card(i: int, ctr: Vector2, sz: Vector2, f: float) -> void:
	var look: Dictionary = SKINS[skin]
	var sx := absf(1.0 - 2.0 * f)   # a card turning over narrows to a line at the half
	var base := Transform2D(Vector2(sx, 0), Vector2(0, 1), ctr)
	board.draw_set_transform_matrix(base)
	var r := Rect2(-sz / 2.0, sz)
	board.draw_rect(Rect2(r.position + Vector2(4, 6), sz), Color(0, 0, 0, 0.35))
	var rim: Color = look["rim"]
	if f < 0.5:
		board.draw_rect(r, look["back"])
		board.draw_rect(r, rim, false, 3.0)
		board.draw_rect(r.grow(-sz.x * 0.08), Color(look["back_ink"], 0.6), false, 2.0)
		board.draw_rect(r.grow(-sz.x * 0.14), Color(look["back_ink"], 0.3), false, 1.0)
		_text(Vector2.ZERO, str(look["glyph"]), int(sz.x * 0.5), look["back_ink"])
	else:
		var card: Dictionary = drawn[i]
		var id := int(card["id"])
		board.draw_rect(r, look["face"])
		board.draw_rect(r, rim, false, 3.0)
		board.draw_rect(r.grow(-sz.x * 0.06), Color(rim, 0.55), false, 1.5)
		var ink: Color = look["ink"]
		_text(Vector2(0, -sz.y * 0.4), ROMAN[id], int(sz.y * 0.09), ink, sz.x * 0.8)
		# The symbol turns upside down when the card is reversed.
		board.draw_set_transform_matrix(base * Transform2D(PI if card["rev"] else 0.0, Vector2(0, -sz.y * 0.04)))
		_text(Vector2.ZERO, engine.symbol_of(id), int(sz.x * 0.52), ink)
		board.draw_set_transform_matrix(base)
		_text(Vector2(0, sz.y * 0.39), engine.name_of(id), int(sz.y * 0.075), ink, sz.x * 0.86)
	board.draw_set_transform_matrix(Transform2D.IDENTITY)

# ---- collection ----

func _show_collection() -> void:
	engine.lang = _lang()
	var parts: Array = home.card(tr("📖 Collection"))
	var body: Control = parts[1]
	var head := Label.new()
	head.text = tr("Cards discovered: %d of 22") % engine.discovered()
	head.add_theme_font_size_override("font_size", 30)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for i in 22:
		var e: Variant = engine.seen.get(i)
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 24)
		if e == null:
			l.text = "%s  ?" % ROMAN[i]
			l.add_theme_color_override("font_color", HomeKit.DIM)
		else:
			var marks := ("↑" if e["up"] else "") + ("↓" if e["rev"] else "")
			l.text = "%s %s  %s  %s" % [ROMAN[i], engine.symbol_of(i), engine.name_of(i), marks]
		grid.add_child(l)
	home.show_card(parts[0])

# ---- sound ----

func _sfx(id: String) -> void:
	# Ids stay full string literals at the call sites so `hub.py sync` finds them.
	match id:
		"casino/card_fan":
			SoundLib.play(self, "casino/card_fan", -4.0)
		"casino/card_place":
			SoundLib.play(self, "casino/card_place")
		"impact/bell_heavy":
			SoundLib.play(self, "impact/bell_heavy", -8.0)
