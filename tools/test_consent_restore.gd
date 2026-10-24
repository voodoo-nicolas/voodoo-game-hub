extends SceneTree

## Consent.restore's answer handling: the server's rows for this account at the
## current version (both documents) bring the acceptance and age bracket back;
## an older version or one document only don't. user://consent.json is backed
## up and restored. Signed out here, so the "account" is user_id "".
##   godot --headless --path . --script res://tools/test_consent_restore.gd

var fails := 0
var called := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: " + msg)
		fails += 1

func _done() -> void:
	called += 1

func _initialize() -> void:
	var C = load("res://scripts/common/consent.gd")
	var backup := FileAccess.get_file_as_string(C.PATH) if FileAccess.file_exists(C.PATH) else ""
	var v: String = C.version()

	DirAccess.remove_absolute(C.PATH)
	C._on_restore([{"doc_type": "terms_eula", "doc_version": v, "age_bracket": "18+"}], "", _done)
	_check(not C.has_accepted(), "one document only: not accepted")
	C._on_restore([{"doc_type": "terms_eula", "doc_version": "0.0.1"}, {"doc_type": "privacy", "doc_version": "0.0.1"}], "", _done)
	_check(not C.has_accepted(), "older version: not accepted")
	C._on_restore(null, "", _done)
	_check(not C.has_accepted(), "offline: not accepted")
	C._on_restore([{"doc_type": "terms_eula", "doc_version": v, "age_bracket": "18+"},
			{"doc_type": "privacy", "doc_version": v, "age_bracket": "18+"}], "", _done)
	_check(C.has_accepted(), "both at current version: accepted")
	_check(C.bracket() == "18+" and C.max_game_age() == 18, "bracket restored")
	_check(str(C._state().synced.get("", "")) == v, "marked synced")
	_check(called == 4, "on_done every time (%d)" % called)
	C._on_restore([{"doc_type": "terms_eula", "doc_version": v}], "someone-else", _done)
	_check(called == 5, "on_done for another account too")

	DirAccess.remove_absolute(C.PATH)
	if backup != "":
		var f := FileAccess.open(C.PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	print("consent restore: %s" % ("OK" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
