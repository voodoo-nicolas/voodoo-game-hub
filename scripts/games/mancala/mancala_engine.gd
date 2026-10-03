extends RefCounted

## Standard Kalah rules. Board is 14 pits: 0-5 = P1's pits, 6 = P1's store,
## 7-12 = P2's pits, 13 = P2's store. Sowing skips the opponent's store,
## landing your last seed in your own store earns an extra turn, and landing
## it in one of your own empty pits captures that seed plus everything in
## the directly opposite pit.
const P1_STORE := 6
const P2_STORE := 13

var board: Array = []
var current_player: int = 1
var game_over: bool = false
var winner: int = 0

func reset() -> void:
	board = []
	for i in range(14):
		board.append(4)
	board[P1_STORE] = 0
	board[P2_STORE] = 0
	current_player = 1
	game_over = false
	winner = 0

func _player_pits(p: int) -> Array:
	return range(0, 6) if p == 1 else range(7, 13)

func _own_store(p: int) -> int:
	return P1_STORE if p == 1 else P2_STORE

func _opp_store(p: int) -> int:
	return P2_STORE if p == 1 else P1_STORE

func legal_pits(p: int) -> Array:
	var out: Array = []
	for i in _player_pits(p):
		if board[i] > 0:
			out.append(i)
	return out

## Returns {valid, extra_turn, captured (seed count, 0 if none), landed_in_store}.
func sow(pit: int) -> Dictionary:
	if not _player_pits(current_player).has(pit) or board[pit] <= 0:
		return {"valid": false}

	var seeds: int = board[pit]
	board[pit] = 0
	var idx := pit
	var opp_store: int = _opp_store(current_player)
	while seeds > 0:
		idx = (idx + 1) % 14
		if idx == opp_store:
			continue
		board[idx] += 1
		seeds -= 1

	var own_store: int = _own_store(current_player)
	var extra_turn := false
	var captured := 0

	if idx == own_store:
		extra_turn = true
	elif _player_pits(current_player).has(idx) and board[idx] == 1:
		var opposite: int = 12 - idx
		if board[opposite] > 0:
			captured = board[opposite] + board[idx]
			board[own_store] += captured
			board[idx] = 0
			board[opposite] = 0

	_check_game_over()
	if not extra_turn and not game_over:
		current_player = 3 - current_player

	return {"valid": true, "extra_turn": extra_turn, "captured": captured, "landed_in_store": idx == own_store}

func _check_game_over() -> void:
	if not legal_pits(1).is_empty() and not legal_pits(2).is_empty():
		return
	for i in range(0, 6):
		board[P1_STORE] += board[i]
		board[i] = 0
	for i in range(7, 13):
		board[P2_STORE] += board[i]
		board[i] = 0
	game_over = true
	if board[P1_STORE] > board[P2_STORE]:
		winner = 1
	elif board[P2_STORE] > board[P1_STORE]:
		winner = 2
	else:
		winner = 0

# ---------- computer opponent ----------

const _CPU_DEPTH := [1, 3, 6]
const _CPU_SLIP := [0.4, 0.1, 0.0]

func clone():
	var e = get_script().new()
	e.board = board.duplicate()
	e.current_player = current_player
	e.game_over = game_over
	e.winner = winner
	return e

## The pit the computer sows for the player to move (level 0..2).
func cpu_move(level: int, rng: RandomNumberGenerator) -> int:
	var pits := legal_pits(current_player)
	if pits.is_empty():
		return -1
	level = clampi(level, 0, 2)
	if rng.randf() < _CPU_SLIP[level]:
		return pits[rng.randi() % pits.size()]
	var me := current_player
	var best_score := -1000000
	var best: Array = []
	for p in pits:
		var e = clone()
		e.sow(p)
		var s: int = e._search(me, _CPU_DEPTH[level] - 1, -1000000, 1000000)
		if s > best_score:
			best_score = s
			best = [p]
		elif s == best_score:
			best.append(p)
	return best[rng.randi() % best.size()]

## Minimax from `me`'s side (an extra turn keeps the same player moving).
func _search(me: int, depth: int, alpha: int, beta: int) -> int:
	var diff: int = board[_own_store(me)] - board[_own_store(3 - me)]
	if game_over:
		return diff * 100 + (10000 if diff > 0 else (-10000 if diff < 0 else 0))
	if depth <= 0:
		return diff * 100
	var maximize := current_player == me
	var best := -1000000 if maximize else 1000000
	for p in legal_pits(current_player):
		var e = clone()
		e.sow(p)
		var v: int = e._search(me, depth - 1, alpha, beta)
		if maximize:
			best = maxi(best, v)
			alpha = maxi(alpha, v)
		else:
			best = mini(best, v)
			beta = mini(beta, v)
		if beta <= alpha:
			break
	return best
