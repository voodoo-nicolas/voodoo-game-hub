extends RefCounted

## Nash's stuff. Pure logic (no Nodes), tested headless by tests/test_last_shift_inventory.gd.
##
##   Bag     SLOTS slots. Every slot holds one kind of item, up to that item's stack size
##           (2 first-aid kits or 3 snacks per slot). A full bag can't take more: whatever
##           doesn't fit stays where it was (on the floor / in the drawer).
##   Weapons fist (always), knife, severed arm, wrench, pistol, coolant can (v0.5). They live on the
##           weapon wheel, not in the bag.
##   Ammo    bullets for the pistol: a plain counter (v0.4: ammo never takes a bag slot), max 99.
##   Cans    coolant cans to throw: a counter like the bullets (v0.5), max CANS_MAX.
##   Wallet  money, for the vending machines. Takes no slot.
## Keys and keycards are story flags (the world's state), shown in the bag screen, no slot.

const SLOTS := 6
## Item kinds that go in the bag, and how many fit in one slot.
const STACK := {"medkit": 2, "snack": 3}
const AMMO_MAX := 99
const CANS_MAX := 5
const WEAPONS := ["fist", "knife", "arm", "wrench", "pistol", "coolant"]
## Hats Nash can find and wear (one at a time; cosmetic, no slot).
const HATS := ["party", "chef"]

## One entry per slot: {} = empty, else {"kind": String, "n": int}.
var slots: Array = []
var weapons: Array = ["fist"]
## The weapon B uses.
var equipped := "fist"
var money := 0
var bullets := 0
var cans := 0
## Hats (v0.4.1 party hat, v0.5 the cook's hat): the ones he owns, and the one he wears ("" = none).
var hats: Array = []
var hat_worn := ""

## Older code and tests: "has the party hat" / "is wearing a hat".
var hat: bool:
	get: return hats.has("party")
var hat_on: bool:
	get: return hat_worn != ""

func _init() -> void:
	clear()

func clear() -> void:
	slots.clear()
	for i in SLOTS:
		slots.append({})
	weapons = ["fist"]
	equipped = "fist"
	money = 0
	bullets = 0
	cans = 0
	hats = []
	hat_worn = ""

# ---------------------------------------------------------------- bag

static func is_bag_item(kind: String) -> bool:
	return STACK.has(kind)

## How many of `kind` are in the bag.
func count(kind: String) -> int:
	var n := 0
	for s in slots:
		if s.get("kind", "") == kind:
			n += int(s.n)
	return n

## How many more of `kind` would fit.
func space_for(kind: String) -> int:
	if not STACK.has(kind):
		return 0
	var free := 0
	for s in slots:
		if s.is_empty():
			free += int(STACK[kind])
		elif s.kind == kind:
			free += int(STACK[kind]) - int(s.n)
	return free

## Puts up to `n` of `kind` in the bag (topping up partial stacks first). Returns how many went in.
func add(kind: String, n: int) -> int:
	if not STACK.has(kind) or n <= 0:
		return 0
	var cap: int = STACK[kind]
	var left := n
	for s in slots:
		if left <= 0:
			break
		if s.get("kind", "") == kind and int(s.n) < cap:
			var take := mini(left, cap - int(s.n))
			s.n = int(s.n) + take
			left -= take
	for i in slots.size():
		if left <= 0:
			break
		if slots[i].is_empty():
			var take := mini(left, cap)
			slots[i] = {"kind": kind, "n": take}
			left -= take
	return n - left

## Takes up to `n` of `kind` out (from the last stacks first). Returns how many came out.
func remove(kind: String, n: int) -> int:
	var left := n
	for i in range(slots.size() - 1, -1, -1):
		if left <= 0:
			break
		var s: Dictionary = slots[i]
		if s.get("kind", "") != kind:
			continue
		var take := mini(left, int(s.n))
		s.n = int(s.n) - take
		left -= take
		if int(s.n) <= 0:
			slots[i] = {}
	return n - left

