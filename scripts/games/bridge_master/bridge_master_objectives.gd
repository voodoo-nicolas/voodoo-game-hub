extends RefCounted

## Bridge Master objectives (owner 2026-11-14): 3 daily, 3 weekly and the story line.
## Every finished objective pays stars into the Garage wallet (progress.bonus) at once; nothing
## to claim. State lives in progress.obj of user://bridge_master_progress.json:
##   {"day": "2026-11-14", "d": {stat: n}, "dpaid": [ids],
##    "week": "2026-11-09", "w": {stat: n}, "wpaid": [ids], "story": [chapters paid]}
## Stats the game reports with record(): cross (a bridge crossed: campaign or daily), stars (stars
## of that crossing), three (a ★★★ crossing), daily (Daily Bridge crossed), load (Load Test rounds
## held), cheap (crossed for 60%% of the budget or less), new (a level cleared the first time),
## wood (crossed with no steel and no cables).
## The story: one chapter of the campaign at a time; it opens when the chapter's first level
## opens and pays when all 30 of its levels are built (or skipped). Progressive reveal: the
## Objectives screen shows only the chapters reached (STANDARDS: no spoilers).

## [id, stat, target, reward ★, text with %d for the target]
const DAILY := [
	["d_cross", "cross", 3, 4, "Build %d bridges that hold"],
	["d_stars", "stars", 6, 5, "Earn %d stars"],
	["d_three", "three", 1, 5, "Get ★★★ on %d bridge"],
	["d_daily", "daily", 1, 6, "Cross %d Daily Bridge"],
	["d_load", "load", 4, 5, "Hold %d Load Test rounds"],
	["d_cheap", "cheap", 1, 6, "Cross %d bridge for 60%% of its budget or less"],
	["d_new", "new", 2, 5, "Clear %d new levels"],
	["d_wood", "wood", 1, 5, "Cross %d bridge with no steel and no cables"],
]
const WEEKLY := [
	["w_cross", "cross", 20, 20, "Build %d bridges that hold"],
	["w_stars", "stars", 40, 25, "Earn %d stars"],
	["w_three", "three", 8, 25, "Get ★★★ on %d bridges"],
	["w_daily", "daily", 4, 30, "Cross the Daily Bridge on %d days"],
	["w_load", "load", 25, 20, "Hold %d Load Test rounds"],
	["w_new", "new", 12, 25, "Clear %d new levels"],
	["w_cheap", "cheap", 5, 25, "Cross %d bridges for 60%% of their budget or less"],
]
const PER_PERIOD := 3
const STORY_REWARD := 25
## One beat per chapter (E.CHAPTERS order): [when it opens, when it is rebuilt].
const STORY := [
	["The storm took every bridge in the land. The old engineer hands you his toolbox: \"Start at home. Green Valley's farms can't reach the market.\"",
		"Carts roll to market again. The engineer nods: \"Not bad. The river towns are next.\""],
	["River Bend's ferry sank in the flood. The town is cut in two, and the school is on the far bank.",
		"Children walk to school over your bridges. The ferryman buys you lunch."],
	["In Red Rocks the canyon is wide and the miners need heavy trucks to cross. Steel is your friend here.",
		"Ore trucks thunder across. The mine sends a crate of steel bolts as thanks."],
	["The lumber mill in Pine Gorge is stuck: logs pile up and the trucks can't leave the forest.",
		"The mill is back at work, and the whole valley smells of fresh pine."],
	["Dry Canyon's water wagons can't reach the villages. Build light and cheap: every dollar buys water.",
		"Water reaches the villages. They name a well after you."],
	["The Sunset Mesa fair is in a month, and no visitor can get up the mesa. Cables can carry long spans.",
		"The fair opens with fireworks over your longest bridge yet."],
	["At Twin Falls the spray soaks everything. The hospital on the island needs a road for its ambulance.",
		"The ambulance crosses with its lights on. The doctors cheer from the windows."],
	["Eagle Pass is high and windy. The mountain post office has had no mail since the storm.",
		"Bags of letters arrive at last, and some of them are thank-you notes for you."],
	["Deep Ravine is the engineer's old enemy: his first bridge there fell. \"Do better than I did.\"",
		"Your bridge stands where his fell. The old engineer is quiet for a long time, then smiles."],
	["The Great Divide splits the land in two. Join both halves and the land is whole again.",
		"The last bridge holds. Every town is connected. You are the Bridge Master."],
]

