extends SceneTree
## Checks the content files of every mod and fails on any problem, for CI and for a
## quick check after editing data:
## godot --headless --path . --script res://tools/validate.gd

const Content := preload("res://src/shared/content.gd")
const Mat := preload("res://src/shared/materials.gd")
const AiRules := preload("res://src/shared/ai_rules.gd")
const Trees := preload("res://src/shared/trees.gd")
const Bushes := preload("res://src/shared/bushes.gd")
const Items := preload("res://src/shared/items.gd")
const Crafting := preload("res://src/shared/crafting.gd")
const Plants := preload("res://src/shared/plants.gd")


func _init() -> void:
	var problems := Content.problems.duplicate()
	problems.append_array(Mat.check())
	problems.append_array(AiRules.check())
	problems.append_array(Trees.check())
	problems.append_array(Bushes.check())
	problems.append_array(Items.check())
	problems.append_array(Crafting.check())
	problems.append_array(Plants.check())
	for p in problems:
		printerr("content: " + p)
	if problems.is_empty():
		print("content OK: %d materials, %d items, %d creatures, %d trees, %d bushes, %d recipes, %d plants" % [
			Mat.COUNT, Items.IDS.size(), AiRules.SPECIES.size(), Trees.SPECIES.size(), Bushes.TYPES.size(),
			Crafting.RECIPES.size(), Plants.BY_ID.size()])
	else:
		printerr("%d content problems" % problems.size())
	quit(1 if problems.size() > 0 else 0)