## Empties one slot and returns what was in it ({} if it was empty).
func take_slot(i: int) -> Dictionary:
	if i < 0 or i >= slots.size():
		return {}
	var s: Dictionary = slots[i]
	slots[i] = {}
	return s

func used_slots() -> int:
	var n := 0
	for s in slots:
		if not s.is_empty():
			n += 1
	return n

# ---------------------------------------------------------------- weapons

func has_weapon(w: String) -> bool:
	return weapons.has(w)

## Adds a weapon (kept in WEAPONS order). Returns false if Nash already had it.
func add_weapon(w: String) -> bool:
	if not WEAPONS.has(w) or weapons.has(w):
		return false
	weapons.append(w)
	weapons.sort_custom(func(a, b): return WEAPONS.find(a) < WEAPONS.find(b))
	return true

func equip(w: String) -> bool:
	if not weapons.has(w):
		return false
	equipped = w
	return true

## Next owned weapon after the equipped one (keyboard Q). Returns the new one.
func cycle_weapon() -> String:
	var i := weapons.find(equipped)
	equipped = weapons[(i + 1) % weapons.size()]
	return equipped

func ammo() -> int:
	return bullets

## Adds bullets (up to AMMO_MAX). Returns how many were taken.
func add_ammo(n: int) -> int:
	var take := clampi(n, 0, AMMO_MAX - bullets)
	bullets += take
	return take

## Adds coolant cans (up to CANS_MAX); the first one also puts the can on the wheel.
## Returns how many were taken.
func add_cans(n: int) -> int:
	var take := clampi(n, 0, CANS_MAX - cans)
	cans += take
	if take > 0:
		add_weapon("coolant")
	return take

## What is left for a weapon that uses something up ("" for the others): bullets, cans.
func count_for(w: String) -> String:
	match w:
		"pistol":
			return str(bullets)
		"coolant":
			return str(cans)
	return ""

# ---------------------------------------------------------------- hats

## Picks up a hat. Returns false if he already had it.
func add_hat(h: String) -> bool:
	if not HATS.has(h) or hats.has(h):
		return false
	hats.append(h)
	hats.sort_custom(func(a, b): return HATS.find(a) < HATS.find(b))
	return true

## Wears this hat, or takes it off if he is already wearing it. Returns the hat now worn ("" = none).
func toggle_hat(h: String) -> String:
	if not hats.has(h):
		return hat_worn
	hat_worn = "" if hat_worn == h else h
	return hat_worn

# ---------------------------------------------------------------- save

func to_dict() -> Dictionary:
	return {"slots": slots.duplicate(true), "weapons": weapons.duplicate(), "equipped": equipped,
		"money": money, "bullets": bullets, "cans": cans, "hats": hats.duplicate(), "hat_worn": hat_worn}

## Restores from to_dict() (JSON gives numbers back as floats).
func from_dict(d: Dictionary) -> void:
	clear()
	var saved: Array = d.get("slots", [])
	for i in mini(saved.size(), SLOTS):
		var s: Dictionary = saved[i]
		if not s.is_empty() and STACK.has(str(s.get("kind", ""))):
			slots[i] = {"kind": str(s.kind), "n": int(s.n)}
	for w in d.get("weapons", []):
		add_weapon(str(w))
	equipped = str(d.get("equipped", "fist"))
	if not weapons.has(equipped):
		equipped = "fist"
	money = int(d.get("money", 0))
	bullets = int(d.get("bullets", 0))
	cans = int(d.get("cans", 0))
	for h in d.get("hats", []):
		add_hat(str(h))
	if bool(d.get("hat", false)):       # saves from v0.4.1: one party hat, on or off
		add_hat("party")
		if bool(d.get("hat_on", false)):
			hat_worn = "party"
	if d.has("hat_worn") and hats.has(str(d.hat_worn)):
		hat_worn = str(d.hat_worn)
