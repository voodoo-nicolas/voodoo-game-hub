extends RefCounted

## Ink Ninja engine: pure logic, no Nodes (headless-testable).
## World units: the camera sees VIEW_W x H; the ground top is at GROUND.
## A stage is a strip of ground with pits, ledges, foes and ink scrolls,
## ending in a walled arena where a boss waits. 10 stages; boss kinds rotate.

const VIEW_W := 1280.0
const H := 720.0
const GROUND := 600.0
const STAGES := 10

const GRAV := 2200.0
const RUN := 380.0
const JUMP_V := 860.0
const WALL_SLIDE := 160.0
const DASH_V := 900.0
const DASH_T := 0.18
const DASH_CD := 0.7
const SLASH_T := 0.22
const SLASH_REACH := 92.0
const STAR_V := 900.0
const INVULN := 1.0
const PW := 34.0   # player box
const PH := 70.0
const MAX_HP := 5
const START_STARS := 8

const BOSS_NAMES := ["Iron Monk", "Twin Blade", "Paper Crane", "Shadow Daimyo"]

var diff := 1
var stage := 1
var score := 0
var lives := 3
var state := "play"   # play, dead, won, over, cleared
var length := 4000.0

# player
var px := 120.0
var py := GROUND
var vx := 0.0
var vy := 0.0
var facing := 1
var on_ground := true
var wall := 0           # -1 / 1 when sliding on a wall
var jumps := 0
var hp := MAX_HP
var stars := START_STARS
var dash_t := 0.0
var dash_cd := 0.0
var slash_t := 0.0
var slash_hit := {}     # foes already hit by this slash
var hurt_t := 0.0
var run_t := 0.0
var combo := 0
var combo_t := 0.0

var solids: Array = []     # Rect2 (ground pieces, ledges, walls)
var pits: Array = []       # [x0, x1]
var foes: Array = []       # Dictionary
var shots: Array = []      # {x, y, vx, vy, mine}
var scrolls: Array = []    # Vector2
var boss := {}
var arena_x := 0.0
var locked := false
var time := 0.0
var rng := RandomNumberGenerator.new()
var events: Array = []

func reset(d: int) -> void:
	diff = clampi(d, 0, 2)
	stage = 1
	score = 0
	lives = 3
	hp = MAX_HP
	stars = START_STARS
	build_stage()

## Speed / aggression multiplier for foes.
func power() -> float:
	return [0.75, 1.0, 1.3][diff] * (1.0 + (stage - 1) * 0.06)

func build_stage() -> void:
	rng.seed = stage * 7919 + 13
	state = "play"
	time = 0.0
	length = 3600.0 + stage * 500.0
	arena_x = length
	locked = false
	solids.clear()
	pits.clear()
	foes.clear()
	shots.clear()
	scrolls.clear()
	boss = {}
	# Ground with pits (none in the first 700 or in the arena).
	var x := 0.0
	var gx := 0.0
	x = 700.0
	while x < length - 500.0:
		x += rng.randf_range(500.0, 900.0)
		if x > length - 500.0:
			break
		if rng.randf() < 0.35 + stage * 0.03:
			var w := rng.randf_range(110.0, 170.0 + stage * 6.0)
			solids.append(Rect2(gx, GROUND, x - gx, 200))
			pits.append([x, x + w])
			gx = x + w
			x += w
	solids.append(Rect2(gx, GROUND, length + VIEW_W - gx, 200))
	# Left and right world walls (the right one closes the arena).
	solids.append(Rect2(-60, -400, 60, 1300))
	solids.append(Rect2(length + VIEW_W - 60, -400, 60, 1300))
	# Ledges and pillars to climb.
	x = 500.0
	while x < length - 600.0:
		x += rng.randf_range(350.0, 650.0)
		if _over_pit(x) or _over_pit(x + 160):
			continue
		if rng.randf() < 0.3:
			solids.append(Rect2(x, GROUND - 140, 46, 140))     # a pillar: one jump clears it (a taller one turned the second jump into a wall-kick)
		else:
			var lw := rng.randf_range(160.0, 260.0)
			var ly := GROUND - rng.randf_range(130.0, 190.0)
			solids.append(Rect2(x, ly, lw, 22))
			scrolls.append(Vector2(x + lw / 2.0, ly - 40))
	# Foes.
	x = 900.0
	while x < length - 300.0:
		x += rng.randf_range(260.0, 520.0) / (1.0 + diff * 0.15)
		if _over_pit(x):
			continue
		var kinds := ["blade"]
		if stage >= 2:
			kinds.append("thrower")
		if stage >= 3:
			kinds.append("leaper")
		if stage >= 5:
			kinds.append("brute")
		var k: String = kinds[rng.randi() % kinds.size()]
		var hp_f: int = {"blade": 1, "thrower": 1, "leaper": 1, "brute": 3}[k]
		foes.append({"kind": k, "x": x, "y": GROUND, "vx": 0.0, "vy": 0.0, "hp": hp_f, "face": -1,
			"t": rng.randf() * 2.0, "atk": 0.0, "hit": 0.0, "id": foes.size()})
	for i in 3:
		var sx := rng.randf_range(300.0, length - 300.0)
		if not _over_pit(sx):
			scrolls.append(Vector2(sx, GROUND - 60))
	px = 120.0
	py = GROUND
	vx = 0.0
	vy = 0.0
	facing = 1
	on_ground = true
	wall = 0
	dash_t = 0.0
	slash_t = 0.0
	hurt_t = 0.0

