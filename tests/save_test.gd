extends SceneTree
## Plays, saves and starts the game again without a screen: what the player dug, where
## they stood, the clock, the props, the explored map, the markers and a module's part
## of the player come back; the playtest page's teleport puts the player down. The
## saves go to a test folder of their own. Run:
## godot --headless --path . --script res://tests/save_test.gd

const Mat := preload("res://src/shared/content/materials.gd")
const TestGround := preload("res://src/shared/world/test_ground.gd")
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
	# A marker, and a far region of the map as if explored, one pixel painted red.
	main.markers.add(Vector2i(120, -40), 4)
	var mm = main.hud.minimap
	var far := Vector2i(40, -40)
	mm._region(far).image.set_pixel(3, 5, Color.RED)
	mm.unsaved[far] = true
	var explored: Array = mm.regions.keys()
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
	_check(main.markers.list.size() == 1 and main.markers.list[0].cell == Vector2i(120, -40) and main.markers.list[0].color == 4,
		"the markers come back")
	mm = main.hud.minimap
	_check(explored.all(func(k: Vector2i) -> bool: return mm.regions.has(k)), "the explored map comes back")
	_check(mm.regions.has(far) and mm.regions[far].image.get_pixel(3, 5).is_equal_approx(Color.RED),
		"a region explored far away comes back as it was painted")

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
	main.settings.revive_at_death = true
	main.death_screen._fill()
	_check(main.death_screen._respawn.get_child_count() == ch.respawn_points().size() + 1,
		"the playtest switch adds coming back where they fell")
	main.settings.revive_at_death = false
	main.death_screen._revive(ch.respawn_points()[0][1])
	await process_frame
	_check(not ch.is_dead() and not main.death_screen.visible and main.hud.visible and main.player.visible,
		"the character comes back at the campfire")
	_check(ch.vitals.health > 0.0 and main.player.position.distance_to(ch.home) < 0.01, "brought back with health, at home")
	# The playtest page's teleport: held over the column until its chunk is made, then
	# put down on the ground near it.
	var to := Vector2i((ch.home / main.CELL).floor().x, (ch.home / main.CELL).floor().z) + Vector2i(150, -90)
	ch.go_to_column(to)
	frames = 0
	while ch.arriving != null and frames < 1200:
		await process_frame
		frames += 1
	for i in 30:
		await process_frame
	var at: Vector3 = main.player.position / main.CELL
	_check(ch.arriving == null and Vector2(at.x, at.z).distance_to(Vector2(to) + Vector2(0.5, 0.5)) < 25.0,
		"the teleport puts the player near the column (%d frames, at %s)" % [frames, at])
	_check(absf(at.y - main.world.surface_y(floori(at.x), floori(at.z))) < 1.5 or main.player.body.swimming,
		"the teleport puts the player on the ground (y %.1f, ground %d)" % [at.y, main.world.surface_y(floori(at.x), floori(at.z))])
	var place: Dictionary = main.hud._settings._section_rows("marks")[0]
	main.player.position += Vector3(40.0, 0.0, 40.0)
	main.character.go_to_column(place.cell)
	_check(place.get("place") == ch.respawn_points()[0][0]
		and Vector2(main.player.position.x, main.player.position.z).distance_to(Vector2(ch.home.x, ch.home.z)) < 1.0,
		"the playtest page takes the player back to the respawn point")
	main.settings.go_to_death()
	_check(main.player.position.distance_to(fell) < 0.01 and not ch.is_dead(), "the playtest button goes back where they fell")
	main.settings.set_no_overload(true)
	_check(not ch.inventory.heavy, "the playtest switch turns overload off")
	main.settings.set_no_overload(false)
	var test_save := WorldStore.new(WorldStore.world_dir(TestGround.SEED, {}))
	test_save.write_json(WorldStore.WORLD, {"format": WorldStore.FORMAT, "seed": TestGround.SEED})
	main.settings.reset_test_world()
	_check(not test_save.exists() and main.world_seed != TestGround.SEED, "the test world's save is reset from another world")
	main.queue_free()
	await process_frame
	WorldStore.new(ROOT).erase()
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)
