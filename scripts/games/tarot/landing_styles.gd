extends RefCounted

## Landing styles: other ways to lay out the Landing kit's buttons (docs/claude/landing-styles.md).
##
## GENERATED COPY: `python tools/hub.py sync` copies tools/templates/landing_styles.gd to
## scripts/games/<id>/landing_styles.gd for every game whose scripts mention it, so each pack
## carries its own copy and runs on any app version (like home_kit.gd, N7). Edit the template.
##
## A game opts in through the kit's cfg:
##     const LandingStyles = preload("res://scripts/games/<id>/landing_styles.gd")
##     HomeKit.new({..., "landing": "orbs", "landing_style": LandingStyles, ...})
## The kit then builds the Landing through `build()` instead of its stacked buttons. The
## actions are the same ones (Resume, Quick Play, the ways to play, How to Play, 🏆, 🏅, 📊, ⚙,
## the game's own "more" screens, ← Hub): only the layout and the motion change. Navigation
## rules stay (N1: ← Hub only here; N6: a way to play starts in one tap).
##
## Styles: "orbs" (round buttons of uneven size, floating). "stack" (or no "landing") is the
## kit's own column. Not built yet: "carousel" (swipeable card fan) and "scene" (tap things in
## a picture); an unknown name falls back to the stack.
##
## "orbs" cfg (all optional):
##   "orb_color": Color            ring colour of the orbs (default the kit accent)
##   "orb_glitter": Color          colour of the glitter (default the orb colour)
##   "landing_title_art": path     the title painted on a transparent picture; used while the
##                                 title is in English (a translated title is drawn as text)
##   "landing_colors": [top, mid]  the night gradient behind everything
##   "orb_main_max": int           at most this many main orbs (default 8)
## cfg "modes" entries may carry "orb": "10" (the big glyph) and "orb_name": "Celtic" (the short
## name): when the solo ways to play are 5 or fewer and there are no pickers (cfg "extra"),
## they become the row of round buttons along the bottom, one tap each.

const Fx = preload("fx_lib.gd")

## The kit calls this once from _build_home. Returns the style's node (a child of `home`) or
## null for "use the stack".
static func build(kit, home: Control) -> Control:
	match str(kit.cfg.get("landing", "")):
		"orbs":
			var o := OrbLanding.new(kit)
			home.add_child(o)
			o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			return o
	return null

## The kit calls this inside ⚙ Options (games with a styled Landing): the shared
## "Reduce effects" switch.
static func options(kit, body: VBoxContainer) -> void:
	var s = kit._style
	if s == null:
		return
	body.add_child(kit._section(kit.tr("✨ Effects")))
	body.add_child(kit.choice_row(["Full", "Reduced"], 1 if Fx.reduced() else 0, s._on_fx_pick, kit.BUTTON))
	body.add_child(kit.label(kit.tr("Reduced turns off the drifting smoke, the sparkles and the floating. It is easier on older phones."), 22, kit.DIM, true))

## ---------- orbs ----------

