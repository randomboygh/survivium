extends SceneTree
## Plays, saves and starts the game again without a screen: what the player dug, where
## they stood, the clock, the props and a module's part of the player come back. The
## saves go to a test folder of their own. Run:
## godot --headless --path . --script res://tests/save_test.gd

const Mat := preload("res://src/shared/content/materials.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const ROOT := "user://test_saves/game"

var checks := 0
var failures := 0


## A module's part of the player (see SaveGame.track).
class Bag extends RefCounted:
	var items := {}

	func to_dict() -> Dictionary:
		return {"items": items}

	func from_dict(d: Dictionary) -> void:
		items = d.get("items", {})


func _initialize() -> void:
	OS.low_processor_usage_mode_sleep_usec = 0
	_run()


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


func _start() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.skip_setup = true
	main.save_root = ROOT
	root.add_child(main)
	while not main.ready_to_play:
		await process_frame
	return main


func _run() -> void:
	WorldStore.new(ROOT).erase()
	var main: Node = await _start()
	_check(not main.save.has_save, "a new world has no save")
	var bag := Bag.new()
	main.save.track("bag", bag)
	bag.items = {"core:stick": 3.0}
	main.character.inventory.add("core:branch", 7)
	main.character.inventory.add("core:fiber", 9)
	main.character.vitals.satiety = 42.0
	# A cord being made, a worn axe, a workbench placed and a log in the spawn chest.
	var shop = main.workshop
	_check(shop.start(shop.knowledge.recipes().filter(func(r: Dictionary) -> bool: return r.id == "core:cord")[0], 2) == 2,
		"cord is known from fibre and queued")
	main.character.inventory.add("core:stone_axe", 1, 17)
	main.character.inventory.add("core:workbench", 1)
	_check(main.props.put_from_bag("core:workbench"), "a workbench is placed in front of the player")
	main.placed.chest_items.add("core:log", 2)
	main.save.begin()
	# A pit dug three cells deep beside the player, who then steps aside.
	var w = main.world
	var p := Vector3i((main.player.position / main.CELL).floor())
	var pit := Vector3i(p.x + 3, 0, p.z)
	var top: int = w.surface_y(pit.x, pit.z)
	for y in range(top - 3, top):
		w.set_cell(pit.x, y, pit.z, Mat.AIR)
		main.chunks.on_cell_changed(Vector3i(pit.x, y, pit.z))
	main.player.position += Vector3(-1.0, 0.0, 0.5)
	main.clock.day = 5
	main.clock.time_of_day = 0.6
	for i in 10:
		await process_frame
	# A save while playing goes a few chunks a frame.
	main.save._clock = main.save.INTERVAL
	var frames := 0
	await process_frame
	while main.save._writing and frames < 100:
		await process_frame
		frames += 1
	_check(frames < 100 and main.save.has_save, "the game saves while playing (%d frames)" % frames)
	main.save.flush()
	var listed := WorldStore.list_worlds()
	_check(listed.size() == 1 and listed[0].seed == main.world_seed and listed[0].day == 5, "the world list shows the save")
	var stood: Vector3 = main.player.position
	var props: Array = main.placed.to_list()
	var seed_value: int = main.world_seed
	main.queue_free()
	await process_frame
	await process_frame

	main = await _start()
	w = main.world
	_check(main.save.has_save and main.world_seed == seed_value, "the same world starts again from its save")
	_check(w.get_cell(pit.x, top - 1, pit.z) == Mat.AIR and w.get_cell(pit.x, top - 3, pit.z) == Mat.AIR,
		"the pit dug is still there")
	_check(main.player.position.distance_to(stood) < 0.01, "the player stands where they stood")
	_check(main.clock.day == 5 and absf(main.clock.time_of_day - 0.6) < 0.01, "the clock goes on from the save")
	_check(str(main.placed.to_list()) == str(props), "the props stand where they stood")
	_check(main.placed.cell_of("core:workbench") != null and main.placed.chest_items.count("core:log") == 2,
		"the workbench placed and what the chest holds come back")
	_check(main.workshop.queue.jobs.size() >= 1 and main.workshop.knowledge.seen.has("core:fiber"),
		"the crafting queue and what the character knows come back")
	var axe_slot: int = main.character.inventory.slots.find(main.character.inventory.slots.filter(
		func(x) -> bool: return x != null and x[0] == "core:stone_axe")[0])
	_check(main.character.inventory.worn(axe_slot) == 17, "a tool's wear comes back")
	var bag2 := Bag.new()
	main.save.track("bag", bag2)
	_check(bag2.items == {"core:stick": 3.0}, "a module gets its part of the player back")
	_check(main.character.inventory.count("core:branch") == 7, "the character's bag comes back")
	_check(absf(main.character.vitals.satiety - 42.0) < 1.0, "the character's satiety comes back")

	# Death: the bag goes into a sack, the character lies dead until brought back, and a
	# world left dead is entered dead.
	main.save.begin()
	var ch = main.character
	ch.vitals.health = 0.0
	ch.vitals.hurt_by = "hunger"
	await process_frame
	await process_frame
	_check(ch.is_dead() and ch.inventory.is_empty() and not main.player.visible, "a death empties the bag and hides the player")
	_check(main.death_screen.visible and not main.hud.visible, "the death screen is shown")
	_check(ch.death.lost.any(func(st: Array) -> bool: return st[0] == "core:branch" and st[1] == 7),
		"the death screen knows what was lost")
	var fell: Vector3 = main.player.position
	main.queue_free()
	await process_frame
	await process_frame

	main = await _start()
	ch = main.character
	await process_frame
	_check(ch.is_dead() and ch.death.get("cause") == "hunger" and main.death_screen.visible, "a world left dead is entered dead")
	_check(main.player.position.distance_to(fell) < 0.01 and not main.player.visible, "the dead lie where they fell")
	main.death_screen._revive(ch.respawn_points()[0][1])
	await process_frame
	_check(not ch.is_dead() and not main.death_screen.visible and main.hud.visible and main.player.visible,
		"the character comes back at the campfire")
	_check(ch.vitals.health > 0.0 and main.player.position.distance_to(ch.home) < 0.01, "brought back with health, at home")
	main.queue_free()
	await process_frame
	WorldStore.new(ROOT).erase()
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)
