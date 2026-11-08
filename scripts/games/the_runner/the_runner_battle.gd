extends RefCounted

## A real-time space battle (design doc v2 §1.3, battle_mode "realtime"): your ship and an enemy
## wing in an arena. You steer (stick or drag), tap an enemy to target it; guns fire by themselves
## at the target when it is in range; ability buttons have cooldowns. No Nodes: the screen
## (the_runner_battle_view.gd) calls tick() every frame and draws the state; tests call it headless.
## The engine builds the two sides (engine.battle_player() / battle_enemies()) and takes the result
## (engine.end_battle(outcome, info)).

const ARENA := Vector2(1600, 900)
const RANGE := 600.0
const ENEMY_CD := 1.4             # seconds between shots per gun
const SHIELD_DELAY := 2.5         # seconds without a hit before shields recharge
const ENEMY_SHIELD_REGEN := 2.0
const FLEE_CHANNEL := 3.0
const ABILITY_CD := {"shields": 14.0, "evade": 9.0, "flee": 8.0}
const EVADE_SECS := 2.5
const EVADE_BONUS := 0.45
const MOVE_EVA := 0.10            # extra evasion while moving fast
const HACK_SECS := 6.0

var rng := RandomNumberGenerator.new()
var p := {}                       # the player: pos, vel, hull, max_hull, shield, max_shield, ...
var foes: Array = []              # enemies: pos, hull, max, shield, max_shield, guns, dmg, acc, eva, speed, cd, hacked, alive, fled
var allies: Array = []            # called ships: pos, t, dmg, cd, kind
var shots: Array = []             # visuals only: {a, b, t, hit, mine}
var target := 0
var time := 0.0
var cds := {"shields": 0.0, "evade": 0.0, "flee": 0.0}
var evade_t := 0.0
var flee_t := -1.0                # >= 0 while charging the jump
var spore_t := 0.0
var hack_used := false
var used_calls: Array = []
var outcome := ""                 # "" while fighting; then won / boarded / fled / lost / cloaked / duel_lost
var lucky_saved := false
var broken := 0                   # enemies destroyed
var _since_hit := 99.0

func setup(player: Dictionary, enemies: Array, seed_v: int = 0) -> void:
	rng.seed = seed_v if seed_v != 0 else randi()
	p = player.duplicate(true)
	p["pos"] = Vector2(ARENA.x * 0.22, ARENA.y * 0.5)
	p["vel"] = Vector2.ZERO
	p["max_shield"] = int(player.shield)
	p["shield"] = float(player.shield)
	p["hull"] = float(player.hull)
	p["fire_t"] = 0.0 if player.get("first_shot", false) else 0.6
	foes = []
	var n := enemies.size()
	for i in n:
		var e: Dictionary = enemies[i].duplicate()
		e["pos"] = Vector2(ARENA.x * 0.78, ARENA.y * (0.5 + (i - (n - 1) / 2.0) * 0.26))
		e["max"] = float(e.hull)
		e["hull"] = float(e.hull)
		e["max_shield"] = float(e.shield)
		e["shield"] = float(e.shield)
		e["fire_t"] = rng.randf_range(0.8, 1.6) + (1.5 if player.get("first_shot", false) else 0.0)
		e["hacked"] = 0.0
		e["alive"] = true
		e["fled"] = false
		e["orbit"] = 1.0 if i % 2 == 0 else -1.0
		e["since_hit"] = 99.0
		foes.append(e)
	target = 0

func alive_foes() -> Array:
	return foes.filter(func(e): return e.alive)

func target_foe() -> Dictionary:
	if target >= 0 and target < foes.size() and foes[target].alive:
		return foes[target]
	for i in foes.size():
		if foes[i].alive:
			target = i
			return foes[i]
	return {}

## Tap an enemy: it becomes the target.
func pick_target(i: int) -> void:
	if i >= 0 and i < foes.size() and foes[i].alive:
		target = i

## The nearest living enemy to an arena point, within `r` ( -1 = none).
func foe_at(at: Vector2, r: float = 90.0) -> int:
	var best := -1
	var bd := r
	for i in foes.size():
		if foes[i].alive and foes[i].pos.distance_to(at) < bd:
			bd = foes[i].pos.distance_to(at)
			best = i
	return best

func player_eva() -> float:
	var e := float(p.eva)
	if evade_t > 0.0:
		e += EVADE_BONUS
	if p.vel.length() > float(p.speed) * 0.6:
		e += MOVE_EVA
	return clampf(e, 0.0, 0.85)

# ---------------------------------------------------------------- abilities