func boss_kind() -> int:
	return (stage - 1) % BOSS_NAMES.size()

func boss_name() -> String:
	return BOSS_NAMES[boss_kind()]

func _over_pit(x: float) -> bool:
	for p in pits:
		if x > p[0] - 40 and x < p[1] + 40:
			return true
	return false

func _spawn_boss() -> void:
	var k := boss_kind()
	var hpb := int((12 + stage * 2) * [0.7, 1.0, 1.3][diff])
	boss = {"kind": k, "x": arena_x + VIEW_W - 260, "y": GROUND, "vx": 0.0, "vy": 0.0, "hp": hpb, "max": hpb,
		"face": -1, "phase": "idle", "t": 1.2, "hit": 0.0, "n": 0}
	events.append("boss")

# ---------- step ----------

## move: -1..1, jump/slash/throw/dash: pressed this frame. Returns events.
func step(dt: float, move: float, jump: bool, slash: bool, throw: bool, dash: bool) -> Array:
	events = []
	if state != "play":
		return events
	time += dt
	hurt_t = maxf(0.0, hurt_t - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	_player(dt, move, jump, slash, throw, dash)
	_foes(dt)
	_boss(dt)
	_shots(dt)
	for s in scrolls.duplicate():
		if absf(s.x - px) < 40 and absf(s.y - (py - PH / 2)) < 60:
			scrolls.erase(s)
			score += 50
			events.append("scroll")
	if not locked and px > arena_x + 80:
		locked = true
		solids.append(Rect2(arena_x, -400, 40, GROUND + 400))   # the gate shuts behind you
		_spawn_boss()
	if py > H + 120:
		_hurt(MAX_HP, true)
	return events

func _player(dt: float, move: float, jump: bool, slash: bool, throw: bool, dash: bool) -> void:
	if absf(move) > 0.2:
		facing = 1 if move > 0 else -1
	if dash and dash_cd <= 0.0:
		dash_t = DASH_T
		dash_cd = DASH_CD
		events.append("dash")
	if dash_t > 0.0:
		dash_t -= dt
		vx = facing * DASH_V
		vy = 0.0
	else:
		var target := move * RUN
		vx = move_toward(vx, target, (3000.0 if on_ground else 1800.0) * dt)
		vy += GRAV * dt
		if wall != 0 and vy > WALL_SLIDE:
			vy = WALL_SLIDE
	if jump:
		if on_ground:
			vy = -JUMP_V
			jumps = 1
			events.append("jump")
		elif wall != 0:
			vy = -JUMP_V * 0.95
			vx = -wall * RUN * 1.3
			facing = -wall
			jumps = 1
			events.append("walljump")
		elif jumps < 2:
			vy = -JUMP_V * 0.85
			jumps = 2
			events.append("jump")
	if slash and slash_t <= 0.0:
		slash_t = SLASH_T
		slash_hit = {}
		events.append("slash")
	if throw and stars > 0:
		stars -= 1
		shots.append({"x": px + facing * 20, "y": py - PH * 0.6, "vx": facing * STAR_V, "vy": 0.0, "mine": true, "life": 1.2})
		events.append("throw")
	# Move and collide, axis by axis.
	px += vx * dt
	var r := _box()
	wall = 0
	for s in solids:
		if r.intersects(s):
			if vx > 0 or (vx == 0 and px < s.get_center().x):
				px = s.position.x - PW / 2
				if not on_ground and move > 0.2:
					wall = 1
			else:
				px = s.end.x + PW / 2
				if not on_ground and move < -0.2:
					wall = -1
			r = _box()
	py += vy * dt
	r = _box()
	on_ground = false
	for s in solids:
		if r.intersects(s):
			if vy >= 0:
				py = s.position.y
				vy = 0.0
				on_ground = true
				jumps = 0
			else:
				py = s.end.y + PH
				vy = 0.0
			r = _box()
	if on_ground:
		wall = 0
	if locked:
		px = maxf(px, arena_x + 40 + PW / 2)
	if on_ground and absf(vx) > 10:
		run_t += dt
	if slash_t > 0.0:
		slash_t -= dt
		_slash_hits()

func _box() -> Rect2:
	return Rect2(px - PW / 2, py - PH, PW, PH)

func slash_rect() -> Rect2:
	var x0 := px if facing > 0 else px - SLASH_REACH
	return Rect2(x0, py - PH - 10, SLASH_REACH, PH + 20)

func _slash_hits() -> void:
	var sr := slash_rect()
	for f in foes:
		if f.hp > 0 and not slash_hit.has(f.id) and sr.intersects(_foe_box(f)):
			slash_hit[f.id] = true
			_hit_foe(f, 1, facing)
	if not boss.is_empty() and boss.hp > 0 and not slash_hit.has("boss") and sr.intersects(boss_box()):
		slash_hit["boss"] = true
		_hit_boss(1)
	# A slash cuts enemy stars out of the air.
	for s in shots:
		if not s.mine and sr.has_point(Vector2(s.x, s.y)):
			s.life = 0.0
			score += 10
			events.append("parry")

func _foe_box(f: Dictionary) -> Rect2:
	var w := 50.0 if f.kind == "brute" else 34.0
	var h := 90.0 if f.kind == "brute" else 70.0
	return Rect2(f.x - w / 2, f.y - h, w, h)

func boss_box() -> Rect2:
	return Rect2(boss.x - 34, boss.y - 110, 68, 110)

func _hit_foe(f: Dictionary, dmg: int, dir: int) -> void:
	f.hp -= dmg
	f.hit = 0.15
	f.vx = dir * 200.0
	if f.hp <= 0:
		combo += 1
		combo_t = 2.0
		score += 100 * mini(combo, 5)
		events.append("kill")
		events.append("ink:%d:%d" % [int(f.x), int(f.y - 40)])
		if f.kind == "thrower" and rng.randf() < 0.6:
			stars += 2
	else:
		events.append("hit")

func _hit_boss(dmg: int) -> void:
	boss.hp -= dmg
	boss.hit = 0.15
	events.append("bosshit")
	events.append("ink:%d:%d" % [int(boss.x), int(boss.y - 60)])
	if boss.hp <= 0:
		score += 2000 + maxi(0, int(300 - time) * 5)
		events.append("bosskill")
		state = "won"
		events.append("win")

func _hurt(dmg: int, fell: bool = false) -> void:
	if not fell and (hurt_t > 0.0 or dash_t > 0.0):
		return   # a dash passes through attacks
	hp -= dmg
	hurt_t = INVULN
	events.append("hurt")
	events.append("ink:%d:%d" % [int(px), int(py - 40)])
	if hp <= 0:
		lives -= 1
		state = "over" if lives <= 0 else "dead"
		events.append("die")
	elif fell:
		pass

## After "dead": restart the stage with full health.
func retry() -> void:
	hp = MAX_HP
	stars = maxi(stars, START_STARS)
	build_stage()

## After "won": next stage, or the campaign is cleared.
func next_stage() -> void:
	if stage >= STAGES:
		state = "cleared"
		return
	stage += 1
	hp = mini(MAX_HP, hp + 2)
	stars = maxi(stars, START_STARS)
	build_stage()

func _foes(dt: float) -> void:
	var p := power()
	for f in foes:
		if f.hp <= 0:
			continue
		f.hit = maxf(0.0, f.hit - dt)
		var dx: float = px - f.x
		if absf(dx) > VIEW_W * 0.7:
			continue   # asleep off screen
		f.face = 1 if dx > 0 else -1
		f.t -= dt * p
		match f.kind:
			"blade", "brute":
				var spd := (90.0 if f.kind == "brute" else 150.0) * p
				if f.atk > 0.0:
					f.atk -= dt * p
					if f.atk <= 0.0 and absf(dx) < 80 and absf(py - f.y) < 60:
						_hurt(2 if f.kind == "brute" else 1)
				elif absf(dx) < 70:
					f.atk = 0.45   # wind-up, then the cut lands
					events.append("foeswing")
				else:
					f.vx = move_toward(f.vx, f.face * spd, 600 * dt)
			"thrower":
				f.vx = move_toward(f.vx, 0.0, 600 * dt)
				if f.t <= 0.0 and absf(dx) < 800:
					f.t = 2.2
					var sp := 520.0 * p
					shots.append({"x": f.x, "y": f.y - 45, "vx": f.face * sp, "vy": 0.0, "mine": false, "life": 2.0})
					events.append("foethrow")
			"leaper":
				if f.y >= GROUND and f.t <= 0.0 and absf(dx) < 500:
					f.t = 1.8
					f.vy = -700.0
					f.vx = clampf(dx * 1.1, -420, 420)
		f.vy += GRAV * dt
		var nx: float = f.x + f.vx * dt
		if f.y >= GROUND and _over_pit(nx) and f.kind != "leaper":
			f.vx = 0.0   # foes don't walk into pits
		else:
			f.x = nx
		f.y += f.vy * dt
		if f.y >= GROUND and not _pit_under(f.x):
			f.y = GROUND
			f.vy = 0.0
			if f.kind == "leaper":
				f.vx = 0.0
		if f.y > H + 100:
			f.hp = 0
		if f.hp > 0 and _foe_box(f).intersects(_box()):
			_hurt(1)
	foes = foes.filter(func(f): return f.hp > 0)

func _pit_under(x: float) -> bool:
	for pt in pits:
		if x > pt[0] and x < pt[1]:
			return true
	return false

func _boss(dt: float) -> void:
	if boss.is_empty() or boss.hp <= 0:
		return
	var p := power()
	boss.hit = maxf(0.0, boss.hit - dt)
	var dx: float = px - boss.x
	boss.t -= dt * p
	var lo := arena_x + 80
	var hi := arena_x + VIEW_W - 80
	match boss.phase:
		"idle":
			boss.face = 1 if dx > 0 else -1
			boss.vx = move_toward(boss.vx, boss.face * 90.0, 400 * dt)
			if boss.t <= 0.0:
				var picks: Array = [["charge", "leap", "fan"], ["charge", "charge", "fan"], ["fan", "leap", "fan"], ["leap", "charge", "fan"]][boss.kind]
				boss.phase = picks[boss.n % 3]
				boss.n += 1
				boss.t = 0.6   # telegraph
				events.append("telegraph")
		"charge":
			if boss.t > 0.0:
				boss.vx = 0.0
			else:
				boss.vx = boss.face * 700.0 * p
				if boss.x <= lo or boss.x >= hi or boss.t < -1.2:
					_boss_rest()
		"leap":
			if boss.t <= 0.0 and boss.vy == 0.0 and boss.y >= GROUND:
				boss.vy = -900.0
				boss.vx = clampf(dx * 1.0, -600, 600)
				boss.t = -10.0
		"fan":
			if boss.t <= 0.0:
				var n := 3 + diff + (1 if boss.kind == 2 else 0)
				for i in n:
					var a := -0.5 + i * (0.6 / maxf(1, n - 1))
					var v := Vector2(boss.face * 480.0 * p, 0).rotated(a * boss.face)
					shots.append({"x": boss.x, "y": boss.y - 70, "vx": v.x, "vy": v.y, "mine": false, "life": 2.5})
				events.append("foethrow")
				_boss_rest()
	boss.vy += GRAV * dt
	boss.x = clampf(boss.x + boss.vx * dt, lo, hi)
	boss.y += boss.vy * dt
	if boss.y >= GROUND:
		if boss.vy > 300:
			events.append("slam")
			if on_ground and absf(dx) < 220:
				_hurt(1)
			if boss.phase == "leap":
				_boss_rest()
		boss.y = GROUND
		boss.vy = 0.0
	if boss_box().intersects(_box()):
		_hurt(2 if boss.phase == "charge" else 1)

func _boss_rest() -> void:
	boss.phase = "idle"
	boss.vx = 0.0
	boss.t = maxf(0.7, 1.8 - stage * 0.08 - diff * 0.2)

func _shots(dt: float) -> void:
	for s in shots:
		s.x += s.vx * dt
		s.y += s.vy * dt
		s.life -= dt
		if s.life <= 0.0:
			continue
		var pt := Vector2(s.x, s.y)
		for so in solids:
			if so.has_point(pt):
				s.life = 0.0
		if s.life <= 0.0:
			continue
		if s.mine:
			for f in foes:
				if f.hp > 0 and _foe_box(f).has_point(pt):
					_hit_foe(f, 1, 1 if s.vx > 0 else -1)
					s.life = 0.0
					break
			if s.life > 0.0 and not boss.is_empty() and boss.hp > 0 and boss_box().has_point(pt):
				_hit_boss(1)
				s.life = 0.0
		elif _box().has_point(pt):
			_hurt(1)
			s.life = 0.0
	shots = shots.filter(func(s): return s.life > 0.0)

## Camera left edge (world x).
func cam_x() -> float:
	if locked:
		return arena_x
	return clampf(px - VIEW_W * 0.38, 0.0, arena_x)

func progress() -> float:
	return clampf(px / (arena_x + VIEW_W * 0.5), 0.0, 1.0)
