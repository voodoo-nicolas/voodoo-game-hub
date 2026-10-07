extends RefCounted

## Blackjack against the dealer with play chips. Casino-standard rules:
## 6-deck shoe (reshuffled when a quarter remains), dealer stands on all 17s,
## blackjack pays 3:2, double down on the first two cards, split a pair once
## (split aces get one card each; 21 after a split is 1:1, not a blackjack).

const DECKS := 6
const STARTING_CHIPS := 1000
const MIN_BET := 10
const SUITS := ["♠", "♥", "♦", "♣"]
const RANK_NAMES := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

enum Phase { BETTING, PLAYER_TURN, ROUND_OVER }

var shoe: Array = []
var player: Array = []  # cards: {rank: 1-13, suit: String}
var dealer: Array = []
var chips: int = STARTING_CHIPS
var bet: int = 0
var phase: int = Phase.BETTING
var outcome: String = ""  # "blackjack", "win", "lose", "push", "bust", "dealer_bust"
var payout: int = 0       # net chips won (+) or lost (-) this round

func _init() -> void:
	_new_shoe()

func _new_shoe() -> void:
	shoe = []
	for d in range(DECKS):
		for suit in SUITS:
			for rank in range(1, 14):
				shoe.append({"rank": rank, "suit": suit})
	shoe.shuffle()

func _draw() -> Dictionary:
	if shoe.is_empty():
		_new_shoe()
	return shoe.pop_back()

static func card_text(card: Dictionary) -> String:
	return RANK_NAMES[card.rank] + card.suit

static func is_red(card: Dictionary) -> bool:
	return card.suit == "♥" or card.suit == "♦"

## {total, soft}: aces count 11 when that doesn't bust, and `soft` says one
## is currently counted that way.
static func hand_value(hand: Array) -> Dictionary:
	var total := 0
	var aces := 0
	for card in hand:
		var r: int = card.rank
		if r == 1:
			aces += 1
			total += 1
		else:
			total += min(r, 10)
	var soft := false
	if aces > 0 and total + 10 <= 21:
		total += 10
		soft = true
	return {"total": total, "soft": soft}

static func is_blackjack(hand: Array) -> bool:
	return hand.size() == 2 and hand_value(hand).total == 21

## The hands in play: {cards, bet, done, outcome, returned}. `player` and `bet`
## always point at the hand being played (so a single hand reads as before).
var hands: Array = []
var cur: int = 0
var was_split: bool = false
var split_aces: bool = false

func _sync() -> void:
	player = hands[cur].cards
	bet = hands[cur].bet

## Chips on the table across all hands.
func total_bet() -> int:
	var t := 0
	for h in hands:
		t += int(h.bet)
	return t

static func _card_value(card: Dictionary) -> int:
	return mini(int(card.rank), 10)

func can_double() -> bool:
	return phase == Phase.PLAYER_TURN and player.size() == 2 and chips >= bet and not split_aces

## Two cards of the same value (a 10 and a king count), once per round.
func can_split() -> bool:
	return phase == Phase.PLAYER_TURN and hands.size() == 1 and player.size() == 2 \
		and _card_value(player[0]) == _card_value(player[1]) and chips >= bet

## Starts a round. Returns false if the bet isn't allowed.
func deal(amount: int) -> bool:
	if phase == Phase.PLAYER_TURN or amount < MIN_BET or amount > chips:
		return false
	if shoe.size() < DECKS * 52 / 4:
		_new_shoe()
	chips -= amount
	hands = [{"cards": [_draw(), _draw()], "bet": amount, "done": false, "outcome": "", "returned": 0}]
	cur = 0
	was_split = false
	split_aces = false
	_sync()
	dealer = [_draw(), _draw()]
	outcome = ""
	payout = 0
	phase = Phase.PLAYER_TURN
	# Naturals end the round at once (the dealer "peeks" for blackjack).
	if is_blackjack(player) or is_blackjack(dealer):
		_settle()
	return true

func hit() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	player.append(_draw())
	if hand_value(player).total >= 21:
		_advance()

func stand() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	_advance()

func double_down() -> void:
	if not can_double():
		return
	chips -= bet
	hands[cur].bet *= 2
	bet = hands[cur].bet
	player.append(_draw())
	_advance()

## Splits a pair into two hands with their own bets, one new card each.
## Split aces get that one card only and then stand.
func split() -> void:
	if not can_split():
		return
	chips -= bet
	var second: Dictionary = hands[0].cards.pop_back()
	hands[0].cards.append(_draw())
	hands.append({"cards": [second, _draw()], "bet": hands[0].bet, "done": false, "outcome": "", "returned": 0})
	was_split = true
	cur = 0
	_sync()
	if hands[0].cards[0].rank == 1:
		split_aces = true
		for h in hands:
			h.done = true
		_dealer_plays()
	elif hand_value(player).total == 21:
		_advance()

## The hand in play is finished: on to the next one, or the dealer.
func _advance() -> void:
	hands[cur].done = true
	for i in hands.size():
		if not hands[i].done:
			cur = i
			_sync()
			if hand_value(player).total == 21:
				_advance()
			return
	_dealer_plays()

func _dealer_plays() -> void:
	var live := false
	for h in hands:
		if hand_value(h.cards).total <= 21:
			live = true
	while live and hand_value(dealer).total < 17:
		dealer.append(_draw())
	_settle()

func _settle() -> void:
	phase = Phase.ROUND_OVER
	var d: int = hand_value(dealer).total
	var staked := 0
	var returned := 0
	for h in hands:
		var p: int = hand_value(h.cards).total
		var natural: bool = not was_split and is_blackjack(h.cards)
		var back := 0
		if natural and is_blackjack(dealer):
			h.outcome = "push"
			back = h.bet
		elif natural:
			h.outcome = "blackjack"
			back = h.bet + h.bet * 3 / 2
		elif not was_split and is_blackjack(dealer):
			h.outcome = "lose"
		elif p > 21:
			h.outcome = "bust"
		elif d > 21:
			h.outcome = "dealer_bust"
			back = h.bet * 2
		elif p > d:
			h.outcome = "win"
			back = h.bet * 2
		elif p == d:
			h.outcome = "push"
			back = h.bet
		else:
			h.outcome = "lose"
		h.returned = back
		h.done = true
		staked += int(h.bet)
		returned += back
	chips += returned
	payout = returned - staked
	outcome = hands[0].outcome if hands.size() == 1 else "split"

## Out of chips: start over with a fresh stack.
func is_broke() -> bool:
	return phase != Phase.PLAYER_TURN and chips < MIN_BET

func rebuy() -> void:
	chips = STARTING_CHIPS
