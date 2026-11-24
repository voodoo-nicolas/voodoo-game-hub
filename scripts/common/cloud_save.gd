extends Node
## Cloud progress for any game (owner 2026-11-24: "progress saved on the cloud as well as
## locally; load whichever has the most progress"). STANDARDS "Cloud progress".
##
## The game keeps its own JSON progress file (SaveUtil); this node mirrors it to the
## account (`save_game_progress` / `load_game_progress`, migration 20261101000000) and,
## when a game is opened or the player signs in, keeps whichever copy scores higher on
## the game's own progress number (levels cleared, stars, ...). Ties keep the device copy.
##
## APK-side (scripts/common): packs must load it guarded so older apps stay local-only:
##   if ResourceLoader.exists(CLOUD_SAVE):
##       cloud = load(CLOUD_SAVE).new()
##       cloud.setup("arrows", PROGRESS_PATH, _progress_score, _on_cloud_progress)
##       add_child(cloud)
##   ... after every local progress write:  if cloud: cloud.saved()
## score_fn(data: Dictionary) -> int ; on_loaded() is called after the cloud copy replaced
## the local file (re-read it). Callbacks must be methods (never lambdas).
##
## 80 % alert (owner: "when someone reaches 80% of a game, make me aware so more levels
## are added; not adventure games"): report_completion(done, total) records it once per
## game and account via `report_completion` (migration 20261124000000).

const SaveUtil = preload("res://scripts/common/save_util.gd")
const ALERTS_PATH := "user://cloud_save_alerts.json"
const ALERT_AT := 0.8
const PUSH_DELAY := 3.0

var game := ""
var path := ""
var score_fn: Callable
var on_loaded: Callable
var _timer: Timer

func setup(game_id: String, save_path: String, score: Callable, loaded: Callable = Callable()) -> void:
	game = game_id
	path = save_path
	score_fn = score
	on_loaded = loaded

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = PUSH_DELAY
	_timer.timeout.connect(push)
	add_child(_timer)
	var a := _auth()
	if a == null:
		return
	if not a.signed_in.is_connected(_on_signed_in):
		a.signed_in.connect(_on_signed_in)
	pull()

func _exit_tree() -> void:
	if _timer != null and not _timer.is_stopped():
		push()   # leaving soon after a level: don't lose the last push

func _auth() -> Node:
	var a := get_node_or_null("/root/Auth")
	return a if a != null and a.has_method("db_call") and a.has_method("is_logged_in") else null

func _signed() -> bool:
	var a := _auth()
	return a != null and a.is_logged_in()

func _on_signed_in(_uid: String, _name: String) -> void:
	pull()

## The game just wrote its progress file: push it a moment later (batches quick saves).
func saved() -> void:
	if _signed() and _timer != null:
		_timer.start()

## Fetch the account copy and keep whichever has more progress.
func pull() -> void:
	if _signed():
		_auth().db_call("load_game_progress", {"p_game": game}, _on_pulled)

func _on_pulled(ok: bool, result: Variant) -> void:
	if not ok:
		return
	var local = SaveUtil.read(path)
	var local_score := _score(local)
	var cloud_score := _score(result)
	if cloud_score > local_score:
		SaveUtil.write(path, result)
		if on_loaded.is_valid():
			on_loaded.call()
	elif local_score > cloud_score or (local is Dictionary and not (result is Dictionary)):
		push()

func _score(d: Variant) -> int:
	if not (d is Dictionary) or d.is_empty() or not score_fn.is_valid():
		return -1
	return int(score_fn.call(d))

func push() -> void:
	if _timer != null:
		_timer.stop()
	if not _signed():
		return
	var d = SaveUtil.read(path)
	if d is Dictionary:
		_auth().db_call("save_game_progress", {"p_game": game, "p_data": d}, _ignore)

func _ignore(_ok: bool, _r: Variant) -> void:
	pass

## Call after progress grows. Sends one alert per game per account when done/total >= 80 %.
func report_completion(done: int, total: int) -> void:
	if total <= 0 or float(done) / float(total) < ALERT_AT or not _signed():
		return
	var a := _auth()
	var key := "%s|%s" % [game, str(a.get("user_id"))]
	var sent = SaveUtil.read(ALERTS_PATH)
	sent = sent if sent is Dictionary else {}
	if sent.has(key):
		return
	a.db_call("report_completion", {"p_game": game, "p_done": done, "p_total": total}, _on_reported.bind(key))

func _on_reported(ok: bool, _r: Variant, key: String) -> void:
	if not ok:
		return   # SQL not run yet / offline: try again next time
	var sent = SaveUtil.read(ALERTS_PATH)
	sent = sent if sent is Dictionary else {}
	sent[key] = int(Time.get_unix_time_from_system())
	SaveUtil.write(ALERTS_PATH, sent)
