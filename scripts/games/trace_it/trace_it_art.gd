extends RefCounted

## Trace It's pictures: the built-in line drawings (trace_it_drawings.json)
## rasterized on the phone, and a photo prepared for the overlay -- both as
## a "source" Dictionary the overlay shows:
##   {kind: "drawing" | "photo", id, size: Vector2,
##    full: Image,               # what you see with steps off
##    lines: Image,              # photo only: the picture the "lines" style edges
##    steps: [{name, tip, image, mode, gain}, ...]}
## Strings in drawings.json carry their own Spanish ("name_es"...), like
## Trivia's questions, so they never go through es.json.

const ENGINE = preload("res://scripts/games/trace_it/trace_it_engine.gd")
const DATA_PATH := "res://scripts/games/trace_it/trace_it_drawings.json"
const MAX_SIDE := 1024
const LINE_WIDTH := 7.0   # px at MAX_SIDE

static var _drawings: Array = []


static func drawings() -> Array:
	if _drawings.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				_drawings = data.get("drawings", [])
	return _drawings


static func find(id: String) -> Dictionary:
	for d in drawings():
		if d.get("id") == id:
			return d
	return {}


static func spanish() -> bool:
	return TranslationServer.get_locale().begins_with("es")


## A text field in the player's language ("title" -> "title_es" in Spanish).
static func text(d: Dictionary, key: String) -> String:
	if spanish() and d.has(key + "_es"):
		return str(d[key + "_es"])
	return str(d.get(key, ""))


static func step_count(d: Dictionary) -> int:
	var n := 0
	for s in d.get("strokes", []):
		n = maxi(n, int(s.get("step", 0)) + 1)
	return maxi(n, 1)


## Every stroke as [points, closed] in drawing units; `only` = one step.
static func polylines(d: Dictionary, only: int = -1) -> Array:
	var out := []
	for s in d.get("strokes", []):
		if only >= 0 and int(s.get("step", 0)) != only:
			continue
		var pts := PackedVector2Array()
		var closed := bool(s.get("closed", false))
		if s.has("line"):
			var a: Array = s.line
			pts = PackedVector2Array([Vector2(a[0], a[1]), Vector2(a[2], a[3])])
		elif s.has("rect"):
			var a: Array = s.rect
			pts = PackedVector2Array([Vector2(a[0], a[1]), Vector2(a[2], a[1]), Vector2(a[2], a[3]), Vector2(a[0], a[3])])
			closed = true
		elif s.has("poly"):
			pts = _pairs(s.poly)
		elif s.has("curve"):
			var raw := _pairs(s.curve)
			closed = raw.size() > 2 and raw[0].distance_to(raw[-1]) < 0.01
			if closed:
				raw.remove_at(raw.size() - 1)
			pts = _spline(raw, closed)
		elif s.has("circle"):
			var a: Array = s.circle
			pts = _ellipse(Vector2(a[0], a[1]), a[2], a[2], 0.0)
			closed = true
		elif s.has("ellipse"):
			var a: Array = s.ellipse
			pts = _ellipse(Vector2(a[0], a[1]), a[2], a[3], deg_to_rad(float(a[4])))
			closed = true
		if pts.size() >= 2:
			out.append([pts, closed])
	return out


static func _pairs(a: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(0, a.size() - 1, 2):
		pts.append(Vector2(float(a[i]), float(a[i + 1])))
	return pts


static func _ellipse(c: Vector2, rx: float, ry: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := clampi(int((rx + ry) * 0.6), 24, 96)
	for i in n:
		var t := TAU * i / n
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry).rotated(rot))
	return pts


