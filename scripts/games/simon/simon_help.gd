extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "simon"
const TITLE := "Memory Lights"
const GOAL := "Repeat the sequence of colours for as long as you can."
const HOW := [
	"Watch the pads light up, then tap them in the same order.",
	"Each round adds one more colour to the end of the sequence.",
	"One wrong tap and the game is over. Your level is the longest sequence you repeated.",
	"⏸ pauses. A game is quick, so it isn't saved for later.",
]
const TIPS := [
	"Say the colours out loud, or give each one a number.",
	"Group the sequence into chunks of three or four.",
	"The sequence only ever grows at the end, so you just need to remember one new colour each round.",
]
const STATS := ["Best level", "Games played"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"Each colour has its own tone, so you can remember the sequence by ear as well as by sight.",
]
