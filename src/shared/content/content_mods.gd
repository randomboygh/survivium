extends "res://src/shared/content/content_fields.gd"
## The mods' data, part three (content.gd): the mods and bundles on disk, read once
## (universe: their manifests, records, what each owns, needs and patches), and which
## of them a set of bundles loads, in what order (resolve, closure, deps).

## The bundles to load, as asked for; `loaded` has the order they were loaded in after
## their dependencies, without the ones left out: those are in `dropped` with the bundle
## they needed.
static var BUNDLES: Array = _all_on_disk()
static var loaded: Array = []
static var dropped := {}
## Everything under content/, read once per run (refresh reads it again): bundle ->
## {"mod", "info" (its manifest), "records" (kind -> raw records), "owns", "hard", "soft",
## "patches", "replaces" (sets of "kind/id"), "requires", "wants" (bundle ids)}, mod -> its mod.yaml,
## the bundles in their order (core first, then by name), who owns which record, and
## the problems found reading each bundle.
static var _universe := {}
static var _mods := {}
static var _order: Array = []
static var _owners := {}
static var _scan_problems := {}
## How long the last reading of everything under content/ took (_scan: the files read and
## their records parsed), and the last load of a set after it (load_all), in ms: what the
## mods' data costs a start of the game, shown in the playtest report.
static var read_ms := 0.0
static var load_ms := 0.0


## Every mod under `content/`: the folders with a mod.yaml, core first, then by name.
## Folders starting with `_` are the tests' and are left out. Read from the scan
## (universe); refresh sees new folders.
static func available() -> Array:
	universe()
	return _mods.keys().filter(func(m: String) -> bool: return not m.begins_with("_"))


static func _folders(hidden: bool) -> Array:
	var out := []
	for name in DirAccess.get_directories_at(ROOT):
		if (name.begins_with("_") and not hidden) or not FileAccess.file_exists("%s/%s/mod.yaml" % [ROOT, name]):
			continue
		out.append(name)
	out.sort()
	if "core" in out:
		out.erase("core")
		out.push_front("core")
	return out


## The bundles of mod `mod`: its folders with a bundle.yaml by name, or the mod itself
## when it has none. Read from the scan (universe).
static func bundles_of(mod: String) -> Array:
	universe()
	var out := _order.filter(func(b: String) -> bool: return mod_of(b) == mod)
	return out if not out.is_empty() else [mod]


## bundles_of as the folders on disk say now, for the scan.
static func _bundles_on_disk(mod: String) -> Array:
	var out := []
	for name in DirAccess.get_directories_at("%s/%s" % [ROOT, mod]):
		if FileAccess.file_exists("%s/%s/%s/bundle.yaml" % [ROOT, mod, name]):
			out.append("%s/%s" % [mod, name])
	out.sort()
	return out if not out.is_empty() else [mod]


## Every bundle of every mod, in load order before dependencies (from the scan).
static func all_bundles() -> Array:
	universe()
	return _order.filter(func(b: String) -> bool: return not b.begins_with("_"))


## all_bundles as the folders on disk say, without the scan: BUNDLES' first value, set
## before the scan's own static vars exist.
static func _all_on_disk() -> Array:
	var out := []
	for mod in _folders(false):
		out.append_array(_bundles_on_disk(mod))
	return out


## The mod bundle `bundle` belongs to.
static func mod_of(bundle: String) -> String:
	return bundle.get_slice("/", 0)


## The mod.yaml of `mod` as a Dictionary with its fields checked, empty when it cannot
## be read.
static func info(mod: String) -> Dictionary:
	if universe().is_empty() or not _mods.has(mod):
		return _manifest("%s/%s/mod.yaml" % [ROOT, mod], MOD_SCHEMA, mod, "%s/mod.yaml" % mod)
	return _mods[mod]


