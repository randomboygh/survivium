extends RefCounted
## The orders the content of a save was numbered in (audit DATA-1, DATA-2). A chunk's
## cells hold materials, its trees species, its bushes types and its columns biomes by
## their number in the load order of the mods, which changes when a mod is added,
## removed or updated. So world.json keeps every order its chunks were written in
## (`numberings`: a list of {kind: [ids]}), and each chunk file names the one it was
## written in (`order`, an index in the list; a chunk saved before has none and is of
## the first). A chunk read in another order than the loaded one is translated as it is
## read (translate); one written is of the loaded order, added to the list when it is
## new. Nothing is rewritten in the background, and an unvisited chunk keeps its meaning
## however many times the world is saved.

const Content := preload("res://src/shared/content/content.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const Biomes := preload("res://src/shared/content/biomes.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")

## The numbered kinds, by their name in a numbering and in Content.
const KINDS := ["materials", "trees", "bushes", "biomes"]
## A column of no biome (WorldData.NO_BIOME).
const NO_BIOME := 255


## The order the loaded content is numbered in: the ids of each kind.
static func current() -> Dictionary:
	var trees: Array = []
	for s: Dictionary in Trees.SPECIES:
		trees.append(s.id)
	var bushes: Array = []
	for b: Dictionary in Bushes.TYPES:
		bushes.append(b.id)
	return {"materials": Array(Mat.IDS), "trees": trees, "bushes": bushes, "biomes": Array(Biomes.IDS)}


## The orders the chunks of the world saved as `meta` (its world.json) are numbered in;
## empty for a new world. A save from before the list has one: its `materials`
## (WorldStore.materials_of) and no list of the other kinds (read as they are loaded).
static func of_world(meta: Dictionary) -> Array:
	var out: Array = []
	var saved: Variant = meta.get("numberings")
	if saved is Array:
		for n: Variant in saved:
			out.append(_clean(n))
		if not out.is_empty():
			return out
	if meta.is_empty():
		return out
	var materials := WorldStore.materials_of(meta)
	out.append({"materials": Array(materials)} if not materials.is_empty() else {})
	return out


## The index of the loaded order in `list`, added at its end when it is not its last.
static func add_current(list: Array) -> int:
	var now := current()
	if not list.is_empty() and _same(list[-1], now):
		return list.size() - 1
	list.append(now)
	return list.size() - 1


## How to read a chunk numbered by `numbering` in the loaded order: for each kind the
## saved number -> the loaded one (an empty array when the orders agree or the
## numbering has no list of the kind). An id no longer loaded becomes stone, the first
## tree species or bush type, or no biome.
static func maps(numbering: Dictionary) -> Dictionary:
	var now := current()
	var out := {}
	for kind: String in KINDS:
		var ids: Variant = numbering.get(kind)
		if not ids is Array or ids == now[kind]:
			out[kind] = PackedInt32Array()
			continue
		var map := PackedInt32Array()
		for id: String in ids:
			map.append(_index(kind, id))
		out[kind] = map
	return out


## Puts chunk record `d` (WorldGen.pack) numbered by `maps` (see maps) into the
## loaded order, in place.
static func translate(d: Dictionary, m: Dictionary) -> void:
	var mats: PackedInt32Array = m.get("materials", PackedInt32Array())
	if not mats.is_empty() and d.get("cells") is PackedByteArray:
		var cells: PackedByteArray = d.cells
		var n := mats.size()
		for i in cells.size():
			var c := cells[i]
			cells[i] = mats[c] if c < n else Mat.STONE
		d.cells = cells
	var biomes: PackedInt32Array = m.get("biomes", PackedInt32Array())
	if not biomes.is_empty() and d.get("biome") is PackedByteArray:
		var cols: PackedByteArray = d.biome
		for i in cols.size():
			var b := cols[i]
			cols[i] = NO_BIOME if b == NO_BIOME else (biomes[b] if b < biomes.size() else NO_BIOME)
		d.biome = cols
	var trees: PackedInt32Array = m.get("trees", PackedInt32Array())
	if not trees.is_empty():
		var kept: Array = []
		for t: Variant in d.get("trees", []):
			if t is Array and t.size() == 2 and (t[1] is int or t[1] is float):
				var s := _of(trees, int(t[1]))
				if s >= 0:
					kept.append([t[0], s])
		d.trees = kept
		var planted: Array = []
		for t: Variant in d.get("planted", []):
			if t is Array and t.size() >= 4 and (t[2] is int or t[2] is float):
				var s := _of(trees, int(t[2]))
				if s >= 0:
					var copy: Array = t.duplicate()
					copy[2] = s
					planted.append(copy)
		d.planted = planted
	var bushes: PackedInt32Array = m.get("bushes", PackedInt32Array())
	var lists: Variant = d.get("bushes")
	if not bushes.is_empty() and lists is Dictionary and lists.get("bushes") is Array:
		var kept: Array = []
		for b: Variant in lists.bushes:
			if b is Array and b.size() == 2 and (b[1] is int or b[1] is float):
				var t := _of(bushes, int(b[1]))
				if t >= 0:
					kept.append([b[0], t])
		lists.bushes = kept


## True when `maps` (see maps) changes nothing.
static func same(m: Dictionary) -> bool:
	for kind: String in m:
		if not m[kind].is_empty():
			return false
	return true


## Saved number `i` of a kind mapped by `map` in the loaded order, -1 for none.
static func _of(map: PackedInt32Array, i: int) -> int:
	return map[i] if i >= 0 and i < map.size() else -1


## The loaded number of `id` of `kind`, read through its renames; a stand-in when it is
## not loaded (see maps).
static func _index(kind: String, id: String) -> int:
	match kind:
		"materials":
			var m := Mat.index(Content.canon("materials", Mat.RENAMED.get(id, id)))
			return m if m >= 0 else Mat.STONE
		"trees":
			var t := Trees.index(Content.canon("trees", id))
			return t if t >= 0 else (0 if not Trees.SPECIES.is_empty() else -1)
		"bushes":
			var b := Bushes.index(Content.canon("bushes", id))
			return b if b >= 0 else (0 if not Bushes.TYPES.is_empty() else -1)
		"biomes":
			var i := Biomes.index(Content.canon("biomes", id))
			return i if i >= 0 else NO_BIOME
	return -1


## A numbering as read from JSON: each kind a list of ids; anything else left out.
static func _clean(n: Variant) -> Dictionary:
	var out := {}
	if not n is Dictionary:
		return out
	for kind: String in KINDS:
		var ids: Variant = n.get(kind)
		if ids is Array:
			var list: Array = []
			for id: Variant in ids:
				list.append(str(id))
			out[kind] = list
	return out


static func _same(a: Dictionary, b: Dictionary) -> bool:
	for kind: String in KINDS:
		if a.get(kind) != b.get(kind):
			return false
	return true
