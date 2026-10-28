extends Control

## Poker's 📈 My stats screen: a Stats tab (level and XP, the owner's list of
## numbers, habits, results by variant / stake / position, hands made, sessions,
## best and worst starting hands, tournaments, a graph of the chips won) and a
## Hands tab (every recorded hand, filtered and sorted; tap one to replay it).
## Lifetime numbers come from the profile, rates and breakdowns from the last
## hands in the history. Opens a replay (video_poker_replay_screen.gd) on top.

signal back_pressed()

const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")
const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const History = preload("res://scripts/games/video_poker/video_poker_history.gd")
const Profile = preload("res://scripts/games/video_poker/video_poker_profile.gd")
const Stats = preload("res://scripts/games/video_poker/video_poker_stats.gd")
const Look = preload("res://scripts/games/video_poker/video_poker_look.gd")
const HomeKit = preload("res://scripts/games/video_poker/home_kit.gd")
const ReplayScreen = preload("res://scripts/games/video_poker/video_poker_replay_screen.gd")

## Hands listed at most (newest or best first).
const LIST_MAX := 100

var profile
var hands: Array = []
var tab := "stats"
var with_aids := true
var mode_filter := 0            # 0 all, 1 cash, 2 tournaments
var result_filter := 0          # 0 all, 1 won, 2 lost, 3 bookmarked
var sort_by := 0                # 0 newest, 1 biggest win, 2 biggest loss

