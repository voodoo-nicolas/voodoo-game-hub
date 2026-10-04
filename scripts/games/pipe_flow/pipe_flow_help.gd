extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "pipe_flow"
const TITLE := "Pipe Flow"
const GOAL := "Turn the pipes so the water from the pump in the middle reaches every piece, with no open ends."
const HOW := [
	"Every piece starts turned the wrong way. Tap a piece to turn it a quarter turn clockwise.",
	"Pieces joined to the gold pump fill with blue water; the rest stay purple.",
	"A pink dot marks a wet pipe that leads nowhere — a leak.",
	"The puzzle is solved when every piece is wet and nothing leaks.",
	"Pick a size on the Home screen: Easy 5 × 5 up to Expert 11 × 11. Every board can be solved.",
	"⏸ pauses the clock and keeps the board; Resume on the Home screen carries on.",
]
const TIPS := [
	"Start at the edges and corners: a pipe there can only point inwards.",
	"End pieces (one opening) can never face each other — that would close off a pair.",
	"Straight pieces have only two useful positions, so they're quick to settle.",
]
const STATS := ["Puzzles solved", "Best time (Easy)", "Best time (Medium)", "Best time (Hard)", "Best time (Expert)"]
