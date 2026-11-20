extends Control

## "How to Play" + "Your Stats" for one game: a card with the game's goal,
## rules, tips and the player's records, opened from the settings drawer's
## "How to Play" button. Opens only when the player asks (Landing ❓ / pause menu).
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
const Achievements = preload("res://scripts/common/achievements.gd")

## Games with this stat get a 🏆 Leaderboard on the card (see Auth's
## leaderboard section and docs/leaderboards.sql).
const LEADERBOARD_KEY := "Best score"
const LEADERBOARD_SIZE := 10

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
var lb_heading: Label
var lb_box: VBoxContainer
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
	# Badges already earned before achievements existed (or in an older
	# version of this game) unlock quietly -- no toast flood on opening.
	if not stats.is_empty():
		var total_was = stats.get("_ach_total")
		if not Achievements.check(consts, stats).is_empty() or stats.get("_ach_total") != total_was:
			SaveUtil.write(save_path, stats)

func _ready() -> void:
	# In the tree already, so set_anchors_preset alone would keep our 0×0 size.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The card pauses the game underneath; it must keep working itself.
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_build_tab")
	# No card on first play (owner 2026-10-07): How to Play opens only from the
	# Landing's ❓ button or the pause menu.
	if not stats.has("_seen"):
		stats["_seen"] = 1
		_save()

func _exit_tree() -> void:
	_unpause()

# ---------- recording ----------

## A finished game against an opponent, from this player's point of view.
## Online games pass online = true: they're counted apart ("Online wins"),
## since the same screen also counts same-phone games per side.
func result(outcome: String, online: bool = false) -> void:
	_maybe_promo(online)
	if outcome == "loss":
		_buzz()  # wins buzz in celebrate(), which many games call directly
		_sfx("lose")
	elif outcome != "win":
		_sfx("draw")
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
	if key == "Games played":  # how arcade games mark a game over
		_maybe_promo(false)

## Higher is better. Returns true if `value` is a new record. A new
## "Best score" also goes on the online leaderboard when signed in.
func high(key: String, value: float) -> bool:
	if stats.has(key) and value <= float(stats[key]):
		return false
	_count_record(key)
	stats[key] = value
	_save()
	if key == LEADERBOARD_KEY:
		_submit_best()
	return true

## Lower is better (times, move counts). Returns true if `value` is a new record.
func low(key: String, value: float) -> bool:
	if stats.has(key) and value >= float(stats[key]):
		return false
	_count_record(key)
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
	_maybe_promo(false)
	_buzz()
	_sfx("record" if text == "New best!" else "win")
	if _party:
		_party.queue_free()
	var vp: Vector2 = get_viewport_rect().size
	_party = Control.new()
	_party.set_anchors_preset(Control.PRESET_FULL_RECT)
	_party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party.draw.connect(_draw_party.bind(_party))
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

## `layer` is the one being drawn: a second celebrate() replaces _party while
## the old one may still get one last draw.
func _draw_party(layer: Control) -> void:
	if layer != _party:
		return
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

## No floating "?" tab any more (since v0.22): it covered game boards, so the
## card opens from the ⚙ drawer's "How to Play" button instead. Kept for a
## game with no SettingsDrawer, which would otherwise have no way to open it.
## Deferred from _ready(): the drawer is added just after us.
func _build_tab() -> void:
	var parent := get_parent()
	if parent:
		for c in parent.get_children():
			if c != self and c.get_script() and str(c.get_script().resource_path).ends_with("settings_drawer.gd"):
				return
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
	_load_leaderboard()
	overlay.visible = true
	if tab_button:
		tab_button.visible = false
	if not get_tree().paused:
		get_tree().paused = true
		_paused_tree = true

func close() -> void:
	if overlay:
		overlay.visible = false
	if tab_button:
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
	if _has_leaderboard():
		_heading(body, tr("🏆 Leaderboard"))
		lb_heading = body.get_child(body.get_child_count() - 1)
		lb_box = VBoxContainer.new()
		lb_box.add_theme_constant_override("separation", 4)
		body.add_child(lb_box)

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

# ---------- leaderboard ----------

func _auth() -> Node:
	var a := get_node_or_null("/root/Auth")
	return a if a and a.has_method("fetch_leaderboard") else null

