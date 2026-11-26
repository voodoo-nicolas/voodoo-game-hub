extends Control

## Camera Hunter (id hue_hunt) -- photograph real things that match a colour.
## Live camera -> 📸 freezes a frame -> tap the spot -> the median Lab of a
## 15x15 patch is scored with CIEDE2000 (hue_hunt_engine.gd). Photos never
## leave the phone and are never saved.
##
## Built (phase 3): Landing (kit), solo Time Attack / Free Hunt / Daily
## Color, the six solo round types (Classic, Duo, Mix, Opposite, Blind,
## Superlative), Colour Book, helps (Hot/Cold, Peek, Second Chance, More
## Time; solo only), first-launch safety notice, save / Resume of a Time
## Attack. Not built yet: multiplayer rooms, reveal, power-ups, object
## rounds (phases 4-6, docs/hue_hunt/DESIGN.md).
##
## Camera: the APK's shared scripts/common/camera_service.gd (app build 65+),
## loaded guarded; older apps get an "Update the app" screen.
##
## Landing menu style: S11 Sticker Board (docs/MENU_STYLES.md) -- playful,
## party; the last two new games used S2 ring (arrow_cube) and S6 slabs
## (chinchon).

const MenuStyles = preload("res://scripts/games/hue_hunt/menu_styles.gd")
const E = preload("res://scripts/games/hue_hunt/hue_hunt_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const HomeKit = preload("res://scripts/games/hue_hunt/home_kit.gd")
const Help = preload("res://scripts/games/hue_hunt/hue_hunt_help.gd")
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const CAM_PATH := "res://scripts/common/camera_service.gd"

const SAVE_PATH := "user://hue_hunt_run.json"
const BOOK_PATH := "user://hue_hunt_book.json"
const PREFS_PATH := "user://hue_hunt_prefs.json"

const ATTACK_ROUNDS := 5
const ATTACK_TIME := 180.0
const HOTCOLD_TIME := 10.0
const MORE_TIME := 30.0
const METER_EVERY := 0.4

## Where you might find each family. Family-level on purpose: no per-colour
## "facts" until the owner has checked them (OPEN, docs/hue_hunt/DESIGN.md).
const FAMILY_TIPS := {
	"red": "Try fruit, signs, brake lights or packaging.",
	"pink": "Try flowers, clothes, toys or sweets.",
	"orange": "Try fruit, traffic cones, autumn leaves or bricks.",
	"yellow": "Try fruit, flowers, pencils or road markings.",
	"green": "Try plants, leaves, grass or bottles.",
	"cyan": "Try pools, tiles, clothes or toys.",
	"blue": "Try the sky, jeans, clothes or packaging.",
	"purple": "Try flowers, fruit, clothes or pens.",
	"brown": "Try wood, bread, coffee, leather or soil.",
	"neutral": "Try walls, paper, stone, metal or fabric.",
}

var info = null
var home
var cam = null              # CameraService, or null on older apps
var prefs := {"safety_ok": false, "daily": {}, "superlative_best": {}}
var book := {}              # colour id -> {pct, swatch, date, best_date}

# run state
var mode := ""              # attack / free / daily
var plan: Array = []        # RoundSpecs
var seed_v := 0
var round_i := 0
var pcts: Array = []        # % per finished round
var time_left := 0.0
var started := false        # a run began in this scene (else _save_game skips)
var run_on := false
var phase := ""             # idle / live / frozen / preview / result / end
var photo: Image = null
var taps: Array = []        # image pixels tapped on this photo
var samples: Array = []     # Lab per tap
var peeked := false
var hot_t := 0.0
var _meter_t := 0.0
var _meter_busy := false
var skin := "classic"

# nodes
var stage: Control
var frozen: TextureRect
var marks: Control
var bar_top: PanelContainer
var target_box: HBoxContainer
var target_name: Label
var timer_label: Label
var hint: Label
var meter: ProgressBar
var bottom: HBoxContainer
var shutter: Button
var retake_btn: Button
var lock_btn: Button
var next_btn: Button
var result_box: VBoxContainer
var cam_msg: VBoxContainer


func _ready() -> void:
	Orientation.lock_portrait()
	preload("res://scripts/games/hue_hunt/hue_hunt_i18n.gd").install(self)
	var p = SaveUtil.read(PREFS_PATH)
	if p is Dictionary:
		prefs.merge(p, true)
	var b = SaveUtil.read(BOOK_PATH)
	if b is Dictionary:
		book = b
	_build_ui()


# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	if ResourceLoader.exists(CAM_PATH):
		cam = load(CAM_PATH).new()
		cam.set_anchors_preset(Control.PRESET_FULL_RECT)
		stage.add_child(cam)
		cam.state_changed.connect(_on_cam_state)
		cam.light_changed.connect(_on_light)
	frozen = TextureRect.new()
	frozen.set_anchors_preset(Control.PRESET_FULL_RECT)
	frozen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frozen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frozen.visible = false
	frozen.mouse_filter = Control.MOUSE_FILTER_STOP
	frozen.gui_input.connect(_on_frozen_input)
	stage.add_child(frozen)
	marks = Control.new()
	marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.draw.connect(_draw_marks)
	stage.add_child(marks)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	bar_top = PanelContainer.new()
	col.add_child(bar_top)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	bar_top.add_child(top)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(72, 64)
	pause_btn.pressed.connect(_on_pause)
	top.add_child(pause_btn)
	target_box = HBoxContainer.new()
	target_box.add_theme_constant_override("separation", 6)
	top.add_child(target_box)
	target_name = Label.new()
	target_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_name.add_theme_font_size_override("font_size", 28)
	top.add_child(target_name)
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 28)
	top.add_child(timer_label)

	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 8)
	col.add_child(hint)
	meter = ProgressBar.new()
	meter.max_value = 4
	meter.show_percentage = false
	meter.custom_minimum_size = Vector2(0, 22)
	meter.visible = false
	col.add_child(meter)

	cam_msg = VBoxContainer.new()
	cam_msg.alignment = BoxContainer.ALIGNMENT_CENTER
	cam_msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cam_msg.add_theme_constant_override("separation", 14)
	col.add_child(cam_msg)
	result_box = VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_box.add_theme_constant_override("separation", 12)
	result_box.visible = false
	col.add_child(result_box)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	var bot_margin := MarginContainer.new()
	bot_margin.add_theme_constant_override("margin_bottom", 18)
	bot_margin.add_theme_constant_override("margin_left", 14)
	bot_margin.add_theme_constant_override("margin_right", 14)
	col.add_child(bot_margin)
	bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 14)
	bot_margin.add_child(bottom)
	retake_btn = _big_button("↺ " + tr("Retake"), _on_retake)
	shutter = _big_button("📸", _on_shutter)
	shutter.custom_minimum_size = Vector2(150, 110)
	shutter.add_theme_font_size_override("font_size", 52)
	lock_btn = _big_button("✔ " + tr("Lock in"), _on_lock)
	lock_btn.modulate = Color(0.6, 1.0, 0.6)
	next_btn = _big_button(tr("Next") + " ▶", _on_next)
	for btn in [retake_btn, shutter, lock_btn, next_btn]:
		bottom.add_child(btn)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(Help)
	_build_home()
	if info:
		add_child(info)
	_set_skin(skin)
	_show_phase("idle")


