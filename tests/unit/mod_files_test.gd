extends "res://tests/unit/test_case.gd"
## The mods' files a server gives its players (decision 189): the list of a set and its
## hash (ModFiles), the server's side (ContentHost) and the game's (ModFetch, ModCache)
## over a wire inside the test, and the game playing with the files taken (Content.serve).

const ModFiles := preload("res://src/shared/content/mod_files.gd")
const ModCache := preload("res://src/client/net/mod_cache.gd")
const ModFetch := preload("res://src/client/net/mod_fetch.gd")
const ContentHost := preload("res://src/server/content_host.gd")
const TestMod := preload("res://src/server/test_mod.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const ModImport := preload("res://src/client/mod_import.gd")
const ModReload := preload("res://src/client/mod_reload.gd")

const DIR := "user://mod_files_test"
const WOLF := "animals/wolf/data/creatures.yaml"
const WOLF_PICTURE := "animals/wolf/sprites/creatures/wolf.png"
const GROWL := "animals/wolf/sounds/wolf_growl_2.wav"
const NEW_PICTURE := "core/icons/mod_files_test.png"
const MARK := Color(1.0, 0.0, 1.0)


## A connection to a ContentHost without a socket: the game's messages reach the host at
## once, the host's are delivered by `pump` (a tenth of a second of sending each time).
class Wire extends RefCounted:
	signal event(kind: String, args: Variant)
	var host: ContentHost
	var feed := ContentHost.Feed.new()
	var sent: Array = []
	var now := 0.0
	## Spoils the first byte of the next piece of a file delivered.
	var spoil := false

	func send(kind: String, args: Variant) -> void:
		sent.append(kind)
		if kind == Protocol.MOD_LIST:
			_deliver(host.list_msg(feed))
		elif kind == Protocol.MOD_FILES:
			host.ask(feed, args[0])

	func pump() -> void:
		now += 0.1
		for b in host.pieces(feed, now, 0):
			_deliver(b)

	func _deliver(bytes: PackedByteArray) -> void:
		var msg := Protocol.decode(bytes)
		if spoil and msg[0] == Protocol.MOD_DATA:
			for part: Array in msg[1]:
				if part[3] == 0 and part[4].size() > 0:
					spoil = false
					part[4][0] = part[4][0] ^ 0xFF
					break
		event.emit(msg[0], msg[1])


func run() -> void:
	_test_lists()
	_test_wire()
	_test_fetch_and_serve()
	_test_cache()
	_test_test_mod()
	_test_own_mods()
	_test_import()
	_test_big_reload()


func _test_lists() -> void:
	var all := ModFiles.scan("res://content")
	_check(all.has("core/mod.yaml") and all.has(WOLF) and all.has(WOLF_PICTURE) and all.has(GROWL),
		"the scan of the mods finds their YAML, pictures and sounds (%d files)" % all.size())
	_check(all.keys().all(func(rel: String) -> bool: return rel.get_extension() in ModFiles.KINDS and ModFiles.valid_path(rel)),
		"and nothing else: no imports, no READMEs; every path is one a list may hold")
	_check(ModFiles.skipped.is_empty(), "no file of the game's mods is left out of it: %s" % [ModFiles.skipped])
	var bytes := FileAccess.get_file_as_bytes("res://content/" + WOLF)
	_check(all[WOLF] == [ModFiles.hash_of(bytes), bytes.size()] and ModFiles.valid_hash(all[WOLF][0]),
		"a file goes with the hash of its bytes and its size")
	var bundles: Array = Mods.all()
	var whole := ModFiles.of_set(all, bundles)
	var no_wolf := ModFiles.of_set(all, bundles.filter(func(b: String) -> bool: return b != "animals/wolf"))
	_check(whole.size() == all.size(), "the set of every bundle is every file")
	_check(no_wolf.has(WOLF) and not no_wolf.has(WOLF_PICTURE) and not no_wolf.has(GROWL) and no_wolf.has("animals/mod.yaml")
		and no_wolf.has("animals/fox/sprites/creatures/fox.png"),
		"a set without a bundle keeps its YAML (the mods are read the same) and leaves out its pictures and sounds")
	var only_core := ModFiles.of_set(all, ["core"])
	_check(only_core.has("core/icons/campfire.png") and not only_core.has("animals/fox/sprites/creatures/fox.png")
		and only_core.has("animals/fox/data/creatures.yaml"), "a mod not played gives no pictures either")
	var shuffled := {}
	var keys := whole.keys()
	keys.reverse()
	for k: String in keys:
		shuffled[k] = whole[k]
	var other := whole.duplicate(true)
	other[WOLF] = [ModFiles.hash_of(PackedByteArray([1, 2, 3])), 3]
	_check(ModFiles.digest(whole) == ModFiles.digest(shuffled) and ModFiles.digest(whole) != ModFiles.digest(other)
		and ModFiles.digest(whole) != ModFiles.digest(no_wolf) and ModFiles.valid_hash(ModFiles.digest(whole)),
		"the hash of a set does not depend on the order and changes with any file")
	_check(Content.playing() == ModFiles.digest(ModFiles.of_set(all, Content.BUNDLES)) and Content.own_digest(bundles) == ModFiles.digest(whole),
		"the game names the files it plays with by that hash")
	var packed := ModFiles.pack(whole)
	_check(ModFiles.unpack(packed[0], packed[1]) == whole and packed[1].size() < 200 << 10,
		"a list packed for the wire comes out the same (%d KB packed)" % (packed[1].size() >> 10))
	_check(ModFiles.unpack(packed[0] + 1, packed[1]).is_empty() and ModFiles.unpack(packed[0], packed[1].slice(0, 100)).is_empty()
		and ModFiles.unpack("x", packed[1]).is_empty() and ModFiles.unpack(12, var_to_bytes([1, 2, 3])).is_empty(),
		"what is no packed list unpacks to nothing")
	var bad_lists := [{"../outside.yaml": all[WOLF]}, {"core/run.gd": all[WOLF]}, {"/etc/x.yaml": all[WOLF]},
		{"core/.hidden/x.yaml": all[WOLF]}, {"core\\x.yaml": all[WOLF]}, {"core/big.png": [all[WOLF][0], ModFiles.FILE_MAX + 1]},
		{"core/x.yaml": [all[WOLF][0], -1]}, {"user://x.yaml": all[WOLF]}]
	var refused := 0
	for bad: Dictionary in bad_lists:
		var p := ModFiles.pack(bad)
		refused += 1 if ModFiles.unpack(p[0], p[1]).is_empty() else 0
	_check(refused == bad_lists.size(), "a list with a path out of the mods' folder, a script or a file too large is refused whole (%d of %d)"
		% [refused, bad_lists.size()])
	_check(ModFiles.valid_path("my_mod/a-b/data/items.yaml") and not ModFiles.valid_path("a/../b.yaml") and not ModFiles.valid_path("a//b.yaml")
		and not ModFiles.valid_path("a/b.yaml/") and not ModFiles.valid_path("") and not ModFiles.valid_path("a/b") and not ModFiles.valid_path("a/b c.yaml"),
		"a path is folders and a name of plain letters with a known extension")
	_check(not ModFiles.valid_hash("abc") and not ModFiles.valid_hash(5) and not ModFiles.valid_hash("z".repeat(32)), "a hash is 32 hex letters")
	var png := FileAccess.get_file_as_bytes("res://content/" + WOLF_PICTURE)
	var huge := png.duplicate()
	huge[16] = 0x7F
	_check(ModFiles.may_be(png, "png") and not ModFiles.may_be(huge, "png") and not ModFiles.may_be(bytes, "png")
		and ModFiles.may_be(FileAccess.get_file_as_bytes("res://content/" + GROWL), "wav") and not ModFiles.may_be(png, "wav")
		and ModFiles.may_be(bytes, "yaml") and not ModFiles.may_be(bytes, "gd"),
		"a picture must be a PNG of a sane size (read from its header), a sound a WAVE")


## The mods copied to DIR/content with a number, a picture, a file more and a file less.
func _changed_copy() -> String:
	var dir := DIR + "/content"
	_copy("res://content", dir)
	var text := FileAccess.get_file_as_string(dir.path_join(WOLF))
	var f := FileAccess.open(dir.path_join(WOLF), FileAccess.WRITE)
	f.store_string(text.replace("mass: 40", "mass: 41"))
	f.close()
	var img := Image.load_from_file(dir.path_join(WOLF_PICTURE))
	img.convert(Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, MARK)
	img.save_png(dir.path_join(WOLF_PICTURE))
	img.set_pixel(1, 0, MARK)
	img.save_png(dir.path_join(NEW_PICTURE))
	DirAccess.remove_absolute(dir.path_join(GROWL))
	return dir


func _test_wire() -> void:
	var dir := _changed_copy()
	var bundles: Array = Mods.all()
	var host := ContentHost.new(dir, bundles)
	host.ready()
	_check(host.digest != Content.own_digest(bundles) and host.list.has(NEW_PICTURE) and not host.list.has(GROWL)
		and host.size == ModFiles.total(host.list), "a server with other files has another hash for the same bundles")
	_check(not host.read() and host.read(["core"]) and host.read(bundles), "reading the files again tells whether they changed")
	var feed := ContentHost.Feed.new()
	_check(not host.ask(feed, "x") and not host.ask(feed, [1, 2]) and not host.ask(feed, ["zz"]) and not host.ask(feed, [host.digest, 5])
		and feed.queue.is_empty(), "what is no list of hashes is not taken")
	var many := []
	many.resize(ContentHost.ASK_MAX + 1)
	many.fill(host.list[WOLF][0])
	_check(not host.ask(feed, many) and feed.queue.is_empty(), "nor more hashes than a message may hold")
	# A file the server does not have comes as one piece that says so; the others after it.
	var unknown := "0".repeat(ModFiles.HASH_LEN)
	_check(host.ask(feed, [unknown, host.list[WOLF][0]]), "hashes are taken into the queue")
	var out := host.pieces(feed, 0.0, 0)
	var parts: Array = Protocol.decode(out[0])[1] if out.size() == 1 else []
	var yaml := FileAccess.get_file_as_bytes(dir.path_join(WOLF))
	_check(parts.size() == 2 and parts[0].slice(0, 3) == [unknown, 0, -1] and parts[1][0] == host.list[WOLF][0] and parts[1][2] == yaml.size()
		and parts[1][3] == yaml.size() and parts[1][4].decompress(parts[1][3], FileAccess.COMPRESSION_ZSTD) == yaml,
		"a file the server lacks is said so, a YAML comes packed in one message with it")
	# The sounds are megabytes: they go no faster than the rate, and not into a full pipe.
	var sounds := host.list.keys().filter(func(rel: String) -> bool: return rel.ends_with(".wav"))
	for i in range(0, sounds.size(), ContentHost.ASK_MAX):
		host.ask(feed, sounds.slice(i, i + ContentHost.ASK_MAX).map(func(rel: String) -> String: return host.list[rel][0]))
	var first := 0
	for b in host.pieces(feed, 1.0, 0):
		first += b.size()
	_check(first > 0 and first <= ContentHost.BURST + 2 * ContentHost.PIECE and not feed.queue.is_empty(),
		"the files go at the connection's rate: %d KB at once" % (first >> 10))
	_check(host.pieces(feed, 1.0, 0).is_empty() and host.pieces(feed, 2.0, ContentHost.BUFFERED_MAX).is_empty()
		and not host.pieces(feed, 2.0, 0).is_empty(), "nothing more in the same moment, nor while the connection has much waiting")
	var lists := 0
	for i in ContentHost.LISTS_MAX + 3:
		lists += 0 if host.list_msg(feed).is_empty() else 1
	_check(lists == ContentHost.LISTS_MAX, "the list is sent to a connection a few times at most")
	# A file edited since the list was read is not sent as the old one: the host is told.
	var later := FileAccess.open(dir.path_join(WOLF), FileAccess.WRITE)
	later.store_string("# edited\n")
	later.close()
	var stale := ContentHost.Feed.new()
	host.ask(stale, [host.list[WOLF][0]])
	var said: Array = Protocol.decode(host.pieces(stale, 0.0, 0)[0])[1]
	_check(said[0][2] == -1 and host.changed == WOLF, "a file changed on disk since the last reload is not given, and the host learns which")


func _test_fetch_and_serve() -> void:
	var dir := _changed_copy()
	var bundles: Array = Mods.all()
	ModCache.dir = DIR + "/cache"
	_remove(ModCache.dir)
	var host := ContentHost.new(dir, bundles)
	host.ready()
	var wire := Wire.new()
	wire.host = host
	var fetch := ModFetch.new()
	var ended := []
	fetch.finished.connect(func(ok: bool) -> void: ended.append(ok))
	fetch.begin(wire, host.digest, bundles)
	_check(fetch.state == "files" and fetch.files == 3 and wire.sent == [Protocol.MOD_LIST, Protocol.MOD_FILES]
		and fetch.want == host.list[WOLF][1] + host.list[WOLF_PICTURE][1] + host.list[NEW_PICTURE][1],
		"the game asks for the list, then only for the files it lacks (%d, %d bytes)" % [fetch.files, fetch.want])
	for i in 50:
		if fetch.state != "files":
			break
		wire.pump()
	_check(fetch.state == "done" and ended == [true] and fetch.got == fetch.want and fetch.table.size() == host.list.size(),
		"they come and the taking ends with every file of the set placed (%s %s)" % [fetch.state, fetch.error])
	var at: String = fetch.table.get(WOLF, "")
	_check(at == ModCache.path(host.list[WOLF][0], "yaml") and FileAccess.get_file_as_bytes(at) == FileAccess.get_file_as_bytes(dir.path_join(WOLF))
		and fetch.table.get("core/mod.yaml") == "res://content/core/mod.yaml" and not fetch.table.has(GROWL),
		"a file taken is kept by its hash, one the game has is its own, one the server lacks is nowhere")
	# The game plays with the server's files.
	var own := Content.playing()
	Content.serve(fetch.table, fetch.digest)
	var problems := Mods.activate(bundles)
	var wolf: Dictionary = AiRules.SPECIES.get("animals:wolf", {})
	var pic := Content.picture(Content.asset(wolf, "sprites/creatures/wolf.png")) if not wolf.is_empty() else null
	_check(problems.is_empty() and Content.serving() and Content.playing() == host.digest and wolf.get("mass") == 41.0,
		"served, the data is the server's: the wolf weighs %s (%s)" % [wolf.get("mass"), problems])
	_check(pic != null and pic.get_pixel(0, 0).is_equal_approx(MARK), "its picture is the server's")
	_check(not Content.exists(Content.ROOT.path_join(GROWL)) and Content.exists(Content.ROOT.path_join(NEW_PICTURE))
		and Content.exists(Content.ROOT.path_join("animals/wolf/sounds/wolf_growl_1.wav"))
		and Content.sound(Content.ROOT.path_join("animals/wolf/sounds/wolf_growl_1.wav")) != null,
		"a file the server lacks is not there, one it added is, the rest are the game's own")
	_check(Mods.all() == bundles and Lang.phrases("en").has("[animals.creatures.wolf]") and Content.text(Figure.SPRITES + "/player.yaml") != "",
		"the bundles, the phrases and the figure's layout are read through the served files")
	# Joined again later: the set is kept, nothing is asked of the server.
	var again_wire := Wire.new()
	again_wire.host = host
	var again := ModFetch.new()
	again.begin(again_wire, host.digest, bundles)
	_check(again.state == "done" and again_wire.sent.is_empty() and again.table == fetch.table and again.files == 0,
		"a set taken before is all on the device: nothing is asked for")
	# The server's host edits a number and reloads: one file more to take.
	var f := FileAccess.open(dir.path_join(WOLF), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://content/" + WOLF).replace("mass: 40", "mass: 43"))
	f.close()
	_check(host.read(), "the server reads its files again: they changed")
	var next_wire := Wire.new()
	next_wire.host = host
	var next := ModFetch.new()
	next.begin(next_wire, host.digest, bundles)
	for i in 50:
		if next.state != "files":
			break
		next_wire.pump()
	Content.serve(next.table, next.digest)
	Mods.rescan(true)
	_check(next.state == "done" and next.files == 1 and AiRules.SPECIES["animals:wolf"].mass == 43.0 and Content.playing() == host.digest,
		"after a reload only the file that changed is taken, and the data is the new one")
	# Back to the game's own.
	Content.serve({})
	Content.live = false
	Mods.rescan()
	_check(not Content.serving() and Content.playing() == own and AiRules.SPECIES["animals:wolf"].mass == 40.0
		and Content.exists(Content.ROOT.path_join(GROWL)), "back in a world of its own the game plays with its own files")
	# A server that sends other bytes than the list says is not believed.
	_remove(ModCache.dir)
	var bad_wire := Wire.new()
	bad_wire.host = host
	bad_wire.spoil = true
	var bad := ModFetch.new()
	bad.begin(bad_wire, host.digest, bundles)
	for i in 50:
		if bad.state != "files":
			break
		bad_wire.pump()
	_check(bad.state == "failed" and bad.error == "[a_mod_file_from_the]" and ModCache.size() < bad.want,
		"a file whose bytes are not what the list says fails the taking and is not kept (%s %s)" % [bad.state, bad.error])
	var wrong := ModFetch.new()
	var wrong_wire := Wire.new()
	wrong_wire.host = host
	wrong.begin(wrong_wire, "f".repeat(ModFiles.HASH_LEN), bundles)
	_check(wrong.state == "failed", "a list that is not the set the server named is refused")
	var quiet := ModFetch.new()
	var quiet_wire := Wire.new()
	quiet_wire.host = host
	quiet.begin(quiet_wire, host.digest, bundles)
	quiet._heard -= int(ModFetch.STALL * 1000.0) + 1
	quiet.update()
	_check(quiet.state == "failed" and quiet.error == "[the_server_does_not_respond]", "a server gone quiet ends the taking")
	ModCache.dir = "user://mod_cache"


func _test_cache() -> void:
	ModCache.dir = DIR + "/cache2"
	_remove(ModCache.dir)
	_check(not DirAccess.dir_exists_absolute(ModCache.dir) and ModCache.size() == 0 and ModCache.trim() == 0 and ModCache.clear() == 0
		and not DirAccess.dir_exists_absolute(ModCache.dir), "nothing kept yet: nothing to count or clear, and no folder made for it")
	var files := []
	for i in 4:
		var bytes := PackedByteArray()
		bytes.resize(1000)
		bytes.fill(i + 1)
		files.append([ModFiles.hash_of(bytes), bytes])
		_check(ModCache.store(files[i][0], "yaml", bytes), "a file is kept")
	_check(ModCache.has(files[0][0], "yaml", 1000) and not ModCache.has(files[0][0], "yaml", 999) and not ModCache.has(files[0][0], "png", 1000)
		and ModCache.size() == 4000, "kept by hash, kind and size")
	_check(not ModCache.store(files[0][0], "yaml", files[1][1]) and not ModCache.store(files[0][0], "png", files[0][1])
		and not ModCache.store(files[0][0], "gd", files[0][1]) and not ModCache.store("../x", "yaml", files[0][1]),
		"bytes of another hash, of another kind than said, or under a name that is no hash are not kept")
	var name := func(i: int) -> String: return "%s.yaml" % files[i][0]
	var f := FileAccess.open(ModCache.dir.path_join(ModCache.USED), FileAccess.WRITE)
	f.store_string(JSON.stringify({name.call(0): 400, name.call(1): 100, name.call(2): 300, name.call(3): 200}))
	f.close()
	var freed := ModCache.trim(2500, {name.call(1): true})
	_check(freed == 2000 and ModCache.has(files[1][0], "yaml", 1000) and ModCache.has(files[0][0], "yaml", 1000)
		and not ModCache.has(files[3][0], "yaml", 1000) and not ModCache.has(files[2][0], "yaml", 1000),
		"past the limit the files used the longest ago go, never one of the set played (%d freed)" % freed)
	var list := {"core/a.yaml": [files[0][0], 1000]}
	ModCache.keep_set(ModFiles.digest(list), ["core"], ModFiles.pack(list))
	_check(ModCache.set_of(ModFiles.digest(list)) == {"bundles": ["core"], "list": list} and ModCache.set_of(files[0][0]).is_empty(),
		"the list of a set is kept under its hash")
	_check(ModCache.clear() == 2000 and ModCache.size() == 0 and ModCache.set_of(ModFiles.digest(list)).is_empty(), "clearing empties the cache")
	ModCache.dir = "user://mod_cache"
	_remove(DIR)


func _copy(from: String, to: String) -> void:
	_remove(to)
	DirAccess.make_dir_recursive_absolute(to)
	for f in DirAccess.get_files_at(from):
		if f.get_extension() in ModFiles.KINDS:
			DirAccess.copy_absolute(from.path_join(f), to.path_join(f))
	for d in DirAccess.get_directories_at(from):
		_copy(from.path_join(d), to.path_join(d))


## The test mod of a server for checking (TestMod): files no build has, each one a mod's
## file may be, other ones at each step; a server plays with them put over its own
## (ContentHost.over) and gives them; without them it is back to its own.
func _test_test_mod() -> void:
	var bundles: Array = Mods.all()
	var own := ModFiles.scan(Content.ROOT)
	var one := TestMod.write(Content.ROOT, 1, DIR + "/test_mod_1")
	var two := TestMod.write(Content.ROOT, 2, DIR + "/test_mod_2")
	var wanted := [TestMod.MARK, "core/data/items.yaml", "core/lang/en.yaml", "core/lang/ru.yaml",
		"animals/rabbit/sprites/creatures/rabbit.png", "animals/rabbit/lang/en.yaml", "animals/rabbit/lang/ru.yaml"] + TestMod.SOUNDS
	_check(wanted.all(func(rel: String) -> bool: return one.has(rel)), "the test mod has a new item, painted animals, names, sounds (%d files)" % one.size())
	var fit := 0
	var other := 0
	var stepped := 0
	for rel: String in one:
		var bytes := FileAccess.get_file_as_bytes(one[rel])
		fit += 1 if ModFiles.valid_path(rel) and ModFiles.may_be(bytes, rel.get_extension()) else 0
		other += 1 if not own.has(rel) or own[rel][0] != ModFiles.hash_of(bytes) else 0
		stepped += 1 if two.has(rel) and FileAccess.get_file_as_bytes(two[rel]) != bytes else 0
	_check(fit == one.size() and other == one.size(), "each a file a mod may have, none the game's own (%d, %d of %d)" % [fit, other, one.size()])
	_check(two.size() == one.size() and stepped == one.size() - 1, "the next step has other files, all but the item's record (%d of %d)" % [stepped, one.size()])
	var host := ContentHost.new(Content.ROOT, bundles)
	host.read()
	var plain := host.digest
	ContentHost.over = one
	_check(host.read() and host.digest != plain and host.list.has(TestMod.MARK) and host.table()[TestMod.MARK] == one[TestMod.MARK]
		and host.table()[WOLF] == Content.ROOT.path_join(WOLF), "a server with the files put over its own names another set")
	_check(host._bytes_of(host.list[TestMod.MARK][0]) == FileAccess.get_file_as_bytes(one[TestMod.MARK]), "and gives the files put over")
	Content.serve(host.table())
	var problems := Mods.rescan(true)
	_check(problems.is_empty() and Items.has(TestMod.ITEM) and Items.title(TestMod.ITEM) == "[core.items.test_mod]"
		and Lang.phrases("en").get("[core.items.test_mod]") == "Test mod token 1"
		and str(Lang.phrases("en").get("[animals.creatures.rabbit]")).ends_with(" +1")
		and Content.picture(Content.ROOT.path_join(TestMod.MARK)) != null,
		"the data read with them has the new item, its name and picture: %s" % [problems])
	ContentHost.over = {}
	_check(host.read() and host.digest == plain, "without them the server's set is its own again")
	Content.serve({})
	Content.live = false
	Mods.rescan()
	_check(not Items.has(TestMod.ITEM) and Lang.phrases("en").get("[core.items.test_mod]") == "Test mod token", "and so is the data")


## One's own mods on a phone (ModFiles.extra_dir): a folder whose files are laid over the
## game's sealed ones. The game plays with them, a server made there lists and gives
## them, a server's files are played with in their place while on it, and a file no list
## may carry is left out.
func _test_own_mods() -> void:
	var bundles: Array = Mods.all()
	var stock := Content.playing(true)
	var dir := DIR + "/extra"
	_remove(dir)
	DirAccess.make_dir_recursive_absolute(dir.path_join(WOLF.get_base_dir()))
	DirAccess.make_dir_recursive_absolute(dir.path_join(NEW_PICTURE.get_base_dir()))
	var text := FileAccess.get_file_as_string("res://content/" + WOLF)
	var f := FileAccess.open(dir.path_join(WOLF), FileAccess.WRITE)
	f.store_string(text.replace("mass: 40", "mass: 46"))
	f.close()
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(MARK)
	img.save_png(dir.path_join(NEW_PICTURE))
	f = FileAccess.open(dir.path_join("core/my notes.yaml"), FileAccess.WRITE)
	f.store_string("a: 1\n")
	f.close()
	ModFiles.extra_dir = dir
	ModFiles.skipped.clear()
	Mods.rescan()
	_check(ModFiles.extra().size() == 2 and ModFiles.skipped == PackedStringArray(["core/my notes.yaml"]),
		"the folder's files are found, one with a name no list may carry is left out: %s" % [ModFiles.skipped])
	_check(not Content.serving() and AiRules.SPECIES["animals:wolf"].mass == 46.0 and Content.exists(Content.ROOT.path_join(NEW_PICTURE))
		and Content.exists(Content.ROOT.path_join(GROWL)) and Content.playing() != stock,
		"the game plays with them laid over its own: the wolf weighs %s" % AiRules.SPECIES["animals:wolf"].mass)
	var host := ContentHost.new(Content.ROOT, bundles)
	host.ready()
	_check(host.digest == Content.playing() and host.list.has(NEW_PICTURE) and host.table()[WOLF] == dir.path_join(WOLF)
		and host._bytes_of(host.list[WOLF][0]) == FileAccess.get_file_as_bytes(dir.path_join(WOLF)),
		"a server made there names the set with them and gives them")
	var plan := ModFetch.plan(host.list)
	_check(plan.need.is_empty() and plan.table[WOLF] == dir.path_join(WOLF) and plan.table["core/mod.yaml"] == "res://content/core/mod.yaml",
		"its own game has every file of that set")
	# A server with the game's stock files: played with in place of one's own, then back.
	var plain := {}
	for rel: String in ModFiles.of_set(ModFiles.scan(Content.ROOT), bundles):
		plain[rel] = Content.ROOT.path_join(rel)
	Content.serve(plain, stock)
	Mods.rescan()
	_check(Content.serving() and Content.playing() == stock and AiRules.SPECIES["animals:wolf"].mass == 40.0
		and not Content.exists(Content.ROOT.path_join(NEW_PICTURE)), "on a server the game plays with the server's files, not its own mods")
	Content.serve({})
	Mods.rescan()
	_check(not Content.serving() and AiRules.SPECIES["animals:wolf"].mass == 46.0, "and with its own again after it")
	ModFiles.extra_dir = ""
	ModFiles.skipped.clear()
	Mods.rescan()
	_check(Content.served.is_empty() and Content.playing() == stock and AiRules.SPECIES["animals:wolf"].mass == 40.0,
		"without the folder the game's mods are as built")


## One's own mods brought in from a zip (ModImport): a whole «content» folder inside a
## folder, one mod with its mod.yaml at the top (named after the zip), the files no mod
## may have left out; and deleted.
func _test_import() -> void:
	var dir := DIR + "/import"
	_remove(dir)
	var zip_path := DIR + "/My-Pack 2.zip"
	var zip := ZIPPacker.new()
	zip.open(zip_path)
	for entry: Array in [["Pack/content/mine/mod.yaml", "id: mine\n"], ["Pack/content/mine/stuff/data/items.yaml", "a: 1\n"],
			["Pack/content/core/icons/x.png", "png"], ["Pack/readme.txt", "hello"], ["Pack/content/mine/../evil.yaml", "x"]]:
		zip.start_file(entry[0])
		zip.write_file((entry[1] as String).to_utf8_buffer())
		zip.close_file()
	zip.close()
	var got := ModImport.unpack(zip_path, dir)
	_check(got.files == 3 and got.skipped == 2 and FileAccess.file_exists(dir + "/mine/stuff/data/items.yaml")
		and FileAccess.file_exists(dir + "/core/icons/x.png") and not FileAccess.file_exists(dir + "/readme.txt"),
		"a zip of a content folder goes in as it is laid out there: %s" % got)
	zip = ZIPPacker.new()
	zip.open(zip_path)
	for entry: Array in [["mod.yaml", "id: pack\n"], ["fish/data/creatures.yaml", "b: 2\n"]]:
		zip.start_file(entry[0])
		zip.write_file((entry[1] as String).to_utf8_buffer())
		zip.close_file()
	zip.close()
	got = ModImport.unpack(zip_path, dir)
	_check(got.files == 2 and FileAccess.file_exists(dir + "/my_pack_2/fish/data/creatures.yaml"),
		"a zip of one mod goes in as a mod named after it: %s" % got)
	zip = ZIPPacker.new()
	zip.open(zip_path)
	var huge := PackedByteArray()
	huge.resize(ModImport.ModFiles.FILE_MAX + 1)
	for entry: Array in [["mod.yaml", "id: pack\n".to_utf8_buffer()], ["bomb/data/items.yaml", huge]]:
		zip.start_file(entry[0])
		zip.write_file(entry[1])
		zip.close_file()
	zip.close()
	var sizes := ModImport.sizes_of(FileAccess.get_file_as_bytes(zip_path))
	got = ModImport.unpack(zip_path, dir)
	_check(sizes.get("bomb/data/items.yaml") == huge.size() and sizes.get("mod.yaml") == 9 and got.files == 1 and got.skipped == 1
		and not FileAccess.file_exists(dir + "/my_pack_2/bomb/data/items.yaml"),
		"a file too big is left out by the zip's own list, never unpacked: %s %s" % [got, sizes])
	var bad := FileAccess.open(DIR + "/bad.zip", FileAccess.WRITE)
	bad.store_string("not a zip")
	bad.close()
	_check(ModImport.unpack(DIR + "/bad.zip", dir).error == "[this_is_not_a_zip]", "what is not a zip is told so")
	ModImport.clear(dir)
	_check(DirAccess.get_files_at(dir).is_empty() and DirAccess.get_directories_at(dir).is_empty(), "one's own mods are deleted")
	_remove(dir)


func _remove(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_remove(dir.path_join(d))
	DirAccess.remove_absolute(dir)


## A server's reload of more than ModFetch.ASK_ABOVE in the middle of play is not taken
## unasked (the weekly audit's WA-014): the game leaves the server saying how much, and
## joining again agrees to it.
func _test_big_reload() -> void:
	var link_script := GDScript.new()
	link_script.source_code = "extends RefCounted\nstatic var mods_allowed := \"\"\nvar socket\nvar join_error := \"\"\n"
	link_script.reload()
	var main_script := GDScript.new()
	main_script.source_code = "extends RefCounted\nvar bot\nvar link\nvar hud\nvar menu\n"
	main_script.reload()
	var game: RefCounted = main_script.new()
	game.link = link_script.new()
	var reload := ModReload.new(game)
	reload.fetch = ModFetch.new()
	reload.fetch.digest = "d".repeat(ModFiles.HASH_LEN)
	reload.fetch.want = ModFetch.ASK_ABOVE + 1
	reload.fetch.state = "ask"
	reload.update()
	_check(reload.fetch == null and reload.served == 0 and game.link.join_error != "" and link_script.mods_allowed == "d".repeat(ModFiles.HASH_LEN),
		"a big reload of a server in play is not taken: the player is asked by joining again: %s" % game.link.join_error)

