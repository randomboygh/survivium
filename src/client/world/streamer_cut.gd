extends "res://src/client/world/streamer_edits.gd"
## The chunk streamer's level cut (see chunk_streamer.gd): the automatic cut under a roof
## or in a cave, the level buttons, the build mode's floors, the view in layers and its
## solid map, and the caps over the cut on the chunks around the player.

## How much of a frame may go to building caps, in microseconds (see EDIT_BUDGET_US).
const CAP_BUDGET_US := 3000
## How many levels of caps a chunk keeps built (see cap_cache).
const CAP_KEPT := 4
## How many levels above and below the player's the level buttons may look; from deep
## in a pit, up to the surface over it (see view_range).
const VIEW_REACH := 4
## Cells behind the player searched for earth rising over the head (see _rises_behind).
const RISE_REACH := 6
## One step along a diagonal.
const SQRT1_2 := 0.70710678
## Levels above the feet searched for earth that hides the player from the camera.
const HIDE_REACH := 16

var cap_order: Array[Vector2i] = []
var cap_home := Vector2i(-1000000, 0)
var cap_reach := 0
var cut_level := -1
## The build mode's cut of the floors (the level buttons in the build mode, BuildMode): how
## many floors up (down if negative) from the player's the view looks at, a floor as tall as
## the shape drawn (BuildMode.height); 0 for none, the ordinary cut. Only what is built is
## cut there (ChunkMesher.BUILT_BLUE), never natural ground (the user's pick, 2026-11-26).
var build_floor := 0
## Whether the build mode cuts the floors: off on entering it (all floors show, as out of
## it), on from the first press of a level button, off again by the level label (the
## user's pick, 2026-11-27).
var floors_on := false
## The level the floors are cut over (built cells above it are left out), -1 for none.
var build_cut := -1
## The cut that follows the player looks only at natural ground (the build mode, _roof).
var _natural_only := false

## Added to cap_level() for caps over built cells only (the build cut's).
const BUILT_CAPS := 1 << 16

var _depth_steps := Vector4.ZERO
var manual_level := -1
## The column whose surface was found last, and that surface (see view_range).
var _surface_at := Vector3i(1 << 30, 0, 0)
var _surface := 0
## The cut the player's position asks for; the view follows it at once.
var cut_target := -1
## The level the player last stood on: a jump does not move the cut.
var ground_level := 0
var indoor := false
## The view in layers is on: where the automatic cut
## would cut the view, nothing is cut and the shaders dither away what stands in front
## of the player and over their head instead (CaveLayers), from the cell layer_base.
var layers_on := false
var layer_base := Vector3i.ZERO
## The lowest level of earth between the camera and the player's body, -1 for none
## (see _hiding_level); worked out where the player stands.
var hidden_by := -1
## Earth hides the player, but nothing rises behind them: a hill, left whole.
var hill := false
## The earth hidden_by found stands as a sheer wall (see _sheer_below).
var _hide_steep := false
## The view hidden_by was worked out for (up and slope, see _hiding_level).
var _hidden_view := Vector3.ZERO


