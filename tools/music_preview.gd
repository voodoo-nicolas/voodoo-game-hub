extends SceneTree

## Renders the shared Music library's synthesized tracks (scripts/common/
## music.gd SONGS) to builds/music_preview/<style>_<n>.wav, to listen to,
## and prints how long each took to make (a phone is several times slower).
##
##   godot --headless --path . --script res://tools/music_preview.gd -- [style ...]

const Music = preload("res://scripts/common/music.gd")

func _init() -> void:
	var styles: Array = OS.get_cmdline_user_args()
	if styles.is_empty():
		styles = Music.STYLES
	var out := ProjectSettings.globalize_path("res://builds/music_preview/")
	DirAccess.make_dir_recursive_absolute(out)
	for style in styles:
		for i in (Music.SONGS[style] as Array).size():
			var t0 := Time.get_ticks_msec()
			var job := Music._new_job(style, i)
			Music._job_step(job, -1)
			var wav: AudioStreamWAV = job.wav
			var ms := Time.get_ticks_msec() - t0
			var path := out + "%s_%d.wav" % [style, i]
			wav.save_to_wav(path)
			print("%s %d: %d BPM, %.1f s loop, made in %d ms -> %s" % [style, i, Music.SONGS[style][i].bpm,
				wav.data.size() / 2.0 / Music.RATE, ms, path])
	quit()
