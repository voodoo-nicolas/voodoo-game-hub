extends Control

## "How to Play" + "Your Stats" for one game: a "?" tab docked just above the
## settings drawer's ⚙ tab, opening a card with the game's goal, rules, tips
## and the player's records. Opens by itself the first time a game is played.
##
## Games never preload this (packs also run on apps from before v0.20):
##
##     const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
##     var info = null  # null on older apps -- guard every call with `if info:`
##     ...
##     if ResourceLoader.exists(GAME_INFO_PATH):
##         info = load(GAME_INFO_PATH).new(preload("res://scripts/games/<id>/<id>_help.gd"))
##         add_child(info)
##     add_child(SettingsDrawer.new())   # stays last, as always
##
## The help script (`<id>_help.gd`, in the game's pack) holds only constants:
##   ID     save-file id              TITLE  game name (English; translated here)
##   GOAL   one sentence              HOW    Array of rule lines
##   TIPS   Array of tip lines        STATS  stat keys always shown, in order
## Stat keys are English and translated for display; build a key with a
## variant as `"Best time (%s)" % "Hard"` so both the "(%s)" pattern and the
## variant are literals the i18n extractor sees. Keys containing "time" hold
## seconds and show as m:ss; keys starting with "_" are internal, never shown.
##
## Recording: result("win"|"loss"|"draw"[, online]) for games against someone,
## add(key) for counters, high(key, v) / low(key, v) for records (both return
## true on a new record). summary() is a one-line recap for game-over screens.
## start_clock() / stop_clock() time a puzzle for games with no clock of their own.
## best(key, v) is high()/low() that celebrates beating an old record.
## celebrate("Solved!") plays the victory show (flash, starburst, big banner,
## confetti) over whatever end screen the game shows; result("win") does it
## by itself. It never blocks taps, and clears itself after a few seconds.

const Ui = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")

const TAB_SIZE := 44.0
## Matches SettingsDrawer: its tab is centred on the right edge; ours sits above.
const TAB_GAP := 10.0

var help: Script
var consts: Dictionary
var stats: Dictionary = {}
var save_path: String

var tab_button: Button
var overlay: ColorRect
var stats_box: VBoxContainer
var _paused_tree: bool = false
var _clock: float = 0.0
var _clock_on: bool = false

## Victory show state (see celebrate()).
const CELEBRATE_SECS := 4.2
## The stock banner texts, listed so the i18n extractor picks them up.
const CHEERS := ["You win!", "Solved!", "New best!"]
const CONFETTI_COLORS := [Color(1, 0.84, 0.1), Color(1, 0.3, 0.45), Color(0.3, 0.85, 1), Color(0.5, 1, 0.45), Color(0.8, 0.45, 1), Color(1, 0.6, 0.2), Color(1, 1, 1)]
var _party: Control
var _party_t: float = 0.0
var _confetti: Array = []  # [{p: Vector2, v: Vector2, rot, spin, size: Vector2, color}]

func _init(help_script: Script) -> void:
	help = help_script
	consts = help.get_script_constant_map()
	save_path = "user://stats_%s.json" % consts.get("ID", "game")
	var data = SaveUtil.read(save_path)
	if data != null:
		stats = data

func _ready() -> void:
	# In the tree already, so set_anchors_preset alone would keep our 0×0 size.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The card pauses the game underneath; it must keep working itself.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_tab()
	if not stats.has("_seen"):
		stats["_seen"] = 1
		_save()
		# After the game's own _ready() has finished building its screen.
		call_deferred("open")

func _exit_tree() -> void:
	_unpause()

# ---------- recording ----------

## A finished game against an opponent, from this player's point of view.
## Online games pass online = true: they're counted apart ("Online wins"),
## since the same screen also counts same-phone games per side.
func result(outcome: String, online: bool = false) -> void:
	if outcome == "loss":
		_buzz()  # wins buzz in celebrate(), which many games call directly
	if outcome == "win":
		celebrate("You win!")
	if online:
		add({"win": "Online wins", "loss": "Online losses"}.get(outcome, "Online draws"))
		return
	match outcome:
		"win":
			add("Wins")
			stats["_streak"] = int(stats.get("_streak", 0)) + 1
			high("Best streak", int(stats["_streak"]))
		"loss":
			add("Losses")
			stats["_streak"] = 0
		_:
			add("Draws")
			stats["_streak"] = 0
	_save()

