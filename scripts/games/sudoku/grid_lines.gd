extends Control

## Draws the bold 3x3 box-separator + outer border lines on top of the cell grid.
## Positions match CellButton.custom_minimum_size (72) + GridContainer separation (2):
## column/row j starts at j*74; the board is 9*72 + 8*2 = 664 px square.
const BOUNDARY_POSITIONS := [0.0, 222.0, 444.0, 664.0]
const THICKNESS := 4.0
const LINE_COLOR := Color(0.95, 0.95, 1.0)

func _draw() -> void:
	for pos in BOUNDARY_POSITIONS:
		draw_line(Vector2(pos, 0.0), Vector2(pos, 664.0), LINE_COLOR, THICKNESS)
		draw_line(Vector2(0.0, pos), Vector2(664.0, pos), LINE_COLOR, THICKNESS)
