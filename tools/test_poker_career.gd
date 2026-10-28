extends SceneTree

## Headless check of Poker's characters, bosses and Career (video_poker_characters.gd,
## _career.gd, the profile's career record, the AI's use of a character's traits):
## the roster matches the AI's name list, every character has a style, lines and a
## Spanish translation, every stage can be built (known characters, a valid variant
## and betting, at most six at the table), the stars and the unlocking follow the
## rules, a character's decision is always a move the table accepts, and a trapper
## checks strong hands more than an aggressive player.
## godot --headless --path . --script res://tools/test_poker_career.gd

const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const AI = preload("res://scripts/games/video_poker/video_poker_ai.gd")
const Characters = preload("res://scripts/games/video_poker/video_poker_characters.gd")
const Career = preload("res://scripts/games/video_poker/video_poker_career.gd")
const Profile = preload("res://scripts/games/video_poker/video_poker_profile.gd")

var fails := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	_characters()
	_stages()
	_stars()
	_profile()
	_decisions()
	_trapper()
	print("poker career: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)

func _spanish() -> Dictionary:
	var f := FileAccess.open("res://tools/i18n/es.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	return d

func _characters() -> void:
	var es := _spanish()
	var seen := {}
	var bosses := 0
	for c in Characters.ALL:
		ok(not seen.has(c.name), "name %s is unique" % c.name)
		seen[c.name] = true
		ok(int(c.style) >= 0 and int(c.style) < AI.STYLES.size(), c.name + ": a valid style")
		for k in ["tight", "aggr", "bluff"]:
			ok(float(c[k]) >= 0.0 and float(c[k]) <= 1.0, "%s: %s in 0..1" % [c.name, k])
		ok(str(c.quirk) in ["", "bully", "tilt", "trapper", "sticky"], c.name + ": a known quirk")
		ok(int(c.skill) >= 0 and int(c.skill) <= 1, c.name + ": skill 0 or 1")
		ok(str(c.icon) != "", c.name + ": an icon")
		for k in ["bio", "win", "allin", "bust"]:
			ok(str(c[k]) != "", "%s: has a %s" % [c.name, k])
			ok(es.get(str(c[k])) != null and str(es.get(str(c[k]), "")) != str(c[k]), "%s: %s is translated" % [c.name, k])
		if bool(c.boss):
			bosses += 1
	ok(bosses == Career.STAGES.size(), "one boss per stage (%d)" % bosses)
	ok(Characters.roster().size() == Characters.ROSTER_SIZE, "roster size")
	ok(Characters.names() == AI.NAMES, "the AI's name list is the roster, in order")
	for c in Characters.roster():
		ok(not bool(c.boss), c.name + " in the roster is not a boss")
	ok(Characters.find("Player 2").is_empty() and Characters.find("").is_empty(), "the player is nobody's character")
	ok(Characters.line("Gator", "win") == "Chomp!" and Characters.line("Nobody", "win") == "", "lines by name")

func _stages() -> void:
	var es := _spanish()
	var ids := {}
	for s in Career.STAGES:
		ok(not ids.has(s.id), "stage id %s is unique" % s.id)
		ids[s.id] = true
		ok(Table.VARIANTS.has(str(s.variant)) and Table.LIMITS.has(str(s.limit)), s.id + ": a real variant and limit")
		var forced: String = Table.rules_for(str(s.variant)).forced_limit()
		ok(forced == "" or forced == str(s.limit), s.id + ": respects a forced limit")
		var boss: Dictionary = Characters.find(str(s.boss))
		ok(not boss.is_empty() and bool(boss.boss), s.id + ": the boss is a boss character")
		var names: Array = Career.opponents(s)
		var uniq := {}
		for n in names:
			ok(not Characters.find(str(n)).is_empty(), "%s: %s exists" % [s.id, n])
			uniq[n] = true
		ok(uniq.size() == names.size(), s.id + ": nobody twice")
		ok(names.size() + 1 <= 6 and names.size() >= 2, s.id + ": 3 to 6 at the table")
		ok(float(s.boss_stack) >= 1.0 and int(s.hpl) >= 3 and int(s.fast) > 0 and int(s.xp) > 0, s.id + ": sane numbers")
		for k in ["title", "blurb"]:
			ok(es.get(str(s[k])) != null, "%s: %s is translated" % [s.id, k])
		# the table can be dealt for every variant a stage uses
		var t = Table.new()
		t.variant = s.variant
		t.limit = s.limit
		t.sb = 10
		t.bb = 20
		t.seats.append(Table.new_seat("", Career.START_STACK, 1))
		for n in names:
			t.seats.append(Table.new_seat(str(n), Career.START_STACK, 0, int(Characters.find(str(n)).style)))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		ok(t.start_hand(rng), s.id + ": a hand can be dealt")
	ok(Career.STAGES.size() == 8, "eight stages")
	ok(Career.index_of("the_vault") == 5 and Career.index_of("nope") == -1 and Career.stage("nope").is_empty(), "lookup")

func _stars() -> void:
	ok(Career.stars("back_room", false, false, 5) == 0, "no stars for a loss")
	ok(Career.stars("back_room", true, true, 99) == 1, "one star for winning")
	ok(Career.stars("back_room", true, false, 99) == 2, "two stars without help")
	ok(Career.stars("back_room", true, false, 18) == 3 and Career.stars("back_room", true, true, 18) == 2, "the third star is speed")
	ok(Career.stars("back_room", true, false, 19) == 2, "18 hands is the limit of the first stage")
	var earned := {}
	ok(Career.unlocked(0, earned) and not Career.unlocked(1, earned), "only the first stage is open at the start")
	earned["back_room"] = 1
	ok(Career.unlocked(1, earned) and not Career.unlocked(2, earned), "a clear opens the next")
	earned["candle_cellar"] = 3
	ok(Career.cleared(earned) == 2 and Career.total_stars(earned) == 4, "cleared and star totals")

func _profile() -> void:
	var path := "user://test_poker_career_profile.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var p = Profile.new(path)
	var a: Dictionary = p.record_career("back_room", 2, 100)
	ok(bool(a.first) and int(a.xp) == 100 and int(a.added) == 2, "first clear: the stage's xp")
	var b: Dictionary = p.record_career("back_room", 1, 100)
	ok(int(b.xp) == 0 and p.career_stars("back_room") == 2, "a worse run changes nothing")
	var c: Dictionary = p.record_career("back_room", 3, 100)
	ok(not bool(c.first) and int(c.xp) == 30 and p.career_stars("back_room") == 3, "an extra star is worth 30 xp")
	ok(int(p.d.xp) == 130, "xp added up")
	var q = Profile.new(path)
	ok(q.career_stars("back_room") == 3, "career survives a save and load")
	var lost: Dictionary = q.record_career("candle_cellar", 0, 150)
	ok(int(lost.xp) == 0 and q.career_stars("candle_cellar") == 0, "a loss earns nothing")
	DirAccess.remove_absolute(path)
	# the size of the field scales tournament xp
	var r = Profile.new(path)
	var small: int = r.record_tourney(1, 2, "holdem")
	var big: int = r.record_tourney(1, 6, "holdem")
	ok(small < big and big == 250, "a heads-up win is worth less than a full table")
	DirAccess.remove_absolute(path)

# ---------- the AI ----------

func _flop_table(seat_name: String, other: String) -> RefCounted:
	var t = Table.new()
	t.variant = "holdem"
	t.limit = "nl"
	t.sb = 10
	t.bb = 20
	t.seats.append(Table.new_seat(seat_name, 1500, 0, 1))
	t.seats.append(Table.new_seat(other, 1500, 0, 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	t.start_hand(rng)
	var guard := 0
	while t.street == 0 and t.phase == "bet" and guard < 6:
		guard += 1
		t.act("call" if t.legal().to_call > 0 else "check")
	return t

func _decisions() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for c in Characters.ALL:
		for variant in ["holdem", "stud"]:
			var t = Table.new()
			t.variant = variant
			t.limit = "fl" if variant == "stud" else "nl"
			t.sb = 10
			t.bb = 20
			t.seats.append(Table.new_seat(c.name, 1500, 0, int(c.style)))
			t.seats.append(Table.new_seat("", 1500, 1))
			t.seats.append(Table.new_seat("P3", 1500, 0, 1))
			t.start_hand(rng)
			var guard := 0
			while t.phase in ["bet", "draw"] and guard < 12:
				guard += 1
				var cpu: bool = int(t.seats[t.to_act].kind) == 0
				var move := {"action": "call"}
				if cpu and t.seats[t.to_act].name == c.name:
					move = AI.decide(t.to_dict(), 1, rng.randi())
					ok(move.action in ["fold", "check", "call", "raise", "allin", "draw"], "%s: a known action (%s)" % [c.name, move.action])
				var done: bool = t.act(str(move.action), int(move.get("amount", 0)))
				if not done:
					done = t.act("check") or t.act("fold") or t.act("call")
				ok(done, "%s (%s): the table accepted a move" % [c.name, variant])

## A trapper checks a monster more often than an aggressive player bets it.
func _trapper() -> void:
	var rates := {}
	for who in ["Mama Zuzu", "Lucky Lou"]:
		var raised := 0
		var n := 40
		for k in n:
			var t = _flop_table(who, "P2")
			if t.street != 1 or int(t.seats[t.to_act].kind) != 0:
				continue
			# put the character on the first move after the flop with a monster
			t.to_act = 0
			t.seats[0].hole = [0, 13]       # two aces
			t.seats[1].hole = [30, 44]
			t.board = [1, 14, 27]           # three deuces: aces full
			t.current_bet = 0
			for s in t.seats:
				s.bet = 0
			var move: Dictionary = AI.decide(t.to_dict(), 1, 1000 + k)
			if str(move.action) in ["raise", "allin"]:
				raised += 1
		rates[who] = float(raised) / n
	ok(float(rates["Lucky Lou"]) > float(rates["Mama Zuzu"]) + 0.15, "a trapper bets a monster less than a maniac does (%s)" % str(rates))
