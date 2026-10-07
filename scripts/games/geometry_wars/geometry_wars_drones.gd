extends RefCounted

## Campaign familiars: a small spirit companion that follows the player and
## helps. One per level, picked on the campaign map. Cursed runs have none.
## (Internally still "drones".)
##
## Owning and upgrading (owner, 2026-10-07): each familiar comes up for sale
## once its campaign level (SHOP) is cleared and is bought with points -- the
## total of every campaign score. Points scored while one flies with you also
## go to its own pool, which buys its upgrades (STATS, MAX_LEVEL levels each):
##   armor  hits it takes before it is knocked out for a while
##   speed  how fast it follows and flies at things
##   power  how hard and how often it attacks
##   pull   how far it draws souls (geoms) in and gathers them for you
## Familiars follow on a loose spring with a slow wander, never pinned to one
## spot, and trail their own flame.
##
##   attack   Raven  fires pins along with you, in your aiming direction
##   collect  Moth   flies off and gathers souls for you
##   ram      Bull   charges the nearest enemy, smashing it
##   snipe    Owl    zaps the nearest enemy with a long ray, once a second
##   defend   Bat    guards your back: fires the opposite way you fire
##   sweep    Wisp   circles your skull, burning anything it touches
##
## update() moves the drone and returns events:
##   {kind: "kills", list}     enemies it destroyed (removed already), like
##                             Core.resolve_bullet_hits() returns
##   {kind: "geoms", v}        multiplier it picked up
##   {kind: "boss", boss, n}   damage to a boss
##   {kind: "ray", from, to}   a snipe shot to draw
##   {kind: "shot"}            it fired (for the sound)

const Core = preload("res://scripts/games/geometry_wars/geometry_wars_core.gd")
const Bosses = preload("res://scripts/games/geometry_wars/geometry_wars_bosses.gd")

const KINDS := ["attack", "collect", "ram", "snipe", "defend", "sweep"]
## The stars that used to unlock each one (before the shop): saves from then
## keep the familiars they had.
const OLD_UNLOCK := {"attack": 0, "collect": 5, "ram": 12, "snipe": 24, "defend": 40, "sweep": 60}
## [campaign level that must be cleared first, price in points].
const SHOP := {"attack": [0, 0], "collect": [3, 25000], "ram": [8, 80000], "snipe": [14, 250000],
	"defend": [20, 600000], "sweep": [28, 1500000]}
const STATS := ["armor", "speed", "power", "pull"]
const STAT_LABELS := {"armor": "🛡 Armor", "speed": "💨 Speed", "power": "⚔ Power", "pull": "🧲 Soul pull"}
const STAT_DESCS := {
	"armor": "Takes more hits before it is knocked out.",
	"speed": "Follows and flies faster.",
	"power": "Attacks harder and more often.",
	"pull": "Draws souls in from farther and gathers them for you.",
}
const MAX_LEVEL := 5
## Points (from that familiar's own pool) for each next level of a stat.
const UPGRADE_COST := [10000, 25000, 60000, 140000, 300000]
## Seconds a knocked-out familiar is gone (less with armor).
const DOWN_TIME := 8.0
const HURT_TIME := 0.6
const ICONS := {"attack": "🐦", "collect": "🦋", "ram": "🐂", "snipe": "🦉", "defend": "🦇", "sweep": "🔥"}
const NAMES := {"attack": "Raven", "collect": "Moth", "ram": "Bull", "snipe": "Owl", "defend": "Bat", "sweep": "Wisp"}
## What the UI shows (icon + name in one string, so it translates on its own:
## "Raven" / "Owl" / "Bat" alone are word-list data in other games' es.json).
const LABELS := {"attack": "🐦 Raven", "collect": "🦋 Moth", "ram": "🐂 Bull", "snipe": "🦉 Owl", "defend": "🦇 Bat", "sweep": "🔥 Wisp"}
const DESCS := {
	"attack": "Fires pins with you, the way you aim.",
	"collect": "Flies off and gathers souls for you.",
	"ram": "Charges into the nearest enemy.",
	"snipe": "Zaps the nearest enemy every second.",
	"defend": "Guards your back: fires the other way.",
	"sweep": "Circles your skull, burning what it touches.",
}
const COLORS := {
	"attack": Color(1.0, 0.6, 0.2), "collect": Color(1.0, 0.9, 0.3), "ram": Color(1.0, 0.3, 0.4),
	"snipe": Color(0.4, 1.0, 1.0), "defend": Color(0.5, 0.7, 1.0), "sweep": Color(0.75, 0.45, 1.0),
}

