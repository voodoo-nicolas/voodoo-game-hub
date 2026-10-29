extends SceneTree

## IQ Test achievements (owner, 2026-10-28): the 🏅 screen lists the 10 generic badges and
## the 11 CHALLENGES (980 points), practice time pays 📚 Prepper at one hour, the server's
## "awards" reply pays genius medals and 🔧 Fixer, and nothing pays twice.
##   godot --headless --path . --script res://tools/test_iq_awards.gd [-- <out_dir>]
## WRITES user://challenges_voodoo_iq.json and user://voodoo_iq_awards.json, then puts the
## player's own copies back (other saves are untouched).

const Awards = preload("res://scripts/games/voodoo_iq/voodoo_iq_awards.gd")
const Help = preload("res://scripts/games/voodoo_iq/voodoo_iq_help.gd")
const FILES := [Awards.CHALLENGES_PATH, Awards.STATE_PATH]

var fails := 0
var out_dir := ""
var kept := {}

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await process_frame

func shot(name: String) -> void:
	if out_dir == "":
		return
	await frames(3)
	root.get_texture().get_image().save_png(out_dir + "/" + name + ".png")

func _keep() -> void:
	for f in FILES:
		kept[f] = FileAccess.get_file_as_string(f) if FileAccess.file_exists(f) else null
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)

func _restore() -> void:
	for f in FILES:
		if kept[f] == null:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(f)
		else:
			var h := FileAccess.open(f, FileAccess.WRITE)
			h.store_string(kept[f])
			h.close()

func _run() -> void:
	_keep()
	var xp := 0
	for c in Help.CHALLENGES:
		xp += int(c.xp)
	check(Help.CHALLENGES.size() == 11 and xp == 500, "11 challenges worth 500 points (got %d, %d)" % [Help.CHALLENGES.size(), xp])
	check(Awards.available(), "this app can pay challenges")

	var game = load("res://scenes/games/voodoo_iq/voodoo_iq.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	var sc = game._page_scroller()
	if sc:
		sc.scroll_vertical = 100000
	await shot("home")
	game._show_achievements()
	await frames(3)
	var rows: Array = Awards.rows(game.info, Help.CHALLENGES)
	var total := 0
	for r in rows:
		total += int(r.xp)
	check(rows.size() == 21, "21 badges on the 🏅 screen (got %d)" % rows.size())
	check(total == 980, "980 points in all (got %d)" % total)
	await shot("achievements")

	# Prepper: 59 minutes is not enough, the hour is
	Awards.add_practice(59 * 60.0)
	check(not Awards.earned("prepper"), "59 practice minutes: no Prepper yet")
	var prep: Dictionary = Awards.rows(game.info, Help.CHALLENGES).filter(func(r): return str(r.title) == tr("Prepper"))[0]
	check(absf(float(prep.progress) - 59.0 / 60.0) < 0.001, "Prepper's bar shows 59 of 60 minutes")
	game.practice_pending = 60.0
	game._flush_practice()
	check(Awards.earned("prepper") and game.practice_pending == 0.0, "the hour pays Prepper")
	check(absf(Awards.practice_seconds() - 3600.0) < 0.01, "practice total is 3600 s")

	# the server's reply: only what isn't earned is asked, and paid once
	var req := Awards.request(["LOG", "MUS"], true)
	check(req.get("genius", []) == ["LOG", "MUS"] and req.get("fixer", false) == true, "asks for LOG, MUS and Fixer")
	game._on_awards(true, 200, {"genius": ["LOG"], "fixer": true})
	check(Awards.earned("genius_LOG") and Awards.earned("fixer") and not Awards.earned("genius_MUS"), "the reply pays Logic Genius and Fixer only")
	req = Awards.request(["LOG", "MUS"], true)
	check(req.get("genius", []) == ["MUS"] and req.get("fixer", true) == false, "next time it asks only for MUS")
	check(Awards.request(["LOG"], true).is_empty(), "nothing left to ask: no request")
	check(not Awards.pay("genius_LOG"), "a medal pays only once")
	game._on_awards(false, 400, {"error": "bad_board"})  # an older server: nothing happens
	game.ach_filter = 1
	game._show_achievements()
	var earned := Awards.rows(game.info, Help.CHALLENGES).filter(func(r): return r.unlocked).size()
	check(earned >= 3, "Earned lists at least the 3 new ones (got %d)" % earned)
	await shot("achievements_earned")

	game.queue_free()
	await frames(2)
	_restore()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
