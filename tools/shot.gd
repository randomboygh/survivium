extends SceneTree
## Renders the game and saves screenshots, for looking at visual changes without a
## browser. Needs a display (not --headless), for example:
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tools/shot.gd -- /tmp/shots [--phone] [name ...]
## `--phone` lays the window out as a phone's screen (fractional scales, CameraRig.turning).
## `--keys` saves no pictures (it runs headless too): each shot's screen is searched for
## a key left untranslated (Lang.keys_shown), each one printed as `KEYS <shot>: <node>: <text>`.
## Each shot sets the time of day, season, weather and an offset of the player from
## the spawn point, waits for the weather to settle and saves <name>.png. The spots are
## searched in cells (half a world unit); the player stands in world units.

const Items := preload("res://src/shared/content/items.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const ModFiles := preload("res://src/shared/content/mod_files.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const Shots := preload("res://tools/shot/shots.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
const Places := preload("res://tools/shot/places.gd")
const SettingsScript := preload("res://src/client/settings.gd")


const WorldData := preload("res://src/shared/world/world_data.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const Plants := preload("res://src/shared/content/plants.gd")
const TestGround := preload("res://src/shared/world/test_ground.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")
const CELL := 0.5
const TEST_SAVES := "user://shot_ground"

var main: Node
var out_dir := "user://shots"
var names: Array = []
var phone := false
var keys_only := false
## The spots and scenes of the shots (see tools/shot/places.gd).
var places := Places.new()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	phone = "--phone" in args
	args.erase("--phone")
	keys_only = "--keys" in args
	args.erase("--keys")
	# `--lang en`: the shots in that language (else Russian, as the game is written).
	SettingsScript.language_override = "ru"
	var at := args.find("--lang")
	if at >= 0 and at + 1 < args.size():
		SettingsScript.language_override = args[at + 1]
		args.remove_at(at + 1)
		args.remove_at(at)
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
	var list = main.link.ServerList
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
		main.settings.values.shadow_on_things = shot.get("shadow_on_things", main.settings.DEFAULTS.shadow_on_things)
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
		if shot.get("walls", false):
			main.player.position = places.walls(main.world, main.player.position)
		if shot.get("strata", false):
			main.player.position = places.strata(main.world, main.player.position)
		if shot.has("openings"):
			main.player.position = places.openings(main.world, main.player.position, shot.openings == "storage")
		if shot.get("fences", false):
			main.player.position = places.fences(main.world, main.player.position)
		if shot.has("signs"):
			main.player.position = places.signs(main.world, main.player.position, shot.signs)
		if shot.has("lit_room"):
			main.player.position = places.lit_room(main.world, main.player.position, shot.lit_room == "open",
				shot.get("lamps", false), shot.get("door_first", false))
		if shot.get("furniture", false):
			main.player.position = places.furniture(main.world, main.player.position)
		if shot.get("plan", false):
			main.player.position = places.plan(main.world, main.player.position)
		if shot.get("forms", false):
			main.player.position = places.forms(main.world, main.player.position, shot.get("only", 0))
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
		if shot.has("steep"):
			main.player.position = places.steep(main.world, main.player.position)
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
		# Afloat in a vessel (Character.riding): launched where the player is; the body
		# rises onto the water in its first step.
		if shot.has("ride"):
			var hp = main.host.player
			hp.teleport(main.player.position)
			var turn := 0.6
			var v: Dictionary = main.session.actions.vessels.launch(shot.ride, main.player.position, turn)
			hp.riding = shot.ride
			hp.vessel = v.id
			hp.seat = 0
			main.character.riding = shot.ride
			main.character.vessel = v.id
		if shot.has("find"):
			main.player.position = places.find(main.world, main.player.position, shot.find)
		if shot.has("patch"):
			main.player.position = places.find_patch(main.world, main.player.position, shot.patch)
			main.chunks.build_around()
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
		if shot.get("pick_fiber", false):
			places.pick_fiber(main.world, Vector3i((main.player.position / CELL).floor()) + Vector3i(0, 0, -3))
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
		# The animals' minds over them (F4, AiDebug).
		main.settings.set_ai_debug(shot.get("ai", false))
		main.hud.show_keys(shot_name == "ui")
		if shot.get("lab", false):
			places.lab(main.world, Vector3i((main.player.position / CELL).floor()))
			main.roof.build(main.world)
		if shot.get("wall", false) and not shot.wall is String:
			places.wall(main.world, Vector3i((main.player.position / CELL).floor()))
			main.roof.build(main.world)
		if shot.get("trench", false):
			main.player.position = places.trench(main.world, Vector3i((main.player.position / CELL).floor()))
		if shot.get("room", false):
			places.room(main.world, Vector3i((main.player.position / CELL).floor()))
		if shot.has("walk_into"):
			# The player walks into what stands that way (x east, y south) until it stops them.
			var body = main.player.body
			body.move_input = Vector2(shot.walk_into[0], shot.walk_into[1])
			for i in 90:
				main.player.position = body.step(main.player.position, 1.0 / 60.0, false)
			body.move_input = Vector2.ZERO
			main.player.facing = shot.get("facing", "s")
		if shot.get("face_water", false):
			# Thirsty and turned to the water beside: the action button says «Попить».
			main.host.player.vitals.water = 20.0
			for way: String in ["s", "sw", "w", "nw", "n", "ne", "e", "se"]:
				main.player.facing = way
				var ahead: Vector3 = main.actions.water_ahead(main.player.position,
					Vector2(main.character.facing_step()).normalized(), main.actions.DRINK_REACH)
				if ahead.is_finite():
					break
		if shot.has("cut"):
			main.chunks.manual_level = main.player.level() + int(shot.cut)
			main.chunks.update_cut(0.0)
		# Let snow, wetness, tints and particles settle.
		for i in 90:
			await process_frame
			main.session.clock.snow = shot.get("snow", 1.0) if main.session.clock.season == 3 else 0.0
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
		if shot.has("shadow_zoo"):
			await _place_shadow_zoo(shot.shadow_zoo)
		if shot.get("trap", false):
			_place_trap()
		if shot.has("put_fire"):
			var spot: Vector3i = main.session.placed.spot_near(main.player.position + Vector3(shot.put_fire[0], 0.0, shot.put_fire[1]) * main.CELL)
			if spot.y >= 0:
				added_fires.append(main.session.placed.put(main.session.placed.CAMPFIRE, spot, null))
		# Things set down round the player: [item, offset in cells].
		for put: Array in shot.get("put", []):
			var spot: Vector3i = main.session.placed.spot_near(main.player.position + Vector3(put[1][0], 0.0, put[1][1]) * main.CELL)
			if spot.y >= 0:
				added_fires.append(main.session.placed.put(put[0], spot, null))
		for i in 3:
			await process_frame
		main.effects.pick_shadow_fires(PixelView.screen_plane(main.player.position))
		for f: Dictionary in main.effects.fires:
			f.light.light_energy = main.effects.fire_energy(f, main.sky)
			if f.light.shadow_enabled:
				PixelView.twin_follow(f.light, f.light.light_energy / main.effects.shadow_energy)
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
			if shot.has("burnt"):
				# The light in hand burned this share of its time (Character.burning).
				var held: String = main.character.light_held()
				for who in [main.character, main.host.player]:
					who.burning[held] = [Items.burns(held) * float(shot.burnt)]
		if shot.has("cast"):
			await _cast(shot.cast == "bite")
		if shot.has("pit"):
			places.pit_round(main.world, Vector3i((main.player.position / CELL).floor()), int(shot.pit))
			for i in 30:
				await process_frame
		if shot.get("wall", "") is String and shot.get("wall", "") == "north":
			# Right behind the player where they stand now.
			places.wall(main.world, Vector3i((main.player.position / CELL).floor()), true)
			main.roof.build(main.world)
			for i in 20:
				await process_frame
		if shot.has("prey"):
			# One animal [kind, east, south] of the player, standing still.
			var life = main.session.wildlife
			for c in life.animals:
				c.pos = main.player.position + Vector3(60.0, 0.0, 60.0)
				c.target = c.pos
				c.think = 100.0
			var at: Vector3 = main.player.position + Vector3(shot.prey[1], 0.0, shot.prey[2]) * CELL
			at.y = life.ground(at.x, at.z)
			var one = life._add(shot.prey[0], at)
			one.think = 100.0
			one.facing = -1.0
			if shot.has("flight"):
				# Something shot on its way to the animal, caught halfway.
				var from: Vector3 = main.player.position + Vector3(0.0, 0.6, 0.0)
				main.props.fly_shot([shot.flight, from, at + Vector3(0.0, 0.3, 0.0), 12.0])
				for i in 30:
					await process_frame
		if shot.has("beasts"):
			# Animals [kind, east, south, state] of the player, standing still in that state
			# (a warning, a bite) and turned toward the player.
			var life = main.session.wildlife
			for c in life.animals:
				c.pos = main.player.position + Vector3(60.0, 0.0, 60.0)
				c.target = c.pos
				c.think = 100.0
			for b: Array in shot.beasts:
				var at: Vector3 = main.player.position + Vector3(b[1], 0.0, b[2]) * CELL
				at.y = life.ground(at.x, at.z)
				var one = life._add(b[0], at)
				one.think = 100.0
				one.facing = -signf(b[1])
				one.state = b[3]
			for i in 10:
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
			if not shot.has("ride"):
				main.player.position = places.flat_near(main.world, main.player.position)
			_hold(shot.keys, true)
			for i in int(shot.get("key_frames", 12)):
				await process_frame
		# Messages fade after a few seconds, longer than the settling above takes here.
		if shot.has("burst"):
			main.effects.burst(main.player.position + Vector3(0.6, 0.4, 0.0), main.Mat.index(shot.burst))
			for i in 3:
				await process_frame
		if shot.has("fuel"):
			# A campfire just north of the player, every fire this full, its flames given a
			# while to follow.
			var spot: Vector3i = main.session.placed.spot_near(main.player.position + Vector3(-0.5, 0.0, -3.0) * CELL)
			if spot.y >= 0:
				main.session.placed.put(main.session.placed.CAMPFIRE, spot)
			for e: Dictionary in main.session.placed.things:
				if main.session.placed.is_fire(e):
					e.fuel = Items.get_item(e.item).fuel_max * float(shot.fuel)
					main.session.placed.fuel_changed.emit(e)
			await create_timer(1.5).timeout
		if shot.get("toast", false):
			main.hud.toast("[summer_has_come]")
			await process_frame
			await process_frame
		if shot.get("chat_lines", false):
			# The chat's lines come up as notifications do, and the host is told of the
			# server's comings and goings in a list of its own under the toasts.
			for l: Array in [[2, "Боря", "Привет! Пойдём к реке?"], [3, "Вова", "Я за вами, только дрова соберу"],
					[2, "Боря", "Жду у моста"]]:
				main.hud.chat.hear(l[0], l[1], l[2])
			main.hud.server_note(Lang.line("[s_joined_the_server_for]", ["Гена"]))
			main.hud.server_note(Lang.line("[s_lost_the_connection_the]", ["Вова", 30]))
			await create_timer(1.0).timeout
		main.settings.set_value("ui_size", shot.get("ui_size", 2))
		main.settings.set_value("control_size", shot.get("control_size", 2))
		for k in ["minimap_size", "level_buttons", "camera_buttons", "layer_front_from",
				"layer_front_stretch", "layer_above_from", "layer_above_stretch", "layer_density", "layer_line", "cut_depth", "solo_social", "crt", "second_hand"]:
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
			main.hud.settings_menu().show_section(shot.get("section", "world"))
		if shot.get("freezes", false):
			# A few made-up freezes of every band for the log's window.
			main.hud.perf.freeze_log = [
				[62.0, 74.0, [["browser", 40.0], ["drawing", 20.0]], ["mesh"], 310],
				[95.0, 128.0, [["drawing", 90.0], ["game", 25.0]], ["torch", "shader 2"], 420],
				[140.0, 312.0, [["engine", 250.0], ["game", 40.0]], ["save", "garbage 93 → 61 MB"], 380],
				[171.0, 58.0, [["browser", 45.0]], [], 300],
			]
			# `many` times as many, for two-figure counts on the tabs.
			var one: Array = main.hud.perf.freeze_log.duplicate(true)
			for i in shot.get("many", 1) - 1:
				main.hud.perf.freeze_log.append_array(one.duplicate(true))
		if shot.has("own_mods"):
			# As on a phone: the settings name the folder of one's own mods (nothing is read from it).
			ModFiles.extra_dir = shot.own_mods
			ModFiles._extra = {}
		if shot.get("playtest", false):
			# As if on a server for checking: the «Тестирование» page shows such a server's rows.
			main.link.join_url = "ws://shot"
			main.link.welcome = {"playtest": true}
		if shot.get("menu", false):
			main.hud.toggle_menu()
			if shot.has("page"):
				main.hud.open_settings(shot.page)
				# The window keeps the section shown last: an earlier shot may have left another.
				if shot.page in ["settings", "test", "report"]:
					main.hud.settings_menu().show_section(shot.get("section",
							{"settings": "game", "test": "world", "report": "place"}[shot.page]))
					if shot.get("menu_end", false):
						# The bottom of the section.
						await process_frame
						main.hud.settings_menu()._scroll.scroll_vertical = 100000
				# «Витрина интерфейса» on tab `gallery` (UiGallery.SECTIONS).
				if shot.has("gallery"):
					# The one an earlier shot opened goes first (it would show through the shade).
					for c in main.hud.get_children():
						if c.get_script() != null and (c.get_script() as Script).resource_path.ends_with("ui_gallery.gd"):
							c.close()
					var gallery: Control = main.hud.settings_menu().open_gallery()
					await process_frame
					gallery.show_section(shot.gallery)
					await process_frame
				# Buttons of the window tapped once, by their vars (a two-tap one turns red).
				for b: String in shot.get("press", []):
					(main.hud.settings_menu().get(b) as Button).pressed.emit()
		if shot.get("kit", false):
			main.settings.give_tools()
			await process_frame
			await process_frame
		if shot.has("wear"):
			for worn: String in (shot.wear if shot.wear is Array else [shot.wear]):
				main.host.player.give(worn, 1)
				main.host.player.wear(main.host.player.inventory.slots.find_custom(
					func(st) -> bool: return st != null and st[0] == worn))
			main.host.player.inventory.add("resources:fiber", 30)
			main.host.player.inventory.add("resources:stone", 40)
			await process_frame
			await process_frame
		if shot.get("sleepy", false):
			main.host.player.vitals.energy = 0.0
			main.view.sway = 1.0
			for i in 4:
				await process_frame
		if shot.get("visions", false):
			main.host.player.vitals.see_visions(200.0)
			main.view.trip = 1.0
			for i in int(shot.get("frames", 4)):
				await process_frame
		if shot.get("asleep", false):
			# Asleep by the campfire: the dimmed screen, the moon on the clock.
			main.host.player.vitals.energy = 40.0
			main.host.player.vitals.asleep = true
			main.hud.vitals.pinned = true
			for i in 4:
				await process_frame
		if shot.has("bed"):
			# A mat (and a bedroll) set down in front, tapped: the player lies in it asleep.
			main.player.position = places.flat_near(main.world, main.player.position + Vector3(14.0, 0.0, 9.0))
			for i in 3:
				await process_frame
			for bed: String in shot.bed:
				main.host.player.inventory.add(bed, 1)
				main.player.facing = "e" if bed == shot.bed[0] else "s"
				main.props.put_from_bag(bed)
				for i in 3:
					await process_frame
			main.host.player.vitals.energy = 10.0
			for e in main.placed.things:
				if e.item == shot.bed[0]:
					main.gathering.gather({"prop": e})
			# Long enough for the letters "z" over the sleeper to be in the air together.
			var since := Time.get_ticks_msec()
			while Time.get_ticks_msec() - since < 3500:
				await process_frame
		if shot.has("skills"):
			# Skills learned: {role: level}, a little on the way to the next.
			var reg = load("res://src/shared/content/skills.gd")
			for role: String in shot.skills:
				var sk: Dictionary = reg.of_role(role)
				main.host.player.skills.gain(role, lerpf(reg.need(sk, shot.skills[role]), reg.need(sk, shot.skills[role] + 1), 0.4))
			for i in 8:
				await process_frame
		if shot.has("level_up"):
			# A skill rose to a new level: the gold edges, the stars, the notice; caught mid-way.
			var reg2 = load("res://src/shared/content/skills.gd")
			main.character.skills.leveled.emit(reg2.of_role(shot.level_up).id, 3)
			var since2 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - since2 < 450:
				await process_frame
		if shot.has("thirst"):
			# A thirsty body: the water bar low and red.
			main.host.player.vitals.water = shot.thirst
			main.hud.vitals.pinned = true
			for i in 4:
				await process_frame
		if shot.has("chill"):
			# A body chilled and wet: the warmth bar low and blue, the drop by it.
			var v = main.host.player.vitals
			v.warmth = shot.chill[0]
			v.wet = shot.chill[1]
			main.hud.vitals.pinned = true
			for i in 4:
				await process_frame
		if shot.has("tired"):
			# Out of breath: the stamina bar red, the bolt in the last column.
			main.host.player.vitals.stamina = 3.0
			main.hud.vitals.pinned = true
			for i in 2:
				await process_frame
		if shot.has("hold"):
			# Things in the hands: [left, right].
			for h in 2:
				main.host.player.give(shot.hold[h], 1)
			await process_frame
			await process_frame
			for h in 2:
				main.controls.put_in_hand(shot.hold[h], h)
		if shot.has("team"):
			_fake_team(main, shot.team)
			# The figures take a few frames to come in.
			for i in 10:
				await process_frame
			if shot.team == "person":
				var screen: Vector2 = main.view.camera.unproject_position(main.others.people[3].figure.global_position)
				main.hud.person.show_person(3, "Вова", screen * main.view.view_scale + main.view.container.global_position)
			if shot.get("team_panel", false):
				main.hud.open_team()
			for i in 3:
				await process_frame
		if shot.has("land"):
			_fake_land(main, shot.land)
			for i in 6:
				await process_frame
			if shot.get("rights", false):
				# Others may also gather the harvest here; the land in blue.
				main.session.territory.set_rights(0, 255 & ~8, 1 | 16)
				main.session.territory.set_color(0, 1)
				for i in 6:
					await process_frame
				main.hud.toggle_bag()
				main.hud.bag.show_tab("land")
				for i in 6:
					await process_frame
				if shot.get("land_end", false):
					# The bottom of the tab: the colours of the land.
					main.hud.bag.land_page.scroll_vertical = 100000
					for i in 3:
						await process_frame
			if shot.get("decay", false):
				# The land is another's, left long ago: the next tick weakens it and lets
				# its farther squares go; the player stands in it and looks at the tab.
				var t = main.session.territory
				var claim: Dictionary = t.claims.values()[0]
				claim.by = 7
				claim.name = "Вова"
				claim.seen = t.time - main.session.rules.territory_abandon_hours * 3600.0 - 1.0
				for i in 10:
					await process_frame
				main.hud._on_land_entered(main.land.here(), false)
				main.hud.toggle_bag()
				main.hud.bag.show_tab("land")
				for i in 6:
					await process_frame
		if shot.get("bag", false):
			main.hud.toggle_bag()
			# The window opens on the tab it was closed on; an earlier shot may have left the craft tab.
			main.hud.bag.show_tab("bag")
			main.hud.bag._let_go()
			var slot: int = shot.get("slot", 1)
			if shot.get("food", false):
				# Food at each stage of going off: fresh, half, nearly spoiled, and rot.
				var inv = main.host.player.inventory
				inv.take_all()
				var ages := [["animals:raw_meat", 3, 0], ["animals:roasted_meat", 2, 5000], ["plants:raspberry", 12, 8600],
					["plants:apple", 4, 2000], ["core:rot", 5, 0]]
				for i in ages.size():
					inv.slots[i] = [ages[i][0], ages[i][1], ages[i][2]] if ages[i][2] > 0 else [ages[i][0], ages[i][1]]
				inv.changed.emit()
				slot = 1
			if shot.get("quality", false):
				# Things of each grade of quality, the best axe chosen.
				var inv = main.host.player.inventory
				inv.take_all()
				var things := [["tools:copper_axe", 1, 92], ["resources:log", 6, 15], ["resources:stone", 14, 38],
					["materials:planks", 8, 55], ["plants:raspberry", 9, 72], ["animals:roasted_meat", 2, 88],
					["tools:wooden_pickaxe", 1, 30], ["resources:fiber", 12, 50]]
				for i in things.size():
					inv.slots[i] = Inventory.stack(things[i][0], things[i][1], 0, null, things[i][2])
				inv.changed.emit()
				slot = 0
				await process_frame
				await process_frame
			if shot.has("give"):
				main.host.player.give(shot.give, 1)
				for i in main.host.player.inventory.slots.size():
					var st = main.host.player.inventory.slots[i]
					if st != null and st[0] == shot.give:
						slot = i
				# The client's copy of the bag takes it with the next frame.
				await process_frame
				await process_frame
			if shot.has("worn"):
				# The tool in the slot worn by so many swings: the panel's spanner shows.
				var inv = main.host.player.inventory
				var st = inv.slots[slot]
				inv.slots[slot] = [st[0], st[1], shot.worn]
				inv.changed.emit()
				await process_frame
				await process_frame
			if slot >= 0:
				main.hud.bag._tap(slot)
			if shot.has("kind"):
				main.hud.bag._kinds.pick(shot.kind)
			if shot.get("destroy", false):
				main.hud.bag._destroy.pressed.emit()
			if shot.has("person"):
				main.hud.bag._tap_person(shot.person)
		if shot.get("openings", "") == "storage":
			# The storage by the player, a few things in each, their strips in the bag's list.
			for e: Dictionary in main.session.placed.things:
				if e.items != null:
					e.items.add("resources:log", 2)
					e.items.add("plants:apple", 5)
			main.hud.bag._kinds.pick("")
			main.hud.bag.refresh_state()
			for i in 4:
				await process_frame
			var grids: Array = main.hud.bag._chest_grids
			print("storage shown: ", main.hud.bag._chests.map(func(e: Dictionary) -> String: return e.item))
			# From the strip of the `storage_at`th (the second: the camp's chest by the spawn may come first).
			if not grids.is_empty():
				var k: int = mini(shot.get("storage_at", 1), grids.size() - 1)
				main.hud.bag._scroll.scroll_vertical = int(grids[k].line.position.y) - 4
			for i in 4:
				await process_frame
		if shot.get("chest", false):
			main.session.placed.chest_items.add("resources:log", 3)
			main.session.placed.chest_items.add("plants:raspberry", 12)
			main.hud.open_chest()
			main.hud.bag._kinds.pick("")
			main.hud.bag.refresh_state()
			main.hud.bag._tap(0, main.hud.bag._chests.find(main.hud.bag._chest_entry))
		if shot.get("chests", false):
			var box: String = shot.get("box", "tools:chest")
			main.host.player.inventory.add(box, 1)
			main.player.facing = "e"
			main.props.put_from_bag(box)
			main.session.placed.chest_items.add("plants:raspberry", 12)
			main.hud.toggle_bag()
			main.hud.bag.show_tab("bag")
			main.hud.bag._kinds.pick("")
			main.hud.bag._tap(0)
			if shot.get("take_all", false):
				# Things in the bag and more in the chest, then «Забрать всё».
				for st in [["resources:stone", 7], ["resources:fiber", 5], ["tools:stone_axe", 1]]:
					main.host.player.inventory.add(st[0], st[1])
				for st in [["resources:branch", 9], ["resources:flint", 4], ["plants:raspberry", 30]]:
					main.session.placed.chest_items.add(st[0], st[1])
				for i in 4:
					await process_frame
				print("bag before: ", main.host.player.inventory.slots)
				if shot.has("wear"):
					main.hud.bag._lock = false
					main.hud.bag._put_all_in_chest()
					for i in 4:
						await process_frame
					print("bag put: ", main.host.player.inventory.slots)
					main.hud.bag.sort("kind")
					for i in 4:
						await process_frame
					print("bag sorted: ", main.host.player.inventory.slots)
				main.hud.bag._take_all_from_chest()
				for i in 4:
					await process_frame
				print("bag after: ", main.host.player.inventory.slots)
				print("client bag after: ", main.character.inventory.slots)
		if shot.get("packed", false):
			# A bag and a chest with things lying in the bag: their grids under it, scrolled to.
			var inv = main.host.player.inventory
			inv.add("tools:leather_bag", 1, 0, {"slots": [["resources:flint", 6], ["plants:raspberry", 10], ["resources:fiber", 8]]})
			inv.add("tools:chest", 1, 0, {"slots": [["resources:branch", 12], ["resources:stone", 9]]})
			for i in 4:
				await process_frame
			main.hud.bag.refresh()
			await process_frame
			main.hud.bag._scroll.scroll_vertical = shot.get("scroll", 0)
			await process_frame
		if shot.get("fire_close", false):
			# A campfire set down in the open, the player up against its logs from the west,
			# over its stones, as close as its boxes (Placed.FIRE_BOXES) let a body come.
			main.player.position = places.flat_near(main.world, main.player.position + Vector3(14.0, 0.0, 9.0))
			for i in 3:
				await process_frame
			main.host.player.inventory.add(Placed.CAMPFIRE, 1)
			main.player.facing = "e"
			main.props.put_from_bag(Placed.CAMPFIRE)
			for i in 3:
				await process_frame
			for e in main.placed.things:
				if main.placed.is_fire(e) and e.cell.distance_to(Vector3i((main.player.position / CELL).floor())) < 4.0:
					var mid: Vector3 = (Vector3(e.cell) + Vector3(1.0, 0.0, 1.0)) * CELL
					main.player.position = Vector3(mid.x - (0.5 + 0.48) * CELL, mid.y, mid.z)
					main.player.facing = "e"
			for i in 10:
				await process_frame
		if shot.get("campfire", false):
			# A few branches to feed it with; the window opens at the client's copy of the fire.
			main.host.player.inventory.add("resources:branch", 6)
			await process_frame
			await process_frame
			for e in main.placed.things:
				if main.placed.is_fire(e):
					main.hud.open_prop(e)
					break
		if shot.get("give_all", false):
			# The playtest's free items turned on: one of every thing, the bag wider for them.
			main.settings.set_free_items(true)
			for i in 10:
				await process_frame
		if shot.get("craft", false):
			_craft(shot.get("forge", false), shot.get("weave", false), shot.get("smith", false), shot.get("dry", false))
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
			if shot.get("know_all", false):
				for r in Crafting.RECIPES:
					main.host.workshop.knowledge._known[r.id] = true
					main.workshop.knowledge._known[r.id] = true
				main.hud.bag.craft.refresh_now()
			if shot.get("free", false):
				# The playtest's free items: every recipe, «получить» on the one chosen.
				main.settings.set_free_items(true)
				main.hud.bag.craft._choose(shot.get("recipe", "tools:lantern"))
				# The cells of the recipes come a few a frame.
				for i in 240:
					await process_frame
			if shot.get("closed", false):
				main.hud.toggle_bag()
			if shot.has("on"):
				for e in main.session.placed.things:
					if e.item == shot.on[0]:
						main.player.position = (Vector3(e.cell) + shot.on[1]) * main.CELL
				for i in 30:
					await process_frame
		if shot.has("build_mode"):
			# The build mode with blocks and parts of a house in the bag, planks chosen, and
			# a stroke held: drawing a wall over the ghost's room, or taking the ghost off.
			var inv = main.host.player.inventory
			for st in [["materials:planks", 60], ["materials:brick", 40], ["materials:log_wall", 30], ["materials:cut_stone", 30],
					["materials:wattle", 20], ["materials:glass", 12], ["tools:door", 2], ["tools:window", 3], ["tools:wooden_bed", 1],
					["tools:chest", 1], ["tools:table", 1], ["tools:stool", 2], ["tools:fireplace", 1], ["tools:stairs", 2]]:
				if Items.has(st[0]):
					inv.add(st[0], st[1])
			for i in 3:
				await process_frame
			main.build.filter = shot.get("filter", "all")
			main.build.set_kind(shot.get("kind", "line"))
			if shot.has("height"):
				main.build.set_height(shot.height)
			main.build.thick = shot.get("thick", 1)
			main.build.form = shot.get("form", 0)
			main.build.enter("materials:planks")
			main.build.set_erasing(shot.build_mode == "erase")
			var feet := Vector3i((main.player.position / CELL).floor())
			var s := {"plan": main.build.kind, "first": feet + Vector3i(-6, 0, -9), "last": feet + Vector3i(-6, 0, -1)}
			if shot.build_mode == "erase":
				s = {"plan": "line", "first": feet + Vector3i(-5, 0, -9), "last": feet + Vector3i(0, 0, -9)}
			elif main.build.kind in ["plane", "cube", "flatten"]:
				# On the ground (a floor or a room stand on it), or the ground itself flattened.
				var y := -1 if main.build.kind == "flatten" else 0
				s = {"plan": main.build.kind, "first": feet + Vector3i(2, y, -3), "last": feet + Vector3i(6, y, 1)}
			for i in 3:
				await process_frame
			main.build.show_stroke(s)
		if shot.has("sapling_tree"):
			# The oak sapling at its last stage east of the farm (TestGround.SAPLINGS) grown
			# by the server into a young tree ("young") or a tree ("grown", "felled"), and
			# then, for "felled", felled.
			var sa = main.session.actions
			var cell := Vector3i(TestGround.SAPLINGS.position.x, 0, TestGround.SAPLINGS.position.y + 4)
			for i in 120:
				var y: int = main.session.world.surface_y(cell.x, cell.z) - 1
				if y > 0 and main.session.world.field_at(Vector3i(cell.x, y, cell.z)) != null:
					cell.y = y
					break
				await process_frame
			var f: Array = main.session.world.field_at(cell)
			if shot.sapling_tree == "young":
				# Both saplings' last stages: the oak and, 4 cells east, the spruce.
				for c in [cell, cell + Vector3i(4, 0, 0)]:
					var g: Array = main.session.world.field_at(c)
					g[1] = Plants.BY_ID[g[0]].grow_days * Plants.BY_ID[g[0]].young
					sa.grow_young(c)
			else:
				f[1] = Plants.BY_ID[f[0]].grow_days
				sa.grow_tree(cell)
			for i in 150:
				await process_frame
			if shot.sapling_tree == "felled":
				sa.fell(main.host.player, cell + Vector3i.UP)
			for i in 30:
				await process_frame
		if shot.has("farm_mode"):
			# The farming mode by the test world's farm: seeds, a bush, a hoe, a can of water
			# and a sickle in the bag, marks of every work drawn by the server (to till and
			# sow on the grass west, to water the dry beds, to reap the ripe row), and a
			# stroke of the work chosen held over the grass.
			var who = main.host.player
			var inv = who.inventory
			for st in [["plants:grain", 30], ["plants:raspberry_bush", 2], ["plants:currant_bush", 2], ["plants:grass_seeds", 8],
					["tools:stone_hoe", 1], ["tools:watering_can_full", 1], ["tools:copper_sickle", 1]]:
				if Items.has(st[0]):
					inv.add(st[0], st[1])
			for i in 3:
				await process_frame
			var plans = main.session.plans
			var sa = main.session.actions
			# On the ground, once its chunk is made.
			var col := Vector2i((main.player.position / CELL).floor().x, (main.player.position / CELL).floor().z)
			for i in 60:
				if main.world.surface_y(col.x, col.y) > 0:
					break
				await process_frame
			main.player.position.y = main.world.surface_y(col.x, col.y) * CELL
			who.position = main.player.position
			var feet := Vector3i((main.player.position / CELL).floor())
			plans.mark(sa, who, "till", feet + Vector3i(-9, 0, 1), feet + Vector3i(-4, 0, 1), false)
			who.hands = ["plants:grain", ""]
			who.active = 0
			plans.mark(sa, who, "sow", feet + Vector3i(-9, 0, 3), feet + Vector3i(-6, 0, 5), true)
			who.hands = ["", ""]
			plans.mark(sa, who, "water", Vector3i(64, feet.y, 16), Vector3i(75, feet.y, 18), true)
			plans.mark(sa, who, "reap", Vector3i(64, feet.y, 26), Vector3i(75, feet.y, 26), false)
			for i in 3:
				await process_frame
			main.farm.filter = shot.get("filter", "all")
			main.farm.shape = shot.get("shape", "square")
			main.farm.enter("plants:grain")
			if shot.has("work"):
				main.farm.set_work(shot.work)
			main.farm.set_erasing(shot.farm_mode == "erase")
			for i in 3:
				await process_frame
			main.farm.show_stroke({"plan": "farm", "first": feet + Vector3i(-3, 0, 3), "last": feet + Vector3i(-1, 0, 6)})
		if shot.has("gesture"):
			main.hud.make_gesture(shot.gesture)
			for i in 6:
				await process_frame
		if shot.get("gesture_wheel", false):
			main.hud.toggle_gestures()
			for i in 3:
				await process_frame
		if shot.get("sign_window", false):
			for i in 3:
				await process_frame
			main.hud.open_sign(main.placed.at(places.sign_cell))
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
			if shot.get("fires", false):
				# One's own fire and a teammate's (player 7, «Аня») next to the spawn's.
				var camp = main.session.placed
				var teams = main.session.teams
				teams.seen(7, "Аня")
				teams.invite(7, "Аня", 0, 0.0)
				teams.accept(0, "[player_n2]", 7, 0.0)
				for f: Array in [[7, Vector3(6.0, 0.0, 4.0)], [0, Vector3(-5.0, 0.0, 6.0)]]:
					var spot: Vector3i = camp.spot_near(main.player.position + f[1])
					if spot.y >= 0:
						camp.put(camp.CAMPFIRE, spot, null, true, -1.0, f[0])
			if shot.get("own_bed", false):
				# One's own bed a little way off: the first place to come back at.
				var beds = main.session.placed
				var at: Vector3i = beds.spot_near(main.player.position + Vector3(-6.0, 0.0, -4.0))
				if at.y >= 0:
					beds.put("tools:fur_bedroll", at, null, true, -1.0, 0)
			main.host.player.vitals.health = 0.0
			main.host.player.vitals.satiety = 0.0
			main.host.player.vitals.hurt_by = "hunger"
			for i in 10:
				await process_frame
			if shot.get("revive", false):
				# Beside the sack: the place is made a respawn point (the server takes no other).
				var fell: Array = main.host.player.death.at
				main.host.player.home = Vector3(fell[0] - 1.5, fell[1], fell[2] + 1.0)
				main.death_screen._revive(main.host.player.home)
				for i in 30:
					await process_frame
		var setup: Control = null
		var mods_off: String = main.settings.values.world_mods_off
		if shot.get("setup", false):
			# The bundles switched off for new worlds, for this shot only (not saved).
			main.settings.values.world_mods_off = shot.get("mods_off", mods_off)
			setup = load("res://src/client/ui/world_setup.gd").new(main)
			main.hud.add_child(setup)
			# A page of the screen other than the first ("mods").
			if shot.setup is String:
				setup._show_page(shot.setup)
			# The map of the setup screen is drawn a few rows a frame.
			for i in 120:
				await process_frame
		if shot.has("main_menu"):
			# The painted landscape at the hour asked (the device's clock otherwise).
			main.MainMenu.hour_override = shot.get("menu_hour", -1.0)
			# A larger interface, as a landscape phone's (the menu must still fit).
			if shot.has("ui_size"):
				main.settings.set_value("ui_size", shot.ui_size)
				await process_frame
			main._build_menu()
			# The landscape only for "sky" and "loading": the world is built already, so it
			# would fade (the menu holds it while it is open and no world was asked for).
			var painted: bool = shot.main_menu in ["sky", "loading"] or shot.get("painted", false)
			main.menu._backdrop.visible = painted
			main.menu._fading = not painted
			main.menu.settled = not painted
			await process_frame
			if shot.main_menu == "loading":
				# The loading screen held at a part of the shaders built ahead.
				main.menu.shown_progress = shot.get("progress", 0.62)
				main.menu._show_loading(true)
				main.menu._update_strip(0.0)
				# A caption with numbers is [template, value...] (Lang.line).
				var caption: Variant = shot.get("caption", main.menu.WARM_CAPTION)
				main.menu._phase_shown = Lang.line(caption[0], caption.slice(1)) if caption is Array else caption
				main.menu._update_strip(0.0)
				for i in 3:
					await process_frame
			if shot.main_menu == "setup":
				main.menu._new_world()
				for i in 120:
					await process_frame
			if shot.main_menu == "changes":
				main.menu._open_changes()
				await process_frame
			if shot.main_menu == "worlds":
				_fake_saves()
				main.menu._open_worlds()
				await process_frame
			if shot.get("dev", false):
				main.settings.testing_unlocked = true
				for i in 3:
					await process_frame
			if shot.main_menu == "dev":
				main.menu._open_settings()
				main.menu.settings_menu().show_section("dev")
				for i in 3:
					await process_frame
			if shot.get("egg", false):
				# The easter egg caught a moment after the sparrow blew up.
				main.menu._explode()
				# Stepped by hand at 20 steps a second: software frames are too slow for it.
				main.menu.set_process(false)
				for i in int(shot.get("egg_ms", 1300) / 50):
					main.menu._update_fx(0.05)
				main.menu._sparrow.queue_redraw()
				await process_frame
			if shot.main_menu == "resume":
				main.menu._entered = true
				main.menu._fill_page("top")
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
					main.link.hosted = main.LocalHost.host({"title": "Дача", "port": 7799, "max_players": 8,
						"password": "", "world": "", "seed_value": main.world_seed, "settings": main.world_options}, root)
					for i in 3:
						await process_frame
					for line: String in shot.get("host_commands", []):
						main.link.hosted.command(line)
				main.menu._fill_page("multi")
				main.menu.open_host()
				if shot.has("host_tab"):
					main.menu._setup.show_tab(shot.host_tab)
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
		if not main.effects.lamps.is_empty():
			# The lights set down light the world (their flicker clock is stopped above),
			# and the drawn fire shadows make their maps, a few rows a frame.
			main.effects._light_lamps(PixelView.screen_plane(main.player.position), main.sky)
			for i in 30:
				await process_frame
		# The trees' light is worked out a few trees a frame in the game: all of it first.
		if main.sun_rays != null and main.sun_rays.finish():
			await process_frame
		if keys_only:
			for k in Lang.keys_shown(root):
				print("KEYS %s: %s" % [shot_name, k])
		else:
			var img := root.get_texture().get_image()
			img.save_png(out_dir.path_join(shot_name + ".png"))
		main.hud.visible = true
		print("player at ", main.player.position)
		# Frames of the sun moving at the game's speed, 60 a second, to see how the
		# shadows move: <name>-01.png and on.
		for i in (0 if keys_only else shot.get("sweep", 0)):
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
			if main.link.hosted != null:
				main.link.hosted.command("stop")
				main.link.hosted.queue_free()
				main.link.hosted = null
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
		# «Витрина интерфейса» goes with its shot (it would cover the next one), before
		# the window under it closes (it shows that one again).
		for c in main.hud.get_children():
			if c.get_script() != null and (c.get_script() as Script).resource_path.ends_with("ui_gallery.gd"):
				c.close()
		if shot.get("menu", false):
			main.hud.toggle_menu()
		if shot.get("test", false):
			main.hud.toggle_test()
		if shot.get("bag", false) or shot.get("chest", false) or shot.get("chests", false) or shot.get("campfire", false) \
				or (shot.get("craft", false) and not shot.get("closed", false)) or shot.get("rights", false) \
				or shot.get("team_panel", false):
			main.hud.toggle_bag()
		if main.hud.sign_window != null:
			main.hud.sign_window.close()
		if main.hud.gesture_wheel != null:
			main.hud.gesture_wheel.close()
		main.player.set_gesture("")
		if shot.get("free", false) or shot.get("give_all", false):
			main.settings.set_free_items(false)
		if shot.get("craft", false):
			while not main.host.workshop.queue.jobs.is_empty():
				main.host.workshop.queue.cancel(0)
			for e in main.session.placed.things.duplicate():
				if e.item in ["tools:workbench", "tools:kiln", "tools:forge", "tools:loom", "tools:potters_wheel", "tools:bloomery", "tools:anvil", "tools:drying_rack"]:
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
## With `weave`, a loom to the north and a potter's wheel to the west in place of the chest,
## linen thread, cord and clay in the bag, linen cloth being woven, the craft tab at the loom.
## With `dry`, a drying rack to the north, hides, fat and meat in the bag, leather being
## tanned, the craft tab at the rack.
## A team for the shots of teams: the player (number 1) leads «Лесные» with Боря,
## who stands by them with Вова, not in it; `what` is "invite" (Гена's invitation),
## "person" (Вова's card, tapped), "chat" (Боря says a line), "map" (Гена in the team
## too, far away, both on the map), "torches" (both hold a torch) or "" (the figures alone).
func _fake_team(main: Node, what: String) -> void:
	main.link.welcome["id"] = 1
	main.link.welcome["name"] = "Аня"
	main.team.take_team({"id": 1, "name": "Лесные", "lead": 1, "members": [[1, "Аня"], [2, "Боря"]]})
	var at: Vector3 = main.player.position
	if what == "map":
		var cell := Vector2i(floori(at.x / main.CELL), floori(at.z / main.CELL))
		main.team.take_mates([[2, "Боря", cell + Vector2i(4, 11)], [4, "Гена", cell + Vector2i(70, -50)]])
	var people := []
	for p: Array in [[2, "Боря", Vector3(2.0, 0.0, 5.5), true], [3, "Вова", Vector3(-2.5, 0.0, 6.0), false]]:
		# With torches they stand apart, each in a light of their own.
		var pos: Vector3 = at + (p[2] * Vector3(2.5, 0.0, 0.4) if what == "torches" else p[2])
		var hands := ["tools:torch", ""] if what == "torches" else ["", ""]
		people.append([p[0], p[1], pos, Vector2i(0, 1), hands, 0, false, false, true, "", 0.0, 0, Vector3.INF, {}, p[3]])
	main.others.take_people(people)
	main.team.take_invites([[4, "Гена"]] if what == "invite" else [])
	if what == "chat":
		main.others.speak(2, "Привет! Пойдём к реке рубить деревья?")


## Land for the shots of territory: a boundary post set down south of the player and
## squares painted round it into a field with a lane out; `painting` turns the marking on.
func _fake_land(main: Node, painting: bool) -> void:
	var who = main.host.player
	var post := Items.with_prop("post")
	who.inventory.add(post, 1)
	main.player.facing = "s"
	main.props.put_from_bag(post)
	var t = main.session.territory
	if t.claims.is_empty():
		push_warning("shot: the boundary post was not set down")
		return
	var claim: Dictionary = t.claims.values()[0]
	var c: Vector2i = claim.sq
	for ring in 4:
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				t.paint(who, c + Vector2i(dx, dz), true)
	for i in 4:
		t.paint(who, c + Vector2i(4 + i, 0), true)
	main.land.set_painting(painting)


func _craft(forge := false, weave := false, smith := false, dry := false) -> void:
	var inv = main.host.player.inventory
	for st in [["resources:fiber", 14], ["resources:branch", 16], ["resources:flint", 3], ["resources:log", 2], ["resources:clay", 6],
			["tools:workbench", 1], ["tools:kiln", 1], ["tools:chest", 1]]:
		inv.add(st[0], st[1])
	main.player.facing = "s"
	main.props.put_from_bag("tools:workbench")
	main.player.facing = "e"
	main.props.put_from_bag("tools:kiln")
	main.player.facing = "w"
	if weave:
		for st in [["tools:loom", 1], ["tools:potters_wheel", 1], ["plants:linen_thread", 12], ["materials:cord", 8], ["tools:pot", 1]]:
			inv.add(st[0], st[1])
		main.props.put_from_bag("tools:potters_wheel")
		main.player.facing = "n"
		main.props.put_from_bag("tools:loom")
	elif smith:
		for st in [["tools:bloomery", 1], ["tools:anvil", 1], ["materials:iron_bar", 6], ["materials:steel_bar", 6], ["materials:planks", 4]]:
			inv.add(st[0], st[1])
		main.props.put_from_bag("tools:bloomery")
		main.player.facing = "n"
		main.props.put_from_bag("tools:anvil")
	else:
		main.props.put_from_bag("tools:chest")
	if dry:
		for st in [["tools:drying_rack", 1], ["animals:hide", 4], ["animals:fat", 4], ["animals:raw_meat", 6]]:
			inv.add(st[0], st[1])
		main.player.facing = "n"
		main.props.put_from_bag("tools:drying_rack")
	var station := "tools:workbench"
	var recipe := "materials:cord"
	if forge:
		for st in [["tools:forge", 1], ["materials:copper_ore", 6], ["materials:charcoal", 3], ["materials:copper_bar", 6], ["materials:planks", 2]]:
			inv.add(st[0], st[1])
		main.player.facing = "n"
		main.props.put_from_bag("tools:forge")
		station = "tools:forge"
		recipe = "tools:copper_bar"
	if weave:
		station = "tools:loom"
		recipe = "plants:cloth"
	if smith:
		station = "tools:anvil"
		recipe = "tools:steel_axe"
	if dry:
		station = "tools:drying_rack"
		recipe = "materials:leather"
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


## The rod in hand cast into the water nearest ahead of the player (the four ways tried),
## a roach let into the water by the float: swimming up to it, or biting at it (`bite`).
func _cast(bite: bool) -> void:
	var who = main.host.player
	var actions = main.session.actions
	var at: Vector3 = main.player.position
	var water := Vector3.INF
	var way := Vector2(0, 1)
	for d: Vector2 in [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]:
		water = actions.water_ahead(at, d, 6)
		if water != Vector3.INF:
			way = d
			break
	if water == Vector3.INF:
		print("no water ahead to cast into at %v" % at)
		return
	main.player.facing = SpriteSheet.direction_of(way)
	await process_frame
	await process_frame
	who.inventory.add("tools:bait", 4)
	if main.session.fishing.has_line(who):
		main.session.fishing.pull(who)
	var life = main.session.wildlife
	main.controls._cooldown = 0.0
	actions.fish(who, water)
	var line: Vector3 = who.line
	if not line.is_finite():
		print("the rod was not cast at %v" % water)
		return
	# Swimming up from farther out, or at the float.
	var spot: Vector3 = line + Vector3(way.x, 0.0, way.y) * (0.0 if bite else 1.0) + Vector3(way.y, 0.0, way.x) * (0.0 if bite else 0.6)
	spot.y = life.water_top(spot.x, spot.z) - life.DIP * CELL
	var fish = life._add("animals:roach", spot)
	fish.think = 1000.0
	# No other fish lured to the float meanwhile.
	main.session.fishing.lines[who].wait = 1000.0
	if bite:
		var l = main.session.fishing.lines[who]
		l.fish = fish
		l.bite = 1000.0
		fish.bait = line
		who.bite = true
	else:
		fish.facing = -signf(way.x) if way.x != 0.0 else 1.0
	for i in 10:
		await process_frame


## By the spawn: a floor painted, a pit dug, berries knocked down, the tools taken but
## for those by the chest left lying, and the frame on what the action button digs.
func _work() -> void:
	var c = main.controls
	var w = main.world
	main.settings.set_value("pickup", 3)
	# The first tools of the game (the playtest button gives the best ones, Items.best_kit).
	for id in ["tools:stone_axe", "tools:stone_pickaxe", "tools:wooden_shovel", "tools:wooden_sword", "tools:stone_scythe", "tools:torch"]:
		main.host.player.inventory.add(id, 1)
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


## Animals `kinds` ([species, frame, height above the ground, view]) in a row before
## the player, far enough apart for their sun shadows, each held in that frame (a flyer
## in the air when its height is above 0), for checking the shadows match the drawings.
func _place_shadow_zoo(kinds: Array) -> void:
	var life = main.session.wildlife
	var p: Vector3 = main.player.position
	for c in life.animals:
		c.pos = p + Vector3(60.0, 0.0, 60.0)
		c.target = c.pos
		c.think = 100.0
	var put := []
	for i in kinds.size():
		var k: Array = kinds[i]
		var at := p + Vector3(-5.0 + (i % 5) * 2.5, 0.0, -2.0 + (i / 5) * 3.0)
		at.y = life.ground(at.x, at.z) + k[2]
		var c = life._add(k[0], at)
		c.think = 100.0
		c.facing = 1.0
		c.flying = k[2] > 0.0
		put.append(c)
	# The drawn animals are the client's copies: held in their frames once they come.
	for f in 30:
		await process_frame
	main.creatures.set_process(false)
	for look in main.creatures._shown:
		for i in put.size():
			var c = put[i]
			if look.animal.kind == c.kind and Vector2(look.animal.pos.x - c.pos.x, look.animal.pos.z - c.pos.z).length() < 0.3:
				var shown: int = kinds[i][3] * main.creatures.looks[c.kind][3] + kinds[i][1]
				look.sprite.material_override = main.creatures._mats(look.animal)[shown]
				look.sprite.position = PixelView.snap(c.pos)


## A trap two cells north-east of the player with a carrot in it and a hare walking up to
## it, another trap beside it with a hare caught (the shot puts a caught hare in the hand).
func _place_trap() -> void:
	var life = main.session.wildlife
	var p: Vector3 = main.player.position
	for c in life.animals:
		c.pos = p + Vector3(60.0, 0.0, 60.0)
		c.target = c.pos
		c.think = 100.0
	var gx := floori(p.x / CELL) + 1
	var gz := floori(p.z / CELL) - 2
	var cell := Vector3i(gx, floori(life.ground((gx + 0.5) * CELL, (gz + 0.5) * CELL) / CELL + 0.01), gz)
	# Bare earth round the traps, so the grass hides nothing.
	for dz in range(-2, 5):
		for dx in range(-5, 4):
			var x := gx + dx
			var z := gz + dz
			var y := floori(life.ground((x + 0.5) * CELL, (z + 0.5) * CELL) / CELL + 0.01) - 1
			if main.world.get_cell(x, y, z) == main.Mat.GRASS:
				main.world.set_cell(x, y, z, main.Mat.DIRT)
	for dx in range(-8, 9, 8):
		main.chunks.on_cell_changed(cell + Vector3i(dx, -1, 0))
	var trap: Dictionary = main.session.placed.put("tools:trap", cell)
	trap.items.add("plants:carrot", 1)
	var full: Dictionary = main.session.placed.put("tools:trap", cell + Vector3i(-3, 0, 0))
	full.items.add("tools:live_rabbit", 1)
	var at := (Vector3(cell) + Vector3(2.4, 0.0, 0.7)) * CELL
	var hare = life._add("animals:rabbit", Vector3(at.x, life.ground(at.x, at.z), at.z))
	hare.think = 100.0
	hare.facing = -1.0
	hare.moving = true
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
