extends RefCounted

## [Phase C 2026-11-25] 🧩 Puzzles: the puzzle bank (games/chess/puzzles.json,
## from the Lichess puzzle database, CC0, built by tools/chess_puzzles.py)
## and the player's puzzle record (kept in chess_progress.json under
## "puzzle", so the existing cloud save carries it).
##
## A puzzle is [id, fen, "uci uci ...", rating, "themes"]: the FEN is the
## position BEFORE the opponent's move; moves[0] is that move, then the
## player's answers and the opponent's replies alternate.

const PATH := "res://games/chess/puzzles.json"
const START_RATING := 1200
const RUSH_SECONDS := 180
const RUSH_STRIKES := 3
const RUSH_START := 700
const RUSH_STEP := 60
const HISTORY := 100

## Lichess theme ids -> names shown (English; translated where shown).
const THEME_NAMES := {
	"mateIn1": "Mate in 1", "mateIn2": "Mate in 2", "mateIn3": "Mate in 3", "mateIn4": "Mate in 4+",
	"fork": "Fork", "pin": "Pin", "skewer": "Skewer", "discoveredAttack": "Discovered attack",
	"doubleCheck": "Double check", "deflection": "Deflection", "attraction": "Decoy",
	"clearance": "Clearance", "interference": "Interference", "zugzwang": "Zugzwang",
	"defensiveMove": "Defence", "endgame": "Endgame", "opening": "Opening",
	"hangingPiece": "Hanging piece", "trappedPiece": "Trapped piece", "sacrifice": "Sacrifice",
	"promotion": "Promotion", "backRankMate": "Back-rank mate", "smotheredMate": "Smothered mate",
	"quietMove": "Quiet move", "intermezzo": "In-between move",
}
## The theme picker, in this order. "mateIn4" also takes mateIn5 puzzles.
const THEME_ORDER := ["mateIn1", "mateIn2", "mateIn3", "mateIn4", "fork", "pin", "skewer",
	"discoveredAttack", "doubleCheck", "deflection", "attraction", "clearance", "interference",
	"zugzwang", "defensiveMove", "hangingPiece", "trappedPiece", "sacrifice", "promotion",
	"backRankMate", "smotheredMate", "quietMove", "intermezzo", "endgame", "opening"]

static var _bank: Array = []

## Every puzzle, by rating (empty if the file is missing).
static func all() -> Array:
	if _bank.is_empty() and FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary and parsed.get("puzzles") is Array:
			_bank = parsed.puzzles
	return _bank

static func has_theme(p: Array, theme: String) -> bool:
	if theme == "":
		return true
	var t: PackedStringArray = str(p[4]).split(" ", false)
	return theme in t or (theme == "mateIn4" and "mateIn5" in t)

## A puzzle near `rating` (closest first, a little random), not in `skip`
## (ids), with `theme` if given. [] if none.
static func pick(rating: int, rng: RandomNumberGenerator, skip: Dictionary = {}, theme: String = "") -> Array:
	var best: Array = []
	var best_d := 1 << 30
	for p in all():
		if skip.has(str(p[0])) or not has_theme(p, theme):
			continue
		var d: int = absi(int(p[3]) - rating) + rng.randi_range(0, 120)
		if d < best_d:
			best_d = d
			best = p
	if best.is_empty() and not skip.is_empty():
		return pick(rating, rng, {}, theme)  # every one seen: start over
	return best

## Today's puzzle: the same for everyone (by date), rated 1200-1800.
static func daily(date: String) -> Array:
	var pool: Array = []
	for p in all():
		if int(p[3]) >= 1200 and int(p[3]) <= 1800:
			pool.append(p)
	if pool.is_empty():
		return []
	var h := 0
	for ch in date:
		h = (h * 31 + ch.unicode_at(0)) % 1000003
	return pool[h % pool.size()]

static func moves_of(p: Array) -> Array:
	return Array(str(p[2]).split(" ", false))

# ---------- the player's record (progress.data.puzzle) ----------

static func record(progress) -> Dictionary:
	var d = progress.data.get("puzzle")
	if not (d is Dictionary):
		d = {}
		progress.data["puzzle"] = d
	for k in ["rating", "played", "streak", "best_streak", "best_rating", "best_rush", "best_survival", "daily_streak"]:
		if not d.has(k):
			d[k] = START_RATING if k in ["rating", "best_rating"] else 0
	for k in ["seen", "history"]:
		if not (d.get(k) is Array):
			d[k] = []
	if not d.has("daily_last"):
		d["daily_last"] = ""
	return d

## A rated try: Elo against the puzzle's rating (K 40 for the first 20, then 24).
## Returns the change.
static func rate(progress, puzzle: Array, solved: bool) -> int:
	var d := record(progress)
	var r: int = int(d.rating)
	var k := 40 if int(d.played) < 20 else 24
	var expected := 1.0 / (1.0 + pow(10.0, (float(puzzle[3]) - r) / 400.0))
	var change := int(round(k * ((1.0 if solved else 0.0) - expected)))
	d.rating = clampi(r + change, 400, 3200)
	d.played = int(d.played) + 1
	d.best_rating = maxi(int(d.best_rating), int(d.rating))
	d.streak = int(d.streak) + 1 if solved else 0
	d.best_streak = maxi(int(d.best_streak), int(d.streak))
	note(progress, puzzle, solved)
	return change

## Remembers a try (also unrated ones): seen ids and the last HISTORY tries.
static func note(progress, puzzle: Array, solved: bool) -> void:
	var d := record(progress)
	var id := str(puzzle[0])
	if not id in d.seen:
		d.seen.append(id)
		while d.seen.size() > 2000:
			d.seen.pop_front()
	d.history.push_front([id, solved, int(puzzle[3]), int(d.rating)])
	while d.history.size() > HISTORY:
		d.history.pop_back()
	progress.save()

static func seen_set(progress) -> Dictionary:
	var out := {}
	for id in record(progress).seen:
		out[str(id)] = true
	return out

## Puzzle of the Day solved: the streak goes on if yesterday was done too.
static func finish_daily(progress, today: String, yesterday: String) -> int:
	var d := record(progress)
	if str(d.daily_last) == today:
		return int(d.daily_streak)
	d.daily_streak = int(d.daily_streak) + 1 if str(d.daily_last) == yesterday else 1
	d.daily_last = today
	progress.save()
	return int(d.daily_streak)
