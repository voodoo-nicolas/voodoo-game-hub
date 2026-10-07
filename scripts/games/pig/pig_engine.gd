extends RefCounted

## Pig: roll a die and keep adding to your turn total, or hold to bank it.
## Roll a 1 and the turn total is lost. First to the goal wins. Big Pig rolls
## two dice: a single 1 ends the turn, double 1s wipe your whole score, any
## other roll adds both dice. Pure logic, no Nodes.

const GOALS := [50, 100]

var variant: String = "pig"      # "pig" (one die) or "big" (two dice)
var goal: int = 100
var players: int = 2
var is_cpu: Array = []           # per player
var level: int = 1               # computer's skill: 0 easy, 1 normal, 2 hard
var scores: Array = []
var turn: int = 0
var turn_total: int = 0
var dice: Array = []             # the last roll
var last: String = ""            # "ok", "bust", "snake" after a roll, "" at turn start
var over: bool = false
var winner: int = -1
var rolls_this_turn: int = 0

func new_game(v: String, g: int, n: int, cpu_players: Array, lvl: int) -> void:
	variant = "big" if v == "big" else "pig"
	goal = g
	players = clampi(n, 2, 4)
	is_cpu = []
	scores = []
	for i in players:
		is_cpu.append(i < cpu_players.size() and bool(cpu_players[i]))
		scores.append(0)
	level = clampi(lvl, 0, 2)
	turn = 0
	turn_total = 0
	dice = []
	last = ""
	over = false
	winner = -1
	rolls_this_turn = 0

func dice_count() -> int:
	return 2 if variant == "big" else 1

func _end_turn() -> void:
	turn_total = 0
	rolls_this_turn = 0
	turn = (turn + 1) % players

## Rolls (the game supplies the faces so it can animate and test deterministically
## with roll_with). Returns "ok", "bust" (turn over, turn total lost) or "snake" (Big Pig only).
func roll() -> String:
	var faces: Array = []
	for i in dice_count():
		faces.append(randi_range(1, 6))
	return roll_with(faces)

func roll_with(faces: Array) -> String:
	if over:
		return "done"
	dice = faces
	rolls_this_turn += 1
	var ones := 0
	var sum := 0
	for f in faces:
		sum += int(f)
		if int(f) == 1:
			ones += 1
	if variant == "big" and ones == 2:
		last = "snake"
		scores[turn] = 0
		_end_turn()
	elif ones > 0:
		last = "bust"
		_end_turn()
	else:
		last = "ok"
		turn_total += sum
	return last

func hold() -> void:
	if over or turn_total <= 0:
		return
	scores[turn] += turn_total
	last = ""
	if scores[turn] >= goal:
		over = true
		winner = turn
		turn_total = 0
		return
	_end_turn()

## Would a player holding right now be at or past the goal?
func can_win_now() -> bool:
	return scores[turn] + turn_total >= goal

func best_other_score() -> int:
	var b := 0
	for i in players:
		if i != turn:
			b = maxi(b, int(scores[i]))
	return b

## The computer's decision for the current turn: true = hold.
func cpu_should_hold() -> bool:
	if turn_total <= 0:
		return false
	if can_win_now():
		return true
	var base: int = 20 if variant == "pig" else 25
	match level:
		0:
			base = 12 if variant == "pig" else 16
		1:
			pass
		2:
			var lead := int(scores[turn]) - best_other_score()
			if best_other_score() + 20 >= goal:
				return false   # they're about to win: go for it
			if lead >= 25:
				base -= 6
			elif lead <= -25:
				base += 6
	return turn_total >= base

func to_dict() -> Dictionary:
	return {"variant": variant, "goal": goal, "players": players, "is_cpu": is_cpu, "level": level, "scores": scores,
		"turn": turn, "turn_total": turn_total, "dice": dice, "last": last, "over": over, "winner": winner,
		"rolls": rolls_this_turn}

func from_dict(d: Dictionary) -> bool:
	if not d.has("scores"):
		return false
	variant = "big" if str(d.get("variant", "pig")) == "big" else "pig"
	goal = int(d.get("goal", 100))
	players = clampi(int(d.get("players", 2)), 2, 4)
	level = clampi(int(d.get("level", 1)), 0, 2)
	is_cpu = []
	scores = []
	var cp = d.get("is_cpu", [])
	var sc = d.get("scores", [])
	for i in players:
		is_cpu.append(bool(cp[i]) if i < cp.size() else false)
		scores.append(int(sc[i]) if i < sc.size() else 0)
	turn = clampi(int(d.get("turn", 0)), 0, players - 1)
	turn_total = int(d.get("turn_total", 0))
	dice = []
	for f in d.get("dice", []):
		dice.append(int(f))
	last = str(d.get("last", ""))
	over = bool(d.get("over", false))
	winner = int(d.get("winner", -1))
	rolls_this_turn = int(d.get("rolls", 0))
	return true
