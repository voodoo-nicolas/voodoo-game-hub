extends Control

## Voodoo IQ -- the adaptive IQ test and Blitz (docs/voodoo-iq-spec.md), Phase 2:
## brain-map home screen + setup, the test runner and the results. The server
## (supabase/functions/, see CLAUDE.md "Voodoo IQ backend") generates and scores
## every item; this scene draws them, times them and sends the answers.
## The look and the text follow the reference prototype (docs/voodoo-iq-prototype.html);
## its EN/ES text comes from voodoo_iq_data.json via voodoo_iq_text.gd.

const T = preload("res://scripts/games/voodoo_iq/voodoo_iq_text.gd")
const Art = preload("res://scripts/games/voodoo_iq/voodoo_iq_art.gd")
const Items = preload("res://scripts/games/voodoo_iq/voodoo_iq_items.gd")
const Audio = preload("res://scripts/games/voodoo_iq/voodoo_iq_audio.gd")
const Api = preload("res://scripts/games/voodoo_iq/voodoo_iq_api.gd")
## 🏅 the game's own achievements (genius medals, Prepper, Fixer; owner 2026-10-28).
const Awards = preload("res://scripts/games/voodoo_iq/voodoo_iq_awards.gd")
const Help = preload("res://scripts/games/voodoo_iq/voodoo_iq_help.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const DragScroll = preload("res://scripts/common/drag_scroll.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded, like every game (see GameInfo's header).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const SETUP_PATH := "user://voodoo_iq_setup.json"

const BG := Color("#07070C")
const PANEL := Color("#12121C")
const FG := Color("#EDEDF5")
const FG2 := Color("#A8A8C0")
const ACCENT := Color("#9b4dff")  # voodoo purple (art standard)
const GOOD := Color("#7dff3a")
const WARN := Color("#FFAE2B")
## Content width: the real screen minus margins (see _fit_width), never a fixed 680.
var W := 680.0

var info = null  # GameInfo; null on apps without it
var api: Node
var page: Control  # the current screen
var overlay_layer: Control
var overlay_footer: VBoxContainer
var overlay_bar: Control
var toast_label: Label

## dur 0 = endless (no clock; the player ends it with Finish)
var setup := {"mode": "iq", "scope": "ALL", "dur": 0, "bdur": 120, "ranked": true, "colorblind": false}

# ---- runner state
var session: Dictionary = {}
var running := false
var waiting := false  # a request is out: the clocks stop
# "Loading" watchdog (owner, 2026-10-27: the test froze on Loading on the PC and web builds)
const STALL_MS := 3000  # a reply later than this is reported, and an answer is sent again
const REPORTS_PATH := "user://voodoo_iq_reports.json"  # reports that couldn't be sent yet
var busy_fn := ""  # which request the "Loading" overlay is waiting for
var busy_since := 0  # Time.get_ticks_msec() when it came up
var busy_flagged := false  # the 3 s mark passed with no reply
var answer_inflight := 0  # answer requests out (1, or 2 after the watchdog's resend)
var pending_body: Dictionary = {}
var reports_sent := 0
var paused := false  # instructions / prediction on screen: the clocks stop
var remaining_ms := 0.0
var endless := false  # IQ test with no clock (dur 0)
var item: Dictionary = {}
var view = null  # Items.ItemView of the current item
var item_ms := 0.0
var item_timing := false
var seen: Dictionary = {}
var blitz_items: Array = []
var blitz_index := 0
var blitz_answers: Array = []
var pending_answer: Dictionary = {}
var clock_label: Label
var item_bar: ProgressBar
var count_label: Label
var qarea: VBoxContainer
var pending_start: Dictionary = {}
var finish_reason := "time"
var screen_name := ""  # the screen _on_screen_resized redraws
var last_result: Dictionary = {}
var fresh_result := true
## The player can't play sound right now: musical questions are passed over
## (sent as unanswered, like a timeout) for the rest of this test.
var skip_music := false
## The text size changed while paused: the question is laid out again on Continue.
var relayout_item := false
const SOUND_OPTIONS_PATH := "res://scripts/common/sound_options.gd"
## Worked examples for the question types players found unclear (Existential).
## The second EXI set (2026-10-25) brings its example lines in voodoo_iq_more.json (wx_<gid>).
const EXAMPLE_GIDS := ["syll", "syllquick", "fallacy", "wason", "necsuf", "assume", "contradict", "crt"]
var info_back: Callable  # where the Info screen's Back goes
## Practice tests only (owner, 2026-10-25: ranked tests show no answers and no review):
## every answered item with the server's feedback, for the right / wrong card after each
## answer and the review at the end. Entries: {item, value, fb, skipped, reported}.
var practice_log: Array = []
var review_wrong_only := false
var review_index := 0
var review_scroll := 0
const PINK := Color("#ff4f9a")
## Practice seconds not yet added to Prepper's total (saved every 15 s and when a test ends).
var practice_pending := 0.0
var awards_checked := false  # the home screen asked the server once this visit
var ach_filter := 0  # 🏅 screen: 0 All, 1 Earned, 2 Locked (STANDARDS §3b)

func _ready() -> void:
	preload("res://scripts/games/voodoo_iq/voodoo_iq_i18n.gd").install(self)
	T.install_en_labels(self)
	Orientation.lock_portrait()
	var saved = SaveUtil.read(SETUP_PATH)
	if saved is Dictionary:
		for k in setup:
			if saved.has(k):
				setup[k] = saved[k]
	setup.dur = int(setup.dur)
	setup.bdur = int(setup.bdur)
	Art.colorblind = bool(setup.colorblind)
	_build_ui()
	get_viewport().size_changed.connect(_on_screen_resized)
	_show_home()
	_flush_reports()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	api = Api.new()
	add_child(api)
	page = Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	overlay_layer = Control.new()
	overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_layer)
	toast_label = _label("", 24, Color.WHITE)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_top = -120
	toast_label.offset_bottom = -60
	toast_label.offset_left = -W / 2
	toast_label.offset_right = W / 2
	toast_label.visible = false
	add_child(toast_label)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(Help)
		add_child(info)
	# No floating SettingsDrawer (retired, STANDARDS §6): the test's own ⏸
	# card has text size and sound, and Hub is only on the home page (N1).

# ================================================================== helpers

func _label(text: String, size: int, color: Color, width: float = 0.0, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(text: String, cb: Callable, accent: Color = ACCENT, min_size := Vector2(0, 72), font := 28) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Items.style_button(b, accent)
	b.pressed.connect(cb)
	return b

func _panel(border: Color = Color("#2A2A3E")) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := Items.box_style(PANEL, border, 2, 16)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)
	return box

func _panel_of(box: VBoxContainer) -> Control:
	return box.get_parent()

## A fresh full-screen page; with scroll, its content scrolls (drag anywhere).
func _new_page(scroll: bool) -> VBoxContainer:
	_fit_width()
	for c in page.get_children():
		c.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	page.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if scroll:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.add_child(box)
		sc.add_child(DragScroll.new())
		margin.add_child(sc)
	else:
		margin.add_child(box)
	return box

## Size everything from the screen we actually have: the root's width in canvas units
## (the text-size setting scales the canvas, and the safe area insets the root).
## Size everything from the screen we actually have: the visible canvas (the text-size
## setting scales it: Large leaves 600 of the 720-wide design) minus the safe-area inset
## Settings puts on this root. Not this Control's own size: content that is too wide
## stretches it past the screen, which is how options ended up cut off on phones.
func _fit_width() -> void:
	var screen := get_viewport_rect().size.x - offset_left + offset_right
	W = clampf(screen - 40.0, 280.0, 680.0)
	Items.W = W

## Settings applies the text size (and safe area) after _ready and when the window
## turns, so lay the current screen out again whenever the visible width changes.
## Not mid-test: an item on screen is never rebuilt.
func _on_screen_resized() -> void:
	var old := W
	_fit_width()
	if absf(W - old) < 1.0 or running or waiting:
		return
	match screen_name:
		"home":
			_show_home()
		"options":
			_show_options()
		"boards":
			_show_boards()
		"achievements":
			_show_achievements()
		"results":
			_show_results(last_result)
		"info":
			_show_info(info_back)
		"review":
			_show_review()
		"review_item":
			_show_review_item(review_index)

func _toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.offset_left = -W / 2
	toast_label.offset_right = W / 2
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	var tw := toast_label.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(toast_label.hide)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

## A dialog card over everything; returns its content box. Close with _close_overlays().
## The card scrolls; `overlay_footer` (shown only when something is added) stays pinned
## below it, so Start / Back never need a scroll to reach.
func _overlay() -> VBoxContainer:
	_fit_width()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.add_to_group("modal_overlay")
	overlay_layer.add_child(dim)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	dim.add_child(col)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(size.x, maxf(0.0, size.y - 110.0))
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(center)
	var box := _panel(ACCENT)
	box.custom_minimum_size = Vector2(W - 40, 0)
	center.add_child(_panel_of(box))
	var bar := PanelContainer.new()
	var sb := Items.box_style(BG, Color(ACCENT, 0.6), 2, 0)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	bar.add_theme_stylebox_override("panel", sb)
	overlay_footer = VBoxContainer.new()
	overlay_footer.add_theme_constant_override("separation", 8)
	bar.add_child(overlay_footer)
	bar.visible = false
	col.add_child(bar)
	overlay_bar = bar
	return box

## Puts a button in the pinned footer of the newest overlay (see _overlay).
func _pin_to_overlay(b: Control) -> void:
	overlay_footer.add_child(b)
	overlay_bar.visible = true

func _close_overlays() -> void:
	for c in overlay_layer.get_children():
		c.queue_free()

func _save_setup() -> void:
	SaveUtil.write(SETUP_PATH, setup)

func _sec_name(scope: String) -> String:
	return T.t("all_mixed") if scope == "ALL" else T.t("sec_" + scope)

func _icon(sec: String, size: float) -> Control:
	return Art.canvas(func(ci, sz): Art.icon(ci, sec, Rect2(Vector2.ZERO, sz)), Vector2(size, size))

# ================================================================== HOME (brain menu + setup)

