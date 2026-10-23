extends RefCounted

## Player-facing text for Turned (English; Spanish in turned_i18n.gd, generated from
## tools/i18n/es.json). Story: docs/turned/story_bible.md. Inner lines are the player
## character's thoughts, short and dry, no voice acting (bible section 3).
## The lines for clues, the note's half-name and the neighbours are placeholders written for
## this slice (docs/turned/DECISIONS.md): replace them when the bible has canon text.

## Inner text (what the player thinks) and short spoken lines.
const INNER := {
	"thirsty": "I'm thirsty.",
	"what_happened": "What happened last night?",
	"achy": "Ugh. Everything aches.",
	"fever": "Like a fever. But I'm not sick.",
	"what_is_this": "What is this?",
	"mirror": "What is going on?",
	"hint_move": "Use the arrows to walk.",
	"need_mirror": "I need a mirror.",
	"cant_remember": "I can't remember.",
	"figure_out": "I need to figure this out.",
	"pockets_empty": "Nothing. No keys, no coins. Where is my coat?",
	"coat_whose": "Whose coat is this? What did I do?",
	"door_coat": "I'm not going out without my coat.",
	"door_first": "I can't go out like this. I need to see myself first.",
	"scarf": "A grey wool scarf. I wind it round my neck. The marks are hidden.",
	"scarf_have": "I'm already wearing it.",
	"sun_first": "The light. It burns.",
	"shade_first": "Better. The shade helps.",
	"died_first": "The sun took me. I woke up in the shade.",
	"died_again": "The sun again. Stay in the shade.",
	"alley_hint": "Sneaking: slower, quieter, harder to notice.",
	"sneak_on": "Sneaking",
	"sneak_off": "Walking",
	"locked_end": "A locked door. Not tonight.",
	"cellar_locked": "The cellar door. An old iron lock, and no key anywhere I've looked.",
	"door_note": "That coat is hiding something. I should look through it before I go out.",
	"bar_locked": "The door is bolted from inside. Nobody is coming to open it.",
	"fol_door": "The pub door opens a crack. A man steps out, sees me, and runs.",
	"fol_steps": "Footsteps behind me. When I slow down, they slow down.",
	"fol_stop": "I stop. They stop. Someone is following me.",
	"fol_lane": "That side lane. If I wait round the corner, he will have to come to me.",
	"door_followed": "Not with someone behind me. I need to know who it is first.",
}

## What a piece of furniture says when you Examine it (id of the interact -> line). Placeholders written for
## the house (docs/turned/DECISIONS.md); a few are hints the story can use later.
const LOOKS := {
	"wardrobe": "My clothes, in a row. Dark coats, nothing bright. I never noticed that before.",
	"portrait": "A stern portrait in a black frame. Family, I think. I can't remember the name.",
	"toilet": "Cold porcelain, a chain that sticks. Nothing here.",
	"washstand": "A jug and a bowl, still half full. The water is cold as a cellar.",
	"cabinet": "Tonics, powders, a bottle of laudanum. Nothing for this.",
	"bath": "The bath is dry. I don't think I used it last night.",
	"desk": "The desk has been cleared. Too tidy. Someone put everything away for me.",
	"bookshelf": "Almanacs and poetry. One gap on the shelf, and the dust keeps the shape of the missing book.",
	"globe": "A globe. Someone has turned it so Marrowgate faces me.",
	"clock": "The hall clock has stopped at ten past four. It is not ten past four.",
	"fireplace": "The fire is out. The ashes are still warm. Someone sat here late.",
	"piano": "The keys are cold. I press one and it rings too loud, then settles.",
	"parlour_books": "Sermons and sheet music. Nothing about last night.",
	"stove": "The stove is cold. Nobody has cooked in days.",
	"table": "Two cups on the table. One full and cold, the other clean. Someone sat across from me.",
	"pantry": "Bread, a week old. I'm hungry, but not for this. That's the strange part.",
	"shelves": "Jars of plums and pickles. Nothing here is what I want.",
}

## The unlock banner (Turned's CLAUDE.md section 3).
const BANNER_NEW := "Something new is awake."

