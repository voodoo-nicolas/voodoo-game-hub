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
	"wit_wait": "Not yet. Something is wrong with that coat, and the matches are still on the nightstand.",
	"matches_take": "I put the box of matches in my pocket.",
	"sense_lamps": "The gas lamps are far too bright. They hurt my eyes.",
	"sense_dog": "A dog is barking, far away. It sounds like it is inside my head.",
	"sense_smell": "Tar, fish, wet rope, tobacco smoke. Every smell cuts like a knife.",
	"sense_thirst": "I am so thirsty. And that ticking, never stopping. Can he not hear it?",
	"cigar_dark": "The cigar shop. This is the logo on the matches.",
	"road_sens2": "My heart is racing. I could run for miles, and I have no idea where to.",
	"road_sens3": "I can hear every shutter, every latch, every sleeping dog. Nothing is quiet any more.",
	"road_gate": "The last gas lamp. Beyond it the road becomes a path, and the forest begins.",
	"road_house": "A light between the trees. A small house, buried in vines.",
	"house_tbc": "The rest of the story is not written yet.",
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
const BANNER_TBC := "To be continued..."

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
	"same_note": "He has the same note, from his own pocket: same day, same time. Wednesday, 10 PM.",
	"watch": "A silver pocket watch from a hidden pocket in the coat's lining. It ticks, warm and humming, and it feels wrong. I did not tell him.",
	"watch_burn": "I showed the shopkeeper the silver watch. It burned my palm. It broke when I dropped it and the ticking stopped. He picked it up with his bare hand and said it was not hot. He kept it. I cannot touch silver.",
	"road": "The priest left the church after he disagreed with something it did. He lives alone outside the city, and he reads and researches. The shopkeeper is taking me to him, on foot, at night.",
	"arm": "A branch cut the shopkeeper's arm. I smelled the blood and I was hungry, so hungry. He would not let me near it. He covered it with cloth and dirt, and the hunger passed. Now he walks behind me.",
	"house": "At the end of the forest path, a small house covered in vines, with a dim light in the window.",
	"shop": "The shopkeeper denied everything. The water burned me and I passed out. When I woke the man from the bar was gone. The shopkeeper knows what is happening to me: he asked if I had bitten anyone. He says I have two or three days, and then he does not want to be near me. There is an old priest who left the church, with old books.",
	"cigar": "The matches come from a cigar company. Their shop is across the city, by the harbor. He knows where.",
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
	"show_matches": "Go home with him and look at the coat again",
	"cigar": "Go to the cigar shop by the harbor",
	"priest": "Go with the shopkeeper to the old priest",
	"to_priest": "Follow the shopkeeper to the priest's house",
	"priest_in": "Go into the priest's house",
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
	"shopkeeper": {"all": "Rest a little. Then we go to the priest."},
	"owner": {"all": "Keep walking."},
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
	"shopkeeper": "Shopkeeper",
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
	"coat_right": "A box of matches. The lid has a logo on it. They are not mine. I leave them on the nightstand.",
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
	# the witness tells what he saw (scene 4)
	"w4_wed": "Wednesday night. I came late. You were outside the bar, talking with a couple of people.",
	"w4_closed": "I went to go in. The tavernkeep told me: \"We're closed. Anyone inside can finish and go. Tonight is over.\" And he slammed the door.",
	"w4_wait": "Thursday, nothing. Today, nothing. I drank, and I waited. Then you walk in tonight.",
	"w4_nothing": "I don't remember any of it. I woke up today in a stranger's coat, with a note.",
	"w4_show": "A note? Show me.",
	"w4_hand": "I give it to him. He reads it. His face loses its colour, and the paper slips from his fingers.",
	"w4_pocket": "With a shaking hand he takes a note from his own pocket. The same paper. The same words.",
	"w4_same": "Same day. Same time.",
	"w4_you": "You got one too?",
	"w4_more": "Was there anything else in that coat?",
	"w4_matches_home": "A box of matches. I left it at home.",
	"w4_matches_here": "A box of matches. I have it here.",
	"w4_home": "Take me to your house. I want to see that coat.",
	# at home (scene 4)
	"coat_tick": "The coat is ticking. A small, steady tick, from somewhere in the lining.",
	"coat_opt_tick": "Follow the ticking",
	"coat_w1": "I follow the sound with my fingers. A second lining, sewn low on the inside. A hidden pocket.",
	"coat_w2": "A silver pocket watch. It is warm, and it hums against my palm. It feels wrong.",
	"coat_w3": "I close my hand round it. He does not need to know. Not yet.",
	"w4m_here": "Here. These were in the coat.",
	"w4m_look": "He turns the box over. His thumb stops on the logo.",
	"w4m_logo": "I know this. A cigar company. Their shop is across the city, by the harbor.",
	"w4m_hide": "The watch stays in my pocket, ticking. I do not say a word about it.",
	"w4m_go": "Come on. Somebody there may know who gave you that coat.",
	# the cigar shop (scene 5)
	"shop_bell": "A bell rings over the door. The shopkeeper looks up from behind the counter.",
	"shop_w1": "Good evening. Do you know this man?",
	"shop_o1": "Never seen him in my life.",
	"shop_w2": "These matches have your company's logo on them.",
	"shop_o2": "Half the harbor has that box. Anything else?",
	"shop_w3": "Anything strange lately? Anyone hurt? Anyone asking questions?",
	"shop_o3": "Nothing. Nothing strange here. Anything else, or are you leaving?",
	"shop_dizzy": "The room tilts. My mouth is dry. My hands are shaking.",
	"shop_y1": "I'm very thirsty. I'm dizzy... weak.",
	"shop_w4": "Sit down, sit. Shopkeeper, some water, please.",
	"shop_o4": "Water? ...Are you sure?",
	"shop_give": "He hesitates. Then he gives me a glass anyway, and watches me.",
	"shop_drink": "I drink it greedily. Then it burns. My throat, my chest. I cough, the glass falls, and everything goes black.",
	"sto_wake": "Dried tobacco hangs from the ceiling, thick and sweet. My throat is on fire. I am lying on a cot in the back of the shop.",
	"sto_alone": "The man from the bar is gone. Only the shopkeeper is here, watching me from a stool.",
	"sto_o1": "How long ago did they do it to you?",
	"sto_neck": "I touch my neck. Two small holes.",
	"sto_collar": "He leans over, opens my collar and looks.",
	"sto_o2": "Four days? Five?",
	"sto_y1": "Two, I think.",
	"sto_o3": "Did you bite anyone yet?",
	"sto_y2": "Bite...? What are you talking about?",
	"sto_realize": "He stares at me. He understands that I have no idea what is happening to me.",
	"sto_o4": "Nobody told you anything. ...There is an old man, a priest who left the church. He has old books. If anyone knows, he does.",
	"sto_o5": "Maybe you have two or three days left. And when that happens, I do not want to be near you.",
	# the watch, the walk, the forest, the arm, the house (scene 6)
	"w6_show": "There is something else. I found this in the coat.",
	"w6_take": "I take the silver watch from my pocket and hold it out.",
	"w6_burn": "The silver burns my hand like a coal. I cry out and drop it. The glass cracks on the floor, and the ticking stops.",
	"w6_palm": "My palm is red and swollen, as if I had grabbed a hot iron.",
	"w6_pick": "He picks the watch up with his bare hand.",
	"w6_o1": "It is not hot.",
	"w6_o2": "You cannot touch it. ...Silver. I will keep it.",
	"w6_o3": "The priest lives outside the city. We go now, while it is dark.",
	"r1_o1": "He was a priest. He left the church after he disagreed with something it did.",
	"r1_o2": "He lives alone, outside the city. He reads. He researches.",
	"r1_sens": "I hardly listen. Every sound is too loud, every light too sharp. I feel anxious, restless, full of an energy I do not understand.",
	"br_scrape": "A low branch scrapes the shopkeeper's arm. He hisses.",
	"br_smell": "Blood. I smell it before I see it, warm and sweet and impossible to ignore. Suddenly I am hungry. Terribly hungry.",
	"br_o1": "It is nothing.",
	"br_hide": "He covers the arm with his other hand and turns it away from me.",
	"br_opt_see": "Ask to see his arm",
	"br_opt_still": "Hold my breath and stay where I am",
	"br_y1": "Let me see it.",
	"br_o2": "No. Stay where you are.",
	"br_back": "He backs away, one step, two. His eyes do not leave me.",
	"br_still": "I clench my fists and do not move. My mouth is full of a thirst I cannot name.",
	"br_cloth": "He tears a strip from his shirt, ties it round the cut and rubs dirt over it. The smell dulls. The hunger fades.",
	"br_o3": "Walk ahead of me. I will follow.",
	"hs_see": "A small house, covered in vines. A dim light burns in one window.",
	"hs_in": "We go in.",
}