## The bundle.yaml of `bundle` (title, requires, wants) with its `mod`; a mod of one
## bundle gives its mod.yaml.
static func bundle_info(bundle: String) -> Dictionary:
	if universe().has(bundle):
		return _universe[bundle].info
	return {}


static func _manifest(path: String, schema: Dictionary, mod: String, file: String) -> Dictionary:
	var d: Variant = _read(path)
	if not d is Dictionary:
		if d != null:
			problems.append("%s: expected a mapping" % file)
		return {}
	if schema == MOD_SCHEMA and d.get("id") != mod:
		problems.append("%s: id must be `%s`" % [file, mod])
	var out: Dictionary = d.duplicate()
	_check_fields(out, schema, mod, file, "mod" if schema == MOD_SCHEMA else "bundle")
	out.erase("id")
	return out


## Everything under content/ (see _universe), read on the first call.
static func universe() -> Dictionary:
	if _universe.is_empty():
		_scan()
	return _universe


## Reads every manifest and data file under content/ once: what each bundle owns,
## references and patches, for `resolve` and the load.
static func _scan() -> void:
	var t := Time.get_ticks_usec()
	cached_files = 0
	parsed_files = 0
	var kept := problems
	_universe = {}
	_mods = {}
	_order = []
	_owners = {}
	_scan_problems = {}
	for mod in _folders(true):
		problems = []
		var mod_info := _manifest("%s/%s/mod.yaml" % [ROOT, mod], MOD_SCHEMA, mod, "%s/mod.yaml" % mod)
		var mod_problems := problems
		_mods[mod] = mod_info
		var bundles := _bundles_on_disk(mod)
		if bundles != [mod] and DirAccess.dir_exists_absolute("%s/%s/data" % [ROOT, mod]):
			mod_problems.append("%s/data: a mod with bundles keeps its records in them" % mod)
		for b in bundles:
			problems = mod_problems.duplicate() if b == bundles[0] else []
			var bi := mod_info.duplicate() if b == mod else _manifest("%s/%s/bundle.yaml" % [ROOT, b], BUNDLE_SCHEMA, mod, "%s/bundle.yaml" % b)
			if mod_info.is_empty():
				problems.append("%s/mod.yaml: cannot read the mod" % mod)
			bi["mod"] = mod
			var u := {"mod": mod, "info": bi, "records": {}, "owns": {}, "hard": {}, "soft": {}, "patches": {}, "replaces": {},
				"requires": _named(bi.get("requires", []), mod), "wants": _named(bi.get("wants", []), mod)}
			# One listing of the bundle's data/ instead of asking for a file of every kind.
			var present := DirAccess.get_files_at("%s/%s/data" % [ROOT, b])
			for kind in SCHEMAS:
				if not ("%s.yaml" % kind) in present:
					u.records[kind] = []
					continue
				var list := _read_records(b, mod, kind)
				u.records[kind] = list
				for r in list:
					var key := "%s/%s" % [kind, r.id]
					if r.get("patch") == true:
						u.patches[key] = true
					else:
						if r.get("replaces") == true:
							u.replaces[key] = true
						u.owns[key] = true
						if not _owners.has(key):
							_owners[key] = []
						_owners[key].append(b)
					for ref in _refs_of(r, kind, mod):
						(u.soft if ref[2] else u.hard)["%s/%s" % [ref[0], ref[1]]] = true
			_universe[b] = u
			_order.append(b)
			_scan_problems[b] = problems
	problems = kept
	read_ms = (Time.get_ticks_usec() - t) / 1000.0


## Bundle ids out of `names` (bundle or mod ids, a bare name a bundle of `mod`).
static func _named(names: Array, mod: String) -> Array:
	var out := []
	for n in names:
		if not n is String:
			continue
		out.append("%s/%s" % [mod, n] if not "/" in n and FileAccess.file_exists("%s/%s/%s/bundle.yaml" % [ROOT, mod, n]) else n)
	return out


