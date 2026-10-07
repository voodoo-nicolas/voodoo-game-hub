extends RefCounted

## Sky Raider: a vertical-scrolling shooter. The fighter fires on its own;
## the player slides it around to dodge bullets while waves of darts,
## gunships, ground turrets and bombers come down the screen, and a boss
## closes every stage. Power-ups widen the guns. Pure logic in world units
## (W x H, y grows downwards), stepped by the game.
##
## Since pack v8 (2026-10-07): the islands are solid -- the hitbox inside
## one is a crash (each island only once) -- and the turrets ride on them;
## islands never overlap in height, so one side is always open. A lost life
## resets the guns to level 1. Battleships get tougher every stage
## (BOSS_PHASES: more armour, more phases, faster fire, new attacks), and
## Hard is harder all round (DIFFS).

const W := 720.0
const H := 1100.0
const SCROLL := 90.0          # ground speed, units / second
const PLAYER_HIT := 9.0       # the player's small hitbox radius
const PLAYER_BODY := 26.0     # for picking things up
const FIRE_EVERY := 0.11
const BULLET_SPEED := 980.0
const STAGE_TIME := 55.0
const MAX_POWER := 4
## Easy / Normal / Hard: enemy bullet speed and fire rate.
## Also: hp / ramp = enemy armour and how much it grows per stage, waves =
## how often waves come, dart_shot = chance a dart fires, fan / turret /
## ring = bullets per gunship spread / turret burst / bomber ring, drop =
## a gunship's drop chance, every = a drop every Nth kill, bombs at the
## start, isl_gap = the open sea between islands, turrets = the chance an
## island carries guns, boss_lvl = levels added to every battleship,
## boss_hp = its armour.
const DIFFS := [
	{"bullet": 0.75, "fire": 0.65, "hp": 0.8, "ramp": 0.1, "waves": 0.85, "dart_shot": 0.25, "fan": 3, "turret": 1,
		"ring": 10, "drop": 0.5, "every": 15, "bombs": 2, "isl_gap": [430.0, 680.0], "turrets": 0.3, "boss_lvl": 0,
		"boss_hp": 0.7},
	{"bullet": 1.0, "fire": 1.0, "hp": 1.0, "ramp": 0.12, "waves": 1.0, "dart_shot": 0.35, "fan": 3, "turret": 1,
		"ring": 12, "drop": 0.45, "every": 15, "bombs": 2, "isl_gap": [330.0, 560.0], "turrets": 0.45, "boss_lvl": 0,
		"boss_hp": 1.0},
	{"bullet": 1.3, "fire": 1.7, "hp": 1.45, "ramp": 0.16, "waves": 1.4, "dart_shot": 0.8, "fan": 5, "turret": 2,
		"ring": 16, "drop": 0.3, "every": 20, "bombs": 1, "isl_gap": [230.0, 430.0], "turrets": 0.65, "boss_lvl": 1,
		"boss_hp": 1.2},
]
## The battleship of level `lvl` (stage - 1 + DIFFS.boss_lvl) has
## mini(2 + lvl / 2, 4) phases, one per equal slice of its armour. Each
## phase cycles through its attacks; an attack joins once lvl reaches the
## number beside it. Fire rate and bullet speed also climb with lvl.
const BOSS_PHASES := [
	[["fans", 0], ["stream", 2]],
	[["ring", 0], ["fans", 0], ["escorts", 1], ["wall", 3]],
	[["spiral", 0], ["stream", 0], ["wall", 2], ["laser", 3]],
	[["laser", 0], ["spiral", 0], ["ring", 0], ["escorts", 0], ["wall", 0]],
]
const BOSS_Y := 210.0
const LASER_HALF := 24.0      # the beam's half width
const LASER_WARN := 1.0       # seconds of warning line before it fires
## kind -> hp, radius, score
const KINDS := {
	"dart": {"hp": 1, "r": 20.0, "score": 100},
	"gunship": {"hp": 7, "r": 30.0, "score": 300},
	"turret": {"hp": 5, "r": 24.0, "score": 250},
	"bomber": {"hp": 26, "r": 52.0, "score": 900},
}

