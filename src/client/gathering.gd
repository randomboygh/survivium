extends RefCounted
## Gathering: picking up what lies on the ground (the logs, branches and seeds of a
## felled tree, what was dug, thrown things, a sack), and what the hand in use does to
## plants: hands pick berries in summer and autumn and break branches off bushes and
## standing trees (seeds too in autumn), a sword knocks the berries to the ground, an
## axe fells a bush into branches, a shovel digs it out to plant elsewhere; hands, a
## sword and a scythe cut the grass (Controls): first what grows tall on it (Plants:
## grain from ears, seeds from flowers, fibre from tall grass), then the grass itself
## down to the ground, for fibre. Bushes, grass seeds and grain are planted from the
## hand or the bag. A tap or a click finds the nearest thing to gather
## within a finger's reach of the point on the screen (plan/design/ui.md: cells are too
## small to hit), within reach of the player. Things lying close to the player fly into
## the bag by themselves unless the setting is off; what the player threw away waits
## until the player has walked off. Berries, branches and seeds come back every spring.
## `game` is the Main node.

const Items := preload("res://src/shared/items.gd")
const Tools := preload("res://src/shared/tools.gd")
const Bushes := preload("res://src/shared/bushes.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const Mat := preload("res://src/shared/materials.gd")
const Trees := preload("res://src/shared/trees.gd")
const Plants := preload("res://src/shared/plants.gd")
const Foliage := preload("res://src/client/foliage.gd")

const CELL := WorldData.CELL
## How far from the player a thing on the ground or a placed thing can be taken or used,
## in world units (ten cells, as Tools.PLACE_REACH).
const REACH := 5.0
## How near the point on the screen a thing must be, in pixels of the world image: a
## finger is wider than a mouse pointer.
const FINGER := 14.0
const POINTER := 7.0
## Things lying this close to the one taken (world units) come along with it.
const PILE := 0.8
const SPRING := 0
const AUTUMN := 2
## Things lying this close to the player's feet (world units) are taken by themselves,
## checked this often (seconds).
const PICKUP := 1.6
const PICKUP_INTERVAL := 0.15
## Berries and branches knocked off a bush land this far from it at most (world units).
const SCATTER := 0.45

var game
var _pickup_clock := 0.0
## Where the player threw things away: those are not taken by themselves until the
## player has gone farther than PICKUP from there.
var _held_back: Array[Vector3] = []


func _init(g) -> void:
	game = g


## The thing to gather nearest the screen point, or {}: {"drop": [chunk key, index]},
## {"bush": cell} or {"prop": a record of Props.placed}, with "at" its position in world
## units. Bushes are within the reach of the tool in hand, things on the ground and
## placed things within REACH.
func target_at(screen_pos: Vector2) -> Dictionary:
	if not game.ready_to_play:
		return {}
	var view = game.view
	var vp_pos: Vector2 = (screen_pos - view.container.global_position) / float(view.container.stretch_shrink)
	var radius: float = FINGER if game.controls.touch else POINTER
	var best := {}
	var best_d := radius
	var player_pos: Vector3 = game.player.position + Vector3(0.0, 0.5, 0.0)
	var world = game.world
	var bush_reach: float = game.controls.tool_record().reach * CELL
	for e: Dictionary in game.props.placed:
		var at: Vector3 = game.props.center(e)
		if at.distance_to(player_pos) <= REACH:
			var d := _screen_distance(at, vp_pos)
			if d < best_d + 6.0:
				best_d = d
				best = {"prop": e, "at": at}
	var home := WorldData.chunk_key(floori(player_pos.x / CELL), floori(player_pos.z / CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := home + Vector2i(dx, dz)
			var list: Array = world.drops.get(key, [])
			for i in list.size():
				var at: Vector3 = list[i][1]
				var d := _screen_distance(at + Vector3(0.0, 0.1, 0.0), vp_pos)
				if d < best_d and at.distance_to(player_pos) <= REACH:
					best_d = d
					best = {"drop": [key, i], "at": at}
			var x0: int = key.x << WorldData.SHIFT
			var z0: int = key.y << WorldData.SHIFT
			for cell in world.bushes_in(x0, z0):
				var at := (Vector3(cell) + Vector3(0.5, 0.4, 0.5)) * CELL
				var d := _screen_distance(at, vp_pos)
				if d < best_d and at.distance_to(player_pos) <= bush_reach:
					best_d = d
					best = {"bush": cell, "at": at}
	return best


## Distance on the world image between world point `p` and image point `vp_pos`.
func _screen_distance(p: Vector3, vp_pos: Vector2) -> float:
	var view = game.view
	var center := Vector2(view.camera.global_position.x, view.camera.global_position.z)
	var on_image := (PixelView.screen_plane(p) - center) * PixelView.PIXELS_PER_UNIT + Vector2(view.image_size) * 0.5
	return on_image.distance_to(vp_pos)


## What a tap on `target` would do, for the hint under the pointer.
func describe(target: Dictionary) -> String:
	if target.has("prop"):
		var e: Dictionary = target.prop
		var title := Items.title(e.item)
		if e.items != null:
			return "%s\nЛКМ открыть" % title
		return "%s\nЛКМ крафт" % title
	if target.has("drop"):
		var d: Array = game.world.drops[target.drop[0]][target.drop[1]]
		if d[0] == Items.SACK:
			return "Мешок с вещами\nЛКМ забрать"
		var n: int = _count(d)
		return "%s%s\nЛКМ подобрать" % [Items.title(d[0]), " ×%d" % n if n > 1 else ""]
	var cell: Vector3i = target.bush
	var b: Dictionary = Bushes.TYPES[game.world.bushes[cell]]
	var tool: String = game.controls.tool_record().tool
	if tool == "shovel":
		return "%s\nЛКМ выкопать" % b.title
	if tool == "axe":
		return "%s\nЛКМ срубить" % b.title
	if _ripe(cell, b):
		return "%s, ягоды\nЛКМ %s" % [b.title, "сбить" if tool == "sword" else "собрать"]
	if _twigs_left(cell, b) > 0 and tool == "hand":
		return "%s\nЛКМ наломать веток" % b.title
	return "%s\nпусто до весны" % b.title


## Gathers `target` (see target_at; also {"tree": trunk's column}) with what is in the
## hand in use; true if anything was done.
func gather(target: Dictionary) -> bool:
	if target.has("drop"):
		return _pick_up(target.drop[0], target.drop[1])
	if target.has("prop"):
		game.hud.open_prop(target.prop)
		return true
	if target.has("tree"):
		return _from_tree(target.tree)
	if not game.world.bushes.has(target.bush):
		return false
	var done := false
	match game.controls.tool_record().tool:
		"sword":
			done = _knock_berries(target.bush)
		"axe":
			done = _fell_bush(target.bush)
		"shovel":
			done = _dig_out(target.bush)
		"hand":
			return _from_bush(target.bush)
		_:
			game.character.nag("bush", "Куст: руки собирают, топор рубит, лопата выкапывает")
			return false
	if done:
		game.workshop.use_tool()
	return done


## Whether gather(target) would do anything to the tree or bush of `target` with the
## hand in use now (the action button passes over the ones it would not).
func useful(target: Dictionary) -> bool:
	var tool: String = game.controls.tool_record().tool
	if target.has("tree"):
		if tool != "hand" or not _has_crown(target.tree):
			return false
		var s: Dictionary = Trees.SPECIES[game.world.trees[target.tree]]
		return _tree_seeds_left(target.tree, s) > 0 or _tree_twigs_left(target.tree, s) > 0
	var cell: Vector3i = target.bush
	if not game.world.bushes.has(cell):
		return false
	var b: Dictionary = Bushes.TYPES[game.world.bushes[cell]]
	match tool:
		"axe", "shovel":
			return true
		"sword":
			return _ripe(cell, b)
		"hand":
			return _ripe(cell, b) or _twigs_left(cell, b) > 0
	return false


## Takes by themselves the things lying near the player's feet, unless the setting is
## off; called every frame.
func update(delta: float) -> void:
	_pickup_clock += delta
	if _pickup_clock < PICKUP_INTERVAL:
		return
	_pickup_clock = 0.0
	var feet: Vector3 = game.player.position
	for i in range(_held_back.size() - 1, -1, -1):
		if _held_back[i].distance_to(feet) > PICKUP:
			_held_back.remove_at(i)
	if not game.settings.values.auto_pickup:
		return
	var world = game.world
	var home := WorldData.chunk_key(floori(feet.x / CELL), floori(feet.z / CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := home + Vector2i(dx, dz)
			var list: Array = world.drops.get(key, [])
			var took := false
			for i in range(list.size() - 1, -1, -1):
				var d: Array = list[i]
				if d[1].distance_to(feet) > PICKUP or _is_held_back(d[1]):
					continue
				if d[0] != Items.SACK and game.character.inventory.room_for(Items.get_item(d[0]).get("id", d[0])) == 0:
					continue
				world.take_drop(key, i)
				var rest := _take(d)
				if not rest.is_empty():
					world.add_drop(rest[0], rest[1], rest[2], rest[3])
				if rest.is_empty() or str(rest[3]) != str(d[3]):
					game.props.fly(d[0], d[1])
				took = true
				list = world.drops.get(key, [])
			if took:
				game.props.show_drops(key)


## Keeps what is thrown away at `at` from flying back into the bag at once.
func hold_back(at: Vector3) -> void:
	_held_back.append(at)


func _is_held_back(at: Vector3) -> bool:
	for p in _held_back:
		if p.distance_to(at) <= PILE:
			return true
	return false


## Takes thing `i` of chunk `key` off the ground with the things lying close to it;
## what does not fit in the bag stays where it lay.
func _pick_up(key: Vector2i, i: int) -> bool:
	var world = game.world
	var list: Array = world.drops[key]
	var at: Vector3 = list[i][1]
	if not game.character.act("pick_up"):
		return false
	var near: Array[int] = []
	for j in list.size():
		if j == i or list[j][1].distance_to(at) <= PILE:
			near.append(j)
	# The last index first, so the others stay right while things go.
	near.reverse()
	var took := false
	var left := []
	for j in near:
		var d: Array = world.take_drop(key, j)
		var rest := _take(d)
		took = took or rest.is_empty() or str(rest[3]) != str(d[3] if d.size() > 3 else 1)
		if not rest.is_empty():
			left.append(rest)
	for d: Array in left:
		world.add_drop(d[0], d[1], d[2], d[3])
	game.props.show_drops(key)
	return took


## Puts what drop `d` holds into the bag; returns what is left of it ([] for nothing).
func _take(d: Array) -> Array:
	var character = game.character
	if d[0] == Items.SACK:
		var rest := []
		for s: Array in d[3]:
			var got: int = character.inventory.add(s[0], s[1], s[2] if s.size() > 2 else 0)
			if got < s[1]:
				rest.append([s[0], s[1] - got] + s.slice(2))
		game.hud.toast("Вещи из мешка забраны" if rest.is_empty() else "Забрано не всё: сумка полна")
		return [] if rest.is_empty() else [d[0], d[1], d[2], rest]
	var n := _count(d)
	var worn: int = d[3].get("worn", 0) if d.size() > 3 and d[3] is Dictionary else 0
	var got: int = character.give(Items.get_item(d[0]).get("id", d[0]), n, worn)
	if got >= n:
		return []
	return [d[0], d[1], d[2], {"n": n - got, "worn": worn} if worn > 0 else n - got]


## How many items drop `d` is (see WorldData.drops): its count, or its "n" for a worn tool.
static func _count(d: Array) -> int:
	if d.size() > 3 and d[3] is Dictionary:
		return d[3].get("n", 1)
	return d[3] if d.size() > 3 and d[3] is int else 1


## Berries off a ripe bush, otherwise a branch while it has any left this year.
func _from_bush(cell: Vector3i) -> bool:
	var world = game.world
	var character = game.character
	var b: Dictionary = Bushes.TYPES[world.bushes[cell]]
	if _ripe(cell, b):
		if not character.act("gather"):
			return false
		if character.give(b.fruit, _berry_count(cell, b)) == 0:
			return false
		world.bush_picked[cell] = true
		world.note_bush(cell)
		game.chunks.remesh_chunk(WorldData.chunk_key(cell.x, cell.z))
		return true
	if _twigs_left(cell, b) <= 0:
		character.nag("bush", "На кусте больше ничего нет до весны")
		return false
	if not character.act("gather"):
		return false
	if character.give(Items.BRANCH, 1) == 0:
		return false
	world.bush_twigs[cell] = world.bush_twigs.get(cell, 0) + 1
	world.note_bush(cell)
	return true


## A sword knocks the ripe berries off a bush: they fall on the ground around it.
func _knock_berries(cell: Vector3i) -> bool:
	var b: Dictionary = Bushes.TYPES[game.world.bushes[cell]]
	if not _ripe(cell, b):
		game.character.nag("bush", "Ягод на кусте нет" if b.fruit != "" else "%s без ягод" % b.title)
		return false
	if not game.character.act("cut"):
		return false
	_scatter(cell, b.fruit, _berry_count(cell, b))
	game.world.bush_picked[cell] = true
	game.world.note_bush(cell)
	game.chunks.remesh_chunk(WorldData.chunk_key(cell.x, cell.z))
	return true


## An axe fells a bush: it is gone, and the branches it had left this year lie beside it.
func _fell_bush(cell: Vector3i) -> bool:
	var b: Dictionary = Bushes.TYPES[game.world.bushes[cell]]
	if not game.character.act("chop"):
		return false
	var n := maxi(1, _twigs_left(cell, b))
	game.props.remove_bush(cell)
	_scatter(cell, Items.BRANCH, n)
	return true


## Hands at a standing tree: in autumn its seeds while it has any left this year, else
## a branch while it has any; they go into the bag.
func _from_tree(col: Vector2i) -> bool:
	var world = game.world
	var character = game.character
	if not world.trees.has(col) or not _has_crown(col):
		return false
	var s: Dictionary = Trees.SPECIES[world.trees[col]]
	var seeds := _tree_seeds_left(col, s) > 0
	if not seeds and _tree_twigs_left(col, s) <= 0:
		character.nag("tree", "%s: больше ничего до весны" % s.title)
		return false
	if not character.act("gather"):
		return false
	var id: String = s.seed if seeds else Items.BRANCH
	if character.give(Items.get_item(id).get("id", id), 1) == 0:
		return false
	var map: Dictionary = world.tree_seeds if seeds else world.tree_twigs
	map[col] = map.get(col, 0) + 1
	world.note_edit(col.x, col.y)
	return true


## Whether the tree with its trunk in `col` still has its crown (a felled one leaves a
## stump): leaves on the columns around the top of its trunk.
func _has_crown(col: Vector2i) -> bool:
	var world = game.world
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if world.leaf_col(col.x + dx, col.y + dz) != 0:
				return true
	return false


func _tree_twigs_left(col: Vector2i, s: Dictionary) -> int:
	return s.twigs - game.world.tree_twigs.get(col, 0)


func _tree_seeds_left(col: Vector2i, s: Dictionary) -> int:
	if game.sky.season != AUTUMN or s.seed == "":
		return 0
	return s.seeds - game.world.tree_seeds.get(col, 0)


## Cuts the grass on top of `cells` (see Controls.can_mow) in two stages: first what
## grows tall on it (tall grass, flowers, ears, reeds; see Plants), and the cell stays
## grass cut short until spring (WorldData.turf); grass with nothing tall on it is cut
## down to the material under it (its `mow`) and gives its `mow_gives` with what the
## low grass had. What is cut falls on the cell. True if anything was cut.
func mow(cells: Array[Vector3i]) -> bool:
	if not game.character.act("cut"):
		return false
	var world = game.world
	var keys := {}
	for c in cells:
		var m: int = world.get_cell(c.x, c.y, c.z)
		var to := Tools.mown(m)
		if to < 0:
			continue
		var plants := Foliage.plants_on(world, c.x, c.y, c.z)
		var tall := plants.filter(func(id: String) -> bool: return id != Plants.TUFT)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([c, game.sky.day])
		var gives := {}
		if not tall.is_empty():
			gives = Plants.harvest(tall, rng)
			world.set_turf(c, "")
			game.chunks.remesh_chunk(WorldData.chunk_key(c.x, c.z))
		else:
			gives = Plants.harvest(plants, rng)
			var own: Dictionary = Mat.RECORDS[m].mow_gives
			for id in own:
				gives[id] = gives.get(id, 0) + own[id]
			world.set_turf(c, null)
			world.set_material(c.x, c.y, c.z, to)
			game.chunks.on_cell_changed(c)
		if game.settings.free_build:
			continue
		var at: Vector3 = game.controls.floor_under(c + Vector3i.UP)
		for id in gives:
			world.heap_drop(Items.get_item(id).get("id", id), at, gives[id], rng.randf() * TAU)
		keys[WorldData.chunk_key(c.x, c.z)] = true
	for key in keys:
		game.props.show_drops(key)
	return true


## A shovel digs the bush out whole: it lies on the ground as an item to plant again.
func _dig_out(cell: Vector3i) -> bool:
	var b: Dictionary = Bushes.TYPES[game.world.bushes[cell]]
	if not game.character.act("dig"):
		return false
	game.props.remove_bush(cell)
	if b.item != "":
		_scatter(cell, b.item, 1)
	return true


## Lays `n` items `id` on the ground around the bush in `cell`.
func _scatter(cell: Vector3i, id: String, n: int) -> void:
	var world = game.world
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([cell, id, game.sky.day, n])
	var at := (Vector3(cell) + Vector3(0.5, 0.0, 0.5)) * CELL
	var p := at + Vector3(rng.randf_range(-SCATTER, SCATTER), 0.0, rng.randf_range(-SCATTER, SCATTER))
	world.heap_drop(id, Vector3(p.x, at.y, p.z), n, rng.randf() * TAU)
	game.props.show_drops(WorldData.chunk_key(floori(p.x / CELL), floori(p.z / CELL)))


## Plants item `id` from the bag in front of the player: a bush (an item with
## `plant`) on grass, seeds (with `sow`) on the bare ground they grow on; true if it was
## planted.
func plant(id: String) -> bool:
	var spot: Variant = plant_spot(id)
	if spot == null:
		var item := Items.get_item(id)
		game.character.nag("plant", "Сажать можно на ровную траву перед собой" if item.get("plant", "") != "" \
			else "Сеять можно на голую землю перед собой")
		return false
	return plant_at(id, spot)


## The ground cell in front of the player where item `id` would be planted (see
## plant_at), or null.
func plant_spot(id: String) -> Variant:
	var feet: Vector3i = game.controls.feet()
	for o in Tools.front_ring(game.controls.step()):
		for dy in [-1, 0, -2]:
			var cell: Vector3i = feet + o + Vector3i(0, dy, 0)
			if _can_plant(id, cell):
				return cell
	return null


## Plants item `id` from the bag on ground cell `cell` (the cell a bush stands on, or
## the ground that seeds turn into their `sow`); true if it was planted.
func plant_at(id: String, cell: Vector3i) -> bool:
	var item := Items.get_item(id)
	if item.is_empty() or game.character.inventory.count(item.id) == 0:
		game.character.nag("no_seed", "В сумке нет: %s" % Items.title(id))
		return false
	if not _can_plant(id, cell):
		game.character.nag("plant", "Сюда не посадить")
		return false
	if not game.character.act("gather"):
		return false
	var world = game.world
	game.character.inventory.remove(item.id, 1)
	if item.plant != "":
		var at := cell + Vector3i.UP
		Bushes.place(world, at.x, at.y, at.z, Bushes.index(item.plant))
		world.note_bush(at)
		game.chunks.remesh_chunk(WorldData.chunk_key(at.x, at.z))
	else:
		world.set_material(cell.x, cell.y, cell.z, Mat.index(item.sow))
		world.set_turf(cell, item.crop)
		game.chunks.on_cell_changed(cell)
	return true


## Whether item `id` can be planted on ground cell `cell` within reach: a bush on level
## grass with air above, seeds on the ground their `sow` grows from (what that material
## is cut down to) open to the air.
func _can_plant(id: String, cell: Vector3i) -> bool:
	var item := Items.get_item(id)
	var world = game.world
	if item.is_empty() or game.controls.too_far(cell, Tools.PLACE_REACH):
		return false
	var at := cell + Vector3i.UP
	if item.plant != "":
		return Bushes.index(item.plant) >= 0 and Bushes.fits(world, at.x, at.y, at.z) and not world.bushes.has(at) \
			and not game.player.overlaps_cell(at)
	if item.sow == "":
		return false
	var grows := Mat.index(item.sow)
	return grows >= 0 and Tools.mown(grows) == world.get_cell(cell.x, cell.y, cell.z) \
		and world.get_cell(at.x, at.y, at.z) == Mat.AIR and not world.bushes.has(at)


## How many berries the bush in `cell` gives today.
func _berry_count(cell: Vector3i, b: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([cell, game.sky.day])
	var share: float = game.sky.BERRY_AMOUNT[game.sky.season]
	return maxi(1, roundi(rng.randi_range(b.fruit_count[0], b.fruit_count[1]) * share))


## Whether the bush in `cell` has ripe berries to pick.
func _ripe(cell: Vector3i, b: Dictionary) -> bool:
	return b.fruit != "" and not game.world.bush_picked.has(cell) and game.sky.BERRY_AMOUNT[game.sky.season] > 0.0


func _twigs_left(cell: Vector3i, b: Dictionary) -> int:
	return b.twigs - game.world.bush_twigs.get(cell, 0)


## A new season: in spring the bushes and trees have their berries, branches and
## seeds again, and grass cut short grows tall.
func on_season(season: int) -> void:
	if season != SPRING:
		return
	var world = game.world
	var keys := {}
	for cell: Vector3i in world.bush_picked:
		keys[WorldData.chunk_key(cell.x, cell.z)] = true
	for cell: Vector3i in world.bush_picked.keys() + world.bush_twigs.keys():
		world.note_bush(cell)
	for col: Vector2i in world.tree_twigs.keys() + world.tree_seeds.keys():
		world.note_edit(col.x, col.y)
	world.bush_picked.clear()
	world.bush_twigs.clear()
	world.tree_twigs.clear()
	world.tree_seeds.clear()
	# Grass cut short grows tall again; what was sown stays.
	for key: Vector2i in world.turf.keys():
		var cells: Dictionary = world.turf[key]
		for cell: Vector3i in cells.keys():
			if cells[cell] == "":
				world.set_turf(cell, null)
				keys[key] = true
	for key in keys:
		game.chunks.remesh_chunk(key)