const FIRE_EVERY := 0.12
const SNIPE_EVERY := 1.0
const SNIPE_RANGE := 14.0
const RAM_RANGE := 8.0
const SWEEP_RADIUS := 2.4
const SWEEP_SPIN := 4.2

static func make(kind: String, player_pos: Vector2, up: Dictionary = {}) -> Dictionary:
	var lv := {}
	for st in STATS:
		lv[st] = clampi(int(up.get(st, 0)), 0, MAX_LEVEL)
	var d := {"kind": kind, "pos": player_pos + Vector2(-1.5, 1.0) * Core.U, "vel": Vector2.ZERO,
		"t": 0.0, "cd": 0.0, "angle": 0.0, "spin": 1.0, "target": -1, "up": lv,
		"hurt": 0.0, "down": 0.0, "seed": randf() * TAU, "facing": Vector2.UP}
	d["hp"] = max_hp(d)
	return d

static func level_of(d: Dictionary, stat: String) -> int:
	return int((d.get("up", {}) as Dictionary).get(stat, 0))

static func max_hp(d: Dictionary) -> int:
	return 3 + 2 * level_of(d, "armor")

static func speed_k(d: Dictionary) -> float:
	return 1.0 + 0.15 * level_of(d, "speed")

static func power_k(d: Dictionary) -> float:
	return 1.0 + 0.2 * level_of(d, "power")

## How far it draws souls in.
static func pull_radius(d: Dictionary) -> float:
	return (1.2 + 0.7 * level_of(d, "pull")) * Core.U

static func color_of(kind: String) -> Color:
	return COLORS.get(kind, Color.WHITE)