## Clue objects in the bedroom: text said on pickup, and the Journal line.
const CLUES := {
	"coat": {
		"verb": "Look",
		"say": "This isn't my coat.",
		"journal": "A stranger's coat on my chair. Heavy wool, and it smells of smoke and rain. It fits me too well.",
	},
	"calendar": {
		"verb": "Look",
		"say": "The wall calendar says Friday. Wednesday was two days ago. Two days, gone.",
		"journal": "The wall calendar says it is Friday. I have lost two days.",
	},
	"towel": {
		"verb": "Look",
		"say": "A towel on the rail, stiff and brown at one end. Dried blood. I don't remember being hurt.",
		"journal": "A bloodstained towel in the bathroom, dried stiff. I don't remember being hurt.",
	},
}

## Journal lines that are not objects in the bedroom.
const JOURNAL := {
	"neck": "Two small marks on my neck. I woke up thirsty and I don't know why.",
	"watcher": "A man in a grey coat stared at my neck and said: \"You should not be out in that sun.\" He knew.",
	"sun": "The sun burns me. Shade, awnings and the inside of a house keep me safe.",
	"alley": "The alley is cool and quiet. Something in me woke up there.",
	"pockets": "My pockets are empty. No keys, no coins. My own coat is gone.",
	"cellar": "A locked cellar door in the hall, with an old iron lock. I have no key.",
	"witness": "A man from the bar followed me. I caught him round a corner. He stared at my neck and at the coat, and said: \"...It's really you.\" He knows something.",
	"matches": "A box of matches from the coat's right pocket, with a cigar company's logo on the lid. They are not mine.",
	"note": "A note sewn into the coat's inside pocket: \"Meet me at The Crooked Lantern. Wednesday. 10 PM. Come alone.\"",
	"bar": "The Crooked Lantern: the whole room was afraid of me, not angry. The keeper threw me out and bolted the door.",
}

## Missions box (one line).
const MISSIONS := {
	"find_out": "Find out what happened",
	"find_coat": "Find your coat",
	"go_bar": "Go to The Crooked Lantern",
	"follower": "Find out who is following you",
}

## What the A button says (translated by the HUD when drawn).
const VERBS := {
	"sit": "Sit up",
	"wipe": "Wipe face",
	"look": "Examine",
	"read": "Read",
	"take": "Take",
	"enter": "Go in",
	"talk": "Talk",
	"door": "Open door",
	"pockets": "Check pockets",
	"up": "Go up",
	"down": "Go down",
	"ok": "OK",
	"grab": "Grab him",
	"continue": "Continue",
	"choose": "Choose",
}

## Neighbours. "exposed" = your neck is uncovered, "covered" = you wear the scarf.
## The watcher knows (knows_player 2): same line either way, nothing else (Turned CLAUDE.md section 10).
const NPC_LINES := {
	"watcher": {"all": "You should not be out in that sun."},
	"patron": {"all": "Please. Just go."},
	"witness": {"all": "...It's really you."},
	"tavernkeep": {"all": "Go home."},
	"vendor": {
		"exposed": "Rough night? You look like death warmed over. Bread's fresh, if you've an appetite.",
		"covered": "Morning! Bread's fresh, if you've an appetite.",
	},
	"parasol": {
		"exposed": "Goodness, are you ill? Your neck... never mind, never mind.",
		"covered": "Lovely morning. Far too bright for me, mind.",
	},
	"newspaper": {
		"exposed": "Hmph. Mind where you're going.",
		"covered": "Morning. Nothing in the paper but rain and rumours.",
	},
	"coachman": {
		"exposed": "Not today. The horse is lame, and you look like you need a doctor, not a carriage.",
		"covered": "Not today. The horse is lame.",
	},
	"lamplighter": {
		"exposed": "Still burning the gas in daylight, aye. Fewer shadows that way. You'd best find some yourself.",
		"covered": "I keep them trimmed even by day. Old habit.",
	},
}

## Speaker names shown above spoken lines.
const SPEAKERS := {
	"watcher": "Man in the grey coat",
	"tavernkeep": "Tavernkeep",
	"witness": "Man from the bar",
	"patron": "Patron",
	"you": "You",
	"vendor": "Baker",
	"parasol": "Woman with a parasol",
	"newspaper": "Man with a newspaper",
	"coachman": "Coachman",
	"lamplighter": "Lamplighter",
}

