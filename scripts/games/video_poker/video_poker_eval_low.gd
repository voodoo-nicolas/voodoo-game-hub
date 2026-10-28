extends RefCounted

## Eight-or-better low hands (Omaha Hi-Lo): five different ranks, none above an
## 8, the Ace counting low, straights and flushes ignored. The best low is
## A-2-3-4-5, then A-2-3-4-6 ... a lower top card wins, then the next one down.
## A low score is a number where bigger is better (like a high score), -1 when
## there is no low.

## The highest card a low may have.
const QUALIFY := 8
## 9^5: scores are this minus the base-9 number of the five ranks, high to low.
const TOP := 59049

## Ace = 1 .. King = 13.
static func rank(card: int) -> int:
	var r := card % 13
	return 1 if r == 0 else r + 1

## Score of exactly five cards as a low, or -1.
static func five_score(cards: Array) -> int:
	var seen := {}
	var ranks: Array = []
	for c in cards:
		var r := rank(int(c))
		if r > QUALIFY or seen.has(r):
			return -1
		seen[r] = true
		ranks.append(r)
	ranks.sort()
	ranks.reverse()
	var key := 0
	for r in ranks:
		key = key * 9 + int(r)
	return TOP - key

## The best low of exactly two of `hole` and three of `board`:
## {"score": int, "cards": the five}. score -1 (cards []) when there is none.
static func best(hole: Array, board: Array) -> Dictionary:
	var best_score := -1
	var best_cards: Array = []
	if board.size() < 3:
		return {"score": -1, "cards": []}
	for a in hole.size():
		if rank(int(hole[a])) > QUALIFY:
			continue
		for b in range(a + 1, hole.size()):
			if rank(int(hole[b])) > QUALIFY:
				continue
			for x in board.size():
				for y in range(x + 1, board.size()):
					for z in range(y + 1, board.size()):
						var five := [hole[a], hole[b], board[x], board[y], board[z]]
						var s := five_score(five)
						if s > best_score:
							best_score = s
							best_cards = five
	return {"score": best_score, "cards": best_cards}

## "8-6-4-2-A": the ranks from the top down.
static func describe(score: int) -> String:
	if score < 0:
		return ""
	var key := TOP - score
	var ranks: Array = []
	for i in 5:
		ranks.append(key % 9)
		key /= 9
	ranks.reverse()
	var out: PackedStringArray = []
	for r in ranks:
		out.append("A" if int(r) == 1 else str(int(r)))
	return "-".join(out)
