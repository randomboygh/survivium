extends SceneTree
## Plays, saves and starts the game again without a screen: what the player dug, where
## they stood, the clock, the props, the explored map, the markers and a module's part
## of the player come back; the playtest page's teleport puts the player down; a sign's
## window and the chat answer touches as they should. The saves go to a test folder of
## their own. Run:
## godot --headless --path . --script res://tests/save_test.gd

const Mat := preload("res://src/shared/content/materials.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const SettingsFile := preload("res://src/client/settings.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const TestGround := preload("res://src/shared/world/test_ground.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
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
	# The settings of this test, apart from the game's and the tools' (shot.gd saves some).
	SettingsFile.path = "user://test_settings.cfg"
	SettingsFile.language_override = "ru"
	# Every text shown to the player must have its English (Lang.seen).
	Lang.watching = true
	DirAccess.remove_absolute(SettingsFile.path)
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
	var zone_checked := false
	while not main.ready_to_play:
		if not zone_checked and main.session != null and main.chunks.gen != null:
			# The menu's loading builds what the session makes, so the session must know
			# where the body is before the world is ready (the smoke test's path).
			zone_checked = true
			var zones: Array = main.session.zones()
			_check(zones.has(main.chunks._player_chunk()),
				"the server makes the world around the player's body before the world is ready")
		await process_frame
	return main


func _touch(pos: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.position = pos
	t.pressed = down
	Input.parse_input_event(t)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## A thing the build mode holds up (BuildMode.drag) never stays in the air: dropped when
## its stroke goes without a release, when another press comes while it is dragged, and
## when the last finger is up though the mouse's emulation missed it (the user's report
## of 2026-11-15: a thing set down with the finger held hung in the air).
func _held_props(main: Node) -> void:
	main.host.player.inventory.add("tools:chest", 1)
	await _frames(2)
	_check(main.props.put_from_bag("tools:chest"), "a chest is set down in front of the player")
	var e: Dictionary = {}
	for t: Dictionary in main.placed.things:
		if t.item == "tools:chest" and t.cell != main.placed.things[0].cell:
			e = t
	if e.is_empty():
		_check(false, "the chest set down is in the client's copy")
		return
	main.build.enter("tools:chest")
	var held_up := func(how: String) -> void:
		main.props.hold_at(e, e.cell + Vector3i(1, 0, 0))
		main.build._dragged = e
		main.controls._stroke = {"button": MOUSE_BUTTON_LEFT, "dig": false, "pos": Vector2(1, 1), "held": true,
			"pending": false, "prop": e, "from": Vector2(1, 1), "ms": 0, "moved": true, "to": null, "corner": null,
			"turn": int(e.get("turn", 0)), "shown": null, "grab": Vector3i.ZERO}
		_check(not main.props.standing(e), "a thing dragged is held up (%s)" % how)
	# Its stroke dropped with no release.
	held_up.call("stroke gone")
	main.controls._stroke = {}
	await _wait_ms(500)
	_check(main.props.standing(e), "a thing held up whose stroke is gone drops back")
	# Another press while it is dragged.
	held_up.call("second press")
	main.controls.tap(main.controls.active, Vector2(2, 2))
	await _wait_ms(500)
	_check(main.props.standing(e) and main.build._dragged.is_empty(), "a second press lets the thing dragged drop back")
	main.controls._stroke = {}
	# The finger lifted, the mouse's emulation still pressed (the middle button here: the
	# world does nothing with it).
	var was_touch: bool = main.controls.touch
	main.controls.set_touch(true)
	main.controls.fingers.clear()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	held_up.call("finger up")
	main.controls._stroke.button = MOUSE_BUTTON_MIDDLE
	await _wait_ms(500)
	_check(main.props.standing(e) and main.controls._stroke.is_empty(), "a thing dragged drops back once no finger is down")
	press = press.duplicate()
	press.pressed = false
	Input.parse_input_event(press)
	main.controls.set_touch(was_touch)
	await _hold_to_put(main)
	main.build.leave()
	await _frames(2)


## The build mode's hands with a thing (the user's picks of 2026-11-15): a tap on the ground
## sets one from the bag down at once, a hold hangs it in the air until it is let go there;
## a tap on a thing set down takes it back into the bag after the double tap's time, a hold hangs it in the air,
## the turn button turns it there, and letting go sets it down turned.
func _hold_to_put(main: Node) -> void:
	main.controls._stroke = {}
	var inv = main.host.player.inventory
	inv.add("tools:chest", 2)
	main.build.choose("tools:chest")
	await _frames(2)
	var me := Vector3i((main.player.position / main.CELL).floor())
	var aim := Vector3i.ZERO
	var found := false
	for d: Vector3i in [Vector3i(4, 0, 0), Vector3i(-4, 0, 0), Vector3i(0, 0, 4), Vector3i(0, 0, -4), Vector3i(4, 0, 4)]:
		var a: Vector3i = me + d
		a.y = main.world.surface_y(a.x, a.z) + 1
		if not found and main.placed.put_spot(main.character, "tools:chest", a, main.world.size_y, 0)[0] != null:
			aim = a
			found = true
	if not found:
		_check(false, "a free place for a chest near the player")
		return
	var count := func() -> int: return inv.count("tools:chest")
	# The middle button stands for the finger held (the world does nothing with it).
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	var before: int = count.call()
	# Off the screen: the finger's place does not move the aim.
	var off := Vector2(-1000, -1000)
	var put := func(held_ms: int) -> Dictionary:
		var s := {"button": MOUSE_BUTTON_MIDDLE, "dig": false, "pos": off, "held": true, "pending": false,
			"put": "tools:chest", "from": off, "ms": Time.get_ticks_msec() - held_ms, "up": false, "aim": aim,
			"turn": 0, "kept": false, "spot": null, "shown": null}
		main.controls._stroke = s
		return s
	# A tap: let go at once, set down where tapped.
	var s: Dictionary = put.call(0)
	main.build.release(s)
	main.controls._stroke = {}
	await _wait_ms(300)
	_check(count.call() == before - 1 and not main.props.holding_new(), "a tap on the ground sets a thing down at once")
	var e: Dictionary = main.placed.things[main.placed.things.size() - 1]
	# A tap on it takes it back at once.
	main.controls._stroke = {"button": MOUSE_BUTTON_MIDDLE, "dig": false, "pos": off, "held": true, "pending": false,
		"prop": e, "from": off, "ms": Time.get_ticks_msec(), "moved": false, "to": null, "corner": null,
		"turn": int(e.get("turn", 0)), "shown": null, "grab": Vector3i.ZERO}
	main.build.release(main.controls._stroke)
	main.controls._stroke = {}
	await _wait_ms(main.build.DOUBLE_TAP_MS + 200)
	_check(count.call() == before and not main.placed.things.has(e), "a tap on a thing set down takes it back into the bag")
	# A hold: it hangs in the air while held, and is set down as it is let go.
	s = put.call(1000)
	await _wait_ms(200)
	_check(main.props.holding_new(), "a thing new from the bag held hangs in the air")
	_check(s.spot != null, "the place it hangs over is free")
	s.held = false
	await _wait_ms(300)
	_check(main.controls._stroke.is_empty() and not main.props.holding_new() and count.call() == before - 1,
		"let go, the thing hanging is set down")
	e = main.placed.things[main.placed.things.size() - 1]
	# Held on a thing set down: it hangs, and let go it stands again.
	main.controls._stroke = {"button": MOUSE_BUTTON_MIDDLE, "dig": false, "pos": main.view.screen_of(Placed.center(e)),
		"held": true, "pending": false, "prop": e, "from": Vector2(-1, -1), "ms": Time.get_ticks_msec() - 1000,
		"moved": false, "to": null, "corner": null, "turn": int(e.get("turn", 0)), "shown": null, "grab": Vector3i.ZERO}
	var held: Dictionary = main.controls._stroke
	await _wait_ms(200)
	_check(held.moved and not main.props.standing(e), "a thing set down and held hangs in the air")
	held.held = false
	await _wait_ms(400)
	e = main.placed.things[main.placed.things.size() - 1]
	_check(main.controls._stroke.is_empty() and main.props.standing(e), "let go, a thing held up stands again")
	# A double tap turns it, and the next of its kind is set down turned so.
	var turned: int = (int(e.get("turn", 0)) + 1) % 4
	main.build.turn_thing(e)
	await _wait_ms(300)
	_check(main.build.kept_turns.get("tools:chest") == turned, "the turn of a thing double tapped is kept for its kind")
	aim = main.placed.at(e.cell).cell if not main.placed.at(e.cell).is_empty() else aim
	for d: Vector3i in [Vector3i(4, 0, 0), Vector3i(-4, 0, 0), Vector3i(0, 0, 4), Vector3i(0, 0, -4), Vector3i(-4, 0, -4)]:
		var a: Vector3i = me + d
		a.y = main.world.surface_y(a.x, a.z) + 1
		if main.placed.put_spot(main.character, "tools:chest", a, main.world.size_y, turned, true)[0] != null:
			aim = a
	var things_before: int = main.placed.things.size()
	s = put.call(0)
	s.turn = main.build.kept_turns.get("tools:chest", 0)
	s.kept = true
	main.build.release(s)
	main.controls._stroke = {}
	await _wait_ms(300)
	var last: Dictionary = main.placed.things[main.placed.things.size() - 1]
	_check(main.placed.things.size() == things_before + 1 and int(last.get("turn", 0)) == turned,
		"the next thing of that kind is set down turned the same")
	# A thing one cell big tapped with its kind in the hand: the next goes beside it; with none
	# left in the bag it is taken, and its slot chosen.
	_check(main.build.face_in(Vector3.ZERO, Vector3(0.5, 5.0, 0.5), Vector3.DOWN) == Vector3i.UP
		and main.build.face_in(Vector3.ZERO, Vector3(-5.0, 0.5, 0.5), Vector3.RIGHT) == Vector3i.LEFT,
		"the face a finger's ray goes in by")
	inv.add("tools:stairs", 1)
	main.build.choose("tools:stairs")
	await _wait_ms(200)
	var step_aim: Vector3i = aim + Vector3i(0, 0, 3)
	step_aim.y = main.world.surface_y(step_aim.x, step_aim.z) + 1
	main.net.request(Protocol.PROP_PUT_AT, ["tools:stairs", step_aim, 0])
	await _wait_ms(300)
	var step: Dictionary = {}
	for t: Dictionary in main.placed.things:
		if t.item == "tools:stairs":
			step = t
	_check(not step.is_empty() and not main.build._beside_kind(step), "with none of its kind left a tap takes a step")
	inv.add("tools:stairs", 1)
	await _wait_ms(200)
	_check(not step.is_empty() and main.build._beside_kind(step), "with one of its kind in the hand a tap sets the next beside it")
	main.build.choose("tools:chest")
	await _frames(2)
	if not step.is_empty():
		main.build._take(step.cell)
	await _wait_ms(300)
	_check(main.controls.held() == "tools:stairs", "a thing taken back has its slot chosen")
	main.build.kept_turns["tools:big_chest"] = 2
	await _frames(3)
	_check(not main.build.kept_turns.has("tools:big_chest"), "a kept turn is forgotten once the bag holds none of its kind")
	press = press.duplicate()
	press.pressed = false
	Input.parse_input_event(press)


func _wait_ms(ms: int) -> void:
	var end := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < end:
		await process_frame


## A sign's window on a touch screen: its buttons act as the finger lifts, and the field keeps
## the keys while a button is held; a finger lifted off the field lets it go; the world under
## the window is not touched; closing it lets the keys go.
func _sign_window(main: Node) -> void:
	root.size = Vector2i(920, 1600)
	main.controls.set_touch(true)
	await _frames(3)
	main.hud.open_sign({"cell": Vector3i(0, 0, 0), "item": "tools:sign"})
	await _frames(3)
	var w: Control = main.hud.sign_window
	var field: LineEdit = w._fields[0]
	var buttons: Array = w.find_children("*", "Button", true, false)
	var shut: Button = buttons[buttons.size() - 1]
	var at := field.get_global_rect().get_center()
	var shut_at := shut.get_global_rect().get_center()
	# The keyboard coming up moves the window: the finger lifts over a button.
	_touch(at, true)
	await _frames(2)
	_touch(shut_at, false)
	await _frames(3)
	_check(main.hud.sign_window == w and field.has_focus(),
		"a touch begun on a line keeps it, lifted over a button that does not act")
	_touch(at, true)
	_touch(at, false)
	await _frames(3)
	_check(field.has_focus(), "a tap on a sign's line gives it the keys")
	_check(main.hud.covers(Vector2(4, 4)), "nothing under a sign's window is a tap on the world")
	var on := shut.get_global_rect().get_center()
	_touch(on, true)
	await _frames(3)
	_check(main.hud.sign_window == w and field.has_focus(), "a button pressed does not act yet, the line keeps the keys")
	_touch(on, false)
	await _frames(3)
	_check(main.hud.sign_window == null and not is_instance_valid(w) or w.is_queued_for_deletion(),
		"the window closes as the finger lifts off its button")
	main.hud.open_sign({"cell": Vector3i(0, 0, 0), "item": "tools:sign"})
	await _frames(3)
	w = main.hud.sign_window
	field = w._fields[0]
	at = field.get_global_rect().get_center()
	_touch(at, true)
	_touch(at, false)
	await _frames(3)
	_touch(Vector2(4, 4), true)
	_touch(Vector2(4, 4), false)
	await _frames(3)
	_check(main.hud.sign_window == w and not field.has_focus(), "a finger lifted off the line lets it go, the window stays")
	w.close()
	await _frames(2)
	main.hud.chat.open()
	await _frames(2)
	_check(main.hud.chat._field.is_editing(), "the chat opens with its field edited (the phone's keyboard up)")
	main.hud.chat.close()
	main.controls.set_touch(false)


## The screen shown, searched for a key left untranslated (Lang.keys_shown): `what` is
## the window and the tab.
func _sweep(what: String) -> void:
	await _frames(3)
	var left := Lang.keys_shown(root)
	_check(left.is_empty(), "%s: no key left untranslated: %s" % [what, left])


## Every window of the game and every tab of it, in Russian: the bag's tabs, the map,
## the gestures, the chat, the pause, the settings and the playtest page with all their
## sections, and the main menu's pages and screens (the server's, «Присоединиться», a new
## world, the worlds saved).
func _every_window(main: Node) -> void:
	var hud = main.hud
	hud.toggle_bag()
	for tab: String in ["person", "bag", "craft", "team", "land"]:
		hud.bag.show_tab(tab)
		await _sweep("the bag's tab " + tab)
	hud.toggle_bag()
	hud.map_view.open()
	await _sweep("the map")
	hud.map_view.close()
	hud.toggle_gestures()
	await _sweep("the gestures")
	hud.toggle_gestures()
	hud.chat.open()
	# A bot's line is a key: each reader's game puts it into its own language.
	hud.chat.hear(7, "Bot1", "[wheres_the_campfire]")
	await _sweep("the chat")
	_check(hud.chat.lines[-1].text == "Bot1: Где костёр?", "a bot's line in the chat in Russian: %s" % hud.chat.lines[-1].text)
	hud.chat.close()
	hud.toggle_menu()
	await _sweep("the pause")
	main.settings.testing_unlocked = true
	var menu: Control = hud.settings_menu()
	for page: String in ["settings", "test"]:
		hud.open_settings(page)
		for sec: Array in menu._tabs_of(page):
			menu.show_section(sec[0])
			await _sweep("%s, %s" % [page, sec[0]])
	# «Данные для теста» (the report) is internal text quoting the logs, keys and all.
	for page: String in ["changes", "freezes"]:
		menu.open(page)
		await _sweep(page)
	menu.close()
	if hud._menu.visible:
		hud.toggle_menu()
	main._build_menu()
	var mm = main.menu
	for page: String in ["top", "single", "multi"]:
		mm._fill_page(page)
		await _sweep("the main menu's page " + page)
	mm.open_host()
	await _frames(2)
	for i in mm._setup._pages.size():
		mm._setup.show_tab(i)
		await _sweep("the server's tab %d" % i)
	# «Новый мир…» over the server's window, then back with the world set up there first.
	var host = mm._setup
	host._open_new_world()
	await _frames(2)
	_check(not host.visible and host._new_world != null, "«Новый мир…» opens over the server's window")
	await _sweep("a new world for the server")
	var seed_before = main.settings.values.world_seed
	main.settings.values.world_seed = 4242
	host._new_world_made(false)
	await _frames(2)
	var chosen: Dictionary = host.settings()
	_check(host.visible and host._new_world == null, "the server's window is back")
	_check(host._worlds[0].get("new", false) and host._world == 0 and chosen.seed_value == 4242 and chosen.world == "",
		"the world set up is first in the list, chosen")
	_check(chosen.get("mods") == main.settings.world_mods(), "the new world is made with the mods chosen for it")
	_check(host._worlds.filter(func(w: Dictionary) -> bool: return w.get("new", false)).size() == 1, "one new world in the list")
	host.choose_world(host._worlds.size() - 1)
	_check(not host.settings().has("mods"), "a saved world keeps its own mods")
	main.settings.values.world_seed = seed_before
	mm.open_join("")
	await _sweep("joining a server")
	mm._new_world()
	await _sweep("a new world")
	mm._close_setup()
	mm._open_worlds()
	await _sweep("the worlds saved")
	mm._close_setup()
	mm._open_settings()
	await _sweep("the menu's settings")
	main.menu.get_parent().queue_free()
	main.menu = null
	main.settings.testing_unlocked = false
	await _frames(2)


func _run() -> void:
	WorldStore.new(ROOT).erase()
	var main: Node = await _start()
	_check(not main.save.has_save, "a new world has no save")
	var bag := Bag.new()
	main.save.track("bag", bag)
	bag.items = {"core:stick": 3.0}
	main.host.player.inventory.add("resources:branch", 7)
	main.host.player.inventory.add("resources:fiber", 9)
	main.host.player.vitals.satiety = 42.0
	# A cord being made, a worn axe, a workbench placed and a log in the spawn chest.
	var shop = main.host.workshop
	_check(shop.start(shop.knowledge.recipes().filter(func(r: Dictionary) -> bool: return r.id == "materials:cord")[0], 2) == 2,
		"cord is known from fibre and queued")
	main.host.player.inventory.add("tools:stone_axe", 1, 17)
	main.host.player.inventory.add("tools:workbench", 1)
	_check(main.props.put_from_bag("tools:workbench"), "a workbench is placed in front of the player")
	main.session.placed.chest_items.add("resources:log", 2)
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
	main.session.clock.day = 5
	main.session.clock.time_of_day = 0.6
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
	var props: Array = main.session.placed.to_list()
	var seed_value: int = main.world_seed
	_check(main.host.workshop.knowledge.recipes().any(func(r: Dictionary) -> bool: return r.id == "tools:torch"),
		"the torch is known with branches and fibre in the bag")
	_check(main.save.meta.get("known", []) == Mods.all(), "a world keeps the bundles there were when it was saved")
	# Saved as a world from before the torch, and before worlds kept the bundles they knew,
	# with the sword left out: it gets the torch's bundle when it loads, not the sword's.
	var store = main.save.store
	var runner: Node = main.host.runner
	_check(runner.get_parent() == root and runner.is_processing(), "the server's loop runs under the tree's root while the game is played")
	main.queue_free()
	await process_frame
	await process_frame
	_check(not is_instance_valid(runner) and root.get_node_or_null("ServerRunner") == null, "the server's loop goes with the scene")
	var old_meta: Dictionary = store.read_json(WorldStore.WORLD)
	old_meta.content = 8
	old_meta.erase("known")
	old_meta.mods = Array(old_meta.mods).filter(func(b: String) -> bool: return not b in ["tools/torch", "tools/sword"])
	# Hosted as a server since (ServerStore): its teams, fights and next player's number.
	var hosted := {"teams": {"teams": [{"id": 1, "name": "Лиса", "lead": 2, "members": [2, 3]}], "names": {"2": "Аня", "3": "Боря"},
		"next": 2}, "fights": {"wars": []}, "next_player": 4}
	old_meta.merge(hosted, true)
	store.write_json(WorldStore.WORLD, old_meta)

	main = await _start()
	_check("tools/torch" in main.world_mods and not "tools/sword" in main.world_mods,
		"a world saved before the torch gets it with the other tools; the sword it left out stays out")
	w = main.world
	_check(main.save.has_save and main.world_seed == seed_value, "the same world starts again from its save")
	_check(w.get_cell(pit.x, top - 1, pit.z) == Mat.AIR and w.get_cell(pit.x, top - 3, pit.z) == Mat.AIR,
		"the pit dug is still there")
	_check(main.player.position.distance_to(stood) < 0.01, "the player stands where they stood")
	_check(main.session.clock.day == 5 and absf(main.session.clock.time_of_day - 0.6) < 0.01, "the clock goes on from the save")
	_check(str(main.session.placed.to_list()) == str(props), "the props stand where they stood")
	_check(main.session.placed.cell_of("tools:workbench") != null and main.session.placed.chest_items.count("resources:log") == 2,
		"the workbench placed and what the chest holds come back")
	_check(main.host.workshop.queue.jobs.size() >= 1 and main.host.workshop.knowledge.seen.has("resources:fiber"),
		"the crafting queue and what the character knows come back")
	var axe_slot: int = main.host.player.inventory.slots.find(main.host.player.inventory.slots.filter(
		func(x) -> bool: return x != null and x[0] == "tools:stone_axe")[0])
	_check(main.host.player.inventory.worn(axe_slot) == 17, "a tool's wear comes back")
	var bag2 := Bag.new()
	main.save.track("bag", bag2)
	_check(bag2.items == {"core:stick": 3.0}, "a module gets its part of the player back")
	main.save.begin()
	main.save.flush()
	var kept: Dictionary = store.read_json(WorldStore.WORLD)
	_check(kept.has("sky") and hosted.keys().all(func(k: String) -> bool: return str(kept.get(k)) == str(JSON.parse_string(JSON.stringify(hosted[k])))),
		"single player's save keeps what a server saved in the world: teams, fights, the next number (%s)" % [kept.keys()])
	_check(main.host.player.inventory.count("resources:branch") == 7, "the character's bag comes back")
	_check(absf(main.host.player.vitals.satiety - 42.0) < 1.0, "the character's satiety comes back")
	_check(main.markers.list.size() == 1 and main.markers.list[0].cell == Vector2i(120, -40) and main.markers.list[0].color == 4,
		"the markers come back")
	mm = main.hud.minimap
	_check(explored.all(func(k: Vector2i) -> bool: return mm.regions.has(k)), "the explored map comes back")
	_check(mm.regions.has(far) and mm.regions[far].image.get_pixel(3, 5).is_equal_approx(Color.RED),
		"a region explored far away comes back as it was painted")
	# A chunk the map already shows is not painted bare when its terrain is made again
	# (its trees would go from the map until it is shaped); one not shown yet is.
	var gen = main.gen
	var seen := Vector2i(main.chunks.load_home.x + 20, main.chunks.load_home.y)
	var unseen := seen + Vector2i(0, 3)
	var seen_px := Vector2i((seen.x & (mm.REGION - 1)) * mm.CHUNK_PX, (seen.y & (mm.REGION - 1)) * mm.CHUNK_PX)
	var seen_region := Vector2i(seen.x >> mm.REGION_SHIFT, seen.y >> mm.REGION_SHIFT)
	mm._region(seen_region).image.set_pixel(seen_px.x, seen_px.y, Color.RED)
	# Made whole, as the loading screen does: the maps take the chunk at once.
	main.chunks._whole = true
	for key: Vector2i in [seen, unseen]:
		gen.run(key, WorldGen.TERRAIN)
	main.chunks._whole = false
	_check(mm.regions[seen_region].image.get_pixel(seen_px.x, seen_px.y).is_equal_approx(Color.RED),
		"a chunk already on the map keeps its picture when its terrain is made again")
	_check(mm.has_chunk(unseen), "a chunk not on the map yet is painted with its terrain")

	# Death: the bag goes into a sack, the character lies dead until brought back, and a
	# world left dead is entered dead.
	main.save.begin()
	var ch = main.character
	main.host.player.vitals.health = 0.0
	main.host.player.vitals.hurt_by = "hunger"
	await process_frame
	await process_frame
	_check(ch.is_dead() and ch.inventory.is_empty() and not main.player.visible, "a death empties the bag and hides the player")
	_check(main.death_screen.visible and not main.hud.visible, "the death screen is shown")
	_check(ch.death.lost.any(func(st: Array) -> bool: return st[0] == "resources:branch" and st[1] == 7),
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
	# The typed-coordinates row comes first (it has no «place»); the first place is the respawn point.
	var place: Dictionary = main.hud.settings_menu()._section_rows("marks").filter(
		func(r: Variant) -> bool: return r is Dictionary and r.has("place"))[0]
	main.player.position += Vector3(40.0, 0.0, 40.0)
	main.character.go_to_column(place.cell)
	_check(place.get("place") == ch.respawn_points()[0][0]
		and Vector2(main.player.position.x, main.player.position.z).distance_to(Vector2(ch.home.x, ch.home.z)) < 1.0,
		"the playtest page takes the player back to the respawn point")
	# Once the world there is built (Trip).
	main.settings.go_to_death()
	var trip_from := Time.get_ticks_msec()
	while main.trip.going() and Time.get_ticks_msec() - trip_from < 30000:
		await process_frame
	_check(main.player.position.distance_to(fell) < 0.01 and not ch.is_dead(), "the playtest button goes back where they fell")
	# Back by the respawn point, where the things are set down next.
	ch.go_to_column(place.cell)
	frames = 0
	while ch.arriving != null and frames < 1200:
		await process_frame
		frames += 1
	main.settings.set_no_overload(true)
	_check(not ch.inventory.heavy, "the playtest switch turns overload off")
	main.settings.set_no_overload(false)
	var test_save := WorldStore.new(WorldStore.world_dir(TestGround.SEED, {}))
	test_save.write_json(WorldStore.WORLD, {"format": WorldStore.FORMAT, "seed": TestGround.SEED})
	main.settings.reset_test_world()
	_check(not test_save.exists() and main.world_seed != TestGround.SEED, "the test world's save is reset from another world")
	# «Очистить все данные» removes everything under its root but the engine's logs.
	var wipe := "user://test_saves/wipe"
	DirAccess.make_dir_recursive_absolute(wipe + "/saves/a/chunks")
	DirAccess.make_dir_recursive_absolute(wipe + "/logs")
	for path in [wipe + "/settings.cfg", wipe + "/saves/current.json", wipe + "/saves/a/chunks/0_0.bin", wipe + "/logs/godot.log"]:
		FileAccess.open(path, FileAccess.WRITE).close()
	main.settings.wipe_data(wipe)
	_check(DirAccess.get_files_at(wipe).is_empty() and Array(DirAccess.get_directories_at(wipe)) == ["logs"],
		"wiping all data leaves nothing but the logs")
	WorldStore.erase_dir(wipe)
	await _sign_window(main)
	await _every_window(main)
	await _held_props(main)
	main.queue_free()
	await process_frame
	WorldStore.new(ROOT).erase()
	_check(Lang.missed.is_empty(), "every text shown has its English: %s" % [Lang.missed])
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)