## HUD and menu words.
const UI := {
	"missions": "Missions",
	"health": "Health",
	"blood": "Blood",
	"xp": "XP",
	"level": "Lv %d",
	"pause": "Pause",
	"menu": "Menu",
	"journal": "Journal",
	"journal_empty": "Nothing here yet.",
	"quest_log": "Quest log",
	"close": "Close",
	"no_mission": "Nothing yet",
	"press_a": "Press A",
	"tap_a": "Tap A to continue",
	"sun_tip": "Sun tolerance",
	"items": "Items",
	"items_empty": "You are carrying nothing.",
}

## Things the player carries (Menu > Items). From the owner's scenes 1-6 (docs/turned/story_scenes_1-6.md);
## `variants` = [flag, description] pairs, the first whose flag is set replaces the description.
## The note's time (10 PM) and the bar's name are the owner's [OPEN] placeholders.
const ITEMS := {
	"matches": {
		"name": "Box of matches",
		"desc": "A box of matches. The lid has a cigar company's logo on it. They are not mine.",
	},
	"note": {
		"name": "The note",
		"desc": "A note, from the sewn-shut pocket of the coat: \"Meet me at The Crooked Lantern. Wednesday. 10 PM. Come alone.\"",
	},
	"watch": {
		"name": "Silver pocket watch",
		"desc": "A silver pocket watch from a hidden pocket. It ticks, warm and humming. It feels wrong in my hand.",
		"variants": [["watch_broken", "A silver pocket watch. The glass is cracked and it has stopped ticking. It burns to touch."]],
	},
}

## Dialogue lines for the scenes in turned_dialogues.json, by id (the runner shows "TODO <id>" for a
## missing one). The `dev_` lines are only for trying the dialogue box (F8 in debug builds).
const DIALOGUE := {
	"dev_hello": "This is a test of the dialogue box. Press A to go on.",
	"dev_ask": "Which do you want to do?",
	"dev_opt_take": "Take the matches",
	"dev_opt_look": "Say nothing",
	"dev_opt_have": "I already have them",
	"dev_took": "You take the box of matches. It is in your Items now.",
	"dev_quiet": "You say nothing. The test goes on.",
	"dev_end": "That is the end of the test.",
	# the coat (scene 2)
	"coat_smell": "This isn't my coat. Heavy wool, and it smells of smoke and rain.",
	"coat_whose": "Whose coat is this? What did I do?",
	"coat_opt_left": "Check the left pocket",
	"coat_opt_right": "Check the right pocket",
	"coat_opt_inner": "Check the inside pocket",
	"coat_opt_tear": "Tear open the stitches",
	"coat_opt_wear": "Try it on",
	"coat_opt_done": "Leave the coat",
	"coat_left": "The left pocket is empty.",
	"coat_right": "A box of matches. The lid has a logo on it. They are not mine.",
	"coat_inner": "The inside pocket is sewn shut with crude stitches. Someone did not want it opened by accident.",
	"coat_tear": "I tear the stitches open. A note, folded small. \"Meet me at The Crooked Lantern. Wednesday. 10 PM. Come alone.\"",
	"coat_tear_thought": "Wednesday. It is Friday. Whatever happened, it happened there.",
	"coat_wear": "It fits. Too well, as if it was made for me.",
	# the bar (scene 2, ends with the start of scene 3)
	"bar_shout": "YOU! You've got nerve coming back after Wednesday night! We don't need more trouble.",
	"bar_afraid": "The whole room has gone quiet. Nobody is angry. They are afraid.",
	"bar_ask": "Wednesday night? I don't remember. Please, what happened here?",
	"bar_home": "Go home.",
	"bar_plead": "Please. Anything. I only need to know...",
	"bar_out": "Out. Now.",
	"bar_bolt": "The door slams. A lock turns, then a bolt slides across.",
	# the follower (scene 3)
	"fol_why": "Why are you following me?!",
	"fol_stare": "He does not answer. He stares at my neck, then at the coat.",
	"fol_really": "...It's really you.",
}
