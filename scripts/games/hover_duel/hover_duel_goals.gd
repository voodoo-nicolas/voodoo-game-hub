extends RefCounted

## Hover Duel objectives: one Daily and one Weekly objective (picked from
## the pools below by the date, the same for everyone), progress kept in
## user://hover_duel_goals.json. Done objectives pay medals; medals unlock
## hull paints. Pure logic, no Nodes: the game feeds it one battle at a time.
##
## A battle's tally (built by the game): {"won", "flawless", "hard", "fast"
## (won in under 60 s), "gun", "missile", "mine" (hits landed with each),
## "crates", "stars" (Campaign stars newly earned), "battles" (1)}.

const PATH := "user://hover_duel_goals.json"
const DAILY_MEDALS := 1
const WEEKLY_MEDALS := 3

## stat: which tally key counts; need: how much.
const DAILY := [
	{"id": "d_win2", "text": "Win 2 battles", "stat": "won", "need": 2},
	{"id": "d_missile3", "text": "Land 3 missile hits", "stat": "missile", "need": 3},
	{"id": "d_mine1", "text": "Catch someone with a mine", "stat": "mine", "need": 1},
	{"id": "d_crates4", "text": "Pick up 4 crates", "stat": "crates", "need": 4},
	{"id": "d_fast", "text": "Win a battle in under a minute", "stat": "fast", "need": 1},
	{"id": "d_gun60", "text": "Land 60 gun hits", "stat": "gun", "need": 60},
	{"id": "d_play3", "text": "Fight 3 battles", "stat": "battles", "need": 3},
	{"id": "d_hard", "text": "Beat the computer on Hard", "stat": "hard", "need": 1},
]
const WEEKLY := [
	{"id": "w_win10", "text": "Win 10 battles", "stat": "won", "need": 10},
	{"id": "w_stars6", "text": "Earn 6 new Campaign stars", "stat": "stars", "need": 6},
	{"id": "w_flawless", "text": "Win 2 battles without a scratch", "stat": "flawless", "need": 2},
	{"id": "w_missile20", "text": "Land 20 missile hits", "stat": "missile", "need": 20},
	{"id": "w_mine6", "text": "Catch rivals with 6 mines", "stat": "mine", "need": 6},
	{"id": "w_hard4", "text": "Beat the computer on Hard 4 times", "stat": "hard", "need": 4},
]

## Hull paints: [name, colour, medals needed].
const PAINTS := [
	["Sky", Color("2f7dff"), 0],
	["Moss", Color("3fae4a"), 2],
	["Sunset", Color("ff9a2a"), 5],
	["Violet", Color("9a5cff"), 9],
	["Gold", Color("e8c13a"), 14],
	["Snow", Color("e8eef4"), 20],
]

var data := {"day": -1, "day_n": 0, "day_done": false, "week": -1, "week_n": 0, "week_done": false, "medals": 0, "paint": 0}

func load_saved(d) -> void:
	if d is Dictionary:
		for k in data:
			if d.has(k):
				data[k] = d[k]
	roll()

func to_dict() -> Dictionary:
	return data.duplicate()

## Days and weeks since 1970 (weeks start on Monday: 1 Jan 1970 was a Thursday).
static func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

static func week_of(day: int) -> int:
	return int(floor((day + 3) / 7.0))

func roll(day: int = -1) -> void:
	if day < 0:
		day = today()
	if int(data.day) != day:
		data.day = day
		data.day_n = 0
		data.day_done = false
	if int(data.week) != week_of(day):
		data.week = week_of(day)
		data.week_n = 0
		data.week_done = false

func daily() -> Dictionary:
	return DAILY[posmod(int(data.day) * 7 + 3, DAILY.size())]

func weekly() -> Dictionary:
	return WEEKLY[posmod(int(data.week) * 5 + 1, WEEKLY.size())]

## Adds one battle's tally. Returns the objectives finished by it: ["daily"], ["weekly"], both or [].
func add_battle(tally: Dictionary, day: int = -1) -> Array:
	roll(day)
	var done: Array = []
	var d := daily()
	if not data.day_done:
		data.day_n = int(data.day_n) + int(tally.get(d.stat, 0))
		if int(data.day_n) >= int(d.need):
			data.day_done = true
			data.medals = int(data.medals) + DAILY_MEDALS
			done.append("daily")
	var w := weekly()
	if not data.week_done:
		data.week_n = int(data.week_n) + int(tally.get(w.stat, 0))
		if int(data.week_n) >= int(w.need):
			data.week_done = true
			data.medals = int(data.medals) + WEEKLY_MEDALS
			done.append("weekly")
	return done

func paint_unlocked(i: int) -> bool:
	return i >= 0 and i < PAINTS.size() and int(data.medals) >= int(PAINTS[i][2])

func paint_color() -> Color:
	var i := int(data.paint)
	return PAINTS[i][1] if paint_unlocked(i) else PAINTS[0][1]