var body: VBoxContainer
var tab_buttons: Array = []
var replay: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(HomeKit.backdrop())
	var page := MarginContainer.new()
	for side in ["left", "right"]:
		page.add_theme_constant_override("margin_" + side, 28)
	page.add_theme_constant_override("margin_top", 24)
	page.add_theme_constant_override("margin_bottom", 24)
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	page.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var back := HomeKit.neon_button("⬅", HomeKit.DIM, 30, 64)
	back.custom_minimum_size.x = 76
	back.pressed.connect(back_pressed.emit)
	head.add_child(back)
	var title := HomeKit.label(tr("📈 My stats"), 36, HomeKit.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(76, 0)
	head.add_child(sp)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	col.add_child(tabs)
	var group := ButtonGroup.new()
	for t in [["stats", "📈 Stats"], ["hands", "📜 Hands"]]:
		var b := _toggle(tr(t[1]), HomeKit.CYAN, group)
		b.button_pressed = t[0] == tab
		b.pressed.connect(_set_tab.bind(t[0]))
		tabs.add_child(b)
		tab_buttons.append(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	replay = ReplayScreen.new()
	replay.visible = false
	replay.closed.connect(_on_replay_closed)
	replay.bookmark_toggled.connect(_on_bookmark)
	add_child(replay)

## Call each time the screen is opened.
func open(p) -> void:
	profile = p
	hands = History.load_all()
	replay.visible = false
	_render()

func _set_tab(name: String) -> void:
	tab = name
	_render()

func _on_replay_closed() -> void:
	replay.visible = false
	_render()

func _on_bookmark(at: int) -> void:
	profile.toggle_bookmark(at)

# ---------- building ----------

func _render() -> void:
	if body == null:
		return
	for c in body.get_children():
		c.queue_free()
	if tab == "stats":
		_build_stats()
	else:
		_build_hands()

func _toggle(text: String, color: Color, group: ButtonGroup) -> Button:
	var b := HomeKit.neon_button(text, color, 24, 60)
	b.toggle_mode = true
	b.button_group = group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on := HomeKit.neon_box(color, "pressed")
	on.bg_color = Color(color, 0.45)
	b.add_theme_stylebox_override("pressed", on)
	return b

## A row of choices; `picked` gets the index.
func _choices(names: Array, current: int, picked: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for i in names.size():
		var b := _toggle(tr(str(names[i])), HomeKit.BUTTON, group)
		b.custom_minimum_size.y = 52
		b.add_theme_font_size_override("font_size", 21)
		b.button_pressed = i == current
		b.pressed.connect(picked.bind(i))
		row.add_child(b)
	return row

func _section(text: String) -> void:
	var l := HomeKit.label(tr(text).to_upper(), 22, HomeKit.DIM)
	body.add_child(l)

func _row(name: String, value: String, color: Color = HomeKit.WHITE) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	var n := HomeKit.label(tr(name), 24, HomeKit.DIM)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(n)
	var v := HomeKit.label(value, 25, color)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(v)
	body.add_child(r)

func _note(text: String) -> void:
	body.add_child(HomeKit.label(text, 21, HomeKit.DIM, true))

static func _chips(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out

static func _signed(v: int) -> String:
	return ("+" if v > 0 else "") + _chips(v)

func _net_color(v: int) -> Color:
	return HomeKit.LIME if v > 0 else (Color("ff6b7a") if v < 0 else HomeKit.WHITE)

static func _date(unix: int) -> String:
	var local := unix + int(Time.get_time_zone_from_system().bias) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

static func _clock(unix: int) -> String:
	var local := unix + int(Time.get_time_zone_from_system().bias) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	return "%04d-%02d-%02d %02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute]

static func _cat_name(cat: int) -> String:
	return str(TranslationServer.translate(Eval.RANKINGS[8 - cat][0]))

# ---------- the Stats tab ----------

func _opts() -> Dictionary:
	var modes: Array = []
	if mode_filter == 1:
		modes = ["cash"]
	elif mode_filter == 2:
		modes = ["tourney"]
	return {"aids": with_aids, "modes": modes}

func _build_stats() -> void:
	var p: Dictionary = profile.d
	# level and xp
	var lvl: int = profile.level()
	body.add_child(_level_card(lvl))
	body.add_child(_choices(["All games", "Cash", "Tournaments"], mode_filter, _on_mode))
	var aid_row := _choices(["With help", "Without help"], 0 if with_aids else 1, _on_aids)
	body.add_child(aid_row)
	var s := Stats.compute(hands, _opts())
	_section("Lifetime")
	_row("Hands played", _chips(int(p.hands)))
	_row("Hands won", "%s  (%s)" % [_chips(int(p.won)), Stats.pct(int(p.won), int(p.hands))])
	_row("Showdown win rate", Stats.pct(int(p.showdowns_won), int(p.showdowns)))
	_row("Chips won or lost", _signed(int(p.net)), _net_color(int(p.net)))
	_row("Biggest single-hand win", _chips(int(p.win_max)))
	_row("Biggest single-hand loss", _chips(int(p.loss_max)))
	_row("Best winning streak", str(int(p.win_run_best)))
	_row("Worst losing streak", str(int(p.lose_run_best)))
	if int(p.cash_hands) > 0:
		_row("bb/100 (cash)", "%+.1f" % (100.0 * float(p.cash_bb) / float(p.cash_hands)))
	if float(p.cph_best) > 0.0:
		_row("Best chips an hour", _chips(roundi(float(p.cph_best))))
	_row("Joined", _date(int(p.joined)) if int(p.joined) > 0 else "-")
	_row("Days in a row (best)", "%d (%d)" % [int(p.day_run), int(p.day_run_best)])
	if int(s.hands) == 0:
		_note(tr("Play a few hands and the rest fills in."))
		return
	_section("Habits")
	_note(tr("From your last %d recorded hands.") % int(s.hands))
	_row("Win rate", Stats.pct(int(s.won), int(s.hands)))
	_row("Played preflop (VPIP)", Stats.pct(int(s.vpip), int(s.pf_hands)))
	_row("Raised preflop (PFR)", Stats.pct(int(s.pfr), int(s.pf_hands)))
	_row("3-bet", Stats.pct(int(s.bet3), int(s.bet3_chance)))
	_row("Fold to a 3-bet", Stats.pct(int(s.f3), int(s.f3_chance)))
	_row("Continuation bet", Stats.pct(int(s.cbet), int(s.cbet_chance)))
	_row("Aggression", Stats.pct(int(s.raises), int(s.raises) + int(s.calls)))
	_row("Fold to a bet", Stats.pct(int(s.folds_faced), int(s.faced)))
	_row("Biggest pot won", _chips(int(s.biggest_won)))
	_row("Biggest pot lost", _chips(int(s.biggest_lost)))
	_section("Graph")
	body.add_child(_graph(s.series))
	_section("Results by game")
	for v in Table.VARIANTS:
		if s.by_variant.has(v):
			var b: Dictionary = s.by_variant[v]
			_row("%s  ·  %s" % [tr(Table.rules_for(v).short_title()), tr("%d hands") % int(b.hands)], _signed(int(b.net)), _net_color(int(b.net)))
	var stakes: Array = s.by_stake.keys()
	stakes.sort()
	if stakes.size() > 1:
		_section("Results by stakes")
		for k in stakes:
			var b: Dictionary = s.by_stake[k]
			_row("%s  ·  %s" % [k, tr("%d hands") % int(b.hands)], _signed(int(b.net)), _net_color(int(b.net)))
	if not (s.by_position as Dictionary).is_empty():
		_section("Results by position")
		_note(tr("Big blinds won per hand."))
		for k in Stats.POSITIONS:
			if s.by_position.has(k):
				var b: Dictionary = s.by_position[k]
				var per := float(b.net) / maxf(1.0, float(b.hands))
				_row("%s  ·  %s" % [tr(k), tr("%d hands") % int(b.hands)], "%+.2f" % per, _net_color(roundi(per * 100.0)))
	var ranked := Stats.starting_ranked(s.starting)
	if ranked.size() >= 2:
		_section("Starting hands")
		_note(tr("Hold'em hands you were dealt at least 3 times."))
		for r in ranked.slice(0, mini(3, ranked.size())):
			_row("%s  ·  %s" % [r[0], tr("%d hands") % int(r[1])], _signed(int(r[2])), _net_color(int(r[2])))
		if ranked.size() > 3:
			_note(tr("The worst:"))
			var worst := ranked.slice(maxi(3, ranked.size() - 3))
			worst.reverse()
			for r in worst:
				_row("%s  ·  %s" % [r[0], tr("%d hands") % int(r[1])], _signed(int(r[2])), _net_color(int(r[2])))
	_section("Hands made")
	_note(tr("Counted when you went to showdown or won."))
	for cat in range(8, -1, -1):
		var n := int(p.types.get(str(cat), 0))
		if n > 0:
			var best := int(p.type_best.get(str(cat), 0))
			_row("%s  ·  %s" % [_cat_name(cat), tr("%d times") % n], tr("best win %s") % _chips(best) if best > 0 else "-")
	var worst_cat := _worst_winning(p)
	if worst_cat >= 0:
		_row("Worst winning hand", "%s (%s)" % [_cat_name(worst_cat), _chips(int(p.type_best[str(worst_cat)]))])
	var ses: Array = s.sessions
	if not ses.is_empty():
		_section("Sessions")
		var best: Dictionary = ses[0]
		var worst: Dictionary = ses[0]
		var hands_n := 0
		var secs := 0
		for c in ses:
			hands_n += int(c.hands)
			secs += int(c.end) - int(c.start)
			if int(c.net) > int(best.net):
				best = c
			if int(c.net) < int(worst.net):
				worst = c
		_row("Cash sessions", str(ses.size()))
		_row("Best session", _signed(int(best.net)), _net_color(int(best.net)))
		_row("Worst session", _signed(int(worst.net)), _net_color(int(worst.net)))
		if secs >= 600:
			_row("Hands per minute", "%.1f" % (float(hands_n) * 60.0 / float(secs)))
	var tn: Array = p.tourneys
	if not tn.is_empty():
		_section("Tournaments")
		var top := 99
		for t in tn:
			top = mini(top, int(t.place))
		_row("Played", str(tn.size()))
		_row("Won", str(profile.tourney_wins()))
		_row("Best finish", str(top))
		for t in tn.slice(maxi(0, tn.size() - 5)):
			_row("%s  ·  %s" % [_date(int(t.at)), tr(Table.rules_for(str(t.variant)).short_title())], tr("%d of %d") % [int(t.place), int(t.of)])

## The lowest hand category the player has won with: its category, or -1.
func _worst_winning(p: Dictionary) -> int:
	var cats: Array = []
	for k in p.type_best:
		if int(p.type_best[k]) > 0:
			cats.append(int(k))
	return -1 if cats.is_empty() else cats.min()

func _on_mode(i: int) -> void:
	mode_filter = i
	_render()

func _on_aids(i: int) -> void:
	with_aids = i == 0
	_render()

func _level_card(lvl: int) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(HomeKit.GOLD, 0.1)
	sb.border_color = Color(HomeKit.GOLD, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var line := HomeKit.label("%s %d  ·  %s" % [tr("Level"), lvl, tr(Profile.title_for(lvl))], 30, HomeKit.GOLD.lerp(Color.WHITE, 0.4), false, true)
	v.add_child(line)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 20)
	var frac: float = profile.level_progress()
	bar.draw.connect(func():
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(1, 1, 1, 0.1))
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * frac, bar.size.y)), HomeKit.GOLD))
	v.add_child(bar)
	var next_xp := Profile.xp_for_level(lvl + 1)
	v.add_child(HomeKit.label("%s / %s XP" % [_chips(int(profile.d.xp)), _chips(next_xp)], 22, HomeKit.DIM, false, true))
	return panel