func _show_home() -> void:
	# Tapping an option rebuilds Home: keep the player where they were instead
	# of jumping back to the top.
	var keep_scroll := 0
	if screen_name == "home":
		var old_sc := _page_scroller()
		if old_sc:
			keep_scroll = old_sc.scroll_vertical
	screen_name = "home"
	running = false
	skip_music = false
	_close_overlays()
	var box := _new_page(true)
	_restore_scroll(keep_scroll)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_button(tr("Hub"), UI.exit_to_hub.bind(self), FG2, Vector2(100, 60), 24))
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_child(_neon_title(T.app_name().to_upper(), 48))
	brand.add_child(_label(T.t("tagline"), 22, FG2))
	top.add_child(brand)
	box.add_child(top)

	box.add_child(_label(T.t("hero"), 30, Color.WHITE, W))
	box.add_child(_label(T.t("hero_sub"), 21, FG2, W))
	if not api.is_signed_in():
		var warn := _panel(WARN)
		warn.add_child(_label(tr("Sign in to take the IQ test: hub → ⚙ Options → Account. Scores are saved to your account."), 24, WARN, W - 40))
		box.add_child(_panel_of(warn))

	# brain map: tap a region to choose a section
	var bp := _panel()
	# baked: the map is ~200 polygons, sent to the GPU every frame as a live Canvas
	var brain := Art.baked(func(ci, sz): Art.brain(ci, Rect2(Vector2.ZERO, sz), str(setup.scope)), Vector2(W - 40, (W - 40) * 440.0 / 560.0))
	brain.mouse_filter = Control.MOUSE_FILTER_STOP
	brain.gui_input.connect(_on_brain_input.bind(brain))
	bp.add_child(brain)
	var legend := GridContainer.new()
	legend.columns = 2
	legend.add_theme_constant_override("h_separation", 8)
	legend.add_theme_constant_override("v_separation", 8)
	legend.add_child(_chip("ALL", "★  " + T.t("all_mixed")))
	var secs := T.secs()
	for i in secs.size():
		legend.add_child(_chip(secs[i], "%d  %s" % [i + 1, T.t("sec_" + secs[i])]))
	bp.add_child(legend)
	var scope := str(setup.scope)
	if scope == "ALL":
		bp.add_child(_label(T.t("all_mixed"), 28, Color.WHITE, W - 40))
		bp.add_child(_label(T.t("all_desc_iq") if setup.mode == "iq" else T.t("all_desc_blitz"), 22, FG2, W - 40))
	else:
		var head := HBoxContainer.new()
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_child(_icon(scope, 34))
		head.add_child(_label(" " + T.t("sec_" + scope), 28, T.sec_color(scope)))
		bp.add_child(head)
		bp.add_child(_label(T.t("desc_" + scope), 22, FG, W - 40))
		bp.add_child(_label(T.t("brain_area") + ": " + T.t("area_" + scope) + "
" + (T.t("counts_iq") if T.core().has(scope) else T.t("counts_profile")), 20, FG2, W - 40))
	box.add_child(_panel_of(bp))

	# start: one big button; mode, time and the rest sit behind the summary line
	var sp := _panel(ACCENT)
	var start_text := "▶ %s · %s
%s" % [T.t("start"), T.t("iqtest") if setup.mode == "iq" else T.t("blitz"), ("🏆 " + T.t("ranked")) if setup.ranked else ("🎯 " + T.t("practice"))]
	sp.add_child(_button(start_text, _start_from_setup, GOOD, Vector2(0, 90), 32))
	sp.add_child(_button("⚙ " + _options_summary() + "  ›", _show_options, FG2, Vector2(0, 64), 20))
	box.add_child(_panel_of(sp))
	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", 10)
	var boards_btn := _button("🏆 " + T.t("nav_boards"), _show_boards, WARN, Vector2(0, 64), 22)
	boards_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links.add_child(boards_btn)
	if info:
		var ach_btn := _button("🏅 " + tr("Achievements"), _show_achievements, ACCENT, Vector2(0, 64), 22)
		ach_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		links.add_child(ach_btn)
	var profile_btn := _button("👤 " + tr("Profile"), _show_profile_form, FG2, Vector2(0, 64), 22)
	profile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links.add_child(profile_btn)
	box.add_child(links)
	if not awards_checked:
		awards_checked = true
		_check_awards(T.secs(), true)  # medals and fixed 🚩 reports earned while away
	box.add_child(_button(T.info("button"), _show_info.bind(_show_home), ACCENT, Vector2(0, 64), 22))

## "IQ Test · ∞ · 🏆 Ranked" (+ 🎨): what Start will run, under the Start button.
func _options_summary() -> String:
	var iq_mode: bool = setup.mode == "iq"
	var parts: Array = [T.t("iqtest") if iq_mode else T.t("blitz")]
	var dur := int(setup.dur) if iq_mode else int(setup.bdur)
	parts.append("∞" if (iq_mode and dur == 0) else ("%d min" % dur if iq_mode else "%d min" % (dur / 60)))
	parts.append(("🏆 " + T.t("ranked")) if setup.ranked else ("🎯 " + T.t("practice")))
	if setup.colorblind:
		parts.append("🎨")
	return " · ".join(parts)

## A tap in the options rebuilds the screen it is on.
func _refresh_setup() -> void:
	if screen_name == "options":
		_show_options()
	else:
		_show_home()

# ================================================================== TEST OPTIONS (mode, time, ranked, colours)

func _show_options() -> void:
	var keep_scroll := 0
	if screen_name == "options":
		var old_sc := _page_scroller()
		if old_sc:
			keep_scroll = old_sc.scroll_vertical
	screen_name = "options"
	running = false
	_close_overlays()
	var box := _new_page(true)
	_restore_scroll(keep_scroll)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_button("◀", _show_home, FG2, Vector2(70, 60), 26))
	var title := _neon_title("⚙ " + T.t("setup_title"), 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	box.add_child(top)
	var scope := str(setup.scope)
	var sp := _panel(ACCENT)
	sp.add_child(_label(T.t("mode"), 22, FG2, 0, HORIZONTAL_ALIGNMENT_LEFT))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	for m in [["iq", T.t("iqtest"), T.t("iq_hint")], ["blitz", T.t("blitz"), T.t("blitz_hint")]]:
		var b := _button(m[1] + "\n" + m[2], _set_mode.bind(m[0]), GOOD if setup.mode == m[0] else FG2, Vector2(0, 90), 24)
		if setup.mode == m[0]:
			b.add_theme_stylebox_override("normal", Items.box_style(Color(GOOD, 0.22), GOOD, 3))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		modes.add_child(b)
	sp.add_child(modes)
	sp.add_child(_label(T.t("time_limit"), 22, FG2, 0, HORIZONTAL_ALIGNMENT_LEFT))
	var durs := HBoxContainer.new()
	durs.add_theme_constant_override("separation", 8)
	var iq_mode: bool = setup.mode == "iq"
	var choices: Array = ([0] + T.data().get("IQ_DURS", [])) if iq_mode else T.data().get("BLITZ_DURS", [])
	for dv in choices:
		var dur := int(dv)
		var on: bool = (setup.dur if iq_mode else setup.bdur) == dur
		var text := "∞" if dur == 0 else "%d min" % (dur if iq_mode else dur / 60)
		var b := _button(text, _set_dur.bind(dur), GOOD if on else FG2, Vector2(0, 64), 30 if dur == 0 else 24)
		if on:
			b.add_theme_stylebox_override("normal", Items.box_style(Color(GOOD, 0.22), GOOD, 3))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		durs.add_child(b)
	sp.add_child(durs)
	if iq_mode and int(setup.dur) == 0:
		sp.add_child(_label(tr("∞ No time limit: answer as many questions as you like and tap Finish when you're done. Every answer counts, so long runs reach the boards faster."), 19, GOOD, W - 40, HORIZONTAL_ALIGNMENT_LEFT))
	# Ranked or practice: two big buttons, the chosen one lit (players missed
	# the old small switch).
	sp.add_child(_label(tr("Does this test count?"), 22, FG2, 0, HORIZONTAL_ALIGNMENT_LEFT))
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 10)
	for opt in [[true, "🏆 " + T.t("ranked"), tr("Saved, on the boards"), WARN], [false, "🎯 " + T.t("practice"), tr("Not saved"), Color("#29e6ff")]]:
		var on: bool = bool(setup.ranked) == opt[0]
		var col: Color = opt[3]
		var rb := _button(("✓ " if on else "") + str(opt[1]) + "\n" + str(opt[2]), _set_ranked.bind(opt[0]), col if on else FG2, Vector2(0, 96), 26)
		if on:
			rb.add_theme_stylebox_override("normal", Items.box_style(Color(col, 0.28), col, 4))
		else:
			rb.add_theme_color_override("font_color", FG2)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rrow.add_child(rb)
	sp.add_child(rrow)
	# not the prototype's ranked_iq_note: ranked IQ has no daily limit any more (user, 2026-10-03)
	var note: String = (tr("Counts for the leaderboard. Your last 3 ranked tests in each section count, so one lucky run can't carry you.") if iq_mode else T.t("ranked_blitz_note")) if setup.ranked else T.t("practice_note")
	sp.add_child(_label(note, 19, FG2, W - 40, HORIZONTAL_ALIGNMENT_LEFT))
	# Colour-blind option: cube colours and creature colours change to a safe set.
	var cbb := _button(("✓ " if setup.colorblind else "") + "🎨 " + tr("Colour-blind friendly colours"), _set_colorblind.bind(not bool(setup.colorblind)), GOOD if setup.colorblind else FG2, Vector2(0, 64), 22)
	if setup.colorblind:
		cbb.add_theme_stylebox_override("normal", Items.box_style(Color(GOOD, 0.22), GOOD, 3))
	sp.add_child(cbb)
	sp.add_child(_label(tr("Changes the colours in the cube and creature questions."), 18, FG2, W - 40, HORIZONTAL_ALIGNMENT_LEFT))
	if scope in ["LIN", "EXI", "ALL"]:
		sp.add_child(_label(T.t("lang_note", {"l": "Español" if T.lang() == "es" else "English"}), 18, FG2, W - 40))
	box.add_child(_panel_of(sp))
	box.add_child(_button("▶ " + T.t("start") + " · " + _options_summary(), _start_from_setup, GOOD, Vector2(0, 80), 24))
	box.add_child(_button("◀ " + tr("Back"), _show_home, FG2, Vector2(0, 64), 24))

# ================================================================== INFO (intelligence, genius, quotes)

## `back` reopens the screen the player came from (home or results).
func _show_info(back: Callable) -> void:
	screen_name = "info"
	info_back = back
	_close_overlays()
	var box := _new_page(true)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_button("← " + str(T.info("back")), back, FG2, Vector2(120, 60), 24))
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_child(_neon_title(str(T.info("title")), 40))
	brand.add_child(_label(str(T.info("subtitle")), 22, FG2))
	top.add_child(brand)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(120, 0)  # balances the Back button
	top.add_child(spacer)
	box.add_child(top)

	var wp := _info_panel(str(T.info("what_h")), ACCENT)
	for p in T.info("what"):
		wp.add_child(_info_text(str(p), FG))
	for p in T.info("what_more"):
		wp.add_child(_info_text(str(p), FG))
	box.add_child(_panel_of(wp))

	var tp := _info_panel(str(T.info("types_h")), ACCENT)
	tp.add_child(_info_text(str(T.info("types_intro")), FG2))
	var descs: Dictionary = T.info("types")
	var examples: Dictionary = T.info("types_ex")
	for sec in T.secs():
		var head := HBoxContainer.new()
		head.add_child(_icon(sec, 32))
		head.add_child(_label(" " + T.t("sec_" + sec), 24, T.sec_color(sec)))
		tp.add_child(head)
		tp.add_child(_info_text(str(descs.get(sec, "")), FG))
		if examples.has(sec):
			tp.add_child(_info_text(str(T.info("types_ex_h")) + ": " + str(examples[sec]), FG2, 18))
		if T.core().has(sec):
			tp.add_child(_label("★ " + str(T.info("core_tag")), 18, GOOD, W - 40, HORIZONTAL_ALIGNMENT_LEFT))
	tp.add_child(_info_text(str(T.info("types_note")), FG2, 18))
	box.add_child(_panel_of(tp))

	var op := _info_panel(str(T.info("one_h")), WARN)
	for p in T.info("one"):
		op.add_child(_info_text(str(p), FG))
	box.add_child(_panel_of(op))

	var ip := _info_panel(str(T.info("iq_h")), Color("#4FB3FF"))
	var iq_paras: Array = T.info("iq")
	for i in iq_paras.size():
		ip.add_child(_info_text(str(iq_paras[i]), FG))
		if i == 0:
			ip.add_child(Art.canvas(func(ci, sz): Art.bell(ci, Rect2(Vector2.ZERO, sz), NAN, 0.0, ACCENT, FG, FG2, 1.96, "★130+", WARN), Vector2(W - 40, (W - 40) * 230.0 / 640.0)))
			ip.add_child(_info_text(tr("The curve shows how many people land in each band: most people are near 100, very few are far from it."), FG2, 18))
	box.add_child(_panel_of(ip))

	var hw := _info_panel(str(T.info("how_h")), Color("#2EE6A6"))
	for p in T.info("how"):
		hw.add_child(_info_text(str(p), FG))
	box.add_child(_panel_of(hw))

	var gp := _info_panel(str(T.info("genius_h")), GOOD)
	gp.add_child(_info_text(str(T.info("genius_intro")), FG2))
	var points: Array = T.info("genius")
	for i in points.size():
		gp.add_child(_label("%d. %s" % [i + 1, points[i][0]], 24, GOOD, W - 40, HORIZONTAL_ALIGNMENT_LEFT))
		gp.add_child(_info_text(str(points[i][1]), FG))
	gp.add_child(_info_text(str(T.info("genius_outro")), FG2))
	box.add_child(_panel_of(gp))

	var qp := _info_panel(str(T.info("quotes_h")), Color("#00e5ff"))
	qp.add_child(_info_text(str(T.info("quotes_note")), FG2, 18))
	for q in T.info("quotes"):
		qp.add_child(_info_text("“%s”" % q[0], Color.WHITE, 22))
		qp.add_child(_label("— " + str(q[1]), 18, Color("#00e5ff"), W - 40, HORIZONTAL_ALIGNMENT_RIGHT))
	box.add_child(_panel_of(qp))

	var ap := _info_panel(str(T.info("about_h")), Color("#2A2A3E"))
	ap.add_child(_info_text(T.t("footer"), FG2))
	ap.add_child(_info_text(T.t("brain_disclaimer"), FG2, 18))
	box.add_child(_panel_of(ap))
	box.add_child(_button("← " + str(T.info("back")), back, FG2, Vector2(0, 68), 24))

