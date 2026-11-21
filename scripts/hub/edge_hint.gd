extends Control

## Layout D: what shows at the left edge while the side rail is hidden (owner 2026-11-21).
## A glowing line down the edge that pulses, and ripples that leave it toward the centre of
## the screen, so players see there is something to drag out. Reduce motion / Menu animations
## off: the line only, still. Draws only; never takes input (layout_d.gd reads the drag).

const PERIOD := 2.4          # s per pulse; a ripple leaves at each pulse's peak
const RIPPLES := 2           # ripples in flight at once (staggered by PERIOD / RIPPLES)

var u := 1.0                 # canvas units per dp (layout_d.dp)
var color := Color(0.4, 0.75, 1.0)
var still := false
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1   # over the tiles (the rail, when out, hides this)
	set_process(not still)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t = fmod(_t + delta, PERIOD * 100.0)
	queue_redraw()

func _draw() -> void:
	var h := size.y
	var cy := h / 2.0
	var pulse := 0.5 if still else 0.5 + 0.5 * sin(_t / PERIOD * TAU)
	var x := 1.5 * u
	# The line: brightest in the middle, fading toward the top and bottom.
	var segs := 24
	for i in segs:
		var y0 := h * float(i) / segs
		var y1 := h * float(i + 1) / segs
		var mid := 1.0 - absf((y0 + y1) / 2.0 - cy) / cy       # 0 at the ends, 1 in the middle
		var a := (0.55 + 0.45 * pulse) * (0.3 + 0.7 * mid)
		for g in [[16.0, 0.10], [8.0, 0.22], [3.0, 1.0]]:     # soft glow, then the core
			var w: float = g[0] * u
			draw_rect(Rect2(0, y0, x + w / 2.0, y1 - y0), Color(color, a * float(g[1])))
	if still:
		return
	# Ripples: arcs from a point just off the left edge, growing toward the centre and fading.
	var origin := Vector2(-40.0 * u, cy)
	for r in RIPPLES:
		var p := fmod(_t / PERIOD + float(r) / RIPPLES, 1.0)
		var radius := 40.0 * u + p * 110.0 * u
		var half := minf(acos(clampf(40.0 * u / radius, -1.0, 1.0)), 1.2)   # only the part on screen
		var a := (1.0 - p) * 0.9
		draw_arc(origin, radius, -half, half, 40, Color(color, a * 0.25), maxf(2.0, 7.0 * u), true)   # glow
		draw_arc(origin, radius, -half, half, 40, Color(color, a), maxf(1.0, 2.5 * u), true)
