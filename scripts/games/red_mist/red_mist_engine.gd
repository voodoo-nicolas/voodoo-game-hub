extends RefCounted

## Red Mist: pure logic (no Nodes), testable headless (tools/test_red_mist.gd).
##
## One static scene per contract: a valley seen from a hide 15 m above its floor.
## The world is a 2400 x 1080 picture in "world units". A thing D metres away
## that is M metres wide is M * F / D units wide; its foot sits on
## HORIZON + CAM_H * F / D. Angles are in milliradians (mils): one mil is
## MIL world units at every range, so the reticle's mil dots, the sway, the
## drop and the wind all share one unit.
##
## Breathing sway: one breath every BREATH seconds; the last part of each
## breath is the natural pause, when the aim sits still. Holding the breath
## freezes the breathing for a few seconds, then the shakes grow and a gasp
## follows. The heart speeds up with every shot and settles back.
##
## Contracts (30, in 6 places, 5 each) set the time of day, the weather and the
## goal: "officer" (take him down before he runs), "all" (everyone, nobody may
## get away), "timed" (everyone before the clock runs out) or "convoy" (stop
## every truck before it leaves; a shot in the fuel tank blows it up, a shot
## through the cab window stops it). Some contracts have civilians in hi-vis
## vests: hitting one ends the contract.

const W := 2400.0
const H := 1080.0
const HORIZON := 470.0
const F := 3333.333
const CAM_H := 15.0
const MIL := F / 1000.0
const V0 := 820.0           # muzzle speed, m/s
const GRAV := 9.81
const ZERO_M := 300.0       # the rifle is zeroed at 300 m
const MAG := 5
const BOLT_S := 1.1         # bolt cycle between shots
const RELOAD_S := 2.6
const BREATH := 4.2         # seconds per breath at rest
const BREATH_MOVE := 0.7    # the part of a breath that moves the aim; the rest is the pause
const HOLD_GOOD := 3.5      # held breath stays steady this long...
const HOLD_MAX := 6.0       # ...and runs out here (a gasp follows)
const GASP_S := 2.4
const REST_HEART := 68.0
const BODY_H := 1.8
const HEAD_R := 0.13
const BODY_W := 0.52
const TRUCK_L := 6.5        # truck length, m
const LEVELS := ["Easy", "Normal", "Hard"]
const SWAY_K := [0.6, 1.0, 1.35]
const LOCATIONS := ["alpine", "desert", "harbour", "canyon", "jungle", "city"]
const LOC_NAMES := {"alpine": "Alpine Pass", "desert": "Dust Basin", "harbour": "Grey Harbour",
	"canyon": "Canyon Railway", "jungle": "Jungle Temple", "city": "Night City"}
const GOALS := ["officer", "all", "timed", "convoy"]
const TIMES := ["dawn", "day", "dusk", "night"]
const PER_PLACE := 5
## Rifle upgrades bought in the Armory: level 0..3 of each line. Each row is
## the value at levels 0, 1, 2, 3.
const UPGRADES := {
	"scope": {"name": "Scope", "what": "Zooms further", "cost": [400, 900, 1600], "zoom": [12.0, 16.0, 20.0, 24.0]},
	"bipod": {"name": "Bipod", "what": "Steadier aim", "cost": [400, 900, 1600], "sway": [1.0, 0.88, 0.78, 0.7]},
	"bolt": {"name": "Bolt", "what": "Faster bolt and reload", "cost": [400, 900, 1600], "bolt": [1.1, 0.95, 0.8, 0.65], "reload": [2.6, 2.3, 2.0, 1.7]},
	"supp": {"name": "Suppressor", "what": "Quieter shots: the alarm rises slower", "cost": [400, 900, 1600], "alarm": [1.0, 0.75, 0.55, 0.4]},
}

