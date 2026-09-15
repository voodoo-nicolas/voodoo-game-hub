extends RefCounted

const EMPTY := 0
const RED := 1
const YELLOW := 2
const COLS := 7
const ROWS := 6

## board[row][col], row 0 = top. 0=empty, 1=red, 2=yellow.
var board: Array = []
var turn: int = RED

func _init() -> void:
	reset()

func reset() -> void:
	board = []
	for r in range(ROWS):
		board.append([EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	turn = RED

## Drops the current player's piece into the given column (0-6).
## Returns the landing row, or -1 if the column is full or the game is over.
func drop(col: int) -> int:
	if is_over():
		return -1
	for r in range(ROWS - 1, -1, -1):
		if board[r][col] == EMPTY:
			board[r][col] = turn
			turn = YELLOW if turn == RED else RED
			return r
	return -1

func winner() -> int:
	for r in range(ROWS):
		for c in range(COLS):
			var v: int = board[r][c]
			if v == EMPTY:
				continue
			for dir in [[0, 1], [1, 0], [1, 1], [1, -1]]:
				var count := 1
				var dr: int = dir[0]
				var dc: int = dir[1]
				var nr: int = r + dr
				var nc: int = c + dc
				while nr >= 0 and nr < ROWS and nc >= 0 and nc < COLS and board[nr][nc] == v:
					count += 1
					nr += dr
					nc += dc
				if count >= 4:
					return v
	return EMPTY

func is_full() -> bool:
	for c in range(COLS):
		if board[0][c] == EMPTY:
			return false
	return true

func is_over() -> bool:
	return winner() != EMPTY or is_full()
