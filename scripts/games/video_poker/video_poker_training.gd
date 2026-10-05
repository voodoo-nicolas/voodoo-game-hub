extends Control

## Poker's 🎓 Training screen: the coach table, a hand rankings chart and
## five drills of ten questions (video_poker_drills.gd), each keeping its
## best score in the stats ("Drill best (%s)").

signal back_pressed()
signal practice_pressed()

const Drills = preload("res://scripts/games/video_poker/video_poker_drills.gd")
const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")
const Cards = preload("res://scripts/games/video_poker/video_poker_cards.gd")
const HomeKit = preload("res://scripts/games/video_poker/home_kit.gd")
const CARD_ASPECT := 1.42

var info = null  # GameInfo (null on old apps)
var rng := RandomNumberGenerator.new()

var menu: Control
var menu_box: VBoxContainer
var drill: Control
var drill_title: Label
var drill_score: Label
var cards_area: Control
var prompt_label: Label
var choices_box: GridContainer
var explain_label: Label
var next_btn: Button
var rankings: Control

var kind := ""
var q: Dictionary = {}
var number := 0
var right := 0
var answered := false
var picked: Array = []      # best5: picked card values
var chosen := -1

func _ready() -> void:
	rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(HomeKit.backdrop())
	_build_menu()
	_build_drill()
	_build_rankings()
	show_menu()

# ---------- menu ----------

func _page(title: String) -> Array:
	var page := MarginContainer.new()
	for side in ["left", "right"]:
		page.add_theme_constant_override("margin_" + side, 32)
	page.add_theme_constant_override("margin_top", 28)
	page.add_theme_constant_override("margin_bottom", 30)
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	page.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var back := HomeKit.neon_button("⬅", HomeKit.DIM, 30, 64)
	back.custom_minimum_size.x = 76
	head.add_child(back)
	var t := HomeKit.label(title, 38, HomeKit.WHITE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color(HomeKit.LIME, 0.5))
	t.add_theme_constant_override("outline_size", 8)
	head.add_child(t)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(76, 0)
	head.add_child(sp)
	return [page, col, back, t]

func _build_menu() -> void:
	var parts := _page(tr("🎓 Training"))
	menu = parts[0]
	(parts[2] as Button).pressed.connect(back_pressed.emit)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(scroll)
	menu_box = VBoxContainer.new()
	menu_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_box.add_theme_constant_override("separation", 14)
	scroll.add_child(menu_box)

func show_menu() -> void:
	menu.visible = true
	drill.visible = false
	rankings.visible = false
	for c in menu_box.get_children():
		c.queue_free()
	var coach := HomeKit.neon_button(tr("🎓 Coach table") + "\n" + tr("Play with a coach: win chance, pot odds and advice on every decision"), HomeKit.LIME, 26, 104)
	coach.pressed.connect(practice_pressed.emit)
	menu_box.add_child(coach)
	var rk := HomeKit.neon_button(tr("📖 Hand rankings") + "\n" + tr("Which hand beats which, with examples"), HomeKit.CYAN, 26, 100)
	rk.pressed.connect(_show_rankings)
	menu_box.add_child(rk)
	menu_box.add_child(HomeKit.label(tr("Drills").to_upper(), 22, HomeKit.DIM))
	for d in Drills.DRILLS:
		var best := ""
		if info:
			var key := "Drill best (%s)" % d[1]
			if info.stats.has(key):
				best = "   ·   " + tr("Best %d/%d") % [int(info.stats[key]), Drills.QUESTIONS]
		var b := HomeKit.neon_button(tr(d[1]) + best + "\n" + tr(d[2]), HomeKit.PURPLE, 25, 100)
		b.pressed.connect(_start_drill.bind(d[0]))
		menu_box.add_child(b)

# ---------- rankings ----------

func _build_rankings() -> void:
	var parts := _page(tr("📖 Hand rankings"))
	rankings = parts[0]
	(parts[2] as Button).pressed.connect(show_menu)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	box.add_child(HomeKit.label(tr("Strongest first. Every poker game here uses the best five cards."), 23, HomeKit.DIM, true))
	for i in Eval.RANKINGS.size():
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		box.add_child(row)
		row.add_child(HomeKit.label("%d. %s" % [i + 1, tr(Eval.RANKINGS[i][0])], 28, HomeKit.GOLD.lerp(Color.WHITE, 0.3)))
		row.add_child(HomeKit.label(tr(Eval.RANKINGS[i][1]), 22, HomeKit.DIM, true))
		var cards := Control.new()
		cards.custom_minimum_size = Vector2(0, 92)
		cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cards.draw.connect(_draw_example.bind(cards, i))
		row.add_child(cards)

