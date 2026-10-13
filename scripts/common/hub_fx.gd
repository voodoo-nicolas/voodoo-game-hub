extends RefCounted

## Motion for the hub's menus (APK-side only): a slowly drifting background
## ("Ken Burns" zoom + pan), rising embers, staggered entrances, a breathing
## logo / pulsing main button, and a press "pop" on every button of a hub
## screen. All of it stops when Options > Reduce motion is on
## (`Settings.reduce_motion`), and every effect is a Tween / CPUParticles2D
## on the node itself, so it dies with the screen.

## Drift on a full-rect picture: zooms 1.0 -> 1.0+`zoom` and pans a little,
## back and forth forever.
static func drift(ctrl: Control, zoom: float = 0.07, seconds: float = 20.0) -> void:
	if _still(ctrl):
		return
	ctrl.pivot_offset_ratio = Vector2(0.5, 0.5)
	var t := ctrl.create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.set_parallel(true)
	t.tween_property(ctrl, "scale", Vector2.ONE * (1.0 + zoom), seconds)
	t.tween_property(ctrl, "position", Vector2(-14, -10), seconds)
	t.chain().set_parallel(true)
	t.tween_property(ctrl, "scale", Vector2.ONE, seconds)
	t.tween_property(ctrl, "position", Vector2.ZERO, seconds)

## A gentle in-and-out of size and brightness (the logo, the Games button).
static func breathe(ctrl: Control, grow: float = 0.025, glow: float = 0.0, seconds: float = 2.6, delay: float = 1.0) -> void:
	if _still(ctrl):
		return
	ctrl.pivot_offset_ratio = Vector2(0.5, 0.5)
	# Waits `delay` so an entrance (stagger_in) on the same node finishes first.
	var start := ctrl.create_tween()
	start.tween_interval(delay)
	start.tween_callback(_start_breathe.bind(ctrl, grow, glow, seconds))

static func _start_breathe(ctrl: Control, grow: float, glow: float, seconds: float) -> void:
	if not is_instance_valid(ctrl):
		return
	var t := ctrl.create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.set_parallel(true)
	t.tween_property(ctrl, "scale", Vector2.ONE * (1.0 + grow), seconds)
	t.tween_property(ctrl, "modulate", Color(1.0 + glow, 1.0 + glow, 1.0 + glow, 1.0), seconds)
	t.chain().set_parallel(true)
	t.tween_property(ctrl, "scale", Vector2.ONE, seconds)
	t.tween_property(ctrl, "modulate", Color.WHITE, seconds)

## Fade + grow-in, one after another. `nodes` are Controls; only the first
## `max_count` are delayed, the rest appear with the last one.
static func stagger_in(nodes: Array, step: float = 0.055, max_count: int = 14, from_scale: float = 0.94) -> void:
	if nodes.is_empty() or _still(nodes[0]):
		return
	var i := 0
	for n in nodes:
		if not (n is Control) or not is_instance_valid(n):
			continue
		var c := n as Control
		c.pivot_offset_ratio = Vector2(0.5, 0.5)
		c.modulate.a = 0.0
		c.scale = Vector2.ONE * from_scale
		var t := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var delay := step * mini(i, max_count)
		t.tween_property(c, "modulate:a", 1.0, 0.28).set_delay(delay)
		t.tween_property(c, "scale", Vector2.ONE, 0.32).set_delay(delay)
		i += 1

## Slow sparks rising over `parent` (full rect): warm orange and cyan to match
## the hub art. Cheap (CPU particles, ~26 of them).
static func embers(parent: Control) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	if _still(parent):
		p.emitting = false
		return p
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.72, 0.35, 0.0))
	grad.add_point(0.2, Color(1.0, 0.62, 0.25, 0.85))
	grad.add_point(0.7, Color(0.45, 0.9, 1.0, 0.55))
	grad.set_color(grad.get_point_count() - 1, Color(0.45, 0.9, 1.0, 0.0))
	p.color_ramp = grad
	p.texture = _dot()
	p.amount = 26
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0.15, -1.0)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 46.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	return p

## Emit along the bottom edge of a `size` area.
static func place_embers(p: CPUParticles2D, area: Vector2) -> void:
	p.position = Vector2(area.x / 2.0, area.y + 8.0)
	p.emission_rect_extents = Vector2(area.x / 2.0, 4.0)

static func _dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 12
	tex.height = 12
	return tex

static func _still(n: Node) -> bool:
	if not is_instance_valid(n):
		return true
	var settings = n.get_node_or_null("/root/Settings") if n.is_inside_tree() else null
	if settings == null:
		settings = Engine.get_main_loop().root.get_node_or_null("Settings") if Engine.get_main_loop() is SceneTree else null
	return settings != null and bool(settings.get("reduce_motion"))

## Adds the press "pop" to every Button under `screen` (now and later: dialogs,
## rebuilt lists). Call once from a hub screen's _ready().
static func attach(screen: Node) -> void:
	if _still(screen):
		return
	var w := Watcher.new()
	screen.add_child(w)

## Connected by method (never a lambda): see CLAUDE.md gotchas.
class Watcher extends Node:
	func _ready() -> void:
		var tree := get_tree()
		tree.node_added.connect(_on_added)
		_scan(get_parent())

	func _scan(n: Node) -> void:
		_on_added(n)
		for c in n.get_children():
			_scan(c)

	func _on_added(n: Node) -> void:
		if n is BaseButton and get_parent().is_ancestor_of(n) and not n.has_meta("hub_fx"):
			var b := n as BaseButton
			b.set_meta("hub_fx", true)
			b.button_down.connect(_down.bind(b))
			b.button_up.connect(_up.bind(b))

	func _down(b: BaseButton) -> void:
		if not is_instance_valid(b) or b.disabled:
			return
		b.pivot_offset = b.size / 2.0
		var t := b.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "scale", Vector2.ONE * 0.95, 0.07)

	func _up(b: BaseButton) -> void:
		if not is_instance_valid(b):
			return
		var t := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "scale", Vector2.ONE, 0.2)
