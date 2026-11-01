extends RefCounted
## The content graph of the loaded set (docs/specifications/BUNDLE_SYSTEM.md, section 11):
## the records and the links their reference fields name (Content.refs, by LINKS), and
## what a player comes to from the start (Starts) by the rules of the hands (Tools): the
## biomes, the cells the generator lays and the plants, trees, bushes and animals living
## there; what acting on them gives with the tools had so far; what the recipes make of
## that at the stations set down; what is set down, planted and sown in turn, until nothing
## new comes. `errors` (the validator fails on them in the full set): an item that can
## never be had or that nothing gives, a recipe never made, a plant, bush or tree that
## never grows, an animal whose food never grows, a tool kind no item is, and the cycles
## that block them; `warnings` (they fail nothing): dead ends, stations of one recipe,
## twins, loops of recipes that give back more than they take, cells that never appear.
## Each thing reached has a depth (`reached`) and an era of progress (`era`, section 9): the
## earliest it comes in, not before the era written on an item; an item written into an era
## earlier than it can come in is an error, an item deeper than its era expects a warning.
## Each is a finding too, with its check and the records it is about, and `basis` tells
## what each thing comes of: tools/content_report.gd writes them into
## docs/generated/content-graph.md and content-checks.md. Built by the validator, the
## reports and the tests, never by the game: `new()` builds it for the set loaded now.

