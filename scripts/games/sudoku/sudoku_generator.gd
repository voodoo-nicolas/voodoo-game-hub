extends RefCounted

## Number of clues (filled cells) left in the puzzle per difficulty.
const CLUE_TARGETS := {
	"easy": 38,
	"medium": 30,
	"hard": 26,
	"expert": 20,
}

## Number of digging attempts to try, keeping the sparsest valid result.
## Naive random digging plateaus around ~24 clues, so harder tiers retry
## with different removal orders to push closer to their target.
const DIG_ATTEMPTS := {
	"easy": 1,
	"medium": 1,
	"hard": 3,
	"expert": 6,
}

static func generate_puzzle(difficulty: String) -> Dictionary:
	var solution := _generate_full_board()
	var target: int = CLUE_TARGETS.get(difficulty, 30)
	var attempts: int = DIG_ATTEMPTS.get(difficulty, 1)

	var best_puzzle: Array = []
	var best_clues := 82

	for i in range(attempts):
		var attempt := _dig(solution, target)
		var attempt_clues: int = attempt.clues
		if attempt_clues < best_clues:
			best_clues = attempt_clues
			best_puzzle = attempt.puzzle
		if best_clues <= target:
			break

	return {"puzzle": best_puzzle, "solution": solution}

static func _dig(solution: Array, target: int) -> Dictionary:
	var puzzle: Array = solution.duplicate(true)

	var positions: Array = []
	for r in range(9):
		for c in range(9):
			positions.append(Vector2i(r, c))
	positions.shuffle()

	var clues := 81

	for pos in positions:
		if clues <= target:
			break
		var r: int = pos.x
		var c: int = pos.y
		var backup: int = puzzle[r][c]
		if backup == 0:
			continue
		puzzle[r][c] = 0
		if _count_solutions(puzzle) == 1:
			clues -= 1
		else:
			puzzle[r][c] = backup

	return {"puzzle": puzzle, "clues": clues}

static func _box_index(r: int, c: int) -> int:
	return int(r / 3) * 3 + int(c / 3)

static func _generate_full_board() -> Array:
	var board: Array = []
	for i in range(9):
		board.append([0, 0, 0, 0, 0, 0, 0, 0, 0])
	var row_mask := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	var col_mask := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	var box_mask := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	_fill_board(board, row_mask, col_mask, box_mask, true)
	return board

## Finds the empty cell with the fewest legal candidates (MRV heuristic).
## Returns [] if the board is fully filled.
static func _find_best_cell(board: Array, row_mask: Array, col_mask: Array, box_mask: Array) -> Array:
	var best_pos: Array = []
	var best_count := 10
	for r in range(9):
		for c in range(9):
			if board[r][c] == 0:
				var used: int = row_mask[r] | col_mask[c] | box_mask[_box_index(r, c)]
				var count := 0
				for n in range(1, 10):
					if not (used & (1 << n)):
						count += 1
				if count < best_count:
					best_count = count
					best_pos = [r, c]
					if count <= 1:
						return best_pos
	return best_pos

static func _fill_board(board: Array, row_mask: Array, col_mask: Array, box_mask: Array, randomize_order: bool) -> bool:
	var pos := _find_best_cell(board, row_mask, col_mask, box_mask)
	if pos.is_empty():
		return true
	var r: int = pos[0]
	var c: int = pos[1]
	var b := _box_index(r, c)
	var used: int = row_mask[r] | col_mask[c] | box_mask[b]

	var candidates: Array = []
	for n in range(1, 10):
		if not (used & (1 << n)):
			candidates.append(n)
	if randomize_order:
		candidates.shuffle()

	for n in candidates:
		board[r][c] = n
		row_mask[r] |= (1 << n)
		col_mask[c] |= (1 << n)
		box_mask[b] |= (1 << n)

		if _fill_board(board, row_mask, col_mask, box_mask, randomize_order):
			return true

		board[r][c] = 0
		row_mask[r] &= ~(1 << n)
		col_mask[c] &= ~(1 << n)
		box_mask[b] &= ~(1 << n)

	return false

## Counts solutions, stopping as soon as it finds 2 (we only need "unique" vs "not unique").
static func _count_solutions(board: Array) -> int:
	var row_mask := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	var col_mask := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	var box_mask := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	for r in range(9):
		for c in range(9):
			var n: int = board[r][c]
			if n != 0:
				row_mask[r] |= (1 << n)
				col_mask[c] |= (1 << n)
				box_mask[_box_index(r, c)] |= (1 << n)

	var work: Array = board.duplicate(true)
	var counter := [0]
	_count_helper(work, row_mask, col_mask, box_mask, counter)
	return counter[0]

static func _count_helper(board: Array, row_mask: Array, col_mask: Array, box_mask: Array, counter: Array) -> void:
	if counter[0] >= 2:
		return
	var pos := _find_best_cell(board, row_mask, col_mask, box_mask)
	if pos.is_empty():
		counter[0] += 1
		return
	var r: int = pos[0]
	var c: int = pos[1]
	var b := _box_index(r, c)
	var used: int = row_mask[r] | col_mask[c] | box_mask[b]

	for n in range(1, 10):
		if not (used & (1 << n)):
			board[r][c] = n
			row_mask[r] |= (1 << n)
			col_mask[c] |= (1 << n)
			box_mask[b] |= (1 << n)

			_count_helper(board, row_mask, col_mask, box_mask, counter)

			board[r][c] = 0
			row_mask[r] &= ~(1 << n)
			col_mask[c] &= ~(1 << n)
			box_mask[b] &= ~(1 << n)

			if counter[0] >= 2:
				return
