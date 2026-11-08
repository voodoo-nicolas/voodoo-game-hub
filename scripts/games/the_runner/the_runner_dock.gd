extends Control

## A world's dock: its picture (the cockpit view of the world, the owner's art as it is) with the
## port's services down the left side, and the news on the right. Pages open over the hangar picture
## (‹ Back returns here): Market, Shipyard (parts, specials, hull refits), Fixer (contracts and
## bounties), Job board (quests, design doc v2 §11), Crew for hire (§10), Faction office (rep repair,
## §7.4), the Laundry and Kessel's collector. A quest with a choice or a faction pick is handed in on
## its own page.

const D = preload("res://scripts/games/the_runner/the_runner_data.gd")
const S = preload("res://scripts/games/the_runner/the_runner_spiral.gd")
const UI = preload("res://scripts/games/the_runner/the_runner_ui.gd")

var game: Control
var page := ""                  # "" = the dock, else market / shipyard / fixer / jobs / crew / office / laundry / kessel / handin
var _qty := 1                   # market: units per tap (1 / 5 / max)
var _note := ""                 # one line of feedback on a page (translated)
var _quest := ""                # handin page: which quest

func _ready() -> void:
	rebuild()

func _e():
	return game.engine

func rebuild() -> void:
	for ch in get_children():
		ch.queue_free()
	var e = _e()
	var wd: Dictionary = D.WORLDS[e.loc]
	add_child(UI.backdrop(str(wd.view) if page == "" else str(wd.dock)))
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.18 if page == "" else 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	match page:
		"market": _market()
		"shipyard": _shipyard()
		"fixer": _fixer()
		"jobs": _jobs()
		"crew": _crew()
		"office": _office()
		"laundry": _laundry()
		"kessel": _kessel()
		"handin": _handin()
		_: _dock()

func open(p: String) -> void:
	page = p
	_note = ""
	rebuild()

func _top() -> float:
	return game.hud_height() + 10

## A panel from `left` to `right` (fractions of the width). `fit`: only as tall as its content.
func _column(left: float, right: float, fit: bool = false) -> VBoxContainer:
	var p := UI.panel(0.9)
	p.anchor_left = left
	p.anchor_right = right
	p.anchor_top = 0.0
	p.anchor_bottom = 0.0 if fit else 1.0
	p.offset_top = _top()
	p.offset_bottom = 0 if fit else -10
	p.offset_left = 10 if left == 0.0 else 0
	p.offset_right = -10 if right == 1.0 else 0
	add_child(p)
	var box := UI.vbox(6)
	p.add_child(box if fit else UI.scroll(box))
	return box

func _page_head(box: VBoxContainer, title: String) -> void:
	var row := UI.hbox(10)
	row.add_child(UI.button("‹ " + UI.tr_s("Back"), open.bind(""), UI.c("accent"), 20, 46))
	row.add_child(UI.label(title, 26, UI.c("accent")))
	box.add_child(row)
	if _note != "":
		box.add_child(UI.label(_note, 18, UI.c("warn"), true))

func _changed(note: String = "") -> void:
	_note = note
	game.refresh()

# ================================================================ the dock

