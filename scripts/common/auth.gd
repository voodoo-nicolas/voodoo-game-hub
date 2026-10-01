extends Node

## First-ever autoload in this project. Wraps Supabase Auth + PostgREST calls
## over plain HTTPRequest -- there's no official Godot Supabase SDK. Every
## network call follows hub.gd's established convention: an ephemeral
## HTTPRequest child, queue_free() from inside its own completion callback
## (never free() -- see CLAUDE.md's crash gotcha about freeing mid-signal),
## every parse guarded by a type check, every failure silent/graceful so a
## flaky network never blocks play.
##
## The publishable/anon key below is meant to be public (it ships inside the
## APK either way) -- it only grants what Row Level Security policies on the
## Supabase project allow. Never put the secret/service_role key here.

const SaveUtil = preload("res://scripts/common/save_util.gd")
const Config = preload("res://scripts/common/config.gd")

const SUPABASE_URL := Config.SUPABASE_URL
const SUPABASE_ANON_KEY := Config.SUPABASE_ANON_KEY
const SESSION_PATH := "user://auth_session.json"

signal signed_in(user_id: String, display_name: String)
signal signed_out()
signal auth_error(context: String, message: String)

var access_token: String = ""
var refresh_token: String = ""
var expires_at: int = 0
var user_id: String = ""
var display_name: String = ""

## Callbacks waiting on the refresh currently in flight. Supabase rotates the
## refresh token on every use, so two overlapping refreshes would spend the
## same token twice -- the second is rejected as reuse and can revoke the
## whole session. Every caller joins the one refresh instead.
var _refresh_waiters: Array[Callable] = []

func _ready() -> void:
	# Keep working while a game is paused (GameInfo pauses the tree).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_session()
	if refresh_token != "":
		_refresh_session(Callable())  # silent background refresh on launch

func is_logged_in() -> bool:
	return access_token != "" and user_id != ""

func get_display_name() -> String:
	return display_name

## Pure reconciliation rule, pulled out for headless testing: the higher of
## the two always wins, so neither a fresh local high score nor an existing
## cloud one is ever silently lost.
func merge_stat(local_value: int, cloud_value: int) -> int:
	return max(local_value, cloud_value)

## Pure expiry check, pulled out for headless testing. The 60s grace period
## means a token that's about to expire gets refreshed proactively rather
## than failing mid-request.
func needs_refresh(now: int, token_expires_at: int) -> bool:
	return now >= token_expires_at - 60

# ---------- public API ----------

func sign_up(email: String, password: String, chosen_display_name: String) -> void:
	var body := {"email": email, "password": password, "data": {"display_name": chosen_display_name}}
	_request(HTTPClient.METHOD_POST, "/auth/v1/signup", body, PackedStringArray(), func(ok, parsed, _code):
		if not ok or typeof(parsed) != TYPE_DICTIONARY:
			auth_error.emit("sign_up", _extract_error(parsed, "Sign up failed."))
			return
		if not parsed.has("access_token"):
			auth_error.emit("sign_up", "Check your email to confirm your account, then sign in.")
			return
		_apply_session(parsed, chosen_display_name)
	)

func sign_in(email: String, password: String) -> void:
	var body := {"email": email, "password": password}
	_request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", body, PackedStringArray(), func(ok, parsed, _code):
		if not ok or typeof(parsed) != TYPE_DICTIONARY or not parsed.has("access_token"):
			auth_error.emit("sign_in", _extract_error(parsed, "Invalid email or password."))
			return
		_apply_session(parsed, _extract_display_name(parsed))
	)

func sign_out() -> void:
	if access_token != "":
		var headers: PackedStringArray = ["Authorization: Bearer " + access_token]
		_request(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, headers, func(_ok, _parsed, _code): pass)
	_clear_session()
	signed_out.emit()

## Always fire-and-forget: the UI shows "check your email" regardless of the
## outcome, matching Supabase's own behavior of not revealing which emails
## have accounts.
func request_password_reset(email: String) -> void:
	var body := {"email": email}
	_request(HTTPClient.METHOD_POST, "/auth/v1/recover", body, PackedStringArray(), func(_ok, _parsed, _code): pass)

## Reads the caller's own `field_name` from player_stats, merges with
## `local_value` by taking the max (so pre-login local progress is never
## lost), pushes the merged value back if the cloud was behind, and reports
## the merged value via `on_done`. Falls back to `local_value` unchanged if
## not logged in or the network is unavailable.
func reconcile_stat(field_name: String, local_value: int, on_done: Callable) -> void:
	_ensure_fresh_token(func(ok):
		if not ok:
			_safe_call(on_done, [local_value])
			return
		var headers: PackedStringArray = ["Authorization: Bearer " + access_token]
		_request(HTTPClient.METHOD_GET, "/rest/v1/player_stats?select=" + field_name, {}, headers, func(ok2, parsed, _code):
			var cloud_value := 0
			if ok2 and typeof(parsed) == TYPE_ARRAY and parsed.size() > 0 and typeof(parsed[0]) == TYPE_DICTIONARY:
				cloud_value = int(parsed[0].get(field_name, 0))
			var merged: int = merge_stat(local_value, cloud_value)
			if merged > cloud_value:
				push_stat(field_name, merged)
			_safe_call(on_done, [merged])
		)
	)

