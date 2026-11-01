extends RefCounted
## The server's save (plan/architecture/server.md, С4): the world it plays and every
## player who came, in the folder of a world as the game keeps it (WorldStore), so a
## world saved in the game opens on the server and the other way round. The chunks the
## players changed (WorldData.unsaved) are written first, each in its place; then the
## snapshot: world.json (seed, settings, bundles, materials, the clock, the things
## placed with what chests hold, the next player's number) and the record of each
## player in the world, players/<hash of their key>.json (number, name, where the body
## is, the bag, the body's state, the character, what they know, their queue), all
## written beside their files first and then moved over them, world.json last, all in
## one frame (no tick between: an item moved from a chest into a bag is in one of
## them). A save cut off leaves the old files whole and its own *.tmp, which the next
## start removes. The server saves every `every` seconds (Config.autosave), when a
## character leaves the world (that player's record alone) and on stop. Ctrl+C ends
## the process at once (Godot does not tell the script): what happened since the last
## save is lost, the save itself is whole.

const WorldStore := preload("res://src/shared/world/world_store.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const Mat := preload("res://src/shared/content/materials.gd")

const PLAYERS := "players"
## The parts of a player's record, as the game's save names them (save_game.gd).
const SECTIONS := ["inventory", "vitals", "character", "knowledge", "crafting"]

var store: WorldStore
var session
## The world's seed, WorldGen settings and bundles (for world.json).
var info := {}
## world.json as read or last written.
var meta := {}
## Seconds between saves.
var every := 10.0
## Seconds played in this world, over all runs.
var played := 0.0
## Saves done.
var saves := 0
var _clock := 0.0


func _init(s: WorldStore, sess, world_info: Dictionary, old_meta := {}) -> void:
	store = s
	session = sess
	info = world_info
	meta = old_meta
	played = float(meta.get("played", 0.0))


## The file of the player with `key`: a hash of it, so the folder does not hold the keys.
static func player_file(key: String) -> String:
	return "%s/%s.json" % [PLAYERS, key.sha256_text().left(32)]


## The number the next new player gets (the saved one, or 1).
func next_player() -> int:
	return maxi(1, int(meta.get("next_player", 1)))


## The record of the player with `key`, {} for one who never came.
func read_player(key: String) -> Dictionary:
	var d := store.read_json(player_file(key))
	return d if d.get("format") == float(WorldStore.FORMAT) and d.get("id") is float else {}


## Removes what a save cut off left beside its files; how many.
func clean() -> int:
	return WorldStore.remove_beside(store.dir)


## Counts the time; saves every `every` seconds.
func update(delta: float, server) -> void:
	played += delta
	_clock += delta
	if _clock >= every:
		save(server)


## Saves the chunks changed, then world.json and every player in the world as one
## snapshot (see above); false when a file could not be written (the old ones stay).
func save(server) -> bool:
	_clock = 0.0
	var ok := true
	var world = session.world
	for key: Vector2i in world.unsaved.keys():
		if not world.has_chunk(key):
			world.unsaved.erase(key)
			continue
		if store.write_chunk(key, session.gen.pack(key)):
			world.unsaved.erase(key)
		else:
			ok = false
	var files := {}
	for a in server.accounts.values():
		files[player_file(a.key)] = record_of(a)
	files[WorldStore.WORLD] = _world_meta(server.next_id)
	for name: String in files:
		if not WorldStore.write_json_beside(store.dir + "/" + name, files[name]):
			ok = false
	if ok:
		for name: String in files:
			ok = WorldStore.move_over(store.dir + "/" + name) and ok
		meta = files[WorldStore.WORLD]
	else:
		clean()
	saves += 1
	return ok


## Who the host blocked and the list of who may come in (Server.access), "" none yet.
const ACCESS := "access.json"


func read_access() -> Dictionary:
	return store.read_json(ACCESS)


func write_access(access: Dictionary) -> bool:
	return store.write_json(ACCESS, access)


## Writes the record of the player of account `a` alone (their character leaves).
func save_player(a) -> bool:
	return store.write_json(player_file(a.key), record_of(a))


## The record of account `a`: who they are and their character as it is.
static func record_of(a) -> Dictionary:
	var who = a.link.who
	var p: Vector3 = who.position
	return {"format": WorldStore.FORMAT, "id": a.id, "name": a.name, "position": [p.x, p.y, p.z],
		"inventory": who.inventory.to_dict(), "vitals": who.vitals.to_dict(), "character": who.to_dict(),
		"knowledge": a.link.workshop.knowledge.to_dict(), "crafting": a.link.workshop.queue.to_dict(),
		"saved": Time.get_datetime_string_from_system()}


## Puts the character of `record` into the new link's player: the bag, the body, what
## they know and their queue, and the body where it was.
static func restore(link, record: Dictionary) -> void:
	var who = link.who
	var parts := {"inventory": who.inventory, "vitals": who.vitals, "character": who,
		"knowledge": link.workshop.knowledge, "crafting": link.workshop.queue}
	for name: String in SECTIONS:
		if record.get(name) is Dictionary:
			parts[name].from_dict(record[name])
	link.workshop.settle()
	var p: Variant = record.get("position")
	if p is Array and p.size() == 3:
		who.teleport(Vector3(p[0], p[1], p[2]))


func _world_meta(next_id: int) -> Dictionary:
	return {
		"format": WorldStore.FORMAT,
		"seed": info.seed,
		"settings": info.settings,
		"mods": info.mods,
		"known": Mods.all(),
		"content": WorldStore.CONTENT,
		"materials": Array(Mat.IDS),
		"levels": session.world.size_y,
		"created": meta.get("created", Time.get_datetime_string_from_system()),
		"saved": Time.get_datetime_string_from_system(),
		"played": played,
		"sky": session.clock.to_dict(),
		"placed": session.placed.to_list(),
		"next_player": next_id,
	}
