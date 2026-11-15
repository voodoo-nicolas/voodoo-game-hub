extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "mini_golf_3d"
const TITLE := "Mini Golf 3D"
const GOAL := "Sink the ball on all 9 holes in as few strokes as you can."
const HOW := [
	"Touch anywhere and drag down to pull back: the further you pull, the harder the putt (the bar at the bottom shows how hard). Drag sideways to aim; the yellow arrow shows the line. Let go to putt.",
	"The camera follows behind the ball and turns with your aim.",
	"Each hole has a par: the strokes a good round takes. Under par is a birdie (1 under), an eagle (2 under) or better.",
	"Ramps need a firm putt; too hard and the ball bounces back down. Mushroom bumpers bounce it away. Windmill sails, spinning bars and googly-eyed blocks knock it around: time your putt.",
	"Boost pads fling the ball through a loop-de-loop. Sand slows it right down. A pond or a fall into the clouds costs a stroke and puts the ball back where it last stopped.",
	"A ball going too fast skips over the cup. After 10 strokes the ball is picked up.",
	"⏸ pauses; Resume on the Home screen carries on the round where the ball lies.",
]
const TIPS := [
	"Gentle wins near the cup: a ball that just reaches it drops in.",
	"On a raised green, a medium putt beats a full one.",
	"Watch the windmill sails go round once before you putt through the tunnel.",
]
const STATS := ["Best round", "Holes in one", "Birdies or better", "Rounds played"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"To get round a loop, a ball must still be moving fast enough at the top that gravity alone can keep it on the track.",
	"A rolling ball keeps some of its energy in the spin, so it climbs a ramp less high than a sliding block launched at the same speed.",
]
