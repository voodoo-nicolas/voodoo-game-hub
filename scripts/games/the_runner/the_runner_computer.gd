extends Control

## The ship computer (Menu button): the owner's six tabs (2026-11-02) — Inventory, Skill Tree,
## Missions, Map, Ship Layout, Stats — plus v2's Factions (rep bars and bonuses, the Paragon and
## Outlaw bars), Crew and Captain (race, every perk and where it comes from). Opens over any screen;
## ✕ (or the Menu button again) closes it.

const D = preload("res://scripts/games/the_runner/the_runner_data.gd")
const S = preload("res://scripts/games/the_runner/the_runner_spiral.gd")
const UI = preload("res://scripts/games/the_runner/the_runner_ui.gd")
const Dock = preload("res://scripts/games/the_runner/the_runner_dock.gd")
const ShipArt = preload("res://scripts/games/the_runner/the_runner_ship_art.gd")

const TABS := [["inventory", "📦", "Inventory"], ["skills", "🌟", "Skill Tree"], ["missions", "📜", "Missions"],
	["map", "🗺", "Map"], ["ship", "🚀", "Ship Layout"], ["stats", "📊", "Stats"],
	["factions", "⚖", "Factions"], ["crew", "🧑‍🚀", "Crew "], ["captain", "🪪", "Captain"]]

var game: Control
var tab := "inventory"
var _note := ""
var _ship_pic: Control = null
var _clock := 0.0

func _e():
	return game.engine

func _gui_input(event: InputEvent) -> void:
	accept_event()   # nothing under the computer takes taps

func _process(delta: float) -> void:
	_clock += delta
	if _ship_pic != null and is_instance_valid(_ship_pic):
		_ship_pic.queue_redraw()

func rebuild() -> void:
	for ch in get_children():
		ch.queue_free()
	_ship_pic = null
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UI.backdrop("ship_layout" if tab == "ship" else "port_hangar"))
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35 if tab == "ship" else 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var p := UI.panel(0.92)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if tab == "ship":
		p.anchor_right = 0.6   # the ship shows on the right
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
		var b := UI.button("%s %s" % [t[1], UI.tr_s(t[2])], _pick.bind(t[0]), UI.c("go") if tab == t[0] else UI.c("accent"), 17, 42)
		bar.add_child(b)
	bar.add_child(UI.button("✕ " + UI.tr_s("Close"), game.close_computer, UI.c("dim"), 17, 42))
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
		"factions": _factions(box)
		"crew": _crew(box)
		"captain": _captain(box)

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
	box.add_child(UI.label(UI.tr_s("Your first branch is your primary, your second your secondary. The other branches stay closed. Ranks open in order. (Perks are in the Captain tab.)"), 16, UI.c("dim"), true))
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
			col.add_child(UI.label(("✔ " if have else "○ ") + UI.tr_s(s.name), 17, UI.c("go") if have else UI.c("text")))
			col.add_child(UI.label(UI.tr_s(s.desc), 14, UI.c("dim"), true))
		if e.next_skill(b) != "":
			var lb := UI.button(UI.tr_s("Learn"), _learn.bind(b), UI.c("go"), 16, 38)
			lb.disabled = not e.can_learn(b)
			col.add_child(lb)

func _learn(b: String) -> void:
	_e().learn(b)
	if game.info:
		game.info.high("Skills learned", _e().skills.size())
	_changed()

# ================================================================ Missions

func _missions(box: VBoxContainer) -> void:
	var e = _e()
	_h(box, UI.tr_s("Active") + "  (%d/%d)" % [e.side_active(), e.quest_slots()])
	var act: Array = e.active_quests()
	if act.is_empty():
		box.add_child(UI.label(UI.tr_s("No active quests. Look for ❗ job boards at the docks."), 18, UI.c("dim")))
	for id in act:
		var q: Dictionary = S.QUESTS[id]
		var pr: Array = e.quest_progress(id)
		var tag: String = Dock.KIND_ICON.get(q.kind, "•")
		box.add_child(UI.label("%s %s  (%d/%d)" % [tag, Dock.quest_title(id), pr[0], pr[1]], 20, UI.c("go") if q.kind == "main" else UI.c("text"), true))
		box.add_child(UI.label(UI.tr_s(q.brief), 16, UI.c("dim"), true))
		box.add_child(UI.label(Dock.reward_text(q), 15, UI.c("clean"), true))
	if not e.contracts.is_empty():
		_h(box, UI.tr_s("Contracts"))
		for c in e.contracts:
			var late: bool = int(c.due) - e.day <= 1 and not c.get("done", false)
			box.add_child(UI.label("• " + Dock._contract_text(c), 18, UI.c("bad") if late else UI.c("text"), true))
	var done := []
	for id in S.QUEST_ORDER:
		if e.quest_state(id) == "done":
			done.append("✔ " + UI.tr_s(S.QUESTS[id].title))
	if not done.is_empty():
		_h(box, UI.tr_s("Done") + "  (%d)" % done.size())
		box.add_child(UI.label("   ".join(done), 16, UI.c("dim"), true))

