extends RefCounted

## Bunco: six rounds, one per number 1-6. On your turn roll three dice again
## and again as long as you score. Each die showing the round's number is 1
## point; three of a kind is 5; three of the round's number is a BUNCO, worth
## 21 and the round. The first to 21 in a round wins it. Most rounds wins the
## game (points break ties). Pure logic, no Nodes.

const ROUNDS := 6
const ROUND_GOAL := 21
const BUNCO_POINTS := 21
const TRIPLE_POINTS := 5

var players: int = 2
var is_cpu: Array = []
var round_no: int = 1          # 1..6, and the number to roll
var round_points: Array = []   # this round
var total_points: Array = []   # whole game
var wins: Array = []           # rounds won
var turn: int = 0
var dice: Array = [1, 1, 1]
var last_kind: String = ""     # "bunco", "triple", "hits", "miss", "" at start of a turn
var last_points: int = 0
var round_winner: int = -1     # set when the last roll ended a round
var over: bool = false
var rolls_in_turn: int = 0

func new_game(n: int, cpu_players: Array) -> void:
	players = clampi(n, 2, 4)
	is_cpu = []
	round_points = []
	total_points = []
	wins = []
	for i in players:
		is_cpu.append(i < cpu_players.size() and bool(cpu_players[i]))
		round_points.append(0)
		total_points.append(0)
		wins.append(0)
	round_no = 1
	turn = 0
	dice = [1, 1, 1]
	last_kind = ""
	last_points = 0
	round_winner = -1
	over = false
	rolls_in_turn = 0

func roll() -> String:
	return roll_with([randi_range(1, 6), randi_range(1, 6), randi_range(1, 6)])

## Plays a roll with the given faces. Returns the kind: "bunco", "triple", "hits" or "miss".
func roll_with(faces: Array) -> String:
	if over:
		return "done"
	dice = faces
	rolls_in_turn += 1
	round_winner = -1
	var hits := 0
	for f in faces:
		if int(f) == round_no:
			hits += 1
	var kind := "miss"
	var pts := 0
	if hits == 3:
		kind = "bunco"
		pts = BUNCO_POINTS
	elif faces[0] == faces[1] and faces[1] == faces[2]:
		kind = "triple"
		pts = TRIPLE_POINTS
	elif hits > 0:
		kind = "hits"
		pts = hits
	last_kind = kind
	last_points = pts
	round_points[turn] += pts
	total_points[turn] += pts
	if kind == "bunco" or round_points[turn] >= ROUND_GOAL:
		_win_round(turn)
	elif kind == "miss":
		_next_turn()
	return kind

func _win_round(who: int) -> void:
	round_winner = who
	wins[who] += 1
	if round_no >= ROUNDS:
		over = true
		return
	round_no += 1
	for i in players:
		round_points[i] = 0
	_next_turn()

func _next_turn() -> void:
	turn = (turn + 1) % players
	rolls_in_turn = 0

## The player with the most round wins; points break ties. -1 if still tied.
func winner() -> int:
	var best := 0
	var tie := false
	for i in range(1, players):
		var a: int = wins[i] * 100000 + total_points[i]
		var b: int = wins[best] * 100000 + total_points[best]
		if a > b:
			best = i
			tie = false
		elif a == b:
			tie = true
	return -1 if tie else best

func to_dict() -> Dictionary:
	return {"players": players, "is_cpu": is_cpu, "round": round_no, "round_points": round_points, "total": total_points,
		"wins": wins, "turn": turn, "dice": dice, "kind": last_kind, "points": last_points, "over": over}

func from_dict(d: Dictionary) -> bool:
	if not d.has("wins"):
		return false
	players = clampi(int(d.get("players", 2)), 2, 4)
	is_cpu = []
	round_points = []
	total_points = []
	wins = []
	var cp = d.get("is_cpu", [])
	var rp = d.get("round_points", [])
	var tp = d.get("total", [])
	var wn = d.get("wins", [])
	for i in players:
		is_cpu.append(bool(cp[i]) if i < cp.size() else false)
		round_points.append(int(rp[i]) if i < rp.size() else 0)
		total_points.append(int(tp[i]) if i < tp.size() else 0)
		wins.append(int(wn[i]) if i < wn.size() else 0)
	round_no = clampi(int(d.get("round", 1)), 1, ROUNDS)
	turn = clampi(int(d.get("turn", 0)), 0, players - 1)
	dice = []
	for f in d.get("dice", [1, 1, 1]):
		dice.append(int(f))
	if dice.size() != 3:
		dice = [1, 1, 1]
	last_kind = str(d.get("kind", ""))
	last_points = int(d.get("points", 0))
	over = bool(d.get("over", false))
	round_winner = -1
	rolls_in_turn = 0
	return true
