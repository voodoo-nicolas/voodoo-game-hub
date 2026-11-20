extends SceneTree

## Headless test of "whose progress is on this device" (auth.gd, owner 2026-11-20: ask first):
##   godot --headless --path . --script res://tools/test_progress_owner.gd
## No network. Backs up and restores user://progress_owner.json.

var fails := 0
var asked := ""

func _initialize() -> void:
	_run()

func ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1

func _on_question(name: String) -> void:
	asked = name

func _own(uid: String, dirty: bool) -> void:
	SaveUtil.write("user://progress_owner.json", {"uid": uid, "dirty": dirty})

const SaveUtil = preload("res://scripts/common/save_util.gd")

func _run() -> void:
	await process_frame
	var A = root.get_node("Auth")
	var bak = SaveUtil.read(A.PROGRESS_PATH)
	var was := [A.user_id, A.access_token, A.display_name]
	A.progress_question.connect(_on_question)
	A.access_token = "x"
	A.display_name = "Nico"

	# A guest played, then Nico signs in: ask, hold uploads.
	A.user_id = "nico"
	_own("", true)
	A._test_has_progress = 1
	A._check_progress_owner()
	ok(A.progress_pending and asked == "Nico", "guest progress: Nico is asked")
	ok(not A._score_allowed("chess", 999), "scores are held while asking")
	var got := []
	A.db_call("xp_report", {}, func(o, _p): got.append(o))
	ok(got == [false], "badge upload (xp_report) is held while asking")

	A.answer_progress(true)
	ok(not A.progress_pending and A._progress().uid == "nico", "Yes: the device's progress is Nico's")
	ok(A._score_allowed("chess", 5), "Yes: scores go up as before")

	# Same account again (token refresh, relaunch): never asked twice.
	asked = ""
	A._check_progress_owner()
	ok(asked == "" and not A.progress_pending, "the owner signing in again isn't asked")

	# Another account on this phone: ask; No keeps the device's bests off.
	A.user_id = "ana"
	A.display_name = "Ana"
	A._check_progress_owner()
	ok(A.progress_pending and asked == "Ana", "another account's progress: Ana is asked")
	A.answer_progress(false)
	var floors: Dictionary = A._progress().get("floors", {})
	ok(bool(A._progress().get("declined", false)), "No: remembered as declined")
	ok(floors.has(A.AchievementsLib.BOARD_ID), "No: the badge count is a floor too")
	floors["chess"] = 100
	var d: Dictionary = A._progress()
	d["floors"] = floors
	SaveUtil.write(A.PROGRESS_PATH, d)
	ok(not A._score_allowed("chess", 100) and A._score_allowed("chess", 101), "No: only scores beyond the device's best go up")
	ok(A._score_allowed("new_game", 1), "No: games with no best on the device post normally")

	# A fresh device: nothing to give, nothing to ask.
	asked = ""
	A.user_id = "zoe"
	_own("", false)
	A._test_has_progress = 0
	A._check_progress_owner()
	ok(asked == "" and not A.progress_pending and A._progress().uid == "zoe", "fresh device: no question, Zoe owns it")

	# Signing out mid-question gives nothing; a signed-out play marks guest progress.
	A._test_has_progress = 1
	_own("someone", false)
	A._check_progress_owner()
	A._clear_session()
	ok(not A.progress_pending, "signing out before answering clears the question")
	A.note_play()
	ok(A._progress().uid == "" and bool(A._progress().dirty), "a game played signed out = guest progress")

	A._test_has_progress = -1
	A.user_id = was[0]
	A.access_token = was[1]
	A.display_name = was[2]
	if bak is Dictionary:
		SaveUtil.write(A.PROGRESS_PATH, bak)
	else:
		SaveUtil.delete(A.PROGRESS_PATH)
	print("progress owner: %d failure(s)" % fails)
	quit(fails)
