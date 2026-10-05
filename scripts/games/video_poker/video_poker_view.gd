extends Control

## Draws a poker table: the felt, the other seats around it (name, chips,
## cards, last action, bet), the board and pot in the middle, and the
## viewer's own cards big at the bottom. Neon on near-black
## (reference/art/ART_STYLE.md). The game sets the fields and calls
## queue_redraw(); taps on the viewer's cards come out as `card_tapped`.

signal card_tapped(index: int)

const Cards = preload("res://scripts/games/video_poker/video_poker_cards.gd")
const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")
const AI = preload("res://scripts/games/video_poker/video_poker_ai.gd")

const BG := Color("070a14")
const CYAN := Color("29e6ff")
const MAGENTA := Color("ff2bd6")
const GOLD := Color("ffae2b")
const LIME := Color("7dff3a")
const PURPLE := Color("9b4dff")
const WHITE := Color(0.95, 0.97, 1.0)
const DIM := Color(0.62, 0.66, 0.78)
const CARD_ASPECT := 1.42
## Poker's "Check" has its own key: plain "Check" is already the Spanish
## "Revisar" of Code Breaker and Crossword (es.json is one shared map).
const CHECK := "Check "

## Box centres (fractions of the felt) for 1..5 other seats, clockwise from
## the viewer's left: left-low, left-high, top, right-high, right-low.
const SPOTS := {
	1: [Vector2(0.5, 0.17)],
	2: [Vector2(0.24, 0.17), Vector2(0.76, 0.17)],
	3: [Vector2(0.17, 0.36), Vector2(0.5, 0.14), Vector2(0.83, 0.36)],
	4: [Vector2(0.17, 0.43), Vector2(0.17, 0.14), Vector2(0.83, 0.14), Vector2(0.83, 0.43)],
	5: [Vector2(0.17, 0.43), Vector2(0.17, 0.14), Vector2(0.5, 0.14), Vector2(0.83, 0.14), Vector2(0.83, 0.43)],
}

var t  # the Table (video_poker_table.gd)
var viewer: int = 0          # the seat drawn at the bottom
var hide_viewer: bool = false  # pass-and-play: cards stay down until "I'm ready"
var thinking: int = -1       # seat that's thinking (drawn pulsing)
var discards: Array = []     # viewer's cards picked to throw away (draw phase)
var show_styles: bool = false  # training: label each computer's style
var you_text := "You"

var _font: Font
var _pulse := 0.0

func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input)
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if thinking >= 0:
		_pulse += delta
		queue_redraw()

# ---------- geometry ----------

func _hero_h() -> float:
	return clampf(size.y * 0.32, 190.0, 360.0)

func felt_rect() -> Rect2:
	return Rect2(10, 6, size.x - 20, size.y - _hero_h() - 12)

func _others() -> Array:
	var out: Array = []
	var n: int = t.seats.size()
	for k in range(1, n):
		out.append((viewer + k) % n)
	return out

func _box_size(count: int) -> Vector2:
	var f := felt_rect()
	var w := minf(f.size.x * 0.31, 250.0)
	var h := f.size.y * (0.25 if count >= 4 else 0.3)
	return Vector2(w, clampf(h, 110.0, 190.0))

func seat_rect(seat: int) -> Rect2:
	var others := _others()
	var k := others.find(seat)
	if k < 0:
		return Rect2()
	var f := felt_rect()
	var bs := _box_size(others.size())
	var spot: Vector2 = SPOTS[clampi(others.size(), 1, 5)][k]
	var c := f.position + Vector2(f.size.x * spot.x, f.size.y * spot.y + bs.y * 0.5 - f.size.y * 0.02)
	var r := Rect2(c - bs / 2.0, bs)
	r.position.x = clampf(r.position.x, f.position.x + 4, f.end.x - bs.x - 4)
	r.position.y = maxf(r.position.y, f.position.y + 4)
	return r