## The records of `bundle/data/<kind>.yaml` as written, ids qualified, duplicates and
## malformed ones left out with a problem.
static func _read_records(bundle: String, mod: String, kind: String) -> Array:
	var out := []
	var path := "%s/%s/data/%s.yaml" % [ROOT, bundle, kind]
	if not FileAccess.file_exists(path):
		return out
	var file := "%s/data/%s.yaml" % [bundle, kind]
	var list: Variant = _read(path)
	if list == null:
		return out
	if not list is Array:
		problems.append("%s: expected a list of records" % file)
		return out
	var seen := {}
	for i in list.size():
		var r: Variant = list[i]
		if not r is Dictionary or not r.get("id") is String or r.id == "":
			problems.append("%s: record %d: expected a mapping with an `id`" % [file, i + 1])
			continue
		var id: String = qualify(r.id, mod)
		if not _valid_id(id):
			problems.append("%s: `%s`: id must be `mod:name`, lowercase letters, digits and `_`" % [file, r.id])
			continue
		if seen.has(id):
			problems.append("%s: `%s`: duplicate id" % [file, id])
			continue
		seen[id] = true
		var rec: Dictionary = r.duplicate()
		rec.id = id
		out.append(rec)
	return out


## The references of raw record `r` of `kind`: [kind, qualified id, soft] each.
static func _refs_of(r: Dictionary, kind: String, mod: String) -> Array:
	var out := []
	for ref: Array in refs(kind):
		var field: String = ref[0].get_slice(".", 0)
		for key in [field, field + "+"]:
			if r.has(key):
				for id: String in named({field: r[key]}, ref[0]):
					out.append([target(ref[1]), qualify(id, mod), ref[1].get("soft", false)])
	return out


## Raw record `r` of `kind` with what its references name qualified by `mod`, the mod of
## the file it is written in: a patch names records as its own mod does, not as the one
## it patches.
static func _qualified(r: Dictionary, kind: String, mod: String) -> Dictionary:
	var out := r.duplicate(true)
	for ref: Array in refs(kind):
		var field: String = ref[0].get_slice(".", 0)
		var sub: String = ref[0].get_slice(".", 1) if "." in ref[0] else ""
		for key in [field, field + "+"]:
			if out.has(key):
				out[key] = _qualify_all(out[key], sub, mod)
	return out


## Value `v` of a reference field with its ids qualified by `mod`; `sub` the field of its
## entries that names one, "" for the value itself.
static func _qualify_all(v: Variant, sub: String, mod: String) -> Variant:
	var q := func(id: Variant) -> Variant: return qualify(id, mod) if id is String and id != "" else id
	if sub != "":
		for e: Variant in (v if v is Array else []):
			if e is Dictionary and e.has(sub):
				e[sub] = q.call(e[sub])
		return v
	if v is Array:
		return v.map(q)
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[q.call(k)] = v[k]
		return out
	return q.call(v)