func _big_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 88)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(action)
	return b


func _build_home() -> void:
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S11 Sticker Board; colours: a red-green-blue
		# camera-sensor triad.
		"landing": "stickers",
		"landing_style": MenuStyles,
		"title_font": "res://games/hue_hunt/title.ttf",
		"title_colors": [Color("ff4f5e"), Color("3ddc84"), Color("3a8cff")],
		"landing_colors": [Color("141024"), Color("231a3a")],
		"menu_color": Color("ffd23c"),
		"help": Help,
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Find real things that match the colour. Snap, tap, score.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "⏱ Time Attack", "sub": "5 colours, 3 minutes", "action": _start_attack},
			{"text": "🎨 Free Hunt", "sub": "Pick any colour", "action": _open_free_picker, "card": true},
			{"text": "📅 Daily Color", "sub": "Same colour for everyone today", "action": _start_daily},
		],
		"save_path": SAVE_PATH,
		"resume": _resume,
		"restart": _restart,
		"board": "Best score",
		"board_note": "Time Attack: the sum of your match % over 5 colours.",
		"more": [["📖 Color Book", HomeKit.GOLD, _open_book]],
		"helps": [
			{"text": "🌡 Hot / Cold", "how": "For 10 seconds a meter shows how close the middle of the camera is to the colour.", "action": _help_hot_cold},
			{"text": "👁 Peek", "how": "Shows the colour in a Blind round.", "action": _help_peek},
			{"text": "🔁 Second Chance", "how": "Undo your lock-in and shoot again.", "action": _help_second},
			{"text": "⏱ More Time", "how": "Adds 30 seconds in Time Attack.", "action": _help_time},
		],
	})
	add_child(home)


