extends RefCounted
## What stands and lies on the ground besides the cells, drawn: the things placed on two
## by two cells (Placed, src/shared: chests, workbenches, kilns, campfires), their
## models and fires and the warmth of the fires, and the items lying on the ground
## (WorldData.drops: what a felled tree leaves, a death sack; a beast's carcass that
## names its species is the beast fallen, drawn by Creatures.show_bodies) and those
## flying to the player when taken. Bushes and snowdrifts are grown by the world generator and drawn
## with the chunk they stand in (see ChunkStreamer, Foliage.finish). `game` is the Main
## node that owns the scene.

const Mat := preload("res://src/shared/content/materials.gd")
const Content := preload("res://src/shared/content/content.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const VoxelProps := preload("res://src/client/view/voxel_props.gd")
const RoofMap := preload("res://src/client/world/roof_map.gd")
const Items := preload("res://src/shared/content/items.gd")
const PixelTextures := preload("res://src/client/view/pixel_textures.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const WorldActions := preload("res://src/shared/game/world_actions.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Vibration := preload("res://src/client/ui/vibration.gd")
const Creatures := preload("res://src/client/game/creatures.gd")

const CELL := WorldData.CELL
## World units the bounding box of a thing flying to the player grows by, so the shear
## of the 3/4 view (which draws a thing `y` units north of its place) does not cull it.
## The models are scaled down to 1/16 and the margin grows the box before that, so they
## get it 16 times over. What stays put is culled by its sheared box (fit) instead.
const CULL_MARGIN := 24.0
## World units round a sheared box, for the half pixel snap of the shaders.
const FIT_MARGIN := 0.25
## Things lower than this (world units; the player is 1 tall) are low: the player's
## silhouette does not show behind them (see sprite_xray.gdshader).
const LOW_HEIGHT := 0.75
## Kinds of things placed (an item's `prop`) too thin for the sun's shadow map: a
## boundary post's pole.
const THIN_PROPS := ["post"]
## The rows of a thing's picture (an item's `picture`, see _add_sprite).
const SPRITE_FRONT := 0
const SPRITE_BACK := 1
const SPRITE_LEFT := 2
const SPRITE_RIGHT := 3
const SPRITE_VIEWS := 4
## Seconds a thing taken from the ground takes to fly to the player.
const FLY_TIME := 0.2
## A thing set down drops into place from this many cells up, in DROP_TIME seconds,
## and lands with dust and a thud (plan: item 23 of the 2026-11-13 list); one turned
## where it stands hops HOP of that.
const DROP_HEIGHT := 0.6
const DROP_TIME := 0.24
const HOP := 0.35
## A thing gone and back on the same cell within this many ms was changed where it
## stands (a sign written or turned, Placed._renew; a thing turned, Placed.move), not set
## down: it does not drop.
const RENEW_MS := 300
## Cells a thing dragged in the build mode is held up over its ground (BuildMode).
const LIFT := 0.3
## A thing landing this near the player (world units) is felt (Vibration "thud"): a little
## past Tools.PLACE_REACH (10 cells, 5 units), so whatever the player sets down is felt as it
## lands (the user's pick of 2026-11-26: a buzz as a thing is taken up and as it is set).
const THUD_NEAR := 5.5

var game
## Meshes of the things on the ground by model, their vertices one triangle after
## another ([verts, normals, uvs, uv2s, colours]) by model, and the nodes of the chunks
## shown (their things in one mesh, and a death sack's glow) by chunk.
var drop_meshes := {}
var _drop_arrays := {}
var drop_nodes := {}
## The models of the placed things by prop kind, their nodes and the campfires' records
## in Effects (see Effects.add_campfire) by the thing's cell (see Placed.things).
var _models := {}
var _nodes := {}
var _fires := {}
## The lights set down (Placed.lights): their records in Effects (Effects.add_lamp) by
## their cell; their models are in _nodes.
var _lamps := {}
## Meshes of the lights standing, by item.
var _standing := {}
var _heat_queued := false
## The things just gone, by cell: [item, turn, when (ms)] (see RENEW_MS).
var _gone := {}
## The things drawn as a picture (an item's `picture`) by cell, and the view the camera
## had when their views were last picked (update); their pictures and materials by
## [sprite, view, stage] (sprite_look).
var _sprite_things := {}
var _sprite_up := Vector2.ZERO
var _sprite_textures := {}
var _sprite_materials := {}
## The model of a thing new from the bag held up in the build mode (hold_new), null for none.
var _held_new: MeshInstance3D = null
## Things newly fallen in a chunk wait to be drawn while the ground they came from is
## still drawn whole (a felled tree's chunk not yet rebuilt): they show as the tree goes.
## The chunks waiting, with when they began to; how many things each chunk shows.
var _drops_held := {}
var _drops_shown := {}
## What each chunk's mesh of the things lying draws, by where a thing lies: [kind, first
## vertex, vertices, its sack's glow or null] apiece. A thing taken up is folded away in
## the mesh as it is (`_fold_taken`), not the whole mesh made again.
var _drop_spans := {}
## The longest things newly fallen wait for their chunk to be rebuilt, ms.
const DROPS_HOLD_MS := 4000


func _init(g) -> void:
	game = g


## Draws the things of `placed` (the client's copy, RemotePlaced) as they come and go
## (their solid parts it reads itself from the same models, Placed.read_footprints).
func watch(placed) -> void:
	placed.added.connect(_on_added)
	placed.removed.connect(_on_removed)
	placed.lit_changed.connect(_on_lit_changed)
	placed.fuel_changed.connect(_on_fuel_changed)
	placed.opened.connect(_on_opened)
	placed.joined.connect(_on_opened)
	placed.water_changed.connect(_on_water_changed)
	placed.melt_changed.connect(_on_opened)


## Puts the placed things into the world as the save had them, or the camp of the start
## next to the player in a new world (Placed.start_camp; and the test world's camp); the
## near chunks are built by then, so the ground under them is known. They go into the
## server's things (the saves move to the server at С4); the copy drawn here gets them
## by events.
func place() -> void:
	if game.session == null:
		# A server far away placed them: the copy has them (Protocol.PROPS).
		_heat_later()
		return
	var meta: Dictionary = game.save.meta
	var placed = game.session.placed
	if meta.get("territory") is Dictionary:
		game.session.territory.from_dict(meta.territory)
	if meta.get("plans") is Array:
		game.session.plans.from_list(meta.plans)
	if meta.get("tame") is Array:
		game.session.wildlife.add_tamed(meta.tame)
	if meta.get("vessels") is Array:
		game.session.actions.vessels.from_list(meta.vessels)
	if meta.get("ice_holes") is Array:
		game.session.ice.from_saved(meta.ice_holes)
	# Building decay: as the world was saved; a new world as «New game» set it, a world
	# saved before decay with it on.
	if meta.get("decay") is Dictionary:
		game.session.decay.from_dict(meta.decay)
	elif not game.save.has_save:
		game.session.decay.on = int(game.settings.values.get("world_decay", 1)) != 0
	if meta.get("placed") is Array:
		placed.from_list(meta.placed)
	elif meta.get("props") is Dictionary:
		# A save from before things could be placed: the chest and the campfire by name.
		for name in ["chest", "campfire"]:
			var c: Variant = game.save.prop_cell(name)
			if c != null:
				placed.put(Items.with_prop("chest") if name == "chest" else Placed.CAMPFIRE, c,
					meta.get("chest") if name == "chest" else null)
	else:
		placed.start_camp(game.player.position)
		# The camp of the test world (TestGround.plan_things), for FPS and freezes.
		if game.gen.has_method("plan_things"):
			for t: Array in game.gen.plan_things():
				placed.put_plan(t)
	_heat_later()


## The mods read anew (a hot reload, ModReload): every thing placed, light set down and
## thing on the ground drawn again from its model as its file has it now.
func remodel() -> void:
	_models = {}
	game.effects.windows.forget_models()
	_standing = {}
	drop_meshes = {}
	_drop_arrays = {}
	for list: Array in [game.placed.things, game.placed.lights]:
		for e: Dictionary in list:
			_on_removed(e)
			if not Items.get_item(e.item).is_empty():
				_on_added(e)
	for key: Vector2i in drop_nodes.keys():
		show_drops(key, true)


## The player places item `id` from the bag (see Placed.put_from_bag) below the level
## cut, through the server; true if it was placed (over the loop the reply is in at once).
func put_from_bag(id: String, slot := -1) -> bool:
	game.land.expect_post(id)
	var r = game.net.request(Protocol.PROP_PUT, [id, slot, game.chunks.cut_level, view_turn()])
	return r.done and r.value is bool and r.value


## The quarter turn a thing set down takes to face the camera (Placed.turn, see
## Placed.faces_view): the view looks along PixelView.up, the thing looks back at it.
static func view_turn() -> int:
	return Placed.turn_facing(Tools.step_of(PixelView.up))


## The player sets light `id` down in front (see Placed.put_light_from_bag) below the
## level cut, through the server; true if it was set down.
func put_light(id: String) -> bool:
	var r = game.net.request(Protocol.LIGHT_PUT, [id, game.chunks.cut_level])
	return r.done and r.value is bool and r.value


func _model(kind: String, turn := 0, open := false, join := -1, water := 0, wreath := ""):
	var key := "%s/%d/%s/%d/%d/%s" % [kind, turn, open, join, water, wreath]
	if not _models.has(key):
		var m = VoxelProps.prop(kind)
		if water > 0:
			m = _with_water(m, water)
		if wreath != "":
			m = _with_wreath(m, wreath)
		if join >= 0:
			# A fence: its post, and its model's north rail turned to each side it joins.
			var joined = m.get_script().new()
			for p: Vector3i in m.voxels:
				if p.z >= 3:
					joined.set_voxel(p, m.voxels[p], false)
					continue
				for t in 4:
					if join & (1 << t):
						joined.set_voxel(Placed.turn_voxels([p], 8, t)[0], m.voxels[p], false)
			m = joined
		elif turn != 0 or open:
			# Turned about the middle of its square (a door swung on its hinge first), as
			# Placed turns its solid parts.
			var side: int = Placed.sizes.get(kind, 2) * 8
			var turned = m.get_script().new()
			for p: Vector3i in m.voxels:
				var q: Vector3i = Placed.swung_voxels(Items.with_prop(kind), [p], side)[0] if open else p
				q = Placed.turn_voxels([q], side, turn)[0]
				turned.set_voxel(q, m.voxels[p], m.foliage.has(p))
			m = turned
		_models[key] = m
	return _models[key]


func _on_added(e: Dictionary, still := false) -> void:
	if Placed.is_light(e):
		_add_lamp(e)
		_arrive(e, null)
		return
	if Placed.is_fire(e):
		_add_fire(e)
		if not e.lit:
			game.effects.put_out(_fires[e.cell])
		_heat_later()
		if not Placed.is_hearth(e):
			_arrive(e, null)
			return
	if Items.get_item(e.item).get("picture", "") != "":
		_add_sprite(e, still)
		return
	var node := MeshInstance3D.new()
	var kind: String = Items.get_item(e.item).prop
	var model = _model(kind, e.get("turn", 0), e.get("open", false), e.get("join", -1), _water_step(e), e.get("wreath", ""))
	node.mesh = model.build_mesh()
	node.material_override = game.low_mat if node.mesh.get_aabb().end.y / 16.0 < LOW_HEIGHT else game.world_mat
	if kind in THIN_PROPS:
		# A pole two voxels thin is under a texel of the sun's shadow map: its shadow
		# came out a wide dark slab with a square flag, so it casts none.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif Placed.lets_light(e):
		# Glass: the sun, the moon and the fires shine through a window into the room.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.scale = Vector3.ONE / 16.0
	node.position = Vector3(e.cell) * CELL
	node.layers = PixelView.LAYER_THINGS
	_fit(node)
	game.world_root.add_child(node)
	_nodes[e.cell] = node
	if Placed.lets_light(e):
		game.effects.windows.add(e.cell, node, model)
	if not still:
		_arrive(e, node)


## Door model `m` with the wreath `wreath` (an item's, Placed.hang_wreath) on its front: the
## wreath's model (drawn upright, a voxel before its own north edge) set on the door's
## first leaf before its face, its top at two thirds of the door's height; it swings with the door.
static func _with_wreath(m, wreath: String):
	var w = VoxelProps.drop(Items.get_item(wreath))
	if w == null:
		return m
	var top := 0
	for p: Vector3i in m.voxels:
		top = maxi(top, p.y)
	var hung = m.get_script().new()
	for p: Vector3i in m.voxels:
		hung.set_voxel(p, m.voxels[p], m.foliage.has(p))
	var wtop := 0
	for p: Vector3i in w.voxels:
		wtop = maxi(wtop, p.y)
	# The door's face is its first two layers (z 0, 1) and its handle a voxel before them: the
	# wreath hangs before both, its top at two thirds of the door, under the wall over a doorway
	# that hides the door's top from the view.
	for p: Vector3i in w.voxels:
		hung.set_voxel(p + Vector3i(0, (top + 1) * 2 / 3 - 1 - wtop, 2), w.voxels[p], w.foliage.has(p))
	return hung


## The water a rain catcher shows: its share of what it holds in WATER_STEPS steps,
## each step a share of the layers of its basin (_with_water), in WATER_COLOR.
const WATER_STEPS := 8
const WATER_COLOR := Color(0.33, 0.52, 0.74)
## The step each rain catcher drawn shows, by its cell.
var _water_steps := {}


## The step of water rain catcher `e` shows, 0 for none (or for a thing that is no catcher).
## Thing `e` drawn as its item's picture (`picture`: sprites/things/<picture>.png of its
## bundle, a row a view — the front, the back, facing left, facing right on the screen —
## and a column a stage of its melting, Placed.melt_stage), standing up on its cell like
## an animal, the view picked by how it is turned against the camera (sprite_view).
func _add_sprite(e: Dictionary, still: bool) -> void:
	var item := Items.get_item(e.item)
	var tex := _sprite_texture(item)
	if tex == null:
		return
	var w := tex.get_width() / Placed.MELT_STAGES
	var h := tex.get_height() / SPRITE_VIEWS
	var node := MeshInstance3D.new()
	node.mesh = PixelView.sprite_mesh(w, h)
	var n: int = Placed.size_of(e.item)
	node.position = (Vector3(e.cell) + Vector3(n * 0.5, 0.0, n * 0.5)) * CELL
	node.layers = PixelView.LAYER_THINGS
	# The quad turns to the camera and to the sun in its shader: boxed as a column as wide
	# as the picture each way.
	var half := w / PixelView.PIXELS_PER_UNIT * 0.5
	node.set_meta("box", AABB(Vector3(-half, 0.0, -half), Vector3(half * 2.0, h / PixelView.PIXELS_PER_UNIT, half * 2.0)))
	node.material_override = _sprite_look(item, tex, sprite_view(e.get("turn", 0)), Placed.melt_stage(e))
	_fit(node)
	game.world_root.add_child(node)
	_nodes[e.cell] = node
	_sprite_things[e.cell] = e
	if not still:
		_arrive(e, node)


## The picture of item `item`'s `picture`, read once.
func _sprite_texture(item: Dictionary) -> Texture2D:
	var path := Content.asset(item, "sprites/things/%s.png" % item.picture)
	if not _sprite_textures.has(path):
		var img := Content.picture(path)
		_sprite_textures[path] = ImageTexture.create_from_image(img) if img != null else null
	return _sprite_textures[path]


## The material that shows view `view` of stage `stage` of picture `tex`.
func _sprite_look(item: Dictionary, tex: Texture2D, view: int, stage: int) -> ShaderMaterial:
	var key := "%s/%d/%d" % [item.id, view, stage]
	if not _sprite_materials.has(key):
		var m := Creatures.PlayerScript.sprite_material(Creatures.SpriteShader, tex)
		m.set_shader_parameter("frame_uv", Vector4(float(stage) / Placed.MELT_STAGES, float(view) / SPRITE_VIEWS,
			1.0 / Placed.MELT_STAGES, 1.0 / SPRITE_VIEWS))
		m.set_shader_parameter("sun_shadow_free", 1.0)
		_sprite_materials[key] = m
	return _sprite_materials[key]


## The row of a thing's picture the camera sees it by, the thing turned `turn` (Placed:
## 0 its front to the south): SPRITE_FRONT when it faces the camera, SPRITE_BACK when it
## faces away, else SPRITE_LEFT or SPRITE_RIGHT by the side of the screen it looks to.
static func sprite_view(turn: int) -> int:
	var facing: Vector2 = [Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0)][posmod(turn, 4)]
	var to_camera := facing.dot(-PixelView.up)
	var to_right := facing.dot(PixelView.right)
	if absf(to_camera) >= absf(to_right) - 0.01:
		return SPRITE_FRONT if to_camera > 0.0 else SPRITE_BACK
	return SPRITE_RIGHT if to_right > 0.0 else SPRITE_LEFT


## Each frame: once the camera has turned, the things drawn as pictures show the view
## of them it looks at now.
func update() -> void:
	if _sprite_things.is_empty() or PixelView.up == _sprite_up:
		return
	_sprite_up = PixelView.up
	for cell: Vector3i in _sprite_things:
		var e: Dictionary = _sprite_things[cell]
		if _nodes.has(cell):
			var item := Items.get_item(e.item)
			_nodes[cell].material_override = _sprite_look(item, _sprite_texture(item), sprite_view(e.get("turn", 0)), Placed.melt_stage(e))


func _water_step(e: Dictionary) -> int:
	if not Placed.is_catcher(e):
		return 0
	var step := ceili(Placed.water_share(e) * WATER_STEPS)
	_water_steps[e.cell] = step
	return step


## Rain catcher `e` holds more or less water: drawn anew when the step it shows changed.
func _on_water_changed(e: Dictionary) -> void:
	if _nodes.has(e.cell) and _water_steps.get(e.cell, 0) != ceili(Placed.water_share(e) * WATER_STEPS):
		_on_opened(e)


## Model `m` with water standing in its basin up to `step` of WATER_STEPS: the basin is
## each empty voxel that, in its own layer, is shut in by the model's voxels (not reached
## from outside the model going north, south, east or west), over the lowest such layer;
## the water fills its layers from the bottom up, at least one when there is any.
static func _with_water(m, step: int):
	var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var hi := -lo
	for p: Vector3i in m.voxels:
		lo = Vector3i(mini(lo.x, p.x), mini(lo.y, p.y), mini(lo.z, p.z))
		hi = Vector3i(maxi(hi.x, p.x), maxi(hi.y, p.y), maxi(hi.z, p.z))
	var layers := []
	for y in range(lo.y, hi.y + 1):
		# What of this layer is reached from outside, one cell round the model.
		var out := {}
		var todo: Array[Vector2i] = [Vector2i(lo.x - 1, lo.z - 1)]
		out[todo[0]] = true
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := c + d
				if n.x < lo.x - 1 or n.x > hi.x + 1 or n.y < lo.z - 1 or n.y > hi.z + 1 or out.has(n) \
						or m.voxels.has(Vector3i(n.x, y, n.y)):
					continue
				out[n] = true
				todo.append(n)
		var inside: Array[Vector3i] = []
		for z in range(lo.z, hi.z + 1):
			for x in range(lo.x, hi.x + 1):
				if not out.has(Vector2i(x, z)) and not m.voxels.has(Vector3i(x, y, z)):
					inside.append(Vector3i(x, y, z))
		if not inside.is_empty():
			layers.append(inside)
	if layers.is_empty():
		return m
	var filled = m.get_script().new()
	for p: Vector3i in m.voxels:
		filled.set_voxel(p, m.voxels[p], m.foliage.has(p))
	var n := maxi(1, ceili(float(step) / WATER_STEPS * layers.size()))
	for i in mini(n, layers.size()):
		for p: Vector3i in layers[i]:
			filled.set_voxel(p, WATER_COLOR * (1.08 if i == n - 1 and (p.x + p.z) % 5 == 0 else 1.0))
	return filled


## Door `e` swung, or fence `e` joins its neighbours anew: drawn anew.
func _on_opened(e: Dictionary) -> void:
	if _nodes.has(e.cell):
		_nodes[e.cell].queue_free()
		_nodes.erase(e.cell)
	_on_added(e, true)


func _on_removed(e: Dictionary) -> void:
	_sprite_things.erase(e.cell)
	var now := Time.get_ticks_msec()
	if _gone.size() > 32:
		for c: Vector3i in _gone.keys():
			if now - int(_gone[c][2]) > RENEW_MS:
				_gone.erase(c)
	_gone[e.cell] = [e.item, e.get("turn", 0), now]
	if _lamps.has(e.cell):
		game.effects.remove_lamp(_lamps[e.cell])
		_lamps.erase(e.cell)
	if _nodes.has(e.cell):
		_nodes[e.cell].queue_free()
		_nodes.erase(e.cell)
	game.effects.windows.remove(e.cell)
	if _fires.has(e.cell):
		game.effects.remove_campfire(_fires[e.cell])
		_fires.erase(e.cell)
		_heat_later()


## Thing `e` came while playing (not with the world or a joining): set down, its model
## `node` (null for a campfire or a light, drawn by Effects) drops into place and lands
## with dust and a thud; changed where it stands (a sign written, a thing turned) it does
## not drop, a turned one hops; what comes with the world comes still and silent.
func _arrive(e: Dictionary, node: Node3D) -> void:
	if not game.ready_to_play:
		return
	var was: Array = _gone.get(e.cell, [])
	_gone.erase(e.cell)
	if not was.is_empty() and was[0] == e.item and Time.get_ticks_msec() - int(was[2]) < RENEW_MS:
		if was[1] != e.get("turn", 0):
			game.sound.play("place", Placed.center(e))
			if node != null:
				_fall(node, Vector3(e.cell) * CELL, DROP_HEIGHT * HOP, DROP_TIME * 0.6)
		return
	if node == null:
		_land(e)
		return
	_fall(node, Vector3(e.cell) * CELL, DROP_HEIGHT, DROP_TIME).tween_callback(_land.bind(e))


## Drops `node` onto world point `to` from `height` cells over it in `time` seconds,
## faster as it goes; while it is up it is culled loosely (its box is fitted to `to`).
func _fall(node: Node3D, to: Vector3, height: float, time: float) -> Tween:
	_stop_fall(node)
	node.position = to + Vector3(0.0, height * CELL, 0.0)
	node.extra_cull_margin = CULL_MARGIN
	var tw := node.create_tween()
	tw.tween_property(node, "position", to, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: node.extra_cull_margin = 0.0)
	node.set_meta("fall", tw)
	return tw


## The drop of `node` still going (_fall, settle) stops where it is: a thing taken up
## while it drops is not pulled down under the finger, nor one settled twice.
func _stop_fall(node: Node3D) -> void:
	if not node.has_meta("fall"):
		return
	var tw: Variant = node.get_meta("fall")
	if tw is Tween and tw.is_valid():
		tw.kill()
	node.remove_meta("fall")


## Built cells fell and things fell apart of decay (Protocol.CRUMBLED; `mats` the material
## of each cell, -1 a thing): dust and bits of the material where each was, and one dull
## knock of the nearest, felt beside the player.
func crumbled(cells: Array, mats: PackedInt32Array) -> void:
	var nearest := INF
	var near := Vector3.INF
	var stuff := -1
	for i in cells.size():
		if not cells[i] is Vector3i:
			continue
		var c: Vector3i = cells[i]
		var m: int = mats[i]
		var under: int = game.world.get_cell(c.x, c.y - 1, c.z) if game.world != null else -1
		var dust_of := m if m >= 0 and m < Mat.COUNT else under
		if game.effects != null:
			game.effects.dust(Vector3(c) * CELL, 1.0, dust_of if dust_of != Mat.AIR else -1)
			if m >= 0 and m < Mat.COUNT:
				game.effects.burst((Vector3(c) + Vector3(0.5, 0.5, 0.5)) * CELL, m, randf() * 0.3)
		var at := (Vector3(c) + Vector3(0.5, 0.0, 0.5)) * CELL
		var d := at.distance_to(game.player.position) if game.player != null else 0.0
		if d < nearest:
			nearest = d
			near = at
			stuff = m
	if near.is_finite() and game.sound != null:
		var hit: String = Mat.RECORDS[stuff].hit if stuff >= 0 and stuff < Mat.COUNT else ""
		game.sound.play(hit if hit != "" else "place", near, 1.0, 0.7)
		game.sound.play("place", near, 0.8, 0.6)
	if nearest < THUD_NEAR:
		Vibration.play(game, "thud", 0.0, 1.4)


## Thing `e` touched the ground: dust of the ground under it from its edges, and a thud,
## lower for a bigger thing.
func _land(e: Dictionary) -> void:
	var c: Vector3i = e.cell
	var n: float = 1.0 if Placed.is_light(e) else float(Placed.size_of(e.item))
	var under: int = game.world.get_cell(c.x, c.y - 1, c.z) if game.world != null else -1
	game.effects.dust(Vector3(c) * CELL, n * 0.75 if Placed.is_light(e) else n, under if under != Mat.AIR else -1)
	game.sound.play("place", Placed.center(e), 1.0, 1.0 if n < 2.0 else 0.8)
	# Set down beside the player, the thud is felt (Vibration "thud").
	if game.player != null and Placed.center(e).distance_to(game.player.position) < THUD_NEAR:
		Vibration.play(game, "thud", 0.0, 1.0 if n < 2.0 else 1.4)


## The standing model of light `id` turned `turn` quarters about its middle.
func _standing_turned(id: String, turn: int) -> Mesh:
	var key := "%s/%d" % [id, turn]
	if not _standing.has(key):
		var m = VoxelProps.standing(Items.get_item(id))
		if turn != 0:
			var turned = m.get_script().new()
			for p: Vector3i in m.voxels:
				var q := p
				for i in turn:
					q = Vector3i(-q.z, q.y, q.x)
				turned.set_voxel(q, m.voxels[p], false)
			m = turned
		_standing[key] = m.build_mesh()
	return _standing[key]


## The model of light `e` in `node` turned `turn` quarters (as _turn_model does a thing's).
func _turn_light(node: MeshInstance3D, e: Dictionary, turn: int) -> void:
	if node.get_meta("turn", int(e.get("turn", 0))) == turn:
		return
	node.mesh = _standing_turned(e.item, turn)
	node.set_meta("turn", turn)


## Where the model of thing `e` stands: its north-west cell's corner, a light's in the middle
## of its cell.
func _rest(e: Dictionary) -> Vector3:
	if Placed.is_light(e):
		return (Vector3(e.cell) + Vector3(0.5, 0.0, 0.5)) * CELL
	return Vector3(e.cell) * CELL


## Holds the model of thing `e` up over the north-west cell `corner`, turned `turn` (its own
## when -1), while the build mode drags it (BuildMode); false when it has no model of its own.
func hold_at(e: Dictionary, corner: Vector3i, turn := -1) -> bool:
	var node: Node3D = _nodes.get(e.cell)
	if node == null or not is_instance_valid(node) or not node is MeshInstance3D:
		return false
	_stop_fall(node)
	var light := Placed.is_light(e)
	if light:
		_turn_light(node, e, int(e.get("turn", 0)) if turn < 0 else turn)
	else:
		_turn_model(node, e, int(e.get("turn", 0)) if turn < 0 else turn)
	node.position = Vector3(corner) * CELL + Vector3(0.0, LIFT * CELL, 0.0)
	if light:
		node.position += Vector3(0.5, 0.0, 0.5) * CELL
	node.extra_cull_margin = CULL_MARGIN
	# Its flames go with it, as far as it is carried from where it stands.
	if _fires.has(e.cell):
		game.effects.shift_fire(_fires[e.cell], node.position - _rest(e))
	if _lamps.has(e.cell):
		game.effects.shift_lamp(_lamps[e.cell], node.position - _rest(e))
	return true


## The model of thing `e` in `node` turned `turn` (held up in the build mode and turned
## there); back to its own turn it is its own model again.
func _turn_model(node: MeshInstance3D, e: Dictionary, turn: int) -> void:
	var was: int = node.get_meta("turn", int(e.get("turn", 0)))
	if was == turn:
		return
	var kind: String = Items.get_item(e.item).prop
	node.mesh = _model(kind, turn, e.get("open", false), e.get("join", -1)).build_mesh()
	node.set_meta("turn", turn)


## A thing new from the bag held up in the air by the build mode over the north-west cell
## `corner`, turned `turn`, before it is set down (BuildMode), moved `out` cells more (a door
## or a window held into a wall, drawn before its face: BuildMode.out_of_wall); false for one
## with no model of its own (a campfire, a light). One at a time: drop_new takes it away.
func hold_new(id: String, corner: Vector3i, turn: int, out := Vector3.ZERO) -> bool:
	var item := Items.get_item(id)
	var kind: String = item.get("prop", "none")
	var probe := {"item": id, "cell": corner, "turn": turn, "lit": false}
	if kind == "none" or Placed.is_light_item(id) or Placed.is_fire(probe) and not Placed.is_hearth(probe):
		drop_new()
		return false
	var key := "%s/%d" % [id, turn]
	if _held_new == null or not is_instance_valid(_held_new):
		_held_new = MeshInstance3D.new()
		_held_new.scale = Vector3.ONE / 16.0
		_held_new.layers = PixelView.LAYER_THINGS
		_held_new.extra_cull_margin = CULL_MARGIN
		game.world_root.add_child(_held_new)
	if _held_new.get_meta("key", "") != key:
		_held_new.mesh = _model(kind, turn).build_mesh()
		_held_new.material_override = game.low_mat if _held_new.mesh.get_aabb().end.y / 16.0 < LOW_HEIGHT else game.world_mat
		_held_new.set_meta("key", key)
	_held_new.position = (Vector3(corner) + out) * CELL + Vector3(0.0, LIFT * CELL, 0.0)
	return true


## The thing new from the bag held up (hold_new) goes away: set down, the server's thing
## drops in its place.
func drop_new() -> void:
	if _held_new != null and is_instance_valid(_held_new):
		_held_new.queue_free()
	_held_new = null


## Whether a thing new from the bag is held up (hold_new).
func holding_new() -> bool:
	return _held_new != null and is_instance_valid(_held_new)


## The model of thing `e` dragged and not moved (BuildMode): it drops back where it stands.
func settle(e: Dictionary) -> void:
	if _fires.has(e.cell):
		game.effects.shift_fire(_fires[e.cell], Vector3.ZERO)
	if _lamps.has(e.cell):
		game.effects.shift_lamp(_lamps[e.cell], Vector3.ZERO)
	var node: Node3D = _nodes.get(e.cell)
	if node == null or not is_instance_valid(node):
		return
	if node is MeshInstance3D:
		if Placed.is_light(e):
			_turn_light(node, e, int(e.get("turn", 0)))
		else:
			_turn_model(node, e, int(e.get("turn", 0)))
	var from := node.position
	var to := _rest(e)
	if from.is_equal_approx(to):
		return
	_stop_fall(node)
	node.extra_cull_margin = CULL_MARGIN
	var tw := node.create_tween()
	tw.tween_property(node, "position", to, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: node.extra_cull_margin = 0.0)
	node.set_meta("fall", tw)


## Whether the model of thing `e` stands on its cells (not held up by the build mode nor
## dropping); true when it has no model of its own.
func standing(e: Dictionary) -> bool:
	var node: Node3D = _nodes.get(e.cell)
	if node == null or not is_instance_valid(node):
		return true
	return node.position.is_equal_approx(_rest(e))


## Light `e` set down: its model standing in the middle of its cell and its flame on top
## (Effects.add_lamp), lighting as far as the item's `light`.
func _add_lamp(e: Dictionary) -> void:
	var item := Items.get_item(e.item)
	var turn := int(e.get("turn", 0))
	var mesh: Mesh = _standing_turned(e.item, turn)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.set_meta("turn", turn)
	node.material_override = game.low_mat
	node.scale = Vector3.ONE / 16.0
	node.position = (Vector3(e.cell) + Vector3(0.5, 0.0, 0.5)) * CELL
	node.layers = PixelView.LAYER_THINGS
	_fit(node)
	game.world_root.add_child(node)
	_nodes[e.cell] = node
	var top := mesh.get_aabb().end.y / 16.0
	_lamps[e.cell] = game.effects.add_lamp(node.position + Vector3(0.0, top + 0.03, 0.0), float(item.get("light", 0.0)), e)


func _on_lit_changed(e: Dictionary) -> void:
	if e.lit:
		game.effects.remove_campfire(_fires[e.cell])
		_add_fire(e)
	else:
		game.effects.put_out(_fires[e.cell])
	_heat_later()


## The flames of fire `e` (Effects.add_campfire): a campfire with its ring of stones, a
## fireplace's in the middle of its hearth, low over its floor.
func _add_fire(e: Dictionary) -> void:
	var hearth := Vector3.INF
	if Placed.is_hearth(e):
		hearth = Placed.center(e) + Vector3(0.0, 0.15 - 0.5 * CELL, 0.0)
	_fires[e.cell] = game.effects.add_campfire(Vector3(e.cell) * CELL, game.low_mat, hearth)
	game.effects.fire_strength(_fires[e.cell], Placed.fuel_share(e))


## A campfire was fed or burned down a little: its flames and light follow what it has
## left (Effects.fire_strength).
func _on_fuel_changed(e: Dictionary) -> void:
	if _fires.has(e.cell):
		game.effects.fire_strength(_fires[e.cell], Placed.fuel_share(e))


## The fires' warmth on the ground is drawn again at the end of the frame, once for all
## the fires that came, went or changed in it.
func _heat_later() -> void:
	if _heat_queued:
		return
	_heat_queued = true
	_update_heat.call_deferred()


func _update_heat() -> void:
	_heat_queued = false
	PixelTextures.set_global("heat_map", game.effects.heat_map(RoofMap.WRAP / 2))


## Shows what lies on the ground in chunk `key` (see WorldData.drops) afresh, all of
## it one mesh: a thing apiece cost a draw call in every light's pass and the sun's
## shadow, some 600 calls round a busy camp on the phone (2026-10-24). A death's sack
## glows (Effects.sack_glow). Things only taken up are folded away in the mesh drawn
## (`_fold_taken`) unless `whole`: a busy chunk's mesh took 16-52 ms to make on the phone
## at every pickup (2026-11-15). The bodies of beasts killed are Creatures' (one new
## falls there, unless the chunk `came` in view just now, ChunkStreamer).
func show_drops(key: Vector2i, whole := false, came := false) -> void:
	_show_bodies(key, came)
	var count: int = game.world.drops.get(key, []).size()
	if not whole and _fold_taken(key):
		_drops_shown[key] = count
		return
	# More things than drawn, while a chunk round whose own cells changed is still to be
	# rebuilt (ChunkStreamer.edited, the chunks of a felled tree): drawn when it is
	# (drops_rebuilt), so the logs appear as the tree goes. Fewer (taken up) are drawn
	# at once.
	if count > _drops_shown.get(key, 0) and game.chunks.chunk_nodes.has(key) and _rebuilding_near(key):
		var since: int = _drops_held.get(key, Time.get_ticks_msec())
		if Time.get_ticks_msec() - since < DROPS_HOLD_MS:
			_drops_held[key] = since
			return
	_drops_held.erase(key)
	hide_drops(key)
	if not game.chunks.chunk_nodes.has(key):
		return
	_drops_shown[key] = count
	var nodes := []
	var spans := {}
	var parts := [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(),
		PackedVector2Array(), PackedColorArray()]
	for d: Array in game.world.drops.get(key, []):
		var arrays := _arrays_of(d[0])
		if arrays.is_empty() or Creatures.is_body(d):
			continue
		var span := [d[0], parts[0].size(), (arrays[0] as PackedVector3Array).size(), null]
		if not spans.has(d[1]):
			spans[d[1]] = []
		spans[d[1]].append(span)
		# Turned in steps of 45 degrees, which keep the pixels tidy.
		var turn := Basis(Vector3.UP, -snappedf(d[2], PI / 4.0))
		parts[0].append_array(Transform3D(turn.scaled(Vector3.ONE / 16.0), d[1]) * (arrays[0] as PackedVector3Array))
		parts[1].append_array(Transform3D(turn, Vector3.ZERO) * (arrays[1] as PackedVector3Array))
		for i in range(2, 5):
			parts[i].append_array(arrays[i])
		if d[0] == Items.SACK:
			span[3] = game.effects.sack_glow(d[1])
			nodes.append(span[3])
	if not parts[0].is_empty():
		var surface := []
		surface.resize(Mesh.ARRAY_MAX)
		surface[Mesh.ARRAY_VERTEX] = parts[0]
		surface[Mesh.ARRAY_NORMAL] = parts[1]
		surface[Mesh.ARRAY_TEX_UV] = parts[2]
		surface[Mesh.ARRAY_TEX_UV2] = parts[3]
		surface[Mesh.ARRAY_COLOR] = parts[4]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
		game.hud.perf.mark("props")
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = game.low_mat
		node.layers = PixelView.LAYER_THINGS
		_fit(node)
		game.world_root.add_child(node)
		nodes.append(node)
		_drop_spans[key] = spans
	drop_nodes[key] = nodes


## Folds away in chunk `key`'s mesh of things lying (show_drops) each thing no longer
## there: its vertices all go to one point, so it draws nothing. False (nothing done)
## when the chunk shows no such mesh or something lies there that the mesh lacks.
func _fold_taken(key: Vector2i) -> bool:
	var spans: Dictionary = _drop_spans.get(key, {})
	var nodes: Array = drop_nodes.get(key, [])
	if spans.is_empty() or nodes.is_empty() or not nodes[-1] is MeshInstance3D:
		return false
	var left := {}
	for at: Vector3 in spans:
		left[at] = (spans[at] as Array).duplicate()
	for d: Array in game.world.drops.get(key, []):
		if _arrays_of(d[0]).is_empty() or Creatures.is_body(d):
			continue
		var here: Array = left.get(d[1], [])
		var found := -1
		for i in here.size():
			if here[i][0] == d[0]:
				found = i
				break
		if found < 0:
			return false
		here.remove_at(found)
	var mesh: ArrayMesh = (nodes[-1] as MeshInstance3D).mesh
	var format := mesh.surface_get_format(0)
	var total := mesh.surface_get_array_len(0)
	var stride := RenderingServer.mesh_surface_get_format_vertex_stride(format, total)
	var start := RenderingServer.mesh_surface_get_format_offset(format, total, Mesh.ARRAY_VERTEX)
	for at: Vector3 in left:
		for span: Array in left[at]:
			var nothing := PackedByteArray()
			nothing.resize(int(span[2]) * stride)
			mesh.surface_update_vertex_region(0, start + int(span[1]) * stride, nothing)
			if span[3] != null:
				(span[3] as Node).queue_free()
				nodes.erase(span[3])
			(spans[at] as Array).erase(span)
	return true


## Draws a shot in flight (WorldActions.shoot, its `shot`: [kind, from, to, seconds]):
## the model of the thing shot flies from `from` to `to` (world units) in a low arc,
## turned along its way, and is gone where it lands (it lies there as a drop); it leaves
## `later` seconds from now.
func fly_shot(shot: Array, later := 0.0) -> void:
	var node := MeshInstance3D.new()
	node.mesh = _drop_mesh(shot[0])
	node.material_override = game.low_mat
	# Scaled 1/16: the shear would cull it by its small box.
	node.extra_cull_margin = CULL_MARGIN
	var from: Vector3 = shot[1]
	var to: Vector3 = shot[2]
	var flat := Vector2(to.x - from.x, to.z - from.z)
	var turn := Basis(Vector3.UP, -flat.angle()).scaled(Vector3.ONE / 16.0)
	node.transform = Transform3D(turn, from)
	game.world_root.add_child(node)
	var arc := flat.length() * 0.12
	var tween := node.create_tween()
	if later > 0.0:
		# Shown only once it leaves the hand (an arrow loosed on the shot's third frame).
		node.visible = false
		tween.tween_interval(later)
		tween.tween_callback(node.show)
	tween.tween_method(func(k: float) -> void:
		node.position = from.lerp(to, k) + Vector3(0.0, sin(k * PI) * arc, 0.0), 0.0, 1.0, maxf(0.05, float(shot[3])))
	tween.tween_callback(node.queue_free)
	# Into the water: a splash and rings where it lands.
	if game.effects != null and game.effects.water != null:
		tween.tween_callback(game.effects.water.ring.bind(to + Vector3(0.0, 1.0, 0.0), true))


## Frees what was drawn lying in chunk `key`, as its chunk goes from the screen.
func hide_drops(key: Vector2i) -> void:
	for node: Node in drop_nodes.get(key, []):
		node.queue_free()
	drop_nodes.erase(key)
	_drops_shown.erase(key)
	_drop_spans.erase(key)
	if game.creatures != null and not game.chunks.chunk_nodes.has(key):
		game.creatures.hide_bodies(key)


## The bodies of the beasts killed lying in chunk `key` (Creatures.show_bodies), drawn
## while the chunk is.
func _show_bodies(key: Vector2i, came: bool) -> void:
	if game.creatures == null:
		return
	if game.chunks.chunk_nodes.has(key):
		game.creatures.show_bodies(key, game.world.drops.get(key, []), came)
	else:
		game.creatures.hide_bodies(key)


## A chunk's new mesh is shown (ChunkStreamer): the things that waited for it are drawn.
func drops_rebuilt() -> void:
	for key: Vector2i in _drops_held.keys():
		show_drops(key)


## Whether chunk `key` or one beside it had its own cells changed and waits to be
## rebuilt, or is being (ChunkStreamer.edited); a chunk rebuilt only because it is near
## the change does not count.
func _rebuilding_near(key: Vector2i) -> bool:
	var edited: Dictionary = game.chunks.edited
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if edited.has(key + Vector2i(dx, dz)):
				return true
	return false


## The vertices of the model of a thing of `kind` on the ground, one triangle after
## another, or none for a thing with no model.
func _arrays_of(kind: String) -> Array:
	if _drop_arrays.has(kind):
		return _drop_arrays[kind]
	var arrays := []
	var mesh := _drop_mesh(kind)
	if mesh != null:
		var a := mesh.surface_get_arrays(0)
		var index: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
			var from = a[k]
			var to = from.duplicate()
			to.resize(index.size())
			for i in index.size():
				to[i] = from[index[i]]
			arrays.append(to)
	_drop_arrays[kind] = arrays
	return arrays


## Culls `node` (a model of the things placed or lying) by the box of what it draws in
## the views the camera shows or turns to (PixelView.sheared_box).
func _fit(node: MeshInstance3D) -> void:
	var to_world := node.transform
	var own: AABB = node.get_meta("box", node.mesh.get_aabb())
	var box := PixelView.sheared_box(to_world * own, FIT_MARGIN)
	node.custom_aabb = to_world.affine_inverse() * box
	# A window's glass lit from inside (WindowGlow) is culled with it.
	for child in node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).custom_aabb = node.custom_aabb


## Fits the boxes of every model again for the views the camera shows now (see
## ChunkStreamer.refit_boxes).
func refit_boxes() -> void:
	for node: MeshInstance3D in _nodes.values():
		_fit(node)
	for nodes: Array in drop_nodes.values():
		for node: Node in nodes:
			if node is MeshInstance3D:
				_fit(node)


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
	elif kind != Items.SACK:
		name = VoxelProps.model_path(item, name)
	if not drop_meshes.has(name):
		var model = VoxelProps.block(_tile_colour(m)) if m >= 0 else (VoxelProps.sack() if name == "sack" else (VoxelProps.bundle() if name == "bundle" else VoxelProps.drop(item)))
		if model == null:
			model = VoxelProps.bundle()
		drop_meshes[name] = model.build_mesh()
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
func fly(kind: String, from: Vector3, _by: Object = null) -> void:
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
