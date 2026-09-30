extends RefCounted

## Farkle, you (0) vs the computer (1), first to 10,000. Roll six dice, set
## aside at least one scoring die, then roll the rest or bank your turn's
## points. A roll with nothing scoring ("farkle") loses the turn's points.
## Score all six dice ("hot dice") and you roll all six again.
##
## Scoring: 1 = 100, 5 = 50; three of a kind = face × 100 (three 1s = 1000),
## each extra die of the kind doubles it; 1-2-3-4-5-6 = 1500; three pairs =
## 1500. Pure logic, no Nodes.

const TARGET := 10000

var scores: Array = [0, 0]
var turn: int = 0
var dice: Array = []        # current roll (values), length = dice in hand
var kept: Array = []        # dice set aside this turn
var turn_points: int = 0
var winner: int = -1

func reset() -> void:
	scores = [0, 0]
	turn = 0
	winner = -1
	start_turn()

func start_turn() -> void:
	dice = []
	kept = []
	turn_points = 0

## Points for exactly these dice if every one of them scores, else -1.
static func score_of(sel: Array) -> int:
	if sel.is_empty():
		return -1
	var counts := [0, 0, 0, 0, 0, 0, 0]
	for v in sel:
		counts[v] += 1
	if sel.size() == 6:
		var ones := 0
		var pairs := 0
		for f in range(1, 7):
			if counts[f] == 1:
				ones += 1
			if counts[f] == 2:
				pairs += 1
		if ones == 6:
			return 1500
		if pairs == 3:
			return 1500
	var total := 0
	for f in range(1, 7):
		var n: int = counts[f]
		if n >= 3:
			var base := 1000 if f == 1 else f * 100
			total += base * (1 << (n - 3))
		elif n > 0:
			if f == 1:
				total += 100 * n
			elif f == 5:
				total += 50 * n
			else:
				return -1
	return total

## The highest-scoring set of dice in a roll (as values), or [] if farkle.
static func best_keep(roll_values: Array) -> Array:
	var best: Array = []
	var best_score := 0
	var n := roll_values.size()
	for mask in range(1, 1 << n):
		var sel: Array = []
		for i in n:
			if mask & (1 << i):
				sel.append(roll_values[i])
		var s := score_of(sel)
		if s > best_score or (s == best_score and s > 0 and sel.size() < best.size()):
			best_score = s
			best = sel
	return best

static func is_farkle(roll_values: Array) -> bool:
	return best_keep(roll_values).is_empty()

func dice_in_hand() -> int:
	return 6 - kept.size() if kept.size() < 6 else 6

## Rolls the dice not yet kept. Returns true if the roll farkled (the turn
## is then over and scores nothing).
func roll() -> bool:
	var n := 6 - kept.size()
	if n == 0:
		kept = []   # hot dice: roll all six again
		n = 6
	dice = []
	for i in n:
		dice.append(randi_range(1, 6))
	if is_farkle(dice):
		turn_points = 0
		return true
	return false

## Sets aside the dice at `indices` of the current roll. Returns false if
## they don't all score.
func keep(indices: Array) -> bool:
	var sel: Array = []
	for i in indices:
		sel.append(dice[i])
	var s := score_of(sel)
	if s <= 0:
		return false
	turn_points += s
	kept.append_array(sel)
	var rest: Array = []
	for i in dice.size():
		if not indices.has(i):
			rest.append(dice[i])
	dice = rest
	return true

func bank() -> void:
	scores[turn] += turn_points
	if scores[turn] >= TARGET:
		winner = turn
	end_turn()

func end_turn() -> void:
	start_turn()
	if winner == -1:
		turn = 1 - turn

## Computer: which dice to keep now (indices of the current roll).
func cpu_keep_indices() -> Array:
	var want := best_keep(dice)
	var out: Array = []
	var pool: Array = want.duplicate()
	for i in dice.size():
		if pool.has(dice[i]):
			pool.erase(dice[i])
			out.append(i)
	return out

## Computer: bank now? (after keeping)
func cpu_should_bank() -> bool:
	var left := 6 - kept.size()
	if left == 0:
		return false   # hot dice: always roll again
	var need: int = TARGET - scores[1]
	if turn_points >= need:
		return true
	var behind: bool = scores[0] - scores[1] > 2000
	var threshold := 300 if left <= 2 else (400 if left == 3 else 600)
	if behind:
		threshold += 200
	return turn_points >= threshold
