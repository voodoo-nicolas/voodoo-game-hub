extends SceneTree

## Headless check of Poker's Career flow in the real game scene: starting a stage
## builds the right table (the boss, the others, the boss's bigger stack, the
## stage's game and blind speed), a win and a loss are recorded with the right
## stars, the next stage opens, and a saved Career table resumes as a Career table.
## It uses a throwaway profile but plays with the real user:// table save and
## chip files (back them up first, CLAUDE.md).
## godot --headless --path . --script res://tools/test_poker_career_flow.gd

const Profile = preload("res://scripts/games/video_poker/video_poker_profile.gd")
const Career = preload("res://scripts/games/video_poker/video_poker_career.gd")

var fails := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	_run()

func _run() -> void:
	for i in 3:
		await process_frame
	var game = load("res://scenes/games/video_poker/video_poker.tscn").instantiate()
	root.add_child(game)
	for i in 5:
		await process_frame
	if game.info:
		game.info.close()
	var path := "user://test_poker_career_flow_profile.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	game.profile = Profile.new(path)
	var st: Dictionary = Career.STAGES[5]   # the vault: a boss with 1.5x the chips
	game._start_career(st.id)
	await process_frame
	var t = game.t
	ok(game.mode == "tourney" and str(game.meta.career) == st.id, "a Career stage is a tournament table")
	ok(t.seats.size() == Career.opponents(st).size() + 1, "everyone at the table")
	ok(t.variant == st.variant and t.limit == st.limit, "the stage's game")
	ok(game._hpl() == int(st.hpl), "the stage's blind speed")
	var boss_seat := -1
	for i in t.seats.size():
		if str(t.seats[i].name) == str(st.boss):
			boss_seat = i
	ok(boss_seat > 0 and int(t.seats[boss_seat].stack) + int(t.seats[boss_seat].total) == 2250, "the boss has 1.5x the chips")
	ok(int(t.seats[0].stack) + int(t.seats[0].total) == Career.START_STACK, "the player has the normal stack")
	# a saved Career table comes back as a Career table
	game._save_game()
	game.meta = {}
	game._load_saved_game()
	ok(str(game.meta.get("career", "")) == st.id and int(game.meta.get("hpl", 0)) == int(st.hpl), "a resumed table is still the stage")
	# win it
	for i in range(1, game.t.seats.size()):
		game.t.seats[i].stack = 0
	game.t.seats[0].stack = 5000
	game.meta.hands = 40
	game.meta.start = game.t.seats.size()
	game._check_match_over()
	ok(game.profile.career_stars(st.id) >= 2, "a win without help earns at least two stars (%d)" % game.profile.career_stars(st.id))
	ok(Career.unlocked(6, game.profile.d.career), "the next stage is open")
	ok(game.end_dialog.visible, "the end message shows")
	# lose another
	game._start_career("back_room")
	await process_frame
	for i in range(1, game.t.seats.size()):
		game.t.seats[i].stack = 3000
	game.t.seats[0].stack = 0
	game.meta.hands = 10
	game.meta.start = game.t.seats.size()
	game._check_match_over()
	ok(game.profile.career_stars("back_room") == 0, "a loss earns nothing")
	DirAccess.remove_absolute(path)
	game.queue_free()
	print("poker career flow: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
