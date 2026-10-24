extends SceneTree

## Tests the shared sound library's player (tools/templates/sound_lib.gd)
## against media/common/sfx/: takes are found, a take never repeats twice in
## a row, unknown ids are silent, play() goes through Sfx, loop() loops and
## respects a sound group switched off.
##
##   godot --headless --path . --script res://tools/test_sound_lib.gd
##
## Leaves the player's sound settings as it found them.

const SoundLib = preload("res://tools/templates/sound_lib.gd")

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sfx = root.get_node_or_null("Sfx")
	var settings = root.get_node_or_null("Settings")
	if sfx == null or settings == null:
		print("FAIL need the Sfx and Settings autoloads")
		quit(1)
		return

	check(SoundLib.takes("casino/card_slide").size() == 8, "casino/card_slide has 8 takes")
	check(SoundLib.takes("voice/fight").size() == 1, "voice/fight is one file")
	check(SoundLib.takes("voice/round_3").size() == 1, "voice/round_3 is its own sound, not a take")
	check(SoundLib.takes("impact/metal_heavy").size() == 5, "impact/metal_heavy has 5 takes")
	check(SoundLib.takes("nope/nothing").is_empty(), "an unknown id has no takes")
	check(SoundLib.stream_for("nope/nothing") == null, "an unknown id gives no stream")

	var last := ""
	var repeats := 0
	var seen := {}
	for i in 200:
		var s: AudioStream = SoundLib.stream_for("casino/card_slide")
		if s.resource_path == last:
			repeats += 1
		last = s.resource_path
		seen[last] = true
	check(repeats == 0, "never the same take twice in a row (%d repeats)" % repeats)
	check(seen.size() == 8, "every take gets played (%d of 8)" % seen.size())

	var host := Node.new()
	root.add_child(host)
	# Sfx hands each play_stream() to its next voice: count the hand-overs.
	var plays := func() -> int:
		return sfx._next
	var before: int = plays.call()
	SoundLib.play(host, "casino/chip_lay")
	check(plays.call() == (before + 1) % sfx.VOICES, "play() plays through Sfx")
	SoundLib.play(host, "casino/chip_lay")
	check(plays.call() == (before + 1) % sfx.VOICES, "the same sound at once is skipped (no stacking)")
	SoundLib.play(host, "nope/nothing")
	check(plays.call() == (before + 1) % sfx.VOICES, "an unknown id plays nothing")

	var rain: AudioStreamPlayer = SoundLib.loop(host, "weather/thunder_rain", -6.0)
	check(rain.playing and rain.get_parent() == host, "loop() plays on a child of the node")
	check(rain.stream is AudioStreamOggVorbis and rain.stream.loop, "the loop's stream loops")
	var shared: AudioStream = load("res://media/common/sfx/weather/thunder_rain.ogg")
	check(not shared.loop, "the shared resource itself is not set to loop")
	check(rain.bus == "SFX", "loop() is on the SFX bus")
	rain.queue_free()

	var was_on: bool = settings.group_on("game")
	settings.set_group_on("game", false)
	var off: AudioStreamPlayer = SoundLib.loop(host, "ambient/crowd_chatter")
	check(not off.playing, "loop() stays silent when Game sounds are off")
	settings.set_group_on("game", was_on)

	host.queue_free()
	print("%d failure(s)" % fails)
	quit(1 if fails else 0)
