extends RefCounted

## Hover Duel Campaign story (original): the Long Circuit. Each battle has a
## briefing (shown before it) and a goal (the Story objective on the
## Objectives card). Indexes match the engine's CAMPAIGN list.

const INTRO := "Six lands, one river road between them, and a rule older than anyone: whoever holds the Circuit decides where the water goes. The Warden has held it for nine years and let the valleys dry. You have a borrowed Skimmer, a full tank and a grudge. Beat every crew on the road and the Warden has to face you."

const ENDING := "The Warden's craft sinks into the ash and the old pumps groan back to life. By morning the rivers run all the way down to Green Valley. The Circuit is yours now. Somewhere out there a new pilot is already fixing up a borrowed craft."

const CHAPTERS := [
	{"goal": "Win your first duel", "brief": "Dash runs the valley ferry and thinks nobody can catch a Gnat. Gnats are fast but thin-skinned: a few clean hits will do."},
	{"goal": "Earn the valley's respect", "brief": "Pip has watched every duel in the valley for years and finally wants a turn. Use the river: water is fast, and Pip hates getting wet."},
	{"goal": "Get past the ferryman of the Isles", "brief": "Old Mossback's Barge is slow and built like a wall. Stay out of mine range, circle, and wear it down."},
	{"goal": "Cross the open sea", "brief": "Reef's Stingray owns the open water. Fight near the islands, where its speed counts for less."},
	{"goal": "Climb into the Highlands", "brief": "Crag never comes down from the hilltops. Remember: from below, the hill eats your shots. Get up there."},
	{"goal": "Topple The Mountain", "brief": "The Mountain guards the high pass in a Bulwark with twice your armour. Missiles, crates, patience."},
	{"goal": "Find the oasis road", "brief": "Mirage only fights at noon, in the shimmer off the dunes. Watch the shadows, not the craft."},
	{"goal": "Outrun the Sidewinder", "brief": "Sidewinder flies a Gnat with nothing to lose. Don't chase it into the dunes: let it come to you."},
	{"goal": "Break the ice", "brief": "Frost's Wraith was built for the Glacier. Ice is slippery for you too: steer early and brake with the fans."},
	{"goal": "Survive the Avalanche", "brief": "Avalanche drives a Bulwark down the glacier like a falling rock. Get out of the way first, shoot second."},
	{"goal": "Reach the Warden's gate", "brief": "Cinder keeps the Ash Fields' gate. The rivers here are lava, and Cinder knows every one of them."},
	{"goal": "Take the Circuit", "brief": "The Warden. Nine years undefeated, six missiles, four mines and armour like a cliff. Everything you learned on the road, now."},
]
