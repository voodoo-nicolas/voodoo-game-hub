extends Control
const Art = preload("res://scripts/games/hesperia/game/art.gd")
const Prefs = preload("res://scripts/games/hesperia/game/prefs.gd")
const Data = preload("res://scripts/games/hesperia/data.gd")
const WorldState = preload("res://scripts/games/hesperia/world_state.gd")
## Hearts + magic top-left, obols, equipped X/Y, quest/objective top-right, toasts top-centre.
## Visual pass (2026-11): bronze-trimmed plates behind each group, shaded hearts that pulse on low health and
## pop when one is lost, gradient magic bar, obol coin icon, item slots with drawn icons, quest card with an
## accent bar, toasts as a sliding banner. Right-side/centre elements follow the real viewport width (phones are wider than 16:9).

const Fx := preload("res://scripts/games/hesperia/game/fx.gd")
const Sounds := preload("res://scripts/games/hesperia/hesperia_sounds.gd")
const UiTheme := preload("res://scripts/games/hesperia/game/ui_theme.gd")
const BRONZE := Color(0.80, 0.60, 0.30)
const GOLD := Color(1.0, 0.86, 0.45)
const PLATE := Color(0.05, 0.045, 0.07, 0.62)

var quest_label: Label
var toast_label: Label
var toasts: Array = []
var toast_t: float = 0.0
var tracked: String = ""
var t: float = 0.0
var last_half: int = -1
var lost_t: float = 0.0          # heart-loss pop
var lost_idx: int = -1
var shown_magic: float = -1.0    # eased magic bar
var shown_obol: int = -1
var obol_t: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.build()
	quest_label = Label.new()
	quest_label.position = Vector2(228, 5)
	quest_label.size = Vector2(150, 40)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quest_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
	quest_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.06))
	quest_label.add_theme_constant_override("outline_size", 2)
	quest_label.add_theme_constant_override("line_spacing", -1)
	add_child(quest_label)
	toast_label = Label.new()
	toast_label.position = Vector2(60, 30)
	toast_label.size = Vector2(264, 20)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 2)
	add_child(toast_label)
	WorldState.bus.changed.connect(queue_redraw)
	WorldState.bus.quest_changed.connect(_on_quest_changed)
	WorldState.bus.toast.connect(push_toast)
	apply_text_size()

func apply_text_size() -> void:
	quest_label.add_theme_font_size_override("font_size", Prefs.fs(8))
	toast_label.add_theme_font_size_override("font_size", Prefs.fs(9))
	refresh_quest()

func _on_quest_changed(id: String) -> void:
	if WorldState.quest_state(id) != "active" or tracked != id:
		Sounds.quest(self)       # new quest or quest completed
	if WorldState.quest_state(id) == "active":
		tracked = id
	refresh_quest()

func refresh_quest() -> void:
	if tracked == "" or WorldState.quest_state(tracked) != "active":
		tracked = ""
		for id in WorldState.quests.state.keys():
			if WorldState.quests.state[id]["state"] == "active":
				tracked = id
				if id.begins_with("m"):
					break
	if tracked == "":
		quest_label.text = ""
		return
	quest_label.text = "%s\n%s" % [Data.name_of(tracked), WorldState.quests.current_text(tracked, Data.lang)]

func push_toast(text: String) -> void:
	toasts.append(text)

func _vw() -> float:
	return get_viewport_rect().size.x

func _process(dt: float) -> void:
	if not visible:
		return
	t += dt
	quest_label.position.x = _vw() - 156.0
	toast_label.position.x = (_vw() - toast_label.size.x) * 0.5
	if toast_t > 0.0:
		toast_t -= dt
		toast_label.modulate.a = clampf(toast_t * 2.0, 0.0, 1.0)
		var enter := clampf((2.2 - toast_t) / 0.18, 0.0, 1.0)
		toast_label.position.y = 30.0 - 6.0 * (1.0 - enter) * (1.0 - enter)
		if toast_t <= 0.0:
			toast_label.text = ""
	elif toasts.size() > 0:
		toast_label.text = toasts.pop_front()
		toast_t = 2.2
		toast_label.modulate.a = 1.0
	# heart loss pop
	if last_half >= 0 and WorldState.half_hearts < last_half:
		lost_t = 0.35
		lost_idx = (WorldState.half_hearts) / 2
	last_half = WorldState.half_hearts
	if lost_t > 0.0:
		lost_t -= dt
	var target := float(WorldState.magic) / float(max(1, WorldState.max_magic))
	shown_magic = target if shown_magic < 0.0 else move_toward(shown_magic, target, dt * 1.5)
	var ob: int = WorldState.item_count("obol")
	if shown_obol >= 0 and ob != shown_obol:
		obol_t = 0.3
	shown_obol = ob
	if obol_t > 0.0:
		obol_t -= dt
	queue_redraw()

