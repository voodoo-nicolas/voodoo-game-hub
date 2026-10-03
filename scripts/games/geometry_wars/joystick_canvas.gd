extends Node2D

## Positioned at (0,0), i.e. screen space, since touch/mouse input coordinates
## are already in that space -- unlike arena_canvas, no offset conversion needed.
var game: Control

func _draw() -> void:
	if game == null:
		return
	# Touches are in screen space, but the game's screen may be inset from the
	# phone's edges (camera cutout), and we draw inside it -- undo that inset.
	position = -game.global_position
	if game.move_touch_index != -1:
		draw_circle(game.move_origin, 70.0, Color(1, 1, 1, 0.12))
		draw_circle(game.move_origin + game.move_value * 70.0, 28.0, Color(1, 1, 1, 0.28))
	if game.aim_touch_index != -1:
		draw_circle(game.aim_origin, 70.0, Color(1, 1, 1, 0.12))
		draw_circle(game.aim_origin + game.aim_value * 70.0, 28.0, Color(1, 1, 1, 0.28))
