extends RefCounted

## Ink Ninja's own music (owner 2026-11-20, STANDARDS §10): tracks shipped in
## this pack at res://games/ink_ninja/music/, never the hub's. Hub music and game
## music never mix.
##
## Apps from v0.43.0: the hub's Music autoload plays them (play_stream): the
## 🎵 switch, volume and pause dip apply, and it fades out when the game closes.
## Older apps have no play_stream: their Music is stopped and the track plays
## on a player of the game's own (child of the game, on the Music bus when the
## app has one, so the 🎵 volume still applies there).

const DIR := "res://games/ink_ninja/music/"
const OWN_PLAYER := "_OwnMusic"

## Plays `track` (file name without .ogg). `then_track` follows it when it
## doesn't loop (a one-shot). Asking for what already plays does nothing.
static func play(owner: Node, track: String, then_track: String = "", fade: float = 1.5) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var s := _load(track)
	if s == null:
		return
	var then := _load(then_track)
	var m = owner.get_node_or_null("/root/Music")
	if m and m.has_method("play_stream"):
		m.play_stream(s, owner, fade, then)
		return
	if m and m.has_method("stop"):
		m.stop(0.5)
	_play_own(owner, s, then)

## Silence (a film, a quiet moment), on any app.
static func stop(owner: Node, fade: float = 1.0) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var m = owner.get_node_or_null("/root/Music")
	if m and m.has_method("stop"):
		m.stop(fade)
	var p := owner.get_node_or_null(OWN_PLAYER) as AudioStreamPlayer
	if p:
		p.set_meta("then", null)
		p.stop()

static func _load(track: String) -> AudioStream:
	if track == "":
		return null
	var path := DIR + track + ".ogg"
	return load(path) as AudioStream if ResourceLoader.exists(path) else null

## Older apps: one player of the game's own; it leaves with the game.
static func _play_own(owner: Node, s: AudioStream, then: AudioStream) -> void:
	var p := owner.get_node_or_null(OWN_PLAYER) as AudioStreamPlayer
	if p == null:
		p = AudioStreamPlayer.new()
		p.name = OWN_PLAYER
		var has_bus := AudioServer.get_bus_index("Music") != -1
		p.bus = "Music" if has_bus else "Master"
		p.volume_db = 0.0 if has_bus else -8.0   # that app's Music sets the bus volume
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		owner.add_child(p)
		p.finished.connect(func():
			var nx = p.get_meta("then", null)
			p.set_meta("then", null)
			if nx is AudioStream:
				p.stream = nx
				p.play())
	p.set_meta("then", then)
	if p.stream == s and p.playing:
		return
	p.stream = s
	p.play()
