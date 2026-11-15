extends RefCounted

## Ink Ninja engine: pure logic, no Nodes (headless-testable).
## World units: the camera sees VIEW_W x H; the ground top is at GROUND.
## A stage is a strip of ground with pits, ledges, foes and ink scrolls,
## ending in a walled arena where a boss waits. 10 stages; boss kinds rotate.
## Owner round 3 (2026-11-15): the ground rolls (a height field, `ground_y()`), and the
## old pits became soft dips, most filled with water (`pools`). Water slows walking 30%;
## deep water lets you swim (A strokes up) but your breath runs out while your head is
## under; surfacing refills it. Nothing has a 90-degree drop any more.

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
const INVULN := 1.3
const PW := 34.0   # player box
const PH := 70.0
const CROUCH_H := 40.0   # crouching: low enemy stars (thrown at 45) fly over
const MAX_HP := 5
const START_STARS := 8
const SEG := 20.0          # height-field sample spacing
const LOWEST := 695.0      # dips never go below this (the screen ends at H)
const WADE := 0.7          # walking speed in water (30% slower)
const AIR := 6.0           # seconds of breath with the head under water
const DROWN_TICK := 1.5    # out of breath: lose a heart this often
const SWIM_V := 430.0      # an A stroke under water
const KNOCK_T := 0.28      # hit: knocked back, no control for this long

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
var crouch := false
var hits_taken := 0   # hearts lost this stage (for "clear a stage without a hit")

var air := AIR
var drown_t := 0.0
var knock_t := 0.0
var in_water := false
var was_wet := false

var solids: Array = []     # Rect2 (ledges, pillars, walls; the ground is `heights`)
var pits: Array = []       # [x0, x1] (no pits since round 3; kept for old callers)
var heights := PackedFloat32Array()   # ground top every SEG world units
var pools: Array = []      # {"x0", "x1", "level"}: water filling a dip
var checkpoints: Array = []   # world x of the stone lanterns; dying restarts at the last one passed
var checkpoint_x := 0.0
var dips: Array = []       # {"x0", "x1", "level", "wet"}: every dip, wet or dry (fog sits in them)
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
	length = (3600.0 + stage * 500.0) * 5.0   # owner 2026-11-15: stages 5x longer ("too short, too quick")
	arena_x = length
	locked = false
	solids.clear()
	pits.clear()
	foes.clear()
	shots.clear()
	scrolls.clear()
	boss = {}
	pools.clear()
	dips.clear()
	# Rolling ground (owner 2026-11-15): two slow waves rising above GROUND, flat at the
	# start and in the arena. The old pits are now soft dips, most filled with water.
	var n := int((length + VIEW_W) / SEG) + 2
	heights.resize(n)
	var amp := minf(110.0 + stage * 6.0, 165.0)   # owner's reference pictures: land that really rises and falls
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	for i in n:
		var gxx := i * SEG
		var wave := 0.5 + 0.5 * (0.6 * sin(gxx / 520.0 + ph1) + 0.4 * sin(gxx / 230.0 + ph2))
		# Terraces: flat stretches joined by short soft ramps, like stepped hillsides.
		var tt := wave * 3.0
		var fl := floorf(tt)
		wave = (fl + smoothstep(0.2, 0.8, tt - fl)) / 3.0
		var rough := sin(gxx * 0.09) * 3.0 + sin(gxx * 0.23 + ph2) * 1.5   # a ragged, hand-painted rim
		var blend := smoothstep(350.0, 800.0, gxx) * (1.0 - smoothstep(length - 700.0, length - 150.0, gxx))
		heights[i] = GROUND - (amp * wave + rough) * blend
	var x := 700.0
	while x < length - 700.0:
		x += rng.randf_range(520.0, 900.0)
		if x > length - 700.0:
			break
		if rng.randf() < 0.35 + stage * 0.04:
			var depth := rng.randf_range(80.0, 150.0 + stage * 6.0)
			var hw := maxf(rng.randf_range(220.0, 420.0), depth * 3.0)   # wide, flat-bottomed lakes with soft banks
			if x + hw > length - 700.0:
				break
			_carve(x, hw, depth, rng.randf() < 0.8)
			x += hw * 1.2
	pits.clear()
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
			var pg := maxf(ground_y(x), ground_y(x + 46))
			solids.append(Rect2(x, minf(ground_y(x), ground_y(x + 46)) - 140, 46, 140 + 140 + pg - minf(ground_y(x), ground_y(x + 46))))     # a pillar: one jump clears it (a taller one turned the second jump into a wall-kick)
		else:
			var lw := rng.randf_range(160.0, 260.0)
			var ly := minf(ground_y(x), ground_y(x + lw)) - rng.randf_range(130.0, 190.0)
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
		foes.append({"kind": k, "x": x, "y": ground_y(x), "vx": 0.0, "vy": 0.0, "hp": hp_f, "face": -1,
			"t": rng.randf() * 2.0, "atk": 0.0, "hit": 0.0, "id": foes.size()})
	for i in 3:
		var sx := rng.randf_range(300.0, length - 300.0)
		if not _over_pit(sx):
			scrolls.append(Vector2(sx, ground_y(sx) - 60))
	# Stone lanterns: 4 checkpoints per stage, each moved onto dry land.
	checkpoints.clear()
	checkpoint_x = 120.0
	for c in range(1, 5):
		var cx := length * c / 5.0
		while water_depth(cx) > 0.0 or _over_pit(cx):
			cx += 40.0
		checkpoints.append(cx)
	px = 120.0
	py = ground_y(px)
	air = AIR
	drown_t = 0.0
	knock_t = 0.0
	in_water = false
	was_wet = false
	vx = 0.0
	vy = 0.0
	facing = 1
	on_ground = true
	wall = 0
	dash_t = 0.0
	slash_t = 0.0
	hurt_t = 0.0
	hits_taken = 0