func _info_panel(heading: String, border: Color) -> VBoxContainer:
	var p := _panel(border)
	p.add_child(_label(heading, 30, Color.WHITE if border == Color("#2A2A3E") else border, W - 40))
	return p

func _info_text(text: String, color: Color, size := 21) -> Label:
	return _label(text, size, color, W - 40, HORIZONTAL_ALIGNMENT_LEFT)

func _page_scroller() -> ScrollContainer:
	for m in page.get_children():
		if m.is_queued_for_deletion():
			continue
		for c in m.get_children():
			if c is ScrollContainer:
				return c
	return null

## Sets the new page's scroll once its content has been laid out (a few
## frames: the scroll range is 0 until then). The tween dies with the page.
func _restore_scroll(v: int) -> void:
	var sc := _page_scroller()
	if sc == null or v <= 0:
		return
	var tw := sc.create_tween()
	for wait in [0.0, 0.03, 0.08]:
		tw.tween_interval(wait)
		tw.tween_callback(sc.set_deferred.bind("scroll_vertical", v))

func _neon_title(text: String, size: int) -> Label:
	var l := _label(text, size, Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(ACCENT, 0.8))
	l.add_theme_constant_override("outline_size", 10)
	return l

func _chip(sec: String, text: String) -> Button:
	var on: bool = setup.scope == sec
	var col := Color.WHITE if sec == "ALL" else T.sec_color(sec)
	# only the chosen chip is coloured: nine colours at once was too busy
	var b := _button(text, _pick_scope.bind(sec), col if on else FG2, Vector2((W - 48) / 2.0, 64), 19)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if on:
		b.add_theme_stylebox_override("normal", Items.box_style(Color(col, 0.28), col, 3))
	if setup.mode == "blitz" and sec == "SELF":
		b.disabled = true
	return b

func _on_brain_input(e: InputEvent, brain: Control) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var sec := Art.brain_hit(e.position, brain.size)
		if sec != "":
			_pick_scope(sec)

func _pick_scope(sec: String) -> void:
	if setup.mode == "blitz" and sec == "SELF":
		_toast(T.t("self_no_blitz"))
		return
	setup.scope = "ALL" if setup.scope == sec else sec
	_save_setup()
	_show_home()

func _set_colorblind(on: bool) -> void:
	setup.colorblind = on
	Art.colorblind = on
	_save_setup()
	_refresh_setup()

func _set_mode(m: String) -> void:
	setup.mode = m
	if m == "blitz" and setup.scope == "SELF":
		setup.scope = "ALL"
	_save_setup()
	_refresh_setup()

func _set_dur(dur: int) -> void:
	if setup.mode == "iq":
		setup.dur = dur
	else:
		setup.bdur = dur
	_save_setup()
	_refresh_setup()

func _set_ranked(on: bool) -> void:
	setup.ranked = on
	_save_setup()
	_refresh_setup()

# ================================================================== PROFILE

func _show_profile_form() -> void:
	if not api.is_signed_in():
		_toast(tr("Sign in to take the IQ test: hub → ⚙ Options → Account. Scores are saved to your account."))
		return
	_close_overlays()
	var box := _overlay()
	box.add_child(_label(T.t("profile_title"), 32, Color.WHITE))
	box.add_child(_label(T.t("profile_sub"), 20, FG2, W - 80))
	box.add_child(_label(T.t("nickname"), 22, FG, 0, HORIZONTAL_ALIGNMENT_LEFT))
	var nick := LineEdit.new()
	nick.max_length = 18
	nick.custom_minimum_size = Vector2(0, 64)
	nick.add_theme_font_size_override("font_size", 28)
	var auth = get_node_or_null("/root/Auth")
	if auth and auth.has_method("get_display_name"):
		nick.text = str(auth.get_display_name()).substr(0, 18)
	box.add_child(nick)
	box.add_child(_label(T.t("birth_year"), 22, FG, 0, HORIZONTAL_ALIGNMENT_LEFT))
	var by := OptionButton.new()
	by.add_theme_font_size_override("font_size", 26)
	by.add_item("—", 0)
	var yr: int = Time.get_datetime_dict_from_system(true).year
	for i in 90:
		by.add_item(str(yr - 10 - i), yr - 10 - i)
	box.add_child(by)
	box.add_child(_label(T.t("birth_note"), 18, FG2, W - 80))
	box.add_child(_label(T.t("country"), 22, FG, 0, HORIZONTAL_ALIGNMENT_LEFT))
	var ctry := OptionButton.new()
	ctry.add_theme_font_size_override("font_size", 26)
	ctry.add_item("—")
	var codes: Array = T.data().get("COUNTRIES", []).duplicate()
	codes.append("XX")
	for c in codes:
		ctry.add_item(T.t("other") if c == "XX" else TranslationServer.get_country_name(c))
		ctry.set_item_metadata(ctry.item_count - 1, c)
	box.add_child(ctry)
	var prov_lab := _label(T.t("province"), 22, FG, 0, HORIZONTAL_ALIGNMENT_LEFT)
	var prov := OptionButton.new()
	prov.add_theme_font_size_override("font_size", 26)
	prov.add_item("—")
	for p in T.data().get("AR_PROV", []):
		prov.add_item(str(p))
	prov_lab.visible = false
	prov.visible = false
	ctry.item_selected.connect(func(i):
		var ar: bool = ctry.get_item_metadata(i) == "AR"
		prov_lab.visible = ar
		prov.visible = ar)
	box.add_child(prov_lab)
	box.add_child(prov)
	var err := _label(" ", 20, Color("#ff4f9a"), W - 80)
	box.add_child(err)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var later := _button(T.t("later"), _close_overlays, FG2, Vector2(0, 70), 26)
	later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(later)
	var save := _button(T.t("save"), func():
		var n := nick.text.strip_edges()
		if n.length() < 2:
			err.text = T.t("err_nick")
			return
		if by.selected <= 0:
			err.text = T.t("err_by")
			return
		var c = ctry.get_item_metadata(ctry.selected) if ctry.selected > 0 else "XX"
		var body := {"nick": n, "birth_year": by.get_item_id(by.selected), "country": c, "lang": T.lang()}
		if c == "AR" and prov.selected > 0:
			body.province = prov.get_item_text(prov.selected)
		_busy(true, "profile-save")
		api.call_fn("profile-save", body, _on_profile_saved), GOOD, Vector2(0, 70), 26)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(save)
	box.add_child(row)

func _on_profile_saved(ok: bool, _code: int, data: Dictionary) -> void:
	_busy(false)
	if not ok:
		_toast(_error_text(data))
		return
	_close_overlays()
	_toast(T.t("saved"))
	if not pending_start.is_empty():
		var cfg := pending_start
		pending_start = {}
		_request_start(cfg)

# ================================================================== START

func _start_from_setup() -> void:
	var iq_mode: bool = setup.mode == "iq"
	var cfg := {"mode": setup.mode, "kind": "normal", "scope": setup.scope, "dur": setup.dur if iq_mode else setup.bdur, "ranked": bool(setup.ranked), "lang": T.lang(), "gv": Items.GV}
	if not api.is_signed_in():
		_toast(tr("Sign in to take the IQ test: hub → ⚙ Options → Account. Scores are saved to your account."))
		return
	if iq_mode and setup.scope == "SELF":
		_show_prediction(cfg)
	else:
		_request_start(cfg)

## SELF: the player predicts their score before the first item (sent with session-start).
func _show_prediction(cfg: Dictionary) -> void:
	var box := _overlay()
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(_icon("SELF", 34))
	head.add_child(_label(" " + T.t("sec_SELF"), 24, T.sec_color("SELF")))
	box.add_child(head)
	box.add_child(_label(T.t("self_title"), 32, Color.WHITE))
	box.add_child(_label(T.t("self_ins"), 22, FG, W - 80))
	box.add_child(_label(T.t("prediction"), 22, FG2, W - 80))
	var out := _label("60%", 56, GOOD)
	box.add_child(out)
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 5
	sl.value = 60
	sl.custom_minimum_size = Vector2(0, 50)
	sl.value_changed.connect(func(v): out.text = "%d%%" % int(v))
	box.add_child(sl)
	box.add_child(_button(T.t("start_timer"), func():
		cfg.pred = sl.value / 100.0
		_close_overlays()
		_request_start(cfg), GOOD, Vector2(0, 80), 30))

func _request_start(cfg: Dictionary) -> void:
	pending_start = cfg
	_busy(true, "session-start")
	api.call_fn("session-start", cfg, _on_started)

func _on_started(ok: bool, code: int, data: Dictionary) -> void:
	_busy(false)
	if ok:
		pending_start = {}
		_begin_session(data)
		return
	var cfg := pending_start
	match str(data.get("error", "")):
		"no_profile":
			_show_profile_form()  # retried after saving (pending_start)
			return
		"not_eligible":
			pending_start = {}
			var box := _overlay()
			box.add_child(_label(T.t("why_" + str(data.get("why", ""))), 26, WARN, W - 80))
			box.add_child(_button(T.t("practice") + " ▶", func():
				_close_overlays()
				cfg.ranked = false
				_request_start(cfg), GOOD, Vector2(0, 72)))
			box.add_child(_button(T.t("home"), _close_overlays, FG2, Vector2(0, 64), 24))
			return
	pending_start = {}
	_toast(_error_text(data))

func _error_text(data: Dictionary) -> String:
	match str(data.get("error", "")):
		"signed_out", "unauthorized":
			return tr("Sign in to take the IQ test: hub → ⚙ Options → Account. Scores are saved to your account.")
		"offline":
			return tr("Couldn't reach the server. Check your connection and try again.")
	return tr("Something went wrong (%s). Try again.") % str(data.get("error", "?"))

func _busy(on: bool, fn := "") -> void:
	waiting = on
	if on:
		busy_fn = fn
		busy_since = Time.get_ticks_msec()
		busy_flagged = false
	else:
		if busy_flagged:
			_client_report("stall_end", {"fn": busy_fn, "waited_ms": Time.get_ticks_msec() - busy_since})
		busy_fn = ""
		busy_flagged = false
	var old := get_node_or_null("Busy")
	if old:
		# out of the tree first: a new "Busy" added this same frame (a skipped
		# musical question re-sends at once) would otherwise get an auto-name,
		# never be found again and leave "Loading" up for good
		remove_child(old)
		old.queue_free()
	if on:
		var dim := ColorRect.new()
		dim.name = "Busy"
		dim.color = Color(0, 0, 0, 0.45)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		var l := _label(T.t("loading"), 32, Color.WHITE)
		l.name = "Label"
		l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		dim.add_child(l)
		add_child(dim)
		move_child(dim, overlay_layer.get_index() + 1)

# ================================================================== RUNNER

func _begin_session(data: Dictionary) -> void:
	session = data
	seen = {}
	blitz_items = data.get("items", [])
	blitz_index = 0
	blitz_answers = []
	practice_log = []
	remaining_ms = float(data.get("dur_s", 300)) * 1000.0
	endless = not _is_blitz() and int(data.get("dur_s", 0)) == 0
	running = true
	paused = false
	_build_runner()
	_present(data.get("first_item", {}))

func _is_blitz() -> bool:
	return str(session.get("mode", "")) == "blitz"

## A practice test (not ranked, not a Daily Brain or Duel): the only kind that shows answers.
func _is_practice() -> bool:
	return not bool(session.get("ranked", false)) and str(session.get("kind", "normal")) == "normal"

func _build_runner() -> void:
	screen_name = "runner"
	var box := _new_page(true)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var meta := VBoxContainer.new()
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mode_text: String = T.t("blitz") if _is_blitz() else T.t("iqtest")
	meta.add_child(_label(mode_text + " · " + _sec_name(str(session.get("scope", "ALL"))), 22, FG, 0, HORIZONTAL_ALIGNMENT_LEFT))
	meta.add_child(_label(T.t("ranked") if session.get("ranked", false) else T.t("practice"), 18, GOOD if session.get("ranked", false) else FG2, 0, HORIZONTAL_ALIGNMENT_LEFT))
	bar.add_child(meta)
	clock_label = _label("0:00", 40, Color.WHITE)
	bar.add_child(clock_label)
	bar.add_child(_button("⏸", _pause_test, FG2, Vector2(64, 60), 26))
	bar.add_child(_button(tr("Finish") if endless else T.t("quit"), _confirm_quit, GOOD if endless else Color("#ff4f9a"), Vector2(110, 60), 24))
	box.add_child(bar)
	item_bar = ProgressBar.new()
	item_bar.show_percentage = false
	item_bar.custom_minimum_size = Vector2(0, 10)
	item_bar.max_value = 1.0
	box.add_child(item_bar)
	if _is_blitz():
		var brow := HBoxContainer.new()
		count_label = _label("", 24, FG2, 0, HORIZONTAL_ALIGNMENT_LEFT)
		count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(count_label)
		brow.add_child(_button(T.t("skip_2s"), _skip, WARN, Vector2(200, 56), 22))
		box.add_child(brow)
	qarea = VBoxContainer.new()
	qarea.add_theme_constant_override("separation", 12)
	box.add_child(qarea)
	_update_clock()

