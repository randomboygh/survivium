extends SceneTree
## Plays the game without a screen and fails when a frame takes longer than the
## budgets allow, so a freeze on digging, on streaming chunks or on a cut change is
## caught in CI instead of on a phone. Run:
## godot --headless --path . --script res://tests/frame_test.gd
##
## The budgets in chunk_streamer.gd are wall-clock, so their part of a frame costs about the
## same on any machine; the rest scales with the machine, and a phone runs GDScript
## about ten times slower than a desktop. So each frame is judged in two parts, with
## main.chunks.budget_us telling them apart: the budgeted loops may take the budgets plus one
## step, and the rest may take an idle frame of the finished map plus a quarter of
## what a whole chunk costs here. Chunk-sized work slipping into one frame fails the
## test on any machine, and a slow runner does not.

const Mat := preload("res://src/shared/content/materials.gd")
const SettingsFile := preload("res://src/client/settings.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const ChunkMesher := preload("res://src/client/world/chunk_mesher.gd")
const Foliage := preload("res://src/client/world/foliage.gd")
const ChunkStreamer := preload("res://src/client/world/chunk_streamer.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const ShotPlaces := preload("res://tools/shot/places.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Items := preload("res://src/shared/content/items.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Content := preload("res://src/shared/content/content.gd")
const WorldActions := preload("res://src/shared/game/world_actions.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const TestGround := preload("res://src/shared/world/test_ground.gd")
const CELL := 0.5
const CHUNK := 16
## The chunk whose neighbours _chunk_cost builds: in the test world, over its steps,
## pits and caves (see TestGround).
const REFERENCE := Vector2i(-2, -2)
## What the nine chunks round the spawn of the test's world cost against the reference
## (1.34 to 1.57, 2026-11-13), when the limits were set by them: the limits stay as they
## were tuned, and no longer move when the generator changes the spawn's ground.
const REFERENCE_SCALE := 1.4
## Frames over a limit allowed in a scenario, one plus one per this many frames: a
## virtual machine stalls the process now and then (a cloud container: up to 50 ms,
## several times in a few thousand frames; a GitHub runner: hardly ever), a real
## freeze comes back with every chunk or every cut change.
const STALLS_PER_FRAMES := 250
## Standing on the finished map, a frame takes less than this share of a chunk: what
## runs every frame (animals, fire shadows, the interface) runs all the time, and a
## phone pays ten times as much for it (an animal looking for the ground from the sky
## took 70 % of the frame until 2026-10-21).
const IDLE_SHARE := 20.0
const NIGHT_SHARE := 16.0
## ...but never less than this, in ms: GitHub's runners come in two speeds (a chunk
## 14-17 ms or 21-25 ms) while an idle frame costs about the same on both (0.9-1.0 ms
## on 2026-11-04), so a share of a fast runner's chunk failed main half the time. The
## floors are the slow runner's shares, a third above the frames measured then. The night
## floor was raised on 2026-11-09: the night frame had grown with what came since (the
## packs that hunt at night, fire fear, boats: on CI 1.26-1.76 ms, the night animals 0.4-0.5
## of it against 0.2 by day) and failed main on 1.59 and 1.76 of 1.55.
const IDLE_FLOOR := 1.25
const NIGHT_FLOOR := 2.0
const NIGHT := "idle at night by the campfire"
const LANDING := "landing in a cave"
const MOWING := "mowing"
## The frames of LANDING the jump into the cave takes (see there).
const LANDING_EVENTS := 2
const IDLE := "idle"

var main: Node
var checks := 0
var failures := 0
var chunk_ms := 0.0
## What the scenarios' callables count (a lambda gets its own copy of a local), and
## the game time the running scenario has played: the game paces the cut and the
## jumps by it, and a frame here can be a millisecond or ten.
var moved := 0.0
## The longest frame of building while the game is paused, microseconds.
var paused_worst := 0
var flips := 0
## Things taken up from the ground while a scenario counts them (_on_taken).
var taken := 0
var clock := 0.0
## Each scenario's name, frame times and the budgeted part of each, judged once the
## idle frame of the finished map is known.
var runs: Array = []
## The chunk cost measured just before each idle scenario, by its name (see _chunk_cost).
var unit := {}
## The game's parts of the idle scenarios' frames, microseconds in all, by scenario and part.
var parts_us := {}
## The patch of the test world _chunk_cost builds (made once, see REFERENCE).
var reference: WorldData


func _initialize() -> void:
	# Without a screen the engine sleeps 6.9 ms a frame (low_processor_usage_mode_sleep_usec),
	# which would hide the game's own time.
	OS.low_processor_usage_mode_sleep_usec = 0
	# The settings of this test, apart from the game's and the tools' (shot.gd saves some).
	SettingsFile.path = "user://test_settings.cfg"
	SettingsFile.language_override = "ru"
	# Every text shown to the player must have its Russian (Lang.seen).
	Lang.watching = true
	DirAccess.remove_absolute(SettingsFile.path)
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_setup = true
	root.add_child(main)
	_run()


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


func _run() -> void:
	# Loading as in the game: the near chunks, 40 ms a frame; the loading screen says
	# what is being done all the way.
	var told := {}
	while not main.ready_to_play:
		if main.chunks != null:
			told[main.loading_phase()] = true
			Lang.seen(main.loading_phase())
		await process_frame
	_check(main.loading_stage == "" and told.size() >= 3 and told.keys().all(func(t: String) -> bool: return t.strip_edges() != ""),
		"the loading screen tells what is being built: %s" % [told.keys()])
	var w = main.world
	var home := Vector2i((Vector2(main.player.position.x, main.player.position.z) / (CHUNK * CELL)).floor())
	# What a whole chunk costs on this machine (see _chunk_cost).
	chunk_ms = _chunk_cost()
	var t := 0
	print("a chunk costs %.1f ms here" % chunk_ms)

	# The smallest step a job takes must stay far below a chunk, or the budgets
	# cannot be kept: a column, or a tree's shadow, never a phase of the whole chunk.
	# Two passes, the better one counts: a single stall of the machine is not a step.
	var worst_step := 1 << 30
	for pass_ in 2:
		var worst := 0
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var job := ChunkMesher.start(w, (home.x + dx) * CHUNK, (home.y + dz) * CHUNK, CHUNK)
				var plants := Foliage.start(w, (home.x + dx) * CHUNK, (home.y + dz) * CHUNK, CHUNK)
				var done := false
				while not done:
					t = Time.get_ticks_usec()
					done = ChunkMesher.step(job, 1) and Foliage.step(plants, 1)
					worst = maxi(worst, Time.get_ticks_usec() - t)
		worst_step = mini(worst_step, worst)
	print("longest step of a job %.2f ms" % (worst_step / 1000.0))
	_check(worst_step / 1000.0 < chunk_ms / 4.0, "a step of a job is under a quarter of a chunk")

	# Streaming the chunks around while walking east and west, four seconds each
	# way (the keys, as the game reads them), so the chunks ahead of the player are
	# generated and built as urgent and the caps' home moves.
	var start: Vector3 = main.player.position
	await _scenario("streaming while walking", 100000, func(_i: int) -> bool:
		var east := int(clock / 4.0) % 2 == 0
		_key(KEY_D, east)
		_key(KEY_A, not east)
		moved = maxf(moved, main.player.position.distance_to(start))
		return main.chunks.map_done)
	_key(KEY_D, false)
	_key(KEY_A, false)
	_check(main.chunks.map_done, "the chunks around stream in")
	_check(moved > 4.0, "the player walked while the map streamed (%.1f units away at most)" % moved)

	# While the game is paused (its menu open) the world is built farther round the
	# player, a budgeted step a frame; on going on, the farther chunks stay.
	var streamer = main.chunks
	var paused_home: Vector2i = streamer._player_chunk()
	var far_built := func() -> bool:
		for cz in range(paused_home.y - streamer.PAUSE_RANGE, paused_home.y + streamer.PAUSE_RANGE + 1):
			for cx in range(paused_home.x - streamer.PAUSE_RANGE, paused_home.x + streamer.PAUSE_RANGE + 1):
				if not streamer.chunk_nodes.has(Vector2i(cx, cz)) or streamer.bare.has(Vector2i(cx, cz)):
					return false
		return true
	var far_before: bool = far_built.call()
	paused_worst = 0
	paused = true
	for i in 3000:
		var b0: int = streamer.budget_us
		await process_frame
		paused_worst = maxi(paused_worst, streamer.budget_us - b0)
		if far_built.call():
			break
	paused = false
	await process_frame
	await process_frame
	print("built within %d chunks while paused, worst frame of building %.1f ms" % [streamer.PAUSE_RANGE, paused_worst / 1000.0])
	_check(not far_before and far_built.call(), "the chunks farther round are built while the game is paused, and stay")
	_check(paused_worst / 1000.0 < streamer.LOAD_MAX_US / 1000.0 + chunk_ms / 4.0, "building while paused keeps to its budget")

	# Standing still on the finished map. The chunks around the player built before it
	# came are built again to keep their jobs (ChunkStreamer.keep_queue) first: part of
	# finishing the map, not of an idle frame. The chunk it is judged by is measured again
	# just before: a shared runner's speed drifts over the minutes of the test, and the
	# idle frame and its unit must be taken on the same machine.
	var kept_from := Time.get_ticks_msec()
	while (not streamer.keep_queue.is_empty() or streamer.job_keep) and Time.get_ticks_msec() - kept_from < 20000:
		await process_frame
	_check(streamer.keep_queue.is_empty() and not streamer.job_keep, "the chunks around the player keep their jobs once the map is built")
	unit[IDLE] = _chunk_cost()
	await _settle()
	await _scenario(IDLE, 120, func(_i: int) -> bool: return false)

	# Digging a ring around the feet and the ground under the nearest bush, then
	# filling it all back, a cell every tenth frame: each edit remeshes the chunk and
	# its neighbours, and the bush goes.
	var p := Vector3i((main.player.position / CELL).floor())
	var cells: Array[Vector3i] = []
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			if maxi(absi(dx), absi(dz)) == 2:
				cells.append(Vector3i(p.x + dx, w.surface_y(p.x + dx, p.z + dz) - 1, p.z + dz))
	var bush := Vector3i.ZERO
	for c: Vector3i in w.bushes:
		if bush == Vector3i.ZERO or (c - p).length_squared() < (bush - p).length_squared():
			bush = c
	var bushes_before: int = w.bushes.size()
	_check(bushes_before > 0, "the map has bushes")
	cells.append(bush - Vector3i(0, 1, 0))
	var before: Array[int] = []
	for c in cells:
		before.append(w.get_cell(c.x, c.y, c.z))
	await _scenario("digging", cells.size() * 10 + 60, func(i: int) -> bool:
		if i % 10 == 0 and i / 10 < cells.size():
			var c: Vector3i = cells[i / 10]
			w.set_cell(c.x, c.y, c.z, Mat.AIR)
			main.chunks.on_cell_changed(c)
		return false)
	await _scenario("filling", cells.size() * 10 + 60, func(i: int) -> bool:
		if i % 10 == 0 and i / 10 < cells.size():
			var c: Vector3i = cells[i / 10]
			w.set_cell(c.x, c.y, c.z, before[i / 10])
			main.chunks.on_cell_changed(c)
		return false)
	_check(main.chunks.dirty_chunks.is_empty() and (main.chunks.job_mesh == null or main.chunks.job_keep), "edits are all built")
	_check(w.bushes.size() == bushes_before - 1 and not w.bushes.has(bush), "the bush dug under is gone")

	# The cut moving up and down four times a second, as when walking in and out of
	# a cave: the caps of the chunks around are rebuilt each time.
	var level: int = main.player.level()
	await _scenario("cut changes", 100000, func(_i: int) -> bool:
		main.chunks.manual_level = level - 4 if int(clock / 0.25) % 2 == 0 else -1
		return clock >= 4.0)
	main.chunks.manual_level = -1

	# Jumping in a cave: the view stays cut at the floor level the whole time. The
	# player lands first, and the automatic cut follows the floor at once. The player
	# is put there from afar, as on coming back to life: the first two frames carry the
	# jump's one-off work (the animals round the new place, the view and the cut moved
	# at once; 8-15 ms past the budgets on a 15-27 ms chunk, 2026-11-13), which took
	# the scenario's one stall and failed main whenever the runner stalled once more.
	# They are let past the frame limit as events, but must stay under a chunk.
	main.player.position = ShotPlaces.cave(w, main.player.position)
	main.player.body.on_ground = false
	await _scenario(LANDING, 100000, func(_i: int) -> bool:
		return main.player.body.on_ground and clock >= 1.0, LANDING_EVENTS)
	# Cut, or in layers (the default «Вид в пещере»).
	_check(main.chunks.indoor and (main.chunks.cut_level < w.size_y or main.chunks.layers_on), "the view is cut in the cave")
	var cut: int = main.chunks.cut_level
	var layered: Vector3i = main.chunks.layer_base
	await _scenario("jumping in a cave", 100000, func(_i: int) -> bool:
		main.controls.jump_held = fmod(clock, 0.8) < 0.1
		if main.chunks.cut_level != cut or main.chunks.layer_base != layered:
			flips += 1
		return clock >= 4.0)
	main.controls.jump_held = false
	_check(flips == 0, "jumping in a cave does not move the cut (%d flips)" % flips)

	# Working as a player does: a 3x3 floor of stone painted with the brush beside the
	# player, dug out again with the pickaxe a cell every tenth frame, what falls taken
	# up by itself, then digging in front with the action button held.
	var c = main.controls
	var inv = main.host.player.inventory
	# The first tools of the game (the playtest button gives the best ones, Items.best_kit).
	for id in ["tools:stone_axe", "tools:stone_pickaxe", "tools:wooden_shovel", "tools:wooden_sword", "tools:stone_scythe", "tools:torch"]:
		inv.add(id, 1)
	inv.add("resources:stone", 9)
	# The client's copy of the bag takes the stones at the next flush.
	await process_frame
	# The cave found depends on the chunks loaded by then, so the column two cells east
	# may be its wall (the floor found on it is then above the cut): the first column
	# two cells away whose floor takes a block.
	var spot: Vector3i = c.feet() + Vector3i(2, 0, 0)
	for d: Vector3i in [Vector3i(2, 0, 0), Vector3i(-2, 0, 0), Vector3i(0, 0, 2), Vector3i(0, 0, -2),
			Vector3i(2, 0, 2), Vector3i(-2, 0, 2), Vector3i(2, 0, -2), Vector3i(-2, 0, -2)]:
		var s: Vector3i = c.feet() + d
		while s.y < w.size_y - 1 and w.is_solid(s.x, s.y, s.z):
			s.y += 1
		while s.y > 1 and not w.is_solid(s.x, s.y - 1, s.z):
			s.y -= 1
		if main.actions.can_place(main.host.player, s, main.chunks.cut_level):
			spot = s
			break
	var slot0 = inv.slots[0]
	c.select_slot(0)
	_check(slot0 != null and c.held() == slot0[0], "a hotbar slot is the bag's first row")
	# A block or a thing to set down there enters the build mode: out of it again.
	main.build.leave()
	await _portrait_hotbar()
	c.put_in_hand("resources:stone")
	c.brush = 2
	var stone_before: int = inv.count("resources:stone")
	var placed: int = c.place_at(spot, Vector3i.UP)
	_check(placed > 0 and inv.count("resources:stone") == stone_before - placed,
		"the brush places blocks from the bag (at %s, feet %s, cut %d)" % [spot, c.feet(), main.chunks.cut_level])
	var laid: Array[Vector3i] = []
	for cell in Tools.brush_cells(spot, Vector3i.UP, 3):
		if w.get_cell(cell.x, cell.y, cell.z) == Mat.STONE:
			laid.append(cell)
	c.hold("tools:stone_pickaxe")
	# Rested, whatever the jumps and climbs before (which depend on the cave and the
	# trees found) left of the stamina digging costs.
	main.host.player.vitals.stamina = main.host.player.vitals.stamina_cap()
	# What falls is drawn as the ground it came from is drawn changed (a felled tree's
	# logs as it goes): not while the chunk waits to be rebuilt.
	var picks: int = main.settings.values.pickup
	main.settings.values.pickup = WorldActions.PICKUP_NONE
	var first_dug: Vector3i = laid.pop_front()
	var dug_key := WorldData.chunk_key(first_dug.x, first_dug.z)
	var lying: int = w.drops.get(dug_key, []).size()
	# A far chunk being streamed is set aside for the edit, not waited for
	# (ChunkStreamer.stashed): a felled tree stood for seconds on a phone at a new place.
	var far_key: Vector2i = WorldData.chunk_key(first_dug.x, first_dug.z) + Vector2i(ChunkStreamer.LOAD_RANGE - 1, 0)
	streamer.unload_chunk(far_key)
	streamer.load_home = Vector2i(-1000000, 0)
	var stream_from := Time.get_ticks_msec()
	while not (streamer.job_mesh != null and not streamer.job_edit and streamer.job_key == far_key) \
			and Time.get_ticks_msec() - stream_from < 10000:
		await process_frame
	var streaming: bool = streamer.job_mesh != null and streamer.job_key == far_key
	streamer.last_stashed = Vector2i(0x7fffffff, 0)
	c._cooldown = 0.0
	c.dig_at(first_dug, Vector3i.UP)
	var held: bool = w.drops.get(dug_key, []).size() > lying and main.props._drops_shown.get(dug_key, 0) == lying
	var patches_before: int = main.chunks.patches
	var kept: bool = main.chunks.kept.has(dug_key)
	# The dug cell's own chunk goes first, before its neighbours (ChunkStreamer.edited).
	var queued: Array = main.chunks.dirty_chunks.keys()
	_check(main.chunks.edited.has(dug_key) and not queued.is_empty() and queued[0] == dug_key,
		"the chunk of a dug cell is rebuilt before the chunks beside it (queue %s, chunk %s)" % [queued, dug_key])
	var set_aside := false
	var waited_from := Time.get_ticks_msec()
	while main.props._rebuilding_near(dug_key) and Time.get_ticks_msec() - waited_from < 10000:
		await process_frame
		# Set aside and maybe taken up again within the frame on a fast machine.
		set_aside = set_aside or streamer.last_stashed == far_key
	# Not finished (it may show its ground already, ChunkStreamer.bare).
	_check(streaming and set_aside and (not streamer.chunk_nodes.has(far_key) or streamer.bare.has(far_key)),
		"an edit sets a chunk being streamed aside instead of waiting for it (streaming %s, set aside %s, built %s, bare %s)"
			% [streaming, set_aside, streamer.chunk_nodes.has(far_key), streamer.bare.has(far_key)])
	await process_frame
	_check(held and main.props._drops_shown.get(dug_key, 0) == w.drops.get(dug_key, []).size(),
		"what is dug is drawn on the ground when the chunk is drawn dug, not before")
	_check(kept and main.chunks.patches > patches_before,
		"the chunk at the player's feet keeps its jobs and a dig rebuilds only the columns around it")
	# Its ground shows first (ChunkStreamer.bare), its plants after: wait for both.
	while not (streamer.chunk_nodes.has(far_key) and not streamer.bare.has(far_key)) \
			and Time.get_ticks_msec() - waited_from < 20000:
		await process_frame
	_check(streamer.chunk_nodes.has(far_key) and not streamer.bare.has(far_key) and streamer.stashed.is_empty()
		and streamer.kept.has(far_key),
		"the chunk set aside is built after the edit, and keeps its jobs")
	main.settings.values.pickup = picks
	await _scenario("digging with tools", laid.size() * 10 + 60, func(i: int) -> bool:
		if i % 10 == 0 and i / 10 < laid.size():
			c._cooldown = 0.0
			c.dig_at(laid[i / 10], Vector3i.UP)
		return false)
	# What lies at the feet is taken up a few times a second (Gathering.PICKUP_INTERVAL),
	# by time, not frames: wait for it however fast the frames go here.
	var waited := Time.get_ticks_msec()
	while Time.get_ticks_msec() - waited < 600:
		await process_frame
	var all_dug := true
	for cell in laid:
		all_dug = all_dug and w.get_cell(cell.x, cell.y, cell.z) == Mat.AIR
	_check(all_dug, "the pickaxe digs the stone placed")
	_check(inv.count("resources:stone") >= stone_before - placed + laid.size() - 2, "what is dug beside the player flies into the bag")
	# Back on the surface, where the ground in front is soil.
	main.player.position = start
	await _scenario("back to the surface", 100000, func(_i: int) -> bool: return main.player.body.on_ground and clock >= 0.5)
	# Grass in front cut with the scythe held in the right hand: fibre falls and flies
	# into the bag, dirt shows where the grass was.
	c.put_in_hand("tools:stone_scythe", 1)
	var mown: Dictionary = main.actions.front_work(main.host.player, c.tool_record())
	if mown.has("mow"):
		var fibre: int = inv.count("resources:fiber")
		var first: Vector3i = mown.mow[0]
		c.action_held = true
		# Each thing taken up comes into the bag in one frame, as a thing made does (the
		# server's pickup and the bag's, skills' and knowledge's copies: 2-4 ms past the
		# budgets here, 2026-11-13), and so does the first swing: they may pass the limit,
		# under a chunk (see the verdict).
		taken = 0
		main.actions.taken.connect(_on_taken)
		await _scenario(MOWING, 100000, func(_i: int) -> bool: return clock >= 1.5)
		main.actions.taken.disconnect(_on_taken)
		runs[-1][3] = 1 + taken
		print("mowing: %d things taken up" % taken)
		c.action_held = false
		_check(w.get_cell(first.x, first.y, first.z) == Mat.DIRT and inv.count("resources:fiber") > fibre,
			"the scythe cuts the grass in front into fibre and leaves dirt")
	var dug_before: int = inv.count("resources:stone") + inv.count("resources:dirt")
	c.put_in_hand("tools:wooden_shovel", 0)
	_check(c.active == 0 and c.held() == "tools:wooden_shovel" and c.hands[1] == "tools:stone_scythe", "each hand holds its own tool")
	c.action_held = true
	await _scenario("action button", 100000, func(_i: int) -> bool: return clock >= 2.0)
	c.action_held = false
	_check(inv.count("resources:stone") + inv.count("resources:dirt") > dug_before, "the action button digs in front of the player")
	var hands_saved: Dictionary = c.to_dict()
	c.put_in_hand("", 0)
	c.from_dict(hands_saved)
	_check(c.held() == "tools:wooden_shovel", "the hands are saved with the player")
	# The last of what the hand in use holds leaves the bag: the hand is bare.
	inv.add("resources:sand", 1)
	c.put_in_hand("resources:sand", 1, false)
	inv.remove("resources:sand", inv.count("resources:sand"))
	await process_frame
	_check(c.held() == "" and c.hands[0] == "tools:wooden_shovel", "a hand whose last item is gone is bare")
	c.put_in_hand("tools:wooden_shovel", 0, false)
	# A stack into the chest by the spawn and back, sorting by hand: a tap on it, a tap
	# on a free slot.
	var bag = main.hud.bag
	# The bag lists the chests within reach: stand by the spawn's chest.
	var stood_at: Vector3 = main.player.position
	for e: Dictionary in main.placed.things:
		if e.items != null and e.items == main.placed.chest_items:
			main.player.position = main.placed.center(e) + Vector3(0.8, 0, 0)
	main.hud.open_chest()
	bag.refresh_state()
	bag._manual = true
	var at: int = inv.slots.find(inv.slots.filter(func(x) -> bool: return x != null and x[0] == "resources:stone")[0])
	var free: int = main.session.placed.chest_items.slots.find(null)
	var stones: int = main.session.placed.chest_items.count("resources:stone") + inv.slots[at][1]
	var chest_at: int = bag._chests.find(bag._chests.filter(func(e) -> bool: return e.items == main.placed.chest_items)[0])
	bag._tap(at)
	bag._tap(free, chest_at)
	_check(inv.slots[at] == null and main.session.placed.chest_items.count("resources:stone") == stones, "a stack goes into the chest")
	bag._tap(free, chest_at)
	bag._tap(at)
	_check(inv.slots[at] != null and main.session.placed.chest_items.slots[free] == null, "and back into the bag")
	bag._manual = false
	# Else a tap only picks.
	var bag_before: Array = inv.slots.duplicate(true)
	bag._tap(at)
	bag._tap(free, chest_at)
	_check(inv.slots == bag_before and main.session.placed.chest_items.slots[free] == null, "a second tap picks, it moves nothing")
	# «Скинуть всё в сундук» leaves the hotbar row.
	var chest_before: Array = main.session.placed.chest_items.slots.duplicate(true)
	inv.slots[inv.slots.size() - 1] = ["resources:flint", 1]
	bag._put_all_in_chest()
	_check(inv.slots.slice(0, inv.HOTBAR) == bag_before.slice(0, inv.HOTBAR) and inv.slots[inv.slots.size() - 1] == null
		and main.session.placed.chest_items.count("resources:flint") > 0, "all the bag past the hotbar row goes into the chest")
	inv.slots = bag_before
	main.session.placed.chest_items.slots = chest_before
	bag.close()
	main.player.position = stood_at

	# Crafting as a player does, with the jobs cut short: cord and a workbench by hand,
	# the workbench placed in front, a stone axe made at it, with the craft tab open.
	var shop = main.host.workshop
	inv.add("resources:fiber", 9)
	inv.add("resources:branch", 10)
	inv.add("resources:flint", 1)
	main.hud.toggle_bag()
	bag.show_tab("craft")
	# The tab's first layout is the opening's cost, not the crafting's.
	for k in 2:
		await process_frame
	for id in ["materials:cord", "tools:workbench"]:
		var r := Crafting.get_recipe(id)
		var n: int = shop.start(r, 3 if id == "materials:cord" else 1)
		_check(n > 0, "%s is known and queued" % r.title)
		for j in shop.queue.jobs:
			j.left = 0.05
		# Each thing made may take a frame past the limit: it comes into the bag, teaches
		# the recipes it is in (the cord a dozen, with their kinds' tabs) and the craft tab
		# shows them; the start of the craft takes one more.
		await _scenario("crafting " + id, 100000, func(_i: int) -> bool: return shop.queue.jobs.is_empty() or clock >= 2.0, n)
	_check(inv.count("tools:workbench") == 1, "a workbench is made by hand")
	# Out of the pit the action button dug, the player turns until there is room.
	main.player.position = start + Vector3(1.5, 0.0, 1.5)
	await _scenario("stepping out of the pit", 100000, func(_i: int) -> bool: return main.player.body.on_ground and clock >= 0.5)
	var put := false
	for facing in ["s", "e", "n", "w", "se", "sw", "ne", "nw"]:
		main.player.facing = facing
		put = put or main.props.put_from_bag("tools:workbench")
	_check(put and shop.stations().has("tools:workbench"), "a workbench placed works as a station")
	var axe := Crafting.get_recipe("tools:stone_axe")
	var axes: int = inv.count("tools:stone_axe")
	_check(shop.start(axe) == 1, "an axe is queued at the workbench")
	for j in shop.queue.jobs:
		j.left = 0.05
	await _scenario("crafting at a workbench", 100000, func(_i: int) -> bool: return shop.queue.jobs.is_empty() or clock >= 2.0, 1)
	_check(inv.count("tools:stone_axe") == axes + 1, "a stone axe is made at the workbench")
	main.hud.toggle_bag()
	var bench: Vector3i = main.session.placed.cell_of("tools:workbench")
	_check(main.world.blocks_body(bench.x, bench.y, bench.z), "a workbench is solid")
	# After the crafting: the things it puts in the bag teach recipes, a longer craft tab.
	await _portrait_palette()

	# The chest by the spawn taken up with a stone in it, and set down again with it.
	main.session.placed.chest_items.add("resources:stone", 1)
	var chest_e := {}
	for e in main.session.placed.things:
		if e.items == main.session.placed.chest_items:
			chest_e = e
	var light_bag: float = inv.weight()
	_check(main.session.placed.take_up(main.host.player, chest_e) and inv.weight() > light_bag + 2.0 and main.session.placed.chest_items == null,
		"the chest is taken up with what it holds")
	var chest_back := false
	for facing in ["s", "e", "n", "w", "se", "sw", "ne", "nw"]:
		main.player.facing = facing
		chest_back = chest_back or main.props.put_from_bag("tools:chest")
	_check(chest_back and main.session.placed.chest_items != null and main.session.placed.chest_items.count("resources:stone") == 1,
		"and set down again with it")
	# The campfire by the spawn put out (no station then), lit again for a branch, put
	# out and destroyed.
	var fire_e := {}
	for e in main.session.placed.things:
		if e.item == "core:campfire":
			fire_e = e

	# Standing by the campfire on a moonless night with the fire shadows drawn: the
	# shadows the fire throws from the player, the animals and the trees are drawn every
	# frame.
	var day: float = main.session.clock.time_of_day
	var fire_setting: int = main.settings.values.fire_shadows
	main.settings.values.fire_shadows = 1
	main.settings.apply()
	main.session.clock.time_of_day = 0.95
	main.sky.moon_override = 0.0
	main.player.position = main.session.placed.center(fire_e) + Vector3(0.6, 0.0, -1.4)
	# Until the chunks stop being built (the earlier scenarios left work queued), so
	# the frames measured hold the fire's work and not the streamer's.
	var quiet := 0
	for i in 3000:
		var b: int = main.chunks.budget_us
		await process_frame
		quiet = quiet + 1 if main.chunks.budget_us == b else 0
		if quiet >= 30:
			break
	_check(main.fire_shadows.multimesh.visible_instance_count > 0, "the campfire throws shadows at night")
	# Mixed fire shadows, the default: the nearest fire's real shadow falls from the
	# player alone, the rest stays drawn, and the torch casts none.
	main.settings.values.fire_shadows = 3
	main.settings.apply()
	await create_timer(0.3).timeout
	var real_fires: Array = main.effects.fires.filter(func(f: Dictionary) -> bool: return f.light.shadow_enabled)
	_check(real_fires.size() == 1 and real_fires[0].light.shadow_caster_mask == PixelView.LAYER_PLAYER
		and main.fire_shadows.enabled and not main.player.torch.shadow_enabled,
		"mixed fire shadows: the fire's real shadow is the player's, the rest drawn")
	var kept_at := Time.get_ticks_msec()
	while (not streamer.keep_queue.is_empty() or streamer.job_keep) and Time.get_ticks_msec() - kept_at < 20000:
		await process_frame
	unit[NIGHT] = _chunk_cost()
	await _settle()
	await _scenario(NIGHT, 120, func(_i: int) -> bool: return false)
	main.settings.values.fire_shadows = fire_setting
	main.settings.apply()
	# Graphics quality: a preset is matched by its settings, a change by hand is «своё».
	var graphics: Dictionary = main.settings.values.duplicate()
	# Not «Авто» (AutoQuality), which the quality is when it is on.
	main.settings.values.auto_quality = false
	main.settings.values.merge(main.settings.QUALITIES[1], true)
	var preset: int = main.settings.quality()
	main.settings.values.sun_rays = true
	_check(preset == 1 and main.settings.quality() == -1, "a quality preset is matched, a change by hand is its own")
	main.settings.values = graphics
	main.settings.apply()
	main.hud.open_settings("settings")
	var menu = main.hud._settings
	menu.show_section("graphics")
	await process_frame
	var tall: float = menu.get_combined_minimum_size().y
	var first: String = menu._rows[0].name.text
	menu.show_section("game")
	await process_frame
	_check(first == "[quality]" and menu._rows[0].name.text == "[language]"
		and is_equal_approx(menu.get_combined_minimum_size().y, tall),
		"settings sections by tabs, the window as tall on each")
	var wide: float = menu.size.x
	menu.open("test")
	menu.show_section("debug")
	await process_frame
	var test_wide: float = menu.size.x
	menu.show_section("world")
	menu.open("changes")
	await process_frame
	_check(is_equal_approx(test_wide, wide) and is_equal_approx(menu.size.x, wide),
		"the settings, playtest and changes windows are as wide")
	# A narrower phone than the reference one has the same room in its interface, so the
	# windows fit it as well.
	var room := []
	for screen in [Vector2(1200, 2608), Vector2(1080, 2400), Vector2(720, 1560)]:
		main.hud.fit(Rect2(Vector2.ZERO, screen), true)
		await process_frame
		room.append(main.hud.size.x)
		room.append(menu.size.x <= main.hud.size.x)
	# On a tall phone no page scrolls: the bar shows only when the rows do not fit.
	var bars := []
	for which in ["settings", "test", "changes"]:
		menu.open(which)
		for sec in menu.PAGES.get(which, [[""]]):
			if sec[0] != "":
				menu.show_section(sec[0])
			await process_frame
			await process_frame
			if menu._scroll.get_v_scroll_bar().visible:
				bars.append("%s/%s" % [which, sec[0]])
	_check(bars.is_empty(), "no scroll bar while the rows fit the screen: %s" % [bars])
	menu.open("settings")
	menu.show_section("game")
	# The top of a phone held upright: the minimap two buttons square, the level
	# buttons as tall, the camera cross under it, the clock under the hotbar, and the
	# statistics across the top with the rest moved down under them.
	var hud = main.hud
	hud.fit(Rect2(Vector2.ZERO, Vector2(1200, 2608)), true)
	await process_frame
	var button: float = hud._stats_button.size.x
	var square := is_equal_approx(hud.minimap.size.x, 2 * button + 6) and is_equal_approx(hud.minimap.size.y, 2 * button + 6)
	var level_tall := is_equal_approx(hud._level.size.y, hud.minimap.size.y) and is_equal_approx(hud._level.size.x, button)
	var cross: bool = hud._camera.get_child_count() == 9 and hud._camera.position.y >= hud.minimap.position.y + hud.minimap.size.y
	hud.update_state()
	var clock_under: bool = hud._clock_panel.position.y >= hud._bar.position.y + hud._bar.size.y - 2 \
		and is_equal_approx(hud._clock_panel.position.x + hud._clock_panel.size.x, hud._bar.position.x + hud._bar.size.x)
	var vitals_tall: bool = is_equal_approx(hud.vitals.get_combined_minimum_size().y, button)
	# A long toast wraps before the buttons on the right (made-up texts: not watched).
	Lang.watching = false
	hud.toast("Длинная подсказка, которая никак не помещается в одну строку до кнопок справа")
	await process_frame
	await process_frame
	var toast: Control = hud._toasts.get_child(hud._toasts.get_child_count() - 1)
	var toast_end: float = toast.get_global_rect().end.x
	_check(toast_end <= hud.get_global_transform().origin.x + (hud._level.position.x - 6) * hud.scale.x + 0.5,
		"a long toast wraps before the buttons: ends at %d, the level buttons at %d" % [toast_end,
			hud.get_global_transform().origin.x + hud._level.position.x * hud.scale.x])
	toast.queue_free()
	# A list of toasts keeps the last three: a fourth comes in and the oldest fades up and
	# away, the list closing up under it.
	# The game may say something of its own meanwhile (the bag grown heavy, CI 2026-11-02):
	# then the list is cleared and the toasts are said again, at most three times.
	var left: Array = []
	for attempt in 3:
		for h in hud._toasts.get_children():
			h.queue_free()
		await process_frame
		for n in 4:
			hud.toast("Подсказка %d" % n)
		var faded := Time.get_ticks_msec()
		while Time.get_ticks_msec() - faded < int((hud.TOAST_FADE + 0.3) * 1000.0):
			await process_frame
		left = hud._toasts.get_children().filter(func(h: Node) -> bool: return not h.is_queued_for_deletion())
		if left.all(func(h: Node) -> bool: return h.get_child(0).get_child(0).text.begins_with("Подсказка")):
			break
	Lang.watching = true
	_check(left.size() == 3 and left[0].get_child(0).get_child(0).text == "Подсказка 1" and hud._toasts.position.y == 0.0
		and left.all(func(h: Control) -> bool: return h.modulate.a == 1.0),
		"a fourth toast pushes the oldest out: %s, the list at %.1f" % [left.map(func(h: Node) -> String: return h.get_child(0).get_child(0).text), hud._toasts.position.y])
	_check(hud.vitals.mouse_filter == Control.MOUSE_FILTER_STOP and hud._clock_panel.mouse_filter == Control.MOUSE_FILTER_STOP,
		"a tap on the state or the clock does not reach the world")
	# The statistics with their longest lines, two freezes told, do not wrap and stay low.
	hud.perf.reset()
	hud.perf.mark("fire shadow")
	hud.perf.mark("mesh")
	hud.perf.mark("video", "+512 KB")
	hud.perf.add_frame(1.234)
	_check(hud.perf.last_freeze[2] == ["fire shadow", "mesh", "video"] and hud.perf.freeze_marks.get("mesh") == 1,
		"a freeze tells what was marked in the frame before it: %s" % [hud.perf.last_freeze])
	_check(hud.perf.freeze_log.size() == 1 and hud.perf.freeze_log[0][3] == ["fire shadow", "mesh", "video +512 KB"],
		"the freezes' log keeps the marks with what they say: %s" % [hud.perf.freeze_log])
	_check(hud.perf.freeze_log[0][2][0][0] == hud.perf.REST and hud.perf.freeze_log[0].size() == 5,
		"time outside the game's code and the drawing is the browser's, with the draw calls: %s" % [hud.perf.freeze_log])
	hud.perf.add_frame(0.01)
	_check(hud.perf.usual[0] >= 10.0 and hud.perf.freeze_log.size() == 1,
		"an ordinary frame is averaged, not logged: %s" % [hud.perf.usual])
	# A long frame the page saw is told beside the freeze it overlaps; a newer one waits.
	var page_now := Time.get_ticks_msec()
	hud.perf._long_frames = [[page_now - 600.0, 1200.0, "frame 1100,touchmove 40"], [page_now + 500.0, 80.0, "sound 70"]]
	hud.perf._attach_long_frames()
	_check(hud.perf.freeze_log[0][3].back() == "page 1200 ms: frame 1100,touchmove 40" and hud.perf._long_frames.size() == 1,
		"a long frame of the page is told beside its freeze: %s, left %s" % [hud.perf.freeze_log[0][3], hud.perf._long_frames])
	hud.perf._long_frames.clear()
	# A collection the page tells of frames later is told beside the last freeze, once.
	hud.perf._mark_last_freeze("garbage 93 → 61 MB")
	hud.perf._mark_last_freeze("garbage")
	_check(hud.perf.freeze_log[0][3].back() == "garbage 93 → 61 MB" and hud.perf.freeze_log[0][3].count("garbage") == 0,
		"a late told collection is marked on the last freeze once: %s" % [hud.perf.freeze_log[0][3]])
	# The log's window: the ordinary frame first, a tab for each band of length.
	hud.perf.freeze_log.append([10.0, 250.0, [], [], 1])
	hud.perf.freeze_log.append([11.0, 70.0, [], [], 1])
	hud.open_settings("freezes")
	var log_page = hud._settings
	_check(log_page._list.get_child(0).text.begins_with("Usual frame") and log_page._list.get_child_count() == 1 + 3,
		"the freezes' log opens with the ordinary frame and every freeze kept")
	_check(main.freeze_log.lines("critical").size() == 2 and main.freeze_log.lines("big").size() == 0
		and main.freeze_log.lines("small").size() == 1 and log_page._tab_buttons.critical.text == "from 200 2",
		"the freezes' log splits the freezes by their length")
	log_page.show_section("critical")
	_check(log_page._list.get_child(1).text.begins_with("0:10  250 ms"), "the critical tab shows the freeze of 250 ms")
	# The report for a playtest: a line each for the build, the world, the place, the
	# camera, the time, the weather, the light, the settings, the device, the frame, the
	# start (its steps, the mods' records, read and loaded), the starts before (this one
	# kept once the world was built) and the server (the requests through it).
	log_page.open("report")
	var report: String = log_page.report_text()
	_check(report.split("\n").size() == 13 and report.contains("World: ") and report.contains("Weather: ")
		and report.contains("mod data ") and report.contains("(%d records: read " % Content.record_count())
		and report.contains("scripts ") and report.contains(", world ") and report.contains("Earlier starts: ")
		and report.contains("Server: in the game (loop), requests ") and main.net.requests > 0
		and log_page._list.get_child(log_page._list.get_child_count() - 1).text == report, "the playtest report tells the moment: %s" % report)
	log_page.close()
	hud.perf.freeze_log.resize(1)
	hud.perf.last_freeze = [1234.0, [["drawing", 1200.0], ["animals", 20.0], ["sky", 9.0]], ["fire shadow", "mesh"]]
	hud.perf.worst_freeze = [2345.0, [["drawing", 2300.0], ["camera", 40.0], ["sky", 5.0]]]
	hud.perf.freeze_marks = {"fire shadow": 123, "figure": 45, "save": 12, "nothing": 8}
	hud.toggle_stats()
	await process_frame
	await process_frame
	hud.perf.refresh()
	await process_frame
	var stats := Rect2(hud.perf.position, hud.perf.size)
	var across: bool = stats.end.x <= hud.size.x and hud._top.position.y >= stats.end.y \
		and hud.perf.size.x >= hud.size.x - 2 * hud.MARGIN - 1
	var stats_lines: int = hud.perf.summary(true).split("\n").size()
	_check(hud.perf._text.get_line_count() == stats_lines and stats.size.y <= 110.0,
		"the statistics fit an upright phone unwrapped and low: %d lines of %d, %d px tall" % [
			hud.perf._text.get_line_count(), stats_lines, stats.size.y])
	hud.toggle_stats()
	hud.perf.reset()
	# The interface size leaves the touch controls as they are.
	var stick_at: Vector2 = hud.stick.get_global_transform().get_scale()
	hud.ui_size = 4
	hud.fit(Rect2(Vector2.ZERO, Vector2(1200, 2608)), true)
	var stick_big: Vector2 = hud.stick.get_global_transform().get_scale()
	hud.ui_size = main.settings.values.ui_size
	_check(stick_at.is_equal_approx(stick_big), "the interface size does not change the controls': %s %s" % [stick_at, stick_big])
	_check(square and level_tall and cross and clock_under and vitals_tall and across,
		"HUD top: minimap %s, level %s, cross %s, clock %s, state %s, statistics %s" % [square, level_tall, cross,
			clock_under, vitals_tall, across])
	# The minimap one or three buttons square; the level buttons as tall as a large one,
	# the camera cross under them and on the screen beside a small one; hidden, the
	# minimap and the toasts take their room.
	var corner := []
	for k in [0, 2]:
		main.settings.set_value("minimap_size", k)
		var side: float = (k + 1) * button + k * 6
		var cross_box := Rect2(hud._camera.position, hud._camera.size)
		corner.append(is_equal_approx(hud.minimap.size.x, side) and cross_box.end.x <= hud.size.x
			and cross_box.position.y >= maxf(hud.minimap.position.y + hud.minimap.size.y, hud._level.position.y + hud._level.size.y if k == 0 else 0.0)
			and (k == 0 or is_equal_approx(hud._level.size.y, side)))
	main.settings.set_value("level_buttons", false)
	main.settings.set_value("camera_buttons", false)
	corner.append(not hud._level.visible and not hud._camera.visible
		and is_equal_approx(hud._toast_room, minf(hud._top.position.x, hud.minimap.position.x) - 6 - hud.MARGIN))
	main.settings.reset()
	corner.append(hud._level.visible and hud._camera.visible and is_equal_approx(hud.minimap.size.x, 2 * button + 6))
	_check(not false in corner, "minimap sizes and hidden level and camera buttons: %s" % [corner])
	# The camera's middle keeps its size whatever its text; a tap just off a button is
	# not one on the world, one further off is.
	var middle: Vector2 = hud._camera_reset.size
	hud._camera_label.text = "315°\n+2"
	await process_frame
	var steady: bool = hud._camera_reset.size == middle and hud._camera_reset.get_combined_minimum_size() == middle \
		and hud._camera_label.get_combined_minimum_size().x + 8 <= middle.x \
		and is_equal_approx(hud._camera.size.x, hud.minimap.size.x)
	var menu_box: Rect2 = hud._menu_button.get_global_rect()
	var near: Vector2 = menu_box.position + Vector2(-4, menu_box.size.y * 0.5) * hud.scale.x
	var level_box: Rect2 = hud._level.get_global_rect()
	var far: Vector2 = Vector2(level_box.position.x - 20 * hud.scale.x, level_box.get_center().y)
	_check(steady and hud.covers(near) and not hud.covers(far) and not hud.covers(hud.get_global_rect().get_center()),
		"the camera's middle keeps its size %s; safe zone round the buttons: near %s, far %s" % [steady,
			hud.covers(near), hud.covers(far)])
	hud._camera_text = ""
	main.view.layout_ui(main.view.safe_rect)
	_check(room[0] == room[2] and room[0] == room[4] and room[1] and room[3] and room[5],
		"every phone's interface is as wide as the reference phone's, the windows fit: %s" % [room])
	# «По умолчанию» asks first, then puts the settings back.
	menu.open("settings")
	menu.show_section("game")
	main.settings.set_value("shake", false)
	menu._defaults.pressed.emit()
	# Asking, the button turns red and keeps its text.
	var asked: bool = main.settings.values.shake == false and menu._defaults.text == "[defaults]" \
		and menu._defaults.has_theme_stylebox_override("normal")
	menu._defaults.pressed.emit()
	_check(asked and main.settings.values.shake == true and not menu._defaults.has_theme_stylebox_override("normal"),
		"«По умолчанию» asks (red), then resets the settings")
	# Stepping through a row's values never moves the rows (a long value is cut).
	menu.open("test")
	menu.show_section("world")
	await process_frame
	var row_at: Vector2 = menu._rows[0].name.global_position
	var still := true
	for k in menu._rows[1].values.size():
		menu._choices.step(1, 1)
		await process_frame
		still = still and menu._rows[0].name.global_position == row_at
	_check(still, "the rows stay put while values change")
	menu.close()
	# The level buttons look a few levels down from the player's, no further.
	for i in 10:
		streamer.shift_cut(-1)
	_check(streamer.manual_level == maxi(1, main.player.level() - streamer.VIEW_REACH),
		"the view is cut no deeper than a few levels below the player")
	main.settings.free_view = true
	streamer.shift_cut(-1)
	_check(streamer.manual_level == maxi(1, main.player.level() - streamer.VIEW_REACH - 1),
		"the playtest switch lets the view go deeper")
	main.settings.free_view = false
	streamer.reset_view_level()
	# Up to the top of the reach the view stays there, not back at the player's level.
	for i in 2 * streamer.VIEW_REACH + 4:
		streamer.shift_cut(1)
	var top: int = streamer.view_range().y
	_check(streamer.manual_level == (top if top < main.world.size_y - 1 else -1),
		"the level button up stops at the top of the reach: %d of %d" % [streamer.manual_level, top])
	streamer.reset_view_level()
	# The map's zoom buttons are dimmed at the ends of the zoom.
	var map = main.hud.map_view
	var zoom_was: int = map.zoom_index
	map.zoom_by(100)
	var top_dim: bool = map._plus.disabled and not map._minus.disabled
	map.zoom_by(-100)
	_check(top_dim and map._minus.disabled and not map._plus.disabled, "the zoom buttons are dimmed at the ends")
	map.zoom_by(zoom_was)
	# A hurt reddens the screen's edges and puts its number over the player's head.
	var feedback = main.hud.feedback
	var health: float = main.host.player.vitals.health
	main.host.player.vitals.health -= 10.0
	await process_frame
	await process_frame
	_check(feedback._frame > 0.0 and feedback._frame_color == feedback.KINDS.hurt[0]
		and feedback._floats.size() > 0, "a hurt shows the red frame and its number")
	main.host.player.vitals.health = health
	main.session.clock.time_of_day = day
	main.sky.moon_override = -1.0
	main.session.placed.put_out(fire_e)
	inv.add("resources:branch", 1)
	var branches: int = inv.count("resources:branch")
	_check(not fire_e.lit and not main.session.placed.stations_near(main.session.placed.center(fire_e), 3.0).has("core:campfire"),
		"a campfire put out is no station")
	_check(main.session.placed.light(main.host.player, fire_e) and fire_e.lit and inv.count("resources:branch") == branches - 1, "it is lit again for a branch")
	main.session.placed.put_out(fire_e)
	_check(main.session.placed.destroy(fire_e) and not main.session.placed.things.has(fire_e), "a campfire put out is destroyed without a trace")

	# An idle frame of the finished map is the engine's own share: it grows with the
	# chunks on the map and the machine, not with the game's work.
	var idle_ms := 0.0
	for r in runs:
		if r[0] == IDLE:
			idle_ms = _mean(r[1])
	# A chunk on the screen with no ground yet raises the budget (ChunkStreamer.lagging).
	var step_limit: float = (maxi(ChunkStreamer.EDIT_BUDGET_US, ChunkStreamer.LAG_BUDGET_US) + ChunkStreamer.CAP_BUDGET_US) / 1000.0 + 0.25 * chunk_ms
	var free_limit: float = idle_ms + 2.0 + 0.25 * chunk_ms
	print("a frame may spend %.1f ms in the budgeted loops and %.1f ms outside them (an idle frame is %.1f ms)" % [
		step_limit, free_limit, idle_ms])
	for r in runs:
		if r[0] == IDLE or r[0] == NIGHT:
			# At night the fire's light, its sparks and the night sounds come on top of an
			# idle frame: a share of a chunk more. The median frame: what runs every frame
			# moves it, a stall of the machine in a few of them does not.
			var share: float = IDLE_SHARE if r[0] == IDLE else NIGHT_SHARE
			var outside: float = _median_outside(r[1], r[2])
			var limit: float = maxf(unit[r[0]] / share, IDLE_FLOOR if r[0] == IDLE else NIGHT_FLOOR)
			print("%s: %.2f ms a frame past the budgets (limit %.2f, a chunk %.1f ms just before); the game's parts: %s" % [
				r[0], outside, limit, unit[r[0]], _parts_text(parts_us.get(r[0], {}), r[1].size())])
			_check(outside < limit, "%s: a frame takes under 1/%d of a chunk (or the floor) past the budgets (%.2f ms of %.2f)" % [
				r[0], share, outside, limit])
	for r in runs:
		var frames: PackedFloat32Array = r[1]
		var steps: PackedFloat32Array = r[2]
		var worst := 0.0
		var worst_in := 0.0
		var worst_free := 0.0
		var over_step := 0
		var over_free := 0
		for i in frames.size():
			worst = maxf(worst, frames[i])
			worst_in = maxf(worst_in, steps[i])
			worst_free = maxf(worst_free, frames[i] - steps[i])
			if steps[i] > step_limit:
				over_step += 1
			if frames[i] - steps[i] > free_limit:
				over_free += 1
		print("%s: %d frames, average %.1f ms, worst %.1f ms; worst budgeted %.1f ms (%d over), worst outside %.1f ms (%d over)" % [
			r[0], frames.size(), _mean(frames), worst, worst_in, over_step, worst_free, over_free])
		var stalls: int = 1 + frames.size() / STALLS_PER_FRAMES + r[3]
		_check(over_step <= stalls, "%s keeps the budgeted loops under %.1f ms" % [r[0], step_limit])
		_check(over_free <= stalls, "%s keeps the rest of a frame under %.1f ms" % [r[0], free_limit])
		if r[0] == LANDING or r[0] == MOWING:
			# Their one-off frames (events) pass the limit, but never by a chunk.
			_check(worst_free < chunk_ms, "%s: no frame takes a chunk past the budgets (%.1f ms of %.1f)" % [
				r[0], worst_free, chunk_ms])
	_check(Lang.missed.is_empty(), "every text shown has its Russian: %s" % [Lang.missed])
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Runs up to `frames` frames calling `act(i)` before each, until it returns true,
## and keeps the time of each frame and its budgeted part for the verdict at the end.
## `events` is how many frames of it may carry one-off work past the limits (a thing made).
func _scenario(what: String, frames: int, act: Callable, events := 0) -> void:
	var times := PackedFloat32Array()
	var steps := PackedFloat32Array()
	clock = 0.0
	for i in frames:
		if act.call(i):
			break
		var t := Time.get_ticks_usec()
		var b: int = main.chunks.budget_us
		var swept: int = main.hud.swept_us
		await process_frame
		clock += root.get_process_delta_time()
		# Less the test's own search of the screen for untranslated texts (Hud.swept_us).
		times.append((Time.get_ticks_usec() - t - (main.hud.swept_us - swept)) / 1000.0)
		steps.append((main.chunks.budget_us - b) / 1000.0)
		if what == IDLE or what == NIGHT:
			# What the game's parts took in the frame (the statistics' parts, see
			# PerfPanel.note), for the idle checks' message.
			var parts: Dictionary = parts_us.get_or_add(what, {})
			var work: Dictionary = main.hud.perf._work
			for part: String in work:
				parts[part] = parts.get(part, 0) + work[part]
	runs.append([what, times, steps, events])


func _on_taken(_id: String, _from: Vector3, _by: Object = null) -> void:
	taken += 1


## A few frames let pass unjudged after _chunk_cost: it holds the game for half a second
## or more, and the frames after it catch up (the server's tick, the animals, the player's
## body: 10-14 ms past the budgets in the night scenario's first frames, 2026-11-13).
func _settle() -> void:
	var from := Time.get_ticks_msec()
	var frames := 0
	while frames < 10 or Time.get_ticks_msec() - from < 300:
		await process_frame
		frames += 1


## Presses or releases a key for the game, which reads the keyboard through Input.
func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


## What a whole chunk costs on this machine now: the unit the limits are set in. It is
## the mean over the nine chunks round REFERENCE in the test world, made by hand, so a
## change of the generator does not move the limits, times REFERENCE_SCALE. The median
## of three passes: one pass on a shared runner swings by a tenth or more, and every
## limit moves with it.
func _chunk_cost() -> float:
	if reference == null:
		var ground = TestGround.new()
		ground.generate_area(REFERENCE - Vector2i(2, 2), REFERENCE + Vector2i(2, 2))
		reference = ground.world
	var passes: Array[float] = []
	for pass_i in 3:
		var t := Time.get_ticks_usec()
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var x := (REFERENCE.x + dx) * CHUNK
				var z := (REFERENCE.y + dz) * CHUNK
				ChunkMesher.build_chunk(reference, x, z, CHUNK)
				Foliage.build_chunk(reference, x, z, CHUNK)
		passes.append((Time.get_ticks_usec() - t) / 9000.0)
	passes.sort()
	return passes[1] * REFERENCE_SCALE


## The game's parts of a scenario's frames as "игрок 0.21, небо 0.10 …", ms a frame, the
## biggest first; the rest of a frame is the engine's.
func _parts_text(parts: Dictionary, frames: int) -> String:
	var keys: Array = parts.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return parts[a] > parts[b])
	var out := []
	var total := 0.0
	for k: String in keys:
		total += parts[k] / 1000.0 / maxi(frames, 1)
		out.append("%s %.2f" % [k, parts[k] / 1000.0 / maxi(frames, 1)])
	return "%.2f in all (%s)" % [total, ", ".join(out)]


## The median of a scenario's frames less their budgeted part, in milliseconds.
func _median_outside(frames: PackedFloat32Array, steps: PackedFloat32Array) -> float:
	var outside: Array[float] = []
	for i in frames.size():
		outside.append(frames[i] - steps[i])
	if outside.is_empty():
		return 0.0
	outside.sort()
	return outside[outside.size() / 2]


func _mean(times: PackedFloat32Array) -> float:
	var total := 0.0
	for ms in times:
		total += ms
	return total / maxi(times.size(), 1)


## The build mode's palette is made as the hotbar (thread «Исправить дверь и палитру
## строительства», 2026-11-07): its cells as big, on a portrait screen as many as the
## hotbar's slots and hands, arrows when more do not fit, a finger dragging them along.
func _portrait_palette() -> void:
	var hud = main.hud
	var was := Rect2(hud.position, hud.size * hud.scale)
	var inv = main.host.player.inventory
	# Room in the bag past its first row, given back as it was at the end.
	var bag_before: Array = inv.slots.duplicate()
	for i in range(inv.HOTBAR, inv.slots.size()):
		inv.slots[i] = null
	for id in ["materials:planks", "materials:brick", "materials:log_wall", "materials:cut_stone", "materials:wattle",
			"materials:glass", "tools:door", "tools:window", "tools:stool", "tools:table"]:
		if Items.has(id) and inv.count(id) == 0:
			inv.add(id, 1)
	for i in 3:
		await process_frame
	main.build.enter("materials:planks")
	hud.fit(Rect2(0, 0, 1200, 2608))
	await process_frame
	await process_frame
	var bar = hud.build_bar
	_check(bar._columns == bar.COLUMNS_PORTRAIT and bar._slots[0].size.y == hud.SLOT and bar._strip.prev.visible
		and bar._strip.prev.size.x == hud._strip.prev.size.x, "the palette's cells and arrows are the hotbar's (%d cells of %s)"
		% [bar._columns, bar._slots[0].size] + " %s" % [bar._items])
	var slot = bar._slots[1]
	var at: Vector2 = slot.get_global_transform_with_canvas() * (slot.size * 0.5)
	var held: String = main.build.chosen()
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.position = at
	touch.pressed = true
	bar._strip._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = at - Vector2((hud.SLOT + hud.GAP) * hud.scale.x * 2.3, 0.0)
	bar._strip._input(drag)
	touch.pressed = false
	touch.position = drag.position
	bar._strip._input(touch)
	_check(bar._strip.first == 2 and main.build.chosen() == held, "a finger dragged along the palette scrolls it two cells")
	# The action button stays down while the mode builds and comes up as it stops (it
	# stuck down until the bag next changed).
	# (With no blueprint the mode lets go at its next frame: the hud is asked at once.)
	main.build.auto = true
	hud.update_state()
	var down: bool = hud._action.button_pressed and hud._action.text == "[stop]"
	main.build.auto = false
	hud.update_state()
	# The action button keeps its size whatever it says (a long word wraps inside it).
	var was_text: String = hud._action.text
	var sizes: Array = []
	for t in ["Stop", "Level", "Fill with water", "Bandage up"]:
		hud._action.text = t
		sizes.append(hud._action.get_combined_minimum_size())
	hud._action.text = was_text
	_check(sizes.all(func(v: Vector2) -> bool: return v == hud._action.custom_minimum_size),
		"the action button is the same size whatever it says: %s" % [sizes])
	_check(down and not hud._action.button_pressed and hud._action.text == "[build]",
		"the action button comes up when the build stops (%s %s %s)" % [down, hud._action.button_pressed, hud._action.text])
	# Each shape keeps its own height: a floor one, walls three, a room five.
	var hs: Array = []
	for k in ["plane", "line", "square", "cube"]:
		main.build.set_kind(k)
		hs.append(main.build.height)
	main.build.set_kind("line")
	_check(hs == [1, 3, 3, 5], "the shapes begin one, three, three and five high: %s" % [hs])
	main.build.leave()
	inv.slots = bag_before
	hud.fit(was)
	await process_frame


## A portrait phone screen shows four hotbar slots between two arrows, which move them
## a slot at a time and stop at the ends; a finger dragged along the slots moves them a
## slot per slot.
func _portrait_hotbar() -> void:
	var hud = main.hud
	var was := Rect2(hud.position, hud.size * hud.scale)
	hud.fit(Rect2(0, 0, 1200, 2608))
	await process_frame
	_check(hud._strip.shown == 4 and hud._strip.prev.visible and hud._strip.next.visible,
		"a portrait screen shows four hotbar slots between arrows")
	_check(hud._strip.prev.disabled and not hud._strip.next.disabled, "at the first slot only the next arrow works")
	hud._strip.scroll(1)
	var stepped: int = hud._strip.first
	for i in 8:
		hud._strip.scroll(1)
	var last: int = hud._strip.first
	var stopped: bool = hud._strip.next.disabled
	hud._strip.scroll(-1)
	_check(stepped == 1 and last == 4 and stopped and hud._strip.first == 3,
		"the arrows move the hotbar a slot at a time and stop at the last slot")
	for i in 8:
		hud._strip.scroll(-1)
	_check(hud._strip.first == 0 and hud._slots[0].visible and not hud._slots[4].visible and hud._strip.prev.disabled,
		"and back to the first, without going round")
	await process_frame
	var slot = hud._slots[1]
	var at: Vector2 = slot.get_global_transform_with_canvas() * (slot.size * 0.5)
	var held: String = main.controls.held()
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.position = at
	touch.pressed = true
	hud._strip._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = at - Vector2((hud.SLOT + hud.GAP) * hud.scale.x * 2.3, 0.0)
	hud._strip._input(drag)
	touch.pressed = false
	touch.position = drag.position
	hud._strip._input(touch)
	_check(hud._strip.first == 2 and main.controls.held() == held, "a finger dragged along the hotbar scrolls it two slots")
	hud.fit(Rect2(0, 0, 2608, 1200))
	_check(hud._strip.shown == 8 and not hud._strip.prev.visible, "a landscape phone screen shows all hotbar slots")
	hud.fit(was)
