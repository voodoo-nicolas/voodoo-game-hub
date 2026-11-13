extends RefCounted

## Landing styles: other ways to lay out the Landing kit's buttons (docs/claude/landing-styles.md).
##
## GENERATED COPY: `python tools/hub.py sync` copies tools/templates/landing_styles.gd to
## scripts/games/<id>/landing_styles.gd for every game whose scripts mention it, so each pack
## carries its own copy and runs on any app version (like home_kit.gd, N7). Edit the template.
##
## A game opts in through the kit's cfg:
##     const LandingStyles = preload("res://scripts/games/<id>/landing_styles.gd")
##     HomeKit.new({..., "landing": "list", "landing_style": LandingStyles, ...})
## The kit then builds the Landing through `build()` instead of its stacked buttons. The
## actions are the same ones (Resume, Quick Play, the ways to play, How to Play, 🏆, 🏅, 📊, ⚙,
## the game's own "more" screens, ← Hub): only the layout and the motion change. Navigation
## rules stay (N1: ← Hub only here; N6: a way to play starts in one tap).
##
## Styles:
##   "list"   a menu down the left: a small diamond icon, a spaced-out name and a thin gold line per
##            row, a gold rule with diamond ends beside it, the game's picture showing on the right;
##            the utility actions (How to Play, 🏆, 🏅, 📊, ⚙) in a row of diamonds along the bottom.
##   "orbs"   round buttons of uneven size, floating.
##   "stack" (or no "landing") is the kit's own column. Not built yet: "carousel", "scene"; an
##   unknown name falls back to the stack.
##
## cfg (all optional, shared by the styles):
##   "orb_color": Color            the gold: rings, lines, icons (default the kit accent)
##   "orb_glitter": Color          colour of the glitter (default the orb colour)
##   "landing_title_art": path     the title painted on a transparent picture; used while the
##                                 title is in English (a translated title is drawn as text)
##   "landing_art": {"portrait": path, "wide": path}   pictures behind everything, one per orientation
##   "landing_veil": 0.42          how dark the veil over them is (0..1)
##   "landing_lights": {"portrait": [[x, y, diameter, Color], ...], "wide": [...]}   candle flames on the
##                                 picture (x, y as fractions of the picture), glowing and flickering
##   "landing_mist": Color         slow drifting fog in this colour
##   "landing_twilight": true      a slow-breathing dusk tint (indigo above, amber below)
##   "landing_colors": [top, mid]  the night gradient behind everything
## cfg "modes" entries may carry "orb": "10" (the big glyph) and "orb_name": "Celtic" (the short
## name): the solo ways to play, when there are 5 or fewer and no pickers (cfg "extra"), become the
## bottom row of round buttons ("orbs") or the first rows of the menu ("list"), one tap each.
## Smoke, glitter, fog and flicker come from fx_lib.gd and obey "Reduce effects" (Options).

const Fx = preload("fx_lib.gd")

## The kit calls this once from _build_home. Returns the style's node (a child of `home`) or
## null for "use the stack".
static func build(kit, home: Control) -> Control:
	var node: Control = null
	match str(kit.cfg.get("landing", "")):
		"orbs":
			node = OrbLanding.new(kit)
		"list":
			node = ListLanding.new(kit)
	if node == null:
		return null
	home.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return node

## The kit calls this inside ⚙ Options (games with a styled Landing): the shared
## "Reduce effects" switch.
static func options(kit, body: VBoxContainer) -> void:
	var s = kit._style
	if s == null:
		return
	body.add_child(kit._section(kit.tr("✨ Effects")))
	body.add_child(kit.choice_row(["Full", "Reduced"], 1 if Fx.reduced() else 0, s._on_fx_pick, kit.BUTTON))
	body.add_child(kit.label(kit.tr("Reduced turns off the drifting smoke, the sparkles and the floating. It is easier on older phones."), 22, kit.DIM, true))


## ---------- shared base ----------