func _board_rect() -> Rect2:
	var f := felt_rect()
	var n: int = t.seats.size() - 1
	var cw := minf((f.size.x - 60.0) / 5.6, 96.0)
	if n >= 4:
		cw = minf(cw, (f.size.x * 0.62) / 5.4)
	var ch := cw * CARD_ASPECT
	var y := f.position.y + f.size.y * (0.74 if n >= 4 else 0.66) - ch / 2.0
	# Below the seats at the sides, with room for the pot line between.
	for i in _others():
		var r := seat_rect(i)
		if r.position.x < f.position.x + f.size.x * 0.3 or r.end.x > f.end.x - f.size.x * 0.3:
			if r.get_center().y > f.position.y + f.size.y * 0.3:
				y = maxf(y, r.end.y + 12)
	y = minf(y, f.end.y - ch - 8)
	var w := cw * 5 + 8 * 4
	return Rect2(f.position.x + (f.size.x - w) / 2.0, y, w, ch)

func hero_card_rects() -> Array:
	var out: Array = []
	if t == null or viewer < 0 or viewer >= t.seats.size():
		return out
	var order := hero_order()
	var n := order.size()
	if n == 0:
		return out
	var hh := _hero_h()
	var top := size.y - hh + 46.0
	var avail_h := hh - 46.0 - 40.0
	var gap := 10.0
	var extra := 18.0 if t.variant == "stud" else 0.0  # a gap between hidden and showing
	var w := minf((size.x - 40.0 - gap * (n - 1) - extra) / n, avail_h / CARD_ASPECT)
	w = minf(w, 150.0)
	var total := w * n + gap * (n - 1) + extra
	var x := (size.x - total) / 2.0
	for k in n:
		if t.variant == "stud" and k == _stud_hidden_count():
			x += extra
		out.append(Rect2(x, top, w, w * CARD_ASPECT))
		x += w + gap
	return out

## Stud: the hidden cards first, then the showing ones.
func hero_order() -> Array:
	var s: Dictionary = t.seats[viewer]
	var order: Array = []
	if t.variant != "stud":
		return range(s.hole.size())
	for k in s.hole.size():
		if not (k < s.up.size() and s.up[k]):
			order.append(k)
	for k in s.hole.size():
		if k < s.up.size() and s.up[k]:
			order.append(k)
	return order

func _stud_hidden_count() -> int:
	var s: Dictionary = t.seats[viewer]
	var n := 0
	for k in s.hole.size():
		if not (k < s.up.size() and s.up[k]):
			n += 1
	return n

# ---------- input ----------

func _on_input(event: InputEvent) -> void:
	# Phones send a touch AND an emulated click: clicks only (CLAUDE.md).
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if t == null:
		return
	var rects := hero_card_rects()
	var order := hero_order()
	for k in rects.size():
		if (rects[k] as Rect2).grow(8).has_point(event.position):
			card_tapped.emit(order[k])
			return

# ---------- drawing ----------

func _draw() -> void:
	if t == null or t.seats.is_empty():
		return
	var f := felt_rect()
	_draw_felt(f)
	var others := _others()
	for i in others:
		_draw_seat(i, seat_rect(i))
	_draw_board()
	_draw_pot()
	_draw_bets()
	_draw_hero()

func _draw_felt(f: Rect2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.09, 0.12)
	sb.set_corner_radius_all(int(minf(f.size.x, f.size.y) * 0.22))
	sb.border_color = Color(CYAN, 0.75)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(CYAN, 0.18)
	sb.shadow_size = 14
	draw_style_box(sb, f)
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0, 0, 0, 0)
	inner.set_corner_radius_all(int(minf(f.size.x, f.size.y) * 0.18))
	inner.border_color = Color(PURPLE, 0.35)
	inner.set_border_width_all(2)
	draw_style_box(inner, f.grow(-14))

func _won(i: int) -> Dictionary:
	if t.phase != "done":
		return {}
	for r in t.results:
		if int(r.seat) == i:
			return r
	return {}

