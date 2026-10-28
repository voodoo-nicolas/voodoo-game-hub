extends Control

## Draws a poker table: the felt, the other seats around it (name, chips,
## cards, last action, bet), the board and pot in the middle, and the
## viewer's own cards big at the bottom. Colours come from video_poker_look.gd
## (classic and voodoo looks). The game sets the fields and calls
## queue_redraw(); taps on the viewer's cards come out as `card_tapped`.

signal card_tapped(index: int)

const Cards = preload("res://scripts/games/video_poker/video_poker_cards.gd")
const Look = preload("res://scripts/games/video_poker/video_poker_look.gd")
const Chips = preload("res://scripts/games/video_poker/video_poker_chips.gd")
const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")
const AI = preload("res://scripts/games/video_poker/video_poker_ai.gd")

const CARD_ASPECT := 1.42
## Room kept for the pot line (chips and amount) above the board.
const POT_W := 210.0
## Bets on the felt keep this far apart (across plus twice down), so a pile and its amount never sit on another.
const BET_APART := 130.0
## Poker's "Check" has its own key: plain "Check" is already the Spanish
## "Revisar" of Code Breaker and Crossword (es.json is one shared map).
const CHECK := "Check "

var t  # the Table (video_poker_table.gd)
var viewer: int = 0          # the seat drawn at the bottom
var hide_viewer: bool = false  # pass-and-play: cards stay down until "I'm ready"
var thinking: int = -1       # seat that's thinking (drawn pulsing)
var discards: Array = []     # viewer's cards picked to throw away (draw phase)
var show_styles: bool = false  # training: label each computer's style
var you_text := "You"
var win_text := ""           # "Win ≈ 36%": shown with your hand when the Options switch is on
var piles := true             # chips drawn as piles (off: numbers only)

var _font: Font
var _pulse := 0.0

func _ready() -> void:
	_font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # the card art is drawn smaller than it is
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input)
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if thinking >= 0:
		_pulse += delta
		queue_redraw()

# ---------- geometry ----------

func _hero_h() -> float:
	if size.x > size.y * 1.1:  # landscape: the table is wide, the hands a little smaller
		return clampf(size.y * 0.3, 150.0, 300.0)
	return clampf(size.y * 0.32, 190.0, 360.0)

## The whole table, rail included: a pill (oval) above the viewer's own cards.
func felt_rect() -> Rect2:
	return Rect2(10, 6, size.x - 20, size.y - _hero_h() - 12)

func _rail_w() -> float:
	var f := felt_rect()
	return clampf(minf(f.size.x, f.size.y) * 0.05, 10.0, 24.0)

## The felt inside the rail.
func play_rect() -> Rect2:
	return felt_rect().grow(-_rail_w())

func _others() -> Array:
	var out: Array = []
	var n: int = t.seats.size()
	for k in range(1, n):
		out.append((viewer + k) % n)
	return out

## Size of a seat's plate: a share of the felt, so it fits any shape of screen.
func plate_size() -> Vector2:
	var p := play_rect()
	var few := 1.0 + 0.16 * (5 - clampi(_others().size(), 1, 5))  # fewer seats: roomier plates
	# (a short felt, landscape at a big text size, keeps room for the board between the plates)
	var w := clampf(minf(minf(p.size.x * 0.22, p.size.y * 0.33) * few, p.size.y * 0.38), 92.0, 190.0)
	return Vector2(w, w * 0.78)

## Where another seat's plate goes: round an ellipse inside the felt, the
## viewer's place (straight down) left open and the others spread evenly round
## the rest, the first to the viewer's left. Works for any number of seats and
## any shape of screen.
func seat_rect(seat: int) -> Rect2:
	var others := _others()
	var k := others.find(seat)
	if k < 0:
		return Rect2()
	var p := play_rect()
	var ps := plate_size()
	var ang := PI / 2.0 + (k + 1) * TAU / (others.size() + 1)  # screen angles: 90 degrees is down
	var rx := p.size.x / 2.0 - ps.x / 2.0 - 6.0
	var ry := p.size.y / 2.0 - ps.y / 2.0 - 6.0
	var at := p.get_center() + Vector2(cos(ang) * rx, sin(ang) * ry)
	return Rect2(at - ps / 2.0, ps)

## Everything on the felt the board must keep clear of: the seats' plates and
## the room for the viewer's own bet.
func _obstacles() -> Array:
	var p := play_rect()
	var out: Array = []
	for i in _others():
		out.append(seat_rect(i).grow(8))
	out.append(Rect2(p.get_center().x - 100, p.end.y - 66, 200, 60))
	return out

