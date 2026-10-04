extends Control

## Yacht Dice -- roll up to three times, tap dice to hold them, then tap a box
## on the scorecard to score this turn. Solo, or 2-4 players passing the
## phone: each has their own scorecard and they take turns.

const YEngine = preload("res://scripts/games/yacht/yacht_engine.gd")
const HomeKit = preload("res://scripts/games/yacht/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://yacht_best.json"
const SAVE_PATH := "user://yacht_save.json"
const PIPS := {1: [[1, 1]], 2: [[0, 0], [2, 2]], 3: [[0, 0], [1, 1], [2, 2]], 4: [[0, 0], [2, 0], [0, 2], [2, 2]],
	5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]], 6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]]}

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: YEngine
var dice_row: Control
var roll_btn: Button
var total_label: Label
var hint_label: Label
var cat_buttons: Dictionary = {}
var end_dialog: ColorRect
var started := false  # a game is on (not just the one behind Home)
var best: int = 0
var shake: float = 0.0
## Pass-and-play: how many players, whose turn, and each one's scorecard
## ({"scores", "bonus"}); the engine holds the current player's card.
var players: int = 1
var turn: int = 0
var cards: Array = []
const P_COLORS := [Color("29e6ff"), Color("ff2bd6"), Color("7dff3a"), Color("ffae2b")]

