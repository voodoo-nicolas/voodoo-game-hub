extends SceneTree
const Combat = preload("res://scripts/games/hesperia/core/combat.gd")
const Cond = preload("res://scripts/games/hesperia/core/cond.gd")
const HydraEngine = preload("res://scripts/games/hesperia/core/hydra_engine.gd")
const QuestEngine = preload("res://scripts/games/hesperia/core/quest_engine.gd")
const SaveEngine = preload("res://scripts/games/hesperia/core/save_engine.gd")
const Tokens = preload("res://scripts/games/hesperia/core/tokens.gd")
## Headless logic test (pure classes only, no autoloads):
##   godot --headless --path hesperia --script tests/test_logic.gd
## Exit code 1 on failure.

var fails: Array = []

class MockState:
	var flags := {}
	var inv := {}
	var qs := {}
	var renown := 0
	func has_flag(f): return flags.get(f, false)
	func item_count(i): return int(inv.get(i, 0))
	func quest_state(q): return qs.get(q, "inactive")

func check(c: bool, msg: String) -> void:
	if not c:
		fails.append(msg)

func _init() -> void:
	# tokens
	check(Tokens.resolve("Hi {name}, {g:lad|lass}!", "Theron", true) == "Hi Theron, lad!", "tokens male")
	check(Tokens.resolve("Hi {name}, {g:lad|lass}!", "Thalia", false) == "Hi Thalia, lass!", "tokens female")
	check(Tokens.resolve("{g:o|a} y {g:o|a}", "x", false) == "a y a", "tokens repeat")
	# cond
	var s := MockState.new()
	s.flags["a"] = true
	s.inv["torch"] = 1
	s.qs["m02"] = "active"
	s.renown = 2
	check(Cond.eval("flag:a&has:torch", s), "cond and")
	check(not Cond.eval("flag:b", s), "cond missing flag")
	check(Cond.eval("!flag:b", s), "cond negation")
	check(Cond.eval("quest:m02=active", s), "cond quest")
	check(Cond.eval("renown>=2", s) and not Cond.eval("renown>=3", s), "cond renown")
	check(Cond.eval("", s), "cond empty")
	# quest engine: m01 -> m02 chain
	var defs = JSON.parse_string(FileAccess.get_file_as_string("res://games/hesperia/data/slice_quests.json"))
	var q := QuestEngine.new()
	q.defs = defs
	check(q.start("m01"), "start m01")
	check(not q.start("m01"), "no double start")
	check(q.state_of("m02") == "inactive", "m02 inactive")
	q.notify("flag:prologue_done")
	check(q.state_of("m01") == "done", "m01 done")
	check(q.log.size() == 1, "reward logged")
	q.start("m02")
	q.notify("item:gaff")                      # out of order: ignored
	check(q.step_of("m02") == 0, "order enforced")
	for ev in ["enter:d0", "item:gaff", "item:torch", "kill:b00"]:
		q.notify(ev)
	check(q.state_of("m02") == "done", "m02 done")
	# save roundtrip
	var packed := SaveEngine.pack({"x": 1, "q": q.to_dict()})
	var back := SaveEngine.unpack(packed)
	check(not back.is_empty() and back["q"]["m02"]["state"] == "done", "save roundtrip")
	check(SaveEngine.unpack("garbage").is_empty(), "bad save rejected")
	# crab shell: front blocked, rear ok
	check(Combat.crab_hit_mult(Vector2i(0, 1), Vector2i(0, -1)) == 0, "crab front blocked")
	check(Combat.crab_hit_mult(Vector2i(0, -1), Vector2i(0, -1)) == 1, "crab rear hit")
	# hydra: sword alone can never kill; sword + fire always can
	check(HydraEngine.beatable(24), "hydra beatable by design")
	var h := HydraEngine.new(24)
	for i in HydraEngine.HEADS:
		check(h.sword_hit(i), "sword severs head %d" % i)
		check(h.fire_hit(i), "fire burns stump %d" % i)
	check(h.defeated(), "hydra defeated by sword+fire on every head (hp=%d)" % h.hp)
	var h2 := HydraEngine.new(24)
	for i in HydraEngine.HEADS:
		h2.sword_hit(i)
	h2.tick(10.0)
	check(h2.heads_up() == HydraEngine.HEADS, "stumps regrow without fire")
	check(h2.hp == 24 - HydraEngine.HEADS, "sword alone chips only")
	var h3 := HydraEngine.new(24)
	check(h3.phase() == 1, "phase 1")
	h3.hp = 12
	check(h3.phase() == 2, "phase 2 at half hp")
	# data counts
	var counts = JSON.parse_string(FileAccess.get_file_as_string("res://games/hesperia/data/counts.json"))
	check(counts["npcs"] == 126 and counts["enemies"] == 72 and counts["bosses"] == 27 and counts["quests"] == 99 and counts["items_total"] == 79, "counts.json")

	if fails.is_empty():
		print("test_logic: ALL PASS")
		quit(0)
	else:
		for f in fails:
			printerr("FAIL: ", f)
		quit(1)