var diff: int = 1
var stage: int = 1
var score: int = 0
var lives: int = 3
var bombs: int = 2
var power: int = 1
var state := "play"           # play, dead, clear, over
var pos := Vector2(W / 2.0, H - 160.0)
var invuln: float = 0.0
var enemies: Array = []       # {"kind", "p", "v", "hp", "t", "path", "cool", "hit", "x0"}
var shots: Array = []         # player bullets: {"p", "v"}
var bullets: Array = []       # enemy bullets: {"p", "v"}
var items: Array = []         # {"p", "kind": "P" | "B" | "1"}
## Solid scenery: {"p", "pts": PackedVector2Array, "top", "bot" (y extents
## of pts), "hit" (crashed into: harmless from then on)}.
var islands: Array = []
var boss: Dictionary = {}
var stage_t: float = 0.0
var scrolled: float = 0.0
var kills: int = 0
var crashes: int = 0
var _fire_t: float = 0.0
var _wave_t: float = 1.5
var _island_due: float = 0.0  # scroll distance until the next island
var rng := RandomNumberGenerator.new()

func reset(p_diff: int = 1, seed_: int = -1) -> void:
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	diff = clampi(p_diff, 0, DIFFS.size() - 1)
	stage = 1
	score = 0
	lives = 3
	bombs = DIFFS[diff].bombs
	power = 1
	kills = 0
	crashes = 0
	start_stage()

func start_stage() -> void:
	enemies = []
	shots = []
	bullets = []
	items = []
	boss = {}
	stage_t = 0.0
	_wave_t = 1.5
	pos = Vector2(W / 2.0, H - 160.0)
	invuln = 2.0
	state = "play"
	# Islands from 40% of the way down upwards: open sea under the fighter
	# to get going. Each one sits a gap above the last (`edge` = where the
	# next one's bottom goes).
	islands = []
	var edge := H * 0.4
	while edge > -100.0:
		var isl := _add_island()
		isl.p.y = edge - isl.bot
		edge = isl.p.y + isl.top - _island_gap()
	_island_due = -30.0 - edge

func move(d: Vector2) -> void:
	pos = Vector2(clampf(pos.x + d.x, 24.0, W - 24.0), clampf(pos.y + d.y, 120.0, H - 40.0))

func bomb() -> bool:
	if bombs <= 0 or state != "play":
		return false
	bombs -= 1
	bullets = []
	for e in enemies.duplicate():
		_damage(e, 18, [])
	if not boss.is_empty():
		boss.hp -= maxi(30, int(boss.max * 0.04))
		boss.hit = 0.2
		boss.laser = {}
		boss.stream = 0
		boss.spiral = 0.0
	invuln = maxf(invuln, 1.0)
	return true

# ---------- one frame ----------

## Returns events: "kill", "big_kill", "hit", "hurt", "power", "bomb_item",
## "life", "boss", "boss_down", "clear", "dead"; since v8 also "crash"
## (into an island), "boss_phase", "laser" (a battleship's beam fires).
func step(dt: float) -> Array:
	var ev: Array = []
	if state != "play":
		return ev
	var lives0 := lives
	stage_t += dt
	scrolled += SCROLL * dt
	invuln = maxf(0.0, invuln - dt)
	_scenery(dt)
	_check_islands(ev)
	_fire(dt)
	_waves(dt, ev)
	_step_enemies(dt)
	_step_boss(dt, ev)
	_step_shots(dt, ev)
	_step_bullets(dt, ev)
	_step_items(dt, ev)
	if lives < lives0:
		ev.append("hurt")
	if state == "dead":
		ev.append("dead")
	return ev

