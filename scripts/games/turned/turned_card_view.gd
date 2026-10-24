extends Control

## A zoom card (docs/turned/SCENE_MODE_PLAN.md, phase S3): the screen dims and a gold frame opens in
## the middle with a title, a macro picture (square) and a caption chip; a note or page also gets its
## words written over the picture by the game (EN or ES). A tap, A or Esc closes it. The world opens
## it (`open(id)`), freezes while it is up, and hears `closed`. Data: turned_cards.gd. No picture file
## yet = a drawn placeholder.

const T = preload("res://scripts/games/turned/turned_tuning.gd")
const Cards = preload("res://scripts/games/turned/turned_cards.gd")
const SceneText = preload("res://scripts/games/turned/turned_scene_text.gd")

signal closed(id: String)

const GOLD := Color("ce9e58")
const GOLD_DIM := Color("b6a58d")
const PLATE := Color("16100b")
const TEXT := Color("f3ede2")
const PAPER := Color("e4d4ae")
const INK_DARK := Color("2b1d12")

var is_open := false
var card_id := ""
var cards_data: Dictionary = {}      # tests put their own here; empty = turned_cards.json

var _card: Dictionary = {}
var _tex: Texture2D = null
var _t := 0.0
var _box: StyleBoxFlat = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false
	_box = StyleBoxFlat.new()
	resized.connect(queue_redraw)

## Opens a card; false (nothing happens) if there is no such card.
func open(id: String) -> bool:
	var c := Cards.card(id, cards_data)
	if c.is_empty():
		return false
	card_id = id
	_card = c
	_tex = Cards.art(str(c.get("art", "")))
	is_open = true
	_t = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()
	return true

func close() -> void:
	if not is_open:
		return
	var id := card_id
	is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_id = ""
	_card = {}
	_tex = null
	closed.emit(id)

func _gui_input(event: InputEvent) -> void:
	if is_open and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		close()

func _process(delta: float) -> void:
	if is_open:
		_t += delta
		queue_redraw()

# ---------------------------------------------------------------- geometry

func _k() -> float:
	return clampf(minf(size.x / 900.0, size.y / 640.0), 0.6, 1.0)

## The frame, the title strip, the square picture and the caption chip for a screen `view`.
static func compute_layout(view: Vector2, k: float) -> Dictionary:
	var pad := T.f("card.pad") * k
	var title_h := T.f("card.title_h") * k
	var cap_h := T.f("card.caption_h") * k
	var fh := view.y * T.f("card.frame_h")
	var p := fh - title_h - cap_h - pad * 2.0
	var max_p := view.x * 0.9 - pad * 2.0
	if p > max_p:
		p = max_p
		fh = p + title_h + cap_h + pad * 2.0
	var fw := p + pad * 2.0
	var frame := Rect2(Vector2((view.x - fw) * 0.5, (view.y - fh) * 0.5), Vector2(fw, fh))
	var picture := Rect2(Vector2(frame.position.x + pad, frame.position.y + title_h + pad * 0.5), Vector2(p, p))
	var title := Rect2(frame.position, Vector2(fw, title_h))
	var caption := Rect2(Vector2(picture.position.x, picture.end.y + 8.0 * k), Vector2(p, cap_h - 8.0 * k))
	return {"frame": frame, "title": title, "picture": picture, "caption": caption}

func layout() -> Dictionary:
	return compute_layout(size, _k())

## Where the card's words go, in screen units (inside the picture), or an empty Rect2.
func text_rect(lay: Dictionary) -> Rect2:
	if not _card.has("text_rect"):
		return Rect2()
	var f: Array = _card["text_rect"]
	var pic: Rect2 = lay["picture"]
	return Rect2(pic.position + pic.size * Vector2(float(f[0]), float(f[1])), pic.size * Vector2(float(f[2]), float(f[3])))

# ---------------------------------------------------------------- drawing

func _frame_box(r: Rect2, fill: Color, border: Color, radius: float, bw: float) -> void:
	_box.bg_color = fill
	_box.border_color = border
	_box.set_border_width_all(int(maxf(1.0, round(bw))))
	_box.set_corner_radius_all(int(round(radius)))
	draw_style_box(_box, r)

