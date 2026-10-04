extends RefCounted

## Stack Tower: a slab slides back and forth above the tower; tap to drop
## it. Whatever hangs over the edge of the slab below is sliced off, so the
## tower gets narrower -- unless the drop is perfect. Miss completely and
## it's over. Pure logic in "world" units (the tower is WIDTH wide).

const WIDTH := 100.0
const PERFECT := 2.5          # within this, a drop counts as perfect (snaps)
const GROW_AFTER := 3         # perfect drops in a row before the slab grows back
const GROW := 6.0
const SPEED0 := 55.0
const SPEED_UP := 2.2

var layers: Array = []        # [x, w] bottom to top
var cur_x: float = 0.0
var cur_w: float = WIDTH
var dir: float = 1.0
var streak: int = 0
var best_streak: int = 0
var score: int = 0
var over := false
var last_cut: Array = []      # [x, w] of the piece sliced off, for the falling animation

func reset() -> void:
	layers = [[0.0, WIDTH]]
	cur_w = WIDTH
	score = 0
	streak = 0
	best_streak = 0
	over = false
	_spawn()

func _spawn() -> void:
	dir = 1.0 if layers.size() % 2 == 0 else -1.0
	# Start just off one side, sliding in.
	cur_x = -cur_w * 0.9 if dir > 0 else WIDTH - cur_w * 0.1

func speed() -> float:
	return SPEED0 + SPEED_UP * minf(score, 40.0)

func step(dt: float) -> void:
	if over:
		return
	cur_x += dir * speed() * dt
	var lo := -cur_w * 0.9
	var hi := WIDTH - cur_w * 0.1
	if cur_x > hi:
		cur_x = hi
		dir = -1.0
	elif cur_x < lo:
		cur_x = lo
		dir = 1.0

## Drops the slab. Returns "perfect", "cut" or "miss".
func drop() -> String:
	if over:
		return "miss"
	var top: Array = layers[-1]
	var left := maxf(cur_x, top[0])
	var right := minf(cur_x + cur_w, top[0] + top[1])
	if right - left <= 0.0:
		over = true
		last_cut = [cur_x, cur_w]
		return "miss"
	var result := "cut"
	if absf(cur_x - top[0]) <= PERFECT:
		result = "perfect"
		left = top[0]
		right = top[0] + top[1]
		last_cut = []
		streak += 1
		best_streak = maxi(best_streak, streak)
		if streak >= GROW_AFTER:
			# A run of perfect drops wins some width back.
			var grow := minf(GROW, WIDTH - (right - left))
			left = maxf(0.0, left - grow / 2.0)
			right = minf(WIDTH, left + top[1] + grow)
	else:
		streak = 0
		if cur_x < top[0]:
			last_cut = [cur_x, top[0] - cur_x]
		else:
			last_cut = [right, cur_x + cur_w - right]
	layers.append([left, right - left])
	cur_w = right - left
	score += 1
	_spawn()
	return result
