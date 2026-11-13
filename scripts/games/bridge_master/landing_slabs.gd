extends RefCounted

## "Plank Slabs" Landing for Bridge Master: docs/MENU_STYLES.md S6 (Stone Slabs) told in this
## game's own materials. Picked 2026-11-13 (the last games used the stack and S5/orbs).
##
## Same contract as the shared Landing styles template (docs/claude/landing-styles.md): the kit
## calls build(kit, home) from _build_home() when cfg has "landing" + "landing_style", and
## options(kit, body) inside ⚙ Options. The actions are the kit's own (Resume, Quick Play, the
## ways to play, ❓, 🏆, 🏅, 📊, ⚙, ← Hub); only the layout and motion are this file's.
## Lives in the game's folder (not the shared template) so the pack carries it as is.
##
##  T1  tapered plank slabs, centre-left (the art's bridge and builder stay clear on the right):
##      ▶ Resume (steel, green), ⚡ Quick Play, the ways to play (cfg modes), cfg play items
##  T2  a cluster of round bolt buttons bottom-right: ❓ 🏆 🏅 📊 ⚙
##  T3  ← Hub: a small plank bottom-left (N1)
## The slabs drop in like planks swung by a crane and sway a little; dust drifts in the light.
## "Reduce effects" (the shared user://fx.json switch) keeps only a short fade-in.

const PARTS := "res://games/bridge_master/parts/"
const FX_PATH := "user://fx.json"
const MIN_HIT := 56.0
const CREAM := Color("fff4dc")
const INK := Color("2b1a0e")

static func build(kit, home: Control) -> Control:
	if str(kit.cfg.get("landing", "")) != "slabs":
		return null
	var s := SlabLanding.new(kit)
	home.add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return s

static func options(kit, body: VBoxContainer) -> void:
	var s = kit._style
	if s == null:
		return
	body.add_child(kit._section(kit.tr("✨ Effects")))
	body.add_child(kit.choice_row(["Full", "Reduced"], 1 if reduced() else 0, s._on_fx_pick, kit.BUTTON))
	body.add_child(kit.label(kit.tr("Reduced turns off the drifting smoke, the sparkles and the floating. It is easier on older phones."), 22, kit.DIM, true))

## The app-wide "Reduce effects" choice (same file and default as the shared effects helper).
static func reduced() -> bool:
	if FileAccess.file_exists(FX_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FX_PATH))
		if d is Dictionary and d.has("reduce"):
			return bool(d.reduce)
	return OS.has_feature("web") or OS.get_processor_count() <= 4

static func set_reduced(on: bool) -> void:
	var f := FileAccess.open(FX_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"reduce": on}))

static func tex(name: String) -> Texture2D:
	var p := PARTS + name + ".png"
	return load(p) if ResourceLoader.exists(p) else null

## ---------- the same look for the game's own buttons (play screen, result card) ----------

## A plank (or steel) face for a button: "road_wood", "road_steel", "beam_steel".
static func plank_box(face: String, state: String) -> StyleBox:
	var t := tex(face)
	if t == null:
		var f := StyleBoxFlat.new()
		f.bg_color = Color("8d5a2b")
		f.set_corner_radius_all(10)
		f.set_border_width_all(3)
		f.border_color = INK
		return f
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = 30
	sb.texture_margin_right = 30
	sb.texture_margin_top = 6
	sb.texture_margin_bottom = 6
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	match state:
		"hover":
			sb.modulate_color = Color(1.12, 1.08, 1.0)
		"pressed", "hover_pressed":
			sb.modulate_color = Color(1.35, 1.2, 0.75)
		"disabled":
			sb.modulate_color = Color(0.55, 0.55, 0.55, 0.8)
	return sb

## A round steel bolt-head face.
static func bolt_box(state: String) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.bg_color = Color("46525d")
	match state:
		"hover":
			f.bg_color = Color("5c6a76")
		"pressed", "hover_pressed":
			f.bg_color = Color("8a6a1f")
		"disabled":
			f.bg_color = Color(0.27, 0.3, 0.33, 0.7)
	f.set_corner_radius_all(2000)
	f.set_border_width_all(4)
	f.border_color = Color("ffd54f") if state in ["pressed", "hover_pressed"] else Color("d7e0e6")
	f.shadow_color = Color(0, 0, 0, 0.45)
	f.shadow_size = 6
	f.shadow_offset = Vector2(0, 3)
	return f

