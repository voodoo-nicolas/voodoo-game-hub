extends PanelContainer

## Beached: the debug panel (KICKOFF M0: "essential: time-heavy games cannot be tested without it").
## Time scale x1 / x60 / x3600, jump the clock to an hour, catch up N hours as if away, set bars,
## spawn items, force weather, flip the hemisphere, reset the save. Opens with F9 or five quick taps
## on the clock. DEV TOOL: hide it before the first public pack (docs/wilson/DECISIONS.md).

const D = preload("res://scripts/games/wilson/wilson_data.gd")

var game  # wilson_game.gd
var _sliders := {}
var _scale_btns := []
var _item_pick: OptionButton
var _weather_pick: OptionButton
var _info: Label

func setup(g) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.1, 0.94)
	sb.border_color = Color("ffb35a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "🛠 Debug"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(hide)
	head.add_child(close)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 18)
	col.add_child(_info)

	col.add_child(_heading("Time scale"))
	var row := HBoxContainer.new()
	col.add_child(row)
	for s in [1, 60, 3600]:
		var b := Button.new()
		b.text = "x%d" % s
		b.toggle_mode = true
		b.pressed.connect(_on_scale.bind(s))
		row.add_child(b)
		_scale_btns.append([b, s])

	col.add_child(_heading("Set clock hour (jumps forward, counts as away)"))
	var grid := GridContainer.new()
	grid.columns = 4
	col.add_child(grid)
	for h in [0, 3, 6, 9, 12, 15, 18, 20, 21, 22, 23, 5]:
		var b := Button.new()
		b.text = "%02d:00" % h
		b.pressed.connect(_on_hour.bind(h))
		grid.add_child(b)
	var row2 := GridContainer.new()
	row2.columns = 2
	col.add_child(row2)
	for hrs in [1, 8, 48]:
		var b := Button.new()
		b.text = "+%d h away" % hrs
		b.pressed.connect(_on_away.bind(hrs))
		row2.add_child(b)
	var now_b := Button.new()
	now_b.text = "Real time"
	now_b.pressed.connect(_on_real)
	row2.add_child(now_b)

	col.add_child(_heading("Bars"))
	for k in ["hp", "food", "water", "energy"]:
		var r := HBoxContainer.new()
		col.add_child(r)
		var l := Label.new()
		l.text = k
		l.custom_minimum_size = Vector2(80, 0)
		r.add_child(l)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 100
		s.step = 1
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(220, 36)
		s.value_changed.connect(_on_bar.bind(k))
		r.add_child(s)
		_sliders[k] = s

	col.add_child(_heading("Spawn items"))
	var r3 := HBoxContainer.new()
	col.add_child(r3)
	_item_pick = OptionButton.new()
	_item_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in D.items():
		_item_pick.add_item(id)
	r3.add_child(_item_pick)
	for n in [1, 10]:
		var b := Button.new()
		b.text = "+%d" % n
		b.pressed.connect(_on_give.bind(n))
		r3.add_child(b)
	var kit := Button.new()
	kit.text = "Starter kit (tier 1-2 mats)"
	kit.pressed.connect(_on_kit)
	col.add_child(kit)

	col.add_child(_heading("Weather (auto = the seeded controller)"))
	_weather_pick = OptionButton.new()
	_weather_pick.add_item("auto (controller)")
	for w in D.WEATHER:
		_weather_pick.add_item(w)
	_weather_pick.item_selected.connect(_on_weather)
	col.add_child(_weather_pick)
	var hemi := Button.new()
	hemi.text = "Flip hemisphere"
	hemi.pressed.connect(_on_hemi)
	col.add_child(hemi)
	var fin := Button.new()
	fin.text = "Finish current action now"
	fin.pressed.connect(_on_finish)
	col.add_child(fin)
	var reset := Button.new()
	reset.text = "⚠ Reset save (new island)"
	reset.add_theme_color_override("font_color", Color("ff8a7a"))
	reset.pressed.connect(_on_reset)
	col.add_child(reset)

func _heading(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color("ffb35a"))
	l.add_theme_font_size_override("font_size", 18)
	return l

func refresh() -> void:
	if not visible or game.engine == null:
		return
	var e = game.engine
	for k in _sliders:
		_sliders[k].set_value_no_signal(e.bars[k])
	for pair in _scale_btns:
		pair[0].set_pressed_no_signal(int(pair[1]) == int(game.time_scale))
	var ph: float = game.Astro.moon_phase(e.t)
	_info.text = "%s  day %d  %s  doy %d  %s\nsunrise %.2f  sunset %.2f  moon %.3f  weather %s%s  tide %.2f\nmood %d  queue %d  t=%d" % [
		Time.get_datetime_string_from_unix_time(int(e.local_t()), true), e.day_number(), e.hemisphere, e.doy(),
		"day" if e.is_day() else "night", e.sunrise_h(), e.sunset_h(), ph, e.weather, "" if e.weather_auto else " (forced)", e.tide_level(), int(e.mood), e.queue.size(), int(e.t)]
	_weather_pick.select(0 if e.weather_auto else 1 + D.WEATHER.find(e.weather))

func _on_scale(s: int) -> void:
	game.time_scale = float(s)
	game.save_debug()

func _on_hour(h: int) -> void:
	var e = game.engine
	var target: float = e.next_hour(float(h))
	game.clock_offset += target - e.t
	game.catch_up(false)
	game.save_debug()

func _on_away(hrs: int) -> void:
	game.clock_offset += hrs * 3600.0
	game.catch_up(false)
	game.save_debug()

func _on_real() -> void:
	game.clock_offset = maxf(0.0, game.engine.t - Time.get_unix_time_from_system()) if game.engine else 0.0
	game.time_scale = 1.0
	game.save_debug()

func _on_bar(v: float, k: String) -> void:
	game.engine.debug_set_bar(k, v)

func _on_give(n: int) -> void:
	game.engine.debug_give(_item_pick.get_item_text(_item_pick.selected), n)
	game.after_change()

func _on_kit() -> void:
	for pair in [["stick", 20], ["stone", 20], ["frond", 30], ["dry_frond", 5], ["rope", 12], ["husk_fiber", 12],
			["sailcloth", 1], ["trunk", 2], ["coconut", 4], ["fish_small", 3]]:
		game.engine.debug_give(pair[0], pair[1])
	game.after_change()

func _on_weather(i: int) -> void:
	if i == 0:
		game.engine.weather_auto = true
		game.engine._weather_tick()
	else:
		game.engine.weather_auto = false
		game.engine.weather = D.WEATHER[i - 1]
	game.after_change()

func _on_hemi() -> void:
	var e = game.engine
	e.hemisphere = "north" if e.hemisphere == "south" else "south"
	game.after_change()

func _on_finish() -> void:
	game.hurry()

func _on_reset() -> void:
	hide()
	game.new_island()
