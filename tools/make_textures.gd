extends SceneTree
## Draws the textures of the cell materials (tools/art/texture_art.gd) and saves each in
## the mod of its material, content/<mod>/textures/<texture>.png (see Mat.texture_path).
## A texture painted over by hand is overwritten, so name the materials to make:
## godot --headless --path . --script res://tools/make_textures.gd -- [material ...]

const Mat := preload("res://src/shared/content/materials.gd")
const TextureArt := preload("res://tools/art/texture_art.gd")


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	for m in range(1, Mat.COUNT):
		var name: String = Mat.IDS[m].get_slice(":", 1)
		if not only.is_empty() and not name in only:
			continue
		var path := Mat.texture_path(m)
		var img := TextureArt.picture(name)
		if img == null:
			print("no drawing for %s" % path)
			continue
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var err := img.save_png(path)
		print("%s %s: %dx%d" % ["wrote" if err == OK else "FAILED", path, img.get_width(), img.get_height()])
	quit()
