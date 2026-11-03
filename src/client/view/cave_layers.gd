extends RefCounted
## The view in layers (setting «Вид в пещере» → «слои»): under a roof, in a ravine or
## behind a hill, what stands in front of the player and over their head is dithered
## away layer by layer instead of cut off. In front of the player (at and above their
## feet) by vertical slices one cell thick across the way the camera looks, over them by
## levels; the first layers keep a share of their texels (density), the next ones fewer
## and fewer until none. The shaders do it (layer_alpha in common.gdshaderinc, globals
## layer_view, layer_fade, layer_density, set by ChunkStreamer.update_cut); this mirrors
## it for picking cells (Controls.pick passes through what is mostly gone).

const PixelView := preload("res://src/client/view/pixel_view.gd")

## The test settings' steps: how many layers count as the first, over how many the
## rest fades out, how much of a first layer is drawn.
const FIRSTS := [0, 1, 2, 3, 4]
const STRETCHES := [1, 2, 3, 4, 6, 8]
const DENSITIES := [0.25, 0.5, 0.75, 1.0]


## How much of the `i`th layer is drawn (as layer_share in common.gdshaderinc).
static func layer_share(i: int, first: int, stretch: int, density: float) -> float:
	if i < 1:
		return 1.0
	if i <= first:
		return density
	return density * clampf(1.0 - float(i - first) / maxf(stretch, 1.0), 0.0, 1.0)


## How much of `cell` is drawn with the player's feet in cell `base`, by `fade`
## (front first, front stretch, above first, above stretch) and `density`.
static func share(cell: Vector3i, base: Vector3i, fade: Vector4i, density: float) -> float:
	var d := cell - base
	var up := PixelView.up
	var way := -up / maxf(maxf(absf(up.x), absf(up.y)), 0.001)
	var front := roundi(d.x * way.x + d.z * way.y) if d.y >= 0 else 0
	return minf(layer_share(front, fade.x, fade.y, density), layer_share(d.y - 1, fade.z, fade.w, density))
