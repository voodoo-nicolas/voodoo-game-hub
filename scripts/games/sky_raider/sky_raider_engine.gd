extends RefCounted

## Sky Raider: a vertical-scrolling shooter. The fighter fires on its own;
## the player slides it around to dodge bullets while waves of darts,
## gunships, ground turrets and bombers come down the screen, and a boss
## closes every stage. Power-ups widen the guns. Pure logic in world units
## (W x H, y grows downwards), stepped by the game.

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
const DIFFS := [
	{"bullet": 0.75, "fire": 0.65, "hp": 0.8},
	{"bullet": 1.0, "fire": 1.0, "hp": 1.0},
	{"bullet": 1.2, "fire": 1.4, "hp": 1.2},
]
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
var islands: Array = []       # scenery: {"p", "pts": PackedVector2Array}
var boss: Dictionary = {}
var stage_t: float = 0.0
var scrolled: float = 0.0
var kills: int = 0
var _fire_t: float = 0.0
var _wave_t: float = 1.5
var _island_t: float = 0.0
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
	bombs = 2
	power = 1
	kills = 0
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
	islands = []
	var y := H
	while y > -200.0:
		_add_island(y)
		y -= rng.randf_range(300.0, 520.0)

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
		boss.hp -= 30
		boss.hit = 0.2
	invuln = maxf(invuln, 1.0)
	return true

# ---------- one frame ----------

## Returns events: "kill", "big_kill", "hit", "hurt", "power", "bomb_item",
## "life", "boss", "boss_down", "clear", "dead".
func step(dt: float) -> Array:
	var ev: Array = []
	if state != "play":
		return ev
	var lives0 := lives
	stage_t += dt
	scrolled += SCROLL * dt
	invuln = maxf(0.0, invuln - dt)
	_scenery(dt)
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
	islands = islands.filter(func(i): return i.p.y < H + 400.0)
	_island_t -= dt
	if _island_t <= 0.0:
		_island_t = rng.randf_range(3.5, 6.0)
		_add_island(-300.0)

func _add_island(y: float) -> void:
	var c := Vector2(rng.randf_range(60.0, W - 60.0), y)
	var n := 11
	var r := rng.randf_range(90.0, 180.0)
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a) * r * rng.randf_range(0.65, 1.2), sin(a) * r * rng.randf_range(0.5, 0.9)))
	islands.append({"p": c, "pts": pts})

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
	_wave_t = rng.randf_range(2.0, 3.4) / (1.0 + 0.08 * (stage - 1))
	var r := rng.randf()
	if r < 0.4:
		# A line of darts swooping down along a sine.
		var n := rng.randi_range(4, 6)
		var x0 := rng.randf_range(140.0, W - 140.0)
		for k in n:
			var dart := _add_enemy("dart", Vector2(x0, -40.0 - k * 60.0), Vector2(0, 260.0))
			dart.path = rng.randf_range(0.6, 1.0) * (1 if rng.randf() < 0.5 else -1)
	elif r < 0.62:
		for k in rng.randi_range(1, 2):
			var e := _add_enemy("gunship", Vector2(rng.randf_range(100.0, W - 100.0), -50.0), Vector2(0, 160.0))
			e.path = rng.randf_range(180.0, 380.0)   # where it stops
	elif r < 0.85:
		var x := rng.randf_range(80.0, W - 80.0)
		_add_enemy("turret", Vector2(x, -40.0), Vector2(0, SCROLL))
		if rng.randf() < 0.5:
			_add_enemy("turret", Vector2(clampf(W - x, 80.0, W - 80.0), -110.0), Vector2(0, SCROLL))
	elif stage >= 2 or stage_t > 25.0:
		_add_enemy("bomber", Vector2(rng.randf_range(160.0, W - 160.0), -80.0), Vector2(0, 55.0))
	else:
		_wave_t = 0.2

func _add_enemy(kind: String, p: Vector2, v: Vector2) -> Dictionary:
	var hp := int(ceilf(KINDS[kind].hp * DIFFS[diff].hp * (1.0 + 0.12 * (stage - 1))))
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
					if rng.randf() < 0.35:
						_aimed(e.p, 260.0)
				"gunship":
					e.cool = 1.4
					_fan(e.p, 3, 0.25, 270.0)
				"turret":
					e.cool = 1.8
					_aimed(e.p, 300.0)
				"bomber":
					e.cool = 2.2
					_ring(e.p, 12, 200.0, e.t)
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
	elif e.kind == "gunship" and rng.randf() < 0.45:
		drop = "P" if power < MAX_POWER and rng.randf() < 0.7 else "B"
	elif kills % 15 == 0:
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
	power = maxi(1, power - 1)
	bullets = []
	invuln = 2.2
	if lives <= 0:
		state = "dead"

# ---------- the boss ----------

func _spawn_boss() -> void:
	var hp := int((220 + stage * 90) * DIFFS[diff].hp)
	boss = {"p": Vector2(W / 2.0, -140.0), "hp": hp, "max": hp, "t": 0.0, "cool": 2.0, "hit": 0.0, "phase": 0}

func _boss_hit(p: Vector2) -> bool:
	var d: Vector2 = p - boss.p
	return absf(d.x) < 120.0 and absf(d.y) < 55.0 or d.length() < 70.0

func _step_boss(dt: float, ev: Array) -> void:
	if boss.is_empty():
		return
	boss.t += dt
	boss.hit = maxf(0.0, boss.hit - dt)
	var target_y := 210.0
	if boss.p.y < target_y:
		boss.p.y += 90.0 * dt
		return
	boss.p.x = W / 2.0 + sin(boss.t * 0.7) * (W / 2.0 - 160.0)
	boss.phase = 0 if float(boss.hp) / boss.max > 0.5 else 1
	boss.cool -= dt * DIFFS[diff].fire
	if boss.cool <= 0.0:
		if boss.phase == 0:
			boss.cool = 1.3
			_fan(boss.p + Vector2(-70, 30), 3, 0.22, 280.0)
			_fan(boss.p + Vector2(70, 30), 3, 0.22, 280.0)
		else:
			boss.cool = 0.9
			_ring(boss.p + Vector2(0, 30), 10 + mini(stage, 6), 220.0, boss.t * 1.7)
			_aimed(boss.p + Vector2(0, 40), 360.0)
	if boss.hp <= 0:
		_boss_down(ev)

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
