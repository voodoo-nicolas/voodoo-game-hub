extends RefCounted

## Stonewater data (pure, no Nodes, headless-testable): pack ranks, terrain types,
## the premade campaign maps and missions, and the Quick Mission generator.
## Every map is just a dictionary the engine builds a world from (wolf_pack_engine.start):
##   name, w, h (px, multiples of 32), seed, type (a MAP_TYPES key), den, landmark,
##   herds [{at, n, sp, weak}], mud [Rect2], posts [Vector2], rivals [{at, n, boss}],
##   raid [Vector2] (where raiders come from; the engine picks edge points if empty).
## A mission is a dictionary: id, map, title, brief, objectives, par (secs for the
## time star), reward (renown), limit (secs, 0 = none), waves [[secs, n, boss]].
## Objectives: hunt {n, sp?}, scout {pct}, mark {n}, reach {}, rivals {n}, defend {secs}.

const CELL := 32.0

# ---------- ranks ----------
## Rank = standing in the pack. Everything is cumulative: a rank keeps what the ones
## before it gave. stage = the body (engine STAGES), roster = who runs with you,
## cmds = what the command wheel offers, abil = abilities switched on.
const RANKS := [
	{"id": "pup", "name": "Pup", "renown": 0, "stage": "pup",
		"roster": [], "cmds": ["rally", "hold"], "abil": ["sense", "sprint"],
		"gain": ["Sense: smell out the weak ones", "Sprint", "Rally: howl and the pack regroups"]},
	{"id": "hunter", "name": "Hunter", "renown": 100, "stage": "juvenile",
		"roster": ["chaser"], "cmds": ["rally", "hold", "drive"], "abil": ["sense", "sprint"],
		"gain": ["A stronger body", "Drive command", "Dart the chaser joins you"]},
	{"id": "tracker", "name": "Tracker", "renown": 260, "stage": "lone",
		"roster": ["chaser", "scout"], "cmds": ["rally", "hold", "drive", "scout"], "abil": ["sense", "sprint", "pounce", "far_sense"],
		"gain": ["Pounce: leap on a running animal", "Scout ahead command", "Whisper the scout joins you", "Longer Sense"]},
	{"id": "warden", "name": "Warden", "renown": 460, "stage": "leader",
		"roster": ["chaser", "scout", "attacker"], "cmds": ["rally", "hold", "drive", "scout", "flank", "strike"],
		"abil": ["sense", "sprint", "pounce", "far_sense", "rally_howl"],
		"gain": ["Flank and Strike commands", "Rallying Howl: heals and quickens the pack", "Juniper the striker joins you"]},
	{"id": "leader", "name": "Pack Leader", "renown": 700, "stage": "leader",
		"roster": ["chaser", "scout", "attacker", "guardian"], "cmds": ["rally", "hold", "drive", "scout", "flank", "strike", "guard"],
		"abil": ["sense", "sprint", "pounce", "far_sense", "rally_howl", "guard"],
		"gain": ["Guard command", "Boulder the guardian joins you", "A fifth wolf: the pack at full strength"]},
	{"id": "elder", "name": "Elder", "renown": 1250, "stage": "elder",
		"roster": ["chaser", "scout", "attacker", "guardian"], "cmds": ["rally", "hold", "drive", "scout", "flank", "strike", "guard"],
		"abil": ["sense", "sprint", "pounce", "far_sense", "rally_howl", "guard", "wisdom"],
		"gain": ["Wisdom: every command works half again as well", "Faster Sense"]},
]
const QUICK_RANK := 4

static func rank_for(renown: int) -> int:
	var r := 0
	for i in RANKS.size():
		if renown >= int(RANKS[i].renown):
			r = i
	return r

## Renown still needed for the next rank (0 at the top).
static func renown_to_next(renown: int) -> int:
	var r := rank_for(renown)
	if r >= RANKS.size() - 1:
		return 0
	return int(RANKS[r + 1].renown) - renown

static func rank(i: int) -> Dictionary:
	return RANKS[clampi(i, 0, RANKS.size() - 1)]

static func has_ability(rank_i: int, a: String) -> bool:
	return a in rank(rank_i).abil

