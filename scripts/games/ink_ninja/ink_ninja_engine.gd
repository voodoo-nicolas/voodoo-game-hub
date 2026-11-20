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
const STAGES := 24   # owner 2026-11-15: the bible's 6 acts x (3 stages + a boss stage); was 10
const ACT_LEN := 4   # stages per act; the 4th of each act is its boss stage

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
const TRAP_PERIOD := 3.4
const KNOCK_T := 0.28      # hit: knocked back, no control for this long
const END_CLEAR := 1500.0  # owner 2026-11-16: nothing stands in the last stretch before the gate
const MAX_STARS := 20      # owner 2026-11-16: 70+ stars piled up; pickups stop at a cap
const MAX_BOMBS := 4
const NIGHT_STAGES := [6, 14, 23]   # the road is dark: lanterns and your torch are the only light
const RUINS_STAGES := [10, 19]      # overgrown ruins: statues, broken walls
const DEADLY_AIR := 0.8             # a deep lake: little breath, a fast drowning tick
const DEADLY_TICK := 0.5
const DEADLY_WADE := 0.35

## Boss per act (story bible, mixed with the first story: Lord Shu IS the Shadow Daimyo).
## They fight with the four boss figures/move sets already built (BOSS_KIND); their own
## art (lion-dog, tiger, dragon, crane, monk, the Hand) is not drawn yet.
const BOSS_NAMES := ["Gate Warden", "Tora", "The Dragon", "Tsuru", "The Calligrapher", "Lord Shu"]
const BOSS_KIND := [0, 1, 0, 2, 1, 3]   # figure + attack set: 0 Iron Monk, 1 Twin Blade, 2 Paper Crane, 3 Daimyo

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
var blocking := false
var jab := false       # this attack is a crouching jab (straight forward, low)
var thrust_hit := {}   # foes already run through by this thrust
var air_dir := 0        # this slash: 0 forward, 1 up (rising), 2 down (falling)
var swing := 0          # which cut of the 3-cut combo this slash is: 0 chop down, 1 rising diagonal, 2 sideways sweep (owner 2026-11-15)
var swing_t := 0.0      # the next slash within this time continues the combo
var bombs := 2          # smoke bombs: their own button (owner 2026-11-16: crouch + star was wrong)
var drops: Array = []   # pickups: {x, y, vy, kind "star"|"heart"|"bomb", age}
var smokes: Array = []  # smoke clouds: {x, y, t}; foes inside are blinded
var bridges: Array = []  # drawbridges over deep lakes: {x0, x1, y, rx, ry (the rope knot, high up), cut, t, deck}
var traps: Array = []   # swinging spike boards: {x, y, ph (phase), state "up"|"warn"|"down", t}
var reserved: Array = []  # [x0, x1] stretches kept clear of random scenery (lakes, structures)
var structs: Array = []   # houses, pagodas, shrines, statues, ruins (decor + climbable roofs)
var roofs: Array = []     # the Rect2 roof ledges of structures (drawn as roofs, not as earth)
var secrets: Array = []   # hidden golden scrolls: {x, y, got}
var bridge_decks: Array = []   # the decks of arch_bridges (Rect2): a long step up, the banks dip away from them
var arch_bridges: Array = []  # decorative bridges over rivers: {x0, x1, y}
var night := false
var ruins := false
var night_lanterns: Array = []  # {x, lit}: lit with the torch (a swing next to them)
var revive_cb: Callable    # asked when hearts hit zero: true = a spare life saved you on the spot
var secrets_found := 0
var pagodas_climbed := {}
var torii_used := {}    # torii already passed (each gives one heart, once)
var scroll_n := 0       # scrolls this stage: every third heals a heart
var tips: Array = []   # [x0, x1, key]: tutorial lines shown while the hero is between x0 and x1
## Abilities unlock as the story goes (owner 2026-11-15): stage 1 teaches move, crouch,
## jump and swing; block from stage 2; throwing stars once stage 2 is beaten; the thrust
## once stage 3 is beaten.
const UNLOCK := {"block": 2, "star": 3, "thrust": 4, "bomb": 3}
const TUTOR := 2800.0   # stage 1: the first stretch is a quiet tutorial
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
var torii: Array = []         # torii gates (scenery): world x
var flora: Array = []         # black/grey scenery: {"x","kind" bamboo|bush|grass,"s","h"}
var trees: Array = []         # cherry trees: {"x", "h", "s", "blood"}; exactly one per stage has blood-red leaves
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

func can(ability: String) -> bool:
	return stage >= int(UNLOCK.get(ability, 1))

func reset(d: int) -> void:
	diff = clampi(d, 0, 2)
	stage = 1
	score = 0
	lives = 3
	hp = MAX_HP
	stars = START_STARS
	bombs = 2
	secrets_found = 0
	pagodas_climbed = {}
	build_stage()

## Speed / aggression multiplier for foes.
func power() -> float:
	return [0.75, 1.0, 1.3][diff] * (1.0 + (stage - 1) * 0.025)   # 24 stages end about where 10 did

## Act 1..6 (4 stages each).
func act() -> int:
	return (stage - 1) / ACT_LEN + 1

## The last stage of each act is its boss duel; the others end at the gate.
func boss_stage() -> bool:
	return stage % ACT_LEN == 0

