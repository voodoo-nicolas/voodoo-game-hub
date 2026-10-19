extends RefCounted

## Creation's monetization seam (SPEC section 7: ONE one-time "Full Game"
## purchase, no ads, no accounts). Pure functions, tested in tools/test_creation.gd.
##
## What is free and what the Full Game adds:
##   free      tiers 1-3 (Nature, Life, Early Civilization), 3 hints a day
##   Full Game tiers 4-5 (Industry & Modern Life, Space & Future), unlimited hints
## Paid-tier results are shown as locked silhouettes, never hidden (the player
## knows there is more) -- see CreationEngine.try_combine.
##
## STATUS: NOT LIVE. `LIVE` stays false until the owner switches monetization
## on (CLAUDE.md: store is on branch `store`, nothing is sold yet), so today
## every tier is open. With `LIVE` false none of the gate code is reachable
## in a shipped pack. `VOODOO_CREATION_PAYWALL=1` turns it on for desktop tests.
##
## Billing cannot live in this pack (a .pck cannot carry the Play Billing
## plugin). The APK-side `Store` autoload must provide it; this game only
## asks, guarded, so packs keep working on every app version:
##   store.has_entitlement("creation_full") -> bool       (to add on branch `store`)
##   store.buy_product("creation_full")                    (to add on branch `store`)
## See docs/claude/creation.md.

const PRODUCT_ID := "creation_full"
const FREE_TIERS := [1, 2, 3]
const LIVE := false

static func live() -> bool:
	return LIVE or OS.get_environment("VOODOO_CREATION_PAYWALL") == "1"

static func tier_is_free(tier: int) -> bool:
	return tier in FREE_TIERS

## May the player collect items of this tier?
static func tier_unlocked(tier: int, full: bool, paywall_on: bool) -> bool:
	return not paywall_on or full or tier_is_free(tier)

## Hints are 3 a day for everyone (SPEC section 4) until the Full Game is owned,
## whether or not the paywall is on: unlimited hints are part of what it sells.
static func unlimited_hints(full: bool) -> bool:
	return full

## Asks the hub's Store (APK side, may not exist yet) whether the Full Game is
## owned. `store` is get_node_or_null("/root/Store"). False when unknown.
static func store_owns(store: Object) -> bool:
	if store != null and store.has_method("has_entitlement"):
		return bool(store.call("has_entitlement", PRODUCT_ID))
	return false

## Starts the purchase through the hub's Store. Returns false when the app has
## no store yet (the caller tells the player it isn't available).
static func store_buy(store: Object) -> bool:
	if store != null and store.has_method("buy_product"):
		store.call("buy_product", PRODUCT_ID)
		return true
	return false
