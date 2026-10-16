extends SceneTree

## Headless checks for the room data, puzzle logic and text:
##   godot --headless --path . --script res://tools/test_last_shift_rooms.gd

const E = preload("res://scripts/games/last_shift/last_shift_engine.gd")
const R = preload("res://scripts/games/last_shift/last_shift_rooms.gd")
const T = preload("res://scripts/games/last_shift/last_shift_text.gd")
const P = preload("res://scripts/games/last_shift/last_shift_prop.gd")
const N = preload("res://scripts/games/last_shift/last_shift_npc.gd")

const LOOT_ITEMS := ["medkit", "snack", "bullets", "money", "knife", "keycard", "maint_key", "vest", "riot", "cutters", "party_hat",
	"coolant", "arm", "chef_hat"]
const LOCKS := ["", "keycard", "sec_key", "maint", "pump", "lockdown", "staff", "elevator", "card", "dock", "chain"]
const WHEN_TAGS := ["", "calm", "alarm", "after_attack"]

var fails := 0

func check(label: String, ok: bool, detail = "") -> void:
	if not ok:
		fails += 1
		print("FAIL ", label, " ", detail)

func _solid(p: Dictionary) -> bool:
	return p.get("solid", true) and p.kind != "birds"

## Is a prop / person with this "when" tag there in this phase ("calm" = before the alarm,
## "alarm" = after the coworker scene)?
func _in_phase(when: String, phase: String) -> bool:
	if when == "":
		return true
	if phase == "calm":
		return when == "calm"
	return when == "alarm" or when == "after_attack"

## Walkable cells of a room in one phase: floor, minus every solid prop present then.
func _walkable(r: Dictionary, phase: String) -> Dictionary:
	var rows: Array = r.rows
	var blocked := {}
	for p in r.props:
		if _solid(p) and _in_phase(p.get("when", ""), phase):
			var rect: Rect2i = p.rect
			for yy in range(rect.position.y, rect.end.y):
				for xx in range(rect.position.x, rect.end.x):
					blocked[Vector2i(xx, yy)] = true
	var open := {}
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "." and not blocked.has(Vector2i(x, y)):
				open[Vector2i(x, y)] = true
	return open