func _draw() -> void:
	if not is_open or size.x < 10.0:
		return
	var k := _k()
	var a := clampf(_t / maxf(T.f("card.open_s"), 0.05), 0.0, 1.0)
	a = a * a * (3.0 - 2.0 * a)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, T.f("card.dim") * a))
	# the whole card grows a little as it opens
	var lay := layout()
	var centre: Vector2 = (lay["frame"] as Rect2).get_center()
	var s := lerpf(0.94, 1.0, a)
	draw_set_transform(centre - centre * s, 0.0, Vector2(s, s))
	var frame: Rect2 = lay["frame"]
	_frame_box(frame, Color(PLATE, 0.97 * a), Color(GOLD, a), 14.0 * k, 3.0 * k)
	draw_rect(frame.grow(-7.0 * k), Color(GOLD_DIM, 0.55 * a), false, 1.2)
	_draw_corners(frame.grow(-7.0 * k), k, a)
	var words: Dictionary = SceneText.CARDS.get(card_id, {})
	var font := ThemeDB.fallback_font
	var tr_rect: Rect2 = lay["title"]
	var fs_t := int(round(26.0 * k))
	var title := tr(str(words.get("title", card_id)))
	_text(font, Vector2(tr_rect.position.x, tr_rect.position.y + tr_rect.size.y * 0.5 + fs_t * 0.34), title, fs_t, Color(TEXT, a), HORIZONTAL_ALIGNMENT_CENTER, tr_rect.size.x)
	var pic: Rect2 = lay["picture"]
	if _tex != null:
		draw_texture_rect(_tex, pic, false, Color(1, 1, 1, a))
	else:
		_draw_placeholder(pic, k, a)
	draw_rect(pic, Color(GOLD_DIM, 0.7 * a), false, 1.5)
	var txt := tr(str(words.get("text", ""))) if words.has("text") else ""
	if txt != "":
		_draw_card_text(lay, txt, k, a)
	var cap: Rect2 = lay["caption"]
	_frame_box(cap, Color(0.125, 0.114, 0.118, 0.94 * a), Color(GOLD_DIM, a), cap.size.y * 0.5, 1.0)
	var fs_c := int(round(18.0 * k))
	var caption := tr(str(words.get("caption", "")))
	_text(font, Vector2(cap.position.x + 14.0 * k, cap.position.y + cap.size.y * 0.5 + fs_c * 0.34), caption, fs_c, Color(TEXT, a), HORIZONTAL_ALIGNMENT_CENTER, cap.size.x - 28.0 * k)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _text(font: Font, pos: Vector2, s: String, fs: int, col: Color, align: int, width: float) -> void:
	draw_string_outline(font, pos, s, align, width, fs, 3, Color(0, 0, 0, col.a * 0.6))
	draw_string(font, pos, s, align, width, fs, col)

func _draw_corners(r: Rect2, k: float, a: float) -> void:
	var l := 26.0 * k
	var col := Color(GOLD, a)
	for corner in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		var c: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_polyline(PackedVector2Array([c + Vector2(d.x * l, 0), c, c + Vector2(0, d.y * l)]), col, 2.0 * k + 0.5)
		var dc := c + d * 9.0 * k
		var s := 3.6 * k
		draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -s), dc + Vector2(s, 0), dc + Vector2(0, s), dc + Vector2(-s, 0)]), col)

func _draw_placeholder(pic: Rect2, k: float, a: float) -> void:
	var top := Color("2a2018", a)
	var bottom := Color("120d09", a)
	draw_polygon(PackedVector2Array([pic.position, pic.position + Vector2(pic.size.x, 0), pic.end, pic.position + Vector2(0, pic.size.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	var fs := int(round(24.0 * k))
	var font := ThemeDB.fallback_font
	var y := pic.get_center().y + (pic.size.y * 0.36 if _card.has("text_rect") else 0.0)
	draw_string(font, Vector2(pic.position.x, y), tr(SceneText.UI["no_picture"]), HORIZONTAL_ALIGNMENT_CENTER, pic.size.x, fs, Color(0.8, 0.74, 0.66, 0.45 * a))
	draw_string(font, Vector2(pic.position.x, y + fs * 1.3), str(_card.get("art", "")), HORIZONTAL_ALIGNMENT_CENTER, pic.size.x, int(fs * 0.7), Color(0.8, 0.74, 0.66, 0.3 * a))

## The card's words over the picture: dark ink by default (paper), light on request. Without a
## picture a paper patch is drawn behind them so they can be read.
func _draw_card_text(lay: Dictionary, txt: String, k: float, a: float) -> void:
	var r := text_rect(lay)
	if r.size.x <= 0.0:
		return
	var ink := INK_DARK if str(_card.get("ink", "dark")) == "dark" else Color("efe6d2")
	if _tex == null:
		draw_rect(r.grow(10.0 * k), Color(PAPER, 0.95 * a))
	var font := ThemeDB.fallback_font
	var fs := int(round(lay["picture"].size.x * 0.052))
	while fs > 12 and _wrapped_height(font, txt, r.size.x, fs) > r.size.y:
		fs -= 1
	var lines_h := _wrapped_height(font, txt, r.size.x, fs)
	var y := r.position.y + (r.size.y - lines_h) * 0.5 + fs
	font.draw_multiline_string(get_canvas_item(), Vector2(r.position.x, y), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, -1, Color(ink, a))

static func _wrapped_height(font: Font, txt: String, width: float, fs: int) -> float:
	return font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, width, fs).y