## The community cards, in the middle of the felt, as big as fit between the
## seats (with the pot line above them): the biggest size that fits anywhere
## down the middle, nearest the centre first.
func _board_rect() -> Rect2:
	var p := play_rect()
	var obstacles := _obstacles()
	var cw := minf(96.0, (p.size.x - 40.0) / 5.6)
	var r := Rect2()
	while cw >= 28.0:
		var w := cw * 5 + 8 * 4
		var ch := cw * CARD_ASPECT
		for off in [0.1, 0.16, 0.04, 0.22, -0.04, 0.28, -0.1]:
			var cy: float = p.get_center().y + p.size.y * off
			r = Rect2(p.get_center().x - w / 2.0, cy - ch / 2.0, w, ch)
			# with the pot line (chips and amount, up to 250 wide) above it
			var probe := Rect2(p.get_center().x - maxf(w, POT_W) / 2.0, r.position.y - 58, maxf(w, POT_W), r.size.y + 58)
			var hit := not p.grow(-4).encloses(r)
			for o in obstacles:
				hit = hit or (o as Rect2).intersects(probe)
			if not hit:
				return r
		cw -= 2.0
	return r

## Where a seat's bet lies on the felt: a plate's length towards the middle,
## above or below the plate or beside it, whichever is clear of the plates, the
## board and the bets already placed (the viewer's: low in the middle).
func bet_spot(seat: int) -> Vector2:
	var p := play_rect()
	var c := p.get_center()
	var mine := Vector2(c.x, p.end.y - 34)
	if seat == viewer:
		return mine
	var board := _board_rect() if t.rules().board_size() > 0 else Rect2()
	var taken: Array = [mine]
	for i in _others():
		var spot := _pick_spot(i, board, taken)
		if i == seat:
			return spot
		taken.append(spot)
	return mine

func _pick_spot(seat: int, board: Rect2, taken: Array) -> Vector2:
	var p := play_rect()
	var c := p.get_center()
	var r := seat_rect(seat)
	var rc := r.get_center()
	var vs := signf(c.y - rc.y) if absf(c.y - rc.y) > 1.0 else 1.0
	var hs := signf(c.x - rc.x) if absf(c.x - rc.x) > 1.0 else 1.0
	var candidates: Array = [
		rc + Vector2(0, vs * (r.size.y / 2.0 + 24.0)),
		rc + Vector2(hs * (r.size.x / 2.0 + 44.0), 0),
		rc + Vector2(0, -vs * (r.size.y / 2.0 + 24.0)),
		rc + Vector2(-hs * (r.size.x / 2.0 + 44.0), 0),
	]
	var inner := p.grow(-14)
	var first_clear := -1
	for k in candidates.size():
		var spot: Vector2 = candidates[k]
		var clear := inner.has_point(spot) and not board.grow(10).has_point(spot)
		for i in _others():
			clear = clear and not seat_rect(i).grow(14).has_point(spot)
		if not clear:
			continue
		if first_clear < 0:
			first_clear = k
		var free := true
		for o in taken:
			free = free and absf(spot.x - (o as Vector2).x) + absf(spot.y - (o as Vector2).y) * 2.0 >= BET_APART
		if free:
			return spot
	return candidates[maxi(first_clear, 0)]

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
	var extra := 18.0 if t.rules().has_up_cards() else 0.0  # a gap between hidden and showing
	var w := minf((size.x - 40.0 - gap * (n - 1) - extra) / n, avail_h / CARD_ASPECT)
	w = minf(w, 150.0)
	var total := w * n + gap * (n - 1) + extra
	var x := (size.x - total) / 2.0
	for k in n:
		if t.rules().has_up_cards() and k == _stud_hidden_count():
			x += extra
		out.append(Rect2(x, top, w, w * CARD_ASPECT))
		x += w + gap
	return out

## Stud: the hidden cards first, then the showing ones.
func hero_order() -> Array:
	var s: Dictionary = t.seats[viewer]
	var order: Array = []
	if not t.rules().has_up_cards():
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
	if play_rect().size.x < 40.0 or play_rect().size.y < 40.0:  # before the first layout
		return
	_draw_felt(f)
	var others := _others()
	for i in others:
		_draw_seat(i, seat_rect(i))
	_draw_bets()
	_draw_board()
	_draw_pot()
	_draw_hero()