func push_stat(field_name: String, value: int) -> void:
	_ensure_fresh_token(func(ok):
		if not ok:
			return
		var body := {}
		body[field_name] = value
		var headers: PackedStringArray = ["Authorization: Bearer " + access_token, "Prefer: return=minimal"]
		_request(HTTPClient.METHOD_PATCH, "/rest/v1/player_stats", body, headers, func(_ok2, _parsed, _code): pass)
	)

# ---------- session lifecycle ----------

func _apply_session(parsed: Dictionary, name_hint: String) -> void:
	access_token = str(parsed.get("access_token", ""))
	refresh_token = str(parsed.get("refresh_token", ""))
	var expires_in: int = int(parsed.get("expires_in", 3600))
	expires_at = int(Time.get_unix_time_from_system()) + expires_in
	if parsed.has("user") and typeof(parsed.user) == TYPE_DICTIONARY:
		user_id = str(parsed.user.get("id", ""))
	display_name = name_hint if name_hint != "" else "Player"
	_save_session()
	signed_in.emit(user_id, display_name)

func _extract_display_name(parsed: Dictionary) -> String:
	if parsed.has("user") and typeof(parsed.user) == TYPE_DICTIONARY:
		var meta = parsed.user.get("user_metadata", {})
		if typeof(meta) == TYPE_DICTIONARY:
			return str(meta.get("display_name", ""))
	return ""

func _extract_error(parsed, fallback: String) -> String:
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in ["error_description", "msg", "message"]:
			if parsed.has(key) and str(parsed[key]) != "":
				return str(parsed[key])
	return fallback

## Only a definite rejection from Supabase (4xx: token revoked, expired or
## already used) signs the player out. A network failure -- offline, timeout,
## server hiccup -- keeps the stored session so it can refresh next time;
## launching the app on a plane must not log anyone out.
func _refresh_session(on_done: Callable) -> void:
	_refresh_waiters.append(on_done)
	if _refresh_waiters.size() > 1:
		return  # a refresh is already in flight; wait for its result
	var body := {"refresh_token": refresh_token}
	_request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", body, PackedStringArray(), func(ok, parsed, code):
		var success: bool = ok and typeof(parsed) == TYPE_DICTIONARY and parsed.has("access_token")
		if success:
			_apply_session(parsed, display_name)
		elif code >= 400 and code < 500:
			_clear_session()
			signed_out.emit()
		var waiters := _refresh_waiters
		_refresh_waiters = []
		for cb in waiters:
			_safe_call(cb, [success])
	)

## Refreshes first if the access token is expired or about to be (60s grace),
## then calls on_ready(true/false). false means "not logged in or refresh
## failed" -- callers should degrade to local-only behavior, never block play.
func _ensure_fresh_token(on_ready: Callable) -> void:
	if not is_logged_in():
		on_ready.call(false)
		return
	var now := int(Time.get_unix_time_from_system())
	if needs_refresh(now, expires_at):
		_refresh_session(on_ready)
	else:
		on_ready.call(true)

func _load_session() -> void:
	var data = SaveUtil.read(SESSION_PATH)
	if data == null:
		return
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", ""))
	expires_at = int(data.get("expires_at", 0))
	user_id = str(data.get("user_id", ""))
	display_name = str(data.get("display_name", ""))

func _save_session() -> void:
	SaveUtil.write(SESSION_PATH, {
		"access_token": access_token,
		"refresh_token": refresh_token,
		"expires_at": expires_at,
		"user_id": user_id,
		"display_name": display_name,
	})

func _clear_session() -> void:
	access_token = ""
	refresh_token = ""
	expires_at = 0
	user_id = ""
	display_name = ""
	SaveUtil.delete(SESSION_PATH)

# ---------- low-level HTTP helper ----------

## on_done is called as on_done(ok: bool, parsed: Variant, response_code: int).
## `parsed` is a Dictionary or Array on success, {} if the body didn't parse
## as either. `ok` is only true for a 2xx response with a request that
## actually completed -- callers must not assume `parsed` is populated just
## because `ok` is true (a 2xx with an empty/malformed body still reports ok).
func _request(method: HTTPClient.Method, path: String, body: Dictionary, extra_headers: PackedStringArray, on_done: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = Config.HTTP_TIMEOUT
	add_child(http)
	http.request_completed.connect(func(result, response_code, _headers, response_body):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS:
			on_done.call(false, {}, response_code)
			return
		var ok: bool = response_code >= 200 and response_code < 300
		var parsed = JSON.parse_string(response_body.get_string_from_utf8())
		if typeof(parsed) != TYPE_DICTIONARY and typeof(parsed) != TYPE_ARRAY:
			on_done.call(ok, {}, response_code)
			return
		on_done.call(ok, parsed, response_code)
	)

	var headers: PackedStringArray = ["apikey: " + SUPABASE_ANON_KEY, "Content-Type: application/json"]
	for h in extra_headers:
		headers.append(h)

	var body_str: String = "" if body.is_empty() else JSON.stringify(body)
	var err := http.request(SUPABASE_URL + path, headers, method, body_str)
	if err != OK:
		http.queue_free()
		# Still report failure: request_completed never fires for a request that
		# didn't start, and callers wait on this callback to re-enable their UI.
		# Dropping it silently leaves the sign-in button disabled forever.
		on_done.call(false, {}, 0)

## Game scenes pass lambdas/methods that may belong to a scene the player has
## already left by the time the network answers; skip those quietly.
static func _safe_call(cb: Callable, args: Array) -> void:
	if cb.is_valid():
		cb.callv(args)