func _has_leaderboard() -> bool:
	return _auth() != null and consts.get("STATS", []).has(LEADERBOARD_KEY)

func _submit_best() -> void:
	var a := _auth()
	if a and a.is_logged_in() and stats.has(LEADERBOARD_KEY):
		a.submit_score(str(consts.get("ID", "")), int(stats[LEADERBOARD_KEY]))

## Fetches the top scores each time the card opens (posting ours first, in
## case it was set before signing in -- the server keeps the higher one).
func _load_leaderboard() -> void:
	if lb_box == null:
		return
	_submit_best()
	for c in lb_box.get_children():
		c.queue_free()
	_paragraph(lb_box, tr("Loading..."), Color(0.65, 0.65, 0.7))
	_auth().fetch_leaderboard(str(consts.get("ID", "")), LEADERBOARD_SIZE, _show_leaderboard)

func _show_leaderboard(rows: Variant) -> void:
	# The reply can land after the game was closed (removed, not yet freed):
	# get_node() from outside the tree would fail and _auth() return null.
	if lb_box == null or not is_instance_valid(lb_box) or not is_inside_tree() or _auth() == null:
		return
	for c in lb_box.get_children():
		c.queue_free()
	# Not set up on the server yet (or offline): no section at all.
	lb_heading.visible = rows != null
	lb_box.visible = rows != null
	if rows == null:
		return
	var a := _auth()
	var me: String = str(a.user_id) if a.is_logged_in() else ""
	if rows.is_empty():
		_paragraph(lb_box, tr("No scores yet — be the first!"), Color(0.65, 0.65, 0.7))
	for i in rows.size():
		var r: Dictionary = rows[i]
		var medal: String = ["🥇", "🥈", "🥉"][i] if i < 3 else "%d." % (i + 1)
		var mine: bool = str(r.get("user_id", "")) == me
		_lb_row("%s  %s" % [medal, str(r.get("display_name", "Player"))], str(int(r.get("score", 0))), mine)
	if not a.is_logged_in():
		_paragraph(lb_box, tr("Sign in (hub ⚙ Options) to put your best score on the board."), Color(0.65, 0.65, 0.7))

func _lb_row(who: String, score_text: String, mine: bool) -> void:
	var row := HBoxContainer.new()
	var col := Color(1, 0.84, 0.3) if mine else Color(0.85, 0.85, 0.9)
	for spec in [[who, true], [score_text, false]]:
		var l := Label.new()
		l.text = spec[0]
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", col)
		if spec[1]:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
		row.add_child(l)
	lb_box.add_child(row)

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

## Beating a record that already existed (not setting the first one)
## counts toward the "Record Breaker" achievements.
func _count_record(key: String) -> void:
	if stats.has(key) and not key.begins_with("_") and not Achievements.SKIP_KEYS.has(key):
		stats["_records"] = int(stats.get("_records", 0)) + 1

func _save() -> void:
	Achievements.merge_saved(save_path, stats)  # badges restored from the server meanwhile
	var got: Array = Achievements.check(consts, stats)
	SaveUtil.write(save_path, stats)
	for def in got:
		_toast_achievement(def)
	if not got.is_empty():
		_after_unlock()

# ---------- achievements ----------

## Every badge this game offers, for the Home kit's 🏅 screen:
## [{icon, title, desc (translated), unlocked: bool, progress: 0..1}],
## unlocked ones first.
func achievement_rows() -> Array:
	var rows: Array = []
	for def in Achievements.defs_for(consts, stats):
		rows.append({"icon": def.icon, "title": tr(def.title), "desc": Achievements.describe(def),
			"unlocked": Achievements.is_unlocked(stats, def), "progress": Achievements.progress(stats, def)})
	rows.sort_custom(func(a, b): return a.unlocked and not b.unlocked)
	return rows

var _toasts: Array = []  # queued badge defs
var _toast_panel: Control

func _toast_achievement(def: Dictionary) -> void:
	_toasts.append(def)
	if _toast_panel == null:
		_next_toast()