func _dock() -> void:
	var e = _e()
	var wd: Dictionary = D.WORLDS[e.loc]
	var box := _column(0.0, 0.36)
	# 🚀 Launch is pinned under the list, so it never scrolls away on a short screen
	var outer := VBoxContainer.new()
	var scroll: Control = box.get_parent()
	var panel: Control = scroll.get_parent()
	panel.remove_child(scroll)
	panel.add_child(outer)
	outer.add_child(scroll)
	box.add_child(UI.label(UI.world_name(e.loc), 30, UI.c("accent")))
	var f: String = wd.faction
	var rep_txt := "" if f == "none" else " · %d%%" % e.rep_pct(f)
	box.add_child(UI.label("%s%s · %s" % [UI.faction_name(f), rep_txt, UI.tr_s("Law %d") % e.law_at(e.loc)], 18, UI.c("dim"), true))
	if e.port_closed():
		box.add_child(UI.label(UI.tr_s("This port is closed to you. Only the fuel dock still serves you."), 18, UI.c("bad"), true))
	# quests and contracts that end here
	for id in e.active_quests():
		if e.can_complete(id) and e.needs_hand_in(id):
			box.add_child(UI.button("📦 " + UI.tr_s("Hand in: %s") % UI.tr_s(S.QUESTS[id].title), _handin_open.bind(id), UI.c("go"), 20, 50))
	for c in e.deliverable_contracts():
		var t := UI.tr_s("Deliver %d x %s") % [c.qty, UI.good_name(c.good)] if c.kind == "carry" else UI.tr_s("Collect the bounty")
		box.add_child(UI.button("📦 " + t, _deliver.bind(c.id), UI.c("go"), 20, 50))
	var jobs: Array = e.quest_offers()
	if not jobs.is_empty():
		var open_n: int = jobs.filter(func(j): return j[1].is_empty()).size()
		box.add_child(UI.button("❗ " + UI.tr_s("Job board (%d)") % open_n, open.bind("jobs"), UI.c("warn"), 22, 52))
	if _crew_here().size() > 0:
		box.add_child(UI.button("🧑‍🚀 " + UI.tr_s("Crew for hire"), open.bind("crew"), UI.c("warn"), 22, 52))
	if e.has_service("market"):
		box.add_child(UI.button("🛒 " + UI.tr_s("Market"), open.bind("market"), UI.c("accent"), 22, 52))
	if e.has_service("shipyard"):
		box.add_child(UI.button("🔧 " + UI.tr_s("Shipyard"), open.bind("shipyard"), UI.c("accent"), 22, 52))
	if e.has_service("fixer"):
		box.add_child(UI.button("🤝 " + UI.tr_s("Fixer: jobs"), open.bind("fixer"), UI.c("accent"), 22, 52))
	if e.has_service("office"):
		box.add_child(UI.button("🏛 " + UI.tr_s("Faction office"), open.bind("office"), UI.c("accent"), 22, 52))
	if e.has_service("front") and e.flags.has("black_market"):
		box.add_child(UI.button("🧺 " + UI.tr_s("The laundry"), open.bind("laundry"), UI.c("accent"), 22, 52))
	if e.has_service("collector"):
		box.add_child(UI.button("💰 " + UI.tr_s("Kessel's collector"), open.bind("kessel"), UI.c("accent"), 22, 52))
	if e.has_service("salvage"):
		box.add_child(UI.button("🔍 " + UI.tr_s("Search the wrecks (1 day)"), _salvage, UI.c("accent"), 22, 52))
	if e.has_service("fuel"):
		var room := int(floor(float(e.tank()) - e.fuel))
		var fb := UI.button("⛽ " + UI.tr_s("Refuel: %s") % UI.num(room * e.fuel_price()), _refuel, UI.c("accent"), 22, 52)
		fb.disabled = room <= 0 or e.total_credits() < e.fuel_price()
		box.add_child(fb)
	if e.has_service("shipyard") and e.hull < e.max_hull():
		var rb := UI.button("🛠 " + UI.tr_s("Repair: %s") % UI.num(e.repair_cost()), _repair, UI.c("accent"), 22, 52)
		rb.disabled = e.repair_cost() > 0 and e.total_credits() < int(ceil(e.repair_unit()))
		box.add_child(rb)
	if e.can_borrow():
		box.add_child(UI.button("💸 " + UI.tr_s("Borrow 500 from Kessel (owe 600)"), _borrow, UI.c("warn"), 20, 52))
	outer.add_child(UI.button("🚀 " + UI.tr_s("Launch"), game.launch, UI.c("go"), 24, 60))
	for ch in box.get_children():
		if ch is Button:
			ch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # the column is narrow; long Spanish wraps
	_news()

func _news() -> void:
	var e = _e()
	if e.news.is_empty() and e.events.is_empty():
		return
	var p := UI.panel(0.85)
	p.anchor_left = 0.62
	p.anchor_right = 1.0
	p.anchor_top = 0.58
	p.anchor_bottom = 1.0
	p.offset_right = -10
	p.offset_bottom = -10
	add_child(p)
	var box := UI.vbox(4)
	p.add_child(UI.scroll(box))
	box.add_child(UI.label("📡 " + UI.tr_s("News"), 20, UI.c("accent")))
	for i in mini(4, e.news.size()):
		box.add_child(UI.label("• " + UI.msg(e.news[i]), 16, UI.c("text"), true))

func _deliver(cid: String) -> void:
	if _e().deliver_contract(cid):
		game.trade_sound()
	_changed()

func _salvage() -> void:
	if _e().start_salvage():
		game.show_encounter()
	game.refresh_hud()

