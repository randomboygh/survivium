extends RefCounted
## The test mod of a server for checking (decision 189; «/test mod», TestCommands): a few
## files made by the server and put over its mods' own (ContentHost.over), so that its
## files are not those of any build and a game that joins has to take them: a new item
## with its own icon, some animals painted another colour and named with a number, the
## jump's sound. Each `step` makes other files (another colour, pitch, name): «change the
## mod and read again» checks that a reload reaches the games in the world. The files are
## written from the server's own ones, so the mod follows the game's data as it changes.

const ModFiles := preload("res://src/shared/content/mod_files.gd")

## Where the files are written.
const DIR := "user://test_mod"
## The new item: its id, and its icon, the file a game knows the test mod by.
const ITEM := "core:test_mod"
const MARK := ModFiles.TEST_MARK
## The animals painted anew: [bundle, creature] each.
const ANIMALS := [["rabbit", "rabbit"], ["deer", "deer"], ["wolf", "wolf"], ["fox", "fox"], ["boar", "boar"]]
## The sounds put anew (the jump's two).
const SOUNDS := ["sounds/player/sounds/jump_1.wav", "sounds/player/sounds/jump_2.wav"]
const SOUND_RATE := 22050
## A painted animal's colour is at least this vivid.
const VIVID := 0.6


## Writes the files of step `step` (1 and up) from the mods of `root` into `dir`; what to
## put over the mods' own: {path inside content/: the file}.
static func write(root: String, step: int, dir := DIR) -> Dictionary:
	var out := {}
	var hue := fposmod(0.58 + step * 0.381966, 1.0)
	_put(out, dir, MARK, _icon(hue))
	var items := FileAccess.get_file_as_string(root.path_join("core/data/items.yaml"))
	if items != "":
		_put(out, dir, "core/data/items.yaml", (items.rstrip("\n") + "\n- id: test_mod\n  title: \"[core.items.test_mod]\"\n"
			+ "  weight: 0.1\n  stack: 10\n  icon: test_mod\n  source: special\n").to_utf8_buffer())
	# The item's name is in the game's own words (lang/<code>.yaml of core), with the step.
	_named(out, dir, root, "core", "[core.items.test_mod]", " %d" % step)
	for a: Array in ANIMALS:
		var picture := "animals/%s/sprites/creatures/%s.png" % a
		# A build for a phone or the browser holds its pictures only as imported: none to paint.
		var painted := _painted(FileAccess.get_file_as_bytes(root.path_join(picture)), hue)
		if not painted.is_empty():
			_put(out, dir, picture, painted)
		_named(out, dir, root, "animals/%s" % a[0], "[animals.creatures.%s]" % a[1], " +%d" % step)
	for i in SOUNDS.size():
		_put(out, dir, SOUNDS[i], _beep(330.0 * pow(2.0, ((step * 3) % 12 + i * 7) / 12.0)))
	return out


## Puts `note` after the words of `key` in every language of `base` (a mod or a bundle)
## that has them.
static func _named(out: Dictionary, dir: String, root: String, base: String, key: String, note: String) -> void:
	for file in DirAccess.get_files_at(root.path_join(base).path_join("lang")):
		var rel := "%s/lang/%s" % [base, file]
		var text := FileAccess.get_file_as_string(root.path_join(rel)) if file.get_extension() == "yaml" else ""
		var at := text.find("\"%s\": \"" % key)
		var end := text.find("\"\n", at)
		if at >= 0 and end >= 0:
			_put(out, dir, rel, (text.left(end) + note + text.substr(end)).to_utf8_buffer())


static func _put(out: Dictionary, dir: String, rel: String, bytes: PackedByteArray) -> void:
	var path := dir.path_join(rel)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null or not ModFiles.may_be(bytes, rel.get_extension()):
		return
	f.store_buffer(bytes)
	f.close()
	out[rel] = path


## The new item's icon: a gem of colour `hue`, 12 px like the others.
static func _icon(hue: float) -> PackedByteArray:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			var d := absf(x - 5.5) + absf(y - 5.5)
			if d <= 5.0:
				var light := 0.95 if x + y < 9 else (0.75 if d < 4.0 else 0.5)
				img.set_pixel(x, y, Color.from_hsv(hue, 0.25 if d < 1.5 else 0.8, light) if d < 5.0 else Color(0.08, 0.06, 0.1))
	return img.save_png_to_buffer()


## The picture `png` with every pixel turned to the colour `hue`, vivid; empty when it is
## no picture.
static func _painted(png: PackedByteArray, hue: float) -> PackedByteArray:
	var img := Image.new()
	if png.is_empty() or img.load_png_from_buffer(png) != OK:
		return PackedByteArray()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				# The dark outline and the white of an eye stay what they are.
				var vivid := maxf(c.s, VIVID) if c.v > 0.2 and c.v < 0.97 else c.s
				img.set_pixel(x, y, Color.from_hsv(hue, vivid, c.v, c.a))
	return img.save_png_to_buffer()


## A short tone of `pitch` Hz as a WAV file (16 bit, one channel).
static func _beep(pitch: float) -> PackedByteArray:
	var n := int(SOUND_RATE * 0.16)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / SOUND_RATE
		var loud := minf(1.0, t * 200.0) * exp(-t * 18.0)
		data.encode_s16(i * 2, int(sin(TAU * pitch * t) * loud * 20000.0))
	var out := PackedByteArray()
	out.resize(44)
	for i in 4:
		out[i] = "RIFF".unicode_at(i)
		out[8 + i] = "WAVE".unicode_at(i)
		out[12 + i] = "fmt ".unicode_at(i)
		out[36 + i] = "data".unicode_at(i)
	out.encode_u32(4, 36 + data.size())
	out.encode_u32(16, 16)
	out.encode_u16(20, 1)
	out.encode_u16(22, 1)
	out.encode_u32(24, SOUND_RATE)
	out.encode_u32(28, SOUND_RATE * 2)
	out.encode_u16(32, 2)
	out.encode_u16(34, 16)
	out.encode_u32(40, data.size())
	return out + data