# ================================================================ Map

func _map(box: VBoxContainer) -> void:
	var e = _e()
	var reveal: bool = e.flag("reveal")
	box.add_child(UI.label(UI.tr_s("▲ = law level. Prices are what you saw the last time you docked.") + (" " + UI.tr_s("Cartographer: today's prices everywhere.") if reveal else ""), 16, UI.c("dim"), true))
	for s in D.SECTOR_ORDER:
		var sd: Dictionary = D.SECTORS[s]
		var open: bool = e.sector_open(s)
		_h(box, ("📍 " if s == e.sector else "") + UI.sector_name(s) + ("" if open else "  🔒"))
		if not open:
			var txt := UI.tr_s("The gate opens with a Rift Key (Act I).") if s != "hollow_deep" else UI.tr_s("The gate opens in Act III, when the fleets muster.")
			box.add_child(UI.label(txt, 16, UI.c("dim"), true))
			continue
		for w in e.worlds_in(s):
			var wd: Dictionary = D.WORLDS[w]
			var p := UI.panel(0.6)
			box.add_child(p)
			var col := UI.vbox(2)
			p.add_child(col)
			var tags := [UI.faction_name(wd.faction)]
			tags.append("▲".repeat(e.law_at(w)) if e.law_at(w) > 0 else UI.tr_s("lawless"))
			if wd.black:
				tags.append(UI.tr_s("black market"))
			if wd.blind:
				tags.append(UI.tr_s("blind spot"))
			if e.port_closed(w):
				tags.append(UI.tr_s("closed to you"))
			var here := "  📍" if w == e.loc else ""
			col.add_child(UI.label("%s%s  ·  %s" % [UI.world_name(w), here, ", ".join(tags)], 19, UI.c("accent"), true))
			var sp: Dictionary = {}
			if reveal and wd.services.has("market"):
				for g in D.GOOD_ORDER:
					if e.trades(g, w):
						sp[g] = e.price(g, w)
				sp["_day"] = e.day
			elif e.seen_prices.has(w):
				sp = e.seen_prices[w]
			if not sp.is_empty():
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
			elif wd.services.has("market"):
				col.add_child(UI.label(UI.tr_s("Not visited yet."), 15, UI.c("dim")))

# ================================================================ Ship Layout

func _toggle_paint() -> void:
	_e().flags["paint_on"] = not _e().flags.get("paint_on", true)
	_changed()

