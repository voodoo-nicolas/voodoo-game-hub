extends RefCounted

## A small QR Code encoder (since v0.31, STANDARDS §5 join links): byte mode,
## error correction level M, versions 1-6 (up to 106 bytes -- a join link is
## ~75), mask 0. Any mask is valid for readers; picking the "best" one only
## matters for marginal prints, not a phone screen.
##
##     var img: Image = QR.image("https://...", 8)   # 8 px per module + quiet zone
##
## Verified against OpenCV's decoder (tools/test_qr.gd writes test images).

## Per version (index = version): [data codewords per block, blocks, EC codewords per block] at level M.
const BLOCKS_M := [[], [16, 1, 10], [28, 1, 16], [44, 1, 26], [32, 2, 18], [43, 2, 24], [27, 4, 16]]
## The single alignment pattern's centre for versions 2-6.
const ALIGN := [0, 0, 18, 22, 26, 30, 34]
## Format bits for level M + mask 0 (BCH-encoded and masked), MSB first.
const FORMAT_M0 := 0x5412

static var _exp: PackedInt32Array = PackedInt32Array()
static var _log: PackedInt32Array = PackedInt32Array()

## The module matrix (true = dark) for `text`, or [] if it is too long.
static func encode(text: String) -> Array:
	var data := text.to_utf8_buffer()
	var version := 0
	for v in range(1, 7):
		var b: Array = BLOCKS_M[v]
		if data.size() + 2 <= int(b[0]) * int(b[1]):  # 4-bit mode + 8-bit count + data + terminator
			version = v
			break
	if version == 0:
		return []
	var codewords := _codewords(data, version)
	var size := 17 + 4 * version
	var grid: Array = []
	var reserved: Array = []
	for r in size:
		grid.append([])
		reserved.append([])
		for c in size:
			grid[r].append(false)
			reserved[r].append(false)
	_function_patterns(grid, reserved, version, size)
	_place(grid, reserved, codewords, size)
	_format(grid, size)
	return grid