## The table: a leather rail with studs round a felt, a pill (oval) in the
## look's colours (classic: leather, brass and gold; voodoo: dark rail with neon
## studs and glow). The owner's "crest" art, when there is one, sits faintly in
## the middle of the felt.
func _draw_felt(f: Rect2) -> void:
	var glow := Look.f("glow")
	var rad := int(minf(f.size.x, f.size.y) / 2.0)
	var rail_w := _rail_w()
	# the rail
	var sb := StyleBoxFlat.new()
	sb.bg_color = Look.c("rail")
	sb.set_corner_radius_all(rad)
	sb.border_color = Color(Look.c("glow_a"), 0.85) if glow > 0.0 else Look.c("rail_hi")
	sb.set_border_width_all(3)
	sb.shadow_color = Color(Look.c("glow_a"), 0.3) if glow > 0.0 else Color(0, 0, 0, 0.55)
	sb.shadow_size = 14 if glow > 0.0 else 12
	sb.shadow_offset = Vector2(0, 0) if glow > 0.0 else Vector2(0, 5)
	draw_style_box(sb, f)
	# a lighter ridge along the middle of the padding
	var ridge := StyleBoxFlat.new()
	ridge.bg_color = Color(0, 0, 0, 0)
	ridge.set_corner_radius_all(maxi(4, rad - int(rail_w * 0.35)))
	ridge.border_color = Color(Look.c("rail_hi"), 0.35)
	ridge.set_border_width_all(2)
	draw_style_box(ridge, f.grow(-rail_w * 0.35))
	_draw_studs(f.grow(-rail_w * 0.5), rail_w)
	# the felt, lighter in the middle
	var felt := f.grow(-rail_w)
	var fr := maxi(4, rad - int(rail_w))
	var base := StyleBoxFlat.new()
	base.bg_color = Look.c("felt_deep")
	base.set_corner_radius_all(fr)
	base.border_color = Color(Look.c("glow_b"), 0.7) if glow > 0.0 else Color(Look.c("rail_lo"), 0.9)
	base.set_border_width_all(2)
	draw_style_box(base, felt)
	var mid := StyleBoxFlat.new()
	mid.bg_color = Color(Look.c("felt"), 0.85)
	mid.set_corner_radius_all(int(fr * 0.8))
	mid.shadow_color = Color(Look.c("felt"), 0.6)
	mid.shadow_size = int(minf(felt.size.x, felt.size.y) * 0.08)
	draw_style_box(mid, felt.grow(-minf(felt.size.x, felt.size.y) * 0.1))
	# the inlay line
	var inlay := StyleBoxFlat.new()
	inlay.bg_color = Color(0, 0, 0, 0)
	inlay.set_corner_radius_all(maxi(4, fr - 9))
	inlay.border_color = Color(Look.c("felt_line"), 0.8 if glow == 0.0 else 0.5)
	inlay.set_border_width_all(2)
	draw_style_box(inlay, felt.grow(-9))
	var crest := Look.tex("crest")
	if crest != null:
		var cs := minf(felt.size.x, felt.size.y) * 0.42
		draw_texture_rect(crest, Rect2(felt.get_center() - Vector2(cs, cs) / 2.0, Vector2(cs, cs)), false, Color(1, 1, 1, 0.5))

## Studs along the middle of the rail, evenly spaced round the pill `track`.
func _draw_studs(track: Rect2, rail_w: float) -> void:
	var r := minf(track.size.x, track.size.y) / 2.0
	var straight := absf(track.size.x - track.size.y)
	var perimeter := 2.0 * straight + 2.0 * PI * r
	var count := maxi(8, int(perimeter / 56.0))
	var glow := Look.f("glow")
	var rs := clampf(rail_w * 0.3, 3.5, 7.0)
	for k in count:
		var at := _pill_point(track, perimeter * k / count)
		if glow > 0.0:
			draw_circle(at, rs + 3.0, Color(Look.c("glow_a"), 0.18))
		draw_circle(at, rs + 1.2, Look.c("rail_lo"))
		draw_circle(at, rs, Look.c("stud"))
		draw_circle(at + Vector2(-rs * 0.3, -rs * 0.3), rs * 0.38, Look.c("stud_hi"))

