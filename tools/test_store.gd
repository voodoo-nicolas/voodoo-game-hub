extends SceneTree

## Headless test for the store (scripts/common/store.gd, paywall.gd, the
## hub's tile tags and GameInfo's promo card):
##   godot --headless --path . --script res://tools/test_store.gd
## Switches the store on in memory only (Catalog.store_config) and puts
## user://store.json back afterwards; never talks to the server or Play.

const DAY := 86400
const CACHE_PATH := "user://store.json"
## Loaded at run time: store.gd and paywall.gd name the Auth / Settings
## autoloads, which a --script test's preloads can't see yet.
var StoreScript: Script
var Paywall: Script

var fails := 0

func _initialize() -> void:
	_run()

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _run() -> void:
	await process_frame
	StoreScript = root.get_node("Store").get_script()
	Paywall = load("res://scripts/common/paywall.gd")
	var locale_before := TranslationServer.get_locale()
	TranslationServer.set_locale("en")  # the text checks are in English
	var cache_before := FileAccess.get_file_as_string(CACHE_PATH) if FileAccess.file_exists(CACHE_PATH) else ""
	_pure_rules()
	await _live_autoload()
	if cache_before != "":
		var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
		f.store_string(cache_before)
		f.close()
	else:
		DirAccess.remove_absolute(CACHE_PATH)
	TranslationServer.set_locale(locale_before)
	print("store tests: %s" % ("OK" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)

func _st(trials: Dictionary = {}, ents: Array = []) -> Dictionary:
	return {"now": 1000000, "trials": trials, "entitlements": ents}

func _pure_rules() -> void:
	var on := {"enabled": true, "trial_days": 3}
	var now := 1_000_000
	var chess := {"id": "chess"}
	var a := func(game: Dictionary, st: Dictionary, logged: bool = true, cfg: Dictionary = on, t: int = now) -> String:
		return StoreScript.access_state(game, st, t, cfg, logged).state

	# Switched off (or no manifest block): everything plays.
	ok(a.call(chess, _st(), true, {"enabled": false}) == "open", "store off = open")
	ok(StoreScript.access_state(chess, _st(), now, {}, false).allowed, "no config = allowed")
	# Free list, signed out or not.
	ok(a.call({"id": "snake", "free": true}, _st(), false) == "free", "free game, signed out")
	# Trials need an account.
	ok(a.call(chess, _st(), false) == "signed_out", "paid game signed out")
	ok(not StoreScript.access_state(chess, _st(), now, on, false).allowed, "signed out not allowed")
	ok(a.call(chess, _st()) == "new", "never tried")
	# Trial clock: 3 days from the server's start, to the second.
	var started := now - 2 * DAY
	var r: Dictionary = StoreScript.access_state(chess, _st({"chess": started}), now, on, true)
	ok(r.state == "trial" and r.allowed and r.left == DAY, "trial with a day left")
	ok(a.call(chess, _st({"chess": now - 3 * DAY})) == "trial_over", "trial ends at exactly 3 days")
	ok(a.call(chess, _st({"chess": now - 3 * DAY + 1})) == "trial", "one second before the end")
	ok(a.call(chess, _st({"chess": float(now - DAY)})) == "trial", "JSON floats from the cache")
	ok(a.call(chess, _st({"chess": now - 10 * DAY}), true, {"enabled": true, "trial_days": 14}) == "trial", "trial_days from the manifest")
	ok(a.call({"id": "hex"}, _st({"chess": now})) == "new", "trials are per game")
	# Purchases beat trials; the subscription beats everything.
	var owned := [{"kind": "game", "game": "chess", "state": "active", "expires": null}]
	ok(a.call(chess, _st({"chess": now - 9 * DAY}, owned)) == "owned", "bought after the trial")
	ok(a.call({"id": "pool"}, _st({}, owned)) == "new", "owning chess doesn't unlock pool")
	ok(a.call(chess, _st({}, owned), false) == "owned", "owned shows even signed out (cached)")
	var sub := [{"kind": "hub", "state": "active", "expires": now + 5 * DAY}]
	ok(a.call({"id": "pool"}, _st({}, sub)) == "subscribed", "subscription unlocks all")
	ok(a.call({"id": "pool"}, _st({}, sub), true, on, now + 6 * DAY) == "new", "lapsed subscription (offline)")
	ok(a.call({"id": "pool"}, _st({}, [{"kind": "hub", "state": "grace", "expires": now - DAY}])) == "subscribed", "grace period keeps access")
	ok(a.call({"id": "pool"}, _st({}, [{"kind": "hub", "state": "active", "expires": null}])) == "subscribed", "lifetime grant")

	# Time left text.
	ok(StoreScript.left_text(2 * DAY + 5) == "2 days", "days left")
	ok(StoreScript.left_text(DAY + 3600) == "25 hours", "hours under 2 days")
	ok(StoreScript.left_text(30) == "1 min", "never 0 min")

	# Promo cards: frequency caps, members, who can be sold to.
	var mates := [{"id": "sky_hop", "title": "Sky Hop"}]
	var counters := {"games": 3, "last": now - 3600}
	ok(StoreScript.promo_pick("snake", {"games": 2, "last": 0}, now, false, true, mates, "trial").is_empty(), "not before 3 games")
	ok(StoreScript.promo_pick("snake", {"games": 9, "last": now - 60}, now, false, true, mates, "trial").is_empty(), "not within 10 minutes")
	ok(StoreScript.promo_pick("snake", counters, now, false, true, mates, "trial").kind == "sub", "sell the subscription")
	ok(StoreScript.promo_pick("snake", counters, now, false, true, mates, "owned").get("owned", false), "owners hear about the other games")
	ok(StoreScript.promo_pick("snake", counters, now, false, false, mates, "trial").kind == "try", "can't sell (signed out / no Play): cross-promo")
	ok(StoreScript.promo_pick("snake", counters, now, true, true, mates, "subscribed").is_empty(), "members: rarer")
	var p: Dictionary = StoreScript.promo_pick("snake", {"games": 6, "last": 0}, now, true, true, mates, "subscribed")
	ok(p.get("kind", "") == "try", "members never get a sales pitch")
	ok(StoreScript.promo_pick("snake", counters, now, true, true, [], "subscribed").is_empty(), "nothing to suggest")

func _live_autoload() -> void:
	var store = root.get_node_or_null("Store")
	var catalog = root.get_node_or_null("Catalog")
	ok(store != null and catalog != null, "Store and Catalog autoloads")
	if store == null:
		return
	ok(not store.enabled() or OS.get_environment("HUB_STORE") == "1", "off unless the manifest says so")
	var was: Dictionary = catalog.store_config
	catalog.store_config = {"enabled": true, "trial_days": 3, "promos": true}
	ok(store.enabled(), "manifest switch")
	ok(store.game_count() >= 100, "game count from the catalog")
	# Since 2026-11-19: every game $1/month, hub $4.99 (docs/BILLING.md).
	ok(store.price(store.game_product("chess")) == "$1.00" and store.price(store.HUB_PRODUCT) == "$4.99", "fallback prices")
	ok(store.game_product("voodoo_iq") == "game_voodoo_iq_monthly" and store.game_of("game_voodoo_iq_monthly") == "voodoo_iq"
			and store.game_of("hub_monthly") == "", "product ids")
	ok(store.trial_end_text(3) != "", "trial end date")
	ok(store.subscription_terms() == "7 days free, then $2.99/month for 3 months, then $4.99/month", "subscription terms: " + store.subscription_terms())

	# server_now never runs behind the server's last answer.
	var saved_status: Dictionary = store.status
	var local := int(Time.get_unix_time_from_system())
	store.status = {"now": local + 5000, "fetched": local, "trials": {}, "entitlements": []}
	ok(store.server_now() >= local + 5000, "clock behind the server")
	store.status = {"now": local - 100, "fetched": local + 9999, "trials": {}, "entitlements": []}
	ok(store.server_now() == local - 100, "phone clock set back")

	# Tile tags.
	store.status = {"now": local, "fetched": local, "trials": {"chess": local - DAY}, "entitlements": []}
	var logged: bool = root.get_node("Auth").is_logged_in()
	var chess: Dictionary = catalog.get_game("chess")
	if logged:
		ok(str(store.badge(chess).get("text", "")).begins_with("⏳"), "trial tag")
	else:
		ok(str(store.badge(chess).get("text", "")) == "✨ Try free", "signed-out tag")

	# The paywall builds in every state without errors.
	var holder := Control.new()
	root.add_child(holder)
	for st in [{"trials": {}}, {"trials": {"chess": local - 9 * DAY}}, {"trials": {"chess": local - DAY}}]:
		store.status = {"now": local, "fetched": local, "trials": st.trials, "entitlements": []}
		var pw = Paywall.new(chess, Callable())
		holder.add_child(pw)
		await process_frame
		ok(pw.box != null and pw.box.get_child_count() >= 3, "paywall built (%s)" % store.access(chess).state)
		pw.queue_free()
	var hub_pw = Paywall.new({}, Callable())
	holder.add_child(hub_pw)
	await process_frame
	ok(hub_pw.box.get_child_count() >= 3, "membership paywall built")
	holder.queue_free()

	store.status = saved_status
	catalog.store_config = was
	await process_frame
