extends RefCounted

## Shut the Box: tiles 1-9 start up. Roll two dice and flip down any up tiles
## that add up to the roll. Once 7, 8 and 9 are all down you may roll a
## single die instead. When no tiles add up to the roll the round is over and
## the tiles still up are your score -- lower is better, and flipping every
## tile ("shutting the box") wins outright. Pure logic, no Nodes.

const TILES := 9

var up: Array = []      # up[n] for n in 1..9 (index 0 unused)
var dice: Array = []    # the last roll: one or two values
var total: int = 0      # what the tiles must add up to this roll (0 = not rolled)

func reset() -> void:
	up = [false]
	for n in TILES:
		up.append(true)
	dice = []
	total = 0

func can_roll_one_die() -> bool:
	return not up[7] and not up[8] and not up[9]

func roll(one_die: bool = false) -> int:
	dice = [randi_range(1, 6)] if one_die and can_roll_one_die() else [randi_range(1, 6), randi_range(1, 6)]
	total = 0
	for d in dice:
		total += d
	return total

## Every set of up tiles that adds up to `t` (each as an ascending Array).
func combos(t: int) -> Array:
	var out: Array = []
	_find(t, 1, [], out)
	return out

func _find(left: int, from: int, picked: Array, out: Array) -> void:
	if left == 0:
		out.append(picked.duplicate())
		return
	for n in range(from, mini(left, TILES) + 1):
		if up[n]:
			picked.append(n)
			_find(left - n, n + 1, picked, out)
			picked.pop_back()

func can_play() -> bool:
	return total > 0 and not combos(total).is_empty()

## Flips the tiles if they're all up and add up to the roll.
func flip(tiles: Array) -> bool:
	var sum := 0
	for n in tiles:
		if n < 1 or n > TILES or not up[n] or tiles.count(n) > 1:
			return false
		sum += n
	if sum != total:
		return false
	for n in tiles:
		up[n] = false
	total = 0
	return true

func score() -> int:
	var s := 0
	for n in range(1, TILES + 1):
		if up[n]:
			s += n
	return s

func is_shut() -> bool:
	return score() == 0

## The computer's pick: knock down the highest tiles first (they're the
## hardest to get rid of later), using as few tiles as possible.
func best_combo() -> Array:
	var best: Array = []
	for c in combos(total):
		if best.is_empty() or c.max() > best.max() or (c.max() == best.max() and c.size() < best.size()):
			best = c
	return best

## The computer rolls one die when it may and what's left is small.
func cpu_wants_one_die() -> bool:
	return can_roll_one_die() and score() <= 6
