extends "res://src/shared/content/content_mods.gd"
## Mods, their bundles and their data files. A mod is a folder under `content/` with
## `mod.yaml`; what it adds comes in bundles, a folder per thing (`content/animals/wolf/`
## with `bundle.yaml`), each with its own `data/<kind>.yaml` (materials, items, creatures,
## trees, bushes, recipes, plants, sounds, starts, eras, skills) and its pictures, models, textures and sounds
## beside them (`sprites/`, `models/`, `icons/`, `textures/`, `sounds/`: a sound's files are
## `<name>.wav`, or `<name>_1.wav` ... for its variants; what a bundle lacks is looked for in
## the mod's `common/`, see `asset`). A mod without bundle folders is one bundle with its
## files at its root. A bundle's id is `mod/bundle` (`animals/wolf`), or the mod's id for a
## mod of one bundle (`plants`). Records are namespaced by the mod whatever bundle holds
## them: `wolf` in `animals/wolf` is `animals:wolf`, and a reference without a namespace
## means the mod of the file it is written in (a patch of another mod's record too). A
## later bundle may replace a record of an earlier one by id when
## it says so (`replaces: true`; the same id again without it is a problem), or patch it:
## a record with `patch: true` changes only the fields it gives, and a key with a `+` at
## the end (`diet+: [plants]`, `needs+: {materials:cord: 1}`) adds to a list or an
## amounts field instead of replacing it. Every record may have the COMMON fields
## (`description`, `tags`, `provisional`) besides those of its kind.
##
## What a bundle depends on is read from its records: a reference to a record of another
## bundle (`needs: {materials:clay: 2}`) makes that bundle load first, and when the field
## is hard (the schema's default) and no bundle of the set has the record, the bundle is
## left out with the one that has it as the reason (`dropped`), so a world is made only
## of things that work. A field marked `soft` in the schema (`likes`, `seed`, `fruit`,
## `gives`, `era`, a creature's `biomes` and more: see SCHEMAS) only orders the load: the reference is
## dropped from the record when its target is not loaded, a problem only when `strict` (the
## validator checking the full set). A patch of another bundle's record loads after it and
## is skipped when it is not loaded. Roles (`land`, `prop`, `kind`, `roost`) bind nothing.
## `requires` (hard) and `wants` (order only) in mod.yaml or bundle.yaml add what the
## records do not show, as bundle or mod ids. BUNDLES is the set a world plays with (the
## world remembers it, see WorldStore); `all_bundles()` finds every bundle under
## `content/`. Switch sets through mods.gd, which also refreshes the registries.
##
## Records are checked against SCHEMAS on load: wrong types, values out of range,
## unknown fields, missing fields without a default and broken references are
## reported with the file and the id. The game loads what it can and reports the
## problems; `tools/validate.gd` runs the same checks in CI and fails on any. Names that
## break the naming rules (docs/specifications/BUNDLE_SYSTEM.md, section 3) are only
## `warnings`. Every reference field names its link (`rel`, one of RELATIONS: what the
## record is to the one it names) and, where an action makes it, which (`via`, ACTIONS),
## for the content graph.
## The registries (materials.gd, items.gd, ai_rules.gd, trees.gd, bushes.gd, biomes.gd,
## crafting.gd, plants.gd, starts.gd, eras.gd, skills.gd, tools.gd) read their kind with
## `records(kind)` when their class loads, so the rest of the code keeps using
## `Mat.GRASS`, `Trees.SPECIES` or `AiRules.SPECIES` as before.

## Names the last load found against the naming rules (see _check_names): reported by
## the validator, never failing it.
static var warnings: PackedStringArray = []
## Where each loaded record comes from, by "kind/id": {"bundle" that defined it first,
## "replaced" (the bundles whose `replaces` took its place, in order), "patched" (the
## bundles that patched it)}.
static var origins := {}
## kind -> an id a record had before (its `was`) -> its id now.
static var _renamed := {}
## kind -> Array of records in load order; a record's `mod` names its mod (its
## namespace) and `bundle` the bundle its files are in.
static var _kinds := {}
## kind -> id -> the record as written (before conversion), for patches to build on.
static var _raw := {}
static var _loaded := false
## Counts the loads (load_all): the registries (Mods) know from it whether they hold the
## arrays of the last one.
static var generation := 0


