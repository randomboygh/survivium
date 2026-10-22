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
const ChunkMesher := preload("res://src/client/world/chunk_mesher.gd")
const Foliage := preload("res://src/client/world/foliage.gd")
const ChunkStreamer := preload("res://src/client/world/chunk_streamer.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const Shot := preload("res://tools/shot.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const CELL := 0.5
const CHUNK := 16
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
const NIGHT := "idle at night by the campfire"

var main: Node
var checks := 0
var failures := 0
var chunk_ms := 0.0
## What the scenarios' callables count (a lambda gets its own copy of a local), and
## the game time the running scenario has played: the game paces the cut and the
## jumps by it, and a frame here can be a millisecond or ten.
var moved := 0.0
var flips := 0
var clock := 0.0
## Each scenario's name, frame times and the budgeted part of each, judged once the
## idle frame of the finished map is known.
var runs: Array = []


func _initialize() -> void:
	# Without a screen the engine sleeps 6.9 ms a frame (low_processor_usage_mode_sleep_usec),
	# which would hide the game's own time.
	OS.low_processor_usage_mode_sleep_usec = 0
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
	# Loading as in the game: the near chunks, 40 ms a frame.
	while not main.ready_to_play:
		await process_frame
	var w = main.world
	var home := Vector2i((Vector2(main.player.position.x, main.player.position.z) / (CHUNK * CELL)).floor())
	# What a whole chunk costs on this machine, the mean over the chunks around the
	# spawn (a meadow chunk is a few milliseconds, a forest one several times that):
	# the unit the limits are set in.
	var t := Time.get_ticks_usec()
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			ChunkMesher.build_chunk(w, (home.x + dx) * CHUNK, (home.y + dz) * CHUNK, CHUNK)
			Foliage.build_chunk(w, (home.x + dx) * CHUNK, (home.y + dz) * CHUNK, CHUNK)
	chunk_ms = (Time.get_ticks_usec() - t) / 9000.0
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

	# Standing still on the finished map.
	await _scenario("idle", 120, func(_i: int) -> bool: return false)

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
	_check(main.chunks.dirty_chunks.is_empty() and main.chunks.job_mesh == null, "edits are all built")
	_check(w.bushes.size() == bushes_before - 1 and not w.bushes.has(bush), "the bush dug under is gone")

	# The cut moving up and down four times a second, as when walking in and out of
	# a cave: the caps of the chunks around are rebuilt each time.
	var level: int = main.player.level()
	await _scenario("cut changes", 100000, func(_i: int) -> bool:
		main.chunks.manual_level = level - 4 if int(clock / 0.25) % 2 == 0 else -1
		return clock >= 4.0)
	main.chunks.manual_level = -1

	# Jumping in a cave: the view stays cut at the floor level the whole time. The
	# player lands first, and the automatic cut follows the floor after CUT_DELAY.
	main.player.position = Shot._cave(w, main.player.position)
	main.player.body.on_ground = false
	await _scenario("landing in a cave", 100000, func(_i: int) -> bool:
		return main.player.body.on_ground and clock >= 1.0)
	_check(main.chunks.indoor and main.chunks.cut_level < w.size_y, "the view is cut in the cave")
	var cut: int = main.chunks.cut_level
	await _scenario("jumping in a cave", 100000, func(_i: int) -> bool:
		main.controls.jump_held = fmod(clock, 0.8) < 0.1
		if main.chunks.cut_level != cut:
			flips += 1
		return clock >= 4.0)
	main.controls.jump_held = false
	_check(flips == 0, "jumping in a cave does not move the cut (%d flips)" % flips)

	# Working as a player does: a 3x3 floor of stone painted with the brush beside the
	# player, dug out again with the pickaxe a cell every tenth frame, what falls taken
	# up by itself, then digging in front with the action button held.
	var c = main.controls
	var inv = main.character.inventory
	main.settings.give_tools()
	inv.add("core:stone", 9)
	var spot: Vector3i = c.feet() + Vector3i(2, 0, 0)
	while spot.y < w.size_y - 1 and w.is_solid(spot.x, spot.y, spot.z):
		spot.y += 1
	while spot.y > 1 and not w.is_solid(spot.x, spot.y - 1, spot.z):
		spot.y -= 1
	var slot0 = inv.slots[0]
	c.select_slot(0)
	_check(slot0 != null and c.held() == slot0[0], "a hotbar slot is the bag's first row")
	await _portrait_hotbar()
	c.put_in_hand("core:stone")
	c.brush = 2
	var stone_before: int = inv.count("core:stone")
	var placed: int = c.place_at(spot, Vector3i.UP)
	_check(placed > 0 and inv.count("core:stone") == stone_before - placed, "the brush places blocks from the bag")
	var laid: Array[Vector3i] = []
	for cell in Tools.brush_cells(spot, Vector3i.UP, 3):
		if w.get_cell(cell.x, cell.y, cell.z) == Mat.STONE:
			laid.append(cell)
	c.hold("core:stone_pickaxe")
	await _scenario("digging with tools", laid.size() * 10 + 60, func(i: int) -> bool:
		if i % 10 == 0 and i / 10 < laid.size():
			c._cooldown = 0.0
			c.dig_at(laid[i / 10], Vector3i.UP)
		return false)
	var all_dug := true
	for cell in laid:
		all_dug = all_dug and w.get_cell(cell.x, cell.y, cell.z) == Mat.AIR
	_check(all_dug, "the pickaxe digs the stone placed")
	_check(inv.count("core:stone") >= stone_before - placed + laid.size() - 2, "what is dug beside the player flies into the bag")
	# Back on the surface, where the ground in front is soil.
	main.player.position = start
	await _scenario("back to the surface", 100000, func(_i: int) -> bool: return main.player.body.on_ground and clock >= 0.5)
	# Grass in front cut with the scythe held in the right hand: fibre falls and flies
	# into the bag, dirt shows where the grass was.
	c.put_in_hand("core:stone_scythe", 1)
	var mown: Dictionary = main.actions.front_work(main.character, c.tool_record())
	if mown.has("mow"):
		var fibre: int = inv.count("core:fiber")
		var first: Vector3i = mown.mow[0]
		c.action_held = true
		await _scenario("mowing", 100000, func(_i: int) -> bool: return clock >= 1.5)
		c.action_held = false
		_check(w.get_cell(first.x, first.y, first.z) == Mat.DIRT and inv.count("core:fiber") > fibre,
			"the scythe cuts the grass in front into fibre and leaves dirt")
	var dug_before: int = inv.count("core:stone") + inv.count("core:dirt")
	c.put_in_hand("core:wooden_shovel", 0)
	_check(c.active == 0 and c.held() == "core:wooden_shovel" and c.hands[1] == "core:stone_scythe", "each hand holds its own tool")
	c.action_held = true
	await _scenario("action button", 100000, func(_i: int) -> bool: return clock >= 2.0)
	c.action_held = false
	_check(inv.count("core:stone") + inv.count("core:dirt") > dug_before, "the action button digs in front of the player")
	var hands_saved: Dictionary = c.to_dict()
	c.put_in_hand("", 0)
	c.from_dict(hands_saved)
	_check(c.held() == "core:wooden_shovel", "the hands are saved with the player")
	# The last of what the hand in use holds leaves the bag: the hand is bare.
	inv.add("core:sand", 1)
	c.put_in_hand("core:sand", 1, false)
	inv.remove("core:sand", inv.count("core:sand"))
	await process_frame
	_check(c.held() == "" and c.hands[0] == "core:wooden_shovel", "a hand whose last item is gone is bare")
	c.put_in_hand("core:wooden_shovel", 0, false)
	# A stack into the chest by the spawn and back, sorting by hand: a tap on it, a tap
	# on a free slot.
	var bag = main.hud.bag
	main.hud.open_chest()
	bag._manual = true
	var at: int = inv.slots.find(inv.slots.filter(func(x) -> bool: return x != null and x[0] == "core:stone")[0])
	var free: int = main.placed.chest_items.slots.find(null)
	var stones: int = main.placed.chest_items.count("core:stone") + inv.slots[at][1]
	bag._tap(at, true)
	bag._tap(free, false)
	_check(inv.slots[at] == null and main.placed.chest_items.count("core:stone") == stones, "a stack goes into the chest")
	bag._tap(free, false)
	bag._tap(at, true)
	_check(inv.slots[at] != null and main.placed.chest_items.slots[free] == null, "and back into the bag")
	bag._manual = false
	# Else a tap only picks.
	var bag_before: Array = inv.slots.duplicate(true)
	bag._tap(at, true)
	bag._tap(free, false)
	_check(inv.slots == bag_before and main.placed.chest_items.slots[free] == null, "a second tap picks, it moves nothing")
	# «Скинуть всё в сундук» leaves the hotbar row.
	var chest_before: Array = main.placed.chest_items.slots.duplicate(true)
	inv.slots[inv.slots.size() - 1] = ["core:flint", 1]
	bag._put_all_in_chest()
	_check(inv.slots.slice(0, inv.HOTBAR) == bag_before.slice(0, inv.HOTBAR) and inv.slots[inv.slots.size() - 1] == null
		and main.placed.chest_items.count("core:flint") > 0, "all the bag past the hotbar row goes into the chest")
	inv.slots = bag_before
	main.placed.chest_items.slots = chest_before
	bag.close()

	# Crafting as a player does, with the jobs cut short: cord and a workbench by hand,
	# the workbench placed in front, a stone axe made at it, with the craft tab open.
	var shop = main.workshop
	inv.add("core:fiber", 9)
	inv.add("core:branch", 10)
	inv.add("core:flint", 1)
	main.hud.toggle_bag()
	bag.show_tab("craft")
	for id in ["core:cord", "core:workbench"]:
		var r := Crafting.get_recipe(id)
		var n: int = shop.start(r, 3 if id == "core:cord" else 1)
		_check(n > 0, "%s is known and queued" % r.title)
		for j in shop.queue.jobs:
			j.left = 0.05
		await _scenario("crafting " + id, 100000, func(_i: int) -> bool: return shop.queue.jobs.is_empty() or clock >= 2.0)
	_check(inv.count("core:workbench") == 1, "a workbench is made by hand")
	# Out of the pit the action button dug, the player turns until there is room.
	main.player.position = start + Vector3(1.5, 0.0, 1.5)
	await _scenario("stepping out of the pit", 100000, func(_i: int) -> bool: return main.player.body.on_ground and clock >= 0.5)
	var put := false
	for facing in ["s", "e", "n", "w", "se", "sw", "ne", "nw"]:
		main.player.facing = facing
		put = put or main.props.put_from_bag("core:workbench")
	_check(put and shop.stations().has("core:workbench"), "a workbench placed works as a station")
	var axe := Crafting.get_recipe("core:stone_axe")
	var axes: int = inv.count("core:stone_axe")
	_check(shop.start(axe) == 1, "an axe is queued at the workbench")
	for j in shop.queue.jobs:
		j.left = 0.05
	await _scenario("crafting at a workbench", 100000, func(_i: int) -> bool: return shop.queue.jobs.is_empty() or clock >= 2.0)
	_check(inv.count("core:stone_axe") == axes + 1, "a stone axe is made at the workbench")
	main.hud.toggle_bag()
	var bench: Vector3i = main.placed.cell_of("core:workbench")
	_check(main.world.blocks_body(bench.x, bench.y, bench.z), "a workbench is solid")

	# The chest by the spawn taken up with a stone in it, and set down again with it.
	main.placed.chest_items.add("core:stone", 1)
	var chest_e := {}
	for e in main.placed.things:
		if e.items == main.placed.chest_items:
			chest_e = e
	var light_bag: float = inv.weight()
	_check(main.placed.take_up(main.character, chest_e) and inv.weight() > light_bag + 2.0 and main.placed.chest_items == null,
		"the chest is taken up with what it holds")
	var chest_back := false
	for facing in ["s", "e", "n", "w", "se", "sw", "ne", "nw"]:
		main.player.facing = facing
		chest_back = chest_back or main.props.put_from_bag("core:chest")
	_check(chest_back and main.placed.chest_items != null and main.placed.chest_items.count("core:stone") == 1,
		"and set down again with it")
	# The campfire by the spawn put out (no station then), lit again for a branch, put
	# out and destroyed.
	var fire_e := {}
	for e in main.placed.things:
		if e.item == "core:campfire":
			fire_e = e

	# Standing by the campfire on a moonless night with the fire shadows drawn: the
	# shadows the fire throws from the player, the animals and the trees are drawn every
	# frame.
	var day: float = main.clock.time_of_day
	var fire_setting: int = main.settings.values.fire_shadows
	main.settings.values.fire_shadows = 1
	main.settings.apply()
	main.clock.time_of_day = 0.95
	main.sky.moon_override = 0.0
	main.player.position = main.placed.center(fire_e) + Vector3(0.6, 0.0, -1.4)
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
	await _scenario(NIGHT, 120, func(_i: int) -> bool: return false)
	main.settings.values.fire_shadows = fire_setting
	main.settings.apply()
	main.clock.time_of_day = day
	main.sky.moon_override = -1.0
	main.placed.put_out(fire_e)
	inv.add("core:branch", 1)
	var branches: int = inv.count("core:branch")
	_check(not fire_e.lit and not main.placed.stations_near(main.placed.center(fire_e), 3.0).has("core:campfire"),
		"a campfire put out is no station")
	_check(main.placed.light(main.character, fire_e) and fire_e.lit and inv.count("core:branch") == branches - 1, "it is lit again for a branch")
	main.placed.put_out(fire_e)
	_check(main.placed.destroy(fire_e) and not main.placed.things.has(fire_e), "a campfire put out is destroyed without a trace")

	# An idle frame of the finished map is the engine's own share: it grows with the
	# chunks on the map and the machine, not with the game's work.
	var idle_ms := 0.0
	for r in runs:
		if r[0] == "idle":
			idle_ms = _mean(r[1])
	var step_limit: float = (ChunkStreamer.EDIT_BUDGET_US + ChunkStreamer.CAP_BUDGET_US) / 1000.0 + 0.25 * chunk_ms
	var free_limit: float = idle_ms + 2.0 + 0.25 * chunk_ms
	print("a frame may spend %.1f ms in the budgeted loops and %.1f ms outside them (an idle frame is %.1f ms)" % [
		step_limit, free_limit, idle_ms])
	for r in runs:
		if r[0] == "idle" or r[0] == NIGHT:
			var outside: float = _mean(r[1]) - _mean(r[2])
			print("%s: %.2f ms a frame past the budgets (limit %.2f)" % [r[0], outside, chunk_ms / IDLE_SHARE])
			_check(outside < chunk_ms / IDLE_SHARE, "%s: a frame takes under 1/%d of a chunk past the budgets (%.2f ms of %.2f)" % [
				r[0], IDLE_SHARE, outside, chunk_ms / IDLE_SHARE])
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
		var stalls := 1 + frames.size() / STALLS_PER_FRAMES
		_check(over_step <= stalls, "%s keeps the budgeted loops under %.1f ms" % [r[0], step_limit])
		_check(over_free <= stalls, "%s keeps the rest of a frame under %.1f ms" % [r[0], free_limit])
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Runs up to `frames` frames calling `act(i)` before each, until it returns true,
## and keeps the time of each frame and its budgeted part for the verdict at the end.
func _scenario(what: String, frames: int, act: Callable) -> void:
	var times := PackedFloat32Array()
	var steps := PackedFloat32Array()
	clock = 0.0
	for i in frames:
		if act.call(i):
			break
		var t := Time.get_ticks_usec()
		var b: int = main.chunks.budget_us
		await process_frame
		clock += root.get_process_delta_time()
		times.append((Time.get_ticks_usec() - t) / 1000.0)
		steps.append((main.chunks.budget_us - b) / 1000.0)
	runs.append([what, times, steps])


## Presses or releases a key for the game, which reads the keyboard through Input.
func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _mean(times: PackedFloat32Array) -> float:
	var total := 0.0
	for ms in times:
		total += ms
	return total / maxi(times.size(), 1)


## A portrait phone screen shows four hotbar slots between two arrows, which move them
## a slot at a time and stop at the ends; a finger dragged along the slots moves them a
## slot per slot.
func _portrait_hotbar() -> void:
	var hud = main.hud
	var was := Rect2(hud.position, hud.size * hud.scale)
	hud.fit(Rect2(0, 0, 1200, 2608))
	await process_frame
	_check(hud._visible_slots == 4 and hud._prev_button.visible and hud._next_button.visible,
		"a portrait screen shows four hotbar slots between arrows")
	_check(hud._prev_button.disabled and not hud._next_button.disabled, "at the first slot only the next arrow works")
	hud._next_page()
	var stepped: int = hud._first
	for i in 8:
		hud._next_page()
	var last: int = hud._first
	var stopped: bool = hud._next_button.disabled
	hud._prev_page()
	_check(stepped == 1 and last == 4 and stopped and hud._first == 3,
		"the arrows move the hotbar a slot at a time and stop at the last slot")
	for i in 8:
		hud._prev_page()
	_check(hud._first == 0 and hud._slots[0].visible and not hud._slots[4].visible and hud._prev_button.disabled,
		"and back to the first, without going round")
	await process_frame
	var slot = hud._slots[1]
	var at: Vector2 = slot.get_global_transform_with_canvas() * (slot.size * 0.5)
	var held: String = main.controls.held()
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.position = at
	touch.pressed = true
	hud._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = at - Vector2((hud.SLOT + hud.GAP) * hud.scale.x * 2.3, 0.0)
	hud._input(drag)
	touch.pressed = false
	touch.position = drag.position
	hud._input(touch)
	_check(hud._first == 2 and main.controls.held() == held, "a finger dragged along the hotbar scrolls it two slots")
	hud.fit(Rect2(0, 0, 2608, 1200))
	_check(hud._visible_slots == 8 and not hud._prev_button.visible, "a landscape phone screen shows all hotbar slots")
	hud.fit(was)