## The chips won over the recorded hands, as a line.
func _graph(series: Array) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, 220)
	g.draw.connect(_draw_graph.bind(g, series))
	return g

func _draw_graph(g: Control, series: Array) -> void:
	var r := Rect2(Vector2(8, 12), g.size - Vector2(16, 28))
	g.draw_rect(Rect2(Vector2.ZERO, g.size), Color(0, 0, 0, 0.3))
	if series.size() < 2:
		return
	var lo := 0
	var hi := 0
	for v in series:
		lo = mini(lo, int(v))
		hi = maxi(hi, int(v))
	var span := float(maxi(1, hi - lo))
	var zero_y := r.end.y - r.size.y * float(0 - lo) / span
	g.draw_line(Vector2(r.position.x, zero_y), Vector2(r.end.x, zero_y), Color(1, 1, 1, 0.25), 1.0)
	var pts := PackedVector2Array()
	var n := series.size()
	for i in n:
		pts.append(Vector2(r.position.x + r.size.x * float(i) / float(n - 1), r.end.y - r.size.y * float(int(series[i]) - lo) / span))
	var end_v := int(series[n - 1])
	g.draw_polyline(pts, _net_color(end_v), 3.0, true)
	var font := ThemeDB.fallback_font
	g.draw_string(font, Vector2(10, 12 + 4), _signed(hi), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, HomeKit.DIM)
	g.draw_string(font, Vector2(10, g.size.y - 4), _signed(lo), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, HomeKit.DIM)

