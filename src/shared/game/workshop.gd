extends RefCounted
## Crafting for one character (plan/design/crafting.md): the recipes they know
## (Knowledge: learned as their materials come into the bag), the queue of things being
## made (CraftQueue: materials are taken when a job is queued, a cancel gives them
## back), worked on while the job's station stands near (Placed.stations_near; by hand
## anywhere) and its tools and what it keeps are in the bag, and what is made, with the
## by-products that come (Crafting.outputs), going into the bag or, when it is full, on
## the ground. Also tool wear, by swings in the world and by the `wear` of a recipe made
## (on only with the playtest switch until the difficulty presets come: decision 105),
## and repair at a station that `repairs` (a workbench). `who` is the character (see
## WorldActions); on the client the window is the craft tab of the bag (InventoryWindow).

const Crafting := preload("res://src/shared/content/crafting.gd")
const CraftQueue := preload("res://src/shared/game/craft_queue.gd")
const Knowledge := preload("res://src/shared/game/knowledge.gd")
const Items := preload("res://src/shared/content/items.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Quality := preload("res://src/shared/game/quality.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
const Lang := preload("res://src/shared/content/lang.gd")

## How far from the character a station works, in world units (as far as a placed
## thing is used, see Gathering.REACH).
const REACH := 4.0

signal changed
## Recipe `recipe` was made and what it makes put into the bag (or on the ground).
signal made(recipe: Dictionary)

var who
## The placed things (Placed), for the stations near.
var placed
## The rules of play (Rules): `tool_wear` turns tool wear on, `instant_craft` makes a
## job take no time, `free_items` lets give_free give any recipe's thing.
var rules
var queue := CraftQueue.new()
var knowledge := Knowledge.new()
## The queue stands still while paused (the pause button of the craft tab); an empty
## queue is never paused.
var paused := false:
	set(v):
		paused = v
		changed.emit()


func _init(by, things, with_rules) -> void:
	who = by
	placed = things
	rules = with_rules
	# Methods, not lambdas: a lambda would keep the workshop, and the world through
	# `placed`, alive by its own signals after the scene is gone.
	who.inventory.changed.connect(_on_bag_changed)
	knowledge.learned_all.connect(_on_learned)
	queue.changed.connect(_on_queue_changed)


func _on_bag_changed() -> void:
	knowledge.look_at(who.inventory)


## One line for what one look at the bag taught, however much: a cord teaches a dozen
## recipes, and a line each would fill the screen and cost a frame.
func _on_learned(ids: PackedStringArray) -> void:
	who.say(learned_line(ids))
	changed.emit()


## "Новый рецепт: X", or for more "Новые рецепты: X, Y и ещё N".
static func learned_line(ids: PackedStringArray) -> String:
	if ids.size() == 1:
		return Lang.line("[new_recipe]", [Crafting.get_recipe(ids[0]).title])
	var a: String = Crafting.get_recipe(ids[0]).title
	var b: String = Crafting.get_recipe(ids[1]).title
	if ids.size() == 2:
		return Lang.line("[new_recipes]", [a, b])
	return Lang.line("[new_recipes_and_more]", [a, b, ids.size() - 2])


func _on_queue_changed() -> void:
	changed.emit()


## Notes what the bag holds now (after a save is loaded) without announcing it.
func settle() -> void:
	knowledge.look_at(who.inventory, false)


## The stations near the character: item id -> true.
func stations() -> Dictionary:
	return placed.stations_near(who.position + Vector3(0.0, 0.5, 0.0), REACH)


## The recipes the character knows, in the order of the data files.
func recipes() -> Array:
	return knowledge.recipes()


## Gives what recipe `r` makes into the bag for nothing, known or not, with no materials,
## station or tools, while the rules allow it (playtest «Бесплатные предметы»); returns
## how many went into the bag (0 when not allowed or the bag is full).
func give_free(r: Dictionary) -> int:
	if not rules.free_items or r.is_empty() or not Crafting.possible(r):
		return 0
	return who.give(r.makes, r.count)


## Why recipe `r` cannot be started now; "" when it can.
func why_not(r: Dictionary) -> String:
	return Crafting.why_not(r, who.inventory, stations())


## Queues recipe `r` `times` times, as many as the materials allow; returns how many.
func start(r: Dictionary, times := 1) -> int:
	var n := 0
	while n < times and why_not(r) == "" and queue.add(r, who.inventory):
		n += 1
	if n == 0:
		var why := why_not(r)
		who.nag("craft", why if why != "" else "[the_queue_is_full]")
	return n


## Cancels job `i` of the queue; its materials go back into the bag (or on the ground).
func cancel(i: int) -> void:
	for s in queue.cancel(i):
		_receive(s[0], s[1], s[2] if s.size() > 2 else 0, int(s[3]) if s.size() > 3 else Quality.NORMAL)
	if queue.jobs.is_empty():
		paused = false


## Cancels every job of the queue, the last first.
func cancel_all() -> void:
	for i in range(queue.jobs.size() - 1, -1, -1):
		cancel(i)


## Works on the queue for `delta` seconds.
func update(delta: float) -> void:
	if paused:
		return
	# A job a frame when crafting is instant; the skill of its work makes it faster.
	var work := 1e9 if rules.instant_craft else delta / _pace()
	for job: Dictionary in queue.step(work, _can_work):
		var r: Dictionary = job.recipe
		var got := Crafting.outputs(r, job.n)
		var sk = who.get("skills")
		if sk != null:
			# A skilled hand makes one more now and then (cooking, butchering).
			var more := yield_role(r)
			if more != "" and sk.extra(more):
				got[r.makes] = got.get(r.makes, 0) + 1
		# What is made is as good as its materials, no better than the hand, the station
		# and the recipe allow.
		var q := Quality.made(r, job.took, quality_cap(r))
		for id: String in got:
			_receive(id, got[id], 0, q)
		_wear_tools(r)
		who.note("crafted", r.count)
		if sk != null:
			sk.gain_recipe(role_of(r), r.id, r.time)
		who.say(Lang.line("[done]", [r.title]))
		made.emit(r)


## The most what recipe `r` makes can be at the skill of its work (Quality.skill_cap)
## and at the best station near that makes it (its `quality_cap`: a campfire cooks
## plainer than a fireplace).
func quality_cap(r: Dictionary) -> int:
	var cap := Quality.MAX
	var sk = who.get("skills")
	if sk != null:
		cap = Quality.skill_cap(sk.share_of(role_of(r)), sk.quality_most(role_of(r)))
	if r.get("at", "") != "":
		var best := 0
		for id: String in stations():
			var it := Items.get_item(id)
			if id == r.at or r.at in it.get("serves", []):
				best = maxi(best, int(it.get("quality_cap", Quality.MAX)))
		cap = mini(cap, best if best > 0 else int(Items.get_item(r.at).get("quality_cap", Quality.MAX)))
	return cap


## The skill (SkillSet role) recipe `r` is the work of: cooking on a fire, or the craft.
static func role_of(r: Dictionary) -> String:
	return "cook" if r.get("process", "craft") == "cook" else "craft"


## The skill whose level gives one more of what recipe `r` makes now and then: cooking
## for what is cooked, hunting for cutting up a beast's carcass; "" for none.
static func yield_role(r: Dictionary) -> String:
	if r.get("process", "craft") == "cook":
		return "cook"
	for id: String in r.get("needs", {}):
		if AiRules.CARCASSES.has(id):
			return "hunt"
	return ""


## The seconds recipe `r` takes `who` at the level of the skill of its work.
func time_of(r: Dictionary) -> float:
	var sk = who.get("skills")
	return float(r.time) * (1.0 if sk == null else sk.pace(role_of(r))) / _haste()


## What is left of the time of the first job of the queue at the skill of its work.
func _pace() -> float:
	var sk = who.get("skills")
	if sk == null or queue.jobs.is_empty():
		return 1.0 / _haste()
	return maxf(0.05, sk.pace(role_of(Crafting.get_recipe(queue.jobs[0].recipe)))) / _haste()


## The playtest multiplier of the pace of work of `who` (Character.haste), 1 for none.
func _haste() -> float:
	var h = who.get("haste")
	return 1.0 if h == null else maxf(1.0, h)


## What job `r` waits for to be worked on, named for the window: its station, a tool of a
## class it needs or a thing it keeps, missing; "" when nothing.
func waits_for(r: Dictionary) -> String:
	if r.at != "" and not stations().has(r.at):
		return Items.title(r.at)
	var kind := Crafting.lacks_tool(r, who.inventory)
	if kind != "":
		return Items.tool_title(kind)
	for id: String in r.keeps:
		if who.inventory.count(id) < r.keeps[id]:
			return Items.title(id)
	return ""


func _can_work(r: Dictionary) -> bool:
	return waits_for(r) == ""


## Whether the first job waits for its station, a tool or a thing it keeps.
func waiting() -> bool:
	return not queue.jobs.is_empty() and not _can_work(Crafting.get_recipe(queue.jobs[0].recipe))


## Puts `n` of item `id` worn by `worn` of quality `q` into the bag; what does not fit
## goes on the ground at the feet.
func _receive(id: String, n: int, worn := 0, q := Quality.NORMAL) -> void:
	var got: int = who.give(id, n, worn, q)
	if got < n:
		who.lay(id, Inventory.drop_data(Inventory.stack(id, n - got, worn, null, q)))


# --- Wear -------------------------------------------------------------------------

## One swing of the tool in the hand in use: it wears when wear is on, and may break. A
## tool of a class the world does not know works as bare hands and does not wear by it.
func use_tool() -> void:
	var id: String = who.held()
	if not (Tools.is_tool_item(id) or not Tools.weapon(id).is_empty()) or not rules.tool_wear:
		return
	# A skilled hand spares the tool now and then (the skill's `care`).
	var sk = who.get("skills")
	if sk != null and sk.spares(Tools.role_of(id)):
		return
	if who.inventory.wear_tool(id, Items.get_item(id).durability):
		who.say(Lang.line("[broke]", [Items.title(id)]))


## Recipe `r` made wears a tool of each class it needs by its `wear` swings, when wear is
## on (a tool of any class: what lasts no swings, `durability` 0, does not wear).
func _wear_tools(r: Dictionary) -> void:
	if r.wear <= 0 or not rules.tool_wear:
		return
	var sk = who.get("skills")
	for kind: String in r.tools:
		var id := Tools.held_of(who.inventory, kind)
		if id == "":
			continue
		for i: int in r.wear:
			if sk != null and sk.spares(role_of(r)):
				continue
			if who.inventory.wear_tool(id, Items.get_item(id).durability):
				who.say(Lang.line("[broke]", [Items.title(id)]))
				break


## How much of tool `id` worn by `worn` swings of quality `q` is left, 0..1 (1 for no wear).
static func condition(id: String, worn: int, q := Quality.NORMAL) -> float:
	var d: int = Quality.durability(Items.get_item(id).get("durability", 0), q)
	return 1.0 if d <= 0 else clampf(1.0 - float(worn) / d, 0.0, 1.0)


## Why the tool in bag slot `i` cannot be repaired now; "" when it can.
func why_not_repair(i: int) -> String:
	var inv = who.inventory
	var s = inv.slots[i]
	if s == null or inv.worn(i) == 0:
		return "[nothing_to_repair]"
	var benches := Array(Items.IDS).filter(func(id: String) -> bool: return Items.get_item(id).repairs)
	if benches.is_empty():
		return "[nowhere_to_repair_no_repair]"
	var near := stations()
	if not benches.any(func(id: String) -> bool: return near.has(id)):
		return Lang.line("[repaired_at_a_station]", [Items.title(benches[0])])
	var item := Items.get_item(s[0])
	var short := {}
	for id in item.repair:
		if inv.count(id) < item.repair[id]:
			short[id] = item.repair[id] - inv.count(id)
	if not short.is_empty():
		return Lang.line("[missing]", [Crafting.amounts_text(short)])
	return ""


## Repairs the tool in bag slot `i` with the materials of its `repair`; true if done.
func repair(i: int) -> bool:
	var why := why_not_repair(i)
	if why != "":
		who.nag("repair", why)
		return false
	var inv = who.inventory
	var item := Items.get_item(inv.slots[i][0])
	for id in item.repair:
		inv.remove(id, item.repair[id])
	inv.mend(i)
	who.say(Lang.line("[repaired]", [item.title]))
	return true
