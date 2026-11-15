extends RefCounted

## Ink Ninja's story line: one chapter card before each stage (title + 2 lines)
## and the stage's story objective shown in the HUD. Translated through the game's tr().
##
## Owner 2026-11-15: "mix the stories". The story bible (D:\Dev\GAME_DESIGN_INK_NINJA.md:
## Hakuu's unfinished scroll, Lord Shu's red seal, Tsuru the crane, 6 acts x 4 stages)
## merged with the first story (the Shadow Daimyo, the Great Brush, the Empty Temple,
## Bamboo Road, River of Paper, the Iron Monks): Lord Shu IS the Shadow Daimyo, and the
## Great Brush is Hakuu's brush. Every 4th stage is the act's boss (engine BOSS_NAMES).
## Cutscenes (cutscene.gd SLOTS) play at the bible's slots between acts.

const PROLOGUE := "The world is a hanging scroll painted by the old master Hakuu. He died before he finished it. Lord Shu, the Shadow Daimyo, stamped his red seal on it, and the red is bleeding down through everything. Only one figure cannot be claimed: the last one Hakuu painted, a ninja with no face."

## [chapter title, text, objective], 24 stages: act = (stage - 1) / 4 + 1.
const CHAPTERS := [
	# Act 1, Pinewood
	["First Stroke", "Sumi wakes among the pines at the foot of the scroll. A seal can only bind what is finished, and Sumi is not finished.", "Reach the temple gate"],
	["Needles", "Fog is what a painter uses when he has not decided yet. A fox Sumi freed waits at the fork.", "Find the path through the fog"],
	["The Long Stair", "The stair climbs to the Empty Temple. Red drips fall from the top of the scroll; where one lands, a creature turns Sealed.", "Climb to the gate"],
	["The Gate Warden", "A stone lion-dog guards the temple gate with the Daimyo's red seal on its brow. Free it.", "Open the temple gate"],
	# Act 2, Bamboo Grove (the Bamboo Road)
	["Green Without Green", "The Bamboo Road. Tsuru the crane, painted just before Sumi, waits at the top of the stalks.", "Cross the grove"],
	["Rain", "Rain on the bamboo. The Daimyo's ninjas guard the road to the woodcutter's hut.", "Reach the woodcutter's hut"],
	["Something Follows", "Stripes move between the stalks. For the first time, something is hunting Sumi.", "Don't stop"],
	["Tora", "The Sealed tiger waits in a ring of bamboo. Hakuu gave it no cage; Lord Shu gave it a seal.", "Free the tiger"],
	# Act 3, River of Wash (the River of Paper)
	["Thin Ice, No Ice", "The River of Paper. Water is the part Hakuu did not paint.", "Follow the river upstream"],
	["The Bridge Builders", "Painted villagers stand frozen on the broken bridge, red-stamped, all facing the top of the scroll.", "Cross the broken bridge"],
	["Up the Falls", "A great carp leaps beside Sumi all the way up the falls, watching.", "Climb the waterfall"],
	["The Dragon", "A carp that climbs the falls becomes a dragon. This one carries the Daimyo's seal.", "Reach the top of the falls"],
	# Act 4, Lantern Town (night)
	["White on Black", "The Daimyo's hand took Tsuru out of the sky. Night in Lantern Town: every door bears a red stamp.", "Enter the town unseen"],
	["The Market of Owned Things", "Stalls sell cut-out pieces of the painting. Everything has a red price tag, even the creatures in cages.", "Find where they took Tsuru"],
	["Rooftops", "A red-marked ninja runs the rooftops with Sumi's own moves.", "Catch the shadow"],
	["Tsuru", "The shadow lands in the courtyard and turns. It is Tsuru, Sealed.", "Free Tsuru"],
	# Act 5, Storm Mountain (the Monks of Iron, the Cliffs of Mist)
	["The Path That Isn't Painted", "Tsuru can no longer fly and climbs on foot. Only the lightning shows the path along the cliffs.", "Climb above the clouds"],
	["Avalanche", "Blank paper sweeps up the mountain. The Shadow Daimyo has started to erase what he cannot own.", "Outrun the white"],
	["The Hermitage", "Hakuu's hut at the summit, where the Iron Monks once prayed. The Great Brush is gone; a monk waits outside with it.", "Reach the summit hut"],
	["The Calligrapher", "The Sealed monk paints his attacks out of the air with the Great Brush.", "Take back the brush"],
	# Act 6, The Margin
	["Past the Edge", "The blank margin. Red veins pulse across the paper. The freed come back to help.", "Cross the blank"],
	["Inscription", "Sumi climbs Hakuu's own unfinished signature, letter by letter.", "Climb the writing"],
	["Vermilion", "Everything is red but Sumi. No music, no guide.", "Reach the seal"],
	["Lord Shu", "The Shadow Daimyo's seal fills the sky. One stroke is still unfinished.", "Break the seal"],
]

const EPILOGUE := "The seal splits. The red drains out of the scroll from top to bottom, and the world remembers its own colours. The corner where a seal should be stays blank."
