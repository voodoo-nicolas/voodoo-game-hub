extends Control
const Art = preload("res://scripts/games/hesperia/game/art.gd")
const Prefs = preload("res://scripts/games/hesperia/game/prefs.gd")
const Data = preload("res://scripts/games/hesperia/data.gd")
const WorldState = preload("res://scripts/games/hesperia/world_state.gd")
## Hearts + magic top-left, obols, equipped X/Y, quest/objective top-right, toasts top-centre.

var quest_label: Label
var toast_label: Label
var toasts: Array = []
var toast_t: float = 0.0
var tracked: String = ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	quest_label = Label.new()
	quest_label.position = Vector2(228, 4)
	quest_label.size = Vector2(152, 40)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quest_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	quest_label.add_theme_color_override("font_outline_color", Color.BLACK)
	quest_label.add_theme_constant_override("outline_size", 3)
	add_child(quest_label)
	toast_label = Label.new()
	toast_label.position = Vector2(60, 30)
	toast_label.size = Vector2(264, 20)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 4)
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

func _process(dt: float) -> void:
	if toast_t > 0.0:
		toast_t -= dt
		toast_label.modulate.a = clampf(toast_t * 2.0, 0.0, 1.0)
		if toast_t <= 0.0:
			toast_label.text = ""
	elif toasts.size() > 0:
		toast_label.text = toasts.pop_front()
		toast_t = 2.2
		toast_label.modulate.a = 1.0

func _heart(c: Vector2, fill: float) -> void:
	# fill: 0, 0.5, 1
	var back := Color(0.25, 0.05, 0.08)
	draw_circle(c + Vector2(-2.5, -1.0), 3.0, back)
	draw_circle(c + Vector2(2.5, -1.0), 3.0, back)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-5.5, 0), c + Vector2(5.5, 0), c + Vector2(0, 6)]), back)
	if fill <= 0.0:
		return
	var red := Color(0.9, 0.15, 0.2)
	if fill >= 1.0:
		draw_circle(c + Vector2(-2.5, -1.0), 2.4, red)
		draw_circle(c + Vector2(2.5, -1.0), 2.4, red)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-4.9, 0), c + Vector2(4.9, 0), c + Vector2(0, 5)]), red)
	else:
		draw_circle(c + Vector2(-2.5, -1.0), 2.4, red)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-4.9, 0), c + Vector2(0, 0), c + Vector2(0, 5)]), red)

func _draw() -> void:
	var hearts := WorldState.max_half_hearts / 2
	for i in hearts:
		var c := Vector2(10.0 + float(i % 10) * 12.0, 9.0 + float(i / 10) * 11.0)
		var half: int = clampi(WorldState.half_hearts - i * 2, 0, 2)
		_heart(c, float(half) / 2.0)
	var my := 9.0 + float((hearts - 1) / 10 + 1) * 11.0
	draw_rect(Rect2(5, my, 52, 4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(6, my + 1, 50.0 * float(WorldState.magic) / float(max(1, WorldState.max_magic)), 2), Color(0.3, 0.8, 0.4))
	Art.label(self, "%s %d" % [Data.tr_ui("obol"), WorldState.item_count("obol")], Vector2(6, my + 14), Prefs.fs(8), Color(0.95, 0.85, 0.4))
	# equipped items
	var x := 70.0
	for pair in [["X", WorldState.equipped_x], ["Y", WorldState.equipped_y]]:
		draw_rect(Rect2(x, 3, 22, 14), Color(0, 0, 0, 0.55))
		Art.label(self, pair[0], Vector2(x + 1, 13), 7, Color(0.7, 0.7, 0.7))
		if pair[1] != "":
			var nm: String = Data.name_of(pair[1])
			Art.label(self, nm.substr(0, 2), Vector2(x + 9, 13), 8, Color(1, 0.85, 0.5))
		x += 25.0