## Records of `kind` from every bundle, checked and with defaults filled in.
static func records(kind: String) -> Array:
	if not _loaded:
		load_all()
	return _kinds.get(kind, [])


## How many records the set loaded has, of every kind.
static func record_count() -> int:
	var n := 0
	for kind in SCHEMAS:
		n += records(kind).size()
	return n


## The record with `id` of `kind`, or an empty Dictionary.
static func find(kind: String, id: String) -> Dictionary:
	var list := records(kind)
	var at: int = _at.get(kind, {}).get(id, -1)
	return list[at] if at >= 0 else {}


## Id `id` of `kind` as it is called now: the id of the record whose `was` names it, any
## other as it is. The registries' own tables of older renames (Items.RENAMED...) go first.
static func canon(kind: String, id: String) -> String:
	if not _loaded:
		load_all()
	return _renamed.get(kind, {}).get(id, id)


## Where the record `id` of `kind` comes from (see origins), empty when it is not loaded.
static func origin(kind: String, id: String) -> Dictionary:
	if not _loaded:
		load_all()
	return origins.get("%s/%s" % [kind, id], {})


## Where record `rec` keeps file `rel` (`sprites/creatures/wolf.png`): in its bundle,
## else in its mod's `common/`; the bundle's path when neither has it.
static func asset(rec: Dictionary, rel: String) -> String:
	var own := "%s/%s/%s" % [ROOT, rec.get("bundle", rec.get("mod", "core")), rel]
	if ResourceLoader.exists(own) or FileAccess.file_exists(own):
		return own
	var common := "%s/%s/common/%s" % [ROOT, rec.get("mod", "core"), rel]
	if ResourceLoader.exists(common) or FileAccess.file_exists(common):
		return common
	return own


## The files of sound record `rec` (see the `sounds` kind): one, or one per variant.
static func sound_files(rec: Dictionary) -> PackedStringArray:
	var name: String = rec.id.get_slice(":", 1)
	if rec.variants == 1:
		return [asset(rec, "sounds/%s.wav" % name)]
	var out: PackedStringArray = []
	for i in rec.variants:
		out.append(asset(rec, "sounds/%s_%d.wav" % [name, i + 1]))
	return out


## Reads everything under content/ again and loads the set; the registries call their
## own `refresh` after this.
static func refresh() -> void:
	_universe = {}
	_loaded = false
	load_all()


## Loads BUNDLES: what they need in order, the rest left out (see resolve).
static func load_all() -> void:
	_loaded = true
	generation += 1
	problems = []
	warnings = []
	origins = {}
	_renamed = {}
	_kinds = {}
	_at = {}
	_raw = {}
	dropped = {}
	for kind in SCHEMAS:
		_kinds[kind] = []
		_at[kind] = {}
		_raw[kind] = {}
	universe()
	var t := Time.get_ticks_usec()
	var set := []
	for b in BUNDLES:
		if _universe.has(b):
			set.append(b)
			problems.append_array(_scan_problems.get(b, []))
		else:
			problems.append("%s: no such bundle" % b)
	var res := resolve(set, true)
	dropped = res.dropped
	loaded = res.order
	for b in loaded:
		_load_bundle(b)
	_check_refs()
	_check_renames()
	_check_names()
	for p in problems:
		push_error("content: " + p)
	load_ms = (Time.get_ticks_usec() - t) / 1000.0