func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 180.0)
	var ctr := c.size / 2.0
	var cols := [Color("ff4f5e"), Color("ffd23c"), Color("3ddc84"), Color("3a8cff"), Color("b05cff")]
	for i in cols.size():
		var a := -PI / 2 + TAU * i / cols.size()
		c.draw_rect(Rect2(ctr + Vector2(cos(a), sin(a)) * h * 0.3 - Vector2.ONE * h * 0.11, Vector2.ONE * h * 0.22), cols[i])
	HomeKit.glow_text(c, ctr, "📷", int(h * 0.36), HomeKit.CYAN)


func _set_skin(s: String) -> void:
	skin = s
	var sb := StyleBoxFlat.new()
	if s == "voodoo":
		sb.bg_color = Color(0.02, 0.0, 0.05, 0.82)
		sb.border_color = HomeKit.PINK
		sb.border_width_bottom = 2
	else:
		sb.bg_color = Color(0.08, 0.1, 0.16, 0.85)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if bar_top:
		bar_top.add_theme_stylebox_override("panel", sb)


func _current_skin() -> String:
	return skin


func _on_pause() -> void:
	home.pause()


func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)


# ---------- modes ----------

func _attack_plan() -> Array:
	return E.plan_match({"seed": seed_v, "rounds": ATTACK_ROUNDS, "selection": "mixed", "solo": true})


func _start_attack() -> void:
	seed_v = randi()
	_begin("attack", _attack_plan())
	time_left = ATTACK_TIME
	_update_timer()


func _start_daily() -> void:
	seed_v = 0
	_begin("daily", [E.make_spec(E.T_CLASSIC, [E.daily_color(_today())])])


func _start_free(id: String) -> void:
	seed_v = 0
	_begin("free", [E.make_spec(E.T_CLASSIC, [id])])


func _begin(m: String, p: Array) -> void:
	SaveUtil.delete(SAVE_PATH)
	mode = m
	plan = p
	round_i = 0
	pcts = []
	time_left = 0.0
	started = true
	run_on = true
	if info:
		info.add("Hunts played")
	if not prefs.safety_ok:
		_show_safety()
	_start_round()


func _restart() -> void:
	match mode:
		"daily":
			_start_daily()
		"free":
			_start_free(plan[0].colors[0] if not plan.is_empty() else "red")
		_:
			_start_attack()


func _resume() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if not d is Dictionary or d.get("mode", "") != "attack":
		_start_attack()
		return
	seed_v = int(d.seed)
	mode = "attack"
	plan = _attack_plan()
	round_i = clampi(int(d.round_i), 0, plan.size() - 1)
	pcts = d.pcts
	time_left = float(d.time_left)
	started = true
	run_on = true
	_start_round()


func _save_game() -> void:
	if not started or not run_on or mode != "attack":
		return
	SaveUtil.write(SAVE_PATH, {"mode": mode, "seed": seed_v, "round_i": round_i, "pcts": pcts, "time_left": time_left})


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()


# ---------- a round ----------

func spec() -> Dictionary:
	return plan[round_i] if round_i < plan.size() else {}


func _start_round() -> void:
	taps = []
	samples = []
	peeked = false
	hot_t = 0.0
	_fill_target()
	_show_phase("live")
	_start_camera()


func _es() -> bool:
	return TranslationServer.get_locale().begins_with("es")


