extends RefCounted

## Amazonia's own Landing (owner, 2026-11-26): four big rows, animated.
##   🎯 Single player  -> opens to: 📜 Contracts / ⚡ Quick Play (vs Computer at the Options difficulty)
##   👥 Multiplayer    -> opens to: 📱 1 phone, 2 players / 🌐 Online
##   🛒 Shop (with your ⭐)
##   ⚙ Game Options    (your amazon, single-player difficulty, then the kit's usual options;
##                       How to Play, 🏆, 🏅 and 📊 sit there too: no bottom bar)
## plus ▶ Resume when a save exists and ← Hub (STANDARDS N1).
## Plugged into the Landing kit as cfg "landing": "amazonia" + "landing_style": this script
## (the kit's styled-Landing hook, docs/claude/landing-styles.md; Beached's wilson_landing.gd is the model).
## The game passes cfg "aa_shop" (opens the Shop), "aa_wallet" (-> stars), "aa_quick" (-> the mode to start)
## and "aa_avatar" (-> {"ch": her dressed character, "emote": id}). Since 2026-11-27 (owner) the menu sits
## on the left and your amazon stands on the right, about 75% of the screen tall; tap her for your emote.

static func build(kit, home: Control) -> Control:
	if str(kit.cfg.get("landing", "")) != "amazonia":
		return null
	var node := AmazoniaLanding.new(kit)
	home.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return node

## Inside ⚙ Options, after the game's own section: what used to be the bottom bar.
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