func _ship(box: VBoxContainer) -> void:
	var e = _e()
	var hd: Dictionary = e.hull_data()
	var title := UI.tr_s(e.ship_name())
	if e.ship == "runner":
		title += "  ·  %s (%s)" % [UI.tr_s(hd.name), UI.tr_s(hd.mk)]
	box.add_child(UI.label(title, 24, UI.c("accent")))
	if e.ship == "runner":
		box.add_child(UI.label(UI.tr_s("Old Marrow's ship. Fast, quiet, and the Ledger can't see it: the Ghost Core stays through every refit."), 15, UI.c("dim"), true))
	else:
		box.add_child(UI.label(UI.tr_s(D.SHIPS.moth.desc), 15, UI.c("dim"), true))
	if str(e.flags.get("paint", "")) != "":
		var on: bool = e.flags.get("paint_on", true)
		box.add_child(UI.button(UI.tr_s("Paint: VEND-O-MATIC gold") + ("  ✔" if on else "  ✖"), _toggle_paint, UI.c("go") if on else UI.c("accent"), 17, 44))
	var stats := UI.tr_s("Hold %d · Hidden %d · Tank %d · Hull %d · Shield %d · Guns %d · Stealth %d · Crew %d") % [
		e.cargo_cap(), e.hidden_cap(), e.tank(), e.max_hull(), e.shield(), e.guns(), e.stealth(), e.crew_slots()]
	box.add_child(UI.label(stats, 17, UI.c("text"), true))
	box.add_child(UI.label(UI.tr_s("Sockets: %d weapons, %d engines, %d shields, %d specials. Swap any part you own here; buy and refit at a shipyard.") % [
		e.sockets("weapons"), e.sockets("engines"), e.sockets("shields"), e.sockets("special")], 15, UI.c("dim"), true))
	for slot in D.SLOTS:
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		var l := UI.label(UI.tr_s(D.SLOT_NAMES[slot]), 18, UI.c("accent"))
		l.custom_minimum_size.x = 150
		row.add_child(l)
		for id in e.modules_for(slot):
			var fitted: bool = e.modules.get(slot) == id
			var b := UI.button(UI.tr_s(D.MODULES[id].name), _fit.bind(id), UI.c("go") if fitted else UI.c("accent"), 15, 38)
			b.tooltip_text = Dock.module_effect(id)
			row.add_child(b)
		row.add_child(UI.label(Dock.module_effect(e.modules[slot]), 14, UI.c("dim")))
		box.add_child(row)
	var srow := HFlowContainer.new()
	srow.add_theme_constant_override("h_separation", 8)
	var sl := UI.label(UI.tr_s("Special") + " %d/%d" % [e.specials.size(), e.sockets("special")], 18, UI.c("accent"))
	sl.custom_minimum_size.x = 150
	srow.add_child(sl)
	for id in e.modules_for("special"):
		var on: bool = e.specials.has(id)
		var b := UI.button(("✔ " if on else "") + UI.tr_s(D.MODULES[id].name), _toggle_special.bind(id), UI.c("go") if on else UI.c("accent"), 15, 38)
		b.tooltip_text = Dock.module_effect(id)
		b.disabled = not on and e.specials.size() >= e.sockets("special")
		srow.add_child(b)
	if e.modules_for("special").is_empty():
		srow.add_child(UI.label(UI.tr_s("None owned."), 15, UI.c("dim")))
	box.add_child(srow)
	# the ship itself, parts showing, on the right
	_ship_pic = Control.new()
	_ship_pic.anchor_left = 0.6
	_ship_pic.anchor_right = 1.0
	_ship_pic.anchor_top = 0.0
	_ship_pic.anchor_bottom = 1.0
	_ship_pic.offset_top = game.hud_height()
	_ship_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ship_pic.draw.connect(_draw_ship.bind(_ship_pic))
	add_child(_ship_pic)

func _draw_ship(c: Control) -> void:
	var e = _e()
	ShipArt.draw(c, c.size / 2.0, minf(c.size.x * 0.5, c.size.y * 0.5), -PI / 2.0, ShipArt.spec_of(e), true, 0.35 if e.shield() > 0 else 0.0, _clock)

func _fit(id: String) -> void:
	_e().fit_module(id)
	_changed()

func _toggle_special(id: String) -> void:
	var e = _e()
	if e.specials.has(id):
		e.unfit_special(id)
	else:
		e.fit_module(id)
	_changed()

# ================================================================ Stats

func _stats(box: VBoxContainer) -> void:
	var e = _e()
	var nw: int = e.net_worth()
	box.add_child(UI.label(UI.tr_s("Net worth: %s") % UI.num(nw), 28, UI.c("go")))
	box.add_child(UI.label(UI.tr_s("Goal: %s (clean enough to spend)") % UI.num(D.GOAL_NET_WORTH), 16, UI.c("dim")))
	box.add_child(UI.meter("", log(maxf(1.0, float(nw))), log(float(D.GOAL_NET_WORTH)), UI.c("go"), 0.0, " "))
	box.add_child(UI.label(UI.tr_s("Net worth = clean credits + ship and parts + cargo + 30% of dirty credits − debt."), 15, UI.c("dim"), true))
	_h(box, UI.tr_s("Heat"))
	box.add_child(UI.label("%s: %d · %s" % [UI.tr_s("Accord patrols"), int(e.heat_of()), UI.tr_s(e.heat_tier())], 18, game._heat_color(e.heat_of())))
	if e.has_skill("fo_ghost"):
		var gb := UI.button(UI.tr_s("🪪 Ghost Identity: wipe your heat"), _ghost, UI.c("warn"), 18, 44)
		gb.disabled = e.ghost_used
		box.add_child(gb)
	_h(box, UI.tr_s("Record"))
	var s: Dictionary = e.stats
	var lines := [
		UI.tr_s("Day %d · level %d") % [e.day, e.level()],
		UI.tr_s("Dockings: %d · trips: %d · gate jumps: %d") % [s.runs, s.trips, s.jumps],
		UI.tr_s("Scans passed: %d · failed: %d · bribes: %d") % [s.scans_passed, s.scans_failed, s.bribes],
		UI.tr_s("Fights won: %d · lost: %d · ships boarded: %d") % [s.fights_won, s.fights_lost, s.boarded],
		UI.tr_s("Quests done: %d · contracts done: %d · salvages: %d") % [s.quests, s.contracts, s.salvages],
		UI.tr_s("Trade profit: %s · best haul: %s") % [UI.num(s.profit), UI.num(s.best_haul)],
		UI.tr_s("Laundered: %s") % UI.num(s.laundered),
	]
	for l in lines:
		box.add_child(UI.label(l, 18))

