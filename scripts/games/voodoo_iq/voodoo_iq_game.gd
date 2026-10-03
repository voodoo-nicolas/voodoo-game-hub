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
var toast_label: Label

var setup := {"mode": "iq", "scope": "ALL", "dur": 15, "bdur": 120, "ranked": true}

# ---- runner state
var session: Dictionary = {}
var running := false
var waiting := false  # a request is out: the clocks stop
var paused := false  # instructions / prediction on screen: the clocks stop
var remaining_ms := 0.0
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

func _ready() -> void:
	preload("res://scripts/games/voodoo_iq/voodoo_iq_i18n.gd").install(self)
	Orientation.lock_portrait()
	var saved = SaveUtil.read(SETUP_PATH)
	if saved is Dictionary:
		for k in setup:
			if saved.has(k):
				setup[k] = saved[k]
	setup.dur = int(setup.dur)
	setup.bdur = int(setup.bdur)
	_build_ui()
	get_viewport().size_changed.connect(_on_screen_resized)
	_show_home()

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
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/voodoo_iq/voodoo_iq_help.gd"))
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.3)
	# Must stay the last child so its tab sits above any dialog.
	add_child(drawer)

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
		"boards":
			_show_boards()
		"results":
			_show_results(last_result)

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
func _overlay() -> VBoxContainer:
	_fit_width()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.add_to_group("modal_overlay")
	overlay_layer.add_child(dim)
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dim.add_child(sc)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(size.x, size.y)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(center)
	var box := _panel(ACCENT)
	box.custom_minimum_size = Vector2(W - 40, 0)
	center.add_child(_panel_of(box))
	return box

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
	screen_name = "home"
	running = false
	_close_overlays()
	var box := _new_page(true)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_button(tr("Hub"), UI.exit_to_hub.bind(self), FG2, Vector2(100, 60), 24))
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_child(_neon_title("VOODOO IQ", 48))
	brand.add_child(_label(T.t("tagline"), 22, FG2))
	top.add_child(brand)
	top.add_child(_button("🏆", _show_boards, WARN, Vector2(70, 60), 26))
	top.add_child(_button("👤", _show_profile_form, FG2, Vector2(70, 60), 26))
	box.add_child(top)

	box.add_child(_label(T.t("hero"), 30, Color.WHITE, W))
	box.add_child(_label(T.t("hero_sub"), 21, FG2, W))
	if not api.is_signed_in():
		var warn := _panel(WARN)
		warn.add_child(_label(tr("Sign in to take the IQ test: hub → ⚙ Options → Account. Scores are saved to your account."), 24, WARN, W - 40))
		box.add_child(_panel_of(warn))

	# brain map: tap a region to choose a section
	var bp := _panel()
	var brain := Art.canvas(func(ci, sz): Art.brain(ci, Rect2(Vector2.ZERO, sz), str(setup.scope)), Vector2(W - 40, (W - 40) * 440.0 / 560.0))
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
		bp.add_child(_label(T.t("brain_area") + ": " + T.t("area_" + scope), 20, FG2, W - 40))
		bp.add_child(_label(T.t("counts_iq") if T.core().has(scope) else T.t("counts_profile"), 20, FG2, W - 40))
	bp.add_child(_label(T.t("brain_disclaimer"), 18, FG2, W - 40))
	box.add_child(_panel_of(bp))

	# setup
	var sp := _panel(ACCENT)
	sp.add_child(_label(T.t("setup_title"), 32, Color.WHITE))
	sp.add_child(_label(T.t("mode"), 22, FG2, 0, HORIZONTAL_ALIGNMENT_LEFT))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	for m in [["iq", T.t("iqtest"), T.t("iq_hint")], ["blitz", T.t("blitz"), T.t("blitz_hint")]]:
		var b := _button(m[1] + "\n" + m[2], _set_mode.bind(m[0]), GOOD if setup.mode == m[0] else FG2, Vector2(0, 90), 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		modes.add_child(b)
	sp.add_child(modes)
	sp.add_child(_label(T.t("time_limit"), 22, FG2, 0, HORIZONTAL_ALIGNMENT_LEFT))
	var durs := HBoxContainer.new()
	durs.add_theme_constant_override("separation", 8)
	var iq_mode: bool = setup.mode == "iq"
	for dv in (T.data().get("IQ_DURS", []) if iq_mode else T.data().get("BLITZ_DURS", [])):
		var dur := int(dv)
		var on: bool = (setup.dur if iq_mode else setup.bdur) == dur
		var b := _button("%d min" % (dur if iq_mode else dur / 60), _set_dur.bind(dur), GOOD if on else FG2, Vector2(0, 64), 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		durs.add_child(b)
	sp.add_child(durs)
	sp.add_child(_label(T.t("questions_from") + ": " + _sec_name(scope), 24, Color.WHITE if scope == "ALL" else T.sec_color(scope), W - 40, HORIZONTAL_ALIGNMENT_LEFT))
	sp.add_child(_label(T.t("pick_hint"), 18, FG2, W - 40, HORIZONTAL_ALIGNMENT_LEFT))
	var rk := CheckButton.new()
	rk.text = T.t("ranked") if setup.ranked else T.t("practice")
	rk.button_pressed = bool(setup.ranked)
	rk.add_theme_font_size_override("font_size", 26)
	rk.toggled.connect(_set_ranked)
	sp.add_child(rk)
	# not the prototype's ranked_iq_note: ranked IQ has no daily limit any more (user, 2026-10-03)
	var note: String = (tr("Counts for the leaderboard. Your last 3 ranked tests in each section count, so one lucky run can't carry you.") if iq_mode else T.t("ranked_blitz_note")) if setup.ranked else T.t("practice_note")
	sp.add_child(_label(note, 19, FG2, W - 40, HORIZONTAL_ALIGNMENT_LEFT))
	var start_text := "▶ %s · %s" % [T.t("start"), T.t("iqtest") if iq_mode else T.t("blitz")]
	sp.add_child(_button(start_text, _start_from_setup, GOOD, Vector2(0, 90), 32))
	if scope in ["LIN", "EXI", "ALL"]:
		sp.add_child(_label(T.t("lang_note", {"l": "Español" if T.lang() == "es" else "English"}), 18, FG2, W - 40))
	box.add_child(_panel_of(sp))
	box.add_child(_button("🏆 " + T.t("nav_boards"), _show_boards, WARN, Vector2(0, 76), 28))

	# how scoring works
	var hp := _panel()
	var body := VBoxContainer.new()
	body.visible = false
	for k in ["how_1", "how_2", "how_3", "how_4", "how_5", "how_6"]:
		body.add_child(_label("• " + T.t(k), 20, FG, W - 40, HORIZONTAL_ALIGNMENT_LEFT))
	hp.add_child(_button(T.t("how_title"), func(): body.visible = not body.visible, FG2, Vector2(0, 64), 22))
	hp.add_child(body)
	box.add_child(_panel_of(hp))
	box.add_child(_label(T.t("footer"), 17, FG2, W))

func _neon_title(text: String, size: int) -> Label:
	var l := _label(text, size, Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(ACCENT, 0.8))
	l.add_theme_constant_override("outline_size", 10)
	return l

func _chip(sec: String, text: String) -> Button:
	var on: bool = setup.scope == sec
	var col := Color.WHITE if sec == "ALL" else T.sec_color(sec)
	var b := _button(text, _pick_scope.bind(sec), col, Vector2((W - 48) / 2.0, 64), 19)
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

func _set_mode(m: String) -> void:
	setup.mode = m
	if m == "blitz" and setup.scope == "SELF":
		setup.scope = "ALL"
	_save_setup()
	_show_home()

func _set_dur(dur: int) -> void:
	if setup.mode == "iq":
		setup.dur = dur
	else:
		setup.bdur = dur
	_save_setup()
	_show_home()

func _set_ranked(on: bool) -> void:
	setup.ranked = on
	_save_setup()
	_show_home()

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
		_busy(true)
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
	var cfg := {"mode": setup.mode, "kind": "normal", "scope": setup.scope, "dur": setup.dur if iq_mode else setup.bdur, "ranked": bool(setup.ranked), "lang": T.lang()}
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
	_busy(true)
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

func _busy(on: bool) -> void:
	waiting = on
	var old := get_node_or_null("Busy")
	if old:
		old.queue_free()
	if on:
		var dim := ColorRect.new()
		dim.name = "Busy"
		dim.color = Color(0, 0, 0, 0.45)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		var l := _label(T.t("loading"), 32, Color.WHITE)
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
	remaining_ms = float(data.get("dur_s", 300)) * 1000.0
	running = true
	paused = false
	_build_runner()
	_present(data.get("first_item", {}))

func _is_blitz() -> bool:
	return str(session.get("mode", "")) == "blitz"

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
	bar.add_child(_button(T.t("quit"), _confirm_quit, Color("#ff4f9a"), Vector2(110, 60), 24))
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
	view = Items.build(item, _is_blitz())
	view.submitted.connect(_on_item_submitted)
	view.timer_ready.connect(_on_item_ready)
	qarea.add_child(view)
	item_bar.visible = not bool(item.get("noTimerBar", false))
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
	box.add_child(_label(T.t("clock_paused"), 18, FG2, W - 80))
	box.add_child(_button(T.t("start_timer"), func():
		_close_overlays()
		paused = false
		_mount_item(), GOOD, Vector2(0, 84), 30))

func _process(delta: float) -> void:
	if not running or waiting or paused:
		return
	var ms := delta * 1000.0
	remaining_ms -= ms
	if view != null and not view.done and item_timing:
		item_ms += ms
		var max_ms := float(item.get("maxMs", 60000))
		item_bar.value = clampf(1.0 - item_ms / max_ms, 0.0, 1.0)
		if item_ms > max_ms:
			view.submit(null)
	_update_clock()
	if remaining_ms <= 0.0:
		_finish("time")

func _update_clock() -> void:
	if clock_label == null:
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
	if str(session.get("scope", "")) == "SELF" and value != "__hidden":
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
	_busy(true)
	api.call_fn("item-answer", body, _on_answered)

func _on_answered(ok: bool, _code: int, data: Dictionary) -> void:
	_busy(false)
	if not running:
		return
	if ok and data.get("done", false):
		_show_results(data.get("result", {}))
		return
	if ok:
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

func _confirm_quit() -> void:
	var box := _overlay()
	box.add_child(_label(T.t("quit_q"), 34, Color.WHITE))
	box.add_child(_label(tr("This ranked test will be scored with the answers you gave.") if session.get("ranked", false) else T.t("quit_practice"), 22, FG, W - 80))
	box.add_child(_button(T.t("keep_going"), _close_overlays, GOOD))
	box.add_child(_button(T.t("quit_score"), func():
		_close_overlays()
		_finish("quit"), Color("#ff4f9a")))

## Leaving the app during an item voids it (scored wrong, counted as hidden).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if running and not paused and not waiting and view != null and not view.done:
			view.submit("__hidden")

func _finish(reason: String) -> void:
	if not running:
		return
	running = false
	finish_reason = reason
	_close_overlays()
	_busy(true)
	if _is_blitz():
		api.call_fn("blitz-submit", {"session_id": session.get("session_id", ""), "answers": blitz_answers, "reason": reason}, _on_finished)
	else:
		api.call_fn("session-finish", {"session_id": session.get("session_id", ""), "reason": reason}, _on_finished)

func _on_finished(ok: bool, _code: int, data: Dictionary) -> void:
	_busy(false)
	var result = data.get("result", null)
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
	box.add_child(_label(T.t("footer"), 17, FG2, W))

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
var boards := {"tab": "viq", "sec": "LOG", "bscope": "ALL", "bdur": 120, "season": "month", "age": "", "country": "", "province": "", "lang": "", "show_prov": false}
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
	box.add_child(filters)
	box.add_child(_label(T.t("bnote_" + str(boards.tab)), 18, FG2, W, HORIZONTAL_ALIGNMENT_LEFT))
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
	for h in ["#", T.t("player"), T.t("points") if blitz else (T.t("status") if prov else T.t("rank_score")), T.t("correct") if blitz else T.t("estimate")]:
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
		if r.get("genius", false):
			nick += "  ★130+"
		who.add_child(_label(nick, 22, col, name_w, HORIZONTAL_ALIGNMENT_LEFT))
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
			est = "%s ±%d" % [T.fmt_iq(float(r.theta)), int(round(15 * float(r.get("se", 0.0))))]
		grid.add_child(_label(est, 20, FG))
	p.add_child(grid)
	return _panel_of(p)
