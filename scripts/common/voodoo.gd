extends Control

## Voodoo Mode: an optional skin that swaps game pieces for skulls,
## crossbones and voodoo dolls (the doll is the app logo: button X eyes,
## a stitched seam, a pin). Switched from the hub's 💀 button or the ⚙
## drawer; saved in `user://voodoo_mode.json`.
##
## Ships in the APK (v0.21+). Games load it, never preload it -- packs also
## run on older apps, which simply keep the plain pieces:
##
##   const VOODOO_PATH := "res://scripts/common/voodoo.gd"
##   var Voodoo = load(VOODOO_PATH) if ResourceLoader.exists(VOODOO_PATH) else null
##   var voodoo_on: bool = Voodoo != null and Voodoo.is_on()
##
## A piece is a node of this script: `var m = Voodoo.new()` added to the cell
## (it fills its parent and ignores the mouse), then set `kind` / `fill` /
## `ink`; it redraws itself. Kind NONE draws nothing.
##
## A game that supports the skin defines `_set_voodoo(on: bool)` (re-skin
## and re-render in place). The ⚙ drawer then shows the toggle and calls it
## -- no scene reload, so an online match keeps going.

const SETTINGS_PATH := "user://voodoo_mode.json"

enum {NONE, SKULL, BONES, DOLL}

const BONE := Color(0.93, 0.9, 0.8)
const INK := Color(0.08, 0.05, 0.1)
const PIN := Color(0.78, 0.78, 0.84)
const PIN_HEAD := Color(0.85, 0.12, 0.15)
## Game background while Voodoo Mode is on.
const BG := Color(0.1, 0.05, 0.13)

var kind: int = NONE:
	set(v):
		kind = v
		queue_redraw()
var fill: Color = BONE:
	set(v):
		fill = v
		queue_redraw()
var ink: Color = INK:
	set(v):
		ink = v
		queue_redraw()
## Thin rim around the silhouette so a piece reads on any background.
var outline: Color = Color(0, 0, 0, 0.55):
	set(v):
		outline = v
		queue_redraw()
## Fraction of the cell's shorter side the piece spans.
var span: float = 0.82

static func is_on() -> bool:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	return typeof(data) == TYPE_DICTIONARY and bool(data.get("on", false))

static func set_on(on: bool) -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"on": on}))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var s: float = min(size.x, size.y) * span
	var c: Vector2 = size / 2.0
	match kind:
		SKULL:
			draw_skull(self, c, s, fill, ink, outline)
		BONES:
			draw_crossbones(self, c, s, fill, outline)
		DOLL:
			draw_doll(self, c, s, fill, ink, outline)

# ---------- shapes (s = the piece's size; shapes stay within c ± s/2) ----------

static func draw_skull(ci: CanvasItem, c: Vector2, s: float, fill_c: Color, ink_c: Color, rim: Color) -> void:
	var jaw := PackedVector2Array()
	for p in [Vector2(-0.22, 0.02), Vector2(0.22, 0.02), Vector2(0.2, 0.3), Vector2(0.12, 0.4),
			Vector2(-0.12, 0.4), Vector2(-0.2, 0.3)]:
		jaw.append(c + p * s)
	var crown := c + Vector2(0, -0.1) * s
	var r := 0.34 * s
	var rim_w := maxf(1.5, s * 0.035)
	if rim.a > 0.0:
		ci.draw_circle(crown, r + rim_w, rim)
		for poly in Geometry2D.offset_polygon(jaw, rim_w):
			ci.draw_colored_polygon(poly, rim)
	ci.draw_circle(crown, r, fill_c)
	ci.draw_colored_polygon(jaw, fill_c)
	# eye sockets, nose, teeth
	ci.draw_circle(c + Vector2(-0.13, -0.04) * s, 0.095 * s, ink_c)
	ci.draw_circle(c + Vector2(0.13, -0.04) * s, 0.095 * s, ink_c)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0.07) * s,
			c + Vector2(-0.05, 0.17) * s, c + Vector2(0.05, 0.17) * s]), ink_c)
	var tooth_w := maxf(1.0, s * 0.028)
	for x in [-0.105, -0.035, 0.035, 0.105]:
		ci.draw_line(c + Vector2(x, 0.25) * s, c + Vector2(x, 0.38) * s, ink_c, tooth_w)

