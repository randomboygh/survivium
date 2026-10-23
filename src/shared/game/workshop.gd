extends RefCounted
## Crafting for one character (plan/design/crafting.md): the recipes they know
## (Knowledge: learned as their materials come into the bag), the queue of things being
## made (CraftQueue: materials are taken when a job is queued, a cancel gives them
## back), worked on while the job's station stands near (Placed.stations_near; by hand
## anywhere), and what is made going into the bag or, when it is full, on the ground.
## Also tool wear (on only with the playtest switch until the difficulty presets come:
## decision 105) and repair at a workbench. `who` is the character (see WorldActions);
## on the client the window is the craft tab of the bag (InventoryWindow).

const Crafting := preload("res://src/shared/content/crafting.gd")
const CraftQueue := preload("res://src/shared/game/craft_queue.gd")
const Knowledge := preload("res://src/shared/game/knowledge.gd")
const Items := preload("res://src/shared/content/items.gd")

## How far from the character a station works, in world units (as far as a placed
## thing is used, see Gathering.REACH).
const REACH := 4.0
## The station a tool is repaired at.
const REPAIR_AT := "core:workbench"

signal changed

var who
## The placed things (Placed), for the stations near.
var placed
## Whose `tool_wear` turns tool wear on and `instant_craft` makes a job take no time
## (the playtest settings on the client).
var settings
var queue := CraftQueue.new()
var knowledge := Knowledge.new()
## The queue stands still while paused (the pause button of the craft tab); an empty
## queue is never paused.
var paused := false:
	set(v):
		paused = v
		changed.emit()


func _init(by, things, with_settings) -> void:
	who = by
	placed = things
	settings = with_settings
	# Methods, not lambdas: a lambda would keep the workshop, and the world through
	# `placed`, alive by its own signals after the scene is gone.
	who.inventory.changed.connect(_on_bag_changed)
	knowledge.learned.connect(_on_learned)
	queue.changed.connect(_on_queue_changed)


func _on_bag_changed() -> void:
	knowledge.look_at(who.inventory)


func _on_learned(id: String) -> void:
	who.say("Новый рецепт: %s" % Crafting.get_recipe(id).title)
	changed.emit()


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
		who.nag("craft", why if why != "" else "Очередь полна")
	return n


## Cancels job `i` of the queue; its materials go back into the bag (or on the ground).
func cancel(i: int) -> void:
	for s in queue.cancel(i):
		_receive(s[0], s[1])
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
	# A job a frame when crafting is instant.
	var work := 1e9 if settings.get("instant_craft") == true else delta
	for r in queue.step(work, _can_work):
		_receive(r.makes, r.count)
		who.note("crafted", r.count)
		who.say("Готово: %s" % r.title)


## Whether the first job can be worked on: its station is near and its tool in the bag.
func _can_work(r: Dictionary) -> bool:
	return (r.at == "" or stations().has(r.at)) and Crafting.has_tool(r, who.inventory)


## Whether the first job waits for its station or tool.
func waiting() -> bool:
	return not queue.jobs.is_empty() and not _can_work(Crafting.get_recipe(queue.jobs[0].recipe))


## Puts `n` of item `id` into the bag; what does not fit goes on the ground at the feet.
func _receive(id: String, n: int) -> void:
	var got: int = who.give(id, n)
	if got < n:
		who.lay(id, n - got)


# --- Wear -------------------------------------------------------------------------

## One swing of the tool in the hand in use: it wears when wear is on, and may break.
func use_tool() -> void:
	var id: String = who.held()
	if id == "" or Items.get_item(id).get("tool", "none") == "none" or not settings.tool_wear:
		return
	if who.inventory.wear_tool(id, Items.get_item(id).durability):
		who.say("Сломалось: %s" % Items.title(id))


## How much of tool `id` worn by `worn` swings is left, 0..1 (1 for no wear).
static func condition(id: String, worn: int) -> float:
	var d: int = Items.get_item(id).get("durability", 0)
	return 1.0 if d <= 0 else clampf(1.0 - float(worn) / d, 0.0, 1.0)


## Why the tool in bag slot `i` cannot be repaired now; "" when it can.
func why_not_repair(i: int) -> String:
	var inv = who.inventory
	var s = inv.slots[i]
	if s == null or inv.worn(i) == 0:
		return "Чинить нечего"
	if not stations().has(REPAIR_AT):
		return "Чинят у станка: %s" % Items.title(REPAIR_AT)
	var item := Items.get_item(s[0])
	var short := {}
	for id in item.repair:
		if inv.count(id) < item.repair[id]:
			short[id] = item.repair[id] - inv.count(id)
	if not short.is_empty():
		return "Не хватает: %s" % Crafting.amounts_text(short)
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
	who.say("Починено: %s" % item.title)
	return true
