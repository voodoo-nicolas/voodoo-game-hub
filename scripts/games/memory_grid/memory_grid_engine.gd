extends RefCounted

## Memory Grid logic: a pattern of tiles lights up, then the player taps
## them from memory. Pure logic, tested headlessly.

const START_LIVES := 3
const MAX_SIDE := 7

var rng := RandomNumberGenerator.new()
var level: int = 1          # the level being played
var lives: int = START_LIVES
var side: int = 3
var target: Array = []      # tile indices to remember
var found: Array = []       # correct taps so far this round
var cleared: int = 0        # levels completed (the score)

func reset(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	level = 1
	lives = START_LIVES
	cleared = 0
	start_round()

func tile_count(lvl: int) -> int:
	return lvl + 2

## Smallest square grid where the pattern fills at most half the tiles.
func side_for(lvl: int) -> int:
	var tiles := tile_count(lvl)
	var s := 3
	while s < MAX_SIDE and tiles > s * s / 2:
		s += 1
	return s

## How long the pattern stays lit, in seconds.
func show_secs() -> float:
	return 1.0 + 0.3 * target.size()

func start_round() -> void:
	side = side_for(level)
	var all: Array = range(side * side)
	for i in range(all.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = all[i]
		all[i] = all[j]
		all[j] = t
	target = all.slice(0, mini(tile_count(level), side * side / 2))
	found = []

## One tap during recall. Returns "hit", "clear" (last tile found, level
## done), "miss", "over" (a miss with no lives left) or "ignored".
func tap(index: int) -> String:
	if found.has(index):
		return "ignored"
	if target.has(index):
		found.append(index)
		if found.size() == target.size():
			cleared += 1
			level += 1
			return "clear"
		return "hit"
	lives -= 1
	return "over" if lives <= 0 else "miss"