## Catmull-Rom through every point.
static func _spline(p: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var n := p.size()
	if n < 3:
		return p
	var out := PackedVector2Array()
	var segs := n if closed else n - 1
	for i in segs:
		var p0 := p[(i - 1 + n) % n] if closed or i > 0 else p[0]
		var p1 := p[i]
		var p2 := p[(i + 1) % n]
		var p3 := p[(i + 2) % n] if closed or i + 2 < n else p[n - 1]
		for k in 12:
			var t := k / 12.0
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	if not closed:
		out.append(p[n - 1])
	return out


## The drawing's strokes (one step, or all) as white lines on transparent.
static func render(d: Dictionary, only: int = -1, long_side: int = MAX_SIDE, width: float = LINE_WIDTH) -> Image:
	var box: Array = d.get("size", [400, 400])
	var k := long_side / maxf(float(box[0]), float(box[1]))
	var img := Image.create_empty(maxi(1, int(box[0] * k)), maxi(1, int(box[1] * k)), false, Image.FORMAT_RGBA8)
	var r := width / 2.0
	var bs := int(ceil(r * 2.0 + 2.0))
	var brush := Image.create_empty(bs, bs, false, Image.FORMAT_RGBA8)
	for y in bs:
		for x in bs:
			var dist := Vector2(x + 0.5 - bs / 2.0, y + 0.5 - bs / 2.0).length()
			brush.set_pixel(x, y, Color(1, 1, 1, clampf(r + 0.5 - dist, 0.0, 1.0)))
	var src := Rect2i(0, 0, bs, bs)
	var spacing := maxf(1.0, r * 0.6)
	for pl in polylines(d, only):
		var pts: PackedVector2Array = pl[0]
		var count := pts.size() + (1 if pl[1] else 0) - 1
		for i in count:
			var a := pts[i] * k
			var b := pts[(i + 1) % pts.size()] * k
			var n := maxi(1, int(ceil(a.distance_to(b) / spacing)))
			for j in n + 1:
				var p := a.lerp(b, float(j) / n)
				img.blend_rect(brush, src, Vector2i(int(p.x) - bs / 2, int(p.y) - bs / 2))
	return img


## A built-in drawing ready for the overlay.
static func drawing_source(d: Dictionary) -> Dictionary:
	var steps := []
	var defs: Array = d.get("steps", [])
	for i in step_count(d):
		var def: Dictionary = defs[i] if i < defs.size() else {}
		steps.append({"name": text(def, "name"), "tip": text(def, "tip"), "image": render(d, i), "mode": "mask"})
	var full := render(d)
	return {"kind": "drawing", "id": str(d.get("id", "")), "title": text(d, "title"),
		"size": Vector2(full.get_size()), "full": full, "lines": full, "steps": steps}


## A photo (from the gallery or the camera) ready for the overlay; the
## teaching steps follow ENGINE.PHOTO_STEPS. Slow-ish (edge finding in
## GDScript, ~0.5-1.5 s on a phone) and touches no nodes, so the game runs it
## on a worker thread; step names are filled in afterwards on the main
## thread (name_photo_steps), since translations are looked up there.
static func photo_source(img: Image) -> Dictionary:
	var full := img.duplicate() as Image
	if full.is_compressed():
		full.decompress()
	if full.get_format() != Image.FORMAT_RGBA8:
		full.convert(Image.FORMAT_RGBA8)
	var big := maxi(full.get_width(), full.get_height())
	if big > MAX_SIDE:
		var k := float(MAX_SIDE) / big
		full.resize(maxi(1, int(full.get_width() * k)), maxi(1, int(full.get_height() * k)), Image.INTERPOLATE_BILINEAR)
	var steps := []
	var details: Image = null
	for def in ENGINE.PHOTO_STEPS:
		var st := {"name": "", "tip": "", "mode": def.mode}
		if def.mode == "tones":
			st.image = full
			var lh := tone_range(full)
			st.lo = lh.x
			st.hi = lh.y
		else:
			st.image = line_art(full, def.width, def.blur, def.keep, def.thick, int(def.get("levels", 0)))
			if def.blur == 0:
				details = st.image
		steps.append(st)
	var lh := tone_range(full)
	return {"kind": "photo", "id": "", "title": "", "size": Vector2(full.get_size()), "full": full,
		"lines": details, "steps": steps, "lo": lh.x, "hi": lh.y}


static func name_photo_steps(s: Dictionary) -> void:
	for i in mini(s.steps.size(), ENGINE.PHOTO_STEPS.size()):
		s.steps[i].name = tr_static(ENGINE.PHOTO_STEPS[i].name)
		s.steps[i].tip = tr_static(ENGINE.PHOTO_STEPS[i].tip)


## The photo's dark and light ends (5th / 95th percentile brightness, 0-1),
## so the shading tones spread over what this photo actually has.
static func tone_range(img: Image) -> Vector2:
	var g := img.duplicate() as Image
	g.convert(Image.FORMAT_L8)
	g.resize(64, maxi(1, int(64.0 * g.get_height() / g.get_width())), Image.INTERPOLATE_BILINEAR)
	var hist := PackedInt32Array()
	hist.resize(256)
	var data := g.get_data()
	for v in data:
		hist[v] += 1
	var n := data.size()
	var lo := 0
	var hi := 255
	var acc := 0
	for i in 256:
		acc += hist[i]
		if acc >= n * 0.05:
			lo = i
			break
	acc = 0
	for i in range(255, -1, -1):
		acc += hist[i]
		if acc >= n * 0.05:
			hi = i
			break
	if hi - lo < 16:
		return Vector2(0.0, 1.0)
	return Vector2(lo / 255.0, hi / 255.0)


## Line art: the picture blurred down to `blur` px across (0 = no blur),
## edges found at `width` px (Sobel), thinned to one pixel along the edge
## (non-maximum suppression), and only the strongest `keep` share kept --
## so a busy photo and a plain one give about the same amount of lines.
## White on transparent; `thick` adds a pixel around each line.
## `levels` > 0 first cuts the blurred picture into that many tones, so the
## only edges left are the borders of the big light and dark masses --
## smooth closed outlines, the "big shapes" an artist blocks in first.
## The accuracy check will compare drawings against these same lines.
static func line_art(img: Image, width: int, blur: int, keep: float, thick: bool, levels: int = 0) -> Image:
	var g := img.duplicate() as Image
	g.convert(Image.FORMAT_L8)
	var w := mini(width, g.get_width())
	var h := maxi(3, int(round(g.get_height() * float(w) / g.get_width())))
	if blur > 0 and blur < w:
		g.resize(blur, maxi(2, int(round(g.get_height() * float(blur) / g.get_width()))), Image.INTERPOLATE_BILINEAR)
		g.resize(w, h, Image.INTERPOLATE_CUBIC)
	else:
		g.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var px := g.get_data()
	if levels > 1:
		var lh := tone_range(g)
		var lo := lh.x * 255.0
		var span := maxf((lh.y - lh.x) * 255.0, 1.0)
		var stepv := 255 / (levels - 1)
		for i in px.size():
			px[i] = clampi(int((px[i] - lo) / span * levels), 0, levels - 1) * stepv
	var n := w * h
	var mag := PackedFloat32Array()
	mag.resize(n)
	var dir := PackedByteArray()
	dir.resize(n)
	for y in range(1, h - 1):
		var row := y * w
		for x in range(1, w - 1):
			var i := row + x
			var tl := px[i - w - 1]
			var tr := px[i - w + 1]
			var bl := px[i + w - 1]
			var br := px[i + w + 1]
			var gx := (tr + 2 * px[i + 1] + br) - (tl + 2 * px[i - 1] + bl)
			var gy := (bl + 2 * px[i + w] + br) - (tl + 2 * px[i - w] + tr)
			mag[i] = sqrt(float(gx * gx + gy * gy))
			var ax := absi(gx)
			var ay := absi(gy)
			if ax * 5 > ay * 12:
				dir[i] = 0
			elif ay * 5 > ax * 12:
				dir[i] = 1
			elif (gx > 0) == (gy > 0):
				dir[i] = 3
			else:
				dir[i] = 2
	# Keep only ridge tops: stronger than both neighbours across the edge.
	var thin := PackedFloat32Array()
	thin.resize(n)
	var strengths := PackedFloat32Array()
	for y in range(1, h - 1):
		var row := y * w
		for x in range(1, w - 1):
			var i := row + x
			var m := mag[i]
			if m < 24.0:
				continue
			var d := dir[i]
			var a: float
			var b: float
			if d == 0:
				a = mag[i - 1]
				b = mag[i + 1]
			elif d == 1:
				a = mag[i - w]
				b = mag[i + w]
			elif d == 3:
				a = mag[i - w - 1]
				b = mag[i + w + 1]
			else:
				a = mag[i - w + 1]
				b = mag[i + w - 1]
			if m >= a and m > b:
				thin[i] = m
				strengths.append(m)
	var out := PackedByteArray()
	out.resize(n * 4)
	if strengths.size() > 0:
		strengths.sort()
		var cut := strengths[clampi(int((1.0 - keep) * strengths.size()), 0, strengths.size() - 1)]
		for i in n:
			if thin[i] >= cut and thin[i] > 0.0:
				_dot(out, i)
				if thick:
					var x := i % w
					if x > 0:
						_dot(out, i - 1)
					if x < w - 1:
						_dot(out, i + 1)
					if i >= w:
						_dot(out, i - w)
					if i + w < n:
						_dot(out, i + w)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)


static func _dot(out: PackedByteArray, i: int) -> void:
	var j := i * 4
	out[j] = 255
	out[j + 1] = 255
	out[j + 2] = 255
	out[j + 3] = 255


static func tr_static(s: String) -> String:
	return str(TranslationServer.translate(s))
