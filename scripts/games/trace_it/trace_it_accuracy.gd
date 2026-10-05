extends RefCounted

## Trace It's accuracy check -- pure data, no nodes, so it runs on a worker
## thread and is tested headlessly with simulated camera pictures.
##
## The phone doesn't move, so the camera picture and the overlay are already
## lined up: `map` (a Transform2D) takes a point of the picture (in the
## source picture's pixels) to the camera image (in camera pixels). It's
## built on the main thread from the locked overlay and the camera view.
##
##  1. Both camera pictures -- the blank paper ("baseline", taken at Lock) and
##     the finished drawing ("final", taken after ✓ Done) -- are resampled
##     into a GRID_W-wide grid over the picture.
##  2. Ink = what got darker than the blank paper (after evening out the
##     camera's exposure), on paper only (not the table), lone specks removed.
##  3. The template = the picture's line art on the same grid.
##  4. Distance maps of both: precision = share of ink within `tol` grid px of
##     a template line, recall = share of template within `tol` of ink,
##     accuracy = F1.
##  5. Coaching: the best small shift (is the whole drawing off to one side?),
##     what was missed vs. drawn off the line, a hand left in view.
##
## Tolerances (grid px at 320 across): relaxed 6, normal 4, strict 2.

const GRID_W := 320
const TOLERANCES := {"relaxed": 6, "normal": 4, "strict": 2}
const LEVELS := ["off", "relaxed", "normal", "strict"]
const BIG := 1 << 20


## The picture -> camera map: overlay holder transform (picture placed on
## screen), the camera view rect on screen and its basis (screen UV -> camera
## UV, see trace_it_fx.CAMERA), and the camera image size.
static func make_map(pic_size: Vector2, fit: Vector2, holder: Transform2D, view_pos: Vector2, view_size: Vector2, bx: Vector2, by: Vector2, cam_size: Vector2) -> Transform2D:
	# Built from the picture's corners, not 1-px steps: Vector2 is 32-bit.
	var pts := [Vector2.ZERO, Vector2(pic_size.x, 0), Vector2(0, pic_size.y)]
	var out := []
	for p in pts:
		var hl := Vector2(p.x / pic_size.x * fit.x, p.y / pic_size.y * fit.y)
		var s: Vector2 = holder * hl
		var u := (s - view_pos) / view_size
		var c := bx * (u.x - 0.5) + by * (u.y - 0.5) + Vector2(0.5, 0.5)
		out.append(c * cam_size)
	return Transform2D((out[1] - out[0]) / pic_size.x, (out[2] - out[0]) / pic_size.y, out[0])


static func grid_size(pic_size: Vector2) -> Vector2i:
	return Vector2i(GRID_W, maxi(8, int(round(GRID_W * pic_size.y / pic_size.x))))


## The template's line art on the grid (1 = line). `lines` is white-on-
## transparent at the picture's size or any size with its aspect.
static func template_mask(lines: Image, g: Vector2i) -> PackedByteArray:
	var img := lines.duplicate() as Image
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.resize(g.x, g.y, Image.INTERPOLATE_BILINEAR)
	var data := img.get_data()
	var m := PackedByteArray()
	m.resize(g.x * g.y)
	for i in g.x * g.y:
		m[i] = 1 if data[i * 4 + 3] > 60 else 0
	return m


## A camera image (L8) sampled on the grid; 255+1 marks "outside the camera".
## Big camera images are box-shrunk first so each grid cell averages roughly
## its own camera pixels (a thin pencil line still darkens its cell).
static func resample(cam: Image, map: Transform2D, pic_size: Vector2, g: Vector2i) -> PackedInt32Array:
	var img := cam.duplicate() as Image
	if img.get_format() != Image.FORMAT_L8:
		img.convert(Image.FORMAT_L8)
	var m := map
	var cell := (m.x * (pic_size.x / g.x)).length()
	while cell >= 2.0 and img.get_width() > 64:
		img.shrink_x2()
		m = Transform2D(m.x * 0.5, m.y * 0.5, m.origin * 0.5)
		cell *= 0.5
	var w := img.get_width()
	var h := img.get_height()
	var px := img.get_data()
	var out := PackedInt32Array()
	out.resize(g.x * g.y)
	var sx := pic_size.x / g.x
	var sy := pic_size.y / g.y
	for j in g.y:
		for i in g.x:
			var c := m * Vector2((i + 0.5) * sx, (j + 0.5) * sy)
			var x := int(c.x)
			var y := int(c.y)
			out[j * g.x + i] = px[y * w + x] if x >= 0 and y >= 0 and x < w and y < h else 256
	return out