func _ready() -> void:
	preload("res://scripts/games/yacht/yacht_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = YEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
	_build_ui()
	_start()
	started = false

func _names() -> Dictionary:
	return {"ones": tr("Ones"), "twos": tr("Twos"), "threes": tr("Threes"), "fours": tr("Fours"), "fives": tr("Fives"),
		"sixes": tr("Sixes"), "three_kind": tr("3 of a Kind"), "four_kind": tr("4 of a Kind"), "full_house": tr("Full House"),
		"small_straight": tr("Small Straight"), "large_straight": tr("Large Straight"), "yacht": tr("Yacht"), "chance": tr("Chance")}

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🎲 Yacht Dice")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start)
	bar.add_child(restart_btn)

	total_label = Label.new()
	total_label.add_theme_font_size_override("font_size", 28)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(total_label)

	dice_row = Control.new()
	dice_row.custom_minimum_size = Vector2(0, 150)
	dice_row.mouse_filter = Control.MOUSE_FILTER_STOP
	dice_row.draw.connect(_draw_dice)
	dice_row.gui_input.connect(_on_dice_input)
	root.add_child(dice_row)

	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 24)
	hint_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.85))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_label)

	var rc := CenterContainer.new()
	root.add_child(rc)
	roll_btn = Button.new()
	roll_btn.custom_minimum_size = Vector2(320, 80)
	roll_btn.add_theme_font_size_override("font_size", 30)
	roll_btn.pressed.connect(_on_roll)
	roll_btn.set_meta("sfx", "")  # _on_roll rattles the dice instead of a tap
	rc.add_child(roll_btn)

	var gm := MarginContainer.new()
	gm.add_theme_constant_override("margin_left", 16)
	gm.add_theme_constant_override("margin_right", 16)
	gm.add_theme_constant_override("margin_bottom", 30)
	gm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(gm)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	gm.add_child(grid)
	for cat in YEngine.CATEGORIES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 24)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_category.bind(cat))
		grid.add_child(b)
		cat_buttons[cat] = b

	end_dialog = UI.build_dialog(tr("Game Over"), [
		{"text": tr("Play Again"), "action": _start},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/yacht/yacht_help.gd"))
	_build_home()
	if info:
		add_child(info)
		if best > 0:
			info.high("Best score", best)
	add_child(SettingsDrawer.new())

func _start() -> void:
	started = true
	engine.reset()
	turn = 0
	cards = []
	for i in players:
		cards.append({"scores": {}, "bonus": 0})
	end_dialog.visible = false
	_refresh()

## Stores the current scorecard and hands the dice to the next player.
func _next_player() -> void:
	cards[turn] = {"scores": engine.scores.duplicate(), "bonus": engine.yacht_bonus}
	turn = (turn + 1) % players
	engine.scores = cards[turn].scores.duplicate()
	engine.yacht_bonus = int(cards[turn].bonus)

func _card_total(i: int) -> int:
	var e := YEngine.new()
	e.scores = cards[i].scores
	e.yacht_bonus = int(cards[i].bonus)
	return e.total()

func _multi_over() -> void:
	SaveUtil.delete(SAVE_PATH)
	var order: Array = range(players)
	order.sort_custom(func(a, b): return _card_total(a) > _card_total(b))
	var lines: Array = []
	for i in order:
		lines.append(tr("Player %d") % (i + 1) + ": %d" % _card_total(i))
	var top: int = _card_total(order[0])
	var tied: bool = players > 1 and _card_total(order[1]) == top
	var head := tr("It's a tie!") if tied else tr("Player %d wins!") % (order[0] + 1)
	if info:
		info.add("Multiplayer games")
		info.celebrate(head)
	end_dialog.get_meta("message_label").text = head + "\n" + "\n".join(lines)
	end_dialog.visible = true

func _process(delta: float) -> void:
	if shake > 0.0:
		shake -= delta
		dice_row.queue_redraw()

func _on_roll() -> void:
	if engine.roll():
		shake = 0.25
		_sfx("dice_roll")
		_refresh()

func _on_category(cat: String) -> void:
	if engine.use(cat):
		_sfx("merge")
		if players > 1:
			var last_turn: bool = turn == players - 1 and engine.is_over()
			if last_turn:
				cards[turn] = {"scores": engine.scores.duplicate(), "bonus": engine.yacht_bonus}
				_refresh()
				_multi_over()
				return
			_next_player()
			_refresh()
			return
		_refresh()
		if engine.is_over():
			SaveUtil.delete(SAVE_PATH)
			var t := engine.total()
			if t > best:
				best = t
				SaveUtil.write(BEST_PATH, {"best": best})
			if info:
				info.add("Games played")
				info.best("Best score", best)
			end_dialog.get_meta("message_label").text = tr("Final score: %d") % t + "\n" + tr("Best: %d") % best
			end_dialog.visible = true

func _refresh() -> void:
	var names := _names()
	var up := engine.upper_total()
	total_label.text = tr("Total: %d   Upper: %d/63   Best: %d") % [engine.total(), up, best]
	total_label.remove_theme_color_override("font_color")
	if players > 1:
		var others: Array = []
		for i in players:
			if i != turn:
				others.append("P%d %d" % [i + 1, _card_total(i)])
		total_label.text = tr("Player %d: %d") % [turn + 1, engine.total()] + "   ·   " + "  ".join(others)
		total_label.add_theme_color_override("font_color", P_COLORS[turn])
	roll_btn.disabled = not engine.can_roll()
	roll_btn.text = tr("🎲 Roll (%d left)") % engine.rolls_left
	if not engine.has_rolled() and players > 1:
		hint_label.text = tr("Player %d, roll the dice!") % (turn + 1)
	elif not engine.has_rolled():
		hint_label.text = tr("Roll the dice to start your turn.")
	elif engine.rolls_left > 0:
		hint_label.text = tr("Tap dice to hold them, roll again, or pick a box.")
	else:
		hint_label.text = tr("Pick a box to score.")
	for cat in YEngine.CATEGORIES:
		var b: Button = cat_buttons[cat]
		if engine.scores.has(cat):
			b.text = "✓ %s: %d" % [names[cat], engine.scores[cat]]
			b.disabled = true
		else:
			var preview := YEngine.score_for(cat, engine.dice) if engine.has_rolled() else 0
			b.text = "%s: %s" % [names[cat], str(preview) if engine.has_rolled() else "–"]
			b.disabled = not engine.has_rolled()
	dice_row.queue_redraw()

func _die_rect(i: int) -> Rect2:
	var s: float = min(120.0, (dice_row.size.x - 60.0) / 5.0 - 12.0)
	var total := 5 * s + 4 * 16.0
	var x := (dice_row.size.x - total) / 2.0 + i * (s + 16.0)
	return Rect2(Vector2(x, (dice_row.size.y - s) / 2.0), Vector2(s, s))

func _draw_dice() -> void:
	for i in 5:
		var r := _die_rect(i)
		if shake > 0.0 and not engine.held[i]:
			r.position += Vector2(randf_range(-4, 4), randf_range(-4, 4))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.97, 0.97, 0.95) if engine.has_rolled() else Color(0.6, 0.65, 0.63)
		sb.set_corner_radius_all(int(r.size.x * 0.16))
		if engine.held[i]:
			sb.set_border_width_all(6)
			sb.border_color = Color(1, 0.8, 0.2)
		dice_row.draw_style_box(sb, r)
		if engine.has_rolled():
			for sp in PIPS[engine.dice[i]]:
				var p := r.position + Vector2(0.22 + sp[0] * 0.28, 0.22 + sp[1] * 0.28) * r.size.x
				dice_row.draw_circle(p, r.size.x * 0.085, Color(0.12, 0.12, 0.14))
		if engine.held[i]:
			dice_row.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.end.y + 22), tr("Held").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color(1, 0.8, 0.2))

