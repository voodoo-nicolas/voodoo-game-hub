extends RefCounted
## Condition strings, joined by "&": "flag:x", "!flag:x", "has:torch", "quest:m02=active|done|inactive",
## "renown>=3". `s` is anything exposing has_flag(), item_count(), quest_state(), renown.

static func eval(expr: String, s) -> bool:
	if expr == "" or expr == null:
		return true
	for part in expr.split("&"):
		if not _one(part.strip_edges(), s):
			return false
	return true

static func _one(p: String, s) -> bool:
	var neg := false
	if p.begins_with("!"):
		neg = true
		p = p.substr(1)
	var r := false
	if p.begins_with("flag:"):
		r = s.has_flag(p.substr(5))
	elif p.begins_with("has:"):
		r = s.item_count(p.substr(4)) > 0
	elif p.begins_with("quest:"):
		var kv := p.substr(6).split("=")
		r = kv.size() == 2 and s.quest_state(kv[0]) == kv[1]
	elif p.begins_with("renown>="):
		r = int(s.renown) >= int(p.substr(8))
	else:
		push_warning("Cond: unknown term '%s'" % p)
	return (not r) if neg else r