## A banner sliding down from the top for each new badge, one at a time.
## Ignores the mouse, so it never blocks the game.
func _next_toast() -> void:
	if _toasts.is_empty() or not is_inside_tree():
		_toast_panel = null
		return
	var def: Dictionary = _toasts.pop_front()
	var vp: Vector2 = get_viewport_rect().size
	var panel := PanelContainer.new()
	var sb := Ui.panel_style()
	sb.border_color = Color(1, 0.75, 0.2)
	sb.shadow_color = Color(1, 0.7, 0.1, 0.5)
	sb.shadow_size = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var icon := Label.new()
	icon.text = str(def.icon)
	icon.add_theme_font_size_override("font_size", 48)
	icon.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	for spec in [[tr("Achievement unlocked!"), 20, Color(1, 0.8, 0.3)], [tr(def.title), 28, Color(1, 1, 1)],
			[Achievements.describe(def), 20, Color(0.75, 0.8, 0.9)]]:
		var l := Label.new()
		l.text = spec[0]
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", spec[2])
		col.add_child(l)
	add_child(panel)
	var w: float = minf(vp.x - 40.0, 560.0)
	panel.custom_minimum_size = Vector2(w, 0)
	panel.reset_size()
	panel.position = Vector2((vp.x - w) / 2.0, -panel.size.y - 20.0)
	_toast_panel = panel
	var top: float = 70.0  # below the safe-area inset and most top bars' text
	var tw := panel.create_tween()
	tw.tween_property(panel, "position:y", top, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.6)
	tw.tween_property(panel, "position:y", -panel.size.y - 20.0, 0.3)
	tw.tween_callback(_end_toast.bind(panel))
	_sfx("notify")

func _end_toast(panel: Control) -> void:
	panel.queue_free()
	_toast_panel = null
	_next_toast()

# ---------- promo cards (the hub's own "ads", docs/monetization/PLAN.md) ----------

## A game just ended: the Store autoload decides whether a card is due (at
## most one every few games, never online, off unless the store is on). It
## slides in from the top after the result has had its moment, like a badge
## toast, but can be tapped: ⭐ subscribe, or open another game. ✕ or 8 s
## closes it. Apps without Store (and packs on them) simply never show one.
var _promo_msec: int = -100000
var _promo_panel: Control

func _maybe_promo(online: bool) -> void:
	_tame_end_screen_soon()
	# One game end often reports twice (result() + celebrate()).
	if Time.get_ticks_msec() - _promo_msec < 5000:
		return
	_promo_msec = Time.get_ticks_msec()
	var store = get_node_or_null("/root/Store")
	if store == null or not store.has_method("promo_for"):
		return
	var p: Dictionary = store.promo_for(str(consts.get("ID", "")), online)
	if p.is_empty():
		return
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_callback(_show_promo.bind(p))

# ---------- end-screen safety net (STANDARDS §6b) ----------

## Every game builds its own game-over dialog, and many (Hangman, ...) had
## two bugs: a long one-line label ("You win! The word was ...  Wins: 2 ·
## Losses: 1 · ...") pushed the panel off a narrow phone, and the dim
## full-screen card hid the board, so you couldn't see how you won or lost.
## Fixed here once, for every pack on this APK: when a game ends we find the
## visible end dialog, wrap its text to the screen, and add "👁 See board",
## which hides the dialog and leaves a small "📋 Results" chip to bring it back.
const END_MARGIN := 48.0

func _tame_end_screen_soon() -> void:
	# The game shows its dialog right after reporting; some after a short tween.
	var tw := create_tween()
	tw.tween_interval(0.05)
	tw.tween_callback(_tame_end_screen)
	tw.tween_interval(0.9)
	tw.tween_callback(_tame_end_screen)

func _tame_end_screen() -> void:
	var root := get_parent() as Control
	if root == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	for c in _end_candidates(root, 0):
		if not c.has_meta("_tamed"):
			c.set_meta("_tamed", true)
			_fit_to_screen(c, vp.x - END_MARGIN * 2.0)
			_add_peek(c)

