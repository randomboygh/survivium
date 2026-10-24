extends SceneTree
## Draws the voxel models of the things (tools/art/voxel_art.gd) and saves them as PNG
## slices in the mod of each item that names one as its `model`:
## content/<mod>/models/<model>.png (see VoxelModel.from_image). A model painted over by
## hand is overwritten, so name the models to make:
## godot --headless --path . --script res://tools/make_models.gd -- [model ...]

const Items := preload("res://src/shared/content/items.gd")
const VoxelArt := preload("res://tools/art/voxel_art.gd")
const VoxelProps := preload("res://src/client/view/voxel_props.gd")


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	var done := {}
	for id in Items.IDS:
		var item := Items.get_item(id)
		var name: String = item.get("model", "")
		var prop: String = item.get("prop", "none")
		if name == "" or (not only.is_empty() and not name in only):
			continue
		var path := VoxelProps.model_path(item.mod, name)
		if done.has(path):
			continue
		done[path] = true
		var model = VoxelArt.prop(prop) if prop != "none" else VoxelArt.drop(name)
		if model == null:
			print("no drawing for %s" % path)
			continue
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var img: Image = model.to_image(prop == "none")
		var err := img.save_png(path)
		print("%s %s: %dx%d" % ["wrote" if err == OK else "FAILED", path, img.get_width(), img.get_height()])
	quit()
