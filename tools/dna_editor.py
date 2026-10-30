"""Evolution DNA tree editor: round-trips Data.NODES / Data.NODE_PLANS with a browser editor.

  python tools/dna_editor.py export            -> tools/dna_editor/dna_editor.html (open it in a browser)
  python tools/dna_editor.py apply tree.json   -> rewrites NODES / NODE_PLANS in evolution_data.gd
  python tools/dna_editor.py apply tree.json --dry-run   (show what would change, write nothing)
  python tools/dna_editor.py roundtrip         -> checks that parse + format reproduces the file byte for byte

Rules: node ids are never renamed. Deleted traits are commented out with `#` (moved, never removed), and
refused while other scripts still name the id (use --force). Other lines in NODES (owner comments) stay.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "scripts/games/evolution/evolution_data.gd"
OUT = ROOT / "tools/dna_editor/dna_editor.html"
TEMPLATE = ROOT / "tools/dna_editor/template.html"
ES = ROOT / "tools/i18n/es.json"
EOL = "\n"

NODE_RE = re.compile(
	r'^\t(?P<hash>#\s*)?\{"id": "(?P<id>\w+)", "branch": "(?P<branch>\w+)", "x": (?P<x>[-\d.]+), "y": (?P<y>[-\d.]+), '
	r'"max": (?P<max>\d+), "cost": (?P<cost>\d+), "stage": (?P<stage>\d+), (?:"size": (?P<size>\d+), )?"req": (?P<req>\[.*?\]), '
	r'"name": "(?P<name>(?:[^"\\]|\\.)*)", "desc": "(?P<desc>(?:[^"\\]|\\.)*)", "ability": (?P<ability>true|false)'
	r'(?:, "excl": "(?P<excl>\w+)")?\},\s*$')


def num(s):
	"""Keep the original text of a number when its value did not change."""
	return s


def fmt_num(v, raw=None):
	if raw is not None and abs(float(raw) - float(v)) < 1e-9:
		return raw
	v = round(float(v), 2)
	return str(int(v)) if v == int(v) else repr(v)


def parse_nodes(lines):
	nodes = []
	for i, ln in enumerate(lines):
		m = NODE_RE.match(ln)
		if not m or m.group("hash"):
			continue
		d = m.groupdict()
		nodes.append({
			"line": i, "id": d["id"], "branch": d["branch"], "x": float(d["x"]), "y": float(d["y"]),
			"xr": d["x"], "yr": d["y"], "max": int(d["max"]), "cost": int(d["cost"]), "stage": int(d["stage"]), "size": int(d["size"] or 0),
			"req": json.loads(d["req"]), "name": d["name"], "desc": d["desc"],
			"ability": d["ability"] == "true", "excl": d["excl"] or "",
		})
	return nodes


def format_node(n):
	req = "[" + ", ".join('["%s", %d]' % (r, k) for r, k in n["req"]) + "]"
	s = '\t{"id": "%s", "branch": "%s", "x": %s, "y": %s, "max": %d, "cost": %d, "stage": %d, %s"req": %s, "name": "%s", "desc": "%s", "ability": %s' % (
		n["id"], n["branch"], fmt_num(n["x"], n.get("xr")), fmt_num(n["y"], n.get("yr")), n["max"], n["cost"], n["stage"],
		'"size": %d, ' % n["size"] if n.get("size") else "", req, n["name"], n["desc"], "true" if n["ability"] else "false")
	if n.get("excl"):
		s += ', "excl": "%s"' % n["excl"]
	return s + "},"


def plans_span(lines):
	start = next(i for i, l in enumerate(lines) if l.startswith("const NODE_PLANS := {"))
	end = next(i for i in range(start, len(lines)) if lines[i].startswith("}"))
	return start, end


def parse_plans(lines):
	a, b = plans_span(lines)
	return {k: re.findall(r'"(\w+)"', v) for k, v in re.findall(r'"(\w+)": (\[[^\]]*\])', "\n".join(lines[a + 1:b]))}


def format_plans(plans):
	rows = ['\t"%s": [%s]' % (k, ", ".join('"%s"' % p for p in v)) for k, v in plans.items()]
	out, cur = [], []
	for r in rows:
		if cur and len(", ".join(cur + [r])) > 110:
			out.append("\t" + ", ".join(cur).strip() + ",")
			cur = []
		cur.append(r.strip())
	if cur:
		out.append("\t" + ", ".join(cur) + ",")
	return out


def load():
	global EOL
	with open(DATA, encoding="utf-8", newline="") as f:
		text = f.read()
	EOL = "\r\n" if "\r\n" in text else "\n"
	return text, text.replace("\r\n", "\n").split("\n")


def cmd_export():
	_, lines = load()
	nodes = parse_nodes(lines)
	payload = {
		"nodes": [{k: v for k, v in n.items() if k not in ("line", "xr", "yr")} for n in nodes],
		"plans": parse_plans(lines),
	}
	html = TEMPLATE.read_text(encoding="utf-8").replace("/*__DATA__*/null", json.dumps(payload, ensure_ascii=False))
	OUT.write_text(html, encoding="utf-8")
	print("wrote", OUT.relative_to(ROOT), "-", len(nodes), "traits")


def cmd_roundtrip():
	text, lines = load()
	nodes = parse_nodes(lines)
	bad = [n["id"] for n in nodes if format_node(n) != lines[n["line"]].rstrip()]
	print(len(nodes), "traits parsed;", "all lines identical" if not bad else "DIFFER: %s" % bad)
	a, b = plans_span(lines)
	same = format_plans(parse_plans(lines)) == lines[a + 1:b]
	print("NODE_PLANS block", "identical" if same else "re-wraps (cosmetic; only rewritten when plans change)")
	return not bad


def referenced_elsewhere(tid):
	hits = []
	for p in (ROOT / "scripts/games/evolution").glob("*.gd"):
		if p == DATA:
			continue
		if re.search(r'["\']%s["\']' % re.escape(tid), p.read_text(encoding="utf-8")):
			hits.append(p.name)
	return hits


def cmd_apply(path, dry, force):
	tree = json.loads(Path(path).read_text(encoding="utf-8"))
	text, lines = load()
	old = {n["id"]: n for n in parse_nodes(lines)}
	new = {n["id"]: n for n in tree["nodes"]}
	problems, notes = [], []

	# Rewrite the lines of existing traits that changed (ids are never renamed).
	out = list(lines)
	changed = 0
	for tid, o in old.items():
		n = new.get(tid)
		if n is None:
			problems.append("%s missing from the file (use deleted: true to remove a trait)" % tid)
			continue
		if n.get("deleted"):
			refs = referenced_elsewhere(tid)
			if refs and not force:
				problems.append("cannot delete %s: named in %s (use --force)" % (tid, ", ".join(refs)))
				continue
			out[o["line"]] = "\t# " + lines[o["line"]].strip()
			notes.append("deleted (commented out): %s" % tid)
			changed += 1
			continue
		cand = dict(o)
		for k in ("branch", "x", "y", "max", "cost", "stage", "size", "req", "name", "desc", "ability", "excl"):
			cand[k] = n.get(k, 0 if k == "size" else o.get(k))
		cand["req"] = [[r, int(k)] for r, k in n["req"]]
		line = format_node(cand)
		if line != lines[o["line"]].rstrip():
			out[o["line"]] = line
			changed += 1

	# New traits go after the last existing trait line.
	added = [n for tid, n in new.items() if tid not in old and not n.get("deleted")]
	if added:
		last = max(o["line"] for o in old.values())
		ins = []
		for n in added:
			if not re.fullmatch(r"[a-z][a-z0-9_]*", n["id"]):
				problems.append("bad id %r" % n["id"])
			n = dict(n)
			n["req"] = [[r, int(k)] for r, k in n["req"]]
			ins.append(format_node(n))
			notes.append("NEW trait %s: inert until the engine gives it an effect" % n["id"])
		out[last + 1:last + 1] = ins
		changed += len(ins)

	# Body plan table.
	a, b = plans_span(out)
	if tree["plans"] != parse_plans(lines):
		keep = {k: v for k, v in tree["plans"].items() if v and k in new and not new[k].get("deleted")}
		out[a + 1:b] = format_plans(keep)
		changed += 1
		notes.append("NODE_PLANS rewritten")

	# Names / descriptions the Spanish file lacks.
	es = json.loads(ES.read_text(encoding="utf-8"))
	for n in tree["nodes"]:
		if n.get("deleted"):
			continue
		for k in ("name", "desc"):
			s = n[k].replace('\\"', '"')
			if s not in es:
				notes.append("needs Spanish (es.json): %s" % s)

	for p in problems:
		print("PROBLEM:", p)
	for s in notes:
		print(s)
	print("%d line(s) change%s" % (changed, " (dry run, nothing written)" if dry else ""))
	if problems:
		sys.exit(1)
	if not dry and changed:
		with open(DATA, "w", encoding="utf-8", newline="") as f:
			f.write(EOL.join(out))
		print("wrote", DATA.relative_to(ROOT))


if __name__ == "__main__":
	a = sys.argv[1:]
	if a[:1] == ["export"]:
		cmd_export()
	elif a[:1] == ["roundtrip"]:
		sys.exit(0 if cmd_roundtrip() else 1)
	elif a[:1] == ["apply"] and len(a) > 1:
		cmd_apply(a[1], "--dry-run" in a, "--force" in a)
	else:
		print(__doc__)