# ---------- species ----------
## speed px/s; stam healthy / weak; hold = seconds of biting (weak / healthy); kick = damage;
## alert = how close a wolf alarms it.
const SPECIES := {
	"deer": {"name": "Deer", "speed": 360.0, "stam": 90.0, "stam_weak": 40.0, "hp": 50.0, "hp_weak": 35.0,
		"hold_weak": 2.4, "hold": 3.6, "kick": 8.0, "alert": 560.0, "herd": false},
	"elk": {"name": "Elk", "speed": 330.0, "stam": 120.0, "stam_weak": 50.0, "hp": 100.0, "hp_weak": 60.0,
		"hold_weak": 3.2, "hold": 5.0, "kick": 14.0, "alert": 520.0, "herd": true},
	"bison": {"name": "Bison", "speed": 270.0, "stam": 220.0, "stam_weak": 110.0, "hp": 220.0, "hp_weak": 140.0,
		"hold_weak": 6.0, "hold": 9.0, "kick": 26.0, "alert": 380.0, "herd": true},
}

# ---------- terrain types ----------
## opts go straight to TerrainGen; tint multiplies the grass; mud = how many bogs a
## quick map gets; relief = how strong the hill shading looks.
const MAP_TYPES := {
	"hills": {"name": "Rolling Hills", "icon": "🌄", "blurb": "Open, rolling land. A fair start.",
		"opts": {"hill": 30.0, "octaves": 5, "warp": 0.7, "macro": 1.0, "macro_size": 3.0, "ridge": 0.15, "max_slope": 0.055, "valleys": 0.45, "erosion": 0.8},
		"tint": Color(0.95, 1.02, 0.88), "mud": 3, "relief": 9.0},
	"valleys": {"name": "Winding Valleys", "icon": "🏞", "blurb": "Long low paths between ridges. Prey follows the valleys.",
		"opts": {"hill": 34.0, "octaves": 5, "warp": 0.9, "macro": 0.8, "macro_size": 3.0, "ridge": 0.1, "max_slope": 0.05, "valleys": 0.62, "erosion": 1.0},
		"tint": Color(0.88, 1.0, 0.92), "mud": 2, "relief": 9.0},
	"highlands": {"name": "High Scree", "icon": "⛰", "blurb": "Steep climbs slow everyone. Tall prey.",
		"opts": {"hill": 26.0, "octaves": 5, "warp": 0.6, "macro": 1.3, "macro_size": 3.0, "ridge": 0.35, "max_slope": 0.078, "valleys": 0.25, "erosion": 1.2},
		"tint": Color(0.84, 0.88, 0.82), "mud": 1, "relief": 11.0},
	"marsh": {"name": "Fog Marsh", "icon": "🌫", "blurb": "Flat and boggy. Mud slows wolves and prey.",
		"opts": {"hill": 45.0, "octaves": 4, "warp": 0.5, "macro": 0.4, "macro_size": 3.0, "ridge": 0.0, "max_slope": 0.035, "valleys": 0.2, "erosion": 0.3},
		"tint": Color(0.76, 0.92, 0.8), "mud": 8, "relief": 6.0},
	"badlands": {"name": "Burnt Ridge", "icon": "🔥", "blurb": "Gullied, sun-baked ground. Fast and rough.",
		"opts": {"hill": 22.0, "octaves": 6, "warp": 0.7, "macro": 0.9, "macro_size": 3.0, "ridge": 0.45, "max_slope": 0.08, "valleys": 0.5, "erosion": 1.5},
		"tint": Color(1.06, 0.92, 0.72), "mud": 1, "relief": 10.0},
}
const TYPE_ORDER := ["hills", "valleys", "highlands", "marsh", "badlands"]

# ---------- player roles (Quick Mission) ----------
## The hero's own role. Only the Leader gives orders; for the other roles a packmate
## (Sable) leads and calls the hunt. Keys match the engine ROLES.
const PLAY_ROLES := {
	"leader": {"name": "Leader", "icon": "👑", "blurb": "Command the pack: Drive, Flank, Strike. The decisive bite is yours."},
	"chaser": {"name": "Chaser", "icon": "💨", "blurb": "Fastest runner. Wear prey down until the pack can finish it."},
	"attacker": {"name": "Striker", "icon": "🦷", "blurb": "Hardest bite and the strongest hold. Wins fights and takedowns."},
	"scout": {"name": "Scout", "icon": "👁", "blurb": "Sees farthest, Sense lasts longer. Maps the land, marks borders."},
}
const ROLE_ORDER := ["leader", "chaser", "attacker", "scout"]

