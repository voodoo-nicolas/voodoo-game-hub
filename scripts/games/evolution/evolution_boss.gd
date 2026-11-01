extends RefCounted

## Evolution's bosses (phase 6, owner 2026-11-01): one at the end of each stage (Data.BOSSES), met in that order in
## every run. Static functions on the engine `e` (evolution_engine.gd keeps the state in `e.boss`); the engine calls
## `step` every step, `shot_hit` for each acid / harpoon shot and `shock` for Electric shock and Spine burst.
##
## How a fight works (owner: "do you just swim over them to attack, and swim away when they attack?" Yes):
## - You bite a boss by swimming into it. Each bite chips its health bar and pushes you back off it.
## - Every boss repeats: wander (follows you), warning (its tell: a glow, a raised claw, rearing tentacles), attack,
##   then a dizzy spell. A bite while it is dizzy (or stunned by a shock) does double and does not push you off.
## - Its attack is what hurts you. Some bodies also guard: Old Snapjaw's snout jabs you from the front, Ironclaw's
##   shell blocks bites from the front, the Hollow Leviathan's hide takes a third of a bite unless it is dizzy.
## - Swim far enough away for long enough and it leaves; it comes back later. In Normal, dying sends it away too.
## - Beaten: its DNA reward, a little growth, and the next boss comes at the next stage.
## Bosses are not in `e.npcs`: nothing eats them, the Food magnet and suction leave them alone.

const Data = preload("res://scripts/games/evolution/evolution_data.gd")

const T := {
	"warn_time": 7.0,        # seconds between the warning banner and the boss arriving
	"first_wait": 40.0,      # seconds at the boss's size before it may come (and xp at least `trigger_frac` of the size)
	"trigger_frac": 0.6,
	"leave_t": 15.0,         # seconds out of its reach before it gives up and leaves ...
	"return_cd": 45.0,       # ... and comes back after this many
	"after_win_cd": 30.0,    # quiet time after a win before the next one may be announced
	"revive_cd": 30.0,       # Normal: it leaves when you die and comes back after this many
	"bite_cd": 0.6,
	"tired_bite_cd": 0.3,
	"shot_dmg": 0.6,         # an acid spit
	"venom_t": 4.0,          # a harpoon's venom: seconds ...
	"venom_dps": 0.4,        # ... and bites' worth per second
	"stun_t": 1.2,           # a shock stuns a boss this long, at most once every `stun_cd`
	"stun_cd": 6.0,
	"win_growth": 0.05,      # share of the size's xp for eating what is left of it
	"hp_mult": 1.5,          # owner 2026-11-01 "make the bosses harder": +50% health (attacks hurt 35% more: TUNING.boss_dmg_mult)
	"minion_max": 2,
	"minion_gap": 6.0,
	"minion_life": 14.0,
}

## The next boss this run, {} once all are beaten.
static func next_boss(e) -> Dictionary:
	for bd in Data.BOSSES:
		if not e.bosses_beaten.has(bd.id):
			return bd
	return {}

static func step(e, delta: float) -> void:
	e.boss_cd = maxf(e.boss_cd - delta, 0.0)
	if e.boss.is_empty():
		_maybe_come(e, delta)
		return
	_fight(e, delta)

# ---------- arriving and leaving ----------

static func _maybe_come(e, delta: float) -> void:
	var lv: int = e.level()
	if lv != e.boss_lvl:
		e.boss_lvl = lv
		e.boss_lvl_t = 0.0
	e.boss_lvl_t += delta
	var bd := next_boss(e)
	if e.boss_warn > 0.0:
		e.boss_warn -= delta
		if e.boss_warn <= 0.0 and not bd.is_empty():
			spawn(e, bd)
		return
	if bd.is_empty() or not e.has_bars() or not e.alive or e.boss_cd > 0.0 or e.grace > 0.0 or lv < int(bd.size):
		return
	var ready: bool = lv > int(bd.size) or lv >= Data.LEVELS.size() or e.xp_frac() >= T.trigger_frac
	if not ready or e.boss_lvl_t < T.first_wait:
		return
	e.boss_warn = T.warn_time
	e.events.append({"type": "boss_warn", "id": bd.id})
	_mission(e, bd)