static func _median(vals: PackedInt32Array) -> float:
	return _percentile(vals, 0.5)


static func _percentile(vals: PackedInt32Array, q: float) -> float:
	if vals.is_empty():
		return 0.0
	var v := vals.duplicate()
	v.sort()
	return float(v[clampi(int(v.size() * q), 0, v.size() - 1)])


## Everything the results screen needs, from the two grid samplings.
## Returns {accuracy, precision, recall, ink, template, paper_share,
## shift: Vector2i, shift_gain, crowded, tips: [keys], heat: Image,
## drawing: Image, ink_mask: Image, template_img: Image}.
static func measure(base_cam: Image, final_cam: Image, map: Transform2D, pic_size: Vector2, template: PackedByteArray, tol: int) -> Dictionary:
	var g := grid_size(pic_size)
	var n := g.x * g.y
	var base := resample(base_cam, map, pic_size, g)
	var fin := resample(final_cam, map, pic_size, g)
	# Evening out exposure: compare the paper's bright end in both pictures
	# (ink and hands only darken, so the bright end is still bare paper), and
	# never by more than auto-exposure really changes -- a hand covering most
	# of the picture must not be "corrected" into paper.
	var bv := PackedInt32Array()
	var fv := PackedInt32Array()
	for i in n:
		if base[i] <= 255 and fin[i] <= 255:
			bv.append(base[i])
			fv.append(fin[i])
	var b_med := _median(bv)
	var f_top := _percentile(fv, 0.9)
	var gain := clampf(_percentile(bv, 0.9) / f_top, 0.75, 1.33) if f_top > 0.0 else 1.0
	# Paper = bright in the blank picture (the table around it doesn't count).
	var paper := PackedByteArray()
	paper.resize(n)
	var ink := PackedByteArray()
	ink.resize(n)
	var paper_n := 0
	for i in n:
		if base[i] > 255 or fin[i] > 255:
			continue
		if base[i] >= b_med * 0.55:
			paper[i] = 1
			paper_n += 1
			var dark := base[i] - fin[i] * gain
			if dark > maxf(10.0, base[i] * 0.08):
				ink[i] = 1
	ink = _despeckle(ink, g)
	var ink_n := 0
	var tpl_n := 0
	var tpl_all := 0
	var tpl := PackedByteArray()
	tpl.resize(n)
	for i in n:
		ink_n += ink[i]
		if template[i]:
			tpl_all += 1
			if paper[i]:
				tpl[i] = 1
				tpl_n += 1
	var d_tpl := chamfer(tpl, g)
	var d_ink := chamfer(ink, g)
	var lim := tol * 3   # chamfer units: 3 per pixel straight
	var ink_ok := 0
	var tpl_ok := 0
	for i in n:
		if ink[i] and d_tpl[i] <= lim:
			ink_ok += 1
		if tpl[i] and d_ink[i] <= lim:
			tpl_ok += 1
	var precision := float(ink_ok) / ink_n if ink_n > 0 else 0.0
	var recall := float(tpl_ok) / tpl_n if tpl_n > 0 else 0.0
	var f1 := 0.0 if precision + recall == 0.0 else 2.0 * precision * recall / (precision + recall)
	# Is the whole drawing off to one side? Try small shifts of the ink:
	# every 2 px, then 1 px around the best (ties keep the smaller shift).
	var best_shift := Vector2i.ZERO
	var best_prec := precision
	if ink_n > 20 and precision < 0.95:
		var pts := PackedInt32Array()
		for i in n:
			if ink[i]:
				pts.append(i)
		var tries := []
		for dy in range(-8, 9, 2):
			for dx in range(-8, 9, 2):
				tries.append(Vector2i(dx, dy))
		for pass_i in 2:
			for t in tries:
				if t == Vector2i.ZERO or t == best_shift:
					continue
				var p := _shifted_precision(pts, t, g, d_tpl, lim, ink_n)
				if p > best_prec + 0.005 or (absf(p - best_prec) <= 0.005 and t.length() < best_shift.length() and best_shift != Vector2i.ZERO):
					best_prec = p
					best_shift = t
			tries = []
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					tries.append(best_shift + Vector2i(dx, dy))
	var res := {
		"accuracy": f1, "precision": precision, "recall": recall,
		"ink": ink_n, "template": tpl_n,
		"paper_share": float(tpl_n) / tpl_all if tpl_all > 0 else 0.0,
		"shift": best_shift, "shift_gain": best_prec - precision,
		"crowded": paper_n > 0 and ink_n > paper_n * 0.35,
		"grid": g,
	}
	res.tips = tips(res)
	res.heat = heatmap(g, tpl, ink, d_tpl, d_ink, lim)
	res.drawing = gray_image(fin, g, gain)
	res.ink_mask = mask_image(ink, g, Color(0.1, 0.1, 0.1))
	res.template_img = mask_image(tpl, g, Color(0.1, 0.4, 1.0))
	return res