func update_cut(_delta: float) -> void:
	var player = game.player
	if world == null or player == null:
		return
	if player.body.on_ground:
		ground_level = player.level()
	else:
		# A jump does not move the cut, but a climb by jumps in the air (a playtest
		# switch) takes it along a level behind the feet, so the view leaves a cave
		# with the player instead of on landing; a fall takes it down with the feet.
		ground_level = clampi(ground_level, player.level() - 1, player.level())
	# The player stands on `level` and is two cells tall.
	var level := ground_level
	var px := floori(player.position.x / CELL)
	var pz := floori(player.position.z / CELL)
	# In the build mode the floors are cut over what is built (build_level), and the cut
	# that follows the player looks only at natural ground (_roof).
	var floors := build_level(level)
	if (floors >= 0) != _natural_only:
		_natural_only = floors >= 0
		hidden_at = Vector3i(0, -1000, 0)
	indoor = false
	# Any roof over the head, however high (the vault of a tall cave); `roofed` a natural one
	# in the build mode.
	var roofed := false
	for y in range(level + 2, world.size_y):
		if Mat.is_roof(world.get_cell(px, y, pz)):
			indoor = true
			if not _natural_only or world.is_natural(px, y, pz):
				roofed = true
				break
	var at := Vector3i(px, level, pz)
	solid.flush()
	if at != hidden_at:
		hidden_at = at
		hidden_by = _hiding_level(px, level, pz)
		hill = hidden_by >= 0 and not _hide_steep and not _rises_behind(px, level, pz)
	elif _hidden_view != Vector3(PixelView.up.x, PixelView.up.y, _view_slope()):
		hidden_by = _hiding_level(px, level, pz)
		hill = hidden_by >= 0 and not _hide_steep and not _rises_behind(px, level, pz)
	var target: int = world.size_y
	if manual_level >= 0:
		# Walking away from the levels looked at brings the view back within reach.
		var reach := view_range()
		if manual_level > reach.y:
			manual_level = -1
		else:
			manual_level = maxi(manual_level, reach.x)
	if floors >= 0:
		# The level buttons step by floors meanwhile.
		manual_level = -1
	if (game.view.first_person and not game.view.ortho_test):
		# The eyes see what is round them: nothing cut away, no layers.
		manual_level = -1
	elif floors >= 0 and build_floor != 0:
		# Another floor looked at: natural ground stays whole, no layers.
		pass
	elif manual_level >= 0:
		target = manual_level
	elif roofed:
		# Over the head.
		target = level + 1
	elif hidden_by >= 0 and not hill:
		# Earth between the camera and the player goes where the player stands in a
		# dip (a ravine running across the view, the near wall of a diagonal one, a
		# pit) or behind a sheer wall (a block, a hut, a ledge). A hill or a mountain
		# the player climbs from the far side, its slope coming down to their feet,
		# stays whole (the player shows through it). Walls round the player that hide
		# nothing (a ravine running along the view) open nothing either.
		target = hidden_by - 1
	_update_depth()
	var opened: bool = manual_level < 0 and target < world.size_y and not (game.view.first_person and not game.view.ortho_test)
	# Where the automatic cut would cut the view, the layers open it instead and fill
	# what they leave out with the rock's section, by the solid cells round the player.
	_update_layers(opened, at)
	if layers_on:
		solid.update(world, px, level, pz)
		target = world.size_y
	if floors != build_cut:
		build_cut = floors
		RenderingServer.global_shader_parameter_set("build_cut", 1000.0 if floors < 0 else (floors + 1) * CELL)
		_hide_caps()
	cut_target = target
	if target == cut_level:
		return
	# No delay, chosen or automatic: the view follows each change of level and the
	# player stepping out from under a roof at once (the user's pick, 2026-11-04).
	cut_level = target
	_apply_cut()


## Whether cell (x, y, z) is earth the cut that follows the player opens (Mat.is_roof): in
## the build mode natural ground only (`_natural_only`), what is built has the cut of the
## floors.
func _roof(x: int, y: int, z: int) -> bool:
	return Mat.is_roof(world.get_cell(x, y, z)) and (not _natural_only or world.is_natural(x, y, z))


## The lowest level of earth (not trunks or leaves) that covers most of the body of a
## player standing on `level` in column (x, z), as the camera sees it, or -1. In the
## default 3/4 view a cell (x, y, z) covers the screen rows z - y - 1 .. z - y + 1 (its
## top and its south face) and the body, two cells tall, the rows pz - level - 1.5 ..
## pz - level + 0.5; earth above the head counts where it covers more than half of
## them. A wall the head looks over hides only the legs and is left alone. A turned or
## tilted view looks along its own way: a cell y - level up is drawn over the body
## from (y - level) * slope cells toward the camera.
## EXPERIMENT (ortho_test): the true camera's way down, cells toward it per level.
func _view_slope() -> float:
	if game.view.ortho_test:
		return 1.0 / tan(-game.view.look_pitch)
	return PixelView.slope


func _hiding_level(x: int, level: int, z: int) -> int:
	var up := PixelView.up
	_hidden_view = Vector3(up.x, up.y, _view_slope())
	var body := Vector2(x + 0.5, z + 0.5)
	for y in range(level + 2, mini(level + 2 + HIDE_REACH, world.size_y)):
		var ahead := body - up * _view_slope() * (y - level)
		for c: Vector2 in [ahead + up, ahead]:
			if _roof(floori(c.x), y, floori(c.y)):
				_hide_steep = _sheer_below(c + up, y)
				return y
	return -1


## Whether the two cells under level `y` in the column at `c` are open: the earth
## found over them stands as a sheer wall to the player's side (a hill of the test
## world, a hut, a ledge), not as a slope coming down to the player's feet.
func _sheer_below(c: Vector2, y: int) -> bool:
	for k in [1, 2]:
		if y - k < 0 or _roof(floori(c.x), y - k, floori(c.y)):
			return false
	return true