## Which of `set` load, in what order, and which are left out and why: {"order",
## "dropped": bundle -> the bundle it needs}. A bundle is dropped when a hard field of
## its records names a record no bundle of the set has (while some bundle under content/
## does: a record nobody has is a mistake reported by the load), or when something it
## `requires` is not in the set; what depended on it goes with it. `report` adds the
## problems found (an unknown requirement, a circle) to `problems`.
static func resolve(set: Array, report := false) -> Dictionary:
	universe()
	var kept := {}
	for b in set:
		if _universe.has(b):
			kept[b] = true
	var out_dropped := {}
	var changed := true
	while changed:
		changed = false
		for b in kept.keys():
			var need := _missing(b, kept)
			if need != "":
				kept.erase(b)
				out_dropped[b] = need
				changed = true
				if report and not _universe.has(need):
					problems.append("%s: requires `%s`, which is not loaded" % [b, need])
	# Kahn's order: each step places the ready bundle (all it depends on placed) that
	# comes first in _order, so the order is the one of the scan where nothing forces
	# another. The dependencies are found once per bundle.
	var order := []
	var placed := {}
	var waits := {}
	var after := {}
	var ready: Array[int] = []
	for i in _order.size():
		var b: String = _order[i]
		if not kept.has(b):
			continue
		var deps := _deps(b, kept)
		waits[b] = deps.size()
		for d in deps:
			if not after.has(d):
				after[d] = []
			after[d].append(i)
		if deps.is_empty():
			ready.append(i)
	while not ready.is_empty():
		var i: int = ready.pop_front()
		var b: String = _order[i]
		order.append(b)
		placed[b] = true
		for j: int in after.get(b, []):
			var next: String = _order[j]
			waits[next] -= 1
			if waits[next] == 0:
				ready.insert(ready.bsearch(j), j)
	if placed.size() < kept.size():
		var rest := _order.filter(func(b: String) -> bool: return kept.has(b) and not placed.has(b))
		if report:
			problems.append("%s: bundles require each other in a circle" % ", ".join(rest))
		order.append_array(rest)
	return {"order": order, "dropped": out_dropped}


## What `b` needs that `kept` lacks: the first owner of a hard reference's record when
## none of its owners is kept, a requirement that is not kept, or "".
static func _missing(b: String, kept: Dictionary) -> String:
	var u: Dictionary = _universe[b]
	for key in u.hard:
		var owners: Array = _owners.get(key, [])
		if owners.is_empty() or u.owns.has(key):
			continue
		if not owners.any(func(o: String) -> bool: return kept.has(o)):
			return owners[0]
	for need in u.requires:
		for nb in _expand_need(need):
			if not kept.has(nb):
				return nb
	return ""


## A requirement as bundles: a bundle id itself, a mod id all its bundles.
static func _expand_need(need: String) -> Array:
	if _universe.has(need):
		return [need]
	if _mods.has(need):
		return _order.filter(func(b: String) -> bool: return mod_of(b) == need)
	return [need]


## The bundles of `kept` that load before `b`: the owners of what it references, patches
## or replaces, and what it requires or wants.
static func _deps(b: String, kept: Dictionary) -> Array:
	var u: Dictionary = _universe[b]
	var out := {}
	# A soft reference orders nothing: it is looked up once everything is loaded.
	for group in [u.hard, u.patches]:
		for key in group:
			for o in _owners.get(key, []):
				if o != b and kept.has(o):
					out[o] = true
	# A replacement loads after the record it replaces (not after other replacements).
	for key in u.replaces:
		for o in _owners.get(key, []):
			if o != b and kept.has(o) and not _universe[o].replaces.has(key):
				out[o] = true
	for need in u.requires + u.wants:
		for nb in _expand_need(need):
			if nb != b and kept.has(nb):
				out[nb] = true
	return out.keys()


## The bundles `bundle` cannot do without, itself last, in load order: the base game,
## the owners of its hard references and its requirements, and theirs. Out of `all`
## (every bundle unless given); the first owner when several have a record.
static func closure(bundle: String, all: Array = []) -> Array:
	universe()
	if all.is_empty():
		all = _order
	var set := {}
	var stack := ["core", bundle]
	while not stack.is_empty():
		var b: String = stack.pop_back()
		if set.has(b) or not _universe.has(b) or not b in all:
			continue
		set[b] = true
		var u: Dictionary = _universe[b]
		for key in u.hard:
			var owners: Array = _owners.get(key, []).filter(func(o: String) -> bool: return o in all)
			if not owners.is_empty() and not u.owns.has(key):
				stack.append(owners[0])
		for need in u.requires:
			stack.append_array(_expand_need(need))
	return resolve(set.keys()).order


## The bundles loaded that `bundle` loads after (see _deps).
static func deps(bundle: String) -> Array:
	var kept := {}
	for b in loaded:
		kept[b] = true
	return _deps(bundle, kept) if _universe.has(bundle) else []