func _refuel() -> void:
	if _e().buy_fuel() > 0:
		game.trade_sound()
	_changed()

func _repair() -> void:
	_e().repair()
	_changed()

func _borrow() -> void:
	_e().borrow()
	_changed()

# ================================================================ job board (quests)

static func reward_text(q: Dictionary) -> String:
	var bits := []
	var cr := int(q.get("credits", 0))
	if cr > 0:
		bits.append(UI.dirty_txt(cr) if str(q.get("money", "clean")) == "dirty" else UI.clean_txt(cr))
	if q.has("xp"):
		bits.append(UI.tr_s("%d XP") % int(q.xp))
	if q.has("points"):
		bits.append(UI.tr_s("+%d skill point") % int(q.points))
	var fd: Dictionary = q.get("faction", {})
	for f in fd:
		bits.append("%s %s%d" % [UI.faction_name(f), "+" if int(fd[f]) > 0 else "", int(fd[f])])
	if q.has("pick"):
		bits.append(UI.tr_s("+%d rep with a faction you pick") % int(q.pick_fp))
	var b: Dictionary = q.get("bars", {})
	if int(b.get("paragon", 0)) > 0:
		bits.append(UI.tr_s("Paragon +%d") % int(b.paragon))
	if int(b.get("outlaw", 0)) > 0:
		bits.append(UI.tr_s("Outlaw +%d") % int(b.outlaw))
	if q.has("recruit"):
		bits.append(UI.tr_s("%s can join you") % UI.tr_s(S.CREW[q.recruit].name))
	if q.has("ship"):
		bits.append(UI.tr_s("a ship"))
	if q.has("choices"):
		bits.append(UI.tr_s("a choice at the end"))
	return UI.tr_s("Reward: %s") % ", ".join(bits)

static func quest_title(id: String) -> String:
	var q: Dictionary = S.QUESTS[id]
	var t := UI.tr_s(q.title)
	if q.has("sub"):
		t += " (" + UI.tr_s(q.sub) + ")"
	return t

const KIND_ICON := {"main": "★", "neutral": "◇", "crew": "🧑‍🚀", "paragon": "☀", "outlaw": "☾", "favor": "✉"}

func _jobs() -> void:
	var e = _e()
	var box := _column(0.0, 1.0)
	_page_head(box, "❗ " + UI.tr_s("Job board"))
	box.add_child(UI.label(UI.tr_s("Quests change only the factions they list. ☀ Paragon, ☾ Outlaw, ✉ a favour, 🧑‍🚀 someone who could join your crew. Active quests: %d of %d.") % [e.side_active(), e.quest_slots()], 16, UI.c("dim"), true))
	for j in e.quest_offers():
		var id: String = j[0]
		var q: Dictionary = S.QUESTS[id]
		var p := UI.panel(0.6)
		box.add_child(p)
		var col := UI.vbox(3)
		p.add_child(col)
		var row := UI.hbox(10)
		var tl := UI.label("%s %s" % [KIND_ICON.get(q.kind, "•"), quest_title(id)], 20, UI.c("accent"))
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tl)
		var b := UI.button(UI.tr_s("Take the job"), _accept.bind(id), UI.c("go"), 18, 42)
		b.disabled = not j[1].is_empty()
		row.add_child(b)
		col.add_child(row)
		col.add_child(UI.label(UI.tr_s(q.brief), 16, UI.c("text"), true))
		col.add_child(UI.label(reward_text(q), 15, UI.c("clean"), true))
		if not j[1].is_empty():
			col.add_child(UI.label("🔒 " + UI.msg(j[1]), 15, UI.c("warn")))

func _accept(id: String) -> void:
	if _e().accept_quest(id):
		_note = UI.tr_s("Taken: %s.") % UI.tr_s(S.QUESTS[id].title)
		game._sfx("tap")
		var done: Array = _e().auto_complete()
		game._after_missions(done)
		game._flush_story()
	game.refresh()

func _handin_open(id: String) -> void:
	_quest = id
	open("handin")

