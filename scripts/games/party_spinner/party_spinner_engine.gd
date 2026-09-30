extends RefCounted

## Party Spinner: the spinner for the classic body-twisting mat game -- a
## random limb (left/right hand/foot) onto a random colour. Pure logic.

const LIMBS := 4     # 0 left hand, 1 right hand, 2 left foot, 3 right foot
const COLORS := 4    # 0 red, 1 blue, 2 yellow, 3 green

var history: Array = []   # Vector2i(limb, colour), newest last

## Picks the next move; returns the wheel sector it lands on (0..15).
func spin() -> int:
	var sector := randi() % (LIMBS * COLORS)
	history.append(Vector2i(sector / COLORS, sector % COLORS))
	if history.size() > 8:
		history.pop_front()
	return sector

func last() -> Vector2i:
	return history.back() if not history.is_empty() else Vector2i(-1, -1)
