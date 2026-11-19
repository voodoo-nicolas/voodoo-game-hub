extends Node

## Autoload `Store`: free trials, $0.99 games, the hub subscription and the
## hub's own promo cards (docs/monetization/PLAN.md -- the decisions live there).
## Since 2026-11-19 (docs/BILLING.md): games are $1/month subscriptions (3-day
## trial, ours), the hub $4.99/month (Play offer: 7-day free trial, then $2.99
## for 3 months). Product ids come from Config.STORE_*.
##
## Switched on by the live manifest, never by an app update:
##     "store": {"enabled": true, "trial_days": 3, "promos": true}
## Missing or `enabled: false` = every game plays, nothing is shown -- the
## behaviour of every app before the store. On a PC build, HUB_STORE=1
## forces it on and HUB_FAKE_BILLING=1 makes purchases succeed at once.
##
## - access(game) -> {state, allowed, left}. state is one of
##   "open" (store off), "free" (manifest "free": true), "subscribed", "owned",
##   "trial" (left = seconds), "trial_over", "new" (never tried), "signed_out"
##   (a paid game and no account -- trials need one, PLAN.md Decision 4).
## - gate(game, on_allowed): the hub's one check before opening a game; shows
##   the paywall (scripts/common/paywall.gd) when it isn't allowed. A guest
##   joining a friend's online room always gets in (PLAN.md "Online play").
## - start_trial(id), buy_game(id), subscribe(), restore(), manage_subscription().
## - promo_for(game_id, online) -> {} or a card for GameInfo to show at a game's end.
##
## The server (supabase/migrations/20261005000000_store.sql) is the source of
## truth: trials start on the server's clock (store_start_trial), purchases
## count once purchase-verify has checked them with Google. Everything is
## cached in user://store.json so offline play keeps working. The client is
## only a polite lock (the repo is public), so none of this is hardened.
##
## Games never reference Store (packs run on older apps): only the hub,
## Options, the paywall and GameInfo do.

const SaveUtil = preload("res://scripts/common/save_util.gd")
const Config = preload("res://scripts/common/config.gd")
const StoreBilling = preload("res://scripts/common/store_billing.gd")
const Brand = preload("res://scripts/common/brand.gd")
const PAYWALL_PATH := "res://scripts/common/paywall.gd"

const CACHE_PATH := "user://store.json"
const HUB_PRODUCT := Config.STORE_HUB_PRODUCT
const GAME_PREFIX := "game_"
const GAME_SUFFIX := "_monthly"
const DEFAULT_TRIAL_DAYS := 3
## Don't ask the server more often than this (hub visits, app resumes).
const REFRESH_SEC := 300
## Shown until Play tells us the player's own prices (and on PC builds).
const FALLBACK_PRICES := {"game": "$1.00", HUB_PRODUCT: "$4.99",
		HUB_PRODUCT + ":intro": "$2.99", HUB_PRODUCT + ":trial_days": 7}
const INTRO_MONTHS := 3
const SUBSCRIPTIONS_URL := "https://play.google.com/store/account/subscriptions?sku=%s&package=%s"
const PACKAGE := Config.PLAY_PACKAGE
## Promo cards: at most one per this many finished games, and this far apart.
const PROMO_EVERY := 3
const PROMO_GAP_SEC := 600
## States that open the game.
const ALLOWED := ["open", "free", "subscribed", "owned", "trial"]

## Anything that changes what a player may play (status fetched, trial
## started, purchase verified, signed in/out). Screens just redraw.
signal changed()
## A purchase didn't go through; `message` is ready to show.
signal purchase_failed(message: String)
## A purchase was verified (product id).
signal purchase_done(product_id: String)

## {now, trials: {game: unix}, entitlements: [{product_id, kind, game, state, expires}],
##  user, fetched (local unix at fetch)}
var status: Dictionary = {}
var prices: Dictionary = {}
var billing: Node
## Trials started while offline, still to tell the server: [game ids].
var _pending_trials: Array = []
## Purchases not yet verified (offline, server down): {token: product_id}.
var _pending_purchases: Dictionary = {}
var _promo: Dictionary = {"games": 0, "last": 0}
var _last_fetch_msec: int = -1000000
var _fetching: bool = false
var _verifying: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	billing = StoreBilling.new()
	add_child(billing)
	billing.prices_ready.connect(_on_prices)
	billing.purchased.connect(_on_purchased)
	billing.failed.connect(_on_billing_failed)
	billing.restored.connect(_on_restored)
	_load()
	Auth.signed_in.connect(_on_signed_in.unbind(2))
	Auth.signed_out.connect(_on_signed_out)
	Catalog.catalog_changed.connect(_on_catalog_changed)
	if enabled():
		refresh(true)
		_ask_prices()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if enabled():
			refresh()

