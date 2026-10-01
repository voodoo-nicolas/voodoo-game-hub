extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "party_spinner"
const TITLE := "Party Spinner"
const GOAL := "The spinner for the body-twisting mat game — no cardboard arrow needed."
const HOW := [
	"Tap the wheel (or 🌀 Spin) to spin it.",
	"It picks a hand or foot and a colour. That player puts that hand or foot on a circle of that colour.",
	"Anyone who falls, or touches the mat with a knee or elbow, is out. The last player standing wins.",
	"Turn on auto-spin to spin by itself every few seconds, so nobody has to hold the phone. The last move is shown under Before.",
]
const TIPS := [
	"Put the phone where everyone can see it.",
	"Keep your weight low and centred to stay balanced.",
	"Use a mat with rows of red, yellow, green and blue circles.",
]
const STATS := ["Spins"]
