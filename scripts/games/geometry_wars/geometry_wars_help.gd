extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "geometry_wars"
const TITLE := "Geometry Wars"
const GOAL := "Survive the swarm of neon shapes and score as many points as you can."
const HOW := [
	"Hold the phone sideways. The left stick flies the ship, and it points the way you steer. The right stick aims and fires without turning the ship.",
	"You fire bursts of three shots, ten bursts a second. The middle shot is faster and flies farther.",
	"After you appear, a glowing halo keeps you safe for 5 seconds. Six quick beeps warn that it is about to fade.",
	"Kills drop green geoms. Fly over one to raise your score multiplier by 1 — they vanish after 3 seconds. Huge gold geoms are worth 10.",
	"Every kill scores its points times your multiplier.",
	"💣 Bomb wipes out every enemy on screen. You start with 3 and earn another every 2,500 points.",
	"Touching anything costs one of your three lives, clears the screen and resets the multiplier.",
	"Wanderers and neutrons drift and bounce. Blue grunts chase you and get faster the longer they live. Green weavers dodge your shots. Pink spinners split in three. Tiny mayflies swarm in hordes, and one shot pierces many.",
	"Snakes can only be killed by hitting the head. Rockets charge in straight lines. Shoot a gravity well to wake it — it sucks in enemies, shots and you. Kill it to blow up everything around it, or let it eat too much and it bursts into protons.",
]
const TIPS := [
	"Keep moving in wide circles — standing still gets you surrounded.",
	"Kill grunts early: the older they get, the faster they chase.",
	"Fire at a weaver's wall side to pin it, or get close and shoot a quick burst it can't dodge.",
	"Sweep through geoms after a fight, before they vanish.",
	"Save a bomb for when you're cornered.",
]
const STATS := ["Best score", "Highest multiplier", "Longest time survived", "Games played"]
