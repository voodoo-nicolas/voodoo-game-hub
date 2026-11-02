extends Control

## The ship computer (Menu button): the owner's six tabs (2026-11-02) — Inventory, Skill Tree,
## Missions, Map, Ship Layout, Stats. Opens over any screen; ✕ (or the Menu button again) closes it.

const D = preload("res://scripts/games/the_runner/the_runner_data.gd")
const UI = preload("res://scripts/games/the_runner/the_runner_ui.gd")
const Dock = preload("res://scripts/games/the_runner/the_runner_dock.gd")

const TABS := [["inventory", "📦", "Inventory"], ["skills", "🌟", "Skill Tree"], ["missions", "📜", "Missions"],
	["map", "🗺", "Map"], ["ship", "🚀", "Ship Layout"], ["stats", "📊", "Stats"]]

var game: Control
var tab := "inventory"
var _note := ""

func _e():
	return game.engine

func _gui_input(event: InputEvent) -> void:
	accept_event()   # nothing under the computer takes taps

func rebuild() -> void:
	for ch in get_children():
		ch.queue_free()
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UI.backdrop("ship_layout" if tab == "ship" else "port_hangar"))
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.25 if tab == "ship" else 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var p := UI.panel(0.92)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if tab == "ship":
		p.anchor_right = 0.58   # the ship picture shows on the right
	p.offset_left = 10
	p.offset_right = -10
	p.offset_top = game.hud_height() + 8
	p.offset_bottom = -10
	add_child(p)
	var outer := UI.vbox(8)
	p.add_child(outer)
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 6)
	bar.add_theme_constant_override("v_separation", 6)
	outer.add_child(bar)
	for t in TABS:
		var b := UI.button("%s %s" % [t[1], UI.tr_s(t[2])], _pick.bind(t[0]), UI.c("go") if tab == t[0] else UI.c("accent"), 18, 44)
		bar.add_child(b)
	bar.add_child(UI.button("✕ " + UI.tr_s("Close"), game.close_computer, UI.c("dim"), 18, 44))
	if _note != "":
		outer.add_child(UI.label(_note, 18, UI.c("warn"), true))
	var box := UI.vbox(6)
	outer.add_child(UI.scroll(box))
	match tab:
		"inventory": _inventory(box)
		"skills": _skills(box)
		"missions": _missions(box)
		"map": _map(box)
		"ship": _ship(box)
		"stats": _stats(box)

func _pick(t: String) -> void:
	tab = t
	_note = ""
	rebuild()

func _changed(note: String = "") -> void:
	_note = note
	game.refresh()

func _h(box: VBoxContainer, text: String) -> void:
	box.add_child(UI.label(text, 22, UI.c("accent")))

# ================================================================ Inventory

func _inventory(box: VBoxContainer) -> void:
	var e = _e()
	var row := UI.hbox(24)
	row.add_child(UI.label(UI.clean_txt(e.clean) + "  " + UI.tr_s("clean"), 20, UI.c("clean")))
	row.add_child(UI.label(UI.dirty_txt(e.dirty) + "  " + UI.tr_s("dirty"), 20, UI.c("dirty")))
	row.add_child(UI.label("⛽ %d/%d" % [int(e.fuel), e.tank()], 20))
	row.add_child(UI.label("🛡 %d/%d" % [e.hull, e.max_hull()], 20))
	box.add_child(row)
	for hold in [["Open hold", e.cargo, e.cargo_cap()], ["Hidden hold", e.hidden, e.hidden_cap()]]:
		var hd: Dictionary = hold[1]
		_h(box, "%s  %d/%d" % [UI.tr_s(hold[0]), e.used(hd), hold[2]])
		if hd.is_empty():
			box.add_child(UI.label(UI.tr_s("Empty."), 18, UI.c("dim")))
		for g in D.GOOD_ORDER:
			if not hd.has(g):
				continue
			var r := UI.hbox(10)
			var contra: bool = D.GOODS[g].contraband
			var l := UI.label("%s%s × %d" % ["◆ " if contra else "", UI.good_name(g), int(hd[g])], 19, UI.c("dirty") if contra else UI.c("text"))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(l)
			r.add_child(UI.label(UI.tr_s("worth ~%s") % UI.num(int(hd[g]) * int(D.GOODS[g].base)), 16, UI.c("dim")))
			if hd == e.cargo and contra:
				var hb := UI.button(UI.tr_s("Hide away"), _hide.bind(g), UI.c("go"), 16, 38)
				hb.disabled = e.used(e.hidden) >= e.hidden_cap()
				r.add_child(hb)
			var db := UI.button(UI.tr_s("Dump 1"), _dump.bind(g), UI.c("bad"), 16, 38)
			db.disabled = e.qty(g) - e.reserved(g) <= 0
			r.add_child(db)
			box.add_child(r)
	if e.contraband_in_open() > 0:
		box.add_child(UI.label(UI.tr_s("Contraband in the open hold is found by any scan that looks. Hide it, or keep the hidden hold for it."), 16, UI.c("warn"), true))