# ---------- campaign maps ----------
const MAPS := {
	"valley": {"name": "Stonewater Valley", "w": 4096, "h": 3072, "seed": 11, "type": "hills",
		"den": Vector2(700, 2500), "landmark": Vector2(2100, 1500),
		"herds": [{"at": Vector2(3000, 900), "n": 5, "sp": "deer", "weak": 2}, {"at": Vector2(3300, 2200), "n": 8, "sp": "elk", "weak": 2}],
		"mud": [Rect2(1500, 2000, 420, 300), Rect2(2700, 1500, 360, 280), Rect2(1200, 900, 320, 260)],
		"posts": [Vector2(1500, 2800), Vector2(2600, 2500), Vector2(1000, 1200), Vector2(3400, 1500)],
		"rivals": []},
	"flats": {"name": "Driftwood Flats", "w": 5120, "h": 3840, "seed": 23, "type": "valleys",
		"den": Vector2(600, 3200), "landmark": Vector2(2600, 1800),
		"herds": [{"at": Vector2(3600, 800), "n": 7, "sp": "deer", "weak": 2}, {"at": Vector2(4200, 2800), "n": 8, "sp": "elk", "weak": 2}, {"at": Vector2(1700, 900), "n": 5, "sp": "deer", "weak": 1}],
		"mud": [Rect2(1800, 2600, 520, 380), Rect2(3000, 1900, 420, 320), Rect2(900, 1500, 380, 300), Rect2(3900, 1500, 460, 300), Rect2(2300, 700, 400, 260)],
		"posts": [Vector2(1400, 3300), Vector2(2900, 3000), Vector2(900, 1700), Vector2(2200, 1100), Vector2(4300, 1900), Vector2(3800, 3400)],
		"rivals": [{"at": Vector2(4000, 1200), "n": 2, "boss": false}, {"at": Vector2(3300, 3300), "n": 2, "boss": false}]},
	"pines": {"name": "Hollow Pines", "w": 6144, "h": 4608, "seed": 37, "type": "hills",
		"den": Vector2(1000, 3700), "landmark": Vector2(3100, 2100),
		"herds": [{"at": Vector2(4400, 1300), "n": 10, "sp": "elk", "weak": 3}, {"at": Vector2(2000, 1000), "n": 6, "sp": "deer", "weak": 2}, {"at": Vector2(4900, 3500), "n": 8, "sp": "elk", "weak": 2}],
		"mud": [Rect2(2200, 2600, 520, 380), Rect2(3500, 1700, 420, 320), Rect2(4700, 900, 560, 300), Rect2(1800, 1500, 380, 420), Rect2(3900, 2900, 500, 360)],
		"posts": [Vector2(1700, 3900), Vector2(2900, 3300), Vector2(1200, 2200), Vector2(2500, 1500), Vector2(4000, 2300), Vector2(5200, 2000), Vector2(5300, 3000), Vector2(3500, 3900)],
		"rivals": [{"at": Vector2(5000, 2400), "n": 2, "boss": false}],
		"raid": [Vector2(6000, 600), Vector2(6000, 2400), Vector2(3600, 80)]},
	"scree": {"name": "High Scree", "w": 6144, "h": 4608, "seed": 41, "type": "highlands",
		"den": Vector2(900, 3800), "landmark": Vector2(3300, 1500),
		"herds": [{"at": Vector2(4300, 1100), "n": 6, "sp": "bison", "weak": 2}, {"at": Vector2(2300, 2800), "n": 6, "sp": "deer", "weak": 2}, {"at": Vector2(5000, 2900), "n": 7, "sp": "elk", "weak": 2}],
		"mud": [Rect2(2000, 1500, 400, 300)],
		"posts": [Vector2(1500, 3200), Vector2(2700, 3500), Vector2(1800, 1800), Vector2(3900, 2300), Vector2(5200, 1500)],
		"rivals": []},
	"ridge": {"name": "Burnt Ridge", "w": 6144, "h": 4608, "seed": 53, "type": "badlands",
		"den": Vector2(800, 3600), "landmark": Vector2(3000, 2300),
		"herds": [{"at": Vector2(4400, 1500), "n": 7, "sp": "deer", "weak": 2}, {"at": Vector2(2300, 800), "n": 7, "sp": "elk", "weak": 2}],
		"mud": [Rect2(2500, 3300, 400, 280)],
		"posts": [Vector2(1500, 3000), Vector2(2200, 2000), Vector2(3600, 3200), Vector2(4300, 2500), Vector2(5000, 1000), Vector2(1700, 1100)],
		"rivals": [{"at": Vector2(3900, 1400), "n": 2, "boss": false}, {"at": Vector2(5000, 2300), "n": 2, "boss": false}, {"at": Vector2(2800, 700), "n": 2, "boss": false}, {"at": Vector2(4800, 3700), "n": 1, "boss": false}]},
	"marsh": {"name": "Ashmaw Marsh", "w": 6144, "h": 4608, "seed": 61, "type": "marsh",
		"den": Vector2(1000, 3500), "landmark": Vector2(3300, 2200),
		"herds": [{"at": Vector2(4600, 3000), "n": 7, "sp": "deer", "weak": 2}],
		"mud": [Rect2(1800, 3000, 600, 400), Rect2(2600, 2500, 500, 400), Rect2(3800, 2800, 600, 380), Rect2(2300, 1500, 560, 360), Rect2(4200, 1500, 520, 400), Rect2(3300, 3600, 600, 360), Rect2(1400, 1900, 480, 380)],
		"posts": [Vector2(1700, 3900), Vector2(2800, 3300), Vector2(3600, 1900), Vector2(4900, 2200)],
		"rivals": [],
		"raid": [Vector2(6000, 300), Vector2(6000, 2200), Vector2(5800, 4500), Vector2(3000, 80)]},
	"stonewater": {"name": "Stonewater", "w": 6144, "h": 4608, "seed": 11, "type": "hills",
		"den": Vector2(700, 2500), "landmark": Vector2(3100, 2300),
		"herds": [{"at": Vector2(3000, 900), "n": 5, "sp": "deer", "weak": 2}, {"at": Vector2(3500, 3600), "n": 9, "sp": "elk", "weak": 3}],
		"mud": [Rect2(1500, 2000, 420, 300), Rect2(2700, 1500, 360, 280), Rect2(1200, 900, 320, 260), Rect2(4000, 2800, 520, 360)],
		"posts": [Vector2(1500, 2800), Vector2(2600, 2500), Vector2(1000, 1200), Vector2(3400, 1500), Vector2(4300, 1000), Vector2(5000, 2200)],
		"rivals": [{"at": Vector2(4300, 2400), "n": 2, "boss": false}, {"at": Vector2(4500, 1300), "n": 2, "boss": false}, {"at": Vector2(5100, 3300), "n": 2, "boss": false}, {"at": Vector2(5400, 1100), "n": 1, "boss": true}],
		"raid": [Vector2(6000, 700), Vector2(6000, 3600)]},
}