# ---------- switches ----------

func config() -> Dictionary:
	var c: Dictionary = {"enabled": false, "trial_days": DEFAULT_TRIAL_DAYS, "promos": true}
	var live = Catalog.get("store_config")
	if live is Dictionary:
		c.merge(live, true)
	if OS.get_environment("HUB_STORE") == "1":
		c["enabled"] = true
	return c

func enabled() -> bool:
	return bool(config().enabled)

# ---------- who may play what ----------

func access(game: Dictionary) -> Dictionary:
	return access_state(game, status, server_now(), config(), Auth.is_logged_in())

## Pure, for tools/test_store.gd. See the header for the states.
static func access_state(game: Dictionary, st: Dictionary, now: int, cfg: Dictionary, logged_in: bool) -> Dictionary:
	var id := str(game.get("id", ""))
	if not bool(cfg.get("enabled", false)) or id == "":
		return {"state": "open", "allowed": true, "left": 0}
	if bool(game.get("free", false)):
		return {"state": "free", "allowed": true, "left": 0}
	for e in st.get("entitlements", []):
		if e is Dictionary and str(e.get("kind", "")) == "hub" and _live(e, now):
			return {"state": "subscribed", "allowed": true, "left": 0}
	for e in st.get("entitlements", []):
		if e is Dictionary and str(e.get("kind", "")) == "game" and str(e.get("game", "")) == id and _live(e, now):
			return {"state": "owned", "allowed": true, "left": 0}
	if not logged_in:
		return {"state": "signed_out", "allowed": false, "left": 0}
	var trials: Dictionary = st.get("trials", {})
	if trials.has(id):
		var left: int = int(trials[id]) + int(cfg.get("trial_days", DEFAULT_TRIAL_DAYS)) * 86400 - now
		if left > 0:
			return {"state": "trial", "allowed": true, "left": left}
		return {"state": "trial_over", "allowed": false, "left": 0}
	return {"state": "new", "allowed": false, "left": 0}

## The server already dropped dead entitlements; this catches one that ran
## out since (a canceled subscription's last day, played offline).
static func _live(e: Dictionary, now: int) -> bool:
	if str(e.get("state", "")) == "grace":
		return true
	var exp = e.get("expires", null)
	return exp == null or int(exp) > now

func is_subscribed() -> bool:
	return access_state({"id": "_any"}, status, server_now(), {"enabled": true}, true).state == "subscribed"

## The subscription entitlement ({} if none): expires, state ("canceled" = won't renew).
func subscription() -> Dictionary:
	for e in status.get("entitlements", []):
		if e is Dictionary and str(e.get("kind", "")) == "hub" and _live(e, server_now()):
			return e
	return {}

## The server's clock as best we know it: what it said at the last fetch plus
## the time since. Never earlier than that answer, so setting the phone's
## clock back doesn't rewind a trial.
func server_now() -> int:
	var local := int(Time.get_unix_time_from_system())
	if int(status.get("now", 0)) <= 0:
		return local
	var est: int = int(status.now) + local - int(status.get("fetched", local))
	return maxi(int(status.now), est)

## A short tile tag for the hub ({} = keep the usual Play / Download tag):
## {text, color} where color is a Settings.palette() key.
func badge(game: Dictionary) -> Dictionary:
	if not enabled() or not game.has("id"):
		return {}
	var a := access(game)
	match a.state:
		"trial":
			return {"text": tr("⏳ %s left") % left_text(a.left), "color": "update"}
		"trial_over":
			return {"text": tr("🔒 Unlock"), "color": "accent"}
		"new", "signed_out":
			return {"text": tr("✨ Try free"), "color": "link"}
	return {}

## "2 days" / "5 hours" / "20 min".
static func left_text(secs: int) -> String:
	var tr_ := func(s: String) -> String: return str(TranslationServer.translate(s))
	if secs >= 2 * 86400:
		return tr_.call("%d days") % (secs / 86400)
	if secs >= 2 * 3600:
		return tr_.call("%d hours") % (secs / 3600)
	return tr_.call("%d min") % maxi(1, secs / 60)

# ---------- the gate ----------

## Calls on_allowed straight away when the game may be played; otherwise opens
## the paywall, which calls it once a trial starts or a purchase lands.
func gate(game: Dictionary, on_allowed: Callable) -> void:
	if access(game).allowed or _joining_friend(str(game.get("id", ""))):
		on_allowed.call()
		return
	open_paywall(game, on_allowed)

