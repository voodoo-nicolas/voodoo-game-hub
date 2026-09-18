extends RefCounted

## Dots and Boxes (a.k.a. "La Pipopipette", invented by Édouard Lucas). Players
## alternate drawing one edge between two orthogonally adjacent dots; whoever
## draws the 4th edge of a 1x1 box claims it and immediately moves again
## (closing two boxes with a single shared edge grants both boxes and still
## only one extra turn). Most boxes when every edge is drawn wins.

var rows: int = 5
var cols: int = 5

## h_lines[r][c] is the horizontal edge between dot(r,c) and dot(r,c+1),
## for r in 0..rows, c in 0..cols-1. 0 = undrawn, else the player who drew it.
var h_lines: Array = []
## v_lines[r][c] is the vertical edge between dot(r,c) and dot(r+1,c),
## for r in 0..rows-1, c in 0..cols. 0 = undrawn, else the player who drew it.
var v_lines: Array = []
## box_owner[r][c]: 0 = unclaimed, else the player who closed that box.
var box_owner: Array = []

var current_player: int = 1
var scores: Dictionary = {1: 0, 2: 0}
var game_over: bool = false
var winner: int = 0  # 0 = tie, else 1 or 2

func reset(p_rows: int = 5, p_cols: int = 5) -> void:
	rows = p_rows
	cols = p_cols
	h_lines = []
	for r in range(rows + 1):
		h_lines.append([])
		for c in range(cols):
			h_lines[r].append(0)
	v_lines = []
	for r in range(rows):
		v_lines.append([])
		for c in range(cols + 1):
			v_lines[r].append(0)
	box_owner = []
	for r in range(rows):
		var row: Array = []
		for c in range(cols):
			row.append(0)
		box_owner.append(row)
	current_player = 1
	scores = {1: 0, 2: 0}
	game_over = false
	winner = 0

func is_h_taken(r: int, c: int) -> bool:
	return h_lines[r][c] != 0

func is_v_taken(r: int, c: int) -> bool:
	return v_lines[r][c] != 0

func total_boxes() -> int:
	return rows * cols

## Plays one edge for the current player. Returns
## {valid, boxes_completed, extra_turn, mover, completed_boxes: Array[Vector2i]}.
func play_line(orientation: String, r: int, c: int) -> Dictionary:
	if game_over:
		return {"valid": false}
	if orientation == "h":
		if r < 0 or r > rows or c < 0 or c >= cols or is_h_taken(r, c):
			return {"valid": false}
		h_lines[r][c] = current_player
	elif orientation == "v":
		if r < 0 or r >= rows or c < 0 or c > cols or is_v_taken(r, c):
			return {"valid": false}
		v_lines[r][c] = current_player
	else:
		return {"valid": false}

	var completed: Array = _newly_completed_boxes(orientation, r, c)
	var mover := current_player
	for box in completed:
		box_owner[box.x][box.y] = mover
		scores[mover] += 1

	if completed.is_empty():
		current_player = 2 if current_player == 1 else 1

	if scores[1] + scores[2] >= total_boxes():
		game_over = true
		if scores[1] > scores[2]:
			winner = 1
		elif scores[2] > scores[1]:
			winner = 2
		else:
			winner = 0

	return {
		"valid": true,
		"boxes_completed": completed.size(),
		"extra_turn": not completed.is_empty(),
		"mover": mover,
		"completed_boxes": completed,
	}

func _is_box_complete(br: int, bc: int) -> bool:
	return h_lines[br][bc] != 0 and h_lines[br + 1][bc] != 0 \
		and v_lines[br][bc] != 0 and v_lines[br][bc + 1] != 0

## The box(es) (at most 2) that touch this edge -- shared by completion
## detection and the AI's "would this give a box away" safety check.
func adjacent_boxes(orientation: String, r: int, c: int) -> Array:
	var candidates: Array = []
	if orientation == "h":
		if r - 1 >= 0:
			candidates.append(Vector2i(r - 1, c))
		if r < rows:
			candidates.append(Vector2i(r, c))
	else:
		if c - 1 >= 0:
			candidates.append(Vector2i(r, c - 1))
		if c < cols:
			candidates.append(Vector2i(r, c))
	return candidates

func _newly_completed_boxes(orientation: String, r: int, c: int) -> Array:
	var completed: Array = []
	for box in adjacent_boxes(orientation, r, c):
		if box_owner[box.x][box.y] == 0 and _is_box_complete(box.x, box.y):
			completed.append(box)
	return completed

func box_edge_count(br: int, bc: int) -> int:
	var n := 0
	if h_lines[br][bc] != 0:
		n += 1
	if h_lines[br + 1][bc] != 0:
		n += 1
	if v_lines[br][bc] != 0:
		n += 1
	if v_lines[br][bc + 1] != 0:
		n += 1
	return n

func available_moves() -> Array:
	var moves: Array = []
	for r in range(rows + 1):
		for c in range(cols):
			if not is_h_taken(r, c):
				moves.append({"o": "h", "r": r, "c": c})
	for r in range(rows):
		for c in range(cols + 1):
			if not is_v_taken(r, c):
				moves.append({"o": "v", "r": r, "c": c})
	return moves

## Non-mutating: how many boxes this move would complete right now.
func peek_completions(orientation: String, r: int, c: int) -> int:
	var n: int
	if orientation == "h":
		if is_h_taken(r, c):
			return 0
		h_lines[r][c] = -1
		n = _newly_completed_boxes("h", r, c).size()
		h_lines[r][c] = 0
	else:
		if is_v_taken(r, c):
			return 0
		v_lines[r][c] = -1
		n = _newly_completed_boxes("v", r, c).size()
		v_lines[r][c] = 0
	return n

## A move is "safe" if it doesn't hand the opponent a box they can claim next
## turn -- i.e. it doesn't bring any adjacent box's edge count from 2 up to 3.
func is_safe_move(orientation: String, r: int, c: int) -> bool:
	for box in adjacent_boxes(orientation, r, c):
		if box_edge_count(box.x, box.y) == 2:
			return false
	return true

## Simple but not naive AI: take any free box(es) greedily, otherwise play a
## move that doesn't give the opponent a box, otherwise (only reachable deep
## in the endgame, once every remaining move sacrifices something) pick at
## random -- true double-cross-chain-counting play is out of scope for this.
func pick_ai_move() -> Dictionary:
	var moves: Array = available_moves()
	var best: Variant = null
	var best_n := 0
	for m in moves:
		var n: int = peek_completions(m.o, m.r, m.c)
		if n > best_n:
			best_n = n
			best = m
	if best != null:
		return best
	var safe: Array = []
	for m in moves:
		if is_safe_move(m.o, m.r, m.c):
			safe.append(m)
	if not safe.is_empty():
		return safe[randi() % safe.size()]
	return moves[randi() % moves.size()]