func boss_kind() -> int:
	if stage >= STAGES:
		return 3   # the last duel is always the Shadow Daimyo (story, ink_ninja_story.gd)
	return (stage - 1) % BOSS_NAMES.size()

func boss_name() -> String:
	return BOSS_NAMES[boss_kind()]

## Over a dip (wet or dry): nothing is placed there.
func _over_pit(x: float) -> bool:
	for d in dips:
		if x > d.x0 - 40 and x < d.x1 + 40:
			return true
	return false

## Ground top at world x (smooth, linear between samples).
func ground_y(x: float) -> float:
	if heights.is_empty():
		return GROUND
	var f := clampf(x / SEG, 0.0, heights.size() - 1.001)
	var i := int(f)
	return lerpf(heights[i], heights[i + 1], f - i)

## Water surface over x, or INF when there is no water there.
func water_level(x: float) -> float:
	for p in pools:
		if x > p.x0 and x < p.x1:
			return p.level
	return INF

## How deep the water is at x (0 = dry).
func water_depth(x: float) -> float:
	var lv := water_level(x)
	return 0.0 if lv == INF else maxf(0.0, ground_y(x) - lv)

## A soft cosine dip centred on cx; wet ones fill with water up to the lower rim.
func _carve(cx: float, hw: float, depth: float, wet: bool) -> void:
	var i0 := maxi(0, int((cx - hw) / SEG))
	var i1 := mini(heights.size() - 1, int((cx + hw) / SEG) + 1)
	for i in range(i0, i1 + 1):
		var dx := absf(i * SEG - cx)
		if dx < hw:
			heights[i] = minf(LOWEST, heights[i] + depth * (1.0 - smoothstep(hw * 0.35, hw, dx)))
	var level := maxf(ground_y(cx - hw), ground_y(cx + hw)) + 6.0
	var a := cx
	while a > cx - hw and ground_y(a) > level:
		a -= 4.0
	var b := cx
	while b < cx + hw and ground_y(b) > level:
		b += 4.0
	dips.append({"x0": cx - hw, "x1": cx + hw, "level": level, "wet": wet and b - a > 60.0})
	if wet and b - a > 60.0:
		pools.append({"x0": a, "x1": b, "level": level})

func _spawn_boss() -> void:
	var k := boss_kind()
	var hpb := int((12 + stage * 2) * [0.7, 1.0, 1.3][diff] * (0.6 if stage == 1 else 1.0))   # the first duel is a gentle one (owner 2026-11-15)
	boss = {"kind": k, "x": arena_x + VIEW_W - 260, "y": GROUND, "vx": 0.0, "vy": 0.0, "hp": hpb, "max": hpb,
		"face": -1, "phase": "idle", "t": 1.2, "hit": 0.0, "n": 0}
	events.append("boss")

# ---------- step ----------

