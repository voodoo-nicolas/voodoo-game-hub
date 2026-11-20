extends SceneTree

## Headless test of "remember me" / quick sign-in (scripts/common/auth.gd, owner 2026-11-20):
##   godot --headless --path . --script res://tools/test_known_accounts.gd
## No network: only the device list, its encryption, hints, cap, forget and sign-out rules.
## Backs up and restores user://known_accounts.dat and user://auth_session.json.

var fails := 0

func _initialize() -> void:
	_run()

func ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1

func _backup(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func _restore(path: String, data: PackedByteArray) -> void:
	if data.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()

func _run() -> void:
	await process_frame
	var A = root.get_node("Auth")
	var known_bak := _backup(A.KNOWN_PATH)
	var sess_bak := _backup(A.SESSION_PATH)
	if FileAccess.file_exists(A.KNOWN_PATH):
		DirAccess.remove_absolute(A.KNOWN_PATH)
	A._known = []
	A._known_loaded = false
	var was := {"uid": A.user_id, "acc": A.access_token, "ref": A.refresh_token, "name": A.display_name, "exp": A.expires_at}

	ok(A.email_hint("nico@gmail.com") == "ni•••@gmail.com", "email hint hides the name part")
	ok(A.email_hint("a@b.co") == "a•••@b.co", "short email hint")
	ok(A.email_hint("") == "", "no email, no hint")

	A._remember("u1", "Nico", "nico@gmail.com", "tok1")
	A._remember("u2", "Ana", "ana@mail.com", "tok2")
	var list: Array = A.known_accounts()
	ok(list.size() == 2 and list[0].user_id == "u2", "newest first")
	ok(not list[0].has("token"), "the list never hands out tokens")
	A._remember("u1", "Nico", "", "tok1b")   # a refresh rotates the token, may omit the email
	list = A.known_accounts()
	ok(list[0].user_id == "u1" and list[0].email_hint == "ni•••@gmail.com", "refresh keeps the email, moves to front")
	ok(A._known[0].token == "tok1b", "rotated token stored")

	# Survives a restart, encrypted on disk.
	A._known = []
	A._known_loaded = false
	ok(A.known_accounts().size() == 2, "list loads back from disk")
	var raw := FileAccess.get_file_as_string(A.KNOWN_PATH)
	ok(not raw.contains("tok1b") and not raw.contains("nico@"), "file is encrypted (no token or email in plain text)")

	for i in 6:
		A._remember("x%d" % i, "P%d" % i, "", "t%d" % i)
	ok(A.known_accounts().size() == A.KNOWN_MAX, "capped at %d accounts" % A.KNOWN_MAX)

	A._forget_local("x5")
	ok(not A.is_remembered("x5"), "forget removes it")

	# Sign out of a remembered account: local only, its token stays for the two-tap way back.
	A.user_id = "x4"
	A.access_token = "acc"
	A.refresh_token = "t4"
	A.sign_out()
	ok(A.user_id == "" and A.is_remembered("x4"), "signing out keeps a remembered account")

	# Remember me off: a new account isn't stored.
	A.set_remember_me(false)
	A._known = []
	A._known_loaded = false
	ok(A.remember_me == false, "the switch survives a restart")
	A.set_remember_me(true)

	# Put everything back.
	A.user_id = was.uid
	A.access_token = was.acc
	A.refresh_token = was.ref
	A.display_name = was.name
	A.expires_at = was.exp
	_restore(A.KNOWN_PATH, known_bak)
	_restore(A.SESSION_PATH, sess_bak)
	print("known accounts: %d failure(s)" % fails)
	quit(fails)