func _ghost() -> void:
	_e().use_ghost_identity()
	_changed()

# ================================================================ Factions (§7, §8)

func _factions(box: VBoxContainer) -> void:
	var e = _e()
	_h(box, UI.tr_s("Alignment"))
	box.add_child(UI.label(UI.tr_s("Two bars, filled separately; they never go down. Quests add to one of them."), 15, UI.c("dim"), true))
	for b in ["paragon", "outlaw"]:
		var bar_name := "☀ " + UI.tr_s("Paragon") if b == "paragon" else "☾ " + UI.tr_s("Outlaw")
		var t: String = e.title_of(b)
		box.add_child(UI.meter(bar_name, float(e.bars[b]), 100.0, Color("ffd36a") if b == "paragon" else Color("b38cff"), 130.0, "%d%s" % [int(e.bars[b]), "  · " + UI.tr_s(t) if t != "" else ""]))
		for m in S.BAR_MILESTONES[b]:
			var on: bool = int(e.bars[b]) >= int(m[0])
			box.add_child(UI.label("%s %d · %s: %s" % ["✔" if on else "○", int(m[0]), UI.tr_s(m[1]), UI.tr_s(m[2])], 14, UI.c("go") if on else UI.c("dim"), true))
	var calls: Array = e.calls()
	if not calls.is_empty():
		var bits := []
		for a in calls:
			bits.append("%s %s%s" % [S.ABILITIES[a].icon, UI.tr_s(S.ABILITIES[a].name), "" if e.call_ready(a) else " (" + UI.tr_s("used") + ")"])
		box.add_child(UI.label(UI.tr_s("Battle calls (once per run): %s") % ", ".join(bits), 16, UI.c("warn"), true))
	for bloc in ["paragon", "outlaw", "neutral"]:
		_h(box, UI.tr_s(S.BLOC_NAMES[bloc]))
		for f in S.FACTION_ORDER:
			var fd: Dictionary = S.FACTIONS[f]
			if fd.bloc != bloc:
				continue
			var r: int = e.rep_of(f)
			var col := UI.c("go") if r >= 500 else (UI.c("bad") if r < 0 else UI.c("text"))
			box.add_child(UI.meter(UI.faction_name(f), maxf(0.0, r), 1000.0, col, 230.0, "%d%%" % e.rep_pct(f)))
			var on := []
			for t in ["50", "75", "100"]:
				if r >= int(t) * 10:
					on.append(UI.tr_s(fd.bonuses[t].text))
			var next := ""
			for t in ["50", "75", "100"]:
				if r < int(t) * 10:
					next = UI.tr_s("At %s%%: %s") % [t, UI.tr_s(fd.bonuses[t].text)]
					break
			if not on.is_empty():
				box.add_child(UI.label("✔ " + " · ".join(on), 14, UI.c("go"), true))
			if next != "":
				box.add_child(UI.label(next, 14, UI.c("dim"), true))
			if r < S.REP_HOSTILE:
				box.add_child(UI.label(UI.tr_s("Hostile: their ships attack, their ports are closed."), 14, UI.c("bad")))
			elif r < 0:
				box.add_child(UI.label(UI.tr_s("No work for you, +20% prices."), 14, UI.c("warn")))

# ================================================================ Crew (§10)