func _plate(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, PLATE)
	draw_rect(r, Color(BRONZE.r, BRONZE.g, BRONZE.b, 0.55), false, 1.0)
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), Color(1, 1, 1, 0.06))

func _heart(c: Vector2, fill: float, s: float) -> void:
	# fill: 0, 0.5, 1  (outline, dark socket, red fill, highlight pixel)
	Fx.heart(self, c, 6.2 * s, Color(0.06, 0.02, 0.03))
	Fx.heart(self, c + Vector2(0, -0.4), 5.2 * s, Color(0.28, 0.06, 0.09))
	if fill <= 0.0:
		return
	var red := Color(0.93, 0.16, 0.22)
	if fill >= 1.0:
		Fx.heart(self, c + Vector2(0, -0.4), 5.2 * s, red)
		draw_rect(Rect2((c + Vector2(-3, -3) * s).round(), Vector2(2, 1)), Color(1, 0.75, 0.75))
	else:
		draw_circle(c + Vector2(-2.4, -1.4) * s, 2.6 * s, red)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-4.8, -0.4) * s, c + Vector2(0, -0.4) * s, c + Vector2(0, 4.8) * s]), red)
		draw_rect(Rect2((c + Vector2(-3, -3) * s).round(), Vector2(1, 1)), Color(1, 0.75, 0.75))

func _coin(c: Vector2, s: float) -> void:
	draw_circle(c, 3.5 * s, Color(0.45, 0.3, 0.08))
	draw_circle(c, 2.8 * s, Color(0.95, 0.78, 0.3))
	draw_rect(Rect2(c + Vector2(-0.5, -1.5), Vector2(1, 3)), Color(0.6, 0.42, 0.12))
	draw_rect(Rect2(c + Vector2(-2, -2), Vector2(1, 1)), Color(1, 0.97, 0.75))

## Tiny icons for equippable items; unknown ids fall back to the name's first two letters.
func _item_icon(id: String, c: Vector2) -> void:
	match id:
		"torch":
			draw_rect(Rect2(c + Vector2(-1, 0), Vector2(2, 5)), Color(0.5, 0.32, 0.15))
			var f := 1.0 + 0.2 * sin(t * 12.0)
			Fx.glow(self, c + Vector2(0, -1), 4.0 * f, Color(1, 0.55, 0.15, 0.4), 3)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 0), c + Vector2(2, 0), c + Vector2(0, -5.0 * f)]), Color(1, 0.75, 0.25))
		"fire_rod":
			draw_line(c + Vector2(-4, 4), c + Vector2(3, -3), Color(0.55, 0.35, 0.18), 2.0)
			Fx.glow(self, c + Vector2(3, -3), 3.5, Color(1, 0.4, 0.1, 0.5), 3)
			draw_rect(Rect2(c + Vector2(2, -4), Vector2(2, 2)), Color(1, 0.85, 0.4))
		"honey":
			draw_rect(Rect2(c + Vector2(-3, -2), Vector2(6, 6)), Color(0.9, 0.6, 0.15))
			draw_rect(Rect2(c + Vector2(-3, -4), Vector2(6, 2)), Color(0.85, 0.82, 0.75))
			draw_rect(Rect2(c + Vector2(-2, -1), Vector2(1, 2)), Color(1, 0.9, 0.6))
		"nectar":
			draw_circle(c + Vector2(0, 1.5), 3.0, Color(0.85, 0.35, 0.75))
			draw_rect(Rect2(c + Vector2(-1, -4), Vector2(2, 3)), Color(0.8, 0.85, 0.9))
			draw_rect(Rect2(c + Vector2(-1, 0), Vector2(1, 1)), Color(1, 0.85, 1))
		_:
			Art.label(self, Data.name_of(id).substr(0, 2), c + Vector2(-5, 3), 10, GOLD)

