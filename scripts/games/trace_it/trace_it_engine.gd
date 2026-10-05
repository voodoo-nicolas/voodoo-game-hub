extends RefCounted

## Trace It -- the logic with no UI: where the overlay sits (and how two
## fingers move it), the look settings, the teaching steps, and the session
## as a saveable Dictionary. Tested headlessly; the game draws from it.

## Overlay looks. "photo" keeps the picture's colours; "lines" is the photo's
## line art; "hatch" and "dots" draw its tones as cross-hatching and as
## stipple (pointillism) -- shading techniques to trace. A line drawing is
## always drawn as lines.
const STYLES := ["photo", "gray", "lines", "invert", "hatch", "dots"]
## How the Shading step shades: flat tones, cross-hatching or dots.
const SHADINGS := ["tones", "hatch", "dots"]
## Line colours: dark for white paper, light for dark paper, two bright ones.
const LINE_COLORS := [Color(0.05, 0.05, 0.08), Color(1, 1, 1), Color("ff2b4a"), Color("1f6bff"), Color("29e6ff")]
## Guides drawn over the picture: none, a 3x3 grid (thirds), 4x4, the golden
## ratio grid (lines at 0.382 / 0.618) and the golden spiral.
const GRIDS := [0, 3, 4, GOLDEN_GRID, GOLDEN_SPIRAL]
const GOLDEN_GRID := -1
const GOLDEN_SPIRAL := -2
const PHI := 1.6180339887
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
var shading := "tones"
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


func next_shading() -> String:
	shading = SHADINGS[(SHADINGS.find(shading) + 1) % SHADINGS.size()]
	return shading


## The golden spiral in a w x h box, as {points: PackedVector2Array,
## squares: [Rect2]}: the largest golden rectangle that fits (centred),
## split into ever smaller squares, and a quarter arc through each one.
## Biggest square first, turning inwards clockwise; a tall box is worked
## out sideways and transposed. Flip the picture for the other turns.
static func golden_layout(w: float, h: float, turns: int = 10) -> Dictionary:
	var tall := h > w
	var bw := h if tall else w
	var bh := w if tall else h
	var gw := minf(bw, bh * PHI)
	var gh := gw / PHI
	var pts := PackedVector2Array()
	var squares := []
	var r := Rect2((bw - gw) / 2.0, (bh - gh) / 2.0, gw, gh)
	for i in turns:
		var s := minf(r.size.x, r.size.y)
		if s < 1.0:
			break
		var c: Vector2
		var a0: float
		var sq: Rect2
		match i % 4:
			0:   # square on the left
				sq = Rect2(r.position, Vector2(s, s))
				c = r.position + Vector2(s, s)
				a0 = PI
				r = Rect2(r.position.x + s, r.position.y, r.size.x - s, r.size.y)
			1:   # on top
				sq = Rect2(r.position, Vector2(s, s))
				c = r.position + Vector2(0, s)
				a0 = -PI / 2.0
				r = Rect2(r.position.x, r.position.y + s, r.size.x, r.size.y - s)
			2:   # on the right
				sq = Rect2(Vector2(r.end.x - s, r.position.y), Vector2(s, s))
				c = Vector2(r.end.x - s, r.position.y)
				a0 = 0.0
				r = Rect2(r.position, Vector2(r.size.x - s, r.size.y))
			_:   # at the bottom
				sq = Rect2(Vector2(r.position.x, r.end.y - s), Vector2(s, s))
				c = Vector2(r.end.x, r.end.y - s)
				a0 = PI / 2.0
				r = Rect2(r.position, Vector2(r.size.x, r.size.y - s))
		squares.append(sq)
		for k in 17:
			if k == 0 and pts.size() > 0:
				continue
			var a := a0 + PI / 2.0 * k / 16.0
			pts.append(c + Vector2(cos(a), sin(a)) * s)
	if tall:
		for i in pts.size():
			pts[i] = Vector2(pts[i].y, pts[i].x)
		for i in squares.size():
			var q: Rect2 = squares[i]
			squares[i] = Rect2(Vector2(q.position.y, q.position.x), Vector2(q.size.y, q.size.x))
	return {"points": pts, "squares": squares}


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
		"opacity": opacity, "style": style, "line_color": line_color, "grid": grid, "shading": shading,
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
	var sh := str(d.get("shading", "tones"))
	shading = sh if SHADINGS.has(sh) else "tones"
	steps_on = bool(d.get("steps_on", false))
	set_step(int(d.get("step", 0)))