# ---------- the Hands tab ----------

func _build_hands() -> void:
	body.add_child(_choices(["All", "Won", "Lost", "⭐"], result_filter, _on_result))
	body.add_child(_choices(["Newest", "Best hands", "Worst hands"], sort_by, _on_sort))
	var list := Stats.mine(hands, {"aids": true})
	var rows: Array = []
	for h in list:
		var hero := int(h.hero)
		var net := int((h.net as Array)[hero]) if hero < (h.net as Array).size() else 0
		match result_filter:
			1:
				if net <= 0:
					continue
			2:
				if net >= 0:
					continue
			3:
				if not profile.is_bookmarked(int(h.at)):
					continue
		rows.append([h, net])
	match sort_by:
		0: rows.reverse()
		1: rows.sort_custom(func(a, b): return a[1] > b[1])
		2: rows.sort_custom(func(a, b): return a[1] < b[1])
	if rows.is_empty():
		_note(tr("No hands yet: they are saved as you play."))
		return
	_note(tr("%d hands. Tap one to replay it.") % rows.size() if rows.size() <= LIST_MAX else tr("Showing %d of %d hands. Tap one to replay it.") % [LIST_MAX, rows.size()])
	for r in rows.slice(0, LIST_MAX):
		body.add_child(_hand_button(r[0], int(r[1])))

func _on_result(i: int) -> void:
	result_filter = i
	_render()

func _on_sort(i: int) -> void:
	sort_by = i
	_render()

func _hand_button(h: Dictionary, net: int) -> Button:
	var hero := int(h.hero)
	var rules = Table.rules_for(str(h.get("variant", "holdem")))
	var what := ""
	for r in h.get("res", []):
		if int(r[0]) == hero and int(r[2]) >= 0 and int(r[3]) == 1:
			what = rules.describe(int(r[2]))
	var star := "⭐ " if profile.is_bookmarked(int(h.at)) else ""
	var text := "%s%s  ·  %s  ·  %s" % [star, _clock(int(h.at)), tr(rules.short_title()), _signed(net)]
	if what != "":
		text += "\n" + what
	var b := HomeKit.neon_button(text, HomeKit.LIME if net > 0 else (HomeKit.MAGENTA if net < 0 else HomeKit.DIM), 22, 70)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(_open_replay.bind(h))
	return b

func _open_replay(h: Dictionary) -> void:
	replay.visible = true
	replay.open(h, profile.is_bookmarked(int(h.at)))