func _cards_visible(i: int) -> bool:
	if t.phase == "done":
		var r := _won(i)
		return not r.is_empty() and bool(r.shown)
	return false

func _draw_seat(i: int, r: Rect2) -> void:
	var s: Dictionary = t.seats[i]
	var active: bool = i == t.to_act and t.phase in ["bet", "draw"]
	var res := _won(i)
	var winner: bool = not res.is_empty() and int(res.won) > 0
	var edge := DIM
	if bool(s.out):
		edge = Color(DIM, 0.35)
	elif winner:
		edge = GOLD
	elif active:
		edge = LIME
	elif not bool(s.folded):
		edge = MAGENTA if int(s.kind) == 0 else CYAN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.11, 0.92)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(edge, 0.9)
	sb.set_border_width_all(3 if (active or winner) else 2)
	var glow := 0.25
	if active and thinking == i:
		glow = 0.25 + 0.2 * sin(_pulse * 6.0)
	sb.shadow_color = Color(edge, glow)
	sb.shadow_size = 10 if (active or winner) else 4
	draw_style_box(sb, r)
	var pad := 8.0
	var fs_name := int(clampf(r.size.x * 0.095, 16, 24))
	var name_col := WHITE if not bool(s.folded) else DIM
	draw_string(_font, r.position + Vector2(pad, pad + fs_name), str(s.name), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2 - 26, fs_name, name_col)
	if t.button == i and not bool(s.out) and t.variant != "stud":
		_dealer_chip(Vector2(r.end.x - 16, r.position.y + 16), 12.0)
	var fs := int(clampf(r.size.x * 0.09, 15, 22))
	var y := r.position.y + pad + fs_name + 6 + fs
	var stack_text := _chips(int(s.stack)) if not bool(s.out) else tr("Out")
	draw_string(_font, Vector2(r.position.x + pad, y), stack_text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2, fs, GOLD.lerp(WHITE, 0.3))
	if show_styles and int(s.kind) == 0:
		var style_name: String = AI.STYLES[clampi(int(s.style), 0, AI.STYLES.size() - 1)][0]
		draw_string(_font, Vector2(r.position.x + pad, y), tr(style_name), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - pad * 2, fs - 3, Color(PURPLE, 1.0).lerp(WHITE, 0.3))
	# cards
	var n: int = s.hole.size()
	var bottom_text_h := fs + 10.0
	var card_top := y + 8.0
	var card_h := r.end.y - bottom_text_h - card_top
	if n > 0 and card_h > 20 and not bool(s.out):
		var cw := card_h / CARD_ASPECT
		var step := cw * 1.06
		var need := cw + step * (n - 1)
		if need > r.size.x - pad * 2:
			step = (r.size.x - pad * 2 - cw) / maxf(1.0, n - 1)
		var x0 := r.position.x + (r.size.x - (cw + step * (n - 1))) / 2.0
		var show_all := _cards_visible(i)
		for k in n:
			var cr := Rect2(x0 + step * k, card_top, cw, card_h)
			var up: bool = k < s.up.size() and s.up[k]
			if bool(s.folded) and not up:
				continue
			var face: bool = show_all or up
			var hl: bool = winner and res.has("best") and (res.best as Array).has(s.hole[k])
			Cards.draw_card(self, cr, s.hole[k], face, hl, bool(s.folded))
	# bottom line: last action / thinking / result
	var line := ""
	var col := DIM
	if not res.is_empty():
		if int(res.won) > 0:
			line = "+" + _chips(int(res.won))
			col = GOLD
		if str(res.desc) != "":
			line = (line + " · " if line != "" else "") + str(res.desc)
			if int(res.won) == 0:
				col = DIM
	elif thinking == i:
		line = tr("Thinking") + ".".repeat(1 + int(_pulse * 3.0) % 3)
		col = LIME
	elif str(s.act) != "":
		line = _act_text(s)
		col = _act_color(str(s.act))
	if line != "":
		var lfs := fs - 2
		var room := r.size.x - pad * 2
		var lw := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
		while lfs > 12 and lw > room:
			lfs -= 1
			lw = _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
		draw_string(_font, Vector2(r.position.x + pad, r.end.y - 9), line, HORIZONTAL_ALIGNMENT_CENTER, room, lfs, col)
		# Chips in front of a seat this round: a little stack by its action.
		if int(s.bet) > 0 and t.phase != "done":
			_chip_stack(Vector2(r.get_center().x - minf(lw, room) / 2.0 - 14, r.end.y - 15), 1)

