extends RefCounted
## Saving the game on this device (see WorldStore for the files). Picks the world the
## game starts with: the one played last, else the one the settings ask for; when it
## was saved, the chunks the player changed come back from the save as the generator
## reaches them, and the player, the clock and the props are put back. Once the
## player has entered the world, the changed chunks and the player are saved every
## INTERVAL seconds, a few chunks a frame, and all at once when the menu opens, the
## game loses focus or quits; so are the regions of the map the player explored
## (Minimap), one a frame among the chunks. What goes in, the systems of src/shared tell themselves
## (Clock, Placed, Character, the bag: to_dict or to_list); other modules keep their
## part of the player with track(). Off for tests and tools (`enabled`). `game` is the
## Main node.

const WorldStore := preload("res://src/shared/world/world_store.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const Mods := preload("res://src/shared/content/mods.gd")

const PLAYER := "players/local.json"
## Seconds between saves while playing.
const INTERVAL := 30.0
## Chunks written in one frame of a save while playing (under a millisecond each
## on a desktop, a zstd file of about a kilobyte).
const CHUNKS_PER_FRAME := 1

var game
var enabled := true
var store: WorldStore
## The world has a save (read at the start or written since): its world.json and
## the player's record.
var has_save := false
var meta := {}
var player_record := {}
## The player was put back where the save had them (else they start at the spawn).
var player_placed := false
## Saving runs once the player has been in the world.
var active := false
## Seconds played in this world, over all runs.
var played := 0.0
## Objects that keep a part of the player (to_dict, from_dict), by section name.
var sections := {}
## The chunks of the save under way, written a few a frame, and the regions of the map.
var _queue: Array[Vector2i] = []
var _maps: Array[Vector2i] = []
var _writing := false
var _clock := 0.0


func _init(g) -> void:
	game = g


## Sets the seed, settings and mods of the world to start (game.world_seed,
## world_options, world_mods) and reads its save if it has one. A saved world keeps the
## mods it was made with; a new one takes the set chosen on «Новый мир».
func choose_world() -> void:
	var current := WorldStore.read_current() if enabled else {}
	game.world_mods = game.settings.world_mods()
	if current.is_empty():
		game.world_seed = game.settings.values.world_seed
		game.world_options = game.settings.world_options()
	else:
		game.world_seed = int(current.seed)
		game.world_options = {}
		for k: String in WorldGen.DEFAULT_SETTINGS:
			game.world_options[k] = int(current.settings.get(k, WorldGen.DEFAULT_SETTINGS[k]))
	if not enabled:
		return
	store = WorldStore.new(WorldStore.world_dir(game.world_seed, game.world_options))
	if not store.exists():
		return
	meta = store.read_json(WorldStore.WORLD)
	if meta.get("format") != float(WorldStore.FORMAT):
		push_error("save %s has format %s, not %d: started anew" % [store.dir, meta.get("format"), WorldStore.FORMAT])
		meta = {}
		return
	has_save = true
	# A save from before mods were kept was made with every mod there was; one from before
	# the plants (no `content` mark), the tools (`content` below 3) or the sounds (below 4)
	# were mods of their own had them in the base game.
	game.world_mods = Array(meta.get("mods", Mods.available())).filter(func(m) -> bool: return m is String)
	for split in [[2, "plants"], [3, "tools"], [4, "sounds"]]:
		if int(meta.get("content", 1)) < split[0] and not split[1] in game.world_mods and split[1] in Mods.available():
			game.world_mods.insert(1, split[1])
	player_record = store.read_json(PLAYER)
	played = meta.get("played", 0.0)
	print("save %s: %d chunks, %.0f s played" % [store.dir, store.chunk_count(), played])


## Makes `seed_value` and `options` the world to start next time; the world being
## played is saved first.
func switch_world(seed_value: int, options: Dictionary) -> void:
	flush()
	if enabled:
		WorldStore.write_current(seed_value, options)


## Puts the saved player back into the scene just built.
func restore_player() -> void:
	var p: Variant = player_record.get("position")
	if has_save and p is Array and p.size() == 3:
		game.player.position = Vector3(p[0], p[1], p[2])
		player_placed = true


## Puts the saved clock and season back (the save keeps them as "sky").
func restore_clock() -> void:
	if has_save and meta.get("sky") is Dictionary:
		game.clock.from_dict(meta.sky)


## The cell of a prop ("chest", "campfire") in a save from before things could be
## placed (see Props.place), or null.
func prop_cell(name: String) -> Variant:
	var c: Variant = meta.get("props", {}).get(name)
	if c is Array and c.size() == 3:
		return Vector3i(int(c[0]), int(c[1]), int(c[2]))
	return null


## Keeps `obj` (with to_dict() and from_dict(d)) in the player's section `name`; it
## gets what was saved there at once.
func track(name: String, obj) -> void:
	sections[name] = obj
	if player_record.get(name) is Dictionary:
		obj.from_dict(player_record[name])


## The player has entered the world: saving starts.
func begin() -> void:
	active = enabled


func update(delta: float) -> void:
	if not active:
		return
	played += delta
	_clock += delta
	if not _writing and _clock >= INTERVAL:
		_clock = 0.0
		_writing = true
		_take_unsaved()
	if not _writing:
		return
	# The browser keeps the files in its own store, written after the frame.
	var wrote := "чанк"
	var n := 0
	while not _queue.is_empty() and n < CHUNKS_PER_FRAME:
		_write_chunk(_queue.pop_back())
		n += 1
	if n == 0 and not _maps.is_empty():
		_write_map(_maps.pop_back())
		wrote = "карта"
	if _queue.is_empty() and _maps.is_empty():
		_write_world()
		wrote = "мир"
		_writing = false
	game.hud.perf.mark("запись", wrote)


## Saves everything now.
func flush() -> void:
	if not active:
		return
	_take_unsaved()
	while not _queue.is_empty():
		_write_chunk(_queue.pop_back())
	while not _maps.is_empty():
		_write_map(_maps.pop_back())
	_write_world()
	_writing = false
	_clock = 0.0


func _take_unsaved() -> void:
	var world: WorldData = game.world
	for key: Vector2i in world.unsaved:
		if not _queue.has(key):
			_queue.append(key)
	world.unsaved.clear()
	var minimap = game.hud.minimap if game.hud != null else null
	if minimap != null:
		for key: Vector2i in minimap.unsaved:
			if not _maps.has(key):
				_maps.append(key)


## Writes region `key` of the explored map; it is kept unsaved when that fails.
func _write_map(key: Vector2i) -> void:
	var data: PackedByteArray = game.hud.minimap.save_region(key)
	if not data.is_empty() and not store.write_map(key, data):
		game.hud.minimap.unsaved[key] = true


func _write_chunk(key: Vector2i) -> void:
	if game.world.has_chunk(key) and not store.write_chunk(key, game.gen.pack(key)):
		game.world.unsaved[key] = true


## world.json and the player, and this world as the one to start next time.
func _write_world() -> void:
	meta = {
		"format": WorldStore.FORMAT,
		"seed": game.world_seed,
		"settings": game.world_options,
		"mods": game.world_mods,
		"content": 4,
		"levels": game.world.size_y,
		"created": meta.get("created", Time.get_datetime_string_from_system()),
		"saved": Time.get_datetime_string_from_system(),
		"played": played,
		"sky": game.clock.to_dict(),
		"placed": game.placed.to_list(),
	}
	var p: Vector3 = game.player.position
	player_record = {"format": WorldStore.FORMAT, "position": [p.x, p.y, p.z]}
	for name: String in sections:
		player_record[name] = sections[name].to_dict()
	store.write_json(PLAYER, player_record)
	store.write_json(WorldStore.WORLD, meta)
	WorldStore.write_current(game.world_seed, game.world_options)
	has_save = true