func _handin() -> void:
	var e = _e()
	var q: Dictionary = S.QUESTS[_quest]
	var box := _column(0.15, 0.85, true)
	_page_head(box, quest_title(_quest))
	box.add_child(UI.label(UI.tr_s(q.brief), 18, UI.c("text"), true))
	if not e.can_complete(_quest):
		box.add_child(UI.label(UI.tr_s("Not ready to hand in."), 18, UI.c("warn")))
		return
	if q.has("choices"):
		box.add_child(UI.label(UI.tr_s("Decide:"), 20, UI.c("accent")))
		for i in q.choices.size():
			var c: Dictionary = q.choices[i]
			var b := UI.button(UI.tr_s(c.label), _complete.bind(i, ""), UI.c("go"), 20, 52, true)
			box.add_child(b)
			box.add_child(UI.label(reward_text(c).trim_prefix(UI.tr_s("Reward: %s") % ""), 15, UI.c("clean"), true))
	elif q.has("pick"):
		box.add_child(UI.label(UI.tr_s("Which faction gets the credit?"), 20, UI.c("accent")))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for f in e.pick_options(_quest):
			flow.add_child(UI.button("%s (%d%%)" % [UI.faction_name(f), e.rep_pct(f)], _complete.bind(-1, f), UI.c("accent"), 17, 46))
		box.add_child(flow)
	else:
		box.add_child(UI.button(UI.tr_s("Hand it over"), _complete.bind(-1, ""), UI.c("go"), 22, 54))

func _complete(choice: int, pick: String) -> void:
	var lines: Array = _e().complete(_quest, choice, pick)
	game._after_missions([_quest])
	page = ""
	game._show_result(lines)
	game._flush_story()
	game.refresh()

# ================================================================ crew for hire

func _crew_here() -> Array:
	var e = _e()
	var out := []
	for cid in S.CREW_ORDER:
		if str(S.CREW[cid].planet) == e.loc and e.recruitable.has(cid):
			out.append(cid)
	return out

func _crew() -> void:
	var e = _e()
	var box := _column(0.0, 1.0)
	_page_head(box, "🧑‍🚀 " + UI.tr_s("Crew for hire"))
	box.add_child(UI.label(UI.tr_s("Crew slots: %d of %d. A crew member refuses a ship with a race they hate aboard. Paragon and Outlaw crew need 3 points on their bar.") % [e.crew.size(), e.crew_slots()], 16, UI.c("dim"), true))
	for cid in _crew_here():
		crew_card(box, e, cid, true, self)

## A crew member's card (also used by the Menu's Crew tab). `hire`: show the hire button.
static func crew_card(box: VBoxContainer, e, cid: String, hire: bool, owner: Object) -> void:
	var c: Dictionary = S.CREW[cid]
	var p := UI.panel(0.6)
	box.add_child(p)
	var col := UI.vbox(3)
	p.add_child(col)
	var row := UI.hbox(10)
	var em := ColorRect.new()
	em.color = Color(S.RACES[c.race].color)
	em.custom_minimum_size = Vector2(22, 22)
	em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(em)
	var align: String = {"paragon": "☀ " + UI.tr_s("Paragon"), "outlaw": "☾ " + UI.tr_s("Outlaw"), "neutral": UI.tr_s("Neutral")}[c.align]
	var tl := UI.label("%s · %s · %s · %s" % [UI.tr_s(c.name), UI.tr_s(c.role), UI.race_name(c.race), align], 19, UI.c("accent"), true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tl)
	if hire:
		var block: Dictionary = e.hire_block(cid)
		var b := UI.button(UI.tr_s("Hire (%s)") % UI.num(int(c.fee)) if int(c.fee) > 0 else UI.tr_s("Take aboard"), owner._hire.bind(cid), UI.c("go"), 18, 42)
		b.disabled = not block.is_empty()
		row.add_child(b)
	else:
		row.add_child(UI.button(UI.tr_s("Let go"), owner._dismiss.bind(cid), UI.c("bad"), 16, 38))
	col.add_child(row)
	col.add_child(UI.label("✚ %s · ✚ %s · ✖ %s (%d%%)" % [UI.perk_name(c.racial), UI.perk_name(c.personal), UI.perk_name(c.quirk), int(D.CONFIG.crew_flaw_strength * 100)], 15, UI.c("text"), true))
	var m: Dictionary = e.crew_member(cid)
	var line := UI.tr_s("Wage %s a day") % UI.num(e.crew_wage(cid))
	if not m.is_empty():
		line += " · " + UI.tr_s("loyalty %d") % int(m.loyalty)
		if e.clash(cid):
			line += " · " + UI.tr_s("ideology clash")
	col.add_child(UI.label(line, 15, UI.c("dim")))
	if hire:
		var block2: Dictionary = e.hire_block(cid)
		if not block2.is_empty():
			col.add_child(UI.label("🔒 " + UI.msg(block2), 15, UI.c("warn")))

