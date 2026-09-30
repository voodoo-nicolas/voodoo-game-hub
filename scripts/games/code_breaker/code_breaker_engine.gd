extends RefCounted

## Code Breaker: guess a hidden code of 4 colours (6 to choose from, repeats
## allowed) in 10 tries. Each guess scores "exact" (right colour, right spot)
## and "near" (right colour, wrong spot). Pure logic, no Nodes.

const SLOTS := 4
const COLORS := 6
const MAX_GUESSES := 10

var secret: Array = []
var guesses: Array = []   # [{code: Array, exact: int, near: int}]
var solved: bool = false

func reset(fixed_secret: Array = []) -> void:
	secret = fixed_secret.duplicate()
	if secret.is_empty():
		for i in SLOTS:
			secret.append(randi() % COLORS)
	guesses.clear()
	solved = false

static func score(code: Array, target: Array) -> Vector2i:
	var exact := 0
	var code_left: Array = []
	var target_left: Array = []
	for i in SLOTS:
		if code[i] == target[i]:
			exact += 1
		else:
			code_left.append(code[i])
			target_left.append(target[i])
	var near := 0
	for c in code_left:
		var k := target_left.find(c)
		if k >= 0:
			near += 1
			target_left.remove_at(k)
	return Vector2i(exact, near)

func is_over() -> bool:
	return solved or guesses.size() >= MAX_GUESSES

func submit(code: Array) -> bool:
	if is_over() or code.size() != SLOTS or code.has(-1):
		return false
	var s := score(code, secret)
	guesses.append({"code": code.duplicate(), "exact": s.x, "near": s.y})
	solved = s.x == SLOTS
	return true