func build_stage() -> void:
	rng.seed = stage * 7919 + 13
	state = "play"
	time = 0.0
	length = (3600.0 + act() * 600.0) * 15.0   # owner 2026-11-16: every stage twice as long again (room for structures)
	if boss_stage():
		length = (3600.0 + act() * 400.0) * 3.0   # a boss stage: a climb to the duel (twice as long, owner 2026-11-16)
	night = NIGHT_STAGES.has(stage)
	ruins = RUINS_STAGES.has(stage)
	arena_x = length
	locked = false
	solids.clear()
	pits.clear()
	foes.clear()
	shots.clear()
	scrolls.clear()
	boss = {}
	drops.clear()
	smokes.clear()
	bridges.clear()
	traps.clear()
	reserved.clear()
	structs.clear()
	roofs.clear()
	secrets.clear()
	arch_bridges.clear()
	bridge_decks.clear()
	night_lanterns.clear()
	torii_used = {}
	scroll_n = 0
	pools.clear()
	dips.clear()
	# Rolling ground (owner 2026-11-15): two slow waves rising above GROUND, flat at the
	# start and in the arena. The old pits are now soft dips, most filled with water.
	var t0 := TUTOR if stage == 1 else 0.0   # the tutorial stretch stays flat and quiet
	var n := int((length + VIEW_W) / SEG) + 2
	heights.resize(n)
	var amp := minf(110.0 + act() * 10.0, 165.0)   # owner's reference pictures: land that really rises and falls
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
		var blend := smoothstep(350.0 + t0, 800.0 + t0, gxx) * (1.0 - smoothstep(length - END_CLEAR - 500.0, length - END_CLEAR, gxx))
		heights[i] = GROUND - (amp * wave + rough) * blend
	_plan_lakes()
	_plan_structs()
	_plan_traps()
	var x := 700.0 + t0
	while x < length - END_CLEAR:
		x += rng.randf_range(520.0, 900.0)
		if x > length - END_CLEAR:
			break
		if rng.randf() < 0.35 + act() * 0.06:
			var depth := rng.randf_range(80.0, 150.0 + act() * 10.0)
			var hw := maxf(rng.randf_range(220.0, 420.0), depth * 3.4)   # wide, flat-bottomed lakes with soft banks
			if x + hw > length - END_CLEAR:
				break
			if _over_pit(x - hw - 80.0) or _over_pit(x + hw + 80.0) or _over_pit(x):
				continue   # never on top of a deep lake or a structure
			_carve(x, hw, depth, rng.randf() < 0.8)
			x += hw * 1.2
	pits.clear()
	_arch_bridges()
	# Left and right world walls (the right one closes the arena).
	solids.append(Rect2(-60, -400, 60, 1300))
	solids.append(Rect2(length + VIEW_W - 60, -400, 60, 1300))
	# Ledges and pillars to climb.
	x = 500.0 + t0
	while x < length - END_CLEAR:
		x += rng.randf_range(350.0, 650.0) * 1.6
		if x > length - END_CLEAR - 300.0:
			break
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
	# Foes (the gaps are longer than before: the stage is twice as long, not twice as crowded).
	x = 900.0 + t0 + (600.0 if stage == 2 else 0.0)
	while x < length - END_CLEAR:
		# Uneven spacing (owner 2026-11-15): now a tight pair, now a long quiet stretch.
		var roll := rng.randf()
		var gap := rng.randf_range(260.0, 520.0)
		if roll < 0.22:
			gap = rng.randf_range(110.0, 200.0)   # right behind the last one
		elif roll > 0.85:
			gap = rng.randf_range(800.0, 1300.0)   # a breather
		x += gap * 1.5 / (1.0 + diff * 0.15)
		while (_over_pit(x) or water_depth(x) > 0.0 or water_depth(x + 40.0) > 0.0) and x < length - END_CLEAR:
			x += 40.0   # never stand a foe in the water: move him onto dry land (owner 2026-11-15)
		if x >= length - END_CLEAR or _over_pit(x) or water_depth(x) > 0.0:
			continue
		var kinds := ["blade"]
		if stage >= 2:
			kinds.append("thrower")
		if stage >= 5:
			kinds.append("leaper")
		if stage >= 9:
			kinds.append("brute")
		var k: String = kinds[rng.randi() % kinds.size()]
		var hp_f: int = {"blade": 1, "thrower": 1, "leaper": 1, "brute": 3}[k]
		foes.append({"kind": k, "x": x, "y": ground_y(x), "vx": 0.0, "vy": 0.0, "hp": hp_f, "face": -1,
			"t": rng.randf() * 2.0, "atk": 0.0, "hit": 0.0, "id": foes.size()})
	for i in 6:
		var sx := rng.randf_range(300.0, length - END_CLEAR)
		if not _over_pit(sx):
			scrolls.append(Vector2(sx, ground_y(sx) - 60))
	_tutorial()
	_plan_night()
	_trees()
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

## Raise the ground between xa and xb to one level y, blended into the land over `edge`.
func _flatten(xa: float, xb: float, y: float, edge: float) -> void:
	for i in heights.size():
		var gx := i * SEG
		var w := clampf(minf(gx - (xa - edge), (xb + edge) - gx) / edge, 0.0, 1.0)
		if w > 0.0:
			heights[i] = lerpf(heights[i], y, w)

## True when water, a dip or a reserved stretch touches [xa, xb].
func _zone_busy(xa: float, xb: float) -> bool:
	var x := xa
	while x <= xb:
		if water_depth(x) > 0.0 or _over_pit(x):
			return true
		x += 40.0
	return false

