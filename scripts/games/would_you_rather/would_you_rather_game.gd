extends Control

## Would You Rather: read the card out loud, everyone picks a side (tap to
## count the votes), argue about it, next card.

const WyEngine = preload("res://scripts/games/would_you_rather/would_you_rather_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/would_you_rather/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/would_you_rather/would_you_rather_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://would_you_rather_save.json"

const SIDE_COLORS := [Color("29e6ff"), Color("ff2bd6")]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var started := false

var count_label: Label
var side_btns: Array = []
var side_labels: Array = []
var bars: Array = []

func _ready() -> void:
	preload("res://scripts/games/would_you_rather/would_you_rather_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = WyEngine.new()
	engine.load_cards()
	_build_ui()
	_start("classic")
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _lang() -> String:
	return "es" if TranslationServer.get_locale().begins_with("es") else "en"

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 18)
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
	title.text = tr("Would you rather...")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 1.0))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.PURPLE, 0.6))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76, 0)
	bar.add_child(spacer)

	count_label = Label.new()
	count_label.add_theme_font_size_override("font_size", 22)
	count_label.add_theme_color_override("font_color", HomeKit.DIM)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(count_label)

	var mid := MarginContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("margin_left", 28)
	mid.add_theme_constant_override("margin_right", 28)
	root.add_child(mid)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 20)
	mid.add_child(col)
	for side in 2:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 230)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("sfx", "")
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := HomeKit.neon_box(SIDE_COLORS[side], st)
			sb.set_corner_radius_all(26)
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_vote.bind(side))
		col.add_child(b)
		side_btns.append(b)
		var l := Label.new()
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.offset_left = 20
		l.offset_right = -20
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 34)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		side_labels.append(l)
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 12)
		pb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		pb.offset_top = -22
		pb.offset_bottom = -10
		pb.offset_left = 24
		pb.offset_right = -24
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		fill.bg_color = SIDE_COLORS[side]
		fill.set_corner_radius_all(6)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.08)
		bg.set_corner_radius_all(6)
		pb.add_theme_stylebox_override("fill", fill)
		pb.add_theme_stylebox_override("background", bg)
		b.add_child(pb)
		bars.append(pb)
		if side == 0:
			var or_label := Label.new()
			or_label.text = tr("— or —")
			or_label.add_theme_font_size_override("font_size", 28)
			or_label.add_theme_color_override("font_color", HomeKit.GOLD)
			or_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(or_label)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 34)
	root.add_child(bm)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bm.add_child(row)
	var next := Button.new()
	next.text = tr("Next card ▶")
	next.custom_minimum_size = Vector2(320, 78)
	next.add_theme_font_size_override("font_size", 30)
	next.set_meta("sfx", "card_flip")
	next.pressed.connect(_next)
	row.add_child(next)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.PURPLE,
		"multi_heading": "Pick a deck",
		"subtitle": "Two choices, no way out. Pick one and defend it.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "😄 Classic", "sub": "For everyone", "row": "deck", "multi": true, "color": HomeKit.CYAN, "action": _new.bind("classic")},
			{"text": "🌶️ Spicy", "sub": "Friends and dates", "row": "deck", "multi": true, "color": HomeKit.PINK, "action": _new.bind("spicy")},
			{"text": "🎲 Mixed", "sub": "Both decks", "row": "deck", "multi": true, "color": HomeKit.PURPLE, "action": _new.bind("mixed")},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": func(): _start(engine.deck_name),
		"board": "Cards played",
		"board_note": "Dilemmas argued over, all time.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.15)  # beside the card count, above the choices
	add_child(drawer)

# ---------- flow ----------

func _new(deck: String) -> void:
	SaveUtil.delete(SAVE_PATH)
	_start(deck)

func _start(deck: String) -> void:
	engine.start(deck, _lang(), rng)
	started = true
	_render()

func _next() -> void:
	engine.next_card(rng)
	if info:
		info.add("Cards played")
	_render()

func _vote(side: int) -> void:
	engine.vote(side)
	_sfx("tick")
	_render()

func _render() -> void:
	var total: int = engine.votes[0] + engine.votes[1]
	count_label.text = tr("Card %d") % engine.played + ("   ·   " + tr("%d votes") % total if total > 0 else "   ·   " + tr("Tap a side to vote"))
	for side in 2:
		var text: String = str(engine.current[side])
		side_labels[side].text = text.substr(0, 1).to_upper() + text.substr(1) + ("\n%d%%" % engine.percent(side) if total > 0 else "")
		bars[side].value = engine.percent(side)
		bars[side].visible = total > 0

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 3.0, 50.0)
	var o := c.size / 2.0
	HomeKit.glow_rect(c, Rect2(o + Vector2(-k * 2.6, -k * 0.9), Vector2(k * 2.2, k * 1.8)), SIDE_COLORS[0], 2.5, 0.12)
	HomeKit.glow_rect(c, Rect2(o + Vector2(k * 0.4, -k * 0.9), Vector2(k * 2.2, k * 1.8)), SIDE_COLORS[1], 2.5, 0.12)
	HomeKit.glow_text(c, o + Vector2(-k * 1.5, 0), "A", int(k * 1.1), SIDE_COLORS[0])
	HomeKit.glow_text(c, o + Vector2(k * 1.5, 0), "B", int(k * 1.1), SIDE_COLORS[1])
	HomeKit.glow_text(c, o, "?", int(k * 0.9), HomeKit.GOLD)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

## Only which deck and how far you got; the next card is a fresh draw.
func _save_game() -> void:
	if not started:
		return
	SaveUtil.write(SAVE_PATH, {"deck": engine.deck_name, "played": engine.played})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Card %d") % int(d.get("played", 1))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	var deck := str(d.get("deck", "classic")) if d else "classic"
	_start(deck if deck in WyEngine.DECKS else "classic")
	if d:
		engine.played = int(d.get("played", 1))
	_render()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
