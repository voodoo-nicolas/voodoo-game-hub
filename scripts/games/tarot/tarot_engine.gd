extends RefCounted

## Tarot: pure logic, no Nodes (headless-tested). The 22 Major Arcana, three
## spreads, a card of the day (same card all day, everywhere), reversed cards,
## a one-line teller summary, and the player's collection.
## Card text is data (tarot_cards.json, EN + ES, our own wording). For fun
## only -- the help text says so.

const DATA_PATH := "res://scripts/games/tarot/tarot_cards.json"
const LORE_PATH := "res://scripts/games/tarot/tarot_lore.json"
const PROGRESS_PATH := "user://tarot_progress.json"
const SPREADS := {"one": 1, "three": 3, "five": 5, "celtic": 10}

var data: Dictionary = {}
var cards: Array = []
## More about each card (tarot_lore.json): traditional picture, what it is linked to, keywords, love and
## work readings, and what each position of a spread stands for. Optional: empty when the file is missing.
var lore: Dictionary = {}
var lang := "en"
## Collection: card index -> {"up": bool, "rev": bool} seen at least once.
var seen: Dictionary = {}
var readings := 0
var daily_day := -1          # day number of the last Card of the Day
var daily_streak := 0
var best_streak := 0

func load_data(path: String = DATA_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return false
	data = parsed
	cards = data.get("cards", [])
	if FileAccess.file_exists(LORE_PATH):
		var l: Variant = JSON.parse_string(FileAccess.get_file_as_string(LORE_PATH))
		if l is Dictionary and l.get("cards", []).size() == 22:
			lore = l
	return cards.size() == 22

func _l(d: Dictionary) -> String:
	return str(d.get(lang, d.get("en", "")))

## Today as a whole number (local date), for the daily card and the streak.
static func today() -> int:
	var d := Time.get_date_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict(d) / 86400)

func name_of(i: int) -> String:
	return _l(cards[i]["name"])

func symbol_of(i: int) -> String:
	return str(cards[i]["sym"])

## The card's meaning for the way it fell.
func meaning(i: int, rev: bool) -> String:
	return _l(cards[i]["rev" if rev else "up"])

func has_lore() -> bool:
	return not lore.is_empty()

func _lore(i: int, key: String) -> Dictionary:
	return lore.get("cards", [])[i].get(key, {}) if has_lore() else {}

## "Air", "the Moon"...: what the card is traditionally linked to.
func assoc(i: int) -> String:
	return _l(_lore(i, "assoc"))

## The traditional picture on the card, in a sentence.
func picture(i: int) -> String:
	return _l(_lore(i, "pic"))

## Keywords for the way the card fell, as one comma-separated line.
func keywords(i: int, rev: bool) -> String:
	var k: Dictionary = _lore(i, "kw").get("rev" if rev else "up", {})
	var arr: Array = k.get(lang, k.get("en", []))
	return ", ".join(PackedStringArray(arr))

func love(i: int, rev: bool) -> String:
	return _l(_lore(i, "love").get("rev" if rev else "up", {}))

func work(i: int, rev: bool) -> String:
	return _l(_lore(i, "work").get("rev" if rev else "up", {}))

## What a position of a spread stands for ("What shaped this situation: its roots.").
func position_note(spread: String, idx: int) -> String:
	var arr: Array = lore.get("positions", {}).get(spread, [])
	return _l(arr[idx]) if idx < arr.size() else ""

func position_name(spread: String, idx: int) -> String:
	var arr: Array = data.get("positions", {}).get(spread, [])
	return _l(arr[idx]) if idx < arr.size() else ""

## Draws a spread: Array of {"id": 0..21, "rev": bool}, no card twice.
## `day` >= 0 seeds the draw (Card of the Day); otherwise it is random.
func draw(spread: String, day: int = -1) -> Array:
	var rng := RandomNumberGenerator.new()
	if day >= 0:
		rng.seed = hash("tarot-day-%d" % day)
	else:
		rng.randomize()
	var deck: Array = range(22)
	# Fisher-Yates with our own rng so the daily draw is the same everywhere.
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	var chance := float(data.get("reversed_chance", 0.3))
	var out: Array = []
	for k in int(SPREADS.get(spread, 1)):
		out.append({"id": int(deck[k]), "rev": rng.randf() < chance})
	return out

## -1 stormy / 0 mixed / 1 bright, summed over the spread.
func tone(drawn: Array) -> String:
	var score := 0
	for c in drawn:
		score += int(cards[int(c["id"])]["t"][1 if c["rev"] else 0])
	var ratio := float(score) / maxf(1.0, float(drawn.size()))
	if ratio >= 0.34:
		return "bright"
	if ratio <= -0.34:
		return "stormy"
	return "mixed"

## The teller's closing line. `pick` chooses among the lines (stable for tests).
func summary(drawn: Array, pick: int = -1) -> String:
	var lines: Array = data.get("summary", {}).get(tone(drawn), {}).get(lang, [])
	if lines.is_empty():
		return ""
	if pick < 0:
		pick = randi()
	return str(lines[pick % lines.size()])

# ---- collection and progress ----

## Marks a reading's cards as seen. Returns the ids that were NEW to the collection.
func record(drawn: Array, count: bool = true) -> Array:
	var fresh: Array = []
	for c in drawn:
		var id := int(c["id"])
		var e: Dictionary = seen.get(id, {"up": false, "rev": false})
		var key := "rev" if c["rev"] else "up"
		if not seen.has(id):
			fresh.append(id)
		e[key] = true
		seen[id] = e
	if count:
		readings += 1
	return fresh

func discovered() -> int:
	return seen.size()

## Card of the Day: advances the streak once per day. Returns true the first time today.
func touch_daily(day: int) -> bool:
	if day == daily_day:
		return false
	daily_streak = daily_streak + 1 if day == daily_day + 1 else 1
	daily_day = day
	best_streak = maxi(best_streak, daily_streak)
	return true

func to_dict() -> Dictionary:
	var s := {}
	for k in seen:
		s[str(k)] = seen[k]
	return {"seen": s, "readings": readings, "daily_day": daily_day,
		"daily_streak": daily_streak, "best_streak": best_streak}

func from_dict(d: Dictionary) -> void:
	seen = {}
	var s: Dictionary = d.get("seen", {})
	for k in s:
		var i := int(k)
		if i >= 0 and i < 22 and s[k] is Dictionary:
			seen[i] = {"up": bool(s[k].get("up", false)), "rev": bool(s[k].get("rev", false))}
	readings = int(d.get("readings", 0))
	daily_day = int(d.get("daily_day", -1))
	daily_streak = int(d.get("daily_streak", 0))
	best_streak = int(d.get("best_streak", 0))

func save(path: String = PROGRESS_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))

func load_progress(path: String = PROGRESS_PATH) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		from_dict(parsed)
