extends RefCounted

## The Runner's small UI kit: the two looks (Classic = cockpit steel and cyan, Voodoo = neon magenta
## and lime on near-black), panels, buttons, labels, number formatting and the engine's messages
## turned into translated text. Every screen of the game builds from these.

const D = preload("res://scripts/games/the_runner/the_runner_data.gd")
const S = preload("res://scripts/games/the_runner/the_runner_spiral.gd")

const LOOKS := {
	"classic": {"panel": Color(0.03, 0.06, 0.11, 0.86), "edge": Color("4fc3ff"), "text": Color(0.93, 0.96, 1.0),
		"dim": Color(0.62, 0.70, 0.80), "accent": Color("4fc3ff"), "go": Color("38e08a"), "warn": Color("ffb547"),
		"bad": Color("ff5a5a"), "clean": Color("8fe3ff"), "dirty": Color("ffcf5a"), "shade": Color(0, 0, 0, 0.45)},
	"voodoo": {"panel": Color(0.05, 0.01, 0.07, 0.88), "edge": Color("ff2bd6"), "text": Color(1.0, 0.94, 1.0),
		"dim": Color(0.72, 0.62, 0.78), "accent": Color("ff2bd6"), "go": Color("7dff3a"), "warn": Color("ffae2b"),
		"bad": Color("ff4f6a"), "clean": Color("7dfff0"), "dirty": Color("d6ff3a"), "shade": Color(0, 0, 0, 0.55)},
}

static var look: Dictionary = LOOKS["classic"]
static var skin := "classic"

static func set_skin(name: String) -> void:
	skin = name if LOOKS.has(name) else "classic"
	look = LOOKS[skin]

static func c(key: String) -> Color:
	return look.get(key, Color.WHITE)

static func panel_box(alpha: float = 1.0, radius: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c("panel"), c("panel").a * alpha)
	sb.border_color = Color(c("edge"), 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func panel(alpha: float = 1.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(alpha))
	return p

static func btn_box(color: Color, state: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var on := state == "pressed" or state == "hover"
	sb.bg_color = Color(color, 0.32 if on else (0.04 if state == "disabled" else 0.16))
	sb.border_color = Color(color, 0.3 if state == "disabled" else 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

## `wrap`: long text wraps (give the button a minimum width then); off, the button is as wide as its text.
static func button(text: String, cb: Callable, color: Color = Color(0, 0, 0, 0), size: int = 22, height: float = 52, wrap: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", size)
	if wrap:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style(b, color if color.a > 0 else c("accent"))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

static func style(b: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, btn_box(color, state))
	b.add_theme_color_override("font_color", c("text"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", c("text"))
	b.add_theme_color_override("font_disabled_color", Color(c("dim"), 0.55))

static func label(text: String, size: int = 22, color: Color = Color(0, 0, 0, 0), wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color if color.a > 0 else c("text"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

static func art(id: String) -> Texture2D:
	var path: String = D.ART + id + ".webp"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

## A picture that covers its rect (cropped, never stretched).
static func backdrop(id: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = art(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## 12345 -> "12,345" (the separator is a comma in English, a point in Spanish).
static func num(n: int) -> String:
	var neg := n < 0
	var s := str(absi(n))
	var sep := "." if TranslationServer.get_locale().begins_with("es") else ","
	var out := ""
	while s.length() > 3:
		out = sep + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out

static func clean_txt(n: int) -> String:
	return "¢ " + num(n)

static func dirty_txt(n: int) -> String:
	return "◆ " + num(n)

static func tr_s(s: String) -> String:
	return str(TranslationServer.translate(s))

## An engine message (a String, or {"text", "args"}) as translated text. String arguments are names
## (goods, worlds) and are translated too; numbers get thousands separators.
static func msg(m: Variant) -> String:
	if m is String:
		return tr_s(m)
	if m is Dictionary and m.is_empty():
		return ""
	if not (m is Dictionary) or not m.has("text"):
		return str(m)
	var args := []
	for a in m.get("args", []):
		if a is String:
			args.append(tr_s(a))
		else:
			args.append(int(a))
	var t := tr_s(str(m.text))
	if args.is_empty():
		return t
	# %d with thousands separators: format numbers as strings first ("%+d" keeps its sign)
	var fixed := t.replace("%+d", "%s").replace("%d", "%s")
	var shown := []
	var signed := []
	var i := 0
	var at := 0
	while true:
		var k := t.find("%", at)
		if k < 0 or k + 1 >= t.length():
			break
		if t[k + 1] == "%":
			at = k + 2
			continue
		signed.append(t[k + 1] == "+")
		at = k + 1
	for a in args:
		if a is int:
			var plus: bool = i < signed.size() and signed[i] and a >= 0
			shown.append(("+" if plus else "") + num(a))
		else:
			shown.append(a)
		i += 1
	return fixed % shown

static func good_name(g: String) -> String:
	return tr_s(D.GOODS[g].name)

static func world_name(w: String) -> String:
	return tr_s(D.WORLDS[w].name)

static func perk_name(id: String) -> String:
	return tr_s(S.PERKS[id].name)

static func perk_desc(id: String) -> String:
	return tr_s(S.PERKS[id].desc)

static func faction_name(f: String) -> String:
	return tr_s(S.FACTIONS.get(f, S.FACTIONS.none).name)

static func race_name(r: String) -> String:
	return tr_s(S.RACES[r].name)

static func sector_name(s: String) -> String:
	return tr_s(D.SECTORS[s].name)

# ---------------------------------------------------------------- portraits (owner's race art, 2026-11-08)

## The race portrait's art id. Ssaryn: Sunscale gold or Ashscale ember, by home faction; Verdanti:
## the second picture for a woman.
static func portrait_id(race: String, home: String = "", gender: String = "") -> String:
	match race:
		"ssaryn": return "race_ashscale" if home == "ashscale_warbands" else "race_sunscale"
		"verdanti": return "race_verdanti_2" if gender == "Female" else "race_verdanti"
	return "race_" + race

static func captain_portrait_id(cap: Dictionary) -> String:
	return portrait_id(str(cap.get("race", "terran")), str(cap.get("home", "")), str(cap.get("gender", "")))

## A crew member's portrait: their race's (Vorga flies for the Ashscale).
static func crew_portrait_id(cid: String) -> String:
	var c: Dictionary = S.CREW[cid]
	return portrait_id(str(c.race), "ashscale_warbands" if cid == "C10" else "")

## A portrait: the middle of the painting (the face), `h` pixels tall. `wide`: the whole painting.
static func portrait(id: String, h: float, wide: bool = false) -> TextureRect:
	var t := TextureRect.new()
	var tex := art(id)
	if tex != null and not wide:
		var sz := tex.get_size()
		var w := sz.y * 0.8
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((sz.x - w) * 0.5, 0, w, sz.y)
		tex = at
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.custom_minimum_size = Vector2(h * (1.83 if wide else 0.8), h)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## A labelled bar: "title  [=====   ]  v/max".
static func meter(title: String, v: float, mx: float, col: Color, width_title: float = 150.0, text: String = "") -> HBoxContainer:
	var h := hbox(10)
	var l := label(title, 18)
	l.custom_minimum_size.x = width_title
	h.add_child(l)
	var bar := ProgressBar.new()
	bar.max_value = maxf(1.0, mx)
	bar.value = clampf(v, 0.0, mx)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	h.add_child(bar)
	h.add_child(label(text if text != "" else "%d/%d" % [int(v), int(mx)], 17))
	return h