func _scenery(dt: float) -> void:
	for isl in islands:
		isl.p.y += SCROLL * dt
	islands = islands.filter(func(i): return i.p.y + i.top < H + 40.0)
	_island_due -= SCROLL * dt
	if _island_due <= 0.0:
		# Its bottom just above the top edge; the next one a gap above it.
		var isl := _add_island()
		isl.p.y = -30.0 - isl.bot
		_island_due += isl.bot - isl.top + _island_gap()
		# Gun emplacements, more often in later stages -- never once the
		# waves are over (the battleship waits for an empty sky).
		var chance: float = minf(0.85, DIFFS[diff].turrets + 0.06 * (stage - 1))
		if stage_t < STAGE_TIME and rng.randf() < chance:
			_arm_island(isl, 2 if rng.randf() < 0.25 + 0.06 * stage else 1)

func _island_gap() -> float:
	var g: Array = DIFFS[diff].isl_gap
	return rng.randf_range(g[0], g[1])

## A new island (centre x random, y left to the caller). At most 360 wide,
## so with no two islands at the same height one side is always open.
func _add_island() -> Dictionary:
	var c := Vector2(rng.randf_range(60.0, W - 60.0), 0.0)
	var n := 11
	var r := rng.randf_range(80.0, 150.0)
	var pts := PackedVector2Array()
	var top := 0.0
	var bot := 0.0
	for i in n:
		var a := TAU * i / n
		var v := Vector2(cos(a) * r * rng.randf_range(0.65, 1.2), sin(a) * r * rng.randf_range(0.5, 0.9))
		pts.append(v)
		top = minf(top, v.y)
		bot = maxf(bot, v.y)
	var isl := {"p": c, "pts": pts, "top": top, "bot": bot, "hit": false}
	islands.append(isl)
	return isl

## Turrets standing on the island (they scroll with it).
func _arm_island(isl: Dictionary, n: int) -> void:
	var placed: Array = []
	for tries in 20:
		if placed.size() >= n:
			break
		var off := Vector2(rng.randf_range(-70.0, 70.0), rng.randf_range(isl.top * 0.5, isl.bot * 0.5))
		if not Geometry2D.is_point_in_polygon(off, isl.pts):
			continue
		if placed.any(func(q): return (q as Vector2).distance_to(off) < 60.0):
			continue
		placed.append(off)
		_add_enemy("turret", isl.p + off, Vector2(0, SCROLL))

func _in_island(p: Vector2) -> bool:
	for isl in islands:
		var rel: Vector2 = p - isl.p
		if rel.y >= isl.top and rel.y <= isl.bot and Geometry2D.is_point_in_polygon(rel, isl.pts):
			return true
	return false

## Flying into an island (only the hitbox counts, like bullets).
func _check_islands(ev: Array) -> void:
	if invuln > 0.0 or state != "play":
		return
	for isl in islands:
		if isl.hit:
			continue
		var rel: Vector2 = pos - isl.p
		if rel.y >= isl.top and rel.y <= isl.bot and Geometry2D.is_point_in_polygon(rel, isl.pts):
			isl.hit = true
			crashes += 1
			ev.append("crash")
			_player_hit()
			return

func _fire(dt: float) -> void:
	_fire_t -= dt
	if _fire_t > 0.0:
		return
	_fire_t = FIRE_EVERY
	var up := Vector2(0, -BULLET_SPEED)
	var spec: Array = [[-10.0, 0.0], [10.0, 0.0]]
	if power >= 2:
		spec += [[-18.0, -0.12], [18.0, 0.12]]
	if power >= 3:
		spec += [[0.0, 0.0]]
	if power >= 4:
		spec += [[-22.0, -0.26], [22.0, 0.26]]
	for s in spec:
		shots.append({"p": pos + Vector2(s[0], -26.0), "v": up.rotated(s[1])})

