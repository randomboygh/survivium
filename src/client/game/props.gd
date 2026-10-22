extends RefCounted
## Things standing on the ground that are not cells and not part of a chunk: what is
## placed from the bag on two by two cells (chests with what they hold, workbenches,
## kilns, campfires; an item's `prop`), the chest and the campfire a new world starts
## with next to the spawn, and the items lying on the ground (WorldData.drops: what a
## felled tree leaves, a death sack). Bushes and snowdrifts are grown by the world
## generator and drawn with the chunk they stand in (see ChunkStreamer, Foliage.finish);
## a bush that goes is taken out of the world and its chunk is rebuilt. Chests and
## stations are solid (WorldData.blockers): the player goes round them or jumps on them.
## A chest is taken up with what it holds; a campfire cannot be carried, but it can be
## put out, lit again for a branch, and destroyed without a trace. `game` is the Main
## node that owns the scene.

const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const VoxelProps := preload("res://src/client/view/voxel_props.gd")
const RoofMap := preload("res://src/client/world/roof_map.gd")
const Items := preload("res://src/shared/content/items.gd")
const PixelTextures := preload("res://src/client/view/pixel_textures.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
const WorldActions := preload("res://src/shared/game/world_actions.gd")

const CELL := WorldData.CELL
## World units the bounding boxes grow by, so the shear of the 3/4 view (which draws a
## thing `y` units north of its place) does not cull it. The models are scaled down to
## 1/16 and the margin grows the box before that, so they get it 16 times over.
const CULL_MARGIN := 24.0
## Things lower than this (world units; the player is 1 tall) are low: the player's
## silhouette does not show behind them (see sprite_xray.gdshader).
const LOW_HEIGHT := 0.75
## Slots of a chest.
const CHEST_SLOTS := 16
## Seconds a thing taken from the ground takes to fly to the player.
const FLY_TIME := 0.2
const MODEL_CULL_MARGIN := CULL_MARGIN * 16.0
## The items of the chest and the campfire by the spawn of a new world.
const CHEST := "core:chest"
const CAMPFIRE := "core:campfire"

var game
## Meshes of the things on the ground by model, and their nodes by chunk.
var drop_meshes := {}
var drop_nodes := {}
## Each thing placed: {"item": id, "cell": Vector3i (the north-west of its two by two
## cells), "node": its model (null for a campfire, drawn by Effects), "items": what a
## chest holds (an Inventory, else null), "fire": a campfire's record in Effects (see
## add_campfire), "lit": false for a campfire put out}. Saved with the world (SaveGame).
var placed: Array = []
## What the chest by the spawn holds (the first chest placed).
var chest_items = null


func _init(g) -> void:
	game = g


## Puts the placed things into the world as the save had them, or a chest and a
## campfire next to the player in a new world; the near chunks are built by then, so
## the ground under them is known.
func place() -> void:
	var meta: Dictionary = game.save.meta
	if meta.get("placed") is Array:
		for e in meta.placed:
			if e is Dictionary and Items.has(e.get("item", "")) and e.get("cell") is Array and e.cell.size() == 3:
				_put(Items.get_item(e.item).id, Vector3i(int(e.cell[0]), int(e.cell[1]), int(e.cell[2])), e.get("items"),
					not e.get("out", false))
	elif meta.get("props") is Dictionary:
		# A save from before things could be placed: the chest and the campfire by name.
		for name in ["chest", "campfire"]:
			var c: Variant = game.save.prop_cell(name)
			if c != null:
				_put(CHEST if name == "chest" else CAMPFIRE, c, meta.get("chest") if name == "chest" else null)
	else:
		var at: Vector3 = game.player.position
		for e in [[CHEST, Vector3(2.0, 0.0, 1.0)], [CAMPFIRE, Vector3(-2.0, 0.0, 2.0)]]:
			var spot := _prop_spot(at + e[1])
			if spot.y >= 0:
				_put(e[0], spot, null)
	_update_heat()


## Places thing `item` (an item with a `prop`) with its north-west cell at `cell`;
## `items` is what a chest holds, as Inventory.to_dict() gave it; `lit` false puts a
## campfire there cold.
func _put(item: String, cell: Vector3i, items: Variant, lit := true) -> Dictionary:
	var kind: String = Items.get_item(item).prop
	var e := {"item": item, "cell": cell, "node": null, "items": null, "fire": null, "lit": true}
	if kind == "campfire":
		e.fire = game.effects.add_campfire(Vector3(cell) * CELL, game.low_mat)
		if not lit:
			game.effects.put_out(e.fire)
			e.lit = false
	else:
		var model = VoxelProps.prop(kind)
		var boxes := VoxelProps.footprint(model)
		for i in 4:
			if boxes[i].has_volume():
				game.world.blockers[cell + Vector3i(i & 1, 0, i >> 1)] = boxes[i]
		var node := MeshInstance3D.new()
		node.mesh = model.build_mesh()
		node.material_override = game.low_mat if node.mesh.get_aabb().end.y / 16.0 < LOW_HEIGHT else game.world_mat
		node.scale = Vector3.ONE / 16.0
		node.position = Vector3(cell) * CELL
		node.extra_cull_margin = MODEL_CULL_MARGIN
		game.world_root.add_child(node)
		e.node = node
	if kind == "chest":
		e.items = Inventory.new(CHEST_SLOTS)
		e.items.nests = false
		if items is Dictionary:
			e.items.from_dict(items)
		if chest_items == null:
			chest_items = e.items
	placed.append(e)
	return e


func _update_heat() -> void:
	RenderingServer.global_shader_parameter_set("heat_map", game.effects.heat_map(RoofMap.WRAP / 2))


## The placed things as plain data for the save.
func to_list() -> Array:
	var out := []
	for e in placed:
		var c: Vector3i = e.cell
		var d := {"item": e.item, "cell": [c.x, c.y, c.z]}
		if e.items != null:
			d.items = e.items.to_dict()
		if not e.lit:
			d.out = true
		out.append(d)
	return out


## The cell of the first thing placed of `item`, or null.
func cell_of(item: String) -> Variant:
	for e in placed:
		if e.item == item:
			return e.cell
	return null


## The middle of placed thing `e` in world units.
func center(e: Dictionary) -> Vector3:
	return (Vector3(e.cell) + Vector3(1.0, 0.5, 1.0)) * CELL


## The placed thing nearest world point `p` within `reach` world units, or {}.
func nearest(p: Vector3, reach: float) -> Dictionary:
	var best := {}
	var best_d := reach
	for e in placed:
		var d := center(e).distance_to(p)
		if d <= best_d:
			best_d = d
			best = e
	return best


## The stations (items with a prop other than a chest; a campfire while it burns)
## within `reach` world units of world point `p`: item id -> true.
func stations_near(p: Vector3, reach: float) -> Dictionary:
	var out := {}
	for e in placed:
		if e.items == null and e.lit and center(e).distance_to(p) <= reach:
			out[e.item] = true
	return out


## The middle of the chest by the spawn in world units, or null when there is none.
func chest_center() -> Variant:
	for e in placed:
		if e.items == chest_items and chest_items != null:
			return center(e)
	return null


## Places item `id` from the bag (from bag slot `slot` when given, else the first that
## holds it) on two by two free cells of level ground in front of the player; a chest
## brings back what it held. True if it was placed.
func put_from_bag(id: String, slot := -1) -> bool:
	var item := Items.get_item(id)
	var inv = game.character.inventory
	if slot < 0:
		for i in inv.slots.size():
			if slot < 0 and inv.slots[i] != null and inv.slots[i][0] == item.get("id", ""):
				slot = i
	if item.get("prop", "none") == "none" or slot < 0 or inv.slots[slot] == null or inv.slots[slot][0] != item.id:
		return false
	var spot: Variant = _spot_in_front()
	if spot == null:
		game.character.nag("put", "Нужно ровное место 2×2 перед собой")
		return false
	if not game.character.act("place"):
		return false
	var taken: Array = inv.take_slot(slot, 1)
	for dz in 2:
		for dx in 2:
			_level_ground(spot + Vector3i(dx, -1, dz))
			remove_bush(spot + Vector3i(dx, 0, dz))
	_put(item.id, spot, taken[3] if taken.size() > 3 else null)
	if item.prop == "campfire":
		_update_heat()
	game.world.note_edit(spot.x, spot.z)
	return true


## Takes placed thing `e` back into the bag, a chest with what it holds (its weight
## and theirs go to the bag); not a campfire (see put_out and destroy). True if it was
## taken.
func take_up(e: Dictionary) -> bool:
	if Items.get_item(e.item).prop == "campfire":
		game.character.nag("take", "Костёр не унести: его можно потушить и разобрать")
		return false
	var inv = game.character.inventory
	var full: bool = e.items != null and not e.items.is_empty()
	if (inv.add(e.item, 1, 0, e.items.to_dict()) if full else game.character.give(e.item, 1)) < 1:
		game.character.nag("full", "Сумка полна")
		return false
	if full:
		game.hud.toast("+1 %s с вещами" % Items.title(e.item))
	_remove(e)
	return true


## Puts out campfire `e` (see placed): it no longer burns, warms or lets anything be
## made at it.
func put_out(e: Dictionary) -> void:
	if e.fire == null or not e.lit:
		return
	game.effects.put_out(e.fire)
	e.lit = false
	_update_heat()
	game.world.note_edit(e.cell.x, e.cell.z)


## Lights campfire `e` again for a branch from the bag; true if it burns.
func light(e: Dictionary) -> bool:
	if e.fire == null or e.lit:
		return e.lit
	if game.character.inventory.remove(Items.BRANCH, 1) < 1:
		game.character.nag("light", "Чтобы разжечь, нужна ветка")
		return false
	game.effects.remove_campfire(e.fire)
	e.fire = game.effects.add_campfire(Vector3(e.cell) * CELL, game.low_mat)
	e.lit = true
	_update_heat()
	game.world.note_edit(e.cell.x, e.cell.z)
	return true


## Destroys campfire `e` that has been put out: nothing is left of it.
func destroy(e: Dictionary) -> bool:
	if e.fire == null or e.lit:
		return false
	_remove(e)
	return true


## Takes placed thing `e` out of the world.
func _remove(e: Dictionary) -> void:
	if e.node != null:
		e.node.queue_free()
	if e.fire != null:
		game.effects.remove_campfire(e.fire)
		_update_heat()
	for dz in 2:
		for dx in 2:
			game.world.blockers.erase(e.cell + Vector3i(dx, 0, dz))
	if e.items == chest_items:
		chest_items = null
	placed.erase(e)
	game.world.note_edit(e.cell.x, e.cell.z)


## The north-west cell of two by two cells in front of the player where a thing can be
## placed (see _fits), the nearest to two cells ahead, at the feet's level or a cell
## below or above; null if none.
func _spot_in_front() -> Variant:
	var feet: Vector3i = game.controls.feet()
	var s: Vector2i = game.controls.step()
	var aim := Vector2(feet.x + 0.5 + s.x * 2.0, feet.z + 0.5 + s.y * 2.0)
	var corners: Array[Vector2i] = []
	for dz in range(-3, 3):
		for dx in range(-3, 3):
			corners.append(Vector2i(feet.x + dx, feet.z + dz))
	corners.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (Vector2(a) + Vector2.ONE).distance_squared_to(aim) < (Vector2(b) + Vector2.ONE).distance_squared_to(aim))
	for c in corners.slice(0, 6):
		for dy in [0, -1, 1]:
			var corner := Vector3i(c.x, feet.y + dy, c.y)
			if _fits(corner):
				return corner
	return null