func _present(it: Dictionary) -> void:
	if not running:
		return
	item = it
	item_ms = 0.0
	item_timing = false
	for c in qarea.get_children():
		c.queue_free()
	view = null
	if count_label:
		count_label.text = "# %d" % (blitz_index + 1)
	var gid := str(it.get("gid", ""))
	if skip_music and str(it.get("sec", "")) == "MUS":
		_pass_music_item()
		return
	if not seen.has(gid):
		seen[gid] = true
		_show_instructions(it)
		return
	_mount_item()

func _mount_item() -> void:
	var sec := str(item.get("sec", "LOG"))
	var chip := HBoxContainer.new()
	chip.add_child(_icon(sec, 28))
	chip.add_child(_label(" " + T.t("sec_" + sec), 22, T.sec_color(sec)))
	qarea.add_child(chip)
	var gid := str(item.get("gid", ""))
	if gid in EXAMPLE_GIDS and not _is_blitz():
		chip.add_child(_spacer())
		chip.add_child(_button("💡 " + tr("Example"), _show_example.bind(gid), FG2, Vector2(170, 48), 20))  # a width, or the wrapping text squeezes it to a sliver
	elif sec == "MUS":
		chip.add_child(_spacer())
		chip.add_child(_button("🔇 " + tr("No sound?"), _no_sound, FG2, Vector2(200, 48), 20))
	view = Items.build(item, _is_blitz())
	view.submitted.connect(_on_item_submitted)
	view.timer_ready.connect(_on_item_ready)
	qarea.add_child(view)
	item_bar.visible = not endless and not bool(item.get("noTimerBar", false))
	item_bar.value = 1.0
	if not bool(item.get("deferTimer", false)):
		item_timing = true

func _on_item_ready() -> void:
	item_timing = true

## Untimed instructions before the first item of each type (the clock is paused);
## musical items add the headphone check.
func _show_instructions(it: Dictionary) -> void:
	paused = true
	var sec := str(it.get("sec", "LOG"))
	var gid := str(it.get("gid", ""))
	var box := _overlay()
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(_icon(sec, 34))
	head.add_child(_label(" " + T.t("sec_" + sec), 24, T.sec_color(sec)))
	box.add_child(head)
	box.add_child(_label(T.t("gt_" + gid), 34, Color.WHITE, W - 80))
	box.add_child(_label(T.t("ins_" + gid), 24, FG, W - 80))
	if sec == "MUS":
		box.add_child(_label(T.t("headphones"), 20, FG2, W - 80))
		var player := AudioStreamPlayer.new()
		player.stream = Audio.test_tone()
		box.add_child(player)
		box.add_child(_button("▶ " + T.t("test_tone"), player.play, T.sec_color("MUS"), Vector2(0, 64), 24))
		box.add_child(_button("🔇 " + tr("I can't play sound right now"), _no_sound, FG2, Vector2(0, 64), 22))
	if gid in EXAMPLE_GIDS:
		_add_example(box, gid)
	box.add_child(_label(T.t("clock_paused"), 18, FG2, W - 80))
	_pin_to_overlay(_button(T.t("start_timer"), func():
		_close_overlays()
		paused = false
		_mount_item(), GOOD, Vector2(0, 84), 30))

func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

# ------------------------------------------------------------------ examples