func _hide(g: String) -> void:
	_e().to_hidden(g)
	_changed()

func _dump(g: String) -> void:
	_e().dump(g, 1)
	_changed()

# ================================================================ Skill Tree

func _skills(box: VBoxContainer) -> void:
	var e = _e()
	var xi: Array = e.xp_into_level()
	box.add_child(UI.label(UI.tr_s("Level %d · %d / %d XP · %d skill points") % [e.level(), xi[0], xi[1], e.skill_points()], 20, UI.c("text")))
	box.add_child(UI.label(UI.tr_s("Your first branch is your primary, your second your secondary. The other branches stay closed. Ranks open in order."), 16, UI.c("dim"), true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for b in D.BRANCHES:
		var p := UI.panel(0.7)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(p)
		var col := UI.vbox(4)
		p.add_child(col)
		var role := ""
		var bi: int = e.branches.find(b)
		if bi == 0:
			role = " · " + UI.tr_s("primary")
		elif bi == 1:
			role = " · " + UI.tr_s("secondary")
		elif not e.branch_open(b):
			role = " · 🔒"
		col.add_child(UI.label("%s %s%s" % [D.BRANCH_ICONS[b], UI.tr_s(D.BRANCH_NAMES[b]), role], 20, UI.c("accent") if e.branch_open(b) else UI.c("dim")))
		for s in D.SKILLS[b]:
			var have: bool = e.has_skill(s.id)
			var mark := "✔ " if have else "○ "
			col.add_child(UI.label(mark + UI.tr_s(s.name), 17, UI.c("go") if have else UI.c("text")))
			col.add_child(UI.label(UI.tr_s(s.desc), 14, UI.c("dim"), true))
		var nxt: String = e.next_skill(b)
		if nxt != "":
			var lb := UI.button(UI.tr_s("Learn"), _learn.bind(b), UI.c("go"), 16, 38)
			lb.disabled = not e.can_learn(b)
			col.add_child(lb)

func _learn(b: String) -> void:
	_e().learn(b)
	_changed()

# ================================================================ Missions

func _missions(box: VBoxContainer) -> void:
	var e = _e()
	_h(box, UI.tr_s("Active"))
	var act: Array = e.active_missions()
	if act.is_empty():
		box.add_child(UI.label(UI.tr_s("No active missions. Look for ❗ jobs at the docks."), 18, UI.c("dim")))
	for id in act:
		var m: Dictionary = D.MISSIONS[id]
		var pr: Array = e.mission_progress(id)
		var tag := UI.tr_s("Main") if m.kind == "main" else UI.tr_s("Side")
		box.add_child(UI.label("%s · %s  (%d/%d)" % [tag, UI.tr_s(m.title), pr[0], pr[1]], 20, UI.c("go") if m.kind == "main" else UI.c("text")))
		box.add_child(UI.label(UI.tr_s(m.brief), 16, UI.c("dim"), true))
		box.add_child(UI.label(Dock._reward_text(m.reward), 16, UI.c("clean"), true))
	if not e.contracts.is_empty():
		_h(box, UI.tr_s("Contracts"))
		for c in e.contracts:
			var late: bool = int(c.due) - e.day <= 1
			box.add_child(UI.label("• " + UI.tr_s("%d x %s to %s, by day %d") % [c.qty, UI.good_name(c.good), UI.world_name(c.to), c.due], 18, UI.c("bad") if late else UI.c("text"), true))
	var done := []
	for id in D.MAIN_ORDER + D.SIDE_ORDER:
		if e.mission_state(id) == "done":
			done.append("✔ " + UI.tr_s(D.MISSIONS[id].title))
	if not done.is_empty():
		_h(box, UI.tr_s("Done"))
		box.add_child(UI.label("   ".join(done), 16, UI.c("dim"), true))

# ================================================================ Map

func _map(box: VBoxContainer) -> void:
	var e = _e()
	box.add_child(UI.label(UI.tr_s("The Cradle Reach system. ▲ = law level. Prices are what you saw last time you docked."), 16, UI.c("dim"), true))
	for w in D.WORLD_ORDER:
		var wd: Dictionary = D.WORLDS[w]
		var p := UI.panel(0.6)
		box.add_child(p)
		var col := UI.vbox(2)
		p.add_child(col)
		var tags := []
		tags.append(UI.tr_s(D.FACTIONS[wd.faction].name))
		tags.append("▲".repeat(e.law_at(w)) if e.law_at(w) > 0 else UI.tr_s("lawless"))
		if wd.black:
			tags.append(UI.tr_s("black market"))
		if wd.blind:
			tags.append(UI.tr_s("blind spot"))
		var here := "  📍" if w == e.loc else ""
		col.add_child(UI.label("%s%s  ·  %s" % [UI.world_name(w), here, ", ".join(tags)], 19, UI.c("accent")))
		if e.seen_prices.has(w):
			var sp: Dictionary = e.seen_prices[w]
			var cheap := []
			var dear := []
			for g in D.GOOD_ORDER:
				if not sp.has(g):
					continue
				var ratio: float = float(sp[g]) / float(D.GOODS[g].base)
				if ratio < 0.85:
					cheap.append(UI.good_name(g))
				elif ratio > 1.2:
					dear.append(UI.good_name(g))
			var line := UI.tr_s("Day %d") % int(sp.get("_day", 0))
			if not cheap.is_empty():
				line += " · " + UI.tr_s("cheap: %s") % ", ".join(cheap)
			if not dear.is_empty():
				line += " · " + UI.tr_s("pays well: %s") % ", ".join(dear)
			col.add_child(UI.label(line, 15, UI.c("text"), true))
		elif e.has_service("market", w):
			col.add_child(UI.label(UI.tr_s("Not visited yet."), 15, UI.c("dim")))

# ================================================================ Ship Layout

func _ship(box: VBoxContainer) -> void:
	var e = _e()
	var sd: Dictionary = D.SHIPS[e.ship]
	box.add_child(UI.label(UI.tr_s(sd.name), 26, UI.c("accent")))
	box.add_child(UI.label(UI.tr_s(sd.desc), 16, UI.c("dim"), true))
	var stats := UI.tr_s("Hold %d · Hidden %d · Tank %d · Hull %d · Shield %d · Guns %d · Stealth %d") % [
		e.cargo_cap(), e.hidden_cap(), e.tank(), e.max_hull(), e.shield(), e.guns(), e.stealth()]
	box.add_child(UI.label(stats, 18, UI.c("text"), true))
	box.add_child(UI.label(UI.tr_s("Swap any part you own here. Buy new parts at a shipyard."), 16, UI.c("dim"), true))
	for slot in D.SLOTS:
		var row := UI.hbox(8)
		var l := UI.label(UI.tr_s(D.SLOT_NAMES[slot]), 19, UI.c("accent"))
		l.custom_minimum_size.x = 170
		row.add_child(l)
		var opts: Array = e.modules_for(slot)
		for id in opts:
			var fitted: bool = e.modules.get(slot) == id
			var b := UI.button(UI.tr_s(D.MODULES[id].name), _fit.bind(id), UI.c("go") if fitted else UI.c("accent"), 16, 40)
			b.tooltip_text = Dock.module_effect(id)
			row.add_child(b)
		var fx := UI.label(Dock.module_effect(e.modules[slot]), 15, UI.c("dim"))
		row.add_child(fx)
		box.add_child(row)

func _fit(id: String) -> void:
	_e().fit_module(id)
	_changed()

# ================================================================ Stats

func _stats(box: VBoxContainer) -> void:
	var e = _e()
	var nw: int = e.net_worth()
	box.add_child(UI.label(UI.tr_s("Net worth: %s") % UI.num(nw), 28, UI.c("go")))
	var goal := UI.tr_s("Goal: %s (clean enough to spend)") % UI.num(D.GOAL_NET_WORTH)
	box.add_child(UI.label(goal, 16, UI.c("dim")))
	var bar := ProgressBar.new()
	bar.max_value = 1000.0
	bar.value = clampf(log(maxf(1.0, float(nw))) / log(float(D.GOAL_NET_WORTH)) * 1000.0, 0.0, 1000.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UI.c("go")
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	box.add_child(bar)
	box.add_child(UI.label(UI.tr_s("Net worth = clean credits + ship parts + cargo + 30% of dirty credits − debt."), 15, UI.c("dim"), true))
	_h(box, UI.tr_s("Heat"))
	for f in D.POLICE:
		box.add_child(UI.label("%s: %d · %s" % [UI.tr_s(D.FACTIONS[f].name), int(e.heat_of(f)), UI.tr_s(e.heat_tier(f))], 18, game._heat_color(e.heat_of(f))))
	if e.has_skill("fo_ghost"):
		var gb := UI.button(UI.tr_s("🪪 Ghost Identity: wipe Concord heat"), _ghost, UI.c("warn"), 18, 44)
		gb.disabled = e.ghost_used
		box.add_child(gb)
	_h(box, UI.tr_s("Reputation"))
	box.add_child(UI.label(UI.tr_s("Infamy (fear): %d · Street cred (respect): %d") % [e.infamy, e.cred], 18))
	_h(box, UI.tr_s("Record"))
	var s: Dictionary = e.stats
	var lines := [
		UI.tr_s("Day %d · level %d") % [e.day, e.level()],
		UI.tr_s("Dockings: %d · trips: %d") % [s.runs, s.trips],
		UI.tr_s("Scans passed: %d · failed: %d · bribes: %d") % [s.scans_passed, s.scans_failed, s.bribes],
		UI.tr_s("Fights won: %d · lost: %d") % [s.fights_won, s.fights_lost],
		UI.tr_s("Contracts done: %d · salvages: %d") % [s.contracts, s.salvages],
		UI.tr_s("Trade profit: %s · best haul: %s") % [UI.num(s.profit), UI.num(s.best_haul)],
		UI.tr_s("Laundered: %s") % UI.num(s.laundered),
	]
	for l in lines:
		box.add_child(UI.label(l, 18))

func _ghost() -> void:
	_e().use_ghost_identity()
	_changed()
