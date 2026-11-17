extends Control

## Poker's per-game menu (owner, 2026-11-17: "pick the poker first, then each
## one has its own menu"). The Landing shows a tile per game (picker(), built
## into the kit's Landing by _game.gd); a tile opens this screen for that game:
## its hand of cards, your record in it, the betting structure, ▶ Quick game
## (one tap to a cash table with your last settings) and the ways to play it:
## Career (the game's own ladder), Cash, Tournaments, Stats, Pass and play,
## Friends table, Online. Every action is a signal; the game does the work, so
## the setup sheets, saves and online code are the same as before.
## Navigation: 🏠 Home = back to the Landing (N2); Android back does the same.

signal home_pressed()
signal action(key: String)
signal limit_picked(limit: String)

const HomeKit = preload("res://scripts/games/video_poker/home_kit.gd")
const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const Cards = preload("res://scripts/games/video_poker/video_poker_cards.gd")
const Look = preload("res://scripts/games/video_poker/video_poker_look.gd")
const Career = preload("res://scripts/games/video_poker/video_poker_career.gd")
const PokerFx = preload("res://scripts/games/video_poker/video_poker_fx.gd")

## One line under each game's name (English keys; es.json has them).
const TAGLINES := {
	"holdem": "Two cards each, five on the board. The classic.",
	"omaha": "Four cards each: use exactly two with three from the board.",
	"draw": "Five cards, one draw. Swap the cards you don't want.",
	"stud": "Seven cards, some face up. No board, no blinds.",
	"short": "36 cards: no twos to fives. A flush beats a full house.",
	"pineapple": "Three cards, throw one away before the flop.",
	"crazy": "Three cards, throw one away after the flop.",
	"omahahilo": "Omaha with a split pot: best high and best low.",
}
## The cards each game's art shows (suit*13 + rank-1): a strong start for it.
const HANDS := {
	"holdem": [0, 25], "omaha": [0, 13, 12, 25], "draw": [0, 13, 26, 39, 12],
	"stud": [0, 13, 26], "short": [8, 21], "pineapple": [0, 25, 4], "crazy": [12, 25, 37],
	"omahahilo": [0, 14, 28, 41],
}
const LIMIT_NAMES := {"nl": "No limit", "pl": "Pot limit", "fl": "Limit"}

var variant := "holdem"
var body: VBoxContainer
var title_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(PokerFx.room())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := MarginContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		page.add_theme_constant_override("margin_" + side, 28)
	page.add_theme_constant_override("margin_top", 24)
	page.add_theme_constant_override("margin_bottom", 36)
	scroll.add_child(page)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	page.add_child(body)

