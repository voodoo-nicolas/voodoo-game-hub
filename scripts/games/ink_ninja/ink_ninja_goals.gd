extends RefCounted

## Daily and weekly objectives (user://ink_ninja_goals.json). One daily goal picked
## from the date, one weekly goal from the week number; progress comes from the
## game's events (`count(key, n)`); a finished goal pays once and says so.
## Pure logic (no Nodes): tools/test_ink_ninja.gd drives it with fake dates.

const PATH := "user://ink_ninja_goals.json"

## [key, target, text]. Text is translated by the game (tr) with the target.
const DAILY := [
	["kills", 40, "Defeat %d ninjas"],
	["parries", 6, "Cut %d enemy stars out of the air"],
	["scrolls", 8, "Collect %d scrolls"],
	["bosses", 1, "Defeat %d boss"],
	["nohit", 1, "Clear %d stage without losing a heart"],
	["combo5", 1, "Reach a 5-kill combo %d time"],
	["stages", 3, "Clear %d stages"],
	["star_kills", 10, "Defeat %d ninjas with throwing stars"],
]
const WEEKLY := [
	["kills", 300, "Defeat %d ninjas"],
	["bosses", 5, "Defeat %d bosses"],
	["parries", 40, "Cut %d enemy stars out of the air"],
	["scrolls", 50, "Collect %d scrolls"],
	["nohit", 3, "Clear %d stages without losing a heart"],
	["stages", 15, "Clear %d stages"],
	["hard_bosses", 1, "Defeat %d boss on Hard"],
]

var data := {}

func load_data(today: int, week: int) -> void:
	data = {}
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				data = d
	roll(today, week)

## New day / new week: fresh goal, progress back to 0.
func roll(today: int, week: int) -> void:
	if int(data.get("day", -1)) != today:
		data["day"] = today
		data["d_i"] = posmod(today * 7 + 3, DAILY.size())
		data["d_n"] = 0
		data["d_done"] = false
	if int(data.get("week", -1)) != week:
		data["week"] = week
		data["w_i"] = posmod(week * 5 + 1, WEEKLY.size())
		data["w_n"] = 0
		data["w_done"] = false

func daily() -> Array:
	return DAILY[int(data.d_i)]

func weekly() -> Array:
	return WEEKLY[int(data.w_i)]

## Adds progress; returns ["daily"] / ["weekly"] for goals finished by this call.
func count(key: String, n: int = 1) -> Array:
	var done: Array = []
	if not data.d_done and daily()[0] == key:
		data.d_n = int(data.d_n) + n
		if int(data.d_n) >= int(daily()[1]):
			data.d_done = true
			done.append("daily")
	if not data.w_done and weekly()[0] == key:
		data.w_n = int(data.w_n) + n
		if int(data.w_n) >= int(weekly()[1]):
			data.w_done = true
			done.append("weekly")
	if not done.is_empty() or n > 0:
		save()
	return done

func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

## Day / week numbers from the device clock (local date).
static func today_num() -> int:
	return int(Time.get_unix_time_from_datetime_dict(Time.get_date_dict_from_system()) / 86400)

static func week_num() -> int:
	return int((today_num() + 3) / 7)   # weeks start on Monday (day 0 = Thursday 1970-01-01)
