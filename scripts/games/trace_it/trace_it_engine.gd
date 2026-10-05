extends RefCounted

## Trace It -- the logic with no UI: where the overlay sits (and how two
## fingers move it), the look settings, the teaching steps, and the session
## as a saveable Dictionary. Tested headlessly; the game draws from it.

## Overlay looks. "photo" keeps the picture's colours; "lines" turns a photo
## into line art (edge shader) -- a line drawing is always drawn as lines.
const STYLES := ["photo", "gray", "lines", "invert"]
## Line colours: dark for white paper, light for dark paper, two bright ones.
const LINE_COLORS := [Color(0.05, 0.05, 0.08), Color(1, 1, 1), Color("ff2b4a"), Color("1f6bff"), Color("29e6ff")]
const GRIDS := [0, 3, 4]
const MIN_SCALE := 0.1
const MAX_SCALE := 10.0

## Step-by-step teaching for a photo: how an artist builds a drawing, from
## the biggest masses to the shading. A line step is the photo blurred down
## to `blur` pixels across (so only what matters at that stage survives),
## then its edges found at `width` and thinned to one pixel, keeping the
## strongest `keep` share (the same line density on any photo); `thick`
## doubles the line width; `levels` traces the borders of that many tone
## masses instead of every edge. Shading is the photo in four tones.
## A line drawing brings its own steps (strokes grouped by "step").
const PHOTO_STEPS := [
	{"name": "Big shapes", "tip": "Draw only the big outer shapes, lightly. No details yet.", "mode": "mask", "blur": 20, "width": 240, "keep": 1.0, "thick": true, "levels": 3},
	{"name": "Main lines", "tip": "Now the main lines inside the big shapes.", "mode": "mask", "blur": 96, "width": 300, "keep": 0.4, "thick": true},
	{"name": "Details", "tip": "Add the small details: eyes, edges, texture.", "mode": "mask", "blur": 0, "width": 360, "keep": 0.3, "thick": false},
	{"name": "Shading", "tip": "Shade the dark areas. Press harder where it's darkest.", "mode": "tones"},
]

# Where the overlay sits, relative to the centre of the screen.
var offset := Vector2.ZERO
var scale := 1.0
var rotation := 0.0
var flip_h := false
var flip_v := false
var locked := false

var opacity := 0.7
var style := "lines"
var line_color := 0
var grid := 0
var steps_on := false
var step := 0
var step_count := 4


func reset_placement() -> void:
	offset = Vector2.ZERO
	scale = 1.0
	rotation = 0.0
	flip_h = false
	flip_v = false


## One finger dragged by `delta` screen units.
func pan(delta: Vector2) -> void:
	if locked:
		return
	offset += delta


## Two fingers moved from (a0, b0) to (a1, b1), all relative to the screen
## centre: the overlay follows them -- moves with their midpoint, scales with
## their distance, turns with their angle -- so the spot under each finger
## stays under it.
func pinch(a0: Vector2, b0: Vector2, a1: Vector2, b1: Vector2) -> void:
	if locked:
		return
	var d0 := b0 - a0
	var d1 := b1 - a1
	if d0.length() < 1.0 or d1.length() < 1.0:
		return
	var k := clampf(scale * d1.length() / d0.length(), MIN_SCALE, MAX_SCALE) / scale
	var turn := d0.angle_to(d1)
	var m0 := (a0 + b0) / 2.0
	var m1 := (a1 + b1) / 2.0
	# The overlay point under the old midpoint must land under the new one.
	offset = m1 + (offset - m0).rotated(turn) * k
	scale *= k
	rotation = wrapf(rotation + turn, -PI, PI)


## Mouse wheel on PC: zoom by `factor` around `at`.
func zoom_at(at: Vector2, factor: float) -> void:
	if locked:
		return
	var k := clampf(scale * factor, MIN_SCALE, MAX_SCALE) / scale
	offset = at + (offset - at) * k
	scale *= k


func turn_by(angle: float) -> void:
	if locked:
		return
	rotation = wrapf(rotation + angle, -PI, PI)


## The overlay's transform on screen, `center` being the screen centre.
func transform(center: Vector2) -> Transform2D:
	var s := Vector2(-scale if flip_h else scale, -scale if flip_v else scale)
	return Transform2D(rotation, s, 0.0, center + offset)


## Scale 1 = the picture fitted inside `area` with a small margin.
static func fit_size(pic: Vector2, area: Vector2) -> Vector2:
	if pic.x <= 0 or pic.y <= 0:
		return Vector2.ZERO
	var k := minf(area.x * 0.9 / pic.x, area.y * 0.9 / pic.y)
	return pic * k


func next_style() -> String:
	style = STYLES[(STYLES.find(style) + 1) % STYLES.size()]
	return style


func next_grid() -> int:
	grid = GRIDS[(GRIDS.find(grid) + 1) % GRIDS.size()]
	return grid


func set_step(i: int) -> void:
	step = clampi(i, 0, step_count - 1)


## How visible layer `i` is in step mode: the current step fully, the ones
## already done faintly (so you see where the new lines go), later ones not.
func layer_alpha(i: int) -> float:
	if not steps_on:
		return 0.0
	if i == step:
		return 1.0
	if i < step:
		return 0.3
	return 0.0


## The size a step's picture is shrunk to (width 0 = full size), keeping
## the short side at least 8 px.
static func step_size(pic: Vector2i, width: int) -> Vector2i:
	if width <= 0 or width >= pic.x:
		return pic
	var h := maxi(8, int(round(pic.y * float(width) / pic.x)))
	return Vector2i(width, h)


func to_dict() -> Dictionary:
	return {
		"offset": [offset.x, offset.y], "scale": scale, "rotation": rotation,
		"flip_h": flip_h, "flip_v": flip_v, "locked": locked,
		"opacity": opacity, "style": style, "line_color": line_color, "grid": grid,
		"steps_on": steps_on, "step": step,
	}


func from_dict(d: Dictionary) -> void:
	var o = d.get("offset")
	offset = Vector2(float(o[0]), float(o[1])) if o is Array and o.size() == 2 else Vector2.ZERO
	scale = clampf(float(d.get("scale", 1.0)), MIN_SCALE, MAX_SCALE)
	rotation = float(d.get("rotation", 0.0))
	flip_h = bool(d.get("flip_h", false))
	flip_v = bool(d.get("flip_v", false))
	locked = bool(d.get("locked", false))
	opacity = clampf(float(d.get("opacity", 0.7)), 0.0, 1.0)
	var st := str(d.get("style", "lines"))
	style = st if STYLES.has(st) else "lines"
	line_color = clampi(int(d.get("line_color", 0)), 0, LINE_COLORS.size() - 1)
	var g := int(d.get("grid", 0))
	grid = g if GRIDS.has(g) else 0
	steps_on = bool(d.get("steps_on", false))
	set_step(int(d.get("step", 0)))