func _crew(box: VBoxContainer) -> void:
	var e = _e()
	box.add_child(UI.label(UI.tr_s("Crew slots: %d of %d (a bigger hull has more).") % [e.crew.size(), e.crew_slots()], 18))
	box.add_child(UI.label(UI.tr_s("Each crew member brings a racial perk, a personal perk and their race's flaw at half strength. Unpaid crew lose loyalty and leave at zero."), 15, UI.c("dim"), true))
	if e.crew.is_empty():
		box.add_child(UI.label(UI.tr_s("Nobody aboard yet. Do a crew member's quest on their planet, then hire them there."), 17, UI.c("dim"), true))
	for m in e.crew:
		Dock.crew_card(box, e, m.id, false, self)
	var waiting: Array = e.recruitable.filter(func(c): return e.crew_member(c).is_empty())
	if not waiting.is_empty():
		_h(box, UI.tr_s("Waiting for you"))
		for cid in waiting:
			box.add_child(UI.label("• %s · %s" % [UI.tr_s(S.CREW[cid].name), UI.world_name(S.CREW[cid].planet)], 16))

func _dismiss(cid: String) -> void:
	_e().dismiss(cid)
	_changed()

# ================================================================ Captain (§2, §5)

func _captain(box: VBoxContainer) -> void:
	var e = _e()
	var cap: Dictionary = e.captain
	var top := UI.hbox(14)
	top.add_child(UI.portrait(UI.captain_portrait_id(cap), 160))
	var who := UI.vbox(4)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(who)
	box.add_child(top)
	who.add_child(UI.label(str(cap.name), 28, UI.c("accent")))
	who.add_child(UI.label("%s · %s · %s" % [UI.tr_s(cap.gender), UI.race_name(cap.race), UI.faction_name(cap.home)], 18, UI.c("text"), true))
	if e.ship == "runner":
		var core := UI.tr_s("Ghost Core: stolen by Queen Vask") if not e.ghost_core() else UI.tr_s("Ghost Core: Blind Nodes %d of 3") % e.nodes
		who.add_child(UI.label(core, 16, UI.c("warn") if not e.ghost_core() else UI.c("dim"), true))
	var perks_of_place := []
	if e.flags.has("safehouse"):
		perks_of_place.append(UI.tr_s("a safehouse (heat cools twice as fast)"))
	if str(e.flags.get("safe_dock", "")) != "":
		perks_of_place.append(UI.tr_s("a safe dock at %s") % UI.world_name(str(e.flags.safe_dock)))
	for w in e.tributaries:
		perks_of_place.append(UI.tr_s("tribute from %s") % UI.world_name(str(w)))
	if e.flags.has("kessel_nemesis"):
		perks_of_place.append(UI.tr_s("Mother Kessel's hunters on your trail"))
	if not perks_of_place.is_empty():
		for line in perks_of_place:
			who.add_child(UI.label("• " + line, 15, UI.c("text"), true))
	if e.ending != "":
		who.add_child(UI.label(UI.tr_s("Ending: %s") % UI.tr_s(S.ENDINGS[e.ending].title), 18, UI.c("go"), true))
	_h(box, UI.tr_s("Perks aboard"))
	box.add_child(UI.label(UI.tr_s("Same perk from two sources: the second counts half, a third not at all. A stat's bonuses stop at +60%, its flaws at −40%."), 15, UI.c("dim"), true))
	for p in e.perk_list():
		var pd: Dictionary = S.PERKS[p[0]]
		var src := _source(str(p[2]))
		var strength := "" if is_equal_approx(float(p[1]), 1.0) else " (%d%%)" % int(round(float(p[1]) * 100))
		var col := UI.c("go") if pd.kind == "good" else UI.c("bad")
		box.add_child(UI.label("%s %s%s: %s  — %s" % ["✚" if pd.kind == "good" else "✖", UI.perk_name(p[0]), strength, UI.perk_desc(p[0]), src], 15, col, true))
	if not e.curses.is_empty():
		box.add_child(UI.label(UI.tr_s("Curses wear off on their own."), 14, UI.c("dim")))

func _source(s: String) -> String:
	if s == "race":
		return UI.tr_s("your race")
	if s == "pick":
		return UI.tr_s("your pick")
	if s == "curse":
		return UI.tr_s("curse")
	if S.CREW.has(s):
		return UI.tr_s(S.CREW[s].name)
	if S.FACTIONS.has(s):
		return UI.faction_name(s)
	return s
