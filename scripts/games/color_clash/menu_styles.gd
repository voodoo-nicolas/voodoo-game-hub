extends RefCounted

## Menu styles: six Landing layouts from docs/MENU_STYLES.md (owner 2026-11-13: "so the menus
## aren't all alike"), with a big, bold, many-coloured title in the game's own font.
##
## GENERATED COPY: `python tools/hub.py sync` copies tools/templates/menu_styles.gd to
## scripts/games/<id>/menu_styles.gd for every game whose scripts mention it, so each pack
## carries its own copy and runs on any app version (like home_kit.gd, N7). Edit the template.
## Self-contained on purpose: it needs no other landing style file and no effects helper.
##
## A game opts in through the kit's cfg:
##     const MenuStyles = preload("res://scripts/games/<id>/menu_styles.gd")
##     HomeKit.new({..., "landing": "slabs", "landing_style": MenuStyles, ...})
## The kit then builds the Landing through `build()` instead of its stacked buttons. Same actions
## in the same order (STANDARDS §3, MENU_STYLES §0.1): T1 Resume / Quick Play / ways to play,
## T2 ❓ 🏆 🏅 📊 ⚙, T3 ← Hub (N1: only here). Only the layout changes.
##
## Styles (MENU_STYLES.md):
##   "ghost"     S1 Corner Ghost: title top-left, plain text rows, hexagon icons top-right, art right
##   "ring"      S2 Center Ring: centred title and rows inside a faint ring, the chosen row gold and big
##   "rail"      S3 Rail List: two-tone title, every action a flush-left row, one glowing box
##   "monument"  S4 Monument: a huge title, two or three small rows under it, the art huge at the right
##   "slabs"     S6 Stone Slabs: chunky tapered slab buttons, centred; icons in the corners, mascot
##   "cinema"    S7 Diegetic Cinema: black bars, a drifting scene, tiny caps rows bottom-left
##   "split"     S8 Diagonal Split: a bold slanted colour band holds the title; slanted tab buttons
##   "marquee"   S9 Arcade Marquee: the title in a sign of chasing bulbs, neon pill buttons, round tokens
##   "bento"     S10 Bento Grid: one big Play tile and smaller coloured tiles, like a lunch box
##   "stickers"  S11 Sticker Board: tilted die-cut stickers with thick outlines on a dotted board
## (S5 Ornate Scroll is the "list" style of the other Landing styles file.)
##
## cfg (all optional):
##   "title_font": "res://games/<id>/title.ttf"   the title's font (falls back to the theme font when a
##                                                 letter of the translated title is missing)
##   "title_colors": [Color, ...]   letters cycle through these (default: accent + white)
##   "title_outline": Color         thick outline under the letters (default near-black)
##   "menu_font": true              the buttons use the title font too
##   "menu_color": Color            the highlight colour (default the kit accent)
##   "landing_colors": [top, bottom]  the backdrop gradient
##   "landing_stars": 60            how many stars in the backdrop (style default otherwise)
## The game's cfg "logo" drawing is the hero art (big in "monument" / "cinema", a mascot in "slabs").

const STYLES := ["ghost", "ring", "rail", "monument", "slabs", "cinema", "split", "marquee", "bento", "stickers"]

static func build(kit, home: Control) -> Control:
	var st := str(kit.cfg.get("landing", ""))
	if not st in STYLES:
		return null
	var node := MenuLanding.new(kit, st)
	home.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return node

## The kit calls this inside ⚙ Options: nothing extra here (motion obeys user://fx.json "reduce",
## which the Options of any orb/list Landing sets).
static func options(_kit, _body: VBoxContainer) -> void:
	pass

## ---------- the big title: one colour per letter, outline, shadow, a gentle bob ----------

class BigTitle extends Control:
	var text := ""
	var font: Font
	var colors: Array = []
	var outline := Color(0.02, 0.02, 0.06)
	var align := HORIZONTAL_ALIGNMENT_LEFT
	var t := 0.0
	var bob := true
	var _lines: PackedStringArray = []
	var _fs := 40

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(_fit)

	func _w(s: String, fs: int) -> float:
		return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 0.14

	## The biggest size at which the title fits the box: one line, or two if that is bigger.
	func _fit() -> void:
		if font == null or size.x < 10.0 or size.y < 10.0:
			return
		var best_fs := 8
		var best: PackedStringArray = [text]
		var options: Array = [PackedStringArray([text])]
		var words := text.split(" ")
		if words.size() > 1:
			var best_split := PackedStringArray()
			var best_w := INF
			for i in range(1, words.size()):
				var a := " ".join(words.slice(0, i))
				var b := " ".join(words.slice(i))
				var w := maxf(_w(a, 40), _w(b, 40))
				if w < best_w:
					best_w = w
					best_split = PackedStringArray([a, b])
			options.append(best_split)
		for lines in options:
			var lo := 8
			var hi := 400
			while lo < hi:
				var mid := (lo + hi + 1) / 2
				var ok := float(lines.size()) * font.get_height(mid) * 0.92 <= size.y
				for l in lines:
					ok = ok and _w(l, mid) <= size.x
				if ok:
					lo = mid
				else:
					hi = mid - 1
			if lo > best_fs:
				best_fs = lo
				best = lines
		_fs = best_fs
		_lines = best
		queue_redraw()

	## Height actually used (the box may be taller than the letters).
	func used_height() -> float:
		return float(_lines.size()) * font.get_height(_fs) * 0.92 if font else 0.0

	func _draw() -> void:
		if font == null or _lines.is_empty():
			return
		var lh := font.get_height(_fs) * 0.92
		var asc := font.get_ascent(_fs)
		var ol := maxi(4, int(_fs * 0.12))
		var k := 0
		for li in _lines.size():
			var line: String = _lines[li]
			var lw := _w(line, _fs)
			var x := 0.0
			if align == HORIZONTAL_ALIGNMENT_CENTER:
				x = (size.x - lw) * 0.5
			elif align == HORIZONTAL_ALIGNMENT_RIGHT:
				x = size.x - lw
			var y := float(li) * lh + asc
			for i in line.length():
				var ch := line.substr(i, 1)
				var adv := font.get_char_size(line.unicode_at(i), _fs).x
				if ch == " ":
					x += adv
					continue
				var dy := sin(t * 2.2 + float(k) * 0.55) * _fs * 0.035 if bob else 0.0
				var p := Vector2(x, y + dy)
				var c: Color = colors[k % colors.size()] if not colors.is_empty() else Color.WHITE
				draw_char_outline(font, p + Vector2(_fs * 0.05, _fs * 0.07), ch, _fs, ol, Color(0, 0, 0, 0.55))
				draw_char_outline(font, p, ch, _fs, ol, outline)
				draw_char(font, p, ch, _fs, c)
				draw_char(font, p + Vector2(0, -_fs * 0.02), ch, _fs, Color(c.lightened(0.45), 0.35))
				x += adv
				k += 1


