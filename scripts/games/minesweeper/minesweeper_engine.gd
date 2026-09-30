extends RefCounted

## Classic Minesweeper. Mines are placed on the FIRST reveal, never on or
## next to that cell, so the opening tap always opens an area instead of
## ending the game. Revealing a 0 flood-fills its neighbors; tapping a
## revealed number whose flag count matches it ("chording") reveals the rest.

const DIFFICULTIES := {
	"easy": {"rows": 9, "cols": 9, "mines": 10},
	"medium": {"rows": 12, "cols": 12, "mines": 24},
	"hard": {"rows": 14, "cols": 14, "mines": 40},
}

var rows: int = 9
var cols: int = 9
var mine_count: int = 10
var mines: Array = []     # rows x cols bool
var adjacent: Array = []  # rows x cols int, mines touching each cell
var revealed: Array = []  # rows x cols bool
var flagged: Array = []   # rows x cols bool
var mines_placed: bool = false
var game_over: bool = false
var won: bool = false
var exploded: Vector2i = Vector2i(-1, -1)
var revealed_count: int = 0

func reset(difficulty: String = "easy") -> void:
	var d: Dictionary = DIFFICULTIES.get(difficulty, DIFFICULTIES.easy)
	rows = d.rows
	cols = d.cols
	mine_count = d.mines
	mines = _grid(false)
	adjacent = _grid(0)
	revealed = _grid(false)
	flagged = _grid(false)
	mines_placed = false
	game_over = false
	won = false
	exploded = Vector2i(-1, -1)
	revealed_count = 0

func _grid(value) -> Array:
	var g: Array = []
	for r in range(rows):
		var row: Array = []
		row.resize(cols)
		row.fill(value)
		g.append(row)
	return g

func in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < rows and c >= 0 and c < cols

func neighbors(r: int, c: int) -> Array:
	var out: Array = []
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if (dr != 0 or dc != 0) and in_bounds(r + dr, c + dc):
				out.append(Vector2i(r + dr, c + dc))
	return out

func flags_left() -> int:
	var n := 0
	for r in range(rows):
		for c in range(cols):
			if flagged[r][c]:
				n += 1
	return mine_count - n

func _place_mines(safe_r: int, safe_c: int) -> void:
	var candidates: Array = []
	for r in range(rows):
		for c in range(cols):
			if abs(r - safe_r) > 1 or abs(c - safe_c) > 1:
				candidates.append(Vector2i(r, c))
	candidates.shuffle()
	for i in range(min(mine_count, candidates.size())):
		var p: Vector2i = candidates[i]
		mines[p.x][p.y] = true
	for r in range(rows):
		for c in range(cols):
			var n := 0
			for nb in neighbors(r, c):
				if mines[nb.x][nb.y]:
					n += 1
			adjacent[r][c] = n
	mines_placed = true

func toggle_flag(r: int, c: int) -> void:
	if game_over or revealed[r][c]:
		return
	flagged[r][c] = not flagged[r][c]

## Reveals (r,c). On an already-revealed number, chords instead.
## Returns "ignored", "ok", "lost" or "won".
func reveal(r: int, c: int) -> String:
	if game_over or flagged[r][c]:
		return "ignored"
	if not mines_placed:
		_place_mines(r, c)
	if revealed[r][c]:
		return _chord(r, c)
	if mines[r][c]:
		_lose(r, c)
		return "lost"
	_flood(r, c)
	return _check_win()

func _chord(r: int, c: int) -> String:
	var n: int = adjacent[r][c]
	if n == 0:
		return "ignored"
	var flags := 0
	for nb in neighbors(r, c):
		if flagged[nb.x][nb.y]:
			flags += 1
	if flags != n:
		return "ignored"
	for nb in neighbors(r, c):
		if not flagged[nb.x][nb.y] and not revealed[nb.x][nb.y]:
			if mines[nb.x][nb.y]:
				_lose(nb.x, nb.y)
				return "lost"
			_flood(nb.x, nb.y)
	return _check_win()

## Iterative, not recursive: a big empty area on the hard board would
## otherwise recurse ~200 deep.
func _flood(r: int, c: int) -> void:
	var stack: Array = [Vector2i(r, c)]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if revealed[p.x][p.y] or flagged[p.x][p.y]:
			continue
		revealed[p.x][p.y] = true
		revealed_count += 1
		if adjacent[p.x][p.y] == 0:
			for nb in neighbors(p.x, p.y):
				if not revealed[nb.x][nb.y] and not mines[nb.x][nb.y]:
					stack.append(nb)

func _lose(r: int, c: int) -> void:
	game_over = true
	won = false
	exploded = Vector2i(r, c)

func _check_win() -> String:
	if revealed_count == rows * cols - mine_count:
		game_over = true
		won = true
		# Flag every mine for the final board, like the classic game does.
		for r in range(rows):
			for c in range(cols):
				flagged[r][c] = mines[r][c]
		return "won"
	return "ok"