## Dresses a Button: plank/steel face (or a round bolt when face == "bolt"), cream text with an ink outline.
static func dress(b: Button, face: String, tint: Color = Color.WHITE) -> void:
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, bolt_box(st) if face == "bolt" else plank_box(face, st))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, CREAM)
	b.add_theme_color_override("font_disabled_color", Color(CREAM, 0.45))
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 8)
	b.self_modulate = tint

class SlabLanding extends Control:
	## "🏆 Leaderboard" -> ["🏆", "Leaderboard"].
	static func split_glyph(text: String) -> Array:
		var t := text.strip_edges()
		var i := t.find(" ")
		if i > 0 and t.unicode_at(0) > 255:
			return [t.substr(0, i), t.substr(i).strip_edges()]
		return ["", t]

	static func fit_font(text: String, width: float, max_fs: int, min_fs: int = 12) -> int:
		var font := ThemeDB.fallback_font
		var fs := max_fs
		while fs > min_fs and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			fs -= 1
		return fs

	var kit
	var slabs: Array = []      # {kind, btn, glyph, name, detail, shown}
	var bolts: Array = []      # utility buttons {btn, glyph, name}
	var hub: Dictionary
	var title: Label
	var sub: Label
	var info_extra: VBoxContainer
	var art: TextureRect
	var veil_top: TextureRect
	var veil_bottom: TextureRect
	var dust: CPUParticles2D
	var sway: Tween
	var active := false
	var voodoo := false

	func _init(p_kit) -> void:
		kit = p_kit
		name = "SlabLanding"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		kit.resume_btn = _dummy()
		kit.quick_btn = _dummy()
		kit._split_modes()

	func _dummy() -> Button:
		var b := Button.new()
		b.visible = false
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
		return b

	func _ready() -> void:
		_build_backdrop()
		_build_title()
		_build_slabs()
		_build_bolts()
		resized.connect(_layout)
		call_deferred("_layout")

	# ----- building -----

	func _build_backdrop() -> void:
		var bg := ColorRect.new()
		bg.color = Color("2c4a63")
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var path: String = str(kit.cfg.get("art", ""))
		art = TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(path):
			art.texture = load(path)
		add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Soft shade at the top (title) and the bottom (Hub, bolts) so text reads over the picture.
		veil_top = _veil(true)
		veil_bottom = _veil(false)
		dust = CPUParticles2D.new()
		dust.amount = 18
		dust.lifetime = 9.0
		dust.preprocess = 9.0
		dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		dust.direction = Vector2(1, -0.25)
		dust.spread = 25.0
		dust.gravity = Vector2.ZERO
		dust.initial_velocity_min = 6.0
		dust.initial_velocity_max = 16.0
		dust.scale_amount_min = 1.5
		dust.scale_amount_max = 4.0
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 0.95, 0.8, 0.0))
		ramp.set_color(1, Color(1, 0.95, 0.8, 0.0))
		ramp.add_point(0.5, Color(1, 0.95, 0.8, 0.55))
		dust.color_ramp = ramp
		dust.emitting = false
		add_child(dust)

	func _veil(top: bool) -> TextureRect:
		var g := Gradient.new()
		g.set_color(0, Color(0.05, 0.03, 0.02, 0.62 if top else 0.0))
		g.set_color(1, Color(0.05, 0.03, 0.02, 0.0 if top else 0.7))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		gt.width = 4
		gt.height = 64
		var r := TextureRect.new()
		r.texture = gt
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		return r

	func _build_title() -> void:
		var t: String = str(kit.tr(kit.cfg.get("title", kit.consts.get("TITLE", ""))))
		title = kit.label(t.to_upper(), 64, CREAM, false, true)
		title.add_theme_color_override("font_outline_color", INK)
		title.add_theme_constant_override("outline_size", 18)
		title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		title.add_theme_constant_override("shadow_offset_x", 0)
		title.add_theme_constant_override("shadow_offset_y", 6)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title)
		var st: String = str(kit.cfg.get("subtitle", ""))
		sub = kit.label(kit.tr(st), 24, Color("ffe0a3"), true, true)
		sub.add_theme_color_override("font_outline_color", INK)
		sub.add_theme_constant_override("outline_size", 8)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sub)
		# Age rating, "Did you know?" and the version line: a small sign bottom-centre, shown when it fits.
		info_extra = VBoxContainer.new()
		info_extra.add_theme_constant_override("separation", 6)
		info_extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(info_extra)
		var rating: Control = kit._rating_row()
		if rating != null:
			info_extra.add_child(rating)
		kit._add_fact_card(info_extra)
		var ver: Control = kit._version_row()
		if ver != null:
			info_extra.add_child(ver)

	func _build_slabs() -> void:
		_slab("resume", "▶", str(kit.tr("Resume")), Callable(kit, "_on_resume"))
		_slab("quick", "⚡", str(kit.tr("Quick Play")), Callable(kit, "_on_quick"))
		for m in kit._solo:
			var p: Array = split_glyph(str(m.get("text", "")))
			_slab("mode", p[0], str(kit.tr(p[1])), Callable(kit, "_on_mode").bind(m))
		for it in kit.cfg.get("play", []):
			var q: Array = split_glyph(str(it.get("text", "")))
			_slab("play", q[0], str(kit.tr(q[1])), Callable(kit, "_on_play_item").bind(it))
		if not kit._multi.is_empty():
			_slab("multi", "👥", str(kit.tr("Multiplayer")), Callable(kit, "_on_group").bind(true))
		hub = _slab("hub", "←", str(kit.tr("Hub")), Callable(kit, "_on_hub_pressed"))

	func _slab(kind: String, glyph: String, nm: String, cb: Callable) -> Dictionary:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = (glyph + " " + nm).strip_edges()   # real text for tests and screen readers
		b.clip_text = true
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color(0, 0, 0, 0))
		var face := "road_steel" if kind == "resume" else "road_wood"
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, _plank_box(face, st))
		if kind == "resume":
			b.self_modulate = Color("9cffb8")
		b.pressed.connect(cb)
		b.button_down.connect(_squash.bind(b, true))
		b.button_up.connect(_squash.bind(b, false))
		# The layout places the slot; the drop-in and sway move the plank inside it.
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		slot.add_child(b)
		# Bolts at both ends.
		for side in [0, 1]:
			var bt := TextureRect.new()
			bt.texture = SlabLanding.part("bolt")
			bt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bt.stretch_mode = TextureRect.STRETCH_SCALE
			bt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bt.name = "Bolt" + str(side)
			b.add_child(bt)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var gl: Label = kit.label(glyph, 34, CREAM, false, true)
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gl.add_theme_color_override("font_outline_color", INK)
		gl.add_theme_constant_override("outline_size", 6)
		row.add_child(gl)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", -4)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		var nl: Label = kit.label(nm, 32, CREAM, false, false)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nl.add_theme_color_override("font_outline_color", INK)
		nl.add_theme_constant_override("outline_size", 10)
		col.add_child(nl)
		var dl: Label = kit.label("", 18, Color("ffe0a3"), false, false)
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dl.add_theme_color_override("font_outline_color", INK)
		dl.add_theme_constant_override("outline_size", 6)
		dl.visible = false
		col.add_child(dl)
		var d := {"kind": kind, "btn": b, "slot": slot, "glyph": gl, "name": nl, "detail": dl, "nm": nm,
			"shown": kind != "resume" and kind != "quick"}
		slabs.append(d)
		return d

	static func part(n: String) -> Texture2D:
		var p := "res://games/bridge_master/parts/" + n + ".png"
		return load(p) if ResourceLoader.exists(p) else null

	func _plank_box(face: String, state: String) -> StyleBox:
		var t := SlabLanding.part(face)
		if t == null:
			var f := StyleBoxFlat.new()
			f.bg_color = Color("8d5a2b") if face == "road_wood" else Color("4f6b5a")
			f.set_corner_radius_all(10)
			f.set_border_width_all(4)
			f.border_color = INK
			return f
		var sb := StyleBoxTexture.new()
		sb.texture = t
		sb.texture_margin_left = 40
		sb.texture_margin_right = 40
		sb.texture_margin_top = 8
		sb.texture_margin_bottom = 8
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		match state:
			"hover":
				sb.modulate_color = Color(1.12, 1.08, 1.0)
			"pressed":
				sb.modulate_color = Color(0.82, 0.78, 0.72)
		return sb

	func _build_bolts() -> void:
		var items: Array = [[kit.tr("❓ How to Play"), Callable(kit, "_show_overlay").bind(null, "info")]]
		if kit._board_key() != "none":
			items.append([kit.tr("🏆 Leaderboard"), Callable(kit, "_show_leaderboard")])
		if kit.info and kit.info.has_method("achievement_rows"):
			items.append([kit.tr("🏅 Achievements"), Callable(kit, "_show_achievements")])
		items.append([kit.tr("📊 Statistics"), Callable(kit, "_show_stats")])
		items.append([kit.tr("⚙ Options"), Callable(kit, "_show_options")])
		for it in items:
			var p: Array = split_glyph(str(it[0]))
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.text = str(it[0])
			b.clip_text = true   # the hidden text must not widen the round button
			b.tooltip_text = p[1]
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(c, Color(0, 0, 0, 0))
			for st in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(st, _bolt_box(st))
			b.pressed.connect(it[1])
			b.button_down.connect(_squash.bind(b, true))
			b.button_up.connect(_squash.bind(b, false))
			add_child(b)
			var gl: Label = kit.label(p[0], 30, Color.WHITE, false, true)
			gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gl.add_theme_color_override("font_outline_color", INK)
			gl.add_theme_constant_override("outline_size", 6)
			b.add_child(gl)
			gl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var nl: Label = kit.label(p[1], 16, CREAM, false, true)
			nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			nl.add_theme_color_override("font_outline_color", INK)
			nl.add_theme_constant_override("outline_size", 6)
			add_child(nl)
			bolts.append({"btn": b, "glyph": gl, "name": nl})

	## A round steel bolt head: dark face, bright rim, soft shadow.
	func _bolt_box(state: String) -> StyleBoxFlat:
		var f := StyleBoxFlat.new()
		f.bg_color = Color("46525d").lerp(Color("6e7f8c"), 0.5 if state == "hover" else (0.0 if state != "pressed" else -0.0))
		if state == "pressed":
			f.bg_color = Color("2f3a43")
		f.set_corner_radius_all(2000)
		f.set_border_width_all(4)
		f.border_color = Color("d7e0e6")
		f.shadow_color = Color(0, 0, 0, 0.45)
		f.shadow_size = 8
		f.shadow_offset = Vector2(0, 4)
		return f

	# ----- state from the kit -----

	func refresh() -> void:
		for s in slabs:
			if s.kind == "resume":
				s["shown"] = kit.resume_btn.visible
				var txt: String = kit.resume_btn.text
				_detail(s, txt.substr(txt.find("·") + 1).strip_edges() if "·" in txt else "")
			elif s.kind == "quick":
				s["shown"] = kit.quick_btn.visible
				var t2: String = kit.quick_btn.text
				_detail(s, t2.get_slice("\n", 1).strip_edges() if "\n" in t2 else "")
		_layout()

	func _detail(s: Dictionary, text: String) -> void:
		var dl: Label = s.detail
		dl.text = text
		dl.visible = text != ""
		(s.btn as Button).text = (str(s.glyph.text) + " " + str(s.nm) + " " + text).strip_edges()

	func set_active(on: bool) -> void:
		active = on
		if sway and sway.is_valid():
			sway.kill()
		dust.emitting = on and not SlabLanding_reduced()
		if not on:
			return
		_layout()
		_drop_in()

	static func SlabLanding_reduced() -> bool:
		return load("res://scripts/games/bridge_master/landing_slabs.gd").reduced()

	## The planks swing down into place one after another (a short fade when effects are reduced).
	func _drop_in() -> void:
		var calm := SlabLanding_reduced()
		var i := 0
		for s in slabs:
			var b: Button = s.btn
			if not (s.slot as Control).visible:
				continue
			var t := b.create_tween()
			if calm:
				b.modulate.a = 0.0
				t.tween_property(b, "modulate:a", 1.0, 0.25).set_delay(0.04 * i)
			else:
				var home_pos := Vector2.ZERO
				b.position = home_pos - Vector2(0, size.y * 0.35)
				b.rotation = deg_to_rad(-6.0 if i % 2 == 0 else 5.0)
				b.modulate.a = 0.0
				t.set_parallel(true)
				t.tween_property(b, "position", home_pos, 0.7).set_delay(0.08 * i).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				t.tween_property(b, "rotation", 0.0, 0.9).set_delay(0.08 * i).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				t.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(0.08 * i)
			i += 1
		for k in bolts.size():
			var bb: Button = bolts[k].btn
			bb.scale = Vector2(0.2, 0.2)
			var t2 := bb.create_tween()
			t2.tween_property(bb, "scale", Vector2.ONE, 0.45).set_delay(0.3 + 0.06 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if not calm:
			sway = create_tween()
			sway.set_loops()
			sway.tween_method(_sway_step, 0.0, TAU, 6.0).set_delay(1.4)

	## A plank hanging in the wind: a very small tilt, each at its own phase.
	func _sway_step(v: float) -> void:
		var i := 0
		for s in slabs:
			if s.kind == "hub":
				continue
			(s.btn as Button).rotation = deg_to_rad(sin(v + i * 1.3) * 0.9)
			i += 1

	func _squash(b: Button, down: bool) -> void:
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2(0.95, 0.9) if down else Vector2.ONE, 0.08 if down else 0.25) \
			.set_trans(Tween.TRANS_BACK if not down else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	func _on_fx_pick(i: int) -> void:
		load("res://scripts/games/bridge_master/landing_slabs.gd").set_reduced(i == 1)
		if sway and sway.is_valid():
			sway.kill()
		for s in slabs:
			(s.btn as Button).rotation = 0.0
		dust.emitting = active and i == 0
		if i == 0 and active:
			sway = create_tween()
			sway.set_loops()
			sway.tween_method(_sway_step, 0.0, TAU, 6.0)

	## Voodoo look: the picture goes to night, planks keep their wood with a neon edge glow.
	func set_voodoo(on: bool) -> void:
		voodoo = on
		art.modulate = Color(0.32, 0.28, 0.5) if on else Color.WHITE
		title.add_theme_color_override("font_color", Color("7df9ff") if on else CREAM)
		title.add_theme_color_override("font_outline_color", Color("3a0a5a") if on else INK)

	# ----- layout -----

	func _layout() -> void:
		if not is_inside_tree() or size.x < 40.0 or size.y < 40.0:
			return
		var W := size.x
		var H := size.y
		var wide := W > H * 1.1
		var pad := 18.0
		veil_top.position = Vector2.ZERO
		veil_top.size = Vector2(W, H * 0.34)
		veil_bottom.position = Vector2(0, H * 0.62)
		veil_bottom.size = Vector2(W, H * 0.38)
		dust.position = Vector2(W * 0.5, H * 0.5)
		dust.emission_rect_extents = Vector2(W * 0.5, H * 0.45)
		# --- title: top, wide and chunky ---
		var tw := W * (0.62 if wide else 0.92)
		var tfs := fit_font(title.text, tw, int(clampf(H * (0.12 if wide else 0.07), 34.0, 96.0)), 26)
		title.add_theme_font_size_override("font_size", tfs)
		title.size = Vector2(tw, 0)
		title.position = Vector2((W - tw) * 0.5, pad + H * 0.01)
		var th := title.get_combined_minimum_size().y
		sub.add_theme_font_size_override("font_size", int(clampf(H * 0.034, 18.0, 28.0)))
		sub.size = Vector2(tw, 0)
		sub.position = Vector2((W - tw) * 0.5, title.position.y + th - 6.0)
		var top_end := sub.position.y + sub.get_combined_minimum_size().y + 10.0
		# --- bottom row: ← Hub left, bolt cluster right ---
		var bs := clampf(H * (0.12 if wide else 0.075), MIN_HIT, 92.0)
		var label_h := 22.0
		var row_y := H - pad - label_h - bs
		var bx := W - pad - bs - 15.0
		for k in range(bolts.size() - 1, -1, -1):
			var bo: Dictionary = bolts[k]
			var b: Button = bo.btn
			b.size = Vector2(bs, bs)
			b.pivot_offset = Vector2(bs, bs) * 0.5
			b.position = Vector2(bx, row_y)
			(bo.glyph as Label).add_theme_font_size_override("font_size", int(bs * 0.42))
			var nl: Label = bo.name
			var lw := bs + 30.0
			nl.add_theme_font_size_override("font_size", fit_font(nl.text, lw - 4.0, 17, 11))
			nl.size = Vector2(lw, label_h)
			nl.position = Vector2(bx - 15.0, row_y + bs)
			bx -= bs + 34.0
		var cluster_left := bx + bs + 34.0
		var hub_b: Button = hub.btn
		var hub_w := clampf(W * 0.2, 190.0, 250.0)
		var hub_h := clampf(H * 0.09, MIN_HIT, 70.0)
		_size_slab(hub, Vector2(hub_w, hub_h))
		(hub.slot as Control).position = Vector2(pad, H - pad - hub_h)
		# --- the planks: tapered, stacked; centre-left in landscape, centred in portrait ---
		var shown: Array = slabs.filter(func(s): return s.kind != "hub" and s.shown)
		for s in slabs:
			(s.slot as Control).visible = s.kind == "hub" or s.shown
		var area_top := top_end + H * 0.02
		var area_bot := (row_y - 12.0) if not wide else (H - pad - hub_h - 14.0)
		var n := shown.size()
		if n > 0:
			var gap := clampf(H * 0.022, 8.0, 18.0)
			var sh := clampf((area_bot - area_top - gap * (n - 1)) / n, MIN_HIT, H * (0.15 if wide else 0.09))
			var cx := W * (0.3 if wide else 0.5)
			var w0 := W * (0.36 if wide else 0.8)
			var y := area_top + maxf(0.0, (area_bot - area_top - (sh * n + gap * (n - 1))) * 0.35)
			for i in n:
				var w := maxf(w0 * (1.0 - 0.045 * i), 260.0)
				_size_slab(shown[i], Vector2(w, sh))
				(shown[i].slot as Control).position = Vector2(cx - w * 0.5, y)
				y += sh + gap
		# --- small sign bottom-centre: rating / fact / version, only if it fits ---
		var free_l := pad + hub_w + 16.0
		var free_w := cluster_left - free_l - 16.0
		if wide:
			var last_bottom := 0.0
			for s in shown:
				last_bottom = maxf(last_bottom, (s.slot as Control).position.y + (s.slot as Control).size.y)
			free_l = maxf(free_l, W * 0.52)
			free_w = cluster_left - free_l - 16.0
		info_extra.visible = free_w >= 240.0
		if info_extra.visible:
			info_extra.size = Vector2(free_w, 0)
			var ih := info_extra.get_combined_minimum_size().y
			info_extra.position = Vector2(free_l, H - pad - ih)
			if info_extra.position.y < top_end + 40.0:
				info_extra.visible = false

	func _size_slab(s: Dictionary, sz: Vector2) -> void:
		var b: Button = s.btn
		(s.slot as Control).size = sz
		b.size = sz
		b.custom_minimum_size = Vector2.ZERO
		b.pivot_offset = sz * 0.5
		var bolt := sz.y * 0.32
		for side in [0, 1]:
			var bt: TextureRect = b.get_node("Bolt" + str(side))
			bt.size = Vector2(bolt, bolt)
			bt.position = Vector2(sz.y * 0.18 if side == 0 else sz.x - sz.y * 0.18 - bolt, (sz.y - bolt) * 0.42)
		var inner := sz.x - sz.y * 1.2
		var gl: Label = s.glyph
		gl.add_theme_font_size_override("font_size", int(sz.y * 0.4))
		var nl: Label = s.name
		var has_detail: bool = (s.detail as Label).visible
		var fs := fit_font(nl.text, inner - sz.y * 0.5, int(sz.y * (0.32 if has_detail else 0.4)), 14)
		nl.add_theme_font_size_override("font_size", fs)
		(s.detail as Label).add_theme_font_size_override("font_size", fit_font((s.detail as Label).text, inner - sz.y * 0.5, int(sz.y * 0.22), 11))