func add(key: String, n: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + n
	_save()

## Higher is better. Returns true if `value` is a new record.
func high(key: String, value: float) -> bool:
	if stats.has(key) and value <= float(stats[key]):
		return false
	stats[key] = value
	_save()
	return true

## Lower is better (times, move counts). Returns true if `value` is a new record.
func low(key: String, value: float) -> bool:
	if stats.has(key) and value >= float(stats[key]):
		return false
	stats[key] = value
	_save()
	return true

## A stopwatch for games without their own clock: start_clock() when a
## puzzle begins, stop_clock() when it's solved (returns seconds). It skips
## time spent with the game paused, including on this card.
func start_clock() -> void:
	_clock = 0.0
	_clock_on = true

func stop_clock() -> float:
	_clock_on = false
	return _clock

func _process(delta: float) -> void:
	if _clock_on and not get_tree().paused:
		_clock += delta
	if _party:
		_step_party(delta)

# ---------- victory show ----------

## The big "you did it" moment: a white flash, a spinning gold starburst, a
## huge bouncing banner and two confetti cannons, drawn over the game's own
## end screen (mouse_filter IGNORE, so its buttons keep working). `text` is
## translated here: "You win!", "Solved!" and "New best!" are the stock ones.
func celebrate(text: String = "You win!") -> void:
	_buzz()
	if _party:
		_party.queue_free()
	var vp: Vector2 = get_viewport_rect().size
	_party = Control.new()
	_party.set_anchors_preset(Control.PRESET_FULL_RECT)
	_party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party.draw.connect(_draw_party)
	add_child(_party)
	move_child(_party, 0)  # under the ? tab and the help card
	_party_t = 0.0

	var flash := ColorRect.new()
	flash.color = Color(1, 1, 0.85, 0.7)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party.add_child(flash)
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.45)

	var banner := Label.new()
	banner.text = tr(text)
	banner.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var font_size := int(clampf(vp.x / maxf(banner.text.length(), 6) * 1.5, 56, 130))
	banner.add_theme_font_size_override("font_size", font_size)
	banner.add_theme_color_override("font_color", Color(1, 0.88, 0.2))
	banner.add_theme_color_override("font_outline_color", Color(0.35, 0.12, 0.0))
	banner.add_theme_constant_override("outline_size", maxi(8, font_size / 7))
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	banner.add_theme_constant_override("shadow_offset_x", 4)
	banner.add_theme_constant_override("shadow_offset_y", 6)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.size = Vector2(vp.x, font_size * 1.6)
	banner.position = Vector2(0, vp.y * 0.16 - banner.size.y / 2.0)
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.1, 0.1)
	_party.add_child(banner)
	var tw := banner.create_tween()
	tw.tween_property(banner, "scale", Vector2(1.18, 1.18), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.18)
	for i in 5:  # heartbeat
		tw.tween_property(banner, "scale", Vector2(1.07, 1.07), 0.26).set_trans(Tween.TRANS_SINE)
		tw.tween_property(banner, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_SINE)
	var fade := banner.create_tween()
	fade.tween_interval(CELEBRATE_SECS - 0.7)
	fade.tween_property(banner, "modulate:a", 0.0, 0.6)

	# two cannons from the bottom corners, plus a shower from the top
	_confetti.clear()
	for side in [0.0, 1.0]:
		for i in 70:
			var ang := deg_to_rad(randf_range(-100, -40) if side == 0.0 else randf_range(-140, -80))
			_confetti.append(_confetto(Vector2(vp.x * side, vp.y * 0.95), Vector2.from_angle(ang) * randf_range(vp.y * 0.9, vp.y * 1.7)))
	for i in 60:
		_confetti.append(_confetto(Vector2(randf() * vp.x, randf_range(-vp.y * 0.4, -10)), Vector2(randf_range(-60, 60), randf_range(80, 260))))

