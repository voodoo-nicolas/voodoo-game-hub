extends RefCounted

## Shared UI styling used across game screens, so the pause/win/settings panels
## in every game stay visually identical without each game carrying its own copy.

## Builds the full-screen dim + centered card used by every pause and game-over
## dialog. `buttons` is an ordered Array of {"text": String, "action": Callable}.
##
## The overlay starts hidden; callers add_child() it and toggle `.visible`.
## Pass with_message for a dialog whose text changes with the result (every
## game-over screen); read that Label back via get_meta("message_label").
static func build_dialog(title_text: String, buttons: Array, with_message: bool = false) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	if title_text != "":
		var title := Label.new()
		title.text = title_text
		title.add_theme_font_size_override("font_size", 40)
		title.add_theme_color_override("font_color", Color(1, 1, 1))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)

	if with_message:
		var message := Label.new()
		message.add_theme_font_size_override("font_size", 30)
		message.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message.autowrap_mode = TextServer.AUTOWRAP_WORD
		message.custom_minimum_size = Vector2(300, 0)
		box.add_child(message)
		overlay.set_meta("message_label", message)

	for spec in buttons:
		var btn := Button.new()
		btn.text = spec.text
		btn.custom_minimum_size = Vector2(320, 64)
		btn.add_theme_font_size_override("font_size", 26)
		btn.pressed.connect(_dismiss_then.bind(overlay, spec.action))
		box.add_child(btn)

	return overlay

## Every dialog button closes the dialog; hiding it here keeps the call sites to
## a single-expression Callable each. GDScript can't parse a multi-line lambda
## inside a dictionary literal, so the button specs must stay one-liners.
## An empty Callable() means the button only closes the dialog (e.g. "Resume").
static func _dismiss_then(overlay: ColorRect, action: Callable) -> void:
	overlay.visible = false
	if action.is_valid():
		action.call()

## Save-then-leave, shared by dialog "Exit to Hub" buttons and the settings
## drawer. Games opt into the save by defining _save_game().
static func exit_to_hub(from: Node) -> void:
	if from.has_method("_save_game"):
		from._save_game()
	from.get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")

## The dark rounded card behind every pause and game-over dialog.
static func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.14, 0.18)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	return sb
