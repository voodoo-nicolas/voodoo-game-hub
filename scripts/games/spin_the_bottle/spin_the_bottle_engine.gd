extends RefCounted

## Spin the Bottle: a bottle spins with friction and stops pointing at one of
## the players seated around it. Angles are radians, 0 = pointing right,
## growing clockwise (screen coordinates); seat 0 sits at the top.
## Pure simulation, no Nodes -- the scene calls step() every frame.

const FRICTION := 0.55      # exponential slow-down per second
const DRAG := 0.9           # constant slow-down, rad/s², so it really stops
const STOP_SPEED := 0.15
const MAX_SPEED := 40.0

var players := 6
var angle := -PI / 2.0      # the neck points up at the start
var speed := 0.0            # rad/s
var spinning := false

func set_players(n: int) -> void:
	players = clampi(n, 2, 12)

## Seat i's direction from the centre.
func seat_angle(i: int) -> float:
	return -PI / 2.0 + i * TAU / players

func spin(initial_speed: float) -> void:
	speed = clampf(initial_speed, -MAX_SPEED, MAX_SPEED)
	spinning = absf(speed) > STOP_SPEED

func spin_random() -> void:
	spin(randf_range(14.0, 24.0) * (1 if randf() < 0.5 else -1))

## Advances the spin. Returns true on the frame it comes to rest.
func step(delta: float) -> bool:
	if not spinning:
		return false
	angle = wrapf(angle + speed * delta, -PI, PI)
	var mag := absf(speed) * exp(-FRICTION * delta) - DRAG * delta
	if mag <= STOP_SPEED:
		speed = 0.0
		spinning = false
		return true
	speed = mag * signf(speed)
	return false

## The seat the neck points at (closest by angle).
func chosen() -> int:
	var best := 0
	var best_d := INF
	for i in players:
		var d := absf(angle_difference(angle, seat_angle(i)))
		if d < best_d:
			best_d = d
			best = i
	return best
