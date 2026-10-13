extends SceneTree

## Consent + age gate: brackets, the under-13 lock (nothing but the lock and
## bracket is stored, never the date), accepted-version bookkeeping and
## re-prompt on a version bump, the markdown -> BBCode reader on all four
## documents (no tables), and the consent screen's steps. user://consent.json
## is backed up and restored.
##   godot --headless --path . --script res://tools/test_consent.gd

var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: " + msg)
		fails += 1

func _initialize() -> void:
	var C = load("res://scripts/common/consent.gd")
	var L = load("res://scripts/common/legal_text.gd")
	var path: String = C.PATH
	var had := FileAccess.file_exists(path)
	var backup := FileAccess.get_file_as_string(path) if had else ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# ---- brackets (now = October 2026; the birth month counts as "birthday not yet") ----
	var now := {"year": 2026, "month": 10}
	_check(C.bracket_for(10, 2013, now) == "<13", "born 10/2013 is under 13 (conservative)")
	_check(C.bracket_for(9, 2013, now) == "13-15", "born 9/2013 is 13")
	_check(C.bracket_for(9, 2010, now) == "16-17", "born 9/2010 is 16")
	_check(C.bracket_for(10, 2010, now) == "13-15", "born 10/2010 is 15")
	_check(C.bracket_for(12, 2008, now) == "16-17", "born 12/2008 is 17")
	_check(C.bracket_for(1, 2008, now) == "18+", "born 1/2008 is 18")
	_check(C.bracket_for(5, 1960, now) == "18+", "older is 18+")

	# ---- the under-13 lock ----
	var b: String = C.record_age(3, 2018)
	_check(b == "<13" and C.is_blocked(), "under 13 sets the lock")
	var stored := FileAccess.get_file_as_string(path)
	_check(not ("2018" in stored) and not ("birth" in stored), "the date is not stored")
	_check(C.bracket() == "", "no bracket for a blocked player")
	C.record_age(1, 1990)  # retyping an adult year
	_check(C.is_blocked(), "retyping an older year does not lift the lock")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# ---- a normal player ----
	_check(C.record_age(1, 1990) == "18+" and not C.is_blocked() and C.bracket() == "18+", "adult bracket saved")
	_check(not C.has_accepted(), "nothing accepted yet")
	C.accept("es")
	_check(C.has_accepted(), "accepted after accept()")
	var state = JSON.parse_string(FileAccess.get_file_as_string(path))
	state["accepted"]["privacy"] = "0.9.0"  # an older version than the app's
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(state))
	f.close()
	_check(not C.has_accepted(), "an older accepted version asks again (re-prompt on a version bump)")

	# ---- the text ----
	for doc in ["terms", "privacy"]:
		for lang in ["es", "en"]:
			var md: String = C.doc_markdown(doc, lang)
			_check(md.length() > 1000, "%s.%s has text" % [doc, lang])
			_check(not ("{{" in md) and not ("[[" in md), "%s.%s has no leftover placeholder or marker" % [doc, lang])
			_check(not ("|---" in md) and not ("| ---" in md), "%s.%s has no markdown table" % [doc, lang])
			var bb: String = C.to_bbcode(md)
			_check(bb.count("[b]") == bb.count("[/b]"), "%s.%s bold tags balanced" % [doc, lang])
			_check(bb.count("[url=") == bb.count("[/url]"), "%s.%s link tags balanced" % [doc, lang])
	var sample: String = C.to_bbcode("# Title\n\n- one **bold** item\n\nSee [site](https://example.com) now.")
	_check("[font_size=36]" in sample and "  •  one [b]bold[/b] item" in sample and "[url=https://example.com]site[/url]" in sample, "markdown converts")
	_check(L.VERSION != "" and L.MIN_AGE == 13, "version and minimum age come from the legal build")

	# ---- the screens ----
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var screen = load("res://scenes/account/consent.tscn").instantiate()
	root.add_child(screen)
	for i in 4:
		await process_frame
	_check(screen.step == 0, "starts at the age gate")
	screen.month = 5
	screen.year = 2020
	screen._on_age_continue()
	for i in 3:
		await process_frame
	_check(screen._too_young and C.is_blocked(), "a 6-year-old is blocked at the gate")
	_check(screen.month == 0 and screen.year == 0, "date cleared from memory")
	screen.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	screen = load("res://scenes/account/consent.tscn").instantiate()
	root.add_child(screen)
	for i in 4:
		await process_frame
	screen.month = 2
	screen.year = 1995
	screen._on_age_continue()
	_check(screen.step == 1 and not screen._too_young, "an adult goes on to the Terms")
	screen._on_next()
	_check(screen.step == 2, "then the Privacy Policy as its own step")
	screen._on_next()
	_check(screen.step == 3, "then the tick boxes")
	for i in 3:
		await process_frame
	var go: Button = null
	var buttons := []
	_collect(screen, buttons)
	for btn in buttons:
		if (btn as Button).text == "Continuar" or (btn as Button).text == "Continue":
			go = btn
	_check(go != null and go.disabled, "Continue is off with both boxes unticked")
	screen._toggle_terms()
	_check(not C.has_accepted(), "one box is not enough")
	screen.ticked_terms = true
	screen.ticked_privacy = false
	screen._on_accept()
	_check(not C.has_accepted(), "accept refuses with only one box ticked")
	screen.ticked_privacy = true
	screen.ticked_terms = true
	C.return_scene = "res://scenes/hub/legal.tscn"  # stays in the test: never leaves the window
	screen._on_accept()
	_check(C.has_accepted(), "both ticked accepts")

	# ---- restore ----
	if had:
		var r := FileAccess.open(path, FileAccess.WRITE)
		r.store_string(backup)
		r.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS" if fails == 0 else "FAILED")
	quit(1 if fails > 0 else 0)

func _find_continue(_n: Node, _b) -> void:
	pass

func _collect(n: Node, into: Array) -> void:
	if n is Button:
		into.append(n)
	for c in n.get_children():
		_collect(c, into)
