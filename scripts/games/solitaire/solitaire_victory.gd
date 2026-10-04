extends Control

## Solitaire's win screen. First the classic cascade: the cards leave the
## foundations one by one (Kings first), bounce along the bottom of the
## screen and leave a fading neon trail. Then a results panel slides in over
## it, counting up the time and moves, with New deal / History /
## Leaderboard / Home. A tap during the cascade brings the panel at once.
##
## Drawn in code into this one Control (cards, trails); the panel is plain
## Controls. Lives in the game's scene, so leaving the game stops it.

signal new_deal
signal show_history
signal show_leaderboard
signal go_home

const HomeKit = preload("res://scripts/games/solitaire/home_kit.gd")
const CardView = preload("res://scripts/games/solitaire/card_view.gd")

const GRAVITY := 2600.0
const BOUNCE := 0.74
const LAUNCH_GAP := 0.075   # seconds between cards leaving the foundations
const STAMP_GAP := 0.018    # seconds between trail stamps of one card
const STAMP_LIFE := 2.4     # seconds a trail stamp takes to fade out
const MAX_STAMPS := 900
const PANEL_AFTER := 3.4    # seconds of cascade before the panel comes in (a tap: sooner)

var _stacks: Array = []     # per suit: the cards still on the foundation
var _slots: Array = []      # per suit: Rect2 of the foundation, in local coords
var _card_size := Vector2(84, 118)
var _flying: Array = []     # {card, pos, vel, stamp}
var _stamps: Array = []     # [pos, card, age]
var _launch_t := 0.0
var _next_suit := 0
var _time := 0.0
var _running := false
var _font: Font

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _tiles: HBoxContainer
var _win_no: Label
var _stats: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = get_theme_default_font()
	_build_panel()

## `foundations`: the engine's 4 full foundation piles. `slots`: where each
## is on screen (in this Control's coordinates). `stats`: time (seconds),
## moves, wins, win_no, best_time / best_moves (bools: new records).
func start(foundations: Array, slots: Array, stats: Dictionary) -> void:
	_stacks = []
	for f in foundations:
		_stacks.append(f.duplicate())
	_slots = slots
	_card_size = slots[0].size if not slots.is_empty() else Vector2(84, 118)
	_flying.clear()
	_stamps.clear()
	_launch_t = 0.25
	_next_suit = 0
	_time = 0.0
	_stats = stats
	_running = true
	visible = true
	_dim.color.a = 0.0
	_panel.visible = false
	queue_redraw()

func stop() -> void:
	_running = false
	visible = false
	_flying.clear()
	_stamps.clear()

func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tap and not _panel.visible:
		_show_panel()
		accept_event()

func _process(delta: float) -> void:
	if not _running:
		return
	_time += delta
	if _time >= PANEL_AFTER and not _panel.visible:
		_show_panel()
	_launch_t -= delta
	while _launch_t <= 0.0 and _launch_one():
		_launch_t += LAUNCH_GAP
	var floor_y: float = size.y - _card_size.y
	var alive: Array = []
	for f in _flying:
		f.vel.y += GRAVITY * delta
		f.pos += f.vel * delta
		if f.pos.y > floor_y:
			f.pos.y = floor_y
			f.vel.y = -absf(f.vel.y) * BOUNCE
			if absf(f.vel.y) < 90.0:
				f.vel.y = 0.0
		f.stamp -= delta
		if f.stamp <= 0.0:
			f.stamp = STAMP_GAP
			_stamps.append([f.pos, f.card, 0.0])
		if f.pos.x > -_card_size.x and f.pos.x < size.x:
			alive.append(f)
	_flying = alive
	for s in _stamps:
		s[2] += delta
	while not _stamps.is_empty() and (_stamps[0][2] > STAMP_LIFE or _stamps.size() > MAX_STAMPS):
		_stamps.pop_front()
	queue_redraw()

## Next card off the foundations, Kings first, round the four suits.
func _launch_one() -> bool:
	for i in 4:
		var s: int = (_next_suit + i) % 4
		if s < _stacks.size() and not _stacks[s].is_empty():
			_next_suit = (s + 1) % 4
			var card = _stacks[s].pop_back()
			var dir: float = -1.0 if randf() < 0.5 else 1.0
			_flying.append({
				"card": card,
				"pos": _slots[s].position,
				"vel": Vector2(dir * randf_range(260.0, 620.0), randf_range(-900.0, -150.0)),
				"stamp": 0.0,
			})
			_sfx("card_deal")
			return true
	return false

func _draw() -> void:
	# The cards still waiting on the foundations.
	for s in _stacks.size():
		if s < _slots.size() and not _stacks[s].is_empty():
			_draw_card(_slots[s].position, _stacks[s].back(), 1.0, true)
	for st in _stamps:
		var a: float = 1.0 - st[2] / STAMP_LIFE
		_draw_card(st[0], st[1], a * a * 0.9, false)
	for f in _flying:
		_draw_card(f.pos, f.card, 1.0, true)