## The scenery per location. Structures are drawn by red_mist_scenery.gd ("base":
## metres it stands on, e.g. a water tank on a roof; "zd": the range used to sort
## it when people stand on it); posts are where a target may stand ([x, d, h
## above ground, cover = lower part hidden]); paths are where someone walks ([x1,
## x2, d, h]); the road is where trucks drive ([x, d] points); drums ([x, d, h])
## and the dish ([x, d, h]) can be shot.
const LAYOUT := {
	"alpine": {
		"structures": [
			{"t": "cabin", "x": 640, "d": 210, "w": 9, "h": 4.5},
			{"t": "truck", "x": 1880, "d": 262, "w": 6, "h": 2.8},
			{"t": "tower", "x": 1120, "d": 290, "w": 4, "h": 8},
			{"t": "cabin", "x": 1560, "d": 330, "w": 11, "h": 5},
			{"t": "sandbags", "x": 985, "d": 420, "w": 6, "h": 1.1},
			{"t": "cabin", "x": 760, "d": 560, "w": 12, "h": 5},
			{"t": "mast", "x": 1720, "d": 620, "w": 1, "h": 22},
			{"t": "tower", "x": 420, "d": 760, "w": 4, "h": 9},
			{"t": "tent", "x": 1340, "d": 880, "w": 7, "h": 3},
			{"t": "sandbags", "x": 2020, "d": 900, "w": 7, "h": 1.1},
		],
		"road": [[-80, 150], [520, 200], [1000, 300], [1400, 470], [1650, 700], [1800, 1000]],
		"posts": [[720, 204, 0.0, 0.0], [1120, 290, 8.0, 0.35], [1480, 326, 0.0, 0.0], [985, 422, 0.0, 0.45],
			[1820, 256, 0.0, 0.0], [820, 565, 0.0, 0.0], [1700, 625, 0.0, 0.0], [420, 760, 9.0, 0.35],
			[1360, 882, 0.0, 0.0], [2020, 902, 0.0, 0.45]],
		"paths": [[480, 900, 250], [1300, 1800, 380], [560, 1100, 600], [1480, 2000, 700], [900, 1500, 950]],
		"drums": [[1870, 252], [1460, 560], [1010, 888]],
		"dish": [1720, 620, 18.0],
		"wind": 1.0,
	},
	"desert": {
		"structures": [
			{"t": "jeep", "x": 1050, "d": 230, "w": 4.5, "h": 2.0},
			{"t": "sandbags", "x": 1400, "d": 262, "w": 6, "h": 1.1},
			{"t": "tank", "x": 600, "d": 300, "w": 14, "h": 10},
			{"t": "hut", "x": 2000, "d": 380, "w": 8, "h": 3.5},
			{"t": "pipes", "x": 1150, "d": 450, "w": 260, "h": 1.6},
			{"t": "tent", "x": 420, "d": 520, "w": 8, "h": 3},
			{"t": "tank", "x": 1700, "d": 520, "w": 18, "h": 12},
			{"t": "tower", "x": 850, "d": 600, "w": 4, "h": 9},
			{"t": "flare", "x": 1250, "d": 700, "w": 2, "h": 30},
			{"t": "sandbags", "x": 1950, "d": 850, "w": 7, "h": 1.1},
			{"t": "mast", "x": 300, "d": 900, "w": 1, "h": 20},
		],
		"road": [[-80, 170], [700, 210], [1300, 280], [2480, 330]],
		"posts": [[1110, 226, 0.0, 0.0], [1400, 264, 0.0, 0.45], [700, 296, 0.0, 0.0], [1940, 376, 0.0, 0.0],
			[600, 300, 10.0, 0.0], [450, 522, 0.0, 0.0], [850, 600, 9.0, 0.35], [1620, 516, 0.0, 0.0],
			[1950, 852, 0.0, 0.45], [330, 902, 0.0, 0.0]],
		"paths": [[800, 1350, 240], [1500, 2100, 340], [500, 1000, 450], [1100, 1650, 640], [400, 1100, 820]],
		"drums": [[1150, 236], [1780, 524], [1900, 846]],
		"dish": [300, 900, 16.0],
		"wind": 1.3,
	},
	"harbour": {
		"structures": [
			{"t": "sandbags", "x": 1200, "d": 240, "w": 6, "h": 1.1},
			{"t": "containers", "x": 500, "d": 250, "w": 12, "h": 5.2},
			{"t": "containers", "x": 1500, "d": 360, "w": 14, "h": 7.8},
			{"t": "crane", "x": 1100, "d": 420, "w": 12, "h": 35},
			{"t": "hut", "x": 800, "d": 520, "w": 7, "h": 3.5},
			{"t": "crane", "x": 1900, "d": 560, "w": 12, "h": 35},
			{"t": "ship", "x": 1450, "d": 680, "w": 80, "h": 14},
			{"t": "lighthouse", "x": 420, "d": 1300, "w": 5, "h": 30},
		],
		"road": [[-80, 300], [2480, 300]],
		"sea": 600,
		"posts": [[1200, 242, 0.0, 0.45], [600, 246, 0.0, 0.0], [500, 250, 5.2, 0.0], [1500, 360, 7.8, 0.0],
			[1400, 356, 0.0, 0.0], [850, 516, 0.0, 0.0], [1100, 420, 0.0, 0.0], [1450, 680, 8.0, 0.3],
			[1600, 680, 8.0, 0.3], [1960, 562, 0.0, 0.0]],
		"paths": [[300, 950, 285], [1250, 2000, 285], [600, 1300, 480], [1300, 1900, 580], [1300, 1620, 680, 8.0]],
		"drums": [[650, 254], [1640, 364], [960, 524]],
		"dish": [1900, 560, 33.0],
		"wind": 1.2,
	},
	"canyon": {
		"structures": [
			{"t": "station", "x": 1300, "d": 262, "w": 12, "h": 4.5},
			{"t": "sandbags", "x": 1500, "d": 300, "w": 6, "h": 1.1},
			{"t": "watertower", "x": 560, "d": 300, "w": 5, "h": 12},
			{"t": "railcar", "x": 900, "d": 430, "w": 14, "h": 4},
			{"t": "railcar", "x": 1650, "d": 440, "w": 14, "h": 4},
			{"t": "tent", "x": 350, "d": 520, "w": 8, "h": 3},
			{"t": "tower", "x": 2050, "d": 560, "w": 5, "h": 14},
			{"t": "trestle", "x": 1200, "d": 650, "w": 170, "h": 22},
			{"t": "mast", "x": 2150, "d": 820, "w": 1, "h": 20},
		],
		"road": [[-80, 380], [2480, 380]],
		"posts": [[1240, 252, 0.0, 0.0], [1500, 302, 0.0, 0.45], [560, 298, 9.0, 0.35], [900, 430, 4.0, 0.0],
			[1650, 440, 4.0, 0.0], [400, 522, 0.0, 0.0], [2050, 560, 14.0, 0.35], [1100, 650, 22.0, 0.3],
			[1320, 650, 22.0, 0.3], [2180, 822, 0.0, 0.0]],
		"paths": [[700, 1200, 340], [1350, 1950, 360], [500, 1000, 500], [1000, 1480, 650, 22.0], [1500, 2000, 560]],
		"drums": [[1560, 300], [960, 436], [1180, 258]],
		"dish": [2150, 820, 16.0],
		"wind": 1.4,
	},
	"jungle": {
		"structures": [
			{"t": "sandbags", "x": 1450, "d": 250, "w": 6, "h": 1.1},
			{"t": "stilt", "x": 600, "d": 280, "w": 8, "h": 7},
			{"t": "ruin", "x": 1000, "d": 380, "w": 14, "h": 1.3},
			{"t": "stilt", "x": 1850, "d": 400, "w": 9, "h": 7},
			{"t": "ruin", "x": 500, "d": 600, "w": 12, "h": 1.2},
			{"t": "tower", "x": 2050, "d": 620, "w": 4, "h": 9},
			{"t": "temple", "x": 1300, "d": 720, "w": 60, "h": 30, "zd": 745},
		],
		"road": [[-80, 200], [800, 260], [1250, 420], [1300, 700]],
		"posts": [[1450, 252, 0.0, 0.45], [600, 280, 7.0, 0.3], [1000, 382, 0.0, 0.5], [1850, 400, 7.0, 0.3],
			[530, 602, 0.0, 0.5], [2050, 620, 9.0, 0.35], [1300, 722, 10.0, 0.0], [1220, 722, 20.0, 0.0],
			[1300, 722, 30.0, 0.0], [1700, 300, 0.0, 0.0]],
		"paths": [[700, 1300, 270], [1100, 1800, 330], [600, 1100, 480], [1500, 2100, 560], [1100, 1500, 740]],
		"drums": [[1500, 254], [1900, 404], [700, 604]],
		"dish": [2050, 620, 12.0],
		"wind": 0.8,
	},
	"city": {
		"structures": [
			{"t": "block", "x": 450, "d": 262, "w": 24, "h": 22},
			{"t": "block", "x": 1850, "d": 302, "w": 22, "h": 18},
			{"t": "billboard", "x": 1850, "d": 302, "w": 12, "h": 5, "base": 18},
			{"t": "block", "x": 1150, "d": 382, "w": 30, "h": 34},
			{"t": "watertank", "x": 1070, "d": 382, "w": 4, "h": 6, "base": 34},
			{"t": "block", "x": 2150, "d": 522, "w": 26, "h": 30},
			{"t": "block", "x": 760, "d": 622, "w": 34, "h": 48},
			{"t": "block", "x": 1600, "d": 702, "w": 40, "h": 60},
			{"t": "mast", "x": 1700, "d": 702, "w": 1, "h": 12, "base": 60},
			{"t": "block", "x": 300, "d": 902, "w": 40, "h": 70},
		],
		"road": [[-80, 240], [2480, 240]],
		"posts": [[440, 260, 22.0, 0.3], [530, 260, 22.0, 0.3], [1150, 380, 34.0, 0.3], [1230, 380, 34.0, 0.3],
			[1800, 300, 18.0, 0.3], [760, 620, 48.0, 0.3], [1560, 700, 60.0, 0.3], [2150, 520, 30.0, 0.3],
			[300, 900, 70.0, 0.3], [1000, 232, 0.0, 0.0]],
		"paths": [[150, 1100, 232], [1300, 2250, 236], [1080, 1250, 380, 34.0], [690, 830, 620, 48.0], [1520, 1680, 700, 60.0]],
		"drums": [[820, 234], [1950, 238], [1190, 380, 34.0]],
		"dish": [1700, 702, 70.0],
		"wind": 1.5,
	},
}