## Deep lakes with a raised drawbridge (owner 2026-11-16, replaces the rope-gates): the water is
## too deep and too short of breath to swim across; a star thrown at the rope knot, high above
## the bank (a jump and a throw: the sword cannot reach it), lowers the bridge.
func _plan_lakes() -> void:
	if stage < 3:
		return
	var r := RandomNumberGenerator.new()
	r.seed = stage * 31337 + 3
	var cnt := 1 if boss_stage() else (2 if stage < 8 else 3)
	var usable := length - END_CLEAR - 2600.0
	for i in cnt:
		var w := r.randf_range(820.0, 900.0)
		var x0 := 1800.0 + usable * (float(i) + 0.2 + r.randf() * 0.5) / cnt
		var xa := x0 - 260.0
		var xb := x0 + w + 260.0
		if xb > length - END_CLEAR or _zone_busy(xa - 100.0, xb + 100.0):
			continue
		var lb := ground_y(xa)
		_flatten(xa, xb, lb, 170.0)
		var depth := minf(230.0, LOWEST - lb - 6.0)
		var lx1 := x0 + w
		for ii in range(maxi(0, int(x0 / SEG) - 1), mini(heights.size(), int(lx1 / SEG) + 3)):
			var gx := ii * SEG
			var ed := minf(gx - x0, lx1 - gx)
			if ed > 0.0:
				heights[ii] = lb + depth * smoothstep(0.0, 1.0, clampf(ed / 240.0, 0.0, 1.0))
		var level := lb + 12.0
		pools.append({"x0": x0 + 2.0, "x1": lx1 - 2.0, "level": level, "deadly": true})
		dips.append({"x0": x0, "x1": lx1, "level": level, "wet": true})
		reserved.append([xa - 140.0, xb + 140.0])
		bridges.append({"x0": x0, "x1": lx1, "y": lb, "rx": x0 - 120.0, "ry": lb - 190.0, "cut": false, "t": 0.0,
			"deck": Rect2(x0 - 6.0, lb, w + 12.0, 22.0)})
		for sx in [x0 - 200.0, x0 - 260.0]:
			drops.append({"x": sx, "y": lb - 20.0, "vy": 0.0, "kind": "star", "age": 0.0})

## Houses, pagodas, shrines and statues along the road; ruins on the ruined stages.
## Pagoda tiers (owner 2026-11-17: a little bigger): first roof PAG_H0 up, each next PAG_DH higher, each PAG_TAPER narrower.
## The jump is 168 px, so a roof is always one jump from the one below.
const PAG_H0 := 140.0
## The dragon statue (games/ink_ninja/art/dragon.png drawn DRAGON_H tall): its plinth is a solid you can climb.
const DRAGON_H := 470.0
const DRAGON_PLINTH := Vector2(200.0, 78.0)
const PAG_DH := 136.0
const PAG_TAPER := 80.0
const STRUCT_W := {"house": 280.0, "shrine": 260.0, "pagoda": 400.0, "akita": 240.0, "komainu": 860.0, "dragon": 320.0,
	"warriors": 600.0, "ruin_wall": 460.0, "ruin_arch": 360.0, "ruin_pagoda": 400.0,
	# owner artwork 2026-11-19 (games/ink_ninja/art): painted shrines and statues
	"kitsune": 200.0, "jizo": 320.0, "lantern": 160.0, "bell": 360.0, "gate": 540.0, "nio": 260.0,
	"ruin_house": 420.0, "ruin_stones": 400.0}

func _plan_structs() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = stage * 55331 + 17
	var x := 1900.0 + (TUTOR if stage == 1 else 0.0)
	var span := 3000.0
	#var pool: Array = ["ruin_wall", "ruin_arch", "warriors", "dragon", "ruin_pagoda", "akita", "komainu", "warriors", "ruin_wall"] if ruins \
	#	else ["house", "house", "shrine", "pagoda", "akita", "komainu", "dragon", "house", "shrine", "pagoda"]
	var pool: Array = ["ruin_wall", "ruin_arch", "warriors", "dragon", "ruin_pagoda", "akita", "komainu", "ruin_house", "ruin_stones", "nio", "ruin_wall"] if ruins \
		else ["house", "house", "shrine", "pagoda", "akita", "komainu", "dragon", "house", "shrine", "pagoda", "kitsune", "jizo", "lantern", "bell", "gate"]
	while x < length - END_CLEAR - 400.0:
		x += r.randf_range(span * 0.7, span * 1.3)
		var kind: String = pool[r.randi() % pool.size()]
		var w: float = STRUCT_W[kind]
		var xa := x - w * 0.5 - 90.0
		var xb := x + w * 0.5 + 90.0
		if xb + 100.0 > length - END_CLEAR or _zone_busy(xa - 120.0, xb + 120.0):
			continue
		var gy := ground_y(x)
		_flatten(xa, xb, gy, 170.0)
		reserved.append([xa - 40.0, xb + 40.0])
		_build_struct(kind, x, gy, w, r)

func _roof(rect: Rect2) -> void:
	solids.append(rect)
	roofs.append(rect)

func _secret(sx: float, sy: float) -> void:
	secrets.append({"x": sx, "y": sy, "got": false})