func _add_example(box: VBoxContainer, gid: String) -> void:
	var ex := _panel(T.sec_color("EXI"))
	ex.add_child(_label("💡 " + tr("Example"), 24, T.sec_color("EXI"), 0, HORIZONTAL_ALIGNMENT_LEFT))
	var lines: Array
	if T.more().get("en", {}).has("wx_" + gid):
		lines = Array(T.t("wx_" + gid).split("\n"))
	elif gid == "fallacy":
		lines = [
			tr("Don't judge whether you agree with the conclusion. Pick the description of the mistake in HOW the argument reasons."),
			tr("“Nobody has proven that ghosts don't exist, so they must exist.”  →  Not disproven, so it must be true."),
			tr("“My grandmother took this herb and got better, so it cures everyone.”  →  Generalizes from too few cases."),
		]
	else:
		lines = [
			tr("Forget the real world: the statements are the only facts. Picture each group as a circle. A conclusion is right only if it is true in EVERY way the circles could be drawn."),
			tr("“All poets are dreamers.” + “All dreamers are mortals.”  →  “All poets are mortals.” must be true."),
			tr("“No ghosts are mortals.” + “All poets are mortals.”  →  “No poets are ghosts.” must be true."),
			tr("“Some poets are ghosts.” + “Some ghosts are sages.”  →  nothing is guaranteed: the poets who are ghosts may not be the ghosts who are sages. Pick “None”."),
		]
	for l in lines:
		ex.add_child(_label(str(l), 21, FG, W - 120, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(_panel_of(ex))

## 💡 during a question: the example card, with the clock stopped.
func _show_example(gid: String) -> void:
	if not running or waiting or paused:
		return
	paused = true
	var box := _overlay()
	_add_example(box, gid)
	_pin_to_overlay(_button(tr("Back to the question"), _close_example, GOOD, Vector2(0, 76), 26))

func _close_example() -> void:
	_close_overlays()
	paused = false

# ------------------------------------------------------------------ no sound

## Musical questions need sound. In a mixed test they can be passed over for the
## rest of the test (each counts as unanswered, for the Musical section only);
## a Musical-only test can just end here.
func _no_sound() -> void:
	if not running or waiting or (view != null and view.done):
		return
	_close_overlays()
	paused = true
	var box := _overlay()
	box.add_child(_label("🔇 " + tr("No sound right now?"), 32, Color.WHITE))
	if str(session.get("scope", "")) == "MUS":
		box.add_child(_label(tr("This section is all musical questions, so it needs sound. End the test now and come back when you can listen."), 22, FG, W - 80))
	else:
		box.add_child(_label(tr("You can skip the musical questions for the rest of this test. Each one counts as unanswered for the Musical section only: your IQ score (Logic, Spatial and Verbal) isn't affected."), 22, FG, W - 80))
		box.add_child(_button(tr("Skip musical questions"), _start_skipping_music, GOOD, Vector2(0, 76), 26))
	box.add_child(_button(tr("End the test"), _end_from_no_sound, Color("#ff4f9a"), Vector2(0, 68), 24))
	box.add_child(_button(tr("Back"), _back_from_no_sound, FG2, Vector2(0, 64), 24))

func _start_skipping_music() -> void:
	skip_music = true
	_close_overlays()
	paused = false
	_pass_music_item()

func _end_from_no_sound() -> void:
	_close_overlays()
	paused = false
	_finish("time" if endless else "quit")

func _back_from_no_sound() -> void:
	_close_overlays()
	if view == null:
		_show_instructions(item)  # still before the first musical question
	else:
		paused = false

## Passes over the current musical question: Blitz skips it, the IQ test sends
## it as unanswered (null = the timer ran out; never scored as too fast).
func _pass_music_item() -> void:
	if view != null and not view.done:
		view.done = true
	_toast("🔇 " + tr("Musical question skipped"))
	if _is_blitz():
		blitz_answers.append({"seq": int(item.get("seq", 0)), "skip": true, "ms": int(round(item_ms))})
		blitz_index += 1
		var tw := create_tween()
		tw.tween_interval(0.14)
		tw.tween_callback(_next_blitz)
		return
	_send_answer({"seq": int(item.get("seq", 0)), "value": null, "ms": int(round(item_ms)), "skipped": true})

# ------------------------------------------------------------------ pause

## ⏸: the clock stops and the question is hidden until Continue. The card has
## the text size and sound settings, so they can be changed mid-test.
func _pause_test() -> void:
	if not running or waiting or paused:
		return
	paused = true
	qarea.visible = false
	_show_pause_card()

func _show_pause_card() -> void:
	_close_overlays()
	var box := _overlay()
	box.add_child(_label("⏸ " + tr("Paused"), 40, Color.WHITE))
	box.add_child(_label(tr("The clock is stopped and the question is hidden until you continue."), 21, FG2, W - 80))
	box.add_child(_button("▶ " + tr("Continue"), _resume_test, GOOD, Vector2(0, 84), 30))
	var settings = get_node_or_null("/root/Settings")
	if settings and "TEXT_SCALES" in settings and settings.has_method("set_text_size"):
		box.add_child(_label(tr("Text size"), 22, FG2, 0, HORIZONTAL_ALIGNMENT_LEFT))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var names: Array = settings.TEXT_SIZE_NAMES if "TEXT_SIZE_NAMES" in settings else ["Normal", "Large", "Extra large"]
		for i in names.size():
			var on: bool = int(settings.text_size) == i
			var b := _button(("✓ " if on else "") + tr(str(names[i])), _set_text_size.bind(i), GOOD if on else FG2, Vector2(0, 64), 20)
			if on:
				b.add_theme_stylebox_override("normal", Items.box_style(Color(GOOD, 0.22), GOOD, 3))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
		box.add_child(row)
	if settings and ResourceLoader.exists(SOUND_OPTIONS_PATH):
		box.add_child(_label("🔊 " + tr("Sound"), 22, FG2, 0, HORIZONTAL_ALIGNMENT_LEFT))
		box.add_child(load(SOUND_OPTIONS_PATH).new(settings.DARK if "DARK" in settings else settings.palette(), true))
	box.add_child(_button(tr("Finish") if endless else T.t("quit"), _quit_from_pause, Color("#ff4f9a"), Vector2(0, 64), 24))

func _set_text_size(i: int) -> void:
	var settings = get_node_or_null("/root/Settings")
	if settings == null:
		return
	settings.set_text_size(i)
	relayout_item = true
	# the screen is re-scaled first; then lay the card out at the new width
	call_deferred("_show_pause_card")

func _resume_test() -> void:
	_close_overlays()
	qarea.visible = true
	# Lay the question out again at the new text size -- unless it times itself
	# (memory sequences, audio, motor trials): rebuilding would replay it.
	if relayout_item and view != null and not view.done and not bool(item.get("deferTimer", false)):
		_fit_width()
		for c in qarea.get_children():
			c.queue_free()
		_mount_item()
	relayout_item = false
	paused = false

func _quit_from_pause() -> void:
	_close_overlays()
	qarea.visible = true
	paused = false
	_confirm_quit()

func _process(delta: float) -> void:
	if waiting:
		_watch_busy()
	# Prepper: practice time, not while ⏸ hides the question (a stalled frame counts 1 s at most)
	if running and _is_practice() and not (paused and is_instance_valid(qarea) and not qarea.visible):
		practice_pending += minf(delta, 1.0)
		if practice_pending >= 15.0:
			_flush_practice()
	if running and delta > 2.0:
		# the whole game stopped for over 2 s (a slow question to draw, a stuck browser tab)
		_client_report("hitch", {"frame_ms": int(delta * 1000.0), "fps": Engine.get_frames_per_second()})
	if not running or waiting or paused:
		return
	var ms := delta * 1000.0
	if not endless:
		remaining_ms -= ms
	if view != null and not view.done and item_timing:
		item_ms += ms
		var max_ms := float(item.get("maxMs", 60000))
		item_bar.value = clampf(1.0 - item_ms / max_ms, 0.0, 1.0)
		if item_ms > max_ms and not endless:  # ∞ has no per-question limit
			view.submit(null)
	_update_clock()
	if not endless and remaining_ms <= 0.0:
		_finish("time")

func _update_clock() -> void:
	if clock_label == null:
		return
	if endless:  # no clock: show how far the player has gone
		clock_label.text = "∞ #%d" % (int(item.get("seq", 0)) + 1)
		return
	var s := int(ceil(maxf(0.0, remaining_ms) / 1000.0))
	clock_label.text = "%d:%02d" % [s / 60, s % 60]
	clock_label.add_theme_color_override("font_color", Color("#ff4f9a") if remaining_ms < 10000 else Color.WHITE)

func _on_item_submitted(value) -> void:
	if not running:
		return
	var answer := {"seq": int(item.get("seq", 0)), "value": value, "ms": int(round(item_ms))}
	if _is_blitz():
		blitz_answers.append(answer)
		blitz_index += 1
		var tw := create_tween()
		tw.tween_interval(0.14)
		tw.tween_callback(_next_blitz)
		return
	# `value` is usually an int (option index): compare as text, or Godot stops
	# here with "Invalid operands" and the test froze after the first tap.
	# a "Will you remember?" trial already is a guess about yourself: no confidence after it
	if str(session.get("scope", "")) == "SELF" and str(value) != "__hidden" and str(item.get("gid", "")) != "recall":
		_ask_confidence(answer)
		return
	_send_answer(answer)

func _ask_confidence(answer: Dictionary) -> void:
	for c in qarea.get_children():
		c.queue_free()
	view = null
	qarea.add_child(_label(T.t("q_conf"), 30, FG, W))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var levels: Array = T.data().get("CONF_LEVELS", [0.25, 0.5, 0.75, 1])
	for i in levels.size():
		var b := _button("%s\n%d%%" % [T.t("conf_" + str(i)), int(round(float(levels[i]) * 100))], _on_confidence.bind(answer, float(levels[i])), T.sec_color("SELF"), Vector2((W - 10) / 2.0, 100), 26)
		grid.add_child(b)
	qarea.add_child(grid)

func _on_confidence(answer: Dictionary, conf: float) -> void:
	answer.conf = conf
	_send_answer(answer)

func _send_answer(answer: Dictionary) -> void:
	pending_answer = answer
	var body := {"session_id": session.get("session_id", ""), "seq": answer.seq, "value": answer.value, "client_ms": answer.ms}
	if answer.has("conf"):
		body.conf = answer.conf
	pending_body = body
	answer_inflight = 1
	_busy(true, "item-answer")
	api.call_fn("item-answer", body, _on_answered)

## The Loading overlay has waited STALL_MS: report it once, say we're still trying, and send an
## answer again (item-answer treats a resend as "give me the same next question"; the first
## request stays out, and whichever reply comes first is used).
func _watch_busy() -> void:
	if busy_flagged or Time.get_ticks_msec() - busy_since < STALL_MS:
		return
	busy_flagged = true
	_client_report("stall", {"fn": busy_fn, "waited_ms": Time.get_ticks_msec() - busy_since, "inflight": answer_inflight})
	var l := get_node_or_null("Busy/Label")
	if l is Label:
		l.text = tr("Still trying…")
	if busy_fn == "item-answer" and answer_inflight == 1 and not pending_body.is_empty():
		answer_inflight = 2
		api.call_fn("item-answer", pending_body, _on_answered)

## Sends a stall / hitch report to the server (client-report); one that can't go out is kept
## in user:// and tried again the next time the test opens. No names or tokens in it.
func _client_report(kind: String, extra := {}) -> void:
	if reports_sent >= 6:
		return
	reports_sent += 1
	var detail := {
		"scope": str(session.get("scope", "")), "mode": str(session.get("mode", "")), "ranked": bool(session.get("ranked", false)),
		"gid": str(item.get("gid", "")), "seq": int(item.get("seq", -1)), "d": int(item.get("d", 0)),
		"lang": T.lang(), "screen": screen_name, "running": running, "waiting": waiting, "paused": paused,
		"web": OS.has_feature("web"), "os": OS.get_name(), "gv": Items.GV, "fps": Engine.get_frames_per_second(),
		"mem_mb": int(OS.get_static_memory_usage() / 1048576.0),
	}
	detail.merge(extra, true)
	var consts: Dictionary = {}
	if ResourceLoader.exists("res://scripts/common/version.gd"):
		consts = load("res://scripts/common/version.gd").get_script_constant_map()
	detail.app = str(consts.get("VERSION", ""))
	var report := {"game": "voodoo_iq", "kind": kind, "build": int(consts.get("BUILD_NUMBER", 0)), "platform": OS.get_name() + (" web" if OS.has_feature("web") else ""), "detail": detail}
	_post_client_report(report)

func _post_client_report(report: Dictionary) -> void:
	api.call_fn("client-report", report, _on_client_report_sent.bind(report))

func _on_client_report_sent(ok: bool, _code: int, _data: Dictionary, report: Dictionary) -> void:
	if ok:
		return
	var kept = SaveUtil.read(REPORTS_PATH)
	var list: Array = kept.get("list", []) if kept is Dictionary else []
	if list.size() < 10:
		list.append(report)
		SaveUtil.write(REPORTS_PATH, {"list": list})

## Reports kept from an earlier stall (no connection then): send them now.
func _flush_reports() -> void:
	var kept = SaveUtil.read(REPORTS_PATH)
	if not (kept is Dictionary) or not api.is_signed_in():
		return
	SaveUtil.write(REPORTS_PATH, {"list": []})
	for r in kept.get("list", []):
		if r is Dictionary:
			_post_client_report(r)

func _on_answered(ok: bool, _code: int, data: Dictionary) -> void:
	# two answer requests can be out after the watchdog's resend: the first good reply wins,
	# a late one is ignored, and an error counts only once nothing else is still coming
	if answer_inflight <= 0:
		return
	answer_inflight -= 1
	if not ok and str(data.get("error", "")) != "session_over" and answer_inflight > 0:
		return
	answer_inflight = 0
	_busy(false)
	if not running:
		return
	if ok and data.get("done", false):
		_show_results(data.get("result", {}))
		return
	if ok:
		var fb = data.get("fb", null)
		if fb is Dictionary and _is_practice():
			var entry := {"item": item, "value": pending_answer.get("value"), "fb": fb, "skipped": bool(pending_answer.get("skipped", false)), "reported": ""}
			practice_log.append(entry)
			if not entry.skipped and int(fb.get("seq", -1)) == int(item.get("seq", -2)):
				_show_feedback(entry, data.get("next_item", {}))
				return
		_present(data.get("next_item", {}))
		return
	if str(data.get("error", "")) == "session_over":
		_show_results(data.get("result", {}))
		return
	# couldn't reach the server: try the same answer again, or quit
	var box := _overlay()
	box.add_child(_label(_error_text(data), 24, WARN, W - 80))
	box.add_child(_button(tr("Retry"), func():
		_close_overlays()
		_send_answer(pending_answer), GOOD))
	box.add_child(_button(T.t("quit_score"), func():
		_close_overlays()
		_finish("quit"), Color("#ff4f9a")))

func _next_blitz() -> void:
	if not running:
		return
	if blitz_index >= blitz_items.size():
		_finish("time")
		return
	_present(blitz_items[blitz_index])

## Blitz Skip: costs 2 s, not counted as an answer.
func _skip() -> void:
	if not running or waiting or paused or view == null or view.done:
		return
	view.done = true
	remaining_ms -= 2000.0
	blitz_answers.append({"seq": int(item.get("seq", 0)), "skip": true, "ms": int(round(item_ms))})
	blitz_index += 1
	_next_blitz()

func _finish_endless() -> void:
	_close_overlays()
	_finish("time")

## Quit (timed tests) or Finish (endless): confirm, then score what was answered.
func _confirm_quit() -> void:
	var box := _overlay()
	if endless:
		box.add_child(_label(tr("Finish the test?"), 34, Color.WHITE))
		box.add_child(_label(tr("You'll see your score now. Every answer you gave counts."), 22, FG, W - 80))
		box.add_child(_button(T.t("keep_going"), _close_overlays, FG2))
		box.add_child(_button(tr("See my score"), _finish_endless, GOOD))
		return
	box.add_child(_label(T.t("quit_q"), 34, Color.WHITE))
	box.add_child(_label(tr("This ranked test will be scored with the answers you gave.") if session.get("ranked", false) else T.t("quit_practice"), 22, FG, W - 80))
	box.add_child(_button(T.t("keep_going"), _close_overlays, GOOD))
	box.add_child(_button(T.t("quit_score"), func():
		_close_overlays()
		_finish("quit"), Color("#ff4f9a")))

## Leaving the app during an item voids it (scored wrong, counted as hidden).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		_flush_practice()
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if running and not paused and not waiting and view != null and not view.done:
			view.submit("__hidden")

func _finish(reason: String) -> void:
	if not running:
		return
	running = false
	finish_reason = reason
	_close_overlays()
	_busy(true, "blitz-submit" if _is_blitz() else "session-finish")
	if _is_blitz():
		api.call_fn("blitz-submit", {"session_id": session.get("session_id", ""), "answers": blitz_answers, "reason": reason}, _on_finished)
	else:
		api.call_fn("session-finish", {"session_id": session.get("session_id", ""), "reason": reason}, _on_finished)

func _on_finished(ok: bool, _code: int, data: Dictionary) -> void:
	_busy(false)
	var result = data.get("result", null)
	if ok and data.get("review", null) is Array and _is_practice():
		_log_blitz_review(data.review)
	if (ok or str(data.get("error", "")) == "session_over") and result is Dictionary:
		_show_results(result)
		return
	var box := _overlay()
	box.add_child(_label(_error_text(data), 24, WARN, W - 80))
	box.add_child(_button(tr("Retry"), func():
		_close_overlays()
		running = true
		_finish(finish_reason), GOOD))
	box.add_child(_button(T.t("home"), _show_home, FG2))

# ================================================================== PRACTICE ANSWERS
# Practice tests only (owner, 2026-10-25): right / wrong and the right answer after each
# answer, a review of every answer at the end, and 🚩 to report a question that looks
# wrong (item-report). Ranked tests show none of it; the server never sends them keys.

## The right / wrong card above the answered question; the clock waits for Next.
func _show_feedback(entry: Dictionary, next_item: Dictionary) -> void:
	paused = true
	if view == null or not is_instance_valid(view):
		# the Self test's confidence question replaced the view: draw it again
		for c in qarea.get_children():
			c.queue_free()
		view = _answer_view(entry)
		if view != null:
			qarea.add_child(view)
	else:
		Items.reveal(view, entry.fb, entry.value)
	var card := _answer_card(entry, view)
	var next := _button(tr("Next") + "  ▶", _after_feedback.bind(next_item), GOOD, Vector2(0, 76), 28)
	card.add_child(next)
	qarea.add_child(_panel_of(card))
	qarea.move_child(_panel_of(card), 0)
	var sc := _page_scroller()
	if sc:
		sc.scroll_vertical = 0

func _after_feedback(next_item: Dictionary) -> void:
	if not running or waiting:
		return
	paused = false
	_present(next_item)

## The question drawn again with its answer marked (null for motor trials and
## "Will you remember?", whose answer is a measurement: text only).
func _answer_view(entry: Dictionary):
	var it: Dictionary = entry.item
	var gid := str(it.get("gid", ""))
	if gid in Items.KIN_GIDS or gid == "recall":
		return null
	var v = Items.build(it, str(session.get("mode", "")) == "blitz")
	Items.reveal(v, entry.fb, entry.value)
	return v

func _right_count() -> int:
	var n := 0
	for e in practice_log:
		if int(e.fb.get("u", 0)) == 1:
			n += 1
	return n

func _entry_mark(entry: Dictionary) -> Array:
	if entry.skipped:
		return ["—", FG2, tr("Skipped")]
	if int(entry.fb.get("u", 0)) == 1:
		return ["✓", GOOD, tr("Correct!")]
	return ["✗", PINK, tr("Wrong answer")]

## Verdict, why it scored wrong, the right answer and what was given, and 🚩.
func _answer_card(entry: Dictionary, v) -> VBoxContainer:
	var m := _entry_mark(entry)
	var card := _panel(m[1])
	card.add_child(_label(m[0] + "  " + m[2], 34, m[1], 0, HORIZONTAL_ALIGNMENT_LEFT))
	for line in Items.answer_lines(v, entry.item, entry.fb, entry.value, entry.skipped):
		card.add_child(_label(str(line), 22, FG, W - 40, HORIZONTAL_ALIGNMENT_LEFT))
	# why the right answer is right, written by the server's generator (practice only)
	var why := str(entry.fb.get("why", ""))
	if why != "":
		var wb := _panel(Color(WARN, 0.6))
		wb.add_child(_label("💡 " + tr("Why"), 22, WARN, 0, HORIZONTAL_ALIGNMENT_LEFT))
		wb.add_child(_label(why, 22, FG, W - 80, HORIZONTAL_ALIGNMENT_LEFT))
		card.add_child(_panel_of(wb))
	var flag := _button(_flag_text(entry), _report.bind(entry), FG2, Vector2(0, 60), 22)
	flag.set_meta("seq", int(entry.fb.get("seq", -1)))
	flag.add_to_group("iq_flag")
	card.add_child(flag)
	return card

func _flag_text(entry: Dictionary) -> String:
	return "🚩 " + (tr("Reported. Thanks!") if str(entry.reported) != "" else tr("This question looks wrong"))

## 🚩: why it looks wrong, then item-report keeps this exact question for us to check.
func _report(entry: Dictionary) -> void:
	var box := _overlay()
	box.add_child(_label("🚩 " + tr("What looks wrong?"), 32, Color.WHITE, W - 80))
	box.add_child(_label(tr("We keep this exact question and your answer, and check it."), 21, FG2, W - 80))
	for w in [["none", tr("No answer is right")], ["two", tr("More than one answer is right")], ["picture", tr("The picture or sound is wrong")], ["other", tr("Something else")]]:
		box.add_child(_button(str(w[1]), _send_report.bind(entry, str(w[0])), WARN, Vector2(0, 68), 24))
	_pin_to_overlay(_button(tr("Cancel"), _close_overlays, FG2, Vector2(0, 64), 24))

func _send_report(entry: Dictionary, why: String) -> void:
	_close_overlays()
	var body := {"session_id": session.get("session_id", ""), "seq": int(entry.fb.get("seq", -1)), "why": why, "value": entry.value, "display": entry.item.get("display", {})}
	api.call_fn("item-report", body, _on_reported.bind(entry, why))

func _on_reported(ok: bool, _code: int, data: Dictionary, entry: Dictionary, why: String) -> void:
	if not ok:
		_toast(_error_text(data))
		return
	entry.reported = why
	_toast("🚩 " + tr("Thanks! We'll check this question."))
	for b in get_tree().get_nodes_in_group("iq_flag"):
		if is_instance_valid(b) and int(b.get_meta("seq", -2)) == int(entry.fb.get("seq", -1)):
			b.text = _flag_text(entry)

## A practice Speed Round: the server's review rows, matched to the items and answers here.
func _log_blitz_review(rows: Array) -> void:
	practice_log = []
	var by_seq := {}
	for it in blitz_items:
		by_seq[int(it.get("seq", -1))] = it
	var given := {}
	for a in blitz_answers:
		given[int(a.get("seq", -1))] = a
	for r in rows:
		if not (r is Dictionary) or not by_seq.has(int(r.get("seq", -1))):
			continue
		var seq := int(r.seq)
		var a: Dictionary = given.get(seq, {})
		practice_log.append({"item": by_seq[seq], "value": a.get("value"), "fb": r, "skipped": false, "reported": ""})

func _open_review() -> void:
	review_scroll = 0
	_show_review()

## Every answer of the practice test, newest last; tap one to see it again.
func _show_review() -> void:
	screen_name = "review"
	_close_overlays()
	var box := _new_page(true)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_button("← " + tr("Back"), _show_results.bind(last_result), FG2, Vector2(130, 60), 24))
	top.add_child(_spacer())
	top.add_child(_button("🏠 " + T.t("home"), _show_home, FG2, Vector2(150, 60), 24))
	box.add_child(top)
	box.add_child(_neon_title(tr("Review answers"), 40))
	box.add_child(_label(tr("%d of %d right. Tap a question to see it again with the right answer.") % [_right_count(), practice_log.size()], 22, FG2, W))
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 10)
	for opt in [[false, tr("All answers")], [true, tr("Wrong only")]]:
		var on: bool = review_wrong_only == opt[0]
		var b := _button(("✓ " if on else "") + str(opt[1]), _set_review_filter.bind(opt[0]), GOOD if on else FG2, Vector2(0, 60), 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.add_child(b)
	box.add_child(seg)
	var shown := 0
	for i in practice_log.size():
		var e: Dictionary = practice_log[i]
		if review_wrong_only and int(e.fb.get("u", 0)) == 1:
			continue
		shown += 1
		var it: Dictionary = e.item
		var m := _entry_mark(e)
		var text := "%s   #%d   %s · %s" % [m[0], i + 1, T.t("sec_" + str(it.get("sec", ""))), T.t("gt_" + str(it.get("gid", "")))]
		if str(e.reported) != "":
			text += "   🚩"
		var b := _button(text, _open_review_item.bind(i), m[1], Vector2(0, 64), 22)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(b)
	if shown == 0:
		box.add_child(_label(tr("No wrong answers. Well done!"), 24, GOOD, W))
	_restore_scroll(review_scroll)

func _set_review_filter(wrong_only: bool) -> void:
	review_wrong_only = wrong_only
	review_scroll = 0
	_show_review()

func _open_review_item(i: int) -> void:
	var sc := _page_scroller()
	review_scroll = sc.scroll_vertical if sc else 0
	_show_review_item(i)

## One answer of the review: the question drawn again with its answer marked.
func _show_review_item(i: int) -> void:
	if practice_log.is_empty():
		_show_results(last_result)
		return
	i = clampi(i, 0, practice_log.size() - 1)
	screen_name = "review_item"
	review_index = i
	_close_overlays()
	var box := _new_page(true)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_button("← " + tr("All answers"), _show_review, FG2, Vector2(240, 60), 22))
	top.add_child(_spacer())
	top.add_child(_button("🏠 " + T.t("home"), _show_home, FG2, Vector2(150, 60), 24))
	box.add_child(top)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	var prev := _button("‹ " + tr("Previous"), _show_review_item.bind(i - 1), FG2, Vector2(0, 60), 22)
	prev.disabled = i == 0
	prev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(prev)
	nav.add_child(_label("%d / %d" % [i + 1, practice_log.size()], 24, FG))
	var nxt := _button(tr("Next") + " ›", _show_review_item.bind(i + 1), FG2, Vector2(0, 60), 22)
	nxt.disabled = i == practice_log.size() - 1
	nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(nxt)
	box.add_child(nav)
	var e: Dictionary = practice_log[i]
	var sec := str(e.item.get("sec", "LOG"))
	var chip := HBoxContainer.new()
	chip.add_child(_icon(sec, 28))
	chip.add_child(_label(" " + T.t("sec_" + sec) + " · " + T.t("gt_" + str(e.item.get("gid", ""))), 22, T.sec_color(sec)))
	box.add_child(chip)
	var v = _answer_view(e)
	box.add_child(_panel_of(_answer_card(e, v)))
	if v != null:
		box.add_child(v)