## Whether the two by two cells from `corner` are free (no cell, no other thing, not the
## player) and stand on solid ground.
func _fits(corner: Vector3i) -> bool:
	var world = game.world
	for dz in 2:
		for dx in 2:
			var c := corner + Vector3i(dx, 0, dz)
			if world.get_cell(c.x, c.y, c.z) != Mat.AIR or not world.is_solid(c.x, c.y - 1, c.z) \
					or game.player.overlaps_cell(c) or c.y > game.chunks.cut_level:
				return false
	for e in placed:
		var o: Vector3i = e.cell
		if o.y == corner.y and absi(o.x - corner.x) < 2 and absi(o.z - corner.z) < 2:
			return false
	return true


## The north-west cell of two by two free cells on ground at one level near the world
## point `p`, the ground under them levelled; y = -1 when there is no such spot.
func _prop_spot(p: Vector3) -> Vector3i:
	var world = game.world
	var x := floori(p.x / CELL)
	var z := floori(p.z / CELL)
	var y: int = world.surface_y(x, z)
	if y <= 0:
		return Vector3i(0, -1, 0)
	for dz in 2:
		for dx in 2:
			if world.get_cell(x + dx, y, z + dz) != Mat.AIR or not world.is_solid(x + dx, y - 1, z + dz):
				return Vector3i(0, -1, 0)
	for dz in 2:
		for dx in 2:
			_level_ground(Vector3i(x + dx, y - 1, z + dz))
			remove_bush(Vector3i(x + dx, y, z + dz))
	return Vector3i(x, y, z)


