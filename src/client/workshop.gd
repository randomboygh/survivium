extends RefCounted
## Crafting for the player (plan/design/crafting.md): the recipes the character knows
## (Knowledge: learned as their materials come into the bag), the queue of things being
## made (CraftQueue: materials are taken when a job is queued, a cancel gives them
## back), worked on while the job's station stands near (Props.stations_near; by hand
## anywhere), and what is made going into the bag or, when it is full, on the ground.
## Also tool wear (on only with the playtest switch until the difficulty presets come:
## decision 105) and repair at a workbench. The window is the craft tab of the bag
## (InventoryWindow). `game` is the Main node.

const Crafting := preload("res://src/shared/crafting.gd")
const CraftQueue := preload("res://src/shared/craft_queue.gd")
const Knowledge := preload("res://src/shared/knowledge.gd")
const Items := preload("res://src/shared/items.gd")

## How far from the player a station works, in world units (as far as a placed thing
## is used, see Gathering.REACH).
const REACH := 4.0
## The station a tool is repaired at.
const REPAIR_AT := "core:workbench"

signal changed

var game
var queue := CraftQueue.new()
var knowledge := Knowledge.new()


func _init(g) -> void:
	game = g
	var inv = game.character.inventory
	inv.changed.connect(func() -> void: knowledge.look_at(inv))
	knowledge.learned.connect(func(id: String) -> void:
		game.hud.toast("Новый рецепт: %s" % Crafting.get_recipe(id).title)
		changed.emit())
	queue.changed.connect(func() -> void: changed.emit())


## Notes what the bag holds now (after a save is loaded) without announcing it.
func settle() -> void:
	knowledge.look_at(game.character.inventory, false)


## The stations near the player: item id -> true.
func stations() -> Dictionary:
	return game.props.stations_near(game.player.position + Vector3(0.0, 0.5, 0.0), REACH)


## The recipes the character knows, in the order of the data files.
func recipes() -> Array:
	return knowledge.recipes()


## Why recipe `r` cannot be started now; "" when it can.
func why_not(r: Dictionary) -> String:
	return Crafting.why_not(r, game.character.inventory, stations())


## Queues recipe `r` `times` times, as many as the materials allow; returns how many.
func start(r: Dictionary, times := 1) -> int:
	var n := 0
	while n < times and why_not(r) == "" and queue.add(r, game.character.inventory):
		n += 1
	if n == 0:
		var why := why_not(r)
		game.character.nag("craft", why if why != "" else "Очередь полна")
	return n


## Cancels job `i` of the queue; its materials go back into the bag (or on the ground).
func cancel(i: int) -> void:
	for s in queue.cancel(i):
		_receive(s[0], s[1])


## Works on the queue for a frame of `delta` seconds; called while playing.
func update(delta: float) -> void:
	for r in queue.step(delta, _can_work):
		_receive(r.makes, r.count)
		game.hud.toast("Готово: %s" % r.title)


## Whether the first job can be worked on: its station is near and its tool in the bag.
func _can_work(r: Dictionary) -> bool:
	return (r.at == "" or stations().has(r.at)) and Crafting.has_tool(r, game.character.inventory)


## Whether the first job waits for its station or tool.
func waiting() -> bool:
	return not queue.jobs.is_empty() and not _can_work(Crafting.get_recipe(queue.jobs[0].recipe))


## Puts `n` of item `id` into the bag; what does not fit goes on the ground at the feet.
func _receive(id: String, n: int) -> void:
	var got: int = game.character.give(id, n)
	if got < n:
		game.character.lay(id, n - got)


# --- Wear -------------------------------------------------------------------------

## One swing of the tool in the left hand: it wears when wear is on, and may break.
func use_tool() -> void:
	var id: String = game.controls.tool
	if id == "" or not game.settings.tool_wear:
		return
	if game.character.inventory.wear_tool(id, Items.get_item(id).durability):
		game.hud.toast("Сломалось: %s" % Items.title(id))


## How much of tool `id` worn by `worn` swings is left, 0..1 (1 for no wear).
static func condition(id: String, worn: int) -> float:
	var d: int = Items.get_item(id).get("durability", 0)
	return 1.0 if d <= 0 else clampf(1.0 - float(worn) / d, 0.0, 1.0)


## Why the tool in bag slot `i` cannot be repaired now; "" when it can.
func why_not_repair(i: int) -> String:
	var inv = game.character.inventory
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
		game.character.nag("repair", why)
		return false
	var inv = game.character.inventory
	var item := Items.get_item(inv.slots[i][0])
	for id in item.repair:
		inv.remove(id, item.repair[id])
	inv.mend(i)
	game.hud.toast("Починено: %s" % item.title)
	return true