func _flood(open: Dictionary, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var todo: Array = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if open.has(n) and not seen.has(n):
				seen[n] = true
				todo.append(n)
	return seen

func _init() -> void:
	# --- puzzle
	check("flow none", E.chiller_flow([false, false, false]) == 0)
	check("flow 1+2", E.chiller_flow([true, true, false]) == 5)
	check("flow all", E.chiller_flow([true, true, true]) == 9)
	var solutions := 0
	for m in 8:
		var open := [m & 1 != 0, m & 2 != 0, m & 4 != 0]
		if E.chiller_status(E.chiller_flow(open)) == "ok":
			solutions += 1
	check("exactly one solution", solutions == 1, solutions)
	check("temp falls with flow", E.chiller_temp(5) < E.chiller_temp(2))
	check("status low", E.chiller_status(3) == "low")
	check("status high", E.chiller_status(9) == "high")
	# --- rooms
	var rooms := R.rooms()
	var story_loot := {}
	for rid in rooms:
		var r: Dictionary = rooms[rid]
		var rows: Array = r.rows
		var w: int = rows[0].length()
		for y in rows.size():
			check(rid + " row width " + str(y), rows[y].length() == w, rows[y].length())
			for ch in rows[y]:
				check(rid + " map char", ch in [".", "#", "A", "H"], ch)
		var ids := {}
		for p in r.props:
			check(rid + " unique id " + p.id, not ids.has(p.id))
			ids[p.id] = true
			var rect: Rect2i = p.rect
			for yy in range(rect.position.y, rect.end.y):
				for xx in range(rect.position.x, rect.end.x):
					var inside := xx >= 0 and yy >= 0 and xx < w and yy < rows.size()
					check(rid + " prop in bounds " + p.id, inside)
					if inside:
						var ch: String = rows[yy][xx]
						check(rid + " prop on floor " + p.id, ch == ".", ch)
			if p.kind == "door" or p.kind == "elevator":
				check(rid + " door target " + p.id, rooms.has(p.to))
				if rooms.has(p.to):
					check(rid + " door spawn " + p.id, rooms[p.to].spawns.has(p.spawn))
			if p.kind in ["terminal", "plaque", "npc_dwayne", "cake", "corkboard"]:
				check("email exists " + p.id, T.EMAILS.has(p.get("email", "")))
			if p.has("note"):
				check("note exists " + p.id, T.EMAILS.has(p.note))
			if p.kind == "poster" and not p.get("product", false):
				check(rid + " poster text " + p.id, T.SIGNS.has(p.get("sign", "")))
			if p.kind == "sign_post":
				check(rid + " sign text " + p.id, T.SIGNS.has(p.get("sign", "")))
			if p.has("label"):
				check(rid + " painted text " + p.id, T.SIGNS.has(p.label))
			for entry in p.get("loot", []):
				check(rid + " loot item " + p.id, entry.item in LOOT_ITEMS, entry.item)
				check(rid + " loot amount " + p.id, int(entry.n) > 0)
				if entry.item in ["keycard", "maint_key", "knife", "vest", "riot", "cutters", "party_hat"]:
					story_loot[entry.item] = story_loot.get(entry.item, 0) + 1
		# solid props never overlap each other (per phase)
		for phase in ["calm", "alarm"]:
			var used := {}
			for p in r.props:
				if not _solid(p) or not _in_phase(p.get("when", ""), phase):
					continue
				var rect: Rect2i = p.rect
				for yy in range(rect.position.y, rect.end.y):
					for xx in range(rect.position.x, rect.end.x):
						var c := Vector2i(xx, yy)
						check(rid + " solid props overlap " + p.id + " / " + str(used.get(c, "")), not used.has(c))
						used[c] = p.id
		for ed in r.get("enemies", []):
			check(rid + " enemy kind " + ed.id, E.ENEMY_HP.has(ed.kind), ed.kind)
			check(rid + " enemy diff " + ed.id, int(ed.get("diff", 0)) in [0, 1, 2])
			var cells: Array = [ed.cell] + ed.get("patrol", [])
			for c in cells:
				check(rid + " enemy cell on floor " + ed.id, rows[c.y][c.x] == ".")
				for p in r.props:
					if _solid(p):
						check(rid + " enemy cell not in prop " + ed.id + " / " + p.id, not Rect2i(p.rect).has_point(c))
		for nd in r.get("npcs", []):
			check(rid + " npc when " + nd.id, nd.get("when", "") in WHEN_TAGS)
			check(rid + " npc look " + nd.id, N.LOOKS.has(nd.look))
			check(rid + " npc bark " + nd.id, nd.bark == "" or T.BARKS.has(nd.bark))
			var cells: Array = [nd.cell] + nd.get("path", [])
			for c in cells:
				check(rid + " npc cell on floor " + nd.id, rows[c.y][c.x] == ".")
				for p in r.props:
					if _solid(p) and _in_phase(p.get("when", ""), "calm" if nd.get("when", "") == "calm" else "alarm"):
						check(rid + " npc cell not in prop " + nd.id + " / " + p.id, not Rect2i(p.rect).has_point(c))
		for sname in r.spawns:
			var c: Vector2i = r.spawns[sname].cell
			check(rid + " spawn on floor " + sname, rows[c.y][c.x] == ".")
			for p in r.props:
				if _solid(p):
					check(rid + " spawn not in prop " + sname + " / " + p.id, not Rect2i(p.rect).has_point(c))
		# reachability: from the first spawn, every other spawn and everything A can use has a
		# free tile next to it (furniture never walls anything off)
		for phase in ["calm", "alarm"]:
			var open := _walkable(r, phase)
			var first: Vector2i = r.spawns.values()[0].cell
			var reach := _flood(open, first)
			for sname in r.spawns:
				check(rid + " " + phase + " spawn reachable " + sname, reach.has(r.spawns[sname].cell))
			for p in r.props:
				if not _in_phase(p.get("when", ""), phase):
					continue
				if not (p.kind in P.USE_KINDS or p.kind == "locker" or p.has("loot")):
					continue
				var rect: Rect2i = p.rect
				var ok := false
				for yy in range(rect.position.y - 1, rect.end.y + 1):
					for xx in range(rect.position.x - 1, rect.end.x + 1):
						if reach.has(Vector2i(xx, yy)):
							ok = true
				check(rid + " " + phase + " can reach " + p.id, ok)
	# --- story items hidden in containers: exactly one each
	for item in ["keycard", "maint_key", "knife", "vest", "riot", "cutters", "party_hat"]:
		check("exactly one " + item + " in the loot", story_loot.get(item, 0) == 1, story_loot.get(item, 0))
	# --- text rule: the word CLAUDIUS never appears in any speaker text, email or message
	# (spec v0.4: it may appear ONLY as the product brand on signage, i.e. T.SIGNS)
	var all_text := ""
	for d in [T.INTERCOM, T.NASH, T.MSG, T.BARKS, T.LOOT_NAMES, T.ROOM_LINES, T.QUEST]:
		for k in d:
			all_text += str(d[k]) + " "
	for k in T.EMAILS:
		all_text += T.EMAILS[k].body + T.EMAILS[k].subject
	check("no CLAUDIUS in text", not all_text.to_upper().contains("CLAUDIUS"))
	# --- every puzzle has exactly one solution
	for pid in E.PUZZLES:
		var n: int = E.puzzle_size(pid)
		var count := 0
		for m in (1 << n):
			var open: Array = []
			for i in n:
				open.append((m >> i) & 1 == 1)
			if E.puzzle_status(pid, E.puzzle_flow(pid, open)) == "ok":
				count += 1
		check("puzzle " + pid + " has exactly one solution", count == 1, count)
	# --- every player-facing string has a Spanish translation
	var I = load("res://scripts/games/last_shift/last_shift_i18n.gd")
	# Hub: the Spanish lives in tools/i18n/es.json; the generated last_shift_i18n.gd holds this
	# game's part of it. (Prototype: I.spanish(), its own table.)
	var es: Dictionary = I.STRINGS["es"]
	var unused := ["obj_end", "obj_end4"]
	# Hub: text with no words to translate ("+$%d", "-"), the CLAUDIUS brand, and "cash" (money is
	# shown as "$5", never by name) are not in es.json -- `hub.py i18n` leaves them out on purpose.
	var no_words := ["got_money", "st_none", "product", "money"]
	for k in T.MSG:
		if not unused.has(k):
			check("ES msg " + k, no_words.has(k) or es.has(T.MSG[k]))
	for k in T.INTERCOM:
		check("ES intercom " + k, es.has(T.INTERCOM[k]))
	for k in T.NASH:
		check("ES nash " + k, es.has(T.NASH[k]))
	# "Music" is marked "not UI text" in es.json (the hub uses it as a bus name); the prototype's
	# volume row that showed it is the hub's Options in the hub, so it is never shown here.
	var unused_ui := ["music_vol"]
	for k in T.UI:
		if not unused_ui.has(k):
			check("ES ui " + k, no_words.has(k) or es.has(T.UI[k]))
	for k in T.EMAILS:
		for part in ["from", "subject", "body"]:
			if T.EMAILS[k].has(part):
				check("ES email " + k + "." + part, es.has(T.EMAILS[k][part]))
	for d in [T.LOOT_NAMES, T.SIGNS, T.BARKS, T.ROOM_LINES, T.QUEST]:
		for k in d:
			check("ES " + k, no_words.has(k) or es.has(d[k]))
	for k in T.ACH:
		check("ES ach name " + k, es.has(T.ACH[k].name))
		check("ES ach desc " + k, es.has(T.ACH[k].desc))
	# every quest and achievement has its text, every exit room exists
	for q in E.QUESTS:
		check("quest text " + q, T.QUEST.has(q))
	for a in E.ACHIEVEMENTS:
		check("achievement text " + a, T.ACH.has(a))
	for room in ["parking_lot", "service_yard", "side_street"]:
		check("exit room " + room, rooms.has(room))
	for k in T.ITEMS:
		check("ES item name " + k, es.has(T.ITEMS[k].name))
		check("ES item desc " + k, es.has(T.ITEMS[k].desc))
	# --- room tags and locks are known values
	for rid in rooms:
		for p in rooms[rid].props:
			check(rid + " when tag " + p.id, p.get("when", "") in WHEN_TAGS)
			check(rid + " lock value " + p.id, p.get("lock", "") in LOCKS)
	print("room data tests: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