# ---------- campaign missions ----------
## Each is playable once the one before is finished. "par" is the time for the second
## star; the third is for losing no wolf. "reward" is renown for a first win (replays
## pay a third), +10 for each star above the first.
const MISSIONS := [
	{"id": "m01", "map": "valley", "title": "First Tracks",
		"brief": "You are the smallest of the pack. Find a weak deer and show you can hunt. Use Sense to read the herd.",
		"objectives": [{"t": "hunt", "n": 1, "sp": "deer"}], "par": 240, "reward": 60},
	{"id": "m02", "map": "valley", "title": "The Limping Elk",
		"brief": "The herd is on the far slope. One elk limps. Your nose will find it; your pack will wait for your signal.",
		"objectives": [{"t": "hunt", "n": 2}, {"t": "mark", "n": 2}], "par": 420, "reward": 70},
	{"id": "m03", "map": "flats", "title": "Driftwood Flats",
		"brief": "A new land of rivers and mud. Learn it by walking it, and feed the pack while you do.",
		"objectives": [{"t": "scout", "pct": 50}, {"t": "hunt", "n": 2}], "par": 540, "reward": 90},
	{"id": "m04", "map": "flats", "title": "Scent Borders",
		"brief": "Another pack hunts here. Mark your borders, and drive off any wolf that will not respect them.",
		"objectives": [{"t": "mark", "n": 4}, {"t": "rivals", "n": 3}], "par": 600, "reward": 100},
	{"id": "m05", "map": "pines", "title": "Hollow Pines",
		"brief": "Old forest, deep elk country. Lead the pack to the Howl Point, then feed it.",
		"objectives": [{"t": "reach"}, {"t": "hunt", "n": 3, "sp": "elk"}], "par": 600, "reward": 110},
	{"id": "m06", "map": "pines", "title": "Night Raid",
		"brief": "Raiders come for the den at night. Hold the den until dawn: every wolf you drive off is a wolf that cannot bite your pack.",
		"objectives": [{"t": "defend", "secs": 150}], "par": 150, "reward": 140,
		"waves": [[12, 2, false], [55, 3, false], [100, 3, false]]},
	{"id": "m07", "map": "scree", "title": "Thunder on the Scree",
		"brief": "A bison herd on the mountain. No lone wolf takes one. Drive it, flank it, and strike together.",
		"objectives": [{"t": "hunt", "n": 1, "sp": "bison"}, {"t": "hunt", "n": 2}], "par": 720, "reward": 150},
	{"id": "m08", "map": "ridge", "title": "Ash and Green",
		"brief": "The burnt ridge is growing back, and Ashmaw scouts are hunting it. Mark it as yours.",
		"objectives": [{"t": "mark", "n": 5}, {"t": "rivals", "n": 5}], "par": 720, "reward": 160},
	{"id": "m09", "map": "marsh", "title": "Night Siege",
		"brief": "Ashmaw attacks the den from every side. Guard it, and keep the pack together in the fog.",
		"objectives": [{"t": "defend", "secs": 200}], "par": 200, "reward": 180,
		"waves": [[10, 3, false], [50, 3, false], [95, 4, false], [140, 4, true]]},
	{"id": "m10", "map": "stonewater", "title": "Stonewater",
		"brief": "Home again, and all of it now yours to see. Break the Ashmaw line, face Skarn, and bring the valley back.",
		"objectives": [{"t": "rivals", "n": 6}, {"t": "hunt", "n": 2}], "par": 900, "reward": 220},
]