## Visible, (nearly) full-screen controls that hold a panel: a game's
## end/overlay card. Our own card, the Landing kit and the party are skipped.
func _end_candidates(node: Node, depth: int) -> Array:
	var out: Array = []
	if depth > 3:
		return out
	var vp: Vector2 = get_viewport_rect().size
	for n in node.get_children():
		var c := n as Control
		if c == null or not c.visible or c == self or c == _party:
			continue
		if c.has_method("celebrate") or c.has_method("start_mode") or c.has_method("open"):
			continue
		var full: bool = c.size.x >= vp.x * 0.9 and c.size.y >= vp.y * 0.9 and c.mouse_filter == Control.MOUSE_FILTER_STOP
		if full and _find_panel(c) != null and (c is ColorRect or c is Panel or c is PanelContainer):
			out.append(c)
		else:
			out.append_array(_end_candidates(c, depth + 1))
	return out

func _find_panel(node: Node) -> Control:
	for n in node.get_children():
		if n is PanelContainer:
			return n
		var deep := _find_panel(n)
		if deep:
			return deep
	return null

## One-line labels wrap at the screen width; wide buttons shrink to fit.
func _fit_to_screen(node: Node, max_w: float) -> void:
	for n in node.get_children():
		if n is Label:
			var l: Label = n
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var natural: float = l.get_minimum_size().x
				if natural > max_w * 0.6:
					l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					l.custom_minimum_size.x = minf(natural, max_w - 60.0)
		elif n is Button:
			var b: Button = n
			if b.custom_minimum_size.x > max_w - 60.0:
				b.custom_minimum_size.x = max_w - 60.0
			if b.get_minimum_size().x > max_w - 60.0:
				b.clip_text = true
		_fit_to_screen(n, max_w)

func _add_peek(dialog: Control) -> void:
	var panel := _find_panel(dialog)
	var box: Node = null
	for n in panel.get_children():
		if n is BoxContainer:
			box = n
			break
	if box == null:
		return
	var peek := Button.new()
	peek.text = "👁  " + tr("See board")
	peek.flat = true
	peek.add_theme_font_size_override("font_size", 22)
	peek.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	peek.custom_minimum_size = Vector2(0, 52)
	peek.pressed.connect(_peek_board.bind(dialog))
	box.add_child(peek)