func _fill_target() -> void:
	for ch in target_box.get_children():
		ch.queue_free()
	var sp := spec()
	var names := []
	for id in sp.colors:
		names.append(E.color_name(id, _es()))
	match sp.type:
		E.T_CLASSIC:
			target_name.text = names[0]
			_add_swatch(_target_rgb(0))
		E.T_BLIND:
			target_name.text = "🙈 " + names[0]
			if peeked:
				_add_swatch(_target_rgb(0))
		E.T_DUO:
			target_name.text = tr("Both in one photo: %s + %s") % [names[0], names[1]]
			_add_swatch(_target_rgb(0))
			_add_swatch(_target_rgb(1))
		E.T_MIX:
			target_name.text = tr("The blend of %s and %s") % [names[0], names[1]]
			_add_swatch(Color.html(E.color_by_id(sp.colors[0])[3]))
			_add_swatch(Color.html(E.color_by_id(sp.colors[1])[3]))
		E.T_OPPOSITE:
			target_name.text = tr("The opposite of %s") % names[0]
			_add_swatch(Color.html(E.color_by_id(sp.colors[0])[3]))
		E.T_SUPERLATIVE:
			match sp.superlative:
				"darkest":
					target_name.text = tr("The darkest thing you can find")
				"lightest":
					target_name.text = tr("The lightest thing you can find")
				_:
					target_name.text = tr("The most vivid colour you can find")
	_update_timer()


func _target_rgb(i: int) -> Color:
	return E.to_rgb(E._lab(spec().targets[i]))


func _add_swatch(c: Color) -> void:
	var r := ColorRect.new()
	r.color = c
	r.custom_minimum_size = Vector2(56, 56)
	target_box.add_child(r)


func _show_phase(p: String) -> void:
	phase = p
	bar_top.visible = p in ["live", "frozen", "preview", "result"]
	shutter.visible = p == "live" and cam != null and cam.state == "running"
	retake_btn.visible = p in ["frozen", "preview"]
	lock_btn.visible = p == "preview"
	next_btn.visible = p == "result"
	frozen.visible = p in ["frozen", "preview", "result"]
	result_box.visible = p in ["result", "end"]
	meter.visible = p == "live" and hot_t > 0.0
	marks.queue_redraw()
	match p:
		"live":
			hint.text = tr("Point the camera at something that matches, then 📸.")
		"frozen":
			if int(spec().taps) == 1:
				hint.text = tr("Tap the spot to sample.")
			else:
				hint.text = tr("Tap one spot for each colour (%d of 2).") % (taps.size() + 1)
		_:
			hint.text = ""
	if p != "live":
		_set_cam_msg("")


# ---------- camera ----------

func _start_camera() -> void:
	if cam == null:
		_set_cam_msg(tr("Camera Hunter needs the newest version of the app for the camera. Please update the app."))
		return
	cam.visible = true
	if cam.state == "running":
		_on_cam_state("running")
	else:
		cam.start()
		_on_cam_state(cam.state)


func _on_cam_state(s: String) -> void:
	if phase != "live":
		return
	match s:
		"running":
			_set_cam_msg("")
		"need_permission":
			_set_cam_msg(tr("Camera Hunter needs the camera to see colours. Photos stay on your phone."), "allow")
		"denied":
			_set_cam_msg(tr("The camera is switched off for this app."), "settings")
		"no_camera":
			_set_cam_msg(tr("No camera found on this device."))
		_:
			_set_cam_msg(tr("Starting the camera…"))
	shutter.visible = s == "running"


func _on_light(dark: bool) -> void:
	if phase == "live":
		hint.text = tr("More light, please! Colours need good light.") if dark else tr("Point the camera at something that matches, then 📸.")


func _set_cam_msg(text: String, button: String = "") -> void:
	for ch in cam_msg.get_children():
		ch.queue_free()
	cam_msg.visible = text != ""
	if text == "":
		return
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	cam_msg.add_child(l)
	if button == "allow":
		cam_msg.add_child(_big_button(tr("Allow camera"), _on_allow))
	elif button == "settings":
		cam_msg.add_child(_big_button(tr("Open settings"), _on_settings))


func _on_allow() -> void:
	if cam:
		cam.request_permission()


func _on_settings() -> void:
	if cam:
		cam.open_app_settings()


