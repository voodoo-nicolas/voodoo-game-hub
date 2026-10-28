extends SceneTree

## DEV TOOL: fills the real user:// hand history and profile with ~400 seeded
## hands so the 📈 My stats screen and the replay can be looked at without
## playing. Overwrites user://video_poker_history.jsonl and
## user://video_poker_profile.json: back them up first (CLAUDE.md).
## godot --headless --path . --script res://tools/poker_fake_history.gd

const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const History = preload("res://scripts/games/video_poker/video_poker_history.gd")
const Profile = preload("res://scripts/games/video_poker/video_poker_profile.gd")

const CONFIGS := [["holdem", "nl"], ["omaha", "pl"], ["draw", "nl"], ["stud", "fl"]]

func _init() -> void:
	for p in [History.PATH, Profile.PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	var prof = Profile.new()
	for rec in _play():
		prof.record_hand(rec)
	prof.record_tourney(2, 6, "holdem")
	print("wrote ", History.new().count(), " hands, level ", prof.level())
	quit()

func ok(_c: bool, _w: String) -> void:
	pass

func _play() -> Array:
	var recs: Array = []
	var arng := RandomNumberGenerator.new()
	arng.seed = 20261028
	var hist = History.new()
	var at := int(Time.get_unix_time_from_system()) - 400 * 70
	for cfg in CONFIGS:
		for round in 25:
			var t = Table.new()
			t.variant = cfg[0]
			t.limit = cfg[1]
			t.sb = 10
			t.bb = 20
			var n := 2 + round % 5
			for i in n:
				t.seats.append(Table.new_seat(["", "Mama Zuzu", "Bones", "Lucky Lou", "Madame Mojo", "Gator"][i], 1000, 1 if i == 0 else 0))
			var rng := RandomNumberGenerator.new()
			rng.seed = 100 + round
			for h in 4:
				if not t.start_hand(rng):
					break
				var guard := 0
				var rec := {}
				hist.observe(t, "cash", 0, false)
				while t.phase != "done" and guard < 200:
					guard += 1
					if t.phase == "draw":
						t.draw([0, 1].slice(0, arng.randi_range(0, 2)))
					else:
						var l: Dictionary = t.legal()
						var r := arng.randf()
						if r < 0.15 and not l.can_check:
							t.act("fold")
						elif r < 0.7:
							t.act("call")
						elif l.can_raise:
							t.act("raise", arng.randi_range(int(l.min_to), int(l.max_to)))
						else:
							t.act("call")
					rec = hist.observe(t, "cash", 0, false)
				if not rec.is_empty():
					rec["at"] = at
					at += 60
					recs.append(rec)
				for s in t.seats:
					if int(s.stack) <= 0:
						s.stack = 1000
	return recs