## The 30 contracts, 5 per place, in order. "n" targets between "near" and "far"
## metres, "walk" of them on patrol, "civ" civilians, "trucks" for a convoy,
## "limit" seconds for a timed goal, "alarm" how quickly the alarm rises,
## "wind" the top wind (m/s), "gust" how much it changes.
const CONTRACTS := [
	{"loc": "alpine", "tod": "dawn", "wx": "clear", "goal": "officer", "n": 3, "near": 150, "far": 340, "wind": 1.0, "walk": 0, "seed": 101},
	{"loc": "alpine", "tod": "day", "wx": "clear", "goal": "officer", "n": 4, "near": 200, "far": 450, "wind": 2.0, "walk": 1, "seed": 102},
	{"loc": "alpine", "tod": "dusk", "wx": "snow", "goal": "all", "n": 4, "near": 200, "far": 600, "wind": 2.0, "walk": 1, "seed": 103},
	{"loc": "alpine", "tod": "day", "wx": "clear", "goal": "convoy", "n": 2, "near": 200, "far": 500, "wind": 2.5, "walk": 1, "trucks": 1, "seed": 104},
	{"loc": "alpine", "tod": "night", "wx": "snow", "goal": "officer", "n": 5, "near": 250, "far": 760, "wind": 3.0, "walk": 2, "seed": 105},
	{"loc": "desert", "tod": "day", "wx": "clear", "goal": "officer", "n": 4, "near": 200, "far": 460, "wind": 3.0, "walk": 1, "seed": 201},
	{"loc": "desert", "tod": "dawn", "wx": "dust", "goal": "timed", "n": 4, "near": 220, "far": 520, "wind": 3.5, "walk": 1, "limit": 90, "seed": 202},
	{"loc": "desert", "tod": "day", "wx": "clear", "goal": "officer", "n": 5, "near": 250, "far": 650, "wind": 4.0, "walk": 2, "civ": 2, "seed": 203},
	{"loc": "desert", "tod": "dusk", "wx": "clear", "goal": "convoy", "n": 3, "near": 250, "far": 700, "wind": 4.0, "walk": 1, "trucks": 2, "seed": 204},
	{"loc": "desert", "tod": "night", "wx": "dust", "goal": "all", "n": 6, "near": 300, "far": 860, "wind": 5.0, "walk": 2, "civ": 1, "seed": 205},
	{"loc": "harbour", "tod": "dusk", "wx": "clear", "goal": "officer", "n": 4, "near": 220, "far": 480, "wind": 3.5, "walk": 2, "seed": 301},
	{"loc": "harbour", "tod": "night", "wx": "rain", "goal": "officer", "n": 5, "near": 240, "far": 620, "wind": 4.0, "walk": 2, "civ": 2, "seed": 302},
	{"loc": "harbour", "tod": "day", "wx": "fog", "goal": "timed", "n": 5, "near": 240, "far": 620, "wind": 4.0, "walk": 2, "limit": 100, "seed": 303},
	{"loc": "harbour", "tod": "dawn", "wx": "clear", "goal": "convoy", "n": 3, "near": 280, "far": 620, "wind": 4.5, "walk": 1, "trucks": 2, "seed": 304},
	{"loc": "harbour", "tod": "dusk", "wx": "storm", "goal": "officer", "n": 6, "near": 300, "far": 700, "wind": 6.0, "walk": 3, "civ": 2, "gust": 1.6, "seed": 305},
	{"loc": "canyon", "tod": "day", "wx": "clear", "goal": "officer", "n": 5, "near": 250, "far": 660, "wind": 4.0, "walk": 2, "gust": 1.4, "seed": 401},
	{"loc": "canyon", "tod": "dusk", "wx": "dust", "goal": "timed", "n": 5, "near": 260, "far": 700, "wind": 4.5, "walk": 2, "limit": 95, "gust": 1.4, "seed": 402},
	{"loc": "canyon", "tod": "dawn", "wx": "clear", "goal": "convoy", "n": 3, "near": 300, "far": 760, "wind": 5.0, "walk": 1, "trucks": 2, "seed": 403},
	{"loc": "canyon", "tod": "day", "wx": "clear", "goal": "officer", "n": 6, "near": 300, "far": 830, "wind": 6.0, "walk": 2, "civ": 3, "gust": 1.7, "seed": 404},
	{"loc": "canyon", "tod": "night", "wx": "clear", "goal": "all", "n": 6, "near": 340, "far": 830, "wind": 5.0, "walk": 3, "alarm": 1.2, "seed": 405},
	{"loc": "jungle", "tod": "night", "wx": "rain", "goal": "officer", "n": 5, "near": 240, "far": 620, "wind": 2.5, "walk": 2, "seed": 501},
	{"loc": "jungle", "tod": "dawn", "wx": "fog", "goal": "all", "n": 6, "near": 260, "far": 760, "wind": 3.0, "walk": 2, "seed": 502},
	{"loc": "jungle", "tod": "dusk", "wx": "rain", "goal": "convoy", "n": 4, "near": 260, "far": 760, "wind": 3.5, "walk": 2, "trucks": 2, "seed": 503},
	{"loc": "jungle", "tod": "night", "wx": "storm", "goal": "timed", "n": 6, "near": 260, "far": 760, "wind": 4.0, "walk": 3, "civ": 2, "limit": 110, "gust": 1.5, "seed": 504},
	{"loc": "jungle", "tod": "day", "wx": "fog", "goal": "all", "n": 7, "near": 260, "far": 960, "wind": 4.5, "walk": 3, "alarm": 1.25, "seed": 505},
	{"loc": "city", "tod": "night", "wx": "clear", "goal": "officer", "n": 5, "near": 230, "far": 650, "wind": 4.0, "walk": 2, "civ": 1, "seed": 601},
	{"loc": "city", "tod": "night", "wx": "rain", "goal": "timed", "n": 6, "near": 230, "far": 700, "wind": 4.5, "walk": 3, "civ": 2, "limit": 100, "seed": 602},
	{"loc": "city", "tod": "dusk", "wx": "clear", "goal": "convoy", "n": 4, "near": 230, "far": 760, "wind": 5.0, "walk": 2, "trucks": 2, "civ": 2, "seed": 603},
	{"loc": "city", "tod": "night", "wx": "fog", "goal": "officer", "n": 7, "near": 230, "far": 910, "wind": 6.0, "walk": 3, "civ": 3, "gust": 1.6, "alarm": 1.25, "seed": 604},
	{"loc": "city", "tod": "night", "wx": "storm", "goal": "all", "n": 8, "near": 230, "far": 910, "wind": 7.0, "walk": 3, "civ": 3, "limit": 150, "gust": 1.8, "alarm": 1.3, "seed": 605},
]

var loc := "alpine"
var mode := "contract"      # contract, survival, daily
var level := 1              # difficulty 0..2
var contract := 0
var seed_used := 0
var tod := "day"            # dawn, day, dusk, night
var wx := "clear"           # clear, fog, snow, rain, dust, storm
var goal := "officer"       # officer, all, timed, convoy
var limit := 0.0            # timed goal: seconds allowed (0 = none)
var alarm_k := 1.0
var gust := 1.0
var rng := RandomNumberGenerator.new()
var targets: Array = []     # see _target()
var props: Array = []       # drums, the dish and trucks: {id, kind, x, d, h, alive, ...}
var pending: Array = []     # shots still in the air: {t, kind, id, head, d, points}
var wind := 0.0             # m/s, + blows to the right
var wind_base := 0.0
var wind_t := 0.0
var t := 0.0                # seconds of play
var heart := REST_HEART
var breath_t := 0.0
var holding := false
var hold_t := 0.0
var gasp_t := 0.0
var ammo := 0               # rounds left in all (survival: -1 = endless)
var mag := MAG
var bolt_t := 0.0
var reload_t := 0.0
var alarm := 0.0            # 0..100; at 100 the primary target runs for it
var dish_quiet_t := 0.0     # the dish was shot: the alarm stays down a while
var shots := 0
var hits := 0
var heads := 0
var kills := 0
var stopped := 0            # trucks stopped
var score := 0
var longest := 0.0
var escapes := 0
var spawn_t := 0.0
var wave := 0
var over := false
var won := false
var reason := ""            # why it ended: "done", "escaped", "ammo", "escapes", "time", "civilian", "convoy"
var events: Array = []      # for the game layer: {"e": "down"/"boom"/"flee"/"escape"/"cover"/"dish"/"civilian"/"truck"...}
var _next_id := 1
var _road: Array = []
# The rifle (set_kit): the Armory's upgrades; reset() keeps them.
var sway_mult := 1.0
var bolt_s := BOLT_S
var reload_s := RELOAD_S
var shot_alarm_k := 1.0

## Applies the Armory's upgrade levels ({"scope": 0..3, "bipod": ..., "bolt": ..., "supp": ...}).
func set_kit(kit: Dictionary) -> void:
	sway_mult = float(UPGRADES.bipod.sway[clampi(int(kit.get("bipod", 0)), 0, 3)])
	bolt_s = float(UPGRADES.bolt.bolt[clampi(int(kit.get("bolt", 0)), 0, 3)])
	reload_s = float(UPGRADES.bolt.reload[clampi(int(kit.get("bolt", 0)), 0, 3)])
	shot_alarm_k = float(UPGRADES.supp.alarm[clampi(int(kit.get("supp", 0)), 0, 3)])       # the road as [Vector2(x, d), metres from its start]