func _on_shutter() -> void:
	if cam == null or phase != "live":
		return
	_sfx("tap")
	var img: Image = await cam.snapshot()
	if img == null or phase != "live":
		return
	photo = img
	frozen.texture = ImageTexture.create_from_image(img)
	taps = []
	samples = []
	cam.stop()
	cam.visible = false
	_show_phase("frozen")


func _on_retake() -> void:
	photo = null
	taps = []
	samples = []
	_show_phase("live")
	_start_camera()


## The frozen photo is drawn cover-fit and centred: [scale, offset].
func _photo_fit() -> Array:
	var isz := Vector2(photo.get_size())
	var k := maxf(frozen.size.x / isz.x, frozen.size.y / isz.y)
	return [k, (frozen.size - isz * k) / 2.0]


func _on_frozen_input(ev: InputEvent) -> void:
	if phase != "frozen" or photo == null:
		return
	# Phones send each tap twice: single taps use the mouse event only.
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var fit := _photo_fit()
	var px := Vector2i(((ev.position - fit[1]) / fit[0]).floor())
	if px.x < 0 or px.y < 0 or px.x >= photo.get_width() or px.y >= photo.get_height():
		return
	var s: Dictionary = E.sample(load(CAM_PATH).patch(photo, px, E.PATCH_HALF))
	if not s.ok:
		hint.text = tr("Too bright or too dark there. Tap another spot or retake.")
		return
	taps.append(px)
	samples.append(s.lab)
	marks.queue_redraw()
	if taps.size() >= int(spec().taps):
		_show_preview()
	else:
		_show_phase("frozen")


func _draw_marks() -> void:
	if photo == null or not frozen.visible:
		return
	var fit := _photo_fit()
	for t in taps:
		var p: Vector2 = Vector2(t) * fit[0] + fit[1]
		var r: float = E.PATCH_HALF * fit[0] + 6.0
		marks.draw_rect(Rect2(p - Vector2.ONE * r, Vector2.ONE * r * 2.0), Color.WHITE, false, 3.0)
		marks.draw_rect(Rect2(p - Vector2.ONE * (r + 3.0), Vector2.ONE * (r + 3.0) * 2.0), Color.BLACK, false, 2.0)


func _show_preview() -> void:
	_show_phase("preview")
	var p := E.solo_pct(spec(), samples)
	if spec().judge == "superlative":
		hint.text = tr("Your sample: %d%%. Lock it in or retake.") % p
	else:
		hint.text = tr("Your sample: %d%% match. Lock it in or retake.") % p


func _on_lock() -> void:
	if phase != "preview":
		return
	var sp := spec()
	var p := E.solo_pct(sp, samples)
	pcts.append(p)
	_sfx("success" if p >= 80 else "tap")
	var day := _today()
	if sp.judge == "color":
		if info:
			info.high("Best match", p)
		if E.score(sp, samples).close and sp.type in [E.T_CLASSIC, E.T_BLIND, E.T_DUO]:
			for i in sp.colors.size():
				E.book_add(book, sp.colors[i], p, E.to_rgb(samples[mini(i, samples.size() - 1)]).to_html(false), day)
			SaveUtil.write(BOOK_PATH, book)
			if info:
				info.high("Colors found", book.size())
	else:
		var best: Dictionary = prefs.superlative_best
		if p > int(best.get(sp.superlative, 0)):
			best[sp.superlative] = p
	if mode == "daily":
		var dd: Dictionary = prefs.daily
		dd[day] = maxi(int(dd.get(day, 0)), p)
		if info:
			info.high("Best daily match", dd[day])
	_save_prefs()
	_save_game()
	_show_result(p)