## ctx: {player_pos, ship_dir, aim_dir, firing, enemies, crystals, bosses,
## bullets, ebullets, arena}. Events: kills, geoms, boss, ray, shot, hurt,
## down (knocked out), back (returned).
static func update(d: Dictionary, ctx: Dictionary, delta: float) -> Array:
	var u: float = Core.U
	var ev: Array = []
	d.t = float(d.t) + delta
	var pp: Vector2 = ctx.player_pos
	if not d.has("up"):  # a familiar from a save made before upgrades
		var fresh := make(str(d.kind), pp)
		for k in fresh:
			if not d.has(k):
				d[k] = fresh[k]
	if float(d.down) > 0.0:
		d.down = float(d.down) - delta
		d.pos = pp
		d.vel = Vector2.ZERO
		if float(d.down) <= 0.0:
			d.hp = max_hp(d)
			d.hurt = 1.2
			ev.append({"kind": "back"})
		return ev
	d.cd = maxf(0.0, float(d.cd) - delta)
	d.hurt = maxf(0.0, float(d.hurt) - delta)
	var pk := power_k(d)
	var prev: Vector2 = d.pos
	var ship: Vector2 = ctx.ship_dir
	var aim: Vector2 = ctx.aim_dir
	var firing: bool = ctx.firing and aim != Vector2.ZERO
	var enemies: Array = ctx.enemies
	var arena: Vector2 = ctx.arena
	match d.kind:
		"attack":
			_follow(d, pp - ship * 1.4 * u + Vector2(-ship.y, ship.x) * 1.1 * u, delta)
			if firing and d.cd <= 0.0:
				d.cd = FIRE_EVERY / pk
				for s in [-1.0, 1.0]:
					ctx.bullets.append({"pos": d.pos + aim * 0.5 * u + Vector2(-aim.y, aim.x) * s * 0.18 * u,
						"vel": aim * 22.0 * u, "life": 0.75, "drone": true})
				ev.append({"kind": "shot"})
		"defend":
			var back: Vector2 = -aim if aim != Vector2.ZERO else -ship
			_follow(d, pp + back * 1.5 * u, delta)
			if firing and d.cd <= 0.0:
				d.cd = FIRE_EVERY / pk
				for s in [-0.18, 0.0, 0.18]:
					ctx.bullets.append({"pos": d.pos + back * 0.5 * u, "vel": back.rotated(s) * 21.0 * u, "life": 0.6, "drone": true})
				ev.append({"kind": "shot"})
		"collect":
			var crystals: Array = ctx.crystals
			var best := -1
			var best_d := 12.0 * u * pk
			for i in crystals.size():
				var dd: float = (crystals[i].pos as Vector2).distance_to(d.pos)
				if dd < best_d:
					best_d = dd
					best = i
			if best >= 0:
				_fly(d, crystals[best].pos, 13.0 * u * speed_k(d), delta)
				if best_d <= 0.8 * u:
					ev.append({"kind": "geoms", "v": int(crystals[best].get("v", 1))})
					crystals.remove_at(best)
			else:
				_follow(d, pp + Vector2(1.2, -1.2) * u, delta)
		"ram":
			var target := _nearest(enemies, pp, RAM_RANGE * u)
			var boss := _nearest_boss(ctx.bosses, pp, RAM_RANGE * u)
			if target >= 0 and d.cd <= 0.0:
				var e: Dictionary = enemies[target]
				_fly(d, e.pos, 15.0 * u * speed_k(d), delta)
				if (d.pos as Vector2).distance_to(e.pos) <= Core.radius_of(e.type) + 0.35 * u:
					ev.append({"kind": "kills", "list": [_smash(enemies, target)]})
					d.cd = 0.2 / pk
			elif not boss.is_empty() and d.cd <= 0.0:
				var tp: Vector2 = Bosses.target_point(boss)
				_fly(d, tp, 15.0 * u * speed_k(d), delta)
				if (d.pos as Vector2).distance_to(tp) <= 1.2 * u:
					ev.append({"kind": "boss", "boss": boss, "n": roundi(pk)})
					d.cd = 0.35 / pk
					d.vel = ((d.pos as Vector2) - tp).normalized() * 12.0 * u
			else:
				_follow(d, pp - ship * 1.6 * u, delta)
		"snipe":
			_follow(d, pp + Vector2(-ship.y, ship.x) * 1.3 * u, delta)
			if d.cd <= 0.0:
				var target := _nearest(enemies, d.pos, SNIPE_RANGE * u)
				if target >= 0:
					var e: Dictionary = enemies[target]
					ev.append({"kind": "ray", "from": d.pos, "to": e.pos})
					if e.type == "well" or e.type == "repulsor":
						e.hp = int(e.hp) - (5 if e.type == "well" else 1)
						if e.type == "well":
							e.active = true
						if int(e.hp) <= 0:
							ev.append({"kind": "kills", "list": [_smash(enemies, target)]})
					else:
						ev.append({"kind": "kills", "list": [_smash(enemies, target)]})
					d.cd = SNIPE_EVERY / pk
				else:
					var boss := _nearest_boss(ctx.bosses, d.pos, SNIPE_RANGE * u)
					if not boss.is_empty():
						ev.append({"kind": "ray", "from": d.pos, "to": Bosses.target_point(boss)})
						ev.append({"kind": "boss", "boss": boss, "n": roundi(2.0 * pk)})
						d.cd = SNIPE_EVERY / pk
		"sweep":
			d.angle = float(d.angle) + SWEEP_SPIN * speed_k(d) * float(d.spin) * delta
			var want: Vector2 = pp + Vector2(cos(d.angle), sin(d.angle)) * SWEEP_RADIUS * u
			if want.x < 0.0 or want.y < 0.0 or want.x > arena.x or want.y > arena.y:
				d.spin = -float(d.spin)  # bounced off a wall: circle the other way
			d.pos = want.clamp(Vector2.ZERO, arena)
			for i in range(enemies.size() - 1, -1, -1):
				var e: Dictionary = enemies[i]
				if e.warm > 0.0 or e.type in Core.GATES or e.type == "well":
					continue
				if (d.pos as Vector2).distance_to(e.pos) <= Core.radius_of(e.type) + 0.4 * u:
					ev.append({"kind": "kills", "list": [_smash(enemies, i)]})
			if d.cd <= 0.0:
				for b in ctx.bosses:
					if Bosses.touches(b, d.pos, 0.3 * u):
						ev.append({"kind": "boss", "boss": b, "n": roundi(pk)})
						d.cd = 0.25
						break
	if d.kind == "sweep":  # placed, not flown: its speed is how far it moved
		d.vel = ((d.pos as Vector2) - prev) / maxf(delta, 0.001)
	_pull_souls(d, ctx.crystals, delta, ev)
	_take_hits(d, enemies, ctx.get("ebullets", []), ev)
	var v: Vector2 = d.vel
	if v.length() > 0.8 * u:
		d.facing = v.normalized()
	return ev