## Props stand on level ground: a slope under them becomes a whole cube.
func _level_ground(cell: Vector3i) -> void:
	var world = game.world
	if world.slope_mask(cell.x, cell.y, cell.z) != world.FULL:
		world.set_natural(cell.x, cell.y, cell.z, false)
		game.chunks.on_cell_changed(cell)


## Takes the bush on `cell` out of the world; its chunk is rebuilt without it.
func remove_bush(cell: Vector3i) -> void:
	if not game.world.bushes.has(cell):
		return
	game.world.remove_bush(cell)
	game.chunks.on_cell_changed(cell)


## Shows what lies on the ground in chunk `key` (see WorldData.drops) afresh; a death's
## sack glows (Effects.sack_glow).
func show_drops(key: Vector2i) -> void:
	for node: Node in drop_nodes.get(key, []):
		node.queue_free()
	var nodes := []
	for d: Array in game.world.drops.get(key, []):
		var mesh := _drop_mesh(d[0])
		if mesh == null:
			continue
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = game.low_mat
		# Turned in steps of 45 degrees, which keep the pixels tidy.
		node.basis = Basis(Vector3.UP, -snappedf(d[2], PI / 4.0)).scaled(Vector3.ONE / 16.0)
		node.position = d[1]
		node.extra_cull_margin = MODEL_CULL_MARGIN
		game.world_root.add_child(node)
		nodes.append(node)
		if d[0] == Items.SACK:
			nodes.append(game.effects.sack_glow(d[1]))
	drop_nodes[key] = nodes