func _waves(dt: float, ev: Array) -> void:
	if stage_t >= STAGE_TIME:
		if boss.is_empty() and enemies.is_empty() and state == "play":
			_spawn_boss()
			ev.append("boss")
		return
	_wave_t -= dt
	if _wave_t > 0.0:
		return
	var d: Dictionary = DIFFS[diff]
	_wave_t = rng.randf_range(2.0, 3.4) / (d.waves * (1.0 + 0.08 * (stage - 1)))
	# Turrets come on the islands now (_scenery), not as a wave of their own.
	var r := rng.randf()
	if r < 0.45:
		# A line of darts swooping down along a sine.
		var n := rng.randi_range(4, 6)
		var x0 := rng.randf_range(140.0, W - 140.0)
		for k in n:
			var dart := _add_enemy("dart", Vector2(x0, -40.0 - k * 60.0), Vector2(0, 260.0))
			dart.path = rng.randf_range(0.6, 1.0) * (1 if rng.randf() < 0.5 else -1)
	elif r < 0.78:
		for k in rng.randi_range(1, 2):
			var e := _add_enemy("gunship", Vector2(rng.randf_range(100.0, W - 100.0), -50.0), Vector2(0, 160.0))
			e.path = rng.randf_range(180.0, 380.0)   # where it stops
	elif stage >= 2 or stage_t > 25.0:
		_add_enemy("bomber", Vector2(rng.randf_range(160.0, W - 160.0), -80.0), Vector2(0, 55.0))
	else:
		_wave_t = 0.2

func _add_enemy(kind: String, p: Vector2, v: Vector2) -> Dictionary:
	var hp := int(ceilf(KINDS[kind].hp * DIFFS[diff].hp * (1.0 + DIFFS[diff].ramp * (stage - 1))))
	var e := {"kind": kind, "p": p, "v": v, "hp": hp, "t": 0.0, "path": 0.0, "cool": rng.randf_range(0.6, 1.6),
		"hit": 0.0, "x0": p.x}
	enemies.append(e)
	return e

func _step_enemies(dt: float) -> void:
	var d: Dictionary = DIFFS[diff]
	var keep: Array = []
	for e in enemies:
		e.t += dt
		e.hit = maxf(0.0, e.hit - dt)
		match e.kind:
			"dart":
				e.p.y += e.v.y * dt
				e.p.x = e.x0 + sin(e.t * 2.4) * 150.0 * e.path
			"gunship":
				if e.p.y < e.path and e.t < 7.0:
					e.p.y += e.v.y * dt
				elif e.t >= 7.0:
					e.p.y += e.v.y * 1.4 * dt
				e.p.x += sin(e.t * 1.3) * 40.0 * dt
			_:
				e.p += e.v * dt
		e.cool -= dt * d.fire
		if e.cool <= 0.0 and e.p.y > 20.0 and e.p.y < H * 0.75:
			match e.kind:
				"dart":
					e.cool = 99.0
					if rng.randf() < d.dart_shot:
						_aimed(e.p, 260.0)
				"gunship":
					e.cool = 1.4
					_fan(e.p, d.fan, 0.25 if d.fan <= 3 else 0.18, 270.0)
				"turret":
					e.cool = 1.8
					_fan(e.p, d.turret, 0.14, 300.0)
				"bomber":
					e.cool = 2.2
					_ring(e.p, d.ring, 200.0, e.t)
		# Ramming the player.
		if invuln <= 0.0 and e.p.distance_to(pos) < KINDS[e.kind].r + PLAYER_HIT:
			if e.kind != "turret":
				_player_hit()
				if e.kind == "dart":
					continue
		if e.p.y > H + 120.0:
			continue
		keep.append(e)
	enemies = keep

func _aimed(from: Vector2, speed: float) -> void:
	var dir := (pos - from).normalized()
	bullets.append({"p": from, "v": dir * speed * DIFFS[diff].bullet})

