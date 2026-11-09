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
## away reads its own with its command `reload`.

const Mods := preload("res://src/shared/content/mods.gd")
const ContentWatch := preload("res://src/shared/content/content_watch.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const VoxelProps := preload("res://src/client/view/voxel_props.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")

var game
## The watch over the files, null where they cannot be watched (an exported game, the
## browser, a headless run: the tests and tools reload only when they ask).
var watch: ContentWatch
## How many reloads were done, and what the last one found (Content.problems).
var reloads := 0
var problems: PackedStringArray = []


func _init(g) -> void:
	game = g
	if ContentWatch.can_watch() and DisplayServer.get_name() != "headless":
		watch = ContentWatch.new()


## Looks at a few of the files (ContentWatch.step) and reloads when one was saved.
func update() -> void:
	if watch != null and watch.step():
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
	if game.workshop != null:
		game.workshop.changed.emit()
	print("mods: read again in %d ms, %d problems" % [Time.get_ticks_msec() - t, problems.size()])
	if game.hud == null:
		return
	if not problems.is_empty():
		game.hud.toast(Lang.line("Ошибок в данных модов: %d (см. консоль)", [problems.size()]))
	elif Mods.cells_kept:
		game.hud.toast("Данные модов перечитаны; новые материалы клеток — только в новом мире")
	else:
		game.hud.toast("Данные модов перечитаны")
