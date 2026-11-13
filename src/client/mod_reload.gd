extends RefCounted
## Hot reload of the mods' data (decision 184): on a computer running the game from the
## project's folder (ContentWatch.can_watch) the files under content/ are watched a few at
## a time each frame, and a YAML, picture or sound saved there is in the game a second or
## two later without a restart; «Перечитать данные модов» on «Тестирование» does the same at
## once. What is read anew: every record (animals, items, recipes, tools, skills, plants,
## starts), the animals' pictures, the items' icons and models, the sounds and the
## translations; the animals in the world take their species' new numbers at once. The
## materials of the cells, the biomes and the generator's land stay as the world was made
## (Mods.cells_kept): a new world takes them. The rules over the world run on the server
## inside the game, which shares the registries, so one reload serves both; a server far
## away reads its own with its command `reload`, and then tells its players' games
## (Protocol.MODS, decision 189): the game takes the files that changed over its
## connection (ModFetch), plays with them (Content.serve) and reads the data again the
## same way, without leaving the world.

const Mods := preload("res://src/shared/content/mods.gd")
const ContentWatch := preload("res://src/shared/content/content_watch.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const VoxelProps := preload("res://src/client/view/voxel_props.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Figure := preload("res://src/client/view/figure.gd")
const Content := preload("res://src/shared/content/content.gd")
const ModFiles := preload("res://src/shared/content/mod_files.gd")
const ModFetch := preload("res://src/client/net/mod_fetch.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")

var game
## The watch over the files, null where they cannot be watched (an exported game, the
## browser, a headless run: the tests and tools reload only when they ask).
var watch: ContentWatch
## How many reloads were done, and what the last one found (Content.problems).
var reloads := 0
var problems: PackedStringArray = []
## The files of a server's reload being taken (ModFetch), null when none are.
var fetch: ModFetch
## How many times a server's reload was taken into the game.
var served := 0


func _init(g) -> void:
	game = g
	if ContentWatch.can_watch() and DisplayServer.get_name() != "headless":
		watch = ContentWatch.new()


## Looks at a few of the files (ContentWatch.step) and reloads when one was saved.
func update() -> void:
	if watch != null and watch.step():
		reload()
	if fetch != null:
		fetch.update()


## Listens to the server of connection `net` for its reloads (Protocol.MODS).
func watch_server(net) -> void:
	net.event.connect(_on_event.bind(net))


## The mods' files are others than a moment ago (a server's instead of the game's own, or
## back): what was read of them and kept is read anew.
func forget_files() -> void:
	Lang.reread()
	VoxelProps.forget()
	ItemIcons.forget()
	Figure.forget()


func _on_event(kind: String, args: Variant, net) -> void:
	if kind != Protocol.MODS or game.welcome.is_empty():
		return
	if not args is Array or args.size() != 3 or not ModFiles.valid_hash(args[0]) or not args[2] is Array \
			or args[2].size() > 4096:
		return
	for b: Variant in args[2]:
		if not b is String or b.length() > 128:
			return
	if fetch != null:
		fetch.stop()
	if args[0] == Content.playing():
		fetch = null
		return
	fetch = ModFetch.new()
	# The player is in this server's world already: what its reload brings is taken.
	fetch.no_ask = true
	fetch.finished.connect(_on_taken)
	fetch.begin(net, args[0], args[2])


## The files of the server's reload are here (or could not be taken): the game plays with
## them and reads its data again.
func _on_taken(ok: bool) -> void:
	var f := fetch
	fetch = null
	if not ok:
		printerr("mods: the server's reload could not be taken: ", f.error)
		if game.hud != null:
			game.hud.toast("[the_servers_mod_data_could]")
		return
	Content.serve(f.table, f.digest)
	if f.bundles != Content.BUNDLES:
		Content.BUNDLES = f.bundles.duplicate()
		game.world_mods = f.bundles.duplicate()
	game.server_mods = {"url": game.join_url, "digest": f.digest, "table": f.table}
	served += 1
	print("mods: the server's reload: %d files taken (%d KB)" % [f.files, f.got >> 10])
	Figure.forget()
	reload()


## Reads the mods' data again and puts it into the game being played; tells how it went.
func reload() -> void:
	var t := Time.get_ticks_msec()
	problems = Mods.rescan(true)
	reloads += 1
	for p in problems:
		printerr("mods: ", p)
	Lang.reread()
	VoxelProps.forget()
	ItemIcons.forget()
	if game.session != null:
		game.session.reread()
	if game.placed != null:
		game.placed.read_footprints()
	if game.sound != null:
		game.sound.read_records()
	if game.creatures != null:
		game.creatures.relook()
	if game.props != null and game.ready_to_play:
		game.props.remodel()
	if game.character != null:
		game.character.inventory.changed.emit()
	if game.hosted != null and game.hosted.server != null:
		# The server made in this game shares the data read: its rules take it, and its
		# other players' games the files that changed.
		game.hosted.server.mods_reread()
	if game.workshop != null:
		game.workshop.changed.emit()
	print("mods: read again in %d ms, %d problems" % [Time.get_ticks_msec() - t, problems.size()])
	if game.hud == null:
		return
	if not problems.is_empty():
		game.hud.toast(Lang.line("[errors_in_the_mod_data]", [problems.size()]))
	elif Mods.cells_kept:
		game.hud.toast("[mod_data_reloaded_new_block]")
	else:
		game.hud.toast("[mod_data_reloaded]")