func _fan(from: Vector2, n: int, spread: float, speed: float) -> void:
	var dir := (pos - from).normalized()
	for k in n:
		var a := (k - (n - 1) / 2.0) * spread
		bullets.append({"p": from, "v": dir.rotated(a) * speed * DIFFS[diff].bullet})

func _ring(from: Vector2, n: int, speed: float, phase: float) -> void:
	for k in n:
		bullets.append({"p": from, "v": Vector2.DOWN.rotated(TAU * k / n + phase) * speed * DIFFS[diff].bullet})

func _step_shots(dt: float, ev: Array) -> void:
	var keep: Array = []
	for s in shots:
		s.p += s.v * dt
		if s.p.y < -30.0 or s.p.x < -30.0 or s.p.x > W + 30.0:
			continue
		var hit := false
		for e in enemies:
			if e.p.y > -30.0 and (e.p as Vector2).distance_to(s.p) < KINDS[e.kind].r:
				_damage(e, 1, ev)
				hit = true
				break
		if not hit and not boss.is_empty() and _boss_hit(s.p):
			boss.hp -= 1
			boss.hit = 0.06
			hit = true
			if boss.hp <= 0:
				_boss_down(ev)
		if not hit:
			keep.append(s)
	shots = keep

func _damage(e: Dictionary, n: int, ev: Array) -> void:
	e.hp -= n
	e.hit = 0.08
	if e.hp > 0:
		ev.append("hit")
		return
	enemies.erase(e)
	score += KINDS[e.kind].score
	kills += 1
	ev.append("big_kill" if e.kind == "bomber" or e.kind == "gunship" else "kill")
	# Drops: bombers always, gunships often, every 15th kill.
	var drop := ""
	if e.kind == "bomber":
		drop = "P" if power < MAX_POWER else "B"
		if rng.randf() < 0.25:
			drop = "1"
	elif e.kind == "gunship" and rng.randf() < DIFFS[diff].drop:
		drop = "P" if power < MAX_POWER and rng.randf() < 0.7 else "B"
	elif kills % int(DIFFS[diff].every) == 0:
		drop = "P" if power < MAX_POWER else "B"
	if drop != "":
		items.append({"p": e.p, "kind": drop, "t": 0.0})

func _step_bullets(dt: float, ev: Array) -> void:
	var keep: Array = []
	for b in bullets:
		b.p += b.v * dt
		if b.p.y < -40.0 or b.p.y > H + 40.0 or b.p.x < -40.0 or b.p.x > W + 40.0:
			continue
		if invuln <= 0.0 and (b.p as Vector2).distance_to(pos) < PLAYER_HIT + 5.0:
			_player_hit()
			keep = []
			break
		keep.append(b)
	bullets = keep

func _step_items(dt: float, ev: Array) -> void:
	var keep: Array = []
	for it in items:
		it.t += dt
		it.p.y += 110.0 * dt
		it.p.x += sin(it.t * 3.0) * 40.0 * dt
		if (it.p as Vector2).distance_to(pos) < PLAYER_BODY + 18.0:
			match it.kind:
				"P":
					if power < MAX_POWER:
						power += 1
					else:
						score += 500
					ev.append("power")
				"B":
					bombs = mini(bombs + 1, 5)
					ev.append("bomb_item")
				"1":
					lives = mini(lives + 1, 5)
					ev.append("life")
			continue
		if it.p.y < H + 30.0:
			keep.append(it)
	items = keep

func _player_hit() -> void:
	if invuln > 0.0 or state != "play":
		return
	lives -= 1
	power = 1  # a lost life costs all the gun power (owner, 2026-10-07)
	bullets = []
	invuln = 2.2
	if lives <= 0:
		state = "dead"

# ---------- the boss ----------

