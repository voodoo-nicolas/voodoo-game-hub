extends RefCounted

## Bird Hop: tap to flap, glide through the gaps between the pillars. Each
## pillar passed scores a point; touching one (or the ground) ends the run.
## Pure simulation in a fixed 600×1000 field.

const FIELD := Vector2(600, 1000)
const GROUND := 900.0
const BIRD_X := 170.0
const BIRD_R := 22.0
const GRAVITY := 2300.0
const FLAP := -720.0
const PILLAR_W := 96.0
const SPACING := 330.0

var bird_y: float = 450.0
var vel: float = 0.0
var pillars: Array = []     # [{x: float, gap_y: float, gap: float, scored: bool}]
var score: int = 0
var dead: bool = false
var started: bool = false
var scroll: float = 0.0

func reset() -> void:
	bird_y = 450.0
	vel = 0.0
	pillars.clear()
	score = 0
	dead = false
	started = false
	scroll = 0.0
	var x := FIELD.x + 200.0
	for i in 4:
		pillars.append(_new_pillar(x))
		x += SPACING

func _new_pillar(x: float) -> Dictionary:
	var gap: float = max(210.0, 280.0 - score * 3.0)
	return {"x": x, "gap_y": randf_range(170.0, GROUND - 170.0), "gap": gap, "scored": false}

func speed() -> float:
	return min(300.0 + score * 4.0, 440.0)

func flap() -> void:
	if dead:
		return
	started = true
	vel = FLAP

func step(delta: float) -> void:
	if dead:
		return
	scroll += speed() * delta
	if not started:
		# gentle bob before the first tap
		bird_y = 450.0 + sin(scroll / 60.0) * 10.0
		return
	vel += GRAVITY * delta
	bird_y += vel * delta
	if bird_y < BIRD_R:
		bird_y = BIRD_R
		vel = 0.0
	for p in pillars:
		p.x -= speed() * delta
		if not p.scored and p.x + PILLAR_W < BIRD_X:
			p.scored = true
			score += 1
	if pillars[0].x + PILLAR_W < -10.0:
		pillars.pop_front()
		pillars.append(_new_pillar(pillars.back().x + SPACING))
	if bird_y + BIRD_R >= GROUND:
		bird_y = GROUND - BIRD_R
		dead = true
		return
	for p in pillars:
		if BIRD_X + BIRD_R * 0.8 > p.x and BIRD_X - BIRD_R * 0.8 < p.x + PILLAR_W:
			if bird_y - BIRD_R * 0.8 < p.gap_y - p.gap / 2.0 or bird_y + BIRD_R * 0.8 > p.gap_y + p.gap / 2.0:
				dead = true
				return
