extends RefCounted
## Text tokens: {name} -> hero name, {g:male|female} -> gendered form (needed for Spanish).

static func resolve(text: String, hero_name: String, male: bool) -> String:
	var out := text.replace("{name}", hero_name)
	var rx := RegEx.new()
	rx.compile(r"\{g:([^|}]*)\|([^}]*)\}")
	var guard := 0
	while guard < 64:
		guard += 1
		var m := rx.search(out)
		if m == null:
			break
		out = out.substr(0, m.get_start()) + (m.get_string(1) if male else m.get_string(2)) + out.substr(m.get_end())
	return out
