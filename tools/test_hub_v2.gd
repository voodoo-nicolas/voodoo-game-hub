extends SceneTree

## Hub v2 behaviours: browser filter combinations + search, Reduce motion,
## and the delete-account confirmation (never actually deletes).
##   godot --headless --path . --script res://tools/test_hub_v2.gd
## Friend removal: tools/test_friends_ui.gd. XP: tools/test_xp.gd.

var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: " + msg)
		fails += 1

func _ids(hub) -> Array:
	var out := []
	for g in hub._filtered_games():
		out.append(str(g.id))
	return out

func _initialize() -> void:
	var settings = root.get_node("Settings")
	var hub = load("res://scenes/hub/hub.tscn").instantiate()
	root.add_child(hub)
	for i in 5:
		await process_frame

	# ---- filters combine (all must match), and with search ----
	hub.chips = {}
	var all := _ids(hub)
	hub.chips = {"quick": true}
	var quick := _ids(hub)
	hub.chips = {"original": true}
	var original := _ids(hub)
	hub.chips = {"quick": true, "original": true}
	var both := _ids(hub)
	var inter := quick.filter(func(id): return original.has(id))
	_check(not all.is_empty() and quick.size() < all.size(), "quick narrows the list")
	_check(both.size() == inter.size() and both.all(func(id): return inter.has(id)), "quick + original = the intersection (%d)" % both.size())
	hub.chips = {"single": true, "two": true}
	var solo_two := _ids(hub)
	hub.chips = {"single": true}
	var solo := _ids(hub)
	hub.chips = {"two": true}
	var two := _ids(hub)
	_check(solo_two.all(func(id): return solo.has(id) and two.has(id)), "Solo + 2 Player only lists games in both")
	hub.chips = {"quick": true}
	hub.search_box.text = "zzzz-no-such-game"
	_check(_ids(hub).is_empty(), "search with no match is empty even with a chip on")
	hub.search_box.text = ""
	hub.chips = {"fav": true, "unplayed": true, "learn": true}
	var weird := _ids(hub)
	for id in weird:
		_check(not (root.get_node("Catalog").get_game(id).get("learn", []) as Array).is_empty(), "Learn chip: %s teaches nothing" % id)
	hub.chips = {}

	# ---- reduce motion ----
	var HubFx = load("res://scripts/common/hub_fx.gd")
	var was: bool = settings.reduce_motion
	settings.reduce_motion = true
	var still := Control.new()
	root.add_child(still)
	HubFx.stagger_in([still])
	_check(is_equal_approx(still.modulate.a, 1.0) and still.scale == Vector2.ONE, "reduce motion: no entrance animation")
	settings.reduce_motion = false
	var moving := Control.new()
	root.add_child(moving)
	HubFx.stagger_in([moving])
	_check(is_equal_approx(moving.modulate.a, 0.0), "motion on: entrance starts from invisible")
	_check(is_equal_approx(settings.anim_time(0.5), 0.5), "anim_time passes through when motion is on")
	settings.reduce_motion = true
	_check(is_equal_approx(settings.anim_time(0.5), 0.0), "anim_time is 0 with reduce motion")
	settings.reduce_motion = was
	still.queue_free()
	moving.queue_free()
	hub.queue_free()

	# ---- delete account: the confirm button needs the tag or DELETE ----
	var profile = load("res://scenes/hub/profile.tscn").instantiate()
	root.add_child(profile)
	for i in 4:
		await process_frame
	profile._on_delete_pressed()
	for i in 3:
		await process_frame
	var edits := []
	_find(profile, LineEdit, edits)
	var buttons := []
	_find(profile, Button, buttons)
	var confirm: Button = null
	for b in buttons:
		if (b as Button).disabled and (b as Button).text.contains("account") or ((b as Button).disabled and (b as Button).text.contains("cuenta")):
			confirm = b
	_check(not edits.is_empty() and confirm != null, "delete dialog has a text box and a disabled confirm button")
	if confirm != null and not edits.is_empty():
		var edit: LineEdit = edits[edits.size() - 1]
		edit.text_changed.emit("something else")
		_check(confirm.disabled, "wrong text keeps Delete off")
		edit.text_changed.emit("delete")
		_check(not confirm.disabled, "DELETE (any case) turns it on")
		edit.text_changed.emit("")
		_check(confirm.disabled, "emptying it turns it off again")
	print("PASS" if fails == 0 else "FAILED")
	quit(1 if fails > 0 else 0)

func _find(n: Node, type, into: Array) -> void:
	if is_instance_of(n, type):
		into.append(n)
	for c in n.get_children():
		_find(c, type, into)
