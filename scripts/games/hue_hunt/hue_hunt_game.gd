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
## Attack.
## Phase 4: multiplayer over the shared OnlineTable (2-8 phones, 5-letter
## code). hue_hunt_room.gd is the table's state machine; the acting host
## (lowest-numbered player still here, so the host can drop and someone
## else carries on) runs it and broadcasts the whole state as event
## "state" (ver-numbered). Lock-ins, flags and 128 px thumbnails are events
## to everyone. Times are Unix seconds (phones' clocks agree to a second or
## so); each state carries the host's "now" and clients keep the offset.
## Not built yet: power-ups, object rounds (phases 5-6).
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
## Recorded sounds from the shared library (docs/claude/sfx-library.md).
const SoundLib = preload("res://scripts/games/hue_hunt/sound_lib.gd")
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const CAM_PATH := "res://scripts/common/camera_service.gd"
const ONLINE_TABLE_PATH := "res://scripts/common/online_table.gd"
const Room = preload("res://scripts/games/hue_hunt/hue_hunt_room.gd")
const Powers = preload("res://scripts/games/hue_hunt/hue_hunt_powerups.gd")
const MAX_PLAYERS := 8
const REVEAL_STEP := 0.7   # seconds between reveal rows

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

# multiplayer
var tbl = null              # OnlineTable, or null on older apps
var mp := false
var st := {}                # the table state (hue_hunt_room.gd)
var mp_settings := {"rounds": 10, "selection": "classic", "place": "local"}
var offset := 0.0           # host clock - my clock (s)
var thumbs := {}            # "n" -> ImageTexture, this round only
var shown_phase := ""       # match start, round and phase last drawn
var result_done := false    # info.result() sent for this match
var reveal_box: VBoxContainer
var reveal_scroll: ScrollContainer
var power_bar: HBoxContainer
var _power_key := ""         # what the power bar last showed

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
	power_bar = HBoxContainer.new()
	power_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	power_bar.add_theme_constant_override("separation", 10)
	power_bar.visible = false
	col.add_child(power_bar)

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
	reveal_scroll = ScrollContainer.new()
	reveal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reveal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reveal_scroll.visible = false
	col.add_child(reveal_scroll)
	var rm := MarginContainer.new()
	rm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		rm.add_theme_constant_override("margin_" + side, 14)
	reveal_scroll.add_child(rm)
	reveal_box = VBoxContainer.new()
	reveal_box.add_theme_constant_override("separation", 10)
	rm.add_child(reveal_box)
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
	if ResourceLoader.exists(ONLINE_TABLE_PATH):
		tbl = load(ONLINE_TABLE_PATH).new("hue_hunt", "Camera Hunter", _online_state)
		tbl.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(tbl)
		tbl.started.connect(_on_table_started)
		tbl.remote_state.connect(_take_state)
		tbl.remote_event.connect(_on_remote_event)
		tbl.status_changed.connect(_on_table_status)
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
	var modes := [
		{"text": "⏱ Time Attack", "sub": "5 colours, 3 minutes", "action": _start_attack},
		{"text": "📅 Daily Color", "sub": "Same colour for everyone today", "action": _start_daily},
	]
	# Cards keep the Landing up ("play" entries); plain modes hide it.
	var play := [{"text": "🎨 Free Hunt", "sub": "Pick any colour", "action": _open_free_picker, "card": true}]
	if tbl:
		play.append({"text": "👥 Host a game", "sub": "2-8 phones, same place or far apart", "action": _open_mp_setup, "card": true})
		play.append({"text": "🔑 Join with a code", "sub": "A friend hosts, you type the code", "action": _open_join, "card": true})
	home = HomeKit.new({
		"play": play,
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
		"modes": modes,
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


## Music only from the shared Music autoload (guarded: older apps).
func _music(what: String, style: String, index: int = 0, fade: float = 1.5) -> void:
	var m = get_node_or_null("/root/Music")
	if m == null:
		return
	if what == "play":
		m.play(style, self, index, fade)
	elif m.has_method("stop"):
		m.stop(fade)


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
	_music("play", "lively")
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
	# Online matches are never saved locally (the table keeps the game).
	if mp or not started or not run_on or mode != "attack":
		return
	SaveUtil.write(SAVE_PATH, {"mode": mode, "seed": seed_v, "round_i": round_i, "pcts": pcts, "time_left": time_left})


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()


# ---------- a round ----------

func spec() -> Dictionary:
	if mp:
		return Room.spec(st) if not st.is_empty() else {}
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
			if peeked or (mp and Room.peeked(st, tbl.my_player)):
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
		E.T_OBJECT:
			target_name.text = "📦 " + tr("Find: %s") % E.object_text(str(sp.prompt), _es())
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
	bar_top.visible = p in ["live", "frozen", "preview", "result", "waiting"]
	shutter.visible = p == "live" and cam != null and cam.state == "running"
	retake_btn.visible = p in ["frozen", "preview"]
	lock_btn.visible = p == "preview"
	next_btn.visible = p == "result" or (p in ["reveal", "final"] and mp and _am_acting_host())
	frozen.visible = p in ["frozen", "preview", "result", "waiting"]
	result_box.visible = p in ["result", "end"]
	reveal_scroll.visible = p in ["reveal", "final", "vote", "best"]
	if p == "reveal":
		next_btn.text = tr("Next") + " ▶"
	elif p == "final":
		next_btn.text = "↺ " + tr("Play again")
	meter.visible = p == "live" and hot_t > 0.0
	marks.queue_redraw()
	match p:
		"live":
			if spec().get("judge", "") == "vote":
				hint.text = tr("Find it and 📸. No people in the photo, please!")
			else:
				hint.text = tr("Point the camera at something that matches, then 📸.")
		"frozen":
			if int(spec().taps) == 1:
				hint.text = tr("Tap the spot to sample.")
			else:
				hint.text = tr("Tap one spot for each colour (%d of 2).") % (taps.size() + 1)
		"waiting":
			hint.text = tr("Locked in! Waiting for the others…")
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
	SoundLib.play(self, "ui/click")
	var img: Image = await cam.snapshot()
	if img == null or phase != "live":
		return
	photo = img
	frozen.texture = ImageTexture.create_from_image(img)
	taps = []
	samples = []
	cam.stop()
	cam.visible = false
	if int(spec().get("taps", 1)) == 0:
		_show_preview()   # Object rounds: the photo itself is judged, no sample
	else:
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
	if spec().judge == "vote":
		hint.text = tr("The others will vote on it. Lock it in or retake.")
	elif spec().judge == "superlative":
		hint.text = tr("Your sample: %d%%. Lock it in or retake.") % p
	else:
		hint.text = tr("Your sample: %d%% match. Lock it in or retake.") % p


func _on_lock() -> void:
	if phase != "preview":
		return
	var sp := spec()
	var p := E.solo_pct(sp, samples)
	_sfx("success" if p >= 80 else "tap")
	var day := _today()
	if mp:
		_book_from(sp, p, day)
		_mp_lock()
		return
	pcts.append(p)
	if sp.judge == "color":
		_book_from(sp, p, day)
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


## Solo and multiplayer captures both feed the Colour Book.
func _book_from(sp: Dictionary, p: int, day: String) -> void:
	if sp.judge != "color":
		return
	if info:
		info.high("Best match", p)
	if E.score(sp, samples).close and sp.type in [E.T_CLASSIC, E.T_BLIND, E.T_DUO]:
		for i in sp.colors.size():
			E.book_add(book, sp.colors[i], p, E.to_rgb(samples[mini(i, samples.size() - 1)]).to_html(false), day)
		SaveUtil.write(BOOK_PATH, book)
		_book_stats()


## Colour Book counts for the badges (hue_hunt_help.gd ACHIEVEMENTS).
func _book_stats() -> void:
	if not info:
		return
	var easy := 0
	var families := {}
	for id in book:
		var c := E.color_by_id(id)
		if c.is_empty():
			continue
		if c[4] == "easy":
			easy += 1
		families[c[5]] = true
	info.high("Colors found", book.size())
	info.high("Easy colors found", easy)
	info.high("Color families found", families.size())


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
	if mp:
		_mp_next()
		return
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
	if mp:
		_mp_process()
		return
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
	if mp:
		return false   # helps are solo only (power-ups come in phase 5)
	if not run_on or phase != "live" or spec().get("judge", "") != "color":
		return false
	hot_t = HOTCOLD_TIME
	_meter_t = 0.0
	meter.value = 0
	meter.visible = true
	hint.text = tr("Hot / Cold: aim the middle of the screen.")
	return true


func _help_peek() -> bool:
	if mp:
		return false   # helps are solo only (power-ups come in phase 5)
	if not run_on or spec().get("type", "") != E.T_BLIND or peeked or phase in ["result", "end"]:
		return false
	peeked = true
	_fill_target()
	return true


func _help_second() -> bool:
	if mp:
		return false   # helps are solo only (power-ups come in phase 5)
	if not run_on or phase != "result" or pcts.is_empty():
		return false
	pcts.pop_back()
	_on_retake()
	return true


func _help_time() -> bool:
	if mp:
		return false   # helps are solo only (power-ups come in phase 5)
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


# ---------- multiplayer (phase 4) ----------

func _open_mp_setup() -> void:
	var parts: Array = home.card("👥 " + tr("Host a game"))
	var body: VBoxContainer = parts[1]
	body.add_child(home.section("Where are you playing?"))
	body.add_child(home.choice_row(["Same place", "Far apart"], 0 if mp_settings.place == "local" else 1, _pick_place))
	body.add_child(_small(tr("Same place: rounds up to 90 s. Far apart: up to 150 s.")))
	body.add_child(home.section("Rounds"))
	var counts := [5, 10, 15]
	body.add_child(home.choice_row(["5", "10", "15"], maxi(0, counts.find(int(mp_settings.rounds))), _pick_rounds))
	body.add_child(home.section("Round types"))
	var sels := ["classic", "mixed", "chaos"]
	body.add_child(home.choice_row(["Classic only", "Mixed", "Chaos"], maxi(0, sels.find(mp_settings.selection)), _pick_selection))
	body.add_child(_small(tr("Mixed: a twist about every 3rd round (Duo, Mix, Opposite, Blind, Darkest / Lightest / Most vivid). Chaos: any type, never the same twice.")))
	body.add_child(home.section("Power-ups"))
	body.add_child(home.choice_row(["On", "Off"], 0 if mp_settings.get("powerups", true) else 1, _pick_powerups))
	body.add_child(_small(tr("Everyone starts with one; whoever is last after a round gets another (3 at most per match).")))
	body.add_child(home.section("Object rounds"))
	body.add_child(home.choice_row(["On", "Off"], 0 if mp_settings.get("objects", true) else 1, _pick_objects))
	body.add_child(_small(tr("In Mixed and Chaos: find a teacup, something round, a pentagon... The players vote whether each photo counts.")))
	var go := _big_button("▶ " + tr("Open the table"), _host_now.bind(parts[0]))
	go.modulate = Color(0.6, 1.0, 0.6)
	body.add_child(go)
	home.show_card(parts[0])


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 22)
	return l


func _pick_place(i: int) -> void:
	mp_settings.place = "local" if i == 0 else "remote"


func _pick_rounds(i: int) -> void:
	mp_settings.rounds = [5, 10, 15][i]


func _pick_selection(i: int) -> void:
	mp_settings.selection = ["classic", "mixed", "chaos"][i]


func _pick_objects(i: int) -> void:
	mp_settings.objects = i == 0


func _pick_powerups(i: int) -> void:
	mp_settings.powerups = i == 0


func _host_now(c: Control) -> void:
	home.close_card(c)
	_watch_lobby()
	tbl.host_table(MAX_PLAYERS, tr("%d rounds") % int(mp_settings.rounds))


func _open_join() -> void:
	_watch_lobby()
	tbl.open_lobby()


func _watch_lobby() -> void:
	if not tbl.lobby.visibility_changed.is_connected(_on_lobby_shown):
		tbl.lobby.visibility_changed.connect(_on_lobby_shown)
		tbl.lobby.cancelled.connect(_on_lobby_cancelled)


func _on_lobby_shown() -> void:
	if tbl.lobby.visible:
		home.hide_home()


func _on_lobby_cancelled() -> void:
	if not mp:
		home.show_home()


## OnlineTable's whole-state callback (rejoin / sync).
func _online_state() -> Dictionary:
	return st


func _clock() -> float:
	return Time.get_unix_time_from_system()


## The table's clock: mine plus the offset to the acting host's.
func _now() -> float:
	return _clock() + (0.0 if _am_acting_host() else offset)


func _present() -> Array:
	var out := []
	if tbl == null:
		return out
	for p in tbl.players():
		if bool(p.here) or int(p.n) == tbl.my_player:
			out.append(int(p.n))
	return out


func _am_acting_host() -> bool:
	return mp and tbl != null and Room.acting_host(_present()) == tbl.my_player


func _on_table_started(my_player: int) -> void:
	mp = true
	mode = "online"
	run_on = true
	result_done = false
	home.hide_home()
	_music("play", "lively")
	if not prefs.safety_ok:
		_show_safety()
	if my_player == 1 and not tbl.adopting:
		var seats := []
		for p in tbl.players():
			seats.append(int(p.n))
		_new_table(seats)
	else:
		_show_phase("waiting")
		hint.text = tr("Waiting for the host…")


func _new_table(seats: Array) -> void:
	st = Room.new_match(mp_settings, seats, randi(), _clock())
	thumbs = {}
	result_done = false
	_broadcast()
	_draw_state()


func _broadcast() -> void:
	st.now = _clock()
	tbl.send_event("state", st)


## A state from the table: newer (or same) version wins.
func _take_state(s: Dictionary) -> void:
	if s.is_empty() or not s.has("ver"):
		return
	var new_match: bool = st.is_empty() or int(s.get("match_id", 0)) != int(st.get("match_id", 0))
	if not new_match and int(s.ver) < int(st.ver):
		return
	offset = float(s.get("now", _clock())) - _clock()
	if new_match or int(s.round_i) != int(st.get("round_i", -1)):
		thumbs = {}
		result_done = false if new_match else result_done
	st = s
	mp = true
	_draw_state()


func _on_remote_event(event: String, from: int, p: Dictionary) -> void:
	match event:
		"state":
			_take_state(p)
		"vote":
			if _am_acting_host() and Room.vote(st, from, int(p.get("target", 0)), bool(p.get("yes", false))):
				_broadcast()
				_draw_state()
		"best":
			if _am_acting_host() and Room.best_vote(st, from, int(p.get("target", 0))):
				_broadcast()
				_draw_state()
		"power":
			if _am_acting_host() and Room.use_power(st, from, str(p.get("id", "")), _now()):
				_broadcast()
				_draw_state()
		"lock":
			if _am_acting_host() and Room.lock_in(st, from, p.get("labs", []), _now()):
				_broadcast()
				_draw_state()
		"flag":
			if _am_acting_host() and Room.flag(st, from, int(p.get("target", 0))):
				_broadcast()
				_draw_state()
		"thumb":
			_store_thumb(str(p.get("n", from)), str(p.get("jpg", "")))


func _on_table_status() -> void:
	# Someone came or went: the acting host may now be me.
	if _am_acting_host() and not st.is_empty():
		_broadcast()
	if mp:
		_draw_state(true)


func _store_thumb(key: String, b64: String) -> void:
	if b64 == "":
		return
	var img := Image.new()
	if img.load_jpg_from_buffer(Marshalls.base64_to_raw(b64)) == OK:
		thumbs[key] = ImageTexture.create_from_image(img)
		if phase == "reveal":
			_draw_reveal(false)


func _mp_lock() -> void:
	var labs := []
	for s in samples:
		labs.append([s.x, s.y, s.z])
	var me: int = tbl.my_player
	# Thumbnail: 128 px JPEG of the frozen photo, sent once, dropped after the reveal.
	# Object rounds send 256 px so the others can tell what it is.
	var side := 256 if spec().get("judge", "") == "vote" else 128
	var jpg: PackedByteArray = load(CAM_PATH).thumbnail_jpg(photo, side, 0.7)
	var b64 := Marshalls.raw_to_base64(jpg)
	_store_thumb(str(me), b64)
	tbl.send_event("thumb", {"n": me, "jpg": b64})
	if _am_acting_host():
		if Room.lock_in(st, me, labs, _now()):
			_broadcast()
	else:
		tbl.send_event("lock", {"labs": labs})
	_show_phase("waiting")


func _mp_next() -> void:
	if not _am_acting_host():
		return
	if st.phase == "reveal" and Room.end_reveal(st, _now()):
		_broadcast()
		_draw_state()
	elif st.phase == "final":
		_new_table(st.seats)


func _mp_process() -> void:
	if st.is_empty():
		return
	_update_power_bar()
	var hot: bool = st.phase == "round" and phase == "live" and Room.active(st, tbl.my_player, "hot_cold", _now())
	meter.visible = hot
	if hot:
		_meter_t -= get_process_delta_time()
		if _meter_t <= 0.0 and not _meter_busy:
			_meter_t = METER_EVERY
			_read_meter()
	if _am_acting_host() and Room.tick(st, _present(), _now()):
		_broadcast()
		_draw_state()
	var left := 0.0
	if st.phase == "round":
		left = float(st.deadline) - _now()
	elif st.phase == "reveal":
		left = float(st.reveal_end) - _now()
	elif st.phase == "vote":
		left = float(st.vote_end) - _now()
	elif st.phase == "best":
		left = float(st.best_end) - _now()
	timer_label.text = ("%d" % maxi(0, ceili(left))) if st.phase in ["round", "reveal", "vote", "best"] else ""
	if st.phase == "round" and float(st.first_close_t) >= 0.0 and phase in ["live", "frozen", "preview"]:
		hint.text = tr("Someone is close! %d s left.") % maxi(0, ceili(left))


## Draws whatever the state says; `soft` = only refresh, keep the camera.
func _draw_state(soft: bool = false) -> void:
	if st.is_empty():
		return
	var key := "%s:%d:%s:%d" % [str(st.started), int(st.round_i), str(st.phase), int(st.get("vote_i", 0))]
	var changed := key != shown_phase
	shown_phase = key
	match st.phase:
		"round":
			if changed and not soft:
				_fill_target()
				if st.lockins.has(str(tbl.my_player)) and phase != "live":
					_show_phase("waiting")
				else:
					photo = null
					_start_round_mp()
			else:
				_fill_target()   # a Peek may have shown the swatch
				if phase == "waiting" and not st.lockins.has(str(tbl.my_player)):
					photo = null   # Second Chance: shoot again
					_start_round_mp()
		"vote", "best":
			if cam:
				cam.stop()
			_show_phase(st.phase)
			bar_top.visible = true
			if st.phase == "vote":
				_draw_vote()
			else:
				_draw_best()
		"reveal":
			if cam:
				cam.stop()
			if changed:
				_count_object_win()
			_show_phase("reveal")
			_draw_reveal(changed)
		"final":
			if cam:
				cam.stop()
			thumbs = {}
			_show_phase("final")
			_draw_final()


func _start_round_mp() -> void:
	taps = []
	samples = []
	_show_phase("live")
	_start_camera()


func _award_icons(key: String) -> String:
	var out := ""
	for a in st.awards:
		if str(a.player) == key:
			match str(a.award):
				"first_close":
					out += " ⚡"
				"closest":
					out += " 🥇"
				"superlative":
					out += " 🏆"
				"first_find":
					out += " 🔎"
				"best_find":
					out += " 😂"
	return out


func _draw_reveal(animate: bool) -> void:
	for ch in reveal_box.get_children():
		ch.queue_free()
	var sp := spec()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	reveal_box.add_child(head)
	if sp.judge == "color":
		for i in sp.targets.size():
			var r := ColorRect.new()
			r.color = _target_rgb(i)
			r.custom_minimum_size = Vector2(90, 90)
			head.add_child(r)
	var title := Label.new()
	title.text = target_name.text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	head.add_child(title)
	if sp.colors.size() > 0:
		reveal_box.add_child(_small("💡 " + tr(FAMILY_TIPS.get(E.color_by_id(sp.colors[0])[5], FAMILY_TIPS.neutral))))
	reveal_box.add_child(_small(tr("Photos can show people or private places: tap 🚩 if one shouldn't be here. Most players flag = it's out.")))
	var order := Room.reveal_order(st)
	if order.is_empty():
		reveal_box.add_child(_small(tr("Nobody locked in this round.")))
	for i in order.size():
		var row := _reveal_row(str(order[i]))
		reveal_box.add_child(row)
		if animate:
			row.modulate.a = 0.0
			var tw := row.create_tween()
			tw.tween_interval(REVEAL_STEP * i)
			tw.tween_property(row, "modulate:a", 1.0, 0.35)
	reveal_box.add_child(_scores_line())


func _reveal_row(key: String) -> HBoxContainer:
	var e: Dictionary = st.lockins[key]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var th := TextureRect.new()
	th.custom_minimum_size = Vector2(96, 96)
	th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	th.texture = thumbs.get(key)
	row.add_child(th)
	var labs: Array = e.labs
	for l in labs:
		var sw := ColorRect.new()
		sw.color = E.to_rgb(Vector3(float(l[0]), float(l[1]), float(l[2])))
		sw.custom_minimum_size = Vector2(48, 96)
		row.add_child(sw)
	var out := Room.flagged(st, int(key))
	var name_l := Label.new()
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 26)
	var who: String = tbl.name_of(int(key))
	if out:
		name_l.text = "%s\n🚩 %s" % [who, tr("Flagged: out this round")]
		th.texture = null
	else:
		if spec().judge == "vote":
			var ok_find := Room.valid(st, key)
			name_l.text = "%s\n%s%s" % [who, ("✅ " + tr("Counts")) if ok_find else ("❌ " + tr("Voted down")), _award_icons(key)]
		else:
			name_l.text = "%s\n%d%%%s" % [who, int(e.pct), _award_icons(key)]
	row.add_child(name_l)
	if int(key) != tbl.my_player and not out and st.phase == "reveal":
		var votes: Array = st.flags.get(key, [])
		var fb := Button.new()
		fb.text = "🚩"
		fb.custom_minimum_size = Vector2(64, 64)
		for v in votes:
			if int(v) == tbl.my_player:
				fb.disabled = true
		fb.pressed.connect(_on_flag.bind(int(key)))
		row.add_child(fb)
	return row


