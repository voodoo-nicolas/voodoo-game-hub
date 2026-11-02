extends Control

## A world's dock: its picture (the cockpit view of the world, the owner's art as it is) with the
## port's services down the left side, and the news on the right. Market, Shipyard, Fixer, Laundry
## and Mother Kessel open as pages over the hangar picture (‹ Back returns here).

const D = preload("res://scripts/games/the_runner/the_runner_data.gd")
const UI = preload("res://scripts/games/the_runner/the_runner_ui.gd")

var game: Control
var page := ""                  # "" = the dock itself, else "market" / "shipyard" / "fixer" / "laundry" / "kessel"
var _qty := 1                   # market: units per tap (1 / 5 / max)
var _note := ""                 # one line of feedback on a page (translated)

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
		"laundry": _laundry()
		"kessel": _kessel()
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
	box.add_child(UI.label("%s · %s" % [UI.tr_s(D.FACTIONS[wd.faction].name), UI.tr_s("Law %d") % e.law_at(e.loc)], 18, UI.c("dim"), true))
	# missions and contracts that end here
	for id in e.active_missions():
		var st: Dictionary = D.MISSIONS[id].steps[0]
		if st.type == "deliver" and e.can_complete(id):
			box.add_child(UI.button("📦 " + UI.tr_s("Hand over: %s") % UI.tr_s(D.MISSIONS[id].title), _complete.bind(id), UI.c("go"), 20, 50))
	for c in e.deliverable_contracts():
		box.add_child(UI.button("📦 " + UI.tr_s("Deliver %d x %s") % [c.qty, UI.good_name(c.good)], _deliver.bind(c.id), UI.c("go"), 20, 50))
	for id in e.side_offers():
		box.add_child(UI.button("❗ " + UI.tr_s("Job: %s") % UI.tr_s(D.MISSIONS[id].title), _offer.bind(id), UI.c("warn"), 20, 50))
	if e.has_service("market"):
		box.add_child(UI.button("🛒 " + UI.tr_s("Market"), open.bind("market"), UI.c("accent"), 22, 52))
	if e.has_service("shipyard"):
		box.add_child(UI.button("🔧 " + UI.tr_s("Shipyard"), open.bind("shipyard"), UI.c("accent"), 22, 52))
	if e.has_service("fixer"):
		box.add_child(UI.button("🤝 " + UI.tr_s("Fixer: jobs"), open.bind("fixer"), UI.c("accent"), 22, 52))
	if e.has_service("front") and e.flags.has("black_market"):
		box.add_child(UI.button("🧺 " + UI.tr_s("Moonwash Laundry"), open.bind("laundry"), UI.c("accent"), 22, 52))
	if e.loc == "luna":
		box.add_child(UI.button("💰 " + UI.tr_s("Mother Kessel"), open.bind("kessel"), UI.c("accent"), 22, 52))
	if e.has_service("salvage"):
		box.add_child(UI.button("🔍 " + UI.tr_s("Search the wrecks (1 day)"), _salvage, UI.c("accent"), 22, 52))
	if e.has_service("fuel"):
		var room := int(floor(float(e.tank()) - e.fuel))
		var fb := UI.button("⛽ " + UI.tr_s("Refuel: %s") % UI.num(room * e.fuel_price()), _refuel, UI.c("accent"), 22, 52)
		fb.disabled = room <= 0 or e.total_credits() < e.fuel_price()
		box.add_child(fb)
	if e.has_service("shipyard") and e.hull < e.max_hull():
		var rb := UI.button("🛠 " + UI.tr_s("Repair: %s") % UI.num(e.repair_cost()), _repair, UI.c("accent"), 22, 52)
		rb.disabled = e.total_credits() < e.REPAIR_PRICE
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

func _complete(id: String) -> void:
	_e().complete(id)
	game._after_missions([id])
	game._flush_story()
	_changed()

func _deliver(cid: String) -> void:
	if _e().deliver_contract(cid):
		game.trade_sound()
	_changed()

func _offer(id: String) -> void:
	var e = _e()
	for ch in get_children():
		ch.queue_free()
	add_child(UI.backdrop(str(D.WORLDS[e.loc].dock)))
	var box := _column(0.2, 0.8, true)
	box.add_child(UI.label(UI.tr_s(D.MISSIONS[id].title), 28, UI.c("accent")))
	box.add_child(UI.label(UI.tr_s(D.MISSIONS[id].brief), 20, UI.c("text"), true))
	box.add_child(UI.label(_reward_text(D.MISSIONS[id].reward), 20, UI.c("go"), true))
	var row := UI.hbox(10)
	row.add_child(UI.button(UI.tr_s("Take the job"), _accept.bind(id), UI.c("go"), 22, 54))
	row.add_child(UI.button(UI.tr_s("Not now"), open.bind(""), UI.c("accent"), 22, 54))
	box.add_child(row)

static func _reward_text(r: Dictionary) -> String:
	var bits := []
	if r.has("clean"):
		bits.append(UI.clean_txt(int(r.clean)))
	if r.has("dirty"):
		bits.append(UI.dirty_txt(int(r.dirty)))
	if r.has("xp"):
		bits.append(UI.tr_s("%d XP") % int(r.xp))
	if r.has("points"):
		bits.append(UI.tr_s("+%d skill point") % int(r.points))
	return UI.tr_s("Reward: %s") % ", ".join(bits)