func _hire(cid: String) -> void:
	if _e().hire(cid):
		game.trade_sound()
		_changed(UI.tr_s("%s joins your crew.") % UI.tr_s(S.CREW[cid].name))
	else:
		_changed()

func _dismiss(cid: String) -> void:
	_e().dismiss(cid)
	_changed()

# ================================================================ faction office

func _office() -> void:
	var e = _e()
	var f := str(D.WORLDS[e.loc].faction)
	var fd: Dictionary = S.FACTIONS[f]
	var box := _column(0.15, 0.85, true)
	_page_head(box, "🏛 " + UI.faction_name(f))
	box.add_child(UI.label("%s · %s · %s" % [UI.tr_s(S.BLOC_NAMES[fd.bloc]), UI.tr_s(fd.leader), UI.tr_s(fd.ideology)], 16, UI.c("dim"), true))
	box.add_child(UI.meter(UI.tr_s("Your rep"), maxf(0.0, e.rep_of(f)), 1000.0, UI.c("go") if e.rep_of(f) >= 0 else UI.c("bad"), 150.0, "%d%%" % e.rep_pct(f)))
	for t in ["50", "75", "100"]:
		var on: bool = e.rep_of(f) >= int(t) * 10
		box.add_child(UI.label("%s %s%%: %s" % ["✔" if on else "○", t, UI.tr_s(fd.bonuses[t].text)], 16, UI.c("go") if on else UI.c("text"), true))
	box.add_child(UI.label(UI.tr_s("A donation buys +10% rep for 1,000 credits, up to 50%. Rep above that is earned."), 16, UI.c("dim"), true))
	var b := UI.button(UI.tr_s("Donate 1,000 (+10%)"), _buy_rep.bind(f), UI.c("go"), 20, 50)
	b.disabled = not e.can_buy_rep(f)
	box.add_child(b)

func _buy_rep(f: String) -> void:
	if _e().buy_rep(f):
		game.trade_sound()
	_changed()

# ================================================================ market

func _market() -> void:
	var e = _e()
	var box := _column(0.0, 1.0)
	_page_head(box, "🛒 " + UI.tr_s("Market"))
	var info := UI.hbox(16)
	info.add_child(UI.label(UI.tr_s("Hold: %d/%d") % [e.used(e.cargo), e.cargo_cap()], 18))
	info.add_child(UI.label(UI.tr_s("Hidden hold: %d/%d") % [e.used(e.hidden), e.hidden_cap()], 18, UI.c("dirty")))
	info.add_child(UI.label(UI.clean_txt(e.clean), 18, UI.c("clean")))
	info.add_child(UI.label(UI.dirty_txt(e.dirty), 18, UI.c("dirty")))
	box.add_child(info)
	var tools := UI.hbox(8)
	tools.add_child(UI.label(UI.tr_s("Per tap:"), 18, UI.c("dim")))
	for q in [1, 5, 99]:
		var qb := UI.button("×%d" % q if q < 99 else UI.tr_s("Max"), _set_qty.bind(q), UI.c("go") if _qty == q else UI.c("accent"), 18, 40)
		tools.add_child(qb)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(sp)
	var hl: int = game.hints_left()
	var hint := UI.button("💡 " + UI.tr_s("Fixer's tip (%d)") % hl, _tip, UI.c("warn"), 18, 40)
	hint.disabled = hl <= 0
	tools.add_child(hint)
	if hl <= 0:
		var wait: int = game.hint_wait()
		tools.add_child(UI.label(UI.tr_s("Next tip in %dh %dm") % [wait / 3600, (wait % 3600) / 60], 16, UI.c("dim")))
	box.add_child(tools)
	if not e.flags.has("black_market") and e.world().get("black", false):
		box.add_child(UI.label(UI.tr_s("There's a black market here, but nobody trusts you yet. Finish the dockmaster's first run."), 16, UI.c("dim"), true))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for h in ["Goods", "Buy", "Sell", "Aboard", "", ""]:
		grid.add_child(UI.label(UI.tr_s(h) if h != "" else "", 16, UI.c("dim")))
	for g in D.GOOD_ORDER:
		if not e.trades(g):
			continue
		var gd: Dictionary = D.GOODS[g]
		var name_l := UI.label(("◆ " if gd.contraband else "") + UI.good_name(g), 19, UI.c("dirty") if gd.contraband else UI.c("text"))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_l)
		var p: int = e.price(g)
		var trend := ""
		if p > int(gd.base) * 1.15:
			trend = " ▲"
		elif p < int(gd.base) * 0.85:
			trend = " ▼"
		grid.add_child(UI.label(UI.num(p) + trend, 19, UI.c("warn") if trend == " ▲" else (UI.c("go") if trend == " ▼" else UI.c("text"))))
		grid.add_child(UI.label(UI.num(e.sell_price(g)), 19))
		var have: int = e.qty(g)
		var res: int = e.reserved(g)
		grid.add_child(UI.label(str(have) + (" (%d)" % res if res > 0 else ""), 19, UI.c("dim") if have == 0 else UI.c("text")))
		var buy := UI.button(UI.tr_s("Buy"), _buy.bind(g), UI.c("go"), 18, 40)
		buy.disabled = e.max_buy(g) <= 0
		grid.add_child(buy)
		var sell := UI.button(UI.tr_s("Sell"), _sell.bind(g), UI.c("accent"), 18, 40)
		sell.disabled = have - res <= 0
		grid.add_child(sell)
	box.add_child(UI.label(UI.tr_s("◆ Contraband: paid and sold in dirty credits, stowed in the hidden hold first. Legal goods pay clean credits."), 15, UI.c("dim"), true))
	box.add_child(UI.label(UI.tr_s("Supply and demand: every crate you buy pushes this port's price up, every crate you sell pushes it down. Prices drift back over the days."), 15, UI.c("dim"), true))