## "Defeat <boss>" on the mission list (once per boss: it stays when the boss swims away).
static func _mission(e, bd: Dictionary) -> void:
	for m in e.missions:
		if not m.done and m.kind == "boss" and m.get("species", "") == bd.id:
			return
	e._add_mission({"kind": "boss", "species": bd.id, "target": 1, "text": "Defeat %s", "args": [bd.name], "reward": ""})

## The boss swims in from just outside what you can see (never from above the surface).
static func spawn(e, bd: Dictionary) -> void:
	var pr: float = e.radius_of(e.player.mass)
	var r: float = pr * float(bd.big)
	var dir := Vector2.RIGHT.rotated(e.rng.randf() * TAU)
	if dir.y < -0.2:
		dir.y = -dir.y
	var pos: Vector2 = e.player.pos + dir * (e.view_r * 1.1 + r)
	pos.y = maxf(pos.y, r + 40.0)
	e.boss = {"id": bd.id, "pos": pos, "vel": Vector2.ZERO, "r": r, "hp": float(bd.hp) * T.hp_mult, "hp_max": float(bd.hp) * T.hp_mult,
		"state": "come", "t": 0.0, "dur": 0.0, "face": (e.player.pos - pos).angle(), "aim": 0.0,
		"bite_cd": 0.0, "stun": 0.0, "stun_cd": 0.0, "venom": 0.0, "hit": 0.0, "struck": false,
		"grab": 0.0, "minions": [], "minion_t": 2.0, "ink_t": 0.0, "ink_pos": pos, "ink_cd": 7.0, "away": 0.0}
	e.boss_warn = 0.0
	e._hunter_cd = maxf(e._hunter_cd, 2.0)
	_mission(e, bd)
	e.events.append({"type": "boss", "id": bd.id})

static func leave(e, cd: float) -> void:
	if e.boss.is_empty():
		return
	e.events.append({"type": "boss_left", "id": e.boss.id})
	e.boss = {}
	e.boss_cd = cd
	e.boss_warn = 0.0

# ---------- the fight ----------

static func _enter(e, b: Dictionary, state: String) -> void:
	var bd := Data.boss_of(b.id)
	b.state = state
	b.t = 0.0
	b.struck = false
	match state:
		"idle":
			b.dur = e.rng.randf_range(2.2, 3.6)
		"tell":
			b.dur = float(bd.tell)
			b.aim = b.face
			e.events.append({"type": "boss_tell", "id": b.id})
		"attack":
			b.dur = float(bd.attack)
			b.aim = b.face
			e.events.append({"type": "boss_attack", "id": b.id})
		"tired":
			b.dur = float(bd.tired)
			e.events.append({"type": "boss_tired", "id": b.id})

static func _fight(e, delta: float) -> void:
	var b: Dictionary = e.boss
	var pr: float = e.radius_of(e.player.mass)
	var sb: float = maxf(e.top_speed(), 150.0)
	var to_p: Vector2 = e.player.pos - b.pos
	var d := to_p.length()
	var dir_p := to_p / maxf(d, 0.001)
	b.t += delta
	b.bite_cd = maxf(b.bite_cd - delta, 0.0)
	b.hit = maxf(b.hit - delta, 0.0)
	b.stun_cd = maxf(b.stun_cd - delta, 0.0)
	e._hunter_cd = maxf(e._hunter_cd, 1.0)      # no new hunters while a boss is here
	if b.venom > 0.0:
		b.venom -= delta
		damage(e, T.venom_dps * delta, false)
		if e.boss.is_empty():
			return
	# Too far away for too long: it gives up.
	if d > b.r * 4.0 + e.view_r * 1.5:
		b.away += delta
		if b.away > T.leave_t:
			leave(e, T.return_cd)
			return
	else:
		b.away = 0.0
	if b.stun > 0.0:
		b.stun -= delta
		b.vel = b.vel.lerp(Vector2.ZERO, clampf(6.0 * delta, 0.0, 1.0))
	elif b.state == "come":
		_move(b, dir_p * sb * 0.9, delta, 3.0)
		b.face = rotate_toward(b.face, dir_p.angle(), 3.0 * delta)
		if d < b.r * 2.6 + pr:
			_enter(e, b, "idle")
	else:
		match b.id:
			"snapjaw":
				_snapjaw(e, b, delta, d, dir_p, pr, sb)
			"lantern":
				_lantern(e, b, delta, d, dir_p, pr, sb)
			"ironclaw":
				_ironclaw(e, b, delta, d, dir_p, pr, sb)
			"kraken":
				_kraken(e, b, delta, d, dir_p, pr, sb)
			"leviathan":
				_leviathan(e, b, delta, d, dir_p, pr, sb)
		if b.t >= b.dur and b.state != "come":
			var nxt: String = {"idle": "tell", "tell": "attack", "attack": "tired", "tired": "idle"}[b.state]
			_enter(e, b, nxt)
	b.pos += b.vel * delta
	if b.pos.y < b.r * 0.8:
		b.pos.y = b.r * 0.8
		b.vel.y = maxf(b.vel.y, 0.0)
	if e.boss.is_empty():
		return
	_minions(e, b, delta, pr, sb)
	if b.ink_t > 0.0:
		b.ink_t -= delta
	if b.grab > 0.0:
		_held(e, b, delta, pr)
	elif b.state != "attack":
		_contact(e, b, pr)