# ================================================================== RESULTS

func _show_results(res: Dictionary) -> void:
	screen_name = "results"
	# a redraw (screen resized) shows the same result: record it and celebrate only once
	fresh_result = res != last_result
	last_result = res
	running = false
	view = null
	_close_overlays()
	var blitz := bool(res.get("blitz", false))
	if info and fresh_result:
		info.add("Blitz runs" if blitz else "Tests taken")
		if blitz:
			info.high("Best Blitz points", float(res.get("pts", 0.0)))
	_flush_practice()
	if fresh_result and not blitz and bool(res.get("ranked", false)) and res.get("secs") is Dictionary:
		_check_awards(res.secs.keys(), false)  # this test may have earned a genius medal
	var box := _new_page(true)
	box.add_child(_neon_title(T.t("your_result"), 44))
	var sub := (T.t("blitz") if blitz else T.t("iqtest")) + " · " + _sec_name(str(res.get("scope", session.get("scope", "ALL"))))
	sub += " · " + (T.t("ranked") if res.get("ranked", false) else T.t("practice"))
	if str(res.get("reason", "")) == "quit":
		sub += " · " + T.t("ended_early")
	box.add_child(_label(sub, 22, FG2, W))
	if blitz:
		_blitz_results(box, res)
	else:
		_iq_results(box, res)
	if not practice_log.is_empty() and not bool(res.get("ranked", false)):
		box.add_child(_button("📝 " + tr("Review answers") + "
" + tr("%d of %d right · see the right answers") % [_right_count(), practice_log.size()], _open_review, ACCENT, Vector2(0, 92), 26))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var again := _button(T.t("play_again"), _start_from_setup, GOOD, Vector2(0, 80), 28)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(again)
	var home := _button(T.t("home"), _show_home, FG2, Vector2(0, 80), 28)
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(home)
	box.add_child(row)
	box.add_child(_button("🏆 " + T.t("nav_boards"), _show_boards, WARN, Vector2(0, 72), 26))
	box.add_child(_button(T.info("button"), _show_info.bind(_show_results.bind(res)), ACCENT, Vector2(0, 68), 24))

func _stat(parent: Container, lab: String, value: String) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_label(value, 34, Color.WHITE))
	col.add_child(_label(lab, 18, FG2))
	parent.add_child(col)

func _blitz_results(box: VBoxContainer, res: Dictionary) -> void:
	var p := _panel(ACCENT)
	var big := HBoxContainer.new()
	_stat(big, T.t("correct"), str(int(res.get("correct", 0))))
	_stat(big, T.t("points"), "%.1f" % float(res.get("pts", 0.0)))
	p.add_child(big)
	var facts := HBoxContainer.new()
	_stat(facts, T.t("wrong"), str(int(res.get("wrong", 0))))
	_stat(facts, T.t("skipped"), str(int(res.get("skipped", 0))))
	_stat(facts, T.t("accuracy"), "%d%%" % int(round(float(res.get("acc", 0.0)) * 100)))
	p.add_child(facts)
	if res.get("best", false):
		p.add_child(_label("★ " + T.t("new_best"), 26, GOOD))
		if info and fresh_result:
			info.celebrate(T.t("new_best"))
	elif res.get("monthBest", false):
		p.add_child(_label("★ " + T.t("month_best"), 26, GOOD))
	if res.get("flagged", false):
		p.add_child(_label("⚠ " + T.t("flagged"), 20, WARN, W - 40))
	p.add_child(_label(T.t("blitz_scoring"), 18, FG2, W - 40))
	box.add_child(_panel_of(p))

func _range_text(r: Dictionary) -> Array:
	var th := float(r.get("theta", 0.0))
	var se := float(r.get("se", 1.0))
	return [int(round(clampf(T.iq(th - 1.96 * se), 40, 160))), int(round(clampf(T.iq(th + 1.96 * se), 40, 160)))]

func _iq_results(box: VBoxContainer, res: Dictionary) -> void:
	var secs: Dictionary = res.get("secs", {})
	var flags: Dictionary = res.get("flags", {})
	if secs.size() > 1:
		if res.get("composite", null) is Dictionary:
			box.add_child(_score_card("VIQ", res.composite, true))
		var tp := _panel()
		tp.add_child(_label(T.t("by_section"), 28, Color.WHITE))
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 14)
		for h in [T.t("section"), T.t("estimate"), T.t("range_short"), T.t("items"), T.t("accuracy")]:
			grid.add_child(_label(h, 18, FG2))
		for s in T.secs():
			if not secs.has(s):
				continue
			var r: Dictionary = secs[s]
			var rg := _range_text(r)
			var name_row := HBoxContainer.new()
			name_row.add_child(_icon(s, 22))
			name_row.add_child(_label(" " + T.t("short_" + s), 20, T.sec_color(s)))
			grid.add_child(name_row)
			grid.add_child(_label(T.fmt_iq(float(r.theta)), 22, Color.WHITE))
			grid.add_child(_label("%d–%d" % rg, 20, FG))
			grid.add_child(_label(str(int(r.n)), 20, FG))
			grid.add_child(_label("%d%%" % int(round(float(r.acc) * 100)), 20, FG))
		tp.add_child(grid)
		tp.add_child(_label(T.t("mixed_note"), 18, FG2, W - 40))
		box.add_child(_panel_of(tp))
	else:
		for s in secs:
			box.add_child(_score_card(s, secs[s], false))
	if res.get("flagged", false):
		box.add_child(_label("⚠ " + T.t("flagged"), 22, WARN, W))
	if int(flags.get("rapid", 0)):
		box.add_child(_label(T.t("rapid_note", {"n": int(flags.rapid)}), 19, FG2, W))
	if int(flags.get("hidden", 0)):
		box.add_child(_label(T.t("hidden_note", {"n": int(flags.hidden)}), 19, FG2, W))
	var wp := _panel()
	var body := _label(T.t("why_50_body"), 20, FG, W - 40, HORIZONTAL_ALIGNMENT_LEFT)
	body.visible = false
	wp.add_child(_button(T.t("why_50"), func(): body.visible = not body.visible, FG2, Vector2(0, 60), 22))
	wp.add_child(body)
	box.add_child(_panel_of(wp))
	if res.get("viq", null) is Dictionary:
		box.add_child(_verify_list(res.viq))

