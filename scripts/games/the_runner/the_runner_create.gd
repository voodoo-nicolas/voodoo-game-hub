extends Control

## Character creation (design doc v2 §2): name, gender, race (8 playable, Sskarn is NPC only), home
## faction (Terrans and Ssaryn choose), two starting perks, then a summary. Emits `done` with the
## captain ({name, gender, race, home, picks}) or `cancelled` (‹ Back on the first page).
## The race picture is a coloured emblem until the owner paints portraits (DECISIONS D-24).

signal done(captain: Dictionary)
signal cancelled

const UI = preload("res://scripts/games/the_runner/the_runner_ui.gd")
const S = preload("res://scripts/games/the_runner/the_runner_spiral.gd")
const D = preload("res://scripts/games/the_runner/the_runner_data.gd")

## Name ideas for the 🎲 button (made up for the game).
const NAMES := ["Ash Corran", "Mira Vale", "Joss Kade", "Teo Brask", "Rin Sollo", "Kit Marrow", "Ivo Strand",
	"Sela Rook", "Nyx Arden", "Dara Quill", "Oskar Venn", "Lio Farr", "Zia Morrow", "Bex Hollan"]
const STEPS := ["name", "gender", "race", "home", "perks", "summary"]

var step := "name"
var cap := {"name": "", "gender": "Other", "race": "terran", "home": "terran_concord", "picks": []}
var _name_edit: LineEdit
var _note := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	rebuild()