static func _move(b: Dictionary, want: Vector2, delta: float, k: float) -> void:
	b.vel = b.vel.lerp(want, clampf(k * delta, 0.0, 1.0))

## Keeps about `want_d` from you, drifting round you a little (`side`).
static func _hover(b: Dictionary, d: float, dir_p: Vector2, want_d: float, speed: float, side: float, delta: float) -> void:
	var radial := dir_p * clampf((d - want_d) / maxf(want_d, 1.0), -1.0, 1.0)
	var tang := dir_p.orthogonal() * side
	_move(b, (radial + tang).limit_length(1.0) * speed, delta, 3.0)

## The player swam into the boss: a bite on it, or a jab / a clang off its guard.
static func _contact(e, b: Dictionary, pr: float) -> void:
	var to_p: Vector2 = e.player.pos - b.pos
	var d := to_p.length()
	if d > b.r * 0.92 + pr * 0.6 or b.bite_cd > 0.0:
		return
	var dir_p := to_p / maxf(d, 0.001)
	var dizzy: bool = b.state == "tired" or b.stun > 0.0
	var front: float = absf(angle_difference(b.face, dir_p.angle()))
	if not dizzy and b.id == "snapjaw" and front < 0.55:
		e.hurt(0.04, b.id)
		_push(e, b, dir_p, pr)
		b.bite_cd = 0.8
		e.events.append({"type": "boss_block", "id": b.id, "pos": b.pos + dir_p * b.r})
		return
	if not dizzy and b.id == "ironclaw" and front < 1.15:
		_push(e, b, dir_p, pr)
		b.bite_cd = 0.6
		e.events.append({"type": "boss_block", "id": b.id, "pos": b.pos + dir_p * b.r})
		return
	var dmg: float = e.bite_power() * (2.0 if dizzy else 1.0)
	if b.id == "leviathan" and not dizzy:
		dmg *= 0.35
	b.bite_cd = T.tired_bite_cd if dizzy else T.bite_cd
	if not dizzy:
		_push(e, b, dir_p, pr)
	e.events.append({"type": "boss_bitten", "id": b.id, "pos": b.pos + dir_p * b.r * 0.9, "dizzy": dizzy})
	damage(e, dmg)

## Shoves you back off its body.
static func _push(e, b: Dictionary, dir_p: Vector2, pr: float) -> void:
	e.player.pos = b.pos + dir_p * (b.r * 0.95 + pr * 0.7)
	e.player.vel = dir_p * maxf(e.top_speed(), 150.0) * 1.8

## Bites, spit and venom: `amount` in bites.
static func damage(e, amount: float, flash: bool = true) -> void:
	if e.boss.is_empty():
		return
	var b: Dictionary = e.boss
	b.hp -= amount
	if flash:
		b.hit = 0.15
	if b.hp <= 0.0:
		_win(e)

static func _win(e) -> void:
	var b: Dictionary = e.boss
	var bd := Data.boss_of(b.id)
	e.bosses_beaten[b.id] = true
	e.bosses_run += 1
	e.dna += int(bd.dna)
	e.events.append({"type": "boss_beaten", "id": b.id, "dna": int(bd.dna), "pos": b.pos, "r": b.r, "n": e.bosses_run})
	e.boss = {}
	e.boss_cd = T.after_win_cd
	e._gain_xp(e.xp_span(e.level()) * T.win_growth, false)