## A point `u` along the outline of the pill `rect`, clockwise from the top of its left end.
func _pill_point(rect: Rect2, u: float) -> Vector2:
	var wide := rect.size.x >= rect.size.y
	var r := minf(rect.size.x, rect.size.y) / 2.0
	var l := absf(rect.size.x - rect.size.y)
	var arc := PI * r
	u = fposmod(u, 2.0 * l + 2.0 * arc)
	var p: Vector2
	if u < l:
		p = Vector2(-l / 2.0 + u, -r)
	elif u < l + arc:
		var a := (u - l) / r - PI / 2.0
		p = Vector2(l / 2.0 + r * cos(a), r * sin(a))
	elif u < 2.0 * l + arc:
		p = Vector2(l / 2.0 - (u - l - arc), r)
	else:
		var a2 := (u - 2.0 * l - arc) / r + PI / 2.0
		p = Vector2(-l / 2.0 + r * cos(a2), r * sin(a2))
	return rect.get_center() + (p if wide else Vector2(p.y, p.x))

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
	var edge := Look.c("dim")
	if bool(s.out):
		edge = Color(Look.c("dim"), 0.35)
	elif winner:
		edge = Look.c("gold")
	elif active:
		edge = Look.c("active")
	elif not bool(s.folded):
		edge = Look.c("cpu") if int(s.kind) == 0 else Look.c("you")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Look.c("seat_bg")
	sb.set_corner_radius_all(14)
	sb.border_color = Color(edge, 0.9)
	sb.set_border_width_all(3 if (active or winner) else 2)
	var glow := 0.25 * (0.35 + 0.65 * Look.f("glow"))
	if active and thinking == i:
		glow = 0.25 + 0.2 * sin(_pulse * 6.0)
	sb.shadow_color = Color(edge, glow)
	sb.shadow_size = 10 if (active or winner) else 4
	draw_style_box(sb, r)
	var pad := 8.0
	var fs_name := int(clampf(r.size.x * 0.095, 16, 24))
	var name_col := Look.c("text") if not bool(s.folded) else Look.c("dim")
	draw_string(_font, r.position + Vector2(pad, pad + fs_name), str(s.name), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2 - 26, fs_name, name_col)
	if t.button == i and not bool(s.out) and t.rules().has_dealer_button():
		Chips.draw_dealer(self, Vector2(r.end.x - 19, r.position.y + 19), 15.0)
	var fs := int(clampf(r.size.x * 0.09, 15, 22))
	var y := r.position.y + pad + fs_name + 6 + fs
	var stack_text := _chips(int(s.stack)) if not bool(s.out) else tr("Out")
	draw_string(_font, Vector2(r.position.x + pad, y), stack_text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2, fs, Look.c("gold").lerp(Look.c("text"), 0.3))
	if r.size.x >= 120.0 and not bool(s.out) and int(s.stack) > 0:
		var pd := 14.0
		if piles:
			Chips.draw_stack(self, Vector2(r.end.x - 12.0 - Chips.stack_width(int(s.stack), pd) / 2.0, y - 3.0), int(s.stack), pd)
	if show_styles and int(s.kind) == 0:
		var style_name: String = AI.STYLES[clampi(int(s.style), 0, AI.STYLES.size() - 1)][0]
		draw_string(_font, Vector2(r.position.x + pad, y), tr(style_name), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - pad * 2, fs - 3, Color(Look.c("line2"), 1.0).lerp(Look.c("text"), 0.3))
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
	var col := Look.c("dim")
	if not res.is_empty():
		if int(res.won) > 0:
			line = "+" + _chips(int(res.won))
			col = Look.c("gold")
		if result_text(res) != "":
			line = (line + " · " if line != "" else "") + result_text(res)
			if int(res.won) == 0:
				col = Look.c("dim")
	elif thinking == i:
		line = tr("Thinking") + ".".repeat(1 + int(_pulse * 3.0) % 3)
		col = Look.c("active")
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

func _act_text(s: Dictionary) -> String:
	var a := str(s.act)
	match a:
		"Call", "Bet", "Raise", "Complete", "Small blind", "Big blind", "Bring-in", "Ante", "All in":
			if int(s.amt) > 0:
				return tr(a) + " " + _chips(int(s.amt))
		"Draw":
			return tr("Draws %d") % int(s.amt)
		"Discard":
			return tr("Discards")
		"Check":
			return tr(CHECK)
	return tr(a)

func _act_color(a: String) -> Color:
	match a:
		"Fold": return Look.c("dim")
		"Raise", "Bet", "Complete": return Look.c("accent_raise").lerp(Look.c("text"), 0.3)
		"All in": return Look.c("gold")
		"Call", "Check": return Look.c("accent_call").lerp(Look.c("text"), 0.3)
	return Look.c("dim")

func _draw_board() -> void:
	if t.rules().board_size() <= 0:
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
	var p := play_rect()
	if t.rules().board_size() > 0:
		var br := _board_rect()
		return Vector2(p.get_center().x, br.position.y - 26)
	return p.get_center() + Vector2(0, -p.size.y * 0.04)