func _build_struct(kind: String, x: float, gy: float, w: float, r: RandomNumberGenerator) -> void:
	var s := {"kind": kind, "x": x, "y": gy, "w": w, "seed": r.randi() % 100000, "ruin": ruins, "tiers": 0}
	match kind:
		"house":
			_roof(Rect2(x - w / 2.0 - 20.0, gy - 126.0, w + 40.0, 16.0))
			if r.randf() < 0.6:
				scrolls.append(Vector2(x + r.randf_range(-40.0, 40.0), gy - 50.0))   # inside, by the lamp
			if r.randf() < 0.45:
				_secret(x + r.randf_range(-70.0, 70.0), gy - 126.0 - 32.0)
		"shrine":
			if r.randf() < 0.4:
				_secret(x, gy - 44.0)   # an offering left inside
		"pagoda", "ruin_pagoda":
			var tiers := 3 if kind == "pagoda" else 2
			s.tiers = tiers
			for i in tiers:
				var tw := w + 40.0 - i * PAG_TAPER
				_roof(Rect2(x - tw / 2.0, gy - PAG_H0 - i * PAG_DH, tw, 16.0))
			_secret(x - 80.0, gy - PAG_H0 - (tiers - 1) * PAG_DH - 32.0)   # on the top roof, beside the spire
			s["top"] = gy - PAG_H0 - (tiers - 1) * PAG_DH
		"dragon":
			#solids.append(Rect2(x - 77.0, gy - 126.0, 154.0, 126.0))   # a stone plinth you can climb (drawn 1.4x)
			solids.append(Rect2(x - DRAGON_PLINTH.x / 2.0, gy - DRAGON_PLINTH.y, DRAGON_PLINTH.x, DRAGON_PLINTH.y))   # the painted statue's plinth (owner art 2026-11-19)
		"warriors":
			if r.randf() < 0.4:
				_secret(x + r.randf_range(-120.0, 120.0), gy - 40.0)   # buried behind the ranks
		"ruin_wall":
			solids.append(Rect2(x - w / 2.0, gy - 150.0, 130.0, 150.0))
			solids.append(Rect2(x - w / 2.0 + 130.0, gy - 80.0, 120.0, 80.0))
			solids.append(Rect2(x + 60.0, gy - 120.0, 46.0, 120.0))
			if r.randf() < 0.65:
				_secret(x - w / 2.0 + 60.0, gy - 150.0 - 32.0)
	structs.append(s)

## Decorative bridges over the narrower rivers (owner 2026-11-16).
func _arch_bridges() -> void:
	for p in pools:
		if p.get("deadly", false) or p.x1 - p.x0 > 560.0:
			continue
		var g0 := ground_y(p.x0 - 40.0)
		var g1 := ground_y(p.x1 + 40.0)
		if absf(g0 - g1) > 12.0 or rng.randf() < 0.4:
			continue
		var y := minf(g0, g1) - 2.0
		var b := {"x0": p.x0 - 40.0, "x1": p.x1 + 40.0, "y": y}
		arch_bridges.append(b)
		var deck := Rect2(b.x0, y, b.x1 - b.x0, 14.0)
		_roof(deck)
		bridge_decks.append(deck)

## Spike boards that swing down on a beat (owner 2026-11-16): lure the foes under one.
func _plan_traps() -> void:
	if stage < 5:
		return
	var r := RandomNumberGenerator.new()
	r.seed = stage * 91121 + 7
	var cnt := 2 if stage < 10 else 3
	var usable := length - END_CLEAR - 3600.0
	for i in cnt:
		var tx := 0.0
		var found := false
		for tries in 16:
			tx = 2400.0 + usable * (float(i) + 0.05 + r.randf() * 0.9) / cnt
			if not _zone_busy(tx - 320.0, tx + 900.0):
				found = true
				break
		if not found:
			continue
		var gy := ground_y(tx)
		_flatten(tx - 220.0, tx + 800.0, gy, 170.0)
		reserved.append([tx - 260.0, tx + 840.0])
		foes = foes.filter(func(f): return f.x < tx - 320.0 or f.x > tx + 900.0)
		traps.append({"x": tx, "y": gy, "ph": r.randf() * 3.4, "state": "up", "t": 0.0, "was": "up"})
		for j in 3:
			var fx := tx + 340.0 + j * 150.0
			foes.append({"kind": "blade", "x": fx, "y": ground_y(fx), "vx": 0.0, "vy": 0.0, "hp": 1, "face": -1,
				"t": 0.0, "atk": 0.0, "hit": 0.0, "id": 1000 + i * 10 + j})

## Night stages: dark lanterns along the road, lit by swinging the torch next to them.
func _plan_night() -> void:
	if not night:
		return
	var x := 700.0
	while x < length - 300.0:
		x += rng.randf_range(650.0, 1000.0)
		if x < length - 300.0 and not _over_pit(x) and water_depth(x) <= 0.0:
			night_lanterns.append({"x": x, "lit": false})

## Level, dry ground between x0 and x1 (nothing sits on a slope or in water).
func _flat_dry(x0: float, x1: float) -> bool:
	if x0 < 800.0 or x1 > length - END_CLEAR or _over_pit(x0) or _over_pit(x1) or _scenery_blocked((x0 + x1) / 2.0, (x1 - x0) / 2.0):
		return false
	var g0 := ground_y(x0)
	var x := x0
	while x <= x1:
		if absf(ground_y(x) - g0) > 14.0 or water_depth(x) > 0.0:
			return false
		x += 20.0
	return true

