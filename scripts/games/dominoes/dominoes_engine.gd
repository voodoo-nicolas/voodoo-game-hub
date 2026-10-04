extends RefCounted

## Dominoes, the Draw game with a double-six set. Each player gets 7 tiles
## (5 with three or four players); the rest form the boneyard. Play a tile
## that matches an open end of the line; if you can't, draw until you can
## (or pass once the boneyard is empty). Empty your hand to win the round
## and score every pip left in the other hands; a blocked round goes to the
## lightest hand. First to the target wins. Pure logic, no Nodes.

const TARGET := 100

var players: int = 2
var hands: Array = []      # per player: Array of [a, b]
var boneyard: Array = []
var chain: Array = []      # tiles left to right, oriented so ends touch
var turn: int = 0
var scores: Array = []
var passes: int = 0        # passes in a row (blocked when everyone passes)
var round_over := false
var round_winner: int = -1
var round_points: int = 0
var starter: int = 0
## Tiles added at the left end (the first tile is chain[left_count]).
var left_count: int = 0

func new_game(n: int, rng: RandomNumberGenerator) -> void:
	players = n
	scores = []
	scores.resize(n)
	scores.fill(0)
	new_round(rng)

func new_round(rng: RandomNumberGenerator) -> void:
	var set_: Array = []
	for a in 7:
		for b in range(a, 7):
			set_.append([a, b])
	for i in range(set_.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = set_[i]
		set_[i] = set_[j]
		set_[j] = t
	var per := 7 if players == 2 else 5
	hands = []
	for p in players:
		hands.append(set_.slice(p * per, (p + 1) * per))
	boneyard = set_.slice(players * per)
	chain = []
	left_count = 0
	passes = 0
	round_over = false
	round_winner = -1
	round_points = 0
	# The highest double starts (else the heaviest tile).
	var best := -1
	starter = 0
	for p in players:
		for t in hands[p]:
			var v: int = (100 + t[0]) if t[0] == t[1] else t[0] + t[1]
			if v > best:
				best = v
				starter = p
	turn = starter

func left_end() -> int:
	return chain[0][0] if not chain.is_empty() else -1

func right_end() -> int:
	return chain[-1][1] if not chain.is_empty() else -1

## Sides (0 = left, 1 = right) where tile t can go.
func sides_for(t: Array) -> Array:
	if chain.is_empty():
		return [1]
	var out: Array = []
	if t[0] == left_end() or t[1] == left_end():
		out.append(0)
	if t[0] == right_end() or t[1] == right_end():
		out.append(1)
	return out

func playable(p: int) -> Array:
	var out: Array = []
	for i in hands[p].size():
		if not sides_for(hands[p][i]).is_empty():
			out.append(i)
	return out

## Plays hand[p][i] on `side`; false if it doesn't fit.
func play(p: int, i: int, side: int) -> bool:
	if round_over or p != turn or i < 0 or i >= hands[p].size():
		return false
	var t: Array = hands[p][i]
	if not side in sides_for(t):
		return false
	hands[p].remove_at(i)
	if chain.is_empty():
		chain.append(t.duplicate())
	elif side == 0:
		left_count += 1
		chain.push_front([t[1], t[0]] if t[1] != left_end() else t.duplicate())
	else:
		chain.append([t[0], t[1]] if t[0] == right_end() else [t[1], t[0]])
	passes = 0
	if hands[p].is_empty():
		_end_round(p)
	else:
		turn = (turn + 1) % players
	return true

## Draws one tile for the player to move; false if the boneyard is empty.
func draw() -> bool:
	if boneyard.is_empty():
		return false
	hands[turn].append(boneyard.pop_back())
	return true

## The player to move can't play and can't draw.
func pass_turn() -> void:
	passes += 1
	if passes >= players:
		# Blocked: the lightest hand wins the pips of the others.
		var best := 0
		for p in players:
			if pips(p) < pips(best):
				best = p
		_end_round(best)
		return
	turn = (turn + 1) % players

func pips(p: int) -> int:
	var s := 0
	for t in hands[p]:
		s += t[0] + t[1]
	return s

func _end_round(w: int) -> void:
	round_over = true
	round_winner = w
	round_points = 0
	for p in players:
		if p != w:
			round_points += pips(p)
	if passes >= players:
		round_points -= pips(w)
	scores[w] += round_points

func game_winner() -> int:
	for p in players:
		if scores[p] >= TARGET:
			return p
	return -1

## Computer: the heaviest tile that fits (doubles first), else -1.
func cpu_choice(p: int) -> Array:
	var best: Array = []
	var best_v := -1
	for i in playable(p):
		var t: Array = hands[p][i]
		var v: int = t[0] + t[1] + (10 if t[0] == t[1] else 0)
		if v > best_v:
			best_v = v
			best = [i, sides_for(t)[0]]
	return best
