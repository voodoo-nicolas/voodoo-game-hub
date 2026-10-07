extends Control

## Party Spinner -- tap the wheel (or Spin) for the next move. Auto-spin calls
## a new move every few seconds so nobody has to leave the mat.

const PSEngine = preload("res://scripts/games/party_spinner/party_spinner_engine.gd")
const HomeKit = preload("res://scripts/games/party_spinner/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

## The mat's four colours as neons (red, blue, yellow, green).
const WHEEL_COLORS := [Color("ff3b6b"), Color("29a8ff"), Color("ffd23a"), Color("7dff3a")]
const AUTO_OPTIONS := [0, 8, 12, 20]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: PSEngine
var wheel: Control
var result_label: Label
var result_panel: PanelContainer
var history_label: Label
var auto_btn: Button
var auto_timer: Timer
var angle: float = 0.0
var spin_from: float = 0.0
var spin_to: float = 0.0
var spin_t: float = 1.0
var auto_index: int = 0
var pending: int = -1
var last_sector: int = 0  # for the tick as each sector passes the pointer

func _ready() -> void:
	preload("res://scripts/games/party_spinner/party_spinner_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = PSEngine.new()
	_build_ui()
	_update_result()

func _limb_names() -> Array:
	return [tr("Left hand"), tr("Right hand"), tr("Left foot"), tr("Right foot")]

func _color_names() -> Array:
	return [tr("Red"), tr("Blue"), tr("Yellow"), tr("Green")]

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🌀 Party Spinner")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var spacer_btn := Control.new()
	spacer_btn.custom_minimum_size = Vector2(60, 0)
	bar.add_child(spacer_btn)

	var rm := MarginContainer.new()
	rm.add_theme_constant_override("margin_left", 48)  # room for the ⚙ tab
	rm.add_theme_constant_override("margin_right", 48)
	root.add_child(rm)
	result_panel = PanelContainer.new()
	rm.add_child(result_panel)
	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 40)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.custom_minimum_size = Vector2(0, 110)
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	result_panel.add_child(result_label)

	wheel = Control.new()
	wheel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wheel.mouse_filter = Control.MOUSE_FILTER_STOP
	wheel.draw.connect(_draw_wheel)
	wheel.gui_input.connect(_on_wheel_input)
	wheel.resized.connect(wheel.queue_redraw)
	root.add_child(wheel)

	history_label = Label.new()
	history_label.add_theme_font_size_override("font_size", 24)
	history_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	history_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(history_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 36)
	bm.add_child(row)
	root.add_child(bm)
	var spin_btn := Button.new()
	spin_btn.text = tr("🌀 Spin")
	spin_btn.custom_minimum_size = Vector2(260, 84)
	spin_btn.add_theme_font_size_override("font_size", 32)
	spin_btn.set_meta("sfx", "")  # the wheel ticks itself
	spin_btn.pressed.connect(_spin)
	row.add_child(spin_btn)
	auto_btn = Button.new()
	auto_btn.custom_minimum_size = Vector2(260, 84)
	auto_btn.add_theme_font_size_override("font_size", 24)
	auto_btn.pressed.connect(_cycle_auto)
	row.add_child(auto_btn)

	auto_timer = Timer.new()
	auto_timer.timeout.connect(_spin)
	add_child(auto_timer)
	_update_auto()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/party_spinner/party_spinner_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _cycle_auto() -> void:
	auto_index = (auto_index + 1) % AUTO_OPTIONS.size()
	_update_auto()

func _update_auto() -> void:
	var secs: int = AUTO_OPTIONS[auto_index]
	auto_timer.stop()
	if secs == 0:
		auto_btn.text = tr("Auto-spin: off")
	else:
		auto_btn.text = tr("Auto-spin: %ds") % secs
		auto_timer.wait_time = secs
		auto_timer.start()

func _spin() -> void:
	if spin_t < 1.0:
		return
	pending = engine.spin()
	if info:
		info.add("Spins")
	# the pointer is at the top; land the middle of the chosen sector there
	var sector_angle := TAU / 16.0
	var target := -(pending + 0.5) * sector_angle
	var turns := TAU * randi_range(3, 5)
	spin_from = angle
	spin_to = angle - fposmod(angle - target, TAU) - turns
	spin_t = 0.0
	result_label.text = "…"

func _process(delta: float) -> void:
	if spin_t >= 1.0:
		return
	spin_t = min(1.0, spin_t + delta / 2.6)
	var eased := 1.0 - pow(1.0 - spin_t, 3.0)
	angle = lerp(spin_from, spin_to, eased)
	wheel.queue_redraw()
	var sector := int(floor(angle / (TAU / 16.0)))
	if sector != last_sector:
		last_sector = sector
		_sfx("spin_tick")
	if spin_t >= 1.0:
		angle = fposmod(angle, TAU)
		last_sector = int(floor(angle / (TAU / 16.0)))
		_sfx("notify")
		_update_result()

func _update_result() -> void:
	var r := engine.last()
	# A neon sign in the colour that came up.
	var col: Color = HomeKit.PURPLE if r.x < 0 else WHEEL_COLORS[r.y]
	var sb := HomeKit.neon_box(col, "pressed")
	sb.set_corner_radius_all(18)
	sb.bg_color = Color(col, 0.16)
	sb.shadow_size = 16
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	result_label.add_theme_color_override("font_outline_color", Color(col, 0.55))
	result_label.add_theme_constant_override("outline_size", 8)
	if r.x < 0:
		result_label.text = tr("Tap the wheel to spin!")
		result_label.add_theme_color_override("font_color", Color(1, 1, 1))
	else:
		result_label.text = "%s → %s" % [_limb_names()[r.x], _color_names()[r.y]]
		result_label.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.6))
	result_panel.add_theme_stylebox_override("panel", sb)
	var parts: Array = []
	var hist: Array = engine.history.duplicate()
	hist.reverse()
	for h in hist.slice(1, 6):
		parts.append("%s %s" % [_limb_names()[h.x], _color_names()[h.y].to_lower()])
	history_label.text = (tr("Before:") + " " + " · ".join(PackedStringArray(parts))) if not parts.is_empty() else ""