## Cherry trees along the road (owner 2026-11-15): pink leaves, and one per stage with
## blood-red leaves (carve a heart in it). Own rng, so foes and land stay as they were.
func _trees() -> void:
	trees.clear()
	torii.clear()
	flora.clear()
	var r := RandomNumberGenerator.new()
	r.seed = stage * 104729 + 5
	var tx := 900.0
	while tx < length - END_CLEAR:
		tx += r.randf_range(3200.0, 5200.0)   # owner 2026-11-16: fewer gates, each one is a heart
		if tx < length - END_CLEAR and not _over_pit(tx - 110.0) and not _over_pit(tx + 110.0) and not _scenery_blocked(tx, 150.0):
			torii.append(tx)
	# Pink cherry trees: half as common as round 7 (owner 2026-11-15); bamboo, bushes and tall grass fill in.
	var x := 650.0
	while x < length - END_CLEAR:
		x += r.randf_range(1400.0, 3200.0)
		if x > length - END_CLEAR:
			break
		if _over_pit(x) or _over_pit(x + 80.0) or _scenery_blocked(x, 130.0) or _near_torii(x, 260.0):
			continue
		trees.append({"x": x, "h": r.randf_range(200.0, 280.0), "s": r.randi() % 100000, "blood": false})
	if trees.is_empty():
		var mx := length * 0.4
		while _over_pit(mx) or _scenery_blocked(mx, 130.0) or _near_torii(mx, 260.0):
			mx += 60.0
		trees.append({"x": mx, "h": 240.0, "s": 7, "blood": false})
	var pick := trees.size() / 3 + r.randi() % (trees.size() - trees.size() / 3)
	trees[pick].blood = true
	var fr := RandomNumberGenerator.new()
	fr.seed = stage * 7919 + 11
	var fx := 400.0
	while fx < length - END_CLEAR + 300.0:
		fx += fr.randf_range(160.0, 520.0)
		if fx > length - END_CLEAR + 300.0:
			break
		var kind: String = ["bamboo", "bush", "grass", "grass", "bush"][fr.randi() % 5]
		if _over_pit(fx - 40.0) or _over_pit(fx + 40.0) or _scenery_blocked(fx, 70.0) or _near_torii(fx, 150.0):
			continue
		flora.append({"x": fx, "kind": kind, "s": fr.randi() % 100000, "h": fr.randf_range(0.8, 1.25)})

## True when a ledge, pillar or wall sits within `half` of x (scenery never overlaps them).
func _scenery_blocked(x: float, half: float) -> bool:
	for s in solids:
		if s.size.y > 600.0:
			continue   # the world and arena walls
		if x + half > s.position.x and x - half < s.position.x + s.size.x:
			return true
	return false

func _near_torii(x: float, half: float) -> bool:
	for t in torii:
		if absf(t - x) < half:
			return true
	return false

## The blood-red tree when the hero stands within reach of it (else empty).
func heart_tree_near(reach: float = 170.0) -> Dictionary:
	for t in trees:
		if t.blood and absf(t.x - px) < reach:
			return t
	return {}

func boss_kind() -> int:
	return BOSS_KIND[clampi(act(), 1, 6) - 1]

func boss_name() -> String:
	return BOSS_NAMES[clampi(act(), 1, 6) - 1]

## Tutorial props and tip lines: stage 1 teaches the basics one at a time; later stages
## open with a line about what was just unlocked.
func _tutorial() -> void:
	tips.clear()
	match stage:
		1:
			tips = [[0.0, 700.0, "move"], [700.0, 1250.0, "crouch"], [1250.0, 1850.0, "jump"], [1850.0, 2700.0, "swing"]]
			solids.append(Rect2(1000.0, GROUND - 230.0, 170.0, 230.0 - 52.0))   # a low beam: crouch to pass under
			solids.append(Rect2(1550.0, GROUND - 120.0, 46.0, 120.0))   # a stump to jump
			foes.append({"kind": "blade", "x": 2300.0, "y": GROUND, "vx": 0.0, "vy": 0.0, "hp": 1, "face": -1,
				"t": 1.0, "atk": 0.0, "hit": 0.0, "id": foes.size()})
		2:
			tips = [[0.0, 1600.0, "block"]]
			var tfx := 1250.0
			while water_depth(tfx) > 0.0 or water_depth(tfx - 60.0) > 0.0 or water_depth(tfx + 60.0) > 0.0 or _over_pit(tfx):
				tfx += 40.0   # owner 2026-11-16: the first foe of stage 2 stood in the water
			foes.append({"kind": "thrower", "x": tfx, "y": ground_y(tfx), "vx": 0.0, "vy": 0.0, "hp": 1, "face": -1,
				"t": 1.5, "atk": 0.0, "hit": 0.0, "id": foes.size()})
		3:
			tips = [[0.0, 900.0, "star"], [900.0, 1700.0, "bomb"]]
		4:
			tips = [[0.0, 900.0, "thrust"]]
	if night:
		tips.append([0.0, 1400.0, "torch"])

## The tip key for where the hero stands ("" = none).
func tip() -> String:
	for t in tips:
		if px >= t[0] and px < t[1]:
			return t[2]
	for b in bridges:
		if not b.cut and px > b.x0 - 700.0 and px < b.x0:
			return "rope"
	for t in traps:
		if px > t.x - 560.0 and px < t.x - 90.0:
			return "trap"
	return ""

## Over a dip (wet or dry): nothing is placed there.
func _over_pit(x: float) -> bool:
	for d in dips:
		if x > d.x0 - 40 and x < d.x1 + 40:
			return true
	for r in reserved:
		if x > r[0] and x < r[1]:
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

## The pool over x (empty = none): deep lakes carry "deadly": true.
func pool_at(x: float) -> Dictionary:
	for p in pools:
		if x > p.x0 and x < p.x1:
			return p
	return {}

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
	var hpb := int((12 + act() * 5) * [0.7, 1.0, 1.3][diff] * (0.75 if act() == 1 else 1.0))   # the first duel is a gentle one (owner 2026-11-15)
	boss = {"kind": k, "x": arena_x + VIEW_W - 260, "y": GROUND, "vx": 0.0, "vy": 0.0, "hp": hpb, "max": hpb,
		"face": -1, "phase": "idle", "t": 1.2, "hit": 0.0, "n": 0}
	events.append("boss")