func _show_result(p: int) -> void:
	_show_phase("result")
	for ch in result_box.get_children():
		ch.queue_free()
	var sp := spec()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	result_box.add_child(row)
	if sp.judge == "color":
		for i in sp.targets.size():
			row.add_child(_swatch_card(tr("Target"), _target_rgb(i)))
	for s in samples:
		row.add_child(_swatch_card(tr("Yours"), E.to_rgb(s)))
	var big := Label.new()
	big.text = "%d%%" % p
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 72)
	big.add_theme_color_override("font_outline_color", Color.BLACK)
	big.add_theme_constant_override("outline_size", 10)
	result_box.add_child(big)
	var note := Label.new()
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 24)
	note.add_theme_color_override("font_outline_color", Color.BLACK)
	note.add_theme_constant_override("outline_size", 6)
	if sp.judge == "superlative":
		note.text = tr("Your best: %d%%") % int(prefs.superlative_best.get(sp.superlative, p))
	elif E.score(sp, samples).close:
		note.text = tr("Close! Added to your Color Book.") if sp.type in [E.T_CLASSIC, E.T_BLIND, E.T_DUO] else tr("Close!")
	else:
		note.text = tr("Not close enough for the Color Book yet.")
	result_box.add_child(note)
	next_btn.text = (tr("Next") + " ▶") if mode == "attack" and round_i + 1 < plan.size() else tr("Done")


func _swatch_card(title: String, c: Color) -> VBoxContainer:
	var v := VBoxContainer.new()
	var r := ColorRect.new()
	r.color = c
	r.custom_minimum_size = Vector2(120, 120)
	v.add_child(r)
	var l := Label.new()
	l.text = title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	v.add_child(l)
	return v


func _on_next() -> void:
	if mode == "attack" and round_i + 1 < plan.size() and time_left > 0.0:
		round_i += 1
		_save_game()
		_start_round()
	else:
		_end_run()


func _end_run() -> void:
	run_on = false
	SaveUtil.delete(SAVE_PATH)
	if cam:
		cam.stop()
	var total := E.time_attack_score(pcts)
	if mode == "attack" and info:
		info.high("Best score", total)
	_show_phase("end")
	for ch in result_box.get_children():
		ch.queue_free()
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 34)
	match mode:
		"attack":
			l.text = tr("Time Attack: %d points (%d colours)") % [total, pcts.size()]
		"daily":
			l.text = tr("Today's best: %d%%") % int(prefs.daily.get(_today(), 0))
		_:
			l.text = tr("Colours found: %d of %d") % [book.size(), E.colors().size()]
	result_box.add_child(l)
	result_box.add_child(_big_button("↺ " + tr("Play again"), _restart))
	result_box.add_child(_big_button("📖 " + tr("Color Book"), _open_book))
	result_box.add_child(_big_button("🏠 " + tr("Home"), _go_home))


func _go_home() -> void:
	home.go_home()


func _process(delta: float) -> void:
	if not run_on:
		return
	if mode == "attack" and phase in ["live", "frozen", "preview"]:
		time_left -= delta
		_update_timer()
		if time_left <= 0.0:
			time_left = 0.0
			_end_run()
			return
	if hot_t > 0.0 and phase == "live":
		hot_t -= delta
		_meter_t -= delta
		if _meter_t <= 0.0 and not _meter_busy:
			_meter_t = METER_EVERY
			_read_meter()
		if hot_t <= 0.0:
			meter.visible = false


func _update_timer() -> void:
	timer_label.text = ("%d:%02d" % [int(time_left) / 60, int(time_left) % 60]) if mode == "attack" else ""


func _read_meter() -> void:
	if cam == null or cam.state != "running":
		return
	_meter_busy = true
	var img: Image = await cam.snapshot()
	_meter_busy = false
	if img == null or phase != "live" or spec().is_empty():
		return
	var s: Dictionary = E.sample(load(CAM_PATH).patch(img, img.get_size() / 2, E.PATCH_HALF))
	if s.ok:
		meter.value = E.hot_cold(spec(), s.lab)
		meter.modulate = Color(0.3, 0.6, 1.0).lerp(Color(1.0, 0.3, 0.2), meter.value / 4.0)


func _today() -> String:
	return Time.get_date_string_from_system(true)


func _save_prefs() -> void:
	SaveUtil.write(PREFS_PATH, prefs)


# ---------- helps (solo only; STANDARDS §17) ----------

func _help_hot_cold() -> bool:
	if not run_on or phase != "live" or spec().get("judge", "") != "color":
		return false
	hot_t = HOTCOLD_TIME
	_meter_t = 0.0
	meter.value = 0
	meter.visible = true
	hint.text = tr("Hot / Cold: aim the middle of the screen.")
	return true