func _act_text(s: Dictionary) -> String:
	var a := str(s.act)
	match a:
		"Call", "Bet", "Raise", "Complete", "Small blind", "Big blind", "Bring-in", "Ante", "All in":
			if int(s.amt) > 0:
				return tr(a) + " " + _chips(int(s.amt))
		"Draw":
			return tr("Draws %d") % int(s.amt)
		"Check":
			return tr(CHECK)
	return tr(a)

func _act_color(a: String) -> Color:
	match a:
		"Fold": return DIM
		"Raise", "Bet", "Complete": return MAGENTA.lerp(WHITE, 0.3)
		"All in": return GOLD
		"Call", "Check": return CYAN.lerp(WHITE, 0.3)
	return DIM

func _dealer_chip(c: Vector2, rad: float) -> void:
	draw_circle(c, rad + 3, Color(WHITE, 0.2))
	draw_circle(c, rad, WHITE)
	draw_string(_font, c + Vector2(-rad, rad * 0.45), "D", HORIZONTAL_ALIGNMENT_CENTER, rad * 2, int(rad * 1.3), Color(0.1, 0.1, 0.15))

func _draw_board() -> void:
	if t.variant != "holdem" and t.variant != "omaha":
		return
	var br := _board_rect()
	var cw := (br.size.x - 32) / 5.0
	var best: Array = []
	for r in t.results:
		if int(r.won) > 0 and r.has("best"):
			best += r.best
	for k in 5:
		var cr := Rect2(br.position.x + k * (cw + 8), br.position.y, cw, br.size.y)
		if k < t.board.size():
			Cards.draw_card(self, cr, t.board[k], true, t.phase == "done" and best.has(t.board[k]))
		else:
			Cards.draw_card(self, cr, -1)

func _pot_pos() -> Vector2:
	var f := felt_rect()
	if t.variant == "holdem" or t.variant == "omaha":
		var br := _board_rect()
		return Vector2(f.get_center().x, br.position.y - 26)
	return f.position + Vector2(f.size.x / 2.0, f.size.y * 0.7)

func _draw_pot() -> void:
	var total: int = t.pot
	if t.phase == "done":
		return
	if total <= 0 and t.pot_total() <= 0:
		return
	var p := _pot_pos()
	var text := tr("Pot") + " " + _chips(t.pot_total())
	_chip_stack(p + Vector2(-_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x / 2.0 - 22, -8), 3)
	draw_string(_font, Vector2(p.x - 200, p.y), text, HORIZONTAL_ALIGNMENT_CENTER, 400, 26, GOLD.lerp(WHITE, 0.25))
	if t.variant == "draw" or t.variant == "stud":
		var info := ""
		if t.variant == "draw":
			info = tr("Before the draw") if t.street == 0 and t.phase != "draw" else (tr("The draw") if t.phase == "draw" else tr("After the draw"))
		else:
			info = tr(["Third street", "Fourth street", "Fifth street", "Sixth street", "Seventh street"][clampi(t.street, 0, 4)])
		draw_string(_font, Vector2(p.x - 200, p.y + 34), info, HORIZONTAL_ALIGNMENT_CENTER, 400, 22, DIM)