func _set_qty(q: int) -> void:
	_qty = q
	rebuild()

func _buy(g: String) -> void:
	var n: int = _e().buy(g, _qty)
	if n > 0:
		game.trade_sound()
	_changed("" if n > 0 else UI.tr_s("Not enough credits or room."))

func _sell(g: String) -> void:
	var got: int = _e().sell(g, _qty)
	if got > 0:
		game.trade_sound()
	_changed(UI.tr_s("Sold for %s.") % UI.num(got) if got > 0 else "")

func _tip() -> void:
	var t: Array = _e().best_trade()
	if t.is_empty():
		_changed(UI.tr_s("The fixer shrugs: nothing worth hauling from here today."))
		return
	if not game.use_hint():
		return
	_changed(UI.tr_s("Fixer's tip: buy %s here, sell on %s, about %s profit per crate.") % [UI.good_name(t[0]), UI.world_name(t[1]), UI.num(int(t[2]))])

# ================================================================ shipyard

func _shipyard() -> void:
	var e = _e()
	var box := _column(0.0, 1.0)
	_page_head(box, "🔧 " + UI.tr_s("Shipyard"))
	# hull refit
	var rp: int = e.refit_price()
	if e.ship == "runner":
		if rp > 0:
			var nt: Dictionary = D.TIERS[e.tier]
			var row0 := UI.hbox(10)
			var l0 := UI.label(UI.tr_s("Refit the Runner into a %s (%s): crew %d, weapons %d, engines %d, shields %d, specials %d") % [UI.tr_s(nt.name), UI.tr_s(nt.mk),
				int(nt.crew), int(nt.weapons), int(nt.engines), int(nt.shields), int(nt.special)], 18, UI.c("go"), true)
			l0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row0.add_child(l0)
			var rb := UI.button(UI.num(rp), _refit, UI.c("go"), 18, 44)
			rb.custom_minimum_size.x = 140
			rb.disabled = not e.can_refit()
			row0.add_child(rb)
			box.add_child(row0)
		else:
			box.add_child(UI.label(UI.tr_s("The Runner is a Cruiser: the biggest hull there is."), 17, UI.c("dim")))
	else:
		box.add_child(UI.label(UI.tr_s("The Moth can't be refitted. Old Marrow's ship can."), 17, UI.c("dim")))
	box.add_child(UI.label(UI.tr_s("One model per part kind goes on every socket of that kind. Legal parts cost clean credits; black-market parts cost dirty ones (blind-spot yards, and others once Kessel is paid)."), 16, UI.c("dim"), true))
	var list: Array = e.shop_modules()
	if list.is_empty():
		box.add_child(UI.label(UI.tr_s("Nothing for sale."), 18))
	for slot in D.SLOTS + ["special"]:
		for id in list:
			var m: Dictionary = D.MODULES[id]
			if m.slot != slot:
				continue
			var row := UI.hbox(10)
			var fitted: bool = e.modules.get(slot) == id or e.specials.has(id)
			var owned: bool = e.owned.has(id)
			var name_l := UI.label("%s: %s" % [UI.tr_s(D.SLOT_NAMES[slot]), UI.tr_s(m.name)], 19, UI.c("dirty") if m.money == "dirty" else UI.c("text"))
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_l)
			row.add_child(UI.label(module_effect(id), 16, UI.c("dim")))
			var price: int = e.part_price(id)
			var cost: String = UI.dirty_txt(price) if m.money == "dirty" else UI.clean_txt(price)
			var b := UI.button(UI.tr_s("Fitted") if fitted else (UI.tr_s("Fit") if owned else cost), _buy_module.bind(id), UI.c("go"), 18, 42)
			b.custom_minimum_size.x = 140
			b.disabled = fitted or (not owned and not e.can_pay(price, str(m.money))) or (slot == "special" and e.specials.size() >= e.sockets("special"))
			row.add_child(b)
			box.add_child(row)

