extends SceneTree
## Fast preview: the default look's sheet drawn straight from PlayerArt (no PNGs, no
## import), outlined per frame as Figure does: body, loincloth, hair/short, fists.
const PlayerArt := preload("res://tools/art/player_art.gd")
const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")
const Figure := preload("res://src/client/view/figure.gd")


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var img: Image = null
	for n: String in ["body", "loincloth", "hair/short", "fists"]:
		var l := PlayerArt.layer(n)
		if img == null:
			img = l.duplicate()
		else:
			img.blend_rect(l, Rect2i(Vector2i.ZERO, l.get_size()), Vector2i.ZERO)
	var s := SpriteSheet.new(Figure.data())
	var walk: Array = []
	for f: Variant in Figure.data().animations.walk.frames:
		walk.append(int(f))
	for row in s.directions.size():
		for col in s.columns:
			# As Figure: the soles stay open only in the walk's frames.
			var soles := int(s.soles.get(s.directions[row], 0)) if walk.has(col) else 0
			SpriteSheet.outline_rect(img, Rect2i(Vector2i(col, row) * s.frame_size, s.frame_size), soles)
	img.save_png(out.path_join("bare.png"))
	var d := Figure.data()
	var f := FileAccess.open(out.path_join("layout.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"frame": d.frame, "directions": d.directions, "animations": d.animations, "works": d.works}))
	f.close()
	quit()
