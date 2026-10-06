extends RefCounted

## Campaign drones: a small companion ship that follows the player and helps
## (Geometry Wars 3's six). One per level, picked on the campaign screen;
## more unlock as the player earns stars. Hardcore has none.
##
##   attack   fires along with you, in your aiming direction
##   collect  flies off and picks up geoms for you
##   ram      rams the nearest enemy, smashing it
##   snipe    zaps the nearest enemy with a long ray, once a second
##   defend   guards your back: fires the opposite way you fire
##   sweep    circles your ship, smashing anything it touches
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
## Campaign stars needed to unlock each.
const UNLOCK := {"attack": 0, "collect": 5, "ram": 12, "snipe": 24, "defend": 40, "sweep": 60}
const ICONS := {"attack": "🔫", "collect": "🧲", "ram": "🐏", "snipe": "🎯", "defend": "🛡", "sweep": "🌀"}
const NAMES := {"attack": "Attack", "collect": "Collect", "ram": "Ram", "snipe": "Snipe", "defend": "Defend", "sweep": "Sweep"}
const DESCS := {
	"attack": "Fires with you, the way you aim.",
	"collect": "Flies off and picks up geoms for you.",
	"ram": "Smashes into the nearest enemy.",
	"snipe": "Zaps the nearest enemy every second.",
	"defend": "Guards your back: fires the other way.",
	"sweep": "Circles your ship, smashing what it hits.",
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

static func make(kind: String, player_pos: Vector2) -> Dictionary:
	return {"kind": kind, "pos": player_pos + Vector2(-1.5, 1.0) * Core.U, "vel": Vector2.ZERO,
		"t": 0.0, "cd": 0.0, "angle": 0.0, "spin": 1.0, "target": -1}

static func color_of(kind: String) -> Color:
	return COLORS.get(kind, Color.WHITE)

## ctx: {player_pos, ship_dir, aim_dir, firing, enemies, crystals, bosses,
## bullets, arena}
static func update(d: Dictionary, ctx: Dictionary, delta: float) -> Array:
	var u: float = Core.U
	var ev: Array = []
	d.t = float(d.t) + delta
	d.cd = maxf(0.0, float(d.cd) - delta)
	var pp: Vector2 = ctx.player_pos
	var ship: Vector2 = ctx.ship_dir
	var aim: Vector2 = ctx.aim_dir
	var firing: bool = ctx.firing and aim != Vector2.ZERO
	var enemies: Array = ctx.enemies
	var arena: Vector2 = ctx.arena
	match d.kind:
		"attack":
			_follow(d, pp - ship * 1.4 * u + Vector2(-ship.y, ship.x) * 1.1 * u, delta)
			if firing and d.cd <= 0.0:
				d.cd = FIRE_EVERY
				for s in [-1.0, 1.0]:
					ctx.bullets.append({"pos": d.pos + aim * 0.5 * u + Vector2(-aim.y, aim.x) * s * 0.18 * u,
						"vel": aim * 22.0 * u, "life": 0.75, "drone": true})
				ev.append({"kind": "shot"})
		"defend":
			var back: Vector2 = -aim if aim != Vector2.ZERO else -ship
			_follow(d, pp + back * 1.5 * u, delta)
			if firing and d.cd <= 0.0:
				d.cd = FIRE_EVERY
				for s in [-0.18, 0.0, 0.18]:
					ctx.bullets.append({"pos": d.pos + back * 0.5 * u, "vel": back.rotated(s) * 21.0 * u, "life": 0.6, "drone": true})
				ev.append({"kind": "shot"})
		"collect":
			var crystals: Array = ctx.crystals
			var best := -1
			var best_d := 12.0 * u
			for i in crystals.size():
				var dd: float = (crystals[i].pos as Vector2).distance_to(d.pos)
				if dd < best_d:
					best_d = dd
					best = i
			if best >= 0:
				_fly(d, crystals[best].pos, 13.0 * u, delta)
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
				_fly(d, e.pos, 15.0 * u, delta)
				if (d.pos as Vector2).distance_to(e.pos) <= Core.radius_of(e.type) + 0.35 * u:
					ev.append({"kind": "kills", "list": [_smash(enemies, target)]})
					d.cd = 0.2
			elif not boss.is_empty() and d.cd <= 0.0:
				var tp: Vector2 = Bosses.target_point(boss)
				_fly(d, tp, 15.0 * u, delta)
				if (d.pos as Vector2).distance_to(tp) <= 1.2 * u:
					ev.append({"kind": "boss", "boss": boss, "n": 1})
					d.cd = 0.35
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
					d.cd = SNIPE_EVERY
				else:
					var boss := _nearest_boss(ctx.bosses, d.pos, SNIPE_RANGE * u)
					if not boss.is_empty():
						ev.append({"kind": "ray", "from": d.pos, "to": Bosses.target_point(boss)})
						ev.append({"kind": "boss", "boss": boss, "n": 2})
						d.cd = SNIPE_EVERY
		"sweep":
			d.angle = float(d.angle) + SWEEP_SPIN * float(d.spin) * delta
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
						ev.append({"kind": "boss", "boss": b, "n": 1})
						d.cd = 0.25
						break
	return ev

## Glides toward a spot beside the player.
static func _follow(d: Dictionary, spot: Vector2, delta: float) -> void:
	var p: Vector2 = d.pos
	d.pos = p.lerp(spot, clampf(delta * 8.0, 0.0, 1.0))

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