func _on_flag(target: int) -> void:
	if _am_acting_host():
		if Room.flag(st, tbl.my_player, target):
			_broadcast()
			_draw_reveal(false)
	else:
		tbl.send_event("flag", {"target": target})


func _scores_line() -> Label:
	var parts := []
	for s in Room.standings(st):
		parts.append("%s %d" % [tbl.name_of(int(s[0])), int(s[1])])
	var l := _small("🏁 " + " · ".join(parts))
	l.add_theme_font_size_override("font_size", 24)
	return l


func _draw_final() -> void:
	for ch in reveal_box.get_children():
		ch.queue_free()
	var stand := Room.standings(st)
	var top: int = stand[0][1] if not stand.is_empty() else 0
	var winners := 0
	for s in stand:
		if int(s[1]) == top:
			winners += 1
	var title := Label.new()
	title.text = "🏆 " + tr("Final scores")
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reveal_box.add_child(title)
	for s in stand:
		var l := Label.new()
		l.text = "%s %s: %d" % ["🥇" if int(s[1]) == top else "▫", tbl.name_of(int(s[0])), int(s[1])]
		l.add_theme_font_size_override("font_size", 32)
		reveal_box.add_child(l)
	if not result_done and info:
		result_done = true
		var mine := int(st.scores.get(str(tbl.my_player), 0))
		info.result("win" if mine == top and winners == 1 else ("draw" if mine == top else "loss"))
		if mine == top and winners == 1 and int(st.get("used", {}).get(str(tbl.my_player), 0)) == 0:
			info.add("Wins without power-ups")
	if not _am_acting_host():
		reveal_box.add_child(_small(tr("The host can start another match.")))
	reveal_box.add_child(_big_button("🏠 " + tr("Home"), _go_home))


