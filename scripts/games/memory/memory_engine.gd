extends RefCounted

const NUM_PAIRS := 8  # 16 cards total, 4x4 grid

var deck: Array = []      # symbol id (0..NUM_PAIRS-1) per card position
var matched: Array = []   # bool per position
var flipped: Array = []   # indices currently face-up but not yet resolved (0, 1, or 2)
var moves: int = 0

func reset() -> void:
	deck = []
	for s in range(NUM_PAIRS):
		deck.append(s)
		deck.append(s)
	deck.shuffle()

	matched = []
	for i in range(deck.size()):
		matched.append(false)
	flipped = []
	moves = 0

func is_over() -> bool:
	for m in matched:
		if not m:
			return false
	return true

## Returns "first" (one card now face-up, waiting for a second), "match" (pair found),
## "mismatch" (caller should show both then call resolve_mismatch() after a delay), or
## "ignored" (already matched, already flipped, or a mismatch is still pending resolution).
func flip(index: int) -> String:
	if matched[index] or flipped.has(index) or flipped.size() >= 2:
		return "ignored"

	flipped.append(index)
	if flipped.size() == 1:
		return "first"

	moves += 1
	var a: int = flipped[0]
	var b: int = flipped[1]
	if deck[a] == deck[b]:
		matched[a] = true
		matched[b] = true
		flipped = []
		return "match"
	return "mismatch"

func resolve_mismatch() -> void:
	flipped = []