func _draw_card(p: Vector2, card, alpha: float, glow: bool) -> void:
	var r := Rect2(p, _card_size)
	var rim: Color = CardView.COLOR_RED if card.is_red() else CardView.COLOR_BLACK
	draw_rect(r, Color(CardView.COLOR_FACE, alpha))
	if glow:
		draw_rect(r.grow(3), Color(rim, 0.25), false, 4.0)
	draw_rect(r, Color(rim, alpha), false, 2.0)
	var k: float = _card_size.x / 84.0
	var sym: String = card.suit_symbol()
	draw_string(_font, p + Vector2(6, 26) * k, card.rank_str() + sym, HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(22 * k), Color(rim.lerp(Color.WHITE, 0.25), alpha))
	draw_string(_font, p + Vector2(0, _card_size.y * 0.72), sym, HORIZONTAL_ALIGNMENT_CENTER, _card_size.x,
		int(40 * k), Color(rim, alpha))

# ---------- results panel ----------

func _build_panel() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.015, 0.04, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(HomeKit.PANEL, 0.94)
	sb.border_color = HomeKit.LIME
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(HomeKit.LIME, 0.35)
	sb.shadow_size = 18
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 26
	sb.content_margin_bottom = 28
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.visible = false
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_panel.add_child(box)

	_title = Label.new()
	_title.text = tr("You Win!").to_upper()
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 76)
	_title.add_theme_color_override("font_color", HomeKit.GOLD.lerp(Color.WHITE, 0.55))
	_title.add_theme_color_override("font_outline_color", Color(HomeKit.GOLD, 0.7))
	_title.add_theme_constant_override("outline_size", 16)
	box.add_child(_title)

	_win_no = HomeKit.label("", 26, HomeKit.DIM, false, true)
	box.add_child(_win_no)

	_tiles = HBoxContainer.new()
	_tiles.add_theme_constant_override("separation", 12)
	box.add_child(_tiles)

	box.add_child(HomeKit.gap(4))
	var again := HomeKit.neon_button(tr("🃏  New deal"), HomeKit.LIME, 32, 88)
	again.pressed.connect(func(): new_deal.emit())
	box.add_child(again)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for it in [[tr("📜 History"), HomeKit.PURPLE, show_history], [tr("🏆 Leaderboard"), HomeKit.GOLD, show_leaderboard]]:
		var b := HomeKit.neon_button(it[0], it[1], 26, 74)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): it[2].emit())
		row.add_child(b)
	var home := HomeKit.neon_button(tr("🏠 %s Home") % tr("Solitaire"), HomeKit.DIM, 26, 70)
	home.pressed.connect(func(): go_home.emit())
	box.add_child(home)

func _show_panel() -> void:
	_panel.visible = true
	_panel.custom_minimum_size.x = minf(size.x - 40.0, 620.0)
	_win_no.text = tr("Win #%d") % int(_stats.get("win_no", 1))
	for c in _tiles.get_children():
		c.queue_free()
	_tiles.add_child(_tile(tr("Time"), HomeKit.CYAN, float(_stats.get("time", 0)), true, _stats.get("best_time", false)))
	_tiles.add_child(_tile(tr("Moves"), HomeKit.PINK, float(_stats.get("moves", 0)), false, _stats.get("best_moves", false)))
	_tiles.add_child(_tile(tr("Games won"), HomeKit.LIME, float(_stats.get("wins", 1)), false, false))

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.6, 0.35)
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.7, 0.7)
	_panel.pivot_offset = _panel.get_combined_minimum_size() / 2.0
	tw.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The title breathes.
	_title.pivot_offset = Vector2(_title.size.x / 2.0, _title.size.y / 2.0)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_title, "theme_override_colors/font_outline_color", Color(HomeKit.LIME, 0.8), 0.7)
	pulse.tween_property(_title, "theme_override_colors/font_outline_color", Color(HomeKit.GOLD, 0.7), 0.7)

## One stat: caption, a number that counts up, and a NEW BEST badge.
func _tile(caption: String, color: Color, value: float, is_time: bool, record: bool) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.1)
	sb.border_color = Color(HomeKit.GOLD if record else color, 0.85)
	sb.set_border_width_all(3 if record else 2)
	sb.set_corner_radius_all(14)
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	if record:
		sb.shadow_color = Color(HomeKit.GOLD, 0.4)
		sb.shadow_size = 10
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	v.add_child(HomeKit.label(caption, 22, HomeKit.DIM, false, true))
	var num := HomeKit.label("0", 44, color.lerp(Color.WHITE, 0.45), false, true)
	num.add_theme_color_override("font_outline_color", Color(color, 0.5))
	num.add_theme_constant_override("outline_size", 6)
	v.add_child(num)
	var badge := HomeKit.label(tr("New best!") if record else " ", 20, HomeKit.GOLD, false, true)
	v.add_child(badge)
	var show := func(x: float) -> void:
		num.text = _fmt(x, is_time)
	create_tween().tween_method(show, 0.0, value, 1.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT).set_delay(0.2)
	return p

func _fmt(x: float, is_time: bool) -> String:
	if is_time:
		var t := int(x)
		return "%d:%02d" % [int(t / 60), t % 60]
	return str(int(round(x)))

func _sfx(sound: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound, -6.0)
