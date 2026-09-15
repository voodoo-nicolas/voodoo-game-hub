extends RefCounted

## board[i]: 0 = empty, 1 = X, 2 = O. Index layout is row-major, 3x3.
const EMPTY := 0
const X := 1
const O := 2

const WIN_LINES := [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6],
]

var board: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0]
var turn: int = X

func reset() -> void:
	board = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	turn = X

## Returns true if the move was applied (cell was empty and game isn't already won).
func move(index: int) -> bool:
	if board[index] != EMPTY:
		return false
	if winner() != EMPTY or is_draw():
		return false
	board[index] = turn
	turn = O if turn == X else X
	return true

## Returns X, O, or EMPTY (no winner yet / draw).
func winner() -> int:
	for line in WIN_LINES:
		var a: int = board[line[0]]
		if a != EMPTY and a == board[line[1]] and a == board[line[2]]:
			return a
	return EMPTY

func is_draw() -> bool:
	if winner() != EMPTY:
		return false
	for v in board:
		if v == EMPTY:
			return false
	return true

func is_over() -> bool:
	return winner() != EMPTY or is_draw()