static func draw_crossbones(ci: CanvasItem, c: Vector2, s: float, fill_c: Color, rim: Color) -> void:
	var rim_w := maxf(1.5, s * 0.035)
	var dirs := [Vector2(1, 1).normalized(), Vector2(1, -1).normalized()]
	if rim.a > 0.0:
		for d in dirs:
			_bone(ci, c, d, s, fill_c, rim, rim_w)
	for d in dirs:
		_bone(ci, c, d, s, fill_c, Color(0, 0, 0, 0), 0.0)

## One bone along direction d; with grow > 0 draws only its rim in rim_c.
static func _bone(ci: CanvasItem, c: Vector2, d: Vector2, s: float, fill_c: Color, rim_c: Color, grow: float) -> void:
	var col: Color = rim_c if grow > 0.0 else fill_c
	var half := 0.33 * s
	var t := 0.11 * s
	var p := Vector2(-d.y, d.x)
	ci.draw_line(c - d * half, c + d * half, col, t + grow * 2.0)
	for e in [c + d * half, c - d * half]:
		var out: Vector2 = d if e.dot(d) > c.dot(d) else -d
		for side in [1.0, -1.0]:
			ci.draw_circle(e + p * t * 0.62 * side + out * t * 0.15, t * 0.62 + grow, col)

static func draw_doll(ci: CanvasItem, c: Vector2, s: float, fill_c: Color, ink_c: Color, rim: Color) -> void:
	var head := c + Vector2(-0.02, -0.1) * s
	var head_r := 0.3 * s
	var body := c + Vector2(-0.02, 0.27) * s
	var body_r := 0.19 * s
	var arms := [c + Vector2(-0.24, 0.25) * s, c + Vector2(0.2, 0.25) * s]
	var arm_r := 0.09 * s
	var line_w := maxf(1.0, s * 0.03)
	var rim_w := maxf(1.5, s * 0.035)

	# the pin goes in behind the head
	var pin_tip := c + Vector2(0.12, -0.12) * s
	var pin_end := c + Vector2(0.4, -0.4) * s
	ci.draw_line(pin_tip, pin_end, PIN, max(1.0, s * 0.025))
	ci.draw_circle(pin_end, 0.055 * s, PIN_HEAD)

	if rim.a > 0.0:
		ci.draw_circle(body, body_r + rim_w, rim)
		for a in arms:
			ci.draw_circle(a, arm_r + rim_w, rim)
		ci.draw_circle(head, head_r + rim_w, rim)
	ci.draw_circle(body, body_r, fill_c)
	for a in arms:
		ci.draw_circle(a, arm_r, fill_c)
	ci.draw_circle(head, head_r, fill_c)

	# seam down the forehead, with cross stitches
	var seam_top := head + Vector2(-0.03, -0.29) * s
	var seam_bot := head + Vector2(0.01, -0.12) * s
	ci.draw_line(seam_top, seam_bot, ink_c, line_w)
	for k in range(3):
		var m: Vector2 = seam_top.lerp(seam_bot, (k + 0.6) / 3.4)
		ci.draw_line(m + Vector2(-0.035, 0) * s, m + Vector2(0.035, 0) * s, ink_c, line_w)

	# button eyes with X's
	for x in [-0.12, 0.12]:
		var e := head + Vector2(x, 0.0) * s
		var er := 0.085 * s
		ci.draw_circle(e, er, ink_c)
		var k := er * 0.5
		ci.draw_line(e + Vector2(-k, -k), e + Vector2(k, k), fill_c, line_w)
		ci.draw_line(e + Vector2(-k, k), e + Vector2(k, -k), fill_c, line_w)

	# stitched mouth
	var m0 := head + Vector2(-0.1, 0.16) * s
	var m1 := head + Vector2(0.1, 0.16) * s
	ci.draw_line(m0, m1, ink_c, line_w)
	for k in range(4):
		var m: Vector2 = m0.lerp(m1, (k + 0.5) / 4.0)
		ci.draw_line(m + Vector2(0, -0.035) * s, m + Vector2(0, 0.035) * s, ink_c, line_w)
