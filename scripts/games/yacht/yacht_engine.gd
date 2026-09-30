extends RefCounted

## Yacht Dice (solo). Roll five dice up to three times per turn, holding any
## you like, then score them in one of 13 boxes. Each box is used once.
## 63+ in the upper section earns a 35-point bonus; extra five-of-a-kinds
## after a scored Yacht are worth 100 each. Pure logic, no Nodes.

const CATEGORIES := ["ones", "twos", "threes", "fours", "fives", "sixes",
	"three_kind", "four_kind", "full_house", "small_straight", "large_straight", "yacht", "chance"]
const UPPER_BONUS_AT := 63
const UPPER_BONUS := 35

var dice: Array = [1, 1, 1, 1, 1]
var held: Array = [false, false, false, false, false]
var rolls_left: int = 3
var scores: Dictionary = {}   # category -> points (absent = unused)
var yacht_bonus: int = 0

func reset() -> void:
	scores = {}
	yacht_bonus = 0
	_new_turn()

func _new_turn() -> void:
	held = [false, false, false, false, false]
	rolls_left = 3

func can_roll() -> bool:
	return rolls_left > 0 and not is_over()

func roll() -> bool:
	if not can_roll():
		return false
	for i in 5:
		if rolls_left == 3 or not held[i]:
			dice[i] = randi_range(1, 6)
	rolls_left -= 1
	return true

func toggle_hold(i: int) -> void:
	if rolls_left < 3 and rolls_left > 0:
		held[i] = not held[i]

func has_rolled() -> bool:
	return rolls_left < 3

static func score_for(cat: String, d: Array) -> int:
	var counts := [0, 0, 0, 0, 0, 0, 0]
	var total := 0
	for v in d:
		counts[v] += 1
		total += v
	var idx := CATEGORIES.find(cat)
	if idx < 6:
		return counts[idx + 1] * (idx + 1)
	match cat:
		"three_kind":
			return total if counts.max() >= 3 else 0
		"four_kind":
			return total if counts.max() >= 4 else 0
		"full_house":
			return 25 if (counts.has(3) and counts.has(2)) or counts.has(5) else 0
		"small_straight":
			for start in [1, 2, 3]:
				if counts[start] > 0 and counts[start + 1] > 0 and counts[start + 2] > 0 and counts[start + 3] > 0:
					return 30
			return 0
		"large_straight":
			var s: Array = d.duplicate()
			s.sort()
			return 40 if s == [1, 2, 3, 4, 5] or s == [2, 3, 4, 5, 6] else 0
		"yacht":
			return 50 if counts.has(5) else 0
		"chance":
			return total
	return 0

func is_yacht(d: Array) -> bool:
	return d.count(d[0]) == 5

func use(cat: String) -> bool:
	if scores.has(cat) or not has_rolled():
		return false
	if is_yacht(dice) and scores.get("yacht", 0) == 50:
		yacht_bonus += 100
	scores[cat] = score_for(cat, dice)
	_new_turn()
	return true

func upper_total() -> int:
	var t := 0
	for i in 6:
		t += scores.get(CATEGORIES[i], 0)
	return t

func total() -> int:
	var t := yacht_bonus
	for c in scores:
		t += scores[c]
	if upper_total() >= UPPER_BONUS_AT:
		t += UPPER_BONUS
	return t

func is_over() -> bool:
	return scores.size() == CATEGORIES.size()
