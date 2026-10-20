extends RefCounted
## Gathering by hand: picking up what lies on the ground (the logs, branches and seeds
## of a felled tree, thrown things, a sack), picking berries off bushes in summer and
## autumn and breaking branches off them. A tap or a click finds the nearest such
## thing within a finger's reach of the point on the screen (plan/design/ui.md: cells
## are too small to hit), within the hands' reach of the player. Berries and branches
## come back every spring. `game` is the Main node.

const Items := preload("res://src/shared/items.gd")
const Bushes := preload("res://src/shared/bushes.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const PixelView := preload("res://src/client/pixel_view.gd")

const CELL := WorldData.CELL
## How far from the player a thing can be taken, in world units.
const REACH := 7.0
## How near the point on the screen a thing must be, in pixels of the world image: a
## finger is wider than a mouse pointer.
const FINGER := 14.0
const POINTER := 7.0
## Things lying this close to the one taken (world units) come along with it.
const PILE := 0.8
const SPRING := 0

var game


func _init(g) -> void:
	game = g


## The thing to gather nearest the screen point, or {}: {"drop": [chunk key, index]}
## or {"bush": cell}, with "at" its position in world units.
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
				if d < best_d and at.distance_to(player_pos) <= REACH:
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
	if target.has("drop"):
		var d: Array = game.world.drops[target.drop[0]][target.drop[1]]
		if d[0] == Items.SACK:
			return "Мешок с вещами\nЛКМ забрать"
		var n: int = d[3] if d.size() > 3 and d[3] is int else 1
		return "%s%s\nЛКМ подобрать" % [Items.title(d[0]), " ×%d" % n if n > 1 else ""]
	var cell: Vector3i = target.bush
	var b: Dictionary = Bushes.TYPES[game.world.bushes[cell]]
	if _ripe(cell, b):
		return "%s, ягоды\nЛКМ собрать" % b.title
	if _twigs_left(cell, b) > 0:
		return "%s\nЛКМ наломать веток" % b.title
	return "%s\nпусто до весны" % b.title


## Gathers `target` (see target_at); true if anything was taken.
func gather(target: Dictionary) -> bool:
	if target.has("drop"):
		return _pick_up(target.drop[0], target.drop[1])
	return game.world.bushes.has(target.bush) and _from_bush(target.bush)


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
			var got: int = character.inventory.add(s[0], s[1])
			if got < s[1]:
				rest.append([s[0], s[1] - got])
		game.hud.toast("Вещи из мешка забраны" if rest.is_empty() else "Забрано не всё: сумка полна")
		return [] if rest.is_empty() else [d[0], d[1], d[2], rest]
	var n: int = d[3] if d.size() > 3 and d[3] is int else 1
	var got: int = character.give(Items.get_item(d[0]).get("id", d[0]), n)
	return [] if got >= n else [d[0], d[1], d[2], n - got]


## Berries off a ripe bush, otherwise a branch while it has any left this year.
func _from_bush(cell: Vector3i) -> bool:
	var world = game.world
	var character = game.character
	var b: Dictionary = Bushes.TYPES[world.bushes[cell]]
	if _ripe(cell, b):
		if not character.act("gather"):
			return false
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([cell, game.sky.day])
		var share: float = game.sky.BERRY_AMOUNT[game.sky.season]
		var n := maxi(1, roundi(rng.randi_range(b.fruit_count[0], b.fruit_count[1]) * share))
		if character.give(b.fruit, n) == 0:
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


## Whether the bush in `cell` has ripe berries to pick.
func _ripe(cell: Vector3i, b: Dictionary) -> bool:
	return b.fruit != "" and not game.world.bush_picked.has(cell) and game.sky.BERRY_AMOUNT[game.sky.season] > 0.0


func _twigs_left(cell: Vector3i, b: Dictionary) -> int:
	return b.twigs - game.world.bush_twigs.get(cell, 0)


## A new season: in spring the bushes have their berries and branches again.
func on_season(season: int) -> void:
	if season != SPRING:
		return
	var world = game.world
	var keys := {}
	for cell: Vector3i in world.bush_picked:
		keys[WorldData.chunk_key(cell.x, cell.z)] = true
	world.bush_picked.clear()
	world.bush_twigs.clear()
	for key in keys:
		game.chunks.remesh_chunk(key)