## Paywall over the current screen. `game` may be {} (Options' "Get all games").
func open_paywall(game: Dictionary, on_allowed: Callable = Callable()) -> void:
	var scene := get_tree().current_scene
	if scene == null or not ResourceLoader.exists(PAYWALL_PATH):
		return
	scene.add_child(load(PAYWALL_PATH).new(game, on_allowed))

## A guest invited into (or joining) a friend's room plays that match free.
func _joining_friend(id: String) -> bool:
	var social = get_node_or_null("/root/Social")
	if social == null:
		return false
	var p = social.get("pending")
	return p is Dictionary and str(p.get("game", "")) == id and str(p.get("mode", "")) == "join"

# ---------- server ----------

func refresh(force: bool = false) -> void:
	if not Auth.is_logged_in() or _fetching:
		return
	if not force and Time.get_ticks_msec() - _last_fetch_msec < REFRESH_SEC * 1000:
		return
	_fetching = true
	Auth.db_call("store_status", {}, _on_status)

func _on_status(ok: bool, result: Variant) -> void:
	_fetching = false
	if not ok or not result is Dictionary or not result.has("now"):
		return  # offline, or the store's SQL isn't there yet: keep the cache
	_last_fetch_msec = Time.get_ticks_msec()
	_apply_status(result)
	for id in _pending_trials.duplicate():
		start_trial(id)
	for token in _pending_purchases.keys():
		_verify(str(_pending_purchases[token]), str(token))

func _apply_status(s: Dictionary) -> void:
	var fresh: Dictionary = s.duplicate(true)
	fresh["user"] = Auth.user_id
	fresh["fetched"] = int(Time.get_unix_time_from_system())
	# Trials started offline aren't on the server yet; keep their local start.
	var trials: Dictionary = fresh.get("trials", {})
	for id in _pending_trials:
		if not trials.has(id) and status.get("trials", {}).has(id):
			trials[id] = status.trials[id]
	fresh["trials"] = trials
	# Fake (PC test) purchases never reach the server.
	for e in status.get("entitlements", []):
		if e is Dictionary and e.get("fake", false):
			fresh.entitlements.append(e)
	status = fresh
	_save()
	changed.emit()

## Starts this game's free trial (signed in only). The server's start time
## wins; offline, it starts now on this phone and tells the server later.
func start_trial(id: String, on_done: Callable = Callable()) -> void:
	if not Auth.is_logged_in():
		_done(on_done, false)
		return
	Auth.db_call("store_start_trial", {"p_game": id}, _on_trial_started.bind(id, on_done))

func _on_trial_started(ok: bool, result: Variant, id: String, on_done: Callable) -> void:
	if not status.has("trials"):
		status["trials"] = {}
	if ok and (result is float or result is int):
		status.trials[id] = int(result)
		_pending_trials.erase(id)
	elif not status.trials.has(id):
		status.trials[id] = server_now()
		if not _pending_trials.has(id):
			_pending_trials.append(id)
	_save()
	changed.emit()
	_done(on_done, true)

# ---------- buying ----------

func game_product(id: String) -> String:
	return Config.STORE_GAME_PRODUCT % id

## "game_chess_monthly" -> "chess" ("" for the hub).
static func game_of(product_id: String) -> String:
	if product_id.begins_with(GAME_PREFIX) and product_id.ends_with(GAME_SUFFIX):
		return product_id.trim_prefix(GAME_PREFIX).trim_suffix(GAME_SUFFIX)
	return ""

## Play's own trial for the hub subscription, in days (0 = this Google
## account already used it).
func hub_trial_days() -> int:
	return int(prices.get(HUB_PRODUCT + ":trial_days", FALLBACK_PRICES[HUB_PRODUCT + ":trial_days"]))

## The date a trial started now would end ("Nov 26, 2026"), or the date this
## game's running trial ends when `game` is given.
func trial_end_text(days: int, game: Dictionary = {}) -> String:
	var end := server_now() + days * 86400
	if not game.is_empty():
		var a := access(game)
		if a.state == "trial":
			end = server_now() + int(a.left)
	return Time.get_date_string_from_unix_time(end)

func price(product_id: String) -> String:
	if prices.has(product_id):
		return str(prices[product_id])
	if FALLBACK_PRICES.has(product_id):
		return str(FALLBACK_PRICES[product_id])
	return str(FALLBACK_PRICES.game)