class StyleBase extends Control:
	var kit
	var entries: Array = []        # one dictionary per action; see _add()
	var info_col: VBoxContainer
	## The fact card and the version line: shown while there is room, else hidden.
	var _extras: Array = []
	var _extras_h := 0.0
	var _last_info_h := -1.0
	var _relayouts := 0
	var _glow: TextureRect
	var _art: TextureRect
	var _pics: Dictionary = {}
	var _veil: ColorRect
	var _twilight: TextureRect
	var _mist: TextureRect
	var _smoke: CPUParticles2D
	var _glitter: CPUParticles2D
	var _lights: Array = []        # [{"node", "frac": Vector2 per orientation...}]
	var _float: Tween
	var _breath: Tween
	var _active := false

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

	## The biggest font size at which the whole of `text` (with `spacing` extra pixels per letter) fits one line.
	static func fit_line(text: String, width: float, max_fs: int, min_fs: int = 11, spacing: float = 0.0) -> int:
		var font := ThemeDB.fallback_font
		var fs := max_fs
		while fs > min_fs and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + spacing * float(text.length()) > width:
			fs -= 1
		return fs

	func _init(p_kit) -> void:
		kit = p_kit
		name = "StyleLanding"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The kit's refresh() writes Resume / Quick Play into these two; refresh() below reads
		# them back into the entries. They are never shown.
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
		_collect()
		_build_items()
		resized.connect(_layout)
		call_deferred("_layout")

	func _orb_color() -> Color:
		return kit.cfg.get("orb_color", kit.accent)

	# ----- the actions, in order of importance -----

	func _add(kind: String, glyph: String, nm: String, color: Color, cb: Callable, extra: Dictionary = {}) -> void:
		var e := {"kind": kind, "glyph": glyph, "nm": nm, "full": nm, "sub": "", "color": color, "cb": cb,
			"shown": kind != "resume" and kind != "quick", "detail": ""}
		e.merge(extra, true)
		entries.append(e)

	func _collect() -> void:
		var color := _orb_color()
		var solo: Array = kit._solo
		var as_row: bool = not solo.is_empty() and solo.size() <= 5 and not kit.cfg.has("extra")
		_add("resume", "▶", str(kit.tr("Resume")), kit.GO, Callable(kit, "_on_resume"))
		_add("quick", "⚡", str(kit.tr("Quick Play")), color, Callable(kit, "_on_quick"))
		if as_row:
			for m in solo:
				var parts: Array = split_glyph(str(kit.tr(str(m.get("text", "")))))
				var glyph: String = str(m.get("orb", parts[0]))
				var short: String = str(kit.tr(str(m.get("orb_name", parts[1]))))
				_add("spread", glyph, short, color, Callable(kit, "_on_mode").bind(m),
					{"full": parts[1], "sub": str(kit.tr(str(m.get("sub", ""))))})
				entries[-1]["icon"] = parts[0]
		for p in kit.cfg.get("play", []):
			var pp: Array = split_glyph(str(kit.tr(str(p.get("text", "")))))
			_add("main", pp[0], pp[1], color, Callable(kit, "_on_play_item").bind(p),
				{"sub": str(kit.tr(str(p.get("sub", ""))))})
		if not as_row and not solo.is_empty():
			_add("main", "🎮", str(kit.tr("Single player")), color, Callable(kit, "_on_group").bind(false))
		if not kit._multi.is_empty():
			_add("main", "👥", str(kit.tr("Multiplayer")), color, Callable(kit, "_on_group").bind(true))
		for it in kit.cfg.get("more", []):
			var mp: Array = split_glyph(str(kit.tr(str(it[0]))))
			_add("main", mp[0], mp[1], color, it[2])
		var utils: Array = [[kit.tr("❓ How to Play"), Callable(kit, "_show_overlay").bind(null, "info")]]
		if kit._board_key() != "none":
			utils.append([kit.tr("🏆 Leaderboard"), Callable(kit, "_show_leaderboard")])
		if kit.info and kit.info.has_method("achievement_rows"):
			utils.append([kit.tr("🏅 Achievements"), Callable(kit, "_show_achievements")])
		utils.append([kit.tr("📊 Statistics"), Callable(kit, "_show_stats")])
		utils.append([kit.tr("⚙ Options"), Callable(kit, "_show_options")])
		for u in utils:
			var up: Array = split_glyph(str(u[0]))
			_add("util", up[0], up[1], color, u[1])
		_add("hub", "←", str(kit.tr("Hub")), color.lerp(Color.WHITE, 0.2), Callable(kit, "_on_hub_pressed"), {"full": str(kit.tr("Hub"))})

	func _entries_of(kinds: Array) -> Array:
		return entries.filter(func(e): return e.kind in kinds and e.shown)

	## The kit's refresh() ran: Resume / Quick Play show or hide, then lay out again.
	func refresh() -> void:
		for e in entries:
			if e.kind == "resume":
				e["shown"] = kit.resume_btn.visible
				var txt: String = kit.resume_btn.text
				e["detail"] = txt.substr(txt.find("·") + 1).strip_edges() if "·" in txt else ""
			elif e.kind == "quick":
				e["shown"] = kit.quick_btn.visible
				var txt2: String = kit.quick_btn.text
				e["detail"] = txt2.get_slice("\n", 1).strip_edges() if "\n" in txt2 else ""
		_items_changed()
		_layout()

	# ----- backdrop and ambience (shared) -----

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
		# The game's own pictures (cfg "landing_art"): one per orientation, under a veil that keeps the
		# text readable.
		var pics: Dictionary = kit.cfg.get("landing_art", {})
		for k in pics:
			if ResourceLoader.exists(str(pics[k])):
				_pics[k] = load(str(pics[k]))
		if not _pics.is_empty():
			_art = TextureRect.new()
			_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_art)
			_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_veil = ColorRect.new()
			_veil.color = Color(0.02, 0.02, 0.08, float(kit.cfg.get("landing_veil", 0.42)))
			_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_veil)
			_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var side: float = float(kit.cfg.get("landing_side_veil", 0.0))
		if side > 0.0 and not _pics.is_empty():
			var sg := Gradient.new()
			sg.set_color(0, Color(0.02, 0.02, 0.08, side))
			sg.set_color(1, Color(0.02, 0.02, 0.08, 0.0))
			sg.add_point(0.45, Color(0.02, 0.02, 0.08, side * 0.75))
			var sfill := GradientTexture2D.new()
			sfill.gradient = sg
			sfill.fill_from = Vector2(0, 0)
			sfill.fill_to = Vector2(1, 0)
			sfill.width = 256
			sfill.height = 4
			var sv := TextureRect.new()
			sv.texture = sfill
			sv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sv.stretch_mode = TextureRect.STRETCH_SCALE
			sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(sv)
			sv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_build_twilight()
		_glow = TextureRect.new()
		_glow.texture = Fx.blob(128)
		_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_glow.stretch_mode = TextureRect.STRETCH_SCALE
		_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glow.modulate = Color(_orb_color(), 0.22)
		add_child(_glow)
		if kit.cfg.has("landing_mist"):
			_mist = Fx.mist(self, kit.cfg.landing_mist, float(kit.cfg.get("landing_mist_amount", 0.22)))
			if _mist:
				_mist.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var lights: Dictionary = kit.cfg.get("landing_lights", {})
		for orient in lights:
			for l in lights[orient]:
				var node := Fx.light(self, l[3], float(l[2]))
				_lights.append({"node": node, "orient": str(orient), "x": float(l[0]), "y": float(l[1]), "d": float(l[2])})
				node.visible = false
		# Smoke behind the title, glitter over the whole screen, both under the buttons.
		_smoke = Fx.smoke(self, Color(kit.accent.lerp(Color.WHITE, 0.25), 1.0), Vector2(200, 40))
		_glitter = Fx.glitter(self, kit.cfg.get("orb_glitter", _orb_color().lerp(Color.WHITE, 0.5)), Vector2(300, 500))
		if _smoke:
			_smoke.emitting = false
		if _glitter:
			_glitter.emitting = false

	## Dusk: indigo at the top, amber at the bottom, the whole tint breathing slowly.
	func _build_twilight() -> void:
		if not bool(kit.cfg.get("landing_twilight", false)):
			return
		var grad := Gradient.new()
		grad.set_color(0, Color(0.16, 0.12, 0.45, 0.5))
		grad.set_color(1, Color(0.95, 0.5, 0.2, 0.2))
		grad.add_point(0.5, Color(0.1, 0.05, 0.25, 0.0))
		var fill := GradientTexture2D.new()
		fill.gradient = grad
		fill.fill_from = Vector2(0, 0)
		fill.fill_to = Vector2(0, 1)
		fill.width = 4
		fill.height = 128
		_twilight = TextureRect.new()
		_twilight.texture = fill
		_twilight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_twilight.stretch_mode = TextureRect.STRETCH_SCALE
		_twilight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_twilight)
		_twilight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	## Where a point of the picture (fractions) lands on screen: the picture is scaled to cover.
	func _cover_point(tex: Texture2D, view: Vector2, fx: float, fy: float) -> Vector2:
		var ts := Vector2(tex.get_size())
		var k := maxf(view.x / ts.x, view.y / ts.y)
		var off := (view - ts * k) * 0.5
		return off + Vector2(fx * ts.x, fy * ts.y) * k

	func _place_backdrop(W: float, H: float, wide: bool) -> void:
		var which := "wide" if wide else "portrait"
		if _art != null:
			var pic: Texture2D = _pics.get(which, _pics.values()[0])
			if _art.texture != pic:
				_art.texture = pic
			for l in _lights:
				var on: bool = l.orient == which
				(l.node as Control).visible = on and _active
				if on:
					var p := _cover_point(pic, Vector2(W, H), l.x, l.y)
					var d: float = l.d * minf(W, H) / 720.0
					(l.node as Control).size = Vector2(d, d)
					(l.node as Control).pivot_offset = Vector2(d, d) * 0.5
					(l.node as Control).position = p - Vector2(d, d) * 0.5
		if _glitter:
			_glitter.position = Vector2(W * 0.5, H * 0.5)
			_glitter.emission_rect_extents = Vector2(W * 0.5, H * 0.5)

	## Glow and smoke sit behind the title: `title_rect` is where it is.
	func _place_title_fx(title_rect: Rect2) -> void:
		_glow.position = title_rect.position - Vector2(title_rect.size.x * 0.1, title_rect.size.y * 0.5)
		_glow.size = Vector2(title_rect.size.x * 1.2, title_rect.size.y * 2.0)
		if _smoke:
			_smoke.position = title_rect.get_center() + Vector2(0, title_rect.size.y * 0.3)
			_smoke.emission_rect_extents = Vector2(title_rect.size.x * 0.42, 30.0)

	# ----- the title column -----

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

	func _fit_info(col_w: float, wide: bool) -> void:
		var art: Node = info_col.get_node_or_null("TitleArt")
		if art:
			(art as Control).custom_minimum_size = Vector2(0, col_w * float(art.get_meta("aspect")))
		var t: Label = info_col.get_node_or_null("TitleText")
		if t:
			t.add_theme_font_size_override("font_size", fit_font(t.text, col_w - 20.0, int(clampf(col_w * 0.11, 30.0, 60.0)), 26))
		var sub: Label = info_col.get_node_or_null("Subtitle")
		if sub:
			sub.add_theme_font_size_override("font_size", 20 if wide else 24)

	## Measures the title column at width `col_w` (in the caller's position) and, if its height changed
	## since the last pass, asks for another layout (labels wrap a frame late). Returns the height.
	func _measure_info(col_w: float, wide: bool, pad: float) -> float:
		info_col.position = Vector2(pad, pad)
		info_col.size = Vector2(col_w, 0.0)
		_fit_info(col_w, wide)
		var h := info_col.get_combined_minimum_size().y
		if absf(h - _last_info_h) > 1.0 and _relayouts < 4:
			_last_info_h = h
			_relayouts += 1
			call_deferred("_layout")
		else:
			_relayouts = 0
		return h

	func _extras_visible() -> bool:
		return not _extras.is_empty() and (_extras[0] as Control).visible

	## Measures the extras while they are shown (their height at the current width).
	func _measure_extras(width: float = 0.0) -> void:
		if _extras_visible():
			_extras_h = 0.0
			for e in _extras:
				if width > 0.0:
					(e as Control).size = Vector2(width, 0.0)
				_extras_h += (e as Control).get_combined_minimum_size().y + 8.0

	func _set_extras(on: bool) -> bool:
		if _extras.is_empty() or on == _extras_visible():
			return false
		for e in _extras:
			(e as Control).visible = on
		_last_info_h = -1.0
		if _relayouts < 6:
			_relayouts += 1
			call_deferred("_layout")
		return true

	# ----- motion -----

	## The kit shows or hides the Landing: motion and particles only run while it is up.
	func set_active(on: bool) -> void:
		_active = on
		if _float and _float.is_valid():
			_float.kill()
		if _breath and _breath.is_valid():
			_breath.kill()
		var full: bool = on and not Fx.reduced()
		if _smoke:
			_smoke.emitting = full
		if _glitter:
			_glitter.emitting = full
		for l in _lights:
			if on:
				Fx.flicker_start(l.node, float(_lights.find(l)) * 1.9)
			else:
				Fx.flicker_stop(l.node)
		if _twilight != null and full:
			_breath = create_tween()
			_breath.set_loops()
			_breath.tween_property(_twilight, "modulate:a", 0.55, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_breath.tween_property(_twilight, "modulate:a", 1.0, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if not on:
			return
		_layout()
		_intro()
		_start_float()

	func _start_float() -> void:
		if Fx.reduced() or not _active:
			return
		_float = create_tween()
		_float.set_loops()
		_float.tween_method(_float_step, 0.0, TAU, 7.0)

	## The "Reduce effects" row of ⚙ Options.
	func _on_fx_pick(i: int) -> void:
		Fx.set_reduced(i == 1)
		_reset_motion()
		if _float and _float.is_valid():
			_float.kill()
		if _breath and _breath.is_valid():
			_breath.kill()
		for l in _lights:
			if i == 0:
				Fx.flicker_start(l.node, float(_lights.find(l)) * 1.9)
			else:
				Fx.flicker_start(l.node, 0.0)
		if _smoke:
			_smoke.emitting = _active and i == 0
		if _glitter:
			_glitter.emitting = _active and i == 0
		if _mist:
			_mist.visible = i == 0
		_start_float()

	# ----- to override -----

	func _build_items() -> void:
		pass

	func _items_changed() -> void:
		pass

	func _layout() -> void:
		pass

	func _intro() -> void:
		pass

	func _float_step(_v: float) -> void:
		pass

	func _reset_motion() -> void:
		pass


## ---------- orbs ----------

class OrbLanding extends StyleBase:
	## Size of each main orb relative to the biggest, in the order they appear.
	const FACTORS := [1.0, 0.78, 0.9, 0.7, 0.84, 0.74, 0.8, 0.68]
	## The bottom row's uneven sizes and how far each bobs off the row's line (x its size).
	const SPREAD_FACTORS := [0.96, 0.8, 0.9, 1.0, 0.84]
	const SPREAD_DROP := [-0.1, 0.12, -0.04, 0.1, -0.12]
	const MIN_ORB := 56.0

	func _build_items() -> void:
		for i in entries.size():
			var e: Dictionary = entries[i]
			_make_orb(e)
			e["phase"] = float(i) * 1.7
			e["amp"] = 5.0 + float((i * 5) % 4) * 1.4

	func _make_orb(e: Dictionary) -> void:
		var color: Color = e.color
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = (str(e.glyph) + " " + str(e.nm)).strip_edges()      # real text: tests, screen readers
		b.clip_text = true
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color(0, 0, 0, 0))   # the labels below draw it
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, _orb_box(color, st))
		b.tooltip_text = str(e.nm)
		b.pressed.connect(e.cb)
		Fx.bind_press(b)
		slot.add_child(b)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var gl: Label = kit.label(str(e.glyph), 40, kit.WHITE, false, true)
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(gl)
		var nl: Label = kit.label(str(e.nm), 20, kit.WHITE, true, true)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nl.add_theme_color_override("font_outline_color", Color(kit.BG, 0.8))
		nl.add_theme_constant_override("outline_size", 4)
		col.add_child(nl)
		e["slot"] = slot
		e["btn"] = b
		e["glyph_l"] = gl
		e["name_l"] = nl

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

	func _items_changed() -> void:
		for e in entries:
			if e.kind == "resume" or e.kind == "quick":
				(e.btn as Button).text = (str(e.glyph) + " " + str(e.nm) + " " + str(e.detail)).strip_edges()

	func _intro() -> void:
		var i := 0
		for e in entries:
			if e.shown:
				Fx.pop_in(e.btn, 0.04 + 0.055 * float(i))
				i += 1

	## One slow sine per orb, each at its own phase; the loop is one full turn, so it never jumps.
	func _float_step(v: float) -> void:
		for e in entries:
			var b: Button = e.btn
			var a: float = e.amp
			b.position = Vector2(sin(v + e.phase * 0.6) * a * 0.45, sin(v + e.phase) * a)

	func _reset_motion() -> void:
		for e in entries:
			(e.btn as Button).position = Vector2.ZERO

	func _layout() -> void:
		if not is_inside_tree() or size.x < 40.0 or size.y < 40.0:
			return
		var W := size.x
		var H := size.y
		var wide := W > H * 1.1
		_place_backdrop(W, H, wide)
		var pad := 18.0
		var hub_s := clampf(minf(W, H) * 0.11, MIN_ORB, 84.0)
		var spreads: Array = _entries_of(["spread"])
		var mains: Array = _entries_of(["resume", "quick", "main", "util"])
		for e in entries:
			(e.slot as Control).visible = e.shown
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
		var hub: Dictionary = entries.filter(func(e): return e.kind == "hub")[0]
		_put(hub, Vector2(pad + hub_s * 0.5, H - pad - hub_s * 0.5), hub_s, false)
		if spreads.is_empty():
			row_top = H - pad - hub_s
		# --- the title column ---
		var col_w := (W * 0.4 - pad) if wide else (W - pad * 2.0)
		var info_h := _measure_info(col_w, wide, pad)
		# Room for the fact card and version line? Landscape: only if the column stays above the
		# bottom row. Portrait: only if the orbs can still be 100+ units wide.
		_measure_extras()
		var full_h: float = info_h + (0.0 if _extras_visible() else _extras_h)
		var want_extras := true
		if wide:
			want_extras = pad + full_h <= row_top - 10.0
		else:
			var top_full := pad + full_h + 14.0
			var area_full := Rect2(pad, top_full, W - pad * 2.0, row_top - top_full - 14.0)
			want_extras = _best(mains.size(), area_full)[1] >= 100.0
		if _set_extras(want_extras):
			return
		_place_title_fx(Rect2(pad, pad, col_w, minf(info_h, 230.0)))
		# --- the main orbs ---
		var area: Rect2
		if wide:
			area = Rect2(W * 0.4, pad, W * 0.6 - pad, row_top - pad - 10.0)
		else:
			var top := pad + info_h + 14.0
			area = Rect2(pad, top, W - pad * 2.0, row_top - top - 14.0)
		_place_main(mains, area)

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
		var cols: int = best[0]
		var unit := clampf(float(best[1]), MIN_ORB, 190.0)
		var rows := ceili(float(n) / float(cols))
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
	func _put(e: Dictionary, c: Vector2, d: float, number: bool) -> void:
		var slot: Control = e.slot
		slot.position = c - Vector2(d, d) * 0.5
		slot.size = Vector2(d, d)
		var b: Button = e.btn
		b.size = Vector2(d, d)
		b.custom_minimum_size = Vector2(d, d)
		b.pivot_offset = Vector2(d, d) * 0.5
		var gl: Label = e.glyph_l
		var nl: Label = e.name_l
		# The big glyph; a number (the spreads) is drawn bolder and larger than an emoji.
		gl.add_theme_font_size_override("font_size", int(d * (0.46 if number else 0.36)))
		var inner := d * 0.78
		nl.custom_minimum_size.x = inner
		nl.text = str(e.nm)
		var fs := fit_font(nl.text, inner, int(clampf(d * 0.17, 12.0, 26.0)), 11)
		nl.add_theme_font_size_override("font_size", fs)
		# A name that cannot fit even at the smallest size is left out (the glyph carries the orb)
		# rather than broken mid-word.
		var longest := ""
		for w in nl.text.split(" "):
			if w.length() > longest.length():
				longest = w
		nl.visible = d >= 62.0 and ThemeDB.fallback_font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= inner + 1.0