static func _shifted_precision(pts: PackedInt32Array, t: Vector2i, g: Vector2i, d_tpl: PackedInt32Array, lim: int, ink_n: int) -> float:
	var ok := 0
	for i in pts:
		var x := i % g.x + t.x
		var y := i / g.x + t.y
		if x >= 0 and y >= 0 and x < g.x and y < g.y and d_tpl[y * g.x + x] <= lim:
			ok += 1
	return float(ok) / ink_n


## Ink pixels with fewer than 2 ink neighbours are noise (paper grain,
## sensor speckle), not pencil.
static func _despeckle(ink: PackedByteArray, g: Vector2i) -> PackedByteArray:
	var out := ink.duplicate()
	for y in range(1, g.y - 1):
		for x in range(1, g.x - 1):
			var i := y * g.x + x
			if not ink[i]:
				continue
			var c := ink[i - g.x - 1] + ink[i - g.x] + ink[i - g.x + 1] + ink[i - 1] + ink[i + 1] + ink[i + g.x - 1] + ink[i + g.x] + ink[i + g.x + 1]
			if c < 2:
				out[i] = 0
	return out


## Two-pass 3-4 chamfer distance to the nearest set pixel (3 = one pixel
## straight, 4 = diagonal); BIG where the mask is empty.
static func chamfer(mask: PackedByteArray, g: Vector2i) -> PackedInt32Array:
	var w := g.x
	var h := g.y
	var d := PackedInt32Array()
	d.resize(w * h)
	for i in w * h:
		d[i] = 0 if mask[i] else BIG
	for y in h:
		for x in w:
			var i := y * w + x
			var v := d[i]
			if v == 0:
				continue
			if x > 0:
				v = mini(v, d[i - 1] + 3)
			if y > 0:
				v = mini(v, d[i - w] + 3)
				if x > 0:
					v = mini(v, d[i - w - 1] + 4)
				if x < w - 1:
					v = mini(v, d[i - w + 1] + 4)
			d[i] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var v := d[i]
			if v == 0:
				continue
			if x < w - 1:
				v = mini(v, d[i + 1] + 3)
			if y < h - 1:
				v = mini(v, d[i + w] + 3)
				if x < w - 1:
					v = mini(v, d[i + w + 1] + 4)
				if x > 0:
					v = mini(v, d[i + w - 1] + 4)
			d[i] = v
	return d