func _peek_board(dialog: Control) -> void:
	var parent := dialog.get_parent() as Control
	if parent == null:
		return
	dialog.visible = false
	var chip := Button.new()
	chip.text = "📋  " + tr("Results")
	chip.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.2, 0.92)
	sb.border_color = Color(0.35, 0.8, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(28)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	for st in ["normal", "hover", "pressed", "focus"]:
		chip.add_theme_stylebox_override(st, sb)
	chip.add_theme_color_override("font_color", Color(1, 1, 1))
	chip.z_index = 50
	parent.add_child(chip)
	chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	var safe_bottom := 0.0
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	if screen.y > 0 and safe.size.y > 0:
		safe_bottom = float(screen.y - safe.end.y) * get_viewport_rect().size.y / float(screen.y)
	chip.position.y -= 40.0 + safe_bottom
	chip.pressed.connect(_unpeek.bind(dialog, chip))
	# The game may reopen/replace the dialog itself (restart, home).
	dialog.visibility_changed.connect(_drop_chip.bind(chip), CONNECT_ONE_SHOT)
	dialog.tree_exiting.connect(_drop_chip.bind(chip), CONNECT_ONE_SHOT)

func _unpeek(dialog: Control, chip: Button) -> void:
	_drop_chip(chip)
	if is_instance_valid(dialog):
		dialog.visible = true

func _drop_chip(chip: Button) -> void:
	if is_instance_valid(chip) and not chip.is_queued_for_deletion():
		chip.queue_free()

func _show_promo(p: Dictionary) -> void:
	if not is_inside_tree() or _promo_panel != null:
		return
	if _toast_panel != null:  # a badge toast first
		var tw := create_tween()
		tw.tween_interval(3.5)
		tw.tween_callback(_show_promo.bind(p))
		return
	var store = get_node_or_null("/root/Store")
	var lang = get_node_or_null("/root/Lang")
	if store == null:
		return
	var icon_text := "⭐"
	var title := ""
	var line := ""
	var action := tr("Try it")
	if p.kind == "sub":
		var days := int(store.prices.get("hub_all:trial_days", 7))
		if p.get("owned", false):
			title = tr("Unlock the other %d games") % (store.game_count() - 1)
		else:
			title = tr("All %d games — %d days free") % [store.game_count(), days]
		line = store.subscription_terms()
	else:
		var g: Dictionary = p.game
		icon_text = str(g.get("icon", "🎮"))
		var game_name: String = lang.pick(g, "title") if lang else str(g.get("title", ""))
		title = tr("You might like %s") % game_name
		line = tr("A game you haven't tried yet.")
		action = tr("Play")

	var vp: Vector2 = get_viewport_rect().size
	var panel := PanelContainer.new()
	var sb := Ui.panel_style()
	sb.border_color = Color(1, 0.75, 0.2) if p.kind == "sub" else Color(0.3, 0.85, 1)
	sb.shadow_color = Color(sb.border_color, 0.5)
	sb.shadow_size = 14
	sb.content_margin_left = 18
	sb.content_margin_right = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var icon := Label.new()
	icon.text = icon_text
	icon.add_theme_font_size_override("font_size", 44)
	icon.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(icon)
	var w: float = minf(vp.x - 32.0, 620.0)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Wrapped labels need a real width, or the card measures one word per line.
	col.custom_minimum_size = Vector2(maxf(100.0, w - 262.0), 0)  # w minus icon, buttons, gaps
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	for spec in [[title, 24, Color(1, 1, 1)], [line, 17, Color(0.75, 0.8, 0.9)]]:
		var l := Label.new()
		l.text = spec[0]
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", spec[2])
		col.add_child(l)
	var go := Button.new()
	go.text = action
	go.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	go.custom_minimum_size = Vector2(100, 60)
	go.add_theme_font_size_override("font_size", 22)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(_on_promo_go.bind(p, panel))
	row.add_child(go)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.custom_minimum_size = Vector2(40, 48)
	close.add_theme_font_size_override("font_size", 24)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_end_promo.bind(panel))
	row.add_child(close)
	add_child(panel)
	panel.custom_minimum_size = Vector2(w, 0)
	panel.position = Vector2((vp.x - w) / 2.0, -4000.0)  # out of sight until measured
	_promo_panel = panel
	# Wrapped labels only know their height once laid out at their width, so
	# measure a moment later (a free-floating panel never shrinks by itself).
	var wait := panel.create_tween()
	wait.tween_interval(0.05)
	wait.tween_callback(_slide_promo.bind(panel))

func _slide_promo(panel: Control) -> void:
	panel.reset_size()
	panel.position = Vector2((get_viewport_rect().size.x - panel.size.x) / 2.0, -panel.size.y - 20.0)
	var tw := panel.create_tween()
	tw.tween_property(panel, "position:y", 70.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(8.0)
	tw.tween_property(panel, "position:y", -panel.size.y - 20.0, 0.3)
	tw.tween_callback(_end_promo.bind(panel))

func _on_promo_go(p: Dictionary, panel: Control) -> void:
	_end_promo(panel)
	if p.kind == "sub":
		var store = get_node_or_null("/root/Store")
		if store:
			store.subscribe()
		return
	# Open the other game through the hub, like an invite does.
	var social = get_node_or_null("/root/Social")
	if social:
		social.launch_request = str(p.game.get("id", ""))
	Ui.exit_to_hub(get_parent() if get_parent() else self)

func _end_promo(panel: Control) -> void:
	if is_instance_valid(panel):
		panel.queue_free()
	if _promo_panel == panel:
		_promo_panel = null

## Hub-wide badges may follow (games tried, badges total), and the badge
## count goes on the 🏅 leaderboard when signed in.
func _after_unlock() -> void:
	for h in Achievements.check_hub():
		_toast_achievement({"icon": h[1], "title": h[2], "desc": h[3]})
	var a := _auth()
	if a and a.is_logged_in():
		a.submit_score(Achievements.BOARD_ID, Achievements.total_unlocked())

## A longer vibration for a game's result, if the player has vibration on.
func _buzz() -> void:
	var settings = get_node_or_null("/root/Settings")
	if settings:
		settings.buzz(settings.RESULT_BUZZ_MS)

func _sfx(sound: String) -> void:
	var sfx = get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound)