## ---------- the backdrop: gradient, stars, bokeh, hills, rays, ring, letterbox ----------

class Backdrop extends Control:
	var top := Color("0a0d24")
	var bottom := Color("1b1450")
	var accent := Color.WHITE
	var stars := 0
	var bokeh := 0
	var hills := false
	var rays := false
	var ring := Rect2()           # a faint circle (S1 arc, S2 ring); size 0 = none
	var ring_color := Color.WHITE
	var bars := 0.0               # letterbox bar height (S7)
	var drift := false            # stars drift sideways (S7 scene)
	var band := PackedVector2Array()   # S8: the slanted colour band
	var band_color := Color.WHITE
	var bulbs := Rect2()          # S9: chasing bulbs around this rect
	var bulb_color := Color.WHITE
	var dots := false             # S11: a dotted board
	var t := 0.0
	var _seed: Array = []
	var _blob: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_blob = _make_blob()
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 160:
			_seed.append(Vector4(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
		resized.connect(queue_redraw)

	func _make_blob() -> Texture2D:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tx := GradientTexture2D.new()
		tx.gradient = g
		tx.fill = GradientTexture2D.FILL_RADIAL
		tx.fill_from = Vector2(0.5, 0.5)
		tx.fill_to = Vector2(1.0, 0.5)
		tx.width = 64
		tx.height = 64
		return tx

	func _draw() -> void:
		var W := size.x
		var H := size.y
		var n := 24
		for i in n:
			var a := float(i) / float(n)
			draw_rect(Rect2(0, H * a, W, H / float(n) + 1.0), top.lerp(bottom, a))
		if rays:
			var c := Vector2(W * 0.78, H * 0.1)
			for i in 9:
				var ang := -0.3 + float(i) * 0.33
				var d := Vector2(cos(ang + PI * 0.5), sin(ang + PI * 0.5))
				var side := Vector2(-d.y, d.x)
				var L := maxf(W, H) * 1.4
				draw_colored_polygon(PackedVector2Array([c, c + d * L + side * L * 0.07, c + d * L - side * L * 0.07]),
					Color(accent, 0.05 if i % 2 == 0 else 0.025))
		for i in bokeh:
			var s: Vector4 = _seed[i]
			var r := (0.04 + s.z * 0.1) * maxf(W, H)
			var cc := Color(accent.lerp(Color(1, 0.75, 0.4), s.w), 0.08 + s.w * 0.1)
			draw_texture_rect(_blob, Rect2(s.x * W - r, s.y * H - r, r * 2.0, r * 2.0), false, cc)
		for i in mini(stars, _seed.size()):
			var s: Vector4 = _seed[i]
			var x := s.x * W
			if drift:
				x = fposmod(x - t * (8.0 + s.z * 30.0), W)
			var tw := 0.55 + 0.45 * sin(t * (1.0 + s.w * 2.0) + s.z * 9.0)
			var sz := 1.0 + s.z * 2.2
			draw_rect(Rect2(x, s.y * H, sz, sz), Color(1, 1, 1, (0.25 + s.w * 0.6) * tw))
		if ring.size.x > 0.0:
			var c2 := ring.get_center()
			var r2 := ring.size.x * 0.5
			draw_arc(c2, r2, 0, TAU, 96, Color(ring_color, 0.22), 2.0, true)
			draw_arc(c2, r2 * 0.93, 0, TAU, 96, Color(ring_color, 0.1), 1.0, true)
		if hills:
			for layer in 3:
				var pts := PackedVector2Array()
				var base := H * (0.78 + 0.07 * float(layer))
				var amp := H * (0.08 - 0.02 * float(layer))
				pts.append(Vector2(0, H))
				for i in 13:
					var x := W * float(i) / 12.0
					pts.append(Vector2(x, base - amp * (0.5 + 0.5 * sin(float(i) * (1.3 + layer * 0.7) + layer * 2.0))))
				pts.append(Vector2(W, H))
				draw_colored_polygon(pts, bottom.darkened(0.25 + 0.2 * float(layer)).lerp(accent, 0.08))
		if dots:
			var step := 26.0
			var y := step * 0.5
			var row := 0
			while y < H:
				var x := step * (0.25 if row % 2 == 0 else 0.75)
				while x < W:
					draw_rect(Rect2(x - 1.5, y - 1.5, 3.0, 3.0), Color(1, 1, 1, 0.09))
					x += step
				y += step
				row += 1
		if band.size() >= 3:
			draw_colored_polygon(band, band_color)
			draw_line(band[3], band[2], band_color.lightened(0.5), 6.0)
		if bulbs.size.x > 0.0:
			var r := bulbs
			var per := (r.size.x + r.size.y) * 2.0
			var nb := int(per / 26.0)
			var bs := 11.0
			for i in nb:
				var d := per * float(i) / float(nb)
				var p := Vector2()
				if d < r.size.x:
					p = r.position + Vector2(d, 0)
				elif d < r.size.x + r.size.y:
					p = r.position + Vector2(r.size.x, d - r.size.x)
				elif d < r.size.x * 2.0 + r.size.y:
					p = r.end - Vector2(d - r.size.x - r.size.y, 0)
				else:
					p = Vector2(r.position.x, r.end.y - (d - r.size.x * 2.0 - r.size.y))
				var on := (i + int(t * 6.0)) % 3 == 0
				var c := bulb_color if on else bulb_color.darkened(0.55)
				if on:
					draw_texture_rect(_blob, Rect2(p - Vector2(bs, bs) * 1.4, Vector2(bs, bs) * 2.8), false, Color(c, 0.4))
				draw_rect(Rect2(p - Vector2(bs, bs) * 0.35, Vector2(bs, bs) * 0.7), c)
		if bars > 0.0:
			draw_rect(Rect2(0, 0, W, bars), Color.BLACK)
			draw_rect(Rect2(0, H - bars, W, bars), Color.BLACK)


## A hexagon (S1 icons) or a stone slab (S6): drawn under an icon button.
class Frame extends Control:
	var kind := "hex"
	var color := Color.WHITE
	var lit := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		if kind == "hex":
			var r := minf(size.x, size.y) * 0.5 - 2.0
			var pts := PackedVector2Array()
			for i in 7:
				var a := PI / 6.0 + float(i) * TAU / 6.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts.slice(0, 6), Color(color, 0.32 if lit else 0.14))
			draw_polyline(pts, Color(color, 1.0 if lit else 0.75), 2.0, true)
		elif kind in ["round", "tile", "sticker"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = color.darkened(0.25) if kind != "round" else Color(0.03, 0.03, 0.08, 0.85)
			sb.border_color = color if kind == "round" else (Color.WHITE if kind == "sticker" else color.darkened(0.6))
			sb.set_border_width_all(3 if kind != "sticker" else 5)
			sb.set_corner_radius_all(2000 if kind != "tile" else 16)
			sb.shadow_color = Color(color, 0.45) if kind == "round" else Color(0, 0, 0, 0.4)
			sb.shadow_size = 10 if kind == "round" else 4
			sb.shadow_offset = Vector2.ZERO if kind == "round" else Vector2(0, 4)
			sb.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))


