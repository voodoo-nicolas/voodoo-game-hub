extends RefCounted

## Word Ladder: turn the start word into the goal word one letter at a time,
## every step a real word. Pure logic, no Nodes. Puzzles are made at run time:
## a common start word, a breadth-first search over the bundled public-domain
## word list, and a common goal word at the wanted distance, so every ladder
## is solvable and the shortest solution (par) is known.

const WORDS_PATH := "res://scripts/games/word_ladder/word_ladder_words.txt.gz"
const ROUND := 5
## Word length and the allowed par (shortest solution) per level.
const LEVELS := [
	{"len": 3, "lo": 2, "hi": 4},
	{"len": 4, "lo": 3, "hi": 6},
	{"len": 5, "lo": 4, "hi": 8},
]
const BASE_POINTS := 100
const EXTRA_STEP_COST := 15
const HINT_COST := 25
const MIN_POINTS := 10

## Everyday words to start and end ladders on (checked against the list when loaded).
const COMMON_TEXT := {
	3: "cat dog sun hat pen cup bed box car bus map net pig rat sky toy van web zip jam key leg man nut owl pie rug sea tea top wax arm bag cow day ear egg eye fan fox gum hen ice jar kid lip mud oil pan pot ray sad tin bat bee big bit bow boy cap cry cut dig dry fit fly gas gem hit hot ink jet joy lid log mat mix mop nap pet pin rag red rib rod row sit sip tap tip toe tub wet win zoo",
	4: "bake band bark barn base bean bear beat bell belt bend bike bill bird bite blue boat bold bone book boot born boss bowl bulb bull burn cage cake calm camp card care cart case cash cast cave chat chin chip city clay clip club coal coat code coin cold cook cool copy cord cork corn cost crab crew crop dark dart data date dawn deal dear deck deep deer desk dial dice diet dime dirt dish dive dock doll door dove down draw drop drum duck dust duty earn east easy edge face fact fail fair fall farm fast fate fear feed feel fell file fill film find fine fire firm fish five flag flat flow foam fold folk food foot fork form fort four free frog fuel full gain game gate gift girl give glad glow glue goal goat gold golf good grab gray grid grin grow gulf hair half hall hand hang hard harm hate hawk head heal heap hear heat heel help herb hero hide high hill hint hold hole home hood hook hope horn host hour huge hunt hurt idea iron jail join joke jump keep kick kind king kiss kite knee knot lack lake lamb lamp land lane last late lawn lazy lead leaf lean left lend lens less life lift like line link lion list live load loaf loan lock long look loop lord lose loud love luck lung mail main make male mall mane mark mask mass mate meal mean meat melt menu mile milk mill mind mine mint miss mist moon more moss most move much mule must nail name navy neck need nest news nice nine node none noon nose note oval oven pace pack page pail pain pair palm park part pass past path peak peel pest pick pier pill pine pink pipe plan play plot plug plus poem pole poll pond pony pool poor port pose post pour pray pull pump pure push race rack rail rain rank rare rate read real rely rent rest rice rich ride ring rise risk road roar rock role roll roof room root rope rose rude ruin rule rush rust safe sail salt sand save seal seat seed seek self sell send shed ship shoe shop shot show shut sick side sign silk sing sink site size skin skip slam slim slip slow snow soap sock soft soil sold sole song soon sore sort soul soup sour spin spot star stay stem step stir stop suit sure swim tail take tale talk tall tank tape task team tear tell tent term test than thin tide tidy tile till time tiny tire toad told toll tone tool torn tour town trap tray tree trim trip true tube tune turn twin type unit used vain vast very vest view vine void vote wage wait wake walk wall want warm warn wash wave weak wear week well west wide wife wild will wind wine wing wipe wire wise wish wolf wood wool word wore work worm wrap yard yarn year yell zero zone",
	5: "about adult after agree ahead alarm alike alive allow alone angle angry apple apply arena argue arise armor aside audio avoid awake award aware badly baker basic beach begin below bench birth black blade blame blank blast blaze blend blind block blood bloom board boast bonus boost booth bound brain brake brand brave bread break breed brick bride brief bring broad brown brush build bunch burst buyer cabin cable candy carry catch cause chain chair chalk charm chart chase cheap check cheek cheer chess chest chief child chill choir civil claim class clean clear clerk click cliff climb clock close cloth cloud coach coast count court cover crack craft crane crash crawl crazy cream crime cross crowd crown crush curve cycle daily dance death delay depth devil diary dirty dizzy doubt dozen draft drain drama dream dress drift drill drink drive eager eagle early earth eight elbow elder empty enemy enjoy enter equal error event every exact exist extra faint faith false fancy fault feast fence fever fiber field fifth fifty fight final first flame flash fleet flesh float flood floor flour fluid focus force forth forty forum found frame frank fresh front frost fruit funny giant glass globe glory glove grace grade grain grand grant grape grass grave great green greet grill group guard guess guest guide habit happy harsh haste heart heavy hedge hello honey honor horse hotel house human humor hurry ideal image index inner input issue ivory jelly jewel joint judge juice knife knock label labor large laser later laugh layer learn lease leave lemon level light limit linen liver lobby local lodge logic loose lover lower loyal lucky lunch magic major maker march match maybe mayor medal media melon mercy merge merit metal meter might minor minus model money month moral motor mount mouse mouth movie music nerve never night noble noise north novel nurse ocean offer olive onion opera orbit order other outer owner paint panel panic paper party pasta patch pause peace pearl phase phone photo piano piece pilot pitch pizza place plain plane plant plate plaza point polar porch pound power press price pride prime print prize proof proud prove pulse punch pupil queen quest quick quiet quite quote radio raise range rapid ratio reach react ready realm rebel refer reign relax reply rider ridge rifle right rigid risky rival river roast robot rocky rough round route royal rural salad sauce scale scare scene scope score scout screw sense serve seven shade shake shame shape share shark sharp sheep sheet shelf shell shift shine shiny shirt shock shoot shore short shout sight silly since skill skirt sleep slice slide slope small smart smell smile smoke snake solid solve sorry sound south space spare speak speed spell spend spice spicy spine spoil spoon sport spray squad stack staff stage stair stake stamp stand stare start state steak steam steel steep steer stick still stock stone store storm story stove strap straw strip stuck study stuff style sugar suite sunny super sweat sweep sweet swift swing sword table taste teach tease teeth thank theme thick thing think third three throw thumb tiger tight timer tired title toast today tooth topic total touch tough towel tower trace track trade trail train trait treat trend trial tribe trick troop truck truly trunk trust truth twice twist uncle under union unity until upper upset urban usual valid value video villa visit vital vivid vocal voice voter wagon waist waste watch water weary weave wedge weigh weird whale wheat wheel white whole widow width witch woman world worry worse worst worth would wound wrist write wrong yield young youth zebra",
}

