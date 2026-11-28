extends RefCounted
## The building of one chunk's meshes and plants, a column at a time (ChunkStreamer.run_jobs):
## which chunk, why it is built, how far it got. Before 2026-11-28 this was a dozen fields
## of the streamer with sentinel values and a positional array for the one set aside
## (REND-2).
##
## A job goes through its phases by `part`: BUILD while its columns are built (and, for an
## edit patching kept jobs, while `old_mesh` and then `old_plants` take the columns built),
## then the finishing parts 0.. (ChunkMesher.finish_part, the ground shown for a chunk new on
## screen, Foliage.finish_part, handing them to the renderer); a chunk whose ground is shown
## and whose plants are still to be built goes PLANTS_ONLY, then on to the plants' parts.

const ChunkMesher := preload("res://src/client/world/chunk_mesher.gd")
const Foliage := preload("res://src/client/world/foliage.gd")

## `part` while the columns are built.
const BUILD := -1
## `part` while only the plants' columns are built (the ground is shown, see `ground`).
const PLANTS_ONLY := -2

var key := Vector2i.ZERO
## Built for an edit (the edit budget, never set aside).
var edit := false
## Built only to keep its jobs for patching (it gives way to edits; see ChunkStreamer.kept).
var keep := false
## New on screen: its ground and water are shown as soon as they are built, its plants
## after (see ChunkStreamer._finish_part).
var ground := false
var mesh: ChunkMesher.Job
var plants: Foliage.Job
## BUILD, PLANTS_ONLY, or the finishing part being done.
var part := BUILD
## What the finishing parts made so far.
var meshes := []
var plant_parts := {}
## The kept jobs an edit patches (null for a whole chunk): the mesh's first, then the
## plants', each let go of once the columns built are put into it.
var old_mesh: ChunkMesher.Job
var old_plants: Foliage.Job
## The frame's budget the job had when it was set aside for the edits (ChunkStreamer.stashed).
var budget := 0


func _init(k: Vector2i, for_edit := false, to_keep := false) -> void:
	key = k
	edit = for_edit
	keep = to_keep


## Whether the columns built are still to be put into kept jobs (an edit's patch).
func patching() -> bool:
	return old_mesh != null or old_plants != null
