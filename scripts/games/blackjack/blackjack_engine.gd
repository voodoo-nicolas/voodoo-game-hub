extends RefCounted

## Blackjack against the dealer with play chips. Casino-standard rules:
## 6-deck shoe (reshuffled when a quarter remains), dealer stands on all 17s,
## blackjack pays 3:2, double down on the first two cards. No splitting.

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

func can_double() -> bool:
	return phase == Phase.PLAYER_TURN and player.size() == 2 and chips >= bet

## Starts a round. Returns false if the bet isn't allowed.
func deal(amount: int) -> bool:
	if phase == Phase.PLAYER_TURN or amount < MIN_BET or amount > chips:
		return false
	if shoe.size() < DECKS * 52 / 4:
		_new_shoe()
	bet = amount
	chips -= amount
	player = [_draw(), _draw()]
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
	if hand_value(player).total > 21:
		_settle()
	elif hand_value(player).total == 21:
		stand()

func stand() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	while hand_value(dealer).total < 17:
		dealer.append(_draw())
	_settle()

func double_down() -> void:
	if not can_double():
		return
	chips -= bet
	bet *= 2
	player.append(_draw())
	if hand_value(player).total > 21:
		_settle()
	else:
		stand()

func _settle() -> void:
	phase = Phase.ROUND_OVER
	var p: int = hand_value(player).total
	var d: int = hand_value(dealer).total
	var returned := 0
	if is_blackjack(player) and is_blackjack(dealer):
		outcome = "push"
		returned = bet
	elif is_blackjack(player):
		outcome = "blackjack"
		returned = bet + bet * 3 / 2
	elif is_blackjack(dealer):
		outcome = "lose"
	elif p > 21:
		outcome = "bust"
	elif d > 21:
		outcome = "dealer_bust"
		returned = bet * 2
	elif p > d:
		outcome = "win"
		returned = bet * 2
	elif p == d:
		outcome = "push"
		returned = bet
	else:
		outcome = "lose"
	chips += returned
	payout = returned - bet

## Out of chips: start over with a fresh stack.
func is_broke() -> bool:
	return phase != Phase.PLAYER_TURN and chips < MIN_BET

func rebuy() -> void:
	chips = STARTING_CHIPS
