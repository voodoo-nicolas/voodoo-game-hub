extends SceneTree

## Chess Phase B1 (2026-11-25), headless: ♟ Ongoing Games. An old single save
## becomes a slot; new games keep the others; Resume opens the latest; a
## finished game frees its slot; all 6 in use opens the replace picker;
## Play Again gets a slot; deleting a slot.
##
##   godot --headless --path . --script res://tools/test_chess_slots.gd
##
## WRITES the real chess_save.json / chess_slots.json / stats: back up
## %APPDATA%\Godot\app_userdata\Voodoo first.

const E = preload("res://scripts/games/chess/chess_engine.gd")
const Slots = preload("res://scripts/games/chess/chess_slots.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")

var fails := 0
var g: Node

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await process_frame

func tap_move(u: String) -> void:
	var m := E.parse_uci(u)
	g._on_square_pressed(m.from.x, m.from.y)
	g._on_square_pressed(m.to.x, m.to.y)

func boot() -> void:
	if g:
		g.queue_free()
		await frames(2)
	g = load("res://scenes/games/chess/chess.tscn").instantiate()
	root.add_child(g)
	await frames(3)

func _run() -> void:
	# An old single save (no slot) and no slots file.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Slots.PATH))
	var e = E.new()
	e.reset()
	e.move(Vector2i(6, 4), Vector2i(4, 4))
	SaveUtil.write("user://chess_save.json", {"board": e.board, "current_player": e.current_player,
		"castling_rights": e.castling_rights, "en_passant_target": [-1, -1], "halfmove_clock": 0,
		"position_counts": {}, "cpu": 1, "sans": ["e4"], "last": [], "clock_limit": 0, "clocks": [0, 0]})
	await boot()
	check(Slots.load_all().size() == 1, "old save became slot 1")
	g.home.start_mode({"action": g._new_two_player})
	await frames(2)
	tap_move("d2d4")
	g._save_game()
	check(Slots.load_all().size() == 2, "a new game keeps the old one (2 slots)")
	var two_id: String = g.slot_id
	# Resume the old one from the list.
	var old_id := ""
	for sl in Slots.load_all():
		if str(sl.id) != two_id:
			old_id = str(sl.id)
	g._resume_slot(old_id)
	await frames(2)
	check(g.slot_id == old_id and g.mode == "cpu" and g.san_moves == ["e4"], "resume a slot from the list")
	check(Slots.find(two_id).data.sans == ["d4"], "the game left keeps its slot")
	# Finishing frees its slot and Resume points at the other.
	g._do_resign()
	check(Slots.load_all().size() == 1 and Slots.find(old_id).is_empty(), "finished game frees its slot")
	var cur = SaveUtil.read("user://chess_save.json")
	check(cur is Dictionary and str(cur.get("slot", "")) == two_id, "Resume now opens the other game")
	# Play Again gets a slot.
	g._on_play_again()
	tap_move("e2e4")
	g._save_game()
	check(Slots.load_all().size() == 2, "Play Again is kept in a slot")
	# Fill to 6, then a 7th opens the picker.
	for i in 4:
		g.home.start_mode({"action": g._new_two_player})
		await frames(1)
		tap_move("g1f3")
		g._save_game()
	check(Slots.load_all().size() == 6 and Slots.is_full(), "6 slots in use")
	var before_id: String = g.slot_id
	g.home.start_mode({"action": g._new_vs_cpu.bind(0)})
	await frames(1)
	check(g._pending_start.is_valid() and g.slot_id == before_id, "7th game waits for the replace picker")
	var victim: String = str(Slots.sorted()[-1].id)
	var card: Control = null
	for c in g.home.get_children():
		if c is ColorRect and c.visible and c.has_meta("nav") and c.get_meta("temporary", false):
			card = c
	g._replace_slot(victim, card)
	await frames(2)
	check(Slots.find(victim).is_empty() and g.mode == "cpu" and g.slot_id != before_id, "picked slot replaced, new game started")
	tap_move("e2e4")
	g._save_game()
	check(Slots.load_all().size() == 6, "still 6")
	# Delete from the list (two taps).
	g._open_ongoing()
	var target: String = str(Slots.sorted()[-1].id)
	var b := Button.new()
	g._on_delete_pressed(b, target)
	check(not Slots.find(target).is_empty(), "first 🗑 tap only asks")
	g._on_delete_pressed(b, target)
	check(Slots.find(target).is_empty(), "second tap deletes")
	b.free()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