func ready(a: String) -> bool:
	if outcome != "":
		return false
	match a:
		"shields": return cds.shields <= 0.0 and p.max_shield > 0 and p.shield < p.max_shield
		"evade": return cds.evade <= 0.0
		"flee": return cds.flee <= 0.0 and flee_t < 0.0 and not p.get("duel", false)
		"hack": return p.get("hack", false) and not hack_used and not target_foe().is_empty()
		"board": return can_board()
	return p.get("calls", []).has(a) and not used_calls.has(a)

func can_board() -> bool:
	var t := target_foe()
	return not t.is_empty() and t.get("board", false) and t.hull <= t.max * 0.25 and not p.get("duel", false)

func use(a: String) -> bool:
	if not ready(a):
		return false
	match a:
		"shields":
			p.shield = minf(float(p.max_shield), float(p.shield) + p.max_shield * 0.5)
			cds.shields = ABILITY_CD.shields
		"evade":
			evade_t = EVADE_SECS
			cds.evade = ABILITY_CD.evade
		"flee":
			flee_t = FLEE_CHANNEL
		"hack":
			hack_used = true
			target_foe().hacked = HACK_SECS
		"board":
			if rng.randf() < float(p.boarding):
				outcome = "boarded"
				for e in foes:
					e.alive = false
			else:
				_hurt_player(p.max_hull * 0.10)
		"shadow_cloak":
			used_calls.append(a)
			outcome = "cloaked"
		"spore_cloud":
			used_calls.append(a)
			spore_t = 12.0
		_:
			used_calls.append(a)
			var n := 2
			var secs := 16.0
			var dmg := 6.0
			var ab := {"escort_wing": [2, 16.0, 5.0], "wingmates": [2, 16.0, 6.0], "raid_fleet": [3, 18.0, 6.0], "allied_fleet": [3, 20.0, 7.0]}
			if ab.has(a):
				n = ab[a][0]
				secs = ab[a][1]
				dmg = ab[a][2]
			for i in n:
				allies.append({"pos": p.pos + Vector2(-80, (i - (n - 1) / 2.0) * 90), "t": secs,
					"dmg": dmg * (1.0 + float(p.get("ally_damage", 0.0))), "fire_t": 0.3 * i, "kind": a})
	return true

# ---------------------------------------------------------------- the clock

## One frame. `move`: the stick (-1..1 each axis).
func tick(dt: float, move: Vector2 = Vector2.ZERO) -> void:
	if outcome != "":
		return
	time += dt
	for k in cds:
		cds[k] = maxf(0.0, cds[k] - dt)
	evade_t = maxf(0.0, evade_t - dt)
	spore_t = maxf(0.0, spore_t - dt)
	_since_hit += dt
	# the player moves
	var want: Vector2 = move.limit_length(1.0) * float(p.speed)
	p.vel = p.vel.lerp(want, clampf(dt * 6.0, 0.0, 1.0))
	p.pos = (p.pos + p.vel * dt).clamp(Vector2(60, 60), ARENA - Vector2(60, 60))
	# shields
	if _since_hit > SHIELD_DELAY and p.shield < p.max_shield:
		p.shield = minf(float(p.max_shield), float(p.shield) + float(p.shield_regen) * dt)
	# jumping out
	if flee_t >= 0.0:
		flee_t -= dt
		if flee_t < 0.0:
			if rng.randf() < float(p.flee):
				outcome = "fled"
				return
			cds.flee = ABILITY_CD.flee
	# the player's guns
	var t := target_foe()
	p.fire_t = float(p.fire_t) - dt
	if not t.is_empty() and flee_t < 0.0 and p.pos.distance_to(t.pos) <= RANGE and p.fire_t <= 0.0:
		p.fire_t = float(p.cd) / maxi(1, int(p.guns))
		var hit := rng.randf() < clampf(float(p.acc) * (1.0 - float(t.eva)), 0.1, 0.95)
		shots.append({"a": p.pos, "b": t.pos, "t": 0.18, "hit": hit, "mine": true})
		if hit:
			_hurt_foe(t, float(p.dmg))
	# allies
	for a in allies.duplicate():
		a.t = float(a.t) - dt
		if a.t <= 0.0:
			allies.erase(a)
			continue
		var at := target_foe()
		if at.is_empty():
			continue
		var goal: Vector2 = at.pos + Vector2(-220, 0).rotated(time * 0.7 + allies.find(a))
		a.pos = a.pos.lerp(goal, clampf(dt * 1.5, 0.0, 1.0))
		a.fire_t = float(a.fire_t) - dt
		if a.fire_t <= 0.0:
			a.fire_t = 0.9
			var hit2 := rng.randf() < 0.8 * (1.0 - float(at.eva))
			shots.append({"a": a.pos, "b": at.pos, "t": 0.15, "hit": hit2, "mine": true})
			if hit2:
				_hurt_foe(at, float(a.dmg))
	# enemies
	for e in foes:
		if not e.alive:
			continue
		e.since_hit = float(e.since_hit) + dt
		e.hacked = maxf(0.0, float(e.hacked) - dt)
		if e.since_hit > SHIELD_DELAY and e.shield < e.max_shield:
			e.shield = minf(float(e.max_shield), float(e.shield) + ENEMY_SHIELD_REGEN * dt)
		var to: Vector2 = p.pos - e.pos
		var d := to.length()
		var want_d := RANGE * 0.6
		var dir := Vector2.ZERO
		if d > want_d + 60.0:
			dir = to.normalized()
		elif d < want_d - 60.0:
			dir = -to.normalized()
		dir += to.normalized().orthogonal() * 0.6 * float(e.orbit)
		e.pos = (e.pos + dir.limit_length(1.0) * float(e.speed) * dt).clamp(Vector2(60, 60), ARENA - Vector2(60, 60))
		e.fire_t = float(e.fire_t) - dt
		if e.hacked <= 0.0 and d <= RANGE and e.fire_t <= 0.0:
			e.fire_t = ENEMY_CD / maxi(1, int(e.guns)) * rng.randf_range(0.85, 1.15)
			var acc := float(e.acc) * (1.0 + float(p.get("lock", 0.0))) * (0.8 if spore_t > 0.0 else 1.0)
			var hit3 := rng.randf() < clampf(acc * (1.0 - player_eva()), 0.05, 0.95)
			shots.append({"a": e.pos, "b": p.pos, "t": 0.18, "hit": hit3, "mine": false})
			if hit3:
				_hurt_player(float(e.dmg))
				if outcome != "":
					return
	for s in shots.duplicate():
		s.t = float(s.t) - dt
		if s.t <= 0.0:
			shots.erase(s)
	if alive_foes().is_empty() and outcome == "":
		outcome = "won"