func rebuild() -> void:
	for ch in get_children():
		ch.queue_free()
	add_child(UI.backdrop("landing"))
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var p := UI.panel(0.94)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 16
	p.offset_right = -16
	p.offset_top = 12
	p.offset_bottom = -12
	add_child(p)
	var outer := UI.vbox(8)
	p.add_child(outer)
	var head := UI.hbox(10)
	head.add_child(UI.button("‹ " + UI.tr_s("Back"), _back, UI.c("accent"), 20, 46))
	var title := UI.label(UI.tr_s("New captain") + "  ·  " + UI.tr_s("Step %d of %d") % [_visible_index() + 1, _visible_steps().size()], 24, UI.c("accent"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	outer.add_child(head)
	if _note != "":
		outer.add_child(UI.label(_note, 18, UI.c("warn"), true))
	var box := UI.vbox(8)
	outer.add_child(UI.scroll(box))
	match step:
		"name": _page_name(box)
		"gender": _page_gender(box)
		"race": _page_race(box)
		"home": _page_home(box)
		"perks": _page_perks(box)
		"summary": _page_summary(box)

func _visible_steps() -> Array:
	var out := []
	for s in STEPS:
		if s == "home" and S.RACES[cap.race].homes.size() < 2:
			continue
		out.append(s)
	return out

func _visible_index() -> int:
	return _visible_steps().find(step)

func _go(s: String) -> void:
	step = s
	_note = ""
	rebuild()

func _next() -> void:
	var v := _visible_steps()
	var i := v.find(step)
	if i + 1 < v.size():
		_go(v[i + 1])

func _back() -> void:
	var v := _visible_steps()
	var i := v.find(step)
	if i <= 0:
		cancelled.emit()
	else:
		_go(v[i - 1])

func _row_next(box: VBoxContainer, enabled: bool = true) -> void:
	var row := UI.hbox(10)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var b := UI.button(UI.tr_s("Next") + "  ▶", _next, UI.c("go"), 22, 54)
	b.disabled = not enabled
	row.add_child(b)
	box.add_child(row)

# ---------------------------------------------------------------- name

func _page_name(box: VBoxContainer) -> void:
	box.add_child(UI.label(UI.tr_s("What do they call you?"), 26))
	box.add_child(UI.label(UI.tr_s("2 to 16 letters. Your name shows in the story and on your papers."), 17, UI.c("dim"), true))
	var row := UI.hbox(10)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.text = str(cap.name)
	_name_edit.placeholder_text = UI.tr_s("Your name")
	_name_edit.custom_minimum_size = Vector2(360, 54)
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.text_changed.connect(_on_name)
	_name_edit.text_submitted.connect(_on_name_submit)
	row.add_child(_name_edit)
	row.add_child(UI.button("🎲 " + UI.tr_s("Random"), _random_name, UI.c("accent"), 20, 54))
	box.add_child(row)
	_row_next(box, _name_ok())

func _name_ok() -> bool:
	var n := str(cap.name).strip_edges()
	return n.length() >= 2 and n.length() <= 16

func _on_name(t: String) -> void:
	cap.name = t
	var nb := _find_next()
	if nb:
		nb.disabled = not _name_ok()

func _on_name_submit(_t: String) -> void:
	if _name_ok():
		_next()

func _find_next() -> Button:
	for b in find_children("*", "Button", true, false):
		if (b as Button).text.ends_with("▶"):
			return b
	return null

func _random_name() -> void:
	cap.name = NAMES[randi() % NAMES.size()]
	rebuild()

# ---------------------------------------------------------------- gender

func _page_gender(box: VBoxContainer) -> void:
	box.add_child(UI.label(UI.tr_s("Gender"), 26))
	box.add_child(UI.label(UI.tr_s("Only how people speak of you. No effect on the game."), 17, UI.c("dim"), true))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	for g in S.GENDERS:
		var b := UI.button(UI.tr_s(g), _pick_gender.bind(g), UI.c("go") if cap.gender == g else UI.c("accent"), 22, 56)
		b.custom_minimum_size.x = 200
		row.add_child(b)
	box.add_child(row)
	_row_next(box)

func _pick_gender(g: String) -> void:
	cap.gender = g
	rebuild()

# ---------------------------------------------------------------- race

func _page_race(box: VBoxContainer) -> void:
	box.add_child(UI.label(UI.tr_s("Race"), 26))
	var cols := UI.hbox(14)
	box.add_child(cols)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	cols.add_child(grid)
	for r in S.RACE_ORDER:
		if not S.RACES[r].playable:
			continue
		var b := UI.button(UI.race_name(r), _pick_race.bind(r), UI.c("go") if cap.race == r else Color(S.RACES[r].color), 20, 50)
		b.custom_minimum_size.x = 170
		grid.add_child(b)
	var info := UI.panel(0.7)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(info)
	var col := UI.vbox(5)
	info.add_child(col)
	_race_info(col, str(cap.race))
	box.add_child(UI.label(UI.tr_s("The Sskarn (feral reptilians) are not playable: you'll meet them as mercenaries."), 15, UI.c("dim"), true))
	_row_next(box)

static func _race_info(col: VBoxContainer, r: String) -> void:
	var rd: Dictionary = S.RACES[r]
	var top := UI.hbox(10)
	var em := ColorRect.new()
	em.color = Color(rd.color)
	em.custom_minimum_size = Vector2(28, 28)
	em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(em)
	top.add_child(UI.label("%s · %s" % [UI.race_name(r), UI.tr_s(rd.type)], 22, UI.c("accent")))
	col.add_child(top)
	col.add_child(UI.label(UI.tr_s(rd.flavor), 16, UI.c("dim"), true))
	for p in rd.perks:
		col.add_child(UI.label("✚ %s: %s" % [UI.perk_name(p), UI.perk_desc(p)], 16, UI.c("go"), true))
	col.add_child(UI.label("✖ %s: %s" % [UI.perk_name(rd.flaw), UI.perk_desc(rd.flaw)], 16, UI.c("bad"), true))
	var homes := []
	for f in rd.homes:
		homes.append(UI.faction_name(f))
	var home_txt: String = homes[0] if homes.size() == 1 else UI.tr_s("%s or %s") % [homes[0], homes[1]]
	col.add_child(UI.label(UI.tr_s("Home: %s") % home_txt, 16, UI.c("text"), true))
	var hs := []
	for h in rd.hostile:
		hs.append(UI.race_name(h))
	col.add_child(UI.label(UI.tr_s("Won't share a ship with: %s") % (", ".join(hs) if not hs.is_empty() else UI.tr_s("nobody")), 16, UI.c("warn"), true))

func _pick_race(r: String) -> void:
	cap.race = r
	if not S.RACES[r].homes.has(cap.home):
		cap.home = S.RACES[r].homes[0]
	cap.picks = cap.picks.filter(func(p): return not S.RACES[r].perks.has(p))
	rebuild()

# ---------------------------------------------------------------- home faction

func _page_home(box: VBoxContainer) -> void:
	box.add_child(UI.label(UI.tr_s("Home faction"), 26))
	box.add_child(UI.label(UI.tr_s("You start with 10% rep there. The other side starts at zero."), 17, UI.c("dim"), true))
	for f in S.RACES[cap.race].homes:
		var fd: Dictionary = S.FACTIONS[f]
		var p := UI.panel(0.6)
		box.add_child(p)
		var col := UI.vbox(4)
		p.add_child(col)
		col.add_child(UI.button("%s  ·  %s" % [UI.faction_name(f), UI.tr_s(S.BLOC_NAMES[fd.bloc])], _pick_home.bind(f), UI.c("go") if cap.home == f else UI.c("accent"), 20, 50))
		col.add_child(UI.label("%s · %s" % [UI.tr_s(fd.leader), UI.tr_s(fd.ideology)], 16, UI.c("dim"), true))
	_row_next(box)

func _pick_home(f: String) -> void:
	cap.home = f
	rebuild()

# ---------------------------------------------------------------- perks

func _page_perks(box: VBoxContainer) -> void:
	var need: int = int(D.CONFIG.starting_perk_picks)
	box.add_child(UI.label(UI.tr_s("Pick %d perks") % need + "  (%d/%d)" % [cap.picks.size(), need], 26))
	box.add_child(UI.label(UI.tr_s("On top of your race's two. Same perk twice counts half the second time, so these exclude your race's own."), 16, UI.c("dim"), true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for p in S.GOOD_PERKS:
		if S.RACES[cap.race].perks.has(p):
			continue
		var on: bool = cap.picks.has(p)
		var b := UI.button(("✔ " if on else "") + UI.perk_name(p) + "\n" + UI.perk_desc(p), _toggle.bind(p), UI.c("go") if on else UI.c("accent"), 15, 64, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 200
		b.disabled = not on and cap.picks.size() >= need
		grid.add_child(b)
	_row_next(box, cap.picks.size() == need)

func _toggle(p: String) -> void:
	if cap.picks.has(p):
		cap.picks.erase(p)
	elif cap.picks.size() < int(D.CONFIG.starting_perk_picks):
		cap.picks.append(p)
	rebuild()

# ---------------------------------------------------------------- summary

func _page_summary(box: VBoxContainer) -> void:
	box.add_child(UI.label(str(cap.name).strip_edges(), 30, UI.c("accent")))
	box.add_child(UI.label("%s · %s · %s" % [UI.tr_s(cap.gender), UI.race_name(cap.race), UI.faction_name(cap.home)], 19, UI.c("text"), true))
	var rd: Dictionary = S.RACES[cap.race]
	box.add_child(UI.label(UI.tr_s("Perks"), 22, UI.c("accent")))
	for p in rd.perks + cap.picks:
		box.add_child(UI.label("✚ %s: %s" % [UI.perk_name(p), UI.perk_desc(p)], 17, UI.c("go"), true))
	box.add_child(UI.label("✖ %s: %s" % [UI.perk_name(rd.flaw), UI.perk_desc(rd.flaw)], 17, UI.c("bad"), true))
	var row := UI.hbox(10)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	row.add_child(UI.button("🚀 " + UI.tr_s("Start the run"), _finish, UI.c("go"), 24, 60))
	box.add_child(row)

func _finish() -> void:
	var c := cap.duplicate(true)
	c.name = str(c.name).strip_edges()
	done.emit(c)
