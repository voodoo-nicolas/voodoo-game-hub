extends Node

## Calls the Voodoo IQ Edge Functions (supabase/functions/) as the signed-in
## player. The server generates and scores every item; this only carries
## requests and replies. One HTTPRequest per call, freed when it answers, and
## children of this node, so nothing calls back into a scene that's gone.
##
## call_fn(name, body, callback): callback(ok: bool, status: int, data: Dictionary)
## `data` is the parsed JSON reply ({error: "<code>", ...} on failure; code
## "offline" when there was no reply, "signed_out" when there's no session).

const Config = preload("res://scripts/common/config.gd")

## Blitz session-start builds a 200-item batch; give the server time.
const TIMEOUT := 25.0

## The signed-in player's access token from the Auth autoload ("" when signed out).
func access_token() -> String:
	var auth = get_node_or_null("/root/Auth")
	if auth == null or not auth.has_method("is_logged_in") or not auth.is_logged_in():
		return ""
	return str(auth.get("access_token"))

func is_signed_in() -> bool:
	return access_token() != ""

func call_fn(fn_name: String, body: Dictionary, callback: Callable) -> void:
	var auth = get_node_or_null("/root/Auth")
	if access_token() == "":
		callback.call(false, 401, {"error": "signed_out"})
		return
	# Auth refreshes the hourly token first when it's about to expire (single-flight,
	# since Supabase rotates refresh tokens); every app version with accounts has it.
	if auth.has_method("_ensure_fresh_token"):
		auth._ensure_fresh_token(_send.bind(fn_name, body, callback))
	else:
		_send(true, fn_name, body, callback)

func _send(fresh: bool, fn_name: String, body: Dictionary, callback: Callable) -> void:
	var token := access_token()
	if not fresh or token == "":
		callback.call(false, 401 if token == "" else 0, {"error": "signed_out" if token == "" else "offline"})
		return
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	add_child(req)
	req.request_completed.connect(_on_done.bind(req, callback))
	var headers := PackedStringArray([
		"apikey: " + Config.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + token,
		"Content-Type: application/json",
	])
	var err := req.request(Config.SUPABASE_URL + "/functions/v1/" + fn_name, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		callback.call(false, 0, {"error": "offline"})

func _on_done(result: int, code: int, _headers: PackedStringArray, raw: PackedByteArray, req: HTTPRequest, callback: Callable) -> void:
	req.queue_free()
	if not callback.is_valid():
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		callback.call(false, 0, {"error": "offline"})
		return
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}
	callback.call(code >= 200 and code < 300, code, data)