func _draw_pot() -> void:
	var total: int = t.pot
	if t.phase == "done":
		return
	if total <= 0 and t.pot_total() <= 0:
		return
	var p := _pot_pos()
	var text := tr("Pot") + " " + _chips(t.pot_total())
	var pot_d := 24.0
	var text_w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	if piles:
		Chips.draw_stack(self, p + Vector2(-text_w / 2.0 - Chips.stack_width(t.pot_total(), pot_d) / 2.0 - 8.0, -2), t.pot_total(), pot_d)
	draw_string(_font, Vector2(p.x - 200, p.y), text, HORIZONTAL_ALIGNMENT_CENTER, 400, 24, Look.c("gold").lerp(Look.c("text"), 0.25))
	var note: String = t.rules().round_note(t)
	if note != "":
		draw_string(_font, Vector2(p.x - 200, p.y + 34), tr(note), HORIZONTAL_ALIGNMENT_CENTER, 400, 22, Look.c("dim"))

## Every seat's bet this round lies on the felt as a pile and its amount.
func _draw_bets() -> void:
	if t.phase == "done":
		return
	for i in t.seats.size():
		var b: int = int(t.seats[i].bet)
		if b <= 0 or (i != viewer and not _others().has(i)):
			continue
		var at := bet_spot(i)
		var bd := 22.0
		var sw := Chips.stack_width(b, bd) if piles else 0.0
		var text := _chips(b)
		var fs := 18
		var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var gap := 6.0 if piles else 0.0
		var x0 := at.x - (sw + gap + tw) / 2.0
		if piles:
			Chips.draw_stack(self, Vector2(x0 + sw / 2.0, at.y), b, bd)
		draw_string(_font, Vector2(x0 + sw + gap, at.y + 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Look.c("text"))

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
	var head_col := Look.c("active") if active else Look.c("text")
	draw_string(_font, Vector2(20, top + 30), head, HORIZONTAL_ALIGNMENT_LEFT, size.x - 120, 26, head_col)
	if t.button == viewer and not bool(s.out) and t.rules().has_dealer_button():
		Chips.draw_dealer(self, Vector2(size.x - 34, top + 22), 17.0)
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
			draw_string(_font, Vector2(r.position.x - 10, r.position.y - 6), tr(t.rules().discard_word()).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 20, 20, Look.c("gold"))
	if t.rules().has_up_cards() and rects.size() > 0:
		var hidden := _stud_hidden_count()
		if hidden > 0 and hidden < rects.size():
			var hr: Rect2 = rects[hidden - 1]
			draw_string(_font, Vector2(rects[0].position.x, top + 44 + rects[0].size.y + 26), tr("Hidden"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Look.c("dim"))
			var sr: Rect2 = rects[hidden]
			draw_string(_font, Vector2(sr.position.x, top + 44 + sr.size.y + 26), tr("Showing"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Look.c("dim"))
			draw_line(Vector2(hr.end.x + 9, hr.position.y), Vector2(hr.end.x + 9, hr.end.y), Color(Look.c("dim"), 0.4), 2)
	# what you have right now
	var line := ""
	var col := Look.c("you").lerp(Look.c("text"), 0.3)
	if not res.is_empty():
		line = result_text(res)
		if int(res.won) > 0:
			line = "+" + _chips(int(res.won)) + ("  ·  " + line if line != "" else "")
			col = Look.c("gold")
	elif bool(s.folded):
		line = tr("Folded")
		col = Look.c("dim")
	elif s.hole.size() >= 2 and t.phase != "idle":
		line = t.describe(t.hand_score(viewer))
		if t.rules().is_split():
			var lo: int = t.rules().low_score(s.hole, t.board)
			line += "  ·  " + (tr("Low: %s") % t.rules().describe_low(lo) if lo >= 0 else tr("No low"))
		if win_text != "":
			line += "  ·  " + win_text
	if line != "" and rects.size() > 0:
		var y: float = rects[0].end.y + (52.0 if t.rules().has_up_cards() else 30.0)
		draw_string(_font, Vector2(0, minf(y, size.y - 6)), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, col)

## A showdown result in words: the high hand, and in a Hi-Lo game the low too.
static func result_text(r: Dictionary) -> String:
	var parts: Array = []
	if str(r.desc) != "":
		parts.append(str(r.desc))
	if str(r.get("low_desc", "")) != "":
		parts.append(str(TranslationServer.translate("Low: %s")) % str(r.low_desc))
	return " · ".join(parts)

static func _chips(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