# ---------- geometry ----------

static func ground_y(d: float) -> float:
	return HORIZON + CAM_H * F / maxf(d, 1.0)

static func upm(d: float) -> float:
	return F / maxf(d, 1.0)

## The range of the ground seen at world height y (0 above the horizon).
static func depth_at_y(y: float) -> float:
	if y <= HORIZON + 1.0:
		return 0.0
	return CAM_H * F / (y - HORIZON)

## Contract i (0-based) as a full definition with every field filled in.
static func contract_def(i: int) -> Dictionary:
	var c: Dictionary = CONTRACTS[clampi(i, 0, CONTRACTS.size() - 1)].duplicate()
	for k in ["civ", "trucks", "limit"]:
		if not c.has(k):
			c[k] = 0
	if not c.has("gust"):
		c["gust"] = 1.0
	if not c.has("alarm"):
		c["alarm"] = 1.0
	return c

## Which place (0..5) contract i is in.
static func chapter_of(i: int) -> int:
	return i / PER_PLACE

# ---------- ballistics ----------

## Time of flight: the bullet slows down with range.
static func tof(d: float) -> float:
	return d / V0 * (1.0 + d / 3000.0)

static func drop_m(d: float) -> float:
	var tt := tof(d)
	return 0.5 * GRAV * tt * tt

## How far below the aim the bullet lands, in mils, with the sight set for `zero` metres.
static func drop_mils(d: float, zero: float = ZERO_M) -> float:
	if d <= 1.0:
		return 0.0
	return (drop_m(d) - drop_m(zero) * d / zero) / d * 1000.0

## Sideways drift in mils (the lag rule: wind x (flight time - vacuum time)).
static func wind_mils(d: float, w: float) -> float:
	if d <= 1.0:
		return 0.0
	return w * (tof(d) - d / V0) / d * 1000.0

## Where the bullet lands relative to the aim, in mils (+x right, +y down), for a
## target at range d. `lased` is the range the scope is dialled to (Normal
## dials it for you), 0 = not dialled.
func impact_mils(d: float, lased: float) -> Vector2:
	match level:
		0:
			return Vector2.ZERO
		1:
			var dial := lased if lased > 1.0 else ZERO_M
			return Vector2(wind_mils(d, wind), drop_mils(d) - drop_mils(dial))
		_:
			return Vector2(wind_mils(d, wind), drop_mils(d))

# ---------- setup ----------

