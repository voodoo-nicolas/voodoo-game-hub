extends Node

## Google Play Billing for the `Store` autoload -- the only file that talks to
## the billing plugin (godot-sdk-integrations/godot-google-play-billing, its
## `BillingClient` class in addons/). Store only sees the signals below.
##
## Three modes:
## - "play": the plugin is installed and this is an Android build (Play builds
##   only -- Play Billing refuses apps that weren't installed from Play).
## - "fake": HUB_FAKE_BILLING=1 on a PC build -- purchases succeed at once
##   with "fake-..." tokens, so the paywall and promos can be tried for real.
## - "none": everything else (PC, sideloaded APK, tests): `available` is false
##   and the paywall says purchases need the Play Store version.
##
## Plugin 3.3.0 (Billing Library 9.1) is in addons/; its key names were
## checked against its Utils.kt. It is still load()ed by path, never named as
## a class, and "play" also needs its Android singleton, which only a Gradle
## build with the plugin enabled has -- the sideloaded APK stays "none".

const SINGLETON := "GodotGooglePlayBilling"
const PLUGIN_PATHS := [
	"res://addons/GodotGooglePlayBilling/BillingClient.gd",
	"res://addons/GodotGooglePlayBilling/billing_client.gd",
]
## BillingClient.ProductType values.
const INAPP := 0
const SUBS := 1
## The subscriptions' base plan in Play Console (Config.STORE_BASE_PLAN).
const BASE_PLAN := "monthly"
## BillingClient.PurchaseState.PENDING.
const PENDING := 2

## Prices as Play formats them for this player ("$0.99", "US$ 4,99"...):
## {product_id: price}, plus "<sub>:intro" / "<sub>:trial_days" when the
## subscription has an intro price / free trial offer.
signal prices_ready(prices: Dictionary)
## A purchase finished (or was found by restore) and needs verifying.
signal purchased(product_id: String, token: String)
## A purchase didn't happen. `cancelled` is true when the player backed out.
signal failed(message: String, cancelled: bool)
## Restore finished; `found` purchases were also sent through `purchased`.
signal restored(found: int)

var mode: String = "none"
var available: bool = false
var _client = null
var _ready_client: bool = false
var _queued: Array = []        # Callables waiting for the connection
var _restore_left: int = 0
var _restore_found: int = 0
var _sub_offers: Dictionary = {}  # base plan / offer ids from product details
## The subscription offer to buy ("" = the base plan at full price). Play only
## lists offers this Google account may still use, and the plugin applies an
## offer only when named, so the best listed one is picked here.
var _sub_offer_id: String = ""
## Since 2026-11-19 every product is a subscription: the chosen offer per
## product id (the single _sub_offer_id above was the hub's only).
var _offer_ids: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("HUB_FAKE_BILLING") == "1":
		mode = "fake"
		available = true
		return
	if OS.get_name() != "Android" or not Engine.has_singleton(SINGLETON):
		return
	for path in PLUGIN_PATHS:
		if ResourceLoader.exists(path):
			_client = load(path).new()
			break
	if _client == null:
		return
	mode = "play"
	available = true
	if _client is Node:
		add_child(_client)
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_product_details)
	_client.query_purchases_response.connect(_on_purchases)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.start_connection()

# ---------- what Store calls ----------

func query_prices(game_products: Array, sub_product: String) -> void:
	if mode == "fake":
		var prices := {sub_product: "$4.99", sub_product + ":intro": "$2.99", sub_product + ":trial_days": 7}
		for id in game_products:
			prices[id] = "$1.00"
		prices_ready.emit.call_deferred(prices)
		return
	_when_ready(func():
		# All subscriptions now (games too): one query.
		_client.query_product_details(PackedStringArray(game_products + [sub_product]), SUBS))

func buy(product_id: String, account_id: String) -> void:
	if mode == "fake":
		purchased.emit.call_deferred(product_id, "fake-%s-%d" % [product_id, Time.get_ticks_usec()])
		return
	_when_ready(func():
		_client.set_obfuscated_account_id(account_id)
		_check_launch(_client.purchase(product_id)))

func subscribe(product_id: String, account_id: String) -> void:
	if mode == "fake":
		purchased.emit.call_deferred(product_id, "fake-%s-%d" % [product_id, Time.get_ticks_usec()])
		return
	_when_ready(func():
		_client.set_obfuscated_account_id(account_id)
		# The 7-day trial + intro price offer while this account may use it
		# (once per Google account); the plain base plan after that.
		_check_launch(_client.purchase_subscription(product_id, str(_sub_offers.get("base_plan", BASE_PLAN)),
				str(_offer_ids.get(product_id, "")))))

func restore() -> void:
	if mode == "fake":
		restored.emit.call_deferred(0)
		return
	_when_ready(func():
		_restore_left = 2
		_restore_found = 0
		_client.query_purchases(INAPP)
		_client.query_purchases(SUBS))

func open_subscriptions(product_id: String) -> bool:
	if mode != "play":
		return false
	_client.open_subscriptions_page(product_id)
	return true

