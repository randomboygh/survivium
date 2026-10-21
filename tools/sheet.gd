extends SceneTree
## Saves the player's sprite sheet as a PNG, scaled up, to look at the frames:
## godot --headless --path . --script res://tools/sheet.gd -- /tmp/sheet.png [scale] [left] [right] [active]
## left, right: what each hand holds, a model of PlayerArt.SHAPES, "block", "thing" or
## "-" for nothing; active: "left" or "right".

const PlayerArt := preload("res://src/client/player_art.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "user://sheet.png"
	var scale := int(args[1]) if args.size() > 1 else 8
	var held := {"active": args[4] if args.size() > 4 else "right"}
	var colours := {"block": Color(0.45, 0.6, 0.3), "thing": Color(0.78, 0.7, 0.52)}
	for i in 2:
		var model: String = args[2 + i] if args.size() > 2 + i else ["-", "axe"][i]
		if model != "-":
			held[["left", "right"][i]] = {"model": model, "colour": colours.get(model, Color(0.56, 0.57, 0.6))}
	var look := ["body", "hair", "shirt", "trousers", "boots"]
	var img := PlayerArt.sheet(look, held).texture.get_image()
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("saved ", path)
	quit()