class OrbLanding extends Control:
	## Size of each main orb relative to the biggest, in the order they appear.
	const FACTORS := [1.0, 0.78, 0.9, 0.7, 0.84, 0.74, 0.8, 0.68]
	## The bottom row's uneven sizes and how far each bobs off the row's line (x its size).
	const SPREAD_FACTORS := [0.96, 0.8, 0.9, 1.0, 0.84]
	const SPREAD_DROP := [-0.1, 0.12, -0.04, 0.1, -0.12]
	const MIN_ORB := 56.0
	const FLOAT_SECONDS := 7.0

	## "🏆 Leaderboard" -> ["🏆", "Leaderboard"]; text with no leading symbol -> ["", text].
	static func split_glyph(text: String) -> Array:
		var t := text.strip_edges()
		var i := t.find(" ")
		if i > 0 and t.unicode_at(0) > 255:
			return [t.substr(0, i), t.substr(i).strip_edges()]
		return ["", t]

	## The biggest font size (<= max_fs, >= min_fs) at which the longest word of `text` fits `width`.
	static func fit_font(text: String, width: float, max_fs: int, min_fs: int = 11) -> int:
		var font := ThemeDB.fallback_font
		var longest := ""
		for w in text.split(" "):
			if w.length() > longest.length():
				longest = w
		var fs := max_fs
		while fs > min_fs and font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			fs -= 1
		return fs

	var kit
	var orbs: Array = []          # every orb: see _make_orb
	var info_col: VBoxContainer
	var _glow: TextureRect
	var _smoke: CPUParticles2D
	var _glitter: CPUParticles2D
	var _float: Tween
	var _active := false
	var _last_info_h := -1.0
	## The fact card and the version line: shown while there is room, else hidden (the orbs come first).
	var _extras: Array = []
	var _extras_h := 0.0
	var _relayouts := 0

	func _init(p_kit) -> void:
		kit = p_kit
		name = "OrbLanding"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The kit's refresh() writes Resume / Quick Play into these two; refresh() below reads
		# them back into the orbs. They are never shown.
		kit.resume_btn = _dummy()
		kit.quick_btn = _dummy()
		kit._split_modes()

	func _dummy() -> Button:
		var b := Button.new()
		b.modulate.a = 0.0
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.focus_mode = Control.FOCUS_NONE
		b.visible = false
		add_child(b)
		return b

	func _ready() -> void:
		_build_backdrop()
		_build_info()
		_build_orbs()
		resized.connect(_layout)
		call_deferred("_layout")

	# ----- building -----

	func _orb_color() -> Color:
		return kit.cfg.get("orb_color", kit.accent)

	func _build_backdrop() -> void:
		var cols: Array = kit.cfg.get("landing_colors", [Color("0a0d24"), Color("1b1450")])
		var grad := Gradient.new()
		grad.set_color(0, cols[0])
		grad.set_color(1, cols[0])
		grad.add_point(0.45, cols[1])
		var fill := GradientTexture2D.new()
		fill.gradient = grad
		fill.fill_from = Vector2(0, 0)
		fill.fill_to = Vector2(0, 1)
		fill.width = 4
		fill.height = 256
		var bg := TextureRect.new()
		bg.texture = fill
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_glow = TextureRect.new()
		_glow.texture = Fx.blob(128)
		_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_glow.stretch_mode = TextureRect.STRETCH_SCALE
		_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glow.modulate = Color(_orb_color(), 0.22)
		add_child(_glow)
		# Smoke behind the logo, glitter over the whole screen, both under the buttons.
		_smoke = Fx.smoke(self, Color(kit.accent.lerp(Color.WHITE, 0.25), 1.0), Vector2(200, 40))
		_glitter = Fx.glitter(self, kit.cfg.get("orb_glitter", _orb_color().lerp(Color.WHITE, 0.5)), Vector2(300, 500))
		if _smoke:
			_smoke.emitting = false
		if _glitter:
			_glitter.emitting = false

	func _build_info() -> void:
		info_col = VBoxContainer.new()
		info_col.add_theme_constant_override("separation", 8)
		info_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(info_col)
		var title_text: String = str(kit.tr(kit.cfg.get("title", kit.consts.get("TITLE", ""))))
		var art_path: String = str(kit.cfg.get("landing_title_art", ""))
		var english: bool = title_text == str(kit.cfg.get("title", kit.consts.get("TITLE", "")))
		if art_path != "" and english and ResourceLoader.exists(art_path):
			var tex: Texture2D = load(art_path)
			var art := TextureRect.new()
			art.name = "TitleArt"
			art.texture = tex
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.set_meta("aspect", float(tex.get_height()) / float(tex.get_width()))
			info_col.add_child(art)
		else:
			var t: Label = kit.label(title_text.to_upper(), 56, kit.accent.lerp(Color.WHITE, 0.72), true, true)
			t.name = "TitleText"
			t.add_theme_color_override("font_outline_color", Color(kit.accent, 0.6))
			t.add_theme_constant_override("outline_size", 12)
			info_col.add_child(t)
		var sub_text: String = str(kit.cfg.get("subtitle", kit.consts.get("GOAL", "")))
		if sub_text != "":
			var sub: Label = kit.label(kit.tr(sub_text), 24, kit.WHITE, true, true)
			sub.name = "Subtitle"
			sub.add_theme_color_override("font_outline_color", Color(kit.BG, 0.9))
			sub.add_theme_constant_override("outline_size", 8)
			info_col.add_child(sub)
		var rating: Control = kit._rating_row()
		if rating != null:
			info_col.add_child(rating)
		var first_extra := info_col.get_child_count()
		kit._add_fact_card(info_col)
		var ver: Control = kit._version_row()
		if ver != null:
			info_col.add_child(ver)
		for i in range(first_extra, info_col.get_child_count()):
			_extras.append(info_col.get_child(i))

	func _build_orbs() -> void:
		var color := _orb_color()
		# --- the way-to-play row along the bottom ---
		var solo: Array = kit._solo
		var as_row: bool = not solo.is_empty() and solo.size() <= 5 and not kit.cfg.has("extra")
		if as_row:
			for m in solo:
				var parts: Array = split_glyph(str(m.get("text", "")))
				var glyph: String = str(m.get("orb", parts[0]))
				var nm: String = str(kit.tr(str(m.get("orb_name", parts[1]))))
				_make_orb("spread", glyph, nm, color, Callable(kit, "_on_mode").bind(m))
		# --- the main orbs, most important first ---
		_make_orb("resume", "▶", str(kit.tr("Resume")), kit.GO, Callable(kit, "_on_resume"))
		_make_orb("quick", "⚡", str(kit.tr("Quick Play")), color, Callable(kit, "_on_quick"))
		for p in kit.cfg.get("play", []):
			var pp: Array = split_glyph(str(p.get("text", "")))
			_make_orb("main", pp[0], str(kit.tr(pp[1])), color, Callable(kit, "_on_play_item").bind(p))
		if not as_row:
			if not solo.is_empty():
				_make_orb("main", "🎮", str(kit.tr("Single player")), color, Callable(kit, "_on_group").bind(false))
		if not kit._multi.is_empty():
			_make_orb("main", "👥", str(kit.tr("Multiplayer")), color, Callable(kit, "_on_group").bind(true))
		for it in kit.cfg.get("more", []):
			var mp: Array = split_glyph(str(kit.tr(str(it[0]))))
			_make_orb("main", mp[0], mp[1], color, it[2])
		var items: Array = [[kit.tr("❓ How to Play"), Callable(kit, "_show_overlay").bind(null, "info")]]
		if kit._board_key() != "none":
			items.append([kit.tr("🏆 Leaderboard"), Callable(kit, "_show_leaderboard")])
		if kit.info and kit.info.has_method("achievement_rows"):
			items.append([kit.tr("🏅 Achievements"), Callable(kit, "_show_achievements")])
		items.append([kit.tr("📊 Statistics"), Callable(kit, "_show_stats")])
		items.append([kit.tr("⚙ Options"), Callable(kit, "_show_options")])
		for it in items:
			var ip: Array = split_glyph(str(it[0]))
			_make_orb("main", ip[0], ip[1], color, it[1])
		# --- ← Hub: small, bottom-left (N1: only the Landing has it) ---
		_make_orb("hub", "←", str(kit.tr("Hub")), color.lerp(Color.WHITE, 0.2), Callable(kit, "_on_hub_pressed"))
		for i in orbs.size():
			orbs[i]["phase"] = float(i) * 1.7
			orbs[i]["amp"] = 5.0 + float((i * 5) % 4) * 1.4

	func _make_orb(kind: String, glyph: String, nm: String, color: Color, cb: Callable) -> void:
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = (glyph + " " + nm).strip_edges()      # real text: tests, screen readers
		b.clip_text = true
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color(0, 0, 0, 0))   # the labels below draw it
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, _orb_box(color, st))
		b.tooltip_text = nm
		b.pressed.connect(cb)
		Fx.bind_press(b)
		slot.add_child(b)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var gl: Label = kit.label(glyph, 40, kit.WHITE, false, true)
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(gl)
		var nl: Label = kit.label(nm, 20, kit.WHITE, true, true)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nl.add_theme_color_override("font_outline_color", Color(kit.BG, 0.8))
		nl.add_theme_constant_override("outline_size", 4)
		col.add_child(nl)
		orbs.append({"kind": kind, "slot": slot, "btn": b, "glyph": gl, "name": nl, "col": col,
			"nm": nm, "color": color, "phase": 0.0, "amp": 6.0, "shown": kind != "resume" and kind != "quick"})

	func _orb_box(color: Color, state: String) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		var down := state == "pressed"
		sb.bg_color = Color(0.05, 0.05, 0.14, 0.86).lerp(Color(color, 1.0), 0.32 if down else (0.16 if state == "hover" else 0.08))
		sb.border_color = Color(color, 1.0 if state != "normal" else 0.9)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(2000)
		sb.shadow_color = Color(color, 0.5 if down else 0.34)
		sb.shadow_size = 16
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		return sb

	# ----- state from the kit -----

	## The kit's refresh() ran: Resume / Quick Play show or hide, then lay out again.
	func refresh() -> void:
		for o in orbs:
			if o.kind == "resume":
				o["shown"] = kit.resume_btn.visible
				var detail := ""
				var txt: String = kit.resume_btn.text
				if "·" in txt:
					detail = txt.substr(txt.find("·") + 1).strip_edges()
				_set_orb_text(o, "▶", str(kit.tr("Resume")), detail)
			elif o.kind == "quick":
				o["shown"] = kit.quick_btn.visible
				var txt2: String = kit.quick_btn.text
				var detail2 := txt2.get_slice("\n", 1).strip_edges() if "\n" in txt2 else ""
				_set_orb_text(o, "⚡", str(kit.tr("Quick Play")), detail2)
		_layout()

	func _set_orb_text(o: Dictionary, glyph: String, nm: String, detail: String) -> void:
		(o.btn as Button).text = (glyph + " " + nm + " " + detail).strip_edges()
		o["nm"] = nm
		o["detail"] = detail
		(o.name as Label).text = nm

	## The kit shows or hides the Landing: motion and particles only run while it is up.
	func set_active(on: bool) -> void:
		_active = on
		if _float and _float.is_valid():
			_float.kill()
		if _smoke:
			_smoke.emitting = on and not Fx.reduced()
		if _glitter:
			_glitter.emitting = on and not Fx.reduced()
		if not on:
			return
		_layout()
		var i := 0
		for o in orbs:
			if o.shown:
				Fx.pop_in(o.btn, 0.04 + 0.055 * float(i))
				i += 1
		_start_float()

	func _start_float() -> void:
		if Fx.reduced() or not _active:
			return
		_float = create_tween()
		_float.set_loops()
		_float.tween_method(_float_step, 0.0, TAU, FLOAT_SECONDS)

	## One slow sine per orb, each at its own phase; the loop is one full turn, so it never jumps.
	func _float_step(v: float) -> void:
		for o in orbs:
			var b: Button = o.btn
			var a: float = o.amp
			b.position = Vector2(sin(v + o.phase * 0.6) * a * 0.45, sin(v + o.phase) * a)

	## The "Reduce effects" row of ⚙ Options.
	func _on_fx_pick(i: int) -> void:
		Fx.set_reduced(i == 1)
		for o in orbs:
			(o.btn as Button).position = Vector2.ZERO
		if _smoke:
			_smoke.emitting = _active and i == 0
		if _glitter:
			_glitter.emitting = _active and i == 0
		if _float and _float.is_valid():
			_float.kill()
		if i == 0 and _smoke == null:
			# Effects switched back on after this Landing was built without them.
			_smoke = Fx.smoke(self, Color(kit.accent.lerp(Color.WHITE, 0.25), 1.0), Vector2(200, 40))
			_glitter = Fx.glitter(self, kit.cfg.get("orb_glitter", _orb_color().lerp(Color.WHITE, 0.5)), Vector2(300, 500))
			move_child(_smoke, _glow.get_index() + 1)
			move_child(_glitter, _smoke.get_index() + 1)
			_layout()
		_start_float()

	# ----- layout -----

	func _layout() -> void:
		if not is_inside_tree() or size.x < 40.0 or size.y < 40.0:
			return
		var W := size.x
		var H := size.y
		var wide := W > H * 1.1
		var pad := 18.0
		var hub_s := clampf(minf(W, H) * 0.11, MIN_ORB, 84.0)
		var spreads: Array = orbs.filter(func(o): return o.kind == "spread")
		var mains: Array = orbs.filter(func(o): return o.kind in ["resume", "quick", "main"] and o.shown)
		# Hidden ones (Resume / Quick Play when they don't apply) stay out of the way.
		for o in orbs:
			(o.slot as Control).visible = o.shown
		# --- bottom row: ← Hub, then the ways to play ---
		var row_top := H - pad
		if not spreads.is_empty():
			var x0 := pad + hub_s + 14.0
			var avail := W - pad - x0
			var ss := clampf(minf(avail / float(spreads.size()) * 0.9, H * (0.24 if wide else 0.17)), MIN_ORB, 138.0)
			var slot_w := avail / float(spreads.size())
			var band := ss * 1.28
			row_top = H - pad - band
			for i in spreads.size():
				var f: float = SPREAD_FACTORS[i % SPREAD_FACTORS.size()]
				var d := maxf(MIN_ORB, ss * f)
				var cx := x0 + (float(i) + 0.5) * slot_w + sin(float(i) * 2.1) * slot_w * 0.05
				var drop: float = SPREAD_DROP[i % SPREAD_DROP.size()]
				var cy: float = row_top + band * 0.5 + drop * ss
				_put(spreads[i], Vector2(cx, cy), d, true)
		var hub: Dictionary = orbs.filter(func(o): return o.kind == "hub")[0]
		_put(hub, Vector2(pad + hub_s * 0.5, H - pad - hub_s * 0.5), hub_s, false)
		if spreads.is_empty():
			row_top = H - pad - hub_s
		# --- the title column ---
		var col_w := (W * 0.4 - pad) if wide else (W - pad * 2.0)
		info_col.position = Vector2(pad, pad)
		info_col.size = Vector2(col_w, 0.0)
		_fit_info(col_w, wide)
		var info_h := info_col.get_combined_minimum_size().y
		# Room for the fact card and version line? Landscape: only if the column stays above the
		# bottom row. Portrait: only if the orbs can still be 100+ units wide.
		var extras_shown: bool = not _extras.is_empty() and (_extras[0] as Control).visible
		if extras_shown:
			_extras_h = 0.0
			for e in _extras:
				_extras_h += (e as Control).get_combined_minimum_size().y + 8.0
		var full_h: float = info_h + (0.0 if extras_shown else _extras_h)
		var want_extras := true
		if wide:
			want_extras = pad + full_h <= row_top - 10.0
		else:
			var top_full := pad + full_h + 14.0
			var area_full := Rect2(pad, top_full, W - pad * 2.0, row_top - top_full - 14.0)
			want_extras = _best(mains.size(), area_full)[1] >= 100.0
		if want_extras != extras_shown and not _extras.is_empty():
			for e in _extras:
				(e as Control).visible = want_extras
			_last_info_h = -1.0
			if _relayouts < 6:
				_relayouts += 1
				call_deferred("_layout")
			return
		if absf(info_h - _last_info_h) > 1.0 and _relayouts < 4:
			_last_info_h = info_h
			_relayouts += 1
			call_deferred("_layout")
		else:
			_relayouts = 0
		# glow + smoke sit behind the title
		var title_h := minf(info_h, 230.0)
		_glow.position = Vector2(pad - col_w * 0.1, pad - title_h * 0.4)
		_glow.size = Vector2(col_w * 1.2, title_h * 1.8)
		if _smoke:
			_smoke.position = Vector2(pad + col_w * 0.5, pad + title_h * 0.7)
			_smoke.emission_rect_extents = Vector2(col_w * 0.42, 30.0)
		if _glitter:
			_glitter.position = Vector2(W * 0.5, H * 0.5)
			_glitter.emission_rect_extents = Vector2(W * 0.5, H * 0.5)
		# --- the main orbs ---
		var area: Rect2
		if wide:
			area = Rect2(W * 0.4, pad, W * 0.6 - pad, row_top - pad - 10.0)
		else:
			var top := pad + info_h + 14.0
			area = Rect2(pad, top, W - pad * 2.0, row_top - top - 14.0)
		_place_main(mains, area)

	func _fit_info(col_w: float, wide: bool) -> void:
		var art: Node = info_col.get_node_or_null("TitleArt")
		if art:
			(art as Control).custom_minimum_size = Vector2(0, col_w * float(art.get_meta("aspect")))
		var t: Label = info_col.get_node_or_null("TitleText")
		if t:
			var fs := fit_font(t.text, col_w - 20.0, int(clampf(col_w * 0.11, 30.0, 60.0)), 26)
			t.add_theme_font_size_override("font_size", fs)
		var sub: Label = info_col.get_node_or_null("Subtitle")
		if sub:
			sub.add_theme_font_size_override("font_size", 20 if wide else 24)

	## [columns, orb size] that give the biggest orbs for `n` of them in `area`.
	func _best(n: int, area: Rect2) -> Array:
		var best_cols := 2
		var best_unit := 0.0
		for cols in [2, 3, 4]:
			var rows := ceili(float(n) / float(cols))
			var u := minf(area.size.x / float(cols) * 0.8, area.size.y / float(rows) * 0.78)
			if u > best_unit + 1.0:
				best_unit = u
				best_cols = cols
		return [best_cols, maxf(0.0, best_unit)]

	## Puts the main orbs on an uneven grid inside `area`: more or fewer columns, whichever
	## gives the biggest orbs; every other row nudged sideways; sizes by rank.
	func _place_main(items: Array, area: Rect2) -> void:
		var n := items.size()
		if n == 0:
			return
		var best: Array = _best(n, area)
		var best_cols: int = best[0]
		var best_unit: float = best[1]
		var cols := best_cols
		var rows := ceili(float(n) / float(cols))
		var unit := clampf(best_unit, MIN_ORB, 190.0)
		var col_w := area.size.x / float(cols)
		var row_h := area.size.y / float(rows)
		for i in n:
			var r := i / cols
			var c := i % cols
			var in_row := mini(cols, n - r * cols)
			var off := float(cols - in_row) * col_w * 0.5
			var stagger := (0.08 if r % 2 == 1 else -0.08) * col_w
			var cx := area.position.x + (float(c) + 0.5) * col_w + off + stagger + sin(float(i) * 2.399) * col_w * 0.05
			var cy := area.position.y + (float(r) + 0.5) * row_h + cos(float(i) * 1.713) * row_h * 0.08
			var f: float = FACTORS[i % FACTORS.size()]
			_put(items[i], Vector2(cx, cy), maxf(MIN_ORB, unit * f), false)

	## Centre `c`, diameter `d`: sizes the slot, the button and the labels inside it.
	func _put(o: Dictionary, c: Vector2, d: float, number: bool) -> void:
		var slot: Control = o.slot
		slot.position = c - Vector2(d, d) * 0.5
		slot.size = Vector2(d, d)
		var b: Button = o.btn
		b.size = Vector2(d, d)
		b.custom_minimum_size = Vector2(d, d)
		b.pivot_offset = Vector2(d, d) * 0.5
		var gl: Label = o.glyph
		var nl: Label = o.name
		# The big glyph; a number (the spreads) is drawn bolder and larger than an emoji.
		var gsize := int(d * (0.46 if number else 0.36))
		gl.add_theme_font_size_override("font_size", gsize)
		var inner := d * 0.78
		nl.custom_minimum_size.x = inner
		nl.text = str(o.get("nm", nl.text))
		var fs := fit_font(nl.text, inner, int(clampf(d * 0.17, 12.0, 26.0)), 11)
		nl.add_theme_font_size_override("font_size", fs)
		# A name that cannot fit even at the smallest size is left out (the glyph carries the orb)
		# rather than broken mid-word.
		var longest := ""
		for w in nl.text.split(" "):
			if w.length() > longest.length():
				longest = w
		nl.visible = d >= 62.0 and ThemeDB.fallback_font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= inner + 1.0