func _draw_example(c: Control, i: int) -> void:
	var h := c.size.y - 6
	var w := h / CARD_ASPECT
	for k in 5:
		Cards.draw_card(c, Rect2(k * (w + 8), 2, w, h), Eval.EXAMPLES[i][k], true)

func _show_rankings() -> void:
	menu.visible = false
	rankings.visible = true

# ---------- drills ----------

func _build_drill() -> void:
	var parts := _page("")
	drill = parts[0]
	drill_title = parts[3]
	(parts[2] as Button).pressed.connect(show_menu)
	var col: VBoxContainer = parts[1]
	drill_score = HomeKit.label("", 24, HomeKit.DIM, false, true)
	col.add_child(drill_score)
	cards_area = Control.new()
	cards_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_area.custom_minimum_size = Vector2(0, 240)
	cards_area.mouse_filter = Control.MOUSE_FILTER_STOP
	cards_area.draw.connect(_draw_cards)
	cards_area.gui_input.connect(_on_cards_input)
	cards_area.resized.connect(cards_area.queue_redraw)
	col.add_child(cards_area)
	prompt_label = HomeKit.label("", 27, HomeKit.WHITE, true, true)
	col.add_child(prompt_label)
	choices_box = GridContainer.new()
	choices_box.columns = 2
	choices_box.add_theme_constant_override("h_separation", 12)
	choices_box.add_theme_constant_override("v_separation", 12)
	col.add_child(choices_box)
	explain_label = HomeKit.label("", 23, HomeKit.LIME, true, true)
	col.add_child(explain_label)
	next_btn = HomeKit.neon_button(tr("Next ▶"), HomeKit.LIME, 28, 72)
	next_btn.pressed.connect(_next_question)
	col.add_child(next_btn)

func _start_drill(k: String) -> void:
	kind = k
	number = 0
	right = 0
	for d in Drills.DRILLS:
		if d[0] == k:
			drill_title.text = tr(d[1])
	menu.visible = false
	drill.visible = true
	_next_question()

func _drill_name() -> String:
	for d in Drills.DRILLS:
		if d[0] == kind:
			return d[1]
	return kind

func _next_question() -> void:
	if number >= Drills.QUESTIONS:
		_finish_drill()
		return
	number += 1
	q = Drills.question(kind, rng)
	answered = false
	picked = []
	chosen = -1
	explain_label.text = ""
	prompt_label.text = q.prompt
	next_btn.visible = false
	next_btn.text = tr("Next ▶") if number < Drills.QUESTIONS else tr("See score")
	drill_score.text = tr("Question %d of %d   ·   %d right") % [number, Drills.QUESTIONS, right]
	for c in choices_box.get_children():
		c.queue_free()
	if kind == "best5":
		choices_box.columns = 1
		var check := HomeKit.neon_button(tr("Check my five"), HomeKit.GOLD, 26, 70)
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.pressed.connect(_check_best5)
		choices_box.add_child(check)
	else:
		choices_box.columns = 2 if q.choices.size() != 3 else 3
		for i in q.choices.size():
			var b := HomeKit.neon_button(str(q.choices[i]), HomeKit.CYAN, 26, 70)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(_answer.bind(i))
			choices_box.add_child(b)
	cards_area.queue_redraw()

func _answer(i: int) -> void:
	if answered:
		return
	answered = true
	chosen = i
	var good: bool = i == int(q.answer)
	_mark(good)
	for k in choices_box.get_child_count():
		var b := choices_box.get_child(k) as Button
		var col := HomeKit.LIME if k == int(q.answer) else (HomeKit.PINK if k == i else HomeKit.DIM)
		HomeKit.style_button(b, col)
		b.disabled = k != int(q.answer) and k != i
	cards_area.queue_redraw()

func _check_best5() -> void:
	if answered:
		return
	if picked.size() != 5:
		explain_label.text = tr("Pick exactly 5 cards (%d picked).") % picked.size()
		explain_label.add_theme_color_override("font_color", HomeKit.GOLD)
		return
	answered = true
	_mark(Drills.best5_correct(q, picked))
	cards_area.queue_redraw()

func _mark(good: bool) -> void:
	if good:
		right += 1
		_sfx("letter_right")
	else:
		_sfx("letter_wrong")
	explain_label.add_theme_color_override("font_color", HomeKit.LIME if good else HomeKit.PINK)
	explain_label.text = (tr("Right!") if good else tr("Not quite.")) + "\n" + str(q.explain)
	drill_score.text = tr("Question %d of %d   ·   %d right") % [number, Drills.QUESTIONS, right]
	next_btn.visible = true