## Fill the screen for game `v`. `d` = what the game knows: chips, hands
## (played in this game), net (chips), stars / stars_max (its Career ladder),
## quick (the Quick game's second line), limit, friends / online (available).
func open(v: String, d: Dictionary) -> void:
	variant = v
	for c in body.get_children():
		c.queue_free()
	var rules = Table.rules_for(v)
	# 🏠 Home and the chips
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	body.add_child(top)
	var home_b := HomeKit.neon_button(tr("🏠 Home"), HomeKit.BUTTON, 24, 60)
	home_b.custom_minimum_size.x = 150
	home_b.pressed.connect(home_pressed.emit)
	PokerFx.press(home_b)
	top.add_child(home_b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(_chip_pill("🪙 " + str(d.get("chips_text", ""))))
	# the hero: the game's hand, its name and line
	var hero := HandArt.new()
	hero.cards = HANDS.get(v, [0, 25])
	hero.custom_minimum_size = Vector2(0, 250)
	body.add_child(hero)
	title_label = HomeKit.label(tr(rules.title()).to_upper(), 46, Look.c("gold").lerp(Color.WHITE, 0.55), true, true)
	title_label.add_theme_color_override("font_outline_color", Color(Look.c("gold"), 0.45))
	title_label.add_theme_constant_override("outline_size", 12)
	body.add_child(title_label)
	body.add_child(HomeKit.label(tr(str(TAGLINES.get(v, ""))), 23, HomeKit.WHITE, true, true))
	var rec := tr("Hands played: %d") % int(d.get("hands", 0))
	if int(d.get("hands", 0)) > 0:
		rec += "  ·  " + tr("Net: %s") % str(d.get("net_text", "0"))
	rec += "  ·  🎯 ★ %d/%d" % [int(d.get("stars", 0)), int(d.get("stars_max", 0))]
	body.add_child(HomeKit.label(rec, 21, HomeKit.DIM, true, true))
	# betting
	var forced: String = rules.forced_limit()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	var group := ButtonGroup.new()
	for l in Table.LIMITS:
		var b := HomeKit.neon_button(tr(LIMIT_NAMES[l]), HomeKit.BUTTON, 22, 54)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var on := HomeKit.neon_box(HomeKit.BUTTON, "pressed")
		on.bg_color = Color(HomeKit.BUTTON, 0.45)
		on.set_border_width_all(3)
		b.add_theme_stylebox_override("pressed", on)
		b.disabled = forced != "" and l != forced
		b.button_pressed = l == (forced if forced != "" else str(d.get("limit", "nl")))
		b.pressed.connect(limit_picked.emit.bind(l))
		row.add_child(b)
	# ▶ Quick game: one tap to play (N6)
	var quick := HomeKit.neon_button("▶  " + tr("Quick game") + "\n" + str(d.get("quick", "")), HomeKit.GO, 30, 104)
	quick.pressed.connect(action.emit.bind("quick"))
	PokerFx.press(quick)
	body.add_child(quick)
	_shine(quick)
	# the ways to play this game
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	var tiles := [
		["career", "🎯", "Career", tr("%d bosses · ★ %d of %d") % [Career.ladder(v).size(), int(d.get("stars", 0)), int(d.get("stars_max", 0))]],
		["cash", "💰", "Cash game", tr("Sit down with the computer. Leave any time.")],
		["tourney", "🏆", "Tournaments", tr("Tournament, Sit & Go or Heads-up")],
		["stats", "📈", "My stats", tr("Your numbers and hands in this game")],
		["local", "👥", "Pass and play", tr("2 to 6 players share one phone")],
	]
	if bool(d.get("friends", false)):
		tiles.append(["friends", "🃏", "Friends table", tr("2 to 6 friends, each on their own phone")])
	if bool(d.get("online", false)):
		tiles.append(["online", "🌐", "Online", tr("Heads-up against a friend on another phone")])
	var k := 0
	for t in tiles:
		var tile := _tile(str(t[1]), tr(str(t[2])), str(t[3]))
		tile.pressed.connect(action.emit.bind(str(t[0])))
		if k == tiles.size() - 1 and tiles.size() % 2 == 1:
			body.add_child(tile)   # an odd last tile spans the row
		else:
			grid.add_child(tile)
		PokerFx.pop_in(tile, 0.08 + 0.04 * k)
		k += 1
	PokerFx.pop_in(hero, 0.0)

func _chip_pill(text: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.border_color = Color(Look.c("gold"), 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(30)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(HomeKit.label(text, 24, Look.c("gold").lerp(Color.WHITE, 0.3)))
	return p

## A tall glass tile: big icon, name, one line. One kit blue (STANDARDS §9).
static func _tile(icon: String, title: String, sub: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := HomeKit.neon_box(HomeKit.BUTTON, state)
		sb.bg_color = Color(0.02, 0.04, 0.09, 0.78) if state == "normal" else Color(HomeKit.BUTTON, 0.22)
		sb.set_corner_radius_all(18)
		sb.shadow_size = 12
		sb.shadow_offset = Vector2(0, 4)
		b.add_theme_stylebox_override(state, sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	for l in [HomeKit.label(icon, 40, Color.WHITE, false, true), HomeKit.label(title, 25, HomeKit.WHITE, true, true),
			HomeKit.label(sub, 18, HomeKit.DIM, true, true)]:
		(l as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	PokerFx.press(b)
	return b

## A light streak that crosses a button every few seconds (the one to tap).
static func _shine(b: Control) -> void:
	if PokerFx.reduced():
		return
	b.clip_contents = true
	var s := ColorRect.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.color = Color(1, 1, 1, 0.16)
	s.size = Vector2(46, 260)
	s.rotation = 0.35
	s.position = Vector2(-120, -60)
	b.add_child(s)
	var tw := s.create_tween().set_loops()
	tw.tween_interval(2.6)
	tw.tween_callback(func() -> void: s.position.x = -120.0)
	tw.tween_property(s, "position:x", 1400.0, 0.9).set_trans(Tween.TRANS_SINE)

# ---------- the Landing's game picker ----------

## The Landing's "Choose your game" block: a tile per game (2 columns) and
## wide tiles for Video Poker and Training. `on_pick(variant)` / `on_extra(key)`.
static func picker(on_pick: Callable, on_extra: Callable, last: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var head := HomeKit.label(TranslationServer.translate("Choose your game"), 30, Look.c("gold").lerp(Color.WHITE, 0.4), false, true)
	head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	head.add_theme_constant_override("outline_size", 8)
	box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	var k := 0
	for v in Table.VARIANTS:
		var t := GameTile.new()
		t.variant = v
		t.cards = HANDS.get(v, [0, 25])
		t.title = str(TranslationServer.translate(Table.rules_for(v).short_title()))
		t.sub = str(TranslationServer.translate(str(TAGLINES.get(v, ""))))
		t.last = v == last
		t.pressed.connect(on_pick.bind(v))
		grid.add_child(t)
		PokerFx.pop_in(t, 0.05 * k)
		k += 1
	for e in [["vp", "🎰", "Video Poker", "Jacks or Better, played with your chips"],
			["training", "🎓", "Training", "A coach at the table, hand rankings and drills"]]:
		var b := _tile(e[1], str(TranslationServer.translate(e[2])), str(TranslationServer.translate(e[3])))
		b.custom_minimum_size.y = 120
		b.pressed.connect(on_extra.bind(e[0]))
		box.add_child(b)
	return box

## A game on the picker: felt panel, its fanned cards, name and line.
class GameTile extends Button:
	var variant := ""
	var cards: Array = []
	var title := ""
	var sub := ""
	var last := false
	var art: HandArt

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 236)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var edge := Look.c("gold") if Look.is_classic() else Look.c("glow_a")
		for state in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Look.c("felt_deep") if state == "normal" else Look.c("felt")
			sb.bg_color.a = 0.92
			sb.border_color = Color(edge, 1.0 if (last or state != "normal") else 0.55)
			sb.set_border_width_all(3 if last else 2)
			sb.set_corner_radius_all(20)
			sb.shadow_color = Color(0, 0, 0, 0.55) if state == "normal" else Color(edge, 0.35)
			sb.shadow_size = 12
			sb.shadow_offset = Vector2(0, 5)
			add_theme_stylebox_override(state, sb)
		art = HandArt.new()
		art.cards = cards
		art.small = true
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		art.offset_top = 8
		art.offset_bottom = 128
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		add_child(v)
		v.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		v.offset_top = -104
		v.offset_bottom = -8
		v.offset_left = 10
		v.offset_right = -10
		var t := HomeKit.label(title, 26, Look.c("text"), true, true)
		t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		t.add_theme_constant_override("outline_size", 6)
		v.add_child(t)
		var s := HomeKit.label(sub, 18, Look.c("dim").lerp(Color.WHITE, 0.25), true, true)
		s.max_lines_visible = 3
		v.add_child(s)
		for l in [t, s]:
			(l as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
		PokerFx.press(self)
		button_down.connect(func() -> void: art.lift(true))
		button_up.connect(func() -> void: art.lift(false))

## A fan of cards with a soft glow under it; it breathes gently and lifts when
## its tile is pressed. Each card is its own node: Cards.draw_card resets the
## draw transform for its corner index, which would land at this node's origin.
class HandArt extends Control:
	var cards: Array = []
	var small := false
	var t := 0.0
	var up := 0.0
	var _calm := false
	var _nodes: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_calm = load("res://scripts/games/video_poker/video_poker_fx.gd").reduced()
		for c in cards:
			var n := OneCard.new()
			n.card = int(c)
			add_child(n)
			_nodes.append(n)
		resized.connect(_place)
		set_process(not _calm)
		_place()

	func lift(on: bool) -> void:
		var tw := create_tween()
		tw.tween_method(func(x: float) -> void:
			up = x
			_place(), up, 1.0 if on else 0.0, 0.14)

	func _process(delta: float) -> void:
		t += delta
		if is_visible_in_tree():
			_place()

	func _place() -> void:
		var n := _nodes.size()
		if size.y < 10 or n == 0:
			return
		var h := size.y * 0.86
		var w := h / 1.42
		var o := Vector2(size.x / 2.0, size.y * 0.52 - up * 6.0 + sin(t * 1.3) * 2.0)
		var spread := 0.16 if n <= 2 else (0.13 if n <= 3 else 0.1)
		var step := w * (0.5 if n <= 2 else (0.36 if n <= 4 else 0.3))
		for k in n:
			var f := k - (n - 1) / 2.0
			var c: Control = _nodes[k]
			c.size = Vector2(w, h)
			c.pivot_offset = Vector2(w / 2.0, h / 2.0)
			c.position = o + Vector2(f * step, absf(f) * h * 0.05) - c.pivot_offset
			c.rotation = f * spread * (1.0 + up * 0.25) + sin(t * 0.9 + k) * 0.012
		queue_redraw()

	func _draw() -> void:
		if size.y < 10 or _nodes.is_empty():
			return
		var h := size.y * 0.86
		var w := h / 1.42
		var o := Vector2(size.x / 2.0, size.y * 0.52 - up * 6.0)
		var glow := Look.c("gold") if Look.is_classic() else Look.c("glow_a")
		draw_set_transform(o + Vector2(0, h * 0.42), 0.0, Vector2(1.0, 0.28))
		for r in [[w * 1.6, 0.06], [w * 1.1, 0.08], [w * 0.7, 0.1]]:
			draw_circle(Vector2.ZERO, r[0] + _nodes.size() * 6.0, Color(glow, r[1]))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

class OneCard extends Control:
	var card := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if size.y > 4:
			Cards.draw_card(self, Rect2(Vector2.ZERO, size), card, true, false)