func _spawn_boss() -> void:
	var lvl: int = stage - 1 + int(DIFFS[diff].boss_lvl)
	var hp := int((400.0 + 130.0 * lvl + 6.0 * lvl * lvl) * DIFFS[diff].boss_hp)
	boss = {"p": Vector2(W / 2.0, -140.0), "hp": hp, "max": hp, "t": 0.0, "cool": 2.0, "hit": 0.0, "phase": 0,
		"lvl": lvl, "phases": mini(2 + lvl / 2, BOSS_PHASES.size()), "entered": false, "t_in": 0.0, "ai": 0,
		"stream": 0, "stream_t": 0.0, "spiral": 0.0, "spiral_t": 0.0, "spin": 0.0, "laser": {}}

func _boss_hit(p: Vector2) -> bool:
	var d: Vector2 = p - boss.p
	return absf(d.x) < 120.0 and absf(d.y) < 55.0 or d.length() < 70.0

func _step_boss(dt: float, ev: Array) -> void:
	if boss.is_empty():
		return
	boss.t += dt
	boss.hit = maxf(0.0, boss.hit - dt)
	if not boss.entered:
		boss.p.y += 90.0 * dt
		if boss.p.y >= BOSS_Y:
			boss.entered = true
			boss.t_in = boss.t
		if boss.hp <= 0:
			_boss_down(ev)
		return
	var lvl: int = boss.lvl
	var bt: float = boss.t - boss.t_in
	# Sweeps side to side, faster at higher levels, and bobs from level 2;
	# a laser shot first slides to its mark (the sight line), then holds.
	var want_x := W / 2.0 + sin(bt * minf(0.7 + 0.06 * lvl, 1.2)) * (W / 2.0 - 160.0)
	var lz: Dictionary = boss.laser
	if not lz.is_empty():
		want_x = lz.x
	boss.p.x = move_toward(boss.p.x, want_x, (240.0 + 20.0 * lvl) * dt)
	if lvl >= 2:
		boss.p.y = BOSS_Y + sin(bt * 0.9) * minf(20.0 + 10.0 * lvl, 70.0)
	if invuln <= 0.0 and _boss_hit(pos):
		_player_hit()  # flying into the hull
	var ph := clampi(int((1.0 - float(boss.hp) / boss.max) * boss.phases), 0, boss.phases - 1)
	if ph != boss.phase:
		boss.phase = ph
		boss.ai = 0
		boss.cool = 0.8
		boss.laser = {}
		ev.append("boss_phase")
	# Part of the difficulty's fire rate (boss_lvl already adds the rest).
	var rate: float = lerpf(1.0, DIFFS[diff].fire, 0.6) * minf(1.0 + 0.05 * lvl, 1.6)
	_boss_ongoing(dt, rate, ev)
	boss.cool -= dt * rate
	if boss.cool <= 0.0:
		var list := _boss_attacks(ph, lvl)
		var attack: String = list[boss.ai % list.size()]
		boss.ai += 1
		boss.cool = _boss_attack(attack, lvl)
	if boss.hp <= 0:
		_boss_down(ev)

## This phase's attacks at this level.
func _boss_attacks(ph: int, lvl: int) -> Array:
	var out: Array = []
	for a in BOSS_PHASES[ph]:
		if lvl >= a[1]:
			out.append(a[0])
	return out

## Bullet speed for the battleship's level.
func _boss_speed(lvl: int) -> float:
	return minf(1.0 + 0.04 * lvl, 1.4)

