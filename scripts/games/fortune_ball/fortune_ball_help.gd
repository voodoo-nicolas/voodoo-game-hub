extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "fortune_ball"
const TITLE := "Fortune Ball"
const GOAL := "Ask the ball a yes-or-no question and see what fate says."
const HOW := [
	"On Home, pick the ball's voice: Classic answers, or Spooky answers from the spirits.",
	"Think of a yes-or-no question — or say it out loud for everyone.",
	"Shake your phone. No sensor? Grab the ball and flick it around, tap it, or press Shake.",
	"Stop shaking: the ball settles and the answer floats up in its window.",
	"Green answers lean yes, gold ones are unsure, pink ones lean no.",
	"⏸ pauses. There's nothing to save: every question is fresh.",
]
const TIPS := [
	"A small bump doesn't count — give it a real shake.",
	"The answers are just for fun. Don't make big decisions with a ball!",
	"No answer repeats until you've seen them all.",
]
const STATS := ["Questions asked", "Yes answers", "No answers"]