## move: -1..1, jump/slash/throw/dash: pressed this frame. Returns events.
func step(dt: float, move: float, jump: bool, slash: bool, throw: bool, dash: bool, down: bool = false) -> Array:
	events = []
	if state != "play":
		return events
	time += dt
	hurt_t = maxf(0.0, hurt_t - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	crouch = down and on_ground and dash_t <= 0.0
	_player(dt, move, jump, slash, throw, dash)
	_foes(dt)
	_boss(dt)
	_shots(dt)
	for s in scrolls.duplicate():
		if absf(s.x - px) < 40 and absf(s.y - (py - PH / 2)) < 60:
			scrolls.erase(s)
			score += 50
			events.append("scroll")
	for c in checkpoints:
		if px >= c and checkpoint_x < c:
			checkpoint_x = c
			events.append("checkpoint")
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
	var lv := water_level(px)
	in_water = py > lv + 8.0   # feet in the water
	var swim := in_water and ground_y(px) - lv > PH * 0.75   # too deep to stand with the head out
	knock_t = maxf(0.0, knock_t - dt)
	if knock_t > 0.0:
		vy += GRAV * dt
	elif dash_t > 0.0:
		dash_t -= dt
		vx = facing * DASH_V * (WADE if in_water else 1.0)
		vy = 0.0
	else:
		var target := 0.0 if crouch else move * RUN * (WADE if in_water else 1.0)   # crouching: turn only, no walking
		vx = move_toward(vx, target, (3000.0 if on_ground else 1800.0) * dt)
		if in_water:
			vy = minf(vy + GRAV * 0.3 * dt, 200.0)   # water holds you up: a slow sink
		else:
			vy += GRAV * dt
		if wall != 0 and vy > WALL_SLIDE:
			vy = WALL_SLIDE
	if not was_wet and in_water and vy > 250.0:
		events.append("splash")
	was_wet = in_water
	# Breath: only while the head is under water; surfacing refills it at once.
	if py - height() > lv + 4.0:
		air -= dt
		if air <= 0.0:
			drown_t -= dt
			if drown_t <= 0.0:
				drown_t = DROWN_TICK
				_hurt(1, true)
				events.append("drown")
	else:
		if air < AIR - 0.5:
			events.append("breathe")
		air = AIR
		drown_t = 0.0
	if jump and knock_t <= 0.0:
		if in_water and (swim or not on_ground):
			# A stroke: near the surface it leaps you out, deeper it pulls you up.
			vy = -JUMP_V * 0.8 if py - height() < lv + 30.0 else -SWIM_V
			jumps = 1
			events.append("swim")
		elif on_ground:
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
		shots.append({"x": px + facing * 20, "y": py - height() * 0.6, "vx": facing * STAR_V, "vy": 0.0, "mine": true, "life": 1.2})
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
	var was_ground := on_ground
	var fall_v := vy
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
				py = s.end.y + height()
				vy = 0.0
			r = _box()
	# The rolling ground: never sink into it; walking downhill keeps your feet on it.
	var g := ground_y(px)
	if not on_ground and (py >= g or (was_ground and vy >= 0.0 and g - py < 28.0)):
		py = g
		vy = 0.0
		on_ground = true
		jumps = 0
	if on_ground:
		wall = 0
		if not was_ground and fall_v > 300.0:
			events.append("land")
	if locked:
		px = maxf(px, arena_x + 40 + PW / 2)
	if on_ground and absf(vx) > 10:
		run_t += dt
	if slash_t > 0.0:
		slash_t -= dt
		_slash_hits()

func height() -> float:
	return CROUCH_H if crouch else PH

func _box() -> Rect2:
	return Rect2(px - PW / 2, py - height(), PW, height())

func slash_rect() -> Rect2:
	var x0 := px if facing > 0 else px - SLASH_REACH
	return Rect2(x0, py - height() - 10, SLASH_REACH, height() + 20)

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

func _hit_foe(f: Dictionary, dmg: int, dir: int, by_star: bool = false) -> void:
	f.hp -= dmg
	f.hit = 0.15
	f.vx = dir * 200.0
	if f.hp <= 0:
		combo += 1
		combo_t = 2.0
		score += 100 * mini(combo, 5)
		events.append("kill")
		if by_star:
			events.append("starkill")
		if combo == 5:
			events.append("combo5")
		events.append("red:%d:%d" % [int(f.x), int(f.y - 40)])
		if f.kind == "thrower" and rng.randf() < 0.6:
			stars += 2
	else:
		events.append("hit")
		events.append("red:%d:%d" % [int(f.x), int(f.y - 40)])   # damage dealt leaves a faint red mark (owner 2026-11-15)

func _hit_boss(dmg: int) -> void:
	boss.hp -= dmg
	boss.hit = 0.15
	events.append("bosshit")
	events.append("red:%d:%d" % [int(boss.x), int(boss.y - 60)])
	if boss.hp <= 0:
		score += 2000 + maxi(0, int(300 - time) * 5)
		events.append("bosskill")
		state = "won"
		events.append("win")

## from_x: where the blow came from; the hero is knocked away from it (owner 2026-11-15:
## a boss used to pin you and land every hit in a row, "one touch and you die").
func _hurt(dmg: int, fell: bool = false, from_x: float = NAN) -> void:
	if not fell and (hurt_t > 0.0 or dash_t > 0.0):
		return   # a dash passes through attacks
	hp -= dmg
	hits_taken += 1
	hurt_t = INVULN
	if not is_nan(from_x):
		var away := 1.0 if px >= from_x else -1.0
		vx = away * 420.0
		vy = -460.0
		knock_t = KNOCK_T
		on_ground = false
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
	var cp := checkpoint_x
	build_stage()
	restart_at(cp)

## Put the hero back at a lantern (retry after a fall, or Resume from a save).
func restart_at(cp: float) -> void:
	checkpoint_x = cp
	px = cp
	py = ground_y(px)
	foes = foes.filter(func(f): return absf(f.x - px) > 500.0)   # no ambush on the spot

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
						_hurt(2 if f.kind == "brute" else 1, false, f.x)
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
				if f.y >= ground_y(f.x) - 1.0 and f.t <= 0.0 and absf(dx) < 500:
					f.t = 1.8
					f.vy = -700.0
					f.vx = clampf(dx * 1.1, -420, 420)
		f.vy += GRAV * dt
		var nx: float = f.x + f.vx * dt
		if f.y >= ground_y(f.x) - 1.0 and water_depth(nx) > 20.0 and f.kind != "leaper":
			f.vx = 0.0   # foes don't wade into water
		else:
			f.x = nx
		f.y += f.vy * dt
		var fg := ground_y(f.x)
		if f.y >= fg or (f.vy >= 0.0 and fg - f.y < 24.0 and f.kind != "leaper"):
			f.y = fg
			f.vy = 0.0
			if f.kind == "leaper":
				f.vx = 0.0
		if f.y > H + 100:
			f.hp = 0
		if f.hp > 0 and _foe_box(f).intersects(_box()):
			_hurt(1, false, f.x)
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
				boss.vx = boss.face * 700.0 * p * (0.7 if stage == 1 else 1.0)
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
			if on_ground and absf(dx) < (150 if stage == 1 else 220):
				_hurt(1, false, boss.x)
			if boss.phase == "leap":
				_boss_rest()
		boss.y = GROUND
		boss.vy = 0.0
	if boss_box().intersects(_box()):
		_hurt(2 if boss.phase == "charge" and stage > 1 else 1, false, boss.x)

func _boss_rest() -> void:
	boss.phase = "idle"
	boss.vx = 0.0
	boss.t = maxf(0.7, 1.8 - stage * 0.08 - diff * 0.2) + (0.8 if stage == 1 else 0.0)

func _shots(dt: float) -> void:
	for s in shots:
		s.x += s.vx * dt
		s.y += s.vy * dt
		s.life -= dt
		if s.life <= 0.0:
			continue
		var pt := Vector2(s.x, s.y)
		if pt.y > ground_y(pt.x):
			s.life = 0.0
		for so in solids:
			if so.has_point(pt):
				s.life = 0.0
		if s.life <= 0.0:
			continue
		if s.mine:
			for f in foes:
				if f.hp > 0 and _foe_box(f).has_point(pt):
					_hit_foe(f, 1, 1 if s.vx > 0 else -1, true)
					s.life = 0.0
					break
			if s.life > 0.0 and not boss.is_empty() and boss.hp > 0 and boss_box().has_point(pt):
				_hit_boss(1)
				s.life = 0.0
		elif _box().has_point(pt):
			_hurt(1, false, s.x - s.vx)
			s.life = 0.0
	shots = shots.filter(func(s): return s.life > 0.0)

## Camera left edge (world x).
func cam_x() -> float:
	if locked:
		return arena_x
	return clampf(px - VIEW_W * 0.38, 0.0, arena_x)

func progress() -> float:
	return clampf(px / (arena_x + VIEW_W * 0.5), 0.0, 1.0)