static func today() -> String:
	return Time.get_date_string_from_system()

## The Monday that starts this week, as a date string (the week's key).
static func week_key() -> String:
	var now := Time.get_unix_time_from_system()
	var wd := int(Time.get_datetime_dict_from_system().weekday)  # 0 = Sunday
	var back := (wd + 6) % 7
	return Time.get_date_string_from_unix_time(int(now) - back * 86400)

## The objectives on today's / this week's board: PER_PERIOD of the pool, picked from the date.
static func picks(pool: Array, key: String) -> Array:
	var order: Array = []
	for i in pool.size():
		order.append([absi(hash(key + str(pool[i][0]))), i])
	order.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	for k in mini(PER_PERIOD, order.size()):
		out.append(pool[order[k][1]])
	return out

## Makes progress.obj current: a new day / week starts an empty board.
static func roll(progress: Dictionary) -> Dictionary:
	if not progress.get("obj") is Dictionary:
		progress["obj"] = {}
	var o: Dictionary = progress.obj
	if str(o.get("day", "")) != today():
		o["day"] = today()
		o["d"] = {}
		o["dpaid"] = []
	if str(o.get("week", "")) != week_key():
		o["week"] = week_key()
		o["w"] = {}
		o["wpaid"] = []
	if not o.get("story") is Array:
		o["story"] = []
	return o

static func daily_list(progress: Dictionary) -> Array:
	return picks(DAILY, str(roll(progress).day))

static func weekly_list(progress: Dictionary) -> Array:
	return picks(WEEKLY, str(roll(progress).week))

## How far an objective is: [count, target, paid].
static func state(progress: Dictionary, row: Array, weekly: bool) -> Array:
	var o := roll(progress)
	var counts: Dictionary = o.w if weekly else o.d
	var paid: Array = o.wpaid if weekly else o.dpaid
	return [mini(int(counts.get(row[1], 0)), int(row[2])), int(row[2]), row[0] in paid]

## Counts a stat for today and this week; pays what it finished. Returns the finished rows
## [{text, reward}] so the game can cheer.
static func record(progress: Dictionary, stat: String, amount: int = 1) -> Array:
	var o := roll(progress)
	o.d[stat] = int(o.d.get(stat, 0)) + amount
	o.w[stat] = int(o.w.get(stat, 0)) + amount
	return _pay(progress)

static func _pay(progress: Dictionary) -> Array:
	var o := roll(progress)
	var done: Array = []
	for weekly in [false, true]:
		var rows: Array = weekly_list(progress) if weekly else daily_list(progress)
		var paid: Array = o.wpaid if weekly else o.dpaid
		var counts: Dictionary = o.w if weekly else o.d
		for row in rows:
			if row[0] in paid or int(counts.get(row[1], 0)) < int(row[2]):
				continue
			paid.append(row[0])
			progress["bonus"] = int(progress.get("bonus", 0)) + int(row[3])
			done.append({"text": row[4], "target": int(row[2]), "reward": int(row[3])})
	return done

## Story: the chapter the player is on (first not fully built), and how many of its levels are done.
## done_fn(n) -> bool says if level n is built or skipped.
static func chapter_done_count(c: int, per: int, done_fn: Callable) -> int:
	var n := 0
	for i in range(c * per + 1, c * per + per + 1):
		if done_fn.call(i):
			n += 1
	return n

## Pays every finished chapter not paid yet (also chapters finished before objectives existed).
## Returns the chapters just paid.
static func pay_story(progress: Dictionary, chapters: int, per: int, done_fn: Callable) -> Array:
	var o := roll(progress)
	var out: Array = []
	for c in chapters:
		if c in o.story:
			continue
		if chapter_done_count(c, per, done_fn) >= per:
			o.story.append(c)
			progress["bonus"] = int(progress.get("bonus", 0)) + STORY_REWARD
			out.append(c)
	return out

## Unpaid objectives finished / total on today's and this week's boards: [daily_done, weekly_done].
static func summary(progress: Dictionary) -> Array:
	var o := roll(progress)
	return [(o.dpaid as Array).size(), (o.wpaid as Array).size()]
