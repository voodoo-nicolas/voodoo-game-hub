extends Label

## HUD text on a dark ink panel. The panel is only as big as the text (wraps at max_width),
## is centered on screen (unless `centered` is false) and hides itself when there is no text.

var max_width := 820.0
var centered := true
var _last := "\u0001"
var _last_max := -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.055, 0.055, 0.07, 0.8)
	box.border_color = Color("0e0e12")
	box.set_border_width_all(2)
	box.set_corner_radius_all(7)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	add_theme_stylebox_override("normal", box)

func _process(_delta: float) -> void:
	visible = text != ""
	if not visible:
		_last = "\u0001"
		return
	if text != _last or max_width != _last_max:
		_last = text
		_last_max = max_width
		autowrap_mode = TextServer.AUTOWRAP_OFF
		custom_minimum_size = Vector2.ZERO
		reset_size()
		if size.x > max_width:
			autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			custom_minimum_size.x = max_width
			reset_size()
	if centered:
		position.x = (get_viewport_rect().size.x - size.x) * 0.5