var valid := {}      # length -> Dictionary(word -> true)
var common := {}     # length -> Array of everyday words that are in the list
var _buckets := {}   # length -> Dictionary("c_t" -> Array of words)

var level: int = 0
var puzzles: Array = []   # [{"start", "end", "par"}], made one ladder at a time
var _used := {}
var index: int = 0
var score: int = 0
var chain: Array = []     # the words so far, starting with the start word
var hints: int = 0        # hints used on this ladder
var last_points: int = 0

func load_words() -> void:
	if not valid.is_empty():
		return
	var f := FileAccess.open(WORDS_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_buffer(f.get_length())
	f.close()
	var all := raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8().split("\n", false)
	for w in all:
		var n: int = w.length()
		if not valid.has(n):
			valid[n] = {}
		valid[n][w] = true
	for n in COMMON_TEXT:
		common[n] = []
		for w in COMMON_TEXT[n].split(" ", false):
			if valid.get(n, {}).has(w):
				common[n].append(w)

func is_word(w: String) -> bool:
	return valid.get(w.length(), {}).has(w)

func _bucket(n: int) -> Dictionary:
	if _buckets.has(n):
		return _buckets[n]
	var b := {}
	for w in valid.get(n, {}):
		for i in n:
			var key: String = w.substr(0, i) + "_" + w.substr(i + 1)
			if not b.has(key):
				b[key] = []
			b[key].append(w)
	_buckets[n] = b
	return b

func neighbors(w: String) -> Array:
	var b := _bucket(w.length())
	var out: Array = []
	for i in w.length():
		for x in b.get(w.substr(0, i) + "_" + w.substr(i + 1), []):
			if x != w:
				out.append(x)
	return out

## Steps from `from` to every reachable word of the same length.
func distances(from: String) -> Dictionary:
	var d := {from: 0}
	var q: Array = [from]
	var h := 0
	while h < q.size():
		var w: String = q[h]
		h += 1
		for x in neighbors(w):
			if not d.has(x):
				d[x] = d[w] + 1
				q.append(x)
	return d

## A shortest ladder from `from` to `to` (both included), or [] if none.
func path(from: String, to: String) -> Array:
	if from == to:
		return [from]
	var parent := {from: ""}
	var q: Array = [from]
	var h := 0
	while h < q.size():
		var w: String = q[h]
		h += 1
		for x in neighbors(w):
			if parent.has(x):
				continue
			parent[x] = w
			if x == to:
				var out: Array = [to]
				var cur: String = w
				while cur != "":
					out.push_front(cur)
					cur = parent[cur]
				return out
			q.append(x)
	return []

func _make_puzzle(used: Dictionary) -> Dictionary:
	var spec: Dictionary = LEVELS[level]
	var n: int = spec.len
	var pool: Array = common.get(n, [])
	var lo: int = spec.lo
	var hi: int = spec.hi
	for attempt in 80:
		if attempt == 40:
			lo = maxi(2, lo - 1)
			hi += 1
		var s: String = pool[randi() % pool.size()]
		if used.has(s):
			continue
		var d := distances(s)
		var cands: Array = []
		for w in pool:
			var k: int = d.get(w, -1)
			if k >= lo and k <= hi and not used.has(w):
				cands.append(w)
		if cands.is_empty():
			continue
		var e: String = cands[randi() % cands.size()]
		used[s] = true
		used[e] = true
		return {"start": s, "end": e, "par": d[e]}
	# Last resort: any two linked words.
	var s2: String = pool[0]
	var d2 := distances(s2)
	for w in pool:
		if d2.get(w, 0) >= 2:
			return {"start": s2, "end": w, "par": d2[w]}
	return {"start": s2, "end": pool[1], "par": 1}

func new_round(lvl: int) -> void:
	level = clampi(lvl, 0, LEVELS.size() - 1)
	index = 0
	score = 0
	puzzles = []
	_used = {}
	_begin()

func _begin() -> void:
	while puzzles.size() <= index:
		puzzles.append(_make_puzzle(_used))
	chain = [puzzles[index].start]
	hints = 0
	last_points = 0

func is_over() -> bool:
	return index >= ROUND or puzzles.is_empty()

func current() -> Dictionary:
	return puzzles[index]

func par() -> int:
	return int(puzzles[index].par)

func steps() -> int:
	return chain.size() - 1

func solved() -> bool:
	return not is_over() and chain.back() == puzzles[index].end

func _diff(a: String, b: String) -> int:
	var n := 0
	for i in a.length():
		if a[i] != b[i]:
			n += 1
	return n

## Adds `word` as the next step. Returns "ok" or why not:
## "same", "not_one" (not exactly one letter changed), "used", "not_word", "done".
func try_step(word: String) -> String:
	if is_over() or solved():
		return "done"
	var cur: String = chain.back()
	if word == cur:
		return "same"
	if word.length() != cur.length() or _diff(word, cur) != 1:
		return "not_one"
	if chain.has(word):
		return "used"
	if not is_word(word):
		return "not_word"
	chain.append(word)
	return "ok"

func undo() -> bool:
	if chain.size() <= 1 or solved():
		return false
	chain.pop_back()
	return true

## Plays the next word of a shortest ladder from where you are; costs points.
func hint() -> String:
	if is_over() or solved():
		return ""
	var p := path(chain.back(), puzzles[index].end)
	if p.size() < 2:
		return ""
	hints += 1
	var nxt: String = p[1]
	if chain.has(nxt):
		chain = chain.slice(0, chain.find(nxt) + 1)
	else:
		chain.append(nxt)
	return nxt

func is_perfect() -> bool:
	return steps() == par() and hints == 0

func points_now() -> int:
	var extra := maxi(0, steps() - par() - hints)
	return maxi(MIN_POINTS, BASE_POINTS - EXTRA_STEP_COST * extra - HINT_COST * hints)

## Banks the points of a solved ladder and moves on to the next one.
func finish_ladder() -> int:
	last_points = points_now()
	score += last_points
	index += 1
	if not is_over():
		_begin()
	return last_points

func skip() -> void:
	last_points = 0
	index += 1
	if not is_over():
		_begin()

func to_dict() -> Dictionary:
	return {"level": level, "puzzles": puzzles, "index": index, "score": score, "chain": chain, "hints": hints}

func from_dict(d: Dictionary) -> bool:
	var pz = d.get("puzzles", [])
	if not (pz is Array) or pz.is_empty():
		return false
	level = clampi(int(d.get("level", 0)), 0, LEVELS.size() - 1)
	puzzles = []
	for p in pz:
		puzzles.append({"start": str(p.start), "end": str(p.end), "par": int(p.par)})
	index = clampi(int(d.get("index", 0)), 0, ROUND)
	_used = {}
	for p in puzzles:
		_used[p.start] = true
		_used[p.end] = true
	score = int(d.get("score", 0))
	hints = int(d.get("hints", 0))
	chain = []
	for w in d.get("chain", []):
		chain.append(str(w))
	if not is_over() and (index >= puzzles.size() or chain.is_empty() or chain[0] != puzzles[index].start):
		_begin()
	return true