## ---------- the Landing ----------

class MenuLanding extends Control:
	const LOGO_BASE := Vector2(240, 170)
	var kit
	var style := ""
	var entries: Array = []
	var title: BigTitle
	var sub_title: Label           # S3: the accent word ("MAIN MENU")
	var tagline: Label
	var back: Backdrop
	var logo: Control
	var caption: Label
	var sel := 0
	var hi := Color.WHITE
	var menu_font: Font
	var _active := false
	var _reduced := false

	func _init(p_kit, p_style: String) -> void:
		kit = p_kit
		style = p_style
		name = "StyleLanding"
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
		hi = kit.cfg.get("menu_color", kit.accent)
		_reduced = _reduced_check()
		_build_backdrop()
		_build_logo()
		_build_title()
		_collect()
		for e in entries:
			_make(e)
		caption = kit.label("", 18, Color(1, 1, 1, 0.85), false, true)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(caption)
		resized.connect(_layout)
		call_deferred("_layout")

	func _reduced_check() -> bool:
		if OS.has_feature("web"):
			return true
		var f := FileAccess.open("user://fx.json", FileAccess.READ)
		if f == null:
			return OS.get_processor_count() <= 4 and OS.has_feature("mobile")
		var d: Variant = JSON.parse_string(f.get_as_text())
		return d is Dictionary and bool(d.get("reduce", false))

	# ----- building -----

	func _build_backdrop() -> void:
		back = Backdrop.new()
		var cols: Array = kit.cfg.get("landing_colors", [Color("0a0d24"), Color("1b1450")])
		back.top = cols[0]
		back.bottom = cols[1]
		back.accent = hi
		back.ring_color = hi
		match style:
			"ghost":
				back.stars = 50
			"ring":
				back.stars = 90
				back.hills = true
			"rail":
				back.bokeh = 18
			"monument":
				back.rays = true
				back.stars = 20
			"slabs":
				back.stars = 40
				back.hills = true
			"cinema":
				back.stars = 140
				back.drift = true
			"split":
				back.stars = 30
			"marquee":
				back.stars = 70
				back.bokeh = 8
			"stickers":
				back.dots = true
		back.stars = int(kit.cfg.get("landing_stars", back.stars))
		add_child(back)
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _build_logo() -> void:
		var cb: Variant = kit.cfg.get("logo", null)
		if not (cb is Callable) or not (cb as Callable).is_valid():
			return
		logo = Control.new()
		logo.name = "LogoArt"
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo.draw.connect((cb as Callable).bind(logo))
		logo.resized.connect(logo.queue_redraw)
		add_child(logo)
		if style == "rail":
			logo.modulate.a = 0.35
		elif style == "ring":
			logo.modulate.a = 0.14      # a watermark inside the ring, under the rows

	func _title_text() -> String:
		var raw: String = str(kit.tr(kit.cfg.get("title", kit.consts.get("TITLE", ""))))
		var t := raw.strip_edges()
		var i := t.find(" ")
		if i > 0 and t.unicode_at(0) > 255:
			t = t.substr(i).strip_edges()
		return t.to_upper()

	func _build_title() -> void:
		title = BigTitle.new()
		title.name = "TitleText"
		title.text = _title_text()
		var f: Font = null
		var path := str(kit.cfg.get("title_font", ""))
		if path != "" and ResourceLoader.exists(path):
			f = load(path)
			for i in title.text.length():
				var cp := title.text.unicode_at(i)
				if cp != 32 and not f.has_char(cp):
					f = null
					break
		title.font = f if f != null else get_theme_default_font()
		menu_font = title.font if bool(kit.cfg.get("menu_font", false)) else get_theme_default_font()
		title.colors = kit.cfg.get("title_colors", [hi.lightened(0.2), Color.WHITE])
		title.outline = kit.cfg.get("title_outline", Color(0.02, 0.02, 0.06))
		title.bob = not _reduced
		title.align = HORIZONTAL_ALIGNMENT_CENTER if style in ["ring", "slabs", "marquee", "stickers"] else HORIZONTAL_ALIGNMENT_LEFT
		add_child(title)
		if style == "rail":
			sub_title = kit.label(str(kit.tr("Menu")).to_upper(), 30, hi, false, false)
			sub_title.add_theme_font_override("font", title.font)
			sub_title.add_theme_color_override("font_outline_color", Color(hi, 0.45))
			sub_title.add_theme_constant_override("outline_size", 10)
			add_child(sub_title)
		var sub_text: String = str(kit.cfg.get("subtitle", kit.consts.get("GOAL", "")))
		tagline = kit.label(str(kit.tr(sub_text)), 20, Color(1, 1, 1, 0.82), true, style in ["ring", "slabs", "marquee", "stickers"])
		tagline.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		tagline.add_theme_constant_override("outline_size", 6)
		tagline.visible = sub_text != "" and style != "cinema"
		add_child(tagline)

	func _add(kind: String, glyph: String, nm: String, cb: Callable) -> void:
		entries.append({"kind": kind, "glyph": glyph, "nm": nm, "cb": cb, "shown": kind != "resume" and kind != "quick"})

	static func split_glyph(text: String) -> Array:
		var t := text.strip_edges()
		var i := t.find(" ")
		if i > 0 and t.unicode_at(0) > 255:
			return [t.substr(0, i), t.substr(i).strip_edges()]
		return ["", t]

	func _collect() -> void:
		_add("resume", "▶", str(kit.tr("Resume")), Callable(kit, "_on_resume"))
		_add("quick", "⚡", str(kit.tr("Quick Play")), Callable(kit, "_on_quick"))
		for p in kit.cfg.get("play", []):
			var pp: Array = split_glyph(str(kit.tr(str(p.get("text", "")))))
			_add("main", pp[0], pp[1], Callable(kit, "_on_play_item").bind(p))
		var solo: Array = kit._solo
		# A few solo ways to play: one row each (one tap, N6); more, or with pickers: one group row.
		if not solo.is_empty() and solo.size() <= 3 and not kit.cfg.has("extra"):
			for m in solo:
				var mp: Array = split_glyph(str(kit.tr(str(m.get("text", "")))))
				_add("main", mp[0], mp[1], Callable(kit, "_on_mode").bind(m))
		elif not solo.is_empty():
			_add("main", "🎮", str(kit.tr("Single player")), Callable(kit, "_on_group").bind(false))
		if not kit._multi.is_empty():
			_add("main", "👥", str(kit.tr("Multiplayer")), Callable(kit, "_on_group").bind(true))
		for it in kit.cfg.get("more", []):
			var mp2: Array = split_glyph(str(kit.tr(str(it[0]))))
			_add("main", mp2[0], mp2[1], it[2])
		var utils: Array = [[kit.tr("❓ How to Play"), Callable(kit, "_show_overlay").bind(null, "info")]]
		if kit._board_key() != "none":
			utils.append([kit.tr("🏆 Leaderboard"), Callable(kit, "_show_leaderboard")])
		if kit.info and kit.info.has_method("achievement_rows"):
			utils.append([kit.tr("🏅 Achievements"), Callable(kit, "_show_achievements")])
		utils.append([kit.tr("📊 Statistics"), Callable(kit, "_show_stats")])
		utils.append([kit.tr("⚙ Options"), Callable(kit, "_show_options")])
		for u in utils:
			var up: Array = split_glyph(str(u[0]))
			_add("util", up[0], up[1], u[1])
		_add("hub", "←", str(kit.tr("Hub")), Callable(kit, "_on_hub_pressed"))

	## Does this style show the utilities as icons (else as text rows)?
	func _util_icons() -> bool:
		return style in ["ghost", "ring", "monument", "slabs", "split", "marquee", "bento", "stickers"]

	func _make(e: Dictionary) -> void:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.flat = false               # flat buttons skip their stylebox; the boxes below are empty or drawn
		b.clip_text = true
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.tooltip_text = str(e.nm)
		b.pressed.connect(e.cb)
		var icon: bool = (e.kind == "util" and _util_icons()) or (e.kind == "hub" and style in ["ghost", "monument", "split", "marquee", "bento"])
		e["icon"] = icon
		if icon:
			var fr := Frame.new()
			fr.kind = {"ghost": "hex", "marquee": "round", "bento": "tile", "stickers": "sticker", "split": "tile"}.get(style, "none")
			fr.color = hi
			b.add_child(fr)
			fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			e["frame"] = fr
			b.text = str(e.glyph) + " " + str(e.nm)    # real text for tests and screen readers
			b.add_theme_font_size_override("font_size", 1)
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(c, Color(0, 0, 0, 0))
			var g: Label = kit.label(str(e.glyph), 28, Color.WHITE, false, true)
			g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(g)
			g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			e["glyph_l"] = g
			b.mouse_entered.connect(_show_caption.bind(str(e.nm)))
			b.mouse_exited.connect(_show_caption.bind(""))
			b.button_down.connect(_show_caption.bind(str(e.nm)))
		else:
			var label := str(e.nm)
			if e.kind == "hub":
				label = "← " + label
			elif style in ["slabs", "ghost", "rail", "split", "marquee", "bento", "stickers"] and str(e.glyph) != "":
				label = str(e.glyph) + "  " + label
			if style in ["rail", "cinema", "ghost", "ring", "split", "marquee"]:
				label = label.to_upper()
			b.text = label
			b.add_theme_font_override("font", menu_font)
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER if style in ["ring", "slabs", "marquee", "stickers"] else HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			b.add_theme_constant_override("outline_size", 6 if style != "slabs" else 8)
		b.mouse_entered.connect(_on_hover.bind(e))
		add_child(b)
		e["btn"] = b

	func _show_caption(text: String) -> void:
		caption.text = text

	func _on_hover(e: Dictionary) -> void:
		var i := entries.find(e)
		if i != sel and not e.icon:
			sel = i
			_paint()
			if style == "ring":
				_layout()

	# ----- the look of each row (the highlighted one differs) -----

	func _box(fill: Color, border: Color, bw: int, radius: int, glow: float = 0.0) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = border
		sb.set_border_width_all(bw)
		sb.set_corner_radius_all(radius)
		sb.shadow_color = Color(border, glow)
		sb.shadow_size = int(glow * 24.0)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		return sb

	func _paint() -> void:
		var first_row := _first_row()
		if sel < 0 or sel >= entries.size() or not entries[sel].shown or entries[sel].icon:
			sel = first_row
		for i in entries.size():
			var e: Dictionary = entries[i]
			var b: Button = e.btn
			if e.icon:
				continue
			var on := i == sel
			var col := Color.WHITE
			var normal: StyleBox = StyleBoxEmpty.new()
			match style:
				"ghost":
					col = hi.lightened(0.35) if on else Color(1, 1, 1, 0.9)
					b.add_theme_color_override("font_outline_color", Color(hi, 0.6) if on else Color(0, 0, 0, 0.85))
				"ring":
					col = Color("ffd25e") if on else Color(1, 1, 1, 0.85)
				"rail":
					col = Color.WHITE
					if on:
						normal = _box(Color(0.04, 0.02, 0.02, 0.55), hi, 2, 6, 0.55)
				"monument":
					col = Color.WHITE if on else Color(0.72, 0.72, 0.72, 0.85)
				"slabs":
					var base: Color = e.get("slab", hi)
					normal = _slab(base, false)
					b.add_theme_stylebox_override("pressed", _slab(base, true))
					b.add_theme_stylebox_override("hover", _slab(base.lightened(0.08), false))
				"cinema":
					col = hi.lightened(0.3) if on else Color(1, 1, 1, 0.88)
			var tint: Color = e.get("tint", hi)
			match style:
				"split":
					normal = _box(tint.darkened(0.3), Color.WHITE if on else tint.lightened(0.3), 3, 4, 0.4 if on else 0.0)
					(normal as StyleBoxFlat).skew = Vector2(0.28, 0)
					(normal as StyleBoxFlat).content_margin_left = 30
				"marquee":
					normal = _box(Color(tint, 0.85) if on else Color(0.03, 0.02, 0.08, 0.8), tint, 3, 2000, 0.6)
				"bento":
					normal = _box(tint.darkened(0.2), tint.lightened(0.25) if on else tint.darkened(0.5), 3, 22, 0.0)
					(normal as StyleBoxFlat).shadow_color = Color(0, 0, 0, 0.35)
					(normal as StyleBoxFlat).shadow_size = 6
					(normal as StyleBoxFlat).shadow_offset = Vector2(0, 5)
				"stickers":
					normal = _box(tint, Color.WHITE, 6, 26, 0.0)
					(normal as StyleBoxFlat).shadow_color = Color(0, 0, 0, 0.45)
					(normal as StyleBoxFlat).shadow_size = 3
					(normal as StyleBoxFlat).shadow_offset = Vector2(4, 6)
			if style in ["split", "marquee", "bento", "stickers"]:
				col = Color.WHITE
				# a light tile (white, pale grey) gets dark text
				if style != "marquee" and tint.get_luminance() > 0.62:
					col = Color(0.08, 0.08, 0.12)
					b.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.5))
			elif e.kind == "resume" and style != "slabs":
				col = kit.GO if not on else kit.GO.lightened(0.3)
			b.add_theme_stylebox_override("normal", normal)
			if style != "slabs":
				b.add_theme_stylebox_override("hover", normal)
				var dn: StyleBox = normal.duplicate()
				if dn is StyleBoxFlat:
					(dn as StyleBoxFlat).bg_color = (dn as StyleBoxFlat).bg_color.lightened(0.15)
				b.add_theme_stylebox_override("pressed", dn)
			b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			for c in ["font_color", "font_hover_color", "font_focus_color"]:
				b.add_theme_color_override(c, col)
			b.add_theme_color_override("font_pressed_color", col.lightened(0.3))
			b.add_theme_color_override("font_hover_pressed_color", col.lightened(0.3))

	## S6: a chunky stone slab: bevel (light top, dark bottom), dark outline.
	func _slab(c: Color, down: bool) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c.darkened(0.15) if down else c
		sb.border_color = c.darkened(0.55)
		sb.set_border_width_all(4)
		sb.border_width_bottom = 4 if down else 10
		sb.set_corner_radius_all(18)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 2 if down else 8
		sb.shadow_offset = Vector2(0, 2 if down else 6)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		return sb

	func _first_row() -> int:
		for i in entries.size():
			if entries[i].shown and not entries[i].icon and entries[i].kind != "hub":
				return i
		return 0

	# ----- the kit's hooks -----

	func refresh() -> void:
		for e in entries:
			if e.kind == "resume":
				e["shown"] = kit.resume_btn.visible
			elif e.kind == "quick":
				e["shown"] = kit.quick_btn.visible
		sel = _first_row()
		_paint()
		_layout()

	func set_active(on: bool) -> void:
		_active = on
		set_process(on and not _reduced)
		if on:
			_layout()
			_intro()

	func _process(delta: float) -> void:
		title.t += delta
		title.queue_redraw()
		if back.drift or back.stars > 0:
			back.t += delta
			back.queue_redraw()
		if logo and style in ["cinema", "monument", "slabs"]:
			logo.position.y = logo.get_meta("y", logo.position.y) + sin(title.t * 0.8) * 6.0

	func _intro() -> void:
		var i := 0
		for e in entries:
			if not e.shown:
				continue
			var b: Button = e.btn
			b.modulate.a = 0.0
			var tw := b.create_tween()
			tw.tween_interval(0.04 + 0.05 * float(i))
			tw.tween_property(b, "modulate:a", 1.0, 0.25)
			i += 1
		title.modulate.a = 0.0
		title.create_tween().tween_property(title, "modulate:a", 1.0, 0.4)

	# ----- layout -----

	func _put(b: Control, r: Rect2) -> void:
		b.position = r.position
		b.size = r.size
		b.custom_minimum_size = Vector2.ZERO

	func _put_logo(r: Rect2) -> void:
		if logo == null:
			return
		logo.visible = r.size.x > 40.0 and r.size.y > 40.0
		# A game's logo drawing caps its own size (it was made for a small slot), so it is drawn at a
		# fixed size and scaled up to fill the rect.
		var base := LOGO_BASE
		var k := minf(r.size.x / base.x, r.size.y / base.y)
		logo.size = base
		logo.scale = Vector2(k, k)
		logo.position = r.position + (r.size - base * k) * 0.5
		logo.set_meta("y", logo.position.y)

	func _of(kinds: Array) -> Array:
		return entries.filter(func(e): return e.kind in kinds and e.shown)

	## Text rows down from y: returns the bottom. `fs` font size, `pitch` row height (>= 48 hit area).
	func _rows(list: Array, x: float, y: float, w: float, pitch: float, fs: int) -> float:
		for e in list:
			var b: Button = e.btn
			b.add_theme_font_size_override("font_size", fs)
			_put(b, Rect2(x, y, w, maxf(pitch - 4.0, 48.0)))
			y += pitch
		return y

	## Icon buttons in a row starting at x (centred when `center`).
	func _icons(list: Array, x: float, y: float, s: float, gap: float) -> void:
		for e in list:
			var b: Button = e.btn
			_put(b, Rect2(x, y, s, s))
			(e.glyph_l as Label).add_theme_font_size_override("font_size", int(s * 0.44))
			x += s + gap

	func _layout() -> void:
		if not is_inside_tree() or size.x < 40.0 or size.y < 40.0:
			return
		var W := size.x
		var H := size.y
		var wide := W > H * 1.1
		for e in entries:
			(e.btn as Button).visible = e.shown
		back.ring = Rect2()
		back.bars = 0.0
		back.band = PackedVector2Array()
		back.bulbs = Rect2()
		call("_lay_" + style, W, H, wide)
		_paint()
		back.queue_redraw()

	func _place_title(r: Rect2) -> float:
		title.position = r.position
		title.size = r.size
		title._fit()
		return r.position.y + title.used_height()

	func _place_tagline(x: float, y: float, w: float, fs: int) -> float:
		if not tagline.visible:
			return y
		tagline.add_theme_font_size_override("font_size", fs)
		tagline.position = Vector2(x, y)
		tagline.size = Vector2(w, 0)
		return y + tagline.get_combined_minimum_size().y

	## S1 Corner Ghost
	func _lay_ghost(W: float, H: float, wide: bool) -> void:
		var pad := 22.0
		var mains := _of(["resume", "quick", "main"])
		var utils := _of(["util", "hub"])
		var s := clampf(minf(W, H) * 0.1, 52.0, 76.0)
		var gap := 8.0
		var util_w := float(utils.size()) * (s + gap) - gap
		var tw := W * 0.48 if wide else W - pad * 2.0
		var ty := pad + (0.0 if wide else s + 26.0)
		var bottom := _place_title(Rect2(pad + 6.0, ty, tw, H * (0.24 if wide else 0.17)))
		bottom = _place_tagline(pad + 8.0, bottom + 4.0, tw, 18 if wide else 20)
		var pitch := clampf((H - bottom - pad - 20.0) / float(maxi(1, mains.size())), 48.0, H * 0.09)
		var fs := int(clampf(pitch * 0.42, 18.0, 30.0))
		var end := _rows(mains, pad + 10.0, bottom + 18.0, tw, pitch, fs)
		# T2 + ← Hub: hexagons top-right
		_icons(utils, W - pad - util_w, pad, s, gap)
		caption.position = Vector2(W - pad - util_w, pad + s + 2.0)
		caption.size = Vector2(util_w, 24.0)
		if wide:
			_put_logo(Rect2(W * 0.52, H * 0.22, W * 0.44, H * 0.7))
			back.ring = Rect2(W * 0.74 - H * 0.36, H * 0.57 - H * 0.36, H * 0.72, H * 0.72)
		else:
			var lh := H - end - pad
			_put_logo(Rect2(W * 0.2, end + 6.0, W * 0.6, lh))
			if lh > 80.0:
				back.ring = Rect2(W * 0.5 - lh * 0.5, end + 6.0, lh, lh)

	## S2 Center Ring
	func _lay_ring(W: float, H: float, wide: bool) -> void:
		var pad := 20.0
		var mains := _of(["resume", "quick", "main"])
		var utils := _of(["util"])
		var hub: Array = _of(["hub"])
		var tw := minf(W - pad * 2.0, 760.0)
		var bottom := _place_title(Rect2((W - tw) * 0.5, H * 0.04, tw, H * (0.2 if wide else 0.15)))
		bottom = _place_tagline((W - tw) * 0.5, bottom, tw, 18 if wide else 20)
		var s := clampf(minf(W, H) * 0.085, 48.0, 64.0)
		var foot := H - pad - s - 28.0
		var top := bottom + 14.0
		var pitch := clampf((foot - top) / (float(maxi(1, mains.size())) + 0.6), 48.0, H * 0.1)
		var fs := int(clampf(pitch * 0.4, 18.0, 30.0))
		var y := top
		var rw := minf(W * 0.8, 520.0)
		for i in mains.size():
			var e: Dictionary = mains[i]
			var on: bool = entries.find(e) == sel
			var b: Button = e.btn
			var p := pitch * (1.3 if on else 1.0)
			b.add_theme_font_size_override("font_size", int(fs * (1.3 if on else 0.9)))
			_put(b, Rect2((W - rw) * 0.5, y, rw, maxf(p - 4.0, 48.0)))
			y += p
		var mid := (top + y) * 0.5
		var d := minf(minf(W * 0.92, (y - top) * 1.35), H * 0.8)
		back.ring = Rect2(W * 0.5 - d * 0.5, mid - d * 0.5, d, d)
		_put_logo(Rect2(W * 0.5 - d * 0.3, mid - d * 0.3, d * 0.6, d * 0.6))
		var util_w := float(utils.size()) * (s + 10.0) - 10.0
		_icons(utils, (W - util_w) * 0.5, H - pad - s - 22.0, s, 10.0)
		caption.position = Vector2(0, H - pad - 22.0)
		caption.size = Vector2(W, 22.0)
		for e in hub:
			(e.btn as Button).add_theme_font_size_override("font_size", 18)
			_put(e.btn, Rect2(pad * 0.5, pad * 0.5, 110.0, 48.0))

	## S3 Rail List
	func _lay_rail(W: float, H: float, wide: bool) -> void:
		var pad := 22.0
		var rows := _of(["resume", "quick", "main", "util", "hub"])
		var tw := W * 0.5 if wide else W - pad * 2.0
		var bottom := _place_title(Rect2(pad, pad, tw, H * (0.16 if wide else 0.12)))
		var sfs := int(clampf(H * 0.035, 18.0, 34.0))
		sub_title.add_theme_font_size_override("font_size", sfs)
		sub_title.position = Vector2(pad + 4.0, bottom)
		sub_title.size = Vector2(tw, 0)
		bottom += sub_title.get_combined_minimum_size().y
		tagline.visible = false
		var pitch := clampf((H - bottom - pad - 10.0) / float(maxi(1, rows.size())), 48.0, H * 0.085)
		var fs := int(clampf(pitch * 0.4, 16.0, 26.0))
		var rw := W * 0.38 if wide else minf(W - pad * 2.0, 480.0)
		_rows(rows, pad, bottom + 12.0, rw, pitch, fs)
		if wide:
			_put_logo(Rect2(W * 0.46, H * 0.1, W * 0.52, H * 0.85))
		else:
			_put_logo(Rect2(W * 0.4, H * 0.45, W * 0.6, H * 0.5))

	## S4 Monument
	func _lay_monument(W: float, H: float, wide: bool) -> void:
		var pad := 22.0
		var mains := _of(["resume", "quick", "main"])
		var utils := _of(["util", "hub"])
		var tw := W * 0.52 if wide else W - pad * 2.0
		var bottom := _place_title(Rect2(pad, pad, tw, H * (0.34 if wide else 0.22)))
		bottom = _place_tagline(pad + 4.0, bottom, tw, 18)
		var s := clampf(minf(W, H) * 0.075, 48.0, 60.0)
		var pitch := clampf(H * 0.075, 52.0, 72.0)
		var fs := int(clampf(pitch * 0.46, 22.0, 32.0))
		var bw := minf(tw * 0.7, 340.0)
		var cx := pad + tw * 0.5
		var end := _rows(mains, cx - bw * 0.5, bottom + 14.0, bw, pitch, fs)
		for e in mains:
			(e.btn as Button).alignment = HORIZONTAL_ALIGNMENT_CENTER
		_icons(utils, pad, H - pad - s, s, 6.0)
		caption.position = Vector2(pad, H - pad - s - 26.0)
		caption.size = Vector2(W * 0.5, 22.0)
		if wide:
			_put_logo(Rect2(W * 0.5, H * 0.14, W * 0.46, H * 0.86))
		else:
			_put_logo(Rect2(W * 0.05, end + 4.0, W * 0.9, H - end - s - pad * 2.0))

	## S6 Stone Slabs
	func _lay_slabs(W: float, H: float, wide: bool) -> void:
		var pad := 18.0
		var mains := _of(["resume", "quick", "main"])
		var utils := _of(["util"])
		var hub: Array = _of(["hub"])
		var s := clampf(minf(W, H) * 0.09, 48.0, 64.0)
		_icons(utils, pad, pad, s, 6.0)
		caption.position = Vector2(pad, pad + s)
		caption.size = Vector2(float(utils.size()) * (s + 6.0), 22.0)
		var top := pad + s + 22.0
		var bottom := _place_title(Rect2(pad, top, W - pad * 2.0, H * (0.22 if wide else 0.17)))
		bottom = _place_tagline(pad, bottom, W - pad * 2.0, 18 if wide else 20)
		var hub_h := 56.0
		var avail := H - bottom - pad - hub_h - 24.0
		var n := maxi(1, mains.size())
		var gap := clampf(avail * 0.04, 8.0, 18.0)
		var sh := clampf((avail - gap * float(n)) / float(n), 52.0, 96.0)
		var base_w := minf(W * (0.4 if wide else 0.78), 460.0)
		var fs := int(clampf(sh * 0.36, 18.0, 34.0))
		var used := float(mini(n, mains.size())) * (sh + gap) - gap
		var y := bottom + 16.0 + maxf(0.0, (avail - used) * 0.4)
		var palette: Array = kit.cfg.get("title_colors", [hi])
		for i in n:
			if i >= mains.size():
				break
			var e: Dictionary = mains[i]
			var w := base_w * (1.0 - 0.07 * float(mini(i, 4)))
			e["slab"] = kit.GO.darkened(0.25) if e.kind == "resume" else (palette[i % palette.size()] as Color).darkened(0.35)
			var b: Button = e.btn
			b.add_theme_font_size_override("font_size", fs)
			_put(b, Rect2((W - w) * 0.5, y, w, sh))
			y += sh + gap
		for e in hub:
			(e.btn as Button).add_theme_font_size_override("font_size", 18)
			e["slab"] = Color("5a5f6e")
			_put(e.btn, Rect2(pad, H - pad - hub_h, minf(150.0, W * 0.34), hub_h))
		var ms := minf(W * 0.3, H * 0.24)
		_put_logo(Rect2(W - pad - ms, H - pad - ms, ms, ms))

	## S7 Diegetic Cinema
	func _lay_cinema(W: float, H: float, wide: bool) -> void:
		var bar := H * (0.11 if wide else 0.06)
		back.bars = bar
		var ph := H - bar * 2.0
		var rows := _of(["resume", "quick", "main", "util", "hub"])
		var x := W * 0.06
		var pitch := clampf(ph * 0.06, 48.0, 54.0)
		var fs := int(clampf(pitch * 0.34, 15.0, 20.0))
		var list_h := pitch * float(rows.size())
		var tw := W * 0.5 if wide else W * 0.88
		var th := clampf(ph - list_h - 24.0, 60.0, ph * (0.3 if wide else 0.2))
		var ty := bar + ph - list_h - th - 12.0
		ty = maxf(ty, bar + 8.0)
		var bottom := _place_title(Rect2(x + W * 0.04, ty, tw, th))
		_rows(rows, x, bottom + 8.0, W * (0.36 if wide else 0.7), pitch, fs)
		if wide:
			_put_logo(Rect2(W * 0.5, bar + ph * 0.08, W * 0.46, ph * 0.84))
		else:
			_put_logo(Rect2(W * 0.18, bar + 10.0, W * 0.64, maxf(0.0, ty - bar - 20.0)))


	## The colour of item i: the title palette, Resume always green.
	func _tint(e: Dictionary, i: int) -> Color:
		var pal: Array = kit.cfg.get("title_colors", [hi])
		var c: Color = kit.GO.darkened(0.2) if e.kind == "resume" else pal[i % pal.size()]
		e["tint"] = c
		return c

	func _tint_icons(list: Array) -> void:
		for i in list.size():
			var e: Dictionary = list[i]
			var c := _tint(e, i + 1)
			if e.has("frame"):
				(e.frame as Frame).color = c
				(e.frame as Frame).queue_redraw()

	## S8 Diagonal Split
	func _lay_split(W: float, H: float, wide: bool) -> void:
		var pad := 22.0
		var mains := _of(["resume", "quick", "main"])
		var utils := _of(["util", "hub"])
		_tint_icons(utils)
		var band_h := H * (0.4 if wide else 0.28)
		var slope := H * 0.07
		var bc: Color = (kit.cfg.get("title_colors", [hi]) as Array)[0]
		back.band = PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, band_h - slope), Vector2(0, band_h + slope)])
		back.band_color = Color(bc.darkened(0.6), 0.95)
		var tw := W * (0.62 if wide else 1.0) - pad * 2.0
		var bottom := _place_title(Rect2(pad, pad, tw, band_h * 0.6))
		_place_tagline(pad, bottom, tw, 18 if wide else 19)
		var s := clampf(minf(W, H) * 0.085, 48.0, 62.0)
		var top := band_h + slope + 18.0
		var foot := H - pad - s - 34.0
		var pitch := clampf((foot - top) / float(maxi(1, mains.size())), 58.0, 96.0)
		var fs := int(clampf(pitch * 0.34, 18.0, 30.0))
		var bw := minf(W * (0.46 if wide else 0.8), 520.0)
		var y := top
		for i in mains.size():
			var e: Dictionary = mains[i]
			_tint(e, i)
			var b: Button = e.btn
			b.add_theme_font_size_override("font_size", fs)
			# each tab steps left a little, following the slant
			_put(b, Rect2(W - pad - bw - float(i) * pad * 0.7, y, bw, pitch - 12.0))
			y += pitch
		_icons(utils, pad, H - pad - s, s, 8.0)
		caption.position = Vector2(pad, H - pad - s - 26.0)
		caption.size = Vector2(W * 0.6, 22.0)
		if wide:
			_put_logo(Rect2(W * 0.03, top, W * 0.4, foot - top))
		else:
			_put_logo(Rect2())

	## S9 Arcade Marquee
	func _lay_marquee(W: float, H: float, wide: bool) -> void:
		var pad := 22.0
		var mains := _of(["resume", "quick", "main"])
		var utils := _of(["util", "hub"])
		_tint_icons(utils)
		var sw := minf(W - pad * 2.0, 760.0)
		var sh := H * (0.24 if wide else 0.17)
		var sign := Rect2((W - sw) * 0.5, pad + 6.0, sw, sh)
		back.bulbs = sign
		back.bulb_color = Color("ffe9a0")
		_place_title(sign.grow(-24.0))
		title.position.y = sign.position.y + (sign.size.y - title.used_height()) * 0.5
		var y0 := _place_tagline(pad, sign.end.y + 12.0, W - pad * 2.0, 18 if wide else 20)
		var s := clampf(minf(W, H) * 0.095, 50.0, 70.0)
		var foot := H - pad - s - 34.0
		var cols := 2 if (wide or mains.size() > 4) and mains.size() > 1 else 1
		var rows := ceili(float(mains.size()) / float(cols))
		var gap := 14.0
		var bh := clampf((foot - y0 - 14.0 - gap * float(rows)) / float(maxi(1, rows)), 54.0, 84.0)
		var bw := minf((W - pad * 2.0 - gap * float(cols - 1)) / float(cols), 360.0 if cols == 2 else 460.0)
		var total_w := bw * float(cols) + gap * float(cols - 1)
		var total_h := bh * float(rows) + gap * float(rows - 1)
		var top := y0 + maxf(14.0, (foot - y0 - total_h) * 0.45)
		var fs := int(clampf(bh * 0.32, 18.0, 28.0))
		for i in mains.size():
			var e: Dictionary = mains[i]
			_tint(e, i)
			var b: Button = e.btn
			b.add_theme_font_size_override("font_size", fs)
			_put(b, Rect2((W - total_w) * 0.5 + float(i % cols) * (bw + gap), top + float(i / cols) * (bh + gap), bw, bh))
		var uw := float(utils.size()) * (s + 12.0) - 12.0
		_icons(utils, (W - uw) * 0.5, H - pad - s, s, 12.0)
		caption.position = Vector2(0, H - pad - s - 26.0)
		caption.size = Vector2(W, 22.0)
		var ls := minf(W, H) * 0.24
		var free_top := top + total_h + 10.0
		if foot - free_top > ls * 0.6:
			_put_logo(Rect2((W - ls * 1.4) * 0.5, free_top, ls * 1.4, foot - free_top))
		else:
			_put_logo(Rect2())

	## S10 Bento Grid
	func _lay_bento(W: float, H: float, wide: bool) -> void:
		var pad := 18.0
		var gap := 12.0
		var mains := _of(["resume", "quick", "main"])
		var utils := _of(["util", "hub"])
		_tint_icons(utils)
		var tw := W * (0.46 if wide else 1.0) - pad * 2.0
		var bottom := _place_title(Rect2(pad, pad, tw, H * (0.24 if wide else 0.14)))
		bottom = _place_tagline(pad, bottom, tw, 18 if wide else 19)
		var area: Rect2
		if wide:
			area = Rect2(W * 0.48, pad, W * 0.52 - pad, H - pad * 2.0)
			_put_logo(Rect2(pad, bottom + 10.0, W * 0.42, H - bottom - pad - 10.0))
		else:
			area = Rect2(pad, bottom + 14.0, W - pad * 2.0, H - bottom - pad - 14.0)
			_put_logo(Rect2())
		# the first tile spans the width and is taller; the rest two per row; then one row of small tiles
		var n := mains.size()
		var main_rows := 1 + ceili(float(maxi(0, n - 1)) / 2.0)
		var urow := clampf(area.size.y * 0.13, 52.0, 76.0)
		var unit := clampf((area.size.y - urow - 24.0 - gap * float(main_rows)) / (float(main_rows) + 0.6), 52.0, 170.0)
		var y := area.position.y
		var cw := (area.size.x - gap) * 0.5
		for i in n:
			var e: Dictionary = mains[i]
			_tint(e, i)
			var b: Button = e.btn
			var r: Rect2
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			if i == 0:
				r = Rect2(area.position.x, y, area.size.x, unit * 1.6)
				y += unit * 1.6 + gap
				b.add_theme_font_size_override("font_size", int(clampf(unit * 0.4, 22.0, 44.0)))
			else:
				var c := (i - 1) % 2
				var alone := c == 0 and i == n - 1
				r = Rect2(area.position.x + float(c) * (cw + gap), y, area.size.x if alone else cw, unit)
				if c == 1 or alone:
					y += unit + gap
				b.add_theme_font_size_override("font_size", int(clampf(unit * 0.28, 16.0, 26.0)))
			_put(b, r)
		var uc := utils.size()
		var us := minf((area.size.x - gap * float(uc - 1)) / float(maxi(1, uc)), urow)
		var uw := us * float(uc) + gap * float(uc - 1)
		var uy := area.end.y - us
		if not wide and uy - y > 110.0:
			_put_logo(Rect2(area.position.x, y + 6.0, area.size.x, uy - y - 40.0))   # the art fills the gap
		_icons(utils, area.position.x + (area.size.x - uw) * 0.5, uy, us, gap)
		caption.position = Vector2(area.position.x, uy - 24.0)
		caption.size = Vector2(area.size.x, 22.0)

	## S11 Sticker Board
	func _lay_stickers(W: float, H: float, wide: bool) -> void:
		var pad := 22.0
		var mains := _of(["resume", "quick", "main", "hub"])
		var utils := _of(["util"])
		_tint_icons(utils)
		var tw := W - pad * 2.0
		var bottom := _place_title(Rect2(pad, pad + 4.0, tw, H * (0.22 if wide else 0.16)))
		title.pivot_offset = title.size * 0.5
		title.rotation = deg_to_rad(-3.0)
		bottom = _place_tagline(pad, bottom + 8.0, tw, 18 if wide else 20)
		var s := clampf(minf(W, H) * 0.1, 52.0, 72.0)
		var foot := H - pad - s - 34.0
		var n := mains.size()
		var cols := 2 if wide and n > 2 else 1
		var rows := ceili(float(n) / float(cols))
		var gap := 18.0
		var bh := clampf((foot - bottom - 20.0 - gap * float(rows)) / float(maxi(1, rows)), 54.0, 90.0)
		var bw := minf(W * (0.34 if cols == 2 else 0.72), 440.0)
		var total_h := bh * float(rows) + gap * float(rows - 1)
		var top := bottom + 20.0 + maxf(0.0, (foot - bottom - 20.0 - total_h) * 0.4)
		var fs := int(clampf(bh * 0.34, 18.0, 30.0))
		for i in n:
			var e: Dictionary = mains[i]
			var b: Button = e.btn
			if e.kind == "hub":
				e["tint"] = Color("5a5f6e")
			else:
				_tint(e, i)
			b.add_theme_font_size_override("font_size", fs if e.kind != "hub" else int(fs * 0.75))
			var col := i % cols
			var row := i / cols
			var w := bw * (0.6 if e.kind == "hub" else 1.0)
			var cx := W * 0.5 + (float(col) - float(cols - 1) * 0.5) * (bw + gap * 2.0) + sin(float(i) * 2.3) * W * 0.03
			var r := Rect2(cx - w * 0.5, top + float(row) * (bh + gap), w, bh)
			_put(b, r)
			b.pivot_offset = r.size * 0.5
			b.rotation = deg_to_rad(-4.0 if i % 2 == 0 else 3.5)
		var uw := float(utils.size()) * (s + 12.0) - 12.0
		_icons(utils, (W - uw) * 0.5, H - pad - s, s, 12.0)
		for i in utils.size():
			var ub: Button = utils[i].btn
			ub.pivot_offset = Vector2(s, s) * 0.5
			ub.rotation = deg_to_rad(6.0 if i % 2 == 0 else -6.0)
		caption.position = Vector2(0, H - pad - s - 26.0)
		caption.size = Vector2(W, 22.0)
		var ls := minf(W, H) * 0.22
		if wide:
			_put_logo(Rect2(W - pad - ls * 1.2, H * 0.42, ls * 1.2, ls * 1.2))
		else:
			_put_logo(Rect2(W - pad - ls, minf(top + total_h + 4.0, foot - ls), ls, ls))