## mode "contract" plays CONTRACTS[p_contract]; "daily" picks one by the seed;
## "survival" uses `p_loc` (or one by the seed) with a random time and weather.
func reset(p_mode: String, p_level: int, p_contract: int = 0, p_seed: int = 0, p_loc: String = "") -> void:
	mode = p_mode
	level = clampi(p_level, 0, 2)
	contract = p_contract
	targets.clear()
	props.clear()
	pending.clear()
	events.clear()
	_next_id = 1
	t = 0.0
	heart = REST_HEART
	breath_t = 0.0
	holding = false
	hold_t = 0.0
	gasp_t = 0.0
	mag = MAG
	bolt_t = 0.0
	reload_t = 0.0
	alarm = 0.0
	dish_quiet_t = 0.0
	shots = 0
	hits = 0
	heads = 0
	kills = 0
	stopped = 0
	score = 0
	longest = 0.0
	escapes = 0
	wave = 0
	spawn_t = 2.0
	over = false
	won = false
	reason = ""
	var c: Dictionary
	match mode:
		"survival":
			seed_used = p_seed if p_seed != 0 else 7001
			rng.seed = seed_used
			loc = p_loc if LAYOUT.has(p_loc) else LOCATIONS[rng.randi() % LOCATIONS.size()]
			c = {"loc": loc, "tod": TIMES[rng.randi() % TIMES.size()], "wx": "clear", "goal": "survival", "n": 0,
				"near": 150, "far": 760, "wind": 3.0, "walk": 0, "civ": 0, "trucks": 0, "limit": 0, "gust": 1.2, "alarm": 1.0}
			var wxs: Dictionary = {"alpine": "snow", "desert": "dust", "harbour": "rain", "canyon": "dust", "jungle": "rain", "city": "rain"}
			if rng.randf() < 0.4:
				c.wx = wxs[loc]
		"daily":
			seed_used = p_seed if p_seed != 0 else 1
			rng.seed = seed_used
			contract = rng.randi_range(5, CONTRACTS.size() - 1)
			c = contract_def(contract)
		_:
			contract = clampi(p_contract, 0, CONTRACTS.size() - 1)
			c = contract_def(contract)
			seed_used = int(c.seed) * 10 + level
			rng.seed = seed_used
	loc = c.loc
	tod = c.tod
	wx = c.wx
	goal = c.goal
	limit = float(c.limit) * ([1.4, 1.0, 0.85][level] if c.limit > 0 else 0.0)
	alarm_k = float(c.alarm)
	gust = float(c.gust)
	var lay: Dictionary = LAYOUT[loc]
	_build_road(lay.road)
	wind_base = rng.randf_range(0.4, 1.0) * float(c.wind) * float(lay.get("wind", 1.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
	if wx == "storm":
		wind_base *= 1.25
	wind = wind_base
	wind_t = rng.randf() * 10.0
	for dr in lay.drums:
		props.append({"id": _new_id(), "kind": "drum", "x": float(dr[0]), "d": float(dr[1]), "h": float(dr[2]) if dr.size() > 2 else 0.0, "alive": true})
	var dish: Array = lay.dish
	props.append({"id": _new_id(), "kind": "dish", "x": float(dish[0]), "d": float(dish[1]), "h": float(dish[2]), "alive": true})
	if mode == "survival":
		ammo = -1
		return
	_place_targets(int(c.n), float(c.near), float(c.far), int(c.walk), int(c.civ), goal != "convoy")
	for i in int(c.trucks):
		_add_truck(i)
	var spare: int = [6, 4, 3][level] + (1 if int(c.trucks) > 0 else 0)
	ammo = count_targets() + int(c.trucks) + spare

func _new_id() -> int:
	_next_id += 1
	return _next_id - 1

func _target(kind: String, x: float, d: float, h: float, cover: float) -> Dictionary:
	return {"id": _new_id(), "kind": kind, "x": x, "d": d, "h": h, "cover": cover,
		"state": "idle", "st": rng.randf_range(1.5, 4.0), "face": 1 if rng.randf() < 0.5 else -1,
		"x1": x, "x2": x, "speed": 0.0, "primary": false, "home_x": x, "down_t": 0.0, "head": false,
		"exit": -80.0 if x < W / 2.0 else W + 80.0, "walk": 0.0, "civ": kind == "civilian",
		"act": rng.randi() % 3}

func _place_targets(n: int, dmin: float, dmax: float, patrols: int, civ: int, officer: bool) -> void:
	var lay: Dictionary = LAYOUT[loc]
	var posts: Array = []
	for p in lay.posts:
		if float(p[1]) >= dmin and float(p[1]) <= dmax:
			posts.append(p)
	var paths: Array = []
	for p in lay.paths:
		if float(p[2]) >= dmin and float(p[2]) <= dmax:
			paths.append(p)
	_shuffle(posts)
	_shuffle(paths)
	var walkers := mini(patrols, paths.size())
	var standers := mini(n - walkers, posts.size())
	for i in standers:
		var p: Array = posts[i]
		targets.append(_target("guard", float(p[0]) + rng.randf_range(-6.0, 6.0) * upm(float(p[1])) * 0.1, float(p[1]), float(p[2]), float(p[3])))
	for i in walkers:
		targets.append(_walker("guard", paths[i]))
	# Civilians walk the remaining paths (or the used ones, offset), in hi-vis vests.
	for i in civ:
		var p: Array = paths[(walkers + i) % paths.size()] if not paths.is_empty() else lay.paths[i % lay.paths.size()]
		targets.append(_walker("civilian", p))
	if targets.is_empty() or not officer:
		return
	# The primary: the farthest standing target in a contract (an officer, red armband).
	var best := -1
	for i in targets.size():
		if targets[i].civ:
			continue
		if best < 0 or (targets[i].state != "walk" and (targets[best].state == "walk" or float(targets[i].d) > float(targets[best].d))):
			best = i
	if best >= 0:
		targets[best].primary = true
		targets[best].kind = "officer"

func _walker(kind: String, p: Array) -> Dictionary:
	var tg := _target(kind, rng.randf_range(float(p[0]), float(p[1])), float(p[2]), float(p[3]) if p.size() > 3 else 0.0, 0.3 if p.size() > 3 else 0.0)
	tg.x1 = float(p[0])
	tg.x2 = float(p[1])
	tg.state = "walk"
	tg.speed = rng.randf_range(1.0, 1.5) * (0.6 if level == 0 else 1.0) * (0.8 if kind == "civilian" else 1.0)
	return tg

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp

# ---------- trucks ----------

func _build_road(pts: Array) -> void:
	_road = []
	var total := 0.0
	for i in pts.size():
		var p := Vector2(float(pts[i][0]), float(pts[i][1]))
		if i > 0:
			var a: Vector2 = _road[i - 1][0]
			var dm := (p.y + a.y) * 0.5
			var dx := (p.x - a.x) / upm(dm)
			total += sqrt(dx * dx + pow(p.y - a.y, 2.0))
		_road.append([p, total])

func road_length() -> float:
	return float(_road[_road.size() - 1][1]) if not _road.is_empty() else 0.0

## [x, d, face] on the road `s` metres from its start.
func road_at(s: float) -> Array:
	if _road.size() < 2:
		return [W * 0.5, 300.0, 1]
	s = clampf(s, 0.0, road_length())
	for i in range(1, _road.size()):
		var b: Array = _road[i]
		if s <= float(b[1]) or i == _road.size() - 1:
			var a: Array = _road[i - 1]
			var seg := maxf(0.001, float(b[1]) - float(a[1]))
			var f := clampf((s - float(a[1])) / seg, 0.0, 1.0)
			var p: Vector2 = (a[0] as Vector2).lerp(b[0], f)
			return [p.x, p.y, 1 if (b[0] as Vector2).x >= (a[0] as Vector2).x else -1]
	return [W * 0.5, 300.0, 1]

func _add_truck(i: int) -> void:
	var rev := i % 2 == 1
	var tr := {"id": _new_id(), "kind": "truck", "x": 0.0, "d": 300.0, "h": 0.0, "alive": true,
		"state": "wait", "st": 5.0 + i * 11.0, "s": road_length() if rev else 0.0, "dir": -1 if rev else 1,
		"speed": [5.5, 8.0, 9.5][level], "face": 1}
	_place_truck(tr)
	props.append(tr)

func _place_truck(tr: Dictionary) -> void:
	var r := road_at(float(tr.s))
	tr.x = float(r[0])
	tr.d = float(r[1])
	tr.face = int(r[2]) * int(tr.dir)

## Where a truck will be `ahead` seconds from now (it keeps driving).
func truck_pos(tr: Dictionary, ahead: float = 0.0) -> Vector2:
	if ahead > 0.0 and tr.state == "drive":
		var r := road_at(float(tr.s) + float(tr.dir) * float(tr.speed) * ahead)
		return Vector2(float(r[0]), ground_y(float(r[1])))
	return Vector2(float(tr.x), ground_y(float(tr.d)))

func trucks_total() -> int:
	var n := 0
	for pr in props:
		if pr.kind == "truck":
			n += 1
	return n

func trucks_left() -> int:
	var n := 0
	for pr in props:
		if pr.kind == "truck" and pr.state in ["wait", "drive"]:
			n += 1
	return n

func _step_trucks(dt: float) -> void:
	for tr in props:
		if tr.kind != "truck":
			continue
		match tr.state:
			"wait":
				tr.st -= dt
				if tr.st <= 0.0:
					tr.state = "drive"
					events.append({"e": "truck", "id": tr.id})
			"drive":
				tr.s += float(tr.dir) * float(tr.speed) * dt
				_place_truck(tr)
				if (tr.dir > 0 and tr.s >= road_length()) or (tr.dir < 0 and tr.s <= 0.0):
					tr.state = "gone"
					tr.alive = false
					escapes += 1
					events.append({"e": "truck_escape", "id": tr.id})

# ---------- the body: breath, heart, sway ----------

func hold_breath(on: bool) -> void:
	if on and gasp_t > 0.0:
		return  # still catching breath
	if on and not holding:
		hold_t = 0.0
	holding = on

## Where the aim has drifted to, in mils (+x right, +y down).
func sway_mils() -> Vector2:
	var k: float = SWAY_K[level] * sway_mult
	var p := breath_t / BREATH
	var b := Vector2.ZERO
	if p < BREATH_MOVE:
		var q := p / BREATH_MOVE
		b = Vector2(0.9 * sin(TAU * q), -3.0 * sin(PI * q))  # up on the in-breath, down on the out-breath
	var hold_k := 1.0
	if holding:
		hold_k = maxf(0.0, 1.0 - hold_t / 0.5)
	b *= hold_k * (1.0 + (1.6 if gasp_t > 0.0 else 0.0))
	var amp := _tremor_amp()
	var tr := Vector2(sin(t * 7.3) + 0.6 * sin(t * 12.9 + 1.3) + 0.4 * sin(t * 3.1 + 0.7),
		cos(t * 6.1 + 0.4) + 0.5 * sin(t * 11.7 + 2.1) + 0.4 * cos(t * 2.3)) * amp * 0.5
	var beat := fposmod(t * heart / 60.0, 1.0)
	var jolt := exp(-beat * 14.0) * (0.25 + (heart - REST_HEART) / 100.0)
	return (b + tr + Vector2(0.0, jolt * 0.6)) * k

func _tremor_amp() -> float:
	var amp := 0.22 + maxf(0.0, heart - REST_HEART) / 120.0 * 0.6
	if gasp_t > 0.0:
		amp *= 2.2
	if holding:
		amp *= 0.45 if hold_t < HOLD_GOOD else 0.45 + (hold_t - HOLD_GOOD) * 0.9
	return amp

## 0 (all over the place) .. 1 (rock steady): how much the aim is moving now.
func steady() -> float:
	var p := breath_t / BREATH
	var b := 0.0
	if p < BREATH_MOVE and not (holding and hold_t > 0.5):
		b = 3.0 * sin(PI * p / BREATH_MOVE) + 0.6
	if gasp_t > 0.0:
		b += 2.0
	return clampf(1.0 - (b + _tremor_amp() * 1.5) / 3.0, 0.0, 1.0)

## 0..1 through the breath (the pause is BREATH_MOVE..1); held breath: hold_t / HOLD_MAX.
func breath_phase() -> float:
	return breath_t / BREATH

func _step_body(dt: float) -> void:
	heart = move_toward(heart, REST_HEART, 4.0 * dt)
	if holding:
		hold_t += dt
		if hold_t >= HOLD_MAX:
			holding = false
			gasp_t = GASP_S
			heart += 8.0
	else:
		var rate := 1.0 + maxf(0.0, heart - REST_HEART) / 80.0 + (0.9 if gasp_t > 0.0 else 0.0)
		breath_t = fposmod(breath_t + dt * rate, BREATH)
		hold_t = maxf(0.0, hold_t - dt)
	gasp_t = maxf(0.0, gasp_t - dt)

# ---------- play ----------

func can_fire() -> bool:
	return not over and bolt_t <= 0.0 and reload_t <= 0.0 and ammo != 0 and mag > 0

## The world position of a target's feet now (or `ahead` seconds from now, if it keeps going).
func target_pos(tg: Dictionary, ahead: float = 0.0) -> Vector2:
	var x: float = tg.x
	if ahead > 0.0 and tg.state in ["walk", "flee"]:
		var v := float(tg.face) * float(tg.speed) * upm(tg.d)
		x += v * ahead
		if tg.state == "walk":
			x = clampf(x, tg.x1, tg.x2)
	return Vector2(x, ground_y(tg.d) - float(tg.h) * upm(tg.d))

## How much of a target shows above its cover: 1 standing, ~0.3 ducked.
func exposed(tg: Dictionary) -> float:
	if tg.state == "cover":
		return 0.0 if tg.cover > 0.0 else 0.62
	return 1.0

## The truck's two weak spots, in world units: [fuel tank rect, cab window centre, window radius].
func truck_spots(tr: Dictionary, foot: Vector2) -> Array:
	var u := upm(tr.d)
	var face := float(tr.face)
	var tank := Rect2(foot.x - 0.75 * u - face * 0.4 * u, foot.y - 1.25 * u, 1.5 * u, 0.8 * u)
	var cab := foot + Vector2(face * TRUCK_L * 0.36 * u, -2.0 * u)
	return [tank, cab, 0.38 * u]

## Fires at `aim` (world units, where the reticle is). `lased`: the range the
## scope is dialled to. Returns what happened (empty when the rifle can't fire).
func fire(aim: Vector2, lased: float = 0.0) -> Dictionary:
	if not can_fire():
		return {}
	shots += 1
	if ammo > 0:
		ammo -= 1
	mag -= 1
	bolt_t = bolt_s
	if mag <= 0 and ammo != 0:
		reload_t = reload_s
	var calm := steady()
	heart += 9.0 + (1.0 - calm) * 4.0
	_raise_alarm([5.0, 9.0, 12.0][level] * shot_alarm_k)
	# The nearest thing on the bullet's line wins.
	var best := {}
	var best_d := INF
	for tg in targets:
		if not _live(tg) or float(tg.d) >= best_d:
			continue
		var d: float = tg.d
		var u := upm(d)
		var ip := aim + impact_mils(d, lased) * MIL
		var foot := target_pos(tg, tof(d))
		var ex := exposed(tg)
		if ex <= 0.0:
			continue
		var top := BODY_H if ex >= 1.0 else BODY_H * 0.62
		var head_c := foot + Vector2(0.0, -(top - HEAD_R) * u)
		var head_hit := ip.distance_to(head_c) <= HEAD_R * 1.25 * u
		var low := maxf(float(tg.cover), 1.0 - ex) * BODY_H
		var body := Rect2(foot.x - BODY_W * 0.5 * u, foot.y - (top - HEAD_R * 2.0) * u, BODY_W * u, (top - HEAD_R * 2.0 - low) * u)
		if head_hit or (body.size.y > 0.0 and body.has_point(ip)):
			best = {"kind": "civilian" if tg.civ else "target", "id": tg.id, "head": head_hit, "d": d, "impact": ip}
			best_d = d
	for pr in props:
		if not pr.alive or float(pr.d) >= best_d:
			continue
		var d: float = pr.d
		var u := upm(d)
		var ip := aim + impact_mils(d, lased) * MIL
		var hit := ""
		if pr.kind == "drum":
			var base := Vector2(pr.x, ground_y(d) - float(pr.h) * u)
			if Rect2(base.x - 0.32 * u, base.y - 0.9 * u, 0.64 * u, 0.9 * u).has_point(ip):
				hit = "drum"
		elif pr.kind == "dish":
			var base := Vector2(pr.x, ground_y(d) - float(pr.h) * u)
			if ip.distance_to(base + Vector2(0.0, -0.6 * u)) <= 0.75 * u:
				hit = "dish"
		elif pr.kind == "truck" and pr.state == "drive" and not pr.get("doomed", false):
			var foot := truck_pos(pr, tof(d))
			var spots := truck_spots(pr, foot)
			if (spots[0] as Rect2).has_point(ip):
				hit = "tank"
			elif ip.distance_to(spots[1]) <= float(spots[2]):
				hit = "cab"
		if hit != "":
			best = {"kind": hit, "id": pr.id, "head": false, "d": d, "impact": ip}
			best_d = d
	# Solid cover in front of the hit stops the bullet (learned from The Hunt): a wall,
	# a tank, a container stack... A thing standing on it is nearer, so it isn't blocked.
	var wall := _cover_hit(aim, lased, best_d)
	if not wall.is_empty():
		var res2 := {"kind": "miss", "blocked": true, "id": 0, "head": false, "d": float(wall.d), "impact": wall.impact, "tof": tof(float(wall.d)), "points": 0}
		_scare(float(wall.impact.x), float(wall.d), 6.0, 40.0)
		return res2
	if best.is_empty():
		var gd := depth_at_y(aim.y)
		var res := {"kind": "miss", "id": 0, "head": false, "d": gd, "impact": aim + impact_mils(gd, lased) * MIL if gd > 0.0 else aim, "tof": tof(gd if gd > 0.0 else 800.0), "points": 0}
		if gd > 0.0:
			_scare(res.impact.x, gd, 6.0, 40.0)
		return res
	best["tof"] = tof(best.d)
	best["points"] = 0
	best["calm"] = calm
	match str(best.kind):
		"target", "civilian":
			var tg := _find(best.id)
			tg.doomed = true
			if best.kind == "target":
				hits += 1
				var pts := 100 + int(float(best.d) / 5.0)
				if best.head:
					pts += 50
				if calm >= 0.8:
					pts += 30
				if tg.primary:
					pts *= 2
				best.points = pts
		"drum":
			hits += 1
			best.points = 40
		"tank", "cab":
			hits += 1
			best.points = 200 + int(float(best.d) / 4.0) + (60 if best.kind == "cab" else 0)
			_find(best.id).doomed = true  # keeps driving until the bullet gets there
		_:
			hits += 1
			best.points = 60
	pending.append({"t": best.tof, "kind": best.kind, "id": best.id, "head": best.head, "d": best.d, "points": best.points, "x": best.impact.x})
	return best

## Kinds of structure a bullet can't pass through (masts, cranes and the trestle's
## open timbers let it by).
const SOLID := ["cabin", "hut", "station", "block", "tank", "containers", "railcar", "ship", "temple", "truck", "jeep", "watertower", "sandbags", "ruin", "tent", "lighthouse", "stilt"]

## The nearest solid structure the shot meets before range `max_d`: {"d", "impact"} or {}.
func _cover_hit(aim: Vector2, lased: float, max_d: float) -> Dictionary:
	var best := {}
	for st in LAYOUT[loc].structures:
		if not str(st.t) in SOLID:
			continue
		var d := float(st.d)
		if float(st.get("zd", d)) >= max_d - 1.0 or (not best.is_empty() and d >= float(best.d)):
			continue
		var u := upm(d)
		var ip := aim + impact_mils(d, lased) * MIL
		var foot_y := ground_y(d) - float(st.get("base", 0.0)) * u
		var w := float(st.get("w", 4.0)) * u
		var h := float(st.get("h", 4.0)) * u
		if st.t == "ship":
			h = 8.0 * u  # the hull; the deck above is open
		if st.t == "stilt":
			foot_y -= h * 0.55  # the hut on its stilts, not the gap below
			h *= 0.55
		if Rect2(float(st.x) - w * 0.5, foot_y - h, w, h).has_point(ip):
			best = {"d": d, "impact": ip}
	return best

func _raise_alarm(by: float) -> void:
	if dish_quiet_t <= 0.0:
		alarm = minf(100.0, alarm + by * alarm_k)

func _find(id: int) -> Dictionary:
	for tg in targets:
		if int(tg.id) == id:
			return tg
	for pr in props:
		if int(pr.id) == id:
			return pr
	return {}

## A bullet cracked past or a body fell near (x, d): the ones close by duck.
func _scare(x: float, d: float, metres: float, depth: float) -> void:
	for tg in targets:
		if not _live(tg) or tg.state == "flee":
			continue
		if absf(float(tg.d) - d) <= depth and absf(float(tg.x) - x) <= metres * upm(d) * 4.0:
			tg.state = "cover"
			tg.st = rng.randf_range(2.5, 4.5)
			events.append({"e": "cover", "id": tg.id})
	_raise_alarm([6.0, 12.0, 16.0][level])

func step(dt: float) -> void:
	if over:
		return
	t += dt
	_step_body(dt)
	bolt_t = maxf(0.0, bolt_t - dt)
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0:
			reload_t = 0.0
			mag = MAG if ammo < 0 else mini(MAG, ammo)
	dish_quiet_t = maxf(0.0, dish_quiet_t - dt)
	alarm = maxf(0.0, alarm - (2.0 if level < 2 else 1.2) * dt)
	wind_t += dt
	wind = wind_base * (1.0 + gust * (0.25 * sin(wind_t * 0.31) + 0.12 * sin(wind_t * 0.83 + 1.7) + (0.15 * sin(wind_t * 2.3) if gust > 1.3 else 0.0)))
	_land_bullets(dt)
	_step_targets(dt)
	_step_trucks(dt)
	if mode == "survival":
		_step_survival(dt)
	_check_end()

## Seconds left on a timed contract (0 when there is no clock).
func time_left() -> float:
	return maxf(0.0, limit - t) if limit > 0.0 else 0.0

func _land_bullets(dt: float) -> void:
	var landed: Array = []
	for p in pending:
		p.t -= dt
		if p.t <= 0.0:
			landed.append(p)
	for p in landed:
		pending.erase(p)
		var o := _find(p.id)
		if o.is_empty():
			continue
		match p.kind:
			"target":
				_down(o, bool(p.head), int(p.points), float(p.d))
			"civilian":
				_down(o, bool(p.head), 0, float(p.d))
				events.append({"e": "civilian", "id": o.id})
				if not over:
					_end(false, "civilian")
			"drum":
				if not o.alive:
					continue
				o.alive = false
				score += int(p.points)
				_blast(o)
			"tank":
				if o.state != "drive":
					continue
				o.alive = false
				o.state = "burning"
				stopped += 1
				score += int(p.points)
				_blast(o)
				_after_truck()
			"cab":
				if o.state != "drive":
					continue
				o.alive = false
				o.state = "stopped"
				stopped += 1
				score += int(p.points)
				events.append({"e": "cab", "id": o.id, "x": o.x, "d": o.d, "points": p.points})
				_scare(o.x, o.d, 10.0, 40.0)
				_after_truck()
			"dish":
				if not o.alive:
					continue
				o.alive = false
				score += int(p.points)
				alarm = maxf(0.0, alarm - 40.0)
				dish_quiet_t = 20.0
				events.append({"e": "dish", "id": o.id})

## A drum or a truck's fuel tank goes up: anyone within 6 m goes down with it.
func _blast(o: Dictionary) -> void:
	events.append({"e": "boom", "id": o.id, "x": o.x, "d": o.d, "h": float(o.get("h", 0.0))})
	for tg in targets:
		if not _live(tg):
			continue
		if absf(float(tg.d) - float(o.d)) <= 12.0 and absf(float(tg.x) - float(o.x)) <= 6.0 * upm(o.d) and absf(float(tg.h) - float(o.get("h", 0.0))) < 3.0:
			if tg.civ:
				_down(tg, false, 0, float(tg.d))
				events.append({"e": "civilian", "id": tg.id})
				if not over:
					_end(false, "civilian")
			else:
				_down(tg, false, 100 + int(float(tg.d) / 5.0) + 50, float(tg.d))
	_scare(o.x, o.d, 25.0, 80.0)

## The last truck stopped: the guards make a run for it.
func _after_truck() -> void:
	if goal == "convoy" and trucks_left() == 0:
		for o in targets:
			if _live(o) and not o.civ:
				o.panic = rng.randf_range(3.0, 6.0)

## Still in play: not down, not gone, no bullet already on its way to it.
func _live(tg: Dictionary) -> bool:
	return tg.state != "down" and tg.state != "gone" and not tg.get("doomed", false)

func _down(tg: Dictionary, head: bool, points: int, d: float) -> void:
	if tg.state == "down" or tg.state == "gone":
		return
	tg.state = "down"
	tg.doomed = false
	tg.down_t = 0.0
	tg.head = head
	if not tg.civ:
		kills += 1
		score += points
		if head:
			heads += 1
		longest = maxf(longest, d)
	events.append({"e": "down", "id": tg.id, "head": head, "points": points, "x": tg.x, "d": tg.d, "primary": tg.primary, "civ": tg.civ})
	_scare(tg.x, d, 12.0, 60.0)
	if tg.primary and mode != "survival" and goal == "officer":
		# The rest panic and run for it.
		for o in targets:
			if not _live(o) or o.civ:
				continue
			o.panic = rng.randf_range(1.5, 4.0)

func _step_targets(dt: float) -> void:
	for tg in targets:
		if tg.has("panic") and _live(tg) and tg.state != "flee":
			tg.panic -= dt
			if tg.panic <= 0.0:
				_run(tg)
		match tg.state:
			"down":
				tg.down_t += dt
				if tg.down_t > 2.5:
					tg.state = "gone"
			"idle":
				tg.st -= dt
				if tg.st <= 0.0:
					tg.face = -int(tg.face)
					tg.act = rng.randi() % 3
					tg.st = rng.randf_range(2.0, 5.0) * (0.5 if alarm > 50.0 else 1.0)
			"cover":
				tg.st -= dt
				if tg.st <= 0.0:
					tg.state = "walk" if tg.x2 > tg.x1 else "idle"
					tg.st = rng.randf_range(1.0, 3.0)
			"walk":
				var fast := 1.6 if alarm > 50.0 and not tg.civ else 1.0
				var v := float(tg.speed) * fast * upm(tg.d)
				tg.walk += dt * float(tg.speed) * fast
				tg.x += float(tg.face) * v * dt
				if tg.x <= tg.x1:
					tg.x = tg.x1
					tg.face = 1
				elif tg.x >= tg.x2:
					tg.x = tg.x2
					tg.face = -1
			"flee":
				var v := float(tg.speed) * upm(tg.d)
				tg.walk += dt * float(tg.speed)
				tg.x += float(tg.face) * v * dt
				if (tg.face < 0 and tg.x <= tg.exit) or (tg.face > 0 and tg.x >= tg.exit):
					tg.state = "gone"
					if not tg.civ:
						escapes += 1
						events.append({"e": "escape", "id": tg.id, "primary": tg.primary})
	# The alarm at full: the officer makes a run for it.
	if alarm >= 100.0 and mode != "survival":
		for tg in targets:
			if tg.primary and _live(tg) and tg.state != "flee":
				_run(tg)

func _run(tg: Dictionary) -> void:
	tg.state = "flee"
	tg.h = 0.0
	tg.cover = 0.0
	tg.speed = 3.2 if level > 0 else 2.2
	tg.face = -1 if tg.exit < tg.x else 1
	events.append({"e": "flee", "id": tg.id, "primary": tg.primary})

func _step_survival(dt: float) -> void:
	spawn_t -= dt
	if spawn_t > 0.0:
		return
	wave += 1
	var lay: Dictionary = LAYOUT[loc]
	var paths: Array = lay.paths.filter(func(q): return q.size() < 4)  # ground paths only (no decks or roofs)
	var p: Array = paths[rng.randi() % paths.size()]
	var d := float(p[2]) + rng.randf_range(-15.0, 15.0)
	var left := rng.randf() < 0.5
	var civ := wave > 8 and rng.randf() < 0.15
	var tg := _target("civilian" if civ else "guard", -60.0 if left else W + 60.0, d, 0.0, 0.0)
	tg.state = "flee"
	tg.face = 1 if left else -1
	tg.exit = W + 80.0 if left else -80.0
	tg.speed = minf(1.3 + wave * 0.04, 3.4) * (0.7 if level == 0 else 1.0) * (0.7 if civ else 1.0)
	tg.primary = not civ and wave % 7 == 0
	if tg.primary:
		tg.kind = "officer"
	targets.append(tg)
	spawn_t = maxf(1.6, 6.0 - wave * 0.18) * (1.3 if level == 0 else 1.0)
	# Old bodies leave the list so a long run stays light.
	targets = targets.filter(func(o): return o.state != "gone")

func _check_end() -> void:
	if over:
		return
	if mode == "survival":
		if escapes >= 3:
			_end(false, "escapes")
		return
	if limit > 0.0 and t >= limit:
		_end(false, "time")
		return
	var primary_left := false
	var any_left := false
	for tg in targets:
		if tg.civ:
			continue
		if not _live(tg):
			if tg.state == "gone" and not _was_down(tg):
				if tg.primary or goal in ["all", "timed"]:
					_end(false, "escaped")
					return
			continue
		any_left = true
		if tg.primary:
			primary_left = true
	if goal == "convoy":
		for pr in props:
			if pr.kind == "truck" and pr.state == "gone":
				_end(false, "convoy")
				return
	if not any_left and trucks_left() == 0 and pending.is_empty():
		_end(_goal_met(), "done")
	elif ammo == 0 and mag <= 0 and pending.is_empty():
		_end(_goal_met() and not primary_left, "ammo")

func _goal_met() -> bool:
	match goal:
		"officer":
			return _primary_down()
		"convoy":
			return trucks_left() == 0 and stopped == trucks_total()
		_:
			return count_targets() > 0 and kills >= count_targets()

func _was_down(tg: Dictionary) -> bool:
	return float(tg.down_t) > 0.0 or tg.state == "down"

func _primary_down() -> bool:
	for tg in targets:
		if tg.primary:
			return _was_down(tg)
	return false

func _end(p_won: bool, why: String) -> void:
	over = true
	won = p_won
	reason = why
	if won and mode != "survival":
		score += int(accuracy() * 200.0)
		if limit > 0.0:
			score += int(time_left()) * 5

func accuracy() -> float:
	return float(hits) / float(shots) if shots > 0 else 0.0

## Targets that count (civilians don't).
func count_targets() -> int:
	var n := 0
	for tg in targets:
		if not tg.civ:
			n += 1
	return n

func total_targets() -> int:
	return count_targets()

## Contract stars: 1 = the goal, 2 = and 80% of everything, 3 = all of it at 70% accuracy.
func stars() -> int:
	if not won:
		return 0
	var n := count_targets() + trucks_total()
	if n == 0:
		return 0
	var got := kills + stopped
	if got >= n and accuracy() >= 0.7:
		return 3
	if float(got) / float(n) >= 0.8:
		return 2
	return 1

func targets_left() -> int:
	var n := 0
	for tg in targets:
		if _live(tg) and not tg.civ:
			n += 1
	return n

## The live target under the reticle (expanded a little), for the rangefinder; {} if none.
func target_at(aim: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for tg in targets:
		if tg.state in ["gone"] or float(tg.d) >= best_d:
			continue
		var u := upm(tg.d)
		var foot := target_pos(tg)
		if Rect2(foot.x - 1.0 * u, foot.y - 2.5 * u, 2.0 * u, 2.6 * u).has_point(aim):
			best = tg
			best_d = tg.d
	return best

## The rangefinder: the range of whatever is under the reticle -- a target, a
## truck, a drum or dish, a building -- else the ground there (0 = sky).
func range_at(aim: Vector2) -> float:
	var best := INF
	var tg := target_at(aim)
	if not tg.is_empty():
		best = float(tg.d)
	for pr in props:
		var d: float = pr.d
		var u := upm(d)
		if d >= best:
			continue
		if pr.kind == "truck":
			if pr.state in ["wait", "gone"]:
				continue
			var foot := truck_pos(pr)
			if Rect2(foot.x - TRUCK_L * 0.5 * u, foot.y - 3.0 * u, TRUCK_L * u, 3.0 * u).has_point(aim):
				best = d
			continue
		var c := Vector2(pr.x, ground_y(d) - float(pr.h) * u - 0.5 * u)
		if absf(aim.x - c.x) <= 1.0 * u and absf(aim.y - c.y) <= 1.0 * u:
			best = d
	for s in LAYOUT[loc].structures:
		var d := float(s.get("zd", s.d))
		if d >= best:
			continue
		var u := upm(float(s.d))
		var w := float(s.get("w", 4.0)) * u
		if s.t == "crane":
			w *= 4.0  # the boom reaches out
		var top := float(s.h) + float(s.get("base", 0.0))
		var r := Rect2(float(s.x) - w * 0.5, ground_y(float(s.d)) - top * u, w, top * u)
		if r.has_point(aim):
			best = float(s.d)
	if best < INF:
		return best
	return depth_at_y(aim.y)

# ---------- save ----------

func to_dict() -> Dictionary:
	return {"loc": loc, "mode": mode, "level": level, "contract": contract, "seed": seed_used,
		"tod": tod, "wx": wx, "goal": goal, "limit": limit, "alarm_k": alarm_k, "gust": gust,
		"targets": targets.duplicate(true), "props": props.duplicate(true), "wind": wind_base, "wind_t": wind_t, "t": t,
		"ammo": ammo, "mag": mag, "alarm": alarm, "shots": shots, "hits": hits, "heads": heads, "kills": kills,
		"stopped": stopped, "score": score, "longest": longest, "escapes": escapes, "wave": wave, "spawn_t": spawn_t,
		"dish_quiet_t": dish_quiet_t, "pending": pending.duplicate(true), "rng": rng.state, "next_id": _next_id}

func from_dict(d: Dictionary) -> void:
	reset(str(d.get("mode", "contract")), int(d.get("level", 1)), int(d.get("contract", 0)), int(d.get("seed", 0)), str(d.get("loc", "")))
	loc = str(d.get("loc", loc))
	tod = str(d.get("tod", tod))
	wx = str(d.get("wx", wx))
	goal = str(d.get("goal", goal))
	limit = float(d.get("limit", limit))
	alarm_k = float(d.get("alarm_k", alarm_k))
	gust = float(d.get("gust", gust))
	_build_road(LAYOUT[loc].road)
	targets = []
	for tg in d.get("targets", []):
		var o: Dictionary = tg.duplicate(true)
		for k in ["id", "face", "act"]:
			if o.has(k):
				o[k] = int(o[k])
		targets.append(o)
	props = []
	for pr in d.get("props", []):
		var o: Dictionary = pr.duplicate(true)
		o.id = int(o.id)
		for k in ["dir", "face"]:
			if o.has(k):
				o[k] = int(o[k])
		props.append(o)
	wind_base = float(d.get("wind", 0.0))
	wind = wind_base
	wind_t = float(d.get("wind_t", 0.0))
	t = float(d.get("t", 0.0))
	ammo = int(d.get("ammo", 0))
	mag = int(d.get("mag", MAG))
	alarm = float(d.get("alarm", 0.0))
	shots = int(d.get("shots", 0))
	hits = int(d.get("hits", 0))
	heads = int(d.get("heads", 0))
	kills = int(d.get("kills", 0))
	stopped = int(d.get("stopped", 0))
	score = int(d.get("score", 0))
	longest = float(d.get("longest", 0.0))
	escapes = int(d.get("escapes", 0))
	wave = int(d.get("wave", 0))
	spawn_t = float(d.get("spawn_t", 2.0))
	dish_quiet_t = float(d.get("dish_quiet_t", 0.0))
	_next_id = int(d.get("next_id", _next_id))
	pending = []
	for p in d.get("pending", []):  # bullets still in the air when the game was saved
		var o: Dictionary = p.duplicate(true)
		o.id = int(o.id)
		o.points = int(o.points)
		pending.append(o)
	if d.has("rng"):
		rng.state = int(d.rng)
