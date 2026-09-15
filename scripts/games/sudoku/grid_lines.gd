extends Control

## Draws the bold 3x3 box-separator + outer border lines on top of the cell grid.
## Call setup(cell_size, separation) before this is drawn (before it enters the tree,
## or call queue_redraw() after) since positions depend on the actual board dimensions.
const THICKNESS := 4.0
const LINE_COLOR := Color(0.95, 0.95, 1.0)

var boundary_positions: Array = [0.0, 222.0, 444.0, 664.0]
var board_size: float = 664.0

func setup(cell_size: float, separation: float) -> void:
	var step: float = cell_size + separation
	board_size = cell_size * 9.0 + separation * 8.0
	boundary_positions = [0.0, step * 3.0, step * 6.0, board_size]

func _draw() -> void:
	for pos in boundary_positions:
		draw_line(Vector2(pos, 0.0), Vector2(pos, board_size), LINE_COLOR, THICKNESS)
		draw_line(Vector2(0.0, pos), Vector2(board_size, pos), LINE_COLOR, THICKNESS)