func _score_card(sec: String, r: Dictionary, composite: bool) -> Control:
	var col := ACCENT if composite else T.sec_color(sec)
	var p := _panel(col)
	var head := HBoxContainer.new()
	if not composite:
		head.add_child(_icon(sec, 30))
	head.add_child(_label(" " + (T.t("session_viq") if composite else T.t("sec_" + sec)), 26, col))
	if r.has("n"):
		var n := _label(T.t("n_items", {"n": int(r.n)}), 18, FG2)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(n)
	p.add_child(head)
	var th := float(r.get("theta", 0.0))
	var se := float(r.get("se", 1.0))
	var rg := _range_text(r)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	line.add_child(_neon_title(T.fmt_iq(th), 72))
	var facts := VBoxContainer.new()
	facts.add_child(_label(T.t("range", {"lo": rg[0], "hi": rg[1]}), 22, FG, 0, HORIZONTAL_ALIGNMENT_LEFT))
	facts.add_child(_label(T.band_label(T.iq(th)), 22, col, 0, HORIZONTAL_ALIGNMENT_LEFT))
	facts.add_child(_label(T.t("percentile", {"p": int(round(T.norm_cdf(th) * 100))}), 18, FG2, 420, HORIZONTAL_ALIGNMENT_LEFT))
	line.add_child(facts)
	p.add_child(line)
	p.add_child(Art.canvas(func(ci, sz): Art.bell(ci, Rect2(Vector2.ZERO, sz), th, se, col, FG, FG2), Vector2(W - 40, (W - 40) * 230.0 / 640.0)))
	if composite:
		p.add_child(_label(T.t("session_viq_note"), 18, FG2, W - 40))
		return _panel_of(p)
	var stats := HBoxContainer.new()
	var maxd := int(r.get("maxd", 0))
	_stat(stats, T.t("level"), ("%d/10" % maxd) if maxd else "—")
	_stat(stats, T.t("accuracy"), "%d%%" % int(round(float(r.get("acc", 0.0)) * 100)))
	_stat(stats, T.t("hard_right"), str(int(r.get("hard", 0))))
	p.add_child(stats)
	if sec == "SELF" and r.get("auc", null) != null:
		var bias := float(r.get("bias", 0.0))
		p.add_child(_label(T.t("self_auc", {"p": int(round(float(r.auc) * 100))}), 20, FG, W - 40))
		var cal := T.t("self_calibrated") if absf(bias) < 0.05 else (T.t("self_over", {"p": int(round(bias * 100))}) if bias > 0 else T.t("self_under", {"p": int(round(-bias * 100))}))
		p.add_child(_label(cal, 20, FG, W - 40))
		if r.get("predErr", null) != null:
			p.add_child(_label(T.t("self_pred", {"a": int(round(float(r.pred) * 100)), "b": int(round(float(r.acc) * 100))}), 20, FG, W - 40))
		if not r.get("valid", false):
			p.add_child(_label(T.t("self_invalid"), 20, WARN, W - 40))
	if sec == "SELF" and int(r.get("recallN", 0)) > 0:  # "Will you remember?" trials (gv 8)
		var rb := float(r.get("recallBias", 0.0))
		p.add_child(_label(T.t("self_recall", {"n": int(r.recallN), "p": int(round(float(r.get("recallErr", 0.0)) * 100))}), 20, FG, W - 40))
		p.add_child(_label(T.t("self_recall_ok") if absf(rb) < 0.05 else T.t("self_recall_over" if rb > 0 else "self_recall_under"), 20, FG, W - 40))
	if r.get("misfit", false):
		p.add_child(_label("⚠ " + T.t("misfit"), 20, WARN, W - 40))
	var n := int(r.get("n", 0))
	if n < T.gate("minItems") or se > T.gate("seBoard"):
		p.add_child(_label(T.t("provisional_session", {"n": maxi(0, int(T.gate("minItems")) - n)}), 18, FG2, W - 40))
	return _panel_of(p)

func _verify_list(v: Dictionary) -> Control:
	var p := _panel(ACCENT)
	p.add_child(_label(T.t("viq_status"), 28, Color.WHITE))
	var checks: Dictionary = v.get("checks", {})
	var rows: Array = []
	for c in checks.get("secs", []):
		var se = c.get("se", null)
		rows.append([bool(c.ok), T.t("chk_sec", {"s": T.t("sec_" + str(c.sec)), "n": int(c.get("n", 0)), "se": int(round(15 * float(se))) if se != null else "—"})])
	rows.append([bool(checks.get("days", false)), T.t("chk_days")])
	rows.append([bool(checks.get("consistent", false)), T.t("chk_consistent")])
	var verified := bool(v.get("verified", false))
	rows.append([verified, T.t("chk_verified") if verified else T.t("chk_unverified")])
	for r in rows:
		p.add_child(_label(("✓  " if r[0] else "○  ") + r[1], 20, GOOD if r[0] else FG, W - 40, HORIZONTAL_ALIGNMENT_LEFT))
	return _panel_of(p)

# ================================================================== LEADERBOARDS

const AGE_BANDS := ["16-24", "25-34", "35-44", "45-54", "55+"]
const BOARD_TABS := [["viq", "b_viq"], ["nine", "b_nine"], ["sec", "b_sec"], ["blitz", "blitz"]]

## Board settings, like the prototype's S.boards (kept while the scene lives).
var boards := {"tab": "viq", "sec": "LOG", "bscope": "ALL", "bdur": 120, "season": "month", "age": "", "country": "", "province": "", "lang": "", "show_prov": false, "show_help": false, "show_filters": false}
var board_box: VBoxContainer

