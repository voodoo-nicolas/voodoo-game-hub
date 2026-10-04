extends RefCounted

## Air Hockey on a table W x H (world units). Player 1 defends the bottom
## goal, player 2 the top. Each mallet stays in its own half; the puck
## bounces off the walls and mallets. First to WIN_AT goals wins.
## Pure simulation, stepped by the game; includes a computer for player 2.

const W := 100.0
const H := 170.0
const GOAL_W := 36.0
const PUCK_R := 4.5
const MALLET_R := 7.5
const MAX_PUCK := 260.0
const FRICTION := 0.9988      # per step at 120 Hz (about 13% speed lost per second)
const WIN_AT := 7

var puck := Vector2(W / 2.0, H / 2.0)
var puck_v := Vector2.ZERO
var mallets: Array = [Vector2(W / 2.0, H - 20.0), Vector2(W / 2.0, 20.0)]
var mallet_v: Array = [Vector2.ZERO, Vector2.ZERO]
var targets: Array = [Vector2(W / 2.0, H - 20.0), Vector2(W / 2.0, 20.0)]
var score: Array = [0, 0]
var serve_to: int = 0
var winner: int = 0           # 0 none, 1, 2
var pause_t: float = 0.0       # short wait after a goal
var cpu_aim_x: float = W / 2.0  # where the computer is shooting this time
var cpu_attacking := false
var rng := RandomNumberGenerator.new()

func reset() -> void:
	score = [0, 0]
	winner = 0
	mallets = [Vector2(W / 2.0, H - 20.0), Vector2(W / 2.0, 20.0)]
	targets = mallets.duplicate()
	_face_off(0)

## The puck waits in the half of the player who conceded.
func _face_off(to: int) -> void:
	puck = Vector2(W / 2.0, H / 2.0 + (18.0 if to == 0 else -18.0))
	puck_v = Vector2.ZERO
	pause_t = 0.8

## Where player p wants their mallet (kept inside their half).
func aim(p: int, at: Vector2) -> void:
	targets[p] = _clamp_half(p, at)

func _clamp_half(p: int, at: Vector2) -> Vector2:
	var x := clampf(at.x, MALLET_R, W - MALLET_R)
	var y := clampf(at.y, H / 2.0 + MALLET_R, H - MALLET_R) if p == 0 else clampf(at.y, MALLET_R, H / 2.0 - MALLET_R)
	return Vector2(x, y)

## Advances dt seconds. Returns events: "hit", "wall", "goal1", "goal2".
func step(dt: float) -> Array:
	var ev: Array = []
	if winner != 0:
		return ev
	var sub := maxi(1, int(ceil(dt * 120.0)))
	var h := dt / sub
	for s in sub:
		if winner != 0:
			break
		for p in 2:
			var old: Vector2 = mallets[p]
			# Mallets follow the finger quickly but not instantly.
			var next: Vector2 = old.move_toward(targets[p], 900.0 * h)
			mallets[p] = next
			mallet_v[p] = (next - old) / h
		if pause_t > 0.0:
			pause_t -= h
			continue
		puck += puck_v * h
		puck_v *= FRICTION
		# Walls (with goal mouths at the top and bottom).
		if puck.x < PUCK_R:
			puck.x = PUCK_R
			puck_v.x = absf(puck_v.x)
			ev.append("wall")
		elif puck.x > W - PUCK_R:
			puck.x = W - PUCK_R
			puck_v.x = -absf(puck_v.x)
			ev.append("wall")
		var in_mouth := absf(puck.x - W / 2.0) < GOAL_W / 2.0
		if puck.y < PUCK_R and not in_mouth:
			puck.y = PUCK_R
			puck_v.y = absf(puck_v.y)
			ev.append("wall")
		elif puck.y > H - PUCK_R and not in_mouth:
			puck.y = H - PUCK_R
			puck_v.y = -absf(puck_v.y)
			ev.append("wall")
		if puck.y < -PUCK_R:
			_goal(1, ev)   # player 1 scored in the top goal
			continue
		if puck.y > H + PUCK_R:
			_goal(2, ev)
			continue
		for p in 2:
			var d: Vector2 = puck - mallets[p]
			var dist := d.length()
			if dist < PUCK_R + MALLET_R and dist > 0.001:
				var n := d / dist
				puck = mallets[p] + n * (PUCK_R + MALLET_R + 0.1)
				var rel: Vector2 = puck_v - mallet_v[p]
				var along := rel.dot(n)
				if along < 0.0:
					puck_v -= n * along * 1.9
				puck_v += mallet_v[p] * 0.35
				if puck_v.length() > MAX_PUCK:
					puck_v = puck_v.normalized() * MAX_PUCK
				ev.append("hit")
		# A mallet can't push the puck through a side wall.
		puck.x = clampf(puck.x, PUCK_R, W - PUCK_R)
		# Squeezed between both mallets? Let it squirt out sideways.
		var r := PUCK_R + MALLET_R
		if puck.distance_to(mallets[0]) < r and puck.distance_to(mallets[1]) < r:
			var side := 1.0 if puck.x < W / 2.0 else -1.0
			puck.x = clampf(puck.x + side * r, PUCK_R, W - PUCK_R)
			puck_v = Vector2(side * 120.0, 0.0)
	return ev

func _goal(p: int, ev: Array) -> void:
	score[p - 1] += 1
	ev.append("goal%d" % p)
	if score[p - 1] >= WIN_AT:
		winner = p
		puck_v = Vector2.ZERO
		return
	_face_off(2 - p)  # the player who conceded gets the puck (index 0 = bottom)

## The computer (player 2): guard the goal, strike when the puck is in its half.
func cpu_target(level: int) -> Vector2:
	var home := Vector2(W / 2.0, 16.0)
	var speed_k: float = [0.55, 0.8, 1.0][level]
	if puck.y < H / 2.0 - PUCK_R:
		if not cpu_attacking:
			# A new attack: shoot for a corner of the goal, or bank it off a wall.
			cpu_attacking = true
			var r := rng.randf()
			cpu_aim_x = W / 2.0 + rng.randf_range(-GOAL_W * 0.4, GOAL_W * 0.4)
			if r < 0.3:
				cpu_aim_x = -W * 0.6 if puck.x < W / 2.0 else W * 1.6  # off the side wall
		# Attack: line up behind the puck, then drive through it towards the bottom goal.
		var aim_at := Vector2(cpu_aim_x, H)
		var dir := (aim_at - puck).normalized()
		var behind := puck - dir * (MALLET_R + PUCK_R + 4.0)
		var m: Vector2 = mallets[1]
		if m.distance_to(behind) < 5.0 or (m - puck).dot(dir) < -(MALLET_R + PUCK_R):
			return puck + dir * 20.0 * speed_k  # strike
		return m.lerp(behind, speed_k)
	cpu_attacking = false
	# Defend: stay between the puck and the goal.
	var x := lerpf(W / 2.0, puck.x, 0.6 * speed_k)
	return Vector2(x, home.y + 6.0)
