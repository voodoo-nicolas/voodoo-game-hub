extends Control

## Replays one recorded hand (video_poker_replay.gd): the table drawn by the
## same view as live play, a line saying what just happened, and buttons to
## step back and forward, jump to the start / end or play it through. ⭐
## bookmarks the hand.

signal closed()
signal bookmark_toggled(at: int)

const View = preload("res://scripts/games/video_poker/video_poker_view.gd")
const Replay = preload("res://scripts/games/video_poker/video_poker_replay.gd")
const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const HomeKit = preload("res://scripts/games/video_poker/home_kit.gd")

## Seconds between steps when playing through.
const STEP_SECONDS := 1.4

var rec: Dictionary = {}
var frames: Array = []
var at := 0
var view: Control
var title_label: Label
var caption_label: Label
var step_label: Label
var star_btn: Button
var play_btn: Button
var timer: Timer
var root_box: BoxContainer     # portrait: bar, table, controls stacked; landscape: table left, the rest in side_box
var side_box: VBoxContainer
var top_box: MarginContainer
var low_box: MarginContainer
var landscape := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(HomeKit.backdrop())
	var col := BoxContainer.new()
	col.vertical = true
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box = col
	side_box = VBoxContainer.new()
	side_box.visible = false
	col.add_child(side_box)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_child(gap)
	var top := MarginContainer.new()
	top_box = top
	top.add_theme_constant_override("margin_top", 16)
	top.add_theme_constant_override("margin_left", 14)
	top.add_theme_constant_override("margin_right", 14)
	col.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var back := HomeKit.neon_button("⬅", HomeKit.DIM, 30, 60)
	back.custom_minimum_size.x = 72
	back.pressed.connect(_close)
	bar.add_child(back)
	title_label = HomeKit.label("", 20, HomeKit.WHITE, false, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	bar.add_child(title_label)
	star_btn = Button.new()
	star_btn.text = "☆"
	star_btn.custom_minimum_size = Vector2(72, 60)
	star_btn.pressed.connect(_on_star)
	bar.add_child(star_btn)
	view = View.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(view)
	var pm := MarginContainer.new()
	low_box = pm
	for side in ["left", "right"]:
		pm.add_theme_constant_override("margin_" + side, 14)
	pm.add_theme_constant_override("margin_bottom", 22)
	col.add_child(pm)
	var low := VBoxContainer.new()
	low.add_theme_constant_override("separation", 8)
	pm.add_child(low)
	caption_label = HomeKit.label("", 24, HomeKit.WHITE, true, true)
	caption_label.custom_minimum_size.y = 62
	low.add_child(caption_label)
	step_label = HomeKit.label("", 20, HomeKit.DIM, false, true)
	low.add_child(step_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	low.add_child(row)
	for spec in [["⏮", _first], ["◀", _prev], ["", _toggle_play], ["▶", _next], ["⏭", _last]]:
		var b := HomeKit.neon_button(spec[0], HomeKit.CYAN, 28, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.pressed.connect(spec[1])
		row.add_child(b)
		if spec[0] == "":
			play_btn = b
			b.text = "▶▶"
	resized.connect(_fit)
	col.move_child(side_box, col.get_child_count() - 1)  # after the table: the right-hand column
	timer = Timer.new()
	timer.wait_time = STEP_SECONDS
	timer.timeout.connect(_tick)
	add_child(timer)

## Wider than tall: the table fills the left and the title, words and buttons
## stand in a column at the right.
func _fit() -> void:
	var land := size.x > size.y * 1.1
	if land == landscape:
		return
	landscape = land
	root_box.vertical = not land
	side_box.visible = land
	if land:
		top_box.reparent(side_box, false)
		side_box.move_child(top_box, 0)
		low_box.reparent(side_box, false)
		side_box.custom_minimum_size.x = 360
	else:
		top_box.reparent(root_box, false)
		root_box.move_child(top_box, 0)
		low_box.reparent(root_box, false)
		root_box.move_child(low_box, 2)
		side_box.custom_minimum_size.x = 0

func open(record: Dictionary, bookmarked: bool) -> void:
	_fit()
	rec = record
	frames = Replay.frames(record)
	at = 0
	view.hide_viewer = false
	view.viewer = maxi(0, int(record.get("hero", 0)))
	view.you_text = "You"
	timer.stop()
	play_btn.text = "▶▶"
	var rules = Table.rules_for(str(record.get("variant", "holdem")))
	title_label.text = "%s  ·  %s" % [tr(rules.short_title()), tr("Hand %d") % int(record.get("n", 0))]
	star_btn.text = "⭐" if bookmarked else "☆"
	_show()

func _show() -> void:
	if frames.is_empty():
		return
	var f: Dictionary = frames[at]
	view.t = f.t
	view.queue_redraw()
	var last := at == frames.size() - 1
	caption_label.text = _result_text(f.t) if last else (str(f.caption) if str(f.caption) != "" else tr("The deal."))
	step_label.text = tr("Pot %s") % View._chips(int(f.t.pot_total())) if not last else tr("Final pot %s") % View._chips(int(rec.get("pot", 0)))
	step_label.text += "   ·   %d / %d" % [at, frames.size() - 1]

## Who won what, in words.
func _result_text(t) -> String:
	var lines: Array = []
	for r in t.results:
		if int(r.won) <= 0:
			continue
		var name := str(t.seats[int(r.seat)].name)
		var amount := View._chips(int(r.won))
		var mine: bool = name == ""
		if str(r.desc) != "":
			lines.append(tr("You win %s with %s.") % [amount, str(r.desc)] if mine else tr("%s wins %s with %s.") % [name, amount, str(r.desc)])
		else:
			lines.append(tr("You win %s.") % amount if mine else tr("%s wins %s.") % [name, amount])
	return "\n".join(lines.slice(0, 3))

func _first() -> void:
	timer.stop()
	play_btn.text = "▶▶"
	at = 0
	_show()

func _prev() -> void:
	timer.stop()
	play_btn.text = "▶▶"
	at = maxi(0, at - 1)
	_show()

func _next() -> void:
	timer.stop()
	play_btn.text = "▶▶"
	at = mini(frames.size() - 1, at + 1)
	_show()

func _last() -> void:
	timer.stop()
	play_btn.text = "▶▶"
	at = frames.size() - 1
	_show()

func _toggle_play() -> void:
	if timer.is_stopped():
		if at >= frames.size() - 1:
			at = 0
			_show()
		timer.start()
		play_btn.text = "⏸"
	else:
		timer.stop()
		play_btn.text = "▶▶"

func _tick() -> void:
	if at >= frames.size() - 1:
		timer.stop()
		play_btn.text = "▶▶"
		return
	at += 1
	_show()
	if at >= frames.size() - 1:
		timer.stop()
		play_btn.text = "▶▶"

func _on_star() -> void:
	star_btn.text = "☆" if star_btn.text == "⭐" else "⭐"
	bookmark_toggled.emit(int(rec.get("at", 0)))

func _close() -> void:
	timer.stop()
	closed.emit()