func _draw_wheel() -> void:
	var c := wheel.size / 2.0
	var r: float = min(wheel.size.x, wheel.size.y) / 2.0 - 20.0
	# Neon wheel (ART_STYLE): dark glass segments tinted by colour, each with
	# a glowing rim arc; glowing spokes between limbs; a white-hot hub.
	wheel.draw_circle(c, r + 12, Color(0.02, 0.02, 0.06))
	HomeKit.glow_circle(wheel, c, r + 8, Color(HomeKit.PURPLE, 0.9), 2.0)
	var font: Font = ThemeDB.fallback_font
	var limb_short := [tr("Lh").to_upper(), tr("Rh").to_upper(), tr("Lf").to_upper(), tr("Rf").to_upper()]
	var seg := TAU / 16.0
	for s in 16:
		var a0 := angle + s * seg - PI / 2.0
		var pts := PackedVector2Array([c])
		for k in 9:
			var a := a0 + seg * k / 8.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		var col: Color = WHEEL_COLORS[s % 4]
		wheel.draw_colored_polygon(pts, Color(col, 0.2 if (s / 4) % 2 == 0 else 0.13))
		# rim arc for this segment, a little inset so neighbours don't merge
		var rim := PackedVector2Array()
		for k in 9:
			var a := a0 + seg * (0.06 + 0.88 * k / 8.0)
			rim.append(c + Vector2(cos(a), sin(a)) * (r - 6.0))
		HomeKit.glow_polyline(wheel, rim, col, 3.0)
		var mid := a0 + seg / 2.0
		var lp := c + Vector2(cos(mid), sin(mid)) * r * 0.72
		HomeKit.glow_text(wheel, lp, limb_short[s / 4], int(r * 0.09), col)
	# dividers between limbs
	for q in 4:
		var a := angle + q * 4 * seg - PI / 2.0
		HomeKit.glow_line(wheel, c + Vector2(cos(a), sin(a)) * r * 0.17, c + Vector2(cos(a), sin(a)) * r, HomeKit.WHITE, 2.0)
	wheel.draw_circle(c, r * 0.16, Color(0.03, 0.03, 0.08))
	HomeKit.glow_circle(wheel, c, r * 0.16, HomeKit.WHITE, 2.5)
	HomeKit.glow_circle(wheel, c, r * 0.06, HomeKit.GOLD, 2.0, 0.9)
	# the pointer at the top
	var tip := c + Vector2(0, -r + 26)
	var ptr := PackedVector2Array([tip, c + Vector2(-24, -r - 18), c + Vector2(24, -r - 18)])
	wheel.draw_colored_polygon(ptr, Color(1, 1, 1, 0.25))
	HomeKit.glow_polyline(wheel, ptr, HomeKit.WHITE, 2.5, true)

func _on_wheel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_spin()

# ---------- Home screen (home_kit.gd) ----------

func _build_home() -> void:
	home = HomeKit.new({
		"retro": true,
		"help": preload("res://scripts/games/party_spinner/party_spinner_help.gd"),
		"info": info,
		"accent": HomeKit.LIME,
		"subtitle": "The spinner for the body-twisting mat game.",
		"logo": _draw_home_logo,
		"multi_heading": "Party · one phone, a group of friends",
		"modes": [{"text": "🌀  Spin", "sub": "Tap the wheel or the button", "multi": true, "color": HomeKit.LIME, "action": _update_result}],
		"board": "Spins",
		"board_note": "Spins, all time.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var r := minf(c.size.y * 0.45, 80.0)
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	var cols := [HomeKit.PINK, HomeKit.BLUE, HomeKit.GOLD, HomeKit.LIME]
	for k in 4:
		var pts := PackedVector2Array([ctr])
		for i in 13:
			var a := TAU * (k + i / 12.0) / 4.0
			pts.append(ctr + Vector2(cos(a), sin(a)) * r)
		c.draw_colored_polygon(pts, Color(cols[k], 0.22))
	HomeKit.glow_circle(c, ctr, r, Color.WHITE, 2.0)
	HomeKit.glow_line(c, ctr, ctr + Vector2(cos(-0.9), sin(-0.9)) * r * 0.85, Color.WHITE, 3.0)
	HomeKit.glow_circle(c, ctr, r * 0.08, Color.WHITE, 2.0, 1.0)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
