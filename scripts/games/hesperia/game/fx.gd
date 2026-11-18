extends RefCounted
## Small drawing helpers shared by the visual pass (shadows, glows, pixel bevels). Static, no state.

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)

## Ground contact shadow under an actor.
static func shadow(ci: CanvasItem, c: Vector2, rx: float, alpha: float = 0.3) -> void:
	ellipse(ci, c, rx, maxf(1.5, rx * 0.38), Color(0.02, 0.03, 0.06, alpha))

## Soft additive-looking glow: stacked translucent circles, outer faint -> inner bright.
static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color, layers: int = 4) -> void:
	for i in layers:
		var k := 1.0 - float(i) / float(layers)
		ci.draw_circle(c, r * k, Color(col.r, col.g, col.b, col.a * (0.18 + 0.5 * (1.0 - k))))

## Pixel bevel box: fill + light top/left edge + dark bottom/right edge.
static func bevel(ci: CanvasItem, r: Rect2, fill: Color, lite: float = 0.25, dark: float = 0.35) -> void:
	ci.draw_rect(r, fill)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), fill.lightened(lite))
	ci.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), fill.lightened(lite * 0.6))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), fill.darkened(dark))
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), fill.darkened(dark * 0.8))

## Small heart shape (drops, HUD).
static func heart(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-0.45, -0.2) * s, 0.5 * s, col)
	ci.draw_circle(c + Vector2(0.45, -0.2) * s, 0.5 * s, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.93, 0.0) * s, c + Vector2(0.93, 0.0) * s, c + Vector2(0, 1.0) * s]), col)