## ---------- list ----------

## A diamond outline with a symbol inside: the icon of a menu row.
class Diamond extends Control:
	var color := Color("e0bf4d")
	var lit := 0.0

	func set_lit(v: float) -> void:
		lit = v
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var pts := [Vector2(c.x, c.y - r), Vector2(c.x + r, c.y), Vector2(c.x, c.y + r), Vector2(c.x - r, c.y)]
		if lit > 0.0:
			draw_colored_polygon(PackedVector2Array(pts), Color(color, 0.22 * lit))
		var a := 0.8 + 0.2 * lit
		for i in 4:
			draw_line(pts[i], pts[(i + 1) % 4], Color(color, a), 1.6)
		var r2 := r * 0.8
		var q := [Vector2(c.x, c.y - r2), Vector2(c.x + r2, c.y), Vector2(c.x, c.y + r2), Vector2(c.x - r2, c.y)]
		for i in 4:
			draw_line(q[i], q[(i + 1) % 4], Color(color, 0.35), 1.0)


## The gold rule beside the list (diamonds at both ends) and the ornament under it.
class Rules extends Control:
	var color := Color("e0bf4d")
	var rule := Rect2()           # x, y top, w unused, h
	var ornament := Rect2()       # a horizontal ornament: x, y, w, h
	var show_rule := false
	var show_ornament := false

	func _diamond(c: Vector2, r: float, alpha: float) -> void:
		var pts := PackedVector2Array([Vector2(c.x, c.y - r), Vector2(c.x + r, c.y), Vector2(c.x, c.y + r), Vector2(c.x - r, c.y)])
		draw_colored_polygon(pts, Color(color, alpha))

	func _draw() -> void:
		if show_rule:
			var x := rule.position.x
			var y0 := rule.position.y
			var y1 := rule.position.y + rule.size.y
			draw_line(Vector2(x, y0), Vector2(x, y1), Color(color, 0.7), 1.5)
			_diamond(Vector2(x, y0), 6.0, 0.9)
			_diamond(Vector2(x, y1), 6.0, 0.9)
		if show_ornament:
			var o := ornament
			var cy := o.position.y + o.size.y * 0.5
			var cx := o.position.x + o.size.x * 0.5
			draw_line(Vector2(o.position.x, cy), Vector2(o.end.x, cy), Color(color, 0.55), 1.2)
			_diamond(Vector2(cx, cy), 7.0, 0.95)
			_diamond(Vector2(cx - 22.0, cy), 3.5, 0.8)
			_diamond(Vector2(cx + 22.0, cy), 3.5, 0.8)