func _confetto(pos: Vector2, vel: Vector2) -> Dictionary:
	var w := randf_range(10, 20)
	return {"p": pos, "v": vel, "rot": randf() * TAU, "spin": randf_range(-9, 9),
		"size": Vector2(w, w * randf_range(0.4, 0.8)), "color": CONFETTI_COLORS[randi() % CONFETTI_COLORS.size()]}

func _step_party(delta: float) -> void:
	_party_t += delta
	if _party_t >= CELEBRATE_SECS:
		_party.queue_free()
		_party = null
		_confetti.clear()
		return
	var g: float = get_viewport_rect().size.y * 1.1
	for c in _confetti:
		c.v.y += g * delta
		c.v *= 1.0 - 1.6 * delta  # air drag: bursts slow down, then flutter
		c.p += c.v * delta
		c.rot += c.spin * delta
	_party.queue_redraw()

func _draw_party() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var fade: float = clampf((CELEBRATE_SECS - _party_t) / 0.8, 0.0, 1.0)
	# starburst behind the banner
	var center := Vector2(vp.x / 2.0, vp.y * 0.16)
	var r: float = vp.length() * 0.6 * minf(1.0, _party_t * 3.0)
	for i in 12:
		var a: float = _party_t * 0.6 + i * TAU / 12.0
		var pts := PackedVector2Array([center, center + Vector2.from_angle(a - 0.12) * r, center + Vector2.from_angle(a + 0.12) * r])
		_party.draw_colored_polygon(pts, Color(1, 0.85, 0.3, 0.16 * fade))
	for c in _confetti:
		_party.draw_set_transform(c.p, c.rot, Vector2.ONE)
		var col: Color = c.color
		col.a = fade
		# the flat side flashes as it tumbles
		var sz: Vector2 = c.size
		sz.y *= absf(cos(c.rot * 1.7)) * 0.8 + 0.2
		_party.draw_rect(Rect2(-sz / 2.0, sz), col)
	_party.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A score-style record at the end of a game: like high() (or low() with
## lower = true), and beating an earlier record plays the victory show. The
## very first game sets the record quietly -- there was nothing to beat.
func best(key: String, value: float, lower: bool = false) -> bool:
	var had := stats.has(key)
	var record: bool = low(key, value) if lower else high(key, value)
	if record and had:
		celebrate("New best!")
	return record

func get_stat(key: String, default: Variant = 0) -> Variant:
	return stats.get(key, default)

## "Wins: 3 · Losses: 1 · Draws: 0" -- the listed keys, or the game's STATS.
func summary(keys: Array = []) -> String:
	if keys.is_empty():
		keys = consts.get("STATS", [])
	var parts: PackedStringArray = []
	for k in keys:
		if k.begins_with("_") or (not stats.has(k) and _is_record(k)):
			continue
		parts.append("%s: %s" % [_label(k), _value_text(k)])
	return " · ".join(parts)

# ---------- UI ----------

func _build_tab() -> void:
	tab_button = Button.new()
	tab_button.text = "?"
	tab_button.add_theme_font_size_override("font_size", 26)
	tab_button.focus_mode = Control.FOCUS_NONE
	tab_button.anchor_left = 1.0
	tab_button.anchor_right = 1.0
	tab_button.anchor_top = 0.5
	tab_button.anchor_bottom = 0.5
	tab_button.position = Vector2(-TAB_SIZE, -TAB_SIZE / 2.0 - TAB_SIZE - TAB_GAP)
	tab_button.size = Vector2(TAB_SIZE, TAB_SIZE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	sb.corner_radius_top_left = 10
	sb.corner_radius_bottom_left = 10
	for state in ["normal", "hover", "pressed", "focus"]:
		tab_button.add_theme_stylebox_override(state, sb)
	tab_button.pressed.connect(open)
	add_child(tab_button)

func open() -> void:
	if overlay == null:
		_build_overlay()
	_fill_stats()
	overlay.visible = true
	tab_button.visible = false
	if not get_tree().paused:
		get_tree().paused = true
		_paused_tree = true

func close() -> void:
	if overlay:
		overlay.visible = false
	tab_button.visible = true
	_unpause()

func _unpause() -> void:
	if _paused_tree and is_inside_tree():
		get_tree().paused = false
	_paused_tree = false

func _build_overlay() -> void:
	var vp: Vector2 = get_viewport_rect().size
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	center.add_child(panel)

	var width: float = minf(vp.x - 48.0, 640.0) - 56.0  # minus the card's margins
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	panel.add_child(outer)

	var title := Label.new()
	title.text = tr(consts.get("TITLE", ""))
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.custom_minimum_size = Vector2(width, 0)
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(width, minf(vp.y * 0.62, 900.0))
	outer.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.custom_minimum_size = Vector2(width - 12.0, 0)
	scroll.add_child(body)

	if consts.has("GOAL"):
		_heading(body, tr("🎯 Goal"))
		_paragraph(body, tr(consts.GOAL), Color(1, 0.84, 0.3))
	if consts.has("HOW"):
		_heading(body, tr("📋 How to Play"))
		for line in consts.HOW:
			_paragraph(body, "•  " + tr(line))
	if consts.has("TIPS"):
		_heading(body, tr("💡 Tips"))
		for line in consts.TIPS:
			_paragraph(body, "•  " + tr(line))
	_heading(body, tr("📊 Your Stats"))
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 4)
	body.add_child(stats_box)

	var close_btn := Button.new()
	close_btn.text = tr("Got it!")
	close_btn.custom_minimum_size = Vector2(0, 64)
	close_btn.add_theme_font_size_override("font_size", 26)
	close_btn.pressed.connect(close)
	outer.add_child(close_btn)

func _heading(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
	parent.add_child(l)

func _paragraph(parent: Control, text: String, color: Color = Color(0.88, 0.88, 0.9)) -> void:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # already translated
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)

func _fill_stats() -> void:
	for c in stats_box.get_children():
		c.queue_free()
	var keys: Array = consts.get("STATS", []).duplicate()
	for k in stats:
		if not k.begins_with("_") and not keys.has(k):
			keys.append(k)
	var rows := 0
	for k in keys:
		if not stats.has(k) and _is_record(k):
			continue  # "Best score: —" before the first game says nothing useful
		_stat_row(_label(k), _value_text(k))
		rows += 1
	var w := int(stats.get("Wins", 0))
	var played := w + int(stats.get("Losses", 0)) + int(stats.get("Draws", 0))
	if played > 0:
		_stat_row(tr("Win rate"), "%d%%" % roundi(100.0 * w / played))
		rows += 1
	if rows == 0:
		_paragraph(stats_box, tr("Play a game and your records will show up here."), Color(0.65, 0.65, 0.7))

func _stat_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	var v := Label.new()
	v.text = value_text
	v.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_theme_font_size_override("font_size", 22)
	v.add_theme_color_override("font_color", Color(1, 1, 1))
	row.add_child(v)
	stats_box.add_child(row)

# ---------- formatting ----------

## Records (bests) only mean something once set; counters are 0 until then.
static func _is_record(key: String) -> bool:
	var k := key.to_lower()
	return k.begins_with("best") or k.begins_with("fewest") or k.begins_with("most") or k.begins_with("lowest") \
		or k.begins_with("fastest") or k.begins_with("highest") or k.begins_with("longest")

## A key translated as a whole ("Fastest reaction (ms)") wins; otherwise
## "Best time (Hard)" -> tr("Best time (%s)") % tr("Hard"). Games write the
## "(%s)" form as a literal so the extractor picks it up for translation.
func _label(key: String) -> String:
	var whole := tr(key)
	var open_at := key.rfind(" (")
	if whole != key or open_at <= 0 or not key.ends_with(")"):
		return whole
	var inner := key.substr(open_at + 2, key.length() - open_at - 3)
	return tr(key.substr(0, open_at) + " (%s)").replace("%s", tr(inner))

func _value_text(key: String) -> String:
	var v := float(stats.get(key, 0))
	if "time" in key.to_lower():
		var total := int(round(v))
		return "%d:%02d" % [int(total / 60), total % 60]
	return str(int(round(v)))

func _save() -> void:
	SaveUtil.write(save_path, stats)

## A longer vibration for a game's result, if the player has vibration on.
func _buzz() -> void:
	var settings = get_node_or_null("/root/Settings")
	if settings:
		settings.buzz(settings.RESULT_BUZZ_MS)
