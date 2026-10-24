extends RefCounted

## Words for Scene mode (docs/turned/SCENE_MODE_PLAN.md): hotspot labels and the lines a hotspot
## says, by id. English here, Spanish in tools/i18n/es.json (every string goes through tr()).
## The two `dev_` scenes are a test, not story (F7 in debug builds).

## The label on a hotspot chip (turned_scenes.json "label").
const HOTSPOTS := {
	"hs_dev_lamp": "Lamp",
	"hs_dev_box": "Wooden box",
	"hs_dev_talk": "Talk",
	"hs_dev_paper": "Paper",
	"hs_dev_door": "Door",
	"hs_dev_back": "Back",
	"hs_dev_leave": "Leave",
}

## What a "look:<id>" action says (a thought, in the blue inner-text style).
const LOOKS := {
	"dev_lamp": "A lamp. This is a test of Scene mode, not part of the story.",
	"dev_box": "A wooden box. It stays examined, but it can be looked at again.",
}

## Zoom cards (turned_cards.json): the title above the picture, the caption under it, and the text the
## game writes over a paper picture. The note's time and the bar's name are the owner's [OPEN] placeholders.
const CARDS := {
	"coat_pocket": {"title": "Coat pocket", "caption": "Sewn shut with crude black stitches."},
	"matches": {"title": "Box of matches", "caption": "A cigar company's logo on the lid."},
	"note": {
		"title": "The note",
		"caption": "From the coat's inner pocket.",
		"text": "Meet me at The Crooked Lantern. Wednesday. 10 PM. Come alone.",
	},
	"watch": {"title": "Silver pocket watch", "caption": "It ticks, warm and humming."},
	"watch_broken": {"title": "Broken watch", "caption": "The glass is cracked. It has stopped ticking."},
}

const UI := {
	"no_painting": "No painting yet",
	"no_picture": "No picture yet",
	"items_look": "Look closer",
	"day": "Day %d",
	"morning": "Morning",
	"afternoon": "Afternoon",
	"evening": "Evening",
	"night": "Night",
	"nav_inventory": "Inventory",
	"nav_map": "Map",
	"nav_journal": "Journal",
	"nav_shelter": "Shelter",
	"nav_contacts": "Contacts",
}