## The code as an image: black on white, `scale` px per module, with the
## 4-module quiet zone readers need.
static func image(text: String, scale: int = 8) -> Image:
	var grid := encode(text)
	if grid.is_empty():
		return null
	var n: int = grid.size()
	var px := (n + 8) * scale
	var img := Image.create(px, px, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	for r in n:
		for c in n:
			if grid[r][c]:
				img.fill_rect(Rect2i((c + 4) * scale, (r + 4) * scale, scale, scale), Color.BLACK)
	return img

# ---------- data ----------

static func _codewords(data: PackedByteArray, version: int) -> PackedByteArray:
	var spec: Array = BLOCKS_M[version]
	var per_block: int = spec[0]
	var blocks: int = spec[1]
	var ec_len: int = spec[2]
	var capacity: int = per_block * blocks
	var bits: Array = []
	_push(bits, 0b0100, 4)          # byte mode
	_push(bits, data.size(), 8)     # character count (versions 1-9)
	for byte in data:
		_push(bits, byte, 8)
	for i in mini(4, capacity * 8 - bits.size()):
		bits.append(0)              # terminator
	while bits.size() % 8 != 0:
		bits.append(0)
	var stream := PackedByteArray()
	for i in range(0, bits.size(), 8):
		var b := 0
		for k in 8:
			b = (b << 1) | int(bits[i + k])
		stream.append(b)
	var pad := [0xEC, 0x11]
	var p := 0
	while stream.size() < capacity:
		stream.append(pad[p % 2])
		p += 1
	# Split into blocks, add Reed-Solomon EC to each, then interleave.
	var data_blocks: Array = []
	var ec_blocks: Array = []
	for b in blocks:
		var chunk := stream.slice(b * per_block, (b + 1) * per_block)
		data_blocks.append(chunk)
		ec_blocks.append(_rs(chunk, ec_len))
	var out := PackedByteArray()
	for i in per_block:
		for b in blocks:
			out.append(data_blocks[b][i])
	for i in ec_len:
		for b in blocks:
			out.append(ec_blocks[b][i])
	return out

static func _push(bits: Array, value: int, count: int) -> void:
	for i in range(count - 1, -1, -1):
		bits.append((value >> i) & 1)

# ---------- Reed-Solomon over GF(256), polynomial 0x11D ----------

static func _gf_init() -> void:
	if not _exp.is_empty():
		return
	_exp.resize(512)
	_log.resize(256)
	var x := 1
	for i in 255:
		_exp[i] = x
		_log[x] = i
		x <<= 1
		if x & 0x100:
			x ^= 0x11D
	for i in range(255, 512):
		_exp[i] = _exp[i - 255]

static func _mul(a: int, b: int) -> int:
	if a == 0 or b == 0:
		return 0
	return _exp[_log[a] + _log[b]]

static func _rs(data: PackedByteArray, n: int) -> PackedByteArray:
	_gf_init()
	# Generator: product of (x - a^i), i = 0..n-1; coefficients highest first.
	var gen: Array = [1]
	for i in n:
		var next: Array = []
		next.resize(gen.size() + 1)
		next.fill(0)
		for j in gen.size():
			next[j] ^= gen[j]
			next[j + 1] ^= _mul(gen[j], _exp[i])
		gen = next
	var rem: Array = []
	rem.resize(n)
	rem.fill(0)
	for byte in data:
		var factor: int = byte ^ int(rem[0])
		rem.pop_front()
		rem.append(0)
		for j in n:
			rem[j] ^= _mul(int(gen[j + 1]), factor)
	var out := PackedByteArray()
	for v in rem:
		out.append(int(v))
	return out

# ---------- layout ----------

static func _put(grid: Array, reserved: Array, r: int, c: int, dark: bool) -> void:
	grid[r][c] = dark
	reserved[r][c] = true

static func _finder(grid: Array, reserved: Array, top: int, left: int, size: int) -> void:
	for dr in range(-1, 8):
		for dc in range(-1, 8):
			var r := top + dr
			var c := left + dc
			if r < 0 or c < 0 or r >= size or c >= size:
				continue
			var inside := dr >= 0 and dr <= 6 and dc >= 0 and dc <= 6
			var dark := inside and (dr == 0 or dr == 6 or dc == 0 or dc == 6 or (dr >= 2 and dr <= 4 and dc >= 2 and dc <= 4))
			_put(grid, reserved, r, c, dark)

static func _function_patterns(grid: Array, reserved: Array, version: int, size: int) -> void:
	_finder(grid, reserved, 0, 0, size)
	_finder(grid, reserved, 0, size - 7, size)
	_finder(grid, reserved, size - 7, 0, size)
	for i in range(8, size - 8):
		_put(grid, reserved, 6, i, i % 2 == 0)
		_put(grid, reserved, i, 6, i % 2 == 0)
	if version >= 2:
		var a: int = ALIGN[version]
		for dr in range(-2, 3):
			for dc in range(-2, 3):
				_put(grid, reserved, a + dr, a + dc, maxi(absi(dr), absi(dc)) != 1)
	# Format areas (filled in later) and the dark module.
	for i in 9:
		reserved[8][i] = true
		reserved[i][8] = true
	for i in 8:
		reserved[8][size - 1 - i] = true
		reserved[size - 1 - i][8] = true
	_put(grid, reserved, size - 8, 8, true)

## Codewords into the free modules: two-column zigzag from the bottom
## right, skipping the timing column; mask 0 flips (r + c) even modules.
static func _place(grid: Array, reserved: Array, codewords: PackedByteArray, size: int) -> void:
	var bit_index := 0
	var total := codewords.size() * 8
	var col := size - 1
	var upward := true
	while col > 0:
		if col == 6:
			col -= 1
		for k in size:
			var r := size - 1 - k if upward else k
			for dc in 2:
				var c := col - dc
				if reserved[r][c]:
					continue
				var dark := false
				if bit_index < total:
					dark = ((codewords[bit_index / 8] >> (7 - bit_index % 8)) & 1) == 1
					bit_index += 1
				if (r + c) % 2 == 0:
					dark = not dark
				grid[r][c] = dark
		upward = not upward
		col -= 2

## The 15 format bits (bit 0 = least significant) in both copies, in the
## standard's order (as in Nayuki's reference encoder; grid is [row][col]).
static func _format(grid: Array, size: int) -> void:
	var bits := FORMAT_M0
	var bit := func(i: int) -> bool: return ((bits >> i) & 1) == 1
	for i in range(0, 6):
		grid[i][8] = bit.call(i)
	grid[7][8] = bit.call(6)
	grid[8][8] = bit.call(7)
	grid[8][7] = bit.call(8)
	for i in range(9, 15):
		grid[8][14 - i] = bit.call(i)
	for i in range(0, 8):
		grid[8][size - 1 - i] = bit.call(i)
	for i in range(8, 15):
		grid[size - 15 + i][8] = bit.call(i)
	grid[size - 8][8] = true