static func _load_bundle(bundle: String) -> void:
	var u: Dictionary = _universe[bundle]
	for kind in SCHEMAS:
		var file := "%s/data/%s.yaml" % [bundle, kind]
		for r in u.records[kind]:
			var rec: Dictionary = r.duplicate()
			var id: String = rec.id
			var raw: Dictionary = _raw[kind]
			for own in ["mod", "bundle"]:
				# Where a record comes from is the folder it lies in, never a field it writes.
				if rec.has(own):
					problems.append("%s: %s.%s: unknown field" % [file, id, own])
					rec.erase(own)
			if rec.get("patch") == true:
				rec.erase("patch")
				if not raw.has(id):
					# The record's bundle is not in the set: the patch waits for it.
					if _owners.get("%s/%s" % [kind, id], []).is_empty():
						problems.append("%s: %s: patches a record no mod has" % [file, id])
					continue
				rec = _patched(raw[id], _qualified(rec, kind, u.mod), file, id, kind)
				origins["%s/%s" % [kind, id]].patched.append(bundle)
			else:
				var replaces: bool = rec.get("replaces") == true
				rec.erase("replaces")
				if raw.has(id) and not replaces:
					# The first record stays: another bundle's is never swapped silently.
					problems.append("%s: %s: %s has it already; a record of the same id replaces it only with `replaces: true`"
						% [file, id, raw[id].bundle])
					continue
				elif replaces and not raw.has(id) and _owners.get("%s/%s" % [kind, id], []).size() < 2:
					problems.append("%s: %s: replaces a record no mod has" % [file, id])
				rec.mod = u.mod
				rec.bundle = bundle
				var key := "%s/%s" % [kind, id]
				if origins.has(key):
					origins[key].replaced.append(bundle)
				else:
					origins[key] = {"bundle": bundle, "replaced": [], "patched": []}
			raw[id] = rec.duplicate()
			if not rec.get("title") is String or rec.title == "":
				problems.append("%s: %s.title: expected a string" % [file, id])
				rec.title = id
			_check_fields(rec, schema(kind), rec.mod, file, id)
			for f in rec.provisional:
				if not SCHEMAS[kind].has(f):
					problems.append("%s: %s.provisional: `%s` is no field of %s" % [file, id, f, kind])
			var list_of_kind: Array = _kinds[kind]
			var at: int = _at[kind].get(id, -1)
			if at >= 0:
				list_of_kind[at] = rec
			else:
				_at[kind][id] = list_of_kind.size()
				list_of_kind.append(rec)


## `base` with the fields of `patch` over it; a key ending in `+` adds its list or
## mapping to the field's (to its default when `base` does not write it). The record
## stays its first bundle's (its pictures and sounds are looked for there).
static func _patched(base: Dictionary, patch: Dictionary, file: String, id: String, kind: String) -> Dictionary:
	var out := base.duplicate(true)
	for key in patch:
		if key == "id":
			continue
		var v: Variant = patch[key]
		if key.ends_with("+"):
			var field: String = key.trim_suffix("+")
			var had: Variant = out.get(field, schema(kind).get(field, {}).get("default"))
			if had is Array and v is Array:
				out[field] = had + v
			elif had is Dictionary and v is Dictionary:
				var merged: Dictionary = had.duplicate()
				merged.merge(v, true)
				out[field] = merged
			else:
				problems.append("%s: %s.%s: `+` adds to a list or a mapping the record has" % [file, id, field])
		else:
			out[key] = v
	return out


