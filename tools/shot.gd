extends SceneTree
## Renders the game and saves screenshots, for looking at visual changes without a
## browser. Needs a display (not --headless), for example:
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tools/shot.gd -- /tmp/shots [--phone] [name ...]
## `--phone` lays the window out as a phone's screen (fractional scales, CameraRig.turning).
## Each shot sets the time of day, season, weather and an offset of the player from
## the spawn point, waits for the weather to settle and saves <name>.png. The spots are
## searched in cells (half a world unit); the player stands in world units.

const Shots := preload("res://tools/shot/shots.gd")
const Places := preload("res://tools/shot/places.gd")


const WorldData := preload("res://src/shared/world/world_data.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const CELL := 0.5
const TEST_SAVES := "user://shot_ground"

var main: Node
var out_dir := "user://shots"
var names: Array = []
var phone := false
## The spots and scenes of the shots (see tools/shot/places.gd).
var places := Places.new()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	phone = "--phone" in args
	args.erase("--phone")
	if args.size() > 0:
		out_dir = args[0]
	names = args.slice(1) if args.size() > 1 else Shots.SHOTS.keys()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ground: bool = names.any(func(n: String) -> bool: return n.begins_with("ground-"))
	if ground:
		_test_world()
	main = load("res://scenes/main.tscn").instantiate()
	places.main = main
	if ground:
		main.save_root = TEST_SAVES
	main.skip_setup = true
	root.add_child(main)
	_run()


## Starts the run in the test world, in a folder of saves of its own made anew.
func _test_world() -> void:
	var store := load("res://src/shared/world/world_store.gd")
	store.erase_dir(TEST_SAVES)
	store.root = TEST_SAVES
	DirAccess.make_dir_recursive_absolute(TEST_SAVES)
	store.write_current(-1, {})


## Saved worlds made up for the world list, in a folder of their own.
func _fake_saves() -> void:
	main.WorldStore.root = "user://shot_saves"
	var worlds := [[main.world_seed, main.world_options, 12, "2026-10-20T18:40:00"],
		[48151623, {"size": 0, "water": 2, "mountains": 1, "rivers": 0, "biomes": 1}, 3, "2026-10-19T21:05:00"],
		[777, {"size": 1, "water": 1, "mountains": 2, "rivers": 1, "biomes": 1}, 41, "2026-10-18T12:30:00"],
		[-1, main.world_options, 2, "2026-10-17T10:00:00"]]
	for w: Array in worlds:
		var store = main.WorldStore.new(main.WorldStore.world_dir(w[0], w[1]))
		store.write_json(main.WorldStore.WORLD, {"format": main.WorldStore.FORMAT, "seed": w[0], "settings": w[1],
			"sky": {"day": w[2]}, "saved": w[3], "played": 1800.0})


## Servers joined lately made up for «Присоединиться», in a file of their own.
func _fake_servers() -> void:
	var list = main.ServerList
	list.path = "user://shot_servers.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(list.path))
	list.set_player_name("Аня")
	for i in 3:
		var s: Array = [["ws://192.168.1.20:7777", "Дача"], ["wss://quiet-river-lamp.trycloudflare.com", "У Миши"],
			["wss://north-pines-water.trycloudflare.com", "Survivium"]][i]
		list.remember(s[0], "key", s[1])


func _run() -> void:
	while not main.ready_to_play:
		await process_frame
	if phone:
		main.view.turning = true
		main.view.on_screen_resized()
	var spawn: Vector3 = main.player.position
	var added_fires := []
	for shot_name in names:
		main.player.position = spawn
		var shot: Dictionary = Shots.SHOTS[shot_name]
		main.session.clock.time_speed = 0.0
		main.session.clock.season = shot.season
		# A shot's time is the sun's: the same light whatever the season's day length.
		main.session.clock.season_clock = main.session.clock.DAYS_PER_SEASON * 0.5
		main.session.clock.time_of_day = shot.clock if shot.has("clock") else main.session.clock.time_at_sun(shot.time)
		main.session.clock.raining = shot.get("rain", false)
		if shot.has("weather"):
			main.session.clock.set_weather(_weather_index(shot.weather))
		main.session.clock.wind_to = shot.get("wind", 0.0)
		main.session.clock.leaf_fall = shot.get("leaf_fall", 0.0)
		main.sky.moon_override = shot.get("moon", -1.0)
		if "sun_steps" in main.sky:
			main.sky.sun_steps = shot.get("sun_steps", main.sky.SUN_STEPS)
		RenderingServer.directional_soft_shadow_filter_set_quality(shot.get("shadow_filter",
			ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")))
		main.settings.values.fire_shadows = shot.get("fire_shadows", main.settings.DEFAULTS.fire_shadows)
		main.settings.values.sun_rays = shot.get("rays", true)
		main.settings.values.fog = shot.get("fog", true)
		main.session.clock.morning_fog_pin = shot.get("morning_fog", 0)
		main.settings.set_value("shadows", shot.get("shadows", true))
		# Fires burn steadily in shots, so shots with and without shadows compare.
		main.effects.flicker_clock = -INF
		main.settings.set_value("show_help", false)
		main.chunks.manual_level = -1
		if shot.get("shore", false):
			main.player.position = places.shore(main.world, main.player.position)
		if shot.get("slopes", false):
			main.player.position = places.hills(main.world, main.player.position)
		if shot.get("hut", false):
			main.player.position = places.hut(main.world, main.player.position)
		if shot.get("underground", false):
			main.player.position = Places.cave(main.world, main.player.position)
		if shot.get("corners", false):
			main.player.position = places.corners(main.world, main.player.position)
		if shot.get("trees", false):
			main.player.position = places.lone_trees(main.world, main.player.position)
		if shot.get("forest", false):
			main.player.position = places.forest(main.world, main.player.position)
		if shot.has("place"):
			main.player.position = places.place(main.world, shot.place)
		if shot.has("at"):
			var at := Vector2i(shot.at[0], shot.at[1])
			main.player.position = Vector3(at.x + 0.5, main.world.size_y - 1, at.y + 0.5) * CELL
			main.chunks.build_around()
			main.player.position.y = shot.get("y", main.world.surface_y(at.x, at.y)) * CELL
		if shot.has("by_fire"):
			for e: Dictionary in main.session.placed.things:
				if main.session.placed.is_fire(e):
					main.player.position = main.session.placed.center(e) + shot.by_fire
					for off: Vector3 in shot.get("more_fires", []):
						var spot: Vector3i = main.session.placed.spot_near(main.session.placed.center(e) + off)
						if spot.y >= 0:
							added_fires.append(main.session.placed.put(main.session.placed.CAMPFIRE, spot, null))
					if shot.get("fire_blocks", false):
						places.fire_blocks(main.world, e.cell)
						for put: Array in [["tools:chest", Vector3(2.6, 0.0, 2.2)], ["tools:workbench", Vector3(-3.2, 0.0, 1.0)]]:
							var spot: Vector3i = main.session.placed.spot_near(main.session.placed.center(e) + put[1])
							if spot.y >= 0:
								added_fires.append(main.session.placed.put(put[0], spot, null))
					if shot.get("fire_out", false):
						places.out_fire = e
						main.session.placed.put_out(e)
					break
		# The shots look at far places too: the chunks around the new spot at once.
		main.chunks.build_around()
		if shot.has("water"):
			main.player.position = places.in_water(main.world, main.player.position, shot.water)
		if shot.has("find"):
			main.player.position = places.find(main.world, main.player.position, shot.find)
		if shot.get("copper_moss", false):
			var mossy := places.stone_moss_near(main.world, Vector3i((main.player.position / CELL).floor()))
			if mossy != Vector3i.MIN:
				main.player.position = (Vector3(mossy + Vector3i(0, 1, 3)) + Vector3(0.5, 0.0, 0.5)) * CELL
				places.copper_patch(main.world, mossy)
		if shot.get("pick_moss", false):
			var mossy := places.stone_moss_near(main.world, Vector3i((main.player.position / CELL).floor()))
			if mossy != Vector3i.MIN:
				main.player.position = (Vector3(mossy + Vector3i(0, 1, 3)) + Vector3(0.5, 0.0, 0.5)) * CELL
				places.pick_moss(main.world, mossy)
		if shot.get("grove", false):
			# Away from the campfire by the spawn, which melts the snow around it.
			places.grove(main.world, Vector3i((spawn / CELL).floor()) + Vector3i(0, 0, -44))
		if shot.get("orchard", false):
			# South of the spawn, within the chunks loaded there (the grove is north, the clearing east).
			places.orchard(main.world, Vector3i((spawn / CELL).floor()) + Vector3i(0, 0, 48))
			# A long row is shot in parts: the player steps `pan` cells east along it.
			main.player.position.x += shot.get("pan", 0) * CELL
		if shot.has("specimen"):
			# West of the spawn, away from the grove, the orchard and the clearing.
			places.specimen(main.world, Vector3i((spawn / CELL).floor()) + Vector3i(-60, 0, 0), shot.specimen)
		if shot.get("clearing", false):
			places.clearing(main.world, Vector3i((spawn / CELL).floor()) + Vector3i(40, 0, 0), shot.get("fell", false), shot.get("trees", []))
			main.player.position += shot.get("offset", Vector3.ZERO)
		if shot.get("gather", false):
			_gather()
		main.controls.set_touch(shot.get("touch", false))
		main.settings.values.camera_turn = shot.get("turn", 0)
		main.settings.values.camera_tilt = shot.get("tilt", 0)
		main.view.look_at_player()
		if shot.has("spin"):
			# Caught in a smooth turn (a turn button held), `spin` degrees round, held still.
			main.view.hold_turn(1)
			main.view._spin_start()
			main.view._hold = 0
			main.view.turn = deg_to_rad(shot.spin)
		if shot.get("work", false):
			_work()
		main.hud.perf.visible = shot.get("stats", false)
		main.hud.show_keys(shot_name == "ui")
		if shot.get("lab", false):
			places.lab(main.world, Vector3i((main.player.position / CELL).floor()))
			main.roof.build(main.world)
		if shot.get("wall", false) and not shot.wall is String:
			places.wall(main.world, Vector3i((main.player.position / CELL).floor()))
			main.roof.build(main.world)
		if shot.get("trench", false):
			main.player.position = places.trench(main.world, Vector3i((main.player.position / CELL).floor()))
		if shot.has("walk_into"):
			# The player walks into what stands that way (x east, y south) until it stops them.
			var body = main.player.body
			body.move_input = Vector2(shot.walk_into[0], shot.walk_into[1])
			for i in 90:
				main.player.position = body.step(main.player.position, 1.0 / 60.0, false)
			body.move_input = Vector2.ZERO
			main.player.facing = shot.get("facing", "s")
		if shot.has("cut"):
			main.chunks.manual_level = main.player.level() + int(shot.cut)
			main.chunks.update_cut(0.0)
		# Let snow, wetness, tints and particles settle.
		for i in 90:
			await process_frame
			main.session.clock.snow = 1.0 if main.session.clock.season == 3 else 0.0
			main.session.clock.settle_weather()
			if shot.has("clouds"):
				main.session.clock.clouds = shot.clouds
			main.session.clock.wet = 1.0 if main.session.clock.raining and main.session.clock.season != 3 else shot.get("after_rain", 0.0)
			main.sky.after_rain = shot.get("after_rain", 0.0)
			main.session.clock.puddles = shot.get("puddles", 0.0)
			main.sky.foliage = main.sky.FOLIAGE[main.session.clock.season]
			main.sky.grass = main.sky.GRASS[main.session.clock.season]
			main.sky.berry_amount = main.sky.BERRY_AMOUNT[main.session.clock.season]
			main.sky.blossom_amount = main.sky.BLOSSOM_AMOUNT[main.session.clock.season]
			main.sky.leaf_amount = lerpf(main.sky.LEAF_AMOUNT[main.session.clock.season], main.sky.LEAF_AMOUNT[3], main.session.clock.leaf_fall)
		if shot.get("windfall", false):
			# A long storm: the wind breaks branches off the trees around.
			main.session.clock.time_speed = 20.0
			for i in 2000:
				main.storms.step(main.storms.TICK, main.player.position)
			main.session.clock.time_speed = 0.0
		if shot.has("animal") and not main.session.wildlife.animals.is_empty():
			# Stands still where it is put until the shot is taken.
			var c = main.session.wildlife.animals[0]
			c.pos = main.player.position + shot.animal
			c.pos.y = main.session.wildlife.ground(c.pos.x, c.pos.z)
			c.target = c.pos
			c.think = 100.0
		if shot.get("birds", false):
			_place_birds()
		if shot.has("zoo"):
			_place_zoo(shot.zoo == "water")
		main.effects.pick_shadow_fires(PixelView.screen_plane(main.player.position))
		for f: Dictionary in main.effects.fires:
			f.light.light_energy = f.base * lerpf(1.0, 0.15, main.sky.daylight) \
					* (main.effects.shadow_energy if f.light.shadow_enabled else 1.0)
		if shot.has("put_fire"):
			var spot: Vector3i = main.session.placed.spot_near(main.player.position + Vector3(shot.put_fire[0], 0.0, shot.put_fire[1]) * main.CELL)
			if spot.y >= 0:
				added_fires.append(main.session.placed.put(main.session.placed.CAMPFIRE, spot, null))
		for at: Array in shot.get("sacks", []):
			main.host.player.sacks.append(main.player.position + Vector3(at[0], 0.0, at[1]) * main.CELL)
		await process_frame
		if shot.get("walk", false):
			# A walk in a hook south-east, then west, over a flat open spot, leaving
			# footprints.
			main.player.position = places.flat_near(main.world, main.player.position)
			for i in 100:
				main.player.body.move_input = Vector2(0.6, 0.8) if i < 50 else Vector2(-1.0, 0.0)
				main.player.step(1.0 / 30.0, false)
				main._leave_footprints()
				await process_frame
			main.player.body.move_input = Vector2.ZERO
			for i in 10:
				await process_frame
		if shot.has("hands"):
			await _hands(shot.hands)
		if shot.get("wall", "") is String and shot.get("wall", "") == "north":
			# Right behind the player where they stand now.
			places.wall(main.world, Vector3i((main.player.position / CELL).floor()), true)
			main.roof.build(main.world)
			for i in 20:
				await process_frame
		if shot.has("drops"):
			# Things lying in a row in front of the player, not picked up (WorldActions.PICKUP_NONE).
			main.settings.set_value("pickup", 3)
			var w = main.world
			var p: Vector3 = main.player.position
			for i in shot.drops.size():
				var at := p + Vector3(-1.5 + i * 0.6, 0.0, 1.0)
				var h: float = w.ground_height(at.x / CELL, at.z / CELL)
				w.add_drop(shot.drops[i], Vector3(at.x, h * CELL if h >= 0.0 else at.y, at.z), i * 0.7)
				main.props.show_drops(WorldData.chunk_key(floori(at.x / CELL), floori(at.z / CELL)))
		if shot.has("keys"):
			# Holds the keys while the shot is taken, so the walk animation shows.
			main.player.position = places.flat_near(main.world, main.player.position)
			_hold(shot.keys, true)
			for i in 12:
				await process_frame
		# Messages fade after a few seconds, longer than the settling above takes here.
		if shot.has("burst"):
			main.effects.burst(main.player.position + Vector3(0.6, 0.4, 0.0), main.Mat.index(shot.burst))
			for i in 3:
				await process_frame
		if shot.get("toast", false):
			main.hud.toast("Наступило лето")
			await process_frame
			await process_frame
		main.settings.set_value("ui_size", shot.get("ui_size", 2))
		main.settings.set_value("control_size", shot.get("control_size", 2))
		for k in ["minimap_size", "level_buttons", "camera_buttons"]:
			main.settings.set_value(k, shot.get("settings", {}).get(k, main.settings.DEFAULTS[k]))
		await process_frame
		await process_frame
		if shot.has("body"):
			# What the screen shows when the body is hurt, or healed and fed.
			var v = main.host.player.vitals
			if shot.body == "fed":
				v.health = 60.0
				v.satiety = 30.0
				for i in 3:
					await process_frame
				v.health = 75.0
				v.satiety = 55.0
			else:
				v.health -= 12.0
			for i in 4:
				await process_frame
		for m: Array in shot.get("markers", []):
			main.markers.add(Vector2i((main.player.position / CELL).floor().x, (main.player.position / CELL).floor().z) \
					+ Vector2i(m[0], m[1]), m[2])
		if shot.has("markers"):
			await process_frame
		if shot.get("test", false):
			main.hud.toggle_test()
			main.hud._settings.show_section(shot.get("section", "world"))
		if shot.get("freezes", false):
			# A few made-up freezes of every band for the log's window.
			main.hud.perf.freeze_log = [
				[62.0, 74.0, [["браузер", 40.0], ["отрисовка", 20.0]], ["сетка"], 310],
				[95.0, 128.0, [["отрисовка", 90.0], ["игра", 25.0]], ["факел", "шейдер 2"], 420],
				[140.0, 312.0, [["движок", 250.0], ["игра", 40.0]], ["запись", "мусор 93 → 61 МБ"], 380],
				[171.0, 58.0, [["браузер", 45.0]], [], 300],
			]
			# `many` times as many, for two-figure counts on the tabs.
			var one: Array = main.hud.perf.freeze_log.duplicate(true)
			for i in shot.get("many", 1) - 1:
				main.hud.perf.freeze_log.append_array(one.duplicate(true))
		if shot.get("menu", false):
			main.hud.toggle_menu()
			if shot.has("page"):
				main.hud.open_settings(shot.page)
				# The window keeps the section shown last: an earlier shot may have left another.
				if shot.page in ["settings", "test"]:
					main.hud._settings.show_section(shot.get("section", "game" if shot.page == "settings" else "world"))
				# Buttons of the window tapped once, by their vars (a two-tap one turns red).
				for b: String in shot.get("press", []):
					(main.hud._settings.get(b) as Button).pressed.emit()
		if shot.get("bag", false):
			main.hud.toggle_bag()
			# The window opens on the tab it was closed on; an earlier shot may have left the craft tab.
			main.hud.bag.show_tab("bag")
			main.hud.bag._let_go()
			var slot: int = shot.get("slot", 1)
			if shot.has("give"):
				main.host.player.give(shot.give, 1)
				for i in main.host.player.inventory.slots.size():
					var st = main.host.player.inventory.slots[i]
					if st != null and st[0] == shot.give:
						slot = i
			main.hud.bag._tap(slot, true)
			if shot.has("kind"):
				main.hud.bag._kinds.pick(shot.kind)
			if shot.get("destroy", false):
				main.hud.bag._destroy.pressed.emit()
		if shot.get("chest", false):
			main.session.placed.chest_items.add("resources:log", 3)
			main.session.placed.chest_items.add("plants:raspberry", 12)
			main.hud.open_chest()
			main.hud.bag._kinds.pick("")
			main.hud.bag._tap(0, false)
		if shot.get("chests", false):
			main.host.player.inventory.add("tools:chest", 1)
			main.player.facing = "e"
			main.props.put_from_bag("tools:chest")
			main.session.placed.chest_items.add("plants:raspberry", 12)
			main.hud.toggle_bag()
			main.hud.bag.show_tab("bag")
			main.hud.bag._kinds.pick("")
			main.hud.bag._tap(0, true)
		if shot.get("campfire", false):
			for e in main.session.placed.things:
				if main.session.placed.is_fire(e):
					main.hud.open_prop(e)
					break
		if shot.get("craft", false):
			_craft(shot.get("forge", false))
			if shot.has("recipe"):
				main.host.player.inventory.add("materials:cord", 2)
				main.hud.bag.craft._choose(shot.recipe)
			if shot.get("unknown", false) or shot.get("idle", false):
				while not main.host.workshop.queue.jobs.is_empty():
					main.host.workshop.queue.cancel(0)
				main.hud.bag.craft.refresh_now()
			if shot.get("unknown", false):
				main.host.workshop.knowledge.seen.clear()
				main.host.workshop.knowledge._known.clear()
				main.hud.bag.craft.refresh_now()
			if shot.get("closed", false):
				main.hud.toggle_bag()
			if shot.has("on"):
				for e in main.session.placed.things:
					if e.item == shot.on[0]:
						main.player.position = (Vector3(e.cell) + shot.on[1]) * main.CELL
				for i in 30:
					await process_frame
		if shot.get("test", false) or shot.get("menu", false) or shot.get("bag", false) or shot.get("chest", false) \
				or shot.get("craft", false) or shot.get("chests", false) or shot.get("campfire", false):
			# The window settles its height a frame after it opens (see InventoryWindow.refresh).
			for i in 3:
				await process_frame
		if shot.get("death", false):
			for st in [["resources:branch", 12], ["resources:fiber", 9], ["plants:raspberry", 23], ["tools:stone_axe", 1], ["resources:flint", 3]]:
				main.host.player.inventory.add(st[0], st[1])
			main.player.position += Vector3(14.0, 0.0, 9.0)
			main.player.position = places.flat_near(main.world, main.player.position)
			# A life of two and a half days, the second in this world.
			var ch = main.host.player
			ch.life = {"walked": 1840.0, "dug": 64.0, "built": 23.0, "trees": 3.0, "got": 212.0, "eaten": 17.0,
				"crafted": 6.0, "jumps": 148.0}
			main.session.clock.day += 2
			ch.born = main.session.clock.day + main.session.clock.time_of_day - 2.4
			ch.deaths = 1
			ch.best_days = 1.2
			main.host.player.vitals.health = 0.0
			main.host.player.vitals.satiety = 0.0
			main.host.player.vitals.hurt_by = "hunger"
			for i in 10:
				await process_frame
			if shot.get("revive", false):
				var fell: Array = main.host.player.death.at
				main.death_screen._revive(Vector3(fell[0] - 1.5, fell[1], fell[2] + 1.0))
				for i in 30:
					await process_frame
		var setup: Control = null
		var mods_off: String = main.settings.values.world_mods_off
		if shot.get("setup", false):
			# The bundles switched off for new worlds, for this shot only (not saved).
			main.settings.values.world_mods_off = shot.get("mods_off", mods_off)
			setup = main.WorldSetup.new(main)
			main.hud.add_child(setup)
			# A page of the screen other than the first ("mods").
			if shot.setup is String:
				setup._show_page(shot.setup)
			# The map of the setup screen is drawn a few rows a frame.
			for i in 120:
				await process_frame
		if shot.has("main_menu"):
			main._build_menu()
			# Painted sky only for "sky": the world is built already, so it would fade.
			main.menu._fading = shot.main_menu in ["sky", "loading", "part"]
			main.menu._backdrop.visible = shot.main_menu in ["sky", "loading", "part"]
			main.menu._clouds.visible = shot.main_menu in ["sky", "loading", "part"]
			await process_frame
			if shot.main_menu == "part":
				# Halfway through the clouds parting, held there for the shot.
				main.menu._part = 0.6
				main.menu._backdrop.modulate.a = 0.5
				main.menu.set_process(false)
				main.menu._clouds.queue_redraw()
			if shot.main_menu == "setup":
				main.menu._new_world()
				for i in 120:
					await process_frame
			if shot.main_menu == "worlds":
				_fake_saves()
				main.menu._open_worlds()
				await process_frame
			if shot.main_menu in ["single", "multi"]:
				# A phone's menu on a touch screen: «Создать сервер» is not there.
				main.menu.host_here = not shot.get("touch", false)
				main.menu._fill_page(shot.main_menu)
				if shot.get("press_host", false):
					main.menu._buttons.host.pressed.emit()
				await process_frame
			if shot.main_menu in ["host", "host-running"]:
				if shot.main_menu == "host-running":
					# A server for real, on a port of its own, stopped after the shot.
					main.hosted = main.LocalHost.host({"title": "Дача", "port": 7799, "max_players": 8,
						"password": "", "world": "", "seed_value": main.world_seed, "settings": main.world_options}, root)
					for i in 3:
						await process_frame
				main.menu._fill_page("multi")
				main.menu.open_host()
				for i in 3:
					await process_frame
			if shot.main_menu == "join":
				_fake_servers()
				main.menu._fill_page("multi")
				main.menu.open_join("", shot.get("error", ""))
				await process_frame
			await process_frame
		if shot.get("map", false):
			main.hud.map_view.open()
			main.hud.map_view.zoom_index = shot.get("map_zoom", main.hud.map_view.FIRST_ZOOM)
			main.hud.map_view.redraw()
			if shot.has("map_tap"):
				var mv: Control = main.hud.map_view
				mv.tap(mv.point_of(Vector2(main.hud.minimap.player_cell + Vector2i(shot.map_tap[0], shot.map_tap[1]))))
			await process_frame
			await process_frame
		if shot.get("revive", false):
			# The key hints come back with the interface; they would hide the sack.
			main.hud.show_keys(false)
			await process_frame
		if not shot.get("hud", true):
			main.hud.visible = false
			await process_frame
			await process_frame
		var img := root.get_texture().get_image()
		main.hud.visible = true
		print("player at ", main.player.position)
		img.save_png(out_dir.path_join(shot_name + ".png"))
		# Frames of the sun moving at the game's speed, 60 a second, to see how the
		# shadows move: <name>-01.png and on.
		for i in shot.get("sweep", 0):
			main.session.clock.time_of_day += shot.get("sweep_step", 1.0) / (main.session.clock.DAY_LENGTH * 60.0)
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png(out_dir.path_join("%s-%02d.png" % [shot_name, i + 1]))
		main.creatures.set_process(true)
		if shot.has("keys"):
			_hold(shot.keys, false)
		if setup != null:
			setup.queue_free()
			main.settings.values.world_mods_off = mods_off
		if shot.has("main_menu"):
			if main.hosted != null:
				main.hosted.command("stop")
				main.hosted.queue_free()
				main.hosted = null
			main.menu.get_parent().queue_free()
			main.menu = null
			main.hud.visible = true
		if shot.get("map", false):
			main.hud.map_view.close()
		main.host.player.sacks.clear()
		main.markers.from_dict({})
		print("saved ", shot_name)
		for e in added_fires:
			main.session.placed._remove(e)
		added_fires.clear()
		if not places.out_fire.is_empty():
			places.out_fire.lit = true
			main.session.placed.lit_changed.emit(places.out_fire)
			places.out_fire = {}
		if shot.get("fire_blocks", false) or shot.get("copper_moss", false):
			places.unwall_cells(main.world)
		if shot.get("wall", false) or shot.get("trench", false):
			places.unwall(main.world, Vector3i((main.player.position / CELL).floor()))
		main.settings.set_value("ui_size", shot.get("ui_size", 2))
		main.settings.set_value("control_size", shot.get("control_size", 2))
		if shot.get("menu", false):
			main.hud.toggle_menu()
		if shot.get("test", false):
			main.hud.toggle_test()
		if shot.get("bag", false) or shot.get("chest", false) or shot.get("chests", false) or shot.get("campfire", false) \
				or (shot.get("craft", false) and not shot.get("closed", false)):
			main.hud.toggle_bag()
		if shot.get("craft", false):
			while not main.host.workshop.queue.jobs.is_empty():
				main.host.workshop.queue.cancel(0)
			for e in main.session.placed.things.duplicate():
				if e.item in ["tools:workbench", "tools:kiln", "tools:forge"]:
					main.session.placed.take_up(main.host.player, e)
			main.host.player.inventory.take_all()
		if shot.get("chest", false):
			main.session.placed.chest_items.take_all()
		if shot.get("gather", false) or shot.get("work", false):
			main.host.player.inventory.take_all()
			main.host.player.vitals.revive(1.0)
		if shot.get("death", false):
			main.death_screen._revive(main.host.player.home)
		if shot.get("work", false):
			main.settings.set_value("pickup", 0)
			main.controls.hold("")
			main.controls._cursor_clock = 0.0
	quit()


## By the spawn: a workbench and a kiln set down in front of the player, what the first
## tools are made of in the bag, an axe being made and a pickaxe queued, the craft tab
## open at the workbench.
## With `forge`, a forge too, to the north, with ore, charcoal and bars in the bag, a copper
## bar being smelted, the craft tab open at the forge.
func _craft(forge := false) -> void:
	var inv = main.host.player.inventory
	for st in [["resources:fiber", 14], ["resources:branch", 16], ["resources:flint", 3], ["resources:log", 2], ["resources:clay", 6],
			["tools:workbench", 1], ["tools:kiln", 1], ["tools:chest", 1]]:
		inv.add(st[0], st[1])
	main.player.facing = "s"
	main.props.put_from_bag("tools:workbench")
	main.player.facing = "e"
	main.props.put_from_bag("tools:kiln")
	main.player.facing = "w"
	main.props.put_from_bag("tools:chest")
	var station := "tools:workbench"
	var recipe := "materials:cord"
	if forge:
		for st in [["tools:forge", 1], ["materials:copper_ore", 6], ["materials:charcoal", 3], ["materials:copper_bar", 6], ["materials:planks", 2]]:
			inv.add(st[0], st[1])
		main.player.facing = "n"
		main.props.put_from_bag("tools:forge")
		station = "tools:forge"
		recipe = "tools:copper_bar"
	main.player.facing = "s"
	var shop = main.host.workshop
	shop.start(Crafting.get_recipe(recipe), 2)
	shop.queue.jobs[0].left = 0.5
	shop.queue.step(0.25, func(_r: Dictionary) -> bool: return true)
	for e in main.session.placed.things:
		if e.item == station:
			main.hud.open_prop(e)


## Puts the tool `h.tool` in the left hand and a stone block (or `h.other`) in the
## right, the right one in use if `h.right`, turns the player to `h.facing` and holds the work `h.work`
## still at its wind-up, or at its strike if `h.strike`.
func _hands(h: Dictionary) -> void:
	# On flat grass nearby, unless the shot keeps its spot (`h.stay`).
	if not h.get("stay", false):
		main.player.position = places.flat_near(main.world, main.player.position)
	var inv = main.host.player.inventory
	var other: String = h.get("other", "resources:stone")
	inv.add(h.tool, 1)
	inv.add(other, 10 if other == "resources:stone" else 1)
	# The tool in the left hand, a stone block in the right one; the tool's hand in use
	# unless the shot says the right one.
	main.controls.put_in_hand(other, 1, false)
	main.controls.put_in_hand(h.tool, 0, false)
	if h.get("right", false):
		main.controls.set_active(1)
	await process_frame
	# The sheet with the new things in hand is built over a few frames.
	while main.player._build != null:
		await process_frame
	main.player.facing = h.facing
	if h.has("work"):
		main.player.work(h.work, 1000.0)
		if h.get("strike", false):
			main.player._work_time = 600.0
	await process_frame
	await process_frame


## By the spawn: a floor painted, a pit dug, berries knocked down, the tools taken but
## for those by the chest left lying, and the frame on what the action button digs.
func _work() -> void:
	var c = main.controls
	var w = main.world
	main.settings.set_value("pickup", 3)
	main.settings.give_tools()
	main.host.player.inventory.add("resources:stone", 20)
	var f: Vector3i = c.feet()
	c.put_in_hand("resources:stone")
	c.brush = 2
	var spot := f + Vector3i(-4, 0, -4)
	spot.y = w.surface_y(spot.x, spot.z)
	c.place_at(spot, Vector3i.UP)
	c.brush = 0
	c.hold("tools:wooden_shovel")
	for i in 3:
		var cell := f + Vector3i(2 + i, 0, -5)
		cell.y = w.surface_y(cell.x, cell.z) - 1
		c._cooldown = 0.0
		c.dig_at(cell, Vector3i.UP)
	var bush := f + Vector3i(0, 0, -7)
	bush.y = w.surface_y(bush.x, bush.z)
	if not w.bushes.has(bush):
		w.add_bush(bush, Bushes.first(true))
		main.chunks.remesh_chunk(WorldData.chunk_key(bush.x, bush.z))
	c.hold("tools:wooden_sword")
	main.gathering.gather({"bush": bush})
	# A patch of grass cut by the scythe west of the player: the near row cut once (short
	# grass), the next cut twice (dirt with fibre on it), the far row cut twice and sown
	# with grain (ears).
	c.put_in_hand("tools:stone_scythe", 1, false)
	main.host.player.inventory.add("plants:grain", 5)
	var mown := 0
	for i in 15:
		var cell := f + Vector3i(-7 + i % 5, 0, 1 + i / 5)
		cell.y = w.surface_y(cell.x, cell.z) - 1
		var one: Array[Vector3i] = [cell]
		for k in 1 if i < 5 else 2:
			if main.actions.can_mow(cell) and main.actions.mow(main.host.player, one):
				mown += 1
		if i >= 10:
			main.actions.plant_at(main.host.player, "plants:grain", cell)
	print("grass cut %d times" % mown)
	c.put_in_hand("tools:wooden_shovel", 0, false)
	c.set_active(1)
	main.player.facing = "s"
	main.cursor.show_cells(c._front_preview(), true)
	c._cursor_clock = 1000.0


## On the felled clearing: berry bushes by the player, the things lying nearest picked
## up, a bush picked, some blocks dug, and the character a little tired and hungry.
func _gather() -> void:
	var w = main.world
	var at := Vector3i((main.player.position / CELL).floor())
	for i in 3:
		var cell := at + Vector3i(-6 + i * 3, 0, 5)
		w.add_bush(cell, [Bushes.first(true), Bushes.first(true, 1), Bushes.first(false)][i])
		main.chunks.remesh_chunk(WorldData.chunk_key(cell.x, cell.z))
	var a = main.actions
	var who = main.host.player
	a._from_bush(who, at + Vector3i(-6, 0, 5))
	a._from_bush(who, at + Vector3i(0, 0, 5))
	for key: Vector2i in w.drops.keys():
		var list: Array = w.drops[key]
		for i in range(list.size() - 1, -1, -1):
			if i < list.size() and list[i][1].x < main.player.position.x - 1.0:
				a.pick_up(who, key, i)
	main.host.player.inventory.add("resources:dirt", 4)
	main.host.player.inventory.add("resources:stone", 5)
	main.host.player.vitals.stamina = 45.0
	main.host.player.vitals.satiety = 35.0
	main.hud.refresh_counts()


## The nearest spot to `p` with level dry ground and no trees for 7 cells around.
func _hold(keys: Array, down: bool) -> void:
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.pressed = down
		Input.parse_input_event(ev)


func _weather_index(id: String) -> int:
	for i in main.session.clock.WEATHERS.size():
		if main.session.clock.WEATHERS[i].id == id:
			return i
	return 0


## Puts the sparrows round the player, every third in the air and every third in a
## crown when there is a tree near, and holds them there until the shot is taken.
## One of every species on the land in rows before the player, walking (its second
## frame), or, for `water`, every swimmer in the water near the player; a species
## with tints once in each of them.
func _place_zoo(water: bool) -> void:
	var life = main.session.wildlife
	var p: Vector3 = main.player.position
	var kinds: Array = []
	for kind in AiRules.SPECIES:
		if kind != AiRules.HUMAN and AiRules.SPECIES[kind].swims == water:
			for t in maxi(1, AiRules.SPECIES[kind].tints.size()):
				kinds.append([kind, t])
	for c in life.animals:
		c.pos = p + Vector3(60.0, 0.0, 60.0)
		c.target = c.pos
		c.think = 100.0
	var spots: Array[Vector3] = []
	if water:
		# The water cells nearest the player, two cells apart.
		var cells: Array[Vector3] = []
		for dz in range(-14, 15):
			for dx in range(-14, 15):
				var at := p + Vector3(dx, 0.0, dz) * CELL
				var y: float = life.water_top(at.x, at.z)
				if y > 0.0 and dx % 2 == 0 and dz % 2 == 0:
					cells.append(Vector3(at.x, y - life.DIP * CELL, at.z))
		cells.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(p) < b.distance_to(p))
		spots = cells
	else:
		for i in kinds.size():
			var at := p + Vector3(-4.5 + (i % 5) * 2.2, 0.0, -1.2 + (i / 5) * 2.0)
			spots.append(Vector3(at.x, life.ground(at.x, at.z), at.z))
	var i := 0
	for kt in kinds:
		if i >= spots.size():
			break
		var c = life._add(kt[0], spots[i])
		c.tint = kt[1]
		c.think = 100.0
		c.facing = 1.0 if i % 2 == 0 else -1.0
		c.moving = true
		c.left = i % 2 == 0
		i += 1
	main.creatures._process(0.0)
	main.creatures.set_process(false)


func _place_birds() -> void:
	var life = main.session.wildlife
	var p: Vector3 = main.player.position
	var i := 0
	for c in life.animals:
		if c.kind != "animals:sparrow":
			continue
		c.pos = p + Vector3(-3.0 + (i % 5) * 1.4, 0.0, -2.5 + (i / 5) * 1.2)
		c.pos.y = life.ground(c.pos.x, c.pos.z)
		c.flying = false
		c.perched = false
		c.target = c.pos
		var tree: Variant = life._tree_spot(AiRules.SPECIES[c.kind], p, 7.0) if i % 3 == 2 else null
		if i % 3 == 1:
			c.pos.y = life._canopy(c.pos.x, c.pos.z) + 1.0 + (i % 4) * 0.5
			c.flying = true
			c.target = c.pos + Vector3(5.0, 0.0, 0.0)
		elif tree != null:
			c.pos = tree
			c.perched = true
			c.target = c.pos
		c.facing = 1.0 if i % 2 == 0 else -1.0
		c.think = 100.0
		i += 1
	main.creatures._process(0.0)
	main.creatures.set_process(false)
