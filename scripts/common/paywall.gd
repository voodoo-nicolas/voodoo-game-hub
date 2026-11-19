extends Control

## The store's one screen (docs/monetization/PLAN.md): a card over whatever is
## showing, opened by Store.gate() for a game that isn't unlocked, or by
## Options' "Get all games" with no game. Built and styled like the hub's own
## dialogs (neon card, Settings.palette()), sized from the viewport.
##
## What it offers depends on Store.access(game).state:
##   signed_out  -> Sign in (trials and purchases need an account)
##   new         -> Start the free trial, or buy now
##   trial_over  -> All games (recommended), or just this game
##   {} (no game) -> the subscription, Restore purchases
## Every purchase goes through Google Play; when the purchase is verified (or
## the trial starts) the card closes and `on_allowed` opens the game.

const Brand = preload("res://scripts/common/brand.gd")

var game: Dictionary
var on_allowed: Callable
var pal: Dictionary
var box: VBoxContainer
var status_label: Label
var _buttons: Array = []
var _done: bool = false

func _init(for_game: Dictionary, allowed: Callable = Callable()) -> void:
	game = for_game
	on_allowed = allowed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("modal_overlay")  # the hub list behind doesn't drag-scroll
	pal = Settings.palette()
	Store.changed.connect(_on_store_changed)
	Store.purchase_failed.connect(_on_failed)
	_build()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_close()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_buttons.clear()
	var dim := ColorRect.new()
	dim.color = pal.overlay
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = pal.card_fill
	sb.border_color = pal.accent
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(pal.accent, 0.45 * float(pal.glow))
	sb.shadow_size = 22
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(minf(560.0, get_viewport_rect().size.x - 80.0), 0)
	panel.add_child(box)

	var a: Dictionary = Store.access(game) if not game.is_empty() else {"state": "hub"}
	var title := Lang.pick(game, "title") if not game.is_empty() else ""
	var count := Store.game_count()

	if not game.is_empty():
		_label(str(game.get("icon", "🎮")), 64, pal.text)
		_label(title, 40, pal.accent)

	match a.state:
		"signed_out":
			_label(tr("Sign in to play %s free for %d days.") % [title, _trial_days()], 28, pal.card_message)
			_button(tr("Sign In"), "ready", _sign_in)
		"new":
			_label(tr("Play free for %d days. Then get all %d games, or keep just this one for %s.") % [
					_trial_days(), count, Store.price(Store.game_product(game.id))], 28, pal.card_message)
			# Trial length + end date (owner 2026-11-19: the paywall shows both).
			_label(tr("Free trial: %d days, ends %s. No card needed.") % [_trial_days(), Store.trial_end_text(_trial_days())], 22, pal.text_dim)
			_button(tr("▶ Start %d-day free trial") % _trial_days(), "ready", _start_trial)
			_buy_buttons(title, count)
		"trial_over":
			_label(tr("Your free trial of %s has ended. Keep playing:") % title, 28, pal.card_message)
			_buy_buttons(title, count)
		"subscribed", "owned", "trial", "free", "open":
			_label(tr("You can play this game."), 28, pal.card_message)
		_:  # no game: the membership offer
			_label(tr("⭐ All %d games") % count, 40, pal.accent)
			if Store.is_subscribed():
				_label(tr("You're a member. Thanks for supporting %s!") % Brand.NAME, 28, pal.card_message)
				_button(tr("Manage subscription"), "link", Store.manage_subscription)
			else:
				_label(tr("Every game in the hub, and every new one we add."), 28, pal.card_message)
				_buy_buttons("", count)

	status_label = _label("", 24, pal.update)
	status_label.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	if a.state != "signed_out":
		var restore := _button(tr("Restore purchases"), "", _restore, row)
		restore.add_theme_font_size_override("font_size", 22)
	var later := _button(tr("Not now"), "", _close, row)
	later.add_theme_font_size_override("font_size", 22)

