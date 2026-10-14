extends SceneTree

## Headless checks for the bag, weapons and the rules in the engine (v0.4):
##   godot --headless --path . --script res://tools/test_last_shift_inventory.gd

const Inv = preload("res://scripts/games/last_shift/last_shift_inventory.gd")
const E = preload("res://scripts/games/last_shift/last_shift_engine.gd")

var fails := 0

func check(label: String, got, want) -> void:
	if got != want:
		fails += 1
		print("FAIL ", label, ": got ", got, " want ", want)

func _init() -> void:
	var inv := Inv.new()
	# --- bag: stacking and space
	check("empty bag", inv.used_slots(), 0)
	check("space for kits", inv.space_for("medkit"), Inv.SLOTS * 2)
	check("add 3 kits", inv.add("medkit", 3), 3)
	check("3 kits = 2 slots", inv.used_slots(), 2)
	check("count kits", inv.count("medkit"), 3)
	check("top up the half stack first", inv.add("medkit", 1), 1)
	check("still 2 slots", inv.used_slots(), 2)
	check("not a bag item", inv.add("knife", 1), 0)
	# --- ammo never takes a slot (v0.4)
	check("bullets are not a bag item", inv.add("bullets", 5), 0)
	check("ammo counter", inv.add_ammo(13), 13)
	check("still 2 slots with ammo", inv.used_slots(), 2)
	check("ammo", inv.ammo(), 13)
	check("ammo cap", inv.add_ammo(200), Inv.AMMO_MAX - 13)
	check("ammo at the cap", inv.ammo(), Inv.AMMO_MAX)
	inv.bullets = 11
	check("snacks", inv.add("snack", 13), 12)      # 4 free slots x 3: one snack stays behind
	check("bag full", inv.used_slots(), Inv.SLOTS)
	check("no room for kits", inv.add("medkit", 1), 0)
	check("remove more than there is", inv.remove("medkit", 9), 4)
	check("kits gone", inv.count("medkit"), 0)
	var s: Dictionary = inv.take_slot(inv.slots.find(inv.slots.filter(func(x): return x.get("kind", "") == "snack")[0]))
	check("take a slot", s.kind, "snack")
	# --- weapons
	check("starts with fists", inv.weapons, ["fist"])
	check("fist equipped", inv.equipped, "fist")
	check("add pistol", inv.add_weapon("pistol"), true)
	check("add wrench", inv.add_weapon("wrench"), true)
	check("no duplicates", inv.add_weapon("wrench"), false)
	check("kept in wheel order", inv.weapons, ["fist", "wrench", "pistol"])
	check("cycle", inv.cycle_weapon(), "wrench")
	check("cycle", inv.cycle_weapon(), "pistol")
	check("cycle wraps", inv.cycle_weapon(), "fist")
	check("can't equip what you don't have", inv.equip("knife"), false)
	# --- save round trip
	inv.money = 7
	inv.equip("wrench")
	var copy := Inv.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	check("saved slots", copy.slots, inv.slots)
	check("saved weapons", copy.weapons, inv.weapons)
	check("saved equipped", copy.equipped, "wrench")
	check("saved money", copy.money, 7)
	check("saved bullets", copy.bullets, 11)
	# --- v0.5: coolant cans, hats
	check("first can puts the coolant on the wheel", inv.add_cans(2), 2)
	check("coolant on the wheel", inv.has_weapon("coolant"), true)
	check("cans are capped", inv.add_cans(9), Inv.CANS_MAX - 2)
	check("count shown for the cans", inv.count_for("coolant"), str(Inv.CANS_MAX))
	check("no count for the wrench", inv.count_for("wrench"), "")
	check("a hat", inv.add_hat("chef"), true)
	check("not twice", inv.add_hat("chef"), false)
	check("wear it", inv.toggle_hat("chef"), "chef")
	check("take it off", inv.toggle_hat("chef"), "")
	inv.add_hat("party")
	inv.toggle_hat("party")
	var copy2 := Inv.new()
	copy2.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	check("saved cans", copy2.cans, Inv.CANS_MAX)
	check("saved hats", copy2.hats, ["party", "chef"])
	check("saved hat worn", copy2.hat_worn, "party")
	var old := Inv.new()
	old.from_dict({"hat": true, "hat_on": true})
	check("v0.4.1 saves: the party hat, worn", old.hat_worn, "party")
	# --- engine: melee damage
	check("wrench on walker", E.melee_damage("wrench", "walker", true), 2)
	check("fist on walker", E.melee_damage("fist", "walker", true), 1)
	check("the knife hits harder than the wrench", E.melee_damage("knife", "walker", true) > E.melee_damage("wrench", "walker", true), true)
	check("knife takedown", E.melee_damage("knife", "walker", false) >= E.ENEMY_HP.walker, true)
	check("no takedown on the brute", E.melee_damage("knife", "brute", false), E.WEAPONS.knife.damage)
	check("knife never on people", E.melee_damage("knife", "guard", false), 0)
	check("fists on a guard", E.melee_damage("fist", "guard", true), 1)
	check("melee does nothing to Dwayne", E.melee_damage("wrench", "runner", true), 0)
	# v0.5 (playtest: tougher infected): three wrench hits for a walker, four bullets for Dwayne
	check("three wrench hits drop a walker", E.ENEMY_HP.walker / E.WEAPONS.wrench.damage, 3)
	check("four bullets drop Dwayne", E.ENEMY_HP.runner / E.WEAPONS.pistol.damage, 4)
	check("the severed arm reaches further than the wrench", E.WEAPONS.arm.reach > E.WEAPONS.wrench.reach, true)
	check("the severed arm hits for 1", E.melee_damage("arm", "walker", true), 1)
	check("snacks heal 10", E.HEAL.snack, 10)
	# --- engine: hits on Nash (difficulty, armor)
	check("normal walker hit", E.hit_on_nash(15, 1, 0), {"hp": 15, "armor": 0})
	check("easy is softer", E.hit_on_nash(15, 0, 0).hp < 15, true)
	check("hard is harder", E.hit_on_nash(15, 2, 0).hp > 15, true)
	check("armor soaks 60%", E.hit_on_nash(20, 1, 100), {"hp": 8, "armor": 12})
	check("almost no armor left", E.hit_on_nash(20, 1, 5), {"hp": 15, "armor": 5})
	check("zombies hit softer than before (v0.4)", E.DAMAGE.walker < 30, true)
	# --- engine: quick heal choice
	check("nothing missing", E.quick_heal_item(0, 1, 1), "")
	check("small wound: snack", E.quick_heal_item(15, 1, 1), "snack")
	check("big wound: kit", E.quick_heal_item(60, 1, 1), "medkit")
	check("no kit: snack anyway", E.quick_heal_item(60, 0, 1), "snack")
	check("nothing to use", E.quick_heal_item(60, 0, 0), "")
	# --- engine: bodies
	check("same body, same loot", E.body_loot("walker_x", "walker"), E.body_loot("walker_x", "walker"))
	check("guards carry bullets", E.body_loot("guard_a", "guard"), [{"item": "bullets", "n": 3}])
	# --- engine: quests
	var st := {"entered_lobby": false, "solved": {"chiller": false, "pump": false, "vents": false},
		"alarm": false, "attack_done": false, "kills": 0, "searched": {}, "dead": {}, "has_keycard": false,
		"has_maint_key": false, "has_sec_key": false, "lobby_alarm_seen": false, "visited": {}, "read": {},
		"tried": {}, "flags": {}, "exit": ""}
	var ctx := {"wrench": false, "pistol": false, "knife": false, "room": "parking_lot"}
	check("first quest open", E.quest_status("enter", st, ctx), "active")
	check("later quest hidden", E.quest_status("pistol", st, ctx), "hidden")
	st.entered_lobby = true
	check("enter done", E.quest_status("enter", st, ctx), "done")
	check("elevator open", E.quest_status("elevator", st, ctx), "active")
	st.read["gift"] = true
	check("an email starts the gift quest", E.quest_status("gift", st, ctx), "active")
	ctx.knife = true
	check("the knife finishes it", E.quest_status("gift", st, ctx), "done")
	st.tried["door_fire"] = true
	check("a chained door starts the cutters quest", E.quest_status("cutters", st, ctx), "active")
	st.exit = "dock"
	check("the dock quest is done by using it", E.quest_status("dock", st, ctx), "done")
	for q in E.QUESTS:
		check("every quest has a rule " + q, E.quest_status(q, st, ctx) in ["hidden", "active", "done"], true)
	print("inventory tests: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