## Every reference must name a record that is loaded; a soft one that does not is dropped
## from the record (an entry naming it with it), and reported when strict.
static func _check_refs() -> void:
	for kind in SCHEMAS:
		for field_ref: Array in refs(kind):
			var key: String = field_ref[0]
			var spec: Dictionary = field_ref[1]
			var of := target(spec)
			var soft: bool = spec.get("soft", false)
			for r in _kinds[kind]:
				if "." in key:
					var field := key.get_slice(".", 0)
					var sub := key.get_slice(".", 1)
					var keep := []
					for e: Dictionary in r[field]:
						var gone: bool = e[sub] != "" and find(of, e[sub]).is_empty()
						if gone:
							_broken(r, kind, key, of, e[sub], soft)
						if not (gone and soft):
							keep.append(e)
					r[field] = keep
				elif spec.type == "list":
					var keep := []
					for ref in r[key]:
						if find(of, ref).is_empty():
							_broken(r, kind, key, of, ref, soft)
						if not soft or not find(of, ref).is_empty():
							keep.append(ref)
					r[key] = keep
				elif spec.type in ["amounts", "shares"]:
					for ref in r[key].keys():
						if find(of, ref).is_empty():
							_broken(r, kind, key, of, ref, soft)
							if soft:
								r[key].erase(ref)
				else:
					var ref: String = r[key]
					if ref == "" and spec.get("default") == "":
						continue
					if find(of, ref).is_empty():
						_broken(r, kind, key, of, ref, soft)
						if soft:
							r[key] = ""


## The ids records had before (`was`): each in the record's mod unless it names one, not
## the id of a record still loaded, and claimed by one record only.
static func _check_renames() -> void:
	for kind in SCHEMAS:
		var renamed := {}
		for r in _kinds[kind]:
			for old in r.was:
				var q := qualify(old, r.mod)
				var file := "%s/data/%s.yaml" % [r.bundle, kind]
				if not _valid_id(q):
					problems.append("%s: %s.was: `%s`: an id is `mod:name`" % [file, r.id, old])
				elif not find(kind, q).is_empty():
					problems.append("%s: %s.was: `%s` is a record still" % [file, r.id, q])
				elif renamed.has(q):
					problems.append("%s: %s.was: `%s` was `%s` already" % [file, r.id, renamed[q], q])
				else:
					renamed[q] = r.id
		_renamed[kind] = renamed


## Names against the rules of docs/specifications/BUNDLE_SYSTEM.md (section 3), as
## `warnings`: a recipe is named after what it makes, or `<item>_from_<what it needs>`
## when the item has more recipes; a tool `<material>_<thing>`; ore `<metal>_ore`; a tag
## is a lowercase word, and one only one record has is likely a slip.
static func _check_names() -> void:
	var bare := {}
	for r in records("recipes"):
		var name: String = r.id.get_slice(":", 1)
		var item: String = r.makes.get_slice(":", 1)
		if name == item:
			if bare.has(r.makes):
				warnings.append("recipes: `%s` and `%s` both make `%s` by its name; name the other `%s_from_<what it needs>`"
					% [bare[r.makes], r.id, r.makes, item])
			bare[r.makes] = r.id
		elif not name.begins_with(item + "_from_"):
			warnings.append("recipes: `%s` makes `%s`: name it `%s`, or `%s_from_<what it needs>`" % [r.id, r.makes, item, item])
		elif not r.needs.keys().any(func(n: String) -> bool: return n.get_slice(":", 1) == name.trim_prefix(item + "_from_")):
			warnings.append("recipes: `%s`: `%s` is not among what it needs" % [r.id, name.trim_prefix(item + "_from_")])
	for r in records("items"):
		if r.tool != "none" and not "_" in r.id.get_slice(":", 1):
			warnings.append("items: `%s`: a tool is named `<material>_<thing>`, like `stone_axe`" % r.id)
	for r in records("materials"):
		if r.role == "ore" and not r.id.ends_with("_ore"):
			warnings.append("materials: `%s`: ore is named `<metal>_ore`" % r.id)
	var tagged := {}
	for kind in SCHEMAS:
		for r in records(kind):
			for t in r.tags:
				if not t.is_valid_ascii_identifier() or t != t.to_lower():
					warnings.append("%s: `%s`: the tag `%s` is not a lowercase word" % [kind, r.id, t])
				tagged[t] = tagged.get(t, []) + ["%s `%s`" % [kind, r.id]]
	for t in tagged:
		if tagged[t].size() == 1:
			warnings.append("%s: the tag `%s` is on nothing else" % [tagged[t][0], t])
