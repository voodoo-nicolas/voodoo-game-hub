extends RefCounted

## Voyage of Aeneas -- objectives (pure logic, headless-testable).
## Daily objective: one per day from DAILY (same for everyone), met by one voyage.
## Weekly objective: one per week from WEEKLY, counted over every voyage that week.
## Story objective: the Chronicle -- every myth (fact) met on any voyage, kept forever,
## plus the furthest stop ever reached. Rewards are laurels (🌿 stat, achievements).
## State lives in a Dictionary the game saves to user://roman_voyage_goals.json.

const DAILY := [
	{"id": "ships5", "text": "Reach Italy with at least 5 ships"},
	{"id": "underworld", "text": "Visit the Underworld and reach Italy"},
	{"id": "calm_juno", "text": "Reach Italy with Juno's wrath at 2 or less"},
	{"id": "no_prayer", "text": "Reach Italy without praying to any god"},
	{"id": "score1200", "text": "Score 1,200 or more in one voyage"},
	{"id": "favor6", "text": "Reach Italy with 6 or more favor"},
	{"id": "crew80", "text": "Reach Italy with 80 or more men"},
]
const WEEKLY := [
	{"id": "wins3", "text": "Reach Italy 3 times", "need": 3, "count": "win"},
	{"id": "choices60", "text": "Make 60 choices", "need": 60, "count": "choice"},
	{"id": "myths25", "text": "Meet 25 myths", "need": 25, "count": "myth"},
	{"id": "ships20", "text": "Bring 20 ships to Italy in all", "need": 20, "count": "ships_home"},
	{"id": "hard1", "text": "Reach Italy on Hard", "need": 1, "count": "hard_win"},
]
const DAILY_LAURELS := 1
const WEEKLY_LAURELS := 3

## Day number since 1970 (UTC) and week number (weeks start on Monday).
static func day_index(unix: float) -> int:
	return int(floor(unix / 86400.0))

static func week_index(unix: float) -> int:
	return int(floor((day_index(unix) + 3) / 7.0))  # 1970-01-01 was a Thursday

static func daily_for(unix: float) -> Dictionary:
	return DAILY[posmod(day_index(unix) * 5 + 2, DAILY.size())]

static func weekly_for(unix: float) -> Dictionary:
	return WEEKLY[posmod(week_index(unix), WEEKLY.size())]

## Fresh or rolled-over state for the given time.
static func normalize(st: Dictionary, unix: float) -> Dictionary:
	var s := st.duplicate(true)
	var d := day_index(unix)
	var w := week_index(unix)
	if int(s.get("day", -1)) != d:
		s["day"] = d
		s["daily_done"] = false
	if int(s.get("week", -1)) != w:
		s["week"] = w
		s["week_count"] = 0
		s["weekly_done"] = false
	if not s.has("chronicle"):
		s["chronicle"] = []
	if not s.has("furthest"):
		s["furthest"] = 0
	if not s.has("laurels"):
		s["laurels"] = 0
	return s

static func daily_met(id: String, e) -> bool:
	if not e.won:
		return false
	match id:
		"ships5":
			return e.ships >= 5
		"underworld":
			return e.flags.has("underworld")
		"calm_juno":
			return e.wrath <= 2
		"no_prayer":
			return not e.flags.has("prayed")
		"score1200":
			return e.score() >= 1200
		"favor6":
			return e.favor >= 6
		"crew80":
			return e.crew >= 80
	return false

## After every choice: Chronicle, furthest stop, weekly "choice" / "myth" counts.
## Returns the list of things just achieved ("weekly").
static func on_choice(s: Dictionary, e, unix: float, new_myth: String) -> Array:
	var out := []
	s.merge(normalize(s, unix), true)
	s.furthest = maxi(int(s.furthest), e.stop)
	if new_myth != "" and not new_myth in s.chronicle:
		s.chronicle.append(new_myth)
	var wk: Dictionary = weekly_for(unix)
	if wk.count == "choice" or (wk.count == "myth" and new_myth != ""):
		_bump(s, wk, 1, out)
	return out

## When a voyage ends. Returns the list of things just achieved ("daily", "weekly").
static func on_end(s: Dictionary, e, unix: float) -> Array:
	var out := []
	s.merge(normalize(s, unix), true)
	if e.won:
		s.furthest = E_STOPS_LAST()
	var dl: Dictionary = daily_for(unix)
	if not bool(s.daily_done) and daily_met(dl.id, e):
		s.daily_done = true
		s.laurels = int(s.laurels) + DAILY_LAURELS
		out.append("daily")
	var wk: Dictionary = weekly_for(unix)
	match str(wk.count):
		"win":
			if e.won:
				_bump(s, wk, 1, out)
		"ships_home":
			if e.won:
				_bump(s, wk, e.ships, out)
		"hard_win":
			if e.won and e.diff == 2:
				_bump(s, wk, 1, out)
	return out

static func E_STOPS_LAST() -> int:
	return load("res://scripts/games/roman_voyage/roman_voyage_engine.gd").STOPS.size() - 1

static func _bump(s: Dictionary, wk: Dictionary, n: int, out: Array) -> void:
	if bool(s.weekly_done):
		return
	s.week_count = int(s.week_count) + n
	if int(s.week_count) >= int(wk.need):
		s.week_count = int(wk.need)
		s.weekly_done = true
		s.laurels = int(s.laurels) + WEEKLY_LAURELS
		out.append("weekly")

## Every myth the Chronicle can hold: one per story stop and sea event that has a fact.
static func all_myths() -> Array:
	var E = load("res://scripts/games/roman_voyage/roman_voyage_engine.gd")
	var out := []
	for x in E.STOPS + E.SEA:
		if x.has("fact"):
			out.append(x.id)
	return out