func _draw() -> void:
	var hearts := WorldState.max_half_hearts / 2
	var rows_h := (hearts - 1) / 10 + 1
	var cols: int = mini(hearts, 10)
	var low := WorldState.half_hearts <= 2 and WorldState.half_hearts > 0
	var pw := 10.0 + float(cols) * 12.0
	_plate(Rect2(2, 2, maxf(pw, 66.0), 18.0 + float(rows_h) * 11.0))
	for i in hearts:
		var c := Vector2(10.0 + float(i % 10) * 12.0, 10.0 + float(i / 10) * 11.0)
		var half: int = clampi(WorldState.half_hearts - i * 2, 0, 2)
		var s := 1.0
		if low and half > 0:
			s = 1.0 + 0.12 * maxf(0.0, sin(t * 7.0))
		if lost_t > 0.0 and i == lost_idx:
			s = 1.0 + lost_t * 1.2
		_heart(c, float(half) / 2.0, s)
	var my := 9.0 + float(rows_h) * 11.0
	# magic bar: dark trough, green->teal gradient fill, top sheen
	var bw := 52.0
	draw_rect(Rect2(6, my - 1, bw + 2, 5), Color(0.02, 0.02, 0.03, 0.9))
	var fw := roundf(bw * clampf(shown_magic, 0.0, 1.0))
	if fw > 0.0:
		draw_polygon(PackedVector2Array([Vector2(7, my), Vector2(7 + fw, my), Vector2(7 + fw, my + 3), Vector2(7, my + 3)]),
			PackedColorArray([Color(0.25, 0.75, 0.35), Color(0.35, 0.9, 0.75), Color(0.35, 0.9, 0.75), Color(0.25, 0.75, 0.35)]))
		draw_rect(Rect2(7, my, fw, 1), Color(1, 1, 1, 0.35))
	# obols
	var os := 1.0 + obol_t * 1.2
	_coin(Vector2(10, my + 11), os)
	Art.label(self, str(WorldState.item_count("obol")), Vector2(16, my + 14), Prefs.fs(8), GOLD.lerp(Color.WHITE, obol_t * 3.0))
	# equipped items
	var x := maxf(pw, 66.0) + 8.0
	for pair in [["X", WorldState.equipped_x], ["Y", WorldState.equipped_y]]:
		var r := Rect2(x, 3, 20, 18)
		_plate(r)
		draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), Color(0, 0, 0, 0.3))
		if pair[1] != "":
			_item_icon(pair[1], r.get_center() + Vector2(1, 0))
		# button badge
		draw_circle(Vector2(x + 1, 4), 4.0, Color(0.1, 0.08, 0.1))
		draw_circle(Vector2(x + 1, 4), 3.4, BRONZE)
		Art.label(self, pair[0], Vector2(x - 1, 7), 10, Color(0.1, 0.06, 0.03))
		x += 24.0
	# quest card behind the label
	if quest_label.text != "":
		var f := quest_label.get_theme_font("font")
		var fs := quest_label.get_theme_font_size("font_size")
		var wmax := 0.0
		for ln in quest_label.text.split("\n"):
			wmax = maxf(wmax, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		wmax = minf(wmax, quest_label.size.x)
		var hh := float(quest_label.get_line_count()) * float(quest_label.get_line_height()) + 4.0
		var qr := Rect2(_vw() - 6.0 - wmax - 8.0, 3, wmax + 10.0, hh)
		_plate(qr)
		draw_rect(Rect2(qr.end.x - 2, qr.position.y + 2, 1, qr.size.y - 4), GOLD)
	# toast banner
	if toast_label.text != "" and toast_label.modulate.a > 0.0:
		var f2 := toast_label.get_theme_font("font")
		var tw := f2.get_string_size(toast_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, toast_label.get_theme_font_size("font_size")).x + 24.0
		var a := toast_label.modulate.a
		var tr := Rect2((_vw() - tw) * 0.5, toast_label.position.y + 3.0, tw, 14)
		draw_rect(tr, Color(0.06, 0.04, 0.07, 0.8 * a))
		draw_rect(Rect2(tr.position, Vector2(tw, 1)), Color(GOLD.r, GOLD.g, GOLD.b, 0.8 * a))
		draw_rect(Rect2(tr.position + Vector2(0, 13), Vector2(tw, 1)), Color(BRONZE.r, BRONZE.g, BRONZE.b, 0.6 * a))
		for sx in [tr.position.x - 3.0, tr.end.x + 3.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(sx, tr.get_center().y - 3), Vector2(sx + 3, tr.get_center().y), Vector2(sx, tr.get_center().y + 3), Vector2(sx - 3, tr.get_center().y)]), Color(GOLD.r, GOLD.g, GOLD.b, a))