## Souls within reach drift toward it; one it touches is gathered for you.
static func _pull_souls(d: Dictionary, crystals: Array, delta: float, ev: Array) -> void:
	var u: float = Core.U
	var reach := pull_radius(d)
	var p: Vector2 = d.pos
	var speed := (4.0 + 2.0 * level_of(d, "pull")) * u
	for i in range(crystals.size() - 1, -1, -1):
		var c: Dictionary = crystals[i]
		if float(c.get("age", 0.0)) < 0.0:
			continue  # still flying out of a big burst
		var off: Vector2 = p - (c.pos as Vector2)
		var dist := off.length()
		if dist <= 0.6 * u:
			ev.append({"kind": "geoms", "v": int(c.get("v", 1))})
			crystals.remove_at(i)
		elif dist <= reach:
			c.pos = (c.pos as Vector2) + off / dist * minf(speed * delta, dist)

## Enemies that run into it and enemy shots hurt it; out of health, it is
## knocked out for a while (less with armor) and comes back by your side.
static func _take_hits(d: Dictionary, enemies: Array, ebullets: Array, ev: Array) -> void:
	if float(d.hurt) > 0.0 or d.kind == "sweep":
		return  # the Wisp burns what it touches
	var u: float = Core.U
	var p: Vector2 = d.pos
	var hit := false
	for e in enemies:
		if e.warm > 0.0 or e.type in Core.GATES or e.type == "well":
			continue
		if p.distance_to(e.pos) <= Core.radius_of(e.type) + 0.3 * u:
			hit = true
			break
	if not hit:
		for i in range(ebullets.size() - 1, -1, -1):
			if p.distance_to(ebullets[i].pos) <= float(ebullets[i].get("r", 0.25)) * u + 0.3 * u:
				ebullets.remove_at(i)
				hit = true
				break
	if not hit:
		return
	d.hp = int(d.hp) - 1
	d.hurt = HURT_TIME
	if int(d.hp) <= 0:
		d.down = DOWN_TIME - 0.6 * level_of(d, "armor")
		ev.append({"kind": "down", "pos": p})
	else:
		ev.append({"kind": "hurt", "pos": p})

## Stays near a spot beside the player, never pinned to it: the spot wanders
## slowly, and a soft spring lets it lag, swing wide and catch up.
static func _follow(d: Dictionary, spot: Vector2, delta: float) -> void:
	var u: float = Core.U
	var t: float = d.t
	var sd: float = d.get("seed", 0.0)
	var wander := Vector2(sin(t * 0.9 + sd) + 0.5 * sin(t * 2.3 + sd * 2.0), cos(t * 0.7 + sd * 1.3) + 0.5 * cos(t * 1.9 + sd)) * 0.55 * u
	var target := spot + wander
	var sk := speed_k(d)
	var p: Vector2 = d.pos
	var v: Vector2 = d.vel
	var dt := minf(delta, 0.05)
	v += ((target - p) * 30.0 * sk - v * 7.5) * dt
	v = v.limit_length(18.0 * u * sk)
	d.vel = v
	d.pos = p + v * dt

## Flies at a target at `speed` px/s.
static func _fly(d: Dictionary, to: Vector2, speed: float, delta: float) -> void:
	var p: Vector2 = d.pos
	var off: Vector2 = to - p
	d.vel = (d.vel as Vector2).move_toward(off.normalized() * speed, speed * 6.0 * delta)
	d.pos = p + (d.vel as Vector2) * delta

static func _nearest(enemies: Array, from: Vector2, max_d: float) -> int:
	var best := -1
	var best_d := max_d
	for i in enemies.size():
		var e: Dictionary = enemies[i]
		if e.warm > 0.0 or e.type in Core.GATES:
			continue
		var dd: float = from.distance_to(e.pos)
		if dd < best_d:
			best_d = dd
			best = i
	return best

static func _nearest_boss(bosses: Array, from: Vector2, max_d: float) -> Dictionary:
	for b in bosses:
		if float(b.warm) <= 0.0 and from.distance_to(Bosses.target_point(b)) <= max_d + Bosses.body_radius(b):
			return b
	return {}

static func _smash(enemies: Array, i: int) -> Dictionary:
	var e: Dictionary = enemies[i]
	enemies.remove_at(i)
	return {"pos": e.pos, "type": e.type, "eaten": int(e.get("eaten", 0))}
