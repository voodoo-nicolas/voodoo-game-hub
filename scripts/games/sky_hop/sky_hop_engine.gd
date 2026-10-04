extends RefCounted

## Sky Hop: a little hopper bounces off every platform it lands on. Steer
## left and right (the sides wrap around) and climb as high as you can.
## Some platforms slide, some crumble, springs launch you. Fall off the
## bottom of the screen and it's over. Pure simulation; y grows upwards,
## in world units (the world is WIDTH wide, the view VIEW_H tall).

const WIDTH := 100.0
const VIEW_H := 170.0
const GRAVITY := 130.0
const JUMP := 112.0
const SPRING := 190.0
const STEER := 95.0
const PLAT_W := 18.0
const HOPPER_W := 8.0

var px: float = 50.0
var py: float = 10.0
var vy: float = JUMP
var cam: float = 0.0          # world y at the bottom of the view
var best: float = 0.0
var platforms: Array = []     # {"x", "y", "kind": "plain"/"move"/"crumble"/"spring", "dx", "gone"}
var top_y: float = 0.0
var over := false
var rng := RandomNumberGenerator.new()

func reset(seed_: int = -1) -> void:
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	px = 50.0
	py = 12.0
	vy = JUMP
	cam = 0.0
	best = 0.0
	over = false
	platforms = [{"x": 50.0 - PLAT_W / 2.0, "y": 5.0, "kind": "plain", "dx": 0.0, "gone": false}]
	top_y = 5.0
	_fill()

func score() -> int:
	return int(best)

## Gap between platforms grows with height, up to just under a jump's reach.
func _gap() -> float:
	return clampf(14.0 + best * 0.012, 14.0, 40.0)

func _fill() -> void:
	while top_y < cam + VIEW_H * 1.5:
		top_y += rng.randf_range(_gap() * 0.6, _gap())
		var kind := "plain"
		var r := rng.randf()
		var h := top_y
		if h > 300.0 and r < 0.18:
			kind = "move"
		elif h > 150.0 and r < 0.3:
			kind = "crumble"
		elif r > 0.93:
			kind = "spring"
		platforms.append({"x": rng.randf_range(0.0, WIDTH - PLAT_W), "y": top_y, "kind": kind,
			"dx": (rng.randf_range(15.0, 30.0) * (1 if rng.randf() < 0.5 else -1)) if kind == "move" else 0.0, "gone": false})
		# A crumbling platform never stands alone: add a safe one nearby.
		if kind == "crumble":
			platforms.append({"x": rng.randf_range(0.0, WIDTH - PLAT_W), "y": top_y + rng.randf_range(3.0, 8.0),
				"kind": "plain", "dx": 0.0, "gone": false})
	platforms = platforms.filter(func(p): return p.y > cam - 20.0)

## One frame: steer -1 / 0 / 1. Returns events: "bounce", "spring", "crumble", "over".
func step(dt: float, steer: float) -> Array:
	var ev: Array = []
	if over:
		return ev
	px = fposmod(px + steer * STEER * dt, WIDTH)
	for p in platforms:
		if p.kind == "move":
			p.x += p.dx * dt
			if p.x < 0.0 or p.x > WIDTH - PLAT_W:
				p.dx = -p.dx
				p.x = clampf(p.x, 0.0, WIDTH - PLAT_W)
	var old_y := py
	vy -= GRAVITY * dt
	py += vy * dt
	if vy < 0.0:
		for p in platforms:
			if p.gone:
				continue
			if old_y >= p.y and py <= p.y and _over_platform(p):
				if p.kind == "crumble":
					p.gone = true
					ev.append("crumble")
					continue
				py = p.y
				vy = SPRING if p.kind == "spring" else JUMP
				ev.append("spring" if p.kind == "spring" else "bounce")
				break
	best = maxf(best, py)
	cam = maxf(cam, py - VIEW_H * 0.4)
	_fill()
	if py < cam - 10.0:
		over = true
		ev.append("over")
	return ev

func _over_platform(p: Dictionary) -> bool:
	# The world wraps, so test the hopper against the platform at x and x +- WIDTH.
	for shift in [0.0, WIDTH, -WIDTH]:
		var x: float = px + shift
		if x + HOPPER_W / 2.0 > p.x and x - HOPPER_W / 2.0 < p.x + PLAT_W:
			return true
	return false