# ---------- power-ups (phase 5; multiplayer only) ----------

## The bar of my power-ups; rebuilt only when what it shows changes.
func _update_power_bar() -> void:
	var held: Array = st.get("powers", {}).get(str(tbl.my_player), []) if mp else []
	var show: bool = mp and st.phase == "round" and phase in ["live", "frozen", "preview", "waiting"] and not held.is_empty()
	var usable := []
	for id in held:
		usable.append(Powers.can_use(st, tbl.my_player, id, _now()))
	var key := "%s|%s|%s" % [str(show), str(held), str(usable)]
	if key == _power_key:
		return
	_power_key = key
	power_bar.visible = show
	for ch in power_bar.get_children():
		ch.queue_free()
	if not show:
		return
	for i in held.size():
		var id: String = held[i]
		var pw: Dictionary = Powers.POWERS.get(id, {})
		var b := Button.new()
		b.text = "%s %s" % [pw.get("icon", "?"), tr(pw.get("name", id))]
		b.custom_minimum_size = Vector2(0, 60)
		b.add_theme_font_size_override("font_size", 22)
		b.disabled = not usable[i]
		b.pressed.connect(_use_power.bind(id))
		power_bar.add_child(b)


func _use_power(id: String) -> void:
	_sfx("tap")
	if _am_acting_host():
		if Room.use_power(st, tbl.my_player, id, _now()):
			_broadcast()
			_draw_state()
	else:
		tbl.send_event("power", {"id": id})
	if id == "hot_cold":
		_meter_t = 0.0
		hint.text = tr("Hot / Cold: aim the middle of the screen.")


