extends SceneTree
## Saves the player's sprite sheet as a PNG, scaled up, to look at the frames:
## godot --headless --path . --script res://tools/sheet.gd -- /tmp/sheet.png [scale] [layer ...]

const PlayerArt := preload("res://src/client/player_art.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "user://sheet.png"
	var scale := int(args[1]) if args.size() > 1 else 8
	var look: Array = args.slice(2) if args.size() > 2 else ["body", "hair", "shirt", "trousers", "boots", "axe"]
	var img := PlayerArt.sheet(look).texture.get_image()
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("saved ", path)
	quit()