## Whether earth rises over the head of a player standing on `level` in column (x, z)
## within RISE_REACH cells behind them, away from the camera, straight or at either
## diagonal: the far side of a dip. A ravine running slantwise to the view has its far
## wall straight behind further off than its width, but close at a diagonal (the
## player pressed to the near wall of one, 2026-11-12). Where none does, what hides
## the player is a hill they stand behind.
func _rises_behind(x: int, level: int, z: int) -> bool:
	var up := PixelView.up
	var side := Vector2(-up.y, up.x)
	var body := Vector2(x + 0.5, z + 0.5)
	var y := level + 2
	if y >= world.size_y:
		return false
	for way: Vector2 in [up, (up + side) * SQRT1_2, (up - side) * SQRT1_2]:
		for r in range(1, RISE_REACH + 1):
			var c := body + way * r
			if _roof(floori(c.x), y, floori(c.y)):
				return true
	return false


## The level the build mode's cut of the floors cuts built cells over for a player standing
## on `level`, -1 for none (out of the build mode): on each floor its floor and one row of
## its walls show, all built above them is left out (the user's pick, 2026-11-27), within
## floors_range.
func build_level(level: int) -> int:
	if game.build == null or not game.build.on or (game.view.first_person and not game.view.ortho_test):
		build_floor = 0
		floors_on = false
		return -1
	if not floors_on:
		return -1
	var reach := floors_range()
	return clampi(level + build_floor * floor_height(), reach.x, reach.y)


## The levels the cut of the floors may lie on: anywhere in the world (natural ground is
## never cut, so a floor far up or down shows only what is built there).
func floors_range() -> Vector2i:
	return Vector2i(1, world.size_y - 2)


## How tall a floor is for the build cut: the height of the shape drawn.
func floor_height() -> int:
	return maxi(1, game.build.height)


## Whether the level buttons step by floors (in the build mode, not in first person).
func by_floors() -> bool:
	return game.build != null and game.build.on and not (game.view.first_person and not game.view.ortho_test)


## The highest level a built thing shows on, what the finger can touch (the cut of the
## floors, or the ordinary cut).
func top_level() -> int:
	return mini(cut_level, build_cut) if build_cut >= 0 else cut_level


func shift_cut(d: int) -> void:
	if world == null:
		return
	if by_floors():
		manual_level = -1
		if not floors_on:
			# The first press cuts: down to the player's floor, up to the one above.
			floors_on = true
			build_floor = maxi(0, d)
			return
		# A floor at a time while the next one is within reach (see build_level).
		var reach := floors_range()
		var next := ground_level + (build_floor + d) * floor_height()
		if next >= reach.x and next <= reach.y or build_floor + d == 0:
			build_floor += d
		manual_level = -1
		return
	var reach := view_range()
	# The view stays at the ends of the reach (the level button goes back to the
	# automatic cut); a cut over the whole world is none.
	manual_level = clampi(cut_base() + d, reach.x, reach.y)
	if manual_level >= world.size_y - 1:
		manual_level = -1


## The level the buttons step from: the level chosen, the cut, or above the player
## with none.
func cut_base() -> int:
	if manual_level >= 0:
		return manual_level
	return cut_level if cut_level < world.size_y else game.player.level() + 1


## The lowest and highest levels the level buttons may cut the view at: VIEW_REACH
## around the player's, and from below the surface of the column up to it, so a
## player fallen into a pit can look up out of it. The playtest switch lifts it.
func view_range() -> Vector2i:
	if game.settings.free_view:
		return Vector2i(1, world.size_y)
	var level: int = game.player.level()
	# Looked up again on a step to another column or level (a dug pit changes it).
	var at := Vector3i(floori(game.player.position.x / CELL), level, floori(game.player.position.z / CELL))
	if at != _surface_at:
		_surface_at = at
		_surface = 0
		for y in range(world.size_y - 1, 0, -1):
			if Mat.is_roof(world.get_cell(at.x, y, at.z)):
				_surface = y
				break
	return Vector2i(maxi(1, level - VIEW_REACH), maxi(level + VIEW_REACH, _surface + 1))


## Back to the automatic cut that follows the player.
func reset_view_level() -> void:
	manual_level = -1
	build_floor = 0
	floors_on = false


## Whether level button `d` (1 up, -1 down) has somewhere to go.
func can_shift(d: int) -> bool:
	if by_floors():
		var reach := floors_range()
		if not floors_on:
			var first := ground_level + maxi(0, d) * floor_height()
			return first >= reach.x and first <= reach.y
		var floor_at := ground_level + (build_floor + d) * floor_height()
		return build_floor + d == 0 or floor_at >= reach.x and floor_at <= reach.y
	var view := view_range()
	var next := cut_base() + d
	return next >= view.x and next <= view.y