# ---------- Object rounds: the players' vote (phase 6) ----------

func _draw_vote() -> void:
	for ch in reveal_box.get_children():
		ch.queue_free()
	var key := Room.voting_on(st)
	if key == "":
		return
	var prompt := E.object_text(str(spec().prompt), _es())
	var q := Label.new()
	q.text = tr("Is this %s?") % prompt
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.add_theme_font_size_override("font_size", 34)
	reveal_box.add_child(q)
	reveal_box.add_child(_small("%s · %d / %d" % [tbl.name_of(int(key)), int(st.vote_i) + 1, st.vote_order.size()]))
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(0, 380)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture = thumbs.get(key)
	reveal_box.add_child(pic)
	var out := Room.flagged(st, int(key))
	if out:
		pic.texture = null
		reveal_box.add_child(_small("🚩 " + tr("Flagged: out this round")))
	var votes: Dictionary = st.votes.get(key, {})
	var me := str(tbl.my_player)
	if key == me:
		reveal_box.add_child(_small(tr("The others are voting on your photo.")))
	elif votes.has(me):
		reveal_box.add_child(_small(tr("Voted. Waiting for the others…")))
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		var yes := _big_button("👍 " + tr("Yes"), _on_vote.bind(int(key), true))
		yes.modulate = Color(0.6, 1.0, 0.6)
		row.add_child(yes)
		row.add_child(_big_button("👎 " + tr("No"), _on_vote.bind(int(key), false)))
		reveal_box.add_child(row)
	if key != me and not out:
		reveal_box.add_child(_small(tr("A person in it, or something that shouldn't be here? Tap 🚩.")))
		var fb := _big_button("🚩 " + tr("Flag"), _on_flag.bind(int(key)))
		for v in st.flags.get(key, []):
			if int(v) == tbl.my_player:
				fb.disabled = true
		reveal_box.add_child(fb)


