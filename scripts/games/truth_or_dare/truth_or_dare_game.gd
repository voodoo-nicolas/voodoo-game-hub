extends Control

## Truth or Dare: pass the phone round the group. On your turn pick Truth or
## Dare, read your card out loud, then Done (+1) or Skip (-1).

const TdEngine = preload("res://scripts/games/truth_or_dare/truth_or_dare_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/truth_or_dare/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/truth_or_dare/truth_or_dare_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://truth_or_dare_save.json"

const TRUTH := Color("29e6ff")
const DARE := Color("ff2bd6")
const PLAYER_COUNTS := [2, 3, 4, 5, 6, 8]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var started := false
var count_pick: int = 2  # index into PLAYER_COUNTS

var who_label: Label
var card_panel: PanelContainer
var card_label: Label
var kind_label: Label
var choose_row: HBoxContainer
var result_row: HBoxContainer
var score_label: Label

func _ready() -> void:
	preload("res://scripts/games/truth_or_dare/truth_or_dare_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = TdEngine.new()
	engine.load_cards()
	_build_ui()
	_start(false)
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _lang() -> String:
	return "es" if TranslationServer.get_locale().begins_with("es") else "en"

func _big_button(text: String, color: Color, action: Callable, sfx: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(290, 120)
	b.add_theme_font_size_override("font_size", 36)
	b.set_meta("sfx", sfx)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := HomeKit.neon_box(color, st)
		sb.set_corner_radius_all(24)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(action)
	return b

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 20)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("Truth or Dare")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.9, 1))
	title.add_theme_color_override("font_outline_color", Color(DARE, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76, 0)
	bar.add_child(spacer)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 22)
	score_label.add_theme_color_override("font_color", HomeKit.DIM)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(score_label)

	who_label = Label.new()
	who_label.add_theme_font_size_override("font_size", 40)
	who_label.add_theme_color_override("font_color", HomeKit.GOLD.lerp(Color.WHITE, 0.4))
	who_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(who_label)

	var mid := MarginContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("margin_left", 28)
	mid.add_theme_constant_override("margin_right", 28)
	root.add_child(mid)
	var center := CenterContainer.new()
	mid.add_child(center)
	card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(600, 420)
	center.add_child(card_panel)
	var cbox := VBoxContainer.new()
	cbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cbox.add_theme_constant_override("separation", 20)
	card_panel.add_child(cbox)
	kind_label = Label.new()
	kind_label.add_theme_font_size_override("font_size", 34)
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cbox.add_child(kind_label)
	card_label = Label.new()
	card_label.custom_minimum_size = Vector2(540, 0)
	card_label.add_theme_font_size_override("font_size", 34)
	card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cbox.add_child(card_label)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 40)
	root.add_child(bm)
	var rows := VBoxContainer.new()
	bm.add_child(rows)
	choose_row = HBoxContainer.new()
	choose_row.alignment = BoxContainer.ALIGNMENT_CENTER
	choose_row.add_theme_constant_override("separation", 20)
	rows.add_child(choose_row)
	choose_row.add_child(_big_button(tr("Truth"), TRUTH, _draw_card.bind("truth"), "card_flip"))
	choose_row.add_child(_big_button(tr("Dare"), DARE, _draw_card.bind("dare"), "card_flip"))
	result_row = HBoxContainer.new()
	result_row.alignment = BoxContainer.ALIGNMENT_CENTER
	result_row.add_theme_constant_override("separation", 20)
	rows.add_child(result_row)
	result_row.add_child(_big_button(tr("✔ Done"), HomeKit.LIME, _finish.bind(true), "pickup"))
	result_row.add_child(_big_button(tr("✖ Skip"), HomeKit.PINK, _finish.bind(false), "buzzer"))

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": DARE,
		"multi_heading": "Pick the cards",
		"subtitle": "Pass the phone. Tell the truth — or take the dare.",
		"logo": _draw_home_logo,
		"extra": _add_options,
		"modes": [
			{"text": "😇 Mild", "sub": "For any group", "row": "deck", "multi": true, "color": TRUTH, "action": _new.bind(false)},
			{"text": "😈 Spicy", "sub": "Friends and dates", "row": "deck", "multi": true, "color": DARE, "action": _new.bind(true)},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": func(): _start(engine.spicy),
		"board": "Cards played",
		"board_note": "Truths told and dares done, all time.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.15)  # beside the scores
	add_child(drawer)

func _add_options(box: VBoxContainer) -> void:
	box.add_child(home.section("Players"))
	var names: Array = []
	for n in PLAYER_COUNTS:
		names.append(str(n))
	box.add_child(home.choice_row(names, count_pick, _pick_count, HomeKit.GOLD))

func _pick_count(i: int) -> void:
	count_pick = i

# ---------- flow ----------

func _player_names(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(tr("Player %d") % (i + 1))
	return out

func _new(spicy: bool) -> void:
	SaveUtil.delete(SAVE_PATH)
	_start(spicy)

func _start(spicy: bool) -> void:
	engine.start(_player_names(PLAYER_COUNTS[count_pick]), spicy, _lang())
	started = true
	_render()

func _draw_card(k: String) -> void:
	engine.draw(k, rng)
	_render()

func _finish(done: bool) -> void:
	engine.finish(done)
	if info:
		info.add("Cards played")
		if done:
			info.add("Dares done" if engine.kind == "dare" else "Truths told")
	_render()

func _render() -> void:
	var parts: Array = []
	for i in engine.players.size():
		parts.append("%s: %d" % [engine.players[i], engine.points[i]])
	score_label.text = "   ·   ".join(parts)
	var choosing: bool = engine.card == ""
	who_label.text = tr("%s's turn") % engine.players[engine.turn] if not engine.players.is_empty() else ""
	choose_row.visible = choosing
	result_row.visible = not choosing
	var col: Color = HomeKit.PURPLE if choosing else (TRUTH if engine.kind == "truth" else DARE)
	var sb := HomeKit.neon_box(col, "normal")
	sb.set_corner_radius_all(28)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	card_panel.add_theme_stylebox_override("panel", sb)
	kind_label.text = tr("Truth or Dare?") if choosing else (tr("Truth") if engine.kind == "truth" else tr("Dare")).to_upper()
	kind_label.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.3))
	card_label.text = tr("Pick one!") if choosing else engine.card

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 3.0, 50.0)
	var o := c.size / 2.0
	var a := Rect2(o + Vector2(-k * 2.3, -k * 1.1), Vector2(k * 1.9, k * 2.4))
	var b := Rect2(o + Vector2(k * 0.4, -k * 1.3), Vector2(k * 1.9, k * 2.4))
	HomeKit.glow_rect(c, a, TRUTH, 2.5, 0.12)
	HomeKit.glow_rect(c, b, DARE, 2.5, 0.12)
	HomeKit.glow_text(c, a.get_center(), "T", int(k * 1.1), TRUTH)
	HomeKit.glow_text(c, b.get_center(), "D", int(k * 1.1), DARE)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _save_game() -> void:
	if not started:
		return
	SaveUtil.write(SAVE_PATH, {"n": engine.players.size(), "points": engine.points, "turn": engine.turn,
		"spicy": engine.spicy, "played": engine.played})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("%d players") % int(d.get("n", 2)) + "   ·   " + (tr("Spicy") if bool(d.get("spicy", false)) else tr("Mild"))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_start(false)
		return
	var n := clampi(int(d.get("n", 2)), 2, 8)
	engine.start(_player_names(n), bool(d.get("spicy", false)), _lang())
	var pts: Array = d.get("points", [])
	for i in mini(pts.size(), n):
		engine.points[i] = int(pts[i])
	engine.turn = clampi(int(d.get("turn", 0)), 0, n - 1)
	engine.played = int(d.get("played", 0))
	started = true
	_render()
