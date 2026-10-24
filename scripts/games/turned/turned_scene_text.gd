extends RefCounted

## Words for Scene mode (docs/turned/SCENE_MODE_PLAN.md): hotspot labels and the lines a hotspot
## says, by id. English here, Spanish in tools/i18n/es.json (every string goes through tr()).
## The two `dev_` scenes are a test, not story (F7 in debug builds).

## The label on a hotspot chip (turned_scenes.json "label").
const HOTSPOTS := {
	"hs_dev_lamp": "Lamp",
	"hs_dev_box": "Wooden box",
	"hs_dev_talk": "Talk",
	"hs_dev_door": "Door",
	"hs_dev_back": "Back",
	"hs_dev_leave": "Leave",
}

## What a "look:<id>" action says (a thought, in the blue inner-text style).
const LOOKS := {
	"dev_lamp": "A lamp. This is a test of Scene mode, not part of the story.",
	"dev_box": "A wooden box. It stays examined, but it can be looked at again.",
}

const UI := {
	"no_painting": "No painting yet",
}
