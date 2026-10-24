extends RefCounted

## Words for Scene mode (docs/turned/SCENE_MODE_PLAN.md): hotspot labels and the lines a hotspot
## says, by id. English here, Spanish in tools/i18n/es.json (every string goes through tr()).
## The house's painted rooms (bedroom, bathroom, study, hall; S5); the two `dev_` scenes are a test, not story (F7 in debug builds).

## The label on a hotspot chip (turned_scenes.json "label").
const HOTSPOTS := {
	"hs_landing": "Landing",
	"hs_bathroom": "Bathroom",
	"hs_window": "Window",
	"hs_bed": "Bed",
	"hs_matches": "Matches",
	"hs_coat": "Coat",
	"hs_wardrobe": "Wardrobe",
	"hs_desk": "Desk",
	"hs_calendar": "Calendar",
	"hs_mirror": "Looking glass",
	"hs_towel": "Towel",
	"hs_bath": "Bath",
	"hs_shelf": "Shelf",
	"hs_washstand": "Washstand",
	"hs_toilet": "Toilet",
	"hs_globe": "Globe",
	"hs_bookshelf": "Bookshelf",
	"hs_armchair": "Armchair",
	"hs_front_door": "Front door",
	"hs_scarf": "Scarf",
	"hs_clock": "Hall clock",
	"hs_cellar": "Cellar door",
	"hs_upstairs": "Upstairs",
	"hs_portrait": "Portrait",
	"hs_parlour": "Parlour door",
	"hs_kitchen": "Kitchen door",
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
	"bed_window": "I keep away from the glass. Even this light stings.",
	"bed_pillow": "The pillow. A dark stain, dried now. Is it mine?",
	"bed_desk": "Papers, and a candle burned down to a stub. Nothing here says where I was.",
	"study_desk": "Letters and bills under the green lamp. Ordinary. Too ordinary.",
	"study_armchair": "The leather is cracked and cold. Nobody has sat here for days.",
	"dev_lamp": "A lamp. This is a test of Scene mode, not part of the story.",
	"dev_box": "A wooden box. It stays examined, but it can be looked at again.",
}

## Zoom cards (turned_cards.json): the title above the picture, the caption under it, and the text the
## game writes over a paper picture. The note's time and the bar's name are the owner's [OPEN] placeholders.
const CARDS := {
	"coat_pocket": {"title": "Coat pocket", "caption": "Crude black stitches, torn open. A note inside."},
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