## An acid spit or a harpoon: its young first, then the boss. True when it hit.
static func shot_hit(e, sh: Dictionary) -> bool:
	var b: Dictionary = e.boss
	for m in b.minions:
		if m.pos.distance_to(sh.pos) < b.r * 0.16 + 14.0:
			m.life = 0.0
			e.events.append({"type": "spit_hit", "pos": sh.pos})
			return true
	if b.pos.distance_to(sh.pos) > b.r * 0.9 + 14.0:
		return false
	if sh.get("kind", "spit") == "harpoon":
		b.venom = T.venom_t
	else:
		damage(e, T.shot_dmg)
	e.events.append({"type": "spit_hit", "pos": sh.pos})
	return true

## Electric shock / Spine burst: stuns a boss in reach for a moment (bites on it then do double).
static func shock(e, rad: float) -> void:
	if e.boss.is_empty():
		return
	var b: Dictionary = e.boss
	for m in b.minions:
		if m.pos.distance_to(e.player.pos) < rad:
			m.life = 0.0
	if b.stun_cd <= 0.0 and b.pos.distance_to(e.player.pos) < rad + b.r * 0.9:
		b.stun = T.stun_t
		b.stun_cd = T.stun_cd
		if b.state == "attack":
			_enter(e, b, "tired")
		e.events.append({"type": "boss_stun", "id": b.id})

# ---------- each boss ----------

## Old Snapjaw (Didinium): circles you, aims, lunges in a straight line; dizzy after.
static func _snapjaw(e, b: Dictionary, delta: float, d: float, dir_p: Vector2, pr: float, sb: float) -> void:
	match b.state:
		"idle":
			_hover(b, d, dir_p, b.r * 1.6 + pr * 2.0, sb * 0.75, 0.7, delta)
			b.face = rotate_toward(b.face, dir_p.angle(), 3.0 * delta)
		"tell":
			_move(b, Vector2.ZERO, delta, 5.0)
			b.face = rotate_toward(b.face, dir_p.angle(), 3.5 * delta)
			b.aim = b.face
		"attack":
			b.vel = Vector2.from_angle(b.aim) * sb * 2.2
			if not b.struck and d < b.r * 0.85 + pr * 0.8:
				b.struck = true
				e.hurt(0.15, b.id)
				e.player.vel = (dir_p + Vector2.from_angle(b.aim)).normalized() * sb * 2.0
		"tired":
			_move(b, Vector2.ZERO, delta, 2.0)
			b.face += 2.4 * delta

## Lantern Mother (anglerfish): hovers in the dark; her lure flares, she pulls you to her mouth and snaps.
static func _lantern(e, b: Dictionary, delta: float, d: float, dir_p: Vector2, pr: float, sb: float) -> void:
	var mouth: Vector2 = b.pos + Vector2.from_angle(b.face) * b.r * 0.85
	match b.state:
		"idle":
			_hover(b, d, dir_p, b.r * 2.0 + pr, sb * 0.55, 0.4, delta)
			b.face = rotate_toward(b.face, dir_p.angle(), 2.4 * delta)
			b.minion_t -= delta
			if b.minion_t <= 0.0 and b.minions.size() < T.minion_max:
				b.minion_t = T.minion_gap
				var lure: Vector2 = b.pos + Vector2.from_angle(b.face) * b.r * 1.5
				b.minions.append({"pos": lure, "vel": Vector2.ZERO, "life": T.minion_life})
				e.events.append({"type": "boss_young", "pos": lure})
		"tell":
			_move(b, Vector2.ZERO, delta, 4.0)
			b.face = rotate_toward(b.face, dir_p.angle(), 3.5 * delta)
		"attack":
			_move(b, Vector2.ZERO, delta, 4.0)
			b.face = rotate_toward(b.face, dir_p.angle(), 1.0 * delta)
			var to_m: Vector2 = mouth - e.player.pos
			if to_m.length() < b.r * 6.0 and to_m.length() > 1.0:
				e.player.pos += to_m.normalized() * sb * 0.8 * delta
			if not b.struck and b.t >= b.dur - 0.35:
				b.struck = true
				e.events.append({"type": "boss_snap", "id": b.id})
				if mouth.distance_to(e.player.pos) < b.r * 0.75 + pr:
					e.hurt(0.22, b.id)
					e.player.vel = -dir_p * sb * 1.5
		"tired":
			_move(b, Vector2.ZERO, delta, 2.0)