## One menu row: a flat button over an inner Control that holds the icon, the texts and the line.
class Row extends Button:
	var inner: Control
	var dia: Diamond
	var glyph: Label
	var name_l: Label
	var sub_l: Label
	var line: TextureRect


class ListLanding extends StyleBase:
	const MIN_ROW := 38.0
	const MAX_ROW := 96.0
	var rows: Array = []              # the Row of each entry (same order as entries; null for utils)
	var rules: Rules
	var caption: Label                # the name of the utility icon under the pointer
	var _squeezed := false            # a very short window: the subtitle and rating line are dropped
	var _caption_tw: Tween
	var _caps: FontVariation

	func _gold() -> Color:
		return _orb_color()

	func _build_items() -> void:
		_caps = FontVariation.new()
		_caps.base_font = get_theme_default_font()
		_caps.spacing_glyph = 2
		rules = Rules.new()
		rules.color = _gold()
		rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rules)
		caption = kit.label("", 22, Color("f3e6c8"), false, true)
		caption.add_theme_font_override("font", _caps)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.modulate.a = 0.0
		add_child(caption)
		# The extras (fact card, version line) go below the menu, not in the title column.
		for e in entries:
			e["row"] = _make_row(e)
		for x in _extras:
			(x as Control).reparent(self, false)

	func _make_row(e: Dictionary) -> Row:
		var gold := _gold()
		var util: bool = e.kind == "util"
		var r := Row.new()
		r.flat = true
		r.focus_mode = Control.FOCUS_NONE
		r.text = (str(e.glyph) + " " + str(e.full)).strip_edges()
		r.clip_text = true
		r.add_theme_font_size_override("font_size", 6)    # the text is only for tests and screen readers
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			r.add_theme_color_override(c, Color(0, 0, 0, 0))
		r.tooltip_text = str(e.full)
		r.pressed.connect(e.cb)
		r.button_down.connect(_row_down.bind(r))
		r.button_up.connect(_row_up.bind(r))
		if util:
			# The five utility icons carry no printed names (they only collided): the name shows in one
			# caption above them on mouse-over, or while an icon is pressed and held.
			r.mouse_entered.connect(_show_caption.bind(str(e.nm)))
			r.mouse_exited.connect(_hide_caption)
			r.button_down.connect(_show_caption.bind(str(e.nm)))
			r.button_up.connect(_hide_caption)
		add_child(r)
		r.inner = Control.new()
		r.inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(r.inner)
		r.dia = Diamond.new()
		r.dia.color = gold
		r.dia.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.inner.add_child(r.dia)
		var glyph_text: String = str(e.get("icon", e.glyph))
		r.glyph = kit.label(glyph_text, 26, kit.WHITE, false, true)
		r.glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.dia.add_child(r.glyph)
		r.glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		r.name_l = kit.label(str(e.full if not util else e.nm).to_upper(), 24, Color("f3e6c8"), false, util)
		r.name_l.add_theme_font_override("font", _caps)
		r.name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.name_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		r.inner.add_child(r.name_l)
		r.sub_l = kit.label(str(e.sub), 16, Color(kit.DIM, 0.95), false, util)
		r.sub_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.inner.add_child(r.sub_l)
		if not util:
			var grad := Gradient.new()
			grad.set_color(0, Color(gold, 0.85))
			grad.set_color(1, Color(gold, 0.0))
			var fill := GradientTexture2D.new()
			fill.gradient = grad
			fill.fill_from = Vector2(0, 0)
			fill.fill_to = Vector2(1, 0)
			fill.width = 256
			fill.height = 2
			r.line = TextureRect.new()
			r.line.texture = fill
			r.line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.line.stretch_mode = TextureRect.STRETCH_SCALE
			r.line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.inner.add_child(r.line)
		return r

	func _show_caption(text: String) -> void:
		caption.text = text.to_upper()
		if _caption_tw and _caption_tw.is_valid():
			_caption_tw.kill()
		_caption_tw = caption.create_tween()
		_caption_tw.tween_property(caption, "modulate:a", 1.0, 0.12)

	func _hide_caption() -> void:
		if _caption_tw and _caption_tw.is_valid():
			_caption_tw.kill()
		_caption_tw = caption.create_tween()
		_caption_tw.tween_interval(0.5)
		_caption_tw.tween_property(caption, "modulate:a", 0.0, 0.3)

	func _row_down(r: Row) -> void:
		r.dia.set_lit(1.0)
		r.name_l.add_theme_color_override("font_color", Color.WHITE)
		if r.has_meta("nudge"):
			var old: Variant = r.get_meta("nudge")
			if old is Tween and old.is_valid():
				old.kill()
		var tw := r.create_tween()
		r.set_meta("nudge", tw)
		tw.tween_property(r.inner, "position:x", 8.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	func _row_up(r: Row) -> void:
		r.dia.set_lit(0.0)
		r.name_l.add_theme_color_override("font_color", Color("f3e6c8"))
		if r.has_meta("nudge"):
			var old: Variant = r.get_meta("nudge")
			if old is Tween and old.is_valid():
				old.kill()
		var tw := r.create_tween()
		r.set_meta("nudge", tw)
		tw.tween_property(r.inner, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	func _items_changed() -> void:
		for e in entries:
			if e.kind == "resume" or e.kind == "quick":
				var r: Row = e.row
				r.sub_l.text = str(e.detail)

	func _intro() -> void:
		var i := 0
		for e in entries:
			var r: Row = e.row
			if e.shown:
				Fx.slide_in(r.inner, 0.05 + 0.06 * float(i))
				i += 1

	## The diamonds breathe: a slow sine of brightness, each row at its own phase.
	func _float_step(v: float) -> void:
		var i := 0
		for e in entries:
			var r: Row = e.row
			r.dia.modulate.a = 0.78 + 0.22 * sin(v + float(i) * 0.9)
			i += 1

	func _reset_motion() -> void:
		for e in entries:
			(e.row as Row).dia.modulate.a = 1.0

	func _layout() -> void:
		if not is_inside_tree() or size.x < 40.0 or size.y < 40.0:
			return
		var W := size.x
		var H := size.y
		_place_backdrop(W, H, W > H * 1.1)
		# A short window (landscape, or a near-square one at big text) gets the two-column layout.
		var wide := W > H * 1.1 or H < 600.0
		var pad := 18.0
		for e in entries:
			(e.row as Row).visible = e.shown
		var mains: Array = _entries_of(["resume", "quick", "spread", "main", "hub"])
		var utils: Array = _entries_of(["util"])
		# --- the title: centred across the top ---
		var title_w := minf(W - pad * 2.0, 620.0) if not wide else minf(W * 0.5, 460.0)
		var info_h := _measure_info(title_w, wide, pad)
		info_col.position.x = (W - title_w) * 0.5 if not wide else pad + 20.0
		# --- the bottom: the utility diamonds and an ornament over them ---
		var tb_h := clampf(H * 0.085, 70.0, 112.0) if utils.size() > 0 else 0.0
		var bottom := H - pad
		var tb_top := bottom - tb_h
		var orn_y := tb_top - 18.0
		var menu_top := pad + info_h + 14.0
		var avail := orn_y - menu_top - (40.0 if not utils.is_empty() else 10.0)
		var cols := 2 if wide else 1
		if wide and avail / float(ceili(float(mains.size()) / 2.0)) < MIN_ROW:
			cols = 3
		var per_col := ceili(float(mains.size()) / float(cols))
		if wide and not _squeezed and avail / float(per_col) < MIN_ROW:
			_squeezed = true
			for ch in info_col.get_children():
				if ch.name != "TitleArt" and ch.name != "TitleText" and not _extras.has(ch):
					(ch as Control).visible = false
			_last_info_h = -1.0
			call_deferred("_layout")
			return
		# Room for the fact card and version line? Only if the rows can stay 80+ units tall.
		_measure_extras(W - pad * 2.0)
		var foot_h: float = _extras_h
		var want_extras := not wide and (avail - foot_h) / float(maxi(1, per_col)) >= 80.0
		if _extras_visible() != want_extras and _set_extras(want_extras):
			return
		var foot_shown := _extras_visible() and not wide
		var rows_avail := avail - (foot_h if foot_shown else 0.0)
		var row_h := clampf(rows_avail / float(maxi(1, per_col)), MIN_ROW, MAX_ROW)
		var list_x := pad + 34.0
		var col_w := 0.0
		if wide:
			col_w = minf((W - list_x - pad) / float(cols) - 24.0, 330.0)
		else:
			col_w = minf(W * 0.66, 470.0)
		# --- the rows ---
		for i in mains.size():
			var c := i / per_col if wide else 0
			var rr := i % per_col if wide else i
			_put_row(mains[i].row, Vector2(list_x + float(c) * (col_w + 24.0), menu_top + float(rr) * row_h), Vector2(col_w, row_h), mains[i])
		var list_h := float(per_col) * row_h
		# --- the rule beside the list and the ornament under it ---
		rules.position = Vector2.ZERO
		rules.size = size
		rules.rule = Rect2(pad + 8.0, menu_top + 4.0, 0.0, list_h - 8.0)
		rules.show_rule = not mains.is_empty()
		rules.ornament = Rect2(pad, orn_y - 6.0, W - pad * 2.0, 12.0)
		rules.show_ornament = not utils.is_empty()
		rules.queue_redraw()
		caption.position = Vector2(pad, orn_y - 40.0)
		caption.size = Vector2(W - pad * 2.0, 30.0)
		caption.add_theme_font_size_override("font_size", int(clampf(H * 0.022, 16.0, 24.0)))
		# --- the foot (fact card, version) between the rows and the ornament ---
		if foot_shown:
			var fy := menu_top + list_h + 6.0
			for x in _extras:
				var ctl := x as Control
				ctl.position = Vector2(pad, fy)
				ctl.size = Vector2(W - pad * 2.0, 0.0)
				fy += ctl.get_combined_minimum_size().y + 8.0
		# --- the utility diamonds ---
		var cell := (W - pad * 2.0) / float(maxi(1, utils.size()))
		for i in utils.size():
			var d := minf(cell * 0.62, tb_h * 0.66)
			var cx := pad + (float(i) + 0.5) * cell
			_put_util(utils[i].row, Vector2(cx, tb_top + tb_h * 0.5), Vector2(cell, tb_h), d, utils[i])
		_place_title_fx(Rect2(info_col.position.x, pad, title_w, minf(info_h, 230.0)))

	func _put_row(r: Row, pos: Vector2, sz: Vector2, e: Dictionary) -> void:
		r.position = pos
		r.size = sz
		r.custom_minimum_size = sz
		r.inner.size = sz
		var d := minf(sz.y * 0.7, 60.0)
		r.dia.position = Vector2(2.0, (sz.y - d) * 0.5)
		r.dia.size = Vector2(d, d)
		r.glyph.add_theme_font_size_override("font_size", int(d * 0.46))
		var tx := d + 20.0
		var tw := maxf(10.0, sz.x - tx)
		var name_fs := fit_line(r.name_l.text, tw - 4.0, int(clampf(sz.y * 0.3, 18.0, 30.0)), 13, 2.0)
		r.name_l.add_theme_font_size_override("font_size", name_fs)
		var has_sub: bool = sz.y >= 66.0 and str(e.sub) != ""
		var sub_fs := int(clampf(float(name_fs) * 0.66, 12.0, 20.0))
		r.sub_l.add_theme_font_size_override("font_size", sub_fs)
		r.sub_l.visible = has_sub
		r.sub_l.clip_text = true
		r.sub_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var name_h := ThemeDB.fallback_font.get_height(name_fs)
		var sub_h := ThemeDB.fallback_font.get_height(sub_fs) if has_sub else 0.0
		var block := name_h + sub_h + (2.0 if has_sub else 0.0)
		var y0 := (sz.y - block) * 0.5 - 2.0
		r.name_l.position = Vector2(tx, y0)
		r.name_l.size = Vector2(tw, name_h)
		r.name_l.clip_text = true
		r.sub_l.position = Vector2(tx, y0 + name_h + 2.0)
		r.sub_l.size = Vector2(tw, sub_h)
		if r.line:
			r.line.position = Vector2(tx, sz.y - 3.0)
			r.line.size = Vector2(tw, 2.0)

	## A utility diamond: the icon with its name small underneath.
	func _put_util(r: Row, c: Vector2, cell: Vector2, d: float, _e: Dictionary) -> void:
		r.position = c - cell * 0.5
		r.size = cell
		r.custom_minimum_size = cell
		r.inner.size = cell
		r.dia.position = Vector2((cell.x - d) * 0.5, 2.0)
		r.dia.size = Vector2(d, d)
		r.glyph.add_theme_font_size_override("font_size", int(d * 0.46))
		var fs := fit_line(r.name_l.text, cell.x - 6.0, int(clampf(cell.y * 0.17, 12.0, 20.0)), 10, 2.0)
		r.name_l.add_theme_font_size_override("font_size", fs)
		r.name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.name_l.position = Vector2(3.0, d + 4.0)
		r.name_l.size = Vector2(cell.x - 6.0, ThemeDB.fallback_font.get_height(fs))
		r.name_l.visible = false      # the caption above the row shows it while the icon is held
		r.sub_l.visible = false
