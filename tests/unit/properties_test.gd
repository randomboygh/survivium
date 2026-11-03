extends "res://tests/unit/test_case.gd"
## Generated tests: many random cases from fixed seeds, each checked against what must
## always hold, so a case the hand-written tests never thought of is still met. The bag
## (Inventory) under random adds, removals, takes, moves between bags, sorts and saves:
## nothing appears or vanishes, no stack is over its size, what goes in is what there was
## room for. The content graph (ContentGraph) on random chains of recipes of a test mod: it
## reaches exactly what a plain fixed point over the recipes reaches from the start bag,
## and names each thing it cannot reach in an error, never one it can. A failure prints its
## seed and step: `godot --headless --path . --script res://tests/run_tests.gd -- properties`.

const ContentGraph := preload("res://src/shared/content/content_graph.gd")

## Random bags played, and steps in each.
const BAGS := 40
const STEPS := 120
## Random recipe sets checked, and things in each.
const GRAPHS := 12
const THINGS := 12


func run() -> void:
	_test_bags()
	_test_graphs()


# --- The bag ---------------------------------------------------------------------------

## Items of plain stacks (nothing that wears, spoils or holds things), stack sizes from one up.
func _plain_items() -> Array:
	var out := []
	var ids: Array = Items.IDS.duplicate()
	ids.sort()
	for id: String in ids:
		if not Inventory.keeps_wear(id) and Items.get_item(id).get("storage", 0) == 0 \
				and Items.get_item(id).get("bag_slots", 0) == 0 and Items.wear_on(id) == "":
			out.append(id)
	return out


func _test_bags() -> void:
	var pool := _plain_items()
	var sizes := {}
	for id: String in pool:
		sizes[Items.stack_size(id)] = id
	# One item of each stack size, a few of the commonest besides.
	var picked: Array = sizes.values()
	for id: String in pool.slice(0, 4):
		if not id in picked:
			picked.append(id)
	_check(picked.size() >= 3 and sizes.has(1), "the generated bags have items of a stack of one and bigger: %s" % [picked])
	var broken := ""
	for seed_i in BAGS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + seed_i
		var a := Inventory.new(rng.randi_range(1, 10))
		var b := Inventory.new(rng.randi_range(1, 6))
		var want := {}
		for step in STEPS:
			var id: String = picked[rng.randi() % picked.size()]
			var what := rng.randi() % 7
			match what:
				0, 1:
					var n := rng.randi_range(1, Items.stack_size(id) * 3)
					var room := a.room_for(id)
					var went := a.add(id, n)
					if went != mini(n, room):
						broken = "add %d %s with room for %d put in %d" % [n, id, room, went]
					want[id] = want.get(id, 0) + went
				2:
					var n := rng.randi_range(1, Items.stack_size(id) * 2)
					var had := a.count(id)
					var took := a.remove(id, n)
					if took != mini(n, had):
						broken = "remove %d %s of %d took %d" % [n, id, had, took]
					want[id] = want.get(id, 0) - took
				3:
					var i := rng.randi() % a.slots.size()
					var s = a.take_slot(i, rng.randi_range(1, 5))
					if s != null:
						want[s[0]] = want.get(s[0], 0) - s[1]
				4:
					# Into the other bag, and now and then all of it back: the two bags
					# together hold what they held.
					a.move_slot(rng.randi() % a.slots.size(), b)
					if rng.randf() < 0.5:
						b.move_all(a)
				5:
					a.sort(Inventory.SORTS.keys()[rng.randi() % Inventory.SORTS.size()], rng.randi() % 2)
				6:
					var copy := Inventory.new(a.slots.size())
					copy.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
					if copy.slots != a.slots:
						broken = "a save as JSON gave back %s, not %s" % [copy.slots, a.slots]
			if broken == "":
				broken = _bag_problem(a, b, want)
			if broken != "":
				broken = "seed %d step %d: %s" % [7000 + seed_i, step, broken]
				break
		if broken != "":
			break
	_check(broken == "", "random adds, removals, takes, moves, sorts and saves keep the bag's counts and stacks: %s" % broken)


## What is wrong with bags `a` and `b` together holding the counts `want`, "" if nothing.
func _bag_problem(a, b, want: Dictionary) -> String:
	for bag in [a, b]:
		for s in bag.slots:
			if s != null and (s[1] < 1 or s[1] > Items.stack_size(s[0])):
				return "a stack of %d %s (stack %d)" % [s[1], s[0], Items.stack_size(s[0])]
	for id: String in want:
		if a.count(id) + b.count(id) != want[id]:
			return "%s: %d in the bags, %d put in and not taken out" % [id, a.count(id) + b.count(id), want[id]]
	return ""