## Ironclaw (spider crab): walks at you, turns slowly; the shell guards her front; her claw grabs and holds you.
static func _ironclaw(e, b: Dictionary, delta: float, d: float, dir_p: Vector2, pr: float, sb: float) -> void:
	match b.state:
		"idle":
			_hover(b, d, dir_p, b.r * 1.5 + pr, sb * 0.5, 0.0, delta)
			b.face = rotate_toward(b.face, dir_p.angle(), 1.1 * delta)
		"tell":
			_move(b, Vector2.ZERO, delta, 5.0)
			b.face = rotate_toward(b.face, dir_p.angle(), 0.9 * delta)
		"attack":
			_move(b, Vector2.ZERO, delta, 5.0)
			var tip := claw_tip(b)
			if not b.struck and tip.distance_to(e.player.pos) < pr + b.r * 0.35:
				b.struck = true
				b.grab = 1.3
				e.events.append({"type": "boss_grab", "id": b.id})
		"tired":
			_move(b, Vector2.ZERO, delta, 3.0)

## Where Ironclaw's right claw is now (it reaches out during the attack).
static func claw_tip(b: Dictionary) -> Vector2:
	var reach := 1.7
	if b.state == "attack":
		reach += 1.2 * sin(PI * clampf(b.t / maxf(b.dur, 0.01), 0.0, 1.0))
	elif b.grab > 0.0:
		reach = 2.3
	return b.pos + Vector2.from_angle(b.face + 0.38) * b.r * reach

## Held in Ironclaw's claw: no swimming, it squeezes, then flings you away.
static func _held(e, b: Dictionary, delta: float, pr: float) -> void:
	b.grab -= delta
	e.player.pos = claw_tip(b)
	e.player.vel = Vector2.ZERO
	e.hurt(0.16 * delta / 1.3, b.id, false)
	if b.grab <= 0.0:
		b.grab = 0.0
		var away: Vector2 = (e.player.pos - b.pos).normalized()
		e.player.pos = b.pos + away * (b.r * 1.0 + pr)
		e.player.vel = away * maxf(e.top_speed(), 150.0) * 2.2
		_enter(e, b, "tired")

## Grey Kraken (giant squid): keeps her distance and squirts ink; two tentacles rear back (their tips glow: bite one
## to stun her), then sweep across the area in front of her.
static func _kraken(e, b: Dictionary, delta: float, d: float, dir_p: Vector2, pr: float, sb: float) -> void:
	b.ink_cd -= delta
	match b.state:
		"idle":
			_hover(b, d, dir_p, b.r * 2.4 + pr, sb * 0.6, 0.5, delta)
			b.face = rotate_toward(b.face, dir_p.angle(), 2.0 * delta)
			if b.ink_cd <= 0.0:
				b.ink_cd = 10.0
				b.ink_t = 5.0
				b.ink_pos = b.pos.lerp(e.player.pos, 0.5)
				e.events.append({"type": "boss_ink", "pos": b.ink_pos})
		"tell":
			_move(b, Vector2.ZERO, delta, 4.0)
			b.face = rotate_toward(b.face, dir_p.angle(), 1.2 * delta)
			for tip in kraken_tips(b):
				if tip.distance_to(e.player.pos) < pr + b.r * 0.28:
					b.stun = 1.0
					_enter(e, b, "tired")
					b.dur = 3.6
					e.events.append({"type": "boss_stun", "id": b.id})
					return
		"attack":
			_move(b, Vector2.ZERO, delta, 4.0)
			var sweep := sweep_angle(b)
			if not b.struck and d < b.r * 3.4 + pr and absf(angle_difference(sweep, dir_p.angle())) < 0.28:
				b.struck = true
				e.hurt(0.17, b.id)
				e.player.vel = dir_p.rotated(PI * 0.5 * signf(angle_difference(b.face, dir_p.angle()) + 0.001)) * sb * 2.0
		"tired":
			_move(b, Vector2.ZERO, delta, 2.0)