func _help_peek() -> bool:
	if not run_on or spec().get("type", "") != E.T_BLIND or peeked or phase in ["result", "end"]:
		return false
	peeked = true
	_fill_target()
	return true


func _help_second() -> bool:
	if not run_on or phase != "result" or pcts.is_empty():
		return false
	pcts.pop_back()
	_on_retake()
	return true


func _help_time() -> bool:
	if not run_on or mode != "attack":
		return false
	time_left += MORE_TIME
	_update_timer()
	return true


# ---------- safety notice ----------

func _show_safety() -> void:
	var parts: Array = home.card("⚠ " + tr("Before you hunt"))
	var body: VBoxContainer = parts[1]
	for line in [tr("Watch where you walk: be aware of your surroundings."),
			tr("Don't photograph people without asking."),
			tr("Don't go onto private property or into traffic."),
			tr("Photos never leave your phone and are never saved.")]:
		var l := Label.new()
		l.text = "• " + line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 26)
		body.add_child(l)
	var ok := _big_button(tr("I understand"), _on_safety_ok.bind(parts[0]))
	ok.modulate = Color(0.6, 1.0, 0.6)
	body.add_child(ok)
	home.show_card(parts[0])


func _on_safety_ok(c: Control) -> void:
	prefs.safety_ok = true
	_save_prefs()
	home.close_card(c)


# ---------- Free Hunt picker + Colour Book ----------

func _colour_grid(body: Control, on_pick: Callable, show_locked: bool) -> void:
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for id in E.book_order():
		var found: bool = book.has(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(72, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.html(E.color_by_id(id)[3]) if (found or not show_locked) else Color(0.16, 0.16, 0.2)
		sb.set_corner_radius_all(10)
		if found:
			sb.border_color = Color.WHITE
			sb.set_border_width_all(3)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.text = "" if (found or not show_locked) else "?"
		b.pressed.connect(on_pick.bind(id))
		grid.add_child(b)


func _open_free_picker() -> void:
	var parts: Array = home.card("🎨 " + tr("Free Hunt"))
	var l := Label.new()
	l.text = tr("Pick a colour to hunt. White outline = already in your Color Book.")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parts[1].add_child(l)
	_colour_grid(parts[1], _on_free_pick.bind(parts[0]), false)
	home.show_card(parts[0])


func _on_free_pick(id: String, c: Control) -> void:
	home.close_card(c)
	home.play_now(_start_free.bind(id))


func _open_book() -> void:
	var parts: Array = home.card("📖 " + tr("Color Book"))
	var n := book.size()
	var total: int = E.colors().size()
	var l := Label.new()
	l.text = tr("%d of %d colours found (%d%%)") % [n, total, roundi(100.0 * n / total)]
	l.add_theme_font_size_override("font_size", 28)
	parts[1].add_child(l)
	_colour_grid(parts[1], _on_book_pick, true)
	home.show_card(parts[0])


func _on_book_pick(id: String) -> void:
	var c := E.color_by_id(id)
	var found: bool = book.has(id)
	var parts: Array = home.card(E.color_name(id, _es()) if found else "?")
	var body: VBoxContainer = parts[1]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	body.add_child(row)
	if found:
		row.add_child(_swatch_card(tr("Colour"), Color.html(c[3])))
		row.add_child(_swatch_card(tr("Your best"), Color.html(book[id].swatch)))
	var lines := []
	if found:
		lines.append(tr("Best match: %d%%") % int(book[id].pct))
		lines.append(tr("First found: %s") % book[id].date)
		lines.append(tr("Hex: %s") % c[3])
		lines.append(tr("English: %s · Spanish: %s") % [c[1], c[2]])
	else:
		lines.append(tr("Not found yet. Hunt it in Free Hunt!"))
	lines.append(tr("Family: %s · %s") % [tr(c[5].capitalize()), tr(E.warmth(id).capitalize())])
	lines.append("💡 " + tr(FAMILY_TIPS.get(c[5], FAMILY_TIPS.neutral)))
	for t in lines:
		var l := Label.new()
		l.text = t
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 26)
		body.add_child(l)
	home.show_card(parts[0])