func _on_vote(target: int, yes: bool) -> void:
	_sfx("tap")
	if _am_acting_host():
		if Room.vote(st, tbl.my_player, target, yes):
			_broadcast()
			_draw_state()
	else:
		tbl.send_event("vote", {"target": target, "yes": yes})
		# Shown as voted at once; the host's next state confirms it.
		var v: Dictionary = st.votes.get(str(target), {})
		v[str(tbl.my_player)] = yes
		st.votes[str(target)] = v
		_draw_vote()


func _draw_best() -> void:
	for ch in reveal_box.get_children():
		ch.queue_free()
	var q := Label.new()
	q.text = "😂 " + tr("Best find? Pick your favourite.")
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.add_theme_font_size_override("font_size", 32)
	reveal_box.add_child(q)
	var me := str(tbl.my_player)
	var choices := Room._best_choices(st, tbl.my_player)
	if st.best.has(me):
		reveal_box.add_child(_small(tr("Voted. Waiting for the others…")))
		return
	if choices.is_empty():
		reveal_box.add_child(_small(tr("No other photo counts this round.")))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	reveal_box.add_child(grid)
	for k in choices:
		var b := Button.new()
		b.custom_minimum_size = Vector2(240, 260)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = thumbs.get(k)
		b.expand_icon = true
		b.text = tbl.name_of(int(k))
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.pressed.connect(_on_best.bind(int(k)))
		grid.add_child(b)


func _on_best(target: int) -> void:
	_sfx("tap")
	if _am_acting_host():
		if Room.best_vote(st, tbl.my_player, target):
			_broadcast()
			_draw_state()
	else:
		tbl.send_event("best", {"target": target})
		st.best[str(tbl.my_player)] = target
		_draw_best()


## An Object-round award for me (First or Best Find) counts once per round.
var _object_win_round := ""


func _count_object_win() -> void:
	if not info or spec().get("judge", "") != "vote":
		return
	var key := "%s:%d" % [str(st.get("match_id", 0)), int(st.round_i)]
	if key == _object_win_round:
		return
	for a in st.awards:
		if str(a.player) == str(tbl.my_player):
			_object_win_round = key
			info.add("Object rounds won")
			return
