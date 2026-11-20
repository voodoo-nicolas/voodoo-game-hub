extends RefCounted

## Beached's own Landing (owner, 2026-11-20: "something sleeker; only resume, new, options and back to hub;
## the rest under options"). Plugged into the Landing kit as cfg "landing": "beached" + "landing_style": this
## script (the kit's styled-Landing hook, docs/claude/landing-styles.md). The art fills the screen; four quiet
## glass buttons sit low on the left. How to Play, 🏆, 🏅 and 📊 move into ⚙ Options (`options`), so every
## STANDARDS Landing item stays reachable, one tap deeper.

static func build(kit, home: Control) -> Control:
	if str(kit.cfg.get("landing", "")) != "beached":
		return null
	var node := BeachedLanding.new(kit)
	home.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return node

## Inside ⚙ Options: the Landing's other buttons, as a short list.
static func options(kit, body: VBoxContainer) -> void:
	body.add_child(kit._section(kit.tr("More")))
	var rows: Array = [[kit.tr("❓ How to Play"), Callable(kit, "_show_overlay").bind(null, "info")]]
	if kit._board_key() != "none":
		rows.append([kit.tr("🏆 Leaderboard"), Callable(kit, "_show_leaderboard")])
	if kit.info and kit.info.has_method("achievement_rows"):
		rows.append([kit.tr("🏅 Achievements"), Callable(kit, "_show_achievements")])
	rows.append([kit.tr("📊 Statistics"), Callable(kit, "_show_stats")])
	for r in rows:
		var b: Button = kit.neon_button(str(r[0]), kit.BUTTON, 26, 66)
		b.pressed.connect(r[1])
		body.add_child(b)

class BeachedLanding extends Control:
	const ART := "res://games/wilson/art/landing_logo.webp"
	const GLASS := Color(0.03, 0.06, 0.1, 0.62)
	const EDGE := Color(1, 1, 1, 0.16)
	const SAND := Color("ffd98a")
	const GREEN := Color("2bff88")

	var kit
	var _art: TextureRect
	var _col: VBoxContainer
	var _resume: Button

	func _init(k) -> void:
		kit = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# the kit's refresh() sets these; hidden stand-ins, as the shared menu styles do
		kit.resume_btn = _dummy()
		kit.quick_btn = _dummy()
		kit._split_modes()

	func _dummy() -> Button:
		var b := Button.new()
		b.visible = false
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.focus_mode = Control.FOCUS_NONE
		add_child(b)
		return b

	func _ready() -> void:
		_art = TextureRect.new()
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if ResourceLoader.exists(ART):
			_art.texture = load(ART)
		add_child(_art)
		_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# a soft dark band on the left so the buttons read over any part of the art
		var shade := TextureRect.new()
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.55))
		g.set_color(1, Color(0, 0, 0, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_to = Vector2(1, 0)
		shade.texture = gt
		shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shade.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(shade)
		shade.anchor_bottom = 1.0
		shade.anchor_right = 0.45
		_col = VBoxContainer.new()
		_col.add_theme_constant_override("separation", 12)
		add_child(_col)
		_resume = _button("▶  " + kit.tr("Resume"), GREEN, Callable(kit, "_on_resume"))
		var modes: Array = kit.cfg.get("modes", [])      # read from cfg: the kit sorts its _solo list after building the style
		if not modes.is_empty():
			_button("🏝  " + kit.tr("New island"), SAND, Callable(kit, "_on_mode").bind(modes[0]))
		_button("⚙  " + kit.tr("Options"), Color.WHITE, Callable(kit, "_show_options"))
		_button("←  " + kit.tr("Hub"), Color(1, 1, 1, 0.75), Callable(kit, "_on_hub_pressed"))
		resized.connect(_layout)
		refresh()

	func _button(text: String, color: Color, action: Callable) -> Button:
		var b := Button.new()
		b.text = text
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 28)
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(st, color)
		for state in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = GLASS.lightened(0.12) if state in ["hover", "pressed"] else GLASS
			sb.border_color = color if state in ["hover", "pressed"] else EDGE
			sb.set_border_width_all(2)
			sb.border_width_left = 4
			sb.set_corner_radius_all(14)
			sb.content_margin_left = 22
			sb.content_margin_right = 22
			b.add_theme_stylebox_override(state, sb)
		b.custom_minimum_size = Vector2(320, 64)
		b.pressed.connect(action)
		_col.add_child(b)
		return b

	func _layout() -> void:
		var vs := size
		var w := clampf(vs.x * 0.32, 280.0, 420.0)
		_col.custom_minimum_size.x = w
		_col.reset_size()
		var h := _col.get_combined_minimum_size().y
		var safe := Vector2(36, 28)
		_col.position = Vector2(safe.x + 24.0, vs.y - h - safe.y - vs.y * 0.08)
		_col.size = Vector2(w, h)

	# ----- the kit's hooks -----

	func refresh() -> void:
		if _resume == null:
			return          # called before the node is in the tree; _ready() refreshes
		_resume.visible = kit.resume_btn.visible
		_layout()

	func set_active(_on: bool) -> void:
		pass
