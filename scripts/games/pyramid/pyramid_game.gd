extends Control

## Pyramid Solitaire -- tap two uncovered cards that add up to 13 (a King goes
## alone). Tap the stock to turn a card onto the waste pile.

const PyrEngine = preload("res://scripts/games/pyramid/pyramid_engine.gd")
const Cards = preload("res://scripts/games/pyramid/pyramid_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")

const COLOR_FELT := Color(0.05, 0.3, 0.17)
const WASTE := 100
const STOCK := 200

var engine: PyrEngine
var board: Control
var info_label: Label
var end_dialog: ColorRect
var selected: int = -1

func _ready() -> void:
	preload("res://scripts/games/pyramid/pyramid_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = PyrEngine.new()
	_build_ui()
	_start_new_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = COLOR_FELT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🔺 Pyramid")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = tr("New")
	new_btn.add_theme_font_size_override("font_size", 26)
	new_btn.pressed.connect(_start_new_game)
	bar.add_child(new_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 22)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(info_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 30)
	cm.add_child(controls)
	root.add_child(cm)
	var undo_btn := Button.new()
	undo_btn.text = tr("↶ Undo")
	undo_btn.custom_minimum_size = Vector2(220, 68)
	undo_btn.add_theme_font_size_override("font_size", 26)
	undo_btn.pressed.connect(_on_undo)
	controls.add_child(undo_btn)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("↶ Undo"), "action": _on_undo},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(end_dialog)
	add_child(SettingsDrawer.new())

func _start_new_game() -> void:
	engine.new_game()
	selected = -1
	end_dialog.visible = false
	_refresh()

func _on_undo() -> void:
	engine.undo()
	selected = -1
	end_dialog.visible = false
	_refresh()

func _refresh() -> void:
	info_label.text = tr("Pairs that add to 13 · J=11 Q=12 K=13\nPass %d of %d · %d left in the pyramid") % [
		engine.pass_no, PyrEngine.PASSES, 28 - engine.pyramid.count(-1)]
	board.queue_redraw()
	if engine.is_won():
		end_dialog.get_meta("message_label").text = tr("You cleared the pyramid!")
		end_dialog.visible = true
	elif engine.is_stuck():
		end_dialog.get_meta("message_label").text = tr("No moves left.")
		end_dialog.visible = true

# ---------- geometry ----------

func _card_size() -> Vector2:
	var w: float = floor(min((board.size.x - 20.0) / 7.3, (board.size.y - 20.0) / 7.2))
	return Vector2(w, floor(w * 1.4))

func _slot_rect(p: int) -> Rect2:
	var cs := _card_size()
	var r := PyrEngine._row_of(p)
	var i := p - PyrEngine.index(r, 0)
	var gap := cs.x * 1.04
	var x := board.size.x / 2.0 - (r + 1) * gap / 2.0 + i * gap
	return Rect2(Vector2(x, 8 + r * cs.y * 0.5), cs)

func _stock_rect() -> Rect2:
	var cs := _card_size()
	var y := 8 + 6 * cs.y * 0.5 + cs.y + 30.0
	return Rect2(Vector2(board.size.x / 2.0 - cs.x * 1.3, y), cs)

func _waste_rect() -> Rect2:
	var cs := _card_size()
	var s := _stock_rect()
	return Rect2(s.position + Vector2(cs.x * 1.6, 0), cs)

func _draw_board() -> void:
	if engine.pyramid.is_empty():
		return
	for p in 28:
		if engine.pyramid[p] == -1:
			continue
		var free := engine.is_free(p)
		Cards.draw_card(board, _slot_rect(p), engine.pyramid[p], true, p == selected, not free)
	if engine.stock.is_empty():
		Cards.draw_card(board, _stock_rect(), -1)
		if engine.can_draw():
			board.draw_string(ThemeDB.fallback_font, _stock_rect().position + Vector2(0, _stock_rect().size.y * 0.6), "↺",
				HORIZONTAL_ALIGNMENT_CENTER, _stock_rect().size.x, 40, Color(1, 1, 1, 0.6))
	else:
		Cards.draw_card(board, _stock_rect(), 0, false)
	var w := _waste_rect()
	if engine.waste.is_empty():
		Cards.draw_card(board, w, -1)
	else:
		Cards.draw_card(board, w, engine.waste.back(), true, selected == WASTE)
	var font: Font = ThemeDB.fallback_font
	board.draw_string(font, _stock_rect().position + Vector2(0, _stock_rect().size.y + 26), tr("Stock: %d") % engine.stock.size(),
		HORIZONTAL_ALIGNMENT_CENTER, _stock_rect().size.x, 20, Color(0.85, 0.9, 0.85))

func _slot_at(pos: Vector2) -> int:
	if _stock_rect().has_point(pos):
		return STOCK
	if _waste_rect().has_point(pos):
		return WASTE
	# topmost (lowest row drawn last) first
	for p in range(27, -1, -1):
		if engine.pyramid[p] != -1 and _slot_rect(p).has_point(pos):
			return p
	return -1

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if end_dialog.visible:
		return
	var slot := _slot_at(event.position)
	if slot == STOCK:
		selected = -1
		engine.draw()
		_refresh()
		return
	if slot == -1 or engine.card_at(slot) == -1:
		selected = -1
		board.queue_redraw()
		return
	if PyrEngine.rank(engine.card_at(slot)) == 13:
		engine.try_remove(slot)
		selected = -1
	elif selected == -1 or selected == slot:
		selected = -1 if selected == slot else slot
	elif engine.try_remove(selected, slot):
		selected = -1
	else:
		selected = slot
	_refresh()