# --- The content graph -----------------------------------------------------------------

func _test_graphs() -> void:
	var before := Content.BUNDLES.duplicate()
	var mod := "res://content/_gen"
	_write_file(mod + "/mod.yaml", "id: _gen\ntitle: Случайные рецепты\nversion: \"1\"\napi: 1\n")
	var cases := []
	for g in GRAPHS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9100 + g
		cases.append(_random_set(rng))
		var c: Dictionary = cases.back()
		_write_file("%s/g%d/bundle.yaml" % [mod, g], "title: g%d\n" % g)
		_write_file("%s/g%d/data/items.yaml" % [mod, g], c.items)
		_write_file("%s/g%d/data/recipes.yaml" % [mod, g], c.recipes)
		_write_file("%s/g%d/data/starts.yaml" % [mod, g], c.starts)
	Content.refresh()
	var wrong := ""
	for g in GRAPHS:
		var c: Dictionary = cases[g]
		Mods.activate(["core", "_gen/g%d" % g])
		var graph := ContentGraph.new()
		var errors := Array(graph.errors).filter(func(e: String) -> bool: return not "`core:campfire`" in e)
		for i in THINGS:
			var key := "items/_gen:t%d" % i
			var named := errors.any(func(e: String) -> bool: return "`_gen:t%d`" % i in e)
			if graph.reached.has(key) != c.reach.has(i):
				wrong = "seed %d: t%d reached %s by the graph, %s by the recipes" % [9100 + g, i, graph.reached.has(key), c.reach.has(i)]
			elif named == c.reach.has(i):
				wrong = "seed %d: t%d %s, and named in an error %s: %s" % [9100 + g, i,
					"reached" if c.reach.has(i) else "not reached", named, errors]
			if wrong != "":
				break
		if wrong != "":
			break
	_check(wrong == "", "on %d random sets of recipes the graph reaches what the recipes reach from the start, and errs on the rest: %s" % [GRAPHS, wrong])
	_check(cases.any(func(c: Dictionary) -> bool: return c.reach.size() < THINGS)
		and cases.any(func(c: Dictionary) -> bool: return c.reach.size() == THINGS),
		"the random sets have some that reach everything and some that do not")
	Mods.activate(before)
	_remove(mod)
	Content.refresh()
	Mods.rescan()
	_check(Content.problems.is_empty() and ContentGraph.new().errors.is_empty(), "the full set loads clean again")


## A random set of THINGS things t0.. of a test bundle: some in the start bag, each of the
## others made by a recipe of two or three things (the earlier ones mostly, a later one
## now and then, which can close a cycle), or by none. {"items", "recipes", "starts" (the
## data files), "reach" (the things a plain fixed point reaches)}.
func _random_set(rng: RandomNumberGenerator) -> Dictionary:
	var items := ""
	var recipes := ""
	var start := {}
	var needs := {}
	for i in THINGS:
		items += "- {id: t%d, title: Вещь %d, weight: 0.1, stack: 20, fuel: true}\n" % [i, i]
		if i < 2 or rng.randf() < 0.1:
			start[i] = true
			continue
		if rng.randf() < 0.12:
			# Nothing makes it.
			continue
		var want := {}
		for k in rng.randi_range(1, 3):
			var j := rng.randi() % i if rng.randf() < 0.85 else rng.randi() % THINGS
			if j != i:
				want[j] = rng.randi_range(1, 3)
		if want.is_empty():
			want[0] = 1
		needs[i] = want
		var parts := []
		for j: int in want:
			parts.append("t%d: %d" % [j, want[j]])
		recipes += "- {id: t%d, title: Вещь %d, makes: t%d, needs: {%s}}\n" % [i, i, i, ", ".join(parts)]
	var bag := []
	for i: int in start:
		bag.append("_gen:t%d: 5" % i)
	var reach := start.duplicate()
	var grew := true
	while grew:
		grew = false
		for i: int in needs:
			if not reach.has(i) and needs[i].keys().all(func(j: int) -> bool: return reach.has(j)):
				reach[i] = true
				grew = true
	return {"items": items, "recipes": recipes if recipes != "" else "[]\n",
		"starts": "- {id: core:default, patch: true, bag+: {%s}}\n" % ", ".join(bag), "reach": reach}