static func mission(id: String) -> Dictionary:
	for m in MISSIONS:
		if m.id == id:
			return m
	return {}

static func mission_index(id: String) -> int:
	for i in MISSIONS.size():
		if MISSIONS[i].id == id:
			return i
	return -1

## Map dictionary for a campaign mission.
static func map_for(m: Dictionary) -> Dictionary:
	return MAPS[m.map]

## Renown a win is worth: `first` = never won before.
static func reward_for(m: Dictionary, stars: int, first: bool) -> int:
	var base: int = int(m.reward) if first else floori(float(m.reward) / 3.0)
	return base + 10 * maxi(0, stars - 1)

# ---------- quick mission ----------

## Builds a whole quick mission from three choices. Same (type, role, seed) = same mission.
## Returns {"map": ..., "mission": ..., "rank": QUICK_RANK, "role": role}. The map is small
## (3072 x 2304) so a mission lasts about five minutes.
static func quick_setup(type_id: String, role: String, seed_v: int) -> Dictionary:
	if not MAP_TYPES.has(type_id):
		type_id = "hills"
	if not PLAY_ROLES.has(role):
		role = "leader"
	var r := RandomNumberGenerator.new()
	r.seed = seed_v * 7919 + 13
	var w := 3072.0
	var h := 2304.0
	var den := Vector2(w * r.randf_range(0.10, 0.17), h * r.randf_range(0.70, 0.86))
	var lm := Vector2(w * r.randf_range(0.42, 0.58), h * r.randf_range(0.30, 0.55))
	var taken: Array = [den, lm]
	var herds: Array = []
	var species: Array = ["deer", "elk"]
	if type_id == "highlands":
		species = ["elk", "bison", "deer"]
	elif type_id == "marsh":
		species = ["deer", "deer", "elk"]
	for i in 3:
		var sp: String = species[i % species.size()]
		var at := _spot(r, w, h, taken, 800.0, Rect2(w * 0.40, h * 0.10, w * 0.55, h * 0.78))
		taken.append(at)
		herds.append({"at": at, "n": 4 if sp == "bison" else r.randi_range(5, 7), "sp": sp, "weak": 2})
	var mud: Array = []
	for i in int(MAP_TYPES[type_id].mud):
		var at2 := _spot(r, w, h, [den], 420.0, Rect2(w * 0.10, h * 0.08, w * 0.80, h * 0.84))
		mud.append(Rect2(at2 - Vector2(220, 160), Vector2(r.randf_range(320, 520), r.randf_range(240, 380))))
	var n_posts := 5 if role == "scout" else 4
	var posts: Array = []
	var ptaken: Array = [den]
	for i in n_posts:
		var pp := _spot(r, w, h, ptaken, 520.0, Rect2(w * 0.08, h * 0.08, w * 0.84, h * 0.84))
		ptaken.append(pp)
		posts.append(pp)
	var rivals: Array = []
	var n_riv := 0
	if role == "attacker":
		n_riv = 3
	elif role == "leader":
		n_riv = 2
	var rtaken: Array = [den, lm]
	var groups := 2 if n_riv > 0 else 0
	for i in groups:
		var rp := _spot(r, w, h, rtaken, 800.0, Rect2(w * 0.5, h * 0.08, w * 0.45, h * 0.84))
		rtaken.append(rp)
		rivals.append({"at": rp, "n": ceili(n_riv / 2.0) if i == 0 else floori(n_riv / 2.0), "boss": false})
	var map := {"name": "Quick Mission", "w": int(w), "h": int(h), "seed": seed_v, "type": type_id,
		"den": den, "landmark": lm, "herds": herds, "mud": mud, "posts": posts, "rivals": rivals, "raid": []}
	var objectives: Array = []
	var title := ""
	var brief := ""
	match role:
		"chaser":
			objectives = [{"t": "hunt", "n": 4}]
			title = "Run Them Down"
			brief = "You are the chaser. Wear the prey down and let the pack finish the job."
		"attacker":
			objectives = [{"t": "rivals", "n": n_riv}, {"t": "hunt", "n": 2}]
			title = "Hold the Line"
			brief = "You are the striker. Drive off the rival wolves, then take a meal for the pack."
		"scout":
			objectives = [{"t": "scout", "pct": 55}, {"t": "mark", "n": n_posts}]
			title = "Pathfinder"
			brief = "You are the scout. Map the land and mark its borders."
		_:
			objectives = [{"t": "hunt", "n": 3}, {"t": "mark", "n": 3}, {"t": "rivals", "n": n_riv}]
			title = "Lead the Pack"
			brief = "You are the leader. Feed the pack, mark the border, and drive off anyone who tests it."
	var mission := {"id": "quick", "map": "quick", "title": title, "brief": brief, "objectives": objectives,
		"par": 330, "reward": 0}
	return {"map": map, "mission": mission, "rank": QUICK_RANK, "role": role, "type": type_id, "seed": seed_v}

## A random point inside `area`, at least `gap` from every point in `avoid`.
static func _spot(r: RandomNumberGenerator, w: float, h: float, avoid: Array, gap: float, area: Rect2) -> Vector2:
	var best := area.get_center()
	var best_d := -1.0
	for _try in 30:
		var p := Vector2(r.randf_range(area.position.x, area.end.x), r.randf_range(area.position.y, area.end.y))
		p = Vector2(clampf(p.x, 160.0, w - 160.0), clampf(p.y, 160.0, h - 160.0))
		var nearest := 1e9
		for a in avoid:
			nearest = minf(nearest, p.distance_to(a))
		if nearest >= gap:
			return p
		if nearest > best_d:
			best_d = nearest
			best = p
	return best

## Who runs with the hero in a Quick Mission: the full pack minus the player's own role;
## a non-leader player gets Sable as the NPC leader calling the hunt.
static func quick_roster(role: String) -> Array:
	var out: Array = []
	for ro in ["chaser", "scout", "attacker", "guardian"]:
		if ro != role:
			out.append(ro)
	if role != "leader":
		out.append("leader")
	return out