# ---------- plugin replies ----------

func _when_ready(action: Callable) -> void:
	if not available:
		failed.emit("unavailable", false)
		return
	if _ready_client:
		action.call()
	else:
		_queued.append(action)
		if _client.has_method("start_connection") and _queued.size() == 1:
			_client.start_connection()

func _on_connected() -> void:
	_ready_client = true
	var q := _queued
	_queued = []
	for a in q:
		a.call()

func _on_disconnected() -> void:
	_ready_client = false

func _on_connect_error(_code: int, message: String) -> void:
	_ready_client = false
	_queued.clear()
	failed.emit(message, false)

func _check_launch(r) -> void:
	if r is Dictionary and int(r.get("response_code", 0)) != 0:
		failed.emit(str(r.get("debug_message", "")), int(r.response_code) == 1)

func _on_product_details(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != 0:
		return
	var prices := {}
	for d in r.get("product_details", []):
		if not d is Dictionary:
			continue
		var id := str(d.get("product_id", d.get("id", "")))
		var ones = d.get("one_time_purchase_offer_details_list", null)
		if ones is Array:
			for one in ones:  # the plain purchase option, not a discount offer
				if one is Dictionary and (one.get("offer_id") == null or prices.get(id, "") == ""):
					prices[id] = str(one.get("formatted_price", ""))
		var offers = d.get("subscription_offer_details", null)
		if offers is Array:
			# Only what Play lists counts: no trial offer = this account used it.
			prices[id + ":trial_days"] = 0
			prices[id + ":intro"] = ""
			# The terms shown are the chosen offer's, so they match the charge.
			_sub_offer_id = ""
			_offer_ids[id] = ""
			var best := 0
			var chosen := {}
			for offer in offers:
				if offer is Dictionary:
					var terms := {}
					var score := _read_offer(id, offer, terms)
					if terms.has(id):
						prices[id] = terms[id]
					if score > best and offer.get("offer_id") != null:
						best = score
						_sub_offer_id = str(offer.offer_id)
						_offer_ids[id] = _sub_offer_id
						chosen = terms
			for k in [id + ":trial_days", id + ":intro"]:
				if chosen.has(k):
					prices[k] = chosen[k]
	if not prices.is_empty():
		prices_ready.emit(prices)

## A subscription offer's pricing phases: free (trial), then intro, then the
## full price (the base plan's last, infinitely recurring phase). Returns how
## good a deal the offer is (2 per free phase, 1 per intro phase).
func _read_offer(id: String, offer: Dictionary, prices: Dictionary) -> int:
	_sub_offers["base_plan"] = str(offer.get("base_plan_id", BASE_PLAN))
	var score := 0
	var phases = offer.get("pricing_phases", [])
	if phases is Dictionary:
		phases = phases.get("pricing_phase_list", [])
	for ph in phases:
		if not ph is Dictionary:
			continue
		var micros := int(ph.get("price_amount_micros", -1))
		var price := str(ph.get("formatted_price", ""))
		var period := str(ph.get("billing_period", ""))
		if micros == 0:
			prices[id + ":trial_days"] = _period_days(period)
			score += 2
		elif int(ph.get("recurrence_mode", 0)) == 1:  # INFINITE_RECURRING
			prices[id] = price
		elif micros > 0:
			prices[id + ":intro"] = price
			score += 1
	return score

## ISO 8601 period ("P7D", "P1W", "P1M") in days, roughly.
static func _period_days(p: String) -> int:
	var n := int(p.substr(1, p.length() - 2))
	match p.right(1):
		"D": return n
		"W": return n * 7
		"M": return n * 30
	return 0

func _on_purchase_updated(r: Dictionary) -> void:
	var code := int(r.get("response_code", -1))
	if code != 0:
		failed.emit(str(r.get("debug_message", "")), code == 1)  # 1 = USER_CANCELED
		return
	if _emit_purchases(r.get("purchases", [])) == 0 and _has_pending(r.get("purchases", [])):
		failed.emit("pending", false)

func _has_pending(list) -> bool:
	if list is Array:
		for p in list:
			if p is Dictionary and int(p.get("purchase_state", 0)) == PENDING:
				return true
	return false

func _on_purchases(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) == 0:
		_restore_found += _emit_purchases(r.get("purchases", []))
	_restore_left -= 1
	if _restore_left == 0:
		restored.emit(_restore_found)

## Only completed purchases (a pending one, e.g. cash at a shop, arrives again
## through on_purchase_updated once paid). Returns how many were sent.
func _emit_purchases(list) -> int:
	var n := 0
	if not list is Array:
		return 0
	for p in list:
		if not p is Dictionary:
			continue
		var state = p.get("purchase_state", 1)
		if int(state) != 1:  # PurchaseState.PURCHASED
			continue
		var ids = p.get("product_ids", p.get("products", []))
		var token := str(p.get("purchase_token", ""))
		if token == "" or not (ids is Array) or ids.is_empty():
			continue
		purchased.emit(str(ids[0]), token)
		n += 1
	return n