func _show_boards() -> void:
	screen_name = "boards"
	running = false
	_close_overlays()
	var box := _new_page(true)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_button("◀", _show_home, FG2, Vector2(70, 60), 26))
	var title := _neon_title("🏆 " + T.t("nav_boards"), 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	box.add_child(top)
	# board tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for tb in BOARD_TABS:
		tabs.add_child(_seg_button(T.t(tb[1]), "tab", tb[0]))
	box.add_child(tabs)
	if boards.tab == "sec":
		box.add_child(_board_chips("sec", T.secs()))
	elif boards.tab == "blitz":
		var scopes: Array = ["ALL"]
		for s in T.secs():
			if s != "SELF":
				scopes.append(s)
		box.add_child(_board_chips("bscope", scopes))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for dv in T.data().get("BLITZ_DURS", []):
			var d := int(dv)
			row.add_child(_seg_button("%d min" % (d / 60), "bdur", d))
		box.add_child(row)
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 6)
		row2.add_child(_seg_button(T.t("this_month"), "season", "month"))
		row2.add_child(_seg_button(T.t("all_time"), "season", "all"))
		box.add_child(row2)
	# filters: age, country, province (Argentina), verbal language
	var filters := GridContainer.new()
	filters.columns = 2
	filters.add_theme_constant_override("h_separation", 10)
	filters.add_theme_constant_override("v_separation", 6)
	var ages: Array = [["", T.t("any")]]
	for a in AGE_BANDS:
		ages.append([a, a])
	_board_filter(filters, T.t("age"), "age", ages)
	var countries: Array = [["", T.t("world")]]
	for c in T.data().get("COUNTRIES", []):
		countries.append([c, TranslationServer.get_country_name(c)])
	_board_filter(filters, T.t("country"), "country", countries)
	if boards.country == "AR":
		var provs: Array = [["", T.t("all_provinces")]]
		for pv in T.data().get("AR_PROV", []):
			provs.append([pv, pv])
		_board_filter(filters, T.t("province"), "province", provs)
	if boards.tab == "viq" or (boards.tab == "sec" and boards.sec == "LIN"):
		_board_filter(filters, T.t("verbal_lang"), "lang", [["", T.t("any")], ["es", "Español"], ["en", "English"]])
	# closed by default: the four dropdowns were most of the screen (the count says what is on)
	var active := 0
	for fk in ["age", "country", "province"]:
		if str(boards[fk]) != "":
			active += 1
	if (boards.tab == "viq" or (boards.tab == "sec" and boards.sec == "LIN")) and str(boards.lang) != "":
		active += 1
	filters.visible = bool(boards.show_filters)
	var ftext := "🔎 " + (tr("Filters (%d)") % active if active > 0 else tr("Filters"))
	box.add_child(_button(ftext, _toggle_filters.bind(filters), WARN if active > 0 else FG2, Vector2(0, 56), 20))
	box.add_child(filters)
	var bnote: String = T.t("bnote_" + str(boards.tab))
	if boards.tab == "viq":
		bnote = tr("Logic + Spatial + Verbal combined, highest first. Everyone with all three is shown; ✓ = verified (sessions on 2 days that agree).")
	elif boards.tab == "sec":
		bnote = tr("Your last 3 ranked tests in this section (90 days), highest first. ✓ = enough questions for a tight ±.")
	box.add_child(_label(bnote, 18, FG2, W, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(_board_help())
	board_box = VBoxContainer.new()
	board_box.add_theme_constant_override("separation", 10)
	board_box.add_child(_label(T.t("loading"), 24, FG2, W))
	box.add_child(board_box)
	var req := {"board": boards.tab, "age": boards.age, "country": boards.country, "province": boards.province, "lang": boards.lang}
	if boards.tab == "sec":
		req.sec = boards.sec
	if boards.tab == "blitz":
		req.scope = boards.bscope
		req.dur_s = boards.bdur
		req.season = boards.season
	api.call_fn("leaderboard", req, _on_board)

func _set_board(key: String, value) -> void:
	boards[key] = value
	if key == "country":
		boards.province = ""
	_show_boards()

func _seg_button(text: String, key: String, value) -> Button:
	var on: bool = boards[key] == value
	var b := _button(text, _set_board.bind(key, value), GOOD if on else FG2, Vector2(0, 56), 20)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if on:
		b.add_theme_stylebox_override("normal", Items.box_style(Color(GOOD, 0.22), GOOD, 3))
	return b

func _board_chips(key: String, secs: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for s in secs:
		var col := Color.WHITE if s == "ALL" else T.sec_color(s)
		var b := _button(T.t("short_all") if s == "ALL" else T.t("short_" + s), _set_board.bind(key, s), col, Vector2((W - 12) / 3.0, 54), 19)
		if boards[key] == s:
			b.add_theme_stylebox_override("normal", Items.box_style(Color(col, 0.28), col, 3))
		grid.add_child(b)
	return grid

func _board_filter(grid: GridContainer, label: String, key: String, options: Array) -> void:
	grid.add_child(_label(label, 20, FG2, 0, HORIZONTAL_ALIGNMENT_LEFT))
	var ob := OptionButton.new()
	ob.add_theme_font_size_override("font_size", 20)
	ob.custom_minimum_size = Vector2(W * 0.6, 50)
	for i in options.size():
		ob.add_item(str(options[i][1]))
		ob.set_item_metadata(i, options[i][0])
		if options[i][0] == boards[key]:
			ob.select(i)
	ob.item_selected.connect(_on_filter_picked.bind(ob, key))
	grid.add_child(ob)

func _on_filter_picked(i: int, ob: OptionButton, key: String) -> void:
	_set_board(key, ob.get_item_metadata(i))

func _on_board(ok: bool, _code: int, data: Dictionary) -> void:
	if board_box == null or not is_instance_valid(board_box):
		return
	for c in board_box.get_children():
		c.queue_free()
	if not ok:
		board_box.add_child(_label(_error_text(data), 22, WARN, W))
		return
	var ranked: Array = data.get("rows", [])
	var prov: Array = data.get("provisional", [])
	if boards.tab == "sec":
		for r in ranked:
			if r is Dictionary and r.get("me", false) and r.get("genius", false) and float(r.get("score", 0.0)) >= 130.0:
				Awards.pay("genius_" + str(boards.sec))
	if ranked.is_empty():
		board_box.add_child(_label(T.t("board_empty"), 24, FG, W))
	else:
		board_box.add_child(_board_table(ranked, false))
	if not prov.is_empty():
		var tp := _board_table(prov, true)
		tp.visible = bool(boards.show_prov)
		board_box.add_child(_button(T.t("provisional_n", {"n": prov.size()}), _toggle_prov.bind(tp), FG2, Vector2(0, 60), 20))
		board_box.add_child(tp)

func _toggle_prov(tp: Control) -> void:
	boards.show_prov = not tp.visible
	tp.visible = boards.show_prov

## Closed by default (the screen is busy enough): what the ± and the ★130+ medal on the rows mean.
func _board_help() -> Control:
	var hp := _panel()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.visible = bool(boards.show_help)
	hp.add_child(_button("ℹ️ " + tr("What do ± and ★130+ mean?"), _toggle_board_help.bind(body), FG2, Vector2(0, 60), 20))
	hp.add_child(body)
	body.add_child(_label("± " + tr("The margin of error"), 24, ACCENT, W - 40, HORIZONTAL_ALIGNMENT_LEFT))
	body.add_child(_info_text(tr("A score is an estimate, not an exact number. Example: IQ 115 ±5.\n• We are 68% sure your real IQ is between 110 and 120 (115 ±5).\n• We are 95% sure it is between 105 and 125 (115 ±10)."), FG))
	body.add_child(Art.canvas(func(ci, sz): Art.bell(ci, Rect2(Vector2.ZERO, sz), 1.0, 5.0 / 15.0, ACCENT, FG, FG2, 1.0, "115 ±5"), Vector2(W - 40, (W - 40) * 230.0 / 640.0)))
	body.add_child(_info_text(tr("Few questions give a wide ±, more questions a tighter one. A gap between two players smaller than the ± is not a real difference."), FG))
	body.add_child(_info_text(tr("✓ = enough evidence: at least 15 questions and a ± of 6.75 or less in a section. For Voodoo IQ: a ± of 6 or less in each of Logic, Spatial and Verbal, on 2 different days that agree."), FG2, 18))
	body.add_child(_label("★130+ " + tr("The genius medal"), 24, WARN, W - 40, HORIZONTAL_ALIGNMENT_LEFT))
	body.add_child(_info_text(tr("Only about 2 people in 100 reach 130. The medal is given for a 130+ score with proof it is not luck: a very tight ± (4.5 or less) and at least 3 very hard questions answered right in that section (Voodoo IQ: at least 2 in each of Logic, Spatial and Verbal)."), FG))
	body.add_child(_info_text(tr("A 130+ score with a wider ± still shows its number, just without the medal. Self needs 40+ questions instead of the hard ones; 9-Mind needs only the tight ±."), FG2, 18))
	return _panel_of(hp)

func _toggle_filters(filters: Control) -> void:
	boards.show_filters = not filters.visible
	filters.visible = boards.show_filters

func _toggle_board_help(body: Control) -> void:
	boards.show_help = not body.visible
	body.visible = boards.show_help

## The prototype's boardTable: # | player (+ you / 130+, place · age) | rank score,
## points or status | estimate ± or correct answers.
func _board_table(rows: Array, prov: bool) -> Control:
	var p := _panel(Color("#2A2A3E") if prov else ACCENT)
	var blitz: bool = boards.tab == "blitz"
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	var name_w := maxf(140.0, W - 300.0)
	for h in ["#", T.t("player"), T.t("points") if blitz else (T.t("status") if prov else "IQ"), T.t("correct") if blitz else T.t("status")]:
		grid.add_child(_label(h, 17, FG2))
	for i in rows.size():
		var r: Dictionary = rows[i]
		var me := bool(r.get("me", false))
		var col := GOOD if me else Color.WHITE
		grid.add_child(_label("–" if prov else str(i + 1), 22, col))
		var who := VBoxContainer.new()
		var nick := str(r.get("nick", "—"))
		if me:
			nick += "  (" + T.t("you") + ")"
		# the medal is for 130+ (the server checks it too; Voodoo IQ and 9-Mind rows came without that check)
		if r.get("genius", false) and float(r.get("score", 0.0)) >= 130.0:
			nick += "  ★130+"
		var nick_btn := Button.new()
		nick_btn.text = nick
		nick_btn.flat = true
		nick_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nick_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nick_btn.custom_minimum_size = Vector2(name_w, 0)
		nick_btn.add_theme_font_size_override("font_size", 22)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			nick_btn.add_theme_color_override(c, col)
		if not str(r.get("nick", "")) == "":
			nick_btn.pressed.connect(_show_player.bind(str(r.get("nick", ""))))
		who.add_child(nick_btn)
		var loc: Array = []
		for k in ["country", "province", "age_band"]:
			var v = r.get(k, null)
			if v != null and str(v) != "" and str(v) != "XX":
				loc.append(str(v))
		if not loc.is_empty():
			who.add_child(_label(" · ".join(loc), 16, FG2, name_w, HORIZONTAL_ALIGNMENT_LEFT))
		grid.add_child(who)
		var main := ""
		if blitz:
			main = "%.1f" % float(r.get("score", 0.0))
		elif prov:
			if r.has("sections"):
				main = "%d/9" % int(r.sections)
			elif int(r.get("need_items", 0)) > 0:
				main = T.t("need_items", {"n": int(r.need_items)})
			elif r.has("need_items"):
				main = T.t("need_precision")
			else:
				main = T.t("provisional")
		else:
			main = str(int(round(float(r.get("score", 0.0)))))
		grid.add_child(_label(main, 16 if prov else 24, col, 110.0 if prov else 0.0))
		var est := "—"
		if blitz:
			est = str(int(r.get("correct", 0)))
		elif r.get("theta", null) != null:
			est = "±%d" % int(round(15 * float(r.get("se", 0.0))))
			if r.get("verified", false):
				est += "  ✓"
			elif int(r.get("need_items", 0)) > 0:
				est += "\n" + T.t("need_items", {"n": int(r.need_items)})
		grid.add_child(_label(est, 18, GOOD if r.get("verified", false) else FG, 0.0 if blitz else 130.0))
	p.add_child(grid)
	return _panel_of(p)

# ------------------------------------------------------------------ player card

## Tap a name on a board: that player's answers, accuracy and pace (leaderboard "player").
func _show_player(nick: String) -> void:
	var box := _overlay()
	box.add_child(_label(nick, 34, Color.WHITE, W - 80))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.add_child(_label("…", 24, FG2))
	box.add_child(body)
	_pin_to_overlay(_button(tr("Close"), _close_overlays, FG2, Vector2(0, 68), 26))
	api.call_fn("leaderboard", {"board": "player", "nick": nick}, _on_player.bind(body))

func _on_player(ok: bool, _code: int, data: Dictionary, body: VBoxContainer) -> void:
	if not is_instance_valid(body):
		return
	for c in body.get_children():
		c.queue_free()
	if not ok:
		var msg := tr("Player not found.") if str(data.get("error", "")) == "no_player" else _error_text(data)
		body.add_child(_label(msg, 22, WARN, W - 80))
		return
	var loc: Array = []
	for k in ["country", "province", "age_band"]:
		var v = data.get(k, null)
		if v != null and str(v) != "" and str(v) != "XX":
			loc.append(str(v))
	if not loc.is_empty():
		body.add_child(_label(" · ".join(loc), 20, FG2, W - 80))
	if data.get("iq", null) != null:
		body.add_child(_label("IQ %d  ±%d" % [int(data.iq), int(round(15 * float(data.get("se", 0.0))))], 40, GOOD, W - 80))
	var answered := int(data.get("answered", 0))
	if answered == 0:
		body.add_child(_label(tr("No ranked answers yet."), 22, FG2, W - 80))
	else:
		_stat(body, tr("Ranked tests"), str(int(data.get("tests", 0))))
		_stat(body, tr("Questions answered"), str(answered))
		_stat(body, tr("Correct"), "%d  (%d%%)" % [int(data.get("correct", 0)), int(round(100.0 * float(data.get("pct", 0.0))))])
		_stat(body, tr("Correct answers per minute"), "%.1f" % float(data.get("per_min", 0.0)))
		_stat(body, tr("Average seconds per question"), "%.1f" % float(data.get("avg_s", 0.0)))
	var secs: Array = data.get("sections", [])
	if not secs.is_empty():
		body.add_child(_label(tr("By section"), 24, Color.WHITE, W - 80))
		for r in secs:
			var sec := str(r.get("sec", ""))
			var row := HBoxContainer.new()
			row.add_child(_icon(sec, 28))
			var l := _label(" " + T.t("sec_" + sec), 20, T.sec_color(sec), 0, HORIZONTAL_ALIGNMENT_LEFT)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			row.add_child(_label("IQ %d  ±%d" % [int(r.get("iq", 0)), int(round(15 * float(r.get("se", 0.0))))], 20, FG))
			body.add_child(row)

# ================================================================== ACHIEVEMENTS (🏅)

## Asks the leaderboard function (board "awards") about the genius medals in `secs` and
## fixed 🚩 reports not earned yet; nothing is sent once they all are.
func _check_awards(secs: Array, fixer: bool) -> void:
	var req := Awards.request(secs, fixer)
	if not req.is_empty():
		api.call_fn("leaderboard", req, _on_awards)

func _on_awards(ok: bool, _code: int, data: Dictionary) -> void:
	if ok:  # an older server says "bad_board": nothing to pay yet
		Awards.apply(data)

func _flush_practice() -> void:
	if practice_pending > 0.0:
		Awards.add_practice(practice_pending)
		practice_pending = 0.0

## Every IQ badge: tests and Speed Rounds (GameInfo), then the game's own; All / Earned /
## Locked, progress bars on locked counters, each badge's points.
func _show_achievements() -> void:
	screen_name = "achievements"
	running = false
	_close_overlays()
	var box := _new_page(true)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_button("◀", _show_home, FG2, Vector2(70, 60), 26))
	var title := _neon_title("🏅 " + tr("Achievements"), 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	box.add_child(top)
	var rows: Array = Awards.rows(info, Help.CHALLENGES)
	var have := 0
	var pts := 0
	var pts_all := 0
	for r in rows:
		pts_all += int(r.get("xp", 0))
		if r.unlocked:
			have += 1
			pts += int(r.get("xp", 0))
	box.add_child(_label(tr("%d of %d unlocked") % [have, rows.size()], 28, Color.WHITE, W))
	if pts_all > 0:
		box.add_child(_label(tr("%d of %d points") % [pts, pts_all], 22, WARN, W))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	var names := ["All", "Earned", "Locked"]
	for i in names.size():
		var on := ach_filter == i
		var b := _button(tr(names[i]), _set_ach_filter.bind(i), GOOD if on else FG2, Vector2(0, 56), 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if on:
			b.add_theme_stylebox_override("normal", Items.box_style(Color(GOOD, 0.22), GOOD, 3))
		tabs.add_child(b)
	box.add_child(tabs)
	var shown := 0
	for r in rows:
		if (ach_filter == 1 and not r.unlocked) or (ach_filter == 2 and r.unlocked):
			continue
		box.add_child(_badge(r))
		shown += 1
	if shown == 0:
		box.add_child(_label(tr("None yet — keep playing!") if ach_filter == 1 else tr("All unlocked!"), 24, FG2, W))

func _set_ach_filter(i: int) -> void:
	ach_filter = i
	_show_achievements()

func _badge(r: Dictionary) -> Control:
	var got := bool(r.unlocked)
	var p := _panel(GOOD if got else Color("#2A2A3E"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var icon := _label(str(r.icon) if got else "🔒", 40, Color.WHITE)
	icon.custom_minimum_size = Vector2(58, 0)
	icon.modulate.a = 1.0 if got else 0.55
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var text_w := maxf(120.0, W - 188.0)
	col.add_child(_label(str(r.title), 24, GOOD if got else Color.WHITE, text_w, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(_label(str(r.desc), 19, FG2, text_w, HORIZONTAL_ALIGNMENT_LEFT))
	var progress := float(r.get("progress", 0.0))
	if not got and progress > 0.0:
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = progress
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(text_w, 10)
		bar.add_theme_stylebox_override("background", Items.box_style(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.08), 0, 5))
		bar.add_theme_stylebox_override("fill", Items.box_style(ACCENT, ACCENT, 0, 5))
		col.add_child(bar)
	if int(r.get("xp", 0)) > 0:
		var xp := _label("+%d" % int(r.xp), 20, WARN if got else FG2)
		xp.custom_minimum_size = Vector2(70, 0)
		row.add_child(xp)
	return _panel_of(p)