const Content := preload("res://src/shared/content/content.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Items := preload("res://src/shared/content/items.gd")
const Plants := preload("res://src/shared/content/plants.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Starts := preload("res://src/shared/content/starts.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Eras := preload("res://src/shared/content/eras.gd")

## What each reference field ("kind.field", see Content.refs) is to the graph: `gives` —
## what it names comes from the record by the field's action (`via`, under its rule of the
## hands, see _can); `makes` — what it names comes into the world from the item had (set
## down, planted, sown); `grows` — a biome grows it; `lives` — the record lives in the
## world when one of what it names is there; `made`, `also`, `needs`, `station` — a
## recipe's product, by-products, what it takes (uses up or keeps) and station; `start`,
## `camp` — the start's bag and the things it sets
## down by the spawn; `serves` — a station set down stands for the ones it names; `use` — a
## use only (mending, an animal's food); `era` — the era of an item (see era). A field not
## here fails graph_test: the graph must know every link.
const LINKS := {
	"materials.item": "gives", "materials.bonus": "gives", "materials.mow": "gives", "materials.mow_gives": "gives",
	"items.place": "makes", "items.plant": "makes", "items.sow": "makes", "items.crop": "makes", "items.repair": "use", "items.ammo": "use",
	"items.serves": "serves",
	"creatures.likes": "use", "creatures.biomes": "lives", "plants.biomes": "lives", "creatures.carcass": "gives",
	"trees.seed": "gives", "trees.log": "gives", "trees.twig": "gives",
	"bushes.fruit": "gives", "bushes.twig": "gives", "bushes.item": "gives",
	"biomes.trees": "grows", "biomes.bushes": "grows", "biomes.fish": "gives",
	"recipes.makes": "made", "recipes.also.item": "also", "recipes.needs": "needs", "recipes.keeps": "needs",
	"recipes.at": "station",
	"starts.bag": "start", "starts.camp.item": "camp",
	"plants.gives": "gives",
	"items.era": "era",
}
## The links by which a record uses an item (see uses).
const USED_BY := ["consumes", "requires", "requires_station", "repaired_with"]
## The fields that say what an item is for besides being used up: an item with none of
## them set that no recipe needs and nothing mends with is a dead end.
const FUNCTIONS := ["tool", "prop", "place", "plant", "sow", "crop", "food", "heal", "fuel", "light", "wear_on"]
## The fields that make two items alike in what they do (see _twins).
const ALIKE := ["weight", "stack", "food", "heal", "place", "tool", "power", "area", "mows", "swing", "plant", "sow",
	"crop", "reach", "durability", "repair", "prop", "fuel", "light", "wear_on", "bag_slots"]
## A depth past every real one.
const FAR := 1 << 30
## The checks, each an error (true: the validator fails on it in the full set) or a warning.
const CHECKS := {"no_source": true, "never_had": true, "no_tool_item": true, "never_made": true, "never_grows": true,
	"no_food": true, "cycle": true, "early_era": true, "dead_end": false, "station": false, "twins": false, "loop": false,
	"never_appears": false, "long_chain": false}
## How each way is told in a message (see _why).
const TOLD := {"world": "the world", "start": "the start", "special": "a special source", "craft": "made",
	"recipe": "made by", "also": "a by-product of", "spawns": "grown by", "lives": "living in", "is": "being", "place": "set down from",
	"plant": "planted from", "sow": "sown from", "dig": "dug from", "mow": "mown from", "fell": "felled from",
	"gather": "gathered from", "dig_out": "dug out of", "hunt": "hunted", "fish": "fished from", "serves": "stood in for by"}

## Every way a thing comes about: {"to": key, "via": how ("world", "start", "special", an
## action of Content.ACTIONS, "craft" for a recipe made, "recipe" for its product, "also"
## for a by-product, "spawns", "lives", "is" for a tool of a kind, "serves" for a station
## another stands in for),
## "from": the key it comes from or "", "needs": the keys it takes besides (a recipe's
## materials, what it keeps, station and tools; the tool a thing is set down with), "act":
## the action whose rule of the hands a tool had must keep, "" for none, "step": 1 for a
## recipe's product or by-product}.
## Keys: "kind/id" for a record in the world or had (`items/` in the bag), "placed/<item>"
## for a thing standing in the world, "tool/<kind>" for a tool of that kind in the bag.
var ways: Array = []
## Key -> the ways that give it (see ways), reached or not.
var sources := {}
## Item key -> [link, key of the record that uses it] for each link of USED_BY and an
## animal's food (`feeds_on`).
var uses := {}
## What the start comes to: key -> depth, the steps of making from the start (what the
## world and the start give with bare hands is 0; what a tool gets, the tool's depth; a
## recipe's product one more than the deepest of what it takes, station and tools).
var reached := {}
## Reached key -> the way that gives it at its depth.
var how := {}
## What the start comes to: key -> era, a rank of Eras.ERAS (0 the first): what the world and
## the start give with bare hands 0; what a tool gets, the earliest era of a tool that can;
## a recipe's product the latest of what it takes, station and tools; never before the era
## written on an item (`era`). The same keys as `reached`.
var era := {}
## Reached key -> the way that gives it at its era.
var dated := {}
## Records of the set by key ("items/resources:log"), "placed/" keys by their item's.
var records := {}
## What the checks found, in order: {"check": a key of CHECKS, "text": the message (in
## `errors` or `warnings`), "keys": the records it is about, "of": a check's details (a
## station's recipes, a loop's yield), null for none}.
var findings: Array = []
var errors: PackedStringArray = []
var warnings: PackedStringArray = []


func _init() -> void:
	for kind: String in ["materials", "items", "trees", "bushes", "plants", "creatures", "biomes", "recipes", "starts"]:
		for r: Dictionary in Content.records(kind):
			records["%s/%s" % [kind, r.id]] = r
	_make_ways()
	_reach()
	_check()


## The ways things come about in the set loaded now (see ways).
func _make_ways() -> void:
	_way("starts/" + Starts.START.id, "world")
	# The world as the generator makes it: every biome; the cells it lays (core's and those
	# of the roles, every ore; a trunk's and a crown's are a tree's, felled rather than dug); the plant
	# of each kind and every plant of its own picture (Grass).
	for r: Dictionary in Content.records("biomes"):
		_way("biomes/" + r.id, "world")
	for id: String in Mat.KNOWN.values():
		_way("materials/" + id, "world")
	for role: String in Mat.ROLES:
		var m := Mat.of_role(role, -1)
		if m >= 0 and not role in ["trunk", "crown"]:
			_way("materials/" + Mat.IDS[m], "world")
	# Every ore with a share of the veins (Mat.ORES), not only the last.
	for m: int in Mat.ORES:
		_way("materials/" + Mat.IDS[m], "world")
	for kind: String in Plants.KINDS.values():
		if kind != Plants.KINDS.CUSTOM and Plants.of_kind(kind) != "":
			_way("plants/" + Plants.of_kind(kind), "world")
	for c: Dictionary in Plants.CUSTOM:
		_way("plants/" + c.id, "world")
	for r: Dictionary in Content.records("creatures"):
		if r.biomes.is_empty():
			_way("creatures/" + r.id, "world")
	for id: String in Items.IDS:
		var item := Items.get_item(id)
		if item.source == "special":
			_way("items/" + id, "special")
		if item.prop != "none":
			_way("placed/" + id, "place", "items/" + id, ["tool/" + item.place_tool] if item.place_tool != "none" else [])
			records["placed/" + id] = item
		if item.tool != "none":
			_way("tool/" + item.tool, "is", "items/" + id)
	for r: Dictionary in Crafting.RECIPES:
		var needs := []
		for id: String in r.needs.keys() + r.keeps.keys():
			if not needs.has("items/" + id):
				needs.append("items/" + id)
		if r.at != "":
			needs.append("placed/" + r.at)
		for kind: String in r.tools:
			needs.append("tool/" + kind)
		_way("recipes/" + r.id, "craft", "", needs)
	# A tree stands on cells of the trunk and crown roles (Trees.check).
	var trees_stand := Mat.LOG >= 0 and Mat.LEAVES >= 0
	for kind: String in Content.SCHEMAS:
		for ref: Array in Content.refs(kind):
			var spec: Dictionary = ref[1]
			var of := Content.target(spec)
			for r: Dictionary in Content.records(kind):
				var from := "%s/%s" % [kind, r.id]
				for id: String in Content.named(r, ref[0]):
					var to := "%s/%s" % [of, id]
					match LINKS.get("%s.%s" % [kind, ref[0]], ""):
						"gives":
							_way(to, spec.via, from, [], spec.via)
						"makes":
							_way(to, spec.via, from)
						"grows":
							if of != "trees" or trees_stand:
								_way(to, "spawns", from)
						"lives":
							_way(from, "lives", to)
						"made":
							_way(to, "recipe", from, [], "", 1)
						"also":
							_way(to, "also", from, [], "", 1)
						"start":
							_way(to, "start", from)
						"camp":
							_way("placed/" + id, "start", from)
						"serves":
							_way("placed/" + id, "serves", "placed/" + r.id)
					if spec.rel in USED_BY or spec.rel == "feeds_on":
						if not uses.has(to):
							uses[to] = []
						uses[to].append([spec.rel, from])


func _way(to: String, via: String, from := "", needs: Array = [], act := "", step := 0) -> void:
	var w := {"to": to, "via": via, "from": from, "needs": needs, "act": act, "step": step}
	ways.append(w)
	if not sources.has(to):
		sources[to] = []
	sources[to].append(w)


## Goes over the ways until nothing new comes and no depth gets less; then the same for
## the eras.
func _reach() -> void:
	_settle(reached, how, true)
	_settle(era, dated, false)


## Gives each key the least of `at` its ways come to, until none gets less, and the way in
## `by`: a depth (`steps`: a recipe's product one more than what it takes) or an era (not
## before the one written on an item).
func _settle(at: Dictionary, by: Dictionary, steps: bool) -> void:
	var changed := true
	while changed:
		changed = false
		var tools := _tools_had(at)
		for w: Dictionary in ways:
			var d := _over(w, tools, at)
			if d < 0:
				continue
			d = d + w.step if steps else maxi(d, _written(w.to))
			if d < at.get(w.to, FAR):
				at[w.to] = d
				by[w.to] = w
				changed = true


## The tools had now, [tool record (Tools.of), its depth or era in `at`] each, bare hands
## first.
func _tools_had(at: Dictionary) -> Array:
	var out := [[Tools.HAND, 0]]
	for key: String in at:
		if key.begins_with("items/") and Tools.is_tool_item(key.substr(6)):
			out.append([Tools.of(key.substr(6)), at[key]])
	return out


## The most of `at` (depths or eras) over what way `w` takes and the earliest tool of
## `tools` (see _tools_had) that does its action; -1 when it gives nothing yet.
func _over(w: Dictionary, tools: Array, at: Dictionary) -> int:
	var d := 0
	for key: String in _takes(w):
		if not at.has(key):
			return -1
		d = maxi(d, at[key])
	if w.act != "":
		var best := -1
		for t: Array in tools:
			if (best < 0 or t[1] < best) and _can(w.act, t[0], w.from):
				best = t[1]
		if best < 0:
			return -1
		d = maxi(d, best)
	return d


## The era written on the record of `key` (an item's `era`), as a rank; 0 for none.
func _written(key: String) -> int:
	return Eras.rank(records[key].era) if key.begins_with("items/") and records.has(key) else 0


## The keys way `w` takes: where it comes from and what it needs besides.
static func _takes(w: Dictionary) -> Array:
	return ([w.from] if w.from != "" else []) + w.needs


## Whether tool `t` does action `act` to the record of key `from`, by the rules of the
## hands (Tools, as WorldActions asks them): a cell is dug by what digs it; its own top is
## cut only by what cuts low (Tools.mows_low), a plant on it by what mows at all, low grass
## (a tuft) again only low; a tree is felled, a bush dug out, seeds, twigs and berries
## gathered by hand.
func _can(act: String, t: Dictionary, from: String) -> bool:
	var r: Dictionary = records.get(from, {})
	match act:
		"dig":
			return Tools.can_dig(t, Mat.index(r.id))
		"mow":
			if from.begins_with("materials/"):
				return r.mow != "" and Tools.mows_low(t)
			return Tools.mows_low(t) if r.get("kind", "") == Plants.KINDS.TUFT else Tools.mows(t)
		"fell":
			return Tools.can_chop(t)
		"gather":
			return Tools.can_gather(t)
		"dig_out":
			return Tools.can_dig_out(t)
		"fish":
			return Tools.can_fish(t)
	return true


# --- Checks -------------------------------------------------------------------------------

func _check() -> void:
	for id: String in Items.IDS:
		var key := "items/" + id
		if reached.has(key):
			continue
		if not sources.has(key):
			_found("no_source", "items: `%s` has no source: no recipe makes it, nothing in the world gives it and the start has none (when a quest or a trade gives it, mark it `source: special`)" % id, [key])
		else:
			_found("never_had", "items: `%s` can never be had: %s" % [id, _why(key)], [key])
	for r: Dictionary in Crafting.RECIPES:
		var key: String = "recipes/" + r.id
		var no_item: Array = r.tools.filter(func(kind: String) -> bool: return not sources.has("tool/" + kind))
		if not no_item.is_empty():
			_found("no_tool_item", "recipes: `%s`.tools: no item is a %s" % [r.id, _list(no_item)], [key])
		elif not reached.has(key):
			_found("never_made", "recipes: `%s` can never be made: %s" % [r.id, _why(key)], [key])
	for kind: String in ["plants", "bushes", "trees"]:
		for r: Dictionary in Content.records(kind):
			var key := "%s/%s" % [kind, r.id]
			if not reached.has(key):
				_found("never_grows", "%s: `%s` never grows in the world: %s" % [kind, r.id,
					_why(key) if sources.has(key) else "no biome grows it and nothing plants or sows it"], [key])
	for r: Dictionary in Content.records("creatures"):
		if not r.likes.is_empty() and not r.likes.any(func(p: String) -> bool: return reached.has("plants/" + p)):
			_found("no_food", "creatures: `%s` feeds on %s, and none of them ever grows" % [r.id, _list(r.likes)],
				["creatures/" + r.id])
	for cycle: Array in cycles():
		_found("cycle", "a blocking cycle, each needing the next: %s" % " → ".join((cycle + [cycle[0]]).map(_name)),
			cycle.map(func(k: String) -> String: return "items/" + k.substr(7) if k.begins_with("placed/") else k))
	_eras()
	_dead_ends()
	_stations()
	_twins()
	_loops()
	for r: Dictionary in Content.records("materials"):
		if not reached.has("materials/" + r.id) and not r.role in ["trunk", "crown"]:
			_found("never_appears", "materials: `%s` never appears in the world: the generator lays it for no role and nothing places it" % r.id,
				["materials/" + r.id])


func _found(check: String, text: String, keys: Array, of: Variant = null) -> void:
	findings.append({"check": check, "text": text, "keys": keys, "of": of})
	if CHECKS[check]:
		errors.append(text)
	else:
		warnings.append(text)


## Why `key` is never reached: each way to it and what it lacks ("made by recipe `x`
## (never come to)", "felled from tree `y`, lacking a tool that can fell it (`z`)"; a
## recipe's: "lacking `a`, `b` set down").
func _why(key: String) -> String:
	var parts := []
	for w: Dictionary in sources.get(key, []):
		var lacks := []
		for k: String in w.needs:
			if not reached.has(k):
				lacks.append(_name(k))
		if w.act != "" and (w.from == "" or reached.has(w.from)):
			var tools := able(w)
			lacks.append("a tool that can %s it (%s)" % [w.act, _list(tools) if not tools.is_empty() else "no item can"])
		var text: String = "" if w.via == "craft" else TOLD.get(w.via, w.via)
		if w.from != "":
			text += " %s%s" % [_name(w.from), "" if reached.has(w.from) else " (never come to)"]
		if not lacks.is_empty():
			text += ("" if text == "" else ", ") + "lacking " + ", ".join(lacks)
		parts.append(text)
	return "; ".join(parts)


## The items that would do the action of way `w` as tools (see _can).
func able(w: Dictionary) -> Array:
	return Array(Items.IDS).filter(func(id: String) -> bool: return Tools.is_tool_item(id) and _can(w.act, Tools.of(id), w.from))


## Whether bare hands do the action of way `w` (or it has none).
func by_hand(w: Dictionary) -> bool:
	return w.act == "" or _can(w.act, Tools.HAND, w.from)


## What `key` comes of at its depth (at its era, `by_era`): the keys the way giving it takes
## (where it comes from; a recipe's materials, what it keeps, station and tools) and the
## earliest tool item had that does its action when bare hands cannot. Empty for what is
## never reached.
func basis(key: String, by_era := false) -> Array:
	var by: Dictionary = dated if by_era else how
	var at: Dictionary = era if by_era else reached
	if not by.has(key):
		return []
	var w: Dictionary = by[key]
	var out := _takes(w)
	if not by_hand(w):
		var best := ""
		for id: String in able(w):
			if at.has("items/" + id) and (best == "" or at["items/" + id] < at["items/" + best]):
				best = id
		if best != "":
			out.append("items/" + best)
	return out


## Key `key` named for a message: "`id`" for an item, "`id` set down", "a `kind` tool",
## else "kind `id`".
static func _name(key: String) -> String:
	var kind := key.get_slice("/", 0)
	var id := key.substr(kind.length() + 1)
	match kind:
		"items":
			return "`%s`" % id
		"placed":
			return "`%s` set down" % id
		"tool":
			return "a `%s` tool" % id
		"recipes":
			return "recipe `%s`" % id
	return "%s `%s`" % [kind.trim_suffix("s"), id]


static func _list(ids: Array) -> String:
	return ", ".join(ids.map(func(id: String) -> String: return "`%s`" % id))


## The eras (section 9 of the spec): an item written into an era earlier than any way to it
## comes in is an error (it needs a thing of a later era, or a tool of one gets it); an item
## that comes deeper than the `depth` its era expects is a warning (a long chain for an
## early era).
func _eras() -> void:
	var tools := _tools_had(era)
	for id: String in Items.IDS:
		var key := "items/" + id
		if not era.has(key):
			continue
		var written: String = records[key].era
		if written != "":
			var best := FAR
			var late := ""
			for w: Dictionary in sources.get(key, []):
				var e := _over(w, tools, era)
				if e >= 0 and e < best:
					best = e
					late = _latest(w)
			if best < FAR and best > Eras.rank(written):
				_found("early_era", "items: `%s`.era: `%s`, but it comes no earlier than `%s`, needing %s" % [id, written,
					Eras.ERAS[best].id, late], [key], best)
		var limit: int = Eras.ERAS[era[key]].depth if era[key] < Eras.ERAS.size() else 0
		if limit > 0 and reached[key] > limit:
			_found("long_chain", "items: `%s` of era `%s` comes at depth %d, deeper than its era's %d: a long chain for an early era" % [
				id, Eras.ERAS[era[key]].id, reached[key], limit], [key], reached[key])


## What of way `w` comes in the latest era, named for a message: of what it takes the latest
## (through a recipe, what the recipe takes), or the earliest tool that does its action when
## that comes later.
func _latest(w: Dictionary) -> String:
	var last := ""
	for key: String in _takes(w):
		if last == "" or era.get(key, -1) > era.get(last, -1):
			last = key
	var tool := ""
	if not by_hand(w):
		for id: String in able(w):
			if era.has("items/" + id) and (tool == "" or era["items/" + id] < era[tool]):
				tool = "items/" + id
	if tool != "" and (last == "" or era[tool] > era.get(last, -1)):
		return _name(tool)
	if last.begins_with("recipes/") and dated.has(last):
		return _latest(dated[last])
	return _name(last) if last != "" else "nothing"


## The cycles that keep things from ever being reached: the strongly connected groups of
## what is never reached, linked from each thing to what its ways lack (and to the tools
## that could do their action), each as one cycle through its first member. Mending,
## recycling and ways back and forth between things reached block nothing.
func cycles() -> Array:
	var lacks := {}
	for key: String in sources:
		if reached.has(key):
			continue
		var out := {}
		for w: Dictionary in sources[key]:
			for k: String in _takes(w):
				if not reached.has(k):
					out[k] = true
			if w.act != "":
				for id: String in able(w):
					if not reached.has("items/" + id):
						out["items/" + id] = true
		lacks[key] = out.keys()
	var found := []
	for group: Array in _strong(lacks):
		if group.size() > 1 or lacks.get(group[0], []).has(group[0]):
			found.append(_cycle_through(group, lacks))
	return found


## The strongly connected groups of `edges` (key -> keys), by Tarjan's way, members in
## the order the keys come.
static func _strong(edges: Dictionary) -> Array:
	var index := {}
	var low := {}
	var on := {}
	var stack := []
	var groups := []
	for root: String in edges:
		if index.has(root):
			continue
		# Without recursion: each frame is [key, the next of its edges to follow].
		var frames := [[root, 0]]
		index[root] = index.size()
		low[root] = index[root]
		stack.append(root)
		on[root] = true
		while not frames.is_empty():
			var top: Array = frames.back()
			var key: String = top[0]
			var next: Array = edges.get(key, [])
			if top[1] < next.size():
				var to: String = next[top[1]]
				top[1] += 1
				if not index.has(to):
					index[to] = index.size()
					low[to] = index[to]
					stack.append(to)
					on[to] = true
					frames.append([to, 0])
				elif on.get(to, false):
					low[key] = mini(low[key], index[to])
				continue
			frames.pop_back()
			if not frames.is_empty():
				var up: String = frames.back()[0]
				low[up] = mini(low[up], low[key])
			if low[key] == index[key]:
				var group := []
				while true:
					var k: String = stack.pop_back()
					on[k] = false
					group.push_front(k)
					if k == key:
						break
				groups.append(group)
	return groups


## A cycle through the first member of strongly connected `group`, following `edges`
## (a search that steps back from a member with no way on).
static func _cycle_through(group: Array, edges: Dictionary) -> Array:
	var start: String = group[0]
	var path := [start]
	var seen := {start: true}
	while not path.is_empty():
		var key: String = path.back()
		var next := ""
		for to: String in edges.get(key, []):
			if to == start:
				return path
			if next == "" and group.has(to) and not seen.has(to):
				next = to
		if next == "":
			path.pop_back()
		else:
			seen[next] = true
			path.append(next)
	return group


# --- Warnings -----------------------------------------------------------------------------

## Items had that nothing needs and that are for nothing else either.
func _dead_ends() -> void:
	for id: String in Items.IDS:
		if reached.has("items/" + id) and not uses.has("items/" + id) and not _has_function(Items.get_item(id)):
			_found("dead_end", "items: `%s` is a dead end: no recipe needs it, nothing is mended with it, and it is no tool, station, block, seed, food, cure, fuel, light or thing worn" % id,
				["items/" + id])


static func _has_function(item: Dictionary) -> bool:
	for f: String in FUNCTIONS:
		var v: Variant = item.get(f)
		if v is String and v != "" and v != "none" or v is bool and v or (v is float or v is int) and v > 0:
			return true
	return false


## Stations no recipe or only one is made at, theirs or those of the stations they serve
## (a thing that stores makes nothing).
func _stations() -> void:
	for id: String in Items.IDS:
		if not Items.is_station(id):
			continue
		var at_it: Array = [id] + Items.get_item(id).serves
		var at := Array(Crafting.RECIPES).filter(func(r: Dictionary) -> bool: return r.at in at_it).map(func(r: Dictionary) -> String: return r.id)
		if at.size() < 2:
			_found("station", "items: `%s` is the station of %s" % [id, "no recipe" if at.is_empty() else "one recipe only, %s" % _list(at)],
				["items/" + id], at)


## Items alike in everything they do (ALIKE) and needed by the same records.
func _twins() -> void:
	var by := {}
	for id: String in Items.IDS:
		var item := Items.get_item(id)
		if not uses.has("items/" + id) and not _has_function(item):
			continue
		var sign := []
		for f: String in ALIKE:
			sign.append(item.get(f))
		sign.append(uses.get("items/" + id, []).map(func(u: Array) -> String: return "%s %s" % u))
		var k := str(sign)
		by[k] = by.get(k, []) + [id]
	for k: String in by:
		if by[k].size() > 1:
			_found("twins", "items: %s are alike in all they do and in what needs them" % _list(by[k]),
				by[k].map(func(id: String) -> String: return "items/" + id))


## Loops of recipes that give back more of an item than went in (an endless source): the
## best yield of a path of recipes from each item to each other, by how many come out of
## one going in (a by-product by its share), and an item whose yield back to itself is
## above 1.
func _loops() -> void:
	var ids := []
	for r: Dictionary in Crafting.RECIPES:
		for id: String in r.needs.keys() + _products(r).keys():
			if not ids.has(id):
				ids.append(id)
	var n := ids.size()
	var gain := []
	gain.resize(n * n)
	gain.fill(0.0)
	for r: Dictionary in Crafting.RECIPES:
		var out := _products(r)
		for made: String in out:
			var j := ids.find(made)
			for id: String in r.needs:
				var i := ids.find(id)
				gain[i * n + j] = maxf(gain[i * n + j], out[made] / r.needs[id])
	# Not through a loop at the item gone through (m), which would multiply its own yield.
	for m in n:
		for i in n:
			if i == m or gain[i * n + m] == 0.0:
				continue
			for j in n:
				if j != m:
					gain[i * n + j] = maxf(gain[i * n + j], gain[i * n + m] * gain[m * n + j])
	for i in n:
		if gain[i * n + i] > 1.0001:
			var yield_back := minf(gain[i * n + i], 99.0)
			_found("loop", "recipes: a loop of recipes gives back ×%.2f of `%s`: an endless source of it" % [yield_back, ids[i]],
				["items/" + ids[i]], yield_back)


## What recipe `r` gives a job on the whole: item id -> how many, a by-product by its
## chance.
static func _products(r: Dictionary) -> Dictionary:
	var out := {r.makes: float(r.count)}
	for e: Dictionary in r.also:
		out[e.item] = out.get(e.item, 0.0) + e.count * e.chance
	return out
