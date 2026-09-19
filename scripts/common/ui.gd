extends RefCounted

## Shared UI styling used across game screens, so the pause/win/settings panels
## in every game stay visually identical without each game carrying its own copy.

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