## "7 days free, then $2.99/month for 3 months, then $4.99/month" -- from the
## offer Play reports, or the planned one until it answers.
func subscription_terms() -> String:
	var parts: Array = []
	var trial := int(prices.get(HUB_PRODUCT + ":trial_days", FALLBACK_PRICES[HUB_PRODUCT + ":trial_days"]))
	if trial > 0:
		parts.append(tr("%d days free") % trial)
	var intro := str(prices.get(HUB_PRODUCT + ":intro", FALLBACK_PRICES[HUB_PRODUCT + ":intro"]))
	if intro != "":
		parts.append(tr("%s/month for %d months") % [intro, INTRO_MONTHS])
	parts.append(tr("%s/month") % price(HUB_PRODUCT))
	return tr(", then ").join(parts)

func can_buy() -> bool:
	return billing.available

func buy_game(id: String) -> void:
	_start_purchase(game_product(id), true)  # a $1/month subscription since 2026-11-19

func subscribe() -> void:
	_start_purchase(HUB_PRODUCT, true)

func _start_purchase(product_id: String, sub: bool) -> void:
	if not Auth.is_logged_in():
		purchase_failed.emit(tr("Sign in first, so your purchase follows you to every device."))
		return
	if not billing.available:
		purchase_failed.emit(tr("Purchases work in the Play Store version of %s.") % Brand.NAME)
		return
	if sub:
		billing.subscribe(product_id, Auth.user_id)
	else:
		billing.buy(product_id, Auth.user_id)

func restore() -> void:
	if not Auth.is_logged_in():
		purchase_failed.emit(tr("Sign in first, so your purchase follows you to every device."))
		return
	refresh(true)
	billing.restore()

func manage_subscription() -> void:
	if not billing.open_subscriptions(HUB_PRODUCT):
		OS.shell_open(SUBSCRIPTIONS_URL % [HUB_PRODUCT, PACKAGE])

func _ask_prices() -> void:
	if not billing.available:
		return
	var ids: Array = []
	for cat in Catalog.categories:
		for g in cat.get("games", []):
			if g.has("id") and not bool(g.get("free", false)):
				ids.append(game_product(str(g.id)))
	billing.query_prices(ids, HUB_PRODUCT)

func _on_prices(p: Dictionary) -> void:
	prices.merge(p, true)
	changed.emit()

func _on_purchased(product_id: String, token: String) -> void:
	if token.begins_with("fake-"):
		_grant_fake(product_id)
		return
	_pending_purchases[token] = product_id
	_save()
	_verify(product_id, token)

func _on_billing_failed(message: String, cancelled: bool) -> void:
	if cancelled:
		purchase_failed.emit("")
	elif message == "unavailable":
		purchase_failed.emit(tr("Purchases work in the Play Store version of %s.") % Brand.NAME)
	elif message == "pending":
		purchase_failed.emit(tr("Your payment is still pending. The game unlocks as soon as Google confirms it."))
	else:
		purchase_failed.emit(tr("Google Play couldn't finish the purchase. Try again in a moment."))

func _on_restored(found: int) -> void:
	if found == 0:
		purchase_failed.emit(tr("No purchases found for this Google account."))
	else:  # each one is being re-checked by purchase-verify; Store.changed follows
		purchase_failed.emit(tr("Found %d purchase(s). Syncing them to your account...") % found)

## Asks purchase-verify to check the token with Google. A refusal (4xx) drops
## it; no answer keeps it for the next refresh, so a purchase is never lost.
func _verify(product_id: String, token: String) -> void:
	if _verifying.has(token) or not Auth.is_logged_in():
		return
	_verifying[token] = true
	var http := HTTPRequest.new()
	http.timeout = 25.0
	add_child(http)
	http.request_completed.connect(_on_verified.bind(http, product_id, token))
	var headers := PackedStringArray([
		"apikey: " + Config.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + Auth.access_token,
		"Content-Type: application/json",
	])
	var body := JSON.stringify({"product_id": product_id, "token": token})
	if http.request(Config.SUPABASE_URL + "/functions/v1/purchase-verify", headers, HTTPClient.METHOD_POST, body) != OK:
		http.queue_free()
		_verifying.erase(token)

func _on_verified(result: int, code: int, _h: PackedStringArray, raw: PackedByteArray, http: HTTPRequest,
		product_id: String, token: String) -> void:
	http.queue_free()
	_verifying.erase(token)
	if result != HTTPRequest.RESULT_SUCCESS or code >= 500 or code == 401:
		return  # try again on the next refresh (401: token expired mid-flight)
	_pending_purchases.erase(token)
	var data = JSON.parse_string(raw.get_string_from_utf8())
	if code >= 200 and code < 300 and data is Dictionary and data.get("status") is Dictionary:
		_apply_status(data.status)
		purchase_done.emit(product_id)
		return
	_save()
	var err := str(data.get("error", "")) if data is Dictionary else ""
	if err == "pending":
		purchase_failed.emit(tr("Your payment is still pending. The game unlocks as soon as Google confirms it."))
		_pending_purchases[token] = product_id  # check again later
		_save()
	else:
		purchase_failed.emit(tr("This purchase couldn't be confirmed. If you were charged, use Restore purchases."))

