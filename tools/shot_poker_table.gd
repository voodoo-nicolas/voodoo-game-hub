extends SceneTree

## Draws the Poker table view (video_poker_view.gd) in both looks and a few
## states and saves a picture of each, to check the look without a phone.
## Needs a window (not --headless); the window size is the screen size:
##   godot --path . --resolution 540x960 --script res://tools/shot_poker_table.gd -- <out_dir> [classic|voodoo]
## It draws the view alone (no game, no saves touched). Output: <look>_<state>.png

const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const View = preload("res://scripts/games/video_poker/video_poker_view.gd")
const Look = preload("res://scripts/games/video_poker/video_poker_look.gd")

const NAMES := ["You", "Mama Zuzu", "Bones", "Lucky Lou", "Madame Mojo", "Gator"]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <out_dir> [classic|voodoo]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(args[0])
	_run(args[0], args[1] if args.size() > 1 else "")

func _table(variant: String, limit: String, n: int, seed_value: int) -> RefCounted:
	var t = Table.new()
	t.variant = variant
	t.limit = limit
	t.sb = 10
	t.bb = 20
	for i in n:
		t.seats.append(Table.new_seat(NAMES[i] if i > 0 else "", 1000 + 350 * i, 1 if i == 0 else 0, i % 5))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	t.start_hand(rng)
	return t

func _scenarios() -> Dictionary:
	var out := {}
	var t = _table("holdem", "nl", 6, 11)
	while t.board.size() < 3:
		t.act("call")
	t.act("raise", int(t.legal().min_to) * 2)
	out["holdem6_flop"] = {"t": t}
	t = _table("holdem", "nl", 3, 5)
	while t.phase != "done":
		t.act("call")
	out["holdem3_showdown"] = {"t": t}
	t = _table("stud", "fl", 4, 7)
	for i in 5:
		t.act("call")
	out["stud4"] = {"t": t}
	t = _table("draw", "nl", 3, 9)
	while t.phase != "draw":
		t.act("call")
	out["draw3"] = {"t": t, "discards": [1, 3]}
	t = _table("omaha", "pl", 2, 3)
	t.act("call")
	t.act("check")
	out["omaha2_flop"] = {"t": t}
	return out

func _run(out_dir: String, only: String) -> void:
	for i in 3:
		await process_frame
	var holder := ColorRect.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var view = View.new()
	holder.add_child(view)
	var sz := root.get_visible_rect().size
	view.position = Vector2.ZERO
	view.size = Vector2(sz.x, sz.y - 250.0)
	var scenarios := _scenarios()
	for look in ["classic", "voodoo"]:
		if only != "" and only != look:
			continue
		Look.set_skin(look)
		holder.color = Look.c("room")
		for key in scenarios:
			var sc: Dictionary = scenarios[key]
			view.t = sc.t
			view.viewer = 0
			view.discards = sc.get("discards", [])
			view.queue_redraw()
			for i in 3:
				await process_frame
			var img := root.get_texture().get_image()
			img.save_png(out_dir.path_join("%s_%s.png" % [look, key]))
			print("SHOT ", look, "_", key)
	quit()