class AmazoniaLanding extends Control:
	const ART := "res://games/ancient_assassins/landing_bg.jpg"
	const TITLE_FONT := "res://games/ancient_assassins/title.ttf"
	const GLASS := Color(0.04, 0.07, 0.05, 0.7)
	const EDGE := Color(1, 1, 1, 0.16)
	const GOLD := Color("ffc24a")
	const LEAF := Color("7fe08a")
	const GREEN := Color("2bff88")
	const SUB_H := 62.0
	const CHAR_SCRIPT := "res://scripts/games/ancient_assassins/aa_character.gd"
	const MENU_W := 0.58          # the menu's share of the width (left); she stands in the right half
	const AVATAR_H := 0.82        # the stage's share of the height; she fills ~92% of it = ~75% of the screen

	var kit
	var _col: VBoxContainer
	var _title: Label
	var _resume: Button
	var _shop: Button
	var _rows: Array = []          # every top-level button, for the entrance
	var _groups: Array = []        # [head Button, holder Control, inner VBox, arrow text]
	var _open := -1
	var _stage: Control            # holds the 3D viewport of her
	var _view: SubViewport
	var _hero: Node3D
	var _hero_sig := ""

	func _init(k) -> void:
		kit = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		var art := TextureRect.new()
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if ResourceLoader.exists(ART):
			art.texture = load(ART)
		add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# dark at the foot, where the buttons sit
		var shade := TextureRect.new()
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.75)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		shade.texture = gt
		shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shade.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		_make_stage()

		_title = Label.new()
		_title.text = kit.tr("Amazonia")
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title.add_theme_font_size_override("font_size", 76)
		if ResourceLoader.exists(TITLE_FONT):
			_title.add_theme_font_override("font", load(TITLE_FONT))
		_title.add_theme_color_override("font_color", Color("ffd77a"))
		_title.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02, 0.9))
		_title.add_theme_constant_override("outline_size", 14)
		_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_title)

		_col = VBoxContainer.new()
		_col.add_theme_constant_override("separation", 10)
		add_child(_col)
		_resume = _button(_col, "▶  " + kit.tr("Resume"), GREEN, Callable(kit, "_on_resume"))
		_rows.append(_resume)
		var single := [
			["📜  " + kit.tr("Contracts"), _contract],
			["⚡  " + kit.tr("Quick Play"), _quick],
		]
		_group("🎯  " + kit.tr("Single player"), single)
		var multi: Array = [["📱  " + kit.tr("1 phone, 2 players"), _mode_by_key.bind("2p")]]
		if kit.cfg.get("online") != null:
			multi.append(["🌐  " + kit.tr("Online"), _mode_by_key.bind("online")])
		_group("👥  " + kit.tr("Multiplayer"), multi)
		_shop = _button(_col, "", GOLD, _on_shop)
		_rows.append(_shop)
		_rows.append(_button(_col, "⚙  " + kit.tr("Game Options"), Color.WHITE, Callable(kit, "_show_options")))
		_rows.append(_button(_col, "←  " + kit.tr("Hub"), Color(1, 1, 1, 0.75), Callable(kit, "_on_hub_pressed")))
		resized.connect(_layout)
		visibility_changed.connect(_on_visible)
		refresh()
		_enter()

	## The 3D stage of her, behind the menu (added before it).
	func _make_stage() -> void:
		var cs = load(CHAR_SCRIPT)
		if cs == null:
			return
		_stage = Control.new()
		_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_stage)
		_view = cs.make_stage(_stage, 100.0, false)
		var vc := _view.get_parent() as Control
		vc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vc.mouse_filter = Control.MOUSE_FILTER_STOP
		vc.gui_input.connect(_on_avatar_input)
		_view.get_node("Cam").fov = 40.0
		cs.frame_cam(_view, 1.13)

	## Her, dressed as she is now (rebuilt only when her look changed).
	func _refresh_hero() -> void:
		if _view == null:
			return
		var a = kit.cfg.get("aa_avatar")
		if not (a is Callable):
			return
		var info: Dictionary = a.call()
		var ch: Dictionary = info.get("ch", {})
		var sig := str(ch)
		if sig == _hero_sig and _hero and is_instance_valid(_hero):
			return
		_hero_sig = sig
		if _hero and is_instance_valid(_hero):
			_hero.queue_free()
		_hero = load(CHAR_SCRIPT).new()
		_view.add_child(_hero)
		_hero.build(ch, false)
		_hero.play("idle", 0.0)
		_hero.rotation.y = -0.4      # a little turned towards the menu

	func _on_avatar_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var a = kit.cfg.get("aa_avatar")
			if a is Callable and _hero and is_instance_valid(_hero):
				var id := str((a.call() as Dictionary).get("emote", ""))
				if id != "":
					_hero.play_emote(id)

	func _button(parent: Control, text: String, color: Color, action: Callable, h: float = 70.0, fs: int = 30) -> Button:
		var b := Button.new()
		b.text = text
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", fs)
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(st, color)
		for state in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = GLASS.lightened(0.12) if state in ["hover", "pressed"] else GLASS
			sb.border_color = color if state in ["hover", "pressed"] else EDGE
			sb.set_border_width_all(2)
			sb.border_width_left = 5
			sb.border_color = Color(color, 0.9) if state in ["hover", "pressed"] else EDGE
			sb.set_corner_radius_all(16)
			sb.content_margin_left = 24
			sb.content_margin_right = 24
			b.add_theme_stylebox_override(state, sb)
		b.custom_minimum_size = Vector2(0, h)
		if action.is_valid():
			b.pressed.connect(action)
		b.button_down.connect(_squash.bind(b))
		parent.add_child(b)
		return b

	## A head row that opens a drawer of sub-buttons under it.
	func _group(text: String, items: Array) -> void:
		var head := _button(_col, text + "", LEAF, Callable())
		head.pressed.connect(_toggle.bind(_groups.size()))
		_rows.append(head)
		var holder := Control.new()          # its height animates; clips the drawer
		holder.clip_contents = true
		holder.custom_minimum_size = Vector2(0, 0)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_col.add_child(holder)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 8)
		holder.add_child(inner)
		for it in items:
			var b := _button(inner, str(it[0]), Color.WHITE, it[1], SUB_H, 26)
			var st := b.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			st.content_margin_left = 64     # indented under the head
			for state in ["normal", "focus"]:
				b.add_theme_stylebox_override(state, st)
		holder.visible = false
		_groups.append([head, holder, inner, text, items.size()])
		_set_arrow(_groups.size() - 1, false)

	func _set_arrow(i: int, open: bool) -> void:
		var g: Array = _groups[i]
		(g[0] as Button).text = str(g[3]) + ("   ▾" if open else "   ▸")

	func _toggle(i: int) -> void:
		if kit._dragged():
			return
		var was := _open
		_open = -1 if was == i else i
		for k in _groups.size():
			_animate_group(k, k == _open)

	func _animate_group(i: int, open: bool) -> void:
		var g: Array = _groups[i]
		var holder: Control = g[1]
		var inner: VBoxContainer = g[2]
		_set_arrow(i, open)
		var target := (SUB_H + 8.0) * int(g[4]) + 2.0 if open else 0.0
		if not open and not holder.visible:
			return
		holder.visible = true
		var tw := holder.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK if open else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(holder, "custom_minimum_size:y", target, 0.34 if open else 0.22)
		tw.tween_property(inner, "modulate:a", 1.0 if open else 0.0, 0.25)
		if open:
			inner.modulate.a = 0.0
			# the drawer's buttons drop in one after the other
			var n := 0
			for b in inner.get_children():
				(b as Control).position.x = 60.0
				var bt := b.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
				bt.tween_interval(0.05 + 0.07 * n)
				bt.tween_property(b, "position:x", 0.0, 0.3)
				n += 1
		else:
			tw.chain().tween_callback(holder.hide)
		# the rest of the column follows the drawer: re-place every frame of the tween
		tw.set_parallel(false)
		var lt := create_tween()
		lt.tween_method(_relayout_step, 0.0, 1.0, 0.36)
		inner.size.x = holder.size.x

	func _relayout_step(_t: float) -> void:
		_layout()

	func _squash(b: Button) -> void:
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2(0.96, 0.96), 0.06)
		tw.tween_property(b, "scale", Vector2.ONE, 0.22)

	## The entrance: the title drops, the rows slide in from the left one by one.
	func _enter() -> void:
		_title.modulate.a = 0.0
		_title.scale = Vector2(1.25, 1.25)
		var tt := _title.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tt.tween_property(_title, "modulate:a", 1.0, 0.4)
		tt.tween_property(_title, "scale", Vector2.ONE, 0.55)
		var n := 0
		for b in _rows:
			if not (b as Control).visible:
				continue
			b.modulate.a = 0.0
			var tw := (b as Control).create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.12 + 0.07 * n)
			tw.tween_property(b, "modulate:a", 1.0, 0.25)
			n += 1
		# position:x is the container's to set; slide the whole column instead
		_col.modulate.a = 1.0
		var off := -size.x * 0.6
		_layout()
		var x := _col.position.x
		_col.position.x = x + off
		var ct := _col.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		ct.tween_property(_col, "position:x", x, 0.5)
		if _stage:
			_stage.modulate.a = 0.0
			var st := _stage.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			st.tween_property(_stage, "modulate:a", 1.0, 0.5).set_delay(0.15)

	func _on_visible() -> void:
		if is_visible_in_tree():
			refresh()
			_enter()

	func _layout() -> void:
		var vs := size
		if vs.x <= 0.0:
			return
		# Menu on the left, her on the right.
		var w := clampf(vs.x * MENU_W, 270.0, 520.0)
		var fs := 28 if w < 440.0 else 30
		var sub_fs := 24 if w < 440.0 else 26
		_title.size = Vector2(vs.x, 100)
		_title.position = Vector2(0, maxf(70.0, vs.y * 0.09))
		_title.pivot_offset = _title.size * 0.5
		for r in _rows:
			(r as Button).add_theme_font_size_override("font_size", fs)
		for g in _groups:
			(g[2] as Control).size.x = w
			for b in (g[2] as Control).get_children():
				(b as Button).add_theme_font_size_override("font_size", sub_fs)
		_col.custom_minimum_size.x = w
		_col.reset_size()
		var h := _col.get_combined_minimum_size().y
		_col.size = Vector2(w, h)
		_col.position = Vector2(18.0, vs.y - h - 40.0 - vs.y * 0.03)
		if _stage:
			var sh := vs.y * AVATAR_H
			var x0 := vs.x * 0.46
			_stage.position = Vector2(x0, vs.y - sh - vs.y * 0.02)
			_stage.size = Vector2(vs.x - x0, sh)

	func _on_shop() -> void:
		if kit._dragged():
			return
		var a = kit.cfg.get("aa_shop")
		if a is Callable:
			a.call()

	func _contract() -> void:
		_mode_by_key("contract")

	func _quick() -> void:
		var q = kit.cfg.get("aa_quick")
		_mode_by_key(str(q.call()) if q is Callable else "cpu_1")

	func _mode_by_key(key: String) -> void:
		for m in kit.cfg.get("modes", []):
			if str(m.get("key", "")) == key:
				kit._on_mode(m)
				return

	# ----- the kit's hooks -----

	func refresh() -> void:
		if _resume == null:
			return
		_refresh_hero()
		_resume.visible = kit.resume_btn.visible
		var w = kit.cfg.get("aa_wallet")
		_shop.text = "🛒  " + kit.tr("Shop") + ("     ⭐ %d" % int(w.call()) if w is Callable else "")
		_layout()

	func set_active(_on: bool) -> void:
		pass