# ---------- step ----------

## move: -1..1, jump/slash/throw/dash: pressed this frame. Returns events.
func step(dt: float, move: float, jump: bool, slash: bool, throw: bool, dash: bool, down: bool = false, block: bool = false, bomb: bool = false) -> Array:
	events = []
	if state != "play":
		return events
	time += dt
	hurt_t = maxf(0.0, hurt_t - dt)
	swing_t = maxf(0.0, swing_t - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	var was_crouch := crouch
	crouch = down and on_ground and dash_t <= 0.0
	if was_crouch and not crouch and on_ground and _blocked_overhead():
		crouch = true   # no room to stand up under a beam
	blocking = block and can("block") and on_ground and dash_t <= 0.0 and slash_t <= 0.0
	if not can("star"):
		throw = false
		bomb = false
	if not can("thrust"):
		dash = false
	_player(dt, move, jump, slash, throw, dash, bomb)
	_foes(dt)
	_boss(dt)
	_shots(dt)
	for s in scrolls.duplicate():
		if absf(s.x - px) < 40 and absf(s.y - (py - PH / 2)) < 60:
			scrolls.erase(s)
			score += 50
			events.append("scroll")
			scroll_n += 1   # owner 2026-11-16: too many hearts: scrolls no longer heal
	_world(dt)
	for c in checkpoints:
		if px >= c and checkpoint_x < c:
			checkpoint_x = c
			events.append("checkpoint")
	if not locked and px > arena_x + 80 and not boss_stage():
		# A stage without a boss is cleared at its gate.
		state = "won"
		score += 500 + maxi(0, int(600 - time))
		events.append("clear")
		return events
	if not locked and px > arena_x + 80:
		locked = true
		solids.append(Rect2(arena_x, -400, 40, GROUND + 400))   # the gate shuts behind you
		_spawn_boss()
	if py > H + 120:
		_hurt(MAX_HP, true)
	return events

func _player(dt: float, move: float, jump: bool, slash: bool, throw: bool, dash: bool, bomb: bool = false) -> void:
	if absf(move) > 0.2:
		facing = 1 if move > 0 else -1
	if dash and dash_cd <= 0.0:
		dash_t = DASH_T
		dash_cd = DASH_CD
		thrust_hit = {}
		events.append("dash")
	var lv := water_level(px)
	in_water = py > lv + 8.0   # feet in the water
	var deadly: bool = in_water and pool_at(px).get("deadly", false)
	var swim := in_water and ground_y(px) - lv > PH * 0.75   # too deep to stand with the head out
	knock_t = maxf(0.0, knock_t - dt)
	if knock_t > 0.0:
		vy += GRAV * dt
	elif dash_t > 0.0:
		dash_t -= dt
		vx = facing * DASH_V * (WADE if in_water else 1.0)
		vy = 0.0
		_thrust_hits()
	else:
		var target := move * RUN * (DEADLY_WADE if deadly else (WADE if in_water else 1.0)) * (0.4 if crouch else 1.0)   # crouching: a slow creep (was: turn only)
		if blocking:
			target = 0.0   # feet planted behind the guard
		vx = move_toward(vx, target, (3000.0 if on_ground else 1800.0) * dt)
		if in_water:
			# water holds you up: a slow sink; a deep lake is heavy and sinks you fast
			vy = minf(vy + GRAV * (0.8 if deadly else 0.3) * dt, 420.0 if deadly else 200.0)
		else:
			vy += GRAV * dt
		if wall != 0 and vy > WALL_SLIDE:
			vy = WALL_SLIDE
	if not was_wet and in_water and vy > 250.0:
		events.append("splash")
	was_wet = in_water
	# Breath: only while the head is under water; surfacing refills it at once.
	if py - height() > lv + 4.0:
		air -= dt * (AIR / DEADLY_AIR if deadly else 1.0)   # a deep lake: the breath goes three times as fast
		if air <= 0.0:
			drown_t -= dt
			if drown_t <= 0.0:
				drown_t = DEADLY_TICK if deadly else DROWN_TICK
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
			vy = -SWIM_V * 0.45 if deadly else (-JUMP_V * 0.8 if py - height() < lv + 30.0 else -SWIM_V)   # a deep lake is too heavy to leap out of
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
		jab = crouch
		# Owner 2026-11-16: a cut while rising goes straight up, a cut while falling plunges
		# down (push sideways to keep the ordinary air slash).
		air_dir = 0
		if not on_ground and not in_water and not jab and absf(move) < 0.5:
			if vy < -80.0:
				air_dir = 1
			elif vy > 80.0:
				air_dir = 2
		swing = (swing + 1) % 3 if swing_t > 0.0 else 0
		swing_t = 0.75
		if jab:
			swing = 0
		events.append("jab" if jab else ("slash_up" if air_dir == 1 else ("slash_down" if air_dir == 2 else "slash")))
	if bomb and bombs > 0:
		bombs -= 1
		var bx := px + facing * 70.0
		smokes.append({"x": bx, "y": ground_y(bx), "t": 4.5})
		events.append("bomb")
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
			if s.size.y < 30.0 and py > s.position.y and py - s.position.y <= (60.0 if bridge_decks.has(s) else 14.0) and vy >= 0.0:
				py = s.position.y   # a small step up onto a thin deck or roof edge
				vy = 0.0
				r = _box()
				continue
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

## Standing up would hit a solid (crouched under a beam).
func _blocked_overhead() -> bool:
	var r := Rect2(px - PW / 2 + 2, py - PH, PW - 4, PH - CROUCH_H)
	for s in solids:
		if r.intersects(s):
			return true
	return false

## The thrust (owner 2026-11-15: running into a foe used to hurt YOU): the blade leads,
## every foe it meets takes 2, the boss 1; it stops at the first body and you bounce back.
func _thrust_hits() -> void:
	var r := Rect2(px - PW / 2 if facing > 0 else px - PW / 2 - 70, py - height(), PW + 70, height())
	for f in foes:
		if f.hp > 0 and not thrust_hit.has(f.id) and r.intersects(_foe_box(f)):
			thrust_hit[f.id] = true
			_hit_foe(f, 2, facing)
			if f.hp > 0:
				_thrust_stop()
	if not boss.is_empty() and boss.hp > 0 and not thrust_hit.has("boss") and r.intersects(boss_box()):
		thrust_hit["boss"] = true
		_hit_boss(1)
		_thrust_stop()

func _thrust_stop() -> void:
	dash_t = 0.0
	vx = -facing * 260.0
	hurt_t = maxf(hurt_t, 0.5)   # a moment to get clear

func slash_rect() -> Rect2:
	if air_dir == 1 and not jab:
		return Rect2(px - 56.0, py - height() - 130.0, 112.0, 150.0)   # straight up
	if air_dir == 2 and not jab:
		return Rect2(px - 52.0, py - 14.0, 104.0, 104.0)   # plunging below the feet
	if jab:
		var jx := px if facing > 0 else px - SLASH_REACH - 24
		return Rect2(jx, py - height() - 4, SLASH_REACH + 24, height())   # a jab reaches further, low and narrow
	var reach := SLASH_REACH * (1.25 if swing == 2 else 1.0)
	var x0 := px if facing > 0 else px - reach
	if swing == 1:
		return Rect2(x0, py - height() - 70, reach, height() + 80)   # the rising cut reaches high (leapers, branches)
	return Rect2(x0, py - height() - 10, reach, height() + 20)

func _slash_hits() -> void:
	var sr := slash_rect()
	var pogo := false
	for f in foes:
		if f.hp > 0 and not slash_hit.has(f.id) and sr.intersects(_foe_box(f)):
			slash_hit[f.id] = true
			_hit_foe(f, 2 if air_dir == 2 else 1, facing)
			pogo = pogo or air_dir == 2
	if not boss.is_empty() and boss.hp > 0 and not slash_hit.has("boss") and sr.intersects(boss_box()):
		slash_hit["boss"] = true
		_hit_boss(1)
		pogo = pogo or air_dir == 2
	if pogo:
		vy = -JUMP_V * 0.7   # a plunge that lands bounces you up again
		jumps = 1
		events.append("pogo")
	if night:
		for nl in night_lanterns:
			if not nl.lit and sr.grow(36.0).has_point(Vector2(nl.x, ground_y(nl.x) - 48.0)):
				nl.lit = true
				score += 25
				events.append("light")   # the torch lights the lantern
	for fl in flora:
		if air_dir == 0 and fl.kind == "bamboo" and not fl.get("cut", false) and sr.position.x - 8.0 < fl.x and sr.end.x + 8.0 > fl.x and absf(py - ground_y(fl.x)) < 90.0:
			fl.cut = true
			events.append("bamboo:%d:%d" % [int(fl.x), int(ground_y(fl.x) - 60.0)])
			# Owner 2026-11-16: only bamboo gives hearts (a third of the time); stars and
			# smoke bombs only once the hero can use them.
			var roll := rng.randf()
			var kind := ""
			if roll < 0.33:
				kind = "heart"
			elif can("star"):
				kind = "star" if roll < 0.55 else ("bomb" if roll < 0.62 else "")
			if kind != "":
				drops.append({"x": fl.x, "y": ground_y(fl.x) - 70.0, "vy": -260.0, "kind": kind, "age": 0.0})
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
		events.append("red:%d:%d:big" % [int(f.x), int(f.y - 40)])   # a kill leaves a big lasting pool
		if can("star"):   # owner 2026-11-16: nothing drops that the hero cannot use yet; hearts only come from bamboo
			if f.kind == "thrower" and rng.randf() < 0.3:
				stars = mini(MAX_STARS, stars + 2)
			elif rng.randf() < 0.07:
				drops.append({"x": f.x, "y": f.y - 40.0, "vy": -300.0, "kind": "star" if rng.randf() < 0.7 else "bomb", "age": 0.0})
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
	if not fell and blocking and not is_nan(from_x) and signf(from_x - px) == float(facing):
		events.append("block")   # the guard takes it: no damage, a small push back
		score += 10
		hurt_t = 0.25
		vx = -facing * 220.0
		return
	if not fell:
		dmg = mini(dmg, maxi(1, hp - 1))   # owner 2026-11-15: one hit is never death while you have hearts to spare
	hp -= dmg
	hits_taken += 1
	hurt_t = INVULN
	if hp <= 0 and revive_cb.is_valid() and revive_cb.call():
		# A spare life (the Landing helps, used automatically, owner 2026-11-16): back up at once.
		hp = 3
		hurt_t = 2.5
		events.append("hurt")
		events.append("revive")
		if fell or in_water:
			px = checkpoint_x
			py = ground_y(px)
			vx = 0.0
			vy = 0.0
			on_ground = true
		air = AIR
		drown_t = 0.0
		return
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
		if lives <= 0:
			lives = 3   # owner 2026-11-15: losing every life never starts the game over; you keep your stage and lanterns
			events.append("relife")
		state = "dead"
		events.append("die")
	elif fell:
		pass

## After "dead": restart the stage with full health.
func retry() -> void:
	hp = MAX_HP
	stars = clampi(maxi(stars, START_STARS), 0, MAX_STARS)
	bombs = clampi(maxi(bombs, 2), 0, MAX_BOMBS)
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
	stars = clampi(maxi(stars, START_STARS), 0, MAX_STARS)
	bombs = clampi(maxi(bombs, 2), 0, MAX_BOMBS)
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
		if _in_smoke(f.x, f.y):
			f.atk = 0.0
			f.vx = move_toward(f.vx, 0.0, 900 * dt)   # blinded: stands coughing, can't cut or throw
			f.blind = 0.3
			f.vy += GRAV * dt
			f.y = minf(f.y + f.vy * dt, ground_y(f.x))
			if f.y >= ground_y(f.x):
				f.vy = 0.0
			continue
		f.blind = 0.0
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
		# Owner 2026-11-16: foes do enter the water (slower), but a deep stretch drowns the ones
		# that stay: 3.5 s in deep water, 1.5 s in a deep lake.
		var wd := water_depth(f.x)
		var nx: float = f.x + f.vx * dt * (0.55 if wd > 10.0 else 1.0)
		f.x = nx
		if wd > 60.0:
			f.wet = f.get("wet", 0.0) + dt * (2.4 if pool_at(f.x).get("deadly", false) else 1.0)
			if f.wet > 3.5 and f.hp > 0:
				f.hp = 0
				score += 50
				events.append("foedrown:%d:%d" % [int(f.x), int(water_level(f.x))])
		else:
			f.wet = maxf(0.0, f.get("wet", 0.0) - dt * 2.0)
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

func _in_smoke(x: float, y: float) -> bool:
	for s in smokes:
		if absf(s.x - x) < 135.0 and absf(s.y - y) < 120.0:
			return true
	return false

## Pickups, smoke, torii blessings and spike traps (owner 2026-11-15).
func _world(dt: float) -> void:
	for d in drops:
		d.age += dt
		d.vy += GRAV * 0.6 * dt
		d.y += d.vy * dt
		var g := ground_y(d.x) - 18.0
		if d.y > g:
			d.y = g
			d.vy = 0.0
		if absf(d.x - px) < 38.0 and absf(d.y - (py - PH / 2.0)) < 60.0 and d.age > 0.25:
			if d.kind == "star":
				if stars >= MAX_STARS:
					continue   # a full quiver: it waits
				stars = mini(MAX_STARS, stars + 2)
			elif d.kind == "bomb":
				if bombs >= MAX_BOMBS:
					continue
				bombs += 1
			elif hp < MAX_HP:
				hp += 1
			else:
				continue   # a heart waits until you need it
			d.age = -999.0
			events.append("pick:" + d.kind)
	drops = drops.filter(func(d): return d.age > -900.0)
	for s in smokes:
		s.t -= dt
	smokes = smokes.filter(func(s): return s.t > 0.0)
	for tx in torii:
		if not torii_used.has(tx) and absf(tx - px) < 24.0 and hp < MAX_HP:
			torii_used[tx] = true
			hp += 1
			events.append("torii")   # the first pass heals one heart; the gate's incense is lit
	for t in traps:
		t.t += dt
		var cyc := fmod(t.t + t.ph, TRAP_PERIOD)
		t.state = "down" if (cyc >= 2.7 and cyc < 3.15) else ("warn" if (cyc >= 1.9 and cyc < 2.7) else "up")
		if t.state == "down" and t.was != "down":
			events.append("trapslam")
		t.was = t.state
		if t.state == "down":
			var zone := Rect2(t.x - 70.0, t.y - 130.0, 140.0, 130.0)
			for f in foes:
				if f.hp > 0 and zone.intersects(_foe_box(f)):
					_hit_foe(f, 9, 1)
					events.append("trapkill")
			if hurt_t <= 0.0 and dash_t <= 0.0 and zone.intersects(_box()):
				_hurt(2, false, t.x)
				events.append("spiked")
	for b in bridges:
		if b.cut:
			b.t += dt
	for sc in secrets:
		if not sc.got and absf(sc.x - px) < 38.0 and absf(sc.y - (py - PH / 2.0)) < 60.0:
			sc.got = true
			secrets_found += 1
			score += 500
			events.append("secret")
	for st in structs:
		if st.tiers > 0 and not pagodas_climbed.has(st.x) and absf(st.x - px) < st.w * 0.5 and py <= st.top + 6.0 and on_ground:
			pagodas_climbed[st.x] = true
			events.append("pagoda")

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
				boss.vx = boss.face * 700.0 * p * (0.8 if act() == 1 else 1.0)
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
			if on_ground and absf(dx) < (150 if act() == 1 else 220):
				_hurt(1, false, boss.x)
			if boss.phase == "leap":
				_boss_rest()
		boss.y = GROUND
		boss.vy = 0.0
	if boss_box().intersects(_box()):
		_hurt(2 if boss.phase == "charge" and act() > 1 else 1, false, boss.x)

func _boss_rest() -> void:
	boss.phase = "idle"
	boss.vx = 0.0
	boss.t = maxf(0.7, 1.8 - act() * 0.14 - diff * 0.2) + (0.5 if act() == 1 else 0.0)

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
			for b in bridges:
				if not b.cut and Vector2(b.rx, b.ry).distance_to(pt) < 30.0:
					b.cut = true
					solids.append(b.deck)   # the drawbridge falls across the lake
					s.life = 0.0
					score += 150
					events.append("rope")
			if s.life <= 0.0:
				continue
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
