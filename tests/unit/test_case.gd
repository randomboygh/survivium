extends RefCounted
## What every unit test file under tests/unit/ extends: the scripts under test as consts,
## `_check`, and the helpers more than one file needs. A file groups the tests of one topic
## and lists them in `run`; run_tests.gd runs the files and adds up the counts.

const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const TestGround := preload("res://src/shared/world/test_ground.gd")
const VoxelRaycast := preload("res://src/shared/world/voxel_raycast.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const ChunkMesher := preload("res://src/client/world/chunk_mesher.gd")
const SlopeMesher := preload("res://src/client/world/slope_mesher.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const SkyScript := preload("res://src/client/view/sky.gd")
const PlayerScript := preload("res://src/client/view/player.gd")
const Body := preload("res://src/shared/game/body.gd")
const VoxelProps := preload("res://src/client/view/voxel_props.gd")
const VoxelModel := preload("res://src/client/view/voxel_model.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Growth := preload("res://src/shared/world/growth.gd")
const Felling := preload("res://src/shared/game/felling.gd")
const Foliage := preload("res://src/client/world/foliage.gd")
const Grass := preload("res://src/shared/world/grass.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const Biomes := preload("res://src/shared/content/biomes.gd")
const PixelTextures := preload("res://src/client/view/pixel_textures.gd")
const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")
const Figure := preload("res://src/client/view/figure.gd")
const Yaml := preload("res://src/shared/content/yaml.gd")
const Content := preload("res://src/shared/content/content.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const Items := preload("res://src/shared/content/items.gd")
const Starts := preload("res://src/shared/content/starts.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
const WorldActions := preload("res://src/shared/game/world_actions.gd")
const Storms := preload("res://src/shared/game/storms.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const Workshop := preload("res://src/shared/game/workshop.gd")
const Clock := preload("res://src/shared/game/clock.gd")
const RealWeather := preload("res://src/shared/game/real_weather.gd")
const Wildlife := preload("res://src/shared/game/wildlife.gd")
const Rules := preload("res://src/shared/game/rules.gd")
const Session := preload("res://src/shared/game/session.gd")
const Vitals := preload("res://src/shared/game/vitals.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Plants := preload("res://src/shared/content/plants.gd")
const CraftQueue := preload("res://src/shared/game/craft_queue.gd")
const Knowledge := preload("res://src/shared/game/knowledge.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const Tracks := preload("res://src/client/world/tracks.gd")
const ChunkStreamer := preload("res://src/client/world/chunk_streamer.gd")
const SoundScript := preload("res://src/client/audio/sound.gd")
const Music := preload("res://src/client/audio/music.gd")

var checks := 0
var failures := 0


func run() -> void:
	pass


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


## Writes `text` into the file at `path` (a temporary mod's data), making its folder.
func _write_file(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## Removes folder `dir` with all it holds (a temporary mod).
func _remove(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_remove("%s/%s" % [dir, sub])
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute("%s/%s" % [dir, f])
	DirAccess.remove_absolute(dir)


## Brings a chunk to `stage` the way the game does: its own earlier stages first,
## then the chunks around it to the stage before.
func _ensure_stage(gen, key: Vector2i, stage: int) -> void:
	if gen.stage_of(key) >= stage:
		return
	_ensure_stage(gen, key, stage - 1)
	if stage > WorldGen.TERRAIN:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				_ensure_stage(gen, key + Vector2i(dx, dz), stage - 1)
	gen.run(key, stage)


## A world of `seed` made at once over four by four chunks at its spawn: {"gen", "world",
## "area" (the chunk keys, row by row)}.
func _land(seed_value: int) -> Dictionary:
	var gen := WorldGen.new(seed_value, 40)
	var from := WorldData.chunk_key(gen.spawn_guess.x, gen.spawn_guess.z) - Vector2i(2, 2)
	gen.generate_area(from, from + Vector2i(4, 4))
	var area := []
	for cz in range(from.y, from.y + 4):
		for cx in range(from.x, from.x + 4):
			area.append(Vector2i(cx, cz))
	return {"gen": gen, "world": gen.world, "area": area}


## True when the chunks `keys` have the same cells and shapes in both worlds.
func _same(a: WorldData, b: WorldData, keys: Array) -> bool:
	for key: Vector2i in keys:
		var ca: WorldData.Chunk = a.chunks.get(key)
		var cb: WorldData.Chunk = b.chunks.get(key)
		if ca == null or cb == null or ca.cells != cb.cells or ca.shapes != cb.shapes:
			return false
	return true


func _same_cells(a: WorldData, b: WorldData, keys: Array) -> bool:
	for key: Vector2i in keys:
		var ca: WorldData.Chunk = a.chunks.get(key)
		var cb: WorldData.Chunk = b.chunks.get(key)
		if ca == null or cb == null or ca.cells != cb.cells:
			return false
	return true


## The shapes the meshes of the shaped chunks among `keys` read: the chunk and a
## column around it (the shapes of a chunk not shaped yet are only a draft).
func _same_view(gen, a: WorldData, b: WorldData, keys: Array) -> bool:
	for key: Vector2i in keys:
		if gen.stage_of(key) < WorldGen.SHAPED:
			continue
		var x0 := key.x * WorldData.CHUNK
		var z0 := key.y * WorldData.CHUNK
		var x1 := x0 + WorldData.CHUNK
		var z1 := z0 + WorldData.CHUNK
		if a.padded(true, 0, x0 - 1, z0 - 1, x1 + 1, z1 + 1) != b.padded(true, 0, x0 - 1, z0 - 1, x1 + 1, z1 + 1):
			return false
	return true


## The one acting, for the rules in src/shared/game/ without the client (see WorldActions).
## A character standing at `at` (see Character).
class Survivor extends "res://src/shared/game/character.gd":
	var at := Vector3.ZERO
	var back_at := Vector3.ZERO
	## What the hands hold; the first is the hand in use.
	var hands := ["", ""]

	func _where() -> Vector3:
		return at

	func in_hands() -> Array:
		return hands

	func _came_back(to: Vector3) -> void:
		back_at = to

	func feet() -> Vector3i:
		return Vector3i((at / WorldData.CELL).floor())

	func facing_step() -> Vector2i:
		return Vector2i(0, -1)

	func moving() -> bool:
		return false

	func overlaps_cell(_cell: Vector3i) -> bool:
		return false

	func held() -> String:
		return hands[0]

	func tool() -> Dictionary:
		return Tools.of(hands[0])

	func brush() -> Dictionary:
		return Tools.BRUSHES[0]

	func use_tool() -> void:
		pass


class Who extends RefCounted:
	var inventory := Inventory.new()
	var position := Vector3.ZERO
	var held_back: Array[Vector3] = []
	var sacks: Array[Vector3] = []
	var item := ""
	var said: Array[String] = []

	func feet() -> Vector3i:
		return Vector3i((position / WorldData.CELL).floor())

	func facing_step() -> Vector2i:
		return Vector2i(0, -1)

	func moving() -> bool:
		return false

	func overlaps_cell(_cell: Vector3i) -> bool:
		return false

	func held() -> String:
		return item

	func tool() -> Dictionary:
		return Tools.of(item)

	func brush() -> Dictionary:
		return Tools.BRUSHES[0]

	func act(_action: String) -> bool:
		return true

	func give(id: String, n: int, worn := 0) -> int:
		return inventory.add(id, n, worn)

	func note(_stat: String, _n: float = 1.0) -> void:
		pass

	func use_tool() -> void:
		pass

	func lay(_kind: String, _data: Variant) -> Vector3:
		return position

	func nag(_reason: String, text: String) -> void:
		said.append(text)

	func say(text: String) -> void:
		said.append(text)