func _finish_drill() -> void:
	var name := _drill_name()
	var msg := tr("%d out of %d") % [right, Drills.QUESTIONS]
	if info:
		info.add("Drills done")
		var key := "Drill best (%s)" % name
		var record: bool = info.best(key, right) if info.has_method("best") else info.high(key, right)
		if record:
			msg += "  ·  " + tr("New best!")
		if right == Drills.QUESTIONS:
			info.add("Perfect drills")
	if right == Drills.QUESTIONS:
		_sfx("record")
	drill_score.text = msg
	prompt_label.text = tr("Drill finished!")
	explain_label.text = ""
	for c in choices_box.get_children():
		c.queue_free()
	choices_box.columns = 2
	var again := HomeKit.neon_button(tr("Play again"), HomeKit.LIME, 26, 70)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(_start_drill.bind(kind))
	choices_box.add_child(again)
	var other := HomeKit.neon_button(tr("Other drills"), HomeKit.PURPLE, 26, 70)
	other.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	other.pressed.connect(show_menu)
	choices_box.add_child(other)
	next_btn.visible = false
	q = {}
	cards_area.queue_redraw()

# ---------- the cards of a question ----------

## [label, cards, first index in the tap order] per row.
func _rows() -> Array:
	if q.is_empty():
		return []
	match str(q.kind):
		"winner":
			return [[tr("On the board"), q.board, -1], [tr("Player A"), q.hole, -1], [tr("Player B"), q.hole2, -1]]
		"best5":
			return [[tr("Your cards"), q.hole, 0], [tr("On the board"), q.board, 2]]
		"outs":
			return [[tr("Your cards"), q.hole, -1], [tr("On the board"), q.board, -1]]
		"start":
			return [[tr("Your cards"), q.hole, -1]]
	return []

func _layout() -> Array:
	var rows := _rows()
	var out: Array = []
	if rows.is_empty():
		return out
	var label_h := 30.0
	var n := rows.size()
	var h_each := cards_area.size.y / n
	var cw := minf((cards_area.size.x - 40.0) / 5.4, (h_each - label_h - 8.0) / CARD_ASPECT)
	cw = minf(cw, 120.0 if n > 1 else 150.0)
	var ch := cw * CARD_ASPECT
	for r in n:
		var cards: Array = rows[r][1]
		var y := r * h_each + label_h
		var total := cards.size() * cw + (cards.size() - 1) * 8.0
		var x0 := (cards_area.size.x - total) / 2.0
		var rects: Array = []
		for k in cards.size():
			rects.append(Rect2(x0 + k * (cw + 8.0), y, cw, ch))
		out.append({"label": rows[r][0], "cards": cards, "rects": rects, "y": y, "tap": rows[r][2]})
	return out

func _draw_cards() -> void:
	var font := ThemeDB.fallback_font
	var show_best: bool = answered and (str(q.get("kind", "")) == "winner" or str(q.get("kind", "")) == "best5")
	var best: Array = q.get("best", [])
	for row in _layout():
		cards_area.draw_string(font, Vector2(0, row.y - 8), row.label, HORIZONTAL_ALIGNMENT_CENTER, cards_area.size.x, 22, HomeKit.DIM)
		for k in row.cards.size():
			var card: int = row.cards[k]
			var r: Rect2 = row.rects[k]
			var is_picked := picked.has(card)
			if is_picked:
				r.position.y -= 10
			var hl := is_picked or (show_best and best.has(card))
			Cards.draw_card(cards_area, r, card, true, hl, show_best and not best.has(card))
	if str(q.get("kind", "")) == "best5" and not answered:
		cards_area.draw_string(font, Vector2(0, cards_area.size.y - 6), tr("%d of 5 picked") % picked.size(), HORIZONTAL_ALIGNMENT_CENTER, cards_area.size.x, 22, HomeKit.GOLD)

func _on_cards_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if answered or str(q.get("kind", "")) != "best5":
		return
	for row in _layout():
		for k in row.rects.size():
			if (row.rects[k] as Rect2).grow(6).has_point(event.position):
				var card: int = row.cards[k]
				if picked.has(card):
					picked.erase(card)
				elif picked.size() < 5:
					picked.append(card)
				_sfx("toggle")
				explain_label.text = ""
				cards_area.queue_redraw()
				return

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