func _grant_fake(product_id: String) -> void:
	if not status.has("entitlements"):
		status["entitlements"] = []
	var hub := product_id == HUB_PRODUCT
	status.entitlements.append({"product_id": product_id, "kind": "hub" if hub else "game",
			"game": null if hub else game_of(product_id), "state": "active",
			"expires": server_now() + 30 * 86400, "fake": true})  # games are monthly too
	changed.emit()
	purchase_done.emit(product_id)

# ---------- promo cards ----------

## Called by GameInfo when a game ends. Returns {} (most of the time) or a
## card: {kind: "sub", text, action} or {kind: "try", game, text}.
func promo_for(game_id: String, online: bool = false) -> Dictionary:
	if not enabled() or not bool(config().promos) or online:
		return {}
	_promo.games = int(_promo.get("games", 0)) + 1
	var now := int(Time.get_unix_time_from_system())
	var p := promo_pick(game_id, _promo, now, is_subscribed(), Auth.is_logged_in() and billing.available,
			_category_mates(game_id), access(Catalog.get_game(game_id)).state)
	if not p.is_empty():
		_promo = {"games": 0, "last": now}
	_save()
	return p

## Pure, for tools/test_store.gd. mates = [{id, title...}] untried games of
## the same category the player could open (free, trial, owned or new).
static func promo_pick(_game_id: String, counters: Dictionary, now: int, subscribed: bool, can_sell: bool,
		mates: Array, game_state: String) -> Dictionary:
	var every := PROMO_EVERY * (2 if subscribed else 1)  # members see fewer, and never a sales pitch
	if int(counters.get("games", 0)) < every or now - int(counters.get("last", 0)) < PROMO_GAP_SEC:
		return {}
	if can_sell and not subscribed:
		return {"kind": "sub", "owned": game_state == "owned"}
	if not mates.is_empty():
		return {"kind": "try", "game": mates[now % mates.size()]}
	return {}

## Same-category games never played (no stats file yet) that would open.
func _category_mates(game_id: String) -> Array:
	var out: Array = []
	for cat in Catalog.categories:
		var ids: Array = []
		for g in cat.get("games", []):
			ids.append(str(g.get("id", "")))
		if not ids.has(game_id):
			continue
		for g in cat.get("games", []):
			var id := str(g.get("id", ""))
			if id == "" or id == game_id or FileAccess.file_exists("user://stats_%s.json" % id):
				continue
			if access(g).state in ["trial_over"]:
				continue
			out.append(g)
	return out

## The number of real games, for "All 100 games".
func game_count() -> int:
	var n := 0
	for cat in Catalog.categories:
		for g in cat.get("games", []):
			if g.has("id"):
				n += 1
	return n

# ---------- account changes, cache ----------

func _on_signed_in() -> void:
	status = {}
	_pending_trials.clear()
	_load()
	if enabled():
		refresh(true)

func _on_signed_out() -> void:
	status = {}
	_pending_trials.clear()
	_pending_purchases.clear()
	_save()
	changed.emit()

func _on_catalog_changed() -> void:
	# The live manifest may have just switched the store on.
	if enabled():
		refresh()
		if prices.is_empty():
			_ask_prices()
	changed.emit()

func _load() -> void:
	var data = SaveUtil.read(CACHE_PATH)
	if not data is Dictionary:
		return
	if data.get("promo") is Dictionary:
		_promo = data.promo
	# Another account's cache is no use to this one.
	if str(data.get("user", "")) != Auth.user_id or Auth.user_id == "":
		return
	if data.get("status") is Dictionary:
		status = data.status
	if data.get("pending_trials") is Array:
		_pending_trials = data.pending_trials
	if data.get("pending_purchases") is Dictionary:
		_pending_purchases = data.pending_purchases

func _save() -> void:
	var keep: Dictionary = status.duplicate(true)
	var real: Array = []
	for e in keep.get("entitlements", []):
		if not (e is Dictionary and e.get("fake", false)):
			real.append(e)
	keep["entitlements"] = real
	SaveUtil.write(CACHE_PATH, {"user": Auth.user_id, "status": keep, "pending_trials": _pending_trials,
			"pending_purchases": _pending_purchases, "promo": _promo})

static func _done(cb: Callable, ok: bool) -> void:
	if cb.is_valid():
		cb.call(ok)
