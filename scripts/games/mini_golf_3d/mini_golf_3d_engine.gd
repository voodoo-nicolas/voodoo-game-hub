extends RefCounted

## Mini Golf 3D: the course list and scoring (no Nodes; headless-testable).
## The holes themselves are built in mini_golf_3d_world.gd from its piece kit.

const HOLES := [
	{"name": "Up the Hill", "par": 2},
	{"name": "Windmill Lane", "par": 3},
	{"name": "Dogleg Dash", "par": 3},
	{"name": "Double Decker", "par": 3},
	{"name": "Slide Gates", "par": 3},
	{"name": "Cloud Volcano", "par": 4},
	{"name": "Loop the Loop", "par": 3},
	{"name": "Sandy Shores", "par": 3},
	{"name": "Grand Finale", "par": 4},
]
const MAX_STROKES := 10   # the ball is picked up after this many

var scores: Array = []    # strokes per finished hole

func reset() -> void:
	scores.clear()

func hole() -> int:
	return scores.size()

func done() -> bool:
	return scores.size() >= HOLES.size()

func record(strokes: int) -> void:
	scores.append(strokes)

func total() -> int:
	var t := 0
	for s in scores:
		t += int(s)
	return t

func par_so_far() -> int:
	var p := 0
	for k in scores.size():
		p += int(HOLES[k].par)
	return p

static func course_par() -> int:
	var p := 0
	for h in HOLES:
		p += int(h.par)
	return p

## English key for the result of one hole (translate at display time).
static func score_name(strokes: int, par: int) -> String:
	if strokes == 1:
		return "Hole in one!"
	match strokes - par:
		-3: return "Albatross!"
		-2: return "Eagle!"
		-1: return "Birdie!"
		0: return "Par"
		1: return "Bogey"
		2: return "Double bogey"
	return "Keep going!"