## The glowing tips of the two tentacles that rear back before a sweep.
static func kraken_tips(b: Dictionary) -> Array:
	return [b.pos + Vector2.from_angle(b.face + 1.25) * b.r * 1.9, b.pos + Vector2.from_angle(b.face - 1.25) * b.r * 1.9]

## The sweep crosses the sector in front of her, ±0.9 rad around where she faced when it began.
static func sweep_angle(b: Dictionary) -> float:
	return b.aim - 0.9 + 1.8 * clampf(b.t / maxf(b.dur, 0.01), 0.0, 1.0)

## The Hollow Leviathan: thick hide; it breathes in, swallows what reaches its mouth, and spits you out. Dizzy
## after a gulp: its weak spots glow.
static func _leviathan(e, b: Dictionary, delta: float, d: float, dir_p: Vector2, pr: float, sb: float) -> void:
	var mouth: Vector2 = b.pos + Vector2.from_angle(b.face) * b.r * 0.95
	match b.state:
		"idle":
			_hover(b, d, dir_p, b.r * 1.7 + pr, sb * 0.45, 0.25, delta)
			b.face = rotate_toward(b.face, dir_p.angle(), 0.8 * delta)
		"tell":
			_move(b, Vector2.ZERO, delta, 3.0)
			b.face = rotate_toward(b.face, dir_p.angle(), 0.6 * delta)
		"attack":
			_move(b, Vector2.ZERO, delta, 3.0)
			var to_m: Vector2 = mouth - e.player.pos
			var in_front: bool = absf(angle_difference(b.face, (e.player.pos - b.pos).angle())) < 1.2
			if in_front and to_m.length() < b.r * 5.0 and to_m.length() > 1.0:
				e.player.pos += to_m.normalized() * sb * 0.85 * delta
			# small creatures in front are swept in and swallowed
			for n in e.npcs:
				var tm: Vector2 = mouth - n.pos
				if tm.length() < b.r * 3.0 and absf(angle_difference(b.face, (n.pos - b.pos).angle())) < 1.2:
					n.pos += tm.normalized() * sb * delta
					if tm.length() < b.r * 0.4:
						n["gone"] = true
			if not b.struck and to_m.length() < b.r * 0.35 + pr * 0.5:
				b.struck = true
				e.hurt(0.3, b.id)
				e.player.pos = mouth + Vector2.from_angle(b.face) * (b.r * 0.4 + pr)
				e.player.vel = Vector2.from_angle(b.face) * sb * 2.4
				e.events.append({"type": "boss_snap", "id": b.id})
				_enter(e, b, "tired")
		"tired":
			_move(b, Vector2.ZERO, delta, 2.0)
	var keep: Array = []
	for n in e.npcs:
		if not n.get("gone", false):
			keep.append(n)
	if keep.size() != e.npcs.size():
		e.npcs = keep

## Weak spots along the Leviathan's side (they glow while it is dizzy).
static func weak_spots(b: Dictionary) -> Array:
	var out: Array = []
	for k in 3:
		out.append(b.pos + Vector2(b.r * (0.35 - 0.45 * float(k)), -b.r * 0.42).rotated(b.face))
	return out

## Lantern Mother's young: little glowing fish that chase you and nip; touching one costs a little health and it
## is gone (shots and shocks kill them too).
static func _minions(e, b: Dictionary, delta: float, pr: float, sb: float) -> void:
	if b.minions.is_empty():
		return
	var mr: float = b.r * 0.16
	var keep: Array = []
	for m in b.minions:
		m.life -= delta
		var to_p: Vector2 = e.player.pos - m.pos
		var dd := to_p.length()
		m.vel = m.vel.lerp(to_p / maxf(dd, 0.001) * sb * 0.85, clampf(3.0 * delta, 0.0, 1.0))
		m.pos += m.vel * delta
		if dd < pr + mr:
			e.hurt(0.03, b.id)
			e.events.append({"type": "boss_young_hit", "pos": m.pos})
			continue
		if m.life > 0.0:
			keep.append(m)
	b.minions = keep