## Starts one attack; returns the time until the next (before `rate`).
func _boss_attack(attack: String, lvl: int) -> float:
	var sp := _boss_speed(lvl)
	match attack:
		"fans":
			var n := mini(3 + lvl / 2, 7)
			_fan(boss.p + Vector2(-70, 30), n, 0.2, 280.0 * sp)
			_fan(boss.p + Vector2(70, 30), n, 0.2, 280.0 * sp)
			return 1.3
		"ring":
			_ring(boss.p + Vector2(0, 30), mini(10 + lvl, 20), 220.0 * sp, boss.t * 1.7)
			_aimed(boss.p + Vector2(0, 40), 360.0 * sp)
			return 1.1
		"stream":
			# A quick string of aimed shots: keep moving.
			boss.stream = mini(5 + lvl, 10)
			boss.stream_t = 0.0
			return 1.5
		"spiral":
			boss.spiral = 2.4
			boss.spiral_t = 0.0
			return 2.9
		"wall":
			_wall(boss.p.y + 70.0, maxf(130.0, 220.0 - 12.0 * lvl), 170.0 * sp)
			return 1.7
		"escorts":
			if enemies.size() >= 8:
				return 0.3
			var k := mini(2 + lvl / 3, 4)
			for i in k:
				var dart := _add_enemy("dart", Vector2(boss.p.x + (i - (k - 1) / 2.0) * 70.0, boss.p.y + 40.0), Vector2(0, 240.0))
				dart.path = 0.5 * (1 if i % 2 == 0 else -1)
			return 1.4
		"laser":
			boss.laser = {"x": clampf(pos.x, 160.0, W - 160.0), "warn": LASER_WARN, "on": 0.0}
			return 2.6
	return 1.0

## Attacks that play out over time: the aimed stream, the spiral, the laser.
func _boss_ongoing(dt: float, rate: float, ev: Array) -> void:
	var lvl: int = boss.lvl
	var sp := _boss_speed(lvl)
	if boss.stream > 0:
		boss.stream_t -= dt * rate
		if boss.stream_t <= 0.0:
			boss.stream_t = 0.08
			boss.stream -= 1
			_aimed(boss.p + Vector2(0, 40), 380.0 * sp)
	if boss.spiral > 0.0:
		boss.spiral -= dt
		boss.spiral_t -= dt * rate
		if boss.spiral_t <= 0.0:
			boss.spiral_t = 0.11
			boss.spin += 0.33
			_ring(boss.p + Vector2(0, 30), mini(2 + lvl / 3, 5), 210.0 * sp, boss.spin)
	var lz: Dictionary = boss.laser
	if lz.is_empty():
		return
	if lz.on <= 0.0:
		# Fires once the warning has run AND the ship is on its mark, so
		# the beam always comes down exactly on the sight line.
		lz.warn = maxf(0.0, lz.warn - dt)
		if lz.warn <= 0.0 and absf(boss.p.x - lz.x) < 1.0:
			lz.on = minf(0.8 + 0.04 * lvl, 1.2)
			ev.append("laser")
		return
	lz.on -= dt
	if lz.on <= 0.0:
		boss.laser = {}
	elif invuln <= 0.0 and pos.y > boss.p.y and absf(pos.x - boss.p.x) < LASER_HALF + PLAYER_HIT:
		_player_hit()

## True while the beam is firing (not during its warning).
func laser_on() -> bool:
	return not boss.is_empty() and not (boss.laser as Dictionary).is_empty() and boss.laser.on > 0.0

## A curtain of bullets across the screen with one gap to slip through,
## never over an island at the fighter's height.
func _wall(y: float, gap: float, speed: float) -> void:
	var lo := gap / 2.0 + 30.0
	var gx := rng.randf_range(lo, W - lo)
	for tries in 8:
		if not _in_island(Vector2(gx, pos.y)):
			break
		gx = rng.randf_range(lo, W - lo)
	var x := 18.0
	while x < W:
		if absf(x - gx) > gap / 2.0:
			bullets.append({"p": Vector2(x, y), "v": Vector2(0, speed * DIFFS[diff].bullet)})
		x += 36.0

func _boss_down(ev: Array) -> void:
	if boss.is_empty():
		return
	score += 3000 + stage * 1000
	boss = {}
	bullets = []
	state = "clear"
	ev.append("boss_down")
	ev.append("clear")

## After the pause following a cleared stage or the last life.
func next() -> void:
	if state == "clear":
		stage += 1
		start_stage()
	elif state == "dead":
		state = "over"
