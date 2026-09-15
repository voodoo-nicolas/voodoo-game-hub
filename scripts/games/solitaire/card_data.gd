extends RefCounted

## suit: 0=Spades, 1=Hearts, 2=Diamonds, 3=Clubs
const SPADES := 0
const HEARTS := 1
const DIAMONDS := 2
const CLUBS := 3

var rank: int  # 1=Ace ... 11=Jack, 12=Queen, 13=King
var suit: int
var face_up: bool = false

func _init(r: int = 1, s: int = 0, up: bool = false) -> void:
	rank = r
	suit = s
	face_up = up

func is_red() -> bool:
	return suit == HEARTS or suit == DIAMONDS

func rank_str() -> String:
	match rank:
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
		_: return str(rank)

func suit_symbol() -> String:
	match suit:
		SPADES: return "♠"
		HEARTS: return "♥"
		DIAMONDS: return "♦"
		_: return "♣"

func duplicate_card():
	var c = get_script().new(rank, suit, face_up)
	return c