func _draw_bets() -> void:
	var f := felt_rect()
	var center := f.get_center()
	# Only the viewer's bet sits on the felt; the others show theirs in
	# their seat (there's no room between six seats on a phone).
	var b: int = t.seats[viewer].bet if viewer >= 0 and viewer < t.seats.size() else 0
	if b > 0:
		var at := Vector2(center.x, f.end.y - 30)
		_chip_stack(at + Vector2(-12, -4), 2)
		draw_string(_font, at + Vector2(6, 4), _chips(b), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, WHITE)

func _chip_stack(p: Vector2, n: int) -> void:
	for k in n:
		var c := p + Vector2(0, -k * 4.0)
		draw_circle(c, 10, Color(MAGENTA, 0.9) if k % 2 == 0 else Color(CYAN, 0.9))
		draw_arc(c, 10, 0, TAU, 20, Color(WHITE, 0.7), 1.5, true)
		draw_arc(c, 6, 0, TAU, 16, Color(WHITE, 0.45), 1.0, true)

func _draw_hero() -> void:
	if viewer < 0 or viewer >= t.seats.size():
		return
	var s: Dictionary = t.seats[viewer]
	var hh := _hero_h()
	var top := size.y - hh
	var res := _won(viewer)
	var active: bool = viewer == t.to_act and t.phase in ["bet", "draw"]
	var name_text := str(s.name) if str(s.name) != "" else tr(you_text)
	var head := name_text + "  ·  " + (_chips(int(s.stack)) if not bool(s.out) else tr("Out"))
	var head_col := LIME if active else WHITE
	draw_string(_font, Vector2(20, top + 30), head, HORIZONTAL_ALIGNMENT_LEFT, size.x - 120, 26, head_col)
	if t.button == viewer and not bool(s.out) and t.variant != "stud":
		_dealer_chip(Vector2(size.x - 34, top + 22), 14.0)
	if hide_viewer:
		var rects := hero_card_rects()
		for k in rects.size():
			Cards.draw_card(self, rects[k], 0, false)
		return
	var rects := hero_card_rects()
	var order := hero_order()
	var best: Array = res.get("best", []) if not res.is_empty() and int(res.won) > 0 else []
	for k in rects.size():
		var idx: int = order[k]
		var r: Rect2 = rects[k]
		var picked := discards.has(idx)
		if picked:
			r.position.y += 18
		var card: int = s.hole[idx]
		Cards.draw_card(self, r, card, true, best.has(card) or picked, bool(s.folded) or picked)
		if picked:
			draw_string(_font, Vector2(r.position.x - 10, r.position.y - 6), tr("Swap").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 20, 20, GOLD)
	if t.variant == "stud" and rects.size() > 0:
		var hidden := _stud_hidden_count()
		if hidden > 0 and hidden < rects.size():
			var hr: Rect2 = rects[hidden - 1]
			draw_string(_font, Vector2(rects[0].position.x, top + 44 + rects[0].size.y + 26), tr("Hidden"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, DIM)
			var sr: Rect2 = rects[hidden]
			draw_string(_font, Vector2(sr.position.x, top + 44 + sr.size.y + 26), tr("Showing"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, DIM)
			draw_line(Vector2(hr.end.x + 9, hr.position.y), Vector2(hr.end.x + 9, hr.end.y), Color(DIM, 0.4), 2)
	# what you have right now
	var line := ""
	var col := CYAN.lerp(WHITE, 0.3)
	if not res.is_empty():
		line = str(res.desc)
		if int(res.won) > 0:
			line = "+" + _chips(int(res.won)) + ("  ·  " + line if line != "" else "")
			col = GOLD
	elif bool(s.folded):
		line = tr("Folded")
		col = DIM
	elif s.hole.size() >= 2 and t.phase != "idle":
		line = Eval.describe(t.hand_score(viewer))
	if line != "" and rects.size() > 0:
		var y: float = rects[0].end.y + (52.0 if t.variant == "stud" else 30.0)
		draw_string(_font, Vector2(0, minf(y, size.y - 6)), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, col)

static func _chips(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
