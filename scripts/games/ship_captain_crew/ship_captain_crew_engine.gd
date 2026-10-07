extends RefCounted

## Ship, Captain, Crew: five dice, three rolls a turn. You need a 6 (the ship),
## then a 5 (the captain), then a 4 (the crew), in that order. They are set
## aside as they come. Once you have all three, the other two dice are your
## cargo: their total is your score for the turn, and you can keep each cargo
## die or roll it again with the rolls you have left. No crew, no score.
## Pure logic, no Nodes.

const ROUNDS := 5
const DICE := 5
const ROLLS := 3

var players: int = 2
var is_cpu: Array = []
var level: int = 1
var scores: Array = []
var turn: int = 0
var round_no: int = 1
var dice: Array = []         # 5 faces, 0 = not rolled yet
var locked: Array = []       # set aside as ship / captain / crew
var role: Array = []         # per die: "", "ship", "captain", "crew"
var hold: Array = []         # cargo dice the player keeps
var rolls_left: int = 0
var over: bool = false
var last_turn_score: int = -1   # score of the turn that just ended

func new_game(n: int, cpu_players: Array, lvl: int) -> void:
	players = clampi(n, 2, 4)
	level = clampi(lvl, 0, 2)
	is_cpu = []
	scores = []
	for i in players:
		is_cpu.append(i < cpu_players.size() and bool(cpu_players[i]))
		scores.append(0)
	turn = 0
	round_no = 1
	over = false
	last_turn_score = -1
	_start_turn()

func _start_turn() -> void:
	dice = []
	locked = []
	role = []
	hold = []
	for i in DICE:
		dice.append(0)
		locked.append(false)
		role.append("")
		hold.append(false)
	rolls_left = ROLLS

func has(name: String) -> bool:
	return role.has(name)

func has_crew() -> bool:
	return has("crew")

func rolled() -> bool:
	return rolls_left < ROLLS

## Cargo dice: the ones not set aside, once the crew is aboard.
func cargo_indices() -> Array:
	var out: Array = []
	if not has_crew():
		return out
	for i in DICE:
		if not locked[i]:
			out.append(i)
	return out

func cargo() -> int:
	var t := 0
	for i in cargo_indices():
		t += int(dice[i])
	return t

func roll() -> bool:
	return roll_with([])

## Rolls every die that isn't set aside or held. `faces` (optional, for tests) gives the values in order.
func roll_with(faces: Array) -> bool:
	if over or rolls_left <= 0:
		return false
	var k := 0
	for i in DICE:
		if locked[i] or hold[i]:
			continue
		dice[i] = int(faces[k]) if k < faces.size() else randi_range(1, 6)
		k += 1
	rolls_left -= 1
	_auto_lock()
	return true

func _lock_one(value: int, name: String) -> void:
	for i in DICE:
		if not locked[i] and int(dice[i]) == value:
			locked[i] = true
			role[i] = name
			hold[i] = false
			return

func _auto_lock() -> void:
	if not has("ship"):
		_lock_one(6, "ship")
	if has("ship") and not has("captain"):
		_lock_one(5, "captain")
	if has("captain") and not has("crew"):
		_lock_one(4, "crew")

## Keep (or release) a cargo die for the next roll.
func toggle_hold(i: int) -> bool:
	if not has_crew() or locked[i] or int(dice[i]) == 0 or rolls_left <= 0:
		return false
	hold[i] = not hold[i]
	return true

## The turn ends when the rolls run out, or the player stops with a crew aboard.
func can_stop() -> bool:
	return has_crew() and rolled()

func turn_done() -> bool:
	return rolls_left <= 0

## Banks the cargo (0 with no crew) and passes the dice.
func end_turn() -> int:
	var pts := cargo()
	scores[turn] += pts
	last_turn_score = pts
	turn += 1
	if turn >= players:
		turn = 0
		round_no += 1
		if round_no > ROUNDS:
			over = true
			return pts
	_start_turn()
	return pts

func winner() -> int:
	var best := 0
	var tie := false
	for i in range(1, players):
		if scores[i] > scores[best]:
			best = i
			tie = false
		elif scores[i] == scores[best]:
			tie = true
	return -1 if tie else best

## The computer plays its whole decision: sets holds and returns "roll" or "stop".
func cpu_decide() -> String:
	if not rolled():
		return "roll"
	if not has_crew():
		return "roll" if rolls_left > 0 else "stop"
	var stop_at: int = [7, 8, 9][level]
	if rolls_left == 0 or cargo() >= stop_at + (2 if rolls_left == 1 and level == 2 else 0):
		return "stop"
	# Keep the high dice, roll the low ones again.
	var keep_from: int = 4 if rolls_left >= 2 else 5
	for i in cargo_indices():
		hold[i] = int(dice[i]) >= keep_from
	var all_held := true
	for i in cargo_indices():
		if not hold[i]:
			all_held = false
	return "stop" if all_held else "roll"

func to_dict() -> Dictionary:
	return {"players": players, "is_cpu": is_cpu, "level": level, "scores": scores, "turn": turn, "round": round_no,
		"dice": dice, "locked": locked, "role": role, "hold": hold, "rolls_left": rolls_left, "over": over}

func from_dict(d: Dictionary) -> bool:
	if not d.has("scores"):
		return false
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
	round_no = clampi(int(d.get("round", 1)), 1, ROUNDS + 1)
	over = bool(d.get("over", false))
	_start_turn()
	var dd = d.get("dice", [])
	var lk = d.get("locked", [])
	var ro = d.get("role", [])
	var hd = d.get("hold", [])
	if dd.size() == DICE and lk.size() == DICE and ro.size() == DICE and hd.size() == DICE:
		for i in DICE:
			dice[i] = int(dd[i])
			locked[i] = bool(lk[i])
			role[i] = str(ro[i])
			hold[i] = bool(hd[i])
		rolls_left = clampi(int(d.get("rolls_left", ROLLS)), 0, ROLLS)
	return true