func _hurt_foe(e: Dictionary, dmg: float) -> void:
	e.since_hit = 0.0
	var absorbed := minf(float(e.shield), dmg)
	e.shield = float(e.shield) - absorbed
	e.hull = float(e.hull) - (dmg - absorbed)
	if e.hull <= 0.0:
		e.hull = 0.0
		e.alive = false
		broken += 1
		return
	# weak enemies flee (Intimidating) or surrender (Warlord): they count as beaten
	if (p.get("scare", false) and e.hull < e.max * 0.35) or (p.get("surrender", false) and e.hull < e.max * 0.25):
		e.alive = false
		e.fled = true

func _hurt_player(dmg: float) -> void:
	_since_hit = 0.0
	var absorbed := minf(float(p.shield), dmg)
	p.shield = float(p.shield) - absorbed
	p.hull = float(p.hull) - (dmg - absorbed)
	if p.hull > 0.0:
		return
	if p.get("duel", false):
		p.hull = 1.0
		outcome = "duel_lost"
	elif p.get("lucky", false) and not lucky_saved:
		lucky_saved = true
		p.hull = 1.0
		flee_t = -1.0
		outcome = "fled"     # Lucky: a critical failure ignored, you limp away
	else:
		p.hull = 0.0
		outcome = "lost"

## What the engine needs to know afterwards.
func result_info() -> Dictionary:
	return {"hull": int(ceil(float(p.hull))), "used_calls": used_calls, "broken": broken, "lucky": lucky_saved}

## A simple pilot for tests and the 10,000-trip sim: targets the weakest, uses abilities, flees when low.
func autopilot_move() -> Vector2:
	var t := target_foe()
	if t.is_empty():
		return Vector2.ZERO
	var best := -1
	var low := INF
	for i in foes.size():
		if foes[i].alive and foes[i].hull < low:
			low = foes[i].hull
			best = i
	pick_target(best)
	for a in p.get("calls", []):
		if ready(a) and a != "shadow_cloak":
			use(a)
	if ready("hack"):
		use("hack")
	if ready("board"):
		use("board")
	if ready("shields") and p.shield < p.max_shield * 0.3:
		use("shields")
	if ready("evade") and p.hull < p.max_hull * 0.6:
		use("evade")
	if p.hull < p.max_hull * 0.25 and ready("flee"):
		use("flee")
	var to: Vector2 = t.pos - p.pos
	var d := to.length()
	if d > RANGE * 0.9:
		return to.normalized()
	return to.normalized().orthogonal()   # circle at range: moving fast dodges more