static func module_effect(id: String) -> String:
	var m: Dictionary = D.MODULES[id]
	var bits := []
	if m.has("fuel") and float(m.fuel) < 1.0:
		bits.append(UI.tr_s("fuel -%d%%") % int(round((1.0 - float(m.fuel)) * 100)))
	if float(m.get("speed", 0.0)) > 0.0:
		bits.append(UI.tr_s("speed +%d%%") % int(float(m.speed) * 100))
	if int(m.get("cargo", 0)) > 0:
		bits.append(UI.tr_s("+%d hold") % int(m.cargo))
	if int(m.get("hidden", 0)) > 0:
		bits.append(UI.tr_s("+%d hidden") % int(m.hidden))
	if int(m.get("quality", 0)) > 0:
		bits.append(UI.tr_s("scans +%d%%") % (int(m.quality) * 10))
	if int(m.get("shield", 0)) > 0:
		bits.append(UI.tr_s("shield %d per socket") % int(m.shield))
	if float(m.get("dmg", 1.0)) > 1.0:
		bits.append(UI.tr_s("damage x%s") % str(m.dmg))
	if float(m.get("scan", 0.0)) > 0.0:
		bits.append(UI.tr_s("scans +%d%%") % int(float(m.scan) * 100))
	if m.get("sniff", false):
		bits.append(UI.tr_s("shows patrols"))
	if int(m.get("stealth", 0)) > 0:
		bits.append(UI.tr_s("stealth +%d") % int(m.stealth))
	if float(m.get("flee", 0.0)) > 0.0:
		bits.append(UI.tr_s("escape +%d%%") % int(float(m.flee) * 100))
	if float(m.get("salvage", 0.0)) > 0.0:
		bits.append(UI.tr_s("salvage +%d%%") % int(float(m.salvage) * 100))
	if float(m.get("regen", 0.0)) > 0.0:
		bits.append(UI.tr_s("hull +%d%% a minute") % int(float(m.regen) * 100))
	return ", ".join(bits)

func _buy_module(id: String) -> void:
	if _e().buy_module(id):
		game.trade_sound()
	_changed()

func _refit() -> void:
	if _e().refit():
		game.trade_sound()
		if game.info:
			game.info.high("Highest hull tier", _e().tier)
		_changed(UI.tr_s("Refit done: the Runner is now a %s.") % UI.tr_s(D.TIERS[_e().tier - 1].name))
	else:
		_changed()

# ================================================================ fixer (contracts, §11.6)

