extends Control

## Top-left health readout: a wide bar, the number ("70/100") beside it, and how many first-aid
## kits / snacks are in the bag. The number turns green with a "+" while health ticks back
## (nobody is hunting Nash). Tapping it uses a kit or a snack (the touch controls report the tap;
## this node ignores input itself). v0.4: a thin blue armor bar under it while Nash wears armor.

const Icons = preload("res://scripts/games/last_shift/last_shift_icons.gd")

const BAR := Vector2(300, 26)
const RED := Color("d9402f")
const GREEN := Color("6fd05a")
const ARMOR_BLUE := Color("5a8ad8")

var hp := 100
var max_hp := 100
var regen := false
var medkits := 0
var snacks := 0
var armor := 0
var _t := 0.0
var _trail := 1.0      # v0.6 polish: the pale "damage taken" chunk that drains after a hit
var _low_t := 0.0      # pulse timer while health is low

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(BAR.x + 230, BAR.y + 12)

func set_values(new_hp: int, new_max: int, regenerating: bool, kits: int, snack_count: int, new_armor: int = 0) -> void:
	if new_hp != hp or new_max != max_hp or regenerating != regen or kits != medkits or snack_count != snacks \
			or new_armor != armor:
		hp = new_hp
		max_hp = new_max
		regen = regenerating
		medkits = kits
		snacks = snack_count
		armor = new_armor
		queue_redraw()

func _process(delta: float) -> void:
	if regen:
		_t += delta
		queue_redraw()
	var frac := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	if _trail < frac:
		_trail = frac          # healing: no trail
	elif _trail > frac:
		_trail = move_toward(_trail, frac, delta * 0.6)
		queue_redraw()
	if frac <= 0.3 and hp > 0:
		_low_t += delta
		queue_redraw()

func _draw() -> void:
	var f := ThemeDB.fallback_font
	var r := Rect2(Vector2.ZERO, BAR)
	# v0.6 polish: hard drop shadow, recessed dark track, damage trail, cel-shaded fill, 10% notches
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.45))
	draw_rect(r, Color("0e0e12"))
	draw_rect(Rect2(Vector2(3, 3), Vector2(BAR.x - 6, BAR.y - 6)), Color("1b1f2a"))
	var frac := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	if _trail > frac:
		draw_rect(Rect2(Vector2(3 + (BAR.x - 6) * frac, 3), Vector2((BAR.x - 6) * (_trail - frac), BAR.y - 6)),
			Color("f2d13a", 0.85))
	var fill := Rect2(Vector2(3, 3), Vector2((BAR.x - 6) * frac, BAR.y - 6))
	var col := RED
	if frac <= 0.3:
		col = RED.lerp(Color("ff6a4d"), 0.5 + 0.5 * sin(_low_t * 7.0))
	draw_rect(fill, col)
	draw_rect(Rect2(fill.position + Vector2(0, fill.size.y * 0.62), Vector2(fill.size.x, fill.size.y * 0.38)), col.darkened(0.3))
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, 4)), col.lightened(0.35))
	for i in range(1, 10):
		var nx := 3.0 + (BAR.x - 6) * i / 10.0
		draw_line(Vector2(nx, 4), Vector2(nx, BAR.y - 4), Color(0, 0, 0, 0.35), 1.0)
	if regen and frac < 1.0:
		# a soft green sheen sliding along the bar while health ticks back
		var x := fposmod(_t * 160.0, BAR.x - 6)
		draw_rect(Rect2(Vector2(3 + x, 3), Vector2(minf(24.0, fill.size.x), BAR.y - 6)).intersection(fill), Color(GREEN, 0.35))
	draw_rect(r, Color(1, 1, 1, 0.55), false, 2.0)
	draw_line(Vector2(1, 1), Vector2(BAR.x - 1, 1), Color("ffd479", 0.6), 2.0)
	if armor > 0:
		var ar := Rect2(0, BAR.y + 3, BAR.x, 8)
		draw_rect(ar, Color("0e0e12"))
		draw_rect(Rect2(ar.position + Vector2(2, 2), Vector2((BAR.x - 4) * clampf(armor / 100.0, 0.0, 1.0), 4)), ARMOR_BLUE)
		# a small shield and the armor points, under the health number
		var sp := Vector2(BAR.x + 12, BAR.y + 7)
		draw_colored_polygon(PackedVector2Array([sp + Vector2(-5, -4), sp + Vector2(5, -4), sp + Vector2(5, 1),
			sp + Vector2(0, 6), sp + Vector2(-5, 1)]), ARMOR_BLUE)
		var at := str(armor)
		draw_string_outline(f, sp + Vector2(9, 5), at, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
		draw_string(f, sp + Vector2(9, 5), at, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ARMOR_BLUE.lightened(0.3))
	var text := "%d/%d" % [hp, max_hp]
	var fs := 22
	var pos := Vector2(BAR.x + 10, BAR.y * 0.5 + f.get_ascent(fs) * 0.5 - 2)
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color.BLACK)
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GREEN if regen and hp < max_hp else Color.WHITE)
	var x0 := pos.x + f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8
	if regen and hp < max_hp:
		draw_string_outline(f, Vector2(x0, pos.y), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color.BLACK)
		draw_string(f, Vector2(x0, pos.y), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(GREEN, 0.6 + 0.4 * sin(_t * 8.0)))
		x0 += 18
	# what's in the bag to heal with (tap the bar to use one)
	for pair in [["medkit", medkits], ["snack", snacks]]:
		if int(pair[1]) <= 0:
			continue
		Icons.draw(self, pair[0], Vector2(x0 + 14, BAR.y * 0.5), 26.0)
		var n := "x%d" % int(pair[1])
		draw_string_outline(f, Vector2(x0 + 30, pos.y), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color.BLACK)
		draw_string(f, Vector2(x0 + 30, pos.y), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		x0 += 64