## The mesh of a thing of `kind` lying on the ground (see WorldData.drops): its item's
## model, a clod of the block's colour for a block, else a bundle.
func _drop_mesh(kind: String) -> Mesh:
	var item := Items.get_item(kind)
	var name: String = "sack" if kind == Items.SACK else item.get("model", "")
	var m := Mat.index(item.get("place", "")) if name == "" else -1
	if m >= 0:
		name = "block:%d" % m
	elif name == "":
		name = "bundle"
	if not drop_meshes.has(name):
		var model = VoxelProps.block(_tile_colour(m)) if m >= 0 else VoxelProps.drop(name)
		drop_meshes[name] = model.build_mesh() if model != null else null
	return drop_meshes[name]


## The average colour of material `m`'s tile in the terrain atlas.
func _tile_colour(m: int) -> Color:
	var atlas: Texture2D = game.atlas
	if atlas == null:
		return Color(0.5, 0.4, 0.3)
	# Read back from the texture only when the image is not kept (slow in the browser).
	var img: Image = PixelTextures.atlas_image if PixelTextures.atlas_image != null else atlas.get_image()
	var tile: int = PixelTextures.TILE
	var t := m * 3
	var x0: int = (t % PixelTextures.TILES) * tile
	var y0: int = floori(t / float(PixelTextures.TILES)) * tile
	var sum := Color(0, 0, 0, 0)
	for y in tile:
		for x in tile:
			sum += img.get_pixel(x0 + x, y0 + y)
	return sum / float(tile * tile)


## A thing taken from the ground at `from` flies to the player and is gone.
func fly(kind: String, from: Vector3) -> void:
	var mesh := _drop_mesh(kind)
	if mesh == null:
		return
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = game.low_mat
	node.scale = Vector3.ONE / 16.0
	node.position = from
	node.extra_cull_margin = CULL_MARGIN
	game.world_root.add_child(node)
	var tw := node.create_tween()
	tw.tween_property(node, "position", game.player.position + Vector3(0.0, 0.5, 0.0), FLY_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)


## A bush disappears when its cell is filled or the ground under it is dug.
func on_cell_changed(cell: Vector3i) -> void:
	WorldActions.bushes_lose_ground(game.world, cell)
