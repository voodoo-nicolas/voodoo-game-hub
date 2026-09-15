extends RefCounted

## Turn order runs to each player's left, so the neighbor "to your right" is the
## previous player in seat order and "to your left" is the next one.

var num_players: int = 4
var current_player: int = 0
var three_man: int = -1  # -1 = unassigned

var tiebreak_pool: Array = []  # indices still rolling to determine who starts
var starter_decided: bool = false

func reset(players: int) -> void:
	num_players = max(players, 2)
	current_player = 0
	three_man = -1
	starter_decided = false
	tiebreak_pool = range(num_players)

func right_of(player: int) -> int:
	return (player - 1 + num_players) % num_players

func left_of(player: int) -> int:
	return (player + 1) % num_players

## Rolls 1 die for every player still in the tiebreak pool. Returns
## {rolls: {player_index: value}, pool: Array, resolved: bool, first_player: int}.
## Only the players tied for lowest carry over to the next call.
func roll_tiebreak() -> Dictionary:
	var rolls: Dictionary = {}
	for p in tiebreak_pool:
		rolls[p] = randi_range(1, 6)

	var lowest: int = 7
	for p in tiebreak_pool:
		lowest = min(lowest, rolls[p])

	var still_tied: Array = []
	for p in tiebreak_pool:
		if rolls[p] == lowest:
			still_tied.append(p)

	var resolved := still_tied.size() == 1
	if resolved:
		current_player = still_tied[0]
		starter_decided = true
	else:
		tiebreak_pool = still_tied

	return {
		"rolls": rolls,
		"pool": tiebreak_pool,
		"resolved": resolved,
		"first_player": current_player if resolved else -1,
	}

## Rolls 2 dice for the current player and resolves every Three Man rule.
## Returns {die1, die2, messages: PackedStringArray, continue_turn: bool}.
## continue_turn true = same player rolls again; false = advance to next player.
func roll_turn() -> Dictionary:
	var d1 := randi_range(1, 6)
	var d2 := randi_range(1, 6)
	var s := d1 + d2
	var is_double := d1 == d2
	var has_three := d1 == 3 or d2 == 3

	var messages: PackedStringArray = []
	var continue_turn := false
	var right := right_of(current_player)
	var left := left_of(current_player)

	if is_double and d1 == 3:
		# 3&3: always gives out 3 drinks; only changes 3 Man status if the
		# current 3 Man rolled it themselves (net no-op — they stay 3 Man).
		if three_man == -1:
			messages.append("No one is 3 Man yet — stays that way.")
		elif three_man == current_player:
			messages.append("%s is still 3 Man." % _name(current_player))
		else:
			messages.append("%s (3 Man) drinks twice." % _name(three_man))
		messages.append("Give out 3 drinks, your choice.")
		continue_turn = true
	elif is_double:
		messages.append("Doubles! Give out %d drinks, your choice." % d1)
		continue_turn = true
	elif has_three and s == 7:
		# 3&4: hybrid of the 3 Man trigger and the sum-of-7 "give right" rule.
		if three_man == -1:
			three_man = current_player
			messages.append("%s becomes 3 Man!" % _name(current_player))
		elif three_man == current_player:
			three_man = -1
			messages.append("%s is no longer 3 Man!" % _name(current_player))
		else:
			messages.append("%s (3 Man) drinks 1." % _name(three_man))
		messages.append("%s drinks 1 (to your right)." % _name(right))
		continue_turn = true
	elif has_three or s == 3:
		# Plain 3 trigger: a literal 3 on a die, or the 2&1 combo.
		if three_man == -1:
			three_man = current_player
			messages.append("%s becomes 3 Man!" % _name(current_player))
			continue_turn = false
		else:
			messages.append("%s (3 Man) drinks 1." % _name(three_man))
			continue_turn = true
	elif s == 7:
		messages.append("%s drinks 1 (to your right)." % _name(right))
		continue_turn = true
	elif s == 11:
		messages.append("%s drinks 1 (to your left)." % _name(left))
		continue_turn = true
	else:
		messages.append("Nothing happens.")
		continue_turn = false

	return {
		"die1": d1,
		"die2": d2,
		"messages": messages,
		"continue_turn": continue_turn,
	}

func advance_player() -> void:
	current_player = left_of(current_player)

func _name(player: int) -> String:
	return "Player %d" % (player + 1)