## The hub first, as the recommended choice (PLAN.md: the games are its
## marketing), then the single game as the quieter option.
func _buy_buttons(title: String, count: int) -> void:
	if title != "":
		_label(tr("Best value").to_upper(), 20, pal.update)
	# On the membership card the heading already says "All 100 games".
	_button(tr("⭐ All %d games") % count if title != "" else tr("⭐ Get all games"), "update", _subscribe)
	if title != "":
		_label(tr("Every game in the hub, and every new one we add."), 22, pal.card_message)
	_label(Store.subscription_terms(), 22, pal.text_dim)
	var hub_trial := Store.hub_trial_days()
	if hub_trial > 0:
		_label(tr("%d-day free trial, ends %s. You won't be charged if you cancel before then.") % [
				hub_trial, Store.trial_end_text(hub_trial)], 20, pal.text_dim)
	_label(tr("Renews monthly. Cancel any time in Google Play."), 20, pal.text_dim)
	if title != "":
		_button(tr("🔓 Just %s — %s/month") % [title, Store.price(Store.game_product(game.id))], "", _buy_game)
		_label(tr("Renews monthly. Cancel any time in Google Play."), 20, pal.text_dim)
	if not Store.can_buy():
		_label(tr("Purchases work in the Play Store version of %s.") % Brand.NAME, 22, pal.update)

func _trial_days() -> int:
	return int(Store.config().get("trial_days", Store.DEFAULT_TRIAL_DAYS))

# ---------- actions ----------

func _start_trial() -> void:
	_busy(tr("Starting your trial..."))
	Store.start_trial(str(game.id), _on_trial)

func _on_trial(ok: bool) -> void:
	if ok:
		_open_game()
	else:
		_show(tr("Sign in first, so your purchase follows you to every device."))

func _buy_game() -> void:
	_busy(tr("Waiting for Google Play..."))
	Store.buy_game(str(game.id))

func _subscribe() -> void:
	_busy(tr("Waiting for Google Play..."))
	Store.subscribe()

func _restore() -> void:
	_busy(tr("Checking your purchases..."))
	Store.restore()

func _sign_in() -> void:
	get_tree().change_scene_to_file("res://scenes/account/account.tscn")

func _on_store_changed() -> void:
	if _done:
		return
	if game.is_empty():
		_build()
	elif Store.access(game).allowed:
		_open_game()

func _on_failed(message: String) -> void:
	_show(message)

func _open_game() -> void:
	if _done:
		return
	_done = true
	queue_free()
	if on_allowed.is_valid():
		on_allowed.call()

func _close() -> void:
	_done = true
	queue_free()

func _busy(text: String) -> void:
	for b in _buttons:
		b.disabled = true
	_show(text)

## "" = the player backed out of Google's sheet: just re-enable.
func _show(text: String) -> void:
	for b in _buttons:
		b.disabled = false
	status_label.text = text
	status_label.visible = text != ""

# ---------- building blocks ----------

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return l

## A neon button in a palette colour ("" = the quiet outline style).
func _button(text: String, color_key: String, action: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(0, 72 if color_key != "" else 60)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 28)
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var color: Color = pal[color_key] if color_key != "" else pal.text_dim
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(color, 0.22 if state == "pressed" else 0.12) if color_key != "" else Color(0, 0, 0, 0)
		s.border_color = Color(color, 0.4 if state == "disabled" else 1.0)
		s.set_border_width_all(2)
		s.set_corner_radius_all(16)
		s.shadow_color = Color(color, 0.35 * float(pal.glow)) if color_key != "" else Color(0, 0, 0, 0)
		s.shadow_size = 10
		s.content_margin_left = 16
		s.content_margin_right = 16
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", pal.text)
	b.add_theme_color_override("font_disabled_color", Color(pal.text, 0.4))
	b.pressed.connect(action)
	(parent if parent else box).add_child(b)
	_buttons.append(b)
	return b