## What to tell the player, most useful first (keys; the game words them).
static func tips(r: Dictionary) -> Array:
	var out := []
	if r.crowded:
		out.append("crowded")
	if r.paper_share < 0.7:
		out.append("off_paper")
	if r.ink < 20:
		out.append("no_ink")
		return out
	var s: Vector2i = r.shift
	if r.shift_gain >= 0.12 and not shift_words(s).is_empty():
		out.append("shift")
	if r.recall < 0.55 and r.precision >= 0.6:
		out.append("missed")
	if r.precision < 0.5:
		out.append("off_line")
	if r.accuracy >= 0.85:
		out.append("great")
	elif out.is_empty():
		out.append("compare")
	return out


## Which way the drawing sits, from the shift that best fixes it: the ink
## had to move by `s` to match, so it sits the opposite way.
static func shift_words(s: Vector2i) -> Array:
	var w := []
	if s.y >= 3:
		w.append("above")
	elif s.y <= -3:
		w.append("below")
	if s.x >= 3:
		w.append("left")
	elif s.x <= -3:
		w.append("right")
	return w


## Green: ink on a line. Red: ink off the lines. Grey: template missed.
## Faint green: template covered.
static func heatmap(g: Vector2i, tpl: PackedByteArray, ink: PackedByteArray, d_tpl: PackedInt32Array, d_ink: PackedInt32Array, lim: int) -> Image:
	var data := PackedByteArray()
	data.resize(g.x * g.y * 4)
	for i in g.x * g.y:
		var c := Color(1, 1, 1, 0)
		if ink[i]:
			c = Color(0.1, 0.8, 0.25, 1) if d_tpl[i] <= lim else Color(0.95, 0.15, 0.2, 1)
		elif tpl[i]:
			c = Color(0.55, 0.85, 0.6, 0.6) if d_ink[i] <= lim else Color(0.55, 0.55, 0.6, 0.9)
		data[i * 4] = int(c.r * 255)
		data[i * 4 + 1] = int(c.g * 255)
		data[i * 4 + 2] = int(c.b * 255)
		data[i * 4 + 3] = int(c.a * 255)
	return Image.create_from_data(g.x, g.y, false, Image.FORMAT_RGBA8, data)


static func gray_image(vals: PackedInt32Array, g: Vector2i, gain: float) -> Image:
	var data := PackedByteArray()
	data.resize(g.x * g.y)
	for i in g.x * g.y:
		data[i] = 40 if vals[i] > 255 else clampi(int(vals[i] * gain), 0, 255)
	return Image.create_from_data(g.x, g.y, false, Image.FORMAT_L8, data)


static func mask_image(m: PackedByteArray, g: Vector2i, color: Color) -> Image:
	var data := PackedByteArray()
	data.resize(g.x * g.y * 4)
	for i in g.x * g.y:
		var on := m[i] == 1
		data[i * 4] = int(color.r * 255) if on else 245
		data[i * 4 + 1] = int(color.g * 255) if on else 243
		data[i * 4 + 2] = int(color.b * 255) if on else 235
		data[i * 4 + 3] = 255
	return Image.create_from_data(g.x, g.y, false, Image.FORMAT_RGBA8, data)


## Movement watch: has the paper shifted under the camera since the blank
## picture? Both are small grey pictures of the whole camera view. Ink and
## hands only make the paper darker; a part that got clearly *brighter*
## (after evening out exposure) means the paper's edge or the table moved.
## Returns the share of such pixels.
static func brightened_share(base_small: Image, now_small: Image) -> float:
	var a := base_small.get_data()
	var b := now_small.get_data()
	if a.size() != b.size() or a.is_empty():
		return 0.0
	var av := PackedInt32Array()
	var bv := PackedInt32Array()
	for i in a.size():
		av.append(a[i])
		bv.append(b[i])
	var gain := _median(av) / maxf(_median(bv), 1.0)
	var bright := 0
	for i in a.size():
		if b[i] * gain - a[i] > 28.0:
			bright += 1
	return float(bright) / a.size()
