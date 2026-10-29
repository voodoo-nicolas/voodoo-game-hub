extends SceneTree

## Headless check of Creation's pure logic: the validator (real data + broken
## fixtures), combine symmetry, multi-result recipes, same+same, failed pairs,
## paid-tier gating, hints, shelf search/sort/filter, save/load, and a full
## simulated playthrough (no stall, everything reachable).
## godot --headless --path . --script res://tools/test_creation.gd
## Touches no user files (the engine never saves by itself).

const E = preload("res://scripts/games/creation/creation_engine.gd")
const G = preload("res://scripts/games/creation/creation_gate.gd")
const DATA := "res://scripts/games/creation/creation_data.json"

var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)

func _fresh() -> Object:
	var e = E.new()
	var errs: Array = e.load_data(E.parse_data(FileAccess.get_file_as_string(DATA)))
	check(errs.is_empty(), "real data loads: %s" % str(errs))
	return e

func _init() -> void:
	var data: Dictionary = E.parse_data(FileAccess.get_file_as_string(DATA))
	check(not data.is_empty(), "data parses")
	_test_validator(data)
	_test_combine()
	_test_gating()
	_test_hints()
	_test_shelf()
	_test_save()
	_test_playthrough()
	print("creation tests: ", "ALL OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _test_validator(data: Dictionary) -> void:
	check(E.validate(data).is_empty(), "real data validates")
	check(data.items.size() == 263 and data.recipes.size() == 259, "263 items, 259 recipes (257 + 2 early-game routes): %d/%d" % [data.items.size(), data.recipes.size()])
	# broken fixtures: each one must be caught
	var d: Dictionary = data.duplicate(true)
	d.recipes.append({"a": "earth", "b": "nothing", "results": ["lava"]})
	check(not E.validate(d).is_empty(), "undefined id caught")
	d = data.duplicate(true)
	d.recipes.append({"a": "fire", "b": "earth", "results": ["mud"]})  # earth+fire exists (reversed)
	check(not E.validate(d).is_empty(), "duplicate pair (reversed) caught")
	d = data.duplicate(true)
	d.items.append({"id": "orphan", "name": {"en": "Orphan", "es": "Huérfano"}, "emoji": "?", "tier": 1, "depth": 0})
	check(not E.validate(d).is_empty(), "item with no source / unreachable caught")
	d = data.duplicate(true)
	d.items[5].name.es = ""
	check(not E.validate(d).is_empty(), "missing ES name caught")
	d = data.duplicate(true)
	d.items[5].tier = 9
	check(not E.validate(d).is_empty(), "unknown tier caught")
	d = data.duplicate(true)
	for r in d.recipes:  # make a free item depend on a paid-tier ingredient
		if r.results.has("pot"):
			r.a = "computer"
	check(not E.validate(d).is_empty(), "free item needing a paid ingredient caught")

func _test_combine() -> void:
	var e = _fresh()
	var data: Dictionary = E.parse_data(FileAccess.get_file_as_string(DATA))
	# symmetry: every recipe works in both orders
	for r in data.recipes:
		check(e.combine(r.a, r.b) == r.results and e.combine(r.b, r.a) == r.results, "symmetry %s+%s" % [r.a, r.b])
	check(E.key("water", "earth") == E.key("earth", "water"), "key is order-free")
	# same + same
	check(e.combine("water", "water") == ["puddle"], "water+water = puddle")
	# multi-result
	check(e.combine("cow", "knife") == ["meat", "leather"], "cow+knife = meat + leather")
	check(e.combine("mountain", "tool") == ["cave", "ore"], "mountain+tool = cave + ore")
	check(e.combine("wool", "water").is_empty(), "unknown pair is empty")
	# early-game routes added by build.py
	check(e.combine("earthquake", "mountain") == ["ore"] and e.combine("stone", "tree") == ["tool"], "early-game extra routes")
	# try_combine statuses
	check(e.try_combine("earth", "fire").status == "new", "first lava is new")
	check(e.is_found("lava"), "lava found")
	check(e.try_combine("fire", "earth").status == "known", "again (reversed) is known")
	check(e.found_count() == 5, "5 found")
	check(e.try_combine("earth", "wind").status == "new", "dust new")
	check(e.try_combine("lava", "dust").status == "miss", "miss")
	check(e.is_failed("dust", "lava"), "failed pair remembered, either order")
	check(e.try_combine("dust", "lava").status == "failed_before", "second try says failed_before")
	check(e.try_combine("water", "water").status == "new" and e.is_found("puddle"), "same+same discovers")
	check(e.try_combine("cow", "knife").status == "invalid", "can't use an item you don't own")
	# multi-result unlocks all (give the player the ingredients by cheating the state)
	e._add_found("sheep"); e._add_found("knife")
	var r: Dictionary = e.try_combine("knife", "sheep")
	check(r.status == "new" and r.new.size() == 2 and e.is_found("wool") and e.is_found("meat"), "multi-result unlocks both")
	e._add_found("cow")
	r = e.try_combine("cow", "knife")
	check(r.new == ["leather"] and r.results.size() == 2, "partly known multi-result gives only the new one")
	# unfound uses: count only
	check(e.unfound_uses("fire") > 0 and e.unfound_uses("wool") >= 0, "unfound_uses counts")
	var before: int = e.unfound_uses("water")
	e.try_combine("water", "wind")
	check(e.unfound_uses("water") == before - 1, "finding a recipe lowers unfound_uses")
	# progress
	var tp: Array = e.tier_progress(1)
	check(tp[1] == 53 and tp[0] >= 4, "tier 1 progress %s" % str(tp))

func _test_gating() -> void:
	var e = _fresh()
	# paywall off (today's shipping state): everything open
	check(e.tier_open(5) and e.has_full(), "paywall off: all tiers open")
	# paywall on, not owned
	e.paywall_on = true
	check(e.tier_open(3) and not e.tier_open(4) and not e.tier_open(5) and not e.has_full(), "paywall on: tiers 4-5 closed")
	e._add_found("computer")  # tier 4 item as an ingredient is impossible normally; use free items instead
	e = _fresh()
	e.paywall_on = true
	for id in ["chip", "wire", "electricity"]:
		pass
	# give the player what they need to reach a tier-4 result: gear = metal + wheel (tier 4)
	for id in ["metal", "wheel"]:
		e._add_found(id)
	var r: Dictionary = e.try_combine("metal", "wheel")
	check(r.status == "locked" and r.locked == ["gear"] and not e.is_found("gear") and e.seen_locked.has("gear"), "paid-tier result stays a silhouette")
	check(e.list_items("", "recent", 0, "en").has("gear"), "silhouette listed on the shelf")
	check(not e.list_items("gear", "recent", 0, "en").has("gear"), "silhouette is not searchable")
	check(e.hint_candidates().find(E.key("metal", "wheel")) == -1, "no hints toward locked items")
	# unlock: silhouettes become discoveries
	e.owns_full = true
	var got: Array = e.refresh_unlock()
	check(got == ["gear"] and e.is_found("gear") and e.seen_locked.is_empty(), "unlocking collects the silhouette")
	# a purchase survives save/load
	var e2 = _fresh()
	e2.paywall_on = true
	e2.set_full_purchased(true)
	var e3 = _fresh()
	e3.paywall_on = true
	e3.from_save(e2.to_save())
	check(e3.tier_open(5) and e3.has_full(), "purchase state saved")
	# gate functions
	check(G.unlimited_hints(true) and not G.unlimited_hints(false), "only the Full Game gives unlimited hints")
	check(G.tier_unlocked(4, false, false) and not G.tier_unlocked(4, false, true) and G.tier_unlocked(4, true, true) and G.tier_unlocked(1, false, true), "gate truth table")
	check(not G.LIVE, "monetization is NOT live in this build")
	check(not G.store_owns(null) and not G.store_buy(null), "no store: not owned, can't buy")

func _test_hints() -> void:
	var e = _fresh()
	check(e.hints_available("2026-10-19") == 3, "3 free hints on a new day")
	# same+same recipes show one ingredient only and move straight on
	var s1: Dictionary = e.use_hint("2026-10-19")
	var sk: PackedStringArray = e.hint_key.split("+")
	check(s1.ok and sk[0] == sk[1] and s1.ingredients.size() == 1, "same+same hint shows its single ingredient")
	e = _fresh()
	for st in ["earth", "fire", "wind", "water"]:
		e.try_combine(st, st)
	var h: Dictionary = e.use_hint("2026-10-19")
	check(h.ok and h.ingredients.size() == 1 and e.hints_available("2026-10-19") == 2, "a hint reveals ONE ingredient and costs one")
	var first: String = h.ingredients[0]
	var h2: Dictionary = e.use_hint("2026-10-19")
	check(h2.ok and h2.second and h2.ingredients.size() == 2 and h2.ingredients.has(first), "asking again about it reveals the other ingredient")
	var h3: Dictionary = e.use_hint("2026-10-19")
	check(h3.ok and e.hints_available("2026-10-19") == 0, "third hint used")
	var h4: Dictionary = e.use_hint("2026-10-19")
	check(not h4.ok and h4.reason == "none_left", "no hint when none left")
	check(e.hints_available("2026-10-20") == 3, "hints refill the next day")
	# a hint is about something makeable and unfound
	var e2 = _fresh()
	for k in e2.hint_candidates():
		var p: PackedStringArray = k.split("+")
		check(e2.is_found(p[0]) and e2.is_found(p[1]), "hint pool only holds makeable recipes")
	# unlimited with the Full Game
	e2.paywall_on = true
	e2.owns_full = true
	for i in 10:
		check(e2.use_hint("2026-10-19").ok, "unlimited hint %d" % i)
	check(e2.hints_available("2026-10-19") == 999, "unlimited")
	# paywall off (today): still 3 a day -- unlimited hints are what the Full Game sells
	var e4 = _fresh()
	check(not e4.paywall_on and e4.hints_available("x") == 3, "paywall off: hints still 3 a day")
	# the highlight clears once found
	var e3 = _fresh()
	var hh: Dictionary = e3.use_hint("d")
	var k: String = e3.hint_key
	var p2: PackedStringArray = k.split("+")
	e3.try_combine(p2[0], p2[1])
	check(e3.hint_key == "" and e3.hint_view.is_empty(), "hint highlight clears when its recipe is found")
	check(hh.ok, "hint ok")

func _test_shelf() -> void:
	var e = _fresh()
	for pair in [["earth", "fire"], ["earth", "water"], ["earth", "wind"], ["water", "wind"], ["fire", "water"]]:
		e.try_combine(pair[0], pair[1])
	var recent: Array = e.list_items("", "recent", 0, "en")
	check(recent[0] == "steam" and recent.size() == e.found_count(), "recent = newest first")
	var az: Array = e.list_items("", "az", 0, "en")
	var sorted_ok := true
	for i in range(1, az.size()):
		if E.fold(e.name_of(az[i - 1], "en")) > E.fold(e.name_of(az[i], "en")):
			sorted_ok = false
	check(sorted_ok, "A-Z sorted")
	check(e.list_items("", "tier", 0, "en")[0] != "", "tier sort works")
	check(e.list_items("lav", "recent", 0, "en") == ["lava"], "search by name")
	check(e.list_items("agua", "recent", 0, "en").has("water"), "search finds the other language too")
	check(e.list_items("", "recent", 2, "en").is_empty(), "filter by tier (none found yet in tier 2)")
	check(e.list_items("", "recent", 1, "en").size() == e.found_count(), "filter tier 1 = all so far")
	var shown: Array = e.list_items("", "recent", 0, "en", true)
	var spent_ok := true
	for id in e.list_items("", "recent", 0, "en"):
		if shown.has(id) != (e.unfound_uses(id) > 0):
			spent_ok = false
	check(spent_ok and shown.size() <= e.found_count(), "hide_spent keeps exactly the items with recipes left")
	check(e.settings.has("hide_spent") and e.settings.hide_spent == false, "hide_spent setting defaults off")
	check(E.fold("Árbol Ñandú") == "arbol nandu", "accent folding")
	check(e.resolve_lang("es_AR") == "es" and e.resolve_lang("en_US") == "en" and e.resolve_lang("fr") == "en", "locale -> language")
	e.settings.lang = "es"
	check(e.resolve_lang("en_US") == "es", "manual switch wins over the locale")
	check(e.name_of("water", "es") == "Agua" and e.name_of("water", "en") == "Water", "names per language, ids unchanged")

func _test_save() -> void:
	var e = _fresh()
	e.try_combine("earth", "fire")
	e.try_combine("lava", "earth")  # a miss
	e.use_hint("2026-10-19")
	e.settings.lang = "es"
	e.settings.theme = "light"
	e.workspace = [{"id": "lava", "x": 0.25, "y": 0.5}]
	var saved: Dictionary = e.to_save()
	# through real JSON, like the file would be (numbers come back as floats)
	var back: Variant = JSON.parse_string(JSON.stringify(saved))
	var e2 = _fresh()
	check(e2.from_save(back), "save loads")
	check(e2.found == e.found and e2.failed == e.failed, "found + failed pairs restored")
	check(e2.hints_left == e.hints_left and e2.hint_day == "2026-10-19" and e2.hints_used == 1, "hint counter restored")
	check(e2.hint_view == e.hint_view and e2.hint_key == e.hint_key, "hint highlight restored")
	check(e2.settings.lang == "es" and e2.settings.theme == "light", "settings restored")
	check(e2.workspace.size() == 1 and e2.workspace[0].id == "lava", "workspace restored")
	check(e2.to_save() == e.to_save(), "save -> load -> save is stable")
	# hostile / old / future saves
	var junk: Dictionary = {"v": 1, "found": ["lava", "ghost", 7], "failed": ["x+y", "earth+fire", "bad"], "locked": ["ghost"], "settings": {"lang": "xx", "theme": 5}, "hints": {"left": 99}}
	var e3 = _fresh()
	check(e3.from_save(junk), "junk-ish save loads")
	check(e3.is_found("lava") and not e3.items.has("ghost") and e3.is_found("earth") and e3.is_found("water"), "unknown ids dropped, starters present")
	check(e3.failed.has("earth+fire") and e3.failed.size() == 1, "bad failed pairs dropped")
	check(e3.settings.lang == "auto" and e3.settings.theme == "auto" and e3.hints_left == 3, "bad settings/hints clamped")
	var future: Dictionary = e.to_save()
	future.v = 99
	future["something_new"] = 1
	check(_fresh().from_save(future), "future-version save still loads")
	var legacy: Dictionary = {"found": ["earth", "fire", "wind", "water", "lava"]}
	var e4 = _fresh()
	check(e4.from_save(legacy) and e4.is_found("lava"), "unversioned save migrates")
	check(not _fresh().from_save({}) and not _fresh().from_save({"x": 1}), "non-saves are refused")
	# reset keeps settings + purchase
	e.set_full_purchased(true)
	e.reset_progress()
	check(e.found_count() == 4 and e.failed.is_empty() and e.settings.lang == "es" and e.purchase.full, "reset keeps settings and purchase")

## A greedy player: keeps trying every pair of what they own. Everything
## must be found, and there must always be something makeable (no stall).
func _test_playthrough() -> void:
	var e = _fresh()
	var steps := 0
	var stalls := 0
	while e.found_count() < e.total():
		var cands: Array = e.hint_candidates()
		if cands.is_empty():
			stalls += 1
			break
		var p: PackedStringArray = cands[0].split("+")
		e.try_combine(p[0], p[1])
		steps += 1
		if steps > 2000:
			break
	check(stalls == 0 and e.found_count() == e.total(), "full playthrough finds all %d items (found %d in %d steps)" % [e.total(), e.found_count(), steps])
	# with the paywall on and nothing bought: exactly the free tiers, and still no stall
	var f = _fresh()
	f.paywall_on = true
	var free_total := 0
	for id in f.item_order:
		if G.tier_is_free(f.tier_of(id)):
			free_total += 1
	steps = 0
	while not f.hint_candidates().is_empty() and steps < 2000:
		var q: PackedStringArray = f.hint_candidates()[0].split("+")
		f.try_combine(q[0], q[1])
		steps += 1
	check(f.found_count() == free_total, "free player completes tiers 1-3 (%d of %d)" % [f.found_count(), free_total])
	# ...then tries every recipe they can: paid-tier results show up as silhouettes
	for k in f.recipes.keys():
		var pp: PackedStringArray = k.split("+")
		if f.is_found(pp[0]) and f.is_found(pp[1]):
			f.try_combine(pp[0], pp[1])
	check(f.seen_locked.size() > 0, "free player has seen paid silhouettes")
	f.owns_full = true
	var got: Array = f.refresh_unlock()
	check(got.size() == f.seen_locked.size() + got.size() and f.seen_locked.is_empty(), "unlock collects every silhouette")
	steps = 0
	while not f.hint_candidates().is_empty() and steps < 2000:
		var q2: PackedStringArray = f.hint_candidates()[0].split("+")
		f.try_combine(q2[0], q2[1])
		steps += 1
	check(f.found_count() == f.total(), "after unlocking the whole game is completable")
	# tier progress sums to the total
	var sum := 0
	for t in f.tiers:
		sum += f.tier_progress(int(t.id))[1]
	check(sum == f.total(), "tier sizes add up")
