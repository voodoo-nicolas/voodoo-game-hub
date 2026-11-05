extends SceneTree

## Headless test of the top-down adventure engine against docs/topdown/SPEC.md:
##   godot --headless --path . --script res://tools/test_topdown.gd
## Pure engine only: touches no saves.

const E = preload("res://scripts/games/topdown/topdown_engine.gd")
const Rooms = preload("res://scripts/games/topdown/topdown_rooms.gd")

var fails := 0
var passes := 0

const OPEN := [
	"##########",
	"#........#",
	"#........#",
	"#...P....#",
	"#........#",
	"#........#",
	"##########",
]

func check(name: String, got, want) -> void:
	if typeof(got) == TYPE_FLOAT or typeof(want) == TYPE_FLOAT:
		if absf(float(got) - float(want)) < 0.001:
			passes += 1
			return
	elif got == want:
		passes += 1
		return
	fails += 1
	print("FAIL %s: got %s, want %s" % [name, str(got), str(want)])

func fresh(lines: Array = OPEN) -> Object:
	var e = E.new()
	e.new_game(lines, 1)
	return e

func run(e, n: int, input: Dictionary) -> void:
	for i in n:
		e.tick(input)

func _init() -> void:
	# Walk: 1.5 px/frame straight, 1.0 per axis diagonal, instant start and stop.
	var e = fresh()
	var p0: Vector2 = e.pos
	run(e, 1, {"dir": Vector2i(1, 0)})
	check("walk first frame full speed", e.pos.x - p0.x, 1.5)
	run(e, 1, {})
	check("instant stop", e.pos.x - p0.x, 1.5)
	e = fresh()
	p0 = e.pos
	run(e, 10, {"dir": Vector2i(1, 1)})
	check("diagonal x", e.pos.x - p0.x, 10.0)
	check("diagonal y", e.pos.y - p0.y, 10.0)

	# Walls stop the hero; the box stays out of wall tiles.
	e = fresh()
	run(e, 200, {"dir": Vector2i(-1, 0)})
	check("wall stops hero", e.box_hits_wall(e.pos, E.HERO_HALF), false)
	check("hero against left wall", e.pos.x <= 16.0 + E.HERO_HALF + 1.5, true)

	# Dash: 30-frame wind-up on the spot, then 4 px/frame; release cancels.
	e = fresh()
	p0 = e.pos
	run(e, 1, {"dash": true})
	check("windup state", e.state, E.S.WINDUP)
	run(e, 29, {"dash": true, "dir": Vector2i(1, 0)})
	check("no move in windup", e.pos, p0)
	check("still winding up 29 frames after the press", e.state, E.S.WINDUP)
	run(e, 1, {"dash": true, "dir": Vector2i(1, 0)})
	check("dash starts 30 frames after the press", e.state, E.S.DASH)
	var px: float = e.pos.x
	run(e, 1, {"dir": Vector2i(1, 0)})
	check("dash speed (button no longer needed)", e.pos.x - px, 4.0)
	run(e, 1, {"dir": Vector2i(0, 1)})
	check("other direction ends dash", e.state, E.S.WALK)
	e = fresh()
	run(e, 10, {"dash": true})
	run(e, 25, {})
	check("release in windup cancels", e.state, E.S.WALK)
	# Dash into a wall bounces back
	e = fresh()
	run(e, 31, {"dash": true, "dir": Vector2i(1, 0)})
	var bonked := false
	for i in 60:
		e.tick({})
		if "bonk" in e.events:
			bonked = true
			break
	check("dash into wall bonks", bonked, true)
	check("bonk recoils", e.state, E.S.RECOIL)

	# Sword: 14-frame swing, rooted; hold → charge ready 48 frames later → spin 40 frames.
	e = fresh()
	p0 = e.pos
	run(e, 1, {"sword": true})
	check("swing starts", e.state, E.S.SWING)
	run(e, 12, {"sword": false, "dir": Vector2i(1, 0)})
	check("rooted during swing", e.pos, p0)
	check("swing still on at frame 13", e.state, E.S.SWING)
	run(e, 1, {})
	check("swing over after 14 frames", e.state, E.S.WALK)
	e = fresh()
	run(e, 14, {"sword": true})
	check("hold past swing charges", e.state, E.S.CHARGE)
	var got_ready := -1
	for i in 60:
		e.tick({"sword": true})
		if "charged" in e.events:
			got_ready = i + 1
			break
	check("charged after 48 frames", got_ready, 48)
	run(e, 1, {})
	check("release when charged spins", e.state, E.S.SPIN)
	run(e, 39, {})
	check("spin still on at 40", e.state, E.S.SPIN)
	run(e, 1, {})
	check("spin lasts 40 frames", e.state, E.S.WALK)
	e = fresh()
	run(e, 14, {"sword": true})
	run(e, 10, {"sword": true})
	run(e, 1, {})
	check("early release: no spin", e.state, E.S.WALK)
	# Charge walk is the slow row
	e = fresh()
	run(e, 14, {"sword": true})
	px = e.pos.x
	run(e, 4, {"sword": true, "dir": Vector2i(1, 0)})
	check("charge walk 1.25 px/f", e.pos.x - px, 5.0)
	# Re-swing from pose 4 after release + press
	e = fresh()
	run(e, 1, {"sword": true})
	run(e, 4, {"sword": false})
	check("pose 4 after 5 frames", e.pose, 4)
	run(e, 1, {"sword": true})
	check("re-swing restarts at pose 0", [e.state, e.pose], [E.S.SWING, 0])

	# Beam: level 2+, within half a heart of full.
	e = fresh()
	e.sword_level = 2
	var beamed := false
	for i in 14:
		e.tick({"sword": i == 0})
		beamed = beamed or "beam" in e.events
	check("beam at full health", beamed, true)
	e = fresh()
	e.sword_level = 2
	e.hp = e.max_hp - 4
	beamed = false
	for i in 14:
		e.tick({"sword": i == 0})
		beamed = beamed or "beam" in e.events
	check("no beam half a heart down", beamed, false)

	# Damage: table x armour, knockback 19+ frames, 58 frames of invincibility.
	e = fresh()
	e.take_damage(E.DAMAGE[3][0], Vector2(1, 0))
	check("class 3 armour 0 = 1 heart", e.hp, 16)
	check("recoil state", e.state, E.S.RECOIL)
	check("hurt timer", e.hurt, E.HURT_FRAMES)
	var frames_to_control := 0
	while e.state == E.S.RECOIL and frames_to_control < 100:
		e.tick({"dir": Vector2i(-1, 0)})
		frames_to_control += 1
	check("control back after ~19 frames", frames_to_control >= 18 and frames_to_control <= 20, true)
	check("armour 2 halves twice", E.DAMAGE[5], [16, 8, 4])
	e = fresh()
	e.hp = 4
	e.take_damage(8, Vector2(1, 0))
	check("death at 0", [e.hp, e.dead], [0, true])
	# Contact damage from an enemy, then no second hit while invincible
	e = fresh()
	e.enemies = []
	e._spawn_enemy("blob", e.pos)
	e.enemies[0].wait = 9999
	var hits := 0
	for i in 50:
		e.tick({})
		if "hurt" in e.events:
			hits += 1
	check("one hit inside the invincible window", hits, 1)
	check("blob does half a heart", e.hp, 20)

	# Blinking while hurt
	e = fresh()
	e.hurt = 30
	var vis := []
	for i in 4:
		e.frame = i
		vis.append(e.hero_visible())
	check("blinks every other frame", vis, [true, false, true, false])

	# Low-health beep every 32 frames at 1 heart or less (3 max hearts).
	e = fresh()
	e.hp = 8
	var beeps := 0
	for i in 64:
		e.tick({})
		if "beep" in e.events:
			beeps += 1
	check("beeps every 32 frames", beeps, 2)

	# Refill: one heart per step, capped at max.
	e = fresh()
	e.hp = 4
	e.refill = 40
	run(e, 200, {})
	check("refill caps at max", [e.hp, e.refill], [e.max_hp, 0])
	e.max_hp = 160
	e.add_heart_container()
	check("heart container cap 20", e.max_hp, 160)

	# Kill everything in a real room: sword hits land, enemies die (random play, many seeds).
	var total_kills := 0
	for s in 20:
		e = E.new()
		e.new_game(Rooms.ROOMS[0], s)
		e.hp = 9999
		e.max_hp = 9999
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		for i in 4000:
			var target: Vector2 = e.enemies[0].pos if not e.enemies.is_empty() else e.pos
			var d: Vector2 = target - e.pos
			var dir := Vector2i(int(signf(d.x)) if absf(d.x) > 4 else 0, int(signf(d.y)) if absf(d.y) > 4 else 0)
			e.tick({"dir": dir, "sword": i % 8 < 2})
			if e.enemies.is_empty():
				break
			# Invariant: the hero never ends inside a wall.
			if e.box_hits_wall(e.pos, E.HERO_HALF):
				check("hero inside wall seed %d" % s, true, false)
				break
		total_kills += e.kills
	check("random play kills enemies", total_kills > 0, true)

	print("topdown: %d passed, %d failed" % [passes, fails])
	quit(1 if fails > 0 else 0)
