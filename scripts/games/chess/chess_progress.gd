extends RefCounted

## What the player has built up in Chess, kept on this phone
## (user://chess_progress.json): lesson points and the shop, which lesson
## boards are solved, the daily-lesson streak, a rating from games against
## the computer, and which info panels show. Not synced to the account
## (like the game's other stats); it is not the game save either, so a new
## game never touches it.

const PATH := "user://chess_progress.json"
const STYLES = preload("res://scripts/games/chess/chess_styles.gd")

## Info panels around the board (⚙ Options → Show), all on by default.
const PANELS := ["coords", "players", "clocks", "moves", "eval", "captured"]
const PANEL_NAMES := {
	"coords": "Coordinates (a–h, 1–8)",
	"players": "Player names and ratings",
	"clocks": "Game clocks",
	"moves": "Move list",
	"eval": "Evaluation bar",
	"captured": "Captured pieces and material",
}

## Points for a solved lesson board (first time), finishing a lesson, the
## daily lesson, and wins against the computer per level.
const POINTS_BOARD := 10
const POINTS_HARD_BOARD := 20
const POINTS_LESSON := 20
const POINTS_DAILY := 30
const POINTS_STREAK_STEP := 5
const POINTS_STREAK_MAX := 10
const POINTS_WIN := [5, 15, 40]

## Ratings: everyone starts at START_RATING; the computer's levels have the
## fixed ratings below (rough guides), and each game against it moves yours.
const START_RATING := 1200
const CPU_RATINGS := [800, 1200, 1600]
const K_FACTOR := 32

var data: Dictionary = {}
## Where it's kept (a test points it elsewhere, so it never touches the real one).
var path: String = PATH

func _init(p_path: String = PATH) -> void:
	path = p_path
	load_file()

func load_file() -> void:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text) if text != "" else null
	data = parsed if parsed is Dictionary else {}
	for key in ["owned", "solved_list"]:
		if not (data.get(key) is Array):
			data[key] = []
	for key in ["view", "done_lessons", "daily"]:
		if not (data.get(key) is Dictionary):
			data[key] = {}
	if not data.owned.has("board:wood"):
		data.owned.append("board:wood")
	if not data.owned.has("pieces:staunton"):
		data.owned.append("pieces:staunton")

func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

# ---------- points and shop ----------

func points() -> int:
	return int(data.get("points", 0))

func earn(n: int) -> void:
	data["points"] = points() + n
	data["earned"] = int(data.get("earned", 0)) + n
	save()

func owns(kind: String, id: String) -> bool:
	return data.owned.has(kind + ":" + id)

## Spends the points and equips it. false if it costs more than the player has.
func buy(kind: String, id: String) -> bool:
	if owns(kind, id):
		equip(kind, id)
		return true
	var item: Dictionary = STYLES.board(id) if kind == "board" else STYLES.pieces(id)
	var price := int(item.get("price", 0))
	if price > points():
		return false
	data["points"] = points() - price
	data.owned.append(kind + ":" + id)
	equip(kind, id)
	return true

func equip(kind: String, id: String) -> void:
	data[kind] = id
	save()

func board_id() -> String:
	return str(data.get("board", "wood"))

func pieces_id() -> String:
	return str(data.get("pieces", "staunton"))

# ---------- lessons ----------

func is_solved(board_key: String) -> bool:
	return data.solved_list.has(board_key)

## Marks a lesson board solved; true the first time.
func mark_solved(board_key: String) -> bool:
	if is_solved(board_key):
		return false
	data.solved_list.append(board_key)
	save()
	return true

func lesson_done(lesson_id: String) -> bool:
	return data.done_lessons.has(lesson_id)

## Marks a whole lesson done; true the first time.
func mark_lesson_done(lesson_id: String) -> bool:
	if lesson_done(lesson_id):
		return false
	data.done_lessons[lesson_id] = true
	save()
	return true

# ---------- daily lesson ----------

## Today's date as "2026-10-24" (the phone's own calendar).
static func today() -> String:
	return Time.get_date_string_from_system()

static func day_number(date: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(date + "T12:00:00") / 86400)

func daily_done_today() -> bool:
	return str(data.daily.get("done", "")) == today()

## The streak as it stands today: it lapses when yesterday was missed.
func daily_streak() -> int:
	var last := str(data.daily.get("done", ""))
	if last == "":
		return 0
	var gap: int = day_number(today()) - day_number(last)
	return int(data.daily.get("streak", 0)) if gap <= 1 else 0

## Today's daily lesson finished: returns the points it earned (0 if it was
## already done today).
func finish_daily() -> int:
	if daily_done_today():
		return 0
	var streak := daily_streak() + 1
	data.daily["streak"] = streak
	data.daily["best"] = maxi(streak, int(data.daily.get("best", 0)))
	data.daily["done"] = today()
	var pts := POINTS_DAILY + POINTS_STREAK_STEP * mini(streak - 1, POINTS_STREAK_MAX)
	earn(pts)
	return pts

# ---------- rating ----------

func rating() -> int:
	return int(data.get("rating", START_RATING))

## After a game against the computer at `level`: score 1 win, 0.5 draw, 0
## loss. Returns the change.
func rate(level: int, score: float) -> int:
	var opp: int = CPU_RATINGS[clampi(level, 0, CPU_RATINGS.size() - 1)]
	var expected := 1.0 / (1.0 + pow(10.0, (opp - rating()) / 400.0))
	var change := int(round(K_FACTOR * (score - expected)))
	data["rating"] = maxi(100, rating() + change)
	save()
	return change

## A word for the rating, shown next to the name (our own ranks, not titles
## from any chess federation).
static func rank_name(r: int) -> String:
	if r < 1000:
		return "Novice"
	if r < 1300:
		return "Club player"
	if r < 1600:
		return "Strong player"
	if r < 1900:
		return "Expert"
	return "Master"

# ---------- what shows around the board ----------

func panel_on(key: String) -> bool:
	return bool(data.view.get(key, true))

func set_panel(key: String, on: bool) -> void:
	data.view[key] = on
	save()

## Clock picked on the setup screens: an index into the game's TIME_CONTROLS.
func clock_index() -> int:
	return int(data.get("clock", 0))

func set_clock_index(i: int) -> void:
	data["clock"] = i
	save()
