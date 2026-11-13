extends SceneTree

## Headless test for Tarot's engine (no scene, no saves touched: progress goes to a temp file).
## godot --headless --path . --script res://tools/test_tarot.gd

const E = preload("res://scripts/games/tarot/tarot_engine.gd")
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	var e = E.new()
	check(e.load_data(), "data loads, 22 cards")
	for lang in ["en", "es"]:
		e.lang = lang
		for i in 22:
			check(e.name_of(i) != "", "%s name %d" % [lang, i])
			check(e.meaning(i, false) != "" and e.meaning(i, true) != "", "%s meaning %d" % [lang, i])
			check(str(e.symbol_of(i)) != "", "symbol %d" % i)
			# The lore (tarot_lore.json): every card has every field, both ways, both languages.
			check(e.has_lore(), "lore loads")
			check(e.assoc(i) != "" and e.picture(i) != "", "%s assoc/picture %d" % [lang, i])
			for r in [false, true]:
				check(e.keywords(i, r).count(",") >= 2, "%s keywords %d %s" % [lang, i, r])
				check(e.love(i, r) != "" and e.work(i, r) != "", "%s love/work %d %s" % [lang, i, r])
		for sp in E.SPREADS:
			for k in E.SPREADS[sp]:
				check(e.position_name(sp, k) != "", "%s %s position %d" % [lang, sp, k])
				check(e.position_note(sp, k) != "", "%s %s position note %d" % [lang, sp, k])
		for t in ["bright", "mixed", "stormy"]:
			check(e.data["summary"][t][lang].size() >= 1, "summary %s %s" % [t, lang])
	# Draws: right size, no card twice, ids in range; reversed share near the setting.
	var rev := 0
	var total := 0
	for n in 2000:
		for sp in E.SPREADS:
			var d: Array = e.draw(sp)
			check(d.size() == E.SPREADS[sp], "spread size " + sp)
			var seen := {}
			for c in d:
				check(c["id"] >= 0 and c["id"] < 22, "id range")
				check(not seen.has(c["id"]), "no card twice")
				seen[c["id"]] = true
				total += 1
				if c["rev"]:
					rev += 1
	var share := float(rev) / float(total)
	check(absf(share - 0.3) < 0.02, "reversed share %.3f near 0.3" % share)
	# Card of the Day: same all day, different across days.
	var a: Array = e.draw("one", 20000)
	var b: Array = e.draw("one", 20000)
	check(a == b, "daily draw is stable")
	var ids := {}
	for day in 400:
		ids[e.draw("one", 20000 + day)[0]["id"]] = true
	check(ids.size() == 22, "400 days show all 22 cards (got %d)" % ids.size())
	# Tone covers all three summaries.
	var tones := {}
	for n in 3000:
		tones[e.tone(e.draw("five"))] = true
	check(tones.size() == 3, "all three tones occur (%s)" % str(tones.keys()))
	check(e.summary(e.draw("three"), 0) != "", "summary text")
	# Collection + streak maths.
	check(e.record([{"id": 3, "rev": false}, {"id": 4, "rev": true}]).size() == 2, "two new cards")
	check(e.record([{"id": 3, "rev": true}], false).is_empty(), "known card is not new")
	check(e.seen[3]["up"] and e.seen[3]["rev"], "both ways remembered")
	check(e.readings == 1, "count=false does not count a reading")
	check(e.touch_daily(100) and e.daily_streak == 1, "first daily")
	check(not e.touch_daily(100) and e.daily_streak == 1, "same day twice: no change")
	check(e.touch_daily(101) and e.daily_streak == 2, "next day: streak 2")
	check(e.touch_daily(103) and e.daily_streak == 1 and e.best_streak == 2, "gap resets, best kept")
	# Save round trip.
	var p := "user://tarot_test_tmp.json"
	e.save(p)
	var f = E.new()
	f.load_data()
	f.load_progress(p)
	check(f.discovered() == 2 and f.readings == 1 and f.best_streak == 2 and f.daily_day == 103, "save round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("tarot engine test: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