func _apply_cut() -> void:
	var h := 1000.0 if cut_level >= world.size_y else (cut_level + 1) * CELL
	RenderingServer.global_shader_parameter_set("cut_height", h)
	# The caps follow in update_caps, nearest chunk first; with no cut they go at once.
	if cap_level() < 0:
		_hide_caps()


## Hides the caps of the cut; update_caps builds them again for a new cut.
func _hide_caps() -> void:
	for key in cap_levels:
		cap_nodes[key].visible = false
	cap_levels.clear()
	_caps_ready = -1


## How much darker each level under the sea's surface gets (depth_steps.x, the test
## setting, see sea_bright).
func _update_depth() -> void:
	var steps := Vector4(game.settings.cut_depth(), 0.0, 0.0, 0.0)
	if steps != _depth_steps:
		_depth_steps = steps
		RenderingServer.global_shader_parameter_set("depth_steps", steps)


## Turns the view in layers on or off, from the player's feet in cell `at`.
func _update_layers(on: bool, at: Vector3i) -> void:
	if on == layers_on and (not on or at == layer_base):
		return
	layers_on = on
	layer_base = at
	RenderingServer.global_shader_parameter_set("layer_view",
		Vector4(1.0 if on else 0.0, at.x, at.y, at.z))


## The level the caps of the cut lie on, -1 for none.
## Over built cells only (the build cut of the floors), plus BUILT_CAPS.
func cap_level() -> int:
	if build_cut >= 0:
		return build_cut + BUILT_CAPS if build_cut < world.size_y - 1 else -1
	if cut_level >= world.size_y - 1:
		return -1
	return cut_level


## Shows `mesh`, the cap of chunk `key` at `level`.
func _show_cap(key: Vector2i, level: int, mesh: Mesh) -> void:
	var node: MeshInstance3D = cap_nodes[key]
	node.mesh = mesh
	node.visible = true
	_fit_box(node)
	cap_levels[key] = level


## Brings the caps of the chunks around the player to the current cut, nearest first,
## a few a frame. The cap of a chunk is rebuilt when the cut moves or the chunk is
## edited (its entry in cap_levels goes); chunks out of range lose theirs.
func update_caps() -> void:
	if not game.ready_to_play:
		return
	var home := _player_chunk()
	var far := reach()
	if home != cap_home or far != cap_reach:
		cap_home = home
		cap_reach = far
		_caps_ready = -1
		cap_order.clear()
		for cz in range(home.y - far, home.y + far + 1):
			for cx in range(home.x - far, home.x + far + 1):
				cap_order.append(Vector2i(cx, cz))
		var nearer := func(a: Vector2i, b: Vector2i) -> bool:
			return maxi(absi(a.x - home.x), absi(a.y - home.y)) < maxi(absi(b.x - home.x), absi(b.y - home.y))
		cap_order.sort_custom(nearer)
		for key in cap_levels.keys():
			if maxi(absi(key.x - home.x), absi(key.y - home.y)) > far:
				cap_nodes[key].mesh = null
				cap_levels.erase(key)
		for key in cap_cache.keys():
			if maxi(absi(key.x - home.x), absi(key.y - home.y)) > far:
				cap_cache.erase(key)
	var want: int = cap_level()
	if want < 0 or want == _caps_ready:
		return
	var t0 := Time.get_ticks_usec()
	var all_built := true
	# The caps already built for this level show at once, all of them.
	for key in cap_order:
		if cap_levels.get(key, -1) != want and cap_cache.has(key) and cap_cache[key].has(want) \
				and chunk_nodes.has(key) and cap_nodes.has(key):
			_show_cap(key, want, cap_cache[key][want])
	for key in cap_order:
		if cap_levels.get(key, -1) == want or not chunk_nodes.has(key):
			continue
		if not cap_nodes.has(key):
			var node := MeshInstance3D.new()
			node.material_override = game.world_mat
			# The rock the cap closes casts its own shadow: a cap's, a hair off it,
			# fell on the player jumping by the cut.
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.layers = PixelView.LAYER_GROUND
			game.world_root.add_child(node)
			cap_nodes[key] = node
		game.hud.perf.mark("cut")
		var mesh: Mesh = ChunkMesher.build_cap(world, want % BUILT_CAPS, key.x * CHUNK, key.y * CHUNK, CHUNK,
			want >= BUILT_CAPS)
		var kept: Dictionary = cap_cache.get(key, {})
		if kept.size() >= CAP_KEPT:
			kept.erase(kept.keys()[0])
		kept[want] = mesh
		cap_cache[key] = kept
		_show_cap(key, want, mesh)
		if Time.get_ticks_usec() - t0 > CAP_BUDGET_US:
			all_built = false
			break
	if all_built:
		_caps_ready = want
	budget_us += Time.get_ticks_usec() - t0
