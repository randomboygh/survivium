extends SceneTree
## Saves the player's sprite sheet as a PNG, scaled up, to look at the frames:
## godot --headless --path . --script res://tools/sheet.gd -- /tmp/sheet.png [scale] [left] [right] [active]
## left, right: what each hand holds as "picture:work" (a picture in
## content/core/sprites/held/, a work of player.yaml, e.g. "axe:chop", "scythe:mow") or
## "-" for nothing; active: "left" or "right".

const Figure := preload("res://src/client/figure.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "user://sheet.png"
	var scale := int(args[1]) if args.size() > 1 else 8
	var held := {"active": args[4] if args.size() > 4 else "right"}
	for i in 2:
		var spec: String = args[2 + i] if args.size() > 2 + i else ["-", "axe:chop"][i]
		if spec != "-":
			held[["left", "right"][i]] = {"sprite": "%s/held/%s.png" % [Figure.SPRITES, spec.get_slice(":", 0)],
				"anim": spec.get_slice(":", 1) if spec.contains(":") else "reach"}
	var img := Figure.sheet(Figure.data().layers, held).texture.get_image()
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("saved ", path)
	quit()
