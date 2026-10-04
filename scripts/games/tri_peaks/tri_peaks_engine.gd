extends RefCounted

## Tri-Peaks solitaire: 28 cards in three overlapping peaks, the other 24
## in a stock. Take any uncovered card one rank above or below the top of
## the waste pile (Ace and King touch when `wrap` is on); it becomes the
## new top. Stuck? Turn the next stock card. Clear the peaks to win.
## Pure logic, no Nodes. Cards are ints 0..51 (see tri_peaks_cards.gd).

const N := 28
## Tableau slots: [row, x] with x in card widths (rows overlap by half).
const SLOTS := [
	[0, 1.5], [0, 4.5], [0, 7.5],
	[1, 1.0], [1, 2.0], [1, 4.0], [1, 5.0], [1, 7.0], [1, 8.0],
	[2, 0.5], [2, 1.5], [2, 2.5], [2, 3.5], [2, 4.5], [2, 5.5], [2, 6.5], [2, 7.5], [2, 8.5],
	[3, 0.0], [3, 1.0], [3, 2.0], [3, 3.0], [3, 4.0], [3, 5.0], [3, 6.0], [3, 7.0], [3, 8.0], [3, 9.0],
]
const PEAK_BONUS := 250
const WIN_BONUS := 1000

var tableau: Array = []   # card per slot
var gone: Array = []      # bool per slot
var stock: Array = []
var waste: Array = []
var wrap := true
var score: int = 0
var streak: int = 0
var best_streak: int = 0
var history: Array = []   # ["play", slot, points, streak_before] or ["draw", streak_before]

func deal(p_wrap: bool, rng: RandomNumberGenerator) -> void:
	wrap = p_wrap
	var deck: Array = range(52)
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	tableau = deck.slice(0, N)
	gone = []
	gone.resize(N)
	gone.fill(false)
	stock = deck.slice(N + 1)
	waste = [deck[N]]
	score = 0
	streak = 0
	best_streak = 0
	history = []

## Slots that lie on top of slot i (the next row down, half a card either side).
static func coverers(i: int) -> Array:
	var out: Array = []
	for j in N:
		if SLOTS[j][0] == SLOTS[i][0] + 1 and absf(SLOTS[j][1] - SLOTS[i][1]) == 0.5:
			out.append(j)
	return out

func exposed(i: int) -> bool:
	if gone[i]:
		return false
	for j in coverers(i):
		if not gone[j]:
			return false
	return true

static func rank(card: int) -> int:
	return card % 13 + 1

func fits(card: int) -> bool:
	var d := absi(rank(card) - rank(waste[-1]))
	return d == 1 or (wrap and d == 12)

func can_play(i: int) -> bool:
	return exposed(i) and fits(tableau[i])

func play(i: int) -> bool:
	if not can_play(i):
		return false
	var before := streak
	gone[i] = true
	waste.append(tableau[i])
	streak += 1
	best_streak = maxi(best_streak, streak)
	var pts := 10 * streak
	if SLOTS[i][0] == 0:
		pts += PEAK_BONUS
	if won():
		pts += WIN_BONUS + 50 * stock.size()
	score += pts
	history.append(["play", i, pts, before])
	return true

func draw() -> bool:
	if stock.is_empty():
		return false
	history.append(["draw", streak])
	waste.append(stock.pop_back())
	streak = 0
	return true

func undo() -> bool:
	if history.is_empty():
		return false
	var h: Array = history.pop_back()
	if h[0] == "play":
		gone[h[1]] = false
		waste.pop_back()
		score -= h[2]
		streak = h[3]
	else:
		stock.append(waste.pop_back())
		streak = h[1]
	return true

func remaining() -> int:
	return gone.count(false)

func won() -> bool:
	return remaining() == 0

func any_move() -> bool:
	for i in N:
		if can_play(i):
			return true
	return false

func stuck() -> bool:
	return not won() and stock.is_empty() and not any_move()
