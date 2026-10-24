extends SceneTree
## Draws the pictures of the items (tools/art/icon_art.gd) and saves them in the mod of
## each item that names one as its `icon`, content/<mod>/icons/<icon>.png, and the
## interface's small pictures (ItemIcons.UI) as assets/ui/<name>.png. A picture painted
## over by hand is overwritten, so name the pictures to make:
## godot --headless --path . --script res://tools/make_icons.gd -- [picture ...]

const Items := preload("res://src/shared/content/items.gd")
const IconArt := preload("res://tools/art/icon_art.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	var paths := {}
	for id in Items.IDS:
		var item := Items.get_item(id)
		if item.icon != "":
			paths[ItemIcons.icon_path(item.mod, item.icon)] = item.icon
	for name in ItemIcons.UI:
		paths[ItemIcons.ui_path(name)] = name
	for path in paths:
		var name: String = paths[path]
		if not only.is_empty() and not name in only:
			continue
		var img := IconArt.picture(name)
		if img == null:
			print("no drawing for %s" % path)
			continue
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var err := img.save_png(path)
		print("%s %s: %dx%d" % ["wrote" if err == OK else "FAILED", path, img.get_width(), img.get_height()])
	quit()
