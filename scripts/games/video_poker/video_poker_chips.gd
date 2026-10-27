extends RefCounted

## Poker chips: an amount drawn as a pile of chips by value. Six denominations,
## the colours of the owner's chip art (video_poker_look.gd slots chip_1..6:
## white red blue green black gold); without that art (Voodoo for now) they are
## drawn as coloured discs in the look's chip colours.

const Look = preload("res://scripts/games/video_poker/video_poker_look.gd")

## Value of chip_1 .. chip_6.
const DENOMS := [10, 50, 100, 500, 1000, 5000]
const MAX_COLUMNS := 4
const MAX_HIGH := 8
## Each chip in a column sits this much higher than the one below (of its diameter).
const RISE := 0.1
const COLUMN_GAP := 0.78

## `amount` as [[denomination index, how many]] biggest chips first, by greedy
## change. Under 10 is one white chip; the last few chips are rounded to 10.
## Piles with more than MAX_COLUMNS kinds drop the smallest kinds (worth under
## 4% of the amount), then the smallest still over the limit.
static func breakdown(amount: int) -> Array:
	var out: Array = []
	if amount <= 0:
		return out
	if amount < DENOMS[0]:
		return [[0, 1]]
	var left := int(round(amount / 10.0)) * 10
	for i in range(DENOMS.size() - 1, -1, -1):
		var n: int = left / DENOMS[i]
		if n > 0:
			out.append([i, n])
			left -= n * DENOMS[i]
	var kept: Array = []
	for e in out:
		if out.size() <= 1 or e[1] * DENOMS[e[0]] >= amount * 0.04:
			kept.append(e)
	if kept.is_empty():
		kept = [out[0]]
	while kept.size() > MAX_COLUMNS:
		kept.pop_back()
	return kept

## Width of the pile for `amount` with chips `diameter` across.
static func stack_width(amount: int, diameter: float) -> float:
	var cols := breakdown(amount).size()
	if cols == 0:
		return 0.0
	return diameter + (cols - 1) * diameter * COLUMN_GAP

## Draws the pile for `amount` centred on `centre` (the bottom chips' middle).
static func draw_stack(canvas: CanvasItem, centre: Vector2, amount: int, diameter: float) -> void:
	var cols := breakdown(amount)
	if cols.is_empty():
		return
	var x0 := centre.x - (cols.size() - 1) * diameter * COLUMN_GAP / 2.0
	# the tallest column at the back, so the shorter ones in front stay visible
	var order := range(cols.size())
	order.sort_custom(func(a, b): return cols[a][1] > cols[b][1])
	for oi in order:
		var ci: int = oi
		var kind: int = cols[ci][0]
		var count: int = mini(cols[ci][1], MAX_HIGH)
		var x: float = x0 + ci * diameter * COLUMN_GAP
		canvas.draw_circle(Vector2(x, centre.y + diameter * 0.06), diameter * 0.5, Color(0, 0, 0, 0.3))
		for k in count:
			_draw_chip(canvas, Vector2(x, centre.y - k * diameter * RISE), kind, diameter)

## One chip of denomination index `kind`.
static func _draw_chip(canvas: CanvasItem, c: Vector2, kind: int, d: float) -> void:
	var tex := Look.tex("chip_%d" % (kind + 1))
	if tex != null:
		canvas.draw_texture_rect(tex, Rect2(c - Vector2(d, d) / 2.0, Vector2(d, d)), false)
		return
	var col := Look.c("chip_%d" % (kind + 1))
	canvas.draw_circle(c, d * 0.5, col)
	canvas.draw_arc(c, d * 0.5 - 1.0, 0, TAU, 24, Look.c("chip_edge"), maxf(1.5, d * 0.07), true)
	canvas.draw_arc(c, d * 0.3, 0, TAU, 20, Color(Look.c("chip_edge"), 0.55), 1.0, true)

## The dealer button, `radius` big, centred on `c`: the owner's art, else a plain disc with a D.
static func draw_dealer(canvas: CanvasItem, c: Vector2, radius: float) -> void:
	var tex := Look.tex("dealer")
	if tex != null:
		canvas.draw_circle(c + Vector2(0, radius * 0.1), radius, Color(0, 0, 0, 0.35))
		canvas.draw_texture_rect(tex, Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false)
		return
	canvas.draw_circle(c, radius + 3, Color(Look.c("dealer"), 0.2))
	canvas.draw_circle(c, radius, Look.c("dealer"))
	var font: Font = ThemeDB.fallback_font
	canvas.draw_string(font, c + Vector2(-radius, radius * 0.45), "D", HORIZONTAL_ALIGNMENT_CENTER, radius * 2, int(radius * 1.3), Look.c("dealer_ink"))