func _fixer() -> void:
	var e = _e()
	var box := _column(0.0, 1.0)
	_page_head(box, "🤝 " + UI.tr_s("Fixer: jobs"))
	box.add_child(UI.label(UI.tr_s("Carry cargo or hunt a bounty before the due day. Each job done: +5% rep with whoever posted it; every third Accord or black-market job moves your Paragon or Outlaw bar."), 16, UI.c("dim"), true))
	var offers: Array = e.contract_offers()
	if offers.is_empty():
		box.add_child(UI.label(UI.tr_s("No jobs today. Come back tomorrow."), 18))
	for c in offers:
		var row := UI.hbox(10)
		var shady: bool = c.money == "dirty"
		var t := _contract_text(c)
		var l := UI.label(("◆ " if shady else "") + t, 19, UI.c("dirty") if shady else UI.c("text"), true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.label(UI.dirty_txt(c.pay) if shady else UI.clean_txt(c.pay), 19, UI.c("dirty") if shady else UI.c("clean")))
		var b := UI.button(UI.tr_s("Take"), _take.bind(c.id), UI.c("go"), 18, 42)
		b.disabled = c.kind == "carry" and e.space_for(c.good) < int(c.qty)
		row.add_child(b)
		box.add_child(row)
	if not e.contracts.is_empty():
		box.add_child(UI.label(UI.tr_s("Your jobs"), 22, UI.c("accent")))
		for c in e.contracts:
			box.add_child(UI.label("• " + _contract_text(c), 18, UI.c("text"), true))

static func _contract_text(c: Dictionary) -> String:
	if str(c.get("kind", "carry")) == "bounty":
		if c.get("done", false):
			return UI.tr_s("Bounty done: collect at %s") % UI.world_name(c.from)
		return UI.tr_s("Bounty: %s at %s, by day %d") % [UI.tr_s(D.ENEMIES[c.enemy].name), UI.world_name(c.to), c.due]
	return UI.tr_s("%d x %s to %s, by day %d") % [c.qty, UI.good_name(c.good), UI.world_name(c.to), c.due]

func _take(cid: String) -> void:
	_changed("" if _e().take_contract(cid) else UI.tr_s("No room in the hold."))

# ================================================================ laundry

func _laundry() -> void:
	var e = _e()
	var box := _column(0.15, 0.85, true)
	_page_head(box, "🧺 " + UI.tr_s("The laundry"))
	box.add_child(UI.label(UI.tr_s("A Syndicate front. Dirty credits go in, clean ones come out %d days later, minus %d%%. Sometimes the auditors come.") % [1 if e.has_skill("la_fast") else 2, int(round((1.0 - e.launder_rate()) * 100))], 18, UI.c("text"), true))
	box.add_child(UI.label(UI.tr_s("Dirty credits: %s") % UI.num(e.dirty), 20, UI.c("dirty")))
	var row := UI.hbox(10)
	for amt in [500, 1000, 2000, 4000]:
		var b := UI.button(UI.dirty_txt(amt), _launder.bind(amt), UI.c("accent"), 18, 46)
		b.disabled = e.dirty < amt
		row.add_child(b)
	box.add_child(row)
	if not e.laundry.is_empty():
		box.add_child(UI.label(UI.tr_s("In the wash"), 22, UI.c("accent")))
		for b in e.laundry:
			box.add_child(UI.label("• " + UI.tr_s("%s, ready on day %d") % [UI.dirty_txt(int(b.amount)), int(b.ready)], 18))

func _launder(amt: int) -> void:
	_changed(UI.tr_s("In the wash.") if _e().launder(amt) else "")

# ================================================================ Kessel's collector

func _kessel() -> void:
	var e = _e()
	var box := _column(0.15, 0.85, true)
	_page_head(box, "💰 " + UI.tr_s("Kessel's collector"))
	if e.debt <= 0:
		box.add_child(UI.label(UI.tr_s("\"We're square. Mother says hello.\""), 20, UI.c("text"), true))
		return
	box.add_child(UI.label(UI.tr_s("\"You owe Mother %s. Clean or dirty, she's not fussy.\"") % UI.num(e.debt), 20, UI.c("text"), true))
	var row := UI.hbox(10)
	for amt in [500, 1000]:
		var b := UI.button(UI.tr_s("Pay %s") % UI.num(amt), _pay.bind(amt), UI.c("accent"), 18, 46)
		b.disabled = e.total_credits() < 1
		row.add_child(b)
	var all := UI.button(UI.tr_s("Pay it all"), _pay.bind(e.debt), UI.c("go"), 18, 46)
	all.disabled = e.total_credits() < e.debt
	row.add_child(all)
	box.add_child(row)

func _pay(amt: int) -> void:
	var paid: int = _e().pay_debt(amt)
	if paid > 0:
		game.trade_sound()
	var done: Array = _e().auto_complete()
	game._after_missions(done)
	game._flush_story()
	_changed(UI.tr_s("Paid %s.") % UI.num(paid) if paid > 0 else "")