func _accept(id: String) -> void:
	if not _e().accept_mission(id):
		_note = UI.tr_s("No room in the hold for the job's cargo.")
	open("")

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
		box.add_child(UI.label(UI.tr_s("There's a black market here, but nobody trusts you yet. Finish Kessel's first job."), 16, UI.c("dim"), true))
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
	box.add_child(UI.label(UI.tr_s("Legal parts cost clean credits. Black-market parts cost dirty ones (Gravel Belt, and other yards once Kessel trusts you)."), 16, UI.c("dim"), true))
	var list: Array = e.shop_modules()
	if list.is_empty():
		box.add_child(UI.label(UI.tr_s("Nothing for sale."), 18))
	for slot in D.SLOTS:
		for id in list:
			var m: Dictionary = D.MODULES[id]
			if m.slot != slot:
				continue
			var row := UI.hbox(10)
			var fitted: bool = e.modules.get(slot) == id
			var owned: bool = e.owned.has(id)
			var name_l := UI.label("%s: %s" % [UI.tr_s(D.SLOT_NAMES[slot]), UI.tr_s(m.name)], 19, UI.c("dirty") if m.money == "dirty" else UI.c("text"))
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_l)
			row.add_child(UI.label(module_effect(id), 16, UI.c("dim")))
			var cost: String = UI.dirty_txt(int(m.price)) if m.money == "dirty" else UI.clean_txt(int(m.price))
			var b := UI.button(UI.tr_s("Fitted") if fitted else (UI.tr_s("Fit") if owned else cost), _buy_module.bind(id), UI.c("go"), 18, 42)
			b.custom_minimum_size.x = 140
			b.disabled = fitted or (not owned and not e.can_pay(int(m.price), str(m.money)))
			row.add_child(b)
			box.add_child(row)

static func module_effect(id: String) -> String:
	var m: Dictionary = D.MODULES[id]
	var bits := []
	if m.has("fuel") and float(m.fuel) < 1.0:
		bits.append(UI.tr_s("fuel -%d%%") % int(round((1.0 - float(m.fuel)) * 100)))
	if int(m.get("cargo", 0)) > 0:
		bits.append(UI.tr_s("+%d hold") % int(m.cargo))
	if int(m.get("hidden", 0)) > 0:
		bits.append(UI.tr_s("+%d hidden") % int(m.hidden))
	if int(m.get("quality", 0)) > 0:
		bits.append(UI.tr_s("scans +%d%%") % (int(m.quality) * 10))
	if int(m.get("shield", 0)) > 0:
		bits.append(UI.tr_s("shield %d") % int(m.shield))
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
	return ", ".join(bits)

func _buy_module(id: String) -> void:
	if _e().buy_module(id):
		game.trade_sound()
	_changed()

# ================================================================ fixer

func _fixer() -> void:
	var e = _e()
	var box := _column(0.0, 1.0)
	_page_head(box, "🤝 " + UI.tr_s("Fixer: jobs"))
	box.add_child(UI.label(UI.tr_s("Carry someone's cargo to another world before the due day. Late means no pay and a worse name."), 16, UI.c("dim"), true))
	var offers: Array = e.contract_offers()
	if offers.is_empty():
		box.add_child(UI.label(UI.tr_s("No jobs today. Come back tomorrow."), 18))
	for c in offers:
		var row := UI.hbox(10)
		var shady: bool = c.money == "dirty"
		var t := UI.tr_s("%d x %s to %s, by day %d") % [c.qty, UI.good_name(c.good), UI.world_name(c.to), c.due]
		var l := UI.label(("◆ " if shady else "") + t, 19, UI.c("dirty") if shady else UI.c("text"), true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.label(UI.dirty_txt(c.pay) if shady else UI.clean_txt(c.pay), 19, UI.c("dirty") if shady else UI.c("clean")))
		var b := UI.button(UI.tr_s("Take"), _take.bind(c.id), UI.c("go"), 18, 42)
		b.disabled = e.space_for(c.good) < int(c.qty)
		row.add_child(b)
		box.add_child(row)
	if not e.contracts.is_empty():
		box.add_child(UI.label(UI.tr_s("Your jobs"), 22, UI.c("accent")))
		for c in e.contracts:
			box.add_child(UI.label("• " + UI.tr_s("%d x %s to %s, by day %d") % [c.qty, UI.good_name(c.good), UI.world_name(c.to), c.due], 18, UI.c("text"), true))

func _take(cid: String) -> void:
	_changed("" if _e().take_contract(cid) else UI.tr_s("No room in the hold."))

# ================================================================ laundry

func _laundry() -> void:
	var e = _e()
	var box := _column(0.15, 0.85, true)
	_page_head(box, "🧺 " + UI.tr_s("Moonwash Laundry"))
	box.add_child(UI.label(UI.tr_s("Kessel's front. Dirty credits go in, clean ones come out %d days later, minus %d%%. Sometimes the auditors come.") % [1 if e.has_skill("la_fast") else 2, int(round((1.0 - e.launder_rate()) * 100))], 18, UI.c("text"), true))
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

# ================================================================ Kessel

func _kessel() -> void:
	var e = _e()
	var box := _column(0.15, 0.85, true)
	_page_head(box, "💰 " + UI.tr_s("Mother Kessel"))
	if e.debt <= 0:
		box.add_child(UI.label(UI.tr_s("\"We're square. For now.\""), 20, UI.c("text"), true))
		return
	box.add_child(UI.label(UI.tr_s("\"You owe me %s. Clean or dirty, I'm not fussy.\"") % UI.num(e.debt), 20, UI.c("text"), true))
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