func _on_dice_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in 5:
			if _die_rect(i).has_point(event.position):
				var was: bool = engine.held[i]
				engine.toggle_hold(i)
				if engine.held[i] != was:
					_sfx("toggle" if engine.held[i] else "back")
				dice_row.queue_redraw()
				return

## Plays a sound from the app's library (silent on apps from before v0.23).
func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/yacht/yacht_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/yacht/yacht_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Five dice, three rolls, thirteen boxes to fill.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🎲  New game", "sub": "Solo, beat your best", "action": _fresh_game.bind(1)},
			{"text": "👥 2", "row": "players", "multi": true, "color": P_COLORS[0], "action": _fresh_game.bind(2)},
			{"text": "👥 3", "row": "players", "multi": true, "color": P_COLORS[1], "action": _fresh_game.bind(3)},
			{"text": "👥 4", "row": "players", "multi": true, "color": P_COLORS[2], "action": _fresh_game.bind(4)},
		],
		"multi_heading": "Players on one phone",
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _start,
		"board_note": "Your best total.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var s := minf(c.size.y * 0.4, 62.0)
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	for i in 5:
		var r := Rect2(ctr + Vector2((i - 2.5) * s * 1.15, -s / 2.0 + (i % 2) * s * 0.2), Vector2(s, s))
		HomeKit.glow_rect(c, r, HomeKit.GOLD if i != 2 else HomeKit.CYAN, 2.0, 0.12)
		for sp in [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]]:
			c.draw_circle(r.position + Vector2(0.22 + sp[0] * 0.28, 0.22 + sp[1] * 0.28) * s, s * 0.08, Color.WHITE)

func _fresh_game(n: int = 1) -> void:
	players = n
	SaveUtil.delete(SAVE_PATH)
	_start()

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var n := int(d.get("players", 1))
	var left := tr("%d boxes left") % (13 - d.scores.size())
	return left if n <= 1 else tr("%d players") % n + "   ·   " + left

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if not started or engine.is_over():
		return
	SaveUtil.write(SAVE_PATH, {"dice": engine.dice, "held": engine.held, "rolls": engine.rolls_left, "scores": engine.scores, "bonus": engine.yacht_bonus,
		"players": players, "turn": turn, "cards": cards})

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_start()
		return
	players = clampi(int(d.get("players", 1)), 1, 4)
	_start()
	if players > 1:
		var saved: Array = d.get("cards", [])
		for i in mini(saved.size(), players):
			var sc := {}
			for k in saved[i].get("scores", {}):
				sc[str(k)] = int(saved[i].scores[k])
			cards[i] = {"scores": sc, "bonus": int(saved[i].get("bonus", 0))}
		turn = clampi(int(d.get("turn", 0)), 0, players - 1)
	engine.dice = []
	for v in d.dice:
		engine.dice.append(int(v))
	engine.held = []
	for v in d.held:
		engine.held.append(bool(v))
	engine.rolls_left = int(d.rolls)
	engine.scores = {}
	for k in d.scores:
		engine.scores[str(k)] = int(d.scores[k])
	engine.yacht_bonus = int(d.get("bonus", 0))
	_refresh()
